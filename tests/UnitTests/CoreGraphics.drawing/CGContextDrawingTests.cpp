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

DISABLED_DRAW_TEST_F(CGContext, Canva, UIKitMimicTest<>) {
    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();

    CGFloat red[] = { 1, 0, 0, 1 };
    CGContextSetStrokeColor(context, red);

    CGPoint points[] = { { 0.0, 0.0 }, { 100, 100 }, { 100, 0.0 }, { 0.0, 100 } };
    CGContextStrokeLineSegments(context, points, 4);

    CGFloat green[] = { 0, 1, 0, 1 };
    CGContextSetFillColor(context, green);
    CGRect middleSpot = CGRectMake(100 / 8 * 3, 100 / 8 * 3, 2 * 100 / 8, 2 * 100 / 8);
    CGContextFillRect(context, middleSpot);
}

DRAW_TEST_F(CGContext, RedBox, UIKitMimicTest<>) {
    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();

    CGContextSetRGBFillColor(context, 1.0, 0.0, 0.0, 1.0);
    CGContextFillRect(context, CGRectInset(bounds, 10, 10));
}

DISABLED_DRAW_TEST_F(CGContext, FillThenStrokeIsSameAsDrawFillStroke, WhiteBackgroundTest<>) {
    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();

    // Black with a faint red outline will allow us to see through the red.
    CGContextSetRGBFillColor(context, 0.0, 0.0, 0.0, 1.0);
    CGContextSetRGBStrokeColor(context, 1.0, 0.0, 0.0, 0.33);
    CGContextSetLineWidth(context, 5.f);

    CGPoint leftCenter{ bounds.size.width / 4.f, bounds.size.height / 2.f };
    CGPoint rightCenter{ 3.f * bounds.size.width / 4.f, bounds.size.height / 2.f };

    // Left circle, fill then stroke.
    CGContextBeginPath(context);
    CGContextAddEllipseInRect(context, _CGRectCenteredOnPoint({ 150, 150 }, leftCenter));
    CGContextFillPath(context);
    CGContextBeginPath(context);
    CGContextAddEllipseInRect(context, _CGRectCenteredOnPoint({ 150, 150 }, leftCenter));
    CGContextStrokePath(context);

    // Right circle, all at once
    CGContextBeginPath(context);
    CGContextAddEllipseInRect(context, _CGRectCenteredOnPoint({ 150, 150 }, rightCenter));
    CGContextDrawPath(context, kCGPathFillStroke);
}

static void _drawThreeCirclesInContext(CGContextRef context, CGRect bounds) {
    CGPoint center = _CGRectGetCenter(bounds);
    CGRect centerEllipseRect = _CGRectCenteredOnPoint({ 150, 150 }, center);
    CGFloat translations[]{ -60.f, 0.f, +60.f };

    for (float xSlide : translations) {
        CGRect translatedRect = CGRectApplyAffineTransform(centerEllipseRect, CGAffineTransformMakeTranslation(xSlide, 0));
        CGContextFillEllipseInRect(context, translatedRect);
        CGContextStrokeEllipseInRect(context, translatedRect);
    }
}

DISABLED_DRAW_TEST_F(CGContext, OverlappingCirclesColorAlpha, WhiteBackgroundTest<>) {
    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();

    CGContextSetRGBFillColor(context, 1.0, 0.0, 0.0, 0.5);
    CGContextSetRGBStrokeColor(context, 1.0, 0.0, 0.0, 1.0);
    CGContextSetLineWidth(context, 5);

    _drawThreeCirclesInContext(context, bounds);
}

DISABLED_DRAW_TEST_F(CGContext, OverlappingCirclesGlobalAlpha, WhiteBackgroundTest<>) {
    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();

    CGContextSetRGBFillColor(context, 1.0, 0.0, 0.0, 1.0);
    CGContextSetRGBStrokeColor(context, 1.0, 0.0, 0.0, 1.0);
    CGContextSetLineWidth(context, 5);

    CGContextSetAlpha(context, 0.5);

    _drawThreeCirclesInContext(context, bounds);
}

DISABLED_DRAW_TEST_F(CGContext, OverlappingCirclesGlobalAlphaStackedWithColorAlpha, WhiteBackgroundTest<>) {
    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();

    CGContextSetRGBFillColor(context, 1.0, 0.0, 0.0, 0.5);
    CGContextSetRGBStrokeColor(context, 1.0, 0.0, 0.0, 1.0);
    CGContextSetLineWidth(context, 5);

    CGContextSetAlpha(context, 0.75);

    _drawThreeCirclesInContext(context, bounds);
}

DISABLED_DRAW_TEST_F(CGContext, OverlappingCirclesTransparencyLayerAlpha, WhiteBackgroundTest<>) {
    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();

    CGContextSetRGBFillColor(context, 1.0, 0.0, 0.0, 1.0);
    CGContextSetRGBStrokeColor(context, 1.0, 0.0, 0.0, 1.0);
    CGContextSetLineWidth(context, 5);

    CGContextSetAlpha(context, 0.5);

    CGContextBeginTransparencyLayer(context, nullptr);

    _drawThreeCirclesInContext(context, bounds);

    CGContextEndTransparencyLayer(context);
}

// This test proves that the path is stored fully transformed;
// changing the CTM before stroking it does not cause it to scale!
// However, the stroke width _is_ scaled (!)
DISABLED_DRAW_TEST_F(CGContext, ChangeCTMAfterCreatingPath, WhiteBackgroundTest<>) {
    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();

    CGContextSetRGBStrokeColor(context, 1.0, 0.0, 0.0, 1.0);
    CGContextSetLineWidth(context, 1);

    CGContextBeginPath(context);
    CGContextMoveToPoint(context, 5, 5.5);
    CGContextAddLineToPoint(context, (bounds.size.width - 5) / 3, 5.5);
    CGContextStrokePath(context);

    CGContextSaveGState(context);
    CGContextBeginPath(context);
    CGContextMoveToPoint(context, 5, 10.5);
    CGContextAddLineToPoint(context, (bounds.size.width - 5) / 3, 10.5);
    CGContextScaleCTM(context, 2.0, 2.0);
    CGContextStrokePath(context);
    CGContextRestoreGState(context);

    CGContextSaveGState(context);
    CGContextBeginPath(context);
    CGContextMoveToPoint(context, 5, 15.5);
    CGContextAddLineToPoint(context, (bounds.size.width - 5) / 3, 15.5);
    CGContextScaleCTM(context, 3.0, 3.0);
    CGContextStrokePath(context);
    CGContextRestoreGState(context);
}

DRAW_TEST(CGContext, PremultipliedAlphaImage) {
    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();

    CGContextSetRGBFillColor(context, 1.0, 0.0, 0.0, 0.5);
    CGContextFillRect(context, { 0, 0, 100, 100 });
}
