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

#pragma region ClearRect

class CGClearRect : public WhiteBackgroundTest<PixelByPixelImageComparator<PixelComparisonModeMask<>>>,
                    public ::testing::WithParamInterface<::testing::tuple<CGRect, CGAffineTransform, CGRect>> {
    CFStringRef CreateOutputFilename() {
        CGRect rect = ::testing::get<0>(GetParam());
        CGAffineTransform transformation = ::testing::get<1>(GetParam());
        CGRect addRect = ::testing::get<2>(GetParam());

        return CFStringCreateWithFormat(
            nullptr,
            nullptr,
            CFSTR("TestImage.CGContext.ClearRect.(%0.0f.%0.0f)%0.0fx%0.0f.clear.(%0.0f.%0.0f)%0.0fx%0.0f.[%0.1f,%0."
                  "1f,%0.1f,%0.1f,%0.1f,%0.1f].png"),
            rect.origin.x,
            rect.origin.y,
            rect.size.width,
            rect.size.height,
            addRect.origin.x,
            addRect.origin.y,
            addRect.size.width,
            addRect.size.height,
            transformation.a,
            transformation.b,
            transformation.c,
            transformation.d,
            transformation.tx,
            transformation.ty);
    }
};

DRAW_TEST_P(CGClearRect, Transformed) {
    CGRect rect = ::testing::get<0>(GetParam());
    CGAffineTransform transformation = ::testing::get<1>(GetParam());
    CGRect addRect = ::testing::get<2>(GetParam());

    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();

    CGContextAddRect(context, addRect);
    CGContextConcatCTM(context, transformation);
    CGContextClip(context);

    CGContextClearRect(context, rect);
}

static CGRect addRects[] = { CGRectMake(10, 20, 300, 400), CGRectMake(0, 0, 250, 250) };
static CGRect rects[] = { CGRectMake(0, 0, 100, 100), CGRectMake(0, 0, 50, 250), CGRectMake(100, 100, 125, 250) };
static CGAffineTransform transformation[] = { CGAffineTransformMakeRotation(0.4),
                                              CGAffineTransformMakeTranslation(3, 6),
                                              CGAffineTransformMakeScale(0.25, 0.75),
                                              CGAffineTransformMake(1.f, 0.f, 0.3f, 1.f, 0.f, 0.f),
                                              CGAffineTransformIdentity };

INSTANTIATE_TEST_CASE_P(CGContextTests,
                        CGClearRect,
                        ::testing::Combine(::testing::ValuesIn(rects), ::testing::ValuesIn(transformation), ::testing::ValuesIn(addRects)));

DRAW_TEST_F(CGContext, ClearRect, WhiteBackgroundTest<>) {
    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();

    CGContextSetRGBFillColor(context, 1.0, 0.0, 0.0, 1);
    CGContextFillRect(context, bounds);

    CGRect borderRect = CGRectInset(bounds, 30, 50);
    CGContextClearRect(context, borderRect);
}

// Failure to fill in an Arc geometry - #2059
// Note add a test for CGContextFill of an Arc that spans from 0-2*PI
DISABLED_DRAW_TEST_F(CGContext, ClearRectArc, WhiteBackgroundTest<>) {
    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();

    CGRect cirleRect = CGRectMake(0, 0, 100, 100);
    CGContextAddArc(context, 50, 50, 50, 0.0, 2 * M_PI, 0);
    CGContextClip(context);
    CGContextClearRect(context, cirleRect);
}

DRAW_TEST_F(CGContext, ClearRectTransparencyLayer, WhiteBackgroundTest<>) {
    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();

    CGContextSetRGBFillColor(context, 1, 0, 0, 1);
    CGContextFillRect(context, bounds);

    CGContextBeginTransparencyLayer(context, nullptr);
    CGContextSetRGBFillColor(context, 0, 0, 1, 1);
    CGContextFillRect(context, bounds);

    CGContextClearRect(context, CGRectMake(0, 0, 100, 100));

    CGContextEndTransparencyLayer(context);
}

class CGClearRectArc : public WhiteBackgroundTest<>, public ::testing::WithParamInterface<::testing::tuple<CGRect, CGPoint>> {
    CFStringRef CreateOutputFilename() {
        CGRect rect = ::testing::get<0>(GetParam());
        CGPoint sweep = ::testing::get<1>(GetParam());

        return CFStringCreateWithFormat(nullptr,
                                        nullptr,
                                        CFSTR("TestImage.CGContext.CGClearRectArc.(%0.0f.%0.0f)%0.0fx%0.0f.sweep(%0.0f--%0.0f).png"),
                                        rect.origin.x,
                                        rect.origin.y,
                                        rect.size.width,
                                        rect.size.height,
                                        sweep.x,
                                        sweep.y);
    }
};

DRAW_TEST_P(CGClearRectArc, ClearArc) {
    CGContextRef context = GetDrawingContext();
    CGRect rect = ::testing::get<0>(GetParam());
    CGPoint sweep = ::testing::get<1>(GetParam());

    CGContextAddArc(context, 50, 50, 50, sweep.x, sweep.y, 0);
    CGContextClip(context);
    CGContextClearRect(context, rect);
}

static CGPoint sweep[] = { CGPointMake(0, M_PI), CGPointMake(M_PI, 0), CGPointMake(0.3 * M_PI, 0.6 * M_PI), CGPointMake(0, 1.9 * M_PI) };

INSTANTIATE_TEST_CASE_P(CGContextTests, CGClearRectArc, ::testing::Combine(::testing::ValuesIn(rects), ::testing::ValuesIn(sweep)));

DRAW_TEST_F(CGContext, CustomPathClearRect, WhiteBackgroundTest<>) {
    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();

    CGMutablePathRef thepath = CGPathCreateMutable();
    CGPathMoveToPoint(thepath, NULL, 30, 100);
    CGPathAddCurveToPoint(thepath, NULL, 47.0f, 67.0f, 50.0f, 55.0f, 45.0f, 50.0f);
    CGPathAddCurveToPoint(thepath, NULL, 42.0f, 47.0f, 37.0f, 46.0f, 30.0f, 55.0f);

    CGPathAddCurveToPoint(thepath, NULL, 23.0f, 46.0f, 18.0f, 47.0f, 15.0f, 50.0f);
    CGPathAddCurveToPoint(thepath, NULL, 10.0f, 55.0f, 13.0f, 67.0f, 30.0f, 100.0f);

    CGPathCloseSubpath(thepath);
    CGContextAddPath(context, thepath);

    CGContextConcatCTM(context, CGAffineTransformMakeRotation(0.2));
    CGContextClip(context);
    CGContextClearRect(context, CGRectMake(0, 0, 50, 98));
    CGPathRelease(thepath);
}
#pragma endregion ClearRect