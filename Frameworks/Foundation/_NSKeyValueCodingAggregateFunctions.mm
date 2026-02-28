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

#import <_NSKeyValueCodingAggregateFunctions.h>
#import <Foundation/NSMutableSet.h>
#import <Foundation/NSException.h>
#import <Foundation/NSString.h>
#import <Foundation/NSMutableArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSObject.h>
#import <Foundation/NSNull.h>
#include <ErrorHandling.h>

#define THROW_EXCEPTION_IF_DICTIONARY(obj)                                        \
    if ([(id)obj isKindOfClass:[NSDictionary class]]) {                           \
        THROW_NS_HR_MSG(E_INVALIDARG, "method is not supported for dictionary."); \
    }

#define THROW_EXCEPTION_IF_NOT_FAST_ENUMERATION(obj)                                           \
    if (![(id)obj respondsToSelector:@selector(countByEnumeratingWithState:objects:count:)]) { \
        THROW_NS_HR_MSG(E_INVALIDARG, "the class does not support enumeration.");              \
    }

#define THROW_EXCEPTION_IF_NULL(obj)                            \
    if ([obj isEqual:[NSNull null]]) {                          \
        THROW_NS_HR_MSG(E_INVALIDARG, "object cannot be nil."); \
    }

@implementation _NSKeyValueCodingAggregateFunctions

+ (SEL)resolveFunction:(NSString*)funName {
    if (!funName) {
        return nullptr;
    }
    return NSSelectorFromString([NSString stringWithFormat:@"%@:", funName]);
}

+ (NSSet*)distinctUnionOfSets:(NSSet*)values {
    THROW_NS_IF_FALSE(E_INVALIDARG, values != nil);

    NSMutableSet* result = [NSMutableSet set];

    // flatten the set
    for (NSSet* set in values) {
        [result addObjectsFromArray:[set allObjects]];
    }

    return [[result copy] autorelease];
}

+ (NSArray*)unionOfArrays:(NSArray*)values {
    THROW_NS_IF_FALSE(E_INVALIDARG, values != nil);

    NSMutableArray* result = [NSMutableArray array];

    // flatten the array
    for (NSArray* array in values) {
        [result addObjectsFromArray:array];
    }

    return [[result copy] autorelease];
}

+ (NSArray*)distinctUnionOfArrays:(NSArray*)values {
    return [self distinctUnionOfObjects:[self unionOfArrays:values]];
}

+ (NSArray*)unionOfObjects:(id<NSFastEnumeration>)values {
    THROW_NS_IF_FALSE(E_INVALIDARG, values != nil);
    THROW_EXCEPTION_IF_DICTIONARY(values);
    THROW_EXCEPTION_IF_NOT_FAST_ENUMERATION(values);

    NSMutableArray* array = [NSMutableArray array];
    for (id obj in values) {
        THROW_EXCEPTION_IF_NULL(obj);
        [array addObject:obj];
    }
    return [[array copy] autorelease];
}

+ (NSArray*)distinctUnionOfObjects:(id<NSFastEnumeration>)values {
    THROW_NS_IF_FALSE(E_INVALIDARG, values != nil);
    THROW_EXCEPTION_IF_DICTIONARY(values);
    THROW_EXCEPTION_IF_NOT_FAST_ENUMERATION(values);

    NSMutableSet* set = [NSMutableSet set];

    for (id obj in values) {
        THROW_EXCEPTION_IF_NULL(obj);
        [set addObject:obj];
    }

    return [set allObjects];
}

+ (NSNumber*)avg:(id<NSFastEnumeration>)values {
    THROW_NS_IF_FALSE(E_INVALIDARG, values != nil);
    THROW_EXCEPTION_IF_DICTIONARY(values);
    THROW_EXCEPTION_IF_NOT_FAST_ENUMERATION(values);

    NSNumber* res = [self sum:values];
    NSNumber* count = [self count:values];
    if (!res || !count) {
        return nil;
    }

    return [NSNumber numberWithDouble:([res doubleValue] / [count doubleValue])];
}

+ (id)max:(id<NSFastEnumeration>)values {
    return [self _maxOrMin:values ordering:NSOrderedDescending];
}

+ (id)min:(id<NSFastEnumeration>)values {
    return [self _maxOrMin:values ordering:NSOrderedAscending];
}

+ (id)_maxOrMin:(id<NSFastEnumeration>)values ordering:(NSComparisonResult)order {
    THROW_NS_IF_FALSE(E_INVALIDARG, values != nil);
    THROW_EXCEPTION_IF_DICTIONARY(values);
    THROW_EXCEPTION_IF_NOT_FAST_ENUMERATION(values);

    id tracked = nil;

    for (id obj in values) {
        if (tracked == nil & ![obj isEqual:[NSNull null]]) {
            tracked = obj;
        }

        if (![obj isEqual:[NSNull null]]) {
            tracked = ([obj compare:tracked] == order) ? obj : tracked;
        }
    }

    return tracked;
}

+ (NSNumber*)count:(id<NSFastEnumeration>)values {
    THROW_NS_IF_FALSE(E_INVALIDARG, values != nil);
    THROW_EXCEPTION_IF_NOT_FAST_ENUMERATION(values);

    NSUInteger count = 0;
    for (id obj in values) {
        count++;
    }

    return [NSNumber numberWithUnsignedInt:count];
}

+ (NSNumber*)sum:(id<NSFastEnumeration>)values {
    THROW_NS_IF_FALSE(E_INVALIDARG, values != nil);
    THROW_EXCEPTION_IF_DICTIONARY(values);
    THROW_EXCEPTION_IF_NOT_FAST_ENUMERATION(values);

    double result = 0;

    for (id num in values) {
        if (![num isEqual:[NSNull null]]) {
            result += [(NSNumber*)num doubleValue];
        }
    }

    return [NSNumber numberWithDouble:result];
}
@end
