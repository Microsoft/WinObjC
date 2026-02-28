using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using Microsoft.Build.Utilities;
using Microsoft.Build.Framework;
using System.Runtime.Serialization;
using System.IO;
using System.Text.RegularExpressions;
using System.Reflection;
using System.Diagnostics;
using Microsoft.Win32;
using System.Threading;
using System.Globalization;
using System.Threading.Tasks;

namespace ClangCompile
{
    public static class StringSplitter
    {
        public static IEnumerable<string> Split(this string str, Func<char, bool> controller)
        {
            int nextPiece = 0;
            for (int c = 0; c < str.Length; c++)
            {
                if (controller(str[c]))
                {
                    yield return str.Substring(nextPiece, c - nextPiece);
                    nextPiece = c + 1;
                }
            }

            yield return str.Substring(nextPiece);
        }

        public static IEnumerable<string> SplitCommandLine(string commandLine)
        {
            bool inQuotes = false;
            return commandLine.Split(c =>
            {
                if (c == '\"')
                    inQuotes = !inQuotes;

                return !inQuotes && c == ' ';
            })
                                .Select(arg => arg.Trim())
                                .Where(arg => !string.IsNullOrEmpty(arg));
        }
    }
    
    [Rule(Name="Clang", PageTemplate="tool", DisplayName="Clang", Order="200")]
    [DataSource(Persistence="ProjectFile", ItemType="ClangCompile")]
    [PropertyCategory(Name="General", DisplayName="General", Order = 0)]
    [PropertyCategory(Name = "Paths", DisplayName = "Paths", Order = 1)]
    [PropertyCategory(Name = "Language", DisplayName = "Language", Order = 2)]
    [PropertyCategory(Name = "Preprocessor", DisplayName = "Preprocessor", Order = 3)]
    [PropertyCategory(Name = "All Options", DisplayName = "All Options", Subtype = "Search", Order = 4)]
    [PropertyCategory(Name = "Command Line", DisplayName = "Command Line", Subtype = "CommandLine", Order = 5)]
    [FileExtension(Name="*.c", ContentType="ClangCpp")]
    [FileExtension(Name="*.cpp", ContentType="ClangCpp")]
    [FileExtension(Name="*.cc", ContentType="ClangCpp")]
    [FileExtension(Name="*.cxx", ContentType="ClangCpp")]
    [FileExtension(Name="*.m", ContentType="ClangObjCpp")]
    [FileExtension(Name="*.mm", ContentType="ClangObjCpp")]
    [ItemType(Name="ClangCompile", DisplayName="Clang source")]
    [ContentType(Name="ClangCpp", DisplayName="Clang C/C++", ItemType="ClangCompile")]
    [ContentType(Name = "ClangObjCpp", DisplayName = "Clang Objective C/C++", ItemType = "ClangCompile")]
    public class Clang : ToolTask
    {
        /// <summary>
        /// This class holds an item to be compiled by clang.
        /// </summary>
        class ClangItem
        {
            private Clang clangTask = null;
            private List<string> stdOut;
            private List<string> stdErr;

            public ITaskItem Item { get; private set; }
            public string ObjFileName { get; private set; }
            public string DepFileName { get; private set; }
            public string CommandLine { get; private set; }
            public int ExitCode { get; private set; }

            public ClangItem(Clang clangTask, ITaskItem item, string objFileName, string depFileName, string commandLine)
            {
                this.clangTask = clangTask;
                this.Item = item;
                this.ObjFileName = objFileName;
                this.DepFileName = depFileName;
                this.CommandLine = commandLine;
                this.stdOut = new List<string>();
                this.stdErr = new List<string>();
            }

            public void RunClang(string executable)
            {
                ProcessStartInfo startInfo = new ProcessStartInfo();
                startInfo.CreateNoWindow = true;
                startInfo.FileName = executable;
                startInfo.Arguments = this.CommandLine;
                startInfo.UseShellExecute = false;
                startInfo.RedirectStandardOutput = true;
                startInfo.RedirectStandardError = true;

                string stdOutString = null;
                string stdErrString = null;

                Process process = Process.Start(startInfo);

                // Wait for the program to complete as we record all of its StdOut and StdErr
                Parallel.Invoke(
                    () => { stdOutString = process.StandardOutput.ReadToEnd(); },
                    () => { stdErrString = process.StandardError.ReadToEnd(); }
                    );

                process.WaitForExit();

                ExitCode = process.ExitCode;
                if (!string.IsNullOrEmpty(stdOutString))
                {
                    this.stdOut = (stdOutString.Split(new char[] { '\n', '\r' }, StringSplitOptions.RemoveEmptyEntries)).ToList();
                }

                if (!string.IsNullOrEmpty(stdErrString))
                {
                    this.stdErr = (stdErrString.Split(new char[] { '\n', '\r' }, StringSplitOptions.RemoveEmptyEntries)).ToList();
                }
            }

            public void LogOutput()
            {
                clangTask.LogEventsFromTextOutput(this.Item.ItemSpec, MessageImportance.High);

                for (int i = 0; i < this.stdOut.Count; i++)
                {
                    clangTask.LogEventsFromTextOutput(this.stdOut[i], MessageImportance.Normal);
                }

                for (int i = 0; i < this.stdErr.Count; i++)
                {
                    clangTask.LogEventsFromTextOutput(this.stdErr[i], MessageImportance.Normal);
                }
            }
        }

        // This is only used to output our .tlog files at a logical time, after the end of a build.
        class TLogWriter : IDisposable
        {
            public readonly static string cacheKey = "ClangTaskTLogWriter";

            // Tracker has an AppDomain lifetime, so our cache should never be deleted before it.
            DependencyTracker tracker;

            public TLogWriter(DependencyTracker t)
            {
                tracker = t;
            }

            public void Dispose()
            {
                foreach (var file in tracker.cachedTlogMaps)
                {
                    StreamWriter sw = null;
                    try
                    {
                        // Write all the tlog files out to disk.
                        sw = new StreamWriter(File.Open(file.Key, FileMode.Create));

                        foreach (var val in file.Value)
                        {
                            sw.WriteLine("^" + val.Key);
                            foreach (string line in val.Value) { 
                                sw.WriteLine(line);
                            }
                        }

                        sw.Close();
                    }
                    catch (Exception)
                    {
                        Debug.WriteLine("Error writing TLog file: {0}", (object)file.Key);
                        if (sw != null)
                        {
                            sw.Close();
                        }
                    }
                }
            }
        }

        DependencyTracker Tracker
        {
            get
            {
                if (BuildEngine4 != null)
                {
                    tracker = (DependencyTracker)BuildEngine4.GetRegisteredTaskObject(DependencyTracker.cacheKey, RegisteredTaskObjectLifetime.AppDomain);
                }

                if (tracker == null)
                {
                    tracker = new DependencyTracker();

                    if (BuildEngine4 != null)
                    {
                        BuildEngine4.RegisterTaskObject(DependencyTracker.cacheKey, tracker, RegisteredTaskObjectLifetime.AppDomain, false);
                    }
                }

                return tracker;
            }
        }

        TLogWriter TLogs
        {
            get
            {
                if (BuildEngine4 != null)
                {
                    tlogWriter = (TLogWriter)BuildEngine4.GetRegisteredTaskObject(TLogWriter.cacheKey, RegisteredTaskObjectLifetime.Build);
                }

                if (tlogWriter == null)
                {
                    tlogWriter = new TLogWriter(Tracker);

                    if (BuildEngine4 != null)
                    {
                        BuildEngine4.RegisterTaskObject(TLogWriter.cacheKey, tlogWriter, RegisteredTaskObjectLifetime.Build, false);
                    }
                }
                return tlogWriter;
            }
        }

        TLogWriter tlogWriter;
        static DependencyTracker tracker;

        // CanonicalTrackedInputFiles' caching behaviour isn't good enough. Visual Studio watches the filesystem
        // with vigour, so we'll do the same thing.
        // This has an app object lifetime, so from Visual Studio our incremental builds will be fast, but commandline
        // builds with be comparable to CL.
        class DependencyTracker
        {
            public static readonly string cacheKey = "ClangCompileDependencyTracker";
            public Dictionary<string, Dictionary<string, List<string>>> cachedTlogMaps = new Dictionary<string, Dictionary<string, List<string>>>();

            // Only use canonical paths please.
            DateTime GetModDate(string path)
            {
                if (!cachedFileModDates.ContainsKey(path))
                {
                    try
                    {
                        // Todo: Consider moving to using directories instead?
                        FileSystemWatcher w = new FileSystemWatcher(Path.GetDirectoryName(path), Path.GetFileName(path));
                        w.Changed += WatchedFileChanged;
                        w.Renamed += WatchedFileRenamed;
                        w.Deleted += WatchedFileDeleted;
                        w.EnableRaisingEvents = true;
                        watcher.Add(w);

                        cachedFileModDates[path] = File.GetLastWriteTime(path);
                    } catch (Exception) {
                        // File likely doesn't exist, possibly from an old .tlog, or a moved project. 
                        // The watcher likely died at this point, so don't cache the date, since we'll probably want to retry later.
                        return DateTime.MinValue;
                    }
                }

                return cachedFileModDates[path];
            }

            void WatchedFileRenamed(object sender, RenamedEventArgs e)
            {
                GetModDate(e.FullPath); // Track the 'new' file
                SetOutOfDate(e.FullPath);
                SetOutOfDate(e.OldFullPath);
            }

            void WatchedFileDeleted(object sender, FileSystemEventArgs e)
            {
                SetOutOfDate(e.FullPath);
                needsRebuilding[e.FullPath] = true;
            }

            void WatchedFileChanged(object sender, FileSystemEventArgs e)
            {
                switch(e.ChangeType) {
                    case WatcherChangeTypes.Created:
                        GetModDate(e.FullPath); // Track the new file
                        SetOutOfDate(e.FullPath);
                        break;
                    case WatcherChangeTypes.Changed:
                        SetOutOfDate(e.FullPath);
                        break;
                    default:
                        // see w_Renamed
                        break;
                }
            }

            public void SetDependencies(string source, List<string> deps)
            {
                dependencies.Remove(source);
                dependencies[source] = deps;
                GetModDate(source); // Start tracking the files

                // Clear old updates
                foreach (List<string> updateList in updates.Values)
                {
                    updateList.Remove(source);
                }

                // Add them back
                foreach (var dep in deps)
                {
                    if (!updates.Keys.Contains(dep))
                    {
                        updates[dep] = new List<string>();
                    }
                    GetModDate(dep);
                    updates[dep].Add(source);
                }
            }
            
            public void SetUpToDate(string file, bool upToDate = true)
            {
                needsRebuilding[file] = !upToDate;
            }

            void SetOutOfDate(string file, int nTries = 2)
            {
                List<string> updateList;
                if (nTries > 0 && updates.TryGetValue(file, out updateList))
                {
                    foreach (string updFile in updateList)
                    {
                        needsRebuilding[updFile] = true;
                        SetOutOfDate(updFile, --nTries);
                    }
                }

            }

            DateTime GetNewestInTreeInner(string file, int nTries = 2)
            {
                DateTime newest = GetModDate(file);
                List<string> deps;

                if (nTries > 0 && dependencies.TryGetValue(file, out deps))
                {
                    foreach (string depFile in deps)
                    {
                        DateTime depMod = GetNewestInTreeInner(depFile, --nTries);
                        if (depMod > newest)
                        {
                            newest = depMod;
                        }
                    }
                }

                return newest;
            }

            DateTime GetNewestInTree(string file)
            {
                DateTime newest = DateTime.MinValue;
                List<string> deps;

                if (dependencies.TryGetValue(file, out deps))
                {
                    foreach (string depFile in deps)
                    {
                        DateTime depMod = GetNewestInTreeInner(depFile);
                        if (depMod > newest)
                        {
                            newest = depMod;
                        }
                    }
                }

                return newest;
            }

            public bool OutOfDate(string file)
            {
                bool ret;
                if (needsRebuilding.TryGetValue(file, out ret))
                {
                    return ret;
                }

                if (!File.Exists(file))
                {
                    return true;
                }

                DateTime fileModDate;
                DateTime newestModDate;

                try
                {
                    fileModDate = GetModDate(file);
                    newestModDate = GetNewestInTree(file);
                }
                catch (Exception)
                {
                    // FileNotFoundException is never thrown, it just returns 00:00/1/1/1601 UTC
                    needsRebuilding[file] = true;
                    return true;
                }

                if (fileModDate > newestModDate)
                {
                    needsRebuilding[file] = false;
                    return false;
                }

                needsRebuilding[file] = true;
                return true;
           }

            List<FileSystemWatcher> watcher = new List<FileSystemWatcher>();

            Dictionary<string, DateTime> cachedFileModDates = new Dictionary<string,DateTime>();

            Dictionary<string, List<string>> dependencies = new Dictionary<string, List<string>>();
            Dictionary<string, List<string>> updates = new Dictionary<string,List<string>>(); // Bottom up view of dependencies.
            
            Dictionary<string, bool> needsRebuilding = new Dictionary<string, bool>();
        }

#region Private and utils
        void LogMessage(MessageImportance importance, string message, params object[] list)
        {
#if !LOWLEVEL_DEBUG
            if(importance == MessageImportance.High)
#endif
            {
                if (BuildEngine4 != null)
                {
                    Log.LogMessage(importance, message, list);
                }
            }
        }

        void LogWarning(string message, params object[] list)
        {
            if (BuildEngine4 != null)
            {
                Log.LogWarning(message, list);
            }
        }

        string DecorateFile(string path, string extension)
        {
            return Path.GetFileNameWithoutExtension(path) + "_" + Path.GetFullPath(path).GetHashCode().ToString("X") + extension;
        }

        string GetSpecial(string name, object value, ITaskItem input)
        {
            // ToLower is affected by localization. Need to be careful here.
            name = name.ToLower(new CultureInfo("en-US", false));

            if (value == null)
            {
                if (name == "inputfilename")
                {
                    return Path.GetFileName(input.ItemSpec);
                }
                else if (name == "inputabsdir")
                {
                    return Path.GetDirectoryName(Path.GetFullPath(input.ToString()));
                }
                else if (name == "dependencyfile")
                {
                    return GetSpecial("objectfilename", ObjectFileName, input) + ".d";
                }
            }
            
            if (name == "objectfilename")
            {
                if (value.ToString().Last() == '\\' || value.ToString().Last() == '/')
                {
                    return value + DecorateFile(input.ItemSpec, ".obj");
                }
            }
            else if (name == "input")
            {
                return GetFullPath(input.ToString());
            }

            return value == null ? null : value.ToString();
        }

        static string GetFullPath(string path)
        {
            if (path == null || path == "")
            {
                return "";
            }

            // Clang is not erroneously escaping quotes... per se. Windows allows quotes in filenames, but trims trailing whitespace.
            // eg. "C:\SomeDir\"SomeFile"" is a valid path. For clang to accept it you'd have to escape the filename quotes to "C:\SomeDir\\"SomeFile\""
            // "C:\SomeDir\" is not valid, since it thinks you're trying to refer to a file in SomeDir by the name of " [and subsequent arguments since we didn't match the quote]
            string fullPath = Path.GetFullPath(path);
            if (fullPath.EndsWith("\\"))
            {
                fullPath = fullPath.Substring(0, fullPath.Length - 1);
            }
            return "\"" + fullPath + "\"";
        }

        string GetClangExe()
        {
            return LLVMDirectory + @"\bin\clang.exe";
        }

        string GetClangResourceDir()
        {
            return LLVMDirectory + @"\lib\clang\" + LLVMClangVersion;
        }
        #endregion

        #region MSBuild Properties
        [PropertyPage(Visible = false, IncludeInCommandLine = false)]
        public string LLVMClangVersion
        {
            get
            {
                if(LLVMClangVersionValue == null || LLVMClangVersionValue == "") 
                {
                    LogMessage(MessageImportance.Low, "Clang exe: {0}", GetClangExe());

                    FileVersionInfo version = FileVersionInfo.GetVersionInfo(GetClangExe());
                    LLVMClangVersionValue = string.Format("{0}.{1}.{2}", version.FileMajorPart, version.FileMinorPart, version.FileBuildPart);
                }
                return LLVMClangVersionValue;
            }
            set
            {
                LLVMClangVersionValue = value;
            }
        }

        static string LLVMClangVersionValue;

        [PropertyPage(Visible = false, IncludeInCommandLine = false)]
        public string LLVMResourceDir
        {
            get
            {
                if (LLVMResourceDirValue == null || LLVMResourceDirValue == "")
                {
                    LLVMResourceDirValue = GetClangResourceDir();
                }
                return LLVMResourceDirValue;
            }
            set
            {
                LLVMResourceDirValue = value;
            }
        }

        string LLVMResourceDirValue;

        [Required]
        [PropertyPage(Visible = false, IncludeInCommandLine = false)]
        public string CommandTLogFile
        {
            get;
            set;
        }

        [Required]
        [PropertyPage(Visible = false, IncludeInCommandLine = false)]
        public string ProjectFile
        {
            get;
            set;
        }

        [Required]
        [PropertyPage(Visible = false, IncludeInCommandLine = false)]
        public string ReadTLogFile
        {
            get;
            set;
        }

        [Required]
        [PropertyPage(
          Category = "Command Line",
          Switch = "-c ",
          Visible = false)]
        [DataSource(
            Persistence = "ProjectFile",
            ItemType = "ClangCompile",
            SourceType = "Item")]
        public ITaskItem[] Input { get; set; }

        // Don't build the outputs, just create the output items.
        public bool Autocomplete { get; set; }

        public enum HeaderMapEnum
        {
            [Field(DisplayName="Disabled", Description="Disable use of header maps.")]
            Disabled,
            [Field(DisplayName="Project", Description="User a header map containing all headers in the VS project.")]
            Project,
            [Field(DisplayName = "Combined", Description = "User a header map containing all headers in the VS project, as well as any headers found in the same directory as the source files being compiled.")]
            Combined,
        }

        [PropertyPage(
            Category = "General",
            Description = "Specify type of header map to use.",
            DisplayName = "Use Header Map",
            IncludeInCommandLine = false)]
        [EnumeratedValue(Enumeration = typeof(HeaderMapEnum))]
        public string HeaderMap
        {
            get { return HeaderMapValue.ToString(); }
            set { HeaderMapValue = (HeaderMapEnum)Enum.Parse(typeof(HeaderMapEnum), value, true); }
        }

        HeaderMapEnum HeaderMapValue;

        [PropertyPage(
            DisplayName = "Framework-style header map entries",
            Description = "Add framework-style entries to header map.",
            Category = "General",
            IncludeInCommandLine = false)]
        public bool HeaderMapAddFrameworkEntries { get; set; }

        [PropertyPage(
            Category = "General",
            DisplayName = "Header Map Include",
            Description = "Header Map Include",
            Visible = false)]
        public string HeaderMapInclude { get; set; }

        public enum RuntimeLibraryEnum
        {
            [Field(DisplayName = "Multi-threaded", Description = "Causes your application to use the multithread, static version of the run-time library.", Switch = "-D_MT -Xclang --dependent-lib=libcmt -Xclang --dependent-lib=oldnames")]
            MultiThreaded,
            [Field(DisplayName = "Multi-threaded Debug", Description = "Defines _DEBUG and _MT. This option also causes the compiler to place the library name LIBCMTD.lib into the .obj file so that the linker will use LIBCMTD.lib to resolve external symbols.", Switch= "-D_DEBUG -D_MT -Xclang --dependent-lib=libcmtd -Xclang --dependent-lib=oldnames")]
            MultiThreadedDebug,
            [Field(DisplayName = "Multi-threaded DLL", Description = "Causes your application to use the multithread- and DLL-specific version of the run-time library. Defines _MT and _DLL and causes the compiler to place the library name MSVCRT.lib into the .obj file.", Switch = "-D_MT -D_DLL -Xclang --dependent-lib=msvcrt -Xclang --dependent-lib=oldnames")]
            MultiThreadedDLL,
            [Field(DisplayName = "Multi-threaded Debug DLL", Description = "Defines _DEBUG, _MT, and _DLL and causes your application to use the debug multithread- and DLL-specific version of the run-time library. It also causes the compiler to place the library name MSVCRTD.lib into the .obj file.", Switch = "-D_DEBUG -D_MT -D_DLL -Xclang --dependent-lib=msvcrtd -Xclang --dependent-lib=oldnames")]
            MultiThreadedDebugDLL
        }

        [PropertyPage(
            Category = "General",
            Description = "Specify runtime library for linking.",
            DisplayName = "Runtime Library")]
        [EnumeratedValue(Enumeration = typeof(RuntimeLibraryEnum))]
        public string RuntimeLibrary
        {
            get { return RuntimeLibraryValue.ToString(); }
            set { RuntimeLibraryValue = (RuntimeLibraryEnum)Enum.Parse(typeof(RuntimeLibraryEnum), value, true); }
        }

        RuntimeLibraryEnum RuntimeLibraryValue;

        public enum OptimizationLevelEnum {
            [Field(Switch="-O0", DisplayName="Disabled", Description="Disable optimization.")]
            Disabled,
            [Field(Switch="-Os", DisplayName="Optimize for size", Description="Medium level, with extra optimizations to reduce code size.")]
            MinSpace,
            [Field(Switch="-O2", DisplayName="Optimize for speed", Description="More optimizations.")]
            MaxSpeed,
            [Field(Switch="-O3", DisplayName="Maximum optimizations", Description="Even more optimizations.")]
            Full
        }

        [PropertyPage(
            Category="General",
            DisplayName="Optimization Level",
            Description="Select option for code optimization.")]
        [EnumeratedValue(Enumeration = typeof(OptimizationLevelEnum))]
        public string OptimizationLevel
        {
            get { return OptimizationLevelValue.ToString(); }
            set { OptimizationLevelValue = (OptimizationLevelEnum)Enum.Parse(typeof(OptimizationLevelEnum), value, true); }
        }

        OptimizationLevelEnum OptimizationLevelValue;

        [PropertyPage(
            DisplayName = "Debug Information",
            Description = "Specifies whether to keep debug information.",
            Category = "General",
            Switch = "-g -gcodeview")]
        public bool DebugInformation { get; set; }

        [PropertyPage(
            DisplayName = "Enable Exceptions",
            Description = "Specifies exception handling model to be used by the compiler for (Objective-)C++.",
            Category = "General",
            Switch = "-fexceptions")]
        public bool ExceptionHandling { get; set; }

        [PropertyPage(
            DisplayName = "Enable Objective-C ARC",
            Description = "Specifies whether to use Automatic Reference Counting.",
            Category = "General",
            Switch = "-fobjc-arc")]
        public bool ObjectiveCARC { get; set; }

        [PropertyPage(
            DisplayName = "Enable C and Objective-C Modules",
            Description = "Specifies whether to use Clang modules.",
            Category = "General",
            Switch = "-fmodules")]
        public bool ObjectiveCModules { get; set; }

        [PropertyPage(
            DisplayName = "Path to Objective-C modules",
            Description = "Path to the directory where the modules will be cached",
            Category = "General",
            Visible = false,
            Switch = "-fmodules-cache-path=")]
        [ResolvePath()]
        public string ObjectiveCModulesCachePath { get; set; }

        [PropertyPage(
            Category = "Paths",
            DisplayName = "Hidden SYSTEM include search paths",
            Description = "Hidden SYSTEM include search paths",
            Switch = "-isystem ",
            Visible = false)]
        [ResolvePath()]
        public string[] InternalSystemIncludePaths { get; set; }

        [PropertyPage(
            Category = "Paths",
            DisplayName = "Hidden include paths",
            Description = "Hidden include paths",
            Switch = "-I ",
            Visible = false)]
        [ResolvePath()]
        public string[] InternalIncludePaths { get; set; }

        [PropertyPage(
            Category = "Paths",
            DisplayName = "Hidden force inclusions",
            Description = "Hidden force inclusions",
            Switch = "-include ",
            Visible = false)]
        public string[] InternalForceIncludes { get; set; }

        [PropertyPage(
            Category = "Paths",
            DisplayName = "Excluded Search Path Subdirectories",
            Description = "Wildcard pattern for subdirectories to exclude from recursive search",
            IncludeInCommandLine = false)]
        public string[] ExcludedSearchPathSubdirectories
        {
            get { return ExcludedSearchPathSubdirectoriesValues; }
            set { ExcludedSearchPathSubdirectoriesValues = convertWildcardToRegEx(value); }
        }

        string[] ExcludedSearchPathSubdirectoriesValues;

        private static string[] convertWildcardToRegEx(string[] wildcardPaths)
        {
            List<string> patterns = new List<string>();

            foreach (string wildcard in wildcardPaths)
            {
                string pattern = Regex.Escape(wildcard);
                pattern = pattern.Replace("/", "\\\\");

                // Convert "*" to ".*", i.e. match any character except the path separator, zero or more times.
                pattern = pattern.Replace("\\*", "[^\\\\]*");

                // Convert "?" to ".", i.e. match exactly one character except the path separator.
                pattern = pattern.Replace("\\?", "[^\\\\]");

                patterns.Add(pattern + "$");
            }

            return patterns.ToArray();
        }

        private void dirSearch(string dirPath, ref List<string> outPaths)
        {
            int maxCount = outPaths.Count + 2048;
            outPaths.Add(dirPath);
            for (var i = outPaths.Count - 1; i < Math.Min(outPaths.Count, maxCount); i++)
            {
                try
                {
                    foreach (string d in Directory.GetDirectories(outPaths[i]))
                    {
                        bool excluded = false;
                        if (ExcludedSearchPathSubdirectories != null)
                        {
                            foreach (string pattern in ExcludedSearchPathSubdirectories)
                            {
                                if (Regex.IsMatch(d, pattern, RegexOptions.None))
                                {
                                    excluded = true;
                                    break;
                                }
                            }
                        }

                        if (!excluded)
                        {
                            outPaths.Add(d);
                        }
                    }
                }
                catch (System.Exception) { }
            }
        }

        private string[] expandPathGlobs(string[] inPaths)
        {
            List<string> outPaths = new List<string>();
            foreach (string path in inPaths)
            {
                string winPath = path.Replace('/', '\\');
                if (winPath.EndsWith("\\**"))
                    dirSearch(winPath.Substring(0, path.Length - 3), ref outPaths);
                else
                    outPaths.Add(winPath);
            }
            return outPaths.ToArray();
        }

        [PropertyPage(
            Category = "Paths",
            DisplayName = "User Include Paths",
            Description = "User header search paths.",
            Switch = "-iquote ")]
        [ResolvePath()]
        public string[] UserIncludePaths
        {
            get { return UserIncludePathsValue; }
            set { UserIncludePathsValue = expandPathGlobs(value); }
        }

        string[] UserIncludePathsValue;

        [PropertyPage(
            Category = "Paths",
            DisplayName = "Include Paths",
            Description = "Header search paths.",
            Switch = "-I")]
        [ResolvePath()]
        public string[] IncludePaths
        {
            get { return IncludePathsValue; }
            set { IncludePathsValue = expandPathGlobs(value); }
        }

        string[] IncludePathsValue;

        [PropertyPage(
            Category = "Paths",
            Subtype = "file",
            DisplayName = "Object File Name",
            Description = "Specifies a name to override the default object file name.",
            Switch = "-o ",
            IncludeInCommandLine = false)]
        [ResolvePath()]
        public string ObjectFileName { get; set; }

        [PropertyPage(
            Category = "Preprocessor",
            DisplayName = "Preprocessor Definitions",
            Description = "Define preprocessor symbols for your source files.",
            Switch = "-D")]
        public string[] PreprocessorDefinitions { get; set; }

        [PropertyPage(
            Category = "Preprocessor",
            DisplayName = "Undefine Preprocessor Definitions",
            Description = "Specifies one or more preprocessor undefines.",
            Switch = "-U")]
        public string[] UndefinePreprocessorDefinitions { get; set; }

        // This option needs to go BEFORE the file being compiled
        public enum CompileAsEnum
        {
            [Field(DisplayName = "Default", Description = "Default", Switch = "")]
            Default,
            [Field(DisplayName = "Compile as C Code", Description = "Compile as C Code", Switch = "-x c")]
            CompileAsC,
            [Field(DisplayName = "Compile as C++ Code", Description = "Compile as C++ Code", Switch = "-x c++")]
            CompileAsCpp,
            [Field(DisplayName = "Compile as Objective C Code", Description = "Compile as Objective C Code", Switch = "-x objective-c")]
            CompileAsObjC,
            [Field(DisplayName = "Compile as Objective C++ Code", Description = "Compile as Objective C++ Code", Switch = "-x objective-c++")]
            CompileAsObjCpp
        }

        [PropertyPage(
            Category = "Language",
            DisplayName = "Compile As",
            Description = "Select compile language for [Objective] C/C++ files.")]
        [EnumeratedValue(Enumeration = typeof(CompileAsEnum))]
        public string CompileAs
        {
            get { return CompileAsValue.ToString(); }
            set { CompileAsValue = (CompileAsEnum)Enum.Parse(typeof(CompileAsEnum), value, true); }
        }

        CompileAsEnum CompileAsValue;

        public enum CLanguageStandardEnum
        {
            // The names in this enum are lowercase to match the ClCompile names for the same thing.
            Unspecified,
            [Field(DisplayName = "C89", Description = "C89 Language Standard.", Switch = "-std=c89")]
            stdc89,
            [Field(DisplayName = "C99", Description = "C99 Language Standard.", Switch = "-std=c99")]
            stdc99,
            [Field(DisplayName = "C11", Description = "C11 Language Standard.", Switch = "-std=c11")]
            stdc11,
            [Field(DisplayName = "C99 (GNU Dialect)", Description = "C99 (GNU Dialect) Language Standard.", Switch = "-std=gnu99")]
            stdgnu99,
            [Field(DisplayName = "C11 (GNU Dialect)", Description = "C11 (GNU Dialect) Language Standard.", Switch = "-std=gnu11")]
            stdgnu11,
        }

        [PropertyPage(
            Category = "Language",
            DisplayName = "C Language Standard",
            Description = "Determines the C language standard.")]
        [EnumeratedValue(Enumeration = typeof(CLanguageStandardEnum))]
        public string CLanguageStandard
        {
            get { return CLanguageStandardValue.ToString(); }
            set {
                CLanguageStandardValue = string.IsNullOrEmpty(value)
                    ? CLanguageStandardEnum.Unspecified
                    : (CLanguageStandardEnum)Enum.Parse(typeof(CLanguageStandardEnum), value, true);
            }
        }

        CLanguageStandardEnum CLanguageStandardValue;

        public enum CppLanguageStandardEnum
        {
            // The names in this enum are lowercase to match the ClCompile names for the same thing.
            Unspecified,
            [Field(DisplayName = "C++03", Description = "C++03 Language Standard.", Switch = "-std=c++98")]
            stdcpp98,
            [Field(DisplayName = "C++11", Description = "C++11 Language Standard.", Switch = "-std=c++11")]
            stdcpp11,
            [Field(DisplayName = "C++14", Description = "C++14 Language Standard.", Switch = "-std=c++14")]
            stdcpp14,
            [Field(DisplayName = "C++17", Description = "C++17 Language Standard.", Switch = "-std=c++17")]
            stdcpp17,
            [Field(DisplayName = "C++03 (GNU Dialect)", Description = "C++03 (GNU Dialect) Language Standard.", Switch = "-std=gnu++98")]
            stdgnupp98,
            [Field(DisplayName = "C++11 (GNU Dialect)", Description = "C++11 (GNU Dialect) Language Standard.", Switch = "-std=gnu++11")]
            stdgnupp11,
            [Field(DisplayName = "C++14 (GNU Dialect)", Description = "C++14 (GNU Dialect) Language Standard.", Switch = "-std=gnu++14")]
            stdgnupp14,
            [Field(DisplayName = "C++17 (GNU Dialect)", Description = "C++17 (GNU Dialect) Language Standard.", Switch = "-std=gnu++17")]
            stdgnupp17,
        }

        [PropertyPage(
            Category = "Language",
            DisplayName = "C++ Language Standard",
            Description = "Determines the C++ language standard.")]
        [EnumeratedValue(Enumeration = typeof(CppLanguageStandardEnum))]
        public string CppLanguageStandard
        {
            get { return CppLanguageStandardValue.ToString(); }
            set {
                CppLanguageStandardValue = string.IsNullOrEmpty(value)
                    ? CppLanguageStandardEnum.Unspecified
                    : (CppLanguageStandardEnum)Enum.Parse(typeof(CppLanguageStandardEnum), value, true);
            }
        }

        CppLanguageStandardEnum CppLanguageStandardValue;

        [PropertyPage(
            Category = "Language",
            DisplayName = "LLVM Directory",
            Description = "Use LLVM from this directory for compilation",
            IncludeInCommandLine = false)]
        public string LLVMDirectory { get; set; }

        [PropertyPage(
            Category = "General",
            Subtype = "file",
            DisplayName = "Prefix Header",
            Description = "Specifies prefix header file to be included when compiling all source files.",
            Switch = "-include ")]
        [ResolvePath()]
        public string[] PrefixHeader { get; set; }

        [PropertyPage(
            Category = "General",
            DisplayName = "Maximum Clang Processes",
            Description = "Specifies the maximum number of clang processes to run in parallel. The argument can be -1 or any positive integer. A positive property value limits the number of concurrent operations to the set value. If it is -1, there is no limit on the number of concurrently running operations.",
            IncludeInCommandLine = false)]
        public int MaxClangProcesses { get; set; }

        [PropertyPage(
            Category = "Language",
            DisplayName = "Other C Flags",
            Description = "Other C Flags",
            IncludeInCommandLine = false)]
        public string OtherCFlags { get; set; }

        [PropertyPage(
            Category = "Language",
            DisplayName = "Other C++ Flags",
            Description = "Other C++ Flags",
            IncludeInCommandLine = false)]
        public string OtherCPlusPlusFlags { get; set; }

        [PropertyPage(
            Category = "Language",
            DisplayName = "Language-specific flags",
            Description = "Language-specific flags",
            Visible = false)]
        public string OtherFlags { get; set; }

        [PropertyPage(
            DisplayName = "Internal Compiler Flags",
            Visible = false,
            IncludeInCommandLine = false)]
        public string InternalCompilerFlags { get; set; }

        [PropertyPage(
            DisplayName = "Command Line",
            Visible = false,
            IncludeInCommandLine = false)]
        public string CommandLineTemplate { get; set; }

        public string AutocompleteCommandLineTemplate { get; set; }

        [Output]
        [PropertyPage(
            DisplayName = "Outputs",
            Visible = false,
            IncludeInCommandLine = false)]
        public ITaskItem[] Outputs { get; set; }

        [PropertyPage(
            Subtype = "AdditionalOptions",
            Category = "Command Line",
            DisplayName = "Additional Options",
            Description = "Additional Options",
            IncludeInCommandLine=false)]
        public string AdditionalOptions { get; set; }

        [PropertyPage(
            Category = "Preprocessor",
            DisplayName = "Dependency File",
            Description = "Specifies a name to override the default dependency file name.",
            Switch = "-MF ",
            IncludeInCommandLine = false)]
        [ResolvePath()]
        
        public string DependencyFile { get; set; }

        [PropertyPage(
            Category = "Preprocessor",
            DisplayName = "Use System Headers For Dependencies",
            Description = "Don't ignore system headers when calculating dependencies.",
            Switch = "-MD",
            ReverseSwitch = "-MMD")]
        public bool SystemHeaderDeps { get; set; }
        #endregion

        #region ToolTask Overrides
        // ToLower() is affected by localization.
        // Be VERY careful when adding static strings to the dictionary, since lookup is also done with ToLower.
        static Dictionary<string, PropertyInfo> AllProps = typeof(Clang).GetProperties(BindingFlags.DeclaredOnly | BindingFlags.Public | BindingFlags.Instance).ToDictionary(x => x.Name.ToLower());

        protected override string GenerateFullPathToTool()
        {
            return GetClangExe();
        }

        protected override string ToolName
        {
            get { return "clang.exe"; }
        }

        private string ReplaceOptions(string commandLine, ITaskItem input)
        {
            Match subst = Regex.Match(commandLine, @"\[\w+\]", RegexOptions.IgnoreCase);

            while (subst.Success)
            {
                string autoSubst = subst.Value.Substring(1, subst.Value.Length - 2);
                string substStr = "";

                LogMessage(MessageImportance.Low, "Replace value: {0}", autoSubst);

                PropertyInfo pInfo;
                if (AllProps.TryGetValue(autoSubst.ToLower(), out pInfo))
                {
                    ResolvePathAttribute pathAttr = (ResolvePathAttribute)Attribute.GetCustomAttribute(pInfo, typeof(ResolvePathAttribute));
                    PropertyPageAttribute ppAttr = (PropertyPageAttribute)Attribute.GetCustomAttribute(pInfo, typeof(PropertyPageAttribute));
                    string propSwitch = ppAttr.Switch;
                    object value = pInfo.GetValue(this);                        
                    string propVal = GetSpecial(autoSubst, value, input);

                    if (propVal != null && propVal != "")
                    {
                        if (propSwitch != null && propSwitch != "")
                        {
                            substStr += propSwitch;
                        }
                        if (pathAttr != null)
                        {
                            try
                            {
                                substStr += GetFullPath(propVal);
                            }
                            catch (Exception)
                            {
                                LogWarning(string.Format("Unable to resolve path {0} for property: {1}", value.ToString(), pInfo.Name));
                            }
                        }
                        else
                        {
                            substStr += propVal;
                        }
                    }
                }
                else
                {
                    Log.LogError("Only [Input] [AllOptions] [AdditionalOptions] and task properties are acceptped substitutions for command line arguments; Unknown expansion: " + autoSubst);
                    return null;
                }

                commandLine = commandLine.Replace(subst.Value, substStr);
                subst = subst.NextMatch();
            }

            LogMessage(MessageImportance.Low, "Commandline: {0}", commandLine);

            // NOTE: See GetFullPath about escaping quotes.
            return commandLine;
        }

        protected override string GenerateCommandLineCommands()
        {
            return GenerateCommandLineCommands(CommandLineTemplate);
        }

        protected string GenerateCommandLineCommands(string template)

        {
            string commandToRun = template;
            Match subst = Regex.Match(commandToRun, @"\[alloptions\]", RegexOptions.IgnoreCase);

            if (subst.Success)
            {
                string autoSubst = subst.Value.Substring(1, subst.Value.Length - 2);
                string substStr = "";

                LogMessage(MessageImportance.Low, "Replacing all options");
                foreach (PropertyInfo pInfo in AllProps.Values)
                {
                    PropertyPageAttribute ppAttr = (PropertyPageAttribute)Attribute.GetCustomAttribute(pInfo, typeof(PropertyPageAttribute));
                    EnumeratedValueAttribute enumAttr = (EnumeratedValueAttribute)Attribute.GetCustomAttribute(pInfo, typeof(EnumeratedValueAttribute));
                    ResolvePathAttribute pathAttr = (ResolvePathAttribute)Attribute.GetCustomAttribute(pInfo, typeof(ResolvePathAttribute));

                    if (ppAttr == null)
                    {
                        LogMessage(MessageImportance.Low, "Skipping {0}", pInfo.Name);
                        continue;
                    }

                    if (!ppAttr.IncludeInCommandLine)
                    {
                        LogMessage(MessageImportance.Low, "Excluding {0}", pInfo.Name);
                        continue;
                    }

                    if (enumAttr != null)
                    {
                        FieldInfo fInfo = enumAttr.Enumeration.GetField((string)pInfo.GetValue(this));
                        FieldAttribute fAttr = (FieldAttribute)Attribute.GetCustomAttribute(fInfo, typeof(FieldAttribute));

                        if (fAttr == null || string.IsNullOrEmpty(fAttr.Switch))
                        {
                            continue;
                        }

                        LogMessage(MessageImportance.Low, "Field({0}) switch: {1}", fInfo.Name, fAttr.Switch);
                        substStr += fAttr.Switch + " ";
                    }
                    else
                    {
                        if (pInfo.PropertyType.IsAssignableFrom(typeof(string[])))
                        {
                            string concatStr = ppAttr.Switch;
                            string[] propVal = (string[])pInfo.GetValue(this);

                            LogMessage(MessageImportance.Low, "String array({0}) switch: {1}", pInfo.Name, concatStr);

                            if (propVal != null)
                            {
                                foreach (var item in propVal)
                                {
                                    if (pathAttr != null) // Just awful.
                                    {
                                        try
                                        {
                                            substStr += concatStr + GetFullPath((string)item) + " ";
                                        }
                                        catch (Exception)
                                        {
                                            LogWarning(string.Format("Unable to resolve path {0} for property: {1}", item, pInfo.Name));
                                        }
                                    }
                                    else
                                    {
                                        substStr += concatStr + item + " ";
                                    }
                                    // substStr += string.Join(" ", Array.ConvertAll<string, string>(propVal, new Converter<string, string>(delegate(string x) { return concatStr + " " + x; }))) + " ";
                                }
                            }
                        }
                        else if (pInfo.PropertyType.IsAssignableFrom(typeof(bool)))
                        {
                            object propVal = pInfo.GetValue(this);
                            string cmdStr = propVal.ToString();
                            string cmdSwitch = (bool)propVal ? ppAttr.Switch : ppAttr.ReverseSwitch;

                            if (cmdSwitch != null && cmdSwitch != "")
                            {
                                LogMessage(MessageImportance.Low, "Bool({0}) switch: {1}", pInfo.Name, cmdSwitch);
                                substStr += cmdSwitch + " ";
                            }
                            else if ((bool)propVal)
                            {
                                LogWarning("Boolean is visible, but has no switch: {0}", pInfo.Name);
                            }
                        }
                        else if (pInfo.PropertyType.IsAssignableFrom(typeof(string)))
                        {
                            object propVal = pInfo.GetValue(this);

                            if (propVal != null && (string)propVal != "")
                            {
                                LogMessage(MessageImportance.Low, "String({0}) prop: {1}", pInfo.Name, (string)propVal);
                                if (ppAttr.Switch != null && ppAttr.Switch != "")
                                {
                                    substStr += ppAttr.Switch;
                                }
                                if (pathAttr != null) // Just awful.
                                {
                                    try
                                    {
                                        substStr += GetFullPath((string)propVal) + " ";
                                    }
                                    catch (Exception)
                                    {
                                        LogWarning(string.Format("Unable to resolve path {0} for property: {1}", propVal, pInfo.Name));
                                    }
                                }
                                else
                                {
                                    substStr += (string)propVal + " ";
                                }
                            }
                        }
                    }
                }

                commandToRun = commandToRun.Replace(subst.Value, substStr);
            }

            LogMessage(MessageImportance.Low, "Commandline: {0}", commandToRun);

            // NOTE: See GetFullPath about escaping quotes.
            return commandToRun;
        }

        protected override bool SkipTaskExecution()
        {
            if (Autocomplete)
            {
                return false;
            }

            bool skip = true;

            // Instantiate the writer.
            TLogWriter writer = TLogs;

            if (!Tracker.cachedTlogMaps.ContainsKey(Path.GetFullPath(ReadTLogFile)))
            {
                var deps = ReadTLog(Path.GetFullPath(ReadTLogFile));
                var outs = ReadTLog(Path.GetFullPath(ReadTLogFile.Replace("read", "write")));
                foreach (var dep in deps)
                {
                    Tracker.SetDependencies(dep.Key, dep.Value);
                }
                foreach (var output in outs)
                {
                    Tracker.SetDependencies(output.Value[0], new List<string>() { output.Key }); // Only one output per file
                }
            }

            Outputs = Array.ConvertAll<ITaskItem, ITaskItem>(Input, new Converter<ITaskItem, ITaskItem>(f => 
                { 
                    TaskItem i = new TaskItem(f);
                    i.ItemSpec = GetSpecial("objectfilename", ObjectFileName, i);
                    i.SetMetadata("ObjectFileName", i.ItemSpec);
                    return i; 
                }));

            foreach (ITaskItem item in Input)
            {
                string inputFileName = Path.GetFullPath(item.ItemSpec);
                string objFileName = Path.GetFullPath(GetSpecial("objectfilename", ObjectFileName, item));
                string depFileName = Path.GetFullPath(GetSpecial("dependencyfile", DependencyFile, item));

                if (tracker.OutOfDate(objFileName))
                {
                    skip = false;
                    continue;
                }

                if (!File.Exists(objFileName))
                {
                    tracker.SetUpToDate(objFileName, false);
                    skip = false;
                    continue;
                }

                Dictionary<string, List<string>> cmdMap = ReadTLog(Path.GetFullPath(CommandTLogFile));
                List<string> cmdLine;

                if (cmdMap.TryGetValue(inputFileName, out cmdLine))
                {
                    if (cmdLine.First().Substring(1) == ReplaceOptions(GenerateCommandLineCommands(), item))
                    {
                        // If the command lines match, move on to the next file.
                        continue;
                    }
                    else
                    {
                        // If the commandlines are different, rebuild.
                        tracker.SetUpToDate(objFileName, false);
                        // fallthrough
                    }
                }

                // If we got here, our equivalence checks failed.
                skip = false;
            }

            return skip;
        }

        protected override int ExecuteTool(string pathToTool, string responseFileCommands, string commandLineCommands)
        {
            int retCode = 0;

            if (Autocomplete)
            {
                Outputs = Array.ConvertAll<ITaskItem, ITaskItem>(Input, new Converter<ITaskItem, ITaskItem>(f =>
                {
                    TaskItem i = new TaskItem(f);
                    i.SetMetadata("ObjectFileName", GetSpecial("objectfilename", ObjectFileName, i));
                    i.SetMetadata("AutocompleteCommand", ReplaceOptions(GenerateCommandLineCommands(AutocompleteCommandLineTemplate), f));
                    return i;
                }));
                return 0;
            }
            else
            {
                Outputs = Array.ConvertAll<ITaskItem, ITaskItem>(Input, new Converter<ITaskItem, ITaskItem>(f =>
                {
                    TaskItem i = new TaskItem(f);
                    i.ItemSpec = GetSpecial("objectfilename", ObjectFileName, i);
                    i.SetMetadata("ObjectFileName", i.ItemSpec);
                    return i;
                }));
            }

            List<ClangItem> clangItems = new List<ClangItem>(Input.Length);
            for (int i = 0; i < Input.Length; i++)
            {
                ITaskItem item = Input[i];
                string objFileName = Path.GetFullPath(GetSpecial("objectfilename", ObjectFileName, item));
                string depFileName = Path.GetFullPath(GetSpecial("dependencyfile", DependencyFile, item));

                if (File.Exists(objFileName) && !tracker.OutOfDate(objFileName))
                {
                    continue;
                }

                string commandLine = ReplaceOptions(commandLineCommands, item);
                clangItems.Add(new ClangItem(this, item, objFileName, depFileName, commandLine));
            }

            if ((MaxClangProcesses > 1) || (MaxClangProcesses == -1))
            {
                Parallel.ForEach(clangItems, new ParallelOptions { MaxDegreeOfParallelism = MaxClangProcesses }, (clangItem) =>
                {
                    clangItem.RunClang(pathToTool);
                    lock (this)
                    {
                        clangItem.LogOutput();
                    }
                });
            }
            else
            {
                for(int i=0;i<clangItems.Count; i++)
                {
                    clangItems[i].RunClang(pathToTool);
                    clangItems[i].LogOutput();
                    if (clangItems[i].ExitCode != 0)
                    {
                        //Note: this break is for backward compatibility.  We would previously return on the first file that failed to compile correctly.
                        break;
                    }
                }
            }

            for (int i = 0; i < clangItems.Count; i++)
            {
                ClangItem clangItem = clangItems[i];
                retCode |= clangItem.ExitCode;

                string inputFullPath = Path.GetFullPath(clangItem.Item.ItemSpec);

                ReadTLog(Path.GetFullPath(CommandTLogFile))[inputFullPath] = new List<string>() { clangItem.CommandLine };

                if (clangItem.ExitCode == 0)
                {
                    if (File.Exists(clangItem.DepFileName))
                    {
                        List<string> deps = ReadDependencyFile(clangItem.DepFileName);
                        if (deps != null)
                        {
                            // Should we do anything special if we fail to parse the dependency file?
                            // As it stands now, if we fail the object file will not be up to date, and it will continute to be built.
                            Tracker.SetDependencies(inputFullPath, deps);
                            Tracker.SetUpToDate(clangItem.ObjFileName);
                        }
                        Tracker.SetDependencies(clangItem.ObjFileName, new List<string>() { inputFullPath });
                    }
                }
                else
                {
                    tracker.SetUpToDate(inputFullPath, false); // Probably an invalid object file, if it exists.
                    if ((MaxClangProcesses > 1) || (MaxClangProcesses == -1))
                    {
                        //Note: this return is for backward compatibility.  We would previously return on the first file that failed to compile correctly.
                        return retCode;
                    }
                }
            }
            return retCode;
        }

#endregion

        List<string> ReadDependencyFile(string file)
        {
            StreamReader sr = null;

            if (!File.Exists(file))
            {
                return null;
            }

            List<string> deps = new List<string>();

            try
            {
                sr = new StreamReader(File.Open(file, FileMode.Open));

                Regex matchDep = new Regex(@"((\\\s|\S)+)");
                string curLine = null;
                string sourceFile = null;
                string outputFile = null;

                // First line has the object file, everything before the ':'
                // The first dependency is the source file
                // The rest is a list of header files we depend on. The line ends with " \\\cl\rf"

                while ((curLine = sr.ReadLine()) != null)
                {
                    if(curLine.Contains(@": ")) {
                        outputFile = curLine.Substring(0, curLine.IndexOf(@": "));
                        curLine = curLine.Substring(curLine.IndexOf(@": ") + 1);
                    }

                    // Cull the trailed slash
                    if (curLine[curLine.Length - 1] == '\\')
                    {
                        curLine = curLine.Substring(0, curLine.Length - 2);
                    }

                    Match depMatch = matchDep.Match(curLine);

                    while (depMatch.Success)
                    {                       
                        // Replace escaped spaces
                        string value = depMatch.Groups[0].Value.Replace("\\ ", " ").Replace("/", "\\");

                        if (sourceFile == null)
                        {
                            sourceFile = value;
                            ReadTLog(Path.GetFullPath(ReadTLogFile))[sourceFile] = deps;
                            if (outputFile == null)
                            {
                                LogWarning("Output file not found in dependency file ({0})", file);
                            }
                            else
                            {
                                ReadTLog(Path.GetFullPath(ReadTLogFile.Replace("read", "write")))[sourceFile] = new List<string>() { outputFile, file };
                            }
                        }
                        else
                        {
                            deps.Add(value);
                        }

                        depMatch = depMatch.NextMatch();
                    }
                }
            }
            catch (Exception e)
            {
                LogWarning("Caught exception reading dependency file: " + e.ToString());
            }

            if (sr != null)
            {
                sr.Close();
            }

            return deps;
        }

        Dictionary<string, List<string>> ReadTLog(string file)
        {
            if (Tracker.cachedTlogMaps.ContainsKey(file))
            {
                return Tracker.cachedTlogMaps[file];
            }

            Dictionary<string, List<string>> retMap = new Dictionary<string, List<string>>(StringComparer.OrdinalIgnoreCase);
            StreamReader sr = null;

            if (!File.Exists(file))
            {
                Tracker.cachedTlogMaps[file] = retMap;
                return retMap;
            }

            try
            {
                sr = new StreamReader(File.Open(file, FileMode.Open));
                string curLine = null;
                string keyVal = null;

                while ((curLine = sr.ReadLine()) != null)
                {
                    if (curLine[0] == '^')
                    {
                        keyVal = curLine.Substring(1);
                        retMap.Add(keyVal, new List<string>());
                    }
                    else
                    {
                        if (keyVal == null)
                        {
                            // We got ourselves a malformed tlog. Throw it out.
                            LogWarning("TLog file is malformed.");
                            retMap = new Dictionary<string, List<string>>(StringComparer.OrdinalIgnoreCase);
                            break;
                        }
                        retMap[keyVal].Add(curLine);
                    }
                }
            }
            catch (Exception e)
            {
                LogWarning("Caught exception reading TLog: {0}", e.ToString());
            }

            if (sr != null)
            {
                sr.Close();
            }

            Tracker.cachedTlogMaps[file] = retMap;

            return retMap;
        }
    }
}
