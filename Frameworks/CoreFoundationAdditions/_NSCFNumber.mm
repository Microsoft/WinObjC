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
#include <CoreFoundation/CFBase.h>
#include "CFFoundationInternal.h"
#include "CFInternal.h"
#include "_NSCFNumber.h"
#include <CoreFoundation/CFNumber.h>

// Matches private struct in CFNumber
typedef struct {
    int64_t high;
    uint64_t low;
} CFSInt128Struct;

// Matches private CFNumberType value in CFNumber
enum { kCFNumberSInt128Type = 17 };

// ignore bridge cast warnings here. These will be subclasses of NSNumber after load.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wbridge-cast"

#pragma region _NSCFNumber

@implementation _NSCFNumberSuperclassAnchor
@end

@implementation _NSCFNumber

- (id)retain {
    CFRetain(static_cast<CFNumberRef>(self));
    return self;
}

- (oneway void)release {
    CFRelease(static_cast<CFNumberRef>(self));
}

- (id)autorelease {
    return (id)(CFAutorelease(static_cast<CFNumberRef>(self)));
}

- (NSUInteger)retainCount {
    return CFGetRetainCount(static_cast<CFNumberRef>(self));
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-missing-super-calls"
- (void)dealloc {
    /* No-op for bridged classes. This is because the CF system is responsible for the allocation and dealloc of the backing memory. */
    /* This is all handled via the CFRelease calls. */
    /* When its CF ref count drops to 0 the CF version of dealloc is invoked */
    /* so by the time the NSObject dealloc is called, there is nothing left to do. */
}

+ (instancetype)allocWithZone:(NSZone*)zone {
    return nil;
}
#pragma clang diagnostic pop

- (void)getValue:(void*)dest {
    CFNumberRef cfSelf = static_cast<CFNumberRef>(self);
    CFNumberGetValue(cfSelf, CFNumberGetType(cfSelf), dest);
}

- (NSComparisonResult)compare:(NSNumber*)aNumber {
    return CFNumberCompare(static_cast<CFNumberRef>(self), static_cast<CFNumberRef>(aNumber), NULL);
}

- (BOOL)isEqual:(NSObject*)obj {
// Ignore warning about the + class function not being found - it'll be available once Foundation is loaded
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-method-access"
    if ([obj isKindOfClass:[_NSCFBoolean class]]) {
#pragma clang diagnostic pop
        return NO;
    }
    return [super isEqual:obj];
}

- (const char*)objCType {
    CFNumberType cfType = CFNumberGetType(static_cast<CFNumberRef>(self));

    switch (cfType) {
        case kCFNumberSInt8Type:
        case kCFNumberCharType:
            return @encode(char);
        case kCFNumberSInt16Type:
        case kCFNumberShortType:
            return @encode(short);
        case kCFNumberIntType:
        case kCFNumberCFIndexType:
        case kCFNumberNSIntegerType:
            return @encode(int);
        case kCFNumberSInt32Type:
        case kCFNumberLongType:
            return @encode(long);
        case kCFNumberSInt64Type:
        case kCFNumberLongLongType:
            return @encode(long long);
        case kCFNumberFloat32Type:
        case kCFNumberFloatType:
        case kCFNumberCGFloatType:
            return @encode(float);
        case kCFNumberFloat64Type:
        case kCFNumberDoubleType:
            return @encode(double);

// ignore warning about kCFNumberSInt128Type not being a public CFNumberType
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wswitch"
        case kCFNumberSInt128Type:
            return @encode(unsigned long long);
#pragma clang pop

        default:
            return @encode(int);
    }
}

- (BOOL)boolValue {
    return (([self intValue] == 0) ? NO : YES);
}

// Helper macro for [NSNumber XYZValue] functions (signed)
#define NSCF_NUMBER_GET_VALUE_IMPL(returnType, functionName, cfNumberType)    \
    (returnType) functionName {                                               \
        returnType ret;                                                       \
        CFNumberGetValue(static_cast<CFNumberRef>(self), cfNumberType, &ret); \
        return ret;                                                           \
    }

- NSCF_NUMBER_GET_VALUE_IMPL(char, charValue, kCFNumberCharType);
- NSCF_NUMBER_GET_VALUE_IMPL(double, doubleValue, kCFNumberDoubleType);
- NSCF_NUMBER_GET_VALUE_IMPL(float, floatValue, kCFNumberFloatType);
- NSCF_NUMBER_GET_VALUE_IMPL(int, intValue, kCFNumberIntType);
- NSCF_NUMBER_GET_VALUE_IMPL(NSInteger, integerValue, kCFNumberNSIntegerType);
- NSCF_NUMBER_GET_VALUE_IMPL(long long, longLongValue, kCFNumberLongLongType);
- NSCF_NUMBER_GET_VALUE_IMPL(long, longValue, kCFNumberLongType);
- NSCF_NUMBER_GET_VALUE_IMPL(short, shortValue, kCFNumberShortType);

// Helper macro for [NSNumber unsignedXYZValue] functions (unsigned)
// Unsigned requires an extra step of conversion, as CFNumber does not actually support unsigned types
// Get around this by using a signed intermediate type of twice the size, then returning a cast of its unsigned value
#define NSCF_NUMBER_GET_VALUE_UNSIGNED_IMPL(returnType, functionName, cfNumberType, intermediateType) \
    (returnType) functionName {                                                                       \
        intermediateType ret;                                                                         \
        CFNumberGetValue(static_cast<CFNumberRef>(self), cfNumberType, &ret);                         \
        return static_cast<returnType>(ret);                                                          \
    }

- NSCF_NUMBER_GET_VALUE_UNSIGNED_IMPL(unsigned char, unsignedCharValue, kCFNumberSInt16Type, int16_t);
- NSCF_NUMBER_GET_VALUE_UNSIGNED_IMPL(NSUInteger, unsignedIntegerValue, kCFNumberSInt64Type, int64_t);
- NSCF_NUMBER_GET_VALUE_UNSIGNED_IMPL(unsigned int, unsignedIntValue, kCFNumberSInt64Type, int64_t);
- NSCF_NUMBER_GET_VALUE_UNSIGNED_IMPL(unsigned long, unsignedLongValue, kCFNumberSInt64Type, int64_t);
- NSCF_NUMBER_GET_VALUE_UNSIGNED_IMPL(unsigned short, unsignedShortValue, kCFNumberSInt32Type, int32_t);

// Doesn't match the macro due to the 128-bit struct used by CFNumber
- (unsigned long long)unsignedLongLongValue {
    CFSInt128Struct ret;
    CFNumberGetValue(static_cast<CFNumberRef>(self), static_cast<CFNumberType>(kCFNumberSInt128Type), &ret);
    return ret.low;
}

@end

#pragma endregion

#pragma region _NSCFBoolean

@implementation _NSCFBoolean

- (id)retain {
    CFRetain(static_cast<CFBooleanRef>(self));
    return self;
}

- (oneway void)release {
    CFRelease(static_cast<CFBooleanRef>(self));
}

- (id)autorelease {
    return (id)(CFAutorelease(static_cast<CFBooleanRef>(self)));
}

- (NSUInteger)retainCount {
    return CFGetRetainCount(static_cast<CFBooleanRef>(self));
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-missing-super-calls"
- (void)dealloc {
    /* No-op for bridged classes. This is because the CF system is responsible for the allocation and dealloc of the backing memory. */
    /* This is all handled via the CFRelease calls. */
    /* When its CF ref count drops to 0 the CF version of dealloc is invoked */
    /* so by the time the NSObject dealloc is called, there is nothing left to do. */
}

+ (instancetype)allocWithZone:(NSZone*)zone {
    return nil;
}

#pragma clang diagnostic pop

- (void)getValue:(void*)dest {
    *(BOOL*)dest = [self boolValue];
}

- (NSComparisonResult)compare:(NSNumber*)aNumber {
// Ignore warning about the + class function not being found - it'll be available once Foundation is loaded
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-method-access"
    if (([aNumber isKindOfClass:[_NSCFBoolean class]]) && (static_cast<NSNumber*>(self) == aNumber)) {
#pragma clang diagnostic pop
        return NSOrderedSame;
    }

    int intValue = (static_cast<CFBooleanRef>(self) == kCFBooleanTrue) ? 1 : 0;

    // Since low ints are cached in CFNumber, this actually doesn't create a new instance
    return CFNumberCompare(CFNumberCreate(NULL, kCFNumberIntType, &intValue), static_cast<CFNumberRef>(aNumber), NULL);
}

- (BOOL)isEqual:(NSObject*)obj { // Ignore warning about the + class function not being found - it'll be available once Foundation is loaded
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-method-access"
    if (![obj isKindOfClass:[_NSCFBoolean class]]) {
#pragma clang diagnostic pop
        return NO;
    }
    return [super isEqual:obj];
}

- (const char*)objCType {
    return @encode(BOOL);
}

// Helper macro for [NSNumber XYZValue] functions
#define NSCF_BOOLEAN_GET_VALUE_IMPL(returnType, functionName)                                        \
    (returnType) functionName {                                                                      \
        return static_cast<returnType>((static_cast<CFBooleanRef>(self) == kCFBooleanTrue) ? 1 : 0); \
    }

- NSCF_BOOLEAN_GET_VALUE_IMPL(BOOL, boolValue);
- NSCF_BOOLEAN_GET_VALUE_IMPL(char, charValue);
- NSCF_BOOLEAN_GET_VALUE_IMPL(double, doubleValue);
- NSCF_BOOLEAN_GET_VALUE_IMPL(float, floatValue);
- NSCF_BOOLEAN_GET_VALUE_IMPL(int, intValue);
- NSCF_BOOLEAN_GET_VALUE_IMPL(NSInteger, integerValue);
- NSCF_BOOLEAN_GET_VALUE_IMPL(long long, longLongValue);
- NSCF_BOOLEAN_GET_VALUE_IMPL(long, longValue);
- NSCF_BOOLEAN_GET_VALUE_IMPL(short, shortValue);
- NSCF_BOOLEAN_GET_VALUE_IMPL(unsigned char, unsignedCharValue);
- NSCF_BOOLEAN_GET_VALUE_IMPL(NSUInteger, unsignedIntegerValue);
- NSCF_BOOLEAN_GET_VALUE_IMPL(unsigned int, unsignedIntValue);
- NSCF_BOOLEAN_GET_VALUE_IMPL(unsigned long long, unsignedLongLongValue);
- NSCF_BOOLEAN_GET_VALUE_IMPL(unsigned long, unsignedLongValue);
- NSCF_BOOLEAN_GET_VALUE_IMPL(unsigned short, unsignedShortValue);

@end

#pragma endregion

#pragma clang diagnostic pop