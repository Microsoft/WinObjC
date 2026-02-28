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

CGPathDrawingMode fillModes[] = { kCGPathFill, kCGPathFillStroke, kCGPathEOFill, kCGPathEOFillStroke };

class CGContextFillMode : public WhiteBackgroundTest<>, public ::testing::WithParamInterface<CGPathDrawingMode> {
    CFStringRef CreateOutputFilename() {
        CGPathDrawingMode fillMode = GetParam();

        const char* fillModeName;
        switch (fillMode) {
            case kCGPathFill:
                fillModeName = "Fill";
                break;
            case kCGPathFillStroke:
                fillModeName = "FillStroke";
                break;
            case kCGPathEOFill:
                fillModeName = "EOFill";
                break;
            case kCGPathEOFillStroke:
                fillModeName = "EOFillStroke";
                break;
            default:
                break;
        }

        return CFStringCreateWithFormat(nullptr, nullptr, CFSTR("TestImage.CGContext.FillMode.%s.png"), fillModeName);
    }
};

DRAW_TEST_P(CGContextFillMode, OverlappedEllipses) {
    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();
    bounds = CGRectInset(bounds, 16.f, 16.f);
    CGFloat width = bounds.size.width;
    CGFloat height = bounds.size.height;
    CGFloat xstart = bounds.origin.x;
    CGFloat ystart = bounds.origin.y;

    CGPathDrawingMode fillMode = GetParam();

    CGMutablePathRef leftCircles = CGPathCreateMutable();

    CGPathMoveToPoint(leftCircles, NULL, xstart + .25 * width + .4 * height, ystart + .5 * height);
    CGPathAddArc(leftCircles, NULL, xstart + .25 * width, ystart + .5 * height, .4 * height, 0, M_PI, true);
    CGPathAddArc(leftCircles, NULL, xstart + .25 * width, ystart + .5 * height, .4 * height, M_PI, 0, true);

    CGPathMoveToPoint(leftCircles, NULL, xstart + .25 * width + .3 * height, ystart + .5 * height);
    CGPathAddArc(leftCircles, NULL, xstart + .25 * width, ystart + .5 * height, .3 * height, 0, M_PI, true);
    CGPathAddArc(leftCircles, NULL, xstart + .25 * width, ystart + .5 * height, .3 * height, M_PI, 0, true);

    CGPathMoveToPoint(leftCircles, NULL, xstart + .25 * width + .2 * height, ystart + .5 * height);
    CGPathAddArc(leftCircles, NULL, xstart + .25 * width, ystart + .5 * height, .2 * height, 0, M_PI, true);
    CGPathAddArc(leftCircles, NULL, xstart + .25 * width, ystart + .5 * height, .2 * height, M_PI, 0, true);

    CGPathMoveToPoint(leftCircles, NULL, xstart + .25 * width + .1 * height, ystart + .5 * height);
    CGPathAddArc(leftCircles, NULL, xstart + .25 * width, ystart + .5 * height, .1 * height, 0, M_PI, true);
    CGPathAddArc(leftCircles, NULL, xstart + .25 * width, ystart + .5 * height, .1 * height, M_PI, 0, true);

    CGPathCloseSubpath(leftCircles);

    CGMutablePathRef rightCircles = CGPathCreateMutable();

    CGPathMoveToPoint(rightCircles, NULL, xstart + .75 * width + .4 * height, ystart + .5 * height);
    CGPathAddArc(rightCircles, NULL, xstart + .75 * width, ystart + .5 * height, .4 * height, 0, M_PI, false);
    CGPathAddArc(rightCircles, NULL, xstart + .75 * width, ystart + .5 * height, .4 * height, M_PI, 0, false);

    CGPathMoveToPoint(rightCircles, NULL, xstart + .75 * width + .3 * height, ystart + .5 * height);
    CGPathAddArc(rightCircles, NULL, xstart + .75 * width, ystart + .5 * height, .3 * height, 0, M_PI, true);
    CGPathAddArc(rightCircles, NULL, xstart + .75 * width, ystart + .5 * height, .3 * height, M_PI, 0, true);

    CGPathMoveToPoint(rightCircles, NULL, xstart + .75 * width + .2 * height, ystart + .5 * height);
    CGPathAddArc(rightCircles, NULL, xstart + .75 * width, ystart + .5 * height, .2 * height, 0, M_PI, false);
    CGPathAddArc(rightCircles, NULL, xstart + .75 * width, ystart + .5 * height, .2 * height, M_PI, 0, false);

    CGPathMoveToPoint(rightCircles, NULL, xstart + .75 * width + .1 * height, ystart + .5 * height);
    CGPathAddArc(rightCircles, NULL, xstart + .75 * width, ystart + .5 * height, .1 * height, 0, M_PI, true);
    CGPathAddArc(rightCircles, NULL, xstart + .75 * width, ystart + .5 * height, .1 * height, M_PI, 0, true);

    CGPathCloseSubpath(rightCircles);

    CGContextAddPath(context, leftCircles);
    CGContextAddPath(context, rightCircles);
    CGContextSetRGBFillColor(context, 0, 0, 1, 1);
    CGContextSetRGBStrokeColor(context, 1, 0, 0, 1);
    CGContextDrawPath(context, fillMode);

    CGPathRelease(leftCircles);
    CGPathRelease(rightCircles);
}

INSTANTIATE_TEST_CASE_P(FillModes, CGContextFillMode, ::testing::ValuesIn(fillModes));