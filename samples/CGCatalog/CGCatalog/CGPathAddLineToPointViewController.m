///******************************************************************************
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

#import "CGPathAddLineToPointViewController.h"
#import "CGDrawView.h"

@implementation CGPathAddLineToPointViewController

- (id)initWithLineWidth:(CGFloat)width
              lineColor:(CGColorRef)color
            dashPattern:(CGFloat*)pattern
                  phase:(CGFloat)phase
              dashCount:(size_t)count {
    self = [super initWithLineWidth:width color:color dashPattern:pattern phase:phase dashCount:count];
    return self;
}

- (void)loadView {
    [super loadView];

    CGDrawView* drawView = [[CGDrawView alloc] initWithFrame:self.view.bounds lineWidth:self.lineWidth color:self.lineColor];
    [drawView setDrawBlock:^(void) {
        CGContextRef currentContext = UIGraphicsGetCurrentContext();

        CGContextSetLineWidth(currentContext, self.lineWidth);
        CGContextSetStrokeColorWithColor(currentContext, self.lineColor);
        CGContextSetLineDash(currentContext, self.linePhase, self.lineDashPattern, self.lineDashCount);

        CGMutablePathRef thepath = CGPathCreateMutable();
        CGPathMoveToPoint(thepath, NULL, 200, 35);
        CGPathAddLineToPoint(thepath, NULL, 165, 100);
        CGPathAddLineToPoint(thepath, NULL, 100, 100);
        CGPathAddLineToPoint(thepath, NULL, 150, 150);
        CGPathAddLineToPoint(thepath, NULL, 135, 225);
        CGPathAddLineToPoint(thepath, NULL, 200, 170);
        CGPathAddLineToPoint(thepath, NULL, 265, 225);
        CGPathAddLineToPoint(thepath, NULL, 250, 150);
        CGPathAddLineToPoint(thepath, NULL, 300, 100);
        CGPathAddLineToPoint(thepath, NULL, 235, 100);

        // Unnecessary as close subpath will finish this line off but for the sake of consistency, have this here.
        CGPathAddLineToPoint(thepath, NULL, 200, 35);

        CGPathCloseSubpath(thepath);
        CGContextAddPath(currentContext, thepath);
        CGContextStrokePath(currentContext);

        CGPathRelease(thepath);

        [super drawComparisonCGImageFromImageName:@"AddLineToPoint" intoContext:currentContext];
    }];

    [self.view addSubview:drawView];

    [super addComparisonLabel];
}

@end
