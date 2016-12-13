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

#include "ImageComparison.h"
#include "ImageHelpers.h"

#include <CoreGraphics/CGGeometry.h>
#include <algorithm>
#include <vector>

struct Pixel {
    uint8_t r, g, b, a;
    bool operator==(const Pixel& o) const {
        return r == o.r && g == o.g && g == o.g && a == o.a;
    }
};

struct ImagePixelAccess {
private:
    woc::unique_cf<CGImageRef> _image;
    woc::unique_cf<CFDataRef> _cfData;
    const uint8_t* _data; // view into cfData
    CGBitmapInfo _byteOrder;
    CGImageAlphaInfo _alphaInfo;
    bool _premultiplied;
    bool _alphaFirst;
    bool _alphaSkip;

    static uint8_t unpremultiply(uint8_t val, uint8_t alpha) {
        if (alpha == 0) {
            return 0;
        }
        float fval = (float)val / (float(alpha) / 255.f);
        return std::min((unsigned int)roundf(fval), 255U);
    }

public:
    size_t width;
    size_t height;

    ImagePixelAccess(CGImageRef image)
        : _image(CGImageRetain(image)),
          _cfData(_CFDataCreateFromCGImage(image)),
          _data(reinterpret_cast<const uint8_t*>(CFDataGetBytePtr(_cfData.get()))),
          _alphaInfo(CGImageGetAlphaInfo(image)),
          width(CGImageGetWidth(image)),
          height(CGImageGetHeight(image)) {
        _premultiplied = _alphaInfo == kCGImageAlphaPremultipliedFirst || _alphaInfo == kCGImageAlphaPremultipliedLast;
        _alphaFirst =
            _alphaInfo == kCGImageAlphaPremultipliedFirst || _alphaInfo == kCGImageAlphaFirst || _alphaInfo == kCGImageAlphaNoneSkipFirst;
        _alphaSkip = _alphaInfo == kCGImageAlphaNoneSkipFirst || _alphaInfo == kCGImageAlphaNoneSkipLast;

        CGBitmapInfo bitmapInfo = CGImageGetBitmapInfo(image);
        _byteOrder = bitmapInfo & kCGBitmapByteOrderMask;
        if (_byteOrder == kCGBitmapByteOrderDefault) {
            _byteOrder = kCGBitmapByteOrder32Host;
        }
    }

    Pixel at(size_t x, size_t y) {
        if (_alphaInfo == kCGImageAlphaNone) {
            uint8_t(&rawData)[3] = *(((decltype(&rawData))_data) + (y * width) + x);
            switch (_byteOrder) {
                case kCGBitmapByteOrder32Big:
                    // raw data is B G R
                    return { rawData[2], rawData[1], rawData[0], 255 };
                case kCGBitmapByteOrder32Little:
                    // raw data is R G B
                    return { rawData[0], rawData[1], rawData[2], 255 };
                default:
                    return { 0, 0, 0, 255 };
            }
        } else if (_alphaInfo != kCGImageAlphaOnly) {
            uint8_t(&rawData)[4] = *(((decltype(&rawData))_data) + (y * width) + x);
            Pixel p;
            if (_alphaFirst) {
                switch (_byteOrder) {
                    case kCGBitmapByteOrder32Big:
                        // raw data is B G R A
                        p = { rawData[2], rawData[1], rawData[0], rawData[3] };
                        break;
                    case kCGBitmapByteOrder32Little:
                        // raw data is A R G B
                        p = { rawData[1], rawData[2], rawData[3], rawData[0] };
                        break;
                }
            } else {
                switch (_byteOrder) {
                    case kCGBitmapByteOrder32Big:
                        // raw data is A B G R
                        p = { rawData[3], rawData[2], rawData[1], rawData[0] };
                        break;
                    case kCGBitmapByteOrder32Little:
                        // raw data is R G B A
                        p = { rawData[0], rawData[1], rawData[2], rawData[3] };
                        break;
                }
            }

            if (_alphaSkip) {
                p.a = 255;
            }

            if (_premultiplied) {
                p.r = unpremultiply(p.r, p.a);
                p.g = unpremultiply(p.g, p.a);
                p.b = unpremultiply(p.b, p.a);
            }

            return p;
        } else {
            // Alpha-only images are not supported.
            return { 0, 0, 0, 255 };
        }
    }
};

struct RGBAImageBuffer {
private:
    std::vector<Pixel> _pixels;
    RGBAImageBuffer(const RGBAImageBuffer& other) = delete;

public:
    size_t width;
    size_t height;

    RGBAImageBuffer(size_t width, size_t height) : _pixels(width * height, { 0, 0, 0, 0 }), width(width), height(height) {
    }

    Pixel& at(size_t x, size_t y) {
        return _pixels[(y * width) + x];
    }

    const void* data() const {
        return _pixels.data();
    }

    const size_t len() const {
        return stride() * height;
    };

    const size_t stride() const {
        return width * sizeof(decltype(_pixels[0]));
    }
};

ImageDelta PixelByPixelImageComparator::CompareImages(CGImageRef left, CGImageRef right) {
    if (!left || !right) {
        return { ImageComparisonResult::Incomparable };
    }

    ImagePixelAccess leftAccess{ left };
    ImagePixelAccess rightAccess{ right };

    size_t leftPixelCount = leftAccess.width * leftAccess.height;
    size_t rightPixelCount = rightAccess.width * rightAccess.height;

    if (leftPixelCount != rightPixelCount) {
        return { ImageComparisonResult::Incomparable };
    }

    RGBAImageBuffer deltaBuffer{ leftAccess.width, leftAccess.height };

    // ASSUMPTION: The context draw did not cover the top left pixel;
    // We can use it as the background to detect accidental background deletion and miscomposition.
    Pixel background = leftAccess.at(0, 0);

    size_t npxchg = 0;
    for (off_t y = 0; y < leftAccess.height; ++y) {
        for (off_t x = 0; x < leftAccess.width; ++x) {
            auto bp = leftAccess.at(x, y);
            auto cp = rightAccess.at(x, y);
            auto& gp = deltaBuffer.at(x, y);
            if (!(bp == cp)) {
                ++npxchg;
                if (cp == background) {
                    // Pixel is in EXPECTED but not ACTUAL
                    gp.r = gp.a = 255;
                } else if (bp == background) {
                    // Pixel is in ACTUAL but not EXPECTED
                    gp.g = gp.a = 255;
                } else {
                    // Pixel is in BOTH but DIFFERENT
                    gp.r = gp.g = gp.a = 255;
                }
            } else {
                gp.r = gp.g = gp.b = 0;
                gp.a = 255;
            }
        }
    }

    woc::unique_cf<CFDataRef> deltaData{
        CFDataCreateWithBytesNoCopy(nullptr, reinterpret_cast<const UInt8*>(deltaBuffer.data()), deltaBuffer.len(), kCFAllocatorNull)
    };
    woc::unique_cf<CGDataProviderRef> deltaProvider{ CGDataProviderCreateWithCFData(deltaData.get()) };

    woc::unique_cf<CGImageRef> deltaImage{ CGImageCreate(deltaBuffer.width,
                                                         deltaBuffer.height,
                                                         8,
                                                         32,
                                                         deltaBuffer.stride(),
                                                         CGImageGetColorSpace(left),
                                                         kCGBitmapByteOrder32Little | kCGImageAlphaLast,
                                                         deltaProvider.get(),
                                                         nullptr,
                                                         FALSE,
                                                         kCGRenderingIntentDefault) };

    return {
        (npxchg == 0 ? ImageComparisonResult::Same : ImageComparisonResult::Different), npxchg, deltaImage.get(),
    };
}
