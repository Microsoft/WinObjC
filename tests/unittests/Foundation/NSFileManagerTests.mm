//******************************************************************************
//
// Copyright (c) Microsoft. All rights reserved.
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

#include <sys/types.h>
#include <sys/stat.h>
#include <TestFramework.h>
#include <cstdlib>
#include <time.h>
#include <stdio.h>
#include <errno.h>
#include <Foundation/Foundation.h>
#include <stdlib.h>
#include <windows.h>
#include <Starboard/SmartTypes.h>
#include "TestUtils.h"

TEST(NSFileManager, EnumateDirectoryUsingURL) {
    NSFileManager* manager = [NSFileManager defaultManager];
    NSString* originalPath = [manager currentDirectoryPath];

    // get test startup full path
    wchar_t startUpPath[_MAX_PATH];
    auto fullPath = GetCurrentTestDirectory();
    std::mbstowcs(startUpPath, fullPath.c_str(), _MAX_PATH);

    std::wstring startUpDir(startUpPath);
    ASSERT_TRUE(SetCurrentDirectoryW(startUpDir.c_str()) != 0);

    wchar_t currentDir[_MAX_PATH];
    DWORD ret = GetCurrentDirectoryW(_MAX_PATH, currentDir);
    ASSERT_TRUE(ret > 0 && ret < _MAX_PATH);

    // OSX wchar_t's are twice as wide
    LOG_INFO("Change current dir to:%@",
#if TARGET_OS_WIN32
             [NSString stringWithCharacters:(const unichar*)currentDir length:ret]);
#else
             [NSString stringWithBytes:currentDir length:sizeof(wchar_t) * ret encoding:WCHAR_ENCODING]);
#endif

    // construct target URL using current directory and relative URL
    NSURL* baseURL = [NSURL fileURLWithPath:[manager currentDirectoryPath]];
    NSURL* targetURL = [NSURL URLWithString:@"data/" relativeToURL:baseURL];

    // enumerate target URL
    NSArray* urlContents = [manager contentsOfDirectoryAtURL:targetURL
                                  includingPropertiesForKeys:[NSArray arrayWithObject:NSURLContentModificationDateKey]
                                                     options:(NSDirectoryEnumerationOptions)0
                                                       error:nullptr];

    ASSERT_NE(NSNotFound, [urlContents indexOfObjectPassingTest:^(NSURL* obj, NSUInteger idx, BOOL* stop) {
                  // break file URL into components, get last object of it - which is the file name, and verify name is the expected
                  return [[[obj pathComponents] lastObject] isEqualToString:@"NSFileManagerUT.txt"];
              }]);

    // construct file path for target file and get its attrbutes from windows side
    wchar_t targetFileFullPath[_MAX_PATH];

// wcscpy_s and wcscat_s are MSVC extensions
#if TARGET_OS_WIN32
    ASSERT_TRUE(wcscpy_s(targetFileFullPath, _countof(targetFileFullPath), currentDir) == 0);
    ASSERT_TRUE(wcscat_s(targetFileFullPath, _countof(targetFileFullPath), L"\\data\\NSFileManagerUT.txt") == 0);
#else
    ASSERT_NE(nullptr, wcscpy(targetFileFullPath, currentDir));
    ASSERT_NE(nullptr, wcscat(targetFileFullPath, L"/data/NSFileManagerUT.txt"));
#endif

// _stat and _wstat are MS extensions
#if TARGET_OS_WIN32
    struct _stat fileStatus = { 0 };
    ASSERT_TRUE(::_wstat(targetFileFullPath, &fileStatus) == 0);
#else
    struct stat fileStatus = { 0 };
    char narrowFullPath[_MAX_PATH];
    wcstombs(narrowFullPath, targetFileFullPath, _MAX_PATH);
    ASSERT_TRUE(stat(narrowFullPath, &fileStatus) == 0);
#endif

    // TODO: 7491194: Implement CFURL resourceValue APIs
    // check NSURL resourceValue of NSURLContentModificationDateKey is the same as file modification date
    // NSDate* expectedModificationDate = [NSDate dateWithTimeIntervalSince1970:fileStatus.st_mtime];
    // id value;
    // [targetFileURL getResourceValue:&value forKey:NSURLContentModificationDateKey error:nil];
    // NSDate* actualModificationDate = static_cast<NSDate*>(value);
    // ASSERT_TRUE_MSG(actualModificationDate != nil, "failed to get ModificationDate from %@", targetFileURL);
    // ASSERT_OBJCEQ_MSG(expectedModificationDate, actualModificationDate, "failed to check modification date for %@", targetFileURL);

    ASSERT_TRUE([manager changeCurrentDirectoryPath:originalPath]);
}

TEST(NSFileManager, ChangeDirectory) {
    NSFileManager* manager = [NSFileManager defaultManager];
    NSString* originalPath = [manager currentDirectoryPath];
    NSString* newPath = [originalPath stringByAppendingPathComponent:@"TestCWD"];

    [manager createDirectoryAtPath:newPath withIntermediateDirectories:NO attributes:nullptr error:nullptr];
    ASSERT_TRUE([manager changeCurrentDirectoryPath:newPath]);

    NSString* currentPath = [manager currentDirectoryPath];
    ASSERT_OBJCNE_MSG(originalPath, currentPath, "Expected change in current directory");
    ASSERT_OBJCEQ_MSG(newPath, currentPath, "Expected current directory to change to newPath");

    ASSERT_TRUE([manager changeCurrentDirectoryPath:originalPath]);
    [manager removeItemAtPath:newPath error:nullptr];
}

TEST(NSFileManager, MoveFileViaPath) {
    NSString* srcName = @"NSFileManagerMoveTestFilePath.txt";
    NSString* destName = @"MovedFilePath.txt";

    SCOPE_DELETE_FILE(srcName);
    SCOPE_DELETE_FILE(destName);

    NSString* content = @"The Quick Brown Fox.";
    createFileWithContentAndVerify(srcName, content);

    NSString* srcPath = getPathToFile(srcName);
    NSString* destPath = getPathToFile(destName);

    NSFileManager* manager = [NSFileManager defaultManager];

    NSError* error = nil;
    BOOL status = [manager moveItemAtPath:srcPath toPath:destPath error:&error];
    ASSERT_TRUE(status);
    EXPECT_EQ(nil, error);

    // Verify file exists.
    ASSERT_TRUE([manager fileExistsAtPath:destPath]);
    EXPECT_FALSE([manager fileExistsAtPath:srcPath]);

    // Verify data.
    ASSERT_OBJCEQ([content dataUsingEncoding:NSUTF8StringEncoding], [NSData dataWithContentsOfFile:destPath]);
}

TEST(NSFileManager, MoveFileViaURL) {
    NSString* srcName = @"NSFileManagerMoveTestFileURL.txt";
    NSString* destName = @"MovedFileURL.txt";
    SCOPE_DELETE_FILE(srcName);
    SCOPE_DELETE_FILE(destName);

    NSString* content = @"The Quick Brown Fox.";
    createFileWithContentAndVerify(srcName, content);

    NSURL* srcURL = [NSURL fileURLWithPath:getPathToFile(srcName)];
    NSURL* destURL = [NSURL fileURLWithPath:getPathToFile(destName)];

    NSFileManager* manager = [NSFileManager defaultManager];

    NSError* error = nil;
    BOOL status = [manager moveItemAtURL:srcURL toURL:destURL error:&error];
    ASSERT_TRUE(status);
    EXPECT_EQ(nil, error);

    // Verify file exists.
    ASSERT_TRUE([manager fileExistsAtPath:[destURL path]]);
    EXPECT_FALSE([manager fileExistsAtPath:[srcURL path]]);

    // Verify data.
    ASSERT_OBJCEQ([content dataUsingEncoding:NSUTF8StringEncoding], [NSData dataWithContentsOfURL:destURL]);
}

TEST(NSFileManager, DirectoryWithUTF16Chars) {
    NSString* directoryName = @"oÖo winobjc";
    NSString* testPath = getPathToFile(directoryName);

    EXPECT_TRUE([[NSFileManager defaultManager] createDirectoryAtPath:testPath attributes:nil]);
    EXPECT_TRUE([[NSFileManager defaultManager] fileExistsAtPath:testPath]);
    EXPECT_TRUE([[NSFileManager defaultManager] removeItemAtPath:testPath error:nullptr]);
    EXPECT_FALSE([[NSFileManager defaultManager] fileExistsAtPath:testPath]);
}

TEST(NSFileManager, CopyFileViaURL) {
    NSString* srcName = @"NSFileManagerCopyTestFileURL.txt";
    NSString* destName = @"MovedFileURL.txt";
    SCOPE_DELETE_FILE(srcName);
    SCOPE_DELETE_FILE(destName);

    NSString* content = @"The Quick Brown Fox.";
    createFileWithContentAndVerify(srcName, content);

    NSURL* srcURL = [NSURL fileURLWithPath:getPathToFile(srcName)];
    NSURL* destURL = [NSURL fileURLWithPath:getPathToFile(destName)];

    NSFileManager* manager = [NSFileManager defaultManager];

    NSError* error = nil;
    BOOL status = [manager copyItemAtURL:srcURL toURL:destURL error:&error];
    EXPECT_TRUE(status);
    EXPECT_EQ(nil, error);

    // Verify file exists.
    EXPECT_TRUE([manager fileExistsAtPath:[destURL path]]);
    EXPECT_TRUE([manager fileExistsAtPath:[srcURL path]]);

    // Verify data.
    ASSERT_OBJCEQ([content dataUsingEncoding:NSUTF8StringEncoding], [NSData dataWithContentsOfURL:destURL]);
}

TEST(NSFileManager, GetSetAttributes) {
    NSString* srcName = @"attributestestfile.txt";
    SCOPE_DELETE_FILE(srcName);

    NSString* content = @"The Quick Brown Fox.";
    createFileWithContentAndVerify(srcName, content);
    NSURL* srcURL = [NSURL fileURLWithPath:getPathToFile(srcName)];

    NSDictionary* attributes = @{ NSFileImmutable : @YES };

    NSFileManager* manager = [NSFileManager defaultManager];
    NSError* error = nil;
    EXPECT_TRUE([manager setAttributes:attributes ofItemAtPath:[srcURL path] error:&error]);
    EXPECT_EQ(nil, error);

    error = nil;
    NSDictionary* retrievedAttributes = [manager attributesOfItemAtPath:[srcURL path] error:&error];
    EXPECT_OBJCEQ(attributes[NSFileImmutable], retrievedAttributes[NSFileImmutable]);
    EXPECT_EQ(nil, error);

    NSDictionary* newAttributes = @{ NSFileImmutable : @NO };

    EXPECT_TRUE([manager setAttributes:newAttributes ofItemAtPath:[srcURL path] error:&error]);
    EXPECT_EQ(nil, error);

    error = nil;
    retrievedAttributes = [manager attributesOfItemAtPath:[srcURL path] error:&error];
    EXPECT_OBJCEQ(@NO, retrievedAttributes[NSFileImmutable]);
    EXPECT_EQ(nil, error);
}

// Should never be more than 5 seconds apart from creating the date and creating the file
// If it is then we've bigger problems than attributesOfItemAtPath:
static constexpr double sc_timeThreshold = 5.0;
TEST(NSFileManager, AttributesOfItemAtPath) {
    NSString* srcName = @"NSFileManagerAttributeGetTestFile.txt";
    NSString* content = @"The Quick Brown Fox.";
    NSDate* rightNow = [NSDate date];
    createFileWithContentAndVerify(srcName, content);
    SCOPE_DELETE_FILE(srcName);
    NSURL* srcURL = [NSURL fileURLWithPath:getPathToFile(srcName)];

    NSFileManager* manager = [NSFileManager defaultManager];
    NSError* error = nil;

    NSDictionary* retrievedAttributes = [manager attributesOfItemAtPath:[srcURL path] error:&error];
    EXPECT_OBJCEQ(NSFileTypeRegular, retrievedAttributes[NSFileType]);
    EXPECT_OBJCEQ(@NO, retrievedAttributes[NSFileImmutable]);
    EXPECT_OBJCEQ(@20, retrievedAttributes[NSFileSize]);

    NSDate* modificationDate = retrievedAttributes[NSFileModificationDate];
    EXPECT_NE(nil, modificationDate);
    EXPECT_NEAR([rightNow timeIntervalSince1970], [modificationDate timeIntervalSince1970], 10);

    NSDate* creationDate = retrievedAttributes[NSFileCreationDate];
    EXPECT_NE(nil, creationDate);
    EXPECT_NEAR([rightNow timeIntervalSince1970], [creationDate timeIntervalSince1970], 10);

    EXPECT_EQ(nil, error);
}

TEST(NSFileManager, EnumeratorAtURL) {
    NSString* subFolderName = @"SUBFOLDER";
    NSString* itemName = @"ArBiTraRY_FiLE.txt";

    NSFileManager* manager = [NSFileManager defaultManager];
    [manager createDirectoryAtPath:subFolderName withIntermediateDirectories:NO attributes:nil error:nullptr];
    createFileWithContentAndVerify(itemName, @"The Quick Brown Fox.");
    SCOPE_DELETE_FILE(subFolderName);
    SCOPE_DELETE_FILE(itemName);
    NSString* currentDirectory = [manager currentDirectoryPath];

    NSURL* current = [NSURL fileURLWithPath:currentDirectory];
    NSDirectoryEnumerator* enumerator = [manager enumeratorAtURL:current
                                      includingPropertiesForKeys:nil
                                                         options:NSDirectoryEnumerationSkipsHiddenFiles
                                                    errorHandler:^(NSURL* url, NSError* error) {
                                                        return NO;
                                                    }];

    NSArray* all = [enumerator allObjects];
    EXPECT_TRUE([all containsObject:[NSURL fileURLWithPath:[currentDirectory stringByAppendingPathComponent:subFolderName]]]);
    EXPECT_TRUE([all containsObject:[NSURL fileURLWithPath:[currentDirectory stringByAppendingPathComponent:itemName]]]);
}

TEST(NSFileManager, SubPathsOfDirectoryAtPath) {
    NSString* subFolderName = @"SUBFOLDER";
    NSString* subSubFolderName = @"SUBFOLDER/SUBSUBFOLDER";
    NSFileManager* manager = [NSFileManager defaultManager];
    [manager createDirectoryAtPath:subFolderName withIntermediateDirectories:NO attributes:nil error:nullptr];
    [manager createDirectoryAtPath:subSubFolderName withIntermediateDirectories:NO attributes:nil error:nullptr];
    SCOPE_DELETE_FILE(subFolderName);
    SCOPE_DELETE_FILE(subSubFolderName);

    NSArray* subpaths = [manager subpathsOfDirectoryAtPath:[manager currentDirectoryPath] error:nullptr];

    EXPECT_TRUE([subpaths containsObject:subFolderName]);
    EXPECT_TRUE([subpaths containsObject:subSubFolderName]);

    EXPECT_FALSE([subpaths containsObject:@"."]);
    EXPECT_FALSE([subpaths containsObject:@".."]);
}
