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
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <CoreText/CoreText.h>
#import <CoreFoundation/CFAttributedString.h>

static constexpr double c_errorDelta = 0.0005;
static constexpr float c_arbitraryFloat = 314159.2717;

static NSAttributedString* getAttributedString(NSString* str) {
    UIFontDescriptor* fontDescriptor = [UIFontDescriptor fontDescriptorWithName:@"Segoe UI" size:40];
    UIFont* font = [UIFont fontWithDescriptor:fontDescriptor size:40];

    NSRange wholeRange = NSMakeRange(0, str.length);
    NSMutableAttributedString* string = [[[NSMutableAttributedString alloc] initWithString:str] autorelease];
    [string addAttribute:NSForegroundColorAttributeName value:[UIColor redColor] range:wholeRange];
    [string addAttribute:NSFontAttributeName value:font range:wholeRange];

    return string;
}

DISABLED_TEST(CTFrame, GetStringRange) {
    EXPECT_EQ(0, CTFrameGetStringRange(nullptr).location);
    EXPECT_EQ(0, CTFrameGetStringRange(nullptr).length);
    EXPECT_EQ(0, CTFrameGetVisibleStringRange(nullptr).location);
    EXPECT_EQ(0, CTFrameGetVisibleStringRange(nullptr).length);

    CFAttributedStringRef string = (__bridge CFAttributedStringRef)getAttributedString(@"");
    CTFramesetterRef framesetter = CTFramesetterCreateWithAttributedString(string);
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathAddRect(path, NULL, CGRectMake(0, 0, 60, 57));
    CTFrameRef frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), path, NULL);
    CFAutorelease(framesetter);
    CFAutorelease(frame);
    EXPECT_EQ(0, CTFrameGetStringRange(frame).location);
    EXPECT_EQ(0, CTFrameGetStringRange(frame).length);
    EXPECT_EQ(0, CTFrameGetVisibleStringRange(frame).location);
    EXPECT_EQ(0, CTFrameGetVisibleStringRange(frame).length);

    // Can fit all of the text in frame, so visible range should be equal to string range
    string = (__bridge CFAttributedStringRef)getAttributedString(@"foo");
    framesetter = CTFramesetterCreateWithAttributedString(string);
    frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), path, NULL);
    CFAutorelease(framesetter);
    CFAutorelease(frame);
    EXPECT_EQ(0, CTFrameGetStringRange(frame).location);
    EXPECT_EQ(3, CTFrameGetStringRange(frame).length);
    EXPECT_EQ(0, CTFrameGetVisibleStringRange(frame).location);
    EXPECT_EQ(3, CTFrameGetVisibleStringRange(frame).length);

    // Can only fit "foo" so visible range and string range should NOT be equal
    string = (__bridge CFAttributedStringRef)getAttributedString(@"foobar");
    framesetter = CTFramesetterCreateWithAttributedString(string);
    frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), path, NULL);
    CFAutorelease(framesetter);
    CFAutorelease(frame);
    EXPECT_EQ(0, CTFrameGetStringRange(frame).location);
    EXPECT_EQ(6, CTFrameGetStringRange(frame).length);
    EXPECT_EQ(0, CTFrameGetVisibleStringRange(frame).location);
    EXPECT_EQ(3, CTFrameGetVisibleStringRange(frame).length);

    CGPathRelease(path);
}

DISABLED_TEST(CTFrame, GetLines) {
    EXPECT_EQ(nullptr, CTFrameGetLines(nullptr));
    CFAttributedStringRef string = (__bridge CFAttributedStringRef)getAttributedString(@"");
    CTFramesetterRef framesetter = CTFramesetterCreateWithAttributedString(string);
    CFAutorelease(framesetter);
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathAddRect(path, NULL, CGRectMake(0, 0, 60, 57));
    CTFrameRef frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), path, NULL);
    CFAutorelease(frame);
    CFArrayRef lines = CTFrameGetLines(frame);
    EXPECT_EQ(0, CFArrayGetCount(lines));

    string = (__bridge CFAttributedStringRef)getAttributedString(@"foobar");
    framesetter = CTFramesetterCreateWithAttributedString(string);
    frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), path, NULL);
    CFAutorelease(framesetter);
    CFAutorelease(frame);
    lines = CTFrameGetLines(frame);
    EXPECT_EQ(2, CFArrayGetCount(lines));
    CTLineRef line = (CTLineRef)CFArrayGetValueAtIndex(lines, 0);
    EXPECT_EQ(0, CTLineGetStringRange(line).location);
    EXPECT_EQ(3, CTLineGetStringRange(line).length);
    line = (CTLineRef)CFArrayGetValueAtIndex(lines, 1);
    EXPECT_EQ(3, CTLineGetStringRange(line).location);
    EXPECT_EQ(3, CTLineGetStringRange(line).length);

    CGPathRelease(path);
}

DISABLED_TEST(CTFrame, GetLineOrigins) {
    std::vector<CGPoint> origins(5);

    std::fill(origins.begin(), origins.end(), CGPoint{ c_arbitraryFloat, c_arbitraryFloat });
    CTFrameGetLineOrigins(nullptr, CFRangeMake(0, 0), origins.data());
    EXPECT_EQ(c_arbitraryFloat, origins[0].x);
    EXPECT_EQ(c_arbitraryFloat, origins[0].y);

    CFAttributedStringRef string = (__bridge CFAttributedStringRef)getAttributedString(@"");
    CTFramesetterRef framesetter = CTFramesetterCreateWithAttributedString(string);
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathAddRect(path, NULL, CGRectMake(0, 0, 60, 300));
    CTFrameRef frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), path, NULL);
    CFAutorelease(framesetter);
    CFAutorelease(frame);

    std::fill(origins.begin(), origins.end(), CGPoint{ c_arbitraryFloat, c_arbitraryFloat });
    CTFrameGetLineOrigins(frame, CFRangeMake(0, 0), origins.data());
    EXPECT_EQ(c_arbitraryFloat, origins[0].x);
    EXPECT_EQ(c_arbitraryFloat, origins[0].y);

    string = (__bridge CFAttributedStringRef)getAttributedString(@"foobarbazb");
    framesetter = CTFramesetterCreateWithAttributedString(string);
    frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), path, NULL);
    CFAutorelease(framesetter);
    CFAutorelease(frame);

    // Location greater than available lines, does nothing
    std::fill(origins.begin(), origins.end(), CGPoint{ c_arbitraryFloat, c_arbitraryFloat });
    CTFrameGetLineOrigins(frame, CFRangeMake(110, 0), origins.data());
    EXPECT_EQ(c_arbitraryFloat, origins[0].x);
    EXPECT_EQ(c_arbitraryFloat, origins[0].y);

    // Length negative, does nothing
    std::fill(origins.begin(), origins.end(), CGPoint{ c_arbitraryFloat, c_arbitraryFloat });
    CTFrameGetLineOrigins(frame, CFRangeMake(0, -110), origins.data());
    EXPECT_EQ(c_arbitraryFloat, origins[0].x);
    EXPECT_EQ(c_arbitraryFloat, origins[0].y);

    // Location negative, does nothing
    std::fill(origins.begin(), origins.end(), CGPoint{ c_arbitraryFloat, c_arbitraryFloat });
    std::fill(origins.begin(), origins.end(), CGPoint{ c_arbitraryFloat, c_arbitraryFloat });
    CTFrameGetLineOrigins(frame, CFRangeMake(-110, 0), origins.data());
    EXPECT_EQ(c_arbitraryFloat, origins[0].x);
    EXPECT_EQ(c_arbitraryFloat, origins[0].y);

    std::fill(origins.begin(), origins.end(), CGPoint{ c_arbitraryFloat, c_arbitraryFloat });
    CTFrameGetLineOrigins(frame, CFRangeMake(0, 0), origins.data());
    EXPECT_EQ(std::round(0.0f), std::round(origins[0].x));
    EXPECT_EQ(std::round(43.1641f), std::round(origins[0].y));
    EXPECT_EQ(std::round(0.0f), std::round(origins[1].x));
    EXPECT_EQ(std::round(96.3672f), std::round(origins[1].y));
    EXPECT_EQ(std::round(0.0f), std::round(origins[2].x));
    EXPECT_EQ(std::round(149.5703f), std::round(origins[2].y));
    EXPECT_EQ(std::round(0.0f), std::round(origins[3].x));
    EXPECT_EQ(std::round(202.7734f), std::round(origins[3].y));
    EXPECT_EQ(c_arbitraryFloat, origins[4].x);
    EXPECT_EQ(c_arbitraryFloat, origins[4].y);

    // Length greater than available lines, does nothing
    std::fill(origins.begin(), origins.end(), CGPoint{ c_arbitraryFloat, c_arbitraryFloat });
    CTFrameGetLineOrigins(frame, CFRangeMake(0, 525600), origins.data());
    EXPECT_EQ(c_arbitraryFloat, origins[0].x);
    EXPECT_EQ(c_arbitraryFloat, origins[0].y);

    std::fill(origins.begin(), origins.end(), CGPoint{ c_arbitraryFloat, c_arbitraryFloat });
    CTFrameGetLineOrigins(frame, CFRangeMake(1, 2), origins.data());
    EXPECT_EQ(std::round(0.0f), std::round(origins[0].x));
    EXPECT_EQ(std::round(96.3672f), std::round(origins[0].y));
    EXPECT_EQ(std::round(0.0f), std::round(origins[1].x));
    EXPECT_EQ(std::round(149.5703f), std::round(origins[1].y));
    EXPECT_EQ(c_arbitraryFloat, origins[2].x);
    EXPECT_EQ(c_arbitraryFloat, origins[2].y);

    CGPathRelease(path);
}

TEST(CTFrame, GetPath) {
    EXPECT_EQ(nullptr, CTFrameGetPath(nullptr));

    CFAttributedStringRef string = (__bridge CFAttributedStringRef)getAttributedString(@"TEST");
    CTFramesetterRef framesetter = CTFramesetterCreateWithAttributedString(string);
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathAddRect(path, NULL, CGRectMake(0, 0, 60, 300));
    CTFrameRef frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), path, NULL);
    CFAutorelease(framesetter);
    CFAutorelease(frame);

    EXPECT_EQ(path, CTFrameGetPath(frame));

    CGPathRelease(path);
    EXPECT_NE(nullptr, CTFrameGetPath(frame));
}
