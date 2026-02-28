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
#import "Starboard.h"
#import "CFFoundationInternal.h"
#import "ForFoundationOnly.h"
#import "NSConstantString.h"
#import "BridgeHelpers.h"
#import <CoreFoundation/CFString.h>
#import <algorithm>

#define AS_CHAR_PTR(x)    ((const char*)(x))
#define AS_UNICHAR_PTR(x) ((const unichar*)(x))

namespace {
enum NSConstantStringEncoding {
    NSConstantStringASCIIEncoding = 0,
    NSConstantStringUTF8Encoding = 1,
    NSConstantStringUTF16Encoding = 2,
    NSConstantStringUTF32Encoding = 3
};
NSConstantStringEncoding ConstantStringEncodingFromFlags(uint32_t flags) {
    // The low 3 bits of the flags field contains the encoding.
    return static_cast<NSConstantStringEncoding>(flags & 3);
}
}

// Despite what one would imagine when designing a compiler + runtime to interop with NSString,
// the compiler filled in ivars are in UTF-8 not UTF-16 (which is what NSString's primitive methods operate in).
// Moreover, NSString has the "interesting" quirk that length is the size of the unichar buffer, not a logical
// count of characters, meaning that a traversal + codepoint conversion to UTF16 will fail to correctly account for
// UTF16 surrogate pairs which logically count as 1 character index but 2 unichar indices. In order to "most painlessly"
// account for these shenanigans, defer everything to CF's constant string mechanism. This unfortunately means a duplicate
// CFConstantString will exist and access to it is gated on the CFConstantString dictionary lock. It possible that extra space
// on this object could be used to cache the CFStringRef but because it is a compiler generated object, adding ivars is a big no-no.
@implementation NSConstantString
- (instancetype)retain {
    return self;
}

- (void)release {
}

- (instancetype)autorelease {
    return self;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-missing-super-calls"
- (void)dealloc {
}
#pragma pop

// Override [NSString hash] and [NSString isEqualToString:] for faster perf
- (NSUInteger)hash {
#ifdef WINOBJC_NEW_CONSTANT_STRINGS
    if ((flags & (1 << 16)) == 0) {
        hash = [super hash];
        // This is racy and is technically undefined behaviour, but should be
        // safe because we're only ever transitioning between two values.  We
        // will need to do a proper CAS if we ever use more than one of the flag
        // bits.
        flags |= (1 << 16);
    }
    return hash;
#else
    return _CFStringHash(__CFStringMakeConstantString(c_string));
#endif
}

- (BOOL)isEqualToString:(NSString*)str {
    if (self == str) {
        return YES;
    }

    if ([str isKindOfClass:[NSConstantString class]]) {
#ifdef WINOBJC_NEW_CONSTANT_STRINGS
        auto* other = static_cast<NSConstantString*>(str);
        // Two strings with different lengths are different
        if (other->length != length) {
            return false;
        }
        if (ConstantStringEncodingFromFlags(other->flags) == ConstantStringEncodingFromFlags(flags)) {
            return memcmp(data, other->data, size) == 0;
        }
        // Fall through to superclass if the strings are the same length but
        // different encodings.
#else
        return __CFStringMakeConstantString(c_string) == __CFStringMakeConstantString(static_cast<NSConstantString*>(str)->c_string);
#endif
    }

    return [super isEqualToString:str];
}

#ifdef WINOBJC_NEW_CONSTANT_STRINGS
- (NSUInteger)length {
    return length;
}
- (unichar)characterAtIndex:(NSUInteger)index {
    if (index >= length) {
        [self _raiseBoundsExceptionForSelector:(SEL)_cmd andIndex:index];
    }
    switch (ConstantStringEncodingFromFlags(flags)) {
        case NSConstantStringASCIIEncoding:
            return AS_CHAR_PTR(data)[index];
        case NSConstantStringUTF16Encoding:
            return AS_UNICHAR_PTR(data)[index];
        default:
            [NSException raise:NSInternalInconsistencyException format:@"Unsupported constant string encoding"];
    }
    return 0;
}
- (void)getCharacters:(unichar*)buffer range:(NSRange)range {
    NSUInteger end = range.location + range.length;
    if (end > length) {
        [self _raiseBoundsExceptionForSelector:(SEL)_cmd andRange:range];
    }
    switch (ConstantStringEncodingFromFlags(flags)) {
        case NSConstantStringASCIIEncoding:
            std::copy_n(AS_CHAR_PTR(data) + range.location, range.length, buffer);
            break;
        case NSConstantStringUTF16Encoding:
            std::copy_n(AS_UNICHAR_PTR(data) + range.location, range.length, buffer);
            break;
        default:
            [NSException raise:NSInternalInconsistencyException format:@"Unsupported constant string encoding"];
    }
}

- (const char*)_fastCStringContents:(CFStringEncoding)encoding {
    if (ConstantStringEncodingFromFlags(flags) == NSConstantStringASCIIEncoding)
        return AS_CHAR_PTR(data);
    return nullptr;
}

- (const UniChar*)_fastCharacterContents {
    if (ConstantStringEncodingFromFlags(flags) == NSConstantStringUTF16Encoding)
        return AS_UNICHAR_PTR(data);
    return nullptr;
}

- (Boolean)_encodingCantBeStoredInEightBitCFString {
    // This is somewhat conservative and reports whether the data can be stored
    // as a 7-bit string.  It can't cheaply be stored as an 8-bit string
    // though, so it's probably fine.
    return (ConstantStringEncodingFromFlags(flags) != NSConstantStringASCIIEncoding);
}
#else
- INNER_BRIDGE_CALL(static_cast<NSString*>(__CFStringMakeConstantString(c_string)), NSUInteger, length);
- INNER_BRIDGE_CALL(static_cast<NSString*>(__CFStringMakeConstantString(c_string)), unichar, characterAtIndex:(NSUInteger)index);
- INNER_BRIDGE_CALL(static_cast<NSString*>(__CFStringMakeConstantString(c_string)), void,
                    getCharacters:(unichar*)buffer
                    range:(NSRange)range);

- (const char*)_fastCStringContents:(CFStringEncoding)encoding {
    return CFStringGetCStringPtr(__CFStringMakeConstantString(c_string), encoding);
}

- (const UniChar*)_fastCharacterContents {
    return CFStringGetCharactersPtr(__CFStringMakeConstantString(c_string));
}

- (Boolean)_encodingCantBeStoredInEightBitCFString {
    return (nullptr == CFStringGetCStringPtr(__CFStringMakeConstantString(c_string), __CFStringGetEightBitStringEncoding()));
}
#endif

@end
