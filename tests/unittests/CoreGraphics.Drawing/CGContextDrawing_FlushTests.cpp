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

#if WINOBJC
#include "CGContextInternal.h"

DRAW_TEST_F(CGContextFlush, FillFlush, WhiteBackgroundTest<>) {
    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();
    _CGContextPushBeginDraw(context);

    CGContextSetRGBFillColor(context, 1, 0, 0, 1);
    CGContextFillRect(context, bounds);

    // Flush the red fill rect
    CGContextFlush(context);

    CGContextSetRGBFillColor(context, 0, 0, 1, 1);
    CGContextFillRect(context, CGRectMake(0, 0, 300, 300));

    // We should still have red & blue rectangle should not show up.
    unsigned char* dataPtr = static_cast<unsigned char*>(CGBitmapContextGetData(context));
    ASSERT_NE(dataPtr, nullptr);

    // Validate only the red fill rect is executed.
    EXPECT_EQ(dataPtr[0], 0x00);
    EXPECT_EQ(dataPtr[1], 0x00);
    EXPECT_EQ(dataPtr[2], 0xff);
    EXPECT_EQ(dataPtr[3], 0xff);

    CGContextFlush(context);

    // We should now see the blue fill rect
    EXPECT_EQ(dataPtr[0], 0xff);
    EXPECT_EQ(dataPtr[1], 0x00);
    EXPECT_EQ(dataPtr[2], 0x00);
    EXPECT_EQ(dataPtr[3], 0xff);

    // Add some extra drawings
    CGContextClearRect(context, CGRectMake(100, 100, 200, 300));

    CGPoint center = _CGRectGetCenter(bounds);

    CGMutablePathRef concentricCirclesPath = CGPathCreateMutable();

    CGPathAddEllipseInRect(concentricCirclesPath, nullptr, _CGRectCenteredOnPoint({ 50, 50 }, center));
    CGPathAddEllipseInRect(concentricCirclesPath, nullptr, _CGRectCenteredOnPoint({ 100, 100 }, center));
    CGPathAddEllipseInRect(concentricCirclesPath, nullptr, _CGRectCenteredOnPoint({ 150, 150 }, center));
    CGPathAddEllipseInRect(concentricCirclesPath, nullptr, _CGRectCenteredOnPoint({ 200, 200 }, center));

    CGContextSetRGBFillColor(context, 1.0, 0.0, 0.0, 0.5);
    CGContextSetRGBStrokeColor(context, 1.0, 0.0, 0.0, 1.0);

    CGContextAddPath(context, concentricCirclesPath);
    CGContextDrawPath(context, kCGPathFillStroke);

    CGPathRelease(concentricCirclesPath);

    _CGContextPopEndDraw(context);
}

DRAW_TEST_F(CGContextFlush, FillFlushMultipleDrawingCounters, WhiteBackgroundTest<>) {
    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();
    static int sDrawCount = 5;

    for (int i = 0; i < sDrawCount; ++i) {
        _CGContextPushBeginDraw(context);
    }

    CGContextSetRGBFillColor(context, 1, 0, 0, 1);
    CGContextFillRect(context, bounds);

    for (int i = 0; i < sDrawCount; ++i) {
        // Multiple flushes should work.
        CGContextFlush(context);
    }

    // Add some extra drawings
    CGContextClearRect(context, bounds);

    // We should still have red & clear should not of been executed.
    unsigned char* dataPtr = static_cast<unsigned char*>(CGBitmapContextGetData(context));
    ASSERT_NE(dataPtr, nullptr);

    // Validate only the red fill rect is executed.
    EXPECT_EQ(dataPtr[0], 0x00);
    EXPECT_EQ(dataPtr[1], 0x00);
    EXPECT_EQ(dataPtr[2], 0xff);
    EXPECT_EQ(dataPtr[3], 0xff);

    for (int i = 0; i < 3; ++i) {
        // Multiple flushes should work.
        CGContextFlush(context);
    }

    // validate clear
    EXPECT_EQ(dataPtr[0], 0x00);
    EXPECT_EQ(dataPtr[1], 0x00);
    EXPECT_EQ(dataPtr[2], 0x00);
    EXPECT_EQ(dataPtr[3], 0x00);

    CGContextSetRGBStrokeColor(context, 0, 1, 0, 1);
    CGContextStrokeRect(context, CGRectMake(100, 100, 200, 300));

    // Still should be clear.
    EXPECT_EQ(dataPtr[0], 0x00);
    EXPECT_EQ(dataPtr[1], 0x00);
    EXPECT_EQ(dataPtr[2], 0x00);
    EXPECT_EQ(dataPtr[3], 0x00);

    for (int i = 0; i < sDrawCount; ++i) {
        _CGContextPopEndDraw(context);
    }
}

#endif