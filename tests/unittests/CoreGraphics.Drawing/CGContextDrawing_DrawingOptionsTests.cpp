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

static const CGLineCap sc_lineCaps[] = { kCGLineCapButt, kCGLineCapSquare, kCGLineCapRound };
static const CGLineJoin sc_lineJoins[] = { kCGLineJoinBevel, kCGLineJoinRound };
static const CGFloat sc_miterLimits[] = { 1.5, 1.8, 2, 3 };

struct PhaseDashCount {
    CGFloat phase;
    std::vector<CGFloat> dashPattern;
};

struct PhaseDashCount dashParams[] = { { 0, { 5, 2 } }, { 5, { 5, 2 } }, { 0, { 5, 2, 3, 1 } }, { 0, { 1, 1 } }, { 1, { 1, 1 } } };

class CGDrawLineCaps : public WhiteBackgroundTest<>, public ::testing::WithParamInterface<CGLineCap> {
    CFStringRef CreateOutputFilename() {
        CGLineCap lineCap = GetParam();

        const char* lineCapName;
        switch (lineCap) {
            case kCGLineCapButt:
                lineCapName = "Butt";
                break;
            case kCGLineCapSquare:
                lineCapName = "Square";
                break;
            case kCGLineCapRound:
                lineCapName = "Round";
                break;
            default:
                break;
        }

        return CFStringCreateWithFormat(nullptr, nullptr, CFSTR("TestImage.LineWithCap.%s.png"), lineCapName);
    }
};

class CGDrawLineJoins : public WhiteBackgroundTest<>, public ::testing::WithParamInterface<CGLineJoin> {
    CFStringRef CreateOutputFilename() {
        CGLineJoin lineJoin = GetParam();

        const char* lineJoinName;
        switch (lineJoin) {
            case kCGLineJoinMiter:
                lineJoinName = "Miter";
                break;
            case kCGLineJoinBevel:
                lineJoinName = "Bevel";
                break;
            case kCGLineJoinRound:
                lineJoinName = "Round";
                break;
            default:
                break;
        }

        return CFStringCreateWithFormat(nullptr, nullptr, CFSTR("TestImage.LineWithJoin.%s.png"), lineJoinName);
    }
};

class CGDrawLineMiter : public WhiteBackgroundTest<>, public ::testing::WithParamInterface<CGFloat> {
    CFStringRef CreateOutputFilename() {
        CGFloat miterLimit = GetParam();

        return CFStringCreateWithFormat(nullptr, nullptr, CFSTR("TestImage.LineWithMiter.%g.png"), miterLimit);
    }
};

class CGDrawLineDash : public WhiteBackgroundTest<>, public ::testing::WithParamInterface<PhaseDashCount> {
    CFStringRef CreateOutputFilename() {
        PhaseDashCount dashes = GetParam();

        auto dashString = woc::MakeStrongCF<CFMutableStringRef>(CFStringCreateMutable(NULL, 0));
        for (int i = 0; i < dashes.dashPattern.size(); i++) {
            CFStringAppendFormat(dashString, NULL, CFSTR(".%g"), dashes.dashPattern[i]);
        }

        return CFStringCreateWithFormat(nullptr, nullptr, CFSTR("TestImage.LineWithPhaseDashes.%g%@.png"), dashes.phase, dashString.get());
    }
};

class CGDrawLineDashCaps : public WhiteBackgroundTest<>, public ::testing::WithParamInterface<CGLineCap> {
    CFStringRef CreateOutputFilename() {
        CGLineCap lineCap = GetParam();

        const char* lineCapName;
        switch (lineCap) {
            case kCGLineCapButt:
                lineCapName = "Butt";
                break;
            case kCGLineCapSquare:
                lineCapName = "Square";
                break;
            case kCGLineCapRound:
                lineCapName = "Round";
                break;
            default:
                break;
        }

        return CFStringCreateWithFormat(nullptr, nullptr, CFSTR("TestImage.LineDashWithCap.%s.png"), lineCapName);
    }
};

static void drawStrokeTest(CGContextRef context, CGRect bounds) {
    CGContextSetLineWidth(context, 25);
    CGContextSetRGBStrokeColor(context, 0, 0, 0, 1);

    CGFloat x = bounds.origin.x;
    CGFloat y = bounds.origin.y;
    CGFloat width = bounds.size.width;
    CGFloat height = bounds.size.height;

    CGContextMoveToPoint(context, x + width * .1, y + height * .25);
    CGContextAddLineToPoint(context, x + width * .2, y + height * .75);
    CGContextAddLineToPoint(context, x + width * .3, y + height * .25);
    CGContextAddLineToPoint(context, x + width * .4, y + height * .75);
    CGContextAddLineToPoint(context, x + width * .6, y + height * .25);
    CGContextAddLineToPoint(context, x + width * .8, y + height * .75);

    CGContextStrokePath(context);
}

DRAW_TEST_P(CGDrawLineJoins, LineJoin) {
    CGContextRef context = GetDrawingContext();
    CGRect drawingBounds = GetDrawingBounds();

    CGLineJoin lineJoin = GetParam();
    CGContextSetLineJoin(context, lineJoin);
    drawStrokeTest(context, drawingBounds);
}

DRAW_TEST_P(CGDrawLineCaps, LineCap) {
    CGContextRef context = GetDrawingContext();
    CGRect drawingBounds = GetDrawingBounds();

    CGLineCap lineCap = GetParam();
    CGContextSetLineCap(context, lineCap);
    drawStrokeTest(context, drawingBounds);
}

DRAW_TEST_P(CGDrawLineMiter, LineMiter) {
    CGContextRef context = GetDrawingContext();
    CGRect drawingBounds = GetDrawingBounds();

    CGFloat miterLimit = GetParam();
    CGContextSetLineJoin(context, kCGLineJoinMiter);
    CGContextSetMiterLimit(context, miterLimit);
    drawStrokeTest(context, drawingBounds);
}

DRAW_TEST_P(CGDrawLineDash, LineDash) {
    CGContextRef context = GetDrawingContext();
    CGRect drawingBounds = GetDrawingBounds();

    struct PhaseDashCount dashes = GetParam();
    CGContextSetLineDash(context, dashes.phase, &dashes.dashPattern[0], dashes.dashPattern.size());
    drawStrokeTest(context, drawingBounds);
}

DRAW_TEST_P(CGDrawLineDashCaps, LineDashCaps) {
    CGContextRef context = GetDrawingContext();
    CGRect drawingBounds = GetDrawingBounds();

    CGFloat dashes[] = { 5, 30 };
    CGLineCap lineCap = GetParam();

    CGContextSetLineCap(context, lineCap);
    CGContextSetLineDash(context, 0, dashes, 2);
    drawStrokeTest(context, drawingBounds);
}

INSTANTIATE_TEST_CASE_P(CGContextLineOptions, CGDrawLineJoins, ::testing::ValuesIn(sc_lineJoins));

INSTANTIATE_TEST_CASE_P(CGContextLineOptions, CGDrawLineCaps, ::testing::ValuesIn(sc_lineCaps));

INSTANTIATE_TEST_CASE_P(CGContextLineOptions, CGDrawLineMiter, ::testing::ValuesIn(sc_miterLimits));

INSTANTIATE_TEST_CASE_P(CGContextLineOptions, CGDrawLineDash, ::testing::ValuesIn(dashParams));

INSTANTIATE_TEST_CASE_P(CGContextLineOptions, CGDrawLineDashCaps, ::testing::ValuesIn(sc_lineCaps));