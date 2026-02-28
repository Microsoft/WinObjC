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
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2016 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//

#include "Starboard.h"
#include <Foundation/NSRegularExpression.h>
#include "CFRegularExpression.h"
#include <functional>
#include <vector>

#import "LoggingNative.h"

typedef void (^NSRegularExpressionMatchBlock)(NSTextCheckingResult*, NSMatchingFlags, BOOL*);

class NSRegularExpressionBlockAdapter {
public:
    NSRegularExpressionBlockAdapter(NSRegularExpression* regEx, NSRegularExpressionMatchBlock block) {
        _block = block;
        _regEx = regEx;
    }

    void MatchCallback(CFRange* ranges, CFIndex count, _CFRegularExpressionMatchingOptions options, Boolean* stop) {
        BOOL localStop = NO;
        if (count > 0 && ranges != nullptr) {
            std::vector<NSRange> rangeVector(count);
            for (CFIndex i = 0; i < count; i++) {
                rangeVector[i] = NSMakeRange(ranges[i].location, ranges[i].length);
            }

            _block([NSTextCheckingResult regularExpressionCheckingResultWithRanges:rangeVector.data() count:count regularExpression:_regEx],
                   static_cast<NSMatchingFlags>(options),
                   &localStop);
        } else {
            _block(nil, static_cast<NSMatchingFlags>(options), &localStop);
        }

        if (stop) {
            *stop = (localStop == YES) ? true : false;
        }
    }

private:
    StrongId<NSRegularExpression> _regEx;
    StrongId<NSRegularExpressionMatchBlock> _block;
};

static void _matchCallBack(void* context, CFRange* ranges, CFIndex count, _CFRegularExpressionMatchingOptions options, Boolean* stop) {
    ((NSRegularExpressionBlockAdapter*)(context))->MatchCallback(ranges, count, options, stop);
}

@interface NSRegularExpression () {
    woc::unique_cf<_CFRegularExpressionRef> _cfRegEx;
}

@end

@implementation NSRegularExpression

/**
@Status Interoperable
*/
+ (NSRegularExpression*)regularExpressionWithPattern:(NSString*)pattern options:(NSRegularExpressionOptions)options error:(NSError**)error {
    return [[[self alloc] initWithPattern:pattern options:options error:error] autorelease];
}

/**
 @Status Interoperable
*/
- (instancetype)initWithPattern:(NSString*)pattern options:(NSRegularExpressionOptions)options error:(NSError**)error {
    CFErrorRef localError = nullptr;
    if (self = [super init]) {
        _cfRegEx.reset(_CFRegularExpressionCreate(nullptr,
                                                  static_cast<CFStringRef>(pattern),
                                                  static_cast<_CFRegularExpressionOptions>(options),
                                                  &localError));
    }

    if (localError != nullptr) {
        [self release];
        if (error) {
            *error = static_cast<NSError*>(localError);
        }

        return nil;
    }

    return self;
}

/**
 @Status Interoperable
*/
- (NSUInteger)numberOfMatchesInString:(NSString*)string options:(NSMatchingOptions)options range:(NSRange)range {
    __block NSUInteger count = 0;

    [self enumerateMatchesInString:string
                           options:options
                             range:range
                        usingBlock:^void(NSTextCheckingResult* textResult, NSMatchingFlags flags, BOOL* stop) {
                            if (textResult) {
                                count++;
                            }
                        }];

    return count;
}

/**
 @Status Interoperable
*/
- (NSTextCheckingResult*)firstMatchInString:(NSString*)string options:(NSMatchingOptions)options range:(NSRange)range {
    __block NSTextCheckingResult* result = nil;

    [self enumerateMatchesInString:string
                           options:options
                             range:range
                        usingBlock:^void(NSTextCheckingResult* textResult, NSMatchingFlags flags, BOOL* stop) {
                            if (textResult) {
                                result = [textResult retain];
                                *stop = YES;
                            }
                        }];

    return [result autorelease];
}

/**
 @Status Interoperable
*/
- (NSRange)rangeOfFirstMatchInString:(NSString*)string options:(NSMatchingOptions)options range:(NSRange)range {
    __block NSRange result = { NSNotFound, 0 };

    [self enumerateMatchesInString:string
                           options:options
                             range:range
                        usingBlock:^void(NSTextCheckingResult* textResult, NSMatchingFlags flags, BOOL* stop) {
                            if (textResult) {
                                result = textResult.range;
                                *stop = YES;
                            }
                        }];

    return result;
}

/**
 @Status Interoperable
*/
- (NSArray*)matchesInString:(NSString*)string options:(NSMatchingOptions)options range:(NSRange)range {
    __block NSMutableArray* result = [NSMutableArray array];

    [self enumerateMatchesInString:string
                           options:options
                             range:range
                        usingBlock:^void(NSTextCheckingResult* textResult, NSMatchingFlags flags, BOOL* stop) {
                            if (textResult) {
                                [result addObject:textResult];
                            }
                        }];

    return result;
}

/**
 @Status Interoperable
*/
- (NSUInteger)replaceMatchesInString:(NSMutableString*)string
                             options:(NSMatchingOptions)options
                               range:(NSRange)range
                        withTemplate:(NSString*)templateStr {
    NSArray* matches = [self matchesInString:string options:options range:range];

    int offset = 0;

    for (NSTextCheckingResult* result in matches) {
        NSString* replacedText = [self replacementStringForResult:result inString:string offset:offset template:templateStr];

        if (replacedText == nil) {
            break;
        }

        NSRange foundRange = result.range;
        foundRange.location += offset;
        [string replaceCharactersInRange:foundRange withString:replacedText];

        offset += replacedText.length - foundRange.length;
    }
    return [matches count];
}

/**
 @Status Interoperable
*/
- (NSString*)stringByReplacingMatchesInString:(NSString*)string
                                      options:(NSMatchingOptions)options
                                        range:(NSRange)range
                                 withTemplate:(NSString*)templateStr {
    // This is just a non-mutable version of replaceMatchesInString
    NSMutableString* mutableStr = [string mutableCopy];
    [self replaceMatchesInString:mutableStr options:options range:range withTemplate:templateStr];
    return [mutableStr autorelease];
}

/**
 @Status Interoperable
*/
+ (NSString*)escapedTemplateForString:(NSString*)string {
    return [static_cast<NSString*>(_CFRegularExpressionCreateEscapedTemplate(static_cast<CFStringRef>(string))) autorelease];
}

/**
 @Status Interoperable
*/
+ (NSString*)escapedPatternForString:(NSString*)string {
    return [static_cast<NSString*>(_CFRegularExpressionCreateEscapedPattern(static_cast<CFStringRef>(string))) autorelease];
}

/**
 @Status Interoperable
*/
- (void)enumerateMatchesInString:(NSString*)string
                         options:(NSMatchingOptions)options
                           range:(NSRange)range
                      usingBlock:(void (^)(NSTextCheckingResult* result, NSMatchingFlags flags, BOOL* stop))block {
    NSRegularExpressionBlockAdapter adapter(self, block);

    _CFRegularExpressionEnumerateMatchesInString(_cfRegEx.get(),
                                                 static_cast<CFStringRef>(string),
                                                 static_cast<_CFRegularExpressionMatchingOptions>(options),
                                                 CFRangeMake(range.location, range.length),
                                                 (void*)(&adapter),
                                                 _matchCallBack);
}

// Internal method for string building in replace calls.
static void _appendBufferToNSString(const char* string, int start, int length, NSMutableString* appendString) {
    NSString* part =
        [[NSString alloc] initWithBytesNoCopy:(void*)(string + start) length:length encoding:NSUTF8StringEncoding freeWhenDone:false];
    [appendString appendString:part];
    [part release];
}

/**
 @Status Interoperable
*/
- (NSString*)replacementStringForResult:(NSTextCheckingResult*)result
                               inString:(NSString*)string
                                 offset:(NSInteger)offset
                               template:(NSString*)templateStr {
    static StrongId<NSCharacterSet> s_characterSet = [NSCharacterSet characterSetWithCharactersInString:@"$\\"];
    NSRange range = [templateStr rangeOfCharacterFromSet:s_characterSet];

    if (range.length > 0) {
        // Okay this means that the template string for replacement included either escaped characters
        // that need resolving or back references to a capture group i.e. $0.
        // First thing to do is determine the maximum number of digits (i.e. 3 for 456) that
        // need to be scanned through on capture group replacements. The number of ranges is the
        // maximal number of capture groups.

        NSUInteger numberOfDigits = 1;
        NSUInteger orderOfMagnitude = 10;
        NSUInteger numberOfRanges = [result numberOfRanges];

        StrongId<NSMutableString> toReturn;
        toReturn.attach([templateStr mutableCopy]);

        NSUInteger length = [toReturn length];

        // Hard cap at 20 digits as that is number of digits in 2^64-1
        while (orderOfMagnitude < numberOfRanges && numberOfDigits < 20) {
            numberOfDigits += 1;
            orderOfMagnitude *= 10;
        }

        while (range.length > 0) {
            unichar c = [toReturn characterAtIndex:range.location];
            if (c == L'\\') {
                // To handle an escaped character, remove the '\' and skip past
                // the next character (range.length = 1 will cause next find to start from after the
                // escaped character).

                [toReturn deleteCharactersInRange:range];
                length -= range.length;
                range.length = 1;
            } else if (c == L'$') {
                // To handle a capture group, first figure out which group it belongs to.
                // To do this, use a cute atoi type routine to chomp along the digits.
                // Done manually so that the range (in the string) of the digits is known for replacement.

                NSUInteger groupNumber = NSNotFound;
                NSUInteger index = NSMaxRange(range);
                while (index < length && index < NSMaxRange(range) + numberOfDigits) {
                    c = [toReturn characterAtIndex:index];
                    if (c < L'0' || c > L'9') {
                        break;
                    }

                    if (groupNumber == NSNotFound) {
                        groupNumber = 0;
                    }

                    groupNumber *= 10;
                    groupNumber += (static_cast<NSUInteger>(c) - static_cast<NSUInteger>('0'));
                    index += 1;
                }

                if (groupNumber != NSNotFound) {
                    // Valid capture group number. This means that $14 or what have you needs replaced
                    // with the 14th capture element from the original string. This is kept track of via
                    // a range in the original string so simply substring it and use that as the replacement
                    // for the range of "$14" i.e. the rangeToReplace.

                    NSRange rangeToReplace = NSMakeRange(range.location, index - range.location);
                    NSRange substringRange = NSMakeRange(NSNotFound, 0);
                    NSString* substring = nil;

                    if (groupNumber < numberOfRanges) {
                        substringRange = [result rangeAtIndex:groupNumber];
                    }

                    if (substringRange.location != NSNotFound) {
                        substringRange.location += offset;
                    }

                    if (substringRange.location != NSNotFound && substringRange.length > 0) {
                        substring = [string substringWithRange:substringRange];
                    }

                    [toReturn replaceCharactersInRange:rangeToReplace withString:substring];

                    length += (substringRange.length - rangeToReplace.length);
                    range.length = substringRange.length;
                }
            }

            // this replacement ends outside the string so all done.
            if (NSMaxRange(range) > length) {
                break;
            }

            // find next $5 or \* replacement starting from end of last one.
            range = [toReturn rangeOfCharacterFromSet:s_characterSet
                                              options:0
                                                range:NSMakeRange(NSMaxRange(range), length - NSMaxRange(range))];
        }
        return toReturn.detach();
    }

    // No replacements or complicatedness. Just return the template string as is. Easy mode.
    return templateStr;
}

/**
 @Status Interoperable
*/
- (instancetype)copyWithZone:(NSZone*)zone {
    return [self retain];
}

/**
 @Status Interoperable
*/
- (instancetype)initWithCoder:(NSCoder*)coder {
    NSString* pattern = [coder decodeObjectForKey:@"NS.pattern"];
    NSUInteger options = [coder decodeIntegerForKey:@"NS.options"];

    return [self initWithPattern:pattern options:options error:nullptr];
}

/**
 @Status Interoperable
*/
- (void)encodeWithCoder:(NSCoder*)coder {
    [coder encodeObject:[self pattern] forKey:@"NS.pattern"];
    [coder encodeInteger:[self options] forKey:@"NS.options"];
}

/**
 @Status Interoperable
*/
+ (BOOL)supportsSecureCoding {
    return YES;
}

/**
 @Status Interoperable
*/
- (NSString*)pattern {
    return static_cast<NSString*>(_CFRegularExpressionGetPattern(_cfRegEx.get()));
}

/**
 @Status Interoperable
*/
- (NSRegularExpressionOptions)options {
    return static_cast<NSRegularExpressionOptions>(_CFRegularExpressionGetOptions(_cfRegEx.get()));
}

/**
 @Status Interoperable
*/
- (NSUInteger)numberOfCaptureGroups {
    return static_cast<NSUInteger>(_CFRegularExpressionGetNumberOfCaptureGroups(_cfRegEx.get()));
}

@end
