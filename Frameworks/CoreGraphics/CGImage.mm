//******************************************************************************
//
// Copyright (c) 2016 Intel Corporation. All rights reserved.
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

#import <StubReturn.h>
#import <Starboard.h>
#import <math.h>
#import <vector>
#import <CoreGraphics/CGContext.h>
#import <CoreGraphics/CGGeometry.h>
#import <CoreGraphics/CGDataProvider.h>
#import <Foundation/NSData.h>
#import <LoggingNative.h>
#import <CFRuntime.h>
#import <CFBridgeUtilities.h>
#import <CoreGraphics/D2DWrapper.h>
#import "CGColorSpaceInternal.h"
#import "CGImageInternal.h"
#import "CGSurfaceInfoInternal.h"
#import "CGIWICBitmap.h"

using namespace Microsoft::WRL;

static const wchar_t* TAG = L"CGImage";

// TODO #1124: remove old code
#pragma region OLD_CODE
static std::vector<CGImageDestructionListener> _imageDestructionListeners;
COREGRAPHICS_EXPORT void CGImageAddDestructionListener(CGImageDestructionListener listener) {
    _imageDestructionListeners.push_back(listener);
}

#pragma endregion OLD_CODE

/**
 @Status Interoperable
*/
CFTypeID CGImageGetTypeID() {
    return __CGImage::GetTypeID();
}

/**
 @Status Caveat
 @Notes Limited bitmap formats available and decode is not supported.
*/
CGImageRef CGImageCreate(size_t width,
                         size_t height,
                         size_t bitsPerComponent,
                         size_t bitsPerPixel,
                         size_t bytesPerRow,
                         CGColorSpaceRef colorSpace,
                         CGBitmapInfo bitmapInfo,
                         CGDataProviderRef provider,
                         const float* decode,
                         bool shouldInterpolate,
                         CGColorRenderingIntent intent) {
    RETURN_NULL_IF(((provider == nullptr) || ![(NSObject*)provider isKindOfClass:[NSData class]]) || (colorSpace == nullptr));

    NSData* dataProvider = (__bridge NSData*)provider;

    unsigned char* data = (unsigned char*)[dataProvider bytes];

    ComPtr<IWICBitmap> image;
    ComPtr<IWICImagingFactory> imageFactory;
    RETURN_NULL_IF_FAILED(_CGGetWICFactory(&imageFactory));

    REFGUID pixelFormat = _CGImageGetWICPixelFormatFromImageProperties(bitsPerComponent, bitsPerPixel, colorSpace, bitmapInfo);

    RETURN_NULL_IF_FAILED(
        imageFactory->CreateBitmapFromMemory(width, height, pixelFormat, bytesPerRow, height * bytesPerRow, data, &image));

    CGImageRef imageRef = __CGImage::CreateInstance();
    imageRef->SetImageSource(image).SetColorSpace(colorSpace).SetRenderingIntent(intent).SetInterpolate(shouldInterpolate);

    return imageRef;
}

/**
 @Status Interoperable
*/
CGImageRef CGImageCreateWithImageInRect(CGImageRef ref, CGRect rect) {
    RETURN_NULL_IF(!ref);

    ComPtr<IWICImagingFactory> imageFactory;
    RETURN_NULL_IF_FAILED(_CGGetWICFactory(&imageFactory));

    ComPtr<IWICBitmap> rectImage;
    RETURN_NULL_IF_FAILED(imageFactory->CreateBitmapFromSourceRect(
        ref->ImageSource().Get(), rect.origin.x, rect.origin.y, rect.size.width, rect.size.height, &rectImage));

    CGImageRef imageRef = __CGImage::CreateInstance();
    imageRef->SetImageSource(rectImage)
        .SetColorSpace(ref->ColorSpace())
        .SetRenderingIntent(ref->RenderingIntent())
        .SetInterpolate(ref->Interpolate());

    return imageRef;
}

/**
 @Status Interoperable
*/
CGImageRef CGImageCreateCopy(CGImageRef ref) {
    RETURN_NULL_IF(!ref);

    ComPtr<IWICImagingFactory> imageFactory;
    RETURN_NULL_IF_FAILED(_CGGetWICFactory(&imageFactory));

    ComPtr<IWICBitmap> image;

    RETURN_NULL_IF_FAILED(imageFactory->CreateBitmapFromSource(ref->ImageSource().Get(), WICBitmapCacheOnLoad, &image));

    CGImageRef imageRef = __CGImage::CreateInstance();
    imageRef->SetImageSource(image)
        .SetIsMask(ref->IsMask())
        .SetInterpolate(ref->Interpolate())
        .SetColorSpace(ref->ColorSpace())
        .SetRenderingIntent(ref->RenderingIntent());

    return imageRef;
}

/**
 @Status Caveat
 @Notes decode parameter is ignored
*/
CGImageRef CGImageMaskCreate(size_t width,
                             size_t height,
                             size_t bitsPerComponent,
                             size_t bitsPerPixel,
                             size_t bytesPerRow,
                             CGDataProviderRef provider,
                             const CGFloat* decode,
                             bool shouldInterpolate) {
    RETURN_NULL_IF(((provider == nullptr) || ![(NSObject*)provider isKindOfClass:[NSData class]]));

    NSData* dataProvider = (__bridge NSData*)provider;

    unsigned char* data = (unsigned char*)[dataProvider bytes];

    ComPtr<IWICBitmap> image;
    ComPtr<IWICImagingFactory> imageFactory;
    RETURN_NULL_IF_FAILED(_CGGetWICFactory(&imageFactory));

    woc::unique_cf<CGColorSpaceRef> colorSpace(CGColorSpaceCreateDeviceGray());
    REFGUID pixelFormat =
        _CGImageGetWICPixelFormatFromImageProperties(bitsPerComponent, bitsPerPixel, colorSpace.get(), kCGBitmapByteOrderDefault);

    RETURN_NULL_IF_FAILED(
        imageFactory->CreateBitmapFromMemory(width, height, pixelFormat, bytesPerRow, height * bytesPerRow, data, &image));

    CGImageRef imageRef = __CGImage::CreateInstance();
    imageRef->SetImageSource(image).SetIsMask(true).SetInterpolate(shouldInterpolate);

    return imageRef;
}

/**
 @Status Interoperable
*/
CGDataProviderRef CGImageGetDataProvider(CGImageRef img) {
    RETURN_NULL_IF(!img);

    const unsigned int stride = CGImageGetBytesPerRow(img);
    const unsigned int size = CGImageGetHeight(img) * stride;
    woc::unique_iw<unsigned char> data(static_cast<unsigned char*>(IwMalloc(size)));

    RETURN_NULL_IF_FAILED(img->ImageSource()->CopyPixels(nullptr, stride, size, data.get()));

    NSData* byteData = [NSData dataWithBytesNoCopy:data.release() length:size freeWhenDone:YES];
    CGDataProviderRef ret = CGDataProviderCreateWithCFData((CFDataRef)byteData);
    CFAutorelease(ret);
    return ret;
}

/**
 @Status Interoperable
*/
CGColorRenderingIntent CGImageGetRenderingIntent(CGImageRef image) {
    if (!image) {
        return kCGRenderingIntentDefault;
    }

    return image->RenderingIntent();
}

/**
 @Status Interoperable
*/
bool CGImageGetShouldInterpolate(CGImageRef image) {
    RETURN_FALSE_IF(!image);
    return image->Interpolate();
}

/**
 @Status Interoperable
*/
bool CGImageIsMask(CGImageRef image) {
    RETURN_FALSE_IF(!image);
    return image->IsMask();
}

/**
 @Status Interoperable
*/
CGColorSpaceRef CGImageGetColorSpace(CGImageRef img) {
    RETURN_NULL_IF(!img);
    return img->ColorSpace();
}

/**
 @Status Interoperable
*/
CGBitmapInfo CGImageGetBitmapInfo(CGImageRef img) {
    RETURN_RESULT_IF_NULL(img, kCGBitmapByteOrderDefault);
    return img->BitmapInfo();
}

/**
 @Status Interoperable
*/
size_t CGImageGetWidth(CGImageRef img) {
    RETURN_RESULT_IF_NULL(img, 0);
    return img->Width();
}

/**
 @Status Interoperable
*/
size_t CGImageGetHeight(CGImageRef img) {
    RETURN_RESULT_IF_NULL(img, 0);
    return img->Height();
}

/**
 @Status Interoperable
*/
void CGImageRelease(CGImageRef img) {
    RETURN_IF(!img);
    CFRelease((CFTypeRef)img);
}

/**
 @Status Interoperable
*/
CGImageRef CGImageRetain(CGImageRef img) {
    RETURN_NULL_IF(!img);
    CFRetain((CFTypeRef)img);
    return img;
}

/**
 @Status Caveat
 @Notes decode parameter not supported and must be nullptr.
*/
CGImageRef CGImageCreateWithJPEGDataProvider(CGDataProviderRef source,
                                             const CGFloat decode[],
                                             bool shouldInterpolate,
                                             CGColorRenderingIntent intent) {
    RETURN_NULL_IF((source == nullptr) || ![(NSObject*)source isKindOfClass:[NSData class]]);

    NSData* sourceData = (__bridge NSData*)source;
    CGImageRef imageRef = _CGImageLoadJPEG((void*)[sourceData bytes], [sourceData length]);

    RETURN_NULL_IF(!imageRef);
    imageRef->SetInterpolate(shouldInterpolate).SetRenderingIntent(intent);

    return imageRef;
}

/**
 @Status Caveat
 @Notes decode parameter not supported and must be nullptr.
*/
CGImageRef CGImageCreateWithPNGDataProvider(CGDataProviderRef source,
                                            const CGFloat decode[],
                                            bool shouldInterpolate,
                                            CGColorRenderingIntent intent) {
    RETURN_NULL_IF((source == nullptr) || ![(NSObject*)source isKindOfClass:[NSData class]]);

    NSData* sourceData = (__bridge NSData*)source;
    CGImageRef imageRef = _CGImageLoadPNG((void*)[sourceData bytes], [sourceData length]);

    RETURN_NULL_IF(!imageRef);
    imageRef->SetInterpolate(shouldInterpolate).SetRenderingIntent(intent);

    return imageRef;
}

/**
 @Status Interoperable
*/
size_t CGImageGetBitsPerPixel(CGImageRef img) {
    RETURN_RESULT_IF_NULL(img, 0);
    return img->BitsPerPixel();
}

/**
 @Status Interoperable
*/
size_t CGImageGetBitsPerComponent(CGImageRef img) {
    RETURN_RESULT_IF_NULL(img, 0);
    return img->BitsPerComponent();
}

/**
 @Status Interoperable
*/
size_t CGImageGetBytesPerRow(CGImageRef img) {
    RETURN_RESULT_IF_NULL(img, 0);
    return img->BytesPerRow();
}

/**
 @Status Interoperable
*/
CGImageAlphaInfo CGImageGetAlphaInfo(CGImageRef img) {
    RETURN_RESULT_IF_NULL(img, kCGImageAlphaNone);
    return img->AlphaInfo();
}

/**
 @Status Stub
 @Notes
*/
CGImageRef CGImageCreateCopyWithColorSpace(CGImageRef ref, CGColorSpaceRef colorSpace) {
    RETURN_NULL_IF(!ref);
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 */
CGImageRef CGImageCreateWithMask(CGImageRef image, CGImageRef mask) {
    // TODO #1124: Given how masks are applied during rendering via D2D, we will hold onto the
    // mask then apply it at the appropriate time.
    RETURN_NULL_IF(!image);
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
const CGFloat* CGImageGetDecode(CGImageRef image) {
    RETURN_NULL_IF(!image);
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
CGImageRef CGImageCreateWithMaskingColors(CGImageRef image, const CGFloat* components) {
    RETURN_NULL_IF(!image);
    UNIMPLEMENTED();
    return StubReturn();
}

#pragma region WIC_HELPERS

WICPixelFormatGUID _CGImageGetWICPixelFormat(CGImageRef image) {
    RETURN_RESULT_IF_NULL(image, GUID_WICPixelFormatUndefined);
    return image->PixelFormat();
}

bool _CGIsValidRenderTargetPixelFormat(WICPixelFormatGUID pixelFormat) {
    auto iterator = s_ValidRenderTargetPixelFormat.find(pixelFormat);
    return iterator != s_ValidRenderTargetPixelFormat.end();
}

const __CGImagePixelProperties* _CGGetPixelFormatProperties(WICPixelFormatGUID pixelFormat) {
    RETURN_NULL_IF(pixelFormat == GUID_WICPixelFormatUndefined);

    auto iterator = s_PixelFormats.find(pixelFormat);
    RETURN_NULL_IF(iterator == s_PixelFormats.end());

    return &iterator->second;
}

HRESULT _CGImageGetWICImageSource(CGImageRef image, IWICBitmap** source) {
    RETURN_HR_IF_NULL(E_INVALIDARG, image);
    RETURN_HR_IF_NULL(E_POINTER, source);
    *source = image->ImageSource().Get();
    return S_OK;
}

DisplayTexture* _CGImageGetDisplayTexture(CGImageRef image) {
    RETURN_NULL_IF(!image);

    ComPtr<ICGDisplayTexture> displayTextureAccess;
    RETURN_NULL_IF_FAILED(image->ImageSource().Get()->QueryInterface(IID_PPV_ARGS(&displayTextureAccess)));
    RETURN_NULL_IF(!displayTextureAccess);

    IDisplayTexture* displayTexture;
    RETURN_NULL_IF_FAILED(displayTextureAccess->DisplayTexture(&displayTexture));

    return displayTexture->GetTexture();
}

// Return the data pointer to the Image data.
void* _CGImageGetRawBytes(CGImageRef image) {
    RETURN_NULL_IF(!image);
    return image->Data();
}

CGImageRef _CGImageCreateWithWICBitmap(IWICBitmap* bitmap) {
    RETURN_NULL_IF(!bitmap);
    CGImageRef imageRef = __CGImage::CreateInstance();
    imageRef->SetImageSource(bitmap);

    return imageRef;
}

CGImageRef _CGImageCreateCopyWithPixelFormat(CGImageRef image, WICPixelFormatGUID pixelFormat) {
    RETURN_NULL_IF(!image);
    if (IsEqualGUID(image->PixelFormat(), pixelFormat)) {
        CGImageRetain(image);
        return image;
    }

    ComPtr<IWICImagingFactory> imageFactory;
    RETURN_NULL_IF_FAILED(_CGGetWICFactory(&imageFactory));

    ComPtr<IWICFormatConverter> converter;
    RETURN_NULL_IF_FAILED(imageFactory->CreateFormatConverter(&converter));

    RETURN_NULL_IF_FAILED(converter->Initialize(
        image->ImageSource().Get(), pixelFormat, WICBitmapDitherTypeNone, nullptr, 0.f, WICBitmapPaletteTypeMedianCut));

    ComPtr<IWICBitmap> convertedImage;
    RETURN_NULL_IF_FAILED(imageFactory->CreateBitmapFromSource(converter.Get(), WICBitmapCacheOnLoad, &convertedImage));

    CGImageRef imageRef = __CGImage::CreateInstance();
    imageRef->SetImageSource(convertedImage);

    return imageRef;
}

CGImageRef _CGImageGetImageFromData(void* data, int length) {
    return _CGImageLoadImageWithWICDecoder(GUID_NULL, data, length);
}

CGImageRef _CGImageLoadGIF(void* bytes, int length) {
    return _CGImageLoadImageWithWICDecoder(GUID_ContainerFormatGif, bytes, length);
}

CGImageRef _CGImageLoadBMP(void* bytes, size_t length) {
    return _CGImageLoadImageWithWICDecoder(GUID_ContainerFormatBmp, bytes, length);
}

CGImageRef _CGImageLoadTIFF(void* bytes, int length) {
    return _CGImageLoadImageWithWICDecoder(GUID_ContainerFormatTiff, bytes, length);
}

CGImageRef _CGImageLoadPNG(void* bytes, int length) {
    return _CGImageLoadImageWithWICDecoder(GUID_ContainerFormatPng, bytes, length);
}

CGImageRef _CGImageLoadJPEG(void* bytes, int length) {
    return _CGImageLoadImageWithWICDecoder(GUID_ContainerFormatJpeg, bytes, length);
}

CGImageRef _CGImageLoadImageWithWICDecoder(REFGUID decoderCls, void* bytes, int length) {
    ComPtr<IWICImagingFactory> imageFactory;
    RETURN_NULL_IF_FAILED(_CGGetWICFactory(&imageFactory));

    ComPtr<IWICBitmapDecoder> pDecoder;
    ComPtr<IWICStream> spStream;
    RETURN_NULL_IF_FAILED(imageFactory->CreateStream(&spStream));
    RETURN_NULL_IF_FAILED(spStream->InitializeFromMemory(static_cast<unsigned char*>(bytes), length));

    if (!IsEqualGUID(decoderCls, GUID_NULL)) {
        RETURN_NULL_IF_FAILED(imageFactory->CreateDecoder(decoderCls, nullptr, &pDecoder));
        RETURN_NULL_IF_FAILED(pDecoder->Initialize(spStream.Get(), WICDecodeMetadataCacheOnLoad));
    } else {
        RETURN_NULL_IF_FAILED(imageFactory->CreateDecoderFromStream(spStream.Get(), nullptr, WICDecodeMetadataCacheOnDemand, &pDecoder));
    }

    ComPtr<IWICBitmapFrameDecode> bitMapFrameDecoder;
    RETURN_NULL_IF_FAILED(pDecoder->GetFrame(0, &bitMapFrameDecoder));

    ComPtr<IWICBitmap> bitmap;
    RETURN_NULL_IF_FAILED(imageFactory->CreateBitmapFromSource(bitMapFrameDecoder.Get(), WICBitmapCacheOnDemand, &bitmap));

    CGImageRef imageRef = __CGImage::CreateInstance();
    imageRef->SetImageSource(bitmap);
    return imageRef;
}

NSData* _CGImagePNGRepresentation(CGImageRef image) {
    return _CGImageRepresentation(image, GUID_ContainerFormatPng, -1);
}

NSData* _CGImageJPEGRepresentation(CGImageRef image, float quality) {
    return _CGImageRepresentation(image, GUID_ContainerFormatJpeg, quality);
}

NSData* _CGImageRepresentation(CGImageRef image, REFGUID guid, float quality) {
    // TODO #1124 implement encoder.
    return nil;
}

REFGUID _CGImageGetWICPixelFormatFromImageProperties(unsigned int bitsPerComponent,
                                                     unsigned int bitsPerPixel,
                                                     CGColorSpaceRef colorSpace,
                                                     CGBitmapInfo bitmapInfo) {
    CGColorSpaceModel colorSpaceModel = CGColorSpaceGetModel(colorSpace);

    unsigned int alphaInfo = bitmapInfo & kCGBitmapAlphaInfoMask;
    // TODO #1124: support for kCGBitmapFloatComponents and account for ByteOrder
    // TODO #1124: make this more verbose, map?

    if (colorSpaceModel == kCGColorSpaceModelRGB) {
        switch (alphaInfo) {
            case kCGImageAlphaFirst:
            case kCGImageAlphaLast:
                if (bitsPerPixel == 32) {
                    return GUID_WICPixelFormat32bppRGBA;
                } else if (bitsPerPixel == 64) {
                    return GUID_WICPixelFormat64bppRGBA;
                } else {
                    UNIMPLEMENTED_WITH_MSG("kCGImageAlphaLast: Unknown pixelformat: %d", bitsPerPixel);
                    return GUID_WICPixelFormat32bppRGBA;
                }
                break;
            case kCGImageAlphaPremultipliedLast:
            case kCGImageAlphaPremultipliedFirst:
                if (bitsPerPixel == 32) {
                    return GUID_WICPixelFormat32bppPRGBA;
                } else if (bitsPerPixel == 64) {
                    return GUID_WICPixelFormat64bppPRGBA;
                } else {
                    UNIMPLEMENTED_WITH_MSG("kCGImageAlphaPremultipliedFirst: Unknown pixelformat: %d", bitsPerPixel);
                    return GUID_WICPixelFormat32bppPRGBA;
                }
                break;
            case kCGImageAlphaNoneSkipFirst:
            case kCGImageAlphaNoneSkipLast:
            case kCGImageAlphaNone:
                if (bitsPerPixel == 32) {
                    return GUID_WICPixelFormat32bppRGB;
                } else if (bitsPerPixel == 48) {
                    return GUID_WICPixelFormat48bppRGB;
                } else if (bitsPerPixel == 64) {
                    return GUID_WICPixelFormat64bppRGB;
                } else {
                    UNIMPLEMENTED_WITH_MSG("Alpha None: Unknown pixelformat: %d", bitsPerPixel);
                    return GUID_WICPixelFormat32bppRGB;
                }
                break;
            case kCGImageAlphaOnly:
                return GUID_WICPixelFormat8bppAlpha;
                break;
            default:
                UNIMPLEMENTED_WITH_MSG("Unknown pixel format, alphaInfo:%d, assuming RGBA", alphaInfo);
                return GUID_WICPixelFormat32bppRGBA;
                break;
        }
    } else if (colorSpaceModel == kCGColorSpaceModelCMYK) {
        if (bitsPerPixel == 32) {
            return GUID_WICPixelFormat32bppCMYK;
        } else if (bitsPerPixel == 64) {
            return GUID_WICPixelFormat64bppCMYK;
        } else if (bitsPerPixel == 40) {
            return GUID_WICPixelFormat40bppCMYKAlpha;
        } else if (bitsPerPixel == 80) {
            return GUID_WICPixelFormat80bppCMYKAlpha;
        }
    } else if (colorSpaceModel == kCGColorSpaceModelMonochrome) {
        if (bitsPerPixel == 1) {
            return GUID_WICPixelFormatBlackWhite;
        } else if (bitsPerPixel == 4) {
            return GUID_WICPixelFormat4bppGray;
        } else if (bitsPerPixel == 8) {
            return GUID_WICPixelFormat8bppGray;
        } else if (bitsPerPixel == 16) {
            return GUID_WICPixelFormat16bppGray;
        } else if (bitsPerPixel == 32) {
            return GUID_WICPixelFormat32bppGrayFloat;
        }

    } else if (colorSpaceModel == kCGColorSpaceModelIndexed) {
        if (bitsPerPixel == 1) {
            return GUID_WICPixelFormat1bppIndexed;
        } else if (bitsPerPixel == 2) {
            return GUID_WICPixelFormat2bppIndexed;
        } else if (bitsPerPixel == 4) {
            return GUID_WICPixelFormat4bppIndexed;
        } else if (bitsPerPixel == 8) {
            return GUID_WICPixelFormat8bppIndexed;
        }
    }

    return GUID_WICPixelFormat32bppRGBA;
}

#pragma endregion WIC_HELPERS