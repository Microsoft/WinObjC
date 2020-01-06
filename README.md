# Welcome to the Windows Bridge for iOS Project
The Windows Bridge for iOS (also referred to as WinObjC) is a Microsoft open-source project that provides an Objective-C development environment for Visual Studio and support for iOS APIs. The bridge allows you to create Universal Windows Platform (UWP) apps that will run on many Windows devices by re-using your Objective-C code and iOS APIs alongside Windows 10 features like Cortana and Windows Notifications.

[license-badge]: https://img.shields.io/github/license/microsoft/winobjc.svg?style=flat-square
[license-link]: https://github.com/Microsoft/WinObjC/blob/master/license.txt
[![license][license-badge]][license-link]

[develop-build-badge]:        https://img.shields.io/vso/build/winobjc/03960378-fe55-4577-a8cc-1a874f7cf008/109.svg?style=flat-square
[master-build-badge]:        https://img.shields.io/badge/build-passing-brightgreen.svg?style=flat-square
[github-rel]:                 https://github.com/Microsoft/WinObjC/releases/latest
[github-rel-badge]:           https://img.shields.io/github/tag/microsoft/winobjc.svg?style=flat-square&label=release&colorB=007ec6
[choco]:                      https://chocolatey.org/packages/winobjc-tools
[choco-badge]:                https://img.shields.io/chocolatey/v/winobjc-tools.svg?style=flat-square&colorB=007ec6                 
[choco-badge-pre]:            https://img.shields.io/chocolatey/vpre/winobjc-tools.svg?style=flat-square
[nuget-frmwrk]:               https://www.nuget.org/packages/WinObjC.Frameworks
[nuget-frmwrk-badge]:         https://img.shields.io/nuget/v/WinObjC.Frameworks.svg?style=flat-square&colorB=007ec6
[nuget-frmwrk-badge-pre]:     https://img.shields.io/nuget/vpre/WinObjC.Frameworks.svg?style=flat-square
[nuget-lang]:                 https://www.nuget.org/packages/WinObjC.Language
[nuget-lang-badge]:           https://img.shields.io/nuget/v/WinObjC.Language.svg?style=flat-square&colorB=007ec6
[nuget-lang-badge-pre]:       https://img.shields.io/nuget/vpre/WinObjC.Language.svg?style=flat-square

## Build and Release Status
|                      |           Stable (master)                        |            Pre-release (develop)          |
| -------------------: | :----------------------------------------------: | :---------------------------------------: |
|           **Build**  |       ![VSTS][master-build-badge]                |       ![VSTS][develop-build-badge]        |
|  **GitHub Release**  |[![Github Release][github-rel-badge]][github-rel] |               -                           |
|    **winobjc-tools** |     [![Tools][choco-badge]][choco]               |   [![Tools][choco-badge-pre]][choco]      |
| **WinObjC.Language** |[![Language][nuget-lang-badge]][nuget-lang]       |[![Language][nuget-lang-badge-pre]][nuget-lang]   |
|**WinObjC.Frameworks**|[![Frameworks][nuget-frmwrk-badge]][nuget-frmwrk] |[![Frameworks][nuget-frmwrk-badge-pre]][nuget-frmwrk]|

## Download and Installation
To use the bridge you'll need:
- **Windows 10**, build 10586 or higher. Validate your version number [here](http://windows.microsoft.com/en-US/windows/which-operating-system).
- **Visual Studio 2017** with Windows developer tools. Visual Studio 2017 Community is available for free [here](https://dev.windows.com/downloads).

  
   Ensure the following individual components are selected during installation. Selecting the Universal Windows Platform development workflow should give most of the below 
   
   **NOTE:** Please also install the **Mobile development with .NET** workflow option (Xamarin Tools) due to a bug in Nugetizer (See [Issue 5026](https://github.com/NuGet/Home/issues/5026))

   <details><summary><b>(Click to Expand)</b></summary><p>

  - Visual Studio Core Editor
  - Nuget Package Manager
  - C# and Visual Basic Roslyn compilers
  - Static analysis tools
  - Visual Studio C++ core features
  - VC++ 2015.3 v140 toolset (x86,x64)
  - VC++ 2017 v141 toolset (x86, x64)
  - Visual C++ compilers and libraries for ARM
  - Visual C++ runtime for UWP
  - Windows 10 SDK (10.0.10240.0)
  - Windows 10 SDK (10.0.10586.0)
  - Windows 10 SDK (10.0.14393.0)
  - MSBuild
  - Windows Universal CRT SDK
  - Standard Library Modules
  - Windows Universal C Runtime
</p></details>

To get started with an existing Xcode Project, you will also need:
- **Chocolatey**, a package manager for windows. See how to install the latest version [here](https://chocolatey.org/)
- **winobjc-tools**, the command line tools for WinObjC. Run the below command from **powershell (Admin)** to get the latest version:
```
choco upgrade winobjc-tools
```
(more information about this command and its options can be found [here](https://chocolatey.org/docs/commands-upgrade). If you want to use develop packages add `--pre` to the command.)

## Getting Started With the Bridge
### Importing your Xcode Project
When using the bridge, the first thing you'll want to do is generate a Visual Studio solution from your Xcode project:

1. Open Windows PowerShell (type **powershell** in the Start Menu to find it) and navigate to your Xcode project directory using the **cd** command. Note: use the directory containing your .workspace or .xcodeproj folder.

  ```
    C:\> cd C:\MyProject
  ```
2. Run the vsimporter tool. This will generate the Visual Studio Solution:

  ```
    C:\MyProject> vsimporter.exe
  ```
3. Open the generated Visual Studio solution with the command:

  ```
    C:\MyProject> MyProject.sln
  ```

For more detailed step by step instructions on how to import a project, see the [Quick Start Tutorial](https://github.com/Microsoft/WinObjC/wiki/Quick-Start-Tutorial) page of the wiki. For vsimporter options and known issues, check the [Using vsimporter](https://github.com/Microsoft/WinObjC/wiki/Using-vsimporter) wiki page.

### Building & Running the Samples
A great way to learn more about the bridge and its features is building and running the samples of the SDK, which contain many code examples. We recommend starting with the **WOCCatalog** sample app, which demonstrates an assortment of iOS and XAML UI controls:

1. Clone the repo.
2. Navigate to the *samples/WOCCatalog* directory of the bridge SDK
3. Double-click on the **WOCCatalog-WinStore10.sln** solution to open it in Visual Studio
4. In Visual Studio, right-click on the **WOCCatalog (Universal Windows)** project
5. Select **Set as StartUp project**
6. Use **Ctrl-F5** to build and run the app

For more detailed step by step instructions, see the [Quick Start Tutorial](https://github.com/Microsoft/WinObjC/wiki/Quick-Start-Tutorial) page of the wiki.

## Resources & Documentation
The following resources will help you get started. For more information, check out:

1. [Wiki](https://github.com/Microsoft/WinObjC/wiki), for documentation and tutorials
2. [Development Roadmap](https://github.com/Microsoft/WinObjC/wiki/Roadmap), detailing our highest priorities
3. [Website on Windows Dev Center](https://dev.windows.com/bridges/ios), for evaluation virtual machines
4. [Quick Start Challenge](https://github.com/Microsoft/WinObjC/wiki/Quick-Start-Tutorial), for a quick hands-on introduction to the bridge
5. [FAQ](https://github.com/Microsoft/WinObjC/wiki/FAQ), with common questions and issues
6. [The iOS Bridge Samples Repo](https://github.com/Microsoft/WinObjC-Samples), for sample apps and code using the bridge

## Contributing
There are many ways to contribute to the Windows Bridge for iOS:
- [Submit bugs & issues](https://github.com/Microsoft/WinObjC/issues) and help us verify fixes as they are checked in.
- Review source code changes.
- Submit a bug fix or feature implementation via [pull request](https://github.com/Microsoft/WinObjC/pulls).
- Follow [@WindowsDev on Twitter](https://twitter.com/windowsdev) and join the discussion using the [#WinObjC hashtag](https://twitter.com/hashtag/WinObjC).
- Engage with other users and developers on [StackOverflow](http://stackoverflow.com/) and tag your questions with [WinObjC](http://stackoverflow.com/questions/tagged/winobjc).

See our [contribution guidance in the wiki](https://github.com/Microsoft/WinObjC/wiki/How-to-Contribute) for more details on how to contribute to the project.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/). For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

## Advanced Installation for Contributors and Ninjas

Additional Visual Studio Components Needed for Contributors:
   1. C# and Visual Basic
   2. Visual Studio SDK
   3. .NET Framework 4.6 targeting pack
   4. C++ Profiling Tools

If you want to build the bridge from source instead, you'll also need to install [Git LFS](https://git-lfs.github.com) before cloning the repo. For more detailed instructions, see the [Building From Source](https://github.com/Microsoft/WinObjC/wiki/Building-From-Source) wiki page.

If you're having trouble downloading & installing the bridge, see the [Known Issues](https://github.com/Microsoft/WinObjC#known-issues) section below and check our [FAQ](https://github.com/Microsoft/WinObjC/wiki/FAQ).

## Privacy
See [Microsoft's privacy statement](https://www.microsoft.com/en-us/privacystatement/default.aspx) for more information.

## Roadmap
For details on our planned features and future direction sort the list of issues by [milestone](https://github.com/Microsoft/WinObjC/milestones) and refer to our [roadmap](https://github.com/Microsoft/WinObjC/wiki/Roadmap).

## Known Issues
- **Do not use the Download ZIP option via the "Clone or download" button at the top of the page.** You will not be able to build the bridge using the resulting .zip file. See ["I'm getting errors after downloading the bridge through the "Download ZIP" button on Github. What should I do?"](https://github.com/Microsoft/WinObjC/wiki/FAQ#im-getting-errors-after-downloading-the-bridge-through-the-download-zip-button-on-github-what-should-i-do) for more information.
