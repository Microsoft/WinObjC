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

#import "CGPathAddArcToPointViewController.h"
#import "CGDrawView.h"

@implementation CGPathAddArcToPointViewController

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
        CGPathMoveToPoint(thepath, &transformation, 75, 100);
        CGPathAddArcToPoint(thepath, &transformation, 50, 150, 100, 250, 15);
        CGPathAddArcToPoint(thepath, &transformation, 100, 250, 150, 150, 15);
        CGPathAddArcToPoint(thepath, &transformation, 150, 150, 100, 50, 15);
        CGPathAddArcToPoint(thepath, &transformation, 100, 50, 50, 150, 15);
        CGPathAddLineToPoint(thepath, &transformation, 75, 100);

        CGContextAddPath(currentContext, thepath);

        CGContextStrokePath(currentContext);

        CGPathRelease(thepath);

        [super drawComparisonCGImageFromImageName:@"AddArcToPoint" intoContext:currentContext];
    }];

    [self.view addSubview:drawView];

    [super addComparisonLabel];
}

@end
