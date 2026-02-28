//******************************************************************************
//
// Copyright (c) 2016 Microsoft Corporation. All rights reserved.
//
// This code is licensed under the MIT License (MIT).
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//******************************************************************************
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2015 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//

#import <Foundation/Foundation.h>
#import <TestFramework.h>
#import "TestUtils.h"

#import <array>
#import <windows.h>

NSString* const kURLTestParsingTestsKey = @"ParsingTests";

NSString* const kURLTestTitleKey = @"In-Title";
NSString* const kURLTestUrlKey = @"In-Url";
NSString* const kURLTestBaseKey = @"In-Base";
NSString* const kURLTestURLCreatorKey = @"In-URLCreator";
NSString* const kURLTestPathComponentKey = @"In-PathComponent";
NSString* const kURLTestPathExtensionKey = @"In-PathExtension";

NSString* const kURLTestCFResultsKey = @"Out-CFResults";
NSString* const kURLTestNSResultsKey = @"Out-NSResults";

NSString* const kNSURLWithStringCreator = @"NSURLWithString";
NSString* const kCFURLCreateWithStringCreator = @"CFURLCreateWithString";
NSString* const kCFURLCreateWithBytesCreator = @"CFURLCreateWithBytes";
NSString* const kCFURLCreateAbsoluteURLWithBytesCreator = @"CFURLCreateAbsoluteURLWithBytes";

NSString* const kNullURLString = @"<null url>";
NSString* const kNullString = @"<null>";

static std::string gBaseTemporaryDirectoryPath;
static std::string gBaseCurrentWorkingDirectoryPath;

static unsigned int gRelativeOffsetFromBaseCurrentWorkingDirectory = 0;

static std::string gFileExistsName;
static std::string gFileDoesNotExistName;
static std::string gDirectoryExistsName;
static std::string gDirectoryDoesNotExistName;
static std::string gFileExistsPath;
static std::string gFileDoesNotExistPath;
static std::string gDirectoryExistsPath;
static std::string gDirectoryDoesNotExistPath;

/// Reads the test data plist file and returns the list of objects
static NSArray* getTestData() {
    NSString* testFilePath = [testBundle() pathForResource:@"NSURLTestData" ofType:@"plist"];
    NSData* data = [NSData dataWithContentsOfFile:testFilePath];
    NSError* error = nil;
    id testRoot =
        [NSPropertyListSerialization propertyListWithData:data options:static_cast<NSPropertyListReadOptions>(0) format:nullptr error:&error];

    // WINOBJC: Change to macros to remove LoggingNative
    if (!testRoot || error) {
        EXPECT_NE(nil, testRoot);
        EXPECT_EQ(nil, error);
        return nil;
    }

    NSArray* parsingTests = testRoot[kURLTestParsingTestsKey];
    if (!parsingTests || error) {
        // WINOBJC: Change to macros to remove LoggingNative
        EXPECT_NE(nil, parsingTests);
        EXPECT_EQ(nil, error);
        return nil;
    }
    return parsingTests;
}

static boolean setup_test_paths() {
    static dispatch_once_t predicate;
    dispatch_once(&predicate, ^{
        // MAXPATHLEN is platform specific; this is the lowest common denominator for darwin and most linuxes;
        std::array<char, 1024> buf;
        _getcwd(buf.data(), buf.size());

        // WINOBJC: replace backslashes with forward slashes here
        std::string currentDir(buf.data());
        std::replace(currentDir.begin(), currentDir.end(), '\\', '/');
        gBaseCurrentWorkingDirectoryPath = currentDir.data();

        // WINOBJC: test environment is different
        // gBaseTemporaryDirectoryPath = [NSTemporaryDirectory() UTF8String];
        gBaseTemporaryDirectoryPath = gBaseCurrentWorkingDirectoryPath + "/tmp/";

        gFileExistsName = std::string("TestCFURL_file_exists") + std::string([[NSProcessInfo processInfo].globallyUniqueString UTF8String]);
        gFileDoesNotExistName = "TestCFURL_file_does_not_exist";
        gDirectoryExistsName =
            std::string("TestCFURL_directory_exists") + std::string([[NSProcessInfo processInfo].globallyUniqueString UTF8String]);
        gDirectoryDoesNotExistName = "TestCFURL_directory_does_not_exist";
        gFileExistsPath = gBaseTemporaryDirectoryPath + gFileExistsName;
        gFileDoesNotExistPath = gBaseTemporaryDirectoryPath + gFileDoesNotExistName;
        gDirectoryExistsPath = gBaseTemporaryDirectoryPath + gDirectoryExistsName;
        gDirectoryDoesNotExistPath = gBaseTemporaryDirectoryPath + gDirectoryDoesNotExistName;

        auto cwd = [NSFileManager defaultManager].currentDirectoryPath;
        NSURL* cwdURL = [NSURL fileURLWithPath:cwd isDirectory:YES];
        // 1 for path separator
        gRelativeOffsetFromBaseCurrentWorkingDirectory = strlen(cwdURL.fileSystemRepresentation) + 1;
    });

// File system functions/constants differ between platforms
#if TARGET_OS_WIN32
    // WINOBJC: create tmp/ first
    if (_mkdir(gBaseTemporaryDirectoryPath.data()) != 0 && errno != EEXIST) {
        return false;
    }
    if (_creat(gFileExistsPath.data(), _S_IREAD | _S_IWRITE) < 0 && errno != EEXIST) {
        return false;
    }
    if (_unlink(gFileDoesNotExistPath.data()) != 0 && errno != ENOENT) {
        return false;
    }
    if (_mkdir(gDirectoryExistsPath.data()) != 0 && errno != EEXIST) {
        return false;
    }
    if (_rmdir(gDirectoryDoesNotExistPath.data()) != 0 && errno != ENOENT) {
        return false;
    }
#else
    if (mkdir(gBaseTemporaryDirectoryPath.data(), S_IRWXU) != 0 && errno != EEXIST) {
        return false;
    }
    if (creat(gFileExistsPath.data(), S_IRWXU) < 0 && errno != EEXIST) {
        return false;
    }
    if (unlink(gFileDoesNotExistPath.data()) != 0 && errno != ENOENT) {
        return false;
    }
    if (mkdir(gDirectoryExistsPath.data(), S_IRWXU) != 0 && errno != EEXIST) {
        return false;
    }
    if (rmdir(gDirectoryDoesNotExistPath.data()) != 0 && errno != ENOENT) {
        return false;
    }
#endif

    return true;
}

TEST(NSURL, FileURLWithPath_relativeToURL) {
    // WINOBJC: test environment is different
    if (!setup_test_paths()) {
        auto error = strerror(errno);
        ASSERT_TRUE_MSG(false,
                        @"Failed to set up test paths: %@!",
                        [[[NSString alloc] initWithBytes:error length:strlen(error) encoding:NSASCIIStringEncoding] autorelease]);
    }

    NSString* homeDirectory = NSHomeDirectory();
    ASSERT_OBJCNE_MSG(nil, homeDirectory, @"Failed to find home directory");
    NSURL* homeURL = [NSURL fileURLWithPath:homeDirectory isDirectory:YES];
    ASSERT_OBJCNE_MSG(nil, homeURL, @"fileURLWithPath:isDirectory: failed");
    ASSERT_OBJCEQ(homeDirectory, homeURL.path);

    // #if os(OSX)
    NSURL* baseURL = [NSURL fileURLWithPath:homeDirectory isDirectory:YES];
    auto relativePath = @"Documents";
    // #elseif os(Linux)
    //     NSURL* baseURL = [NSURL fileURLWithPath:@"/usr" isDirectory:YES];
    //     auto relativePath = @"include";
    // #endif

    // we're telling fileURLWithPath:isDirectory:relativeToURL: Documents is a directory
    NSURL* url1 = [NSURL fileURLWithFileSystemRepresentation:[relativePath UTF8String] isDirectory:YES relativeToURL:baseURL];
    ASSERT_OBJCNE_MSG(nil, url1, @"fileURLWithPath:isDirectory:relativeToURL: failed");

    // WINOBJC: fileURLWithPath:relativeToURL: does not exist in iOS
    // // we're letting fileURLWithPath:relativeToURL: determine Documents is a directory with I/O
    // NSURL* url2 = [NSURL fileURLWithPath:relativePath relativeToURL:baseURL];
    // ASSERT_OBJCNE_MSG(nil, url2, @"fileURLWithPath:relativeToURL: failed");
    // ASSERT_OBJCEQ_MSG(url1, url2, @"\(url1) was not equal to \(url2)");

    // // we're telling fileURLWithPath:relativeToURL: Documents is a directory with a trailing slash
    // NSURL* url3 = [NSURL fileURLWithPath:[relativePath stringByAppendingString:@"/"] relativeToURL:baseURL];
    // ASSERT_OBJCNE_MSG(nil, url3, @"fileURLWithPath:relativeToURL: failed");
    // ASSERT_OBJCEQ_MSG(url1, url3, @"\(url1) was not equal to \(url3)");
}

/// Returns a URL from the given url string and base
static NSURL* URLWithString(NSString* urlString, NSString* baseString) {
    if (baseString) {
        NSURL* baseURL = [NSURL URLWithString:baseString];
        return [NSURL URLWithString:urlString relativeToURL:baseURL];
    } else {
        return [NSURL URLWithString:urlString];
    }
}

static NSDictionary<NSString*, NSString*>* generateResults(NSURL* url, NSString* pathComponent, NSString* pathExtension) {
    auto result = [NSMutableDictionary<NSString*, NSString*> dictionary];
    if (pathComponent) {
        if (auto newURL = [url URLByAppendingPathComponent:pathComponent isDirectory:NO]) {
            result[@"appendingPathComponent-File"] = newURL.relativeString;
            result[@"appendingPathComponent-File-BaseURL"] = newURL.baseURL.relativeString ? newURL.baseURL.relativeString : kNullString;
        } else {
            result[@"appendingPathComponent-File"] = kNullString;
            result[@"appendingPathComponent-File-BaseURL"] = kNullString;
        }

        if (auto newURL = [url URLByAppendingPathComponent:pathComponent isDirectory:YES]) {
            result[@"appendingPathComponent-Directory"] = newURL.relativeString;
            result[@"appendingPathComponent-Directory-BaseURL"] =
                newURL.baseURL.relativeString ? newURL.baseURL.relativeString : kNullString;
        } else {
            result[@"appendingPathComponent-Directory"] = kNullString;
            result[@"appendingPathComponent-Directory-BaseURL"] = kNullString;
        }
    } else if (pathExtension) {
        if (auto newURL = [url URLByAppendingPathExtension:pathExtension]) {
            result[@"appendingPathExtension"] = newURL.relativeString;
            result[@"appendingPathExtension-BaseURL"] = newURL.baseURL.relativeString ? newURL.baseURL.relativeString : kNullString;
        } else {
            result[@"appendingPathExtension"] = kNullString;
            result[@"appendingPathExtension-BaseURL"] = kNullString;
        }
    } else {
        result[@"relativeString"] = url.relativeString;
        result[@"baseURLString"] = url.baseURL.relativeString ? url.baseURL.relativeString : kNullString;
        result[@"absoluteString"] = url.absoluteString;
        result[@"absoluteURLString"] = url.absoluteURL.relativeString ? url.absoluteURL.relativeString : kNullString;
        result[@"scheme"] = url.scheme ? url.scheme : kNullString;
        result[@"resourceSpecifier"] = url.resourceSpecifier ? url.resourceSpecifier : kNullString;
        result[@"host"] = url.host ? url.host : kNullString;
        // Temporarily disabled because we're only checking string results
        // result[@"port"] = url.port ? url.port : kNullString
        result[@"user"] = url.user ? url.user : kNullString;
        result[@"password"] = url.password ? url.password : kNullString;
        result[@"path"] = url.path ? url.path : kNullString;
        result[@"query"] = url.query ? url.query : kNullString;
        result[@"fragment"] = url.fragment ? url.fragment : kNullString;
        result[@"parameterString"] = url.parameterString ? url.parameterString : kNullString;
        result[@"relativePath"] = url.relativePath ? url.relativePath : kNullString;
        result[@"isFileURL"] = url.fileURL ? @"YES" : @"NO";
        // Not yet implemented
        // result[@"standardizedURL"] = url.standardizedURL?.relativeString ? .relativeString : kNullString

        // Temporarily disabled because we're only checking string results
        // result[@"pathComponents"] = url.pathComponents ? url.pathComponents : kNullString
        result[@"lastPathComponent"] = url.lastPathComponent ? url.lastPathComponent : kNullString;
        result[@"pathExtension"] = url.pathExtension ? url.pathExtension : kNullString;
        result[@"deletingLastPathComponent"] =
            url.URLByDeletingLastPathComponent.relativeString ? url.URLByDeletingLastPathComponent.relativeString : kNullString;
        result[@"deletingLastPathExtension"] =
            url.URLByDeletingPathExtension.relativeString ? url.URLByDeletingPathExtension.relativeString : kNullString;
    }
    return result;
}

static std::pair<BOOL, NSArray*> compareResults(NSURL* url,
                                                NSDictionary<NSString*, id>* expected,
                                                NSDictionary<NSString*, NSString*>* got) {
    auto differences = [NSMutableArray<NSString*> array];
    for (NSString* key in expected) {
        // Skip non-string expected results
        if ([@[ @"port", @"standardizedURL", @"pathComponents" ] containsObject:key]) {
            continue;
        }

        id obj = [expected objectForKey:key];
        if (auto stringObj = ([obj isKindOfClass:[NSString class]] ? (NSString*)obj : nil)) {
            if (![stringObj isEqual:got[key]]) {
                [differences addObject:[NSString stringWithFormat:@" %@  Expected = '%@',  Got = '%@'", key, stringObj, got[key]]];
            }
        }
    }
    for (NSString* key in got) {
        if (expected[key] == nil) {
            id obj = got[key];
            [differences addObject:[NSString stringWithFormat:@" %@  Expected = 'nil',  Got = '%@'", key, obj]];
        }
    }
    if (differences.count > 0) {
        // WINOBJC: not sure what the intended comparator is here, but it shouldn't matter much as it's only to make failures nicer to read
        // [differences sort];
        [differences insertObject:[NSString stringWithFormat:@" url: '%@", url] atIndex:0];
        return { NO, differences };
    } else {
        return {
            YES, @[]
        };
    }
}

TEST(NSURL, URLStrings) {
    for (NSDictionary<NSString*, id>* testDict in getTestData()) {
        NSString* title = (NSString*)testDict[kURLTestTitleKey];
        NSString* inURL = (NSString*)testDict[kURLTestUrlKey];
        NSString* inBase = (NSString*)testDict[kURLTestBaseKey];
        NSString* inPathComponent = (NSString*)testDict[kURLTestPathComponentKey];
        NSString* inPathExtension = (NSString*)testDict[kURLTestPathExtensionKey];
        id expectedCFResults = testDict[kURLTestCFResultsKey];
        id expectedNSResult = testDict[kURLTestNSResultsKey];
        NSURL* url = nil;

        NSString* creator = (NSString*)testDict[kURLTestURLCreatorKey];
        if ([creator isEqualToString:kNSURLWithStringCreator]) {
            url = URLWithString(inURL, inBase);
        } else if ([creator isEqualToString:kCFURLCreateWithStringCreator] || [creator isEqualToString:kCFURLCreateWithBytesCreator] ||
                   [creator isEqualToString:kCFURLCreateAbsoluteURLWithBytesCreator]) {
            // TODO: Not supported right now
            continue;
        } else {
            ASSERT_TRUE(false);
        }
        if (url) {
            // TODO: NSURL.standardizedURL isn't implemented yet.
            NSMutableDictionary<NSString*, id>* modifiedExpectedNSResult = nil;
            if ([expectedNSResult isKindOfClass:[NSDictionary class]]) {
                modifiedExpectedNSResult = [static_cast<NSDictionary<NSString*, id>*>(expectedNSResult) mutableCopy];
                modifiedExpectedNSResult[@"standardizedURL"] = nil;
            }
            if ([title isEqualToString:@"NSURLWithString-parse-ambiguous-url-001"]) {
                // TODO: Fix this test
            } else {
                auto results = generateResults(url, inPathComponent, inPathExtension);
                std::pair<BOOL, NSArray*> compare = compareResults(url, modifiedExpectedNSResult, results);
                BOOL isEqual = compare.first;
                NSArray* differences = compare.second;
                ASSERT_TRUE_MSG(isEqual, @"%@: %@", title, differences);
            }
        } else {
            ASSERT_OBJCEQ(([expectedCFResults isKindOfClass:[NSString class]] ? (NSString*)expectedCFResults : nil), kNullURLString);
            ASSERT_OBJCEQ(([expectedNSResult isKindOfClass:[NSString class]] ? (NSString*)expectedNSResult : nil), kNullURLString);
        }
    }
}

TEST(NSURL, Sandbox) {
    NSURL* url = [NSURL URLWithString:@".g" relativeToURL:[NSURL URLWithString:@"http://a/b/c/d;p?q"]];
    ASSERT_OBJCEQ(@"", url.pathExtension);
}

TEST(NSURL, FileURLWithPath) {
    if (!setup_test_paths()) {
        auto error = strerror(errno);
        ASSERT_TRUE_MSG(false,
                        @"Failed to set up test paths: %@!",
                        [[[NSString alloc] initWithBytes:error length:strlen(error) encoding:NSASCIIStringEncoding] autorelease]);
    }

    // test with file that exists
    NSString* path = [NSString stringWithCString:gFileExistsPath.data() encoding:NSUTF8StringEncoding];
    NSURL* url = [NSURL fileURLWithPath:path];
    ASSERT_FALSE_MSG(CFURLHasDirectoryPath(static_cast<CFURLRef>(url)), @"did not expect URL with directory path: \(url)");
    ASSERT_OBJCEQ_MSG(path, url.path, @"path from file path URL is wrong");

    // test with file that doesn't exist
    path = [NSString stringWithCString:gFileDoesNotExistPath.data() encoding:NSUTF8StringEncoding];
    url = [NSURL fileURLWithPath:path];
    ASSERT_FALSE_MSG(CFURLHasDirectoryPath(static_cast<CFURLRef>(url)), @"did not expect URL with directory path: \(url)");
    ASSERT_OBJCEQ_MSG(path, url.path, @"path from file path URL is wrong");

    // test with directory that exists
    path = [NSString stringWithCString:gDirectoryExistsPath.data() encoding:NSUTF8StringEncoding];
    url = [NSURL fileURLWithPath:path];
    ASSERT_TRUE_MSG(CFURLHasDirectoryPath(static_cast<CFURLRef>(url)), @"expected URL with directory path: \(url)");
    ASSERT_OBJCEQ_MSG(path, url.path, @"path from file path URL is wrong");

    // test with directory that doesn't exist
    path = [NSString stringWithCString:gDirectoryDoesNotExistPath.data() encoding:NSUTF8StringEncoding];
    url = [NSURL fileURLWithPath:path];
    ASSERT_FALSE_MSG(CFURLHasDirectoryPath(static_cast<CFURLRef>(url)), @"did not expect URL with directory path: \(url)");
    ASSERT_OBJCEQ_MSG(path, url.path, @"path from file path URL is wrong");

    // test with name relative to current working directory
    path = [NSString stringWithCString:gFileDoesNotExistName.data() encoding:NSUTF8StringEncoding];
    url = [NSURL fileURLWithPath:path];
    ASSERT_FALSE_MSG(CFURLHasDirectoryPath(static_cast<CFURLRef>(url)), @"did not expect URL with directory path: \(url)");
    const char* fileSystemRep = url.fileSystemRepresentation;
    auto actualLength = strlen(fileSystemRep);
    // 1 for path separator
    auto expectedLength = gFileDoesNotExistName.size() + gRelativeOffsetFromBaseCurrentWorkingDirectory;
    ASSERT_TRUE_MSG(actualLength == expectedLength, @"fileSystemRepresentation was too short");
    ASSERT_TRUE_MSG(strncmp(gBaseCurrentWorkingDirectoryPath.data(), fileSystemRep, gBaseCurrentWorkingDirectoryPath.size()) == 0,
                    @"fileSystemRepresentation of base path is wrong");
    auto lengthOfRelativePath = gFileDoesNotExistName.size();
    const char* relativePath = &fileSystemRep[gRelativeOffsetFromBaseCurrentWorkingDirectory];
    ASSERT_TRUE_MSG(strncmp(gFileDoesNotExistName.data(), relativePath, lengthOfRelativePath) == 0,
                    @"fileSystemRepresentation of file path is wrong");
}

TEST(NSURL, FileURLWithPath_isDirectory) {
    if (!setup_test_paths()) {
        auto error = strerror(errno);
        ASSERT_TRUE_MSG(false,
                        @"Failed to set up test paths: %@!",
                        [[[NSString alloc] initWithBytes:error length:strlen(error) encoding:NSASCIIStringEncoding] autorelease]);
    }

    // test with file that exists
    NSString* path = [NSString stringWithCString:gFileExistsPath.data() encoding:NSUTF8StringEncoding];
    NSURL* url = [NSURL fileURLWithPath:path isDirectory:YES];
    ASSERT_TRUE_MSG(CFURLHasDirectoryPath(static_cast<CFURLRef>(url)), @"expected URL with directory path: \(url)");
    url = [NSURL fileURLWithPath:path isDirectory:NO];
    ASSERT_FALSE_MSG(CFURLHasDirectoryPath(static_cast<CFURLRef>(url)), @"did not expect URL with directory path: \(url)");
    ASSERT_OBJCEQ_MSG(path, url.path, @"path from file path URL is wrong");

    // test with file that doesn't exist
    path = [NSString stringWithCString:gFileDoesNotExistPath.data() encoding:NSUTF8StringEncoding];
    url = [NSURL fileURLWithPath:path isDirectory:YES];
    ASSERT_TRUE_MSG(CFURLHasDirectoryPath(static_cast<CFURLRef>(url)), @"expected URL with directory path: \(url)");
    url = [NSURL fileURLWithPath:path isDirectory:NO];
    ASSERT_FALSE_MSG(CFURLHasDirectoryPath(static_cast<CFURLRef>(url)), @"did not expect URL with directory path: \(url)");
    ASSERT_OBJCEQ_MSG(path, url.path, @"path from file path URL is wrong");

    // test with directory that exists
    path = [NSString stringWithCString:gDirectoryExistsPath.data() encoding:NSUTF8StringEncoding];
    url = [NSURL fileURLWithPath:path isDirectory:NO];
    ASSERT_FALSE_MSG(CFURLHasDirectoryPath(static_cast<CFURLRef>(url)), @"did not expect URL with directory path: \(url)");
    url = [NSURL fileURLWithPath:path isDirectory:YES];
    ASSERT_TRUE_MSG(CFURLHasDirectoryPath(static_cast<CFURLRef>(url)), @"expected URL with directory path: \(url)");
    ASSERT_OBJCEQ_MSG(path, url.path, @"path from file path URL is wrong");

    // test with directory that doesn't exist
    path = [NSString stringWithCString:gDirectoryDoesNotExistPath.data() encoding:NSUTF8StringEncoding];
    url = [NSURL fileURLWithPath:path isDirectory:NO];
    ASSERT_FALSE_MSG(CFURLHasDirectoryPath(static_cast<CFURLRef>(url)), @"did not expect URL with directory path: \(url)");
    url = [NSURL fileURLWithPath:path isDirectory:YES];
    ASSERT_TRUE_MSG(CFURLHasDirectoryPath(static_cast<CFURLRef>(url)), @"expected URL with directory path: \(url)");
    ASSERT_OBJCEQ_MSG(path, url.path, @"path from file path URL is wrong");

    // test with name relative to current working directory
    path = [NSString stringWithCString:gFileDoesNotExistName.data() encoding:NSUTF8StringEncoding];
    url = [NSURL fileURLWithPath:path isDirectory:NO];
    ASSERT_FALSE_MSG(CFURLHasDirectoryPath(static_cast<CFURLRef>(url)), @"did not expect URL with directory path: \(url)");
    url = [NSURL fileURLWithPath:path isDirectory:YES];
    ASSERT_TRUE_MSG(CFURLHasDirectoryPath(static_cast<CFURLRef>(url)), @"expected URL with directory path: \(url)");
    auto fileSystemRep = url.fileSystemRepresentation;
    auto actualLength = strlen(fileSystemRep);
    // 1 for path separator
    auto expectedLength = gFileDoesNotExistName.size() + gRelativeOffsetFromBaseCurrentWorkingDirectory;
    ASSERT_TRUE_MSG(actualLength == expectedLength, @"fileSystemRepresentation was too short");
    ASSERT_TRUE_MSG(strncmp(gBaseCurrentWorkingDirectoryPath.data(), fileSystemRep, gBaseCurrentWorkingDirectoryPath.size()) == 0,
                    @"fileSystemRepresentation of base path is wrong");
    auto lengthOfRelativePath = gFileDoesNotExistName.size();
    const char* relativePath = &fileSystemRep[gRelativeOffsetFromBaseCurrentWorkingDirectory];
    ASSERT_TRUE_MSG(strncmp(gFileDoesNotExistName.data(), relativePath, lengthOfRelativePath) == 0,
                    @"fileSystemRepresentation of file path is wrong");
}

TEST(NSURL, URLByResolvingSymlinksInPath) {
    NSArray* files = @[ @"/tmp/ABC/test_URLByResolvingSymlinksInPath" ];

    ASSERT_TRUE_MSG(ensureFiles(files), @"Could create files for testing.");

    // tmp is special because it is symlinked to /private/tmp and this /private prefix should be dropped,
    // so tmp is tmp. On Linux tmp is not symlinked so it would be the same.
    {
        NSURL* url = [NSURL fileURLWithPath:@"/.//tmp/ABC/.."];
        auto result = [url URLByResolvingSymlinksInPath].absoluteString;
        ASSERT_OBJCEQ_MSG(result,
                          @"file:///tmp/",
                          @"URLByResolvingSymlinksInPath removes extraneous path components and resolve symlinks.");
    }

    {
        NSURL* url = [NSURL fileURLWithPath:@"~"];
        ASSERT_OBJCEQ(url, [url copy]);
        auto result = [url URLByResolvingSymlinksInPath].absoluteString;

// Absolute paths on OSX naturally begin with '/', not so on Windows, which begins with a drive.
// An extra '/' is needed on Windows to match CF behavior
#if TARGET_OS_WIN32
        auto expected =
            [[@"file:///" stringByAppendingString:[NSFileManager defaultManager].currentDirectoryPath] stringByAppendingString:@"/~"];
#else
        auto expected =
            [[@"file://" stringByAppendingString:[NSFileManager defaultManager].currentDirectoryPath] stringByAppendingString:@"/~"];
#endif
        ASSERT_OBJCEQ_MSG(result, expected, @"URLByResolvingSymlinksInPath resolves relative paths using current working directory.");
    }

    {
        NSURL* url = [NSURL fileURLWithPath:@"anysite.com/search"];
        auto result = [url URLByResolvingSymlinksInPath].absoluteString;

// Absolute paths on OSX naturally begin with '/', not so on Windows, which begins with a drive.
// An extra '/' is needed on Windows to match CF behavior
#if TARGET_OS_WIN32
        auto expected = [[@"file:///" stringByAppendingString:[NSFileManager defaultManager].currentDirectoryPath]
            stringByAppendingString:@"/anysite.com/search"];
#else
        auto expected = [[@"file://" stringByAppendingString:[NSFileManager defaultManager].currentDirectoryPath]
            stringByAppendingString:@"/anysite.com/search"];
#endif
        ASSERT_OBJCEQ(result, expected);
    }

    // tmp is symlinked on OS X only
    // #if os(OSX)
    // {
    //     NSURL* url = [NSURL fileURLWithPath:@"/tmp/.."];
    //     auto result = [url URLByResolvingSymlinksInPath].absoluteString;
    //     ASSERT_OBJCEQ(result, @"file:///private/");
    // }
    // #endif

    {
        NSURL* url = [NSURL fileURLWithPath:@"/tmp/ABC/test_URLByResolvingSymlinksInPath"];
        auto result = [url URLByResolvingSymlinksInPath].absoluteString;
        ASSERT_OBJCEQ_MSG(result,
                          @"file:///tmp/ABC/test_URLByResolvingSymlinksInPath",
                          @"URLByResolvingSymlinksInPath appends trailing slash for existing directories only");
    }

    {
        NSURL* url = [NSURL fileURLWithPath:@"/tmp/ABC/.."];
        auto result = [url URLByResolvingSymlinksInPath].absoluteString;
        ASSERT_OBJCEQ(result, @"file:///tmp/");
    }
}

TEST(NSURL, String) {
    for (NSDictionary<NSString*, id>* testDict in getTestData()) {
        NSString* unencodedString = (NSString*)testDict[kURLTestUrlKey];
        NSString* expectedString = [[NSString stringWithString:unencodedString]
            stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLPathAllowedCharacterSet]];
        NSURLComponents* components = [NSURLComponents componentsWithString:expectedString];
        if (!components) {
            continue;
        }
        ASSERT_OBJCEQ_MSG(components.string, expectedString, @"should be the expected string (\(components.string!) != \(expectedString))");
    }
}

TEST(NSURL, PortSetter) {
    auto urlString = @"http://myhost.mydomain.com";
    NSNumber* port = @8080;
    auto expectedString = @"http://myhost.mydomain.com:8080";
    NSURLComponents* url = [NSURLComponents componentsWithString:urlString];
    url.port = port;
    auto receivedString = url.string;
    ASSERT_OBJCEQ_MSG(receivedString, expectedString, @"expected \(expectedString) but received \(receivedString)");
}
