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

#include <COMIncludes.h>
#import <winrt/Windows.Storage.h>
#import <winrt/Windows.Storage.Streams.h>
#import <winrt/Windows.Storage.FileProperties.h>
#include "RawBuffer.h"
#include <COMIncludes_End.h>

#import "ALAssetRepresentationInternal.h"
#import <Starboard.h>
#import <StubReturn.h>
#import <Foundation/NSError.h>
#import <Foundation/NSURL.h>
#import <AssetsLibrary/ALAssetRepresentation.h>
#import "CppWinRTHelpers.h"

using namespace Microsoft::WRL;
using namespace winrt::Windows::Storage;
using namespace winrt::Windows::Storage::Streams;
using namespace winrt::Windows::Storage::FileProperties;
namespace WF = winrt::Windows::Foundation;

static const wchar_t* TAG = L"ALAssetRepresentation";
NSString* const ALAssetRepresentationDomain = @"ALAssetRepresentation";

@interface ALAssetRepresentation () {
    StrongId<NSURL> _urlRep;
    TrivialDefaultConstructor<StorageFile> _storageFile;
    uint64_t _fileSize;
}
@end

@implementation ALAssetRepresentation

/**
@Status Interoperable
@Notes Creates single Asset Representation
*/
- (instancetype)_initWithAssetURL:(NSURL*)url localPath:(NSString*)path error:(NSError**)error {
    if ((self = [super init])) {
        _urlRep = url;
        _storageFile = nullptr;
        NSError* tempError = nil;

        dispatch_group_t group = dispatch_group_create();
        dispatch_group_enter(group);

        // Make sure the file path is valid and get its StorageFile object
        WF::IAsyncOperation<StorageFile> async = StorageFile::GetFileFromPathAsync(objcwinrt::string(path));

        async.Completed(objcwinrt::callback([self, group, &tempError] (const WF::IAsyncOperation<StorageFile>& op, WF::AsyncStatus status) {
            if (status == WF::AsyncStatus::Completed) {
                _storageFile = op.GetResults();
            } else {
                tempError = [objcwinrt::to_nserror(op, status) retain];
            }

            dispatch_group_leave(group);
        }));

        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        dispatch_release(group);

        if (error) {
            *error = [tempError autorelease];
        } else {
            [tempError release];
        }

        if (!_storageFile) {
            [self release];
            return nil;
        }
    }
    return self;
}

/**
 @Status Stub
 @Notes
*/
- (CGImageRef)CGImageWithOptions:(NSDictionary*)options {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
- (CGImageRef)fullResolutionImage {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
- (CGImageRef)fullScreenImage {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
- (ALAssetOrientation)orientation {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
- (float)scale {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
- (CGSize)dimensions {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
- (NSString*)filename {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Interoperable
 @Notes Returns the size of the represented file in bytes
*/
- (long long)size {
    dispatch_group_t group = dispatch_group_create();
    dispatch_group_enter(group);

    WF::IAsyncOperation<BasicProperties> async = _storageFile.GetBasicPropertiesAsync();

    async.Completed(objcwinrt::callback([self, group] (const WF::IAsyncOperation<BasicProperties>& op, WF::AsyncStatus status) {
        if (status == WF::AsyncStatus::Completed) {
            _fileSize = op.GetResults().Size();
        } else {
            _fileSize = 0;
            TraceError(TAG, L"Error getting basic properties of file - %x", op.ErrorCode());
        }

        dispatch_group_leave(group);
    }));

    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    dispatch_release(group);

    return _fileSize;
}

/**
 @Status Interoperable
 @Notes Copy specified bytes into buffer
*/
- (NSUInteger)getBytes:(uint8_t*)buffer fromOffset:(long long)offset length:(NSUInteger)length error:(NSError**)error {
    unsigned int bufferLength = 0;
    NSError* tempError = nil;

    if (_storageFile) {
        dispatch_group_t group = dispatch_group_create();
        dispatch_group_enter(group);

        WF::IAsyncOperation<IRandomAccessStreamWithContentType> async = _storageFile.OpenReadAsync();

        async.Completed(objcwinrt::callback(
            [buffer, offset, length, group, &bufferLength, &tempError] (const WF::IAsyncOperation<IRandomAccessStreamWithContentType>& op, WF::AsyncStatus status) {
                if (status == WF::AsyncStatus::Completed) {
                    IRandomAccessStreamWithContentType fileStream = op.GetResults();
                    fileStream.Seek(offset);

                    // Create IBuffer from our buffer
                    IBuffer inBuffer = nullptr;
                    ComPtr<ABI::Windows::Storage::Streams::IBuffer> inBufferRaw;
                    HRESULT result = BufferFromRawData(inBufferRaw.GetAddressOf(), buffer, length);
                    THROW_NS_IF_FAILED_MSG(result, "Internal error: Failed to create IBuffer.");
                    winrt::attach_abi(inBuffer, reinterpret_cast<winrt::ABI::Windows::Storage::Streams::IBuffer*>(inBufferRaw.Detach()));
                    inBuffer.Length(0);

                    // Use IBuffer to read the stream
                    WF::IAsyncOperationWithProgress<IBuffer, unsigned int> async =
                        fileStream.ReadAsync(inBuffer, length, InputStreamOptions::None);

                    async.Completed(objcwinrt::callback(
                        [buffer, length, group, &bufferLength, &tempError] (const WF::IAsyncOperationWithProgress<IBuffer, unsigned int>& op, WF::AsyncStatus status) {
                            if (status == WF::AsyncStatus::Completed) {
                                IBuffer outBuffer = op.GetResults();
                                bufferLength = outBuffer.Length();

                                // Get the data buffer out of the com object.
                                ComPtr<IInspectable> insp = objcwinrt::to_insp(outBuffer);
                                ComPtr<IBufferByteAccess> bufferByteAccess;
                                HRESULT result = insp.As(&bufferByteAccess);
                                THROW_NS_IF_FAILED_MSG(result, "Internal error: Failed to get data from com object.");

                                // Retrieve the buffer data.
                                uint8_t* byteBuffer = nullptr;
                                result = bufferByteAccess->Buffer(&byteBuffer);
                                THROW_NS_IF_FAILED_MSG(result, "Internal error: Failed to retrieve buffer data.");

                                // If ReadAsync put the data at a different address than
                                // the one passed in, copy the data into our buffer
                                if (byteBuffer != buffer) {
                                    memcpy_s(buffer, length, byteBuffer, bufferLength);
                                }
                            } else {
                                tempError = [objcwinrt::to_nserror(op, status) retain];
                            }

                            dispatch_group_leave(group);
                    }));
                } else {
                    tempError = [objcwinrt::to_nserror(op, status) retain];
                    dispatch_group_leave(group);
                }
        }));

        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        dispatch_release(group);

        if (error) {
            *error = [tempError autorelease];
        } else {
            [tempError release];
        }

    } else {
        if (error) {
            *error = [NSError errorWithDomain:ALAssetRepresentationDomain code:_ALAssetRepresentationErrorCodeFileAccessError userInfo:nil];
        }
    }

    return bufferLength;
}

/**
 @Status Stub
 @Notes
*/
- (NSString*)UTI {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
- (NSDictionary*)metadata {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Interoperable
 @Notes
*/
- (NSURL*)url {
    return [[_urlRep retain] autorelease];
}

@end
