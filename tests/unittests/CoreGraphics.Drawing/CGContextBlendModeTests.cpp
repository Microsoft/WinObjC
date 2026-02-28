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

struct CGNamedBlendMode {
    const char* name;
    CGBlendMode blendMode;
};

CGNamedBlendMode pdfBlendModes[] =
    { { "kCGBlendModeMultiply", kCGBlendModeMultiply },     { "kCGBlendModeScreen", kCGBlendModeScreen },
      { "kCGBlendModeDarken", kCGBlendModeDarken },         { "kCGBlendModeLighten", kCGBlendModeLighten },
      { "kCGBlendModeColorBurn", kCGBlendModeColorBurn },   { "kCGBlendModeColorDodge", kCGBlendModeColorDodge },
      { "kCGBlendModeOverlay", kCGBlendModeOverlay },       { "kCGBlendModeSoftLight", kCGBlendModeSoftLight },
      { "kCGBlendModeHardLight", kCGBlendModeHardLight },   { "kCGBlendModeDifference", kCGBlendModeDifference },
      { "kCGBlendModeExclusion", kCGBlendModeExclusion },   { "kCGBlendModeHue", kCGBlendModeHue },
      { "kCGBlendModeSaturation", kCGBlendModeSaturation }, { "kCGBlendModeColor", kCGBlendModeColor },
      { "kCGBlendModeLuminosity", kCGBlendModeLuminosity } };

CGNamedBlendMode blendOperators[] = { { "kCGBlendModeClear", kCGBlendModeClear } };

CGNamedBlendMode compositionModesWithoutPlusDarker[] = {
    { "kCGBlendModeNormal", kCGBlendModeNormal },
    { "kCGBlendModeDestinationOver", kCGBlendModeDestinationOver },
    { "kCGBlendModeSourceIn", kCGBlendModeSourceIn },
    { "kCGBlendModeDestinationIn", kCGBlendModeDestinationIn },
    { "kCGBlendModeSourceOut", kCGBlendModeSourceOut },
    { "kCGBlendModeDestinationOut", kCGBlendModeDestinationOut },
    { "kCGBlendModeSourceAtop", kCGBlendModeSourceAtop },
    { "kCGBlendModeDestinationAtop", kCGBlendModeDestinationAtop },
    { "kCGBlendModeXOR", kCGBlendModeXOR },
    { "kCGBlendModePlusLighter", kCGBlendModePlusLighter },
    { "kCGBlendModeCopy", kCGBlendModeCopy },
};

CGNamedBlendMode compositionModes[] = {
    { "kCGBlendModeNormal", kCGBlendModeNormal },
    { "kCGBlendModeDestinationOver", kCGBlendModeDestinationOver },
    { "kCGBlendModeSourceIn", kCGBlendModeSourceIn },
    { "kCGBlendModeDestinationIn", kCGBlendModeDestinationIn },
    { "kCGBlendModeSourceOut", kCGBlendModeSourceOut },
    { "kCGBlendModeDestinationOut", kCGBlendModeDestinationOut },
    { "kCGBlendModeSourceAtop", kCGBlendModeSourceAtop },
    { "kCGBlendModeDestinationAtop", kCGBlendModeDestinationAtop },
    { "kCGBlendModeXOR", kCGBlendModeXOR },
    { "kCGBlendModePlusLighter", kCGBlendModePlusLighter },
    { "kCGBlendModeCopy", kCGBlendModeCopy },
    { "kCGBlendModePlusDarker", kCGBlendModePlusDarker },
};

static void __drawLeftStack(CGContextRef context, CGRect bounds, int variant = 0) {
    CGFloat unitHeight = bounds.size.height / 4.f;

    CGRect cursor = _CGRectCenteredOnPoint({ 2.f * bounds.size.width / 3.f, unitHeight },
                                           { bounds.origin.x + (bounds.size.width / 3.f), bounds.origin.y + (unitHeight / 2.f) });

    CGContextSaveGState(context);
    CGContextSetRGBFillColor(context, .25, .71, .95, 1.0);
    if (variant == 0) {
        // variant 0 = blue lines, blue boxes; variant 1 = dark red lines, blue boxes.
        // This lets us test "lighten" more effectively.
        CGContextSetRGBStrokeColor(context, .25, .71, .95, 1.0);
    } else {
        CGContextSetRGBStrokeColor(context, .45, 0, 0, 1.0);
    }

    CGContextFillRect(context, cursor);
    cursor.origin.y += unitHeight;
    CGContextMoveToPoint(context, CGRectGetMinX(cursor), CGRectGetMinY(cursor));
    CGContextAddLineToPoint(context, CGRectGetMaxX(cursor), CGRectGetMaxY(cursor));
    CGContextStrokePath(context);
    cursor.origin.y += unitHeight;

    CGContextSetRGBFillColor(context, .25, .71, .95, 0.5);
    if (variant == 0) {
        CGContextSetRGBStrokeColor(context, .25, .71, .95, 0.5);
    } else {
        CGContextSetRGBStrokeColor(context, .45, 0, 0, 0.5);
    }

    CGContextFillRect(context, cursor);
    cursor.origin.y += unitHeight;
    CGContextMoveToPoint(context, CGRectGetMinX(cursor), CGRectGetMinY(cursor));
    CGContextAddLineToPoint(context, CGRectGetMaxX(cursor), CGRectGetMaxY(cursor));
    CGContextStrokePath(context);
    CGContextRestoreGState(context);
}

static void __drawRightStackPink(CGContextRef context, CGRect bounds) {
    CGFloat unitHeight = bounds.size.height / 4.f;

    CGRect cursor = _CGRectCenteredOnPoint({ 2.f * bounds.size.width / 3.f, unitHeight },
                                           { bounds.origin.x + (2.f * bounds.size.width / 3.f), bounds.origin.y + (unitHeight / 2.f) });

    CGContextSaveGState(context);
    CGContextSetRGBFillColor(context, .95, .25, .66, 1.0);
    CGContextSetRGBStrokeColor(context, .95, .25, .66, 1.0);

    CGContextFillRect(context, cursor);
    cursor.origin.y += unitHeight;
    CGContextMoveToPoint(context, CGRectGetMinX(cursor), CGRectGetMaxY(cursor));
    CGContextAddLineToPoint(context, CGRectGetMaxX(cursor), CGRectGetMinY(cursor));
    CGContextStrokePath(context);
    cursor.origin.y += unitHeight;

    CGContextSetRGBFillColor(context, .95, .25, .66, 0.5);
    CGContextSetRGBStrokeColor(context, .95, .25, .66, 0.5);

    CGContextFillRect(context, cursor);
    cursor.origin.y += unitHeight;
    CGContextMoveToPoint(context, CGRectGetMinX(cursor), CGRectGetMaxY(cursor));
    CGContextAddLineToPoint(context, CGRectGetMaxX(cursor), CGRectGetMinY(cursor));
    CGContextStrokePath(context);

    CGContextRestoreGState(context);
}

class CGContextBlendMode : public WhiteBackgroundTest<PixelByPixelImageComparator<PixelComparisonModeDifferenceLimen<100>>>,
                           public ::testing::WithParamInterface<::testing::tuple<bool, CGNamedBlendMode>> {
    CFStringRef CreateOutputFilename() {
        const char* blendModeName = ::testing::get<1>(GetParam()).name;
        bool useTransparencyLayer = ::testing::get<0>(GetParam());
        return CFStringCreateWithFormat(nullptr,
                                        nullptr,
                                        CFSTR("TestImage.CGContext.Blending_%s%s.png"),
                                        useTransparencyLayer ? "Layered_" : "",
                                        blendModeName);
    }
};

DRAW_TEST_P(CGContextBlendMode, OverlappedRects) {
    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();
    CGBlendMode blendMode = ::testing::get<1>(GetParam()).blendMode;
    bool useTransparencyLayer = ::testing::get<0>(GetParam());

    bounds = CGRectInset(bounds, 8.f, 8.f);

    CGContextSetLineWidth(context, 6.0f);

    __drawLeftStack(context, bounds);

    CGContextSetBlendMode(context, blendMode);

    if (useTransparencyLayer) {
        CGContextBeginTransparencyLayer(context, nullptr);
    }

    __drawRightStackPink(context, bounds);

    if (useTransparencyLayer) {
        CGContextEndTransparencyLayer(context);
    }
}

// Disabled: layered = false; not supported. plus darker; not supported.
DISABLED_INSTANTIATE_TEST_CASE_P(CompositionModes,
                                 CGContextBlendMode,
                                 ::testing::Combine(::testing::Values(true), ::testing::ValuesIn(compositionModesWithoutPlusDarker)),
                                 ::testing::Combine(::testing::Values(false), ::testing::ValuesIn(compositionModes)));

INSTANTIATE_TEST_CASE_P(AdobePDFBlendModes,
                        CGContextBlendMode,
                        ::testing::Combine(::testing::Values(false, true), ::testing::ValuesIn(pdfBlendModes)));

#if 0
// Disabled: there is no supported configuration of this test, so we cannot fulfill the requirement
// that DISABLED_INSTANTIATE_TEST_CASE_P have a set of "enabled" values.
INSTANTIATE_TEST_CASE_P(OperatorBlendModes,
                        CGContextBlendMode,
                        ::testing::Combine(::testing::Values(false, true), ::testing::ValuesIn(blendOperators)));
#endif

class CGContextBlendModeImage : public WhiteBackgroundTest<PixelByPixelImageComparator<PixelComparisonModeDifferenceLimen<100>>>,
                                public ::testing::WithParamInterface<CGNamedBlendMode> {
    CFStringRef CreateOutputFilename() {
        const char* blendModeName = GetParam().name;
        // This works around the fact that TAEF cannot give us test case names.
        // We have to divine them from the test full name. :(
        auto testFullName = GetTestFullName();
        bool source = (testFullName.find("ImageAsSource", 0) != std::string::npos);
        return CFStringCreateWithFormat(nullptr,
                                        nullptr,
                                        CFSTR("TestImage.CGContext.Blending_Image%s_%s.png"),
                                        source ? "Source" : "Destination",
                                        blendModeName);
    }

public:
    static woc::StrongCF<CGImageRef> s_testImage;
    static void SetUpTestCase() {
        auto drawingConfig = DrawingTestConfig::Get();
        auto testFilename = woc::MakeStrongCF<CFStringRef>(_CFStringCreateWithStdString(drawingConfig->GetResourcePath("winobjc.png")));
        s_testImage.attach(_CGImageCreateFromPNGFile(testFilename));
    }

    static void TearDownTestCase() {
        s_testImage.attach(nullptr);
    }
};
woc::StrongCF<CGImageRef> CGContextBlendModeImage::s_testImage;

DRAW_TEST_P(CGContextBlendModeImage, ImageAsSource) {
    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();
    CGBlendMode blendMode = GetParam().blendMode;

    bounds = CGRectInset(bounds, 8.f, 8.f);

    CGContextSetLineWidth(context, 6.0f);

    __drawLeftStack(context, bounds, 1);

    CGContextSetBlendMode(context, blendMode);

    CGContextDrawImage(context, GetDrawingBounds(), s_testImage);
}

DRAW_TEST_P(CGContextBlendModeImage, ImageAsDestination) {
    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();
    CGBlendMode blendMode = GetParam().blendMode;

    bounds = CGRectInset(bounds, 8.f, 8.f);

    CGContextSetLineWidth(context, 6.0f);

    CGContextDrawImage(context, GetDrawingBounds(), s_testImage);

    CGContextSetBlendMode(context, blendMode);

    CGContextBeginTransparencyLayer(context, nullptr);
    __drawRightStackPink(context, bounds);
    CGContextEndTransparencyLayer(context);
}

INSTANTIATE_TEST_CASE_P(CompositionModes, CGContextBlendModeImage, ::testing::ValuesIn(compositionModesWithoutPlusDarker));

INSTANTIATE_TEST_CASE_P(AdobePDFBlendModes, CGContextBlendModeImage, ::testing::ValuesIn(pdfBlendModes));
