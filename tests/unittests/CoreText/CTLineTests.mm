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

#import <UIKit/UIKit.h>
#include <TestFramework.h>
#import <CoreFoundation/CoreFoundation.h>
#import <CppUtils.h>

NSMutableAttributedString* getAttributedString(NSString* str) {
    UIFontDescriptor* fontDescriptor = [UIFontDescriptor fontDescriptorWithName:@"Segoe UI" size:40];
    UIFont* font = [UIFont fontWithDescriptor:fontDescriptor size:40];

    NSRange wholeRange = NSMakeRange(0, str.length);
    NSMutableAttributedString* string = [[[NSMutableAttributedString alloc] initWithString:str] autorelease];
    [string addAttribute:NSForegroundColorAttributeName value:[UIColor redColor] range:wholeRange];
    [string addAttribute:NSFontAttributeName value:font range:wholeRange];

    return string;
}

TEST(CTLine, CTLineGetStringIndexForPosition) {
    CFAttributedStringRef string = (__bridge CFAttributedStringRef)getAttributedString(@"hello");
    auto line = woc::MakeAutoCF<CTLineRef>(CTLineCreateWithAttributedString(string));

    // testing with position < 0
    CGPoint position = { -1, 0 };
    CFIndex index = CTLineGetStringIndexForPosition(line, position);
    EXPECT_EQ(index, 0);

    // testing with position > length of line.
    position = { 873214, 0 };
    index = CTLineGetStringIndexForPosition(line, position);
    EXPECT_EQ(index, CFAttributedStringGetLength(string));

    position = { 23, 0 };
    index = CTLineGetStringIndexForPosition(line, position);
    EXPECT_EQ(index, 1);

    position = { 44, 0 };
    index = CTLineGetStringIndexForPosition(line, position);
    EXPECT_EQ(index, 2);

    string = (__bridge CFAttributedStringRef)getAttributedString(@"وهذا هو نص عينة للتحقق من الصحة");
    line = woc::MakeAutoCF<CTLineRef>(CTLineCreateWithAttributedString(string));

    // testing with position < 0
    position = { -1, 0 };
    index = CTLineGetStringIndexForPosition(line, position);
    EXPECT_EQ(index, CFAttributedStringGetLength(string));

    // testing with position > length of line.
    position = { 873214, 0 };
    index = CTLineGetStringIndexForPosition(line, position);
    EXPECT_EQ(index, 0);

    position = { 50, 0 };
    index = CTLineGetStringIndexForPosition(line, position);
    EXPECT_EQ(index, 29);

    position = { 100, 0 };
    index = CTLineGetStringIndexForPosition(line, position);
    EXPECT_EQ(index, 27);
}

TEST(CTLine, CTLineGetOffsetForStringIndex) {
    const double errorDelta = 1;
    CFAttributedStringRef string = (__bridge CFAttributedStringRef)getAttributedString(@"hello");
    auto line = woc::MakeAutoCF<CTLineRef>(CTLineCreateWithAttributedString(string));

    CGFloat secOffset;
    // testing with index < 0
    CGFloat offset = CTLineGetOffsetForStringIndex(line, -1, &secOffset);
    EXPECT_EQ(offset, 0);

    // testing with index = 0
    offset = CTLineGetOffsetForStringIndex(line, 0, &secOffset);
    EXPECT_EQ(offset, 0);

    // testing with index > last index.
    offset = CTLineGetOffsetForStringIndex(line, 928347, &secOffset);
    EXPECT_GT(offset, 58);

    offset = CTLineGetOffsetForStringIndex(line, 2, &secOffset);
    EXPECT_NEAR(43.55, offset, errorDelta);

    offset = CTLineGetOffsetForStringIndex(line, 4, &secOffset);
    EXPECT_NEAR(62.93, offset, errorDelta);

    // passing secondaryOffset reference as NULL
    offset = CTLineGetOffsetForStringIndex(line, 4, nullptr);
    EXPECT_NEAR(62.93, offset, errorDelta);

    // comparing secondaryOffset and offset.
    offset = CTLineGetOffsetForStringIndex(line, 4, &secOffset);
    EXPECT_EQ(offset, secOffset);

    string = (__bridge CFAttributedStringRef)getAttributedString(@"وهذا هو نص عينة للتحقق من الصحة.");
    line = woc::MakeAutoCF<CTLineRef>(CTLineCreateWithAttributedString(string));

    offset = CTLineGetOffsetForStringIndex(line, 5, nullptr);
    EXPECT_NEAR(509.04, offset, errorDelta);

    offset = CTLineGetOffsetForStringIndex(line, 14, nullptr);
    EXPECT_NEAR(323.45, offset, errorDelta);
}

TEST(CTLine, CTLineCreateWithAttributedString) {
    NSMutableAttributedString* attrString = getAttributedString(@"hello");
    [attrString addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:20] range:NSMakeRange(3, 2)];
    CFAttributedStringRef string = (__bridge CFAttributedStringRef)attrString;

    CTLineRef line = CTLineCreateWithAttributedString(string);
    EXPECT_NE(line, nullptr);

    EXPECT_EQ(0, CTLineGetStringRange(line).location);
    EXPECT_EQ(5, CTLineGetStringRange(line).length);
    EXPECT_EQ(5, CTLineGetGlyphCount(line));
    CFArrayRef runs = CTLineGetGlyphRuns(line);

    EXPECT_NE(runs, nullptr);
    EXPECT_EQ_MSG(2, CFArrayGetCount(runs), "CTLine should create multiple runs when attributed string has multiple attribute ranges");
    EXPECT_EQ(3, CTRunGetGlyphCount(static_cast<CTRunRef>(CFArrayGetValueAtIndex(runs, 0))));
    EXPECT_EQ(2, CTRunGetGlyphCount(static_cast<CTRunRef>(CFArrayGetValueAtIndex(runs, 1))));

    // Glyphs for h, e, and l respectively
    const CGGlyph* helGlyphs = CTRunGetGlyphsPtr(static_cast<CTRunRef>(CFArrayGetValueAtIndex(runs, 0)));
    ASSERT_NE(nullptr, helGlyphs);

    std::vector<WORD> characters(4);
    [@"hel" getCharacters:characters.data()];
    std::vector<CGGlyph> actualGlyphs(4);
    UIFontDescriptor* fontDescriptor = [UIFontDescriptor fontDescriptorWithName:@"Times New Roman" size:40];
    UIFont* font = [UIFont fontWithDescriptor:fontDescriptor size:40];
    CTFontGetGlyphsForCharacters(static_cast<CTFontRef>(font), characters.data(), actualGlyphs.data(), 3);

    EXPECT_EQ(actualGlyphs[0], *helGlyphs);
    EXPECT_EQ(actualGlyphs[1], *(++helGlyphs));
    EXPECT_EQ(actualGlyphs[2], *(++helGlyphs));

    // Glyphs for l and o respectively
    const CGGlyph* loGlyphs = CTRunGetGlyphsPtr(static_cast<CTRunRef>(CFArrayGetValueAtIndex(runs, 1)));
    ASSERT_NE(nullptr, loGlyphs);

    [@"lo" getCharacters:characters.data()];
    CTFontGetGlyphsForCharacters(static_cast<CTFontRef>([UIFont systemFontOfSize:20]), characters.data(), actualGlyphs.data(), 2);

    EXPECT_EQ(actualGlyphs[0], *loGlyphs);
    EXPECT_EQ(actualGlyphs[1], *(++loGlyphs));

    CFRelease(line);

    string = (__bridge CFAttributedStringRef)getAttributedString(@"");
    line = CTLineCreateWithAttributedString(string);
    EXPECT_NE(line, nullptr);
    EXPECT_EQ(0, CTLineGetStringRange(line).location);
    EXPECT_EQ(0, CTLineGetStringRange(line).length);
    EXPECT_EQ(0, CTLineGetGlyphCount(line));

    runs = CTLineGetGlyphRuns(line);
    EXPECT_NE(runs, nullptr);
    EXPECT_EQ(0, CFArrayGetCount(runs));
    CFRelease(line);

    line = CTLineCreateWithAttributedString(nullptr);
    EXPECT_EQ(line, nullptr);
}

TEST(CTLine, CreateTruncatedLineNoTruncationToken) {
    NSMutableAttributedString* string = getAttributedString(@"ABCDEF");
    [string addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:20] range:NSMakeRange(0, 6)];
    CTLineRef line = CTLineCreateWithAttributedString(static_cast<CFAttributedStringRef>(string));

    // "ABCDEF"
    const CGGlyph* originalGlyphs = CTRunGetGlyphsPtr(static_cast<CTRunRef>(CFArrayGetValueAtIndex(CTLineGetGlyphRuns(line), 0)));

    CTLineRef startTruncated = CTLineCreateTruncatedLine(line, 40.0, kCTLineTruncationStart, NULL);
    EXPECT_EQ(3, CTLineGetGlyphCount(startTruncated));

    // Truncated should be DEF in one run
    const CGGlyph* startTruncatedGlyphs =
        CTRunGetGlyphsPtr(static_cast<CTRunRef>(CFArrayGetValueAtIndex(CTLineGetGlyphRuns(startTruncated), 0)));
    EXPECT_EQ(*(originalGlyphs + 3), *startTruncatedGlyphs);
    EXPECT_EQ(*(originalGlyphs + 5), *(startTruncatedGlyphs + 2));
    CFRelease(startTruncated);

    CTLineRef endTruncated = CTLineCreateTruncatedLine(line, 40.0, kCTLineTruncationEnd, NULL);
    EXPECT_EQ(2, CTLineGetGlyphCount(endTruncated));

    // Truncated should be AB in one run
    const CGGlyph* endTruncatedGlyphs =
        CTRunGetGlyphsPtr(static_cast<CTRunRef>(CFArrayGetValueAtIndex(CTLineGetGlyphRuns(endTruncated), 0)));
    EXPECT_EQ(*originalGlyphs, *endTruncatedGlyphs);
    EXPECT_EQ(*(originalGlyphs + 1), *(endTruncatedGlyphs + 1));
    CFRelease(endTruncated);

    CTLineRef middleTruncated = CTLineCreateTruncatedLine(line, 40.0, kCTLineTruncationMiddle, NULL);
    EXPECT_EQ(2, CTLineGetGlyphCount(middleTruncated));

    // Truncated should be AF in one run
    const CGGlyph* middleTruncatedGlyphs =
        CTRunGetGlyphsPtr(static_cast<CTRunRef>(CFArrayGetValueAtIndex(CTLineGetGlyphRuns(middleTruncated), 0)));
    EXPECT_EQ(*originalGlyphs, *middleTruncatedGlyphs);
    EXPECT_EQ(*(originalGlyphs + 5), *(middleTruncatedGlyphs + 1));
    CFRelease(middleTruncated);
    CFRelease(line);
}

TEST(CTLine, CreateTruncatedLineTruncationToken) {
    NSMutableAttributedString* string = getAttributedString(@"ABCDEF");
    [string addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:20] range:NSMakeRange(0, 6)];
    CTLineRef line = CTLineCreateWithAttributedString(static_cast<CFAttributedStringRef>(string));

    // "ABCDEF"
    const CGGlyph* originalGlyphs = CTRunGetGlyphsPtr(static_cast<CTRunRef>(CFArrayGetValueAtIndex(CTLineGetGlyphRuns(line), 0)));

    CFAttributedStringRef ellipsisString = (__bridge CFAttributedStringRef)getAttributedString(@"...");
    CTLineRef ellipsis = CTLineCreateWithAttributedString(ellipsisString);
    const CGGlyph* ellipsisGlyphs = CTRunGetGlyphsPtr(static_cast<CTRunRef>(CFArrayGetValueAtIndex(CTLineGetGlyphRuns(ellipsis), 0)));

    CTLineRef startTruncated = CTLineCreateTruncatedLine(line, 40.0, kCTLineTruncationStart, ellipsis);
    EXPECT_EQ(4, CTLineGetGlyphCount(startTruncated));

    // Truncated should be ...F in two runs (..., F)
    const CGGlyph* startTruncatedGlyphs =
        CTRunGetGlyphsPtr(static_cast<CTRunRef>(CFArrayGetValueAtIndex(CTLineGetGlyphRuns(startTruncated), 0)));
    EXPECT_EQ(*ellipsisGlyphs, *startTruncatedGlyphs);
    EXPECT_EQ(*ellipsisGlyphs, *(startTruncatedGlyphs + 2));

    startTruncatedGlyphs = CTRunGetGlyphsPtr(static_cast<CTRunRef>(CFArrayGetValueAtIndex(CTLineGetGlyphRuns(startTruncated), 1)));
    EXPECT_EQ(*(originalGlyphs + 5), *startTruncatedGlyphs);
    CFRelease(startTruncated);

    CTLineRef endTruncated = CTLineCreateTruncatedLine(line, 40.0, kCTLineTruncationEnd, ellipsis);
    EXPECT_EQ(4, CTLineGetGlyphCount(endTruncated));

    // Truncated should be A... in two runs (A, ...)
    const CGGlyph* endTruncatedGlyphs =
        CTRunGetGlyphsPtr(static_cast<CTRunRef>(CFArrayGetValueAtIndex(CTLineGetGlyphRuns(endTruncated), 0)));
    EXPECT_EQ(*originalGlyphs, *endTruncatedGlyphs);

    endTruncatedGlyphs = CTRunGetGlyphsPtr(static_cast<CTRunRef>(CFArrayGetValueAtIndex(CTLineGetGlyphRuns(endTruncated), 1)));
    EXPECT_EQ(*ellipsisGlyphs, *endTruncatedGlyphs);
    EXPECT_EQ(*ellipsisGlyphs, *(endTruncatedGlyphs + 2));
    CFRelease(endTruncated);

    CTLineRef middleTruncated = CTLineCreateTruncatedLine(line, 60.0, kCTLineTruncationMiddle, ellipsis);
    EXPECT_EQ(5, CTLineGetGlyphCount(middleTruncated));

    // Truncated should be A...F in three runs (A, ..., F)
    const CGGlyph* middleTruncatedGlyphs =
        CTRunGetGlyphsPtr(static_cast<CTRunRef>(CFArrayGetValueAtIndex(CTLineGetGlyphRuns(middleTruncated), 0)));
    EXPECT_EQ(*originalGlyphs, *middleTruncatedGlyphs);

    middleTruncatedGlyphs = CTRunGetGlyphsPtr(static_cast<CTRunRef>(CFArrayGetValueAtIndex(CTLineGetGlyphRuns(middleTruncated), 1)));
    EXPECT_EQ(*ellipsisGlyphs, *middleTruncatedGlyphs);
    EXPECT_EQ(*ellipsisGlyphs, *(middleTruncatedGlyphs + 2));

    middleTruncatedGlyphs = CTRunGetGlyphsPtr(static_cast<CTRunRef>(CFArrayGetValueAtIndex(CTLineGetGlyphRuns(middleTruncated), 2)));
    EXPECT_EQ(*(originalGlyphs + 5), *middleTruncatedGlyphs);
    CFRelease(middleTruncated);

    CFRelease(ellipsis);
    CFRelease(line);
}

TEST(CTLine, CTLineGetGlyphCount) {
    EXPECT_EQ(0, CTLineGetGlyphCount(nullptr));

    CFAttributedStringRef string = (__bridge CFAttributedStringRef)getAttributedString(@"");
    CTLineRef line = CTLineCreateWithAttributedString(string);
    EXPECT_EQ(0, CTLineGetGlyphCount(line));
    CFRelease(line);

    string = (__bridge CFAttributedStringRef)getAttributedString(@"foobarbaz");
    line = CTLineCreateWithAttributedString(string);
    EXPECT_EQ(9, CTLineGetGlyphCount(line));
    CFRelease(line);
}

TEST(CTLine, CTLineGetTypographicBounds) {
    UIFontDescriptor* fontDescriptor = [UIFontDescriptor fontDescriptorWithName:@"Segoe UI" size:40];
    CTFontRef font = (__bridge CTFontRef)[UIFont fontWithDescriptor:fontDescriptor size:40];
    CFAttributedStringRef baseString = (__bridge CFAttributedStringRef)getAttributedString(@"x");
    CFAttributedStringRef variableString = (__bridge CFAttributedStringRef)getAttributedString(@"gH");
    CTLineRef baseLine = CTLineCreateWithAttributedString(baseString);
    CFAutorelease(baseLine);
    CTLineRef variableLine = CTLineCreateWithAttributedString(variableString);
    CFAutorelease(variableLine);

    CGFloat baseAscent, variableAscent, baseDescent, variableDescent, baseLeading, variableLeading;
    CGFloat baseWidth = CTLineGetTypographicBounds(baseLine, &baseAscent, &baseDescent, &baseLeading);
    EXPECT_LT(0, baseWidth);
    EXPECT_EQ_MSG(CTFontGetLeading(font), baseLeading, "Leading should always be the same as the font");
    EXPECT_GE_MSG(CTFontGetAscent(font), baseAscent, "Ascent should never exceed the maximum font ascent");
    EXPECT_GE_MSG(CTFontGetDescent(font), baseDescent, "Descent should never exceed the maximum font descent");

    CGFloat variableWidth = CTLineGetTypographicBounds(variableLine, &variableAscent, &variableDescent, &variableLeading);
    EXPECT_EQ_MSG(CTFontGetLeading(font), variableLeading, "Leading should always be the same as the font");
    EXPECT_LT(0, variableWidth);
    EXPECT_GE_MSG(CTFontGetAscent(font), variableAscent, "Ascent should never exceed the maximum font ascent");
    EXPECT_GE_MSG(CTFontGetDescent(font), variableDescent, "Descent should never exceed the maximum font descent");

    EXPECT_LE_MSG(baseAscent, variableAscent, "The ascent with \'H\' should be no less than the ascent with \'x\'");
    EXPECT_GE_MSG(baseDescent, variableDescent, "The descent with \'g\' should be no greater than the descent with \'x\'");
}

TEST(CTLine, ShouldSeparateRunsBasedOnColor) {
    NSMutableAttributedString* string = getAttributedString(@"ABCDEF");
    [string addAttribute:NSForegroundColorAttributeName value:[UIColor magentaColor] range:{ 0, 2 }];
    [string addAttribute:NSForegroundColorAttributeName value:[UIColor yellowColor] range:{ 2, 2 }];
    [string addAttribute:NSForegroundColorAttributeName value:[UIColor cyanColor] range:{ 4, 2 }];
    CTLineRef line = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)string);
    EXPECT_EQ(6L, CTLineGetGlyphCount(line));
    EXPECT_EQ(3L, CFArrayGetCount(CTLineGetGlyphRuns(line)));
}

TEST(CTLine, ShouldBeAbleToDrawOnBackgroundThread) {
    dispatch_group_t group = dispatch_group_create();
    dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        CGColorRef myCGColor = [UIColor blackColor].CGColor;
        CTFontRef myCFFont = CTFontCreateWithName((__bridge CFStringRef) @"Helvetica", 20, NULL);
        CFAutorelease(myCFFont);
        NSDictionary* attributesDict =
            @{ (id)kCTFontAttributeName : (__bridge id)myCFFont, (id)kCTForegroundColorAttributeName : (__bridge id)myCGColor };

        CGSize contextSize = CGSizeMake(1000, 1000);
        CGColorSpaceRef colSpace = CGColorSpaceCreateDeviceRGB();
        std::vector<uint8_t> bitmapData(contextSize.width * contextSize.height * 4);
        CGContextRef bitmapContext = CGBitmapContextCreate(bitmapData.data(),
                                                           contextSize.width,
                                                           contextSize.height,
                                                           8,
                                                           contextSize.width * 4,
                                                           colSpace,
                                                           kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Host);
        CGColorSpaceRelease(colSpace);

        CGContextSetRGBFillColor(bitmapContext, 0, 0.0, 0.0, 1);
        CGContextFillRect(bitmapContext, CGRectMake(0.0, 0.0, contextSize.width, contextSize.height));
        CGContextSetRGBFillColor(bitmapContext, 1, 1, 1, 1);
        CGContextSetTextMatrix(bitmapContext, CGAffineTransformIdentity);

        CFAttributedStringRef attrString =
            CFAttributedStringCreate(kCFAllocatorDefault, (__bridge CFStringRef) @"TEST", (__bridge CFDictionaryRef)attributesDict);
        CFAutorelease(attrString);
        CTLineRef line = CTLineCreateWithAttributedString(attrString);
        CFAutorelease(line);
        CGContextSetTextPosition(bitmapContext, 1, floorf(contextSize.height / 5) + 1);

        EXPECT_NO_THROW(CTLineDraw(line, bitmapContext));
        CGContextRelease(bitmapContext);
    });

    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    dispatch_release(group);
}

TEST(CTLine, GetImageBounds) {
    // Should return CGRectNull for null line or context
    EXPECT_EQ(CGRectNull, CTLineGetImageBounds(nullptr, nullptr));

    auto rgbColorSpace = woc::MakeAutoCF<CGColorSpaceRef>(CGColorSpaceCreateDeviceRGB());
    auto context = woc::MakeAutoCF<CGContextRef>(CGBitmapContextCreate(nullptr,
                                                                       512,
                                                                       256,
                                                                       8,
                                                                       4 * 512 /* bytesPerRow = bytesPerPixel*width */,
                                                                       rgbColorSpace.get(),
                                                                       kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big));
    EXPECT_EQ(CGRectNull, CTLineGetImageBounds(nullptr, context));

    CFAttributedStringRef string = (__bridge CFAttributedStringRef)getAttributedString(@"foobar");
    auto line = woc::MakeAutoCF<CTLineRef>(CTLineCreateWithAttributedString(string));
    EXPECT_EQ(CGRectNull, CTLineGetImageBounds(line, nullptr));

    // Size of the rect is exactly the size of the line
    CGFloat ascent, descent;
    double width = CTLineGetTypographicBounds(line, &ascent, &descent, nullptr);
    CGSize lineSize{ width, ascent - descent };
    CGRect lineRect{ CGPointZero, lineSize };
    EXPECT_EQ(lineRect, CTLineGetImageBounds(line, context));

    // Size should be independent of CTM or Text Matrix, but origin is the text position
    CGContextScaleCTM(context, 2, 3);
    CGContextTranslateCTM(context, 35, 75);
    CGContextSetTextMatrix(context, CGAffineTransform{ 1, 2, 3, 4, 0, 0 });
    CGPoint origin{ 17, 23 };
    CGContextSetTextPosition(context, origin.x, origin.y);
    lineRect = { origin, lineSize };
    EXPECT_EQ(lineRect, CTLineGetImageBounds(line, context));
}
