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

#include <TestFramework.h>
#import <CoreText/CoreText.h>
#include "CppUtils.h"

const static float c_errorDelta = 0.001f;

TEST(CoreText, CTParagraphStyle) {
    CTParagraphStyleRef paragraphStyle = CTParagraphStyleCreate(nullptr, 0);
    EXPECT_NE_MSG(paragraphStyle, nullptr, "FAILED: Could not create paragraph style");

    CGFloat val = 2.0f;
    CTParagraphStyleSetting settings[1] = { {.spec = kCTParagraphStyleSpecifierTailIndent, .valueSize = sizeof(CGFloat), .value = &val } };
    paragraphStyle = CTParagraphStyleCreate(settings, 1);
    EXPECT_NE_MSG(paragraphStyle, nullptr, "FAILED: Could not create paragraph style");

    CGFloat bufferFloat;
    bool success =
        CTParagraphStyleGetValueForSpecifier(paragraphStyle, kCTParagraphStyleSpecifierTailIndent, sizeof(CGFloat), &bufferFloat);
    EXPECT_TRUE_MSG(success, "FAILED: Could not found the specifier that was set.");
    EXPECT_NEAR(bufferFloat, val, .0001f);

    CTParagraphStyleRef paragraphStyleCopy = CTParagraphStyleCreateCopy(nullptr);
    EXPECT_EQ(paragraphStyleCopy, nullptr);

    paragraphStyleCopy = CTParagraphStyleCreateCopy(paragraphStyle);
    bufferFloat = 3.0f;
    success = CTParagraphStyleGetValueForSpecifier(paragraphStyleCopy, kCTParagraphStyleSpecifierTailIndent, sizeof(CGFloat), &bufferFloat);
    EXPECT_TRUE_MSG(success, "FAILED: Could not found the specifier that was set.");
    EXPECT_NEAR(bufferFloat, val, .0001f);

    CTTextAlignment defaultTextAlignment = kCTJustifiedTextAlignment;
    val = 9.0f;
    CTParagraphStyleSetting settings2[2] = { {.spec = kCTParagraphStyleSpecifierAlignment,
                                              .valueSize = sizeof(CTTextAlignment),
                                              .value = &defaultTextAlignment },
                                             {.spec = kCTParagraphStyleSpecifierTailIndent, .valueSize = sizeof(CGFloat), .value = &val } };
    paragraphStyle = CTParagraphStyleCreate(settings2, 2);
    EXPECT_NE_MSG(paragraphStyle, nullptr, "FAILED: Could not create paragraph style");

    CTTextAlignment buffer;
    success = CTParagraphStyleGetValueForSpecifier(paragraphStyle, kCTParagraphStyleSpecifierAlignment, sizeof(CTTextAlignment), &buffer);
    EXPECT_TRUE_MSG(success, "FAILED: Could not found the specifier that was set.");
    EXPECT_EQ(buffer, kCTJustifiedTextAlignment);

    paragraphStyleCopy = CTParagraphStyleCreateCopy(paragraphStyle);
    success =
        CTParagraphStyleGetValueForSpecifier(paragraphStyleCopy, kCTParagraphStyleSpecifierAlignment, sizeof(CTTextAlignment), &buffer);
    EXPECT_TRUE_MSG(success, "FAILED: Could not found the specifier that was set.");
    EXPECT_EQ(buffer, kCTJustifiedTextAlignment);

    success = CTParagraphStyleGetValueForSpecifier(paragraphStyleCopy, kCTParagraphStyleSpecifierTailIndent, sizeof(CGFloat), &bufferFloat);
    EXPECT_TRUE_MSG(success, "FAILED: Could not find the specifier that was set");
    EXPECT_NEAR(bufferFloat, val, .0001f);

    success = CTParagraphStyleGetValueForSpecifier(paragraphStyleCopy,
                                                   kCTParagraphStyleSpecifierLineHeightMultiple,
                                                   sizeof(CGFloat),
                                                   &bufferFloat);
    EXPECT_TRUE(success);
    EXPECT_NEAR(bufferFloat, 0.0f, .0001f);

    success = CTParagraphStyleGetValueForSpecifier(paragraphStyleCopy,
                                                   kCTParagraphStyleSpecifierMaximumLineSpacing,
                                                   sizeof(CGFloat),
                                                   &bufferFloat);
    EXPECT_TRUE(success);
    EXPECT_NEAR(bufferFloat, 0.0f, .0001f);

    success = CTParagraphStyleGetValueForSpecifier(paragraphStyleCopy,
                                                   kCTParagraphStyleSpecifierLineHeightMultiple,
                                                   sizeof(CGFloat),
                                                   &bufferFloat);
    EXPECT_TRUE(success);

    success = CTParagraphStyleGetValueForSpecifier(paragraphStyleCopy, 513, sizeof(CGFloat), nullptr);
    EXPECT_FALSE_MSG(success, "FAILED: An invalid specifier crash should not occur.");
}

TEST(CoreText, KernAttribute) {
    const static float c_diff = 2.0f;
    NSMutableAttributedString* string = [[[NSMutableAttributedString alloc] initWithString:@"TESTTESTTEST"] autorelease];
    [string setAttributes:@{ static_cast<NSString*>(kCTKernAttributeName) : [NSNumber numberWithFloat:0.0f] } range:NSMakeRange(0, 4)];
    [string setAttributes:@{ static_cast<NSString*>(kCTKernAttributeName) : [NSNumber numberWithFloat:c_diff] } range:NSMakeRange(4, 4)];
    [string setAttributes:@{ static_cast<NSString*>(kCTKernAttributeName) : [NSNumber numberWithFloat:-c_diff] } range:NSMakeRange(8, 4)];
    CTLineRef line = CTLineCreateWithAttributedString(static_cast<CFAttributedStringRef>(string));
    CFAutorelease(line);
    CFArrayRef runs = CTLineGetGlyphRuns(line);
    ASSERT_EQ(3, CFArrayGetCount(runs));

    CTRunRef firstRun = static_cast<CTRunRef>(CFArrayGetValueAtIndex(runs, 0));
    CTRunRef secondRun = static_cast<CTRunRef>(CFArrayGetValueAtIndex(runs, 1));
    CTRunRef thirdRun = static_cast<CTRunRef>(CFArrayGetValueAtIndex(runs, 2));

    CGSize firstAdvances[4], secondAdvances[4], thirdAdvances[4];
    CTRunGetAdvances(firstRun, { 0, 0 }, firstAdvances);
    CTRunGetAdvances(secondRun, { 0, 0 }, secondAdvances);
    CTRunGetAdvances(thirdRun, { 0, 0 }, thirdAdvances);

    EXPECT_NEAR(secondAdvances[0].width, firstAdvances[0].width + c_diff, c_errorDelta);
    EXPECT_NEAR(secondAdvances[1].width, firstAdvances[1].width + c_diff, c_errorDelta);
    EXPECT_NEAR(secondAdvances[2].width, firstAdvances[2].width + c_diff, c_errorDelta);
    EXPECT_NEAR(secondAdvances[3].width, firstAdvances[3].width + c_diff, c_errorDelta);
    EXPECT_NEAR(thirdAdvances[0].width, firstAdvances[0].width - c_diff, c_errorDelta);
    EXPECT_NEAR(thirdAdvances[1].width, firstAdvances[1].width - c_diff, c_errorDelta);
    EXPECT_NEAR(thirdAdvances[2].width, firstAdvances[2].width - c_diff, c_errorDelta);
    EXPECT_NEAR(thirdAdvances[3].width, firstAdvances[3].width - c_diff, c_errorDelta);
}

class CoreTextLineSpaceMultipleTest : public ::testing::TestWithParam<CGFloat> {
protected:
    virtual void SetUp() {
        NSMutableAttributedString* normalString = [[[NSMutableAttributedString alloc] initWithString:@"TEST\nTEST\nTEST"] autorelease];
        CTFramesetterRef normalFramesetter = CTFramesetterCreateWithAttributedString(static_cast<CFAttributedStringRef>(normalString));
        CFAutorelease(normalFramesetter);
        path = CGPathCreateWithRect(CGRectMake(0, 0, FLT_MAX, FLT_MAX), nullptr);
        CTFrameRef normalFrame = CTFramesetterCreateFrame(normalFramesetter, {}, path, nullptr);
        CFAutorelease(normalFrame);
        CGPoint normalOrigins[3];
        CTFrameGetLineOrigins(normalFrame, {}, normalOrigins);
        normalLineSpaceFirst = normalOrigins[1].y - normalOrigins[0].y;
        normalLineSpaceSecond = normalOrigins[2].y - normalOrigins[0].y;
    }

    virtual void TearDown() {
        CGPathRelease(path);
    }

public:
    CGFloat normalLineSpaceFirst = 0;
    CGFloat normalLineSpaceSecond = 0;
    CGPathRef path;
};

TEST_P(CoreTextLineSpaceMultipleTest, OriginsShouldBeMovedByRatio) {
    NSMutableAttributedString* multipleString = [[[NSMutableAttributedString alloc] initWithString:@"TEST\nTEST\nTEST"] autorelease];
    CGFloat multiple = GetParam();
    CTParagraphStyleSetting settings[1] = {
        {.spec = kCTParagraphStyleSpecifierLineHeightMultiple, .valueSize = sizeof(CGFloat), .value = &multiple }
    };
    NSDictionary* attributes = @{ static_cast<NSString*>(kCTParagraphStyleAttributeName) : (id)CTParagraphStyleCreate(settings, 1) };
    [multipleString setAttributes:attributes range:NSMakeRange(0, 14)];
    CTFramesetterRef multipleFramesetter = CTFramesetterCreateWithAttributedString(static_cast<CFAttributedStringRef>(multipleString));
    CFAutorelease(multipleFramesetter);
    CTFrameRef multipleFrame = CTFramesetterCreateFrame(multipleFramesetter, {}, path, nullptr);
    CFAutorelease(multipleFrame);
    CGPoint multipleOrigins[3];
    CTFrameGetLineOrigins(multipleFrame, {}, multipleOrigins);
    EXPECT_NEAR(multiple * normalLineSpaceFirst, multipleOrigins[1].y - multipleOrigins[0].y, c_errorDelta);
    EXPECT_NEAR(multiple * normalLineSpaceSecond, multipleOrigins[2].y - multipleOrigins[0].y, c_errorDelta);
}

INSTANTIATE_TEST_CASE_P(OriginsShouldBeMovedByRatio,
                        CoreTextLineSpaceMultipleTest,
                        ::testing::Values(0.5, 1.0, 1.5, 2.0, 4.0, 16.0, 255.9, []() {
                            // Need to seed rand before calling to prevent getting the same value each time
                            srand(time(nullptr));
                            return (CGFloat)rand() / (CGFloat)RAND_MAX;
                        }()));

// Parameters with values of (line breaking mode, number of lines, string range of last line)
class CoreTextLineBreakModeTest : public ::testing::TestWithParam<::testing::tuple<CTLineBreakMode, CFIndex, CFRange>> {
protected:
    virtual void SetUp() {
        path = CGPathCreateWithRect(CGRectMake(0, 0, 80, FLT_MAX), nullptr);
    }

    virtual void TearDown() {
        CGPathRelease(path);
    }

public:
    CGPathRef path;
};

TEST_P(CoreTextLineBreakModeTest, ShouldBreakLinesCorrectly) {
    CTLineBreakMode lineBreakMode = ::testing::get<0>(GetParam());
    CFIndex lineCount = ::testing::get<1>(GetParam());
    CFRange stringRange = ::testing::get<2>(GetParam());
    NSMutableAttributedString* attrString = [[[NSMutableAttributedString alloc] initWithString:@"TEST TEST TEST"] autorelease];
    CTParagraphStyleSetting settings[1] = {
        {.spec = kCTParagraphStyleSpecifierLineBreakMode, .valueSize = sizeof(CTLineBreakMode), .value = &lineBreakMode }
    };
    NSDictionary* attributes = @{ static_cast<NSString*>(kCTParagraphStyleAttributeName) : (id)CTParagraphStyleCreate(settings, 1) };
    [attrString setAttributes:attributes range:NSMakeRange(0, 14)];
    CTFramesetterRef framesetter = CTFramesetterCreateWithAttributedString(static_cast<CFAttributedStringRef>(attrString));
    CFAutorelease(framesetter);
    CTFrameRef frame = CTFramesetterCreateFrame(framesetter, {}, path, nullptr);
    CFAutorelease(frame);
    CFArrayRef lines = CTFrameGetLines(frame);
    EXPECT_EQ(lineCount, CFArrayGetCount(lines));
    CTLineRef lastLine = static_cast<CTLineRef>(CFArrayGetValueAtIndex(lines, lineCount - 1));
    EXPECT_EQ(stringRange, CTLineGetStringRange(lastLine));
}

INSTANTIATE_TEST_CASE_P(ShouldBreakLinesCorrectly,
                        CoreTextLineBreakModeTest,
                        ::testing::Values(::testing::make_tuple(kCTLineBreakByWordWrapping, 2, CFRange{ 10, 4 }),
                                          ::testing::make_tuple(kCTLineBreakByCharWrapping, 2, CFRange{ 11, 3 }),
                                          ::testing::make_tuple(kCTLineBreakByClipping, 1, CFRange{ 0, 14 })));
