//******************************************************************************
//
// Copyright (c) 2016 Microsoft Corporation. All rights reserved.
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
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2015 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
#import "Starboard/SmartTypes.h"
#import <Foundation/Foundation.h>
#import <TestFramework.h>
#import "TestUtils.h"

#import <CoreFoundation/CoreFoundation.h>

#include <vector>

TEST(NSString, BOOLValue) {
    auto trueStrings = @[ @"t", @"true", @"TRUE", @"tRuE", @"yes", @"YES", @"1", @"+000009" ];
    for (NSString* string in trueStrings) {
        ASSERT_TRUE([string boolValue]);
    }
    auto falseStrings = @[ @"false", @"FALSE", @"fAlSe", @"no", @"NO", @"0", @"<true>", @"_true", @"-00000" ];
    for (NSString* string in falseStrings) {
        ASSERT_FALSE([string boolValue]);
    }
}

TEST(NSString, BridgeConstruction) {
    NSString* literalConversion = @"literal";
    ASSERT_EQ([literalConversion length], 7);

    NSString* nonLiteralConversion = @"test\(self)";
    ASSERT_TRUE(nonLiteralConversion.length > 4);
    auto c = '4';
    NSString* nonLiteral2 = [[NSString alloc] initWithBytes:&c length:1 encoding:NSASCIIStringEncoding];
    auto t = [nonLiteral2 characterAtIndex:0];
    ASSERT_TRUE(t == 52);

    NSString* externalString = [NSString localizedNameOfStringEncoding:[NSString defaultCStringEncoding]];
    ASSERT_TRUE(externalString.length >= 4);

    NSString* cluster = @"✌🏾";
    ASSERT_EQ([cluster length], 3);
}

TEST(NSString, IntegerValue) {
    NSString* string1 = @"123";
    ASSERT_EQ([string1 integerValue], 123);

    NSString* string2 = @"123a";
    ASSERT_EQ([string2 integerValue], 123);

    NSString* string3 = @"-123a";
    ASSERT_EQ([string3 integerValue], -123);

    NSString* string4 = @"a123";
    ASSERT_EQ([string4 integerValue], 0);

    NSString* string5 = @"+123";
    ASSERT_EQ([string5 integerValue], 123);

    NSString* string6 = @"++123";
    ASSERT_EQ([string6 integerValue], 0);

    NSString* string7 = @"-123";
    ASSERT_EQ([string7 integerValue], -123);

    NSString* string8 = @"--123";
    ASSERT_EQ([string8 integerValue], 0);

    NSString* string9 = @"999999999999999999999999999999";
    ASSERT_EQ([string9 integerValue], LONG_MAX);

    NSString* string10 = @"-999999999999999999999999999999";
    ASSERT_EQ([string10 integerValue], LONG_MIN);
}

TEST(NSString, IntValue) {
    NSString* string1 = @"123";
    ASSERT_EQ([string1 intValue], 123);

    NSString* string2 = @"123a";
    ASSERT_EQ([string2 intValue], 123);

    NSString* string3 = @"-123a";
    ASSERT_EQ([string3 intValue], -123);

    NSString* string4 = @"a123";
    ASSERT_EQ([string4 intValue], 0);

    NSString* string5 = @"+123";
    ASSERT_EQ([string5 intValue], 123);

    NSString* string6 = @"++123";
    ASSERT_EQ([string6 intValue], 0);

    NSString* string7 = @"-123";
    ASSERT_EQ([string7 intValue], -123);

    NSString* string8 = @"--123";
    ASSERT_EQ([string8 intValue], 0);

    NSString* string9 = @"999999999999999999999999999999";
    ASSERT_EQ([string9 intValue], INT_MAX);

    NSString* string10 = @"-999999999999999999999999999999";
    ASSERT_EQ([string10 intValue], INT_MIN);
}

TEST(NSString, IsEqualToStringWithSwiftString) {
    NSString* string = @"literal";
    auto swiftString = @"literal";
    ASSERT_TRUE([string isEqualToString:swiftString]);
}

TEST(NSString, IsEqualToObjectWithNSString) {
    NSString* string1 = @"literal";
    NSString* string2 = @"literal";
    ASSERT_TRUE([string1 isEqual:string2]);
}

TEST(NSString, IsNotEqualToObjectWithNSNumber) {
    NSString* string = @"5";
    NSNumber* number = [NSNumber numberWithInt:5];
    ASSERT_FALSE([string isEqual:number]);
}

static const unsigned char mockASCIIStringBytes[] = { 0x48, 0x65, 0x6C, 0x6C, 0x6F, 0x20, 0x53, 0x77, 0x69, 0x66, 0x74, 0x21 };
static NSString* mockASCIIString = @"Hello Swift!";
static const unsigned char mockUTF8StringBytes[] = { 0x49, 0x20, 0xE2, 0x9D, 0xA4, 0xEF, 0xB8, 0x8F, 0x20, 0x53, 0x77, 0x69, 0x66, 0x74 };
static NSString* mockUTF8String = @"I ❤️ Swift";
static const unsigned char mockMalformedUTF8StringBytes[] = { 0xFF };

TEST(NSString, FromASCIIData) {
    auto bytes = mockASCIIStringBytes;
    NSString* string =
        [[[NSString alloc] initWithBytes:bytes length:sizeof(mockASCIIStringBytes) encoding:NSASCIIStringEncoding] autorelease];
    ASSERT_OBJCNE(nil, string);
    ASSERT_OBJCEQ(mockASCIIString, string);
}

TEST(NSString, FromUTF8Data) {
    auto bytes = mockUTF8StringBytes;
    NSString* string =
        [[[NSString alloc] initWithBytes:bytes length:sizeof(mockUTF8StringBytes) encoding:NSUTF8StringEncoding] autorelease];
    ASSERT_OBJCNE(nil, string);
    ASSERT_OBJCEQ(mockUTF8String, string);
}

TEST(NSString, FromMalformedUTF8Data) {
    auto bytes = mockMalformedUTF8StringBytes;
    NSString* string =
        [[[NSString alloc] initWithBytes:bytes length:sizeof(mockMalformedUTF8StringBytes) encoding:NSUTF8StringEncoding] autorelease];
    ASSERT_OBJCEQ(nil, string);
}

TEST(NSString, FromASCIINSData) {
    auto bytes = mockASCIIStringBytes;
    NSData* data = [NSData dataWithBytes:bytes length:sizeof(mockASCIIStringBytes)];
    NSString* string = [[[NSString alloc] initWithBytes:[data bytes] length:[data length] encoding:NSASCIIStringEncoding] autorelease];
    ASSERT_OBJCNE(nil, string);
    ASSERT_OBJCEQ(mockASCIIString, string);
}

TEST(NSString, FromUTF8NSData) {
    auto bytes = mockUTF8StringBytes;
    NSData* data = [NSData dataWithBytes:bytes length:sizeof(mockUTF8StringBytes)];
    NSString* string = [[[NSString alloc] initWithBytes:[data bytes] length:[data length] encoding:NSUTF8StringEncoding] autorelease];
    ASSERT_OBJCNE(nil, string);
    ASSERT_OBJCEQ(mockUTF8String, string);
}

TEST(NSString, FromMalformedUTF8NSData) {
    auto bytes = mockMalformedUTF8StringBytes;
    NSData* data = [NSData dataWithBytes:bytes length:sizeof(mockMalformedUTF8StringBytes)];
    NSString* string = [[[NSString alloc] initWithBytes:[data bytes] length:[data length] encoding:NSUTF8StringEncoding] autorelease];
    ASSERT_OBJCEQ(string, nil);
}

static const unsigned char nullBytes[] = { 0x00 };

TEST(NSString, FromNullTerminatedCStringInASCII) {
    auto bytes = mockASCIIStringBytes;
    NSMutableData* data = [NSMutableData dataWithBytes:bytes length:sizeof(mockASCIIStringBytes)];
    [data appendBytes:nullBytes length:sizeof(nullBytes)];
    NSString* string = [NSString stringWithCString:static_cast<const char*>([data bytes]) encoding:NSASCIIStringEncoding];
    ASSERT_OBJCNE(nil, string);
    ASSERT_TRUE([string isEqualToString:mockASCIIString]);
}

TEST(NSString, FromNullTerminatedCStringInUTF8) {
    auto bytes = mockUTF8StringBytes;
    NSMutableData* data = [NSMutableData dataWithBytes:bytes length:sizeof(mockUTF8StringBytes)];
    [data appendBytes:nullBytes length:sizeof(nullBytes)];
    NSString* string = [NSString stringWithCString:static_cast<const char*>([data bytes]) encoding:NSUTF8StringEncoding];
    ASSERT_OBJCNE(nil, string);
    ASSERT_TRUE([string isEqualToString:mockUTF8String]);
}

TEST(NSString, FromMalformedNullTerminatedCStringInUTF8) {
    auto bytes = mockMalformedUTF8StringBytes;
    NSMutableData* data = [NSMutableData dataWithBytes:bytes length:sizeof(mockMalformedUTF8StringBytes)];
    [data appendBytes:nullBytes length:sizeof(nullBytes)];
    NSString* string = [NSString stringWithCString:static_cast<const char*>([data bytes]) encoding:NSUTF8StringEncoding];
    ASSERT_OBJCEQ(string, nil);
}

TEST(NSString, FromContentsOfURL) {
    NSURL* testFileURL = [[NSBundle mainBundle] URLForResource:@"NSStringTestData" withExtension:@"txt"];
    ASSERT_OBJCNE_MSG(nil, testFileURL, "URL for NSStringTestData.txt is nil");

    NSString* string;
    NSError* error = nil;
    ASSERT_NO_THROW_MSG(string = [NSString stringWithContentsOfURL:testFileURL encoding:NSUTF8StringEncoding error:&error],
                        "Unable to init NSString from contentsOfURL:encoding:");
    ASSERT_OBJCEQ(error, nil);
    ASSERT_OBJCEQ(string, @"swift-corelibs-foundation");

    ASSERT_NO_THROW_MSG(string = [NSString stringWithContentsOfURL:testFileURL encoding:NSUTF16StringEncoding error:&error],
                        "Unable to init NSString from contentsOfURL:encoding:");
    ASSERT_OBJCEQ(error, nil);
    ASSERT_OBJCNE_MSG(string,
                      @"swift-corelibs-foundation",
                      @"Wrong result when reading UTF-8 file with UTF-16 encoding in contentsOfURL:encoding");
}

TEST(NSString, FromContentOfFile) {
    NSString* testFilePath = [[NSBundle mainBundle] pathForResource:@"NSStringTestData" ofType:@"txt"];
    ASSERT_OBJCNE(nil, testFilePath);

    NSString* str;
    NSError* error = nil;
    ASSERT_NO_THROW_MSG(str = [NSString stringWithContentsOfFile:testFilePath encoding:NSUTF8StringEncoding error:&error],
                        @"Unable to init NSString from contentsOfFile:encoding:");
    ASSERT_OBJCEQ(error, nil);
    ASSERT_OBJCEQ(str, @"swift-corelibs-foundation");
}

TEST(NSString, UppercaseString) {
    ASSERT_OBJCEQ(@"abcd".uppercaseString, @"ABCD");
    ASSERT_OBJCEQ(@"ａｂｃｄ".uppercaseString, @"ＡＢＣＤ"); // full-width;
    ASSERT_OBJCEQ(@"абВГ".uppercaseString, @"АБВГ");
    ASSERT_OBJCEQ(@"たちつてと".uppercaseString, @"たちつてと");

    ASSERT_OBJCEQ(@"\u00df".uppercaseString, @"\u0053\u0053");
    ASSERT_OBJCEQ(@"\ufb01".uppercaseString, @"\u0046\u0049");
}

TEST(NSString, UppercaseStringWithLocale) {
    // Special casing (see swift/validation-tests/stdlib/NSStringAPI.swift)
    ASSERT_OBJCEQ([@"\u0069" uppercaseStringWithLocale:[NSLocale localeWithLocaleIdentifier:@"en"]], @"\u0049");
    // Currently fails; likely there are locale loading issues that are preventing this from functioning correctly
    ASSERT_OBJCEQ([@"\u0069" uppercaseStringWithLocale:[NSLocale localeWithLocaleIdentifier:@"tr"]], @"\u0130");
}

TEST(NSString, LowercaseString) {
    ASSERT_OBJCEQ(@"abCD".lowercaseString, @"abcd");
    ASSERT_OBJCEQ(@"ＡＢＣＤ".lowercaseString, @"ａｂｃｄ"); // full-width;
    ASSERT_OBJCEQ(@"aБВГ".lowercaseString, @"aбвг");
    ASSERT_OBJCEQ(@"たちつてと".lowercaseString, @"たちつてと");
}

TEST(NSString, LowercaseStringWithLocale) {
    // Special casing (see swift/validation-tests/stdlib/NSStringAPI.swift)
    ASSERT_OBJCEQ([@"\u0130" lowercaseStringWithLocale:[NSLocale localeWithLocaleIdentifier:@"en"]], @"\u0069\u0307");
    // Currently fails; likely there are locale loading issues that are preventing this from functioning correctly
    ASSERT_OBJCEQ([@"\u0130" lowercaseStringWithLocale:[NSLocale localeWithLocaleIdentifier:@"tr"]], @"\u0069");
    ASSERT_OBJCEQ([@"\u0049\u0307" lowercaseStringWithLocale:[NSLocale localeWithLocaleIdentifier:@"en"]], @"\u0069\u0307");
    // Currently fails; likely there are locale loading issues that are preventing this from functioning correctly
    ASSERT_OBJCEQ([@"\u0049\u0307" lowercaseStringWithLocale:[NSLocale localeWithLocaleIdentifier:@"tr"]], @"\u0069");
}

TEST(NSString, CapitalizedString) {
    ASSERT_OBJCEQ([@"foo Foo fOO FOO" capitalizedString], @"Foo Foo Foo Foo");
    ASSERT_OBJCEQ([@"жжж" capitalizedString], @"Жжж");
}

TEST(NSString, LongLongValue) {
    NSString* string1 = @"123";
    ASSERT_EQ(string1.longLongValue, 123);

    NSString* string2 = @"123a";
    ASSERT_EQ(string2.longLongValue, 123);

    NSString* string3 = @"-123a";
    ASSERT_EQ(string3.longLongValue, -123);

    NSString* string4 = @"a123";
    ASSERT_EQ(string4.longLongValue, 0);

    NSString* string5 = @"+123";
    ASSERT_EQ(string5.longLongValue, 123);

    NSString* string6 = @"++123";
    ASSERT_EQ(string6.longLongValue, 0);

    NSString* string7 = @"-123";
    ASSERT_EQ(string7.longLongValue, -123);

    NSString* string8 = @"--123";
    ASSERT_EQ(string8.longLongValue, 0);

    NSString* string9 = @"999999999999999999999999999999";
    ASSERT_EQ(string9.longLongValue, LLONG_MAX);

    NSString* string10 = @"-999999999999999999999999999999";
    ASSERT_EQ(string10.longLongValue, LLONG_MIN);
}

TEST(NSString, RangeOfCharacterFromSet) {
    NSString* string = @"0Az";
    auto letters = [NSCharacterSet letterCharacterSet];
    auto decimalDigits = [NSCharacterSet decimalDigitCharacterSet];
    ASSERT_EQ([string rangeOfCharacterFromSet:letters].location, 1);
    ASSERT_EQ([string rangeOfCharacterFromSet:decimalDigits].location, 0);
    ASSERT_EQ([string rangeOfCharacterFromSet:letters options:NSBackwardsSearch].location, 2);
    ASSERT_EQ([string rangeOfCharacterFromSet:letters options:0 range:NSMakeRange(2, 1)].location, 2);
}

TEST(NSString, CFStringCreateMutableCopy) {
    NSString* nsstring = @"абВГ";
    auto mCopy = CFStringCreateMutableCopy(kCFAllocatorSystemDefault, 0, static_cast<CFStringRef>(nsstring));
    auto str = static_cast<NSString*>(mCopy);
    ASSERT_OBJCEQ(nsstring, str);
}

// This test verifies that CFStringGetBytes with a UTF16 encoding works on an NSString backed by a Swift string
TEST(NSString, SwiftStringUTF16) {
    auto testString = @"hello world";
    NSString* string = [NSString stringWithString:testString];
    auto cfString = static_cast<CFStringRef>(string);

    // Get the bytes as UTF16
    auto reservedLength = 50;
    std::vector<uint8_t> buf(reservedLength);
    CFIndex usedLen = 0;
    CFStringGetBytes(
        cfString, CFRangeMake(0, CFStringGetLength(cfString)), kCFStringEncodingUTF16, 0, false, &buf[0], reservedLength, &usedLen);

    // Make a new string out of it
    auto newCFString = CFStringCreateWithBytes(nullptr, &buf[0], usedLen, kCFStringEncodingUTF16, false);
    auto newString = static_cast<NSString*>(newCFString);

    ASSERT_TRUE([newString isEqualToString:testString]);
}

NSString* tmpPath(NSString* path) {
    return [NSString stringWithFormat:@"/tmp/%@", path];
}

BOOL startWith(NSString* prefix, NSArray* strings) {
    for (NSString* item in strings) {
        if (![item hasPrefix:prefix]) {
            return false;
        }
    }

    return true;
}

BOOL stringsAreCaseInsensitivelyEqual(NSString* lhs, NSString* rhs) {
    return [lhs compare:rhs options:NSCaseInsensitiveSearch] == NSOrderedSame;
}

// TODO 7292268: Re-enable this test when NSFileManager correctly interoperates with
// NSURL. Right now any NSURL created as a local file URL i.e. file://localhost/... will
// fail when looking up its path. This makes this test obviously fail and the string code
// untested.
DISABLED_TEST(NSString, CompletePathIntoString) {
    auto fileNames = @[
        @"/tmp/Test_completePathIntoString_01",
        @"/tmp/test_completePathIntoString_02",
        @"/tmp/test_completePathIntoString_01.txt",
        @"/tmp/test_completePathIntoString_01.dat",
        @"/tmp/test_completePathIntoString_03.DAT"
    ];

    ASSERT_TRUE_MSG(ensureFiles(fileNames), @"Could not create temp files for testing.");

    {
        NSString* path = tmpPath(@"");
        NSString* outName;
        NSArray* matches = [[NSArray new] autorelease];
        NSUInteger numMatches = [path completePathIntoString:&outName caseSensitive:false matchesIntoArray:&matches filterTypes:nil];
        NSError* error = nil;
        ASSERT_NO_THROW([[NSFileManager defaultManager] contentsOfDirectoryAtURL:[NSURL URLWithString:path]
                                                      includingPropertiesForKeys:nil
                                                                         options:static_cast<NSDirectoryEnumerationOptions>(0)
                                                                           error:&error]);
        ASSERT_OBJCEQ(nil, error);

        ASSERT_OBJCEQ_MSG(outName, @"/", @"If NSString is valid path to directory which has '/' suffix then outName is '/'.");
        // This assert fails on CI; https://bugs.swift.org/browse/SR-389
        //            ASSERT_TRUE_MSG(matches.count == content.count && matches.count == count, @"If NSString is valid path to directory
        //            then
        //            matches contain all content of directory. expected \(content) but got \(matches)")
    }

    {
        NSString* path = @"/tmp";
        NSString* outName;
        NSArray* matches = [[NSArray new] autorelease];
        NSUInteger numMatches = [path completePathIntoString:&outName caseSensitive:false matchesIntoArray:&matches filterTypes:nil];
        // WINOBJC: /private/tmp doesn't exist // auto urlToTmp = [[[NSURL alloc] initFileURLWithPath:@"/private/tmp/"]
        // autorelease].URLByStandardizingPath;
        auto urlToTmp = [[[NSURL alloc] initFileURLWithPath:@"/tmp/"] autorelease].URLByStandardizingPath;
        NSError* error;
        ASSERT_NO_THROW([[NSFileManager defaultManager] contentsOfDirectoryAtURL:urlToTmp
                                                      includingPropertiesForKeys:nil
                                                                         options:static_cast<NSDirectoryEnumerationOptions>(0)
                                                                           error:&error]);
        ASSERT_OBJCEQ(nil, error);
        ASSERT_OBJCEQ_MSG(outName, @"/tmp/", @"If path could be completed to existing directory then outName is a string itself plus '/'.");
        // This assert fails on CI; https://bugs.swift.org/browse/SR-389
        //            ASSERT_TRUE_MSG(matches.count == content.count && matches.count == count, @"If NSString is valid path to directory
        //            then
        //            matches contain all content of directory. expected \(content) but got \(matches)")
    }

    auto fileNames2 = @[ @"/tmp/ABC/", @"/tmp/ABCD/", @"/tmp/abcde" ];
    ASSERT_TRUE_MSG(ensureFiles(fileNames2), @"Could not create temp files for testing.");

    {
        NSString* path = tmpPath(@"ABC");
        NSString* outName;
        NSArray* matches = [[NSArray new] autorelease];
        auto count = [path completePathIntoString:&outName caseSensitive:false matchesIntoArray:&matches filterTypes:nil];
        ASSERT_TRUE_MSG(stringsAreCaseInsensitivelyEqual(outName, path),
                        @"If NSString is valid path to directory then outName is string itself.");
        ASSERT_TRUE_MSG(matches.count == count && count == fileNames2.count, @"");
    }

    {
        NSString* path = tmpPath(@"Test_completePathIntoString_01");
        NSString* outName;
        NSArray* matches = [[NSArray new] autorelease];
        auto count = [path completePathIntoString:&outName caseSensitive:true matchesIntoArray:&matches filterTypes:nil];
        ASSERT_TRUE_MSG(outName == path, @"If NSString is valid path to file and search is case sensitive then outName is string itself.");
        ASSERT_TRUE_MSG(matches.count == 1 && count == 1 && stringsAreCaseInsensitivelyEqual(matches[0], path),
                        @"If NSString is valid path to file and search is case sensitive then matches contain that file path only");
    }

    {
        NSString* path = tmpPath(@"Test_completePathIntoString_01");
        NSString* outName;
        NSArray* matches = [[NSArray new] autorelease];
        auto count = [path completePathIntoString:&outName caseSensitive:false matchesIntoArray:&matches filterTypes:nil];
        ASSERT_TRUE_MSG(stringsAreCaseInsensitivelyEqual(outName, path),
                        @"If NSString is valid path to file and search is case insensitive then outName is string equal to self.");
        ASSERT_TRUE_MSG(matches.count == 3 && count == 3, @"Matches contain all files with similar name.");
    }

    {
        auto path = tmpPath([[NSUUID UUID] UUIDString]);
        NSString* outName;
        NSArray* matches = [[NSArray new] autorelease];
        auto count = [path completePathIntoString:&outName caseSensitive:false matchesIntoArray:&matches filterTypes:nil];
        ASSERT_TRUE_MSG(outName == nil, @"If no matches found then outName is nil.");
        ASSERT_TRUE_MSG(matches.count == 0 && count == 0, @"If no matches found then return 0 and matches is empty.");
    }

    {
        NSString* path = @"";
        NSString* outName;
        NSArray* matches = [[NSArray new] autorelease];
        auto count = [path completePathIntoString:&outName caseSensitive:false matchesIntoArray:&matches filterTypes:nil];
        ASSERT_TRUE_MSG(outName == nil, @"If no matches found then outName is nil.");
        ASSERT_TRUE_MSG(matches.count == 0 && count == 0, @"If no matches found then return 0 and matches is empty.");
    }

    {
        NSString* path = tmpPath(@"test_c");
        NSString* outName;
        NSArray* matches = [[NSArray new] autorelease];
        // case insensetive
        auto count = [path completePathIntoString:&outName caseSensitive:false matchesIntoArray:&matches filterTypes:nil];
        ASSERT_TRUE_MSG(stringsAreCaseInsensitivelyEqual(outName, tmpPath(@"Test_completePathIntoString_0")),
                        @"If there are matches then outName should be longest common prefix of all matches.");
        ASSERT_TRUE_MSG(matches.count == fileNames.count && count == fileNames.count,
                        @"If there are matches then matches array contains them.");
    }

    {
        NSString* path = tmpPath(@"test_c");
        NSString* outName;
        NSArray* matches = [[NSArray new] autorelease];
        // case sensetive
        auto count = [path completePathIntoString:&outName caseSensitive:true matchesIntoArray:&matches filterTypes:nil];
        ASSERT_TRUE_MSG(outName == tmpPath(@"test_completePathIntoString_0"),
                        @"If there are matches then outName should be longest common prefix of all matches.");
        ASSERT_TRUE_MSG(matches.count == 4 && count == 4, @"Supports case sensetive search");
    }

    {
        NSString* path = tmpPath(@"test_c");
        NSString* outName;
        NSArray* matches = [[NSArray new] autorelease];
        // case sensetive
        auto count = [path completePathIntoString:&outName caseSensitive:true matchesIntoArray:&matches filterTypes:@[ @"DAT" ]];
        ASSERT_TRUE_MSG(outName == tmpPath(@"test_completePathIntoString_03.DAT"),
                        @"If there are matches then outName should be longest common prefix of all matches.");
        ASSERT_TRUE_MSG(matches.count == 1 && count == 1, @"Supports case sensetive search by extensions");
    }

    {
        NSString* path = tmpPath(@"test_c");
        NSString* outName;
        NSArray* matches = [[NSArray new] autorelease];
        // type by filter
        auto count = [path completePathIntoString:&outName caseSensitive:false matchesIntoArray:&matches filterTypes:@[ @"txt", @"dat" ]];
        ASSERT_TRUE_MSG(stringsAreCaseInsensitivelyEqual(outName, tmpPath(@"test_completePathIntoString_0")),
                        @"If there are matches then outName should be longest common prefix of all matches.");
        ASSERT_TRUE_MSG(matches.count == 3 && count == 3, @"Supports filtration by type");
    }

    {
        // will be resolved against current working directory that is directory there results of build process are stored
        NSString* path = @"TestFoundation";
        NSString* outName;
        NSArray* matches = [[NSArray new] autorelease];
        auto count = [path completePathIntoString:&outName caseSensitive:false matchesIntoArray:&matches filterTypes:nil];
        // Build directory at least contains executable itself and *.swiftmodule directory
        ASSERT_TRUE_MSG(matches.count == count && count >= 2, @"Supports relative paths.");
        ASSERT_TRUE_MSG(startWith(path, matches), @"For relative paths matches are relative too.");
    }

// Next check has no sense on Linux due to case sensitive file system.
#if 0 // WINOBJC: never true // #if os(OSX)
    guard ensureFiles([@"/tmp/ABC/temp.txt"]) else {
        ASSERT_TRUE_MSG(false, @"Could not create temp files for testing.");
        return;
    }

    {
        NSString* path = tmpPath(@"aBc/t");
        NSString* outName;
        NSArray* matches = [[NSArray new] autorelease];
        // type by filter
        auto count = [path completePathIntoString:&outName caseSensitive:true matchesIntoArray:&matches filterTypes:@[ @"txt", @"dat" ]];
        ASSERT_TRUE_MSG(outName == tmpPath(@"aBc/temp.txt"), @"outName starts with receiver.");
        ASSERT_TRUE_MSG(matches.count >= 1 && count >= 1, @"There are matches");
    }
#endif
}

TEST(NSString, StringByTrimmingCharactersInSet) {
    auto characterSet = [NSCharacterSet whitespaceCharacterSet];
    NSString* string = @" abc   ";
    ASSERT_OBJCEQ([string stringByTrimmingCharactersInSet:characterSet], @"abc");
}

TEST(NSString, InitializeWithFormat) {
    int arg1 = 42;
    float arg2 = 42.0f;
    NSString* string = [NSString stringWithFormat:@"Value is %d (%.1f)", arg1, arg2];
    ASSERT_OBJCEQ(string, @"Value is 42 (42.0)");
}

TEST(NSString, InitializeWithFormat2) {
    uint8_t argument = 75;
    NSString* string = [NSString stringWithFormat:@"%02X", argument];
    ASSERT_OBJCEQ(string, @"4B");
}

TEST(NSString, StringByDeletingLastPathComponent) {
    {
        NSString* path = @"/tmp/scratch.tiff";
        auto result = path.stringByDeletingLastPathComponent;
        ASSERT_OBJCEQ(result, @"/tmp");
    }

    {
        NSString* path = @"/tmp/lock/";
        auto result = path.stringByDeletingLastPathComponent;
        ASSERT_OBJCEQ(result, @"/tmp");
    }

    {
        NSString* path = @"/tmp/";
        auto result = path.stringByDeletingLastPathComponent;
        ASSERT_OBJCEQ(result, @"/");
    }

    {
        NSString* path = @"/tmp";
        auto result = path.stringByDeletingLastPathComponent;
        ASSERT_OBJCEQ(result, @"/");
    }

    {
        NSString* path = @"/";
        auto result = path.stringByDeletingLastPathComponent;
        ASSERT_OBJCEQ(result, @"/");
    }

    {
        NSString* path = @"scratch.tiff";
        auto result = path.stringByDeletingLastPathComponent;
        ASSERT_OBJCEQ(result, @"");
    }

    {
        NSString* path = @"foo/bar";
        auto result = path.stringByDeletingLastPathComponent;
        ASSERT_OBJCEQ_MSG(result, @"foo", @"Relative path stays relative.");
    }
}

TEST(NSString, StringByResolvingSymlinksInPath) {
    {
        NSString* path = @"foo/bar";
        auto result = path.stringByResolvingSymlinksInPath;
        ASSERT_OBJCEQ_MSG(result,
                          @"foo/bar",
                          @"For relative paths, symbolic links that can’t be resolved are left unresolved in the returned string.");
    }

    {
        NSString* path = @"/tmp/..";
        auto result = path.stringByResolvingSymlinksInPath;

// #if below is from the original Swift tests - platform differences were already known
#if TARGET_OS_WIN32
        auto expected = @"/";
#else
        auto expected = @"/private";
#endif

        ASSERT_OBJCEQ_MSG(result, expected, @"For absolute paths, all symbolic links are guaranteed to be removed.");
    }

    {
        NSString* path = @"tmp/..";
        auto result = path.stringByResolvingSymlinksInPath;
        ASSERT_OBJCEQ_MSG(result, @"tmp/..", @"Parent links could be resolved for absolute paths only.");
    }

    {
        NSString* path = @"/tmp/";
        auto result = path.stringByResolvingSymlinksInPath;
        ASSERT_OBJCEQ_MSG(result, @"/tmp", @"Result doesn't contain trailing slash.");
    }

    {
        NSString* path = @"http://google.com/search/..";
        auto result = path.stringByResolvingSymlinksInPath;
        ASSERT_OBJCEQ_MSG(result, @"http:/google.com/search/..", @"stringByResolvingSymlinksInPath treats receiver as file path always");
    }

    {
        NSString* path = @"file:///tmp/..";
        auto result = path.stringByResolvingSymlinksInPath;
        ASSERT_OBJCEQ_MSG(result, @"file:/tmp/..", @"stringByResolvingSymlinksInPath treats receiver as file path always");
    }
}

TEST(NSString, GetCString_simple) {
    NSString* str = @"foo";
    char chars[] = { 0xF, 0xF, 0xF, 0xF };
    auto count = sizeof(chars);
    unsigned char expected[] = { 102, 111, 111, 0 };
    BOOL res = [str getCString:&chars[0] maxLength:count encoding:NSASCIIStringEncoding];
    ASSERT_TRUE_MSG(res, @"getCString should work on simple strings with ascii string encoding");

    for (unsigned int i = 0; i < count; i++) {
        ASSERT_EQ(chars[i], expected[i]);
    }
}

TEST(NSString, GetCString_nonASCII_withASCIIAccessor) {
    NSString* str = @"ƒoo";
    char chars[] = { 0xF, 0xF, 0xF, 0xF, 0xF };
    char expected[] = { -58, -110, 111, 111, 0 };
    auto count = sizeof(chars);
    BOOL res = [str getCString:chars maxLength:count encoding:NSASCIIStringEncoding];
    ASSERT_FALSE_MSG(res, @"getCString should not work on non ascii strings accessing as ascii string encoding");
    res = [str getCString:chars maxLength:count encoding:NSUTF8StringEncoding];

    ASSERT_TRUE_MSG(res, @"getCString should work on UTF8 encoding");
    for (unsigned int i = 0; i < count; i++) {
        ASSERT_EQ(chars[i], expected[i]);
    }
}

// TODO 7292268: Re-enable this test when NSHomeDirectory doesn't just return nil / NSHomeDirectoryForUser is implemented
DISABLED_TEST(NSString, NSHomeDirectoryForUser) {
    // TODO 7292268: method not implemented.  // NSString* homeDir = NSHomeDirectoryForUser(nil);
    NSString* homeDir = NSHomeDirectory();
    NSString* userName = NSUserName();
    // TODO 7292268: method not implemented. // NSString* homeDir2 = NSHomeDirectoryForUser(userName);
    NSString* homeDir2 = NSHomeDirectory();
    NSString* homeDir3 = NSHomeDirectory();
    ASSERT_TRUE_MSG(homeDir != nil && homeDir == homeDir2 && homeDir == homeDir3, @"Could get user' home directory");
}

// TODO 7292268: Re-enable this test when NSHomeDirectory doesn't just return nil
DISABLED_TEST(NSString, StringByExpandingTildeInPath) {
    {
        NSString* path = @"~";
        auto result = path.stringByExpandingTildeInPath;
        ASSERT_OBJCEQ_MSG(result, NSHomeDirectory(), @"Could resolve home directory for current user");
        ASSERT_FALSE_MSG([result hasSuffix:@"/"], @"Result have no trailing path separator");
    }

    {
        NSString* path = @"~/";
        auto result = path.stringByExpandingTildeInPath;
        ASSERT_OBJCEQ_MSG(result, NSHomeDirectory(), @"Could resolve home directory for current user");
        ASSERT_FALSE_MSG([result hasSuffix:@"/"], @"Result have no trailing path separator");
    }

    {
        NSString* path = [NSString stringWithFormat:@"~%@", NSUserName()];
        auto result = path.stringByExpandingTildeInPath;
        ASSERT_OBJCEQ_MSG(result, NSHomeDirectory(), @"Could resolve home directory for specific user");
        ASSERT_FALSE_MSG([result hasSuffix:@"/"], @"Result have no trailing path separator");
    }

    {
        auto userName = [[NSUUID new] autorelease].UUIDString;
        NSString* path = [NSString stringWithFormat:@"~%@/", userName];
        NSString* result = path.stringByExpandingTildeInPath;
        // next assert fails in VirtualBox because home directory for unknown user resolved to /var/run/vboxadd
        NSString* expected = [NSString stringWithFormat:@"~%@", userName];
        ASSERT_OBJCEQ_MSG(result, expected, @"Return copy of reciver if home directory could no be resolved.");
    }
}

// TODO 7292268: Re-enable this test when NSHomeDirectory works
DISABLED_TEST(NSString, StringByStandardizingPath) {
    // tmp is special because it is symlinked to /private/tmp and this /private prefix should be dropped,
    // so tmp is tmp. On Linux tmp is not symlinked so it would be the same.
    {
        NSString* path = @"/.//tmp/ABC/..";
        auto result = path.stringByStandardizingPath;
        ASSERT_OBJCEQ_MSG(result, @"/tmp", @"stringByStandardizingPath removes extraneous path components and resolve symlinks.");
    }

    {
        NSString* path = @"~";
        auto result = path.stringByStandardizingPath;
        NSString* expected = NSHomeDirectory();
        ASSERT_OBJCEQ_MSG(result, expected, @"stringByStandardizingPath expanding initial tilde.");
    }

    {
        NSString* path = @"~/foo/bar/";
        auto result = path.stringByStandardizingPath;
        NSString* expected = [NSHomeDirectory() stringByAppendingString:@"/foo/bar"];
        ASSERT_OBJCEQ_MSG(result, expected, @"stringByStandardizingPath expanding initial tilde.");
    }

    // relative file paths depend on file path standardizing that is not yet implemented
    {
        NSString* path = @"foo/bar";
        auto result = path.stringByStandardizingPath;
        ASSERT_OBJCEQ_MSG(result, path, @"stringByStandardizingPath doesn't resolve relative paths");
    }

// tmp is symlinked on OS X only
#if 0 // WINOBJC: never true. // #if os(OSX)
    {
        NSString* path = @"/tmp/..";
        auto result = path.stringByStandardizingPath;
        ASSERT_OBJCEQ(result, @"/private");
    }
#endif

    {
        NSString* path = @"/tmp/ABC/..";
        auto result = path.stringByStandardizingPath;
        ASSERT_OBJCEQ_MSG(result, @"/tmp", @"parent links could be resolved for absolute paths");
    }

    {
        NSString* path = @"tmp/ABC/..";
        auto result = path.stringByStandardizingPath;
        ASSERT_OBJCEQ_MSG(result, path, @"parent links could not be resolved for relative paths");
    }
}

TEST(NSString, StringByRemovingPercentEncoding) {
    auto s1 = @"a%20b".stringByRemovingPercentEncoding;
    ASSERT_OBJCEQ(s1, @"a b");
    auto s2 = @"a%1 b".stringByRemovingPercentEncoding;
    ASSERT_OBJCEQ_MSG(s2, nil, @"returns nil for a string with an invalid percent encoding");
}

TEST(NSString, StringByAppendingPathExtension) {
    NSDictionary* values = @{
        @"/tmp/scratch.old" : @"/tmp/scratch.old.tiff",
        @"/tmp/scratch." : @"/tmp/scratch..tiff",
        @"/tmp/" : @"/tmp.tiff",
        @"/scratch" : @"/scratch.tiff",
        @"/~scratch" : @"/~scratch.tiff",
        @"scratch" : @"scratch.tiff",
    };

    for (id fileName in values) {
        NSString* expectedResult = [values objectForKey:fileName];
        auto result = [fileName stringByAppendingPathExtension:@"tiff"];
        ASSERT_OBJCEQ(result, expectedResult);
    }
}

TEST(NSString, StringByDeletingPathExtension) {
    NSDictionary* values = @{
        [NSString stringWithString:@"/tmp/scratch.tiff"] : @"/tmp/scratch",
        [NSString stringWithString:@"/tmp/"] : @"/tmp",
        [NSString stringWithString:@"scratch.bundle"] : @"scratch",
        [NSString stringWithString:@"scratch..tiff"] : @"scratch.",
        [NSString stringWithString:@".tiff"] : @".tiff",
        [NSString stringWithString:@"/"] : @"/",
    };
    for (NSString* fileName in values) {
        NSString* expectedResult = [values objectForKey:fileName];
        auto result = fileName.stringByDeletingPathExtension;
        ASSERT_OBJCEQ(result, expectedResult);
    }
}

TEST(NSString, ExternalRepresentation) {
    // Ensure NSString can be used to create an external data representation

    auto UTF8Encoding = CFStringEncoding(kCFStringEncodingUTF8);
    auto UTF16Encoding = CFStringEncoding(kCFStringEncodingUTF16);
    auto ISOLatin1Encoding = CFStringEncoding(kCFStringEncodingISOLatin1);

    {
        auto string =
            static_cast<CFStringRef>([NSString stringWithString:@"this is an external string that should be representable by data"]);
        auto UTF8Data = CFStringCreateExternalRepresentation(kCFAllocatorDefault, string, UTF8Encoding, 0);
        NSUInteger UTF8Length = CFDataGetLength(UTF8Data);
        ASSERT_EQ(UTF8Length, 63);

        auto UTF16Data = CFStringCreateExternalRepresentation(kCFAllocatorDefault, string, UTF16Encoding, 0);
        NSUInteger UTF16Length = CFDataGetLength(UTF16Data);
        ASSERT_EQ(UTF16Length, 128);

        auto ISOLatin1Data = CFStringCreateExternalRepresentation(kCFAllocatorDefault, string, ISOLatin1Encoding, 0);
        NSUInteger ISOLatin1Length = CFDataGetLength(ISOLatin1Data);
        ASSERT_EQ(ISOLatin1Length, 63);
    }

    {
        auto string = static_cast<CFStringRef>([NSString stringWithString:@"🐢 encoding all the way down. 🐢🐢🐢"]);
        auto UTF8Data = CFStringCreateExternalRepresentation(kCFAllocatorDefault, string, UTF8Encoding, 0);
        NSUInteger UTF8Length = CFDataGetLength(UTF8Data);
        ASSERT_EQ(UTF8Length, 44);

        auto UTF16Data = CFStringCreateExternalRepresentation(kCFAllocatorDefault, string, UTF16Encoding, 0);
        NSUInteger UTF16Length = CFDataGetLength(UTF16Data);
        ASSERT_EQ(UTF16Length, 74);

        auto ISOLatin1Data = static_cast<NSData*>(CFStringCreateExternalRepresentation(kCFAllocatorDefault, string, ISOLatin1Encoding, 0));
        ASSERT_OBJCEQ(ISOLatin1Data, nil);
    }
}

TEST(NSString, MutableStringConstructor) {
    NSMutableString* mutableString = [NSMutableString stringWithString:@"Test"];
    ASSERT_OBJCEQ(mutableString, @"Test");
}

static void checkHasPrefixHasSuffix(NSString* lhs, NSString* rhs, Boolean expectHasPrefix, Boolean expectHasSuffix) {
    if ([lhs isEqual:@""]) {
        ASSERT_FALSE([lhs hasPrefix:rhs]);
        ASSERT_FALSE([lhs hasSuffix:rhs]);
        return;
    }
    if ([rhs isEqual:@""]) {
        ASSERT_FALSE([lhs hasPrefix:rhs]);
        ASSERT_FALSE([lhs hasSuffix:rhs]);
        return;
    }

    // WINOBJC: normalizing the strings messes with the expected value from the reference platform.
    // Instead, just check passed in expectation.
    // To determine the expected results, compare grapheme clusters,
    // scalar-to-scalar, of the NFD form of the strings.
    // NSString* lhsNFDGraphemeClusters = lhs.decomposedStringWithCanonicalMapping;
    // NSString* rhsNFDGraphemeClusters = rhs.decomposedStringWithCanonicalMapping;

    // bool expectHasPrefix = ([lhsNFDGraphemeClusters length] >= [rhsNFDGraphemeClusters length]);
    // for (unsigned int i = 0; expectHasPrefix && i < [rhsNFDGraphemeClusters length]; i++) {
    //     expectHasPrefix &= ([lhsNFDGraphemeClusters characterAtIndex:i] == [rhsNFDGraphemeClusters characterAtIndex:i]);
    // }

    // bool expectHasSuffix = ([lhsNFDGraphemeClusters length] >= [rhsNFDGraphemeClusters length]);
    // for (unsigned int i = 1; expectHasSuffix && i <= [rhsNFDGraphemeClusters length]; i++) {
    //     expectHasSuffix &= ([lhsNFDGraphemeClusters characterAtIndex:([lhsNFDGraphemeClusters length] - i)] ==
    //                         [rhsNFDGraphemeClusters characterAtIndex:([rhsNFDGraphemeClusters length] - i)]);
    // }

    ASSERT_EQ_MSG(expectHasPrefix, [lhs hasPrefix:rhs], "%@ should have prefix of %@", lhs, rhs);
    ASSERT_EQ_MSG(expectHasSuffix, [lhs hasSuffix:rhs], "%@ should have suffix of %@", lhs, rhs);
}

class ComparisonTests : public ::testing::TestWithParam<::testing::tuple<NSString*,
                                                                         NSString*,
                                                                         Boolean,
                                                                         Boolean,
                                                                         Boolean,
                                                                         Boolean,
                                                                         Boolean,
                                                                         Boolean,
                                                                         Boolean,
                                                                         Boolean,
                                                                         Boolean,
                                                                         Boolean,
                                                                         Boolean,
                                                                         Boolean>> {
public:
    explicit ComparisonTests()
        : ::testing::TestWithParam<::testing::tuple<NSString*,
                                                    NSString*,
                                                    Boolean,
                                                    Boolean,
                                                    Boolean,
                                                    Boolean,
                                                    Boolean,
                                                    Boolean,
                                                    Boolean,
                                                    Boolean,
                                                    Boolean,
                                                    Boolean,
                                                    Boolean,
                                                    Boolean>>() {
    }

protected:
    virtual void SetUp() {
    }

    virtual void TearDown() {
    }
};

TEST_P(ComparisonTests, PrefixSuffix) {
    StrongId<NSString> lhs = ::testing::get<0>(GetParam());
    StrongId<NSString> rhs = ::testing::get<1>(GetParam());

    checkHasPrefixHasSuffix(lhs, rhs, ::testing::get<2>(GetParam()), ::testing::get<3>(GetParam()));
    checkHasPrefixHasSuffix(rhs, lhs, ::testing::get<4>(GetParam()), ::testing::get<5>(GetParam()));

    static NSString* fragment = @"abc";
    static NSString* combiner = @"\u0301";

    StrongId<NSMutableString> lhsWithFragment;
    lhsWithFragment.attach([lhs mutableCopy]);
    [lhsWithFragment appendString:fragment];

    StrongId<NSMutableString> fragmentWithLhs;
    fragmentWithLhs.attach([fragment mutableCopy]);
    [fragmentWithLhs appendString:lhs];

    StrongId<NSMutableString> lhsWithCombiner;
    lhsWithCombiner.attach([lhs mutableCopy]);
    [lhsWithCombiner appendString:combiner];

    StrongId<NSMutableString> combinerWithLhs;
    combinerWithLhs.attach([combiner mutableCopy]);
    [combinerWithLhs appendString:lhs];

    checkHasPrefixHasSuffix(lhsWithFragment, rhs, ::testing::get<6>(GetParam()), ::testing::get<7>(GetParam()));
    checkHasPrefixHasSuffix(fragmentWithLhs, rhs, ::testing::get<8>(GetParam()), ::testing::get<9>(GetParam()));
    checkHasPrefixHasSuffix(lhsWithCombiner, rhs, ::testing::get<10>(GetParam()), ::testing::get<11>(GetParam()));
    checkHasPrefixHasSuffix(combinerWithLhs, rhs, ::testing::get<12>(GetParam()), ::testing::get<13>(GetParam()));
}

INSTANTIATE_TEST_CASE_P(
    NSString,
    ComparisonTests,
    ::testing::Values(::testing::make_tuple(@"", @"", NO, NO, NO, NO, NO, NO, NO, NO, NO, NO, NO, NO),
                      ::testing::make_tuple(@"", @"a", NO, NO, NO, NO, YES, NO, YES, NO, NO, NO, NO, NO),

                      // ASCII cases
                      ::testing::make_tuple(@"t", @"tt", NO, NO, YES, YES, NO, NO, NO, NO, NO, NO, NO, NO),
                      ::testing::make_tuple(@"t", @"Tt", NO, NO, NO, YES, NO, NO, NO, NO, NO, NO, NO, NO),
                      ::testing::make_tuple(@"\u0000", @"", NO, NO, NO, NO, NO, NO, NO, NO, NO, NO, NO, NO),
                      ::testing::make_tuple(@"\u0000", @"\u0000", YES, YES, YES, YES, YES, NO, NO, YES, YES, NO, NO, YES),
                      ::testing::make_tuple(@"\r\n", @"t", NO, NO, NO, NO, NO, NO, NO, NO, NO, NO, NO, NO),
                      ::testing::make_tuple(@"\r\n", @"\n", NO, YES, NO, NO, NO, NO, NO, YES, NO, NO, NO, YES),

                      // Whitespace
                      // U+000A LINE FEED (LF)
                      // U+000B LINE TABULATION
                      // U+000C FORM FEED (FF)
                      // U+0085 NEXT LINE (NEL)
                      // U+2028 LINE SEPARATOR
                      // U+2029 PARAGRAPH SEPARATOR
                      ::testing::make_tuple(@"\u0085", @"\n", NO, NO, NO, NO, NO, NO, NO, NO, NO, NO, NO, NO),
                      ::testing::make_tuple(@"\u000b", @"\n", NO, NO, NO, NO, NO, NO, NO, NO, NO, NO, NO, NO),
                      ::testing::make_tuple(@"\u000c", @"\n", NO, NO, NO, NO, NO, NO, NO, NO, NO, NO, NO, NO),
                      ::testing::make_tuple(@"\u2028", @"\n", NO, NO, NO, NO, NO, NO, NO, NO, NO, NO, NO, NO),
                      ::testing::make_tuple(@"\u2029", @"\n", NO, NO, NO, NO, NO, NO, NO, NO, NO, NO, NO, NO),
                      ::testing::make_tuple(@"\r\n\r\n", @"\r\n", YES, YES, NO, NO, YES, NO, NO, YES, YES, NO, NO, YES),

                      // U+0301 COMBINING ACUTE ACCENT
                      // U+00E1 LATIN SMALL LETTER A WITH ACUTE
                      ::testing::make_tuple(@"a\u0301", @"\u00e1", NO, NO, NO, NO, NO, NO, NO, NO, NO, NO, NO, NO),
                      ::testing::make_tuple(@"a", @"a\u0301", NO, NO, YES, NO, NO, NO, NO, NO, YES, YES, NO, NO),
                      ::testing::make_tuple(@"a", @"\u00e1", NO, NO, NO, NO, NO, NO, NO, NO, NO, NO, NO, NO),

                      // U+304B HIRAGANA LETTER KA
                      // U+304C HIRAGANA LETTER GA
                      // U+3099 COMBINING KATAKANA-HIRAGANA VOICED SOUND MARK
                      ::testing::make_tuple(@"\u304b", @"\u304b", YES, YES, YES, YES, YES, NO, NO, YES, YES, NO, NO, YES),
                      ::testing::make_tuple(@"\u304c", @"\u304c", YES, YES, YES, YES, YES, NO, NO, YES, YES, NO, NO, YES),
                      ::testing::make_tuple(@"\u304b", @"\u304c", NO, NO, NO, NO, NO, NO, NO, NO, NO, NO, NO, NO),
                      ::testing::make_tuple(@"\u304b", @"\u304c\u3099", NO, NO, NO, NO, NO, NO, NO, NO, NO, NO, NO, NO),
                      ::testing::make_tuple(@"\u304c", @"\u304b\u3099", NO, NO, NO, NO, NO, NO, NO, NO, NO, NO, NO, NO),
                      ::testing::make_tuple(@"\u304c", @"\u304c\u3099", NO, NO, YES, NO, NO, NO, NO, NO, NO, NO, NO, NO),

                      // U+212B ANGSTROM SIGN
                      // U+030A COMBINING RING ABOVE
                      // U+00C5 LATIN CAPITAL LETTER A WITH RING ABOVE
                      ::testing::make_tuple(@"\u212b", @"A\u030a", NO, NO, NO, NO, NO, NO, NO, NO, NO, NO, NO, NO),
                      ::testing::make_tuple(@"\u212b", @"\u00c5", NO, NO, NO, NO, NO, NO, NO, NO, NO, NO, NO, NO),
                      ::testing::make_tuple(@"A\u030a", @"\u00c5", NO, NO, NO, NO, NO, NO, NO, NO, NO, NO, NO, NO),
                      ::testing::make_tuple(@"A\u030a", @"a", NO, NO, NO, NO, NO, NO, YES, NO, NO, NO, NO, NO),
                      ::testing::make_tuple(@"A", @"A\u030a", NO, NO, YES, NO, NO, NO, NO, NO, NO, NO, NO, NO),

                      // U+2126 OHM SIGN
                      // U+03A9 GREEK CAPITAL LETTER OMEGA
                      ::testing::make_tuple(@"\u2126", @"\u03a9", NO, NO, NO, NO, NO, NO, NO, NO, NO, NO, NO, NO),

                      // U+0323 COMBINING DOT BELOW
                      // U+0307 COMBINING DOT ABOVE
                      // U+1E63 LATIN SMALL LETTER S WITH DOT BELOW
                      // U+1E69 LATIN SMALL LETTER S WITH DOT BELOW AND DOT ABOVE
                      ::testing::make_tuple(@"\u1e69", @"s\u0323\u0307", NO, NO, NO, NO, NO, NO, NO, NO, NO, NO, NO, NO),
                      ::testing::make_tuple(@"\u1e69", @"s\u0307\u0323", NO, NO, NO, NO, NO, NO, NO, NO, NO, NO, NO, NO),
                      ::testing::make_tuple(@"\u1e69", @"\u1e63\u0307", NO, NO, NO, NO, NO, NO, NO, NO, NO, NO, NO, NO),
                      ::testing::make_tuple(@"\u1e63", @"s\u0323", NO, NO, NO, NO, NO, NO, NO, NO, NO, NO, NO, NO),
                      ::testing::make_tuple(@"\u1e63\u0307", @"s\u0323\u0307", NO, NO, NO, NO, NO, NO, NO, NO, NO, NO, NO, NO),
                      ::testing::make_tuple(@"\u1e63\u0307", @"s\u0307\u0323", NO, NO, NO, NO, NO, NO, NO, NO, NO, NO, NO, NO),
                      ::testing::make_tuple(@"s\u0323", @"\u1e69", NO, NO, NO, NO, NO, NO, NO, NO, NO, NO, NO, NO),

                      // U+FB01 LATIN SMALL LIGATURE FI
                      ::testing::make_tuple(@"\ufb01", @"\ufb01", YES, YES, YES, YES, YES, NO, NO, YES, YES, NO, NO, YES),
                      ::testing::make_tuple(@"fi", @"\ufb01", NO, NO, NO, NO, NO, NO, NO, NO, NO, NO, NO, NO),

                      // U+1F1E7 REGIONAL INDICATOR SYMBOL LETTER B
                      // \u1F1E7\u1F1E7 Flag of Barbados
                      ::testing::make_tuple(@"\u1F1E7", @"\u1F1E7\u1F1E7", NO, NO, YES, YES, NO, NO, NO, NO, NO, NO, NO, NO),

                      // Test that Unicode collation is performed in deterministic mode.
                      //
                      // U+0301 COMBINING ACUTE ACCENT
                      // U+0341 COMBINING ACUTE TONE MARK
                      // U+0954 DEVANAGARI ACUTE ACCENT
                      //
                      // Collation elements from DUCET:
                      // 0301  ; [.0000.0024.0002] # COMBINING ACUTE ACCENT
                      // 0341  ; [.0000.0024.0002] # COMBINING ACUTE TONE MARK
                      // 0954  ; [.0000.0024.0002] # DEVANAGARI ACUTE ACCENT
                      //
                      // U+0301 and U+0954 don't decompose in the canonical decomposition mapping.
                      // U+0341 has a canonical decomposition mapping of U+0301.
                      ::testing::make_tuple(@"\u0301", @"\u0341", NO, NO, NO, NO, NO, NO, NO, NO, NO, NO, NO, NO),
                      ::testing::make_tuple(@"\u0301", @"\u0954", NO, NO, NO, NO, NO, NO, NO, NO, NO, NO, NO, NO),
                      ::testing::make_tuple(@"\u0341", @"\u0954", NO, NO, NO, NO, NO, NO, NO, NO, NO, NO, NO, NO)));

// WINOBJC: No playground support for ObjC
/*
TEST(NSString, Reflection) {
    NSString* testString = @"some text here";

    auto ql = PlaygroundQuickLook(reflecting : testString);

    switch
        ql {
            case.text(let str):
                ASSERT_OBJCEQ(testString, str);
    default: ASSERT_TRUE_MSG(false, @"mismatched quicklook");
    }
*/
