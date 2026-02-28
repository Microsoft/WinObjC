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

#include "Starboard.h"
#include <Foundation/NSMutableString.h>
#include "NSCFString.h"
#include "NSRaise.h"
#include "BridgeHelpers.h"
#include "CFFoundationInternal.h"

@implementation NSMutableString

static Class _NSCFString$classForCoder(id self, SEL _cmd) {
    if (_CFStringIsMutable(static_cast<CFStringRef>(self))) {
        return [NSMutableString class];
    }
    return [NSString class];
}

+ (void)load {
    // Now that NSString is loaded, go ahead and reset _NSCFString's superclass
    // to be NSString. This is needed so that any CFString that was created *before*
    // NSString was loaded (namely all the constants in CF) will be properly bridged.
    Class nscfClass = objc_getClass("_NSCFStringSuperclassAnchor");
    Class nscfMetaClass = objc_getMetaClass("_NSCFStringSuperclassAnchor");

    class_setSuperclass(nscfClass, self);
    object_setClass(nscfMetaClass, object_getClass(object_getClass(self)));
    class_setSuperclass(nscfMetaClass, object_getClass(self));

    // NSString is special and needs some help. We can't override classForCoder
    // in _NSCFString because it lives in CoreFoundation (and can't reference us.)
    // We have to stomp it here to make sure that mutable strings are coded properly,
    // and immutable strings are not coded at all (short-circuited through NSKeyedArchiver.)
    class_replaceMethod(nscfClass, @selector(classForCoder), reinterpret_cast<IMP>(&_NSCFString$classForCoder), "#@:");
}

/**
 @Status Interoperable
*/
+ ALLOC_PROTOTYPE_SUBCLASS_WITH_ZONE(NSMutableString, NSMutableStringPrototype);

/**
 @Status Interoperable
*/
+ (instancetype)stringWithCapacity:(NSUInteger)capacity {
    return [[[self alloc] initWithCapacity:capacity] autorelease];
}

/**
 @Status Interoperable
*/
- (instancetype)initWithCapacity:(NSUInteger)capacity {
    // Derived classes are required to implement this initializer
    return NSInvalidAbstractInvocationReturn();
}

/**
 @Status Interoperable
*/
- (void)insertString:(NSString*)str atIndex:(NSUInteger)idx {
    [self replaceCharactersInRange:NSMakeRange(idx, 0) withString:str];
}

/**
 @Status Interoperable
*/
- (void)replaceCharactersInRange:(NSRange)range withString:(NSString*)str {
    // NSMutableString is a class cluster "interface". A concrete implementation (default or derived) MUST implement this.
    NSInvalidAbstractInvocation();
}

/**
 @Status Interoperable
*/
- (void)deleteCharactersInRange:(NSRange)range {
    [self replaceCharactersInRange:range withString:@""];
}

/**
 @Status Interoperable
*/
- (void)appendFormat:(NSString*)formatStr, ... {
    va_list reader;
    va_start(reader, formatStr);

    StrongId<NSString> endStr;
    endStr.attach([[NSString alloc] initWithFormat:formatStr arguments:reader]);
    va_end(reader);

    [self appendString:endStr];
}

/**
 @Status Interoperable
*/
- (void)appendString:(NSString*)str {
    [self insertString:str atIndex:[self length]];
}

/**
 @Status Interoperable
*/
- (void)setString:(NSString*)str {
    [self replaceCharactersInRange:NSMakeRange(0, [self length]) withString:str];
}

/**
 @Status Interoperable
*/
- (NSUInteger)replaceOccurrencesOfString:(id)target
                              withString:(id)replacement
                                 options:(NSStringCompareOptions)options
                                   range:(NSRange)range {
    THROW_NS_IF_NULL_MSG(E_INVALIDARG, target, "nil target object");
    THROW_NS_IF_NULL_MSG(E_INVALIDARG, replacement, "nil replacement object");
    THROW_NS_IF_FALSE_MSG(E_BOUNDS,
                          range.location + range.length <= [self length],
                          "end of search range %d beyond length %d",
                          range.location + range.length,
                          [self length]);

    if (options & NSRegularExpressionSearch) {
        NSRegularExpressionOptions regOptions = 0;
        uint32_t searchOptions = 0;

        if (options & NSCaseInsensitiveSearch) {
            regOptions |= NSRegularExpressionCaseInsensitive;
        }
        if (options & NSAnchoredSearch) {
            searchOptions = NSMatchingAnchored;
        }

        StrongId<NSRegularExpression> regExp;
        regExp.attach([[NSRegularExpression alloc] initWithPattern:target options:regOptions error:NULL]);
        int count = [regExp replaceMatchesInString:self options:searchOptions range:range withTemplate:replacement];

        return count;
    }

    const BOOL isBackwards = (options & NSBackwardsSearch) ? YES : NO;
    const NSUInteger replacementLen = [replacement length];
    NSRange subrange;

    NSUInteger n = 0;
    subrange = [self rangeOfString:target options:static_cast<NSStringCompareOptions>(options) range:range];
    while (subrange.location != 0x7fffffff) {
        [self replaceCharactersInRange:subrange withString:replacement];

        if (!isBackwards) {
            range.length -= (subrange.location - range.location) + subrange.length;
            range.location = subrange.location + replacementLen;
        } else {
            range.length = subrange.location - range.location;
        }

        n++;
        subrange = [self rangeOfString:target options:static_cast<NSStringCompareOptions>(options) range:range];
    }

    return n;
}

/**
 @Status Interoperable
*/
- (NSObject*)copyWithZone:(NSZone*)zone {
    return [[NSString alloc] initWithString:self];
}

- (void)_cfAppendCString:(const unsigned char*)cString length:(NSInteger)length {
    [self appendString:[NSString stringWithCString:(const char*)cString length:length]];
}

- (void)_cfPad:(NSString*)padString length:(uint32_t)length padIndex:(uint32_t)indexIntoPad {
    if (length <= [self length]) {
        [self deleteCharactersInRange:{ length, [self length] }];
    } else {
        // Not so efficient but will get the job done.
        NSString* replacement = [padString substringWithRange:{ indexIntoPad, 1 }];
        for (int i = 0; i < (length - [self length]); i++) {
            [self appendString:replacement];
        }
    }
}

- (void)_cfTrim:(NSString*)trimString {
    // Start searching forward for matching range anchored at start.
    NSInteger newStartIndex = 0;
    NSRange range;
    range = [self rangeOfString:trimString options:NSAnchoredSearch range:{ newStartIndex, [self length] }];
    while (range.location != NSNotFound) {
        newStartIndex = range.location + range.length;
        range = [self rangeOfString:trimString options:NSAnchoredSearch range:{ newStartIndex, [self length] }];
    }

    if (newStartIndex < [self length] && newStartIndex > 0) {
        // valid trim region at the start.
        [self deleteCharactersInRange:{ 0, newStartIndex }];
    }

    // Now search backwards.
    NSInteger newEndIndex = [self length];
    range = [self rangeOfString:trimString
                        options:static_cast<NSStringCompareOptions>(NSAnchoredSearch | NSBackwardsSearch)
                          range:{ 0, newEndIndex }];
    while (range.location != NSNotFound) {
        newEndIndex = range.location;
        range = [self rangeOfString:trimString
                            options:static_cast<NSStringCompareOptions>(NSAnchoredSearch | NSBackwardsSearch)
                              range:{ 0, newEndIndex }];
    }

    if (newEndIndex < [self length] && newEndIndex > 0) {
        // valid trim region at the end.
        [self deleteCharactersInRange:{ newEndIndex, [self length] }];
    }
}

- (void)_cfTrimWS {
    // Start searching forward for matching range anchored at start.
    NSInteger newStartIndex = 0;
    NSRange range;
    NSCharacterSet* whitespace = [NSCharacterSet whitespaceCharacterSet];
    range = [self rangeOfCharacterFromSet:whitespace options:NSAnchoredSearch range:{ newStartIndex, [self length] }];
    while (range.location != NSNotFound) {
        newStartIndex = range.location + range.length;
        range = [self rangeOfCharacterFromSet:whitespace options:NSAnchoredSearch range:{ newStartIndex, [self length] }];
    }

    if (newStartIndex < [self length] && newStartIndex > 0) {
        // valid trim region at the start.
        [self deleteCharactersInRange:{ 0, newStartIndex }];
    }

    // Now search backwards.
    NSInteger newEndIndex = [self length];
    range = [self rangeOfCharacterFromSet:whitespace
                                  options:static_cast<NSStringCompareOptions>(NSAnchoredSearch | NSBackwardsSearch)
                                    range:{ 0, newEndIndex }];
    while (range.location != NSNotFound) {
        newEndIndex = range.location;
        range = [self rangeOfCharacterFromSet:whitespace
                                      options:static_cast<NSStringCompareOptions>(NSAnchoredSearch | NSBackwardsSearch)
                                        range:{ 0, newEndIndex }];
    }

    if (newEndIndex < [self length] && newEndIndex > 0) {
        // valid trim region at the end.
        [self deleteCharactersInRange:{ newEndIndex, [self length] }];
    }
}

- (void)_cfNormalize:(CFStringNormalizationForm)form {
    // This isn't the most efficient but to ensure that its a CF string (and therefore will bridge properly) make a copy and try again.
    NSMutableString* mutableCopy = [[self mutableCopy] autorelease];
    CFStringNormalize(static_cast<CFMutableStringRef>(mutableCopy), form);
    [self setString:mutableCopy];
}

- (void)_cfLowercase:(NSLocale*)locale {
    return [self setString:[self lowercaseStringWithLocale:locale]];
}

- (void)_cfUppercase:(NSLocale*)locale {
    return [self setString:[self uppercaseStringWithLocale:locale]];
}

- (void)_cfCapitalize:(NSLocale*)locale {
    return [self setString:[self capitalizedStringWithLocale:locale]];
}

@end
