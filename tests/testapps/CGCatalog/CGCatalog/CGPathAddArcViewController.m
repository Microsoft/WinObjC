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

#import "CGPathAddArcViewController.h"
#import "CGDrawView.h"

@implementation CGPathAddArcViewController

- (void)loadView {
    [super loadView];
    [self.view setBackgroundColor:[UIColor clearColor]];

    CGDrawView* drawView = [[CGDrawView alloc] initWithFrame:self.view.bounds drawOptions:self.options];
    [drawView setDrawBlock:^(void) {
        CGContextRef currentContext = UIGraphicsGetCurrentContext();

        CGContextSetLineWidth(currentContext, self.options.lineWidth);
        CGContextSetStrokeColorWithColor(currentContext, self.options.lineColor);
        CGContextSetLineDash(currentContext, self.options.linePhase, self.options.lineDashPattern, self.options.lineDashCount);

        CGAffineTransform transformation = self.options.affineTransform;

        CGMutablePathRef thepath = CGPathCreateMutable();
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

        CGPathRelease(thepath);

        [super drawComparisonCGImageFromImageName:@"AddArc" intoContext:currentContext];
    }];

    [self.view addSubview:drawView];

    [super addComparisonLabel];
}

@end
