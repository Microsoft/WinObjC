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
#import "NSEnumeratorInternal.h"
#import "CoreFoundation/CFDictionary.h"
#import "Foundation/NSMutableDictionary.h"
#import "Foundation/NSString.h"
#import "Foundation/NSData.h"
#import "Foundation/NSEnumerator.h"
#import "Foundation/NSMutableArray.h"
#import "Foundation/NSKeyedArchiver.h"
#import "LoggingNative.h"
#import "NSKeyedArchiverInternal.h"
#import "VAListHelper.h"
#import "NSCFDictionary.h"
#import "NSRaise.h"
#import "BridgeHelpers.h"
#import <_NSKeyValueCodingAggregateFunctions.h>

static const wchar_t* TAG = L"NSDictionary";

@class NSPropertyListSerialization;

struct SortedKeysHelperCtx {
    id dict;
    SEL sel;
    id comparator;
};

static int _NSDict_SortedKeysHelper(id key1, id key2, void* context) {
    SortedKeysHelperCtx* ctx = (SortedKeysHelperCtx*)context;
    id obj1 = [ctx->dict objectForKey:key1];
    id obj2 = [ctx->dict objectForKey:key2];

    if (ctx->sel != NULL) {
        int ret = (int)[obj1 performSelector:ctx->sel withObject:obj2];
        return ret;
    } else {
        int ret = (int)CFNSBlockCompare(obj1, obj2, ctx->comparator);

        return ret;
    }
}

@interface NSDictionaryValueEnumerator : NSEnumerator
- (instancetype)initWithDictionary:(NSDictionary*)dictionary;
@property (readonly, copy) NSArray* allObjects;
- (id)nextObject;
@end

@implementation NSDictionaryValueEnumerator {
@public
    StrongId<NSEnumerator> _keyEnumerator;
    StrongId<NSDictionary> _dictionary;
}

- (instancetype)initWithDictionary:(NSDictionary*)dictionary {
    if (self = [super init]) {
        _keyEnumerator = [dictionary keyEnumerator];
        _dictionary = dictionary;
    }
    return self;
}

- (id)nextObject {
    if (_keyEnumerator == nil) {
        return nil;
    }

    id key = [_keyEnumerator nextObject];

    if (key == nil) {
        _keyEnumerator = nil;
        _dictionary = nil;
    }

    return [_dictionary objectForKey:key];
}

- (NSArray*)allObjects {
    if (_keyEnumerator == nil) {
        return nil;
    }

    NSMutableArray* toRet = [NSMutableArray array];

    for (id key in static_cast<NSEnumerator*>(_keyEnumerator)) {
        [toRet addObject:[_dictionary objectForKey:key]];
    }

    return toRet;
}

@end

@implementation NSDictionary

BASE_CLASS_REQUIRED_IMPLS(NSDictionary, NSDictionaryPrototype, CFDictionaryGetTypeID);

/**
 @Status Interoperable
*/
+ (instancetype)dictionaryWithObjectsAndKeys:(id)firstObj, ... {
    va_list argList;
    va_start(argList, firstObj);
    std::vector<id> flatArgs = ConvertVAListToVector((id)firstObj, argList);
    va_end(argList);

    // Need to split the arg list into keys and values.
    std::vector<id> values(flatArgs.size() / 2);
    std::vector<id> keys(flatArgs.size() / 2);

    for (unsigned int i = 0; i < flatArgs.size(); i++) {
        if (i % 2 == 0) {
            values[(i / 2)] = flatArgs[i];
        } else {
            keys[(i / 2)] = flatArgs[i];
        }
    }

    return [[[self alloc] initWithObjects:values.data() forKeys:keys.data() count:values.size()] autorelease];
}

/**
 @Status Interoperable
*/
+ (instancetype)dictionaryWithObjects:(id const*)vals forKeys:(id<NSCopying> const*)keys count:(unsigned)count {
    return [[[self alloc] initWithObjects:vals forKeys:keys count:count] autorelease];
}

/**
 @Status Interoperable
*/
- (instancetype)initWithObjects:(id _Nonnull const*)vals forKeys:(id<NSCopying> _Nonnull const*)keys count:(unsigned)count {
    // Derived classes are required to implement this initializer.
    return NSInvalidAbstractInvocationReturn();
}

/**
 @Status Interoperable
*/
+ (instancetype)dictionaryWithObject:(id)val forKey:(id)key {
    return [[[self alloc] initWithObjects:&val forKeys:&key count:1] autorelease];
}

/**
 @Status Interoperable
*/
+ (instancetype)dictionaryWithDictionary:(NSDictionary*)dictionary {
    return [[[self alloc] initWithDictionary:dictionary] autorelease];
}

/**
 @Status Interoperable
*/
+ (instancetype)dictionaryWithObjects:(NSArray*)vals forKeys:(NSArray*)keys {
    return [[[self alloc] initWithObjects:vals forKeys:keys] autorelease];
}

/**
 @Status Interoperable
*/
- (instancetype)initWithObjectsAndKeys:(id)firstObj, ... {
    va_list argList;
    va_start(argList, firstObj);
    std::vector<id> flatArgs = ConvertVAListToVector((id)firstObj, argList);
    va_end(argList);

    // Need to split the arg list into keys and values.
    std::vector<id> values(flatArgs.size() / 2);
    std::vector<id> keys(flatArgs.size() / 2);

    for (unsigned int i = 0; i < flatArgs.size(); i++) {
        if (i % 2 == 0) {
            values[(i / 2)] = flatArgs[i];
        } else {
            keys[(i / 2)] = flatArgs[i];
        }
    }

    return [self initWithObjects:values.data() forKeys:keys.data() count:values.size()];
}

/**
 @Status Interoperable
*/
- (instancetype)initWithObjects:(id)vals forKeys:(id)keys {
    int count = [vals count];

    std::vector<id> flatValues(count);
    std::vector<id> flatKeys(count);

    for (int i = 0; i < count; i++) {
        flatValues[i] = [vals objectAtIndex:i];
        flatKeys[i] = [keys objectAtIndex:i];
    }

    return [self initWithObjects:flatValues.data() forKeys:flatKeys.data() count:flatValues.size()];
}

/**
 @Status Interoperable
*/
- (instancetype)initWithObject:(id)val forKey:(id)key {
    return [self initWithObjects:&val forKeys:&key count:1];
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
- (id)initWithCoder:(NSCoder*)coder {
    NSArray* keys = [coder decodeObjectOfClasses:coder.allowedClasses forKey:@"NS.keys"];
    NSArray* values = [coder decodeObjectOfClasses:coder.allowedClasses forKey:@"NS.objects"];

    return [self initWithObjects:values forKeys:keys];
}

/**
 @Status Interoperable
*/
- (id)objectForKey:(id)key {
    // NSDictionary is a class cluster "interface". A concrete implementation (default or derived) MUST implement this.
    return NSInvalidAbstractInvocationReturn();
}

/**
 @Status Interoperable
*/
- (id)objectForKeyedSubscript:(id)key {
    return [self objectForKey:key];
}

/**
 @Status Interoperable
*/
- (id)valueForKey:(id)key {
    const char* keyName = (const char*)[key UTF8String];

    if ([key hasPrefix:@"@"]) {
        SEL sel = [_NSKeyValueCodingAggregateFunctions resolveFunction:[key substringFromIndex:1]];
        if (!sel) {
            return [self valueForUndefinedKey:key];
        }

        return [[_NSKeyValueCodingAggregateFunctions class] performSelector:sel withObject:self];
    }

    id ret = [self objectForKey:key];

    return ret;
}

/**
 @Status Interoperable
*/
- (instancetype)initWithDictionary:(NSDictionary*)dictionary {
    return [self initWithDictionary:dictionary copyItems:false];
}

/**
 @Status Interoperable
*/
- (NSDictionary*)initWithDictionary:(NSDictionary*)dictionary copyItems:(BOOL)copyItems {
    NSUInteger count = [dictionary count];

    std::vector<id> keys(count);
    std::vector<id> values(count);

    NSEnumerator* enumerator = [dictionary keyEnumerator];
    id curKey = [enumerator nextObject];

    unsigned int numPairs = 0;
    while (curKey != nil) {
        id curObj = [dictionary objectForKey:curKey];

        assert(numPairs <= count);
        keys[numPairs] = curKey;

        if (copyItems) {
            values[numPairs] = [[curObj copyWithZone:nil] autorelease];
        } else {
            values[numPairs] = curObj;
        }

        numPairs++;

        curKey = [enumerator nextObject];
    }

    assert(numPairs == count);

    return [self initWithObjects:values.data() forKeys:keys.data() count:keys.size()];
}

/**
 @Status Interoperable
*/
- (NSDictionary*)initWithContentsOfFile:(NSString*)filename {
    if (filename == nil) {
        TraceVerbose(TAG, L"initWithContentsOfFile: nil!");
        [self release];
        return nil;
    }

    NSData* data = [NSData dataWithContentsOfFile:filename];

    NSDictionary* deserializedDict = nil;
    if (data) {
        deserializedDict = [NSPropertyListSerialization
            propertyListFromData:data
                mutabilityOption:[self isKindOfClass:[NSMutableDictionary class]] ? NSPropertyListMutableContainersAndLeaves :
                                                                                    NSPropertyListImmutable
                          format:0
                errorDescription:0];
    }

    if (deserializedDict && [deserializedDict isKindOfClass:[NSDictionary class]]) {
        //  Steal its dictionary
        return [self initWithDictionary:deserializedDict];
    } else {
        TraceError(TAG, L"Error deserializing NSDictionary");
        [self release];
        return nil;
    }
}

/**
 @Status Interoperable
*/
+ (NSDictionary*)dictionaryWithContentsOfFile:(NSString*)filename {
    return [[[self alloc] initWithContentsOfFile:filename] autorelease];
}

/**
 @Status Caveat
 @Notes Only file:// URLs supported
*/
+ (NSDictionary*)dictionaryWithContentsOfURL:(NSURL*)url {
    NSData* data = [NSData dataWithContentsOfURL:url];
    if (data == nil) {
        return nil;
    }

    return [NSPropertyListSerialization
        propertyListFromData:data
            mutabilityOption:[self isKindOfClass:[NSMutableDictionary class]] ? NSPropertyListMutableContainersAndLeaves :
                                                                                NSPropertyListImmutable
                      format:0
            errorDescription:0];
}

/**
 @Status Caveat
 @Notes Only file:// URLs supported
*/
- (NSDictionary*)initWithContentsOfURL:(id)url {
    NSData* data = [NSData dataWithContentsOfURL:url];

    NSDictionary* dictionary = nil;
    if (data) {
        dictionary = [NSPropertyListSerialization
            propertyListFromData:data
                mutabilityOption:[self isKindOfClass:[NSMutableDictionary class]] ? NSPropertyListMutableContainersAndLeaves :
                                                                                    NSPropertyListImmutable
                          format:0
                errorDescription:0];
    }

    return [self initWithDictionary:dictionary];
}

/**
 @Status Interoperable
*/
+ (NSDictionary*)dictionary {
    NSDictionary* ret = [NSDictionary new];

    return [ret autorelease];
}

/**
 @Status Interoperable
*/
- (NSArray*)allValues {
    unsigned count = [self count];

    if (count == 0) {
        return [NSArray array];
    }

    std::vector<id> values(count);
    id state = [self keyEnumerator];
    id key;
    unsigned i;
    for (i = 0; (key = [state nextObject]) != nil; i++) {
        assert(i < count);
        values[i] = [self objectForKey:key];
    }
    assert(i == count);

    return [NSArray arrayWithObjects:values.data() count:values.size()];
}

/**
 @Status Interoperable
*/
- (NSArray*)allKeys {
    unsigned count = [self count];

    if (count == 0) {
        return [NSArray array];
    }

    std::vector<id> keys(count);
    id state = [self keyEnumerator];
    id key;
    int i;

    for (i = 0; (key = [state nextObject]) != nil; i++) {
        assert(i < count);
        keys[i] = key;
    }
    assert(i == count);

    return [NSArray arrayWithObjects:keys.data() count:keys.size()];
}

/**
 @Status Interoperable
*/
- (NSArray*)allKeysForObject:(id)obj {
    NSEnumerator* keyEnum = [self keyEnumerator];
    NSEnumerator* valEnum = [self objectEnumerator];

    //  Grab all keys and toss 'em into an array if isEqual returns true
    unsigned numKeys = [self count];
    id* values = (id*)calloc(numKeys, sizeof(id));
    unsigned numValues = 0;

    id curKey = [keyEnum nextObject];
    id curValue = [valEnum nextObject];
    while (curKey != nil) {
        assert(numValues <= numKeys);

        if ([curValue isEqual:obj] == TRUE) {
            values[numValues++] = curKey;
        }

        curKey = [keyEnum nextObject];
        curValue = [valEnum nextObject];
    }

    NSArray* ret = [NSArray arrayWithObjects:values count:numValues];
    free(values);

    return ret;
}

/**
 @Status Interoperable
*/
- (unsigned)count {
    // NSDictionary is a class cluster "interface". A concrete implementation (default or derived) MUST implement this.
    return NSInvalidAbstractInvocationReturn();
}

/**
 @Status Interoperable
*/
- (unsigned)countByEnumeratingWithState:(NSFastEnumerationState*)state objects:(id*)stackBuf count:(unsigned)maxCount {
    if (state->state == 0) {
        state->mutationsPtr = (unsigned long*)&state->extra[1];
        state->extra[0] = (unsigned long)[self keyEnumerator];
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
- (NSEnumerator*)objectEnumerator {
    return [[NSDictionaryValueEnumerator alloc] initWithDictionary:self];
}

/**
 @Status Interoperable
*/
- (NSEnumerator*)keyEnumerator {
    // NSDictionary is a class cluster "interface". A concrete implementation (default or derived) MUST implement this.
    return NSInvalidAbstractInvocationReturn();
}

/**
 @Status Interoperable
*/
- (Class)classForCoder {
    return [NSDictionary class];
}

/**
 @Status Interoperable
*/
- (void)encodeWithCoder:(NSCoder*)coder {
    if ([coder isKindOfClass:[NSKeyedArchiver class]]) {
        [static_cast<NSKeyedArchiver*>(coder) _encodeArrayOfObjects:[self allKeys] forKey:@"NS.keys"];
        [static_cast<NSKeyedArchiver*>(coder) _encodeArrayOfObjects:[self allValues] forKey:@"NS.objects"];
    } else {
        NSEnumerator* state = [self keyEnumerator];
        unsigned count = [self count];

        assert(0);

        /*
        id key;
        coder)"encodeValueOfObjCType:", @encode(int) at:&count];

        while((key=[state nextObject])!=nil){
        id value=[self objectForKey:key];

        [coder encodeObject:key];
        [coder encodeObject:value];
        }
        */
    }
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
- (NSMutableDictionary*)mutableCopyWithZone:(NSZone*)zone {
    return [[NSMutableDictionary alloc] initWithDictionary:self];
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
- (BOOL)isEqual:(id)other {
    if (self == other) {
        return YES;
    }

    if (![other isKindOfClass:[NSDictionary class]]) {
        return NO;
    }

    return [self isEqualToDictionary:other];
}

/**
 @Status Interoperable
*/
- (BOOL)isEqualToDictionary:(NSDictionary*)dictionary {
    id key;

    if (self == dictionary) {
        return YES;
    }

    if ([self count] != [dictionary count]) {
        return NO;
    }

    NSEnumerator* keys = [self keyEnumerator];
    while ((key = [keys nextObject]) != nil) {
        id value = [self objectForKey:key];
        id otherValue = [dictionary objectForKey:key];

        if (otherValue == nil) {
            return NO;
        }
        if (![value isEqual:otherValue]) {
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
- (NSArray*)keysSortedByValueUsingSelector:(SEL)selector {
    SortedKeysHelperCtx ctx;

    ctx.dict = self;
    ctx.sel = selector;
    ctx.comparator = 0;

    return [[self allKeys] sortedArrayUsingFunction:_NSDict_SortedKeysHelper context:&ctx];
}

/**
 @Status Interoperable
*/
- (NSArray*)keysSortedByValueUsingComparator:(NSComparator)comparator {
    SortedKeysHelperCtx ctx;

    ctx.dict = self;
    ctx.comparator = comparator;
    ctx.sel = NULL;

    return [[self allKeys] sortedArrayUsingFunction:_NSDict_SortedKeysHelper context:&ctx];
}

/**
 @Status Interoperable
*/
- (NSArray*)keysSortedByValueWithOptions:(NSSortOptions)opts usingComparator:(NSComparator)cmptr {
    NSMutableArray* ret = [[[self allKeys] mutableCopy] autorelease];
    [ret sortWithOptions:opts
         usingComparator:^NSComparisonResult(id key1, id key2) {
             id val1 = [self objectForKey:key1];
             id val2 = [self objectForKey:key2];
             return cmptr(val1, val2);
         }];

    return ret;
}

/**
 @Status Interoperable
*/
- (NSString*)description {
    return [self descriptionWithLocale:nil indent:0];
}

/**
 @Status Stub
*/
- (NSString*)stringFromQueryComponents {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Interoperable
*/
- (void)getObjects:(id*)objects andKeys:(id*)keys {
    NSEnumerator* state = [self keyEnumerator];
    id key;
    NSInteger i;

    for (i = 0; (key = [state nextObject]) != nil; i++) {
        id value = [self objectForKey:key];

        if (objects) {
            objects[i] = value;
        }

        if (keys) {
            keys[i] = key;
        }
    }
}

/**
 @Status Interoperable
*/
- (void)enumerateKeysAndObjectsUsingBlock:(void (^)(id, id, BOOL*))block {
    [self enumerateKeysAndObjectsWithOptions:0 usingBlock:block];
}

/**
 @Status Interoperable
 @Notes NSEnumerationReverse is undefined on the reference platform so we will ignore it
*/
- (void)enumerateKeysAndObjectsWithOptions:(NSEnumerationOptions)options usingBlock:(void (^)(id, id, BOOL*))block {
    _enumerateWithBlock([self keyEnumerator], options, ^(id key, BOOL* stop) {
        id value = [self objectForKey:key];
        block(key, value, stop);
    });
}

/**
 @Status Interoperable
*/
- (NSArray*)objectsForKeys:(NSArray*)keys notFoundMarker:(id)notFoundMarker {
    NSMutableArray* result = [NSMutableArray arrayWithCapacity:[keys count]];
    NSInteger count = [keys count];

    for (id curkey in keys) {
        id object = [self objectForKey:curkey];

        if (object == nil) {
            object = notFoundMarker;
        }

        [result addObject:object];
    }

    return result;
}

/**
 @Status Interoperable
*/
- (NSSet*)keysOfEntriesPassingTest:(BOOL (^)(id, id, BOOL*))predicate {
    return [self keysOfEntriesWithOptions:0 passingTest:predicate];
}

/**
 @Status Interoperable
*/
- (NSSet*)keysOfEntriesWithOptions:(NSEnumerationOptions)options passingTest:(BOOL (^)(id, id, BOOL*))predicate {
    __block NSMutableSet* ret = [NSMutableSet setWithCapacity:[self count]];
    [self enumerateKeysAndObjectsWithOptions:options
                                  usingBlock:^(id key, id obj, BOOL* stop) {
                                      if (predicate(key, obj, stop)) {
                                          @synchronized(ret) {
                                              [ret addObject:key];
                                          }
                                      }
                                  }];

    return ret;
}

/**
 @Status Caveat
 @Notes atomically parameter not supported
*/
- (BOOL)writeToURL:(NSURL*)url atomically:(BOOL)atomically {
    NSError* error = nil;
    NSData* data = [NSPropertyListSerialization dataWithPropertyList:self format:NSPropertyListXMLFormat_v1_0 options:0 error:&error];
    if (error != nil) {
        return NO;
    }

    return [data writeToURL:url atomically:atomically];
}

/**
 @Status Stub
 @Notes
*/
- (NSString*)descriptionWithLocale:(id)locale {
    return [self descriptionWithLocale:locale indent:0];
}

/**
 @Status Interoperable
*/
- (NSString*)descriptionWithLocale:(id)locale indent:(NSUInteger)level {
    NSMutableString* ret = [NSMutableString new];
    if (level != 0) {
        [ret appendFormat:[NSString stringWithFormat:@"%%%us", sc_indentSpaces * level], " "];
    }

    [ret appendString:@"{\n"];

    {
        ++level;
        auto deferPop = wil::ScopeExit([&level]() { --level; });

        // Documentation specifies that output should be sorted by key using -[compare:] for NSString* keys
        // Order is undefined if keys aren't NSString so just return ascending
        NSArray* sortedKeys = [[self allKeys] sortedArrayUsingFunction:[](id key1, id key2, void* context) {
            return ([key1 isKindOfClass:[NSString class]] && [key2 isKindOfClass:[NSString class]]) ? [key1 compare:key2] :
                                                                                                      NSOrderedAscending;
        }
                                                               context:nullptr];

        for (id key in sortedKeys) {
            [ret appendFormat:[NSString stringWithFormat:@"%%%us%%@ = %%@;\n", sc_indentSpaces * level],
                              " ",
                              _descriptionForCollectionElement(key, locale, level),
                              _descriptionForCollectionElement([self objectForKey:key], locale, level)];
        }
    }

    if (level != 0) {
        [ret appendFormat:[NSString stringWithFormat:@"%%%us", sc_indentSpaces * level], " "];
    }

    [ret appendString:@"}"];
    return [ret autorelease];
}

/**
 @Status NotInPlan
 @Notes Method relies on implementation-specific optimization which will not necessarily translate to WinObjC
*/
+ (id)sharedKeySetForKeys:(NSArray*)keys {
    UNIMPLEMENTED();
    return StubReturn();
}

@end

/**
 @Status Interoperable
*/
NSDictionary* _NSDictionaryOfVariableBindings(NSString* keys, ...) {
    if (keys == nil) {
        TraceVerbose(TAG, L"Nil keys string.");
        return nil;
    }
    NSArray* keyArray = [keys componentsSeparatedByString:@", "];
    NSMutableArray* values = [[NSMutableArray new] autorelease];

    va_list va;

    va_start(va, keys);

    id value = va_arg(va, id);
    while (value != nil) {
        [values addObject:value];
        value = va_arg(va, id);
    }
    va_end(va);

    if ([values count] != [keyArray count]) {
        TraceVerbose(TAG, L"Number of keys does not match the number of objects; nil is not a valid variable\n");
        return nil;
    }

    return [NSDictionary dictionaryWithObjects:values forKeys:keyArray];
}
