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

#pragma region Stencil Pattern

static void drawStencilStar(void* info, CGContextRef context) {
    double r = 0.8 * 16 / 2;
    double theta = 2 * M_PI * (2.0 / 5.0); // 144 degrees

    CGContextTranslateCTM(context, 16 / 2, 16 / 2);

    CGContextMoveToPoint(context, 0, r);
    for (int i = 1; i < 5; i++) {
        CGContextAddLineToPoint(context, r * sin(i * theta), r * cos(i * theta));
    }
    CGContextClosePath(context);
    CGContextFillPath(context);
}

static void drawStencilBox(void* info, CGContextRef context) {
    CGContextFillRect(context, CGRectMake(0, 0, 8, 8));
}

struct PatternCallback {
    const char* name;
    CGPatternDrawPatternCallback callback;
};

struct StencilColor {
    const char* name;
    CGFloat color[4];
};

PatternCallback stencilPatternCallback[] = { { "drawStencilStar", &drawStencilStar }, { "drawStencilBox", &drawStencilBox } };

StencilColor stencilColors[] = { { "red", { 1, 0, 0, 1 } }, { "teal", { 0, 0.5, 0.5, 1 } }, { "purple", { 0.5, 0, 0.5, 1 } } };

int patternsizes[] = { 16, 20, 32 };

//<PatternCallback,StencilColor,pattern size>
class CGPatternStencil : public WhiteBackgroundTest<>,
                         public ::testing::WithParamInterface<::testing::tuple<PatternCallback, StencilColor, int>> {
    CFStringRef CreateOutputFilename() {
        PatternCallback stencil = ::testing::get<0>(GetParam());
        StencilColor stencilColor = ::testing::get<1>(GetParam());
        int size = ::testing::get<2>(GetParam());

        return CFStringCreateWithFormat(nullptr,
                                        nullptr,
                                        CFSTR("TestImage.CGContext.CGPatternStencil.%s.%s.%d.png"),
                                        stencil.name,
                                        stencilColor.name,
                                        size);
    }
};

TEST_P(CGPatternStencil, DrawStencils) {
    CGPatternDrawPatternCallback callback = ::testing::get<0>(GetParam()).callback;
    const CGFloat* stencilColor = ::testing::get<1>(GetParam()).color;
    int size = ::testing::get<2>(GetParam());

    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();

    static const CGPatternCallbacks callbacks = { 0, callback, NULL };

    CGColorSpaceRef baseSpace = CGColorSpaceCreateDeviceRGB();
    CGColorSpaceRef patternSpace = CGColorSpaceCreatePattern(baseSpace);
    CGContextSetFillColorSpace(context, patternSpace);
    CGColorSpaceRelease(patternSpace);
    CGColorSpaceRelease(baseSpace);

    CGPatternRef pattern = CGPatternCreate(
        NULL, CGRectMake(0, 0, size, size), CGAffineTransformIdentity, size, size, kCGPatternTilingConstantSpacing, false, &callbacks);

    CGContextSetFillPattern(context, pattern, stencilColor);
    CGPatternRelease(pattern);
    CGContextFillRect(context, bounds);
}

INSTANTIATE_TEST_CASE_P(CGPatternTests,
                        CGPatternStencil,
                        ::testing::Combine(::testing::ValuesIn(stencilPatternCallback),
                                           ::testing::ValuesIn(stencilColors),
                                           ::testing::ValuesIn(patternsizes)));

#pragma endregion Stencil Pattern

#pragma region Colored Pattern

void drawColoredPatternMultiSquare(void* info, CGContextRef context) {
    CGFloat subunit = 5; // the pattern cell itself is 16 by 18

    CGRect myRect1 = { { 0, 0 }, { subunit, subunit } };
    CGRect myRect2 = { { subunit, subunit }, { subunit, subunit } };
    CGRect myRect3 = { { 0, subunit }, { subunit, subunit } };
    CGRect myRect4 = { { subunit, 0 }, { subunit, subunit } };

    CGContextSetRGBFillColor(context, 0, 0, 1, 0.5);
    CGContextFillRect(context, myRect1);
    CGContextSetRGBFillColor(context, 1, 0, 0, 0.5);
    CGContextFillRect(context, myRect2);
    CGContextSetRGBFillColor(context, 0, 1, 0, 0.5);
    CGContextFillRect(context, myRect3);
    CGContextSetRGBFillColor(context, .5, 0, .5, 0.5);
    CGContextFillRect(context, myRect4);
}

PatternCallback ColoredPatternCallback[] = { { "drawColoredPatternMultiSquare", &drawColoredPatternMultiSquare } };

//<PatternCallback,alpha,pattern size>
class CGPatternColored : public WhiteBackgroundTest<>,
                         public ::testing::WithParamInterface<::testing::tuple<PatternCallback, CGFloat, int>> {
    CFStringRef CreateOutputFilename() {
        PatternCallback pattern = ::testing::get<0>(GetParam());
        CGFloat alpha = ::testing::get<1>(GetParam());
        int size = ::testing::get<2>(GetParam());

        return CFStringCreateWithFormat(nullptr,
                                        nullptr,
                                        CFSTR("TestImage.CGContext.CGPatternColored.%s.size.%d.A%1.01f.png"),
                                        pattern.name,
                                        size,
                                        alpha);
    }
};

TEST_P(CGPatternColored, ColoredSquare) {
    CGPatternDrawPatternCallback callback = ::testing::get<0>(GetParam()).callback;
    CGFloat alpha = ::testing::get<1>(GetParam());
    int size = ::testing::get<2>(GetParam());

    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();
    static const CGPatternCallbacks callbacks = { 0, callback, NULL };

    CGColorSpaceRef patternSpace = CGColorSpaceCreatePattern(NULL);
    CGContextSetFillColorSpace(context, patternSpace);
    CGColorSpaceRelease(patternSpace);

    CGPatternRef pattern = CGPatternCreate(NULL,
                                           CGRectMake(0, 0, size / 2, size / 2),
                                           CGAffineTransformMake(1, 0, 0, 1, 0, 0),
                                           size,
                                           size,
                                           kCGPatternTilingConstantSpacing,
                                           true,
                                           &callbacks);

    CGContextSetFillPattern(context, pattern, &alpha);
    CGPatternRelease(pattern);
    CGContextFillRect(context, bounds);
}

static CGFloat alphas[] = { 0.25f, 0.5f, 1.f };

INSTANTIATE_TEST_CASE_P(CGPatternTests,
                        CGPatternColored,
                        ::testing::Combine(::testing::ValuesIn(ColoredPatternCallback),
                                           ::testing::ValuesIn(alphas),
                                           ::testing::ValuesIn(patternsizes)));

static void drawPatternWindowsLogo(void* info, CGContextRef context) {
    CGContextSetRGBFillColor(context, 0.96, 0.32, 0.07, 1);
    CGContextFillRect(context, CGRectMake(0, 0, 50, 50));

    CGContextSetRGBFillColor(context, 0, 0.63, 0.94, 1);
    CGContextFillRect(context, CGRectMake(0, 50, 50, 50));

    CGContextSetRGBFillColor(context, 0.48, 0.73, 0, 1);
    CGContextFillRect(context, CGRectMake(50, 50, 50, 50));

    CGContextSetRGBFillColor(context, 1, 0.73, 0, 1);
    CGContextFillRect(context, CGRectMake(50, 0, 50, 50));
}

static void _SetPatternForStroke(
    CGContextRef context, CGRect rect, float xStep, float yStep, CGPatternDrawPatternCallback drawpattern, CGFloat alpha) {
    CGPatternCallbacks coloredPatternCallbacks = { 0, drawpattern, NULL };

    woc::unique_cf<CGPatternRef> pattern{
        CGPatternCreate(NULL, rect, CGAffineTransformIdentity, xStep, yStep, kCGPatternTilingNoDistortion, true, &coloredPatternCallbacks)
    };

    woc::unique_cf<CGColorSpaceRef> patternColorSpace{ CGColorSpaceCreatePattern(NULL) };

    CGContextSetStrokeColorSpace(context, patternColorSpace.get());

    CGContextSetStrokePattern(context, pattern.get(), &alpha);
}

static void _SetPatternForFill(
    CGContextRef context, CGRect rect, float xStep, float yStep, CGPatternDrawPatternCallback drawpattern, CGFloat alpha) {
    CGPatternCallbacks coloredPatternCallbacks = { 0, drawpattern, NULL };

    woc::unique_cf<CGPatternRef> pattern{
        CGPatternCreate(NULL, rect, CGAffineTransformIdentity, xStep, yStep, kCGPatternTilingNoDistortion, true, &coloredPatternCallbacks)
    };

    woc::unique_cf<CGColorSpaceRef> patternColorSpace{ CGColorSpaceCreatePattern(NULL) };

    CGContextSetFillColorSpace(context, patternColorSpace.get());

    CGContextSetFillPattern(context, pattern.get(), &alpha);
}

//<PatternCallback,alpha,xstep,ystep,rect>
class CGPatternColoredRectBasedStroke
    : public WhiteBackgroundTest<>,
      public ::testing::WithParamInterface<::testing::tuple<PatternCallback, CGFloat, float, float, CGRect>> {
    CFStringRef CreateOutputFilename() {
        PatternCallback pattern = ::testing::get<0>(GetParam());
        CGFloat alpha = ::testing::get<1>(GetParam());
        float xStep = ::testing::get<2>(GetParam());
        float yStep = ::testing::get<3>(GetParam());
        CGRect rect = ::testing::get<4>(GetParam());
        return CFStringCreateWithFormat(nullptr,
                                        nullptr,
                                        CFSTR("TestImage.CGContext.CGPatternColoredRectBasedStroke.%s.rect.(%0.0f.%0.0f)%0.0fx%0.0f.xStep.%"
                                              ".02f.yStep.%.02f.alpha%.02f.png"),
                                        pattern.name,
                                        rect.origin.x,
                                        rect.origin.y,
                                        rect.size.width,
                                        rect.size.height,
                                        xStep,
                                        yStep,
                                        alpha);
    }
};

TEST_P(CGPatternColoredRectBasedStroke, PatternStrokeRegion) {
    PatternCallback pattern = ::testing::get<0>(GetParam());
    CGFloat alpha = ::testing::get<1>(GetParam());
    float xStep = ::testing::get<2>(GetParam());
    float yStep = ::testing::get<3>(GetParam());
    CGRect rect = ::testing::get<4>(GetParam());

    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();

    _SetPatternForStroke(context, rect, xStep, yStep, pattern.callback, alpha);
    CGRect borderRect = CGRectInset(bounds, 30, 50);
    CGContextSetLineWidth(context, 45);
    CGContextStrokeRect(context, borderRect);
}

static CGRect tileRects[] = { CGRectMake(0, 0, 100, 100), CGRectNull };
static float tileSteps[] = { 100, 50 };

PatternCallback squaredPatternCallbacks[] = { { "drawStencilStar", &drawStencilStar },
                                              { "drawPatternWindowsLogo", &drawPatternWindowsLogo } };
INSTANTIATE_TEST_CASE_P(CGPatternTests,
                        CGPatternColoredRectBasedStroke,
                        ::testing::Combine(::testing::ValuesIn(squaredPatternCallbacks),
                                           ::testing::ValuesIn(alphas),
                                           ::testing::ValuesIn(tileSteps),
                                           ::testing::ValuesIn(tileSteps),
                                           ::testing::ValuesIn(tileRects)));

//<PatternCallback,alpha,xstep,ystep,rect>
class CGPatternColoredRectBasedFill
    : public WhiteBackgroundTest<>,
      public ::testing::WithParamInterface<::testing::tuple<PatternCallback, CGFloat, float, float, CGRect>> {
    CFStringRef CreateOutputFilename() {
        PatternCallback pattern = ::testing::get<0>(GetParam());
        CGFloat alpha = ::testing::get<1>(GetParam());
        float xStep = ::testing::get<2>(GetParam());
        float yStep = ::testing::get<3>(GetParam());
        CGRect rect = ::testing::get<4>(GetParam());
        char rectDesc[100];
        snprintf(rectDesc, sizeof(rectDesc), "(%0.0f.%0.0f)%0.0fx%0.0f", rect.origin.x, rect.origin.y, rect.size.width, rect.size.height);
        return CFStringCreateWithFormat(
            nullptr,
            nullptr,
            CFSTR("TestImage.CGContext.CGPatternColoredRectBasedFill.%s.rect.%s.xStep.%.02f.yStep.%.02f.alpha%.02f.png"),
            pattern.name,
            rectDesc,
            xStep,
            yStep,
            alpha);
    }
};

TEST_P(CGPatternColoredRectBasedFill, PatternFillRegion) {
    PatternCallback pattern = ::testing::get<0>(GetParam());
    CGFloat alpha = ::testing::get<1>(GetParam());
    float xStep = ::testing::get<2>(GetParam());
    float yStep = ::testing::get<3>(GetParam());
    CGRect rect = ::testing::get<4>(GetParam());

    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();

    _SetPatternForFill(context, rect, yStep, 100, pattern.callback, alpha);
    CGContextFillRect(context, bounds);
}

INSTANTIATE_TEST_CASE_P(CGPatternTests,
                        CGPatternColoredRectBasedFill,
                        ::testing::Combine(::testing::ValuesIn(squaredPatternCallbacks),
                                           ::testing::ValuesIn(alphas),
                                           ::testing::ValuesIn(tileSteps),
                                           ::testing::ValuesIn(tileSteps),
                                           ::testing::ValuesIn(tileRects)));

DISABLED_DRAW_TEST_F(CGPatternTests, PatternFillWindowsLogoPath, UIKitMimicTest<>) {
    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();

    _SetPatternForFill(context, CGRectMake(0, 0, 100, 100), 100, 100, drawPatternWindowsLogo, 1);

    CGMutablePathRef thepath = CGPathCreateMutable();
    CGPathMoveToPoint(thepath, NULL, 30, 100);
    CGPathAddCurveToPoint(thepath, NULL, 47.0f, 67.0f, 50.0f, 55.0f, 45.0f, 50.0f);
    CGPathAddCurveToPoint(thepath, NULL, 42.0f, 47.0f, 37.0f, 46.0f, 30.0f, 55.0f);

    CGPathAddCurveToPoint(thepath, NULL, 23.0f, 46.0f, 18.0f, 47.0f, 15.0f, 50.0f);
    CGPathAddCurveToPoint(thepath, NULL, 10.0f, 55.0f, 13.0f, 67.0f, 30.0f, 100.0f);

    CGPathCloseSubpath(thepath);
    CGContextAddPath(context, thepath);
    CGContextFillPath(context);
    CGPathRelease(thepath);
}

DRAW_TEST_F(CGPatternTests, PatternDrawPath, WhiteBackgroundTest<>) {
    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();

    CGMutablePathRef theFirstPath = CGPathCreateMutable();
    CGMutablePathRef theSecondPath = CGPathCreateMutable();

    CGPathMoveToPoint(theFirstPath, NULL, 200, 35);
    CGPathAddLineToPoint(theFirstPath, NULL, 165, 100);
    CGPathAddLineToPoint(theFirstPath, NULL, 100, 100);
    CGPathAddLineToPoint(theFirstPath, NULL, 150, 150);
    CGPathAddLineToPoint(theFirstPath, NULL, 135, 225);
    CGPathAddLineToPoint(theFirstPath, NULL, 200, 170);
    CGPathAddLineToPoint(theFirstPath, NULL, 265, 225);

    CGPathMoveToPoint(theSecondPath, NULL, 265, 225);

    CGPathAddLineToPoint(theSecondPath, NULL, 350, 225);
    CGPathAddLineToPoint(theSecondPath, NULL, 350, 35);
    CGPathAddLineToPoint(theSecondPath, NULL, 200, 35);

    CGPathAddPath(theFirstPath, NULL, theSecondPath);
    CGContextAddPath(context, theFirstPath);

    CGContextClosePath(context);

    CGContextSetLineWidth(context, 30);
    _SetPatternForFill(context, CGRectMake(0, 0, 100, 100), 100, 100, drawPatternWindowsLogo, 1);

    CGContextDrawPath(context, kCGPathEOFillStroke);
    CGPathRelease(theFirstPath);
    CGPathRelease(theSecondPath);
}

static void drawCoolStar(void* info, CGContextRef context) {
    // Back color
    CGContextSetRGBFillColor(context, 0.96, 0.32, 0.07, 1);
    CGContextFillRect(context, CGRectMake(0, 0, 50, 50));

    CGContextSetRGBFillColor(context, 0, 0.63, 0.94, 1);
    CGContextFillRect(context, CGRectMake(0, 50, 50, 50));

    CGContextSetRGBFillColor(context, 0.48, 0.73, 0, 1);
    CGContextFillRect(context, CGRectMake(50, 50, 50, 50));

    CGContextSetRGBFillColor(context, 1, 0.73, 0, 1);
    CGContextFillRect(context, CGRectMake(50, 0, 50, 50));

    double r = 0.8 * 50 / 2;
    double theta = 2 * M_PI * (2.0 / 5.0); // 144 degrees

    CGContextTranslateCTM(context, 50 / 2, 50 / 2);

    CGContextMoveToPoint(context, 0, r);
    for (int i = 1; i < 6; i++) {
        CGContextAddLineToPoint(context, r * sin(i * theta), r * cos(i * theta));
    }
    CGContextClosePath(context);
    CGContextFillPath(context);

    // clipping & arc
    CGRect cirleRect = CGRectMake(0, 0, 50, 25);
    CGContextClip(context);
    CGContextClearRect(context, cirleRect);
}

DRAW_TEST_F(CGPatternTests, PatternFillTransformationWindowsLogoNoneWhiteBackground, WhiteBackgroundTest<>) {
    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();
    _SetPatternForFill(context, CGRectMake(0, 0, 100, 100), 100, 100, drawCoolStar, 1);

    CGContextFillRect(context, bounds);
}

DRAW_TEST_F(CGPatternTests, PatternFillTransformationWindowsLogoRotateWhiteBackground, WhiteBackgroundTest<>) {
    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();
    CGContextRotateCTM(context, 0.4);
    _SetPatternForFill(context, CGRectMake(0, 0, 100, 100), 100, 100, drawCoolStar, 1);

    CGContextFillRect(context, bounds);
}

DRAW_TEST_F(CGPatternTests, PatternFillTransformationWindowsLogoTranslateWhiteBackground, WhiteBackgroundTest<>) {
    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();
    CGContextTranslateCTM(context, 10, 20);
    _SetPatternForFill(context, CGRectMake(0, 0, 100, 100), 100, 100, drawCoolStar, 1);

    CGContextFillRect(context, bounds);
}

DRAW_TEST_F(CGPatternTests, PatternFillTransformationWindowsLogoScaleWhiteBackground, WhiteBackgroundTest<>) {
    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();
    CGContextScaleCTM(context, 4, 10);
    _SetPatternForFill(context, CGRectMake(0, 0, 100, 100), 100, 100, drawCoolStar, 1);

    CGContextFillRect(context, bounds);
}

DRAW_TEST_F(CGPatternTests, PatternFillTransformationWindowsLogoNone, UIKitMimicTest<>) {
    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();
    _SetPatternForFill(context, CGRectMake(0, 0, 100, 100), 100, 100, drawCoolStar, 1);

    CGContextFillRect(context, bounds);
}

DRAW_TEST_F(CGPatternTests, PatternFillTransformationWindowsLogoRotate, UIKitMimicTest<>) {
    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();
    CGContextRotateCTM(context, 0.4);
    _SetPatternForFill(context, CGRectMake(0, 0, 100, 100), 100, 100, drawCoolStar, 1);

    CGContextFillRect(context, bounds);
}

DRAW_TEST_F(CGPatternTests, PatternFillTransformationWindowsLogoTranslate, UIKitMimicTest<>) {
    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();
    CGContextTranslateCTM(context, 10, 20);
    _SetPatternForFill(context, CGRectMake(0, 0, 100, 100), 100, 100, drawCoolStar, 1);

    CGContextFillRect(context, bounds);
}

DRAW_TEST_F(CGPatternTests, PatternFillTransformationWindowsLogoScale, UIKitMimicTest<>) {
    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();
    CGContextScaleCTM(context, 4, 10);
    _SetPatternForFill(context, CGRectMake(0, 0, 100, 100), 100, 100, drawCoolStar, 1);

    CGContextFillRect(context, bounds);
}

DRAW_TEST_F(CGPatternTests, CGPatternColoredRectBasedStrokeTransform, WhiteBackgroundTest<>) {
    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();

    CGContextRotateCTM(context, 0.5);
    CGContextTranslateCTM(context, 0, -3);
    CGContextScaleCTM(context, 2, 2);
    _SetPatternForStroke(context, CGRectMake(0, 0, 100, 100), 100, 100, drawCoolStar, 1);
    CGRect borderRect = CGRectInset(bounds, 30, 50);
    CGContextStrokeRect(context, borderRect);
}

#pragma endregion Colored Pattern