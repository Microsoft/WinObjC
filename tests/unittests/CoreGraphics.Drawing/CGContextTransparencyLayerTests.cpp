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

#import "DrawingTest.h"

static void _strokeTwoCirclesInContext(CGContextRef context, CGRect bounds) {
    CGPoint center = _CGRectGetCenter(bounds);
    CGRect centerEllipseRect = _CGRectCenteredOnPoint({ 150, 150 }, center);
    CGFloat translations[]{ -60.f, +60.f };

    for (float xSlide : translations) {
        CGRect translatedRect = CGRectApplyAffineTransform(centerEllipseRect, CGAffineTransformMakeTranslation(xSlide, 0));
        CGContextStrokeEllipseInRect(context, translatedRect);
    }
}

DISABLED_DRAW_TEST_F(CGContextTransparencyLayer, IsShadowedAllAtOnce, WhiteBackgroundTest<>) {
    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();

    CGContextSetShadow(context, CGSize{ 10.f, 10.f }, 1.0);

    CGContextBeginTransparencyLayer(context, nullptr);

    CGContextSetRGBFillColor(context, 1.0, 0.0, 0.0, 1.0);
    CGContextSetRGBStrokeColor(context, 1.0, 0.0, 0.0, 1.0);
    CGContextSetLineWidth(context, 5);

    CGPoint center = _CGRectGetCenter(bounds);

    CGContextMoveToPoint(context, center.x - 50, center.y);
    CGContextAddLineToPoint(context, center.x + 50, center.y);
    CGContextStrokePath(context);

    CGContextMoveToPoint(context, center.x, center.y - 50);
    CGContextAddLineToPoint(context, center.x, center.y + 50);
    CGContextStrokePath(context);

    CGContextEndTransparencyLayer(context);
}

DISABLED_DRAW_TEST_F(CGContextTransparencyLayer, StacksInnerAndOuterShadow, WhiteBackgroundTest<>) {
    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();

    CGContextSetShadow(context, CGSize{ 10.f, 10.f }, 1.0);

    CGContextBeginTransparencyLayer(context, nullptr);

    CGContextSetShadow(context, CGSize{ -10.f, -10.f }, 1.0);

    CGContextSetRGBStrokeColor(context, 1.0, 0.0, 0.0, 1.0);
    CGContextSetLineWidth(context, 5);

    _strokeTwoCirclesInContext(context, bounds);

    CGContextEndTransparencyLayer(context);
}

DRAW_TEST_F(CGContextTransparencyLayer, FloodFill_GlobalAlpha0_5f, WhiteBackgroundTest<>) {
    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();

    CGContextSetAlpha(context, 0.5);

    CGContextBeginTransparencyLayer(context, nullptr);

    CGContextSetRGBFillColor(context, 1.0, 0.0, 0.0, 1.0);
    CGContextFillRect(context, CGRectInset(bounds, 2.0, 2.0));

    CGContextEndTransparencyLayer(context);
}

DISABLED_DRAW_TEST_F(CGContextTransparencyLayer, DrawCircles_GlobalAlpha0_5f, WhiteBackgroundTest<>) {
    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();

    CGContextSetAlpha(context, 0.5);

    CGContextBeginTransparencyLayer(context, nullptr);

    CGContextSetRGBStrokeColor(context, 1.0, 0.0, 0.0, 1.0);
    CGContextSetLineWidth(context, 5);

    _strokeTwoCirclesInContext(context, bounds);

    CGContextEndTransparencyLayer(context);
}

DRAW_TEST_F(CGContextTransparencyLayer, ZeroGlobalAlpha, WhiteBackgroundTest<>) {
    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();

    CGContextSetAlpha(context, 0.0);

    CGContextBeginTransparencyLayer(context, nullptr);

    CGContextSetRGBStrokeColor(context, 1.0, 0.0, 0.0, 1.0);
    CGContextSetLineWidth(context, 5);

    _strokeTwoCirclesInContext(context, bounds);

    CGContextEndTransparencyLayer(context);
}

DISABLED_DRAW_TEST_F(CGContextTransparencyLayer, BoundedLayerDrawingCircles, WhiteBackgroundTest<>) {
    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();

    CGPoint center = _CGRectGetCenter(bounds);
    CGRect clippingRect = _CGRectCenteredOnPoint({ 150, 150 }, center);

    CGContextBeginTransparencyLayerWithRect(context, clippingRect, nullptr);

    CGContextSetRGBStrokeColor(context, 1.0, 0.0, 0.0, 1.0);
    CGContextSetLineWidth(context, 5);

    _strokeTwoCirclesInContext(context, bounds);

    CGContextEndTransparencyLayer(context);
}

DRAW_TEST_F(CGContextTransparencyLayer, BoundedLayerFloodFill, WhiteBackgroundTest<>) {
    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();

    CGPoint center = _CGRectGetCenter(bounds);
    CGRect clippingRect = _CGRectCenteredOnPoint({ 150, 150 }, center);

    CGContextBeginTransparencyLayerWithRect(context, clippingRect, nullptr);

    CGContextSetRGBFillColor(context, 1.0, 0.0, 0.0, 1.0);
    CGContextFillRect(context, bounds);

    CGContextEndTransparencyLayer(context);
}

// The shadow should extend beyond the bounds of the layer content, even if it is clipped.
DISABLED_DRAW_TEST_F(CGContextTransparencyLayer, BoundedLayerFloodFillShadow, WhiteBackgroundTest<>) {
    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();

    CGPoint center = _CGRectGetCenter(bounds);
    CGRect clippingRect = _CGRectCenteredOnPoint({ 100, 100 }, center);

    CGContextSetShadow(context, CGSize{ 10.f, 10.f }, 1.0);

    CGContextBeginTransparencyLayerWithRect(context, clippingRect, nullptr);

    CGContextSetRGBFillColor(context, 1.0, 0.0, 0.0, 1.0);
    CGContextFillRect(context, bounds);

    CGContextEndTransparencyLayer(context);
}

DISABLED_DRAW_TEST_F(CGContextTransparencyLayer, BoundedLayerFloodFill_GlobalTransform, WhiteBackgroundTest<>) {
    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();

    CGContextConcatCTM(context, CGAffineTransformMake(1.0, 0.0, 0.75, 1.0, 0.0, 0.0));

    CGPoint center = _CGRectGetCenter(bounds);
    CGRect clippingRect = _CGRectCenteredOnPoint({ 150, 150 }, center);

    CGContextBeginTransparencyLayerWithRect(context, clippingRect, nullptr);

    CGContextSetRGBFillColor(context, 1.0, 0.0, 0.0, 1.0);
    CGContextFillRect(context, bounds);

    CGContextEndTransparencyLayer(context);
}

// The shadow should extend beyond the bounds of the layer content, even if it is clipped.
DISABLED_DRAW_TEST_F(CGContextTransparencyLayer, BoundedLayerDrawingCircles_GlobalTransform, WhiteBackgroundTest<>) {
    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();

    CGContextConcatCTM(context, CGAffineTransformMake(1.0, 0.0, 0.75, 1.0, 0.0, 0.0));

    CGPoint center = _CGRectGetCenter(bounds);
    CGRect clippingRect = _CGRectCenteredOnPoint({ 150, 150 }, center);

    CGContextSetShadow(context, CGSize{ 10.f, 10.f }, 1.0);

    CGContextBeginTransparencyLayerWithRect(context, clippingRect, nullptr);

    CGContextSetRGBStrokeColor(context, 1.0, 0.0, 0.0, 1.0);
    CGContextSetLineWidth(context, 5);

    _strokeTwoCirclesInContext(context, bounds);

    CGContextEndTransparencyLayer(context);
}

DRAW_TEST_F(CGContextTransparencyLayer, BoundedLayerFloodFill_GlobalClip, WhiteBackgroundTest<>) {
    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();

    CGPoint center = _CGRectGetCenter(bounds);
    CGRect layerRect = _CGRectCenteredOnPoint({ 100, 100 }, center);

    CGContextBeginPath(context);
    CGContextAddRect(context, _CGRectCenteredOnPoint({ 150, 150 }, center));
    CGContextAddRect(context, _CGRectCenteredOnPoint({ 50, 50 }, center));
    CGContextEOClip(context);

    CGContextSetRGBFillColor(context, 1.0, 1.0, 0.0, 1.0);
    CGContextFillRect(context, _CGRectCenteredOnPoint({ 200, 200 }, center));

    CGContextBeginTransparencyLayerWithRect(context, layerRect, nullptr);

    CGContextSetRGBFillColor(context, 1.0, 0.0, 0.0, 1.0);
    CGContextFillRect(context, bounds);

    CGContextEndTransparencyLayer(context);
}

