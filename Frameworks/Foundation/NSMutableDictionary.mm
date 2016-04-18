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
#include "StubReturn.h"
#include "Foundation/NSDictionary.h"
#include "Foundation/NSMutableDictionary.h"
#include "CoreFoundation/CFDictionary.h"

@implementation NSMutableDictionary
/**
 @Status Interoperable
*/
+ (instancetype)dictionary {
    return [[self new] autorelease];
}

/**
 @Status Interoperable
*/
+ (instancetype)dictionaryWithCapacity:(unsigned)capacity {
    return [[[self alloc] initWithCapacity:capacity] autorelease];
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
- (instancetype)init {
    return [super init];
}

/**
 @Status Interoperable
*/
- (instancetype)initWithCapacity:(unsigned)capacity {
    return [self init];
}

/**
 @Status Interoperable
*/
- (void)setValue:(id)value forKey:(NSString*)key {
    if (value != nil) {
        [self setObject:value forKey:key];
    } else {
        [self removeObjectForKey:key];
    }
}

/**
 @Status Interoperable
*/
- (void)removeObjectForKey:(id)key {
    CFDictionaryRemoveValue((CFMutableDictionaryRef)self, (void*)key);
}

/**
 @Status Interoperable
*/
- (void)removeAllObjects {
    CFDictionaryRemoveAllValues((CFMutableDictionaryRef)self);
}

/**
 @Status Interoperable
*/
- (void)removeObjectsForKeys:(NSArray*)keys {
    NSEnumerator* enumerator = [keys objectEnumerator];

    id curKey = [enumerator nextObject];

    while (curKey != nil) {
        [self removeObjectForKey:curKey];

        curKey = [enumerator nextObject];
    }
}

/**
 @Status Interoperable
*/
- (void)setObject:(id)object forKey:(id)key {
    key = [key copy];
    CFDictionarySetValue((CFMutableDictionaryRef)self, (const void*)key, (void*)object);
    [key release];
}

/**
 @Status Interoperable
*/
- (void)setObject:(id)object forKeyedSubscript:(id)key {
    [self setObject:object forKey:key];
}

/**
 @Status Interoperable
*/
- (void)addEntriesFromDictionary:(NSDictionary*)otherDict {
    for (id curKey in otherDict) {
        id obj = [otherDict objectForKey:curKey];
        [self setObject:obj forKey:curKey];
    }
}

/**
 @Status Interoperable
*/
- (void)addEntriesFromDictionaryNoReplace:(NSDictionary*)otherDict {
    for (id curKey in otherDict) {
        if ([self objectForKey:curKey] == nil) {
            id obj = [otherDict objectForKey:curKey];
            [self setObject:obj forKey:curKey];
        }
    }
}

/**
 @Status Interoperable
*/
- (void)setDictionary:(NSDictionary*)otherDict {
    [self removeAllObjects];
    [self addEntriesFromDictionary:otherDict];
}

/**
 @Status Interoperable
*/
- (Class)classForCoder {
    return [NSMutableDictionary class];
}

/**
 @Status Interoperable
*/
- (id)copyWithZone:(NSZone*)zone {
    return [[NSDictionary alloc] initWithDictionary:self];
}

/**
 @Status Stub
 @Notes
*/
+ (NSMutableDictionary*)dictionaryWithSharedKeySet:(id)keyset {
    UNIMPLEMENTED();
    return StubReturn();
}

@end
