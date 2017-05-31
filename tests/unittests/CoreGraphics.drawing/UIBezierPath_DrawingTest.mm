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
#include <UIKit/UIKit.h>

DRAW_TEST_F(UIBezierPath, Rectangle, UIKitMimicTest<>) {
    CGContextRef context = GetDrawingContext();
    CGRect drawingBounds = GetDrawingBounds();
    CGFloat width = drawingBounds.size.width;
    CGFloat height = drawingBounds.size.height;
    CGFloat xstart = drawingBounds.origin.x;
    CGFloat ystart = drawingBounds.origin.y;

    UIGraphicsPushContext(context);

    CGContextSetRGBFillColor(context, 0, 0, 1, 1);
    UIBezierPath* path = [UIBezierPath bezierPathWithRect:CGRectInset(drawingBounds, .2 * width, .2 * height)];
    [path fill];

    UIGraphicsPopContext();
}

DRAW_TEST_F(UIBezierPath, AddCurveToPoint, UIKitMimicTest<>) {
    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();

    UIGraphicsPushContext(context);
    UIBezierPath* path = [UIBezierPath bezierPath];
    [path moveToPoint:CGPointMake(30, 100)];
    [path addCurveToPoint:CGPointMake(45.0f, 50.0f) controlPoint1:CGPointMake(47.0f, 67.0f) controlPoint2:CGPointMake(50.0f, 55.0f)];
    [path addCurveToPoint:CGPointMake(30.0f, 55.0f) controlPoint1:CGPointMake(42.0f, 47.0f) controlPoint2:CGPointMake(37.0f, 46.0f)];

    [path addCurveToPoint:CGPointMake(15.0f, 50.0f) controlPoint1:CGPointMake(23.0f, 46.0f) controlPoint2:CGPointMake(18.0f, 47.0f)];
    [path addCurveToPoint:CGPointMake(30.0f, 100.0f) controlPoint1:CGPointMake(10.0f, 55.0f) controlPoint2:CGPointMake(13.0f, 67.0f)];

    [path closePath];
    [path stroke];
    UIGraphicsPopContext();
}

DISABLED_DRAW_TEST_F(UIBezierPath, AddEllipse, UIKitMimicTest<>) {
    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();
    UIGraphicsPushContext(context);

    CGRect theRectangle = CGRectMake(50, 50, 300, 200);

    UIBezierPath* path = [UIBezierPath bezierPathWithOvalInRect:theRectangle];
    [path stroke];
    UIGraphicsPopContext();
}

DRAW_TEST_F(UIBezierPath, AddLineToPoint, UIKitMimicTest<>) {
    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();
    UIGraphicsPushContext(context);

    UIBezierPath* path = [UIBezierPath bezierPath];
    [path moveToPoint:CGPointMake(200, 35)];
    [path addLineToPoint:CGPointMake(165, 100)];
    [path addLineToPoint:CGPointMake(100, 100)];
    [path addLineToPoint:CGPointMake(150, 150)];
    [path addLineToPoint:CGPointMake(135, 225)];
    [path addLineToPoint:CGPointMake(200, 170)];
    [path addLineToPoint:CGPointMake(265, 225)];
    [path addLineToPoint:CGPointMake(250, 150)];
    [path addLineToPoint:CGPointMake(300, 100)];
    [path addLineToPoint:CGPointMake(235, 100)];
    [path addLineToPoint:CGPointMake(200, 35)];
    [path closePath];

    [path stroke];
    UIGraphicsPopContext();
}

DRAW_TEST_F(UIBezierPath, AddPath, UIKitMimicTest<>) {
    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();
    UIGraphicsPushContext(context);

    UIBezierPath* theFirstPath = [UIBezierPath bezierPath];
    UIBezierPath* theSecondPath = [UIBezierPath bezierPath];

    [theFirstPath moveToPoint:CGPointMake(200, 35)];
    [theFirstPath addLineToPoint:CGPointMake(165, 100)];
    [theFirstPath addLineToPoint:CGPointMake(100, 100)];
    [theFirstPath addLineToPoint:CGPointMake(150, 150)];
    [theFirstPath addLineToPoint:CGPointMake(135, 225)];
    [theFirstPath addLineToPoint:CGPointMake(200, 170)];
    [theFirstPath addLineToPoint:CGPointMake(265, 225)];

    [theSecondPath moveToPoint:CGPointMake(265, 225)];
    [theSecondPath addLineToPoint:CGPointMake(350, 225)];
    [theSecondPath addLineToPoint:CGPointMake(350, 35)];
    [theSecondPath addLineToPoint:CGPointMake(200, 35)];

    [theFirstPath appendPath:theSecondPath];

    [theFirstPath closePath];
    [theFirstPath stroke];
    UIGraphicsPopContext();
}

DRAW_TEST_F(UIBezierPath, AddQuadCurveToPoint, UIKitMimicTest<>) {
    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();
    UIGraphicsPushContext(context);

    UIBezierPath* path = [UIBezierPath bezierPath];

    [path moveToPoint:CGPointMake(100, 50)];
    [path addQuadCurveToPoint:CGPointMake(150, 50) controlPoint:CGPointMake(125, 25)];

    [path moveToPoint:CGPointMake(200, 50)];
    [path addQuadCurveToPoint:CGPointMake(250, 50) controlPoint:CGPointMake(225, 25)];

    [path moveToPoint:CGPointMake(100, 150)];
    [path addQuadCurveToPoint:CGPointMake(300, 100) controlPoint:CGPointMake(200, 200)];

    [path moveToPoint:CGPointMake(285, 105)];
    [path addQuadCurveToPoint:CGPointMake(310, 110) controlPoint:CGPointMake(300, 90)];
    [path stroke];
    UIGraphicsPopContext();
}

DRAW_TEST_F(UIBezierPath, CloseSubpath, UIKitMimicTest<>) {
    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();
    UIGraphicsPushContext(context);

    UIBezierPath* path = [UIBezierPath bezierPath];
    [path moveToPoint:CGPointMake(50, 50)];
    [path addLineToPoint:CGPointMake(50, 100)];
    [path addLineToPoint:CGPointMake(100, 100)];
    [path closePath];

    [path moveToPoint:CGPointMake(200, 50)];
    [path addLineToPoint:CGPointMake(200, 100)];
    [path addLineToPoint:CGPointMake(150, 100)];
    [path closePath];

    [path moveToPoint:CGPointMake(100, 200)];
    [path addLineToPoint:CGPointMake(125, 150)];
    [path addLineToPoint:CGPointMake(150, 200)];
    [path closePath];

    [path stroke];
    UIGraphicsPopContext();
}

DRAW_TEST_F(UIBezierPath, FillArcsSimple, UIKitMimicTest<>) {
    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();
    CGFloat width = bounds.size.width;
    CGFloat height = bounds.size.height;
    CGFloat xstart = bounds.origin.x;
    CGFloat ystart = bounds.origin.y;
    UIGraphicsPushContext(context);

    UIBezierPath* path = [UIBezierPath bezierPath];

    [path moveToPoint:CGPointMake(xstart + .5 * width, ystart + .5 * height)];
    [path addArcWithCenter:CGPointMake(xstart + .5 * width, ystart + .5 * height)
                    radius:.4 * height
                startAngle:0
                  endAngle:M_PI / 2
                 clockwise:true];
    [path closePath];

    [path moveToPoint:CGPointMake(xstart + .55 * width, ystart + .45 * height)];
    [path addArcWithCenter:CGPointMake(xstart + .55 * width, ystart + .45 * height)
                    radius:.4 * height
                startAngle:M_PI / 2
                  endAngle:0
                 clockwise:true];
    [path closePath];

    CGContextSetRGBFillColor(context, 0, 0, 1, 1);
    [path fill];
    UIGraphicsPopContext();
}

DRAW_TEST_F(UIBezierPath, FillArcsComplex, UIKitMimicTest<>) {
    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();
    CGFloat width = bounds.size.width;
    CGFloat height = bounds.size.height;
    CGFloat xstart = bounds.origin.x;
    CGFloat ystart = bounds.origin.y;
    UIGraphicsPushContext(context);

    UIBezierPath* path = [UIBezierPath bezierPath];

    [path moveToPoint:CGPointMake(xstart + .75 * width, ystart + .5 * height)];
    [path addArcWithCenter:CGPointMake(xstart + .5 * width, ystart + .5 * height)
                    radius:.5 * height
                startAngle:0
                  endAngle:M_PI / 2
                 clockwise:true];
    [path addArcWithCenter:CGPointMake(xstart + .5 * width, ystart + .5 * height)
                    radius:.5 * height
                startAngle:M_PI / 2
                  endAngle:0
                 clockwise:true];
    [path moveToPoint:CGPointMake(xstart + .75 * width, ystart + .5 * height)];
    [path addArcWithCenter:CGPointMake(xstart + .375 * width, ystart + .5 * height)
                    radius:.25 * height
                startAngle:M_PI
                  endAngle:0
                 clockwise:false];
    [path moveToPoint:CGPointMake(xstart + .5 * width, ystart + .5 * height)];

    [path addArcWithCenter:CGPointMake(xstart + .625 * width, ystart + .5 * height)
                    radius:.25 * height
                startAngle:M_PI
                  endAngle:0
                 clockwise:true];
    [path moveToPoint:CGPointMake(xstart + .4375 * width, ystart + .5 * height)];
    [path addArcWithCenter:CGPointMake(xstart + .375 * width, ystart + .5 * height)
                    radius:.125 * height
                startAngle:0
                  endAngle:M_PI / 2
                 clockwise:true];
    [path addArcWithCenter:CGPointMake(xstart + .375 * width, ystart + .5 * height)
                    radius:.125 * height
                startAngle:M_PI / 2
                  endAngle:0
                 clockwise:true];
    [path moveToPoint:CGPointMake(xstart + .6875 * width, ystart + .5 * height)];
    [path addArcWithCenter:CGPointMake(xstart + .625 * width, ystart + .5 * height)
                    radius:.125 * height
                startAngle:0
                  endAngle:M_PI / 2
                 clockwise:true];
    [path addArcWithCenter:CGPointMake(xstart + .625 * width, ystart + .5 * height)
                    radius:.125 * height
                startAngle:M_PI / 2
                  endAngle:0
                 clockwise:true];

    CGAffineTransform transformation = CGAffineTransformIdentity;
    transformation = CGAffineTransformScale(transformation, .8, .8);
    transformation = CGAffineTransformTranslate(transformation, .1 * width, .1 * height);

    [path applyTransform:transformation];

    CGContextSetRGBFillColor(context, 0, 0, 1, 1);
    [path fill];
    UIGraphicsPopContext();
}

DRAW_TEST_F(UIBezierPath, FillStraightLines, UIKitMimicTest<>) {
    CGContextRef context = GetDrawingContext();
    CGRect drawingBounds = GetDrawingBounds();
    CGFloat width = drawingBounds.size.width;
    CGFloat height = drawingBounds.size.height;
    CGFloat xstart = drawingBounds.origin.x;
    CGFloat ystart = drawingBounds.origin.y;
    UIGraphicsPushContext(context);

    UIBezierPath* path = [UIBezierPath bezierPath];
    [path moveToPoint:CGPointMake(xstart + .5 * width, ystart + .1 * height)];
    [path addLineToPoint:CGPointMake(xstart + .35 * width, ystart + .3 * height)];
    [path addLineToPoint:CGPointMake(xstart + .1 * width, ystart + .3 * height)];
    [path addLineToPoint:CGPointMake(xstart + .3 * width, ystart + .5 * height)];
    [path addLineToPoint:CGPointMake(xstart + .25 * width, ystart + .9 * height)];
    [path addLineToPoint:CGPointMake(xstart + .5 * width, ystart + .7 * height)];
    [path addLineToPoint:CGPointMake(xstart + .75 * width, ystart + .9 * height)];
    [path addLineToPoint:CGPointMake(xstart + .7 * width, ystart + .5 * height)];
    [path addLineToPoint:CGPointMake(xstart + .9 * width, ystart + .3 * height)];
    [path addLineToPoint:CGPointMake(xstart + .65 * width, ystart + .3 * height)];
    [path addLineToPoint:CGPointMake(xstart + .5 * width, ystart + .1 * height)];
    [path closePath];

    CGContextSetRGBFillColor(context, 0, 0, 1, 1);
    [path fill];
    UIGraphicsPopContext();
}

DRAW_TEST_F(UIBezierPath, RoundedRect, UIKitMimicTest<>) {
    CGContextRef context = GetDrawingContext();
    CGRect drawingBounds = GetDrawingBounds();
    CGFloat width = drawingBounds.size.width;
    CGFloat height = drawingBounds.size.height;
    CGFloat xstart = drawingBounds.origin.x;
    CGFloat ystart = drawingBounds.origin.y;
    UIGraphicsPushContext(context);

    UIBezierPath* path = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(drawingBounds, .2 * width, .2 * height)
                                               byRoundingCorners:UIRectCornerAllCorners
                                                     cornerRadii:CGSizeMake(10, 20)];

    CGContextSetRGBFillColor(context, 0, 0, 1, 1);
    [path fill];
    UIGraphicsPopContext();
}