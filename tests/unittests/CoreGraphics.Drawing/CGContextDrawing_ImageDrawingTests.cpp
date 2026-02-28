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

#pragma region TiledImageDrawing
static void _drawTiledImage(CGContextRef context, CGRect rect, const std::string& name) {
    auto drawingConfig = DrawingTestConfig::Get();
    woc::unique_cf<CFStringRef> testFilename{ _CFStringCreateWithStdString(drawingConfig->GetResourcePath(name)) };
    woc::unique_cf<CGImageRef> image{ _CGImageCreateFromPNGFile(testFilename.get()) };
    ASSERT_NE(image, nullptr);
    CGContextDrawTiledImage(context, rect, image.get());
}

DISABLED_DRAW_TEST_F(CGImageDrawing, TiledImageFlower, UIKitMimicTest<>) {
    CGRect rect = { { 0, 0 }, { 128, 128 } };
    _drawTiledImage(GetDrawingContext(), rect, "tiledImageFlower.png");
}

DISABLED_DRAW_TEST_F(CGImageDrawing, TiledImageFlowerScaledUp, UIKitMimicTest<>) {
    CGRect rect = { { 0, 0 }, { 250, 250 } };
    _drawTiledImage(GetDrawingContext(), rect, "tiledImageFlower.png");
}

DISABLED_DRAW_TEST_F(CGImageDrawing, TiledImageFlowerScaledTiny, UIKitMimicTest<>) {
    CGRect rect = { { 0, 0 }, { 1, 1 } };
    _drawTiledImage(GetDrawingContext(), rect, "tiledImageFlower.png");
}

DISABLED_DRAW_TEST_F(CGImageDrawing, TiledImageFlowerScaledAlpha1, UIKitMimicTest<>) {
    CGRect rect = { { 0, 0 }, { 100, 100 } };
    CGContextSetAlpha(GetDrawingContext(), 0.8);
    _drawTiledImage(GetDrawingContext(), rect, "tiledImageFlower.png");
}

DISABLED_DRAW_TEST_F(CGImageDrawing, TiledImageFlowerScaledAlpha2, UIKitMimicTest<>) {
    CGRect rect = { { 0, 0 }, { 256, 256 } };
    CGContextSetAlpha(GetDrawingContext(), 0.24);
    _drawTiledImage(GetDrawingContext(), rect, "tiledImageFlower.png");
}

DISABLED_DRAW_TEST_F(CGImageDrawing, TiledImageFlowerScaledAlpha3, UIKitMimicTest<>) {
    CGRect rect = { { 0, 0 }, { 300, 513 } };
    CGContextSetAlpha(GetDrawingContext(), 0.66);
    _drawTiledImage(GetDrawingContext(), rect, "tiledImageFlower.png");
}

DISABLED_DRAW_TEST_F(CGImageDrawing, TiledImageFlowerScaledDown, UIKitMimicTest<>) {
    CGRect rect = { { 0, 0 }, { 50, 50 } };
    _drawTiledImage(GetDrawingContext(), rect, "tiledImageFlower.png");
}

DISABLED_DRAW_TEST_F(CGImageDrawing, TiledImageFlowerScaled, UIKitMimicTest<>) {
    CGRect rect = { { 0, 0 }, { 250, 128 } };
    _drawTiledImage(GetDrawingContext(), rect, "tiledImageFlower.png");
}

DISABLED_DRAW_TEST_F(CGImageDrawing, TiledImageMultiColorFlower, UIKitMimicTest<>) {
    CGRect rect = { { 0, 0 }, { 256, 256 } };
    _drawTiledImage(GetDrawingContext(), rect, "tiledImageMultiColorFlower.png");
}

DISABLED_DRAW_TEST_F(CGImageDrawing, TiledImageMultiColorFlowerScaledDown, UIKitMimicTest<>) {
    CGRect rect = { { 0, 0 }, { 50, 50 } };
    _drawTiledImage(GetDrawingContext(), rect, "tiledImageMultiColorFlower.png");
}

DISABLED_DRAW_TEST_F(CGImageDrawing, TiledImageMultiColorFlowerScaledUp, UIKitMimicTest<>) {
    CGRect rect = { { 0, 0 }, { 512, 512 } };
    _drawTiledImage(GetDrawingContext(), rect, "tiledImageMultiColorFlower.png");
}

DISABLED_DRAW_TEST_F(CGImageDrawing, TiledImageMultiColorFlowerScaled, UIKitMimicTest<>) {
    CGRect rect = { { 0, 0 }, { 350, 500 } };
    _drawTiledImage(GetDrawingContext(), rect, "tiledImageMultiColorFlower.png");
}

DISABLED_DRAW_TEST_F(CGImageDrawing, TiledImageMultiColorFlowerScaled2, UIKitMimicTest<>) {
    CGRect rect = { { 0, 0 }, { 128, 240 } };
    _drawTiledImage(GetDrawingContext(), rect, "tiledImageMultiColorFlower.png");
}

DISABLED_DRAW_TEST_F(CGImageDrawing, TiledImageMultiColorFlowerScaledAspectRatioWrong, UIKitMimicTest<>) {
    CGRect rect = { { 0, 0 }, { 1024, 25 } };
    _drawTiledImage(GetDrawingContext(), rect, "tiledImageMultiColorFlower.png");
}

DISABLED_DRAW_TEST_F(CGImageDrawing, TiledImageMultiColorFlowerScaledAspectRatio, UIKitMimicTest<>) {
    CGRect rect = { { 0, 0 }, { 1024, 1024 } };
    _drawTiledImage(GetDrawingContext(), rect, "tiledImageMultiColorFlower.png");
}

DISABLED_DRAW_TEST_F(CGImageDrawing, TiledImageMultiColorFlowerScaledAlpha, UIKitMimicTest<>) {
    CGRect rect = { { 0, 0 }, { 100, 100 } };
    CGContextSetAlpha(GetDrawingContext(), 0.8);
    _drawTiledImage(GetDrawingContext(), rect, "tiledImageMultiColorFlower.png");
}

DISABLED_DRAW_TEST_F(CGImageDrawing, TiledImageMultiColorFlowerScaledAlpha2, UIKitMimicTest<>) {
    CGRect rect = { { 0, 0 }, { 256, 256 } };
    CGContextSetAlpha(GetDrawingContext(), 0.24);
    _drawTiledImage(GetDrawingContext(), rect, "tiledImageMultiColorFlower.png");
}

DISABLED_DRAW_TEST_F(CGImageDrawing, TiledImageMultiColorFlowerScaledAlpha3, UIKitMimicTest<>) {
    CGRect rect = { { 0, 0 }, { 300, 513 } };
    CGContextSetAlpha(GetDrawingContext(), 0.66);
    _drawTiledImage(GetDrawingContext(), rect, "tiledImageMultiColorFlower.png");
}

DISABLED_DRAW_TEST_F(CGImageDrawing, TiledImageCustom, UIKitMimicTest<>) {
    CGRect rect = { { 0, 0 }, { 562, 469 } };
    _drawTiledImage(GetDrawingContext(), rect, "tiledImageCircleMe.png");
}

DISABLED_DRAW_TEST_F(CGImageDrawing, TiledImageCustomScaledUp, UIKitMimicTest<>) {
    CGRect rect = { { 0, 0 }, { 2050, 2050 } };
    _drawTiledImage(GetDrawingContext(), rect, "tiledImageCircleMe.png");
}

DISABLED_DRAW_TEST_F(CGImageDrawing, TiledImageCustomScaledDown, UIKitMimicTest<>) {
    CGRect rect = { { 0, 0 }, { 20, 20 } };
    _drawTiledImage(GetDrawingContext(), rect, "tiledImageCircleMe.png");
}

DISABLED_DRAW_TEST_F(CGImageDrawing, TiledImageCustomScaledDownReallyLow, UIKitMimicTest<>) {
    CGRect rect = { { 0, 0 }, { 1, 1 } };
    _drawTiledImage(GetDrawingContext(), rect, "tiledImageCircleMe.png");
}

DISABLED_DRAW_TEST_F(CGImageDrawing, TiledImageCustomScaled, UIKitMimicTest<>) {
    CGRect rect = { { 0, 0 }, { 10, 250 } };
    _drawTiledImage(GetDrawingContext(), rect, "tiledImageCircleMe.png");
}

DISABLED_DRAW_TEST_F(CGImageDrawing, TiledImageCustomScaledObscure, UIKitMimicTest<>) {
    CGRect rect = { { 0, 0 }, { 253, 13 } };
    _drawTiledImage(GetDrawingContext(), rect, "tiledImageCircleMe.png");
}

DISABLED_DRAW_TEST_F(CGImageDrawing, TiledImageCustomScaledAlpha, UIKitMimicTest<>) {
    CGRect rect = { { 0, 0 }, { 128, 128 } };
    CGContextSetAlpha(GetDrawingContext(), 0.88);
    _drawTiledImage(GetDrawingContext(), rect, "tiledImageCircleMe.png");
}
#pragma endregion TiledImageDrawing

#pragma region DrawingToCanvas

#ifdef WINOBJC
#include "CGContextInternal.h"

DISABLED_DRAW_TEST_F(CGImageDrawing, DrawIntoRect, UIKitMimicTest<>) {
    // Draw a portion of an image into a different region.
    auto drawingConfig = DrawingTestConfig::Get();

    woc::unique_cf<CFStringRef> testFilename{ _CFStringCreateWithStdString(drawingConfig->GetResourcePath("png3.9.png")) };
    woc::unique_cf<CGImageRef> image{ _CGImageCreateFromPNGFile(testFilename.get()) };
    ASSERT_NE(image, nullptr);

    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();

    CGAffineTransform flip = CGAffineTransformMakeScale(1, -1);
    CGAffineTransform shift = CGAffineTransformTranslate(flip, 0, bounds.size.height * -1);
    CGContextConcatCTM(context, shift);

    _CGContextDrawImageRect(context,
                            image.get(),
                            { 0, 0, bounds.size.width / 4, bounds.size.height / 4 },
                            { 0, 0, bounds.size.width, bounds.size.height });
}
#endif

DRAW_TEST_F(CGImageDrawing, DrawAnImage, UIKitMimicTest<>) {
    // Load an Image and draw it into the canvas context
    auto drawingConfig = DrawingTestConfig::Get();

    woc::unique_cf<CFStringRef> testFilename{ _CFStringCreateWithStdString(drawingConfig->GetResourcePath("jpg1.jpg")) };
    woc::unique_cf<CGImageRef> image{ _CGImageCreateFromJPEGFile(testFilename.get()) };
    ASSERT_NE(image, nullptr);

    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();

    CGAffineTransform flip = CGAffineTransformMakeScale(1, -1);
    CGAffineTransform shift = CGAffineTransformTranslate(flip, 0, bounds.size.height * -1);
    CGContextConcatCTM(context, shift);

    CGContextDrawImage(context, bounds, image.get());
}

DRAW_TEST_F(CGContext, DrawAnImageWithOpacity, UIKitMimicTest<>) {
    // Load an Image and draw it into the canvas context
    auto drawingConfig = DrawingTestConfig::Get();

    woc::unique_cf<CFStringRef> testFilename{ _CFStringCreateWithStdString(drawingConfig->GetResourcePath("png1.9.png")) };
    woc::unique_cf<CGImageRef> image{ _CGImageCreateFromPNGFile(testFilename.get()) };
    ASSERT_NE(image, nullptr);

    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();

    CGAffineTransform flip = CGAffineTransformMakeScale(1, -1);
    CGAffineTransform shift = CGAffineTransformTranslate(flip, 0, bounds.size.height * -1);
    CGContextConcatCTM(context, shift);

    CGContextSetAlpha(context, 0.7);
    CGContextDrawImage(context, bounds, image.get());
}

DRAW_TEST_F(CGContext, DrawAnImageWithInterpolationQuality, UIKitMimicTest<>) {
    auto drawingConfig = DrawingTestConfig::Get();

    woc::unique_cf<CFStringRef> testFilename{ _CFStringCreateWithStdString(drawingConfig->GetResourcePath("png1.9.png")) };
    woc::unique_cf<CGImageRef> image{ _CGImageCreateFromPNGFile(testFilename.get()) };
    ASSERT_NE(image, nullptr);

    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();

    CGContextSetInterpolationQuality(context, kCGInterpolationLow);
    CGContextDrawImage(context, bounds, image.get());
}

DRAW_TEST_F(CGContext, DrawAnImageWithInterpolationQualityAndAlpha, UIKitMimicTest<>) {
    auto drawingConfig = DrawingTestConfig::Get();
    woc::unique_cf<CFStringRef> testFilename{ _CFStringCreateWithStdString(drawingConfig->GetResourcePath("png1.9.png")) };
    woc::unique_cf<CGImageRef> image{ _CGImageCreateFromPNGFile(testFilename.get()) };
    ASSERT_NE(image, nullptr);

    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();

    CGContextSetAlpha(context, 0.25);
    CGContextSetInterpolationQuality(context, kCGInterpolationHigh);
    CGContextDrawImage(context, bounds, image.get());
}

DRAW_TEST_F(CGImageDrawing, DrawAContextIntoAnImage, UIKitMimicTest<>) {
    // This test will create a bitmap context, draw some entity into the context, then create a image out of the bitmap context.
    // Thereafter it will draw the image into the Canvas context

    static woc::unique_cf<CGColorSpaceRef> rgbColorSpace(CGColorSpaceCreateDeviceRGB());
    // Create a bitmap context to draw the Image into
    woc::unique_cf<CGContextRef> contextImage(CGBitmapContextCreate(
        nullptr, 10, 10, 8, 4 * 10 /* bytesPerRow = bytesPerPixel*width*/, rgbColorSpace.get(), kCGImageAlphaPremultipliedFirst));
    ASSERT_NE(contextImage, nullptr);

    CGContextSetRGBFillColor(contextImage.get(), 1.0, 0.0, 0.0, 1.0);
    CGContextFillRect(contextImage.get(), { 0, 0, 10, 10 });

    // Create the image out of the bitmap context
    woc::unique_cf<CGImageRef> image(CGBitmapContextCreateImage(contextImage.get()));
    ASSERT_NE(image, nullptr);

    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();

    CGAffineTransform flip = CGAffineTransformMakeScale(1, -1);
    CGAffineTransform shift = CGAffineTransformTranslate(flip, 0, bounds.size.height * -1);
    CGContextConcatCTM(context, shift);

    // draw the image
    CGContextDrawImage(context, bounds, image.get());
}
#pragma endregion DrawingToCanvas

#pragma region Interpolation
struct CGNamedInterpolationQuality {
    const char* name;
    CGInterpolationQuality quality;
};

static const CGNamedInterpolationQuality interpolationQualities[]{
    { "None", kCGInterpolationNone },
    { "Low", kCGInterpolationLow },
    { "Medium", kCGInterpolationMedium },
    { "High", kCGInterpolationHigh },
};

class CGContextImageInterpolation : public WhiteBackgroundTest<PixelByPixelImageComparator<>>,
                                    public ::testing::WithParamInterface<CGNamedInterpolationQuality> {
    CFStringRef CreateOutputFilename() {
        const char* qualityName = GetParam().name;
        return CFStringCreateWithFormat(nullptr, nullptr, CFSTR("TestImage.CGContext.ImageInterpolation_%s.png"), qualityName);
    }

public:
    static woc::StrongCF<CGImageRef> s_testImage;
    static void SetUpTestCase() {
        auto drawingConfig = DrawingTestConfig::Get();
        auto testFilename =
            woc::MakeStrongCF<CFStringRef>(_CFStringCreateWithStdString(drawingConfig->GetResourcePath("winobjc_indexed.png")));
        s_testImage.attach(_CGImageCreateFromPNGFile(testFilename, true /* shouldInterpolate */));
    }

    static void TearDownTestCase() {
        s_testImage.attach(nullptr);
    }
};
woc::StrongCF<CGImageRef> CGContextImageInterpolation::s_testImage;

DRAW_TEST_P(CGContextImageInterpolation, Downscale) {
    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();

    CGSize imageSize{
        CGImageGetWidth(s_testImage) / 4.f, CGImageGetHeight(s_testImage) / 4.f,
    };

    CGContextSetInterpolationQuality(context, GetParam().quality);
    CGContextDrawImage(context, _CGRectCenteredOnPoint(imageSize, _CGRectGetCenter(bounds)), s_testImage);
}

INSTANTIATE_TEST_CASE_P(Interpolation, CGContextImageInterpolation, ::testing::ValuesIn(interpolationQualities));
#pragma endregion