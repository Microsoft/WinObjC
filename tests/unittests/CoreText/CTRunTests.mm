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
#include "Starboard.h"
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <CoreText/CoreText.h>
#import <CoreFoundation/CFAttributedString.h>
#import <CppUtils.h>

#include <functional>

static constexpr double c_errorDelta = 0.0005;
static constexpr float c_arbitraryFloat = 114138.2292;

NSMutableAttributedString* getString(NSString* str) {
    UIFontDescriptor* fontDescriptor = [UIFontDescriptor fontDescriptorWithName:@"Segoe UI" size:40];
    UIFont* font = [UIFont fontWithDescriptor:fontDescriptor size:40];

    NSRange wholeRange = NSMakeRange(0, str.length);
    NSMutableAttributedString* string = [[NSMutableAttributedString alloc] initWithString:str];
    [string addAttribute:NSForegroundColorAttributeName value:[UIColor redColor] range:wholeRange];
    [string addAttribute:NSFontAttributeName value:font range:wholeRange];
    [string addAttribute:@"testKey" value:[UIColor blueColor] range:wholeRange];

    return string;
}

class TypographicBounds : public ::testing::TestWithParam<::testing::tuple<std::function<CFRange(CFRange)>, double>> {
public:
    explicit TypographicBounds()
        : _lineRef(nullptr),
          _pathRef(nullptr),
          _attributedStringRef(nullptr),
          _textLength(0),
          _run(nullptr),
          _runRange{ 0, 0 },
          ::testing::TestWithParam<::testing::tuple<std::function<CFRange(CFRange)>, double>>() {
    }

protected:
    virtual void SetUp() {
        _textLength = CFStringGetLength((CFStringRef)c_testString);
        CFRange currentRange = CFRangeMake(0, _textLength);

        _attributedStringRef = static_cast<CFAttributedStringRef>([[NSMutableAttributedString alloc] initWithString:c_testString]);

        UIFont* font = [UIFont fontWithName:@"Arial" size:12.0];
        ASSERT_TRUE_MSG(font != nullptr, "FAILED: Font not available!");

        CTFontRef fontRef = CTFontCreateWithName(static_cast<CFStringRef>(font.fontName), font.pointSize, NULL);
        ASSERT_TRUE_MSG(fontRef != nullptr, "FAILED: Could not create font!");

        CFAttributedStringSetAttribute(const_cast<__CFAttributedString*>(_attributedStringRef),
                                       currentRange,
                                       kCTFontAttributeName,
                                       fontRef);
        _lineRef = CTLineCreateWithAttributedString(_attributedStringRef);
        ASSERT_TRUE_MSG(_lineRef != nullptr, "FAILED: Could not create line!");

        CFArrayRef runs = CTLineGetGlyphRuns(const_cast<__CTLine*>(_lineRef));
        _run = static_cast<const __CTRun*>(CFArrayGetValueAtIndex(runs, 0));
        _runRange = CTRunGetStringRange(const_cast<__CTRun*>(_run));
    }

    virtual void TearDown() {
        if (_pathRef) {
            CGPathRelease(_pathRef);
        }
        if (_attributedStringRef) {
            CFRelease(_attributedStringRef);
        }
        if (_lineRef) {
            CFRelease(_lineRef);
        }
    }

    CTFrameRef _frameRef;
    CTLineRef _lineRef;
    CGPathRef _pathRef;
    CFAttributedStringRef _attributedStringRef;
    NSInteger _textLength;
    const __CTRun* _run;
    CFRange _runRange;

    static constexpr NSString* const c_testString = @"bp";
    static constexpr float c_ascentExpected = 8.7363f;
    static constexpr float c_descentExpected = 2.3848f;
    static constexpr float c_leadingExpected = 0.392578f;
};

TEST_F(TypographicBounds, InvalidRange) {
    CGFloat ascent = 0.0;
    CGFloat descent = 0.0;
    CGFloat leading = 0.0;

    // Invalid Range (range is greater than range of characters in run)
    // Expected: width is 0.
    CFRange invalidRange = CFRangeMake(0, _textLength + 1);
    double width = CTRunGetTypographicBounds(_run, invalidRange, &ascent, &descent, &leading);
    ASSERT_EQ_MSG(width, 0, "Failed: Typographic width is incorrect");
}

TEST_P(TypographicBounds, VerifyBounds) {
    CGFloat ascent = 0.0;
    CGFloat descent = 0.0;
    CGFloat leading = 0.0;

    double width = CTRunGetTypographicBounds(_run, ::testing::get<0>(GetParam())(_runRange), &ascent, &descent, &leading);
    EXPECT_NEAR_MSG(ascent, c_ascentExpected, c_errorDelta, "Failed: Run ascent value is incorrect");
    EXPECT_NEAR_MSG(descent, c_descentExpected, c_errorDelta, "Failed: Run descent value is incorrect");
    EXPECT_NEAR_MSG(leading, c_leadingExpected, c_errorDelta, "Failed: Run leading value is incorrect");
    EXPECT_NEAR_MSG(width, ::testing::get<1>(GetParam()), c_errorDelta, "Failed: Typographic width is incorrect");
}

const double widthExpected = 13.3477;
const double reducedWidthExpected = 6.6738;

INSTANTIATE_TEST_CASE_P(CTRun,
                        TypographicBounds,
                        ::testing::Values(::testing::make_tuple([](CFRange range) { return range; }, widthExpected),
                                          ::testing::make_tuple([](CFRange range) { return CFRangeMake(-1, 2); }, reducedWidthExpected),
                                          ::testing::make_tuple([](CFRange range) { return CFRangeMake(-1, 0); }, widthExpected)));

TEST(CTRun, GetAttributes) {
    CTLineRef line = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)getString(@"hello"));
    CFArrayRef runsArray = CTLineGetGlyphRuns(line);
    CTRunRef run = (CTRunRef)CFArrayGetValueAtIndex(runsArray, 0);

    EXPECT_EQ(nullptr, CTRunGetAttributes(nullptr));

    CFDictionaryRef dictionary = CTRunGetAttributes(run);
    UIFont* font = (UIFont*)CFDictionaryGetValue(dictionary, NSFontAttributeName);
    ASSERT_TRUE_MSG([font isKindOfClass:[UIFont class]], "Failed: Wrong object type in dictionary");
    NSString* fontName = ((UIFont*)font).fontName;
    ASSERT_OBJCEQ_MSG(fontName, @"Segoe UI", "Failed: Wrong data in dictionary");

    UIColor* color = (UIColor*)CFDictionaryGetValue(dictionary, NSForegroundColorAttributeName);
    ASSERT_TRUE_MSG([color isKindOfClass:[UIColor class]], "Failed: Wrong object type in dictionary");
    ASSERT_TRUE_MSG([color isEqual:[UIColor redColor]], "Failed: Wrong object type in dictionary");

    color = (UIColor*)CFDictionaryGetValue(dictionary, @"testKey");
    ASSERT_TRUE_MSG([color isKindOfClass:[UIColor class]], "Failed: Wrong object type in dictionary");
    ASSERT_TRUE_MSG([color isEqual:[UIColor blueColor]], "Failed: Wrong object type in dictionary");
}

TEST(CTRun, GetAdvances) {
    CFAttributedStringRef string = (__bridge CFAttributedStringRef)getString(@"hello");
    CTLineRef line = CTLineCreateWithAttributedString(string);
    CFArrayRef runsArray = CTLineGetGlyphRuns(line);
    CTRunRef run = (CTRunRef)CFArrayGetValueAtIndex(runsArray, 0);
    std::vector<CGSize> advances(6);

    EXPECT_NO_THROW(CTRunGetAdvances(nullptr, CFRangeMake(0, 0), nullptr));
    EXPECT_NO_THROW(CTRunGetAdvances(run, CFRangeMake(0, 0), nullptr));

    std::fill(advances.begin(), advances.end(), CGSizeMake(c_arbitraryFloat, c_arbitraryFloat));
    EXPECT_NO_THROW(CTRunGetAdvances(nullptr, CFRangeMake(0, 0), advances.data()));

    std::fill(advances.begin(), advances.end(), CGSizeMake(c_arbitraryFloat, c_arbitraryFloat));
    CTRunGetAdvances(run, CFRangeMake(10, 1), advances.data());
    EXPECT_EQ(c_arbitraryFloat, advances[0].height);
    EXPECT_EQ(c_arbitraryFloat, advances[0].width);

    std::fill(advances.begin(), advances.end(), CGSizeMake(c_arbitraryFloat, c_arbitraryFloat));
    CTRunGetAdvances(run, CFRangeMake(1, 1), advances.data());
    EXPECT_EQ(0, advances[0].height);
    EXPECT_NEAR(20.918, advances[0].width, c_errorDelta);
    EXPECT_EQ(c_arbitraryFloat, advances[1].height);
    EXPECT_EQ(c_arbitraryFloat, advances[1].width);

    std::fill(advances.begin(), advances.end(), CGSizeMake(c_arbitraryFloat, c_arbitraryFloat));
    CTRunGetAdvances(run, CFRangeMake(0, 0), advances.data());
    EXPECT_EQ(0, advances[0].height);
    EXPECT_NEAR(22.637, advances[0].width, c_errorDelta);
    EXPECT_EQ(0, advances[1].height);
    EXPECT_NEAR(20.918, advances[1].width, c_errorDelta);
    EXPECT_EQ(0, advances[2].height);
    EXPECT_NEAR(9.6875, advances[2].width, c_errorDelta);
    EXPECT_EQ(0, advances[3].height);
    EXPECT_NEAR(9.6875, advances[3].width, c_errorDelta);
    EXPECT_EQ(0, advances[4].height);
    EXPECT_NEAR(23.438, advances[4].width, c_errorDelta);
    EXPECT_EQ(c_arbitraryFloat, advances[5].height);
    EXPECT_EQ(c_arbitraryFloat, advances[5].width);

    // Length greater than available advances, does nothing
    std::fill(advances.begin(), advances.end(), CGSizeMake(c_arbitraryFloat, c_arbitraryFloat));
    CTRunGetAdvances(run, CFRangeMake(0, 5000), advances.data());
    EXPECT_EQ(c_arbitraryFloat, advances[0].height);
    EXPECT_EQ(c_arbitraryFloat, advances[0].width);

    CFRelease(line);
}

TEST(CTRun, GetAdvancesPtr) {
    CFAttributedStringRef string = (__bridge CFAttributedStringRef)getString(@"hello");
    CTLineRef line = CTLineCreateWithAttributedString(string);
    CFArrayRef runsArray = CTLineGetGlyphRuns(line);
    CTRunRef run = (CTRunRef)CFArrayGetValueAtIndex(runsArray, 0);

    EXPECT_EQ(nullptr, CTRunGetAdvancesPtr(nullptr));

    const CGSize* advancesPtr = CTRunGetAdvancesPtr(run);
    advancesPtr = CTRunGetAdvancesPtr(run);
    EXPECT_EQ(0, (*(advancesPtr + 0)).height);
    EXPECT_NEAR(22.637, (*(advancesPtr + 0)).width, c_errorDelta);
    EXPECT_EQ(0, (*(advancesPtr + 1)).height);
    EXPECT_NEAR(20.918, (*(advancesPtr + 1)).width, c_errorDelta);
    EXPECT_EQ(0, (*(advancesPtr + 2)).height);
    EXPECT_NEAR(9.6875, (*(advancesPtr + 2)).width, c_errorDelta);
    EXPECT_EQ(0, (*(advancesPtr + 3)).height);
    EXPECT_NEAR(9.6875, (*(advancesPtr + 3)).width, c_errorDelta);
    EXPECT_EQ(0, (*(advancesPtr + 4)).height);
    EXPECT_NEAR(23.438, (*(advancesPtr + 4)).width, c_errorDelta);

    CFRelease(line);
}

TEST(CTRun, GetGlyphCount) {
    EXPECT_EQ(0, CTRunGetGlyphCount(nullptr));

    CFAttributedStringRef string = (__bridge CFAttributedStringRef)getString(@"foobar");
    CTLineRef line = CTLineCreateWithAttributedString(string);
    CFArrayRef runsArray = CTLineGetGlyphRuns(line);
    CTRunRef run = (CTRunRef)CFArrayGetValueAtIndex(runsArray, 0);
    EXPECT_EQ(6, CTRunGetGlyphCount(run));

    CFRelease(line);
}

TEST(CTRun, GetStringRange) {
    EXPECT_EQ(0, CTRunGetStringRange(nullptr).location);
    EXPECT_EQ(0, CTRunGetStringRange(nullptr).length);

    NSMutableAttributedString* string = getString(@"foobar");
    [string addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:20] range:NSMakeRange(3, 3)];
    CTLineRef line = CTLineCreateWithAttributedString(static_cast<CFAttributedStringRef>(string));
    CFArrayRef runsArray = CTLineGetGlyphRuns(line);

    CTRunRef run = (CTRunRef)CFArrayGetValueAtIndex(runsArray, 0);
    EXPECT_EQ(0, CTRunGetStringRange(run).location);
    EXPECT_EQ(3, CTRunGetStringRange(run).length);

    run = (CTRunRef)CFArrayGetValueAtIndex(runsArray, 1);
    EXPECT_EQ(3, CTRunGetStringRange(run).location);
    EXPECT_EQ(3, CTRunGetStringRange(run).length);

    CFRelease(line);
}

TEST(CTRun, GetPositions) {
    CFAttributedStringRef string = (__bridge CFAttributedStringRef)getString(@"foobar");
    CTLineRef line = CTLineCreateWithAttributedString(string);
    CFArrayRef runsArray = CTLineGetGlyphRuns(line);
    CTRunRef run = (CTRunRef)CFArrayGetValueAtIndex(runsArray, 0);
    std::vector<CGPoint> positions(7);

    EXPECT_NO_THROW(CTRunGetPositions(nullptr, CFRangeMake(0, 0), nullptr));
    EXPECT_NO_THROW(CTRunGetPositions(run, CFRangeMake(0, 0), nullptr));

    std::fill(positions.begin(), positions.end(), CGPointMake(c_arbitraryFloat, c_arbitraryFloat));
    EXPECT_NO_THROW(CTRunGetPositions(nullptr, CFRangeMake(0, 0), positions.data()));
    EXPECT_EQ(c_arbitraryFloat, positions[0].x);
    EXPECT_EQ(c_arbitraryFloat, positions[0].y);
    EXPECT_EQ(c_arbitraryFloat, positions[6].x);
    EXPECT_EQ(c_arbitraryFloat, positions[6].y);

    // Location larger than available positions, does nothing
    std::fill(positions.begin(), positions.end(), CGPointMake(c_arbitraryFloat, c_arbitraryFloat));
    CTRunGetPositions(run, CFRangeMake(10, 0), positions.data());
    EXPECT_EQ(c_arbitraryFloat, positions[0].x);
    EXPECT_EQ(c_arbitraryFloat, positions[0].y);
    EXPECT_EQ(c_arbitraryFloat, positions[6].x);
    EXPECT_EQ(c_arbitraryFloat, positions[6].y);

    // Length larger than available positions, does nothing
    std::fill(positions.begin(), positions.end(), CGPointMake(c_arbitraryFloat, c_arbitraryFloat));
    CTRunGetPositions(run, CFRangeMake(0, 5000), positions.data());
    EXPECT_EQ(std::round(c_arbitraryFloat), std::round(positions[0].x));
    EXPECT_EQ(std::round(c_arbitraryFloat), std::round(positions[0].y));
    EXPECT_EQ(std::round(c_arbitraryFloat), std::round(positions[6].x));
    EXPECT_EQ(std::round(c_arbitraryFloat), std::round(positions[6].y));

    std::fill(positions.begin(), positions.end(), CGPointMake(c_arbitraryFloat, c_arbitraryFloat));
    CTRunGetPositions(run, CFRangeMake(1, 2), positions.data());
    EXPECT_EQ(std::round(12.5197), std::round(positions[0].x));
    EXPECT_EQ(std::round(43.1641), std::round(positions[0].y));
    EXPECT_EQ(std::round(35.9570), std::round(positions[1].x));
    EXPECT_EQ(std::round(43.1641), std::round(positions[1].y));
    EXPECT_EQ(std::round(c_arbitraryFloat), std::round(positions[2].x));
    EXPECT_EQ(std::round(c_arbitraryFloat), std::round(positions[2].y));

    std::fill(positions.begin(), positions.end(), CGPointMake(c_arbitraryFloat, c_arbitraryFloat));
    CTRunGetPositions(run, CFRangeMake(0, 0), positions.data());
    EXPECT_EQ(std::round(0), std::round(positions[0].x));
    EXPECT_EQ(std::round(43.1641), std::round(positions[0].y));
    EXPECT_EQ(std::round(12.5197), std::round(positions[1].x));
    EXPECT_EQ(std::round(43.1641), std::round(positions[1].y));
    EXPECT_EQ(std::round(35.9570), std::round(positions[2].x));
    EXPECT_EQ(std::round(43.1641), std::round(positions[2].y));
    EXPECT_EQ(std::round(59.3945), std::round(positions[3].x));
    EXPECT_EQ(std::round(43.1641), std::round(positions[3].y));
    EXPECT_EQ(std::round(82.9101), std::round(positions[4].x));
    EXPECT_EQ(std::round(43.1641), std::round(positions[4].y));
    EXPECT_EQ(std::round(103.2617), std::round(positions[5].x));
    EXPECT_EQ(std::round(43.1641), std::round(positions[5].y));
    EXPECT_EQ(std::round(c_arbitraryFloat), std::round(positions[6].x));
    EXPECT_EQ(std::round(c_arbitraryFloat), std::round(positions[6].y));

    CFRelease(line);
}

TEST(CTRun, GetPositionsPtr) {
    CFAttributedStringRef string = (__bridge CFAttributedStringRef)getString(@"foobar");
    CTLineRef line = CTLineCreateWithAttributedString(string);
    CFArrayRef runsArray = CTLineGetGlyphRuns(line);
    CTRunRef run = (CTRunRef)CFArrayGetValueAtIndex(runsArray, 0);

    EXPECT_NO_THROW(CTRunGetPositionsPtr(nullptr));

    const CGPoint* positionsPtr = CTRunGetPositionsPtr(run);
    EXPECT_EQ(std::round(0), std::round((positionsPtr + 0)->x));
    EXPECT_EQ(std::round(43.1641), std::round((positionsPtr + 0)->y));
    EXPECT_EQ(std::round(12.5197), std::round((positionsPtr + 1)->x));
    EXPECT_EQ(std::round(43.1641), std::round((positionsPtr + 1)->y));
    EXPECT_EQ(std::round(35.9570), std::round((positionsPtr + 2)->x));
    EXPECT_EQ(std::round(43.1641), std::round((positionsPtr + 2)->y));
    EXPECT_EQ(std::round(59.3945), std::round((positionsPtr + 3)->x));
    EXPECT_EQ(std::round(43.1641), std::round((positionsPtr + 3)->y));
    EXPECT_EQ(std::round(82.9101), std::round((positionsPtr + 4)->x));
    EXPECT_EQ(std::round(43.1641), std::round((positionsPtr + 4)->y));
    EXPECT_EQ(std::round(103.2617), std::round((positionsPtr + 5)->x));
    EXPECT_EQ(std::round(43.1641), std::round((positionsPtr + 5)->y));

    CFRelease(line);
}

TEST(CTRun, GetTextMatrix) {
    EXPECT_EQ(CGAffineTransformIdentity, CTRunGetTextMatrix(nullptr));

    CFMutableAttributedStringRef string = (__bridge CFMutableAttributedStringRef)getString(@"foobar");
    CFAttributedStringSetAttribute(string, CFRangeMake(0, 3), kCTForegroundColorAttributeName, CGColorGetConstantColor(kCGColorWhite));
    auto line = woc::MakeAutoCF<CTLineRef>(CTLineCreateWithAttributedString(string));
    CFArrayRef runsArray = CTLineGetGlyphRuns(line);
    CTRunRef run = (CTRunRef)CFArrayGetValueAtIndex(runsArray, 0);
    EXPECT_EQ(CGAffineTransformIdentity, CTRunGetTextMatrix(run));

    run = (CTRunRef)CFArrayGetValueAtIndex(runsArray, 1);
    EXPECT_EQ(CGAffineTransformIdentity, CTRunGetTextMatrix(run));
}

TEST(CTRun, GetStatus) {
    EXPECT_EQ(kCTRunStatusNoStatus, CTRunGetStatus(nullptr));

    CFAttributedStringRef string = (__bridge CFAttributedStringRef)getString(@"foobar");
    auto line = woc::MakeAutoCF<CTLineRef>(CTLineCreateWithAttributedString(string));
    CFArrayRef runsArray = CTLineGetGlyphRuns(line);
    CTRunRef run = (CTRunRef)CFArrayGetValueAtIndex(runsArray, 0);
    EXPECT_EQ(kCTRunStatusNoStatus, CTRunGetStatus(run));

    string = (__bridge CFAttributedStringRef)getString(@"نص اختبار");
    line = woc::MakeAutoCF<CTLineRef>(CTLineCreateWithAttributedString(string));
    runsArray = CTLineGetGlyphRuns(line);
    run = (CTRunRef)CFArrayGetValueAtIndex(runsArray, 0);
    EXPECT_EQ(kCTRunStatusRightToLeft | kCTRunStatusNonMonotonic, CTRunGetStatus(run));
}

TEST(CTRun, GetImageBounds) {
    // Should return CGRectNull for null run or context
    EXPECT_EQ(CGRectNull, CTRunGetImageBounds(nullptr, nullptr, {}));

    auto rgbColorSpace = woc::MakeAutoCF<CGColorSpaceRef>(CGColorSpaceCreateDeviceRGB());
    auto context = woc::MakeAutoCF<CGContextRef>(CGBitmapContextCreate(nullptr,
                                                                       512,
                                                                       256,
                                                                       8,
                                                                       4 * 512 /* bytesPerRow = bytesPerPixel*width */,
                                                                       rgbColorSpace.get(),
                                                                       kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big));
    EXPECT_EQ(CGRectNull, CTRunGetImageBounds(nullptr, context, {}));

    CFAttributedStringRef string = (__bridge CFAttributedStringRef)getString(@"foobar");
    auto line = woc::MakeAutoCF<CTLineRef>(CTLineCreateWithAttributedString(string));
    CFArrayRef runsArray = CTLineGetGlyphRuns(line);
    CTRunRef run = (CTRunRef)CFArrayGetValueAtIndex(runsArray, 0);
    EXPECT_EQ(CGRectNull, CTRunGetImageBounds(run, nullptr, {}));

    // Size of the rect is exactly the size of the run
    CGFloat ascent, descent;
    double width = CTRunGetTypographicBounds(run, {}, &ascent, &descent, nullptr);
    CGSize runSize{ width, ascent - descent };
    CGRect runRect{ CGPointZero, runSize };
    EXPECT_EQ(runRect, CTRunGetImageBounds(run, context, {}));

    // Size should be independent of CTM or Text Matrix, but origin is the text position
    CGContextScaleCTM(context, 2, 3);
    CGContextTranslateCTM(context, 35, 75);
    CGContextSetTextMatrix(context, CGAffineTransform{ 1, 2, 3, 4, 0, 0 });
    CGPoint origin{ 17, 23 };
    CGContextSetTextPosition(context, origin.x, origin.y);
    runRect = { origin, runSize };
    EXPECT_EQ(runRect, CTRunGetImageBounds(run, context, {}));

    // Range works the same for ImageBounds as TypographicBounds
    CFRange range{ 1, 3 };
    width = CTRunGetTypographicBounds(run, range, &ascent, &descent, nullptr);
    runRect.size = { width, ascent - descent };
    EXPECT_EQ(runRect, CTRunGetImageBounds(run, context, range));

    // And returns CGRectNull for invalid ranges
    EXPECT_EQ(CGRectNull, CTRunGetImageBounds(run, context, { 7, 0 }));
    EXPECT_EQ(CGRectNull, CTRunGetImageBounds(run, context, { 7, 1 }));
    EXPECT_EQ(CGRectNull, CTRunGetImageBounds(run, context, { 1, -1 }));
    EXPECT_EQ(CGRectNull, CTRunGetImageBounds(run, context, { -1, 1 }));
}

TEST(CTRun, GetTypographicBoundsShouldHandleNonzeroLocation) {
    CFAttributedStringRef string = (__bridge CFAttributedStringRef)getString(@"foobar");
    auto line = woc::MakeAutoCF<CTLineRef>(CTLineCreateWithAttributedString(string));
    CFArrayRef runsArray = CTLineGetGlyphRuns(line);
    CTRunRef run = (CTRunRef)CFArrayGetValueAtIndex(runsArray, 0);
    EXPECT_EQ(CGRectNull, CTRunGetImageBounds(run, nullptr, {}));

    // Size of the rect is exactly the size of the run
    CGFloat ascent, descent, leading;
    double width = CTRunGetTypographicBounds(run, { 1, 2 }, &ascent, &descent, &leading);
    EXPECT_NEAR(ascent, 29.1211, c_errorDelta);
    EXPECT_NEAR(descent, 7.9492, c_errorDelta);
    EXPECT_NEAR(leading, 0, c_errorDelta);
    EXPECT_NEAR(width, 46.875, c_errorDelta);
}
