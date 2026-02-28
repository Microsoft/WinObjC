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

#include "Foundation/NSSet.h"
#include "BridgeHelpers.h"
#include "Foundation/NSCountedSet.h"
#include "Foundation/NSEnumerator.h"
#include "Foundation/NSKeyedArchiver.h"
#include "Foundation/NSMutableSet.h"
#include "NSCFSet.h"
#include "NSEnumeratorInternal.h"
#include "NSKeyedArchiverInternal.h"
#include "NSRaise.h"
#include "Starboard.h"
#include "StubReturn.h"
#include "VAListHelper.h"
#import "NSKeyValueObserving-Internal.h"
#import <_NSKeyValueCodingAggregateFunctions.h>

@interface NSSet ()
// Public interface for NSSet does not have this method, but is necessary for proper formatting with nested collections
- (NSString*)descriptionWithLocale:(id)locale indent:(NSUInteger)level;
@end

@implementation NSSet

BASE_CLASS_REQUIRED_IMPLS(NSSet, NSSetPrototype, CFSetGetTypeID);

/**
 @Status Interoperable
*/
+ (id)setWithObject:(id)obj {
    return [[[self alloc] initWithObjects:&obj count:1] autorelease];
}

/**
 @Status Interoperable
*/
+ (instancetype)setWithObjects:(NSObject*)first, ... {
    va_list argList;
    va_start(argList, first);
    std::vector<id> flatArgs = ConvertVAListToVector((id)first, argList);
    va_end(argList);

    return [[[self alloc] initWithObjects:flatArgs.data() count:flatArgs.size()] autorelease];
}

/**
 @Status Interoperable
*/
- (instancetype)setByAddingObjectsFromSet:(NSSet*)set {
    NSMutableSet* result = [[self mutableCopy] autorelease];

    [result unionSet:set];

    return result;
}

/**
 @Status Interoperable
*/
- (instancetype)setByAddingObject:(id)obj {
    NSMutableSet* result = [[self mutableCopy] autorelease];

    [result addObject:obj];

    return result;
}

/**
 @Status Interoperable
*/
+ (instancetype)setWithObjects:(id _Nonnull const[])objects count:(NSUInteger)count {
    return [[[self alloc] initWithObjects:objects count:count] autorelease];
}

/**
 @Status Interoperable
*/
+ (NSSet*)setWithSet:(NSSet*)set {
    return [[[self alloc] initWithSet:set] autorelease];
}

/**
 @Status Interoperable
*/
+ (NSSet*)setWithArray:(NSArray*)array {
    return [[[self alloc] initWithArray:array] autorelease];
}

/**
 @Status Interoperable
*/
- (instancetype)initWithObjects:(id _Nonnull const*)objects count:(NSUInteger)count {
    // Derived classes are required to implement this initializer.
    return NSInvalidAbstractInvocationReturn();
}

/**
 @Status Interoperable
*/
- (instancetype)initWithArray:(NSArray*)array {
    NSUInteger count = [array count];
    id* objects = (id*)malloc(count * sizeof(id));

    [array getObjects:objects];

    NSSet* ret = [self initWithObjects:objects count:count];

    free(objects);
    return ret;
}

/**
 @Status Interoperable
*/
- (instancetype)initWithSet:(NSSet*)set {
    return [self initWithSet:set copyItems:NO];
}

/**
 @Status Interoperable
*/
- (instancetype)initWithSet:(NSSet*)set copyItems:(BOOL)flag {
    NSUInteger count = [set count];
    id* objects = (id*)malloc(count * sizeof(id));
    NSUInteger i = 0;
    id obj;

    for (id curObj in set) {
        assert(i < count);
        obj = flag ? [curObj copy] : curObj;
        objects[i++] = obj;
    }

    NSSet* ret = [self initWithObjects:objects count:count];

    if (flag) {
        for (NSUInteger i = 0; i < count; ++i) {
            [objects[i] release];
        }
    }

    free(objects);

    return ret;
}

/**
 @Status Interoperable
*/
- (instancetype)initWithObjects:(NSObject*)first, ... {
    va_list pReader;
    va_start(pReader, first);

    int max = 0;
    int count = 0;
    id* objs = NULL;

    if (count >= max) {
        max += 64;
        objs = (id*)realloc(objs, max * sizeof(id));
    }

    objs[count++] = first;

    id curVal = va_arg(pReader, id);

    while (curVal != NULL) {
        if (count >= max) {
            max += 64;
            objs = (id*)realloc(objs, max * sizeof(id));
        }

        objs[count++] = curVal;

        curVal = va_arg(pReader, id);
    }

    va_end(pReader);

    NSSet* ret = [self initWithObjects:objs count:count];
    free(objs);

    return ret;
}

/**
 @Status Caveat
 @Notes Only supports NSKeyedArchiver NSCoder type.
*/
- (instancetype)initWithCoder:(NSCoder*)coder {
    if ([coder isKindOfClass:[NSKeyedUnarchiver class]]) {
        return [self initWithArray:[coder decodeObjectForKey:@"NS.objects"]];
    } else {
        UNIMPLEMENTED_WITH_MSG("initWithCoder only supports NSKeyedUnarchiver coder type!");
        [self release];
        return nil;
    }
}

/**
 @Status Caveat
 @Notes Only supports NSKeyedArchiver NSCoder type.
*/
- (void)encodeWithCoder:(NSCoder*)coder {
    if ([coder isKindOfClass:[NSKeyedArchiver class]]) {
        [static_cast<NSKeyedArchiver*>(coder) _encodeArrayOfObjects:[self allObjects] forKey:@"NS.objects"];
    } else {
        UNIMPLEMENTED();
    }
}

/**
 @Status Interoperable
*/
+ (NSSet*)set {
    return [[self new] autorelease];
}

/**
 @Status Interoperable
*/
- (BOOL)containsObject:(id)obj {
    return [self member:obj] != nil;
}

/**
 @Status Interoperable
*/
- (id)anyObject {
    for (id curObj in self) {
        return curObj;
    }

    return nil;
}

/**
 @Status Interoperable
*/
- (NSArray*)allObjects {
    return [[self objectEnumerator] allObjects];
}

/**
 @Status Interoperable
*/
- (id)copyWithZone:(NSZone*)zone {
    return [[[self class] alloc] initWithSet:self];
}

/**
 @Status Interoperable
*/
- (NSMutableSet*)mutableCopyWithZone:(NSZone*)zone {
    return [[NSMutableSet alloc] initWithSet:self];
}

/**
 @Status Interoperable
*/
- (void)makeObjectsPerformSelector:(SEL)selector {
    for (id curObj in self) {
        [curObj performSelector:selector];
    }
}

/**
 @Status Interoperable
*/
- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState*)state objects:(id _Nullable*)stackBuf count:(NSUInteger)maxCount {
    if (state->state == 0) {
        state->mutationsPtr = (unsigned long*)&state->extra[1];
        state->extra[0] = (unsigned long)[self objectEnumerator];
        state->state = 1;
    }
    assert(maxCount > 0);

    NSUInteger numRet = 0;
    state->itemsPtr = stackBuf;

    while (maxCount > 0) {
        id next = [(id)state->extra[0] nextObject];
        if (next == nil) {
            break;
        }

        *stackBuf = next;
        stackBuf++;
        numRet++;
        maxCount--;
    }

    return numRet;
}

/**
 @Status Interoperable
*/
- (BOOL)isSubsetOfSet:(NSSet*)other {
    if (self == other) {
        return YES;
    }

    for (id curObj in self) {
        if ([other member:curObj] == nil) {
            return NO;
        }
    }

    return YES;
}

/**
 @Status Interoperable
*/
- (BOOL)intersectsSet:(NSSet*)other {
    if (self == other) {
        return YES;
    }

    for (id curObj in self) {
        if ([other member:curObj]) {
            return YES;
        }
    }

    return NO;
}

/**
 @Status Interoperable
*/
- (BOOL)isEqual:(id)other {
    if (self == other) {
        return YES;
    }

    if (![other isKindOfClass:[NSSet class]]) {
        return NO;
    }

    return [self isEqualToSet:static_cast<NSSet*>(other)];
}

/**
 @Status Interoperable
*/
- (BOOL)isEqualToSet:(NSSet*)other {
    if (self == other) {
        return YES;
    }

    if ([self count] != [other count]) {
        return NO;
    }

    for (id curObj in self) {
        if ([other member:curObj] == nil) {
            return NO;
        }
    }

    return YES;
}

/**
 @Status Interoperable
*/
- (NSUInteger)hash {
    // Surprisingly, this is the behavior on the reference platform
    return [self count];
}

/**
 @Status Interoperable
*/
- (void)enumerateObjectsUsingBlock:(void (^)(id, BOOL*))block {
    [self enumerateObjectsWithOptions:0 usingBlock:block];
}

/**
 @Status Interoperable
 @Notes NSEnumerationReverse is undefined on reference platform so we will ignore it
*/
- (void)enumerateObjectsWithOptions:(NSEnumerationOptions)options usingBlock:(void (^)(id, BOOL*))block {
    _enumerateWithBlock(self, options, block);
}

/**
 @Status Interoperable
*/
- (NSArray*)sortedArrayUsingDescriptors:(NSArray*)descriptors {
    NSArray* ret = [self allObjects];
    [ret sortedArrayUsingDescriptors:descriptors];

    return ret;
}

/**
 @Status Interoperable
*/
- (id)member:(id)obj {
    // NSSet is a class cluster "interface". A concrete implementation (default or derived) MUST implement this.
    return NSInvalidAbstractInvocationReturn();
}

/**
 @Status Interoperable
*/
- (unsigned)count {
    // NSSet is a class cluster "interface". A concrete implementation (default or derived) MUST implement this.
    return NSInvalidAbstractInvocationReturn();
}

/**
 @Status Interoperable
*/
- (void)dealloc {
    [super dealloc];
}

/**
 @Status Interoperable
*/
- (NSEnumerator*)objectEnumerator {
    // NSSet is a class cluster "interface". A concrete implementation (default or derived) MUST implement this.
    return NSInvalidAbstractInvocationReturn();
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
- (NSSet*)setByAddingObjectsFromArray:(NSArray*)other {
    NSMutableSet* result = [[self mutableCopy] autorelease];

    for (id curObj in other) {
        [result addObject:curObj];
    }

    return result;
}

/**
 @Status Interoperable
*/
- (NSSet*)filteredSetUsingPredicate:(NSPredicate*)predicate {
    NSMutableSet* ret = [NSMutableSet setWithSet:self];
    [ret filterUsingPredicate:predicate];
    return ret;
}

/**
 @Status Interoperable
*/
- (void)makeObjectsPerformSelector:(SEL)aSelector withObject:(id)argument {
    for (id element in self) {
        [element performSelector:aSelector withObject:argument];
    }
}

/**
 @Status Interoperable
*/
- (NSSet*)objectsPassingTest:(BOOL (^)(id, BOOL*))predicate {
    return [self objectsWithOptions:0 passingTest:predicate];
}

/**
 @Status Interoperable
*/
- (NSSet*)objectsWithOptions:(NSEnumerationOptions)opts passingTest:(BOOL (^)(id, BOOL*))predicate {
    __block NSMutableSet* ret = [NSMutableSet setWithCapacity:[self count]];

    [self enumerateObjectsWithOptions:opts
                           usingBlock:^void(id obj, BOOL* stop) {
                               if (predicate(obj, stop)) {
                                   @synchronized(ret) {
                                       [ret addObject:obj];
                                   }
                               }
                           }];

    return ret;
}

/**
 @Status Interoperable
*/
- (NSObject*)valueForKey:(NSString*)key {
    if ([key hasPrefix:@"@"]) {
        SEL sel = [_NSKeyValueCodingAggregateFunctions resolveFunction:[key substringFromIndex:1]];
        if (!sel) {
            return [self valueForUndefinedKey:key];
        }

        return [[_NSKeyValueCodingAggregateFunctions class] performSelector:sel withObject:self];
    }

    id ret = [NSMutableSet set];

    id enumerator = [self objectEnumerator];
    id curVal = [enumerator nextObject];

    while (curVal != nil) {
        id newvalue = [curVal valueForKey:key];
        if (newvalue == nil) {
            [ret addObject:[NSNull null]];
        } else {
            [ret addObject:newvalue];
        }

        curVal = [enumerator nextObject];
    }

    return ret;
}

/**
 @Status Interoperable
*/
- (void)setValue:(id)value forKey:(NSString*)key {
    [self enumerateObjectsUsingBlock:^void(id obj, BOOL*) {
        [obj setValue:value forKey:key];
    }];
}

/**
 @Status Interoperable
*/
- (NSString*)descriptionWithLocale:(id)locale {
    return [self descriptionWithLocale:locale indent:0];
}

/**
 @Status Interoperable
*/
- (NSString*)description {
    return [self descriptionWithLocale:nil indent:0];
}

- (NSString*)descriptionWithLocale:(id)locale indent:(NSUInteger)level {
    NSMutableString* ret = [NSMutableString string];
    if (level != 0) {
        [ret appendFormat:[NSString stringWithFormat:@"%%%us", sc_indentSpaces * level], " "];
    }

    [ret appendString:@"{(\n"];

    {
        ++level;
        auto deferPop = wil::ScopeExit([&level]() { --level; });
        for (id val in self) {
            [ret appendFormat:[NSString stringWithFormat:@"%%%us%%@,\n", sc_indentSpaces * level],
                              " ",
                              _descriptionForCollectionElement(val, locale, level)];
        }

        if ([self count] > 0) {
            [ret deleteCharactersInRange:{[ret length] - 2, 1 }];
        }
    }

    if (level != 0) {
        [ret appendFormat:[NSString stringWithFormat:@"%%%us", sc_indentSpaces * level], " "];
    }

    [ret appendString:@")}"];
    return ret;
}

/**
 @Status Interoperable
*/
- (void)addObserver:(id)observer forKeyPath:(NSString*)keyPath options:(NSKeyValueObservingOptions)options context:(void*)context {
    NS_COLLECTION_THROW_ILLEGAL_KVO(keyPath);
}

/**
 @Status Interoperable
*/
- (void)removeObserver:(id)observer forKeyPath:(NSString*)keyPath context:(void*)context {
    NS_COLLECTION_THROW_ILLEGAL_KVO(keyPath);
}

/**
 @Status Interoperable
*/
- (void)removeObserver:(id)observer forKeyPath:(NSString*)keyPath {
    NS_COLLECTION_THROW_ILLEGAL_KVO(keyPath);
}

@end
