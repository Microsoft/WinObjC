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

#import <Starboard.h>
#import <StubReturn.h>
#import <Foundation/NSFileManager.h>
#import <Foundation/NSError.h>
#import <Foundation/NSString.h>
#import <Foundation/NSMutableArray.h>
#import <Foundation/NSMutableDictionary.h>
#import <Foundation/NSNumber.h>
#import <Foundation/NSDate.h>
#import <Foundation/NSData.h>
#import <Foundation/NSURL.h>
#import <Foundation/NSDirectoryEnumerator.h>
#import <Foundation/NSDictionary.h>
#import <string>
#import <vector>
#import <sys/stat.h>
#import <errno.h>
#import <LoggingNative.h>
#import <CFFoundationInternal.h>
#import <ForFoundationOnly.h>
#import "NSDirectoryEnumeratorInternal.h"
#import <Starboard/SmartTypes.h>

#include <COMIncludes.h>
#import <windows.storage.h>
#import <winrt/Windows.Storage.h>
#include <COMIncludes_End.h>

#import <CppWinRTHelpers.h>
#import <WRLHelpers.h>

static const wchar_t* TAG = L"NSFileManager";

namespace WF = winrt::Windows::Foundation;
namespace WS = winrt::Windows::Storage;

// file attribute keys
NSString* const NSFileType = @"NSFileType";
NSString* const NSFileSize = @"NSFileSize";
NSString* const NSFileModificationDate = @"NSFileModificationDate";
NSString* const NSFileReferenceCount = @"NSFileReferenceCount";
NSString* const NSFileDeviceIdentifier = @"NSFileDeviceIdentifier";
NSString* const NSFileOwnerAccountName = @"NSFileOwnerAccountName";
NSString* const NSFileGroupOwnerAccountName = @"NSFileGroupOwnerAccountName";
NSString* const NSFilePosixPermissions = @"NSFilePosixPermissions";
NSString* const NSFileSystemNumber = @"NSFileSystemNumber";
NSString* const NSFileSystemFileNumber = @"NSFileSystemFileNumber";
NSString* const NSFileExtensionHidden = @"NSFileExtensionHidden";
NSString* const NSFileHFSCreatorCode = @"NSFileHFSCreatorCode";
NSString* const NSFileHFSTypeCode = @"NSFileHFSTypeCode";
NSString* const NSFileImmutable = @"NSFileImmutable";
NSString* const NSFileAppendOnly = @"NSFileAppendOnly";
NSString* const NSFileCreationDate = @"NSFileCreationDate";
NSString* const NSFileOwnerAccountID = @"NSFileOwnerAccountID";
NSString* const NSFileGroupOwnerAccountID = @"NSFileGroupOwnerAccountID";
NSString* const NSFileBusy = @"NSFileBusy";

NSString* const NSFileProtectionKey = @"NSFileProtectionKey";

// NSFileType Attribute Values
NSString* const NSFileTypeDirectory = @"NSFileTypeDirectory";
NSString* const NSFileTypeRegular = @"NSFileTypeRegular";
NSString* const NSFileTypeSymbolicLink = @"NSFileTypeSymbolicLink";
NSString* const NSFileTypeSocket = @"NSFileTypeSocket";
NSString* const NSFileTypeCharacterSpecial = @"NSFileTypeCharacterSpecial";
NSString* const NSFileTypeBlockSpecial = @"NSFileTypeBlockSpecial";
NSString* const NSFileTypeUnknown = @"NSFileTypeUnknown";

// File-System attribute Keys
NSString* const NSFileSystemSize = @"NSFileSystemSize";
NSString* const NSFileSystemFreeSize = @"NSFileSystemFreeSize";
NSString* const NSFileSystemNodes = @"NSFileSystemNodes";
NSString* const NSFileSystemFreeNodes = @"NSFileSystemFreeNodes";

// File Protection Values
NSString* const NSFileProtectionNone = @"NSFileProtectionNone";
NSString* const NSFileProtectionComplete = @"NSFileProtectionComplete";
NSString* const NSFileProtectionCompleteUnlessOpen = @"NSFileProtectionCompleteUnlessOpen";
NSString* const NSFileProtectionCompleteUntilFirstUserAuthentication = @"NSFileProtectionCompleteUntilFirstUserAuthentication";

static const winrt::hstring sc_fileSizeKey = L"System.Size";
static const winrt::hstring sc_fileAttributesKey = L"System.FileAttributes";
static const winrt::hstring sc_fileModificationDateKey = L"System.DateModified";
static const winrt::hstring sc_fileCreationDateKey = L"System.DateCreated";

// Conversion math from https://msdn.microsoft.com/en-us/library/ms724228
static DateTime __NSDateToSystemTime(NSDate* date) {
    return { (int64_t)([date timeIntervalSince1970] * 10000000LL) + 116444736000000000LL };
}

static NSDate* __SystemTimeToNSDate(DateTime systemTime) {
    return [NSDate dateWithTimeIntervalSince1970:((systemTime.UniversalTime - 116444736000000000LL) / 10000000LL)];
}

@implementation NSFileManager

// Creating a File Manager

/**
 @Status Interoperable
*/
+ (NSFileManager*)defaultManager {
    static id defaultManager = [[self alloc] init];

    return defaultManager;
}

// Locating System Directories

/**
 @Status Caveat
 @Notes Ignores appropriateForURL, create, and error. Calls URLsForDirectory and returns first result.
*/
- (NSURL*)URLForDirectory:(NSSearchPathDirectory)directory
                 inDomain:(NSSearchPathDomainMask)domains
        appropriateForURL:(NSURL*)forURL
                   create:(BOOL)create
                    error:(NSError**)error {
    NSArray* urls = [self URLsForDirectory:directory inDomains:domains];
    if ([urls count] > 0) {
        return [urls objectAtIndex:0];
    }

    return nil;
}

/**
 @Status Interoperable
*/
- (NSArray*)URLsForDirectory:(NSSearchPathDirectory)directory inDomains:(NSSearchPathDomainMask)domains {
    id paths = NSSearchPathForDirectoriesInDomains(directory, domains, YES);

    int count = [paths count];

    id ret = [NSMutableArray array];

    for (int i = 0; i < count; i++) {
        id curObj = [paths objectAtIndex:i];

        id newUrl = [NSURL fileURLWithPath:curObj];

        [ret addObject:newUrl];
    }

    return ret;
}

// Locating Application Group Container Directories

/**
 @Status Caveat
 @Notes Container is contained within a Publisher Cache Folder, so a user could erase the data
*/
- (NSURL*)containerURLForSecurityApplicationGroupIdentifier:(NSString*)groupIdentifier {
    WS::ApplicationData applicationData = WS::ApplicationData::Current();
    WS::StorageFolder folder = applicationData.GetPublisherCacheFolder(objcwinrt::string(groupIdentifier));
    winrt::hstring path = folder.Path();
    return [NSURL fileURLWithPath:Strings::WideToNSString(winrt::get_abi(path)) isDirectory:YES];
}

// Discovering Directory Contents

/**
 @Status Caveat
 @Notes Fetching directory contents, return an array of NSURL objects. Currently ignoring passed in mask
   and only support prefecch NSURLContentModificationDateKey
*/
- (NSArray*)contentsOfDirectoryAtURL:(NSURL*)url
          includingPropertiesForKeys:(NSArray*)keys
                             options:(NSDirectoryEnumerationOptions)mask
                               error:(NSError**)error {
    if (error) {
        *error = nil;
    }

    // check existence of target dir
    auto isDir = NO;
    if (![self fileExistsAtPath:url.path isDirectory:&isDir]) {
        if (error) {
            // TODO: standardize the error code and message
            *error = [NSError errorWithDomain:@"Target path does not exist" code:100 userInfo:nil];
        }
        return nil;
    } else if (!isDir) {
        // TODO: standardize the error code and message
        if (error) {
            *error = [NSError errorWithDomain:@"Target Path is not a directory" code:100 userInfo:nil];
        }
        return nil;
    }

    id enumerator = [[NSDirectoryEnumerator alloc] _initWithPath:[[url path] UTF8String]
                                                         shallow:YES
                                      includingPropertiesForKeys:keys
                                                         options:mask
                                                     returnNSURL:YES];

    // by enumerating the directory, construct the direcotry contents at this URL
    id ret = [enumerator allObjects];
    [enumerator release];
    return ret;
}

/**
 @Status Caveat
 @Notes Path must exist
*/
- (NSArray*)contentsOfDirectoryAtPath:(NSString*)pathAddr error:(NSError**)error {
    id enumerator = [NSDirectoryEnumerator new];
    enumerator = [enumerator _initWithPath:[pathAddr UTF8String]
                                   shallow:YES
                includingPropertiesForKeys:nil
                                   options:NSDirectoryEnumerationSkipsSubdirectoryDescendants
                               returnNSURL:NO];

    id ret = [enumerator allObjects];
    [enumerator release];
    return ret;
}

/**
 @Status Interoperable
*/
- (NSDirectoryEnumerator<NSURL*>*)enumeratorAtURL:(NSURL*)url
                       includingPropertiesForKeys:(NSArray*)keys
                                          options:(NSDirectoryEnumerationOptions)mask
                                     errorHandler:(BOOL (^)(NSURL* url, NSError* error))handler {
    const char* path = [[url path] UTF8String];
    return [[[NSDirectoryEnumerator alloc] _initWithPath:path shallow:NO includingPropertiesForKeys:keys options:mask returnNSURL:YES]
        autorelease];
}

/**
 @Status Interoperable
*/
- (NSDirectoryEnumerator<NSString*>*)enumeratorAtPath:(NSString*)pathAddr {
    const char* path = [pathAddr UTF8String];
    return [[[NSDirectoryEnumerator alloc] _initWithPath:path
                                                 shallow:NO
                              includingPropertiesForKeys:nil
                                                 options:NSDirectoryEnumerationSkipsSubdirectoryDescendants
                                             returnNSURL:NO] autorelease];
}

/**
 @Status NotInPlan
 @Notes UWP does not provide an API to perform this
*/
- (NSArray*)mountedVolumeURLsIncludingResourceValuesForKeys:(NSArray*)propertyKeys options:(NSVolumeEnumerationOptions)options {
    UNIMPLEMENTED();
    return nil;
}

/**
 @Status Caveat
 @Notes Error not set
*/
- (NSArray*)subpathsOfDirectoryAtPath:(NSString*)path error:(NSError**)error {
    NSArray* allContents = [[self enumeratorAtPath:path] allObjects];
    NSMutableArray* ret = [NSMutableArray arrayWithCapacity:allContents.count];

    // Only return subpaths, not files or . or ..
    for (NSString* path in allContents) {
        if (path.length > 0L && !([path isEqualToString:@"."] || [path isEqualToString:@".."])) {
            struct stat s {};
            if (EbrStat([path UTF8String], &s) == 0 && (s.st_mode & _S_IFDIR)) {
                [ret addObject:path];
            }
        }
    }

    return ret;
}

/**
 @Status Interoperable
*/
- (NSArray*)subpathsAtPath:(NSString*)path {
    return [self subpathsOfDirectoryAtPath:path error:nullptr];
}

// Creating and Deleting Items

/**
 @Status Caveat
 @Notes attributes parameter not supported. error parameter not supported.
*/
- (BOOL)createDirectoryAtURL:(NSURL*)url
    withIntermediateDirectories:(BOOL)createIntermediates
                     attributes:(NSDictionary*)attrs
                          error:(NSError**)err {
    id path = [url path];

    return [self createDirectoryAtPath:path withIntermediateDirectories:createIntermediates attributes:attrs error:err];
}

/**
 @Status Caveat
 @Notes attributes parameter not supported.  error parameter is not populated
*/
- (BOOL)createDirectoryAtPath:(NSString*)pathAddr
    withIntermediateDirectories:(BOOL)createIntermediates
                     attributes:(NSDictionary*)attrs
                          error:(NSError**)err {
    if (createIntermediates) {
        const char* path = [pathAddr UTF8String];
        id components = [pathAddr pathComponents];
        char curPath[256] = "";

        int count = [components count];
        for (int i = 0; i < count; i++) {
            id curComponent = [components objectAtIndex:i];
            const char* pComponent = [curComponent UTF8String];

            if (strlen(pComponent) > 0) {
                strcat_s(curPath, _countof(curPath), pComponent);
                strcat_s(curPath, _countof(curPath), "/");
            }

            if (strlen(curPath) > 0) {
                bool success = EbrMkdir(curPath);
                if (!success && errno != EEXIST) {
                    TraceError(TAG, L"Failed to make path %hs: %d", curPath, errno);
                    // return NO;
                }
            }
        }

        return YES;
    } else {
        const char* path = [pathAddr UTF8String];
        if (EbrMkdir(path) == 0) {
            return YES;
        } else {
            return NO;
        }
    }
}

/**
 @Status Caveat
 @Notes attributes parameter not supported
*/
- (BOOL)createFileAtPath:(id)pathAddr contents:(id)contents attributes:(id)attributes {
    return [[NSData dataWithData:contents] writeToFile:pathAddr options:0 error:nullptr];
}

/**
 @Status Interoperable
*/
- (BOOL)removeItemAtURL:(NSURL*)URL error:(NSError**)error {
    id pathAddr = [URL path];
    if (pathAddr == nil) {
        TraceVerbose(TAG, L"removeItemAtURL: nil!");
        return YES;
    }

    return [self removeItemAtPath:pathAddr error:error];
}

/**
 @Status NotInPlan
 @Notes UWP does not provide an API to perform this
*/
- (BOOL)replaceItemAtURL:(NSURL*)originalItemURL
           withItemAtURL:(NSURL*)newItemURL
          backupItemName:(NSString*)backupItemName
                 options:(NSFileManagerItemReplacementOptions)options
        resultingItemURL:(NSURL**)resultingURL
                   error:(NSError**)error {
    UNIMPLEMENTED();
    return NO;
}

/**
 @Status NotInPlan
 @Notes UWP does not provide an API to perform this
*/
- (BOOL)trashItemAtURL:(NSURL*)url resultingItemURL:(NSURL**)outResultingURL error:(NSError**)error {
    UNIMPLEMENTED();
    return NO;
}

// Moving and Copying Items

/**
 @Status Interoperable
*/
- (BOOL)copyItemAtURL:(NSURL*)srcURL toURL:(NSURL*)dstURL error:(NSError**)error {
    NSString* sourcePath = [[srcURL path] stringByReplacingOccurrencesOfString:@"/" withString:@"\\"];

    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    WF::IAsyncOperation<WS::StorageFile> sourceOperation = WS::StorageFile::GetFileFromPathAsync(objcwinrt::string(sourcePath));
    BOOL ret = NO;
    sourceOperation.Completed(objcwinrt::callback(
        [semaphore, &ret, dstURL, error](const WF::IAsyncOperation<WS::StorageFile>& sourceSuccess, WF::AsyncStatus status) {
            if (status == WF::AsyncStatus::Completed) {
                WS::StorageFile sourceFile = sourceSuccess.GetResults();
                NSString* destinationFileName = dstURL.lastPathComponent;
                NSString* destinationPath = [[dstURL path] stringByReplacingOccurrencesOfString:@"/" withString:@"\\"];
                NSString* destinationFolder = [destinationPath substringToIndex:destinationPath.length - destinationFileName.length];
                WF::IAsyncOperation<WS::StorageFolder> destinationOperation =
                    WS::StorageFolder::GetFolderFromPathAsync(objcwinrt::string(destinationFolder));
                destinationOperation.Completed(objcwinrt::callback([semaphore, &ret, &sourceFile, destinationFileName, error](
                    const WF::IAsyncOperation<WS::StorageFolder>& destinationSuccess, WF::AsyncStatus status) {
                    if (status == WF::AsyncStatus::Completed) {
                        WS::StorageFolder destinationFolder = destinationSuccess.GetResults();
                        WF::IAsyncOperation<WS::StorageFile> copyOperation =
                            sourceFile.CopyAsync(destinationFolder, objcwinrt::string(destinationFileName));
                        copyOperation.Completed(objcwinrt::callback(
                            [semaphore, &ret, error](const WF::IAsyncOperation<WS::StorageFile>& success, WF::AsyncStatus status) {
                                if (status == WF::AsyncStatus::Completed) {
                                    ret = YES;
                                } else if (error) {
                                    *error = objcwinrt::to_nserror(success, status);
                                }

                                dispatch_semaphore_signal(semaphore);
                            }));
                    } else {
                        if (error) {
                            *error = objcwinrt::to_nserror(destinationSuccess, status);
                        }
                        dispatch_semaphore_signal(semaphore);
                    }
                }));
            } else {
                if (error) {
                    *error = objcwinrt::to_nserror(sourceSuccess, status);
                }
                dispatch_semaphore_signal(semaphore);
            }
        }));

    // Wait until async method completes.
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    dispatch_release(semaphore);

    return ret;
}

/**
 @Status Interoperable
*/
- (BOOL)copyItemAtPath:(id)srcPath toPath:(id)destPath error:(NSError**)error {
    if (srcPath == nil || destPath == nil) {
        TraceVerbose(TAG, L"copyItemAtPath: nil!");
        return NO;
    }

    const char* src = [srcPath UTF8String];
    const char* dest = [destPath UTF8String];

    if (EbrAccess(dest, 0) == 0) {
        if (error) {
            // TODO: standardize the error code and message
            *error = [NSError errorWithDomain:@"Would overwrite destination" code:100 userInfo:nil];
        }
        TraceVerbose(TAG, L"Not copying %hs to %hs because dest exists", src, dest);
        return NO;
    }

    TraceVerbose(TAG, L"Copying %hs to %hs", src, dest);

    NSOutputStream* outputStream = [NSOutputStream outputStreamToFileAtPath:destPath append:NO];
    NSInputStream* inputStream = [NSInputStream inputStreamWithFileAtPath:srcPath];

    [outputStream open];
    [inputStream open];
    auto closeStreams = wil::ScopeExit([&outputStream, &inputStream]() {
        [outputStream close];
        [inputStream close];
    });

    if (NSStreamStatusOpen != inputStream.streamStatus) {
        TraceError(TAG, L"Error opening %hs", src);
        return NO;
    }

    if (NSStreamStatusOpen != outputStream.streamStatus) {
        TraceError(TAG, L"Error opening %hs", dest);
        return NO;
    }

    uint8_t in[4096];
    while ([inputStream hasBytesAvailable]) {
        NSInteger readResult = [inputStream read:in maxLength:_countof(in)];
        if (readResult == -1) {
            return NO;
        }

        int bytesToWrite = readResult;
        const unsigned char* baseAddress = (const unsigned char*)in;

        while (bytesToWrite > 0) {
            auto result = [outputStream write:(baseAddress + (readResult - bytesToWrite)) maxLength:bytesToWrite];
            if (result == -1) {
                return NO;
            } else if (result == 0) {
                break;
            }

            bytesToWrite -= result;
        }
    }

    TraceVerbose(TAG, L"Done copying");

    return YES;
}

/**
 @Status Caveat
 @Notes does not support file manager move delegates for shouldMoveItem or shouldProceedAfterError.
*/
- (BOOL)moveItemAtURL:(NSURL*)srcURL toURL:(NSURL*)dstURL error:(NSError**)error {
    THROW_NS_IF_FALSE(E_INVALIDARG, srcURL != nil);
    THROW_NS_IF_FALSE(E_INVALIDARG, dstURL != nil);
    if (![srcURL isFileURL] || ![dstURL isFileURL]) {
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileReadUnsupportedSchemeError userInfo:nil];
        }

        return NO;
    }
    return [self moveItemAtPath:[srcURL path] toPath:[dstURL path] error:error];
}

/**
 @Status Caveat
 @Notes does not support file manager move delegates for shouldMoveItem or shouldProceedAfterError.
*/
- (BOOL)moveItemAtPath:(NSString*)srcPath toPath:(NSString*)destPath error:(NSError**)error {
    THROW_NS_IF_FALSE(E_INVALIDARG, srcPath != nil);
    THROW_NS_IF_FALSE(E_INVALIDARG, destPath != nil);

    if (![self fileExistsAtPath:srcPath]) {
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileNoSuchFileError userInfo:nil];
        }

        return NO;
    }

    const char* src = [srcPath UTF8String];
    const char* dest = [destPath UTF8String];

    bool success = EbrRename(src, dest);
    if (!success) {
        TraceError(TAG, L"Rename failed. errno:%d", errno);
        if (error) {
            *error = [NSError errorWithDomain:NSWin32ErrorDomain code:errno userInfo:nil];
        }
        return NO;
    }

    return YES;
}

// Managing iCloud-Based Items

/**
 @Status NotInPlan
 @Notes UWP does not provide an API to perform this
*/
- (NSURL*)URLForUbiquityContainerIdentifier:(NSString*)containerID {
    UNIMPLEMENTED();

    return nil;
}

/**
 @Status NotInPlan
 @Notes UWP does not provide an API to perform this
*/
- (BOOL)isUbiquitousItemAtURL:(NSURL*)url {
    UNIMPLEMENTED();
    return NO;
}

/**
 @Status NotInPlan
 @Notes UWP does not provide an API to perform this
*/
- (BOOL)setUbiquitous:(BOOL)flag itemAtURL:(NSURL*)url destinationURL:(NSURL*)destinationURL error:(NSError**)errorOut {
    UNIMPLEMENTED();
    return NO;
}

/**
 @Status NotInPlan
 @Notes UWP does not provide an API to perform this
*/
- (BOOL)startDownloadingUbiquitousItemAtURL:(NSURL*)url error:(NSError**)errorOut {
    UNIMPLEMENTED();
    return NO;
}

/**
 @Status NotInPlan
 @Notes UWP does not provide an API to perform this
*/
- (BOOL)evictUbiquitousItemAtURL:(NSURL*)url error:(NSError**)errorOut {
    UNIMPLEMENTED();
    return NO;
}

/**
 @Status NotInPlan
 @Notes UWP does not provide an API to perform this
*/
- (NSURL*)URLForPublishingUbiquitousItemAtURL:(NSURL*)url expirationDate:(NSDate**)outDate error:(NSError**)error {
    UNIMPLEMENTED();
    return nil;
}

// Creating Symbolic and Hard Links
/**
 @Status NotInPlan
 @Notes UWP does not provide an API to perform this
*/
- (BOOL)createSymbolicLinkAtURL:(NSURL*)url withDestinationURL:(NSURL*)destURL error:(NSError**)error {
    UNIMPLEMENTED();
    return NO;
}

/**
 @Status NotInPlan
 @Notes UWP does not provide an API to perform this
*/
- (BOOL)createSymbolicLinkAtPath:(NSString*)path withDestinationPath:(NSString*)toPath error:(NSError**)error {
    UNIMPLEMENTED();
    return NO;
}

/**
 @Status NotInPlan
 @Notes UWP does not provide an API to perform this
*/
- (BOOL)linkItemAtURL:(NSURL*)srcURL toURL:(NSURL*)dstURL error:(NSError**)error {
    UNIMPLEMENTED();
    return NO;
}

/**
 @Status NotInPlan
 @Notes UWP does not provide an API to perform this
*/
- (BOOL)linkItemAtPath:(NSString*)fromPath toPath:(NSString*)toPath error:(NSError**)error {
    UNIMPLEMENTED();
    return NO;
}

/**
 @Status Caveat
 @Notes does not resolve symlinks
*/
- (NSString*)destinationOfSymbolicLinkAtPath:(NSString*)path error:(NSError* _Nullable*)error {
    return [[path copy] autorelease];
}

// Determining Access to Files

/**
 @Status Interoperable
*/
- (BOOL)fileExistsAtPath:(NSString*)pathAddr {
    if (pathAddr == nil) {
        return NO;
    }

    const char* path = [pathAddr UTF8String];

    if (strcmp(path, "") == 0) {
        return NO;
    }

    if (EbrAccess(path, 0) == 0) {
        return YES;
    } else {
        TraceVerbose(TAG, L"File @ %hs doesn't exist", path);
        return NO;
    }
}

/**
 @Status Interoperable
*/
- (BOOL)fileExistsAtPath:(NSString*)pathAddr isDirectory:(BOOL*)isDirectory {
    const char* path = [pathAddr UTF8String];
    struct stat st;

    if (EbrStat(path, &st) == 0) {
        if (isDirectory) {
            *isDirectory = (st.st_mode & _S_IFDIR) == _S_IFDIR;
        }
        return YES;
    } else {
        return NO;
    }
}

/**
 @Status Interoperable
*/
- (BOOL)isReadableFileAtPath:(id)pathAddr {
    const char* path = [pathAddr UTF8String];

    if (EbrAccess(path, 6) == 0) {
        return YES;
    } else {
        TraceVerbose(TAG, L"File @ %hs isn't writable", path);
        return NO;
    }
}

/**
 @Status Interoperable
*/
- (BOOL)isWritableFileAtPath:(id)pathAddr {
    const char* path = [pathAddr UTF8String];

    if (EbrAccess(path, 4) == 0) {
        return YES;
    } else {
        TraceVerbose(TAG, L"File @ %hs isn't readable", path);
        return NO;
    }
}

/**
 @Status Interoperable
*/
- (BOOL)isExecutableFileAtPath:(NSString*)path {
    return EbrAccess([path UTF8String], 1) == 0 ? YES : NO;
}

/**
 @Status NotInPlan
 @Notes UWP does not provide a single API to perform this
*/
- (BOOL)isDeletableFileAtPath:(NSString*)path {
    UNIMPLEMENTED();
    return StubReturn();
}

// Getting and Setting Attributes

/**
 @Status NotInPlan
 @Notes UWP does not provide an API to perform this
*/
- (NSArray*)componentsToDisplayForPath:(NSString*)path {
    UNIMPLEMENTED();
    return nil;
}

/**
 @Status NotInPlan
 @Notes UWP does not provide an API to perform this
*/
- (id)displayNameAtPath:(id)path {
    UNIMPLEMENTED();
    return path;
}

static HRESULT __getFileFromPath(NSString* path, ABI::Windows::Storage::IStorageFile** file) {
    NSString* filePath = [path stringByReplacingOccurrencesOfString:@"/" withString:@"\\"];

    ComPtr<ABI::Windows::Storage::IStorageFileStatics> storageFileStatics;
    RETURN_IF_FAILED(Windows::Foundation::GetActivationFactory(
        Microsoft::WRL::Wrappers::HStringReference(RuntimeClass_Windows_Storage_StorageFile).Get(), &storageFileStatics));

    ComPtr<ABI::Windows::Foundation::IAsyncOperation<ABI::Windows::Storage::StorageFile*>> fileOperation;
    RETURN_IF_FAILED(storageFileStatics->GetFileFromPathAsync(Strings::NarrowToWide<HSTRING>(filePath).Get(), &fileOperation));

    return WRLHelpers::AwaitOperationResult(fileOperation.Get(), file);
}

/**
 @Status Caveat
 @Notes Only NSFileType, NSFileImmutable, NSFileSize, NSFileModificationDate, and NSFileCreationDate are supported
*/
- (NSDictionary<NSFileAttributeKey, id>*)attributesOfItemAtPath:(NSString*)path error:(NSError**)error {
    if (path == nil) {
        TraceVerbose(TAG, L"attributesOfItemAtPath nil!");
        if (error) {
            // TODO: standardize the error code and message
            *error = [NSError errorWithDomain:@"Empty File Path" code:100 userInfo:nil];
        }

        return nil;
    }

    // First get the file
    ComPtr<ABI::Windows::Storage::IStorageFile> file;
    RETURN_NULL_IF_FAILED(__getFileFromPath(path, &file));

    // Then get the attributes, which translate to NSFileType and NSFileImmutable
    ComPtr<ABI::Windows::Storage::IStorageItem> fileAsItem;
    RETURN_NULL_IF_FAILED(file.As(&fileAsItem));

    ABI::Windows::Storage::FileAttributes attributes;
    RETURN_NULL_IF_FAILED(fileAsItem->get_Attributes(&attributes));

    NSMutableDictionary* ret = [NSMutableDictionary dictionary];
    ret[NSFileType] = ((attributes & ABI::Windows::Storage::FileAttributes_Directory) == ABI::Windows::Storage::FileAttributes_Directory) ?
                          NSFileTypeDirectory :
                          NSFileTypeRegular;
    ret[NSFileImmutable] =
        ((attributes & ABI::Windows::Storage::FileAttributes_ReadOnly) == ABI::Windows::Storage::FileAttributes_ReadOnly) ? @YES : @NO;

    ComPtr<ABI::Windows::Storage::IStorageItemProperties> fileAsProperties;
    RETURN_NULL_IF_FAILED(file.As(&fileAsProperties));

    // Then get the properties, which translate to NSFileSize, NSFileModificationDate, and NSFileCreationDate
    ComPtr<ABI::Windows::Storage::FileProperties::IStorageItemContentProperties> properties;
    RETURN_NULL_IF_FAILED(fileAsProperties->get_Properties(&properties));
    ComPtr<ABI::Windows::Storage::FileProperties::IStorageItemExtraProperties> extraProperties;
    RETURN_NULL_IF_FAILED(properties.As(&extraProperties));

    static const StrongId<NSArray> sc_propertiesToRetrieve = @[ @"System.DateModified", @"System.DateCreated", @"System.Size" ];
    ComPtr<IInspectable> inspectablePropertiesToRetrieve = new ObjcIterableProxy<HSTRING, dummyWRLCreator>(sc_propertiesToRetrieve);
    ComPtr<ABI::Windows::Foundation::Collections::IIterable<HSTRING>> abiPropertiesToRetrieve;
    RETURN_NULL_IF_FAILED(inspectablePropertiesToRetrieve.As(&abiPropertiesToRetrieve));

    ComPtr<ABI::Windows::Foundation::IAsyncOperation<ABI::Windows::Foundation::Collections::IMap<HSTRING, IInspectable*>*>>
        propertiesOperation;
    RETURN_NULL_IF_FAILED(extraProperties->RetrievePropertiesAsync(abiPropertiesToRetrieve.Get(), &propertiesOperation));

    ComPtr<ABI::Windows::Foundation::Collections::IMap<HSTRING, IInspectable*>> abiResults;
    WRLHelpers::AwaitOperationResult(propertiesOperation.Get(), &abiResults);
    ComPtr<IInspectable> inspectableValue;

    RETURN_NULL_IF_FAILED(abiResults->Lookup(winrt::get_abi(sc_fileSizeKey), &inspectableValue));
    ComPtr<ABI::Windows::Foundation::IPropertyValue> propertyValue;
    RETURN_NULL_IF_FAILED(inspectableValue.As(&propertyValue));
    uint64_t fileSize = 0;
    RETURN_NULL_IF_FAILED(propertyValue->GetUInt64(&fileSize));
    ret[NSFileSize] = [NSNumber numberWithUnsignedLongLong:fileSize];

    RETURN_NULL_IF_FAILED(abiResults->Lookup(winrt::get_abi(sc_fileModificationDateKey), &inspectableValue));
    RETURN_NULL_IF_FAILED(inspectableValue.As(&propertyValue));
    DateTime dateValue{};
    RETURN_NULL_IF_FAILED(propertyValue->GetDateTime(&dateValue));
    ret[NSFileModificationDate] = __SystemTimeToNSDate(dateValue);

    RETURN_NULL_IF_FAILED(abiResults->Lookup(winrt::get_abi(sc_fileCreationDateKey), &inspectableValue));
    RETURN_NULL_IF_FAILED(inspectableValue.As(&propertyValue));
    RETURN_NULL_IF_FAILED(propertyValue->GetDateTime(&dateValue));
    ret[NSFileCreationDate] = __SystemTimeToNSDate(dateValue);

    return ret;
}

/**
 @Status NotInPlan
 @Notes UWP does not provide an API to perform this
*/
- (id)attributesOfFileSystemForPath:(id)pathAddr error:(NSError**)error {
    UNIMPLEMENTED();
    if (error) {
        *error = nil;
    }

    const char* path = [pathAddr UTF8String];

    TraceVerbose(TAG, L"fileAttributesAtPath: %hs", path);

    id ret = [NSMutableDictionary dictionary];
    [ret setValue:[NSNumber numberWithInt:256 * 1024 * 1024] forKey:NSFileSystemFreeSize];

    return ret;
}

/**
 @Status Caveat
 @Notes Only NSFileType, NSFileImmutable are supported
        NSFileSize, NSFileModificationDate, and NSFileCreationDate cannot be set using WRL APIs
*/
- (BOOL)setAttributes:(NSDictionary<NSFileAttributeKey, id>*)attribs ofItemAtPath:(NSString*)path error:(NSError**)error {
    // First get the file
    ComPtr<ABI::Windows::Storage::IStorageFile> file;
    RETURN_FALSE_IF_FAILED(__getFileFromPath(path, &file));

    // Then create a ValueSet which will contain the attributes
    ComPtr<ABI::Windows::Storage::IStorageItem> fileAsItem;
    RETURN_FALSE_IF_FAILED(file.As(&fileAsItem));

    ABI::Windows::Storage::FileAttributes fileAttributes;
    RETURN_FALSE_IF_FAILED(fileAsItem->get_Attributes(&fileAttributes));

    ComPtr<IInspectable> changingAttributesInspectable;
    RETURN_FALSE_IF_FAILED(
        RoActivateInstance(Microsoft::WRL::Wrappers::HStringReference(RuntimeClass_Windows_Foundation_Collections_ValueSet).Get(),
                           &changingAttributesInspectable));
    ComPtr<ABI::Windows::Foundation::Collections::IMap<HSTRING, IInspectable*>> changingAttributes;
    RETURN_FALSE_IF_FAILED(changingAttributesInspectable.As(&changingAttributes));

    // Iterate through the attributes the user wants changed
    for (NSFileAttributeKey key in attribs) {
        id value = attribs[key];
        if ([key isEqualToString:NSFileType]) {
            // Value is NSFileAttributeType (NSString*), only support Directory or Regular
            if ([value isEqualToString:NSFileTypeRegular]) {
                fileAttributes &= ~ABI::Windows::Storage::FileAttributes_Directory;
            } else if ([value isEqualToString:NSFileTypeRegular]) {
                fileAttributes |= ABI::Windows::Storage::FileAttributes_Directory;
            } // Otherwise just ignore the value, we don't want to fail for all unsupported values
        } else if ([key isEqualToString:NSFileImmutable]) {
            // Value is NSNumber with a boolean value
            if ([value boolValue]) {
                fileAttributes |= ABI::Windows::Storage::FileAttributes_ReadOnly;
            } else {
                fileAttributes &= ~ABI::Windows::Storage::FileAttributes_ReadOnly;
            }
        } else {
            TraceWarning(TAG, L"Unsupported NSFileAttributeKey %@ used in [%s %s]", key, class_getName([self class]), sel_getName(_cmd));
        }
    }

    // Add FileAttributes to the ValueSet of changing attribtues
    ComPtr<ABI::Windows::Foundation::IPropertyValueStatics> propertyStatics;
    RETURN_FALSE_IF_FAILED(ABI::Windows::Foundation::GetActivationFactory(
        Microsoft::WRL::Wrappers::HStringReference(RuntimeClass_Windows_Foundation_PropertyValue).Get(), &propertyStatics));

    ComPtr<IInspectable> attributeInspectableValue;
    RETURN_FALSE_IF_FAILED(propertyStatics->CreateUInt32(fileAttributes, &attributeInspectableValue))

    BOOLEAN unused = false;
    RETURN_FALSE_IF_FAILED(changingAttributes->Insert(winrt::get_abi(sc_fileAttributesKey), attributeInspectableValue.Get(), &unused));

    // Then save the attributes to the file
    ComPtr<ABI::Windows::Foundation::Collections::IIterable<ABI::Windows::Foundation::Collections::IKeyValuePair<HSTRING, IInspectable*>*>>
        abiIterable;
    RETURN_FALSE_IF_FAILED(changingAttributes.As(&abiIterable));

    ComPtr<ABI::Windows::Storage::IStorageItemProperties> fileAsProperties;
    RETURN_FALSE_IF_FAILED(file.As(&fileAsProperties));
    ComPtr<ABI::Windows::Storage::FileProperties::IStorageItemContentProperties> properties;
    RETURN_FALSE_IF_FAILED(fileAsProperties->get_Properties(&properties));
    ComPtr<ABI::Windows::Storage::FileProperties::IStorageItemExtraProperties> extraProperties;
    RETURN_FALSE_IF_FAILED(properties.As(&extraProperties));

    ComPtr<ABI::Windows::Foundation::IAsyncAction> saveAction;
    RETURN_FALSE_IF_FAILED(extraProperties->SavePropertiesAsync(abiIterable.Get(), &saveAction));

    Microsoft::WRL::ComPtr<WRLHelpers::ActionCallback> completion;
    RETURN_FALSE_IF_FAILED(Microsoft::WRL::MakeAndInitialize<WRLHelpers::ActionCallback>(&completion));
    RETURN_FALSE_IF_FAILED(saveAction->put_Completed(completion.Get()));
    completion->Wait();
    return SUCCEEDED(saveAction->GetResults());
}

// Getting and Comparing File Contents

/**
 @Status Interoperable
*/
- (id)contentsAtPath:(id)pathAddr {
    return [NSData dataWithContentsOfFile:pathAddr];
}

/**
 @Status Caveat
 @Notes Comparing directories not supported
*/
- (BOOL)contentsEqualAtPath:(id)pathObj1 andPath:(id)pathObj2 {
    const char* path1 = [pathObj1 UTF8String];
    const char* path2 = [pathObj2 UTF8String];

    bool dir = EbrIsDir(path1);
    if (dir != EbrIsDir(path2)) {
        return NO;
    }

    if (dir) {
        // no good:
        assert(0);
    } else {
        struct stat st1, st2;
        if (EbrStat(path1, &st1) != 0 || EbrStat(path2, &st2) != 0) {
            return NO;
        }

        if (st1.st_size != st2.st_size) {
            return NO;
        }

        id d1 = [[NSData alloc] initWithContentsOfFile:pathObj1];
        id d2 = [[NSData alloc] initWithContentsOfFile:pathObj2];

        bool ret = [d1 isEqualToData:d2] != 0;

        [d1 release];
        [d2 release];

        return ret;
    }

    return NO;
}

// Getting the Relationship Between Items

/**
 @Status NotInPlan
 @Notes UWP does not provide an API to perform this
*/
- (BOOL)getRelationship:(NSURLRelationship*)outRelationship
       ofDirectoryAtURL:(NSURL*)directoryURL
            toItemAtURL:(NSURL*)otherURL
                  error:(NSError**)error {
    UNIMPLEMENTED();
    return NO;
}

/**
 @Status NotInPlan
 @Notes UWP does not provide an API to perform this
*/
- (BOOL)getRelationship:(NSURLRelationship*)outRelationship
            ofDirectory:(NSSearchPathDirectory)directory
               inDomain:(NSSearchPathDomainMask)domainMask
            toItemAtURL:(NSURL*)url
                  error:(NSError**)error {
    UNIMPLEMENTED();
    return NO;
}

// Converting File Paths to Strings

/**
 @Status Interoperable
*/
- (const char*)fileSystemRepresentationWithPath:(id)pathAddr {
    return [pathAddr UTF8String];
}

/**
 @Status Interoperable
*/
- (id)stringWithFileSystemRepresentation:(const char*)path length:(NSUInteger)length {
    return [[NSString string] initWithBytes:path length:length encoding:NSUTF8StringEncoding];
}

// Managing the Delegate

// Managing the Current Directory

/**
 @Status Interoperable
*/
- (BOOL)changeCurrentDirectoryPath:(NSString*)path {
    return (0 == _NS_chdir([path UTF8String]));
}

/**
 @Status Interoperable
*/
- (NSString*)currentDirectoryPath {
    return [[static_cast<NSURL*>(_CFURLCreateCurrentDirectoryURL(kCFAllocatorDefault)) autorelease] path];
}

// Deprecated Methods

/**
 @Status NotInPlan
 @Notes UWP does not provide an API to perform this
*/
- (BOOL)copyPath:(NSString*)src toPath:(NSString*)dest handler:handler {
    UNIMPLEMENTED();
    return NO;
}

/**
 @Status NotInPlan
 @Notes UWP does not provide an API to perform this
*/
- (BOOL)movePath:(NSString*)src toPath:(NSString*)dest handler:handler {
    UNIMPLEMENTED();
    return NO;
}

/**
 @Status NotInPlan
 @Notes UWP does not provide an API to perform this
*/
- (BOOL)removeFileAtPath:(NSString*)path handler:handler {
    UNIMPLEMENTED();
    return NO;
}

/**
 @Status Caveat
 @Notes Only NSFileType, NSFileImmutable are supported
        NSFileSize, NSFileModificationDate, and NSFileCreationDate cannot be set using WRL APIs
*/
- (BOOL)changeFileAttributes:(NSDictionary*)attributes atPath:(NSString*)path {
    return [self setAttributes:attributes ofItemAtPath:path error:nullptr];
}

/**
 @Status Caveat
 @Notes Only NSFileType, NSFileImmutable, NSFileSize, NSFileModificationDate, and NSFileCreationDate are supported
 @traverseLink not supported.
*/
- (NSDictionary*)fileAttributesAtPath:(NSString*)path traverseLink:(BOOL)traverseLinks {
    return [self attributesOfItemAtPath:path error:nullptr];
}

/**
 @Status Caveat
 @Notes returns hardcoded attributes
*/
- (NSDictionary*)fileSystemAttributesAtPath:(NSString*)pathAddr {
    id ret = [NSMutableDictionary dictionary];
    [ret setValue:[NSNumber numberWithInt:32 * 1024 * 1024] forKey:NSFileSystemFreeSize];
    [ret setValue:[NSNumber numberWithInt:64 * 1024 * 1024 * 1024] forKey:NSFileSystemSize];

    return ret;
}

/**
 @Status Interoperable
*/
- (NSArray*)directoryContentsAtPath:(NSString*)pathAddr {
    id enumerator = [[[NSDirectoryEnumerator alloc] _initWithPath:[pathAddr UTF8String]
                                                          shallow:YES
                                       includingPropertiesForKeys:nil
                                                          options:NSDirectoryEnumerationSkipsSubdirectoryDescendants
                                                      returnNSURL:NO] autorelease];

    id ret = [enumerator allObjects];
    return ret;
}

/**
 @Status Caveat
 @Notes attributes parameter not supported
*/
- (BOOL)createDirectoryAtPath:(id)pathAddr attributes:(NSDictionary*)attrs {
    const char* path = [pathAddr UTF8String];

    if (EbrMkdir(path)) {
        return YES;
    } else {
        return NO;
    }
}

/**
 @Status NotInPlan
 @Notes UWP does not provide an API to perform this
*/
- (BOOL)createSymbolicLinkAtPath:(NSString*)path pathContent:(NSString*)destination {
    UNIMPLEMENTED();
    return NO;
}

/**
 @Status NotInPlan
 @Notes UWP does not provide an API to perform this
*/
- (NSString*)pathContentOfSymbolicLinkAtPath:(NSString*)path {
    UNIMPLEMENTED();
    return nil;
}

/**
 @Status NotInPlan
 @Notes UWP does not provide an API to perform this
*/
- (BOOL)linkPath:(NSString*)source toPath:(NSString*)destination handler:handler {
    UNIMPLEMENTED();
    return NO;
}

/**
 @Status Interoperable
*/
- (BOOL)removeItemAtPath:(id)pathAddr error:(NSError**)error {
    if (error) {
        *error = nil;
    }

    const char* path = [pathAddr UTF8String];
    TraceVerbose(TAG, L"removeItemAtPath: %hs", path);

    BOOL ret = EbrRemove(path);
    if (!ret && error) {
        // TODO: standardize the error code and message
        *error = [NSError errorWithDomain:@"Failed to delete file" code:100 userInfo:nil];
    }

    return ret;
}

@end

/**
 @Status NotInPlan
 @Notes UWP does not provide an API to perform this
*/
NSString* NSOpenStepRootDirectory() {
    UNIMPLEMENTED();
    return StubReturn();
}
