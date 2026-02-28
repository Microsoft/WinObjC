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

#import <TestFramework.h>
#import <Foundation/Foundation.h>

#import <windows.h>
#import <algorithm>

void testUrlCharacterSetEncoding(NSString* decodedString, NSString* encodedString, NSCharacterSet* allowedCharacterSet) {
    NSString* testString = [decodedString stringByAddingPercentEncodingWithAllowedCharacters:allowedCharacterSet];
    ASSERT_OBJCEQ(encodedString, testString);
}

TEST(NSString, NSStringTests) {
    // NSString PercentEncoding methods.
    NSString* decodedString = @"Space "
                              @"DoubleQuotes\"Hash#Percent%LessThan<GreaterThan>OpeningBracket[Backslash\\ClosingBracket]Caret^"
                              @"GraveAccent`OpeningBrace{VerticalBar|ClosingBrace}";
    NSString* encodedString = @"Space%20DoubleQuotes%22Hash%23Percent%25LessThan%3CGreaterThan%3EOpeningBracket%5BBackslash%"
                              @"5CClosingBracket%5DCaret%5EGraveAccent%60OpeningBrace%7BVerticalBar%7CClosingBrace%7D";

    NSString* testString = [decodedString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    EXPECT_OBJCEQ(encodedString, testString);

    testString = [encodedString stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    EXPECT_OBJCEQ(decodedString, testString);

    testString = [encodedString stringByRemovingPercentEncoding];
    EXPECT_OBJCEQ(decodedString, testString);

    NSString* urlDecodedString = @"https://www.microsoft.com/en-us/!@#$%^&*()_";
    NSString* urlEncodedString = @"https://www.microsoft.com/en-us/!@%23$%25%5E&*()_";
    NSCharacterSet* allowedCharacterSet = [NSCharacterSet URLFragmentAllowedCharacterSet];

    testUrlCharacterSetEncoding(urlDecodedString, urlEncodedString, allowedCharacterSet);

    urlDecodedString = @"Only alphabetic characters should be allowed and not encoded. !@#$%^&*()_+-=";
    urlEncodedString =
        @"Only%20alphabetic%20characters%20should%20be%20allowed%20and%20not%20encoded%2E%20%21%40%23%24%25%5E%26%2A%28%29%5F%2B%2D%3D";
    allowedCharacterSet = [NSCharacterSet alphanumericCharacterSet];

    testUrlCharacterSetEncoding(urlDecodedString, urlEncodedString, allowedCharacterSet);

    urlDecodedString = @"All alphabetic characters should be encoded. Symbols should not be: !@#$%^&*()_+-=";
    urlEncodedString = @"%41%6C%6C %61%6C%70%68%61%62%65%74%69%63 %63%68%61%72%61%63%74%65%72%73 %73%68%6F%75%6C%64 %62%65 "
                       @"%65%6E%63%6F%64%65%64. %53%79%6D%62%6F%6C%73 %73%68%6F%75%6C%64 %6E%6F%74 %62%65: !@#$%^&*()_+-=";
    allowedCharacterSet = [[NSCharacterSet alphanumericCharacterSet] invertedSet];

    testUrlCharacterSetEncoding(urlDecodedString, urlEncodedString, allowedCharacterSet);

    urlDecodedString = @"Here are some Emojis: \U0001F601 \U0001F602 \U0001F638 Emojis done."; // Multibyte encoded characters
    urlEncodedString = @"Here%20are%20some%20Emojis:%20%F0%9F%98%81%20%F0%9F%98%82%20%F0%9F%98%B8%20Emojis%20done.";
    allowedCharacterSet = [NSCharacterSet URLFragmentAllowedCharacterSet];

    testUrlCharacterSetEncoding(urlDecodedString, urlEncodedString, allowedCharacterSet);

    urlDecodedString = @"\1";
    urlEncodedString = @"%01";
    allowedCharacterSet = [NSCharacterSet alphanumericCharacterSet];

    testUrlCharacterSetEncoding(urlDecodedString, urlEncodedString, allowedCharacterSet);

    NSString* stringWillDie = [NSMutableString stringWithString:@"EntirelyAllowedCharacters"];
    urlEncodedString = @"EntirelyAllowedCharacters";
    allowedCharacterSet = [NSCharacterSet alphanumericCharacterSet];

    testString = [stringWillDie stringByAddingPercentEncodingWithAllowedCharacters:allowedCharacterSet];
    EXPECT_OBJCEQ(urlEncodedString, testString);

    // stringByAppendingFormat test
    NSString* testString2 = @"Numbers: ";
    NSString* expectedString = @"Numbers: 1, 2";
    NSString* actualString = [testString2 stringByAppendingFormat:@"%d, %@", 1, @"2"];
    EXPECT_OBJCEQ(expectedString, actualString);

    // stringWithFormat tests
    actualString = [NSString stringWithFormat:@"%x %d %u %.1f %o %c", 10, 11, 12, 13.0f, 14, 'a'];
    EXPECT_OBJCEQ(@"a 11 12 13.0 16 a", actualString);

    // %i is undocumented, but apps use it
    actualString = [NSString stringWithFormat:@"%i", -1];
    EXPECT_OBJCEQ(@"-1", actualString);

    actualString = [NSString stringWithFormat:@"%hhd %hd %ld %llX", (char)1, (short)2, 3L, -1ULL];
    EXPECT_OBJCEQ(@"1 2 3 FFFFFFFFFFFFFFFF", actualString);

// size_t and ptrdiff_t are not a set size causing this to fail on the reference platform
#ifdef WINOBJC
    actualString = [NSString stringWithFormat:@"%zx %zd", SIZE_MAX, INT_MIN];
    EXPECT_OBJCEQ(@"ffffffff -2147483648", actualString);

    actualString = [NSString stringWithFormat:@"%tx %td", PTRDIFF_MAX, PTRDIFF_MIN];
    EXPECT_OBJCEQ(@"7fffffff -2147483648", actualString);
#endif

    actualString = [NSString stringWithFormat:@"%jx %jd", UINTMAX_MAX, INTMAX_MIN];
    EXPECT_OBJCEQ(@"ffffffffffffffff -9223372036854775808", actualString);

    actualString = [NSString stringWithFormat:@"%qx %qd", ULLONG_MAX, LLONG_MIN];
    EXPECT_OBJCEQ(@"ffffffffffffffff -9223372036854775808", actualString);

    // Formatting with %g looks like it's printing the wrong number of digits, but it matches
    // the reference platform
    actualString = [NSString stringWithFormat:@"%.1e %.1E %.1g %.1G", 1e10, 1e0, 1e10, 1e0];
    EXPECT_OBJCEQ(@"1.0e+10 1.0E+00 1e+10 1", actualString);

    // rangeOfCharactersFromSet test
    NSString* testString3 = @"Alpha Bravo Charlie";
    NSCharacterSet* charSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    NSRange range;

    range = [testString3 rangeOfCharacterFromSet:charSet options:0];
    EXPECT_EQ(5, range.location);
    range = [testString3 rangeOfCharacterFromSet:charSet options:NSBackwardsSearch];
    EXPECT_EQ(11, range.location);
}

TEST(NSString, NSString_FastestEncoding) {
    NSString* asciiStr = @"ObjectiveC";
    NSString* extendedAsciiStr = @"ObjectiveC éééé";
    NSString* chineseStr = @"中文";

    ASSERT_EQ(NSASCIIStringEncoding, [asciiStr fastestEncoding]);
    ASSERT_EQ(NSUnicodeStringEncoding, [extendedAsciiStr fastestEncoding]);
    ASSERT_EQ(NSUnicodeStringEncoding, [chineseStr fastestEncoding]);

    ASSERT_EQ(kCFStringEncodingASCII, CFStringGetFastestEncoding(reinterpret_cast<CFStringRef>(asciiStr)));
    ASSERT_EQ(kCFStringEncodingUnicode, CFStringGetFastestEncoding(reinterpret_cast<CFStringRef>(extendedAsciiStr)));
    ASSERT_EQ(kCFStringEncodingUnicode, CFStringGetFastestEncoding(reinterpret_cast<CFStringRef>(chineseStr)));
}

TEST(NSString, UnownedDeepCopy) {
    char* buffer = _strdup("Hello World");

    NSString* firstString =
        [[[NSString alloc] initWithBytesNoCopy:buffer length:11 encoding:NSUTF8StringEncoding freeWhenDone:NO] autorelease];
    NSString* secondString = [[firstString copy] autorelease];

    EXPECT_OBJCEQ(firstString, secondString);

    buffer[0] = '\'';
    EXPECT_OBJCNE(firstString, secondString);
    free(buffer);
}

TEST(NSString, SubstringFromIndex) {
    NSString* asciiStr = @"ObjectiveC";
    NSString* extendedAsciiStr = @"ObjectiveC éééé";
    NSString* chineseStr = @"中文";
    ASSERT_OBJCEQ(@"tiveC", [asciiStr substringFromIndex:5]);
    ASSERT_OBJCEQ(@"C éééé", [extendedAsciiStr substringFromIndex:9]);
    ASSERT_OBJCEQ(@"文", [chineseStr substringFromIndex:1]);
}

TEST(NSString, PositionalFormatSpecifiers) {
    NSString* formattedString1 = [NSString stringWithFormat:@"%2$@ %1$@", @"Hello", @"World"];
    ASSERT_OBJCEQ(@"World Hello", formattedString1);

    NSString* formattedString2 = [NSString stringWithFormat:@"%4$d %3$d %2$d %1$d", 1, 2, 3, 4];
    ASSERT_OBJCEQ(@"4 3 2 1", formattedString2);
}

TEST(NSString, InitWithFormat) {
    NSString* string = [[[NSString alloc] initWithFormat:@"Default value is %d (%.1f)" locale:nil, 1000, 42.0] autorelease];
    ASSERT_OBJCEQ(string, @"Default value is 1000 (42.0)");

    string = [[[NSString alloc] initWithFormat:@"en_GB value is %d (%.1f)"
                                        locale:[NSLocale localeWithLocaleIdentifier:@"en_GB"], 1000, 42.0] autorelease];
    ASSERT_OBJCEQ(string, @"en_GB value is 1,000 (42.0)");

    string = [[[NSString alloc] initWithFormat:@"de_DE value is %d (%.1f)"
                                        locale:[NSLocale localeWithLocaleIdentifier:@"de_DE"], 1000, 42.0] autorelease];
    ASSERT_OBJCEQ(string, @"de_DE value is 1.000 (42,0)");

    string = [[[NSString alloc] initWithFormat:@"Default value is %d (%.1f)" locale:nil, 1000, 42.0] autorelease];
    ASSERT_OBJCEQ(string, @"Default value is 1000 (42.0)");

    UInt8 val = 75;
    string = [[[NSString alloc] initWithFormat:@"%02X" locale:nil, val] autorelease];
    ASSERT_OBJCEQ(string, @"4B");
}

TEST(NSString, LocalizedStandardCompare) {
    NSString* string = @"Abc3";
    ASSERT_EQ(NSOrderedAscending, [string localizedStandardCompare:@"ABC4"]);
}

TEST(NSString, PropertyList) {
    NSString* string = @"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" "
                       @"\"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n<plist "
                       @"version=\"1.0\">\n<dict>\n<key>Name</key>\n<string>John "
                       @"Doe</string>\n<key>Phones</key>\n<array>\n<string>408-974-0000</string>\n<string>503-333-5555</string>\n</"
                       @"array>\n</dict>\n</plist>";
    NSDictionary* plistDict;
    ASSERT_NO_THROW({ plistDict = [string propertyList]; });
    ASSERT_NE(nil, plistDict);

    NSDictionary* dict = [[[NSDictionary alloc]
        initWithObjectsAndKeys:@"John Doe", @"Name", @[ @"408-974-0000", @"503-333-5555" ], @"Phones", nil] autorelease];
    ASSERT_NE(nil, dict);
    ASSERT_OBJCEQ(dict, plistDict);
}

TEST(NSString, SubstringWithRangeOfComposedCharacterSequences) {
    NSString* string = @"😀H😀A😀👴🏻👮🏽";
    NSRange result = [string rangeOfComposedCharacterSequenceAtIndex:3];
    ASSERT_EQ(2, result.length);
    ASSERT_EQ(3, result.location);
}

TEST(NSString, RangeOfComposedCharacterSequencesForRange) {
    NSString* string = @"👴🏻👮🏽";
    NSRange result = [string rangeOfComposedCharacterSequencesForRange:NSMakeRange(0, [string length])];
    ASSERT_EQ(8, result.length);
}

TEST(NSString, Accents) {
    NSString* string = @"a\u0301";
    NSRange result = [string rangeOfComposedCharacterSequencesForRange:NSMakeRange(0, 1)];
    ASSERT_EQ(2, result.length);

    result = [string rangeOfComposedCharacterSequencesForRange:NSMakeRange(1, 1)];
    ASSERT_EQ(2, result.length);

    string = @"á";
    result = [string rangeOfComposedCharacterSequencesForRange:NSMakeRange(0, 1)];
    ASSERT_EQ(1, result.length);
}

TEST(NSString, GetParagraphStart) {
    NSString* paragraph = @"The NSString class and its mutable subclass, NSMutableString, provide an extensive set of APIs for working "
                          @"with strings, including methods for comparing, searching, and modifying strings. NSString objects are used "
                          @"extensively throughout Foundation and other Cocoa frameworks, serving as the basis for all textual and "
                          @"linguistic functionality on the platform.\r\nNSString is “toll-free bridged” with its Core Foundation "
                          @"counterpart, CFStringRef. See “Toll-Free Bridging” for more information.";
    NSUInteger startIndex, endIndex;
    [paragraph getParagraphStart:&startIndex end:&endIndex contentsEnd:NULL forRange:NSMakeRange(0, [paragraph length])];

    ASSERT_EQ('T', [paragraph characterAtIndex:startIndex]);
    ASSERT_EQ([paragraph length], endIndex);
}

TEST(NSString, GetParagraphStart2) {
    NSString* paragraph = @"\n\nThe NSString class and its mutable subclass, NSMutableString, provide an extensive set of APIs for working "
                          @"with strings, including methods for comparing, searching, and modifying strings. NSString objects are used "
                          @"extensively throughout Foundation and other Cocoa frameworks, serving as the basis for all textual and "
                          @"linguistic functionality on the platform.\r\nrNSString is “toll-free bridged” with its Core Foundation "
                          @"counterpart, CFStringRef. See “Toll-Free Bridging” for more information.\n\n";
    NSUInteger startIndex, endIndex;
    [paragraph getParagraphStart:&startIndex end:&endIndex contentsEnd:NULL forRange:NSMakeRange(1, [paragraph length] - 1)];

    ASSERT_EQ(1, startIndex);
    ASSERT_EQ([paragraph length], endIndex);
}

TEST(NSString, GetParagraphStart3) {
    NSString* paragraph = @"\nThe NSString class and its mutable subclass, NSMutableString, provide an extensive set of APIs for working "
                          @"with strings, including methods for comparing, searching, and modifying strings. NSString objects are used "
                          @"extensively throughout Foundation and other Cocoa frameworks, serving as the basis for all textual and "
                          @"linguistic functionality on the platform.\r\nNSString is “toll-free bridged” with its Core Foundation "
                          @"counterpart, CFStringRef. See “Toll-Free Bridging” for more informat\n\nion.";
    NSUInteger startIndex, endIndex;
    [paragraph getParagraphStart:&startIndex end:&endIndex contentsEnd:NULL forRange:NSMakeRange(1, [paragraph length] - 1)];

    ASSERT_EQ(1, startIndex);
    ASSERT_EQ([paragraph length], endIndex);
}

TEST(NSString, GetParagraphStart4) {
    NSString* paragraph = @"\n\rThe NSString class and its mutable subclass, NSMutableString, provide an extensive set of APIs for working "
                          @"with strings, including methods for comparing, searching, and modifying strings. NSString objects are used "
                          @"extensively throughout Foundation and other Cocoa frameworks, serving as the basis for all textual and "
                          @"linguistic functionality on the platform.\r\nNSString is “toll-free bridged” with its Core Foundation "
                          @"counterpart, CFStringRef. See “Toll-Free Bridging” for more information.\r\n";
    NSUInteger startIndex, endIndex;
    [paragraph getParagraphStart:&startIndex end:&endIndex contentsEnd:NULL forRange:NSMakeRange(1, [paragraph length] - 1)];

    ASSERT_EQ(1, startIndex);
    ASSERT_EQ([paragraph length], endIndex);
}

TEST(NSString, GetParagraphStart5) {
    NSString* paragraph = @"\n\rThe NSString class and its mutable subclass, NSMutableString, provide an extensive set of APIs for working "
                          @"with strings, including methods for comparing, searching, and modifying strings. NSString objects are used "
                          @"extensively throughout Foundation and other Cocoa frameworks, serving as the basis for all textual and "
                          @"linguistic functionality on the platform.\r\nNSString is “toll-free bridged” with its Core Foundation "
                          @"counterpart, CFStringRef. See “Toll-Free Bridging” for more information.\r\n";
    NSUInteger startIndex, endIndex;
    [paragraph getParagraphStart:&startIndex end:&endIndex contentsEnd:NULL forRange:NSMakeRange(1, 0)];

    ASSERT_EQ(1, startIndex);
    ASSERT_EQ(2, endIndex);

    [paragraph getParagraphStart:&startIndex end:&endIndex contentsEnd:NULL forRange:NSMakeRange(1, 20)];
    ASSERT_EQ(1, startIndex);
    ASSERT_EQ(362, endIndex);

    [paragraph getParagraphStart:&startIndex end:&endIndex contentsEnd:NULL forRange:NSMakeRange(10, 20)];
    ASSERT_EQ(2, startIndex);
    ASSERT_EQ(362, endIndex);

    [paragraph getParagraphStart:&startIndex end:&endIndex contentsEnd:NULL forRange:NSMakeRange(365, [paragraph length] - 365)];
    ASSERT_EQ(362, startIndex);
    ASSERT_EQ([paragraph length], endIndex);

    [paragraph getParagraphStart:&startIndex end:&endIndex contentsEnd:NULL forRange:NSMakeRange(0, [paragraph length])];
    ASSERT_EQ(0, startIndex);
    ASSERT_EQ([paragraph length], endIndex);

    [paragraph getParagraphStart:&startIndex end:&endIndex contentsEnd:NULL forRange:NSMakeRange([paragraph length], 0)];
    ASSERT_EQ([paragraph length], startIndex);
    ASSERT_EQ([paragraph length], endIndex);
}

TEST(NSString, GetParagraphStart6) {
    NSString* paragraph = @"\n\rThe NSString class and its mutable subclass, NSMutableString, provide an extensive set of APIs for working "
                          @"with strings, including methods for comparing, searching, and modifying strings. NSString objects are used "
                          @"extensively throughout Foundation and other Cocoa frameworks, serving as the basis for all textual and "
                          @"linguistic functionality on the platform.\r\nNSString is “toll-free bridged” with its Core Foundation "
                          @"counterpart, CFStringRef. See “Toll-Free Bridging” for more information.";
    NSUInteger startIndex, endIndex;
    [paragraph getParagraphStart:&startIndex end:&endIndex contentsEnd:NULL forRange:NSMakeRange(0, [paragraph length])];

    ASSERT_EQ(0, startIndex);
    ASSERT_EQ([paragraph length], endIndex);
}

TEST(NSString, GetParagraphStart7) {
    NSString* paragraph = @"\r";
    NSUInteger startIndex, endIndex, contentsEnd;
    [paragraph getParagraphStart:&startIndex end:&endIndex contentsEnd:&contentsEnd forRange:NSMakeRange(0, 1)];

    ASSERT_EQ(0, startIndex);
    ASSERT_EQ([paragraph length], endIndex);
    ASSERT_EQ(0, contentsEnd);
}

TEST(NSString, GetParagraphStart8) {
    NSString* paragraph = @"\n\rThe NSString class and its mutable subclass, NSMutableString, provide an extensive set of APIs for working "
                          @"with strings, including methods for comparing, searching, and modifying strings. NSString objects are used "
                          @"extensively throughout Foundation and other Cocoa frameworks, serving as the basis for all textual and "
                          @"linguistic functionality on the platform.\r\nNSString is “toll-free bridged” with its Core Foundation "
                          @"counterpart, CFStringRef. See “Toll-Free Bridging” for more information.\r";
    NSUInteger startIndex, endIndex, contentsEnd;
    [paragraph getParagraphStart:&startIndex end:&endIndex contentsEnd:&contentsEnd forRange:NSMakeRange(0, [paragraph length])];

    ASSERT_EQ(0, startIndex);
    ASSERT_EQ([paragraph length], endIndex);
    ASSERT_EQ([paragraph length] - 1, contentsEnd);
}

TEST(NSString, GetParagraphStart9) {
    NSString* paragraph = @"\r\nThe NSString class and its mutable subclass, NSMutableString, provide an extensive set of APIs for working "
                          @"with strings, including methods for comparing, searching, and modifying strings. NSString objects are used "
                          @"extensively throughout Foundation and other Cocoa frameworks, serving as the basis for all textual and "
                          @"linguistic functionality on the platform.\r\nNSString is “toll-free bridged” with its Core Foundation "
                          @"counterpart, CFStringRef. See “Toll-Free Bridging” for more information.\r";
    NSUInteger startIndex, endIndex, contentsEnd;

    [paragraph getParagraphStart:&startIndex end:&endIndex contentsEnd:&contentsEnd forRange:NSMakeRange(1, [paragraph length] - 1)];
    ASSERT_EQ(0, startIndex);
    ASSERT_EQ([paragraph length], endIndex);
    ASSERT_EQ([paragraph length] - 1, contentsEnd);

    [paragraph getParagraphStart:&startIndex end:&endIndex contentsEnd:&contentsEnd forRange:NSMakeRange(1, 20)];
    ASSERT_EQ(0, startIndex);
    ASSERT_EQ(362, endIndex);
    ASSERT_EQ(360, contentsEnd);
}

TEST(NSString, GetParagraphStartEmptyString) {
    NSString* paragraph = @"";
    NSUInteger startIndex, endIndex, contentsEnd;

    [paragraph getParagraphStart:&startIndex end:&endIndex contentsEnd:&contentsEnd forRange:NSMakeRange(0, 0)];
    ASSERT_EQ(0, startIndex);
    ASSERT_EQ(0, endIndex);
    ASSERT_EQ(0, contentsEnd);
}

TEST(NSString, GetParagraphStringWithBytes) {
    NSUInteger startIndex, endIndex, contentsEnd;
    UInt8 data[] = { 'H', '\0', 'E', 'L', '0', '\0', 'W', '\n', '\r' };
    NSString* paragraph = [static_cast<NSString*>(CFStringCreateWithBytes(NULL, data, 9, kCFStringEncodingUTF8, true)) autorelease];
    [paragraph getParagraphStart:&startIndex end:&endIndex contentsEnd:&contentsEnd forRange:NSMakeRange(0, [paragraph length])];
    ASSERT_EQ(0, startIndex);
    ASSERT_EQ([paragraph length], endIndex);
    ASSERT_EQ([paragraph length] - 1, contentsEnd);

    [paragraph getParagraphStart:&startIndex end:&endIndex contentsEnd:&contentsEnd forRange:NSMakeRange(1, [paragraph length] - 1)];
    ASSERT_EQ(0, startIndex);
    ASSERT_EQ([paragraph length], endIndex);
    ASSERT_EQ([paragraph length] - 1, contentsEnd);

    [paragraph getParagraphStart:&startIndex end:&endIndex contentsEnd:&contentsEnd forRange:NSMakeRange(0, 0)];
    ASSERT_EQ(0, startIndex);
    ASSERT_EQ([paragraph length] - 1, endIndex);
    ASSERT_EQ([paragraph length] - 2, contentsEnd);

    [paragraph getParagraphStart:&startIndex end:&endIndex contentsEnd:&contentsEnd forRange:NSMakeRange([paragraph length], 0)];
    ASSERT_EQ([paragraph length], startIndex);
    ASSERT_EQ([paragraph length], endIndex);
    ASSERT_EQ([paragraph length], contentsEnd);
}

TEST(NSString, GetParagraphStringWithBytes2) {
    NSUInteger startIndex, endIndex, contentsEnd;
    UInt8 data[] = { '\0', '\n', 'H', '\0', 'E', 'L', '0', '\0', 'W', '\r', '\n' };
    NSString* paragraph = [static_cast<NSString*>(CFStringCreateWithBytes(NULL, data, 11, kCFStringEncodingUTF8, true)) autorelease];
    [paragraph getParagraphStart:&startIndex end:&endIndex contentsEnd:&contentsEnd forRange:NSMakeRange(0, [paragraph length])];
    ASSERT_EQ(0, startIndex);
    ASSERT_EQ([paragraph length], endIndex);
    ASSERT_EQ([paragraph length] - 2, contentsEnd);

    [paragraph getParagraphStart:&startIndex end:&endIndex contentsEnd:&contentsEnd forRange:NSMakeRange(1, [paragraph length] - 1)];
    ASSERT_EQ(0, startIndex);
    ASSERT_EQ([paragraph length], endIndex);
    ASSERT_EQ([paragraph length] - 2, contentsEnd);

    [paragraph getParagraphStart:&startIndex end:&endIndex contentsEnd:&contentsEnd forRange:NSMakeRange(0, 0)];
    ASSERT_EQ(0, startIndex);
    ASSERT_EQ(2, endIndex);
    ASSERT_EQ(1, contentsEnd);

    [paragraph getParagraphStart:&startIndex end:&endIndex contentsEnd:&contentsEnd forRange:NSMakeRange([paragraph length], 0)];
    ASSERT_EQ([paragraph length], startIndex);
    ASSERT_EQ([paragraph length], endIndex);
    ASSERT_EQ([paragraph length], contentsEnd);
}

TEST(NSString, GetParagraphStringWithBytes3) {
    NSUInteger startIndex, endIndex, contentsEnd;
    UInt8 data[] = { '\n', 'H', '\0', 'E', 'L', '0', '\0', 'W', '\r' };
    NSString* paragraph = [static_cast<NSString*>(CFStringCreateWithBytes(NULL, data, 9, kCFStringEncodingUTF8, true)) autorelease];

    [paragraph getParagraphStart:&startIndex end:&endIndex contentsEnd:&contentsEnd forRange:NSMakeRange(0, [paragraph length])];
    ASSERT_EQ(0, startIndex);
    ASSERT_EQ([paragraph length], endIndex);
    ASSERT_EQ([paragraph length] - 1, contentsEnd);

    [paragraph getParagraphStart:&startIndex end:&endIndex contentsEnd:&contentsEnd forRange:NSMakeRange(1, [paragraph length] - 1)];
    ASSERT_EQ(1, startIndex);
    ASSERT_EQ([paragraph length], endIndex);
    ASSERT_EQ([paragraph length] - 1, contentsEnd);

    [paragraph getParagraphStart:&startIndex end:&endIndex contentsEnd:&contentsEnd forRange:NSMakeRange(0, 0)];
    ASSERT_EQ(0, startIndex);
    ASSERT_EQ(1, endIndex);
    ASSERT_EQ(0, contentsEnd);

    [paragraph getParagraphStart:&startIndex end:&endIndex contentsEnd:&contentsEnd forRange:NSMakeRange([paragraph length], 0)];
    ASSERT_EQ([paragraph length], startIndex);
    ASSERT_EQ([paragraph length], endIndex);
    ASSERT_EQ([paragraph length], contentsEnd);
}

TEST(NSString, GetParagraphStringWithBytes4) {
    NSUInteger startIndex, endIndex, contentsEnd;
    UInt8 data[] = { '\r', 'H', '\0', 'E', 'L', '0', '\0', 'W', '\r' };
    NSString* paragraph = [static_cast<NSString*>(CFStringCreateWithBytes(NULL, data, 9, kCFStringEncodingUTF8, true)) autorelease];

    [paragraph getParagraphStart:&startIndex end:&endIndex contentsEnd:&contentsEnd forRange:NSMakeRange(0, [paragraph length])];
    ASSERT_EQ(0, startIndex);
    ASSERT_EQ([paragraph length], endIndex);
    ASSERT_EQ([paragraph length] - 1, contentsEnd);

    [paragraph getParagraphStart:&startIndex end:&endIndex contentsEnd:&contentsEnd forRange:NSMakeRange(1, [paragraph length] - 1)];
    ASSERT_EQ(1, startIndex);
    ASSERT_EQ([paragraph length], endIndex);
    ASSERT_EQ([paragraph length] - 1, contentsEnd);

    [paragraph getParagraphStart:&startIndex end:&endIndex contentsEnd:&contentsEnd forRange:NSMakeRange(0, 0)];
    ASSERT_EQ(0, startIndex);
    ASSERT_EQ(1, endIndex);
    ASSERT_EQ(0, contentsEnd);

    [paragraph getParagraphStart:&startIndex end:&endIndex contentsEnd:&contentsEnd forRange:NSMakeRange([paragraph length], 0)];
    ASSERT_EQ([paragraph length], startIndex);
    ASSERT_EQ([paragraph length], endIndex);
    ASSERT_EQ([paragraph length], contentsEnd);
}

TEST(NSString, GetParagraphStringWithBytes5) {
    NSUInteger startIndex, endIndex, contentsEnd;
    UInt8 data[] = { '\n', '\r', 'H', '\0', 'E', 'L', '0', '\0', 'W', '\r' };
    NSString* paragraph = [static_cast<NSString*>(CFStringCreateWithBytes(NULL, data, 10, kCFStringEncodingUTF8, true)) autorelease];

    [paragraph getParagraphStart:&startIndex end:&endIndex contentsEnd:&contentsEnd forRange:NSMakeRange(0, [paragraph length])];
    ASSERT_EQ(0, startIndex);
    ASSERT_EQ([paragraph length], endIndex);
    ASSERT_EQ([paragraph length] - 1, contentsEnd);

    [paragraph getParagraphStart:&startIndex end:&endIndex contentsEnd:&contentsEnd forRange:NSMakeRange(1, [paragraph length] - 1)];
    ASSERT_EQ(1, startIndex);
    ASSERT_EQ([paragraph length], endIndex);
    ASSERT_EQ([paragraph length] - 1, contentsEnd);

    [paragraph getParagraphStart:&startIndex end:&endIndex contentsEnd:&contentsEnd forRange:NSMakeRange(0, 0)];
    ASSERT_EQ(0, startIndex);
    ASSERT_EQ(1, endIndex);
    ASSERT_EQ(0, contentsEnd);

    [paragraph getParagraphStart:&startIndex end:&endIndex contentsEnd:&contentsEnd forRange:NSMakeRange([paragraph length], 0)];
    ASSERT_EQ([paragraph length], startIndex);
    ASSERT_EQ([paragraph length], endIndex);
    ASSERT_EQ([paragraph length], contentsEnd);
}

TEST(NSString, GetParagraphStringWithBytes6) {
    NSUInteger startIndex, endIndex, contentsEnd;
    UInt8 data[] = { '\r', '\n', 'H', '\0', 'E', 'L', '0', '\0', 'W', '\r', '\n' };
    NSString* paragraph = [static_cast<NSString*>(CFStringCreateWithBytes(NULL, data, 11, kCFStringEncodingUTF8, true)) autorelease];

    [paragraph getParagraphStart:&startIndex end:&endIndex contentsEnd:&contentsEnd forRange:NSMakeRange(0, [paragraph length])];
    ASSERT_EQ(0, startIndex);
    ASSERT_EQ([paragraph length], endIndex);
    ASSERT_EQ([paragraph length] - 2, contentsEnd);

    [paragraph getParagraphStart:&startIndex end:&endIndex contentsEnd:&contentsEnd forRange:NSMakeRange(1, [paragraph length] - 1)];
    ASSERT_EQ(0, startIndex);
    ASSERT_EQ([paragraph length], endIndex);
    ASSERT_EQ([paragraph length] - 2, contentsEnd);

    [paragraph getParagraphStart:&startIndex end:&endIndex contentsEnd:&contentsEnd forRange:NSMakeRange(0, 0)];
    ASSERT_EQ(0, startIndex);
    ASSERT_EQ(2, endIndex);
    ASSERT_EQ(0, contentsEnd);

    [paragraph getParagraphStart:&startIndex end:&endIndex contentsEnd:&contentsEnd forRange:NSMakeRange([paragraph length], 0)];
    ASSERT_EQ([paragraph length], startIndex);
    ASSERT_EQ([paragraph length], endIndex);
    ASSERT_EQ([paragraph length], contentsEnd);
}

TEST(NSString, PathExtensions) {
    NSString* string = @"";
    ASSERT_TRUE([string.pathExtension isEqualToString:@""]);

    string = @"hello.world";
    ASSERT_TRUE([string.pathExtension isEqualToString:@"world"]);

    string = @"C:\\FolderA\\file.plist";
    ASSERT_TRUE([string.pathExtension isEqualToString:@"plist"]);

    string = @"/tmp/scratch.tiff";
    ASSERT_TRUE([string.pathExtension isEqualToString:@"tiff"]);

    string = @".scratch.tiff";
    ASSERT_TRUE([string.pathExtension isEqualToString:@"tiff"]);

    string = @"/tmp/scratch";
    ASSERT_TRUE([string.pathExtension isEqualToString:@""]);

    string = @".tiff";
    ASSERT_TRUE([string.pathExtension isEqualToString:@""]);

    string = @".";
    ASSERT_TRUE([string.pathExtension isEqualToString:@""]);

    string = @"foo.";
    ASSERT_TRUE([string.pathExtension isEqualToString:@""]);

    string = @"/tmp/";
    ASSERT_TRUE([string.pathExtension isEqualToString:@""]);

    string = @"/tmp/scratch..tiff";
    ASSERT_TRUE([string.pathExtension isEqualToString:@"tiff"]);

    string = @"/tmp/random.foo.tiff";
    ASSERT_TRUE([string.pathExtension isEqualToString:@"tiff"]);
}

TEST(NSString, Exceptions) {
    NSRange range{ 100, 10 };

    EXPECT_ANY_THROW([@"hello" characterAtIndex:10]);

    unichar buffer[1024];
    EXPECT_ANY_THROW([@"hello" getCharacters:&buffer[0] range:range]);

    EXPECT_ANY_THROW([[[@"hello" mutableCopy] autorelease] replaceCharactersInRange:range withString:@"boom"]);

    EXPECT_ANY_THROW([(NSMutableString*)@"hello" replaceCharactersInRange:range withString:@"boom"]);

    NSString* immutableFormattedString = [NSString stringWithFormat:@"Hello %p", buffer];
    EXPECT_ANY_THROW([(NSMutableString*)immutableFormattedString replaceCharactersInRange:range withString:@"boom"]);
}

TEST(NSString, StringsFormatPropertyList) {
    NSString* string = @"key1=value1;\n\"key2\"=\"value2\";";

    ASSERT_OBJCNE(nil, string);

    NSDictionary* propertyList = [string propertyListFromStringsFileFormat];

    ASSERT_OBJCNE(nil, propertyList);

    ASSERT_OBJCEQ(@"value1", propertyList[@"key1"]);
    ASSERT_OBJCEQ(@"value2", propertyList[@"key2"]);
}

TEST(NSString, StringByAddingPercentEscapesUsingEncodingTest) {
    NSString* originalString = @"abcdefghijklmnopqrstuvwxyz : !@#$%^&*()_+1234567890-=`~\\|]}[{'\";:.>,</?";
    NSString* expectedEscapedString =
        @"abcdefghijklmnopqrstuvwxyz%20:%20!@%23$%25%5E&*()_+1234567890-=%60~%5C%7C%5D%7D%5B%7B'%22;:.%3E,%3C/?";

    NSString* escapedString = [originalString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];

    EXPECT_OBJCEQ(expectedEscapedString, escapedString);
    EXPECT_OBJCEQ(originalString, escapedString.stringByRemovingPercentEncoding);
    EXPECT_OBJCEQ(originalString, [escapedString stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding]);

    originalString = @"claesström";
    expectedEscapedString = @"claesstr%C3%B6m";

    escapedString = [originalString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];

    EXPECT_OBJCEQ(expectedEscapedString, escapedString);
    EXPECT_OBJCEQ(originalString, escapedString.stringByRemovingPercentEncoding);
    EXPECT_OBJCEQ(originalString, [escapedString stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding]);

    // Removing percent encoding is unsupported on the reference platform for anything other than UTF8.
    // This test is to ensure the percent encoding matches the reference platform's behavior.
    originalString = @"abcdefghijklmnopqrstuvwxyz : !@#$%^&*()_+1234567890-=`~\\|]}[{'\";:.>,</?";
    expectedEscapedString = @"abcdefghijklmnopqrstuvwxyz%FF%FE%20%00:%FF%FE%20%00!@%FF%FE%23%00$%FF%FE%25%00%FF%FE%5E%00&*()_+1234567890-=%"
                            @"FF%FE%60%00~%FF%FE%5C%00%FF%FE%7C%00%FF%FE%5D%00%FF%FE%7D%00%FF%FE%5B%00%FF%FE%7B%00'%FF%FE%22%00;:.%FF%FE%"
                            @"3E%00,%FF%FE%3C%00/?";

    escapedString = [originalString stringByAddingPercentEscapesUsingEncoding:NSUnicodeStringEncoding];

    EXPECT_OBJCEQ(expectedEscapedString, escapedString);
}
TEST(NSString, LastPathComponent) {
    NSString* string = @"";
    EXPECT_OBJCEQ(@"", string.lastPathComponent);

    string = @"hello.world";
    EXPECT_OBJCEQ(@"hello.world", string.lastPathComponent);

    string = @"/";
    EXPECT_OBJCEQ(@"/", string.lastPathComponent);

#if TARGET_OS_WIN32
    // Backward slash isn't properly supported in OSX, you end up getting FolderA\file.plist
    string = @"C:\\FolderA\\file.plist";
    EXPECT_OBJCEQ(@"file.plist", string.lastPathComponent);
#endif

    string = @"/tmp/scratch.tiff";
    EXPECT_OBJCEQ(@"scratch.tiff", string.lastPathComponent);

    string = @".scratch.tiff";
    EXPECT_OBJCEQ(@".scratch.tiff", string.lastPathComponent);

    string = @"/tmp/scratch";
    EXPECT_OBJCEQ(@"scratch", string.lastPathComponent);

    string = @".tiff";
    EXPECT_OBJCEQ(@".tiff", string.lastPathComponent);

    string = @".";
    EXPECT_OBJCEQ(@".", string.lastPathComponent);

    string = @"foo.";
    EXPECT_OBJCEQ(@"foo.", string.lastPathComponent);

    string = @"/tmp/";
    EXPECT_OBJCEQ(@"tmp", string.lastPathComponent);

    string = @"scratch///";
    EXPECT_OBJCEQ(@"scratch", string.lastPathComponent);

    string = @"////";
    EXPECT_OBJCEQ(@"/", string.lastPathComponent);

    string = @"/tmp/scratch..tiff";
    EXPECT_OBJCEQ(@"scratch..tiff", string.lastPathComponent);

    string = @"/tmp/random.foo.tiff";
    EXPECT_OBJCEQ(@"random.foo.tiff", string.lastPathComponent);

    string = @"/temp//foo//bar.txt";
    EXPECT_OBJCEQ(@"bar.txt", string.lastPathComponent);

    string = @"/.";
    EXPECT_OBJCEQ(@".", string.lastPathComponent);

    string = @"/foo/bar/.";
    EXPECT_OBJCEQ(@".", string.lastPathComponent);

    string = @"/baz/bar/.foo";
    EXPECT_OBJCEQ(@".foo", string.lastPathComponent);

    string = @"/tmp/foo.";
    EXPECT_OBJCEQ(@"foo.", string.lastPathComponent);

    string = @"/tmp/foo///";
    EXPECT_OBJCEQ(@"foo", string.lastPathComponent);
}

TEST(NSString, MutableInstanceArchivesAsMutable) {
    NSMutableString* input = [NSMutableString stringWithString:@"hello"];

    NSData* data = [NSKeyedArchiver archivedDataWithRootObject:input];
    ASSERT_OBJCNE(nil, data);

    NSMutableString* output = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    ASSERT_OBJCNE(nil, output);

    EXPECT_NO_THROW([output appendString:@" world"]);
    EXPECT_OBJCEQ(@"hello world", output);

    EXPECT_OBJCNE(input, output);
}

TEST(NSString, ContainsString) {
    EXPECT_ANY_THROW([@"" containsString:nil]);

    EXPECT_FALSE([@"" containsString:@""]);
    EXPECT_FALSE([@"TÉST" containsString:@""]);

    EXPECT_TRUE([@"TÉST" containsString:@"T"]);
    EXPECT_TRUE([@"TÉST" containsString:@"TÉST"]);
    EXPECT_TRUE([@"TE\u0301ST" containsString:@"TÉST"]);
    EXPECT_TRUE([@"TÉST" containsString:@"TE\u0301ST"]);
    EXPECT_TRUE([@"اختبار النص" containsString:@"اختبار النص"]);
    EXPECT_TRUE([@"اختبار النص" containsString:@"اختبار ال"]);

    EXPECT_FALSE([@"TE\u0301ST" containsString:@"TéST"]);
    EXPECT_FALSE([@"TÉST" containsString:@"Te\u0301ST"]);
    EXPECT_FALSE([@"TÉST" containsString:@"Y"]);
    EXPECT_FALSE([@"TÉST" containsString:@"TÉSTY"]);
    EXPECT_FALSE([@"TÉST" containsString:@"TEST"]);
    EXPECT_FALSE([@"TÉST" containsString:@"test"]);
    EXPECT_FALSE([@"TÉST" containsString:@"tést"]);
}

TEST(NSString, LocalizedCaseInsensitiveContainsString) {
    EXPECT_ANY_THROW([@"" localizedCaseInsensitiveContainsString:nil]);

    EXPECT_FALSE([@"" localizedCaseInsensitiveContainsString:@""]);
    EXPECT_FALSE([@"TÉST" localizedCaseInsensitiveContainsString:@""]);

    EXPECT_TRUE([@"TÉST" localizedCaseInsensitiveContainsString:@"T"]);
    EXPECT_TRUE([@"TÉST" localizedCaseInsensitiveContainsString:@"TÉST"]);
    EXPECT_TRUE([@"TÉST" localizedCaseInsensitiveContainsString:@"tést"]);
    EXPECT_TRUE([@"TE\u0301ST" localizedCaseInsensitiveContainsString:@"TÉST"]);
    EXPECT_TRUE([@"TÉST" localizedCaseInsensitiveContainsString:@"TE\u0301ST"]);
    EXPECT_TRUE([@"اختبار النص" localizedCaseInsensitiveContainsString:@"اختبار النص"]);
    EXPECT_TRUE([@"اختبار النص" localizedCaseInsensitiveContainsString:@"اختبار ال"]);
    EXPECT_TRUE([@"TE\u0301ST" localizedCaseInsensitiveContainsString:@"TéST"]);
    EXPECT_TRUE([@"TÉST" localizedCaseInsensitiveContainsString:@"Te\u0301ST"]);

    EXPECT_FALSE([@"TÉST" localizedCaseInsensitiveContainsString:@"Y"]);
    EXPECT_FALSE([@"TÉST" localizedCaseInsensitiveContainsString:@"TÉSTY"]);
    EXPECT_FALSE([@"TÉST" localizedCaseInsensitiveContainsString:@"TEST"]);
    EXPECT_FALSE([@"TÉST" localizedCaseInsensitiveContainsString:@"test"]);
}

TEST(NSString, LocalizedStandardContainsString) {
    EXPECT_ANY_THROW([@"" localizedStandardContainsString:nil]);

    EXPECT_FALSE([@"" localizedStandardContainsString:@""]);
    EXPECT_FALSE([@"TÉST" localizedStandardContainsString:@""]);

    EXPECT_TRUE([@"TÉST" localizedStandardContainsString:@"T"]);
    EXPECT_TRUE([@"TÉST" localizedStandardContainsString:@"TÉST"]);
    EXPECT_TRUE([@"TE\u0301ST" localizedStandardContainsString:@"TÉST"]);
    EXPECT_TRUE([@"TÉST" localizedStandardContainsString:@"TE\u0301ST"]);
    EXPECT_TRUE([@"اختبار النص" localizedStandardContainsString:@"اختبار النص"]);
    EXPECT_TRUE([@"اختبار النص" localizedStandardContainsString:@"اختبار ال"]);
    EXPECT_TRUE([@"TE\u0301ST" localizedStandardContainsString:@"TéST"]);
    EXPECT_TRUE([@"TÉST" localizedStandardContainsString:@"Te\u0301ST"]);

    EXPECT_FALSE([@"TÉST" localizedStandardContainsString:@"Y"]);
    EXPECT_FALSE([@"TÉST" localizedStandardContainsString:@"TÉSTY"]);

    EXPECT_TRUE([@"TÉST" localizedStandardContainsString:@"TEST"]);
    EXPECT_TRUE([@"TÉST" localizedStandardContainsString:@"test"]);
    EXPECT_TRUE([@"TÉST" localizedStandardContainsString:@"tést"]);
}

TEST(NSString, ComparingDifferentTypes) {
    NSString* stringOne = @"Hello";
    const unsigned char stringOneUTF8[] = { 'H', 'e', 'l', 'l', 'o', 0 };
    const unsigned char stringOneUTF16[] = { 'H', 0, 'e', 0, 'l', 0, 'l', 0, 'o', 0, 0, 0 };
    NSString* stringOneUTF8String = [NSMutableString stringWithUTF8String:reinterpret_cast<const char*>(stringOneUTF8)];
    NSString* stringOneUTF16String = [NSMutableString stringWithCharacters:reinterpret_cast<const unichar*>(stringOneUTF16) length:5];

    EXPECT_OBJCEQ(stringOne, stringOneUTF8String);
    EXPECT_OBJCEQ(stringOne, stringOneUTF16String);
    EXPECT_OBJCEQ(stringOneUTF8String, stringOneUTF16String);

    EXPECT_EQ(stringOne.hash, stringOneUTF8String.hash);
    EXPECT_EQ(stringOne.hash, stringOneUTF16String.hash);
    EXPECT_EQ(stringOneUTF8String.hash, stringOneUTF16String.hash);

    NSString* stringTwo = @"\u0CA0_\u0CA0";
    const unsigned char stringTwoUTF8[] = { 0xE0, 0xB2, 0xA0, '_', 0xE0, 0xB2, 0xA0, 0 };
    const unsigned char stringTwoUTF16[] = { 0xA0, 0x0C, '_', 0, 0xA0, 0x0C, 0, 0 };
    NSString* stringTwoUTF8String = [NSMutableString stringWithUTF8String:reinterpret_cast<const char*>(stringTwoUTF8)];
    NSString* stringTwoUTF16String = [NSMutableString stringWithCharacters:reinterpret_cast<const unichar*>(stringTwoUTF16) length:3];

    EXPECT_OBJCEQ(stringTwo, stringTwoUTF8String);
    EXPECT_OBJCEQ(stringTwo, stringTwoUTF16String);
    EXPECT_OBJCEQ(stringTwoUTF8String, stringTwoUTF16String);

    EXPECT_EQ(stringTwo.hash, stringTwoUTF8String.hash);
    EXPECT_EQ(stringTwo.hash, stringTwoUTF16String.hash);
    EXPECT_EQ(stringTwoUTF8String.hash, stringTwoUTF16String.hash);
}

TEST(NSString, GetCharacters) {
    NSString* string1 = @"i am a fairly boring string";
    //                                    1       2
    //                    0       8       6       4
    NSRange range1{ 7, 13 };
    unichar buffer1[16]{ 0 };
    const char16_t* expected1 = u"fairly boring"; // range: {7, 13}

    [string1 getCharacters:buffer1 range:range1];
    EXPECT_TRUE(std::equal(expected1, expected1 + range1.length, buffer1));

    NSString* string2 = @"my \u0CA0_\u0CA0 face";
    //                    0  3     45     6  8
    NSRange range2{ 3, 3 };
    unichar buffer2[16]{ 0 };
    const char16_t* expected2 = u"\u0CA0_\u0CA0"; // range: {3, 3}

    [string2 getCharacters:buffer2 range:range2];
    EXPECT_TRUE(std::equal(expected2, expected2 + range2.length, buffer2));
}
