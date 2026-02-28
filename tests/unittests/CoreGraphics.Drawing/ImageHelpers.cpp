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

#include "ImageHelpers.h"

#include <Starboard/SmartTypes.h>
#include <ImageIO/ImageIO.h>

#include <memory>

#include <windows.h>

CGImageRef _CGImageCreateFromPNGFile(CFStringRef filename, bool shouldInterpolate) {
    woc::unique_cf<CGDataProviderRef> dataProvider{ CGDataProviderCreateWithFilename(
        CFStringGetCStringPtr(filename, kCFStringEncodingUTF8)) };
    if (!dataProvider) {
        return nullptr;
    }

    return CGImageCreateWithPNGDataProvider(dataProvider.get(), nullptr, shouldInterpolate, kCGRenderingIntentDefault);
}

CGImageRef _CGImageCreateFromJPEGFile(CFStringRef filename) {
    woc::unique_cf<CGDataProviderRef> dataProvider{ CGDataProviderCreateWithFilename(
        CFStringGetCStringPtr(filename, kCFStringEncodingUTF8)) };
    if (!dataProvider) {
        return nullptr;
    }

    return CGImageCreateWithJPEGDataProvider(dataProvider.get(), nullptr, FALSE, kCGRenderingIntentDefault);
}

CFDataRef _CFDataCreatePNGFromCGImage(CGImageRef image) {
    // Estimate the image data size to be as large as its raw pixel buffer.
    // This will never be hit; but if it does, CFData will grow intelligently regardless.
    size_t sizeEstimate = CGImageGetHeight(image) * CGImageGetBytesPerRow(image);
    woc::unique_cf<CFMutableDataRef> imageData{ CFDataCreateMutable(nullptr, sizeEstimate) };
    if (!imageData) {
        return nullptr;
    }

    woc::unique_cf<CGImageDestinationRef> imageDest{ CGImageDestinationCreateWithData(imageData.get(), CFSTR("public.png"), 1, nullptr) };
    if (!imageDest) {
        return nullptr;
    }

    CGImageDestinationAddImage(imageDest.get(), image, nullptr);
    CGImageDestinationFinalize(imageDest.get());

    return imageData.release();
}

bool _WriteCFDataToFile(CFDataRef data, CFStringRef filename) {
    std::unique_ptr<char[]> owningFilenamePtr;

    char* rawFilename = const_cast<char*>(CFStringGetCStringPtr(filename, kCFStringEncodingUTF8));
    size_t len = 0;

    if (!rawFilename) {
        CFRange filenameRange{ 0, CFStringGetLength(filename) };
        CFIndex requiredBufferLength = 0;
        CFStringGetBytes(filename, filenameRange, kCFStringEncodingUTF8, 0, FALSE, nullptr, 0, &requiredBufferLength);
        owningFilenamePtr.reset(new char[requiredBufferLength]);
        rawFilename = owningFilenamePtr.get();
        CFStringGetBytes(
            filename, filenameRange, kCFStringEncodingUTF8, 0, FALSE, (UInt8*)rawFilename, requiredBufferLength, &requiredBufferLength);
        len = requiredBufferLength;
    } else {
        len = strlen(rawFilename);
    }

    woc::unique_cf<CFURLRef> url{ CFURLCreateFromFileSystemRepresentation(nullptr, (UInt8*)rawFilename, len, FALSE) };

    return url ? CFURLWriteDataAndPropertiesToResource(url.get(), data, nullptr, nullptr) : FALSE;
}

CFDataRef _CFDataCreateFromCGImage(CGImageRef image) {
    return CGDataProviderCopyData(CGImageGetDataProvider(image));
}

CFStringRef _CFStringCreateAbsolutePath(CFStringRef relativePath) {
    std::unique_ptr<char[]> owningFilenamePtr;

    char* rawFilename = const_cast<char*>(CFStringGetCStringPtr(relativePath, kCFStringEncodingUTF8));
    size_t len = 0;

    if (!rawFilename) {
        CFRange filenameRange{ 0, CFStringGetLength(relativePath) };
        CFIndex requiredBufferLength = 0;
        CFStringGetBytes(relativePath, filenameRange, kCFStringEncodingUTF8, 0, FALSE, nullptr, 0, &requiredBufferLength);
        owningFilenamePtr.reset(new char[requiredBufferLength]);
        rawFilename = owningFilenamePtr.get();
        CFStringGetBytes(
            relativePath, filenameRange, kCFStringEncodingUTF8, 0, FALSE, (UInt8*)rawFilename, requiredBufferLength, &requiredBufferLength);
        len = requiredBufferLength;
    } else {
        len = strlen(rawFilename);
    }

    uint8_t buffer[MAX_PATH];
    woc::unique_cf<CFURLRef> url{ CFURLCreateFromFileSystemRepresentation(nullptr, (UInt8*)rawFilename, len, FALSE) };
    if (!CFURLGetFileSystemRepresentation(url.get(), true, &buffer[0], std::extent<decltype(buffer)>::value)) {
        return nullptr;
    }
    return CFStringCreateWithCString(nullptr, reinterpret_cast<char*>(buffer), kCFStringEncodingUTF8);
}

CFStringRef _CFStringCreateWithStdString(const std::string& string) {
	return CFStringCreateWithBytes(nullptr, reinterpret_cast<const UInt8*>(&string[0]), string.size(), kCFStringEncodingUTF8, FALSE);
}
