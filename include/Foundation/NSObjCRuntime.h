/* Copyright (c) 2006-2007 Christopher J. W. Lloyd

Copyright (c) 2015 Microsoft Corporation. All rights reserved.

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the
following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. */

#ifndef _NSOBJCRUNTIME_H_
#define _NSOBJCRUNTIME_H_

#import <objc/objc.h>
#import <stdarg.h>
#import <stdint.h>
#import <limits.h>
#import <TargetConditionals.h>
#import <Foundation/FoundationExport.h>
#import <Availability.h>

#define NS_INLINE static inline

// FIXME: do we really need all of these conditions
#if (__cplusplus && __cplusplus >= 201103L && (__has_extension(cxx_strong_enums) || __has_feature(objc_fixed_enum))) || \
    (!__cplusplus && __has_feature(objc_fixed_enum))
#define NS_ENUM(_type, _name) \
    enum _name : _type _name; \
    enum _name : _type
#else
#define NS_ENUM(_type, _name) \
    _type _name;              \
    enum
#endif

#if !defined(NS_REQUIRES_NIL_TERMINATION)
#define NS_REQUIRES_NIL_TERMINATION __attribute__((sentinel(0, 1)))
#endif

#ifndef NS_RETURNS_RETAINED
#if __has_feature(attribute_ns_returns_retained)
#define NS_RETURNS_RETAINED __attribute__((ns_returns_retained))
#else
#define NS_RETURNS_RETAINED
#endif
#endif

#ifndef NS_RETURNS_NOT_RETAINED
#if __has_feature(attribute_ns_returns_not_retained)
#define NS_RETURNS_NOT_RETAINED __attribute__((ns_returns_not_retained))
#else
#define NS_RETURNS_NOT_RETAINED
#endif
#endif

#ifndef CF_RETURNS_RETAINED
#if __has_feature(attribute_cf_returns_retained)
#define CF_RETURNS_RETAINED __attribute__((cf_returns_retained))
#else
#define CF_RETURNS_RETAINED
#endif
#endif

#ifndef CF_RETURNS_NOT_RETAINED
#if __has_feature(attribute_cf_returns_not_retained)
#define CF_RETURNS_NOT_RETAINED __attribute__((cf_returns_not_retained))
#else
#define CF_RETURNS_NOT_RETAINED
#endif
#endif

#ifndef NS_CONSUMED
#if __has_feature(attribute_ns_consumed)
#define NS_CONSUMED __attribute__((ns_consumed))
#else
#define NS_CONSUMED
#endif
#endif

#ifndef CF_CONSUMED
#if __has_feature(attribute_cf_consumed)
#define CF_CONSUMED __attribute__((cf_consumed))
#else
#define CF_CONSUMED
#endif
#endif

#ifndef NS_FORMAT_FUNCTION
#define NS_FORMAT_FUNCTION(F, A) __attribute__((format(NSString, F, A)))
#endif

#ifndef NS_FORMAT_ARGUMENT
#ifdef __clang__
#define NS_FORMAT_ARGUMENT(x) __attribute__((format_arg(x)))
#else
#define NS_FORMAT_ARGUMENT(x)
#endif
#endif

#if __has_attribute(objc_requires_property_definitions)
#define NS_REQUIRES_PROPERTY_DEFINITIONS __attribute__((objc_requires_property_definitions))
#else
#define NS_REQUIRES_PROPERTY_DEFINITIONS
#endif

#ifndef NS_NONATOMIC_IOSONLY
#define NS_NONATOMIC_IOSONLY nonatomic
#endif

@class NSString;

#define NSINTEGER_DEFINED 1

#if defined(__LP64__)
typedef long NSInteger;
typedef unsigned long NSUInteger;
#define NSIntegerMax LONG_MAX
#define NSIntegerMin LONG_MIN
#define NSUIntegerMax ULONG_MAX
#else
typedef int NSInteger;
typedef unsigned int NSUInteger;
#define NSIntegerMax INT_MAX
#define NSIntegerMin INT_MIN
#define NSUIntegerMax UINT_MAX
#endif

enum {
    NSOrderedAscending = -1,
    NSOrderedSame = 0,
    NSOrderedDescending = 1,
};

typedef NSInteger NSComparisonResult;

typedef NSComparisonResult (^NSComparator)(id obj1, id obj2);

typedef double NSTimeInterval;

#define NSNotFound NSIntegerMax

#ifndef MIN
#define MIN(a, b)               \
    ({                          \
        __typeof__(a) _a = (a); \
        __typeof__(b) _b = (b); \
        (_a < _b) ? _a : _b;    \
    })
#endif

#ifndef MAX
#define MAX(a, b)               \
    ({                          \
        __typeof__(a) _a = (a); \
        __typeof__(b) _b = (b); \
        (_a > _b) ? _a : _b;    \
    })
#endif

#ifndef ABS
#define ABS(a)                  \
    ({                          \
        __typeof__(a) _a = (a); \
        (_a < 0) ? -_a : _a;    \
    })
#endif

#ifdef _WINOBJC_DO_NOT_USE_NSLOG
#define NSLOG_ANNOTATION __attribute__((unavailable("NSLog should not be used internally.")))
#else
#define NSLOG_ANNOTATION
#endif

FOUNDATION_EXPORT void NSLog(NSString* format, ...) NS_FORMAT_FUNCTION(1, 2) NSLOG_ANNOTATION;
FOUNDATION_EXPORT void NSLogv(NSString* format, va_list args) NS_FORMAT_FUNCTION(1, 0) NSLOG_ANNOTATION;

FOUNDATION_EXPORT const char* NSGetSizeAndAlignment(const char* type, NSUInteger* size, NSUInteger* alignment);

FOUNDATION_EXPORT SEL NSSelectorFromString(NSString* selectorName);
FOUNDATION_EXPORT NSString* NSStringFromSelector(SEL selector);

FOUNDATION_EXPORT Class NSClassFromString(NSString* className);
FOUNDATION_EXPORT NSString* NSStringFromClass(Class aClass);

FOUNDATION_EXPORT NSString* NSStringFromProtocol(Protocol* proto);
FOUNDATION_EXPORT Protocol* NSProtocolFromString(NSString* namestr);

#ifndef NS_BLOCKS_AVAILABLE
#if __BLOCKS__
#define NS_BLOCKS_AVAILABLE 1
#else
#define NS_BLOCKS_AVAILABLE 0
#endif
#endif

#ifndef NS_UNAVAILABLE
#define NS_UNAVAILABLE UNAVAILABLE_ATTRIBUTE
#endif

#ifndef NS_DESIGNATED_INITIALIZER
#if __has_attribute(objc_designated_initializer)
#define NS_DESIGNATED_INITIALIZER __attribute__((objc_designated_initializer))
#else
#define NS_DESIGNATED_INITIALIZER
#endif
#endif

#ifndef NS_SWIFT_NOTHROW
#define NS_SWIFT_NOTHROW
#endif

#ifndef NS_REFINED_FOR_SWIFT
#define NS_REFINED_FOR_SWIFT
#endif

#ifndef NS_SWIFT_NAME
#define NS_SWIFT_NAME
#endif

#ifdef NS_SWIFT_UNAVAILABLE
#define NS_SWIFT_UNAVAILABLE
#endif

#ifndef NS_ASSUME_NONNULL_BEGIN
#if __has_feature(assume_nonnull)
#define NS_ASSUME_NONNULL_BEGIN _Pragma("clang assume_nonnull begin")
#define NS_ASSUME_NONNULL_END _Pragma("clang assume_nonnull end")
#else
#define NS_ASSUME_NONNULL_BEGIN
#define NS_ASSUME_NONNULL_END
#endif
#endif

#if (!__has_feature(objc_arc))
#ifndef __autoreleasing
#define __autoreleasing
#endif
#ifndef __strong
#define __strong
#endif
#ifndef __weak
#define __weak
#endif
#ifndef __unsafe_unretained
#define __unsafe_unretained
#endif
#endif

#if __has_feature(nullability)
#ifndef __nullable
#define __nullable _Nullable
#endif
#endif

#ifndef NS_AVAILABLE
#define NS_AVAILABLE(x, y)
#endif

#ifndef NS_AVAILABLE_IOS
#define NS_AVAILABLE_IOS(x)
#endif

#ifndef NS_DEPRECATED_IOS
#define NS_DEPRECATED_IOS(x, y)
#endif

#ifndef NS_EXTENSION_UNAVAILABLE_IOS
#define NS_EXTENSION_UNAVAILABLE_IOS(x)
#endif

#ifdef __cplusplus
#define NS_OPTIONS(_t, _n) \
    _t _n;                 \
    enum : _t
#else
#define NS_OPTIONS(_t, _n) \
    enum _n : _t _n;       \
    enum _n : _t
#endif

enum {
    NSSortConcurrent = 1UL,
    NSSortStable = 16UL,
};

typedef uint32_t NSSortOptions;

enum {
    NSEnumerationConcurrent = 1,
    NSEnumerationReverse = 2,
};

typedef uint32_t NSEnumerationOptions;

FOUNDATION_EXPORT const double NSFoundationVersionNumber;

#define NSFoundationVersionNumber_iPhoneOS_2_0 678.24
#define NSFoundationVersionNumber_iPhoneOS_2_1 678.26
#define NSFoundationVersionNumber_iPhoneOS_2_2 678.29
#define NSFoundationVersionNumber_iPhoneOS_3_0 678.47
#define NSFoundationVersionNumber_iPhoneOS_3_1 678.51
#define NSFoundationVersionNumber_iPhoneOS_3_2 678.60
#define NSFoundationVersionNumber_iOS_4_0 751.32
#define NSFoundationVersionNumber_iOS_4_1 751.37
#define NSFoundationVersionNumber_iOS_4_2 751.49
#define NSFoundationVersionNumber_iOS_4_3 751.49
#define NSFoundationVersionNumber_iOS_5_0 881.00
#define NSFoundationVersionNumber_iOS_5_1 890.10
#define NSFoundationVersionNumber_iOS_6_0 993.00
#define NSFoundationVersionNumber_iOS_6_1 993.00
#define NSFoundationVersionNumber_iOS_7_0 1047.20
#define NSFoundationVersionNumber_iOS_7_1 1047.25
#define NSFoundationVersionNumber_iOS_8_0 1140.11
#define NSFoundationVersionNumber_iOS_8_1 1141.1
#define NSFoundationVersionNumber_iOS_8_2 1142.14
#define NSFoundationVersionNumber_iOS_8_3 1144.17

#ifndef NS_VALID_UNTIL_END_OF_SCOPE
#define NS_VALID_UNTIL_END_OF_SCOPE __attribute__((objc_precise_lifetime))
#endif

#ifndef NS_RETURNS_INNER_POINTER
#define NS_RETURNS_INNER_POINTER __attribute__((objc_returns_inner_pointer))
#endif

#endif /* _NSOBJCRUNTIME_H_ */