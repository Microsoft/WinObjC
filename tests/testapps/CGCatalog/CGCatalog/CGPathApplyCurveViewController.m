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

#import "CGPathApplyCurveViewController.h"
#import "CGDrawView.h"

@implementation CGPathApplyCurveViewController

- (void)loadView {
    [super loadView];

    CGDrawView* cgView = [[CGDrawView alloc] initWithFrame:self.view.bounds drawOptions:self.options];

    [cgView setDrawBlock:^(void) {
        CGContextRef currentContext = UIGraphicsGetCurrentContext();

        CGContextSetLineWidth(currentContext, self.options.lineWidth);
        CGContextSetStrokeColorWithColor(currentContext, self.options.lineColor);
        CGContextSetLineDash(currentContext, self.options.linePhase, self.options.lineDashPattern, self.options.lineDashCount);

        CGAffineTransform transformation = self.options.affineTransform;

        CGMutablePathRef thepath = CGPathCreateMutable();

        CGPathMoveToPoint(thepath, &transformation, 100, 450);
        CGPathAddQuadCurveToPoint(thepath, &transformation, 125, 425, 150, 450);
        CGPathMoveToPoint(thepath, &transformation, 200, 450);
        CGPathAddQuadCurveToPoint(thepath, &transformation, 225, 425, 250, 450);
        CGPathMoveToPoint(thepath, &transformation, 100, 550);
        CGPathAddQuadCurveToPoint(thepath, &transformation, 200, 600, 300, 500);
        CGPathMoveToPoint(thepath, &transformation, 285, 505);
        CGPathAddQuadCurveToPoint(thepath, &transformation, 300, 490, 310, 510);

        CGPathMoveToPoint(thepath, &transformation, 100, 100);
        CGPathAddArc(thepath, &transformation, 100, 100, 75, 0, M_PI / 2, true);
        CGPathCloseSubpath(thepath);

        CGPathMoveToPoint(thepath, &transformation, 110, 90);
        CGPathAddArc(thepath, &transformation, 110, 90, 75, M_PI / 2, 0, true);
        CGPathCloseSubpath(thepath);

        CGPathMoveToPoint(thepath, &transformation, 400, 150);
        CGPathAddArc(thepath, &transformation, 300, 150, 100, 0, M_PI / 2, true);
        CGPathAddArc(thepath, &transformation, 300, 150, 100, M_PI / 2, 0, true);
        CGPathMoveToPoint(thepath, &transformation, 200, 150);
        CGPathAddArc(thepath, &transformation, 250, 150, 50, M_PI, 0, false);
        CGPathMoveToPoint(thepath, &transformation, 300, 150);
        CGPathAddArc(thepath, &transformation, 350, 150, 50, M_PI, 0, true);
        CGPathMoveToPoint(thepath, &transformation, 275, 150);
        CGPathAddArc(thepath, &transformation, 250, 150, 25, 0, M_PI / 2, true);
        CGPathAddArc(thepath, &transformation, 250, 150, 25, M_PI / 2, 0, true);
        CGPathMoveToPoint(thepath, &transformation, 375, 150);
        CGPathAddArc(thepath, &transformation, 350, 150, 25, 0, M_PI / 2, true);
        CGPathAddArc(thepath, &transformation, 350, 150, 25, M_PI / 2, 0, true);

        CGContextAddPath(currentContext, thepath);
        CGContextStrokePath(currentContext);

        CGPathApply(thepath, currentContext, CGPathApplyCallback);

        CGContextAddRect(currentContext, CGPathGetPathBoundingBox(thepath));
        CGContextSetRGBStrokeColor(currentContext, 1, 0, 0, 1);
        CGContextStrokePath(currentContext);

        CGContextAddRect(currentContext, CGPathGetBoundingBox(thepath));
        CGContextSetRGBStrokeColor(currentContext, 0, 0, 1, 1);
        CGContextStrokePath(currentContext);

        CGPathRelease(thepath);
    }];

    [self.view addSubview:cgView];
}

static void _CGContextOutlinePoint(CGContextRef context, CGPoint point, CGFloat r, CGFloat g, CGFloat b) {
    CGContextSetRGBStrokeColor(context, r, g, b, 1);

    CGContextStrokeRect(context, CGRectMake(point.x - 2.5, point.y - 2.5, 5, 5));
}

static void CGPathApplyCallback(void* context, const CGPathElement* element) {
    switch (element->type) {
        case kCGPathElementMoveToPoint:
            _CGContextOutlinePoint(context, element->points[0], 1, 0, 0);
            break;
        case kCGPathElementAddLineToPoint:
            _CGContextOutlinePoint(context, element->points[0], 0, 1, 0);
            break;
        case kCGPathElementAddQuadCurveToPoint:
            _CGContextOutlinePoint(context, element->points[0], 0, 1, 1);
            _CGContextOutlinePoint(context, element->points[1], 0, 1, 1);
            break;
        case kCGPathElementAddCurveToPoint:
            _CGContextOutlinePoint(context, element->points[0], 1, 0, 1);
            _CGContextOutlinePoint(context, element->points[1], 1, 0, 1);
            _CGContextOutlinePoint(context, element->points[2], 1, 0, 1);
            break;
        case kCGPathElementCloseSubpath:
            break;
    }
}

@end
