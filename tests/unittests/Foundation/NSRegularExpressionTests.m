//******************************************************************************
//
// Copyright (c) 2015 Microsoft Corporation. All rights reserved.
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
#import <Starboard/SmartTypes.h>

TEST(NSRegularExpression, CaptureGroupReplacementTest) {
    NSString* result = [@"ab  cd e    spaces" stringByReplacingOccurrencesOfString:@"\\s+"
                                                                        withString:@"($0)"
                                                                           options:NSRegularExpressionSearch
                                                                             range:NSMakeRange(0, 18)];

    ASSERT_OBJCEQ(@"ab(  )cd( )e(    )spaces", result);

    result = [@"cat hat bat chunk" stringByReplacingOccurrencesOfString:@"(.)at"
                                                             withString:@"($1)runk"
                                                                options:NSRegularExpressionSearch
                                                                  range:NSMakeRange(0, 17)];

    ASSERT_OBJCEQ(@"(c)runk (h)runk (b)runk chunk", result);

    // Place escaped $ which could have been a capture group
    result = [@"I have x.yy dollars." stringByReplacingOccurrencesOfString:@"((x)\.(yy))"
                                                                withString:@"\\$1$2.$3"
                                                                   options:NSRegularExpressionSearch
                                                                     range:NSMakeRange(0, 20)];
    ASSERT_OBJCEQ(@"I have $1x.yy dollars.", result);

    // Don't stomp spaces after $ for capture groups
    result = [@"cat hat bat" stringByReplacingOccurrencesOfString:@"(.)at"
                                                       withString:@"$ 1$1"
                                                          options:NSRegularExpressionSearch
                                                            range:NSMakeRange(0, 11)];
    ASSERT_OBJCEQ(@"$ 1c $ 1h $ 1b", result);

    // Ignore hex
    result = [@"cat hat bat" stringByReplacingOccurrencesOfString:@"(.)at"
                                                       withString:@"$0x0"
                                                          options:NSRegularExpressionSearch
                                                            range:NSMakeRange(0, 11)];
    ASSERT_OBJCEQ(@"catx0 hatx0 batx0", result);

    result = [@"ネコ hat bat" stringByReplacingOccurrencesOfString:@"ネコ"
                                                          withString:@"Japanese四Cat"
                                                             options:NSRegularExpressionSearch
                                                               range:NSMakeRange(0, 10)];
    ASSERT_OBJCEQ(@"Japanese四Cat hat bat", result);

    result = [@"I like cats" stringByReplacingOccurrencesOfString:@"(.)at"
                                                       withString:@"$1ar"
                                                          options:NSRegularExpressionSearch
                                                            range:NSMakeRange(0, 11)];
    ASSERT_OBJCEQ(@"I like cars", result);
}

TEST(NSRegularExpression, ReplacementTests) {
    StrongId<NSRegularExpression> regex =
        [NSRegularExpression regularExpressionWithPattern:@"Bad" options:NSRegularExpressionCaseInsensitive error:NULL];

    StrongId<NSString> testString = @"Bad Match";
    NSRange range = { 0, [testString length] };

    StrongId<NSTextCheckingResult> firstMatch = [regex firstMatchInString:testString options:0 range:range];
    NSRange rangeresult = [firstMatch range];

    StrongId<NSString> replaced = [regex replacementStringForResult:firstMatch inString:testString offset:0 template:@"Good"];
    ASSERT_OBJCEQ(@"Good", replaced);

    replaced = [regex stringByReplacingMatchesInString:testString options:0 range:rangeresult withTemplate:@"Good"];

    ASSERT_OBJCEQ(@"Good Match", replaced);

    // We replaced "Bad" with "Good" so the offset is +1
    StrongId<NSTextCheckingResult> offsetFromReplacement = [firstMatch resultByAdjustingRangesWithOffset:1];

    rangeresult = [offsetFromReplacement range];
    ASSERT_EQ(rangeresult.location, 1);

    regex = [NSRegularExpression regularExpressionWithPattern:@"iOS" options:0 error:NULL];

    StrongId<NSMutableString> mutableTestString = [[@"iOS is amazing" mutableCopy] autorelease];
    NSUInteger matches = [regex replaceMatchesInString:mutableTestString
                                               options:NSMatchingWithTransparentBounds
                                                 range:{ 0, [mutableTestString length] }
                                          withTemplate:@"Windows"];

    ASSERT_OBJCEQ(@"Windows is amazing", mutableTestString);

    regex = [NSRegularExpression regularExpressionWithPattern:@"iOS(?=\\sbridge)" options:0 error:NULL];

    testString = [[@"iOS bridge is amazing" mutableCopy] autorelease];
    StrongId<NSString> outputString = [regex stringByReplacingMatchesInString:testString
                                                                      options:NSMatchingWithTransparentBounds
                                                                        range:{ 0, [testString length] }
                                                                 withTemplate:@"Windows Objective C"];

    ASSERT_OBJCEQ(@"Windows Objective C bridge is amazing", outputString);
}

NSUInteger checkMatches(NSRegularExpression* regex, NSString* testString) {
    NSRange range = { 0, [testString length] };
    return [regex numberOfMatchesInString:testString options:0 range:range];
}

TEST(NSRegularExpression, MatchCaseInsensitiveTests) {
    NSError* error = nil;
    NSRegularExpression* regex =
        [NSRegularExpression regularExpressionWithPattern:@"t.*t" options:NSRegularExpressionCaseInsensitive error:&error];

    ASSERT_EQ(checkMatches(regex, @"test1"), 1);
    ASSERT_EQ(checkMatches(regex, @"te.st1"), 1);
}

TEST(NSRegularExpression, MatchingTests) {
    LOG_INFO("NSRegularExpression test: ");
    NSError* error = nil;

    // Test that we can do a simple regex search.
    StrongId<NSRegularExpression> regex =
        [NSRegularExpression regularExpressionWithPattern:@"(sub)(.*)" options:NSRegularExpressionCaseInsensitive error:&error];

    StrongId<NSString> testString = @"test subject";
    NSRange range = { 0, [testString length] };
    NSUInteger matches = [regex numberOfMatchesInString:testString options:0 range:range];

    ASSERT_EQ(matches, 1);

    int numberOfCaptureGroups = [regex numberOfCaptureGroups];

    ASSERT_EQ(numberOfCaptureGroups, 2);

    testString = @"test SuBjEcT";
    matches = [regex numberOfMatchesInString:testString options:0 range:range];
    ASSERT_EQ(matches, 1);

    // Test that a case sensitive match will not match incorrect case of a string.
    regex = [NSRegularExpression regularExpressionWithPattern:@"(SuB)(.*)" options:0 error:&error];
    matches = [regex numberOfMatchesInString:testString options:0 range:range];
    ASSERT_EQ(matches, 1);

    testString = @"test subject";
    matches = [regex numberOfMatchesInString:testString options:0 range:range];
    ASSERT_EQ(matches, 0);
}

TEST(NSRegularExpression, RangeResultTests) {
    StrongId<NSRegularExpression> regex = [NSRegularExpression regularExpressionWithPattern:@"iOS" options:0 error:NULL];
    StrongId<NSString> testString = @"The Windows bridge for iOS";

    NSRange theRange =
        [regex rangeOfFirstMatchInString:testString options:NSRegularExpressionCaseInsensitive range:NSMakeRange(0, [testString length])];

    ASSERT_EQ(theRange.location, 23);
    ASSERT_EQ(theRange.length, 3);

    testString = @"Windows is great!";

    theRange =
        [regex rangeOfFirstMatchInString:testString options:NSRegularExpressionCaseInsensitive range:NSMakeRange(0, [testString length])];

    ASSERT_EQ(theRange.location, NSNotFound);
    ASSERT_EQ(theRange.length, 0);

    StrongId<NSTextCheckingResult> result =
        [regex firstMatchInString:testString options:NSRegularExpressionCaseInsensitive range:NSMakeRange(0, [testString length])];

    ASSERT_EQ(nil, result);
}

TEST(NSRegularExpression, EscapeFormattingTests) {
    StrongId<NSString> escapedPattern =
        [NSRegularExpression escapedPatternForString:@"The following characters should be escaped: $^*()+/?[{}. \\"];
    StrongId<NSString> escapedTemplate = [NSRegularExpression escapedPatternForString:@"Only $ and \\ should be escaped"];

    ASSERT_OBJCEQ(@"The following characters should be escaped: \\$\\^\\*\\(\\)\\+\\/\\?\\[\\{\\}\\. \\\\", escapedPattern);
    ASSERT_OBJCEQ(@"Only \\$ and \\\\ should be escaped", escapedTemplate);
}

TEST(NSRegularExpression, ArchivingUnarchiving) {
    LOG_INFO("NSRegularExpression archiving and unarchiving test: ");

    StrongId<NSRegularExpression> regex =
        [NSRegularExpression regularExpressionWithPattern:@"(sub)(.*)" options:NSRegularExpressionCaseInsensitive error:nullptr];

    StrongId<NSData> data = [NSKeyedArchiver archivedDataWithRootObject:regex];

    StrongId<NSRegularExpression> regularExpressionUnarchived = [NSKeyedUnarchiver unarchiveObjectWithData:data];

    // Simple test that NSRegularExpression is working
    StrongId<NSString> testString = @"test subject";
    NSRange range = { 0, [testString length] };
    NSUInteger matches = [regex numberOfMatchesInString:testString options:0 range:range];

    ASSERT_EQ(matches, 1);

    testString = @"test SuBJeCt";
    matches = [regex numberOfMatchesInString:testString options:0 range:range];
    ASSERT_EQ(matches, 1);

    StrongId<NSTextCheckingResult> firstMatch =
        [regex firstMatchInString:testString options:NSRegularExpressionCaseInsensitive range:range];
    NSRange rangeresult = [firstMatch range];

    StrongId<NSData> textCheckingData = [NSKeyedArchiver archivedDataWithRootObject:firstMatch];

    StrongId<NSTextCheckingResult> textCheckUnarchived = [NSKeyedUnarchiver unarchiveObjectWithData:textCheckingData];

    NSRange unarchivedRange = [textCheckUnarchived range];

    ASSERT_EQ(rangeresult.location, unarchivedRange.location);
    ASSERT_EQ(rangeresult.length, unarchivedRange.length);
}

void numberOfMatchesInStringTest(StrongId<NSRegularExpression> regex,
                                 StrongId<NSString> testString,
                                 NSMatchingOptions options,
                                 NSUInteger expectedMatches) {
    NSRange range = { 0, [testString length] };
    NSUInteger matches = [regex numberOfMatchesInString:testString options:options range:range];

    ASSERT_EQ(matches, expectedMatches);
}

TEST(NSRegularExpression, NSRegulareExpressionOptionsTest) {
    StrongId<NSRegularExpression> regex =
        [NSRegularExpression regularExpressionWithPattern:@"(sub)(.*)" options:NSRegularExpressionCaseInsensitive error:nullptr];

    StrongId<NSString> testString = @"test subject";
    numberOfMatchesInStringTest(regex, testString, 0, 1);

    regex = [NSRegularExpression regularExpressionWithPattern:@"t h i s m a t c h"
                                                      options:NSRegularExpressionAllowCommentsAndWhitespace
                                                        error:nullptr];
    testString = @"thismatch";

    numberOfMatchesInStringTest(regex, testString, 0, 1);

    regex = [NSRegularExpression regularExpressionWithPattern:@"Match [this] entire $ sentence."
                                                      options:NSRegularExpressionIgnoreMetacharacters
                                                        error:nullptr];
    testString = @"Match [this] entire $ sentence.";

    numberOfMatchesInStringTest(regex, testString, 0, 1);

    regex =
        [NSRegularExpression regularExpressionWithPattern:@"line.test" options:NSRegularExpressionDotMatchesLineSeparators error:nullptr];
    testString = @"newline\ntest";

    numberOfMatchesInStringTest(regex, testString, 0, 1);

    regex = [NSRegularExpression regularExpressionWithPattern:@"^is$" options:NSRegularExpressionAnchorsMatchLines error:nullptr];
    testString = @"Only this\nis\nis a match";

    numberOfMatchesInStringTest(regex, testString, 0, 1);

    regex =
        [NSRegularExpression regularExpressionWithPattern:@"here$"
                                                  options:(NSRegularExpressionUseUnixLineSeparators | NSRegularExpressionAnchorsMatchLines)
                                                    error:nullptr];
    testString = @"Don't match here\rOnly match here\nextra";

    numberOfMatchesInStringTest(regex, testString, 0, 1);

    // Try to match all line separators, not just unix to validate above test.
    regex = [NSRegularExpression regularExpressionWithPattern:@"here$" options:(NSRegularExpressionAnchorsMatchLines) error:nullptr];
    testString = @"Match here\rAnd also match here\nextra";

    numberOfMatchesInStringTest(regex, testString, 0, 2);
}

TEST(NSRegularExpression, ErrorTest) {
    NSError* error = nil;
    StrongId<NSRegularExpression> regex =
        [NSRegularExpression regularExpressionWithPattern:@"(" options:NSRegularExpressionCaseInsensitive error:&error];

    EXPECT_OBJCEQ(regex, nil);
    EXPECT_OBJCNE(error, nil);
}

void testOption(
    StrongId<NSRegularExpression> regex, StrongId<NSString> testString, NSMatchingOptions options, int expected, NSRange range) {
    __block NSUInteger count = 0;

    [regex enumerateMatchesInString:testString
                            options:options
                              range:range
                         usingBlock:^void(NSTextCheckingResult* textResult, NSMatchingFlags flags, BOOL* stop) {
                             count++;
                         }];

    // NSMatchingReportProgress can match longer than expected based on the running time. This should call the block no fewer than the
    // expected number of times.
    if (NSMatchingReportProgress & options) {
        ASSERT_GE(count, expected);
    } else {
        ASSERT_EQ(count, expected);
    }
}

void testOption(StrongId<NSRegularExpression> regex, StrongId<NSString> testString, NSMatchingOptions options, int expected) {
    NSRange range = { 0, [testString length] };
    testOption(regex, testString, options, expected, range);
}

TEST(NSRegularExpression, NSMatchingOptionsTest) {
    NSError* error;

    StrongId<NSRegularExpression> regex =
        [NSRegularExpression regularExpressionWithPattern:@"[a-z][aeiou]t" options:NSRegularExpressionCaseInsensitive error:&error];

    StrongId<NSString> testString = @"I like cats, bats, and hats.";

    testOption(regex, testString, NSMatchingReportProgress, 20);
    testOption(regex, testString, NSMatchingReportCompletion, 4);
    testOption(regex, testString, NSMatchingAnchored, 0);

    testString = @"Cats are pretty cool. Bats not so much.";
    testOption(regex, testString, NSMatchingAnchored, 1);

    regex = [NSRegularExpression regularExpressionWithPattern:@"^[a-z][aeiou]t$" options:NSRegularExpressionCaseInsensitive error:nullptr];
    testString = @" Cat ";

    NSRange range = { 1, [testString length] - 2 };
    testOption(regex, testString, 0, 1, range);

    testOption(regex, testString, NSMatchingWithoutAnchoringBounds, 0, range);
}

TEST(NSRegularExpression, FlagsTest) {
    NSError* error;

    StrongId<NSRegularExpression> regex =
        [NSRegularExpression regularExpressionWithPattern:@"[a-z][aeiou]ts"
                                                  options:NSRegularExpressionCaseInsensitive | NSRegularExpressionAnchorsMatchLines |
                                                          NSRegularExpressionUseUnixLineSeparators
                                                    error:&error];
    StrongId<NSString> testString = @"cats bats fats hats mats";
    NSRange range = { 0, [testString length] };

    __block NSInteger progressCount = 0;
    __block NSInteger completedCount = 0;
    __block NSInteger hitEndCount = 0;
    __block NSInteger requiredEndCount = 0;

    [regex enumerateMatchesInString:testString
                            options:NSMatchingReportCompletion | NSMatchingReportProgress
                              range:range
                         usingBlock:^void(NSTextCheckingResult* textResult, NSMatchingFlags flags, BOOL* stop) {
                             if (flags & NSMatchingCompleted) {
                                 completedCount++;
                             }
                             if (flags & NSMatchingProgress) {
                                 progressCount++;
                             }
                         }];
    ASSERT_EQ(progressCount, 4);
    ASSERT_EQ(completedCount, 1);

    // Test anchor flags
    regex = [NSRegularExpression regularExpressionWithPattern:@"[a-z][aeiou]ts$" options:NSRegularExpressionCaseInsensitive error:&error];
    testString = @"fats";
    range = { 0, [testString length] };

    [regex enumerateMatchesInString:testString
                            options:0
                              range:range
                         usingBlock:^void(NSTextCheckingResult* textResult, NSMatchingFlags flags, BOOL* stop) {
                             if (flags & NSMatchingHitEnd) {
                                 hitEndCount++;
                             }
                             if (flags & NSMatchingRequiredEnd) {
                                 requiredEndCount++;
                             }
                         }];
    ASSERT_EQ(hitEndCount, 1);
    ASSERT_EQ(requiredEndCount, 1);

    testString = @"fats\ncats";
    range = { 0, [testString length] };

    [regex enumerateMatchesInString:testString
                            options:NSRegularExpressionAnchorsMatchLines
                              range:range
                         usingBlock:^void(NSTextCheckingResult* textResult, NSMatchingFlags flags, BOOL* stop) {
                             if (flags & NSMatchingHitEnd) {
                                 hitEndCount++;
                             }
                             if (flags & NSMatchingRequiredEnd) {
                                 requiredEndCount++;
                             }
                         }];
    ASSERT_EQ(hitEndCount, 2);
    ASSERT_EQ(requiredEndCount, 2);
}
