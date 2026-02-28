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
#include <CoreText/CoreText.h>
#include <Starboard/SmartTypes.h>

#ifdef WINOBJC
static NSURL* __GetURLFromPathRelativeToModuleDirectory(NSString* relativePath) {
    return [NSURL fileURLWithPath:[@(GetCurrentTestDirectory().c_str()) stringByAppendingPathComponent:relativePath]];
}
#endif // WINOBJC

TEXT_DRAW_TEST_F(CTFrame, BasicDrawingTest, WhiteBackgroundTest<>) {
    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();

    // Creates path with current rectangle
    woc::unique_cf<CGMutablePathRef> path{ CGPathCreateMutable() };
    CGPathAddRect(path.get(), nullptr, bounds);

    // Create style setting to match given alignment
    CTParagraphStyleSetting setting;
    CTTextAlignment alignment = kCTCenterTextAlignment;
    setting.spec = kCTParagraphStyleSpecifierAlignment;
    setting.valueSize = sizeof(CTTextAlignment);
    setting.value = &alignment;
    woc::unique_cf<CTParagraphStyleRef> paragraphStyle{ CTParagraphStyleCreate(&setting, std::extent<decltype(setting)>::value) };

    woc::unique_cf<CTFontRef> myCFFont{ CTFontCreateWithName(CFSTR("Arial"), 20, nullptr) };

    CFStringRef keys[2] = { kCTFontAttributeName, kCTParagraphStyleAttributeName };
    CFTypeRef values[2] = { myCFFont.get(), paragraphStyle.get() };

    woc::unique_cf<CFDictionaryRef> dict{ CFDictionaryCreate(nullptr,
                                                             (const void**)keys,
                                                             (const void**)values,
                                                             std::extent<decltype(keys)>::value,
                                                             &kCFTypeDictionaryKeyCallBacks,
                                                             &kCFTypeDictionaryValueCallBacks) };

    woc::unique_cf<CFAttributedStringRef> attrString{ CFAttributedStringCreate(nullptr, CFSTR("TEST TEXT.\ntext to test."), dict.get()) };

    woc::unique_cf<CTFramesetterRef> framesetter{ CTFramesetterCreateWithAttributedString(attrString.get()) };

    // Creates frame for framesetter with current attributed string
    woc::unique_cf<CTFrameRef> frame{ CTFramesetterCreateFrame(framesetter.get(), CFRangeMake(0, 0), path.get(), NULL) };

    // Draws the text in the frame
    CTFrameDraw(frame.get(), context);
}

TEXT_DRAW_TEST_F(CTFrame, BasicUIKitMimicDrawingTest, UIKitMimicTest<>) {
    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();

    // Creates path with current rectangle
    woc::unique_cf<CGMutablePathRef> path{ CGPathCreateMutable() };
    CGPathAddRect(path.get(), nullptr, bounds);

    // Create style setting to match given alignment
    CTParagraphStyleSetting setting;
    CTTextAlignment alignment = kCTCenterTextAlignment;
    setting.spec = kCTParagraphStyleSpecifierAlignment;
    setting.valueSize = sizeof(CTTextAlignment);
    setting.value = &alignment;
    woc::unique_cf<CTParagraphStyleRef> paragraphStyle{ CTParagraphStyleCreate(&setting, std::extent<decltype(setting)>::value) };

    woc::unique_cf<CTFontRef> myCFFont{ CTFontCreateWithName(CFSTR("Arial"), 20, nullptr) };

    CFStringRef keys[2] = { kCTFontAttributeName, kCTParagraphStyleAttributeName };
    CFTypeRef values[2] = { myCFFont.get(), paragraphStyle.get() };

    woc::unique_cf<CFDictionaryRef> dict{ CFDictionaryCreate(nullptr,
                                                             (const void**)keys,
                                                             (const void**)values,
                                                             std::extent<decltype(keys)>::value,
                                                             &kCFTypeDictionaryKeyCallBacks,
                                                             &kCFTypeDictionaryValueCallBacks) };

    woc::unique_cf<CFAttributedStringRef> attrString{ CFAttributedStringCreate(nullptr, CFSTR("TEST TEXT.\ntext to test."), dict.get()) };

    woc::unique_cf<CTFramesetterRef> framesetter{ CTFramesetterCreateWithAttributedString(attrString.get()) };

    // Creates frame for framesetter with current attributed string
    woc::unique_cf<CTFrameRef> frame{ CTFramesetterCreateFrame(framesetter.get(), CFRangeMake(0, 0), path.get(), NULL) };

    // Draws the text in the frame
    CTFrameDraw(frame.get(), context);
}

TEXT_DRAW_TEST_F(CTFrame, BasicUnicodeTest, WhiteBackgroundTest<>) {
    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();

    // Creates path with current rectangle
    woc::unique_cf<CGMutablePathRef> path{ CGPathCreateMutable() };
    CGPathAddRect(path.get(), nullptr, bounds);

    // Create style setting to match given alignment
    CTParagraphStyleSetting setting;
    CTTextAlignment alignment = kCTCenterTextAlignment;
    setting.spec = kCTParagraphStyleSpecifierAlignment;
    setting.valueSize = sizeof(CTTextAlignment);
    setting.value = &alignment;
    woc::unique_cf<CTParagraphStyleRef> paragraphStyle{ CTParagraphStyleCreate(&setting, std::extent<decltype(setting)>::value) };

    woc::unique_cf<CTFontRef> myCFFont{ CTFontCreateWithName(CFSTR("Arial"), 20, nullptr) };

    CFStringRef keys[2] = { kCTFontAttributeName, kCTParagraphStyleAttributeName };
    CFTypeRef values[2] = { myCFFont.get(), paragraphStyle.get() };

    woc::unique_cf<CFDictionaryRef> dict{ CFDictionaryCreate(nullptr,
                                                             (const void**)keys,
                                                             (const void**)values,
                                                             std::extent<decltype(keys)>::value,
                                                             &kCFTypeDictionaryKeyCallBacks,
                                                             &kCFTypeDictionaryValueCallBacks) };

    woc::unique_cf<CFAttributedStringRef> attrString{
        CFAttributedStringCreate(nullptr, CFSTR("он прошел այն անցավ ມັນຜ່ານໄປ minęło"), dict.get())
    };

    woc::unique_cf<CTFramesetterRef> framesetter{ CTFramesetterCreateWithAttributedString(attrString.get()) };

    // Creates frame for framesetter with current attributed string
    woc::unique_cf<CTFrameRef> frame{ CTFramesetterCreateFrame(framesetter.get(), CFRangeMake(0, 0), path.get(), NULL) };

    // Draws the text in the frame
    CTFrameDraw(frame.get(), context);
}

class CTFrame : public WhiteBackgroundTest<>,
                public ::testing::WithParamInterface<::testing::tuple<CTTextAlignment, CTLineBreakMode, CTWritingDirection, CGFloat>> {
    CFStringRef CreateOutputFilename() {
        CTTextAlignment alignment = ::testing::get<0>(GetParam());
        CTLineBreakMode lineBreakMode = ::testing::get<1>(GetParam());
        CTWritingDirection writingDirection = ::testing::get<2>(GetParam());
        CGFloat fontSize = ::testing::get<3>(GetParam());
        return CFStringCreateWithFormat(nullptr,
                                        nullptr,
                                        CFSTR("TestImage.CT.Alignment.%d.LineBreakMode.%d.WritingDirection.%d.FontSize.%.02f.png"),
                                        alignment,
                                        lineBreakMode,
                                        writingDirection,
                                        fontSize);
    }
};

template <size_t size>
static void __DrawLoremIpsum(CGContextRef context, CGPathRef path, const CFStringRef (&keys)[size], const CFTypeRef (&values)[size]) {
    woc::unique_cf<CFDictionaryRef> dict{ CFDictionaryCreate(
        nullptr, (const void**)keys, (const void**)values, size, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks) };

    woc::unique_cf<CFAttributedStringRef> attrString{
        CFAttributedStringCreate(nullptr,
                                 CFSTR("Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut "
                                       "labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris "
                                       "nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit "
                                       "esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt "
                                       "in culpa qui officia deserunt mollit anim id est laborum."),
                                 dict.get())
    };

    woc::unique_cf<CTFramesetterRef> framesetter{ CTFramesetterCreateWithAttributedString(attrString.get()) };

    // Creates frame for framesetter with current attributed string
    woc::unique_cf<CTFrameRef> frame{ CTFramesetterCreateFrame(framesetter.get(), CFRangeMake(0, 0), path, NULL) };

    // Draws the text in the frame
    CTFrameDraw(frame.get(), context);
}

TEXT_DRAW_TEST_P(CTFrame, AlignLBMFontSize) {
    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();

    // Creates path with current rectangle
    woc::unique_cf<CGMutablePathRef> path{ CGPathCreateMutable() };
    CGPathAddRect(path.get(), nullptr, bounds);

    // Create style setting to match given alignment
    CTParagraphStyleSetting setting[3];
    CTTextAlignment alignment = ::testing::get<0>(GetParam());
    setting[0].spec = kCTParagraphStyleSpecifierAlignment;
    setting[0].valueSize = sizeof(CTTextAlignment);
    setting[0].value = &alignment;

    CTLineBreakMode lineBreakMode = ::testing::get<1>(GetParam());
    setting[1].spec = kCTParagraphStyleSpecifierLineBreakMode;
    setting[1].valueSize = sizeof(CTLineBreakMode);
    setting[1].value = &lineBreakMode;

    CTWritingDirection writingDirection = ::testing::get<2>(GetParam());
    setting[2].spec = kCTParagraphStyleSpecifierBaseWritingDirection;
    setting[2].valueSize = sizeof(CTWritingDirection);
    setting[2].value = &writingDirection;

    woc::unique_cf<CTParagraphStyleRef> paragraphStyle{ CTParagraphStyleCreate(setting, 3) };
    woc::unique_cf<CTFontRef> myCFFont{ CTFontCreateWithName(CFSTR("Arial"), ::testing::get<3>(GetParam()), nullptr) };

    CFStringRef keys[2] = { kCTFontAttributeName, kCTParagraphStyleAttributeName };
    CFTypeRef values[2] = { myCFFont.get(), paragraphStyle.get() };
    __DrawLoremIpsum(context, path.get(), keys, values);
}

static constexpr CTTextAlignment c_alignments[] = { kCTLeftTextAlignment,
                                                    kCTRightTextAlignment,
                                                    kCTCenterTextAlignment,
                                                    kCTJustifiedTextAlignment,
                                                    kCTNaturalTextAlignment };
static constexpr CTLineBreakMode c_lineBreakModes[] = { kCTLineBreakByWordWrapping, kCTLineBreakByCharWrapping, kCTLineBreakByClipping };
static constexpr CTWritingDirection c_writingDirections[] = { kCTWritingDirectionNatural,
                                                              kCTWritingDirectionLeftToRight,
                                                              kCTWritingDirectionRightToLeft };
static constexpr CGFloat c_fontSizes[]{ 8.0, 25.5, 91.25 };

INSTANTIATE_TEST_CASE_P(TestAlignmentLineBreakMode,
                        CTFrame,
                        ::testing::Combine(::testing::ValuesIn(c_alignments),
                                           ::testing::ValuesIn(c_lineBreakModes),
                                           ::testing::ValuesIn(c_writingDirections),
                                           ::testing::ValuesIn(c_fontSizes)));

class Transform : public WhiteBackgroundTest<>,
                  public ::testing::WithParamInterface<::testing::tuple<CGAffineTransform, CGAffineTransform>> {};

TEXT_DRAW_TEST_P(Transform, TestMatrices) {
    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();

    CGContextSetTextMatrix(context, ::testing::get<0>(GetParam()));
    CGContextConcatCTM(context, ::testing::get<1>(GetParam()));

    // Creates path with current rectangle
    woc::unique_cf<CGMutablePathRef> path{ CGPathCreateMutable() };
    CGPathAddRect(path.get(), nullptr, bounds);

    // Create style setting to match given alignment
    CTParagraphStyleSetting setting[1];
    CTTextAlignment alignment = kCTCenterTextAlignment;
    setting[0].spec = kCTParagraphStyleSpecifierAlignment;
    setting[0].valueSize = sizeof(CTTextAlignment);
    setting[0].value = &alignment;

    woc::unique_cf<CTParagraphStyleRef> paragraphStyle{ CTParagraphStyleCreate(setting, std::extent<decltype(setting)>::value) };
    woc::unique_cf<CTFontRef> myCFFont{ CTFontCreateWithName(CFSTR("Arial"), 20, nullptr) };

    CFStringRef keys[2] = { kCTFontAttributeName, kCTParagraphStyleAttributeName };
    CFTypeRef values[2] = { myCFFont.get(), paragraphStyle.get() };

    woc::unique_cf<CFDictionaryRef> dict{ CFDictionaryCreate(
        nullptr, (const void**)keys, (const void**)values, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks) };

    woc::unique_cf<CFAttributedStringRef> attrString{
        CFAttributedStringCreate(nullptr, CFSTR("The quick brown fox jumps over the lazy dog"), dict.get())
    };

    woc::unique_cf<CTLineRef> line{ CTLineCreateWithAttributedString(attrString.get()) };
    CTLineDraw(line.get(), context);
    __DrawLoremIpsum(context, path.get(), keys, values);
}

static const CGAffineTransform c_transforms[] = { CGAffineTransformMakeRotation(30.0 * M_PI / 180.0),
                                                  CGAffineTransformMakeRotation(60.0 * M_PI / 180.0),
                                                  CGAffineTransformMakeRotation(-45.0 * M_PI / 180.0),
                                                  CGAffineTransformMakeScale(2.0, 1.0),
                                                  CGAffineTransformMakeScale(1.0, 2.0),
                                                  CGAffineTransformMakeScale(1.0, -1.0),
                                                  CGAffineTransformMakeScale(-1.0, 1.0),
                                                  { 2, 2, 0, 2, 0, 0 },
                                                  { 2, 0, 2, 2, 0, 0 },
                                                  { 2, 2, 1.75, 2, 0, 0 },
                                                  CGAffineTransformIdentity };

INSTANTIATE_TEST_CASE_P(TestDrawingTextWithTransformedMatrices,
                        Transform,
                        ::testing::Combine(::testing::ValuesIn(c_transforms), ::testing::ValuesIn(c_transforms)));

class UIKitTransform : public UIKitMimicTest<PixelByPixelImageComparator<PixelComparisonModeDifferenceLimen<>>>,
                       public ::testing::WithParamInterface<::testing::tuple<CGAffineTransform, CGAffineTransform>> {};

TEXT_DRAW_TEST_P(UIKitTransform, TestMatrices) {
    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();

    CGContextSetTextMatrix(context, CGAffineTransformConcat(CGAffineTransformMakeScale(1.0, -1.0), ::testing::get<0>(GetParam())));
    CGContextConcatCTM(context, ::testing::get<1>(GetParam()));

    // Creates path with current rectangle
    woc::unique_cf<CGMutablePathRef> path{ CGPathCreateMutable() };
    CGPathAddRect(path.get(), nullptr, bounds);

    // Create style setting to match given alignment
    CTParagraphStyleSetting setting[1];
    CTTextAlignment alignment = kCTCenterTextAlignment;
    setting[0].spec = kCTParagraphStyleSpecifierAlignment;
    setting[0].valueSize = sizeof(CTTextAlignment);
    setting[0].value = &alignment;

    woc::unique_cf<CTParagraphStyleRef> paragraphStyle{ CTParagraphStyleCreate(setting, std::extent<decltype(setting)>::value) };
    woc::unique_cf<CTFontRef> myCFFont{ CTFontCreateWithName(CFSTR("Arial"), 20, nullptr) };

    CFStringRef keys[2] = { kCTFontAttributeName, kCTParagraphStyleAttributeName };
    CFTypeRef values[2] = { myCFFont.get(), paragraphStyle.get() };

    woc::unique_cf<CFDictionaryRef> dict{ CFDictionaryCreate(
        nullptr, (const void**)keys, (const void**)values, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks) };

    woc::unique_cf<CFAttributedStringRef> attrString{
        CFAttributedStringCreate(nullptr, CFSTR("The quick brown fox jumps over the lazy dog"), dict.get())
    };

    woc::unique_cf<CTLineRef> line{ CTLineCreateWithAttributedString(attrString.get()) };
    CTLineDraw(line.get(), context);
    __DrawLoremIpsum(context, path.get(), keys, values);
}

INSTANTIATE_TEST_CASE_P(TestDrawingUITransforms,
                        UIKitTransform,
                        ::testing::Combine(::testing::ValuesIn(c_transforms), ::testing::ValuesIn(c_transforms)));

class ExtraKerning : public WhiteBackgroundTest<>, public ::testing::WithParamInterface<CGFloat> {
    CFStringRef CreateOutputFilename() {
        CGFloat extraKerning = GetParam();
        return CFStringCreateWithFormat(nullptr, nullptr, CFSTR("TestImage.ExtraKerning.%.02f.png"), extraKerning);
    }
};

TEXT_DRAW_TEST_P(ExtraKerning, TestExtraKerning) {
    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();

    // Creates path with current rectangle
    woc::unique_cf<CGMutablePathRef> path{ CGPathCreateMutable() };
    CGPathAddRect(path.get(), nullptr, bounds);

    // Create style setting to match given alignment
    CTParagraphStyleSetting setting[1];
    CTTextAlignment alignment = kCTLeftTextAlignment;
    setting[0].spec = kCTParagraphStyleSpecifierAlignment;
    setting[0].valueSize = sizeof(CTTextAlignment);
    setting[0].value = &alignment;

    woc::unique_cf<CTParagraphStyleRef> paragraphStyle{ CTParagraphStyleCreate(setting, std::extent<decltype(setting)>::value) };
    woc::unique_cf<CTFontRef> myCFFont{ CTFontCreateWithName(CFSTR("Arial"), 20, nullptr) };

    CGFloat extraKerning = GetParam();
    woc::unique_cf<CFNumberRef> kerning{ CFNumberCreate(nullptr, kCFNumberCGFloatType, &extraKerning) };

    CFStringRef keys[3] = { kCTFontAttributeName, kCTParagraphStyleAttributeName, kCTKernAttributeName };
    CFTypeRef values[3] = { myCFFont.get(), paragraphStyle.get(), kerning.get() };

    __DrawLoremIpsum(context, path.get(), keys, values);
}

static constexpr CGFloat c_extraKernings[] = { -1.0, 1.0, 5.25, 25.75 };
INSTANTIATE_TEST_CASE_P(TestDrawingTextInExtraKerning, ExtraKerning, ::testing::ValuesIn(c_extraKernings));

class LineHeightMultiple : public WhiteBackgroundTest<>, public ::testing::WithParamInterface<CGFloat> {
    CFStringRef CreateOutputFilename() {
        CGFloat lineHeightMultiple = GetParam();
        return CFStringCreateWithFormat(nullptr, nullptr, CFSTR("TestImage.LineHeightMultiple.%.02f.png"), lineHeightMultiple);
    }
};

TEXT_DRAW_TEST_P(LineHeightMultiple, TestLineHeightMultiple) {
    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();

    // Creates path with current rectangle
    woc::unique_cf<CGMutablePathRef> path{ CGPathCreateMutable() };
    CGPathAddRect(path.get(), nullptr, bounds);

    // Create style setting to match given alignment
    CTParagraphStyleSetting setting[2];
    CTTextAlignment alignment = kCTLeftTextAlignment;
    setting[0].spec = kCTParagraphStyleSpecifierAlignment;
    setting[0].valueSize = sizeof(CTTextAlignment);
    setting[0].value = &alignment;
    CGFloat lineHeightMultiple = GetParam();
    setting[0].spec = kCTParagraphStyleSpecifierLineHeightMultiple;
    setting[0].valueSize = sizeof(CGFloat);
    setting[0].value = &lineHeightMultiple;

    woc::unique_cf<CTParagraphStyleRef> paragraphStyle{ CTParagraphStyleCreate(setting, std::extent<decltype(setting)>::value) };
    woc::unique_cf<CTFontRef> myCFFont{ CTFontCreateWithName(CFSTR("Arial"), 20, nullptr) };

    CFStringRef keys[2] = { kCTFontAttributeName, kCTParagraphStyleAttributeName };
    CFTypeRef values[2] = { myCFFont.get(), paragraphStyle.get() };

    __DrawLoremIpsum(context, path.get(), keys, values);
}

static constexpr CGFloat c_lineHeightMultiples[] = { -1.0, .75, 1.25 };
INSTANTIATE_TEST_CASE_P(TestDrawingTextInLineHeightMultiple, LineHeightMultiple, ::testing::ValuesIn(c_lineHeightMultiples));

TEXT_DRAW_TEST_F(CTRun, BasicDrawingTest, WhiteBackgroundTest<>) {
    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();

    // Creates path with current rectangle
    woc::unique_cf<CGMutablePathRef> path{ CGPathCreateMutable() };
    CGPathAddRect(path.get(), nullptr, bounds);

    woc::unique_cf<CTFontRef> myCFFont{ CTFontCreateWithName(CFSTR("Arial"), 20, nullptr) };

    CFStringRef keys[1] = { kCTFontAttributeName };
    CFTypeRef values[1] = { myCFFont.get() };

    woc::unique_cf<CFDictionaryRef> dict{ CFDictionaryCreate(nullptr,
                                                             (const void**)keys,
                                                             (const void**)values,
                                                             std::extent<decltype(keys)>::value,
                                                             &kCFTypeDictionaryKeyCallBacks,
                                                             &kCFTypeDictionaryValueCallBacks) };

    woc::unique_cf<CFAttributedStringRef> attrString{ CFAttributedStringCreate(nullptr, CFSTR("TEST TEXT. text to test."), dict.get()) };

    woc::unique_cf<CTLineRef> line{ CTLineCreateWithAttributedString(attrString.get()) };

    // Draws the text in the frame
    CTLineDraw(line.get(), context);
}

TEXT_DRAW_TEST_F(CTLine, BasicDrawingTest, WhiteBackgroundTest<>) {
    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();

    // Creates path with current rectangle
    woc::unique_cf<CGMutablePathRef> path{ CGPathCreateMutable() };
    CGPathAddRect(path.get(), nullptr, bounds);

    woc::unique_cf<CTFontRef> myCFFont{ CTFontCreateWithName(CFSTR("Arial"), 20, nullptr) };

    CFStringRef keys[1] = { kCTFontAttributeName };
    CFTypeRef values[1] = { myCFFont.get() };

    woc::unique_cf<CFDictionaryRef> dict{ CFDictionaryCreate(nullptr,
                                                             (const void**)keys,
                                                             (const void**)values,
                                                             std::extent<decltype(keys)>::value,
                                                             &kCFTypeDictionaryKeyCallBacks,
                                                             &kCFTypeDictionaryValueCallBacks) };

    woc::unique_cf<CFAttributedStringRef> attrString{ CFAttributedStringCreate(nullptr, CFSTR("TEST TEXT. text to test."), dict.get()) };

    woc::unique_cf<CTLineRef> line{ CTLineCreateWithAttributedString(attrString.get()) };
    CFArrayRef runs = CTLineGetGlyphRuns(line.get());
    CTRunRef run = static_cast<CTRunRef>(CFArrayGetValueAtIndex(runs, 0));

    // Draws the text in the frame
    CTRunDraw(run, context, {});
}

class Fonts : public WhiteBackgroundTest<>, public ::testing::WithParamInterface<CFStringRef> {
    CFStringRef CreateOutputFilename() {
        CFStringRef fontName = GetParam();
        return CFStringCreateWithFormat(nullptr, nullptr, CFSTR("TestImage.Fonts.%@.png"), fontName);
    }
};

TEXT_DRAW_TEST_P(Fonts, TestFonts) {
    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();

    // Creates path with current rectangle
    woc::unique_cf<CGMutablePathRef> path{ CGPathCreateMutable() };
    CGPathAddRect(path.get(), nullptr, bounds);

    // Create style setting to match given alignment
    CTParagraphStyleSetting setting[1];
    CTTextAlignment alignment = kCTLeftTextAlignment;
    setting[0].spec = kCTParagraphStyleSpecifierAlignment;
    setting[0].valueSize = sizeof(CTTextAlignment);
    setting[0].value = &alignment;

    woc::unique_cf<CTParagraphStyleRef> paragraphStyle{ CTParagraphStyleCreate(setting, std::extent<decltype(setting)>::value) };

    CFStringRef fontName = GetParam();
    woc::unique_cf<CTFontRef> myCFFont{ CTFontCreateWithName(fontName, 20, nullptr) };

    CFStringRef keys[2] = { kCTFontAttributeName, kCTParagraphStyleAttributeName };
    CFTypeRef values[2] = { myCFFont.get(), paragraphStyle.get() };

    __DrawLoremIpsum(context, path.get(), keys, values);
}

// Segoe UI is noticeably different on ARM, but we still want to test other fonts so only remove Segoe
static CFStringRef c_fontNames[] = { CFSTR("Arial"), CFSTR("Times New Roman"), CFSTR("Wingdings") };
INSTANTIATE_TEST_CASE_P(TestDrawingTextInFonts, Fonts, ::testing::ValuesIn(c_fontNames));

#ifdef WINOBJC

// The fall-through font for WinObjC is Segoe, so we can't run this on ARM
ARM_DISABLED_TEXT_DRAW_TEST_F(CTFontManager, DrawWithCustomFont, WhiteBackgroundTest<>) {
    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();

    // Creates path with current rectangle
    woc::unique_cf<CGMutablePathRef> path{ CGPathCreateMutable() };
    CGPathAddRect(path.get(), nullptr, bounds);

    // Create style setting to match given alignment
    CTParagraphStyleSetting setting;
    CTTextAlignment alignment = kCTCenterTextAlignment;
    setting.spec = kCTParagraphStyleSpecifierAlignment;
    setting.valueSize = sizeof(CTTextAlignment);
    setting.value = &alignment;
    woc::unique_cf<CTParagraphStyleRef> paragraphStyle{ CTParagraphStyleCreate(&setting, std::extent<decltype(setting)>::value) };

    NSURL* testFileURL = __GetURLFromPathRelativeToModuleDirectory(@"/data/WinObjC.ttf");
    CTFontManagerRegisterFontsForURL((__bridge CFURLRef)testFileURL, kCTFontManagerScopeSession, nullptr);
    woc::unique_cf<CTFontRef> myCFFont{ CTFontCreateWithName(CFSTR("WinObjC"), 20, nullptr) };

    CFStringRef keys[2] = { kCTFontAttributeName, kCTParagraphStyleAttributeName };
    CFTypeRef values[2] = { myCFFont.get(), paragraphStyle.get() };

    woc::unique_cf<CFDictionaryRef> dict{ CFDictionaryCreate(nullptr,
                                                             (const void**)keys,
                                                             (const void**)values,
                                                             std::extent<decltype(keys)>::value,
                                                             &kCFTypeDictionaryKeyCallBacks,
                                                             &kCFTypeDictionaryValueCallBacks) };

    woc::unique_cf<CFAttributedStringRef> attrString{
        CFAttributedStringCreate(nullptr,
                                 CFSTR("GUR DHVPX OEBJA SBK WHZCF BIRE GUR YNML QBT. gur dhvpx oebja qbt whzcf bire gur ynml sbk."),
                                 dict.get())
    };

    woc::unique_cf<CTFramesetterRef> framesetter{ CTFramesetterCreateWithAttributedString(attrString.get()) };

    // Creates frame for framesetter with current attributed string
    woc::unique_cf<CTFrameRef> frame{ CTFramesetterCreateFrame(framesetter.get(), CFRangeMake(0, 0), path.get(), NULL) };

    // Draws the text in the frame
    CTFrameDraw(frame.get(), context);
    CTFontManagerUnregisterFontsForURL((__bridge CFURLRef)testFileURL, kCTFontManagerScopeSession, nullptr);
}
#endif // WINOBJC

// Segoe UI is noticeably different on ARM so disable this for ARM
ARM_DISABLED_TEXT_DRAW_TEST_F(CTFont, DrawGlyphs, WhiteBackgroundTest<>) {
    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();

    // Creates path with current rectangle
    woc::unique_cf<CGMutablePathRef> path{ CGPathCreateMutable() };
    CGPathAddRect(path.get(), nullptr, bounds);
    woc::unique_cf<CTFontRef> font{ CTFontCreateWithName(CFSTR("Segoe UI"), 20, nullptr) };
    UniChar chars[4] = { 'T', 'E', 'S', 'T' };
    CGGlyph glyphs[4];
    CTFontGetGlyphsForCharacters(font.get(), chars, glyphs, 4);
    CGPoint positions[4] = { { 0, 0 }, { 10, 10 }, { 25, 25 }, { 65, 15 } };
    CTFontDrawGlyphs(font.get(), glyphs, positions, 4, context);
}

class TextDrawingMode : public WhiteBackgroundTest<>, public ::testing::WithParamInterface<::testing::tuple<CGTextDrawingMode, CGFloat>> {
    CFStringRef CreateOutputFilename() {
        CGTextDrawingMode textDrawingMode = ::testing::get<0>(GetParam());
        CGFloat textRotation = ::testing::get<1>(GetParam());
        return CFStringCreateWithFormat(nullptr, nullptr, CFSTR("TestImage.TextDrawingMode.%d.%.0f.png"), textDrawingMode, textRotation);
    }
};

TEXT_DRAW_TEST_P(TextDrawingMode, CGTextDrawingMode) {
    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();

    // Creates path with current rectangle
    woc::unique_cf<CGMutablePathRef> path{ CGPathCreateMutable() };
    CGPathAddRect(path.get(), nullptr, bounds);

    CGTextDrawingMode textDrawingMode = ::testing::get<0>(GetParam());
    CGContextSetTextDrawingMode(context, textDrawingMode);

    CGAffineTransform textMatrix = CGContextGetTextMatrix(context);
    CGContextSetTextMatrix(context, CGAffineTransformRotate(textMatrix, ::testing::get<1>(GetParam()) * M_PI / 180.0));
    CGContextScaleCTM(context, 1.5, 2.25);
    // Create style setting to match given alignment
    CTParagraphStyleSetting setting[1];
    CTTextAlignment alignment = kCTLeftTextAlignment;
    setting[0].spec = kCTParagraphStyleSpecifierAlignment;
    setting[0].valueSize = sizeof(CTTextAlignment);
    setting[0].value = &alignment;

    woc::unique_cf<CTParagraphStyleRef> paragraphStyle{ CTParagraphStyleCreate(setting, std::extent<decltype(setting)>::value) };
    woc::unique_cf<CTFontRef> myCFFont{ CTFontCreateWithName(CFSTR("Arial"), 20, nullptr) };

    CFStringRef keys[3] = { kCTFontAttributeName, kCTParagraphStyleAttributeName, kCTForegroundColorFromContextAttributeName };
    CFTypeRef values[3] = { myCFFont.get(), paragraphStyle.get(), kCFBooleanTrue };

    CGContextSetRGBFillColor(context, 1, 0, 0, 1);
    CGContextSetRGBStrokeColor(context, 0, 1, 0, 1);
    CGContextSetShadow(context, { 3, 5 }, 1);
    __DrawLoremIpsum(context, path.get(), keys, values);

    CGContextSetRGBFillColor(context, 0, 0, 1, 1);
    CGContextFillRect(context, CGRectMake(0, 0, bounds.size.width / 2.0, bounds.size.height));
}

static constexpr CGTextDrawingMode c_textDrawingModes[] = { kCGTextInvisible, kCGTextFill,     kCGTextStroke,     kCGTextFillStroke,
                                                            kCGTextClip,      kCGTextFillClip, kCGTextStrokeClip, kCGTextFillStrokeClip };

static constexpr CGFloat c_rotations[] = { 0.0, 45.0, -30.0 };

INSTANTIATE_TEST_CASE_P(TextDrawing,
                        TextDrawingMode,
                        ::testing::Combine(::testing::ValuesIn(c_textDrawingModes), ::testing::ValuesIn(c_rotations)));

class RTLText : public WhiteBackgroundTest<>, public ::testing::WithParamInterface<CGFloat> {
    CFStringRef CreateOutputFilename() {
        CGFloat degrees = GetParam();
        return CFStringCreateWithFormat(nullptr, nullptr, CFSTR("TestImage.RTLText.Rotated.%.0f.png"), degrees);
    }
};

TEXT_DRAW_TEST_P(RTLText, DrawRTLText) {
    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();

    // Creates path with current rectangle
    woc::unique_cf<CGMutablePathRef> path{ CGPathCreateMutable() };
    CGPathAddRect(path.get(), nullptr, bounds);

    CGAffineTransform textMatrix = CGContextGetTextMatrix(context);
    CGContextSetTextMatrix(context, CGAffineTransformRotate(textMatrix, GetParam() * M_PI / 180.0));
    // Create style setting to match given alignment
    CTParagraphStyleSetting setting[2];
    CTTextAlignment alignment = kCTRightTextAlignment;
    setting[0].spec = kCTParagraphStyleSpecifierAlignment;
    setting[0].valueSize = sizeof(CTTextAlignment);
    setting[0].value = &alignment;
    CTWritingDirection writingDirection = kCTWritingDirectionRightToLeft;
    setting[1].spec = kCTParagraphStyleSpecifierBaseWritingDirection;
    setting[1].valueSize = sizeof(CTWritingDirection);
    setting[1].value = &writingDirection;

    woc::unique_cf<CTParagraphStyleRef> paragraphStyle{ CTParagraphStyleCreate(setting, std::extent<decltype(setting)>::value) };
    woc::unique_cf<CTFontRef> myCFFont{ CTFontCreateWithName(CFSTR("Arial"), 20, nullptr) };

    CFStringRef keys[2] = { kCTFontAttributeName, kCTParagraphStyleAttributeName };
    CFTypeRef values[2] = { myCFFont.get(), paragraphStyle.get() };

    woc::unique_cf<CFDictionaryRef> dict{ CFDictionaryCreate(nullptr,
                                                             (const void**)keys,
                                                             (const void**)values,
                                                             std::extent<decltype(keys)>::value,
                                                             &kCFTypeDictionaryKeyCallBacks,
                                                             &kCFTypeDictionaryValueCallBacks) };

    woc::unique_cf<CFAttributedStringRef> attrString{
        CFAttributedStringCreate(nullptr,
                                 CFSTR("אבל אני חייב להסביר לך איך כל הרעיון מוטעה של בגנות הנאה ומשבחי כאב נולד ואני אתן לך את חשבון מלא "
                                       "של המערכת, להרצות את משנתו בפועל של החוקר הגדול של האמת, הבונה-אדון האדם אושר. אף אחד לא דוחה, לא "
                                       "אוהב, או נמנע התענוג עצמו, כי זה תענוג, אלא בגלל מי לא יודע איך להמשיך הנאה רציונלי נתקלים התוצאות "
                                       "כי הם מאוד כואב. גם שוב האם יש מישהו שאוהב או רודף או רצונות לקבל הכאב של עצמה, כי זה כאב, אבל "
                                       "בגלל לעתים הנסיבות להתרחש בו עמל וכאב יכולים להשיג לו קצת עונג רב. כדי לקחת דוגמה טריוויאלית, מי "
                                       "מאיתנו לא מתחייבת פעילות גופנית מאומצת, אלא כדי להשיג יתרון כלשהו ממנו? אבל למי יש זכות למצוא דופי "
                                       "אדם שבוחר ליהנות הנאה שאין לה השלכות מעצבנות, או מי ימנע כאב מייצר שום הנאה כתוצאה?"),
                                 dict.get())
    };

    woc::unique_cf<CTFramesetterRef> framesetter{ CTFramesetterCreateWithAttributedString(attrString.get()) };

    // Creates frame for framesetter with current attributed string
    woc::unique_cf<CTFrameRef> frame{ CTFramesetterCreateFrame(framesetter.get(), CFRangeMake(0, 0), path, NULL) };

    // Draws the text in the frame
    CTFrameDraw(frame.get(), context);
}

INSTANTIATE_TEST_CASE_P(RTLTextDrawing, RTLText, ::testing::ValuesIn(c_rotations));

TEXT_DRAW_TEST_F(CTDrawing, CGPathTranslation, WhiteBackgroundTest<>) {
    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();

    // Creates path with current rectangle
    woc::AutoCF<CGMutablePathRef> path{ woc::TakeOwnership, CGPathCreateMutable() };
    CGPathAddRect(path, nullptr, { { 25, 50 }, bounds.size });

    CGAffineTransform textMatrix = CGContextGetTextMatrix(context);
    CGContextSetTextMatrix(context, CGAffineTransformRotate(textMatrix, 45 * M_PI / 180.0));
    CGContextScaleCTM(context, 1.1, 1.3);
    // Create style setting to match given alignment
    CTParagraphStyleSetting setting[1];
    CTTextAlignment alignment = kCTLeftTextAlignment;
    setting[0].spec = kCTParagraphStyleSpecifierAlignment;
    setting[0].valueSize = sizeof(CTTextAlignment);
    setting[0].value = &alignment;

    woc::AutoCF<CTParagraphStyleRef> paragraphStyle{ woc::TakeOwnership,
                                                     CTParagraphStyleCreate(setting, std::extent<decltype(setting)>::value) };
    woc::AutoCF<CTFontRef> myCFFont{ woc::TakeOwnership, CTFontCreateWithName(CFSTR("Arial"), 20, nullptr) };

    CFStringRef keys[2] = { kCTFontAttributeName, kCTParagraphStyleAttributeName };
    CFTypeRef values[2] = { myCFFont, paragraphStyle };
    __DrawLoremIpsum(context, path, keys, values);
}
