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

#import "Starboard.h"
#import "StubReturn.h"
#import "CFHelpers.h"
#import "Foundation/NSMutableArray.h"
#import "Foundation/NSMutableData.h"
#import "Foundation/NSEnumerator.h"
#import "Foundation/NSKeyedArchiver.h"
#import "Foundation/NSArray.h"
#import "NSEnumeratorInternal.h"
#import "CoreFoundation/CFArray.h"
#import "Foundation/NSMutableString.h"
#import "NSKeyedArchiverInternal.h"
#import "Foundation/NSIndexSet.h"
#import "Foundation/NSNull.h"
#import "VAListHelper.h"
#import "LoggingNative.h"
#import "NSRaise.h"
#import "NSCFArray.h"
#import "BridgeHelpers.h"
#import "NSKeyValueObserving-Internal.h"
#import "_NSKeyValueCodingAggregateFunctions.h"

static const wchar_t* TAG = L"NSArray";

static const CFPropertyListFormat sc_plistFormat = kCFPropertyListBinaryFormat_v1_0;

@implementation NSArray

BASE_CLASS_REQUIRED_IMPLS(NSArray, NSArrayPrototype, CFArrayGetTypeID);

/**
 @Status Interoperable
*/
+ (instancetype)arrayWithObjects:(NSObject*)first, ... {
    va_list argList;
    va_start(argList, first);
    std::vector<id> flatArgs = ConvertVAListToVector((id)first, argList);
    va_end(argList);

    return [[[self alloc] initWithObjects:flatArgs.data() count:flatArgs.size()] autorelease];
}

/**
 @Status Interoperable
*/
+ (instancetype)arrayWithObject:(NSObject*)obj {
    return [[[self alloc] initWithObjects:&obj count:1] autorelease];
}

/**
 @Status Interoperable
*/
+ (instancetype)array {
    return [[self new] autorelease];
}

/**
 @Status Interoperable
*/
+ (instancetype)arrayWithObjects:(id _Nonnull const*)objs count:(NSUInteger)count {
    return [[[self alloc] initWithObjects:objs count:count] autorelease];
}

/**
 @Status Interoperable
*/
+ (instancetype)arrayWithArray:(NSArray*)arrayToCopy {
    return [[[self alloc] initWithArray:arrayToCopy] autorelease];
}

/**
 @Status Interoperable
*/
+ (NSArray*)arrayWithContentsOfFile:(NSString*)filename {
    return [[[self alloc] initWithContentsOfFile:filename] autorelease];
}

/**
 @Status Interoperable
*/
- (instancetype)initWithObjects:(NSObject*)first, ... {
    va_list argList;
    va_start(argList, first);
    std::vector<id> flatArgs = ConvertVAListToVector((id)first, argList);
    va_end(argList);
    return [self initWithObjects:flatArgs.data() count:flatArgs.size()];
}

/**
 @Status Interoperable
*/
- (NSArray*)initWithContentsOfFile:(NSString*)filename {
    const char* file = (char*)[filename UTF8String];

    NSData* data = [NSData dataWithContentsOfFile:filename];

    if (data == nil) {
        [self release];
        return nil;
    }

    char* pData = (char*)[data bytes];

    id arrayData =
        [NSPropertyListSerialization propertyListFromData:data mutabilityOption:NSPropertyListImmutable format:0 errorDescription:0];
    if (![arrayData isKindOfClass:[NSArray class]]) {
        arrayData = [arrayData objectForKey:@"$objects"];
        if (![(id)arrayData isKindOfClass:[NSArray class]]) {
            TraceWarning(TAG, L"object %hs is not an array", [[arrayData description] UTF8String]);
            [self release];
            return nil;
        }
    }

    return [self initWithArray:arrayData];
}

/**
 @Status Interoperable
*/
- (NSUInteger)count {
    // NSArray is a class cluster "interface". A concrete implementation (default or derived) MUST implement this.
    return NSInvalidAbstractInvocationReturn();
}

/**
 @Status Interoperable
*/
- (instancetype)initWithObjects:(id _Nonnull const*)objs count:(NSUInteger)count {
    // Derived classes are required to implement this initializer.
    return NSInvalidAbstractInvocationReturn();
}

/**
 @Status Interoperable
*/
- (NSObject*)lastObject {
    int count = [self count];

    if (count == 0) {
        return nil;
    }

    return [self objectAtIndex:count - 1];
}

/**
 @Status Interoperable
*/
- (NSObject*)firstObject {
    int count = [self count];

    if (count == 0) {
        return nil;
    }

    return [self objectAtIndex:0];
}

/**
 @Status Interoperable
*/
- (id)objectAtIndex:(NSUInteger)index {
    // NSArray is a class cluster "interface". A concrete implementation (default or derived) MUST implement this.
    return NSInvalidAbstractInvocationReturn();
}

/**
 @Status Interoperable
*/
- (id)objectAtIndexedSubscript:(NSUInteger)index {
    return [self objectAtIndex:index];
}

/**
 @Status Interoperable
*/
- (NSUInteger)indexOfObject:(id)obj {
    return [self indexOfObject:obj inRange:NSRange{ 0, self.count }];
}

/**
 @Status Interoperable
*/
- (NSIndexSet*)indexesOfObjectsPassingTest:(BOOL (^)(id, NSUInteger, BOOL*))pred {
    return [self indexesOfObjectsWithOptions:0 passingTest:pred];
}

/**
 @Status Interoperable
*/
- (NSUInteger)indexOfObjectPassingTest:(BOOL (^)(id, NSUInteger, BOOL*))pred {
    int count = [self count];

    for (int i = 0; i < count; i++) {
        id value = [self objectAtIndex:i];
        BOOL shouldStop = false;

        if (pred(value, i, &shouldStop)) {
            return i;
        }

        if (shouldStop) {
            break;
        }
    }

    return NSNotFound;
}

/**
 @Status Interoperable
*/
- (NSUInteger)indexOfObject:(id)obj inRange:(NSRange)range {
    int count = [self count];

    for (unsigned i = range.location; i < count && i < (range.location + range.length); i++) {
        id value = [self objectAtIndex:i];
        if ([obj isEqual:value]) {
            return i;
        }
    }

    return NSNotFound;
}

/**
 @Status Interoperable
*/
- (NSUInteger)indexOfObjectIdenticalTo:(id)obj {
    return [self indexOfObjectIdenticalTo:obj inRange:NSMakeRange(0, self.count)];
}

/**
 @Status Interoperable
*/
+ (BOOL)supportsSecureCoding {
    return YES;
}

/**
 @Status Caveat
 @Notes Only supports NSKeyedArchiver NSCoder type.
*/
- (instancetype)initWithCoder:(NSCoder*)coder {
    if ([coder isKindOfClass:[NSKeyedUnarchiver class]]) {
        id array = [coder decodeObjectOfClasses:coder.allowedClasses forKey:@"NS.objects"];

        return [self initWithArray:array];
    } else {
        UNIMPLEMENTED_WITH_MSG("initWithCoder only supports NSKeyedUnarchiver coder type!");
        [self release];
        return nil;
    }
}

/**
 @Status Interoperable
*/
- (instancetype)initWithArray:(NSArray*)arrayToCopy {
    return [self initWithArray:arrayToCopy copyItems:NO];
}

/**
 @Status Interoperable
*/
- (instancetype)initWithArray:(NSArray*)arrayToCopy copyItems:(BOOL)copyFlag {
    int count = [arrayToCopy count];
    std::vector<id> objects(count);

    for (int i = 0; i < count; i++) {
        id curVal = [arrayToCopy objectAtIndex:i];

        if (copyFlag) {
            objects[i] = [[curVal copyWithZone:nil] autorelease];
        } else {
            objects[i] = curVal;
        }
    }

    return [self initWithObjects:objects.data() count:objects.size()];
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

    id ret = [NSMutableArray array];

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
- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState*)state objects:(id*)stackBuf count:(NSUInteger)maxCount {
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
- (void)makeObjectsPerformSelector:(SEL)selector {
    id enumerator = [self objectEnumerator];

    id nextObject = [enumerator nextObject];

    while (nextObject != nil) {
        [nextObject performSelector:selector];
        nextObject = [enumerator nextObject];
    }
}

/**
 @Status Interoperable
*/
- (void)setValue:(NSObject*)value forKey:(NSString*)key {
    for (NSObject* cur in self) {
        [cur setValue:value forKey:key];
    }
}

/**
 @Status Interoperable
*/
- (void)makeObjectsPerformSelector:(SEL)selector withObject:(NSObject*)obj {
    id enumerator = [self objectEnumerator];

    id nextObject = [enumerator nextObject];

    while (nextObject != nil) {
        [nextObject performSelector:selector withObject:obj];
        nextObject = [enumerator nextObject];
    }
}

/**
 @Status Interoperable
*/
- (BOOL)containsObject:(NSObject*)obj {
    for (NSObject* curObj in self) {
        if ([curObj isEqual:obj]) {
            return TRUE;
        }
    }

    return FALSE;
}

/**
 @Status Interoperable
*/
- (NSString*)componentsJoinedByString:(NSString*)str {
    id ret = [NSMutableString new];
    id enumerator = [self objectEnumerator];
    id nextObject = [enumerator nextObject];

    bool addSeparator = false;

    while (nextObject != nil) {
        if (addSeparator) {
            [ret appendString:str];
        }
        addSeparator = true;
        [ret appendString:nextObject];

        nextObject = [enumerator nextObject];
    }

    return [ret autorelease];
}

typedef NSInteger (*compFuncType)(id, id, void*);

/**
 @Status Interoperable
*/
- (NSArray*)sortedArrayUsingFunction:(compFuncType)compFunc context:(void*)context {
    NSMutableArray* ret = [NSMutableArray arrayWithArray:self];
    [ret sortUsingFunction:compFunc context:context];

    return ret;
}

/**
 @Status Interoperable
*/
- (NSArray*)sortedArrayUsingComparator:(NSComparator)comparator {
    NSMutableArray* ret = [NSMutableArray arrayWithArray:self];

    [ret sortUsingFunction:CFNSBlockCompare context:comparator];

    return ret;
}

/**
 @Status Interoperable
*/
- (NSArray*)filteredArrayUsingPredicate:(NSPredicate*)predicate {
    NSMutableArray* ret = [NSMutableArray arrayWithArray:self];
    [ret filterUsingPredicate:predicate];

    return ret;
}

/**
 @Status Interoperable
*/
- (NSObject*)mutableCopy {
    return [self mutableCopyWithZone:nil];
}

/**
 @Status Interoperable
*/
- (NSObject*)mutableCopyWithZone:(NSZone*)zone {
    return [[NSMutableArray alloc] initWithArray:self];
}

/**
 @Status Interoperable
*/
- (NSObject*)copyWithZone:(NSZone*)zone {
    return [self retain];
}

/**
 @Status Interoperable
*/
- (NSEnumerator*)objectEnumerator {
    id ret = [NSEnumerator enumeratorWithArray:self];

    return ret;
}

/**
 @Status Interoperable
*/
- (NSEnumerator*)reverseObjectEnumerator {
    return [NSEnumerator enumeratorWithArrayReverse:self];
}

/**
 @Status Interoperable
*/
- (NSArray*)sortedArrayUsingSelector:(SEL)selector {
    NSMutableArray* newArray = [NSMutableArray arrayWithArray:self];

    [newArray sortUsingSelector:selector];

    return newArray;
}

/**
 @Status Interoperable
*/
- (NSArray*)sortedArrayUsingDescriptors:(NSArray*)descriptors {
    NSMutableArray* newArray = [NSMutableArray arrayWithArray:self];

    [newArray sortUsingDescriptors:descriptors];

    return newArray;
}

/**
 @Status Interoperable
*/
- (NSArray*)subarrayWithRange:(NSRange)range {
    std::vector<id> objects;
    for (NSUInteger i = range.location; i < range.location + range.length; i++) {
        objects.push_back([self objectAtIndex:i]);
    }

    return [NSArray arrayWithObjects:objects.data() count:objects.size()];
}

/**
 @Status Interoperable
*/
- (NSObject*)firstObjectCommonWithArray:(NSArray*)array {
    int i, count = [self count];

    for (i = 0; i < count; i++) {
        id obj = [self objectAtIndex:i];

        if ([array indexOfObject:obj] != NSNotFound) {
            return obj;
        }
    }

    return nil;
}

/**
 @Status Interoperable
*/
- (NSArray*)arrayByAddingObject:(NSObject*)obj {
    std::vector<id> objects([self count] + 1);
    for (NSUInteger i = 0; i < [self count]; i++) {
        objects[i] = [self objectAtIndex:i];
    }

    objects[[self count]] = obj;

    return [NSArray arrayWithObjects:objects.data() count:objects.size()];
}

/**
 @Status Interoperable
*/
- (NSArray*)arrayByAddingObjectsFromArray:(NSArray*)arr {
    std::vector<id> objects([self count] + [arr count]);
    NSUInteger currentIndex = 0;
    for (NSUInteger i = 0; i < [self count]; i++) {
        objects[currentIndex++] = [self objectAtIndex:i];
    }

    for (NSUInteger i = 0; i < [arr count]; i++) {
        objects[currentIndex++] = [arr objectAtIndex:i];
    }

    return [NSArray arrayWithObjects:objects.data() count:objects.size()];
}

/**
 @Status Interoperable
*/
- (NSArray*)pathsMatchingExtensions:(NSArray*)extensions {
    id ret = [[NSMutableArray alloc] init];

    id arrEnum = [self objectEnumerator];
    id curObj = [arrEnum nextObject];

    int extCount = [extensions count];

    while (curObj != nil) {
        id ext = [curObj pathExtension];

        for (int i = 0; i < extCount; i++) {
            id curExt = [extensions objectAtIndex:i];

            if ([curExt isEqualToString:ext]) {
                [ret addObject:curExt];
            }
        }
        curObj = [arrEnum nextObject];
    }

    return ret;
}

// Helper that represents an NSComparator as a CFComparatorFunction
static CFComparisonResult _CFComparatorFunctionFromComparator(const void* val1, const void* val2, void* context) {
    auto comparator = *reinterpret_cast<NSComparator*>(context);
    return static_cast<CFComparisonResult>(comparator(static_cast<id>(val1), static_cast<id>(val2)));
}

/**
 @Status Interoperable
*/
- (NSUInteger)indexOfObject:(NSObject*)obj
              inSortedRange:(NSRange)range
                    options:(NSBinarySearchingOptions)options
            usingComparator:(NSComparator)comparator {
    if ((options & NSBinarySearchingFirstEqual) && (options & NSBinarySearchingLastEqual)) {
        [NSException raise:NSInvalidArgumentException
                    format:@"Both NSBinarySearchingFirstEqual and NSBinarySearchingLastEqual were specified."];
    }

    NSUInteger selfCount = [self count];

    if (range.location + range.length > selfCount) {
        [NSException raise:NSInvalidArgumentException
                    format:@"Range {%d, %d} larger than array of size %d.", range.location, range.length, selfCount];
    }

    NSUInteger index = CFArrayBSearchValues(static_cast<CFArrayRef>(self),
                                            { range.location, range.length },
                                            obj,
                                            _CFComparatorFunctionFromComparator,
                                            &comparator);

    if (index >= selfCount && (options & NSBinarySearchingInsertionIndex)) {
        return selfCount;
    }

    if ((selfCount > index) && ([[self objectAtIndex:index] isEqual:obj])) {
        if (options & NSBinarySearchingFirstEqual) {
            while (NSLocationInRange(index - 1, range)) {
                if ([[self objectAtIndex:index - 1] isEqual:obj]) {
                    --index;
                } else {
                    break;
                }
            }
        } else if (options & NSBinarySearchingLastEqual) {
            while (NSLocationInRange(index + 1, range)) {
                if ([[self objectAtIndex:index + 1] isEqual:obj]) {
                    ++index;
                } else {
                    break;
                }
            }

            if (options & NSBinarySearchingInsertionIndex) {
                // LastEqual | InsertionIndex expects a return of the index _after_ the last equal
                // This is guaranteed to be a valid index (<= [self count]) for insertObject:atIndex:
                // index is at most, range.location + range.length - 1, and
                // range.location + range.length <= [self count]
                ++index;
            }
        }

        return index;
    } else {
        if (options & NSBinarySearchingInsertionIndex) {
            return index;
        } else {
            return NSNotFound;
        }
    }
}

/**
 @Status Caveat
 @Notes atomically parameter not supported
*/
- (BOOL)writeToFile:(NSString*)file atomically:(BOOL)atomically {
    NSError* error = nil;
    NSData* data = [NSPropertyListSerialization dataWithPropertyList:self format:NSPropertyListXMLFormat_v1_0 options:0 error:&error];
    if (error != nil) {
        return NO;
    }

    return [data writeToFile:file atomically:atomically];
}

/**
 @Status Interoperable
*/
- (void)encodeWithCoder:(NSCoder*)coder {
    if ([coder isKindOfClass:[NSKeyedArchiver class]]) {
        [static_cast<NSKeyedArchiver*>(coder) _encodeArrayOfObjects:self forKey:@"NS.objects"];
    } else {
        int i, count = [self count];

        [coder encodeValueOfObjCType:"i" at:&count];
        for (i = 0; i < count; i++) {
            [coder encodeObject:[self objectAtIndex:i]];
        }
    }
}

/**
 @Status Interoperable
*/
- (NSString*)description {
    return [self descriptionWithLocale:nil];
}

/**
 @Status Interoperable
*/
- (void)getObjects:(id*)objects {
    NSUInteger i, count = [self count];

    for (i = 0; i < count; i++) {
        objects[i] = [self objectAtIndex:i];
    }
}

/**
 @Status Interoperable
*/
- (void)enumerateObjectsUsingBlock:(void (^)(id, NSUInteger, BOOL*))block {
    [self enumerateObjectsWithOptions:0 usingBlock:block];
}

/**
 @Status Interoperable
*/
- (void)enumerateObjectsWithOptions:(NSEnumerationOptions)options usingBlock:(void (^)(id, NSUInteger, BOOL*))block {
    NSIndexSet* indexSet = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [self count])];
    [self enumerateObjectsAtIndexes:indexSet options:options usingBlock:block];
}

/**
 @Status Interoperable
*/
- (void)getObjects:(id*)objects range:(NSRange)range {
    unsigned count = [self count];
    unsigned loc = range.location;

    if (range.location + range.length > count) {
        // NSRaiseException(NSRangeException,self,_cmd,@"range %@ beyond count %d",
        // NSStringFromRange(range),[self count]);
        assert(0);
    }

    for (unsigned i = 0; i < range.length; i++) {
        objects[i] = [self objectAtIndex:loc + i];
    }
}

/**
 @Status Interoperable
*/
- (BOOL)isEqual:(NSObject*)other {
    if (self == other) {
        return YES;
    }

    if (![other isKindOfClass:[NSArray class]]) {
        return NO;
    }

    return [self isEqualToArray:static_cast<NSArray*>(other)];
}

/**
 @Status Interoperable
*/
- (NSArray*)allObjects {
    return self;
}

/**
 @Status Interoperable
*/
- (BOOL)isEqualToArray:(NSArray*)otherArray {
    if ([self count] != [otherArray count]) {
        return NO;
    }

    int i, count = [self count];
    for (i = 0; i < count; i++) {
        id obj1 = [self objectAtIndex:i];
        id obj2 = [otherArray objectAtIndex:i];

        if (![obj1 isEqual:obj2]) {
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
- (NSArray*)objectsAtIndexes:(NSIndexSet*)indexes {
    unsigned idx = [indexes firstIndex];
    id ret = [NSMutableArray array];
    unsigned count = [self count];

    while (idx != NSNotFound) {
        if (idx >= count) {
            TraceCritical(TAG, L"objectsAtIndexes: index > count (%d > %d), throwing exception", idx, count);
            [NSException raise:@"Array out of bounds" format:@""];
            return nil;
        }
        [ret addObject:[self objectAtIndex:idx]];
        idx = [indexes indexGreaterThanIndex:idx];
    }
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

/**
 @Status Caveat
 @Notes This is a convenience method, no performance gains for using this over individual calls to addObserver to affected objects
*/
- (void)addObserver:(NSObject*)observer
    toObjectsAtIndexes:(NSIndexSet*)indexes
            forKeyPath:(NSString*)keyPath
               options:(NSKeyValueObservingOptions)options
               context:(void*)context {
    [indexes enumerateIndexesUsingBlock:^(NSUInteger index, BOOL* stop) {
        [[self objectAtIndex:index] addObserver:observer forKeyPath:keyPath options:options context:context];
    }];
}

/**
 @Status Caveat
 @Notes This is a convenience method, no performance gains for using this over individual calls to removeObserver to affected objects
*/
- (void)removeObserver:(NSObject*)observer fromObjectsAtIndexes:(NSIndexSet*)indexes forKeyPath:(NSString*)keyPath {
    [self removeObserver:observer fromObjectsAtIndexes:indexes forKeyPath:keyPath context:nullptr];
}

/**
 @Status Caveat
 @Notes This is a convenience method, no performance gains for using this over individual calls to removeObserver to affected objects
*/
- (void)removeObserver:(NSObject*)observer fromObjectsAtIndexes:(NSIndexSet*)indexes forKeyPath:(NSString*)keyPath context:(void*)context {
    [indexes enumerateIndexesUsingBlock:^(NSUInteger index, BOOL* stop) {
        [[self objectAtIndex:index] removeObserver:observer forKeyPath:keyPath context:context];
    }];
}

/**
 @Status Interoperable
*/
+ (NSArray*)arrayWithContentsOfURL:(NSURL*)aURL {
    return [[[self alloc] initWithContentsOfURL:aURL] autorelease];
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
- (NSString*)descriptionWithLocale:(id)locale indent:(NSUInteger)level {
    NSMutableString* ret = [NSMutableString string];
    if (level != 0) {
        [ret appendFormat:[NSString stringWithFormat:@"%%%us", sc_indentSpaces * level], " "];
    }

    [ret appendString:@"(\n"];

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

    [ret appendString:@")"];
    return ret;
}

/**
 @Status Interoperable
*/
- (void)enumerateObjectsAtIndexes:(NSIndexSet*)indexSet
                          options:(NSEnumerationOptions)opts
                       usingBlock:(void (^)(id, NSUInteger, BOOL*))block {
    [indexSet enumerateIndexesWithOptions:opts
                               usingBlock:^(NSUInteger index, BOOL* stop) {
                                   block([self objectAtIndex:index], index, stop);
                               }];
}

/**
 @Status Interoperable
*/
- (NSIndexSet*)indexesOfObjectsWithOptions:(NSEnumerationOptions)opts passingTest:(BOOL (^)(id, NSUInteger, BOOL*))predicate {
    NSIndexSet* fullRange = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, self.count)];
    return [self indexesOfObjectsAtIndexes:fullRange options:opts passingTest:predicate];
}

/**
 @Status Interoperable
*/
- (NSIndexSet*)indexesOfObjectsAtIndexes:(NSIndexSet*)indexSet
                                 options:(NSEnumerationOptions)opts
                             passingTest:(BOOL (^)(id, NSUInteger, BOOL*))predicate {
    __block NSMutableIndexSet* ret = [NSMutableIndexSet indexSet];
    [self enumerateObjectsAtIndexes:indexSet
                            options:opts
                         usingBlock:^(id element, NSUInteger index, BOOL* stop) {
                             if (predicate(element, index, stop)) {
                                 @synchronized(ret) {
                                     [ret addIndex:index];
                                 }
                             }
                         }];

    return ret;
}

/**
 @Status Interoperable
*/
- (NSArray*)initWithContentsOfURL:(NSURL*)aURL {
    NSData* data = [NSData dataWithContentsOfURL:aURL];
    return static_cast<NSArray*>(
        CFPropertyListCreateWithData(nullptr, static_cast<CFDataRef>(data), kCFPropertyListImmutable, nullptr, nullptr));
}

/**
 @Status Caveat
 @Notes Only file:// URLs supported. atomically parameter not supported.
*/
- (BOOL)writeToURL:(NSURL*)aURL atomically:(BOOL)flag {
    CFPropertyListRef plist = static_cast<CFPropertyListRef>(self);
    if (CFPropertyListIsValid(plist, sc_plistFormat)) {
        auto data = woc::MakeStrongCF<CFDataRef>(CFPropertyListCreateData(nullptr, plist, sc_plistFormat, 0, nullptr));
        if (data) {
            return [static_cast<NSData*>(data.get()) writeToURL:aURL atomically:flag];
        }
    }

    return NO;
}

/**
 @Status Caveat
 @Notes Options are currently ignored
*/
- (NSArray*)sortedArrayWithOptions:(NSSortOptions)opts usingComparator:(NSComparator)cmptr {
    NSMutableArray* ret = [NSMutableArray arrayWithArray:self];
    [ret sortWithOptions:opts usingComparator:cmptr];

    return ret;
}

/**
 @Status Stub
*/
- (NSArray*)sortedArrayUsingFunction:(NSInteger (*)(id, id, void*))comparator context:(void*)context hint:(NSData*)hint {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Interoperable
*/
- (NSUInteger)indexOfObjectIdenticalTo:(id)anObject inRange:(NSRange)range {
    if (NSMaxRange(range) > [self count]) {
        [NSException raise:NSRangeException
                    format:@"-[%s %s]: range {%d, %d} extends beyond bounds [0 .. %d]",
                           sel_getName(_cmd),
                           class_getName([self class]),
                           range.location,
                           range.length,
                           [self count]];
    }

    id objects[range.length];
    [self getObjects:objects range:range];
    for (NSUInteger i = 0; i < range.length; ++i) {
        if (objects[i] == anObject) {
            return range.location + i;
        }
    }

    return NSNotFound;
}

/**
 @Status Interoperable
*/
- (NSUInteger)indexOfObjectWithOptions:(NSEnumerationOptions)opts passingTest:(BOOL (^)(id, NSUInteger, BOOL*))predicate {
    NSIndexSet* fullRange = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, self.count)];
    return [self indexOfObjectAtIndexes:fullRange options:opts passingTest:predicate];
}

/**
 @Status Interoperable
*/
- (NSUInteger)indexOfObjectAtIndexes:(NSIndexSet*)indexSet
                             options:(NSEnumerationOptions)opts
                         passingTest:(BOOL (^)(id, NSUInteger, BOOL*))predicate {
    NSIndexSet* matching = [self indexesOfObjectsAtIndexes:indexSet
                                                   options:opts
                                               passingTest:^(id obj, NSUInteger index, BOOL* stop) {
                                                   BOOL ret = predicate(obj, index, stop);
                                                   if (ret == YES) {
                                                       *stop = YES;
                                                   }

                                                   return ret;
                                               }];
    return matching.firstIndex;
}

@end
