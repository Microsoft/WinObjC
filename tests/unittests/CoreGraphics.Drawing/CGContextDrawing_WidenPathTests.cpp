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

CGLineCap lineCaps[] = { kCGLineCapButt, kCGLineCapSquare, kCGLineCapRound };
CGLineJoin lineJoins[] = { kCGLineJoinMiter, kCGLineJoinBevel, kCGLineJoinRound };
CGFloat miterLimits[] = { 0, 1, 5 };
bool shouldUseContext[] = { false, true };

class CGPathCopyByStroking_Lines : public WhiteBackgroundTest<>,
                                   public ::testing::WithParamInterface<::testing::tuple<CGLineCap, CGLineJoin, CGFloat, bool>> {
    CFStringRef CreateOutputFilename() {
        CGLineCap lineCap = ::testing::get<0>(GetParam());
        CGLineJoin lineJoin = ::testing::get<1>(GetParam());
        CGFloat miterLimit = ::testing::get<2>(GetParam());
        bool useContext = ::testing::get<3>(GetParam());

        const char* lineCapName;
        switch (lineCap) {
            case kCGLineCapButt:
                lineCapName = "LineCapButt";
                break;
            case kCGLineCapSquare:
                lineCapName = "LineCapSquare";
                break;
            case kCGLineCapRound:
                lineCapName = "LineCapRound";
                break;
            default:
                break;
        }

        const char* lineJoinName;
        switch (lineJoin) {
            case kCGLineJoinMiter:
                lineJoinName = "LineJoinMiter";
                break;
            case kCGLineJoinBevel:
                lineJoinName = "LineJoinBevel";
                break;
            case kCGLineJoinRound:
                lineJoinName = "LineJoinRound";
                break;
            default:
                break;
        }

        return CFStringCreateWithFormat(nullptr,
                                        nullptr,
                                        CFSTR("TestImage.CopyByStroking_Lines.%f.%s.%s.%s.png"),
                                        miterLimit,
                                        lineJoinName,
                                        lineCapName,
                                        useContext ? "Context" : "Path");
    }
};

class CGPathCopyByStroking_Curves : public WhiteBackgroundTest<>,
                                    public ::testing::WithParamInterface<::testing::tuple<CGLineCap, CGFloat, bool>> {
    CFStringRef CreateOutputFilename() {
        CGLineCap lineCap = ::testing::get<0>(GetParam());
        CGFloat miterLimit = ::testing::get<1>(GetParam());
        bool useContext = ::testing::get<2>(GetParam());

        const char* lineCapName;
        switch (lineCap) {
            case kCGLineCapButt:
                lineCapName = "LineCapButt";
                break;
            case kCGLineCapSquare:
                lineCapName = "LineCapSquare";
                break;
            case kCGLineCapRound:
                lineCapName = "LineCapRound";
                break;
            default:
                break;
        }

        return CFStringCreateWithFormat(nullptr,
                                        nullptr,
                                        CFSTR("TestImage.CopyByStroking_Arcs.%f.%s.png"),
                                        miterLimit,
                                        lineCapName,
                                        useContext ? "Context" : "Path");
    }
};

class CGPathCopyByStroking_OpenFigure0Width : public WhiteBackgroundTest<>, public ::testing::WithParamInterface<bool> {
    CFStringRef CreateOutputFilename() {
        bool useContext = GetParam();

        return CFStringCreateWithFormat(nullptr,
                                        nullptr,
                                        CFSTR("TestImage.CopyByStrokingLinesIndidivudal.ZeroWidth.%s.png"),
                                        useContext ? "Context" : "Path");
    }
};

class CGPathCopyByStroking_OpenFigure : public WhiteBackgroundTest<>,
                                        public ::testing::WithParamInterface<::testing::tuple<CGLineJoin, CGFloat, bool>> {
    CFStringRef CreateOutputFilename() {
        CGLineJoin lineJoin = ::testing::get<0>(GetParam());
        CGFloat miterLimit = ::testing::get<1>(GetParam());
        bool useContext = ::testing::get<2>(GetParam());

        const char* lineJoinName;
        switch (lineJoin) {
            case kCGLineJoinMiter:
                lineJoinName = "LineJoinMiter";
                break;
            case kCGLineJoinBevel:
                lineJoinName = "LineJoinBevel";
                break;
            case kCGLineJoinRound:
                lineJoinName = "LineJoinRound";
                break;
            default:
                break;
        }

        return CFStringCreateWithFormat(nullptr,
                                        nullptr,
                                        CFSTR("TestImage.CopyByStrokingLinesIndidivudal.%f.%s.%s.png"),
                                        miterLimit,
                                        lineJoinName,
                                        useContext ? "Context" : "Path");
    }
};

static void drawStrokeTestWithParams(
    CGContextRef context, CGPathRef path, CGLineCap cap, CGLineJoin join, CGFloat lineWidth, CGFloat miterLimit, bool useContext) {
    if (useContext) {
        CGContextSaveGState(context);
        CGContextAddPath(context, path);
        CGContextSetLineWidth(context, 10);
        CGContextSetLineJoin(context, join);
        CGContextSetLineCap(context, cap);
        CGContextSetMiterLimit(context, miterLimit);

        CGContextReplacePathWithStrokedPath(context);
        CGContextRestoreGState(context);
    } else {
        CGPathRef widenedPath = CGPathCreateCopyByStrokingPath(path, NULL, 10, cap, join, miterLimit);
        CGContextAddPath(context, widenedPath);
        CGPathRelease(widenedPath);
    }
    CGContextSetRGBStrokeColor(context, 0, 0, 1, 1);
    CGContextStrokePath(context);
}

DRAW_TEST_P(CGPathCopyByStroking_Lines, PathWiden) {
    CGContextRef context = GetDrawingContext();
    CGRect drawingBounds = GetDrawingBounds();
    CGFloat width = drawingBounds.size.width;
    CGFloat height = drawingBounds.size.height;
    CGFloat xstart = drawingBounds.origin.x;
    CGFloat ystart = drawingBounds.origin.y;

    CGMutablePathRef thepath = CGPathCreateMutable();
    CGPathMoveToPoint(thepath, NULL, xstart + .5 * width, ystart + .1 * height);
    CGPathAddLineToPoint(thepath, NULL, xstart + .35 * width, ystart + .3 * height);
    CGPathAddLineToPoint(thepath, NULL, xstart + .1 * width, ystart + .3 * height);
    CGPathAddLineToPoint(thepath, NULL, xstart + .3 * width, ystart + .5 * height);
    CGPathAddLineToPoint(thepath, NULL, xstart + .25 * width, ystart + .9 * height);
    CGPathAddLineToPoint(thepath, NULL, xstart + .5 * width, ystart + .7 * height);
    CGPathAddLineToPoint(thepath, NULL, xstart + .75 * width, ystart + .9 * height);
    CGPathAddLineToPoint(thepath, NULL, xstart + .7 * width, ystart + .5 * height);
    CGPathAddLineToPoint(thepath, NULL, xstart + .9 * width, ystart + .3 * height);
    CGPathAddLineToPoint(thepath, NULL, xstart + .65 * width, ystart + .3 * height);
    CGPathAddLineToPoint(thepath, NULL, xstart + .5 * width, ystart + .1 * height);
    CGPathCloseSubpath(thepath);

    CGLineCap lineCap = ::testing::get<0>(GetParam());
    CGLineJoin lineJoin = ::testing::get<1>(GetParam());
    CGFloat miterLimit = ::testing::get<2>(GetParam());
    bool useContext = ::testing::get<3>(GetParam());

    drawStrokeTestWithParams(context, thepath, lineCap, lineJoin, 10, miterLimit, useContext);

    CGPathRelease(thepath);
}

static void CreateOpenFigurePaths(CGContextRef context,
                                  CGFloat xstart,
                                  CGFloat ystart,
                                  CGFloat width,
                                  CGFloat height,
                                  CGLineJoin lineJoin,
                                  CGFloat miterLimit,
                                  bool useContext) {
    CGMutablePathRef straightLine1 = CGPathCreateMutable();
    CGPathMoveToPoint(straightLine1, NULL, xstart + .1 * width, ystart + .5 * height);
    CGPathAddLineToPoint(straightLine1, NULL, xstart + .1 * width, ystart + .1 * height);
    CGPathAddLineToPoint(straightLine1, NULL, xstart + .2 * width, ystart + .1 * height);

    CGMutablePathRef straightLine2 = CGPathCreateMutable();
    CGPathMoveToPoint(straightLine2, NULL, xstart + .2 * width, ystart + .6 * height);
    CGPathAddLineToPoint(straightLine2, NULL, xstart + .2 * width, ystart + .2 * height);
    CGPathAddLineToPoint(straightLine2, NULL, xstart + .3 * width, ystart + .2 * height);

    CGMutablePathRef straightLine3 = CGPathCreateMutable();
    CGPathMoveToPoint(straightLine3, NULL, xstart + .3 * width, ystart + .7 * height);
    CGPathAddLineToPoint(straightLine3, NULL, xstart + .3 * width, ystart + .3 * height);
    CGPathAddLineToPoint(straightLine3, NULL, xstart + .4 * width, ystart + .3 * height);

    CGMutablePathRef curvedLine1 = CGPathCreateMutable();
    CGPathMoveToPoint(curvedLine1, NULL, xstart + .9 * width, ystart + .5 * height);
    CGPathAddArcToPoint(
        curvedLine1, NULL, xstart + .9 * width, ystart + .9 * height, xstart + .8 * width, ystart + .9 * height, width * .1);

    CGMutablePathRef curvedLine2 = CGPathCreateMutable();
    CGPathMoveToPoint(curvedLine2, NULL, xstart + .8 * width, ystart + .4 * height);
    CGPathAddArcToPoint(
        curvedLine2, NULL, xstart + .8 * width, ystart + .8 * height, xstart + .7 * width, ystart + .8 * height, width * .1);

    CGMutablePathRef curvedLine3 = CGPathCreateMutable();
    CGPathMoveToPoint(curvedLine3, NULL, xstart + .7 * width, ystart + .3 * height);
    CGPathAddArcToPoint(
        curvedLine3, NULL, xstart + .7 * width, ystart + .7 * height, xstart + .6 * width, ystart + .7 * height, width * .1);

    drawStrokeTestWithParams(context, straightLine1, kCGLineCapButt, lineJoin, 10, miterLimit, useContext);
    drawStrokeTestWithParams(context, straightLine2, kCGLineCapSquare, lineJoin, 10, miterLimit, useContext);
    drawStrokeTestWithParams(context, straightLine3, kCGLineCapRound, lineJoin, 10, miterLimit, useContext);

    drawStrokeTestWithParams(context, curvedLine1, kCGLineCapButt, lineJoin, 10, miterLimit, useContext);
    drawStrokeTestWithParams(context, curvedLine2, kCGLineCapSquare, lineJoin, 10, miterLimit, useContext);
    drawStrokeTestWithParams(context, curvedLine3, kCGLineCapRound, lineJoin, 10, miterLimit, useContext);

    CGPathRelease(straightLine1);
    CGPathRelease(straightLine2);
    CGPathRelease(straightLine3);
    CGPathRelease(curvedLine1);
    CGPathRelease(curvedLine2);
    CGPathRelease(curvedLine3);
}

DRAW_TEST_P(CGPathCopyByStroking_OpenFigure0Width, PathWiden) {
    CGContextRef context = GetDrawingContext();
    CGRect drawingBounds = GetDrawingBounds();
    CGFloat width = drawingBounds.size.width;
    CGFloat height = drawingBounds.size.height;
    CGFloat xstart = drawingBounds.origin.x;
    CGFloat ystart = drawingBounds.origin.y;

    bool useContext = GetParam();

    CreateOpenFigurePaths(context, xstart, ystart, width, height, kCGLineJoinMiter, 0, useContext);
}

DRAW_TEST_P(CGPathCopyByStroking_OpenFigure, PathWiden) {
    CGContextRef context = GetDrawingContext();
    CGRect drawingBounds = GetDrawingBounds();
    CGFloat width = drawingBounds.size.width;
    CGFloat height = drawingBounds.size.height;
    CGFloat xstart = drawingBounds.origin.x;
    CGFloat ystart = drawingBounds.origin.y;

    CGLineJoin lineJoin = ::testing::get<0>(GetParam());
    CGFloat miterLimit = ::testing::get<1>(GetParam());
    bool useContext = ::testing::get<2>(GetParam());

    CreateOpenFigurePaths(context, xstart, ystart, width, height, lineJoin, miterLimit, useContext);
}

DRAW_TEST_P(CGPathCopyByStroking_Curves, PathWiden) {
    CGContextRef context = GetDrawingContext();
    CGRect drawingBounds = GetDrawingBounds();
    CGFloat width = drawingBounds.size.width;
    CGFloat height = drawingBounds.size.height;
    CGFloat xstart = drawingBounds.origin.x;
    CGFloat ystart = drawingBounds.origin.y;

    CGAffineTransform transformation = CGAffineTransformIdentity;
    transformation = CGAffineTransformScale(transformation, .8, .8);
    transformation = CGAffineTransformTranslate(transformation, .1 * width, .1 * height);

    CGMutablePathRef thepath = CGPathCreateMutable();
    CGPathMoveToPoint(thepath, &transformation, xstart + .75 * width, ystart + .5 * height);
    CGPathAddArc(thepath, &transformation, xstart + .5 * width, ystart + .5 * height, .5 * height, 0, M_PI / 2, true);
    CGPathAddArc(thepath, &transformation, xstart + .5 * width, ystart + .5 * height, .5 * height, M_PI / 2, 0, true);

    CGLineCap lineCap = ::testing::get<0>(GetParam());
    CGFloat miterLimit = ::testing::get<1>(GetParam());
    bool useContext = ::testing::get<2>(GetParam());

    drawStrokeTestWithParams(context, thepath, lineCap, kCGLineJoinMiter, 10, miterLimit, useContext);

    CGPathRelease(thepath);
}

INSTANTIATE_TEST_CASE_P(CGPathWidenTest,
                        CGPathCopyByStroking_Lines,
                        ::testing::Combine(::testing::ValuesIn(lineCaps),
                                           ::testing::ValuesIn(lineJoins),
                                           ::testing::ValuesIn(miterLimits),
                                           ::testing::ValuesIn(shouldUseContext)));

INSTANTIATE_TEST_CASE_P(CGPathWidenTest,
                        CGPathCopyByStroking_Curves,
                        ::testing::Combine(::testing::ValuesIn(lineCaps),
                                           ::testing::ValuesIn(miterLimits),
                                           ::testing::ValuesIn(shouldUseContext)));

INSTANTIATE_TEST_CASE_P(CGPathWidenTest,
                        CGPathCopyByStroking_OpenFigure,
                        ::testing::Combine(::testing::ValuesIn(lineJoins),
                                           ::testing::ValuesIn(miterLimits),
                                           ::testing::ValuesIn(shouldUseContext)));

INSTANTIATE_TEST_CASE_P(CGPathWidenTest, CGPathCopyByStroking_OpenFigure0Width, ::testing::ValuesIn(shouldUseContext));