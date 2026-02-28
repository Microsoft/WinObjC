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

#include "DrawingTest.h"
#include "DrawingTestConfig.h"
#include "ImageHelpers.h"
#include <windows.h>

#include <unordered_map>
#include <vector>
#include <functional>

enum ClippingShape {
    ClippingShapeDiamond = 0x10,
    ClippingShapeSquare = 0x20,
    ClippingShapeRectangle = 0x30,
};

enum ClippingType {
    ClippingTypeMask = 0x0,
    ClippingTypeAlpha = 0x1,
};

template <typename TLambda>
// TLambda is a function of type void(CGContextRef, CGSize, ClippingType).
CGImageRef __CreateClipImage(CGSize size, ClippingType clipType, TLambda&& drawFunction) {
    size_t bitsPerColor = 8;
    size_t componentsPerPixel = clipType == ClippingTypeAlpha ? 4 : 1; // RGBA or G8
    woc::unique_cf<CGColorSpaceRef> colorSpace{ clipType == ClippingTypeAlpha ? CGColorSpaceCreateDeviceRGB() :
                                                                                CGColorSpaceCreateDeviceGray() };

    woc::unique_cf<CGContextRef> bitmapContext{ CGBitmapContextCreate(nullptr,
                                                                      size.width,
                                                                      size.height,
                                                                      8,
                                                                      size.width * componentsPerPixel,
                                                                      colorSpace.get(),
                                                                      componentsPerPixel == 4 ? kCGImageAlphaPremultipliedFirst :
                                                                                                kCGImageAlphaNone) };
    CGContextRef context = bitmapContext.get();

    drawFunction(context, size, clipType);

    woc::unique_cf<CGImageRef> maskImage{ CGBitmapContextCreateImage(context) };

    if (clipType == ClippingTypeMask) {
        maskImage.reset(CGImageMaskCreate(CGImageGetWidth(maskImage.get()),
                                          CGImageGetHeight(maskImage.get()),
                                          CGImageGetBitsPerComponent(maskImage.get()),
                                          CGImageGetBitsPerPixel(maskImage.get()),
                                          CGImageGetBytesPerRow(maskImage.get()),
                                          CGImageGetDataProvider(maskImage.get()),
                                          nullptr,
                                          true));
    }

    return maskImage.release();
}

auto __MakeSquareMaskGenerator(CGAffineTransform transform) {
    // All this work to create a square/diamond with a diamond hole in the middle.
    return [transform](CGContextRef context, CGSize size, ClippingType clipType) {
        if (clipType == ClippingTypeMask) {
            // Since it's a mask, flood it with white.
            CGContextSetRGBFillColor(context, 1.0, 1.0, 1.0, 1.0);
            CGContextFillRect(context, { CGPointZero, size });
        }

        CGContextTranslateCTM(context, size.width / 2.f, size.height / 2.f);
        CGContextConcatCTM(context, transform);
        CGContextTranslateCTM(context, -(size.width / 2.f), -(size.height / 2.f));

        CGContextBeginPath(context);

        // Add a set of nested diamonds and clip to them. They should be anchored at 1/4 and 2/3 of the way through the context,
        // respectively.
        CGContextAddRect(context, { size.width / 4.f, size.height / 4.f, size.width / 2.f, size.height / 2.f });
        CGContextAddRect(context, { size.width * .75 / 2.f, size.height * .75 / 2.f, size.width / 4.f, size.height / 4.f });
        CGContextEOClip(context);

        CGContextSetRGBFillColor(context, 0.5, 0.5, 0.5, clipType == ClippingTypeAlpha ? 0.5 : 1.0);
        CGContextFillRect(context, { CGPointZero, size });

        // Add an additional full-brightness region (the bottom tip of the diamond.)
        CGContextSaveGState(context);
        CGContextAddRect(context, { CGPointZero, size.width / 2.f, size.height / 2.f });
        CGContextClip(context);

        CGContextSetRGBFillColor(context, 0.0, 0.0, 0.0, 1.0);
        CGContextFillRect(context, { CGPointZero, size });
    };
}

void __GradientMaskGenerator(CGContextRef context, CGSize size, ClippingType clipType) {
    for (size_t i = 0; i < 256; ++i) {
        float val = (float)i / 255.f;
        CGContextSetRGBStrokeColor(context, val, val, val, clipType == ClippingTypeAlpha ? (1.0 - val) : 1.0);
        CGPoint line[]{
            { i + .5, 0 }, { i + .5, size.height },
        };
        CGContextStrokeLineSegments(context, line, 2);
    }
}

class CGContextClipping : public ::testing::DrawTest<>,
                          public ::testing::WithParamInterface<::testing::tuple<ClippingShape, ClippingType, CGSize>> {
private:
    static std::vector<std::tuple<ClippingShape, CGSize, std::function<void(CGContextRef, CGSize, ClippingType)>>> s_maskGenerators;

protected:
    CFStringRef CreateOutputFilename() {
        ClippingShape shape = ::testing::get<0>(GetParam());
        ClippingType type = ::testing::get<1>(GetParam());
        const char* shapeName = "unk";
        const char* typeName;
        switch (shape) {
            case ClippingShapeDiamond:
                shapeName = "di";
                break;
            case ClippingShapeSquare:
                shapeName = "sq";
                break;
            case ClippingShapeRectangle:
                shapeName = "rct";
                break;
        }
        switch (type) {
            case ClippingTypeMask:
                typeName = "mask";
                break;
            case ClippingTypeAlpha:
                typeName = "alpha";
                break;
        }
        return CFStringCreateWithFormat(nullptr, nullptr, CFSTR("TestImage.%s.%s.%s.png"), GetTestFullName().c_str(), shapeName, typeName);
    }

    CGImageRef GetClippingImage(ClippingShape shape, ClippingType type) {
        static ClippingType s_clippingTypes[]{
            ClippingTypeAlpha, ClippingTypeMask,
        };
        static std::unordered_map<unsigned int, woc::unique_cf<CGImageRef>> s_clippingImages = []() -> decltype(s_clippingImages) {
            decltype(s_clippingImages) clippingImages;
            for (auto& tpl : s_maskGenerators) {
                for (auto& newType : s_clippingTypes) {
                    ClippingShape newShape = std::get<0>(tpl);
                    woc::unique_cf<CGImageRef> clipImage{ __CreateClipImage(std::get<1>(tpl), newType, std::get<2>(tpl)) };
                    clippingImages.emplace(newShape | newType, std::move(clipImage));
                }
            }
            return std::move(clippingImages);
        }();
        return s_clippingImages.at(shape | type).get();
    }

    void _FillContext() {
        CGContextRef context = GetDrawingContext();
        CGRect bounds = GetDrawingBounds();
        CGContextSetRGBFillColor(context, 0.0, 0.0, 1.0, 1.0);

        CGContextFillRect(context, bounds);
    }
};

std::vector<std::tuple<ClippingShape, CGSize, std::function<void(CGContextRef, CGSize, ClippingType)>>> CGContextClipping::s_maskGenerators{
    { ClippingShapeSquare, CGSize{ 128, 128 }, __MakeSquareMaskGenerator(CGAffineTransformIdentity) },
    { ClippingShapeDiamond, CGSize{ 128, 128 }, __MakeSquareMaskGenerator(CGAffineTransformMakeRotation(45.f * M_PI / 180.f)) },
    { ClippingShapeRectangle, CGSize{ 256, 128 }, __GradientMaskGenerator },
};

DRAW_TEST_P(CGContextClipping, StraightMask) {
    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();
    ClippingShape shape = ::testing::get<0>(GetParam());
    ClippingType type = ::testing::get<1>(GetParam());
    CGSize clipSize = ::testing::get<2>(GetParam());

    CGContextClipToMask(context, _CGRectCenteredOnPoint(clipSize, _CGRectGetCenter(bounds)), GetClippingImage(shape, type));

    _FillContext();
}

DRAW_TEST_P(CGContextClipping, TransformedMask) {
    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();
    ClippingShape shape = ::testing::get<0>(GetParam());
    ClippingType type = ::testing::get<1>(GetParam());
    CGSize clipSize = ::testing::get<2>(GetParam());

    CGContextConcatCTM(context, CGAffineTransformMake(1.0, 0.0, 0.75, 1.0, 0.0, 0.0));

    CGContextClipToMask(context, _CGRectCenteredOnPoint(clipSize, _CGRectGetCenter(bounds)), GetClippingImage(shape, type));

    _FillContext();
}

DRAW_TEST_P(CGContextClipping, StackedMaskSameType) {
    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();
    ClippingShape shape = ::testing::get<0>(GetParam());
    ClippingType type = ::testing::get<1>(GetParam());
    CGSize clipSize = ::testing::get<2>(GetParam());

    ClippingShape otherShape = (shape == ClippingShapeSquare ? ClippingShapeDiamond : ClippingShapeSquare);

    CGContextClipToMask(context, _CGRectCenteredOnPoint(clipSize, _CGRectGetCenter(bounds)), GetClippingImage(shape, type));
    CGContextClipToMask(context, _CGRectCenteredOnPoint(clipSize, _CGRectGetCenter(bounds)), GetClippingImage(otherShape, type));

    _FillContext();
}

DRAW_TEST_P(CGContextClipping, StackedMaskOtherType) {
    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();
    ClippingShape shape = ::testing::get<0>(GetParam());
    ClippingType type = ::testing::get<1>(GetParam());
    CGSize clipSize = ::testing::get<2>(GetParam());

    ClippingShape otherShape = (shape == ClippingShapeSquare ? ClippingShapeDiamond : ClippingShapeSquare);
    ClippingType otherType = (type == ClippingTypeAlpha ? ClippingTypeMask : ClippingTypeAlpha);

    CGContextClipToMask(context, _CGRectCenteredOnPoint(clipSize, _CGRectGetCenter(bounds)), GetClippingImage(shape, type));
    CGContextClipToMask(context, _CGRectCenteredOnPoint(clipSize, _CGRectGetCenter(bounds)), GetClippingImage(otherShape, otherType));

    _FillContext();
}

DRAW_TEST_P(CGContextClipping, MaskedAndClipped) {
    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();
    ClippingShape shape = ::testing::get<0>(GetParam());
    ClippingType type = ::testing::get<1>(GetParam());
    CGSize clipSize = ::testing::get<2>(GetParam());

    CGContextBeginPath(context);
    CGContextAddEllipseInRect(context, _CGRectCenteredOnPoint({ clipSize.width / 2.f, clipSize.height / 2.f }, _CGRectGetCenter(bounds)));
    CGContextEOClip(context);

    CGContextClipToMask(context, _CGRectCenteredOnPoint(clipSize, _CGRectGetCenter(bounds)), GetClippingImage(shape, type));

    _FillContext();
}

INSTANTIATE_TEST_CASE_P(Clipping,
                        CGContextClipping,
                        ::testing::Combine(::testing::Values(ClippingShapeSquare, ClippingShapeDiamond, ClippingShapeRectangle),
                                           ::testing::Values(ClippingTypeMask, ClippingTypeAlpha),
                                           ::testing::Values(CGSize{ 128, 128 }, CGSize{ 128, 256 }, CGSize{ 256, 256 })));

// This image should be completely empty.
DRAW_TEST(CGContextClipping, NonOverlappingImageMasks) {
    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();

    woc::unique_cf<CGImageRef> clipImage{ __CreateClipImage({ 64, 64 },
                                                            ClippingTypeAlpha,
                                                            [](CGContextRef context, CGSize size, ClippingType clipType) {
                                                                CGContextSetRGBFillColor(context, 1.0, 1.0, 1.0, 1.0);
                                                                CGContextFillRect(context, { CGPointZero, size });
                                                            }) };

    CGContextClipToMask(context, { CGPointZero, { 64, 64 } }, clipImage.get());
    CGContextClipToMask(context, { { 0, bounds.size.height - 64 }, { 64, 64 } }, clipImage.get());

    CGContextSetRGBFillColor(context, 0.0, 0.0, 1.0, 1.0);
    CGContextFillRect(context, bounds);
}

// Clip by the same 64x64 image, but shifted 2x2 px.
// The result should be a 62x62 image bounded by the original 64x64 clip with 2x2px to its bottom right.
DRAW_TEST(CGContextClipping, CrossTransformedImageMasks) {
    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();

    woc::unique_cf<CGImageRef> clipImage{ __CreateClipImage({ 64, 64 },
                                                            ClippingTypeAlpha,
                                                            [](CGContextRef context, CGSize size, ClippingType clipType) {
                                                                CGContextSetRGBFillColor(context, 1.0, 1.0, 1.0, 1.0);
                                                                CGContextFillRect(context, { CGPointZero, size });
                                                            }) };

    CGContextClipToMask(context, { CGPointZero, { 64, 64 } }, clipImage.get());
    CGContextTranslateCTM(context, 2.0, 2.0);
    CGContextClipToMask(context, { CGPointZero, { 64, 64 } }, clipImage.get());

    CGContextSetRGBFillColor(context, 0.0, 0.0, 1.0, 1.0);
    CGContextFillRect(context, bounds);
}

DRAW_TEST(CGContextClipping, PushClipPopClip) {
    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();

    woc::unique_cf<CGImageRef> clipImage1{ __CreateClipImage({ 64, 64 },
                                                             ClippingTypeAlpha,
                                                             [](CGContextRef context, CGSize size, ClippingType clipType) {
                                                                 CGContextSetRGBFillColor(context, 1.0, 1.0, 1.0, 0.5);
                                                                 CGContextFillRect(context, { CGPointZero, size });
                                                             }) };

    woc::unique_cf<CGImageRef> clipImage2{ __CreateClipImage({ 64, 64 },
                                                             ClippingTypeAlpha,
                                                             [](CGContextRef context, CGSize size, ClippingType clipType) {
                                                                 CGContextSetRGBFillColor(context, 1.0, 1.0, 1.0, 0.5);
                                                                 CGContextFillEllipseInRect(context, { CGPointZero, size });
                                                             }) };

    CGRect clippingRect{ CGPointZero, { 64, 64 } };
    CGContextClipToMask(context, clippingRect, clipImage1.get());

    CGContextSaveGState(context);

    CGContextClipToMask(context, clippingRect, clipImage2.get());

    // This should draw a 25% alpha circle.
    CGContextSetRGBFillColor(context, 0.0, 0.0, 1.0, 1.0);
    CGContextFillRect(context, bounds);

    CGContextRestoreGState(context);

    // This should draw a 50% alpha square over the circle.
    CGContextSetRGBFillColor(context, 1.0, 0.0, 1.0, 1.0);
    CGContextFillRect(context, bounds);
}

DRAW_TEST(CGContextClipping, ClipDrawClipDraw) {
    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();

    woc::unique_cf<CGImageRef> clipImage1{ __CreateClipImage({ 64, 64 },
                                                             ClippingTypeAlpha,
                                                             [](CGContextRef context, CGSize size, ClippingType clipType) {
                                                                 CGContextSetRGBFillColor(context, 1.0, 1.0, 1.0, 0.5);
                                                                 CGContextFillRect(context, { CGPointZero, size });
                                                             }) };

    woc::unique_cf<CGImageRef> clipImage2{ __CreateClipImage({ 64, 64 },
                                                             ClippingTypeAlpha,
                                                             [](CGContextRef context, CGSize size, ClippingType clipType) {
                                                                 CGContextSetRGBFillColor(context, 1.0, 1.0, 1.0, 0.5);
                                                                 CGContextFillEllipseInRect(context, { CGPointZero, size });
                                                             }) };

    CGRect clippingRect{ CGPointZero, { 64, 64 } };
    CGContextClipToMask(context, clippingRect, clipImage1.get());

    // This should draw a 50% alpha square.
    CGContextSetRGBFillColor(context, 1.0, 1.0, 1.0, 1.0);
    CGContextFillRect(context, bounds);

    CGRect clippingRect2{ { 32, 32 }, { 64, 64 } };
    CGContextClipToMask(context, clippingRect2, clipImage2.get());

    // This should draw a 25% alpha quarter-circle emanating from one corner of the square.
    CGContextSetRGBFillColor(context, 0.0, 1.0, 1.0, 1.0);
    CGContextFillRect(context, bounds);
}

DRAW_TEST(CGContextClipping, ClipATransparencyLayer) {
    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();

    woc::unique_cf<CGImageRef> clipImage{ __CreateClipImage({ 64, 64 },
                                                            ClippingTypeAlpha,
                                                            [](CGContextRef context, CGSize size, ClippingType clipType) {
                                                                CGContextSetRGBFillColor(context, 1.0, 1.0, 1.0, 0.5);
                                                                CGContextFillRect(context, { CGPointZero, size });
                                                            }) };

    CGRect clippingRect{ CGPointZero, { 64, 64 } };
    CGContextClipToMask(context, clippingRect, clipImage.get());

    CGContextBeginTransparencyLayer(context, nullptr);

    // This will draw a 100% alpha blue box.
    CGContextSetRGBFillColor(context, 0.0, 0.0, 1.0, 1.0);
    CGContextFillRect(context, bounds);

    // This should compose down a single 100% alpha blue box at 50% alpha (because of the clip mask).
    // If the clip mask applies twice (wrong) it will be 25%.
    CGContextEndTransparencyLayer(context);
}

DRAW_TEST(CGImage, CreateWithSameSizeMask) {
    auto drawingConfig = DrawingTestConfig::Get();

    woc::unique_cf<CFStringRef> testFilename{ _CFStringCreateWithStdString(drawingConfig->GetResourcePath("jpg1.jpg")) };
    woc::unique_cf<CGImageRef> image{ _CGImageCreateFromJPEGFile(testFilename.get()) };
    ASSERT_NE(nullptr, image);

    CGSize imageSize{ static_cast<CGFloat>(CGImageGetWidth(image.get())), static_cast<CGFloat>(CGImageGetHeight(image.get())) };

    woc::unique_cf<CGImageRef> alphaMask{ __CreateClipImage(imageSize,
                                                            ClippingTypeMask,
                                                            [](CGContextRef context, CGSize size, ClippingType clipType) {
                                                                CGContextSetRGBFillColor(context, 1.0, 1.0, 1.0, 1.0);
                                                                CGContextFillRect(context, { CGPointZero, size });

                                                                CGContextSetRGBStrokeColor(context, 0.0, 0.0, 0.0, 1.0);
                                                                CGContextSetLineWidth(context, 10.0);
                                                                CGContextStrokeRect(context, CGRectInset({ CGPointZero, size }, 20, 20));
                                                            }) };

    ASSERT_NE(nullptr, alphaMask);

    woc::unique_cf<CGImageRef> preMaskedImage{ CGImageCreateWithMask(image.get(), alphaMask.get()) };

    ASSERT_NE(nullptr, preMaskedImage);

    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();

    CGContextDrawImage(context, bounds, preMaskedImage.get());
}

DRAW_TEST(CGImage, CreateWithScaledMask) {
    auto drawingConfig = DrawingTestConfig::Get();

    woc::unique_cf<CFStringRef> testFilename{ _CFStringCreateWithStdString(drawingConfig->GetResourcePath("jpg1.jpg")) };
    woc::unique_cf<CGImageRef> image{ _CGImageCreateFromJPEGFile(testFilename.get()) };
    ASSERT_NE(nullptr, image);

    CGSize imageSize{ static_cast<CGFloat>(CGImageGetWidth(image.get())), static_cast<CGFloat>(CGImageGetHeight(image.get())) };

    woc::unique_cf<CGImageRef> alphaMask{ __CreateClipImage({ 64, 64 },
                                                            ClippingTypeMask,
                                                            [](CGContextRef context, CGSize size, ClippingType clipType) {
                                                                CGContextSetRGBFillColor(context, 1.0, 1.0, 1.0, 1.0);
                                                                CGContextFillRect(context, { CGPointZero, size });

                                                                CGContextSetRGBStrokeColor(context, 0.0, 0.0, 0.0, 1.0);
                                                                CGContextSetLineWidth(context, 4.0);
                                                                CGPoint points[]{
                                                                    { 0, 0 }, { 64, 64 }, { 0, 64 }, { 64, 0 },
                                                                };
                                                                CGContextStrokeLineSegments(context, points, 4);
                                                            }) };

    ASSERT_NE(nullptr, alphaMask);

    woc::unique_cf<CGImageRef> preMaskedImage{ CGImageCreateWithMask(image.get(), alphaMask.get()) };

    ASSERT_NE(nullptr, preMaskedImage);

    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();

    CGContextDrawImage(context, bounds, preMaskedImage.get());
}
