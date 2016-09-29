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

#import "CGPathAddElipseViewController.h"
#import "CGDrawView.h"

@implementation CGPathAddElipseViewController

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

        CGRect theRectangle = CGRectMake(50, 50, 300, 200);

        CGMutablePathRef thepath = CGPathCreateMutable();

        CGPathAddEllipseInRect(thepath, NULL, theRectangle);
        CGPathCloseSubpath(thepath);
        CGContextAddPath(currentContext, thepath);
        CGContextStrokePath(currentContext);

        // A very transparent rectangle to show where the elipse has been drawn inside of.
        CGFloat colorComponents[] = { 1, 1, 1, .2 };
        CGContextSetStrokeColor(currentContext, colorComponents);
        // Draw the rectangle individually just to show where the elipse should be.
        CGContextStrokeRect(currentContext, theRectangle);

        CGPathRelease(thepath);

        [super drawComparisonCGImageFromImageName:@"AddElipseToRect" intoContext:currentContext];
    }];

    [self.view addSubview:drawView];

    [super addComparisonLabel];
}

@end
