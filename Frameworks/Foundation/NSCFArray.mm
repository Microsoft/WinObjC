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

#include "Starboard.h"
#include "CFHelpers.h"
#include "CFFoundationInternal.h"
#include "ForFoundationOnly.h"
#include <CoreFoundation/CFArray.h>
#include "NSCFArray.h"
#include "BridgeHelpers.h"
#include "NSCFCollectionSupport.h"

static const wchar_t* TAG = L"NSArray";

static CFArrayCallBacks _NSCFArrayCallBacks = {
    0, _NSCFCallbackRetain, _NSCFCallbackRelease, _NSCFCallbackCopyDescription, _NSCFCallbackEquals,
};

@interface NSCFArray : NSMutableArray
@end

#pragma region NSArrayPrototype
@implementation NSArrayPrototype

PROTOTYPE_CLASS_REQUIRED_IMPLS(NSCFArray)

- (instancetype)init {
    return [self initWithObjects:nullptr count:0];
}

- (_Nullable instancetype)initWithObjects:(id _Nonnull const* _Nullable)objects count:(NSUInteger)count {
    return reinterpret_cast<NSArrayPrototype*>(
        static_cast<NSArray*>((CFArrayCreate(kCFAllocatorDefault, (const void**)(objects), count, &_NSCFArrayCallBacks))));
}

@end

@implementation NSMutableArrayPrototype

PROTOTYPE_CLASS_REQUIRED_IMPLS(NSCFArray)

- (instancetype)init {
    return [self initWithObjects:nullptr count:0];
}

- (_Nullable instancetype)initWithObjects:(id _Nonnull const* _Nullable)objects count:(NSUInteger)count {
    NSMutableArray* array = [self initWithCapacity:count];
    for (unsigned int i = 0; i < count; i++) {
        [array addObject:objects[i]];
    }

    return reinterpret_cast<NSMutableArrayPrototype*>(array);
}

- (_Nullable instancetype)initWithCapacity:(NSUInteger)numItems {
    return reinterpret_cast<NSMutableArrayPrototype*>((CFArrayCreateMutable(kCFAllocatorDefault, numItems, &_NSCFArrayCallBacks)));
}

@end
#pragma endregion

#pragma region NSCFArray
@implementation NSCFArray

BRIDGED_CLASS_REQUIRED_IMPLS(CFArrayRef, CFArrayGetTypeID, NSArray, NSCFArray)
BRIDGED_MUTABLE_CLASS_FOR_CODER(CFArrayRef, _CFArrayIsMutable, NSArray, NSMutableArray)

- (NSUInteger)count {
    return CFArrayGetCount((CFArrayRef)self);
}

- (id)objectAtIndex:(NSUInteger)index {
    if (index >= CFArrayGetCount((CFArrayRef)self)) {
        [NSException raise:@"Array out of bounds"
                    format:@"objectAtIndex: index > count (%lu > %lu), throwing exception\n",
                           (unsigned long)index,
                           (unsigned long)CFArrayGetCount((CFArrayRef)self)];
        return nil;
    }
    return (id)CFArrayGetValueAtIndex((CFArrayRef)self, index);
}

- (void)removeObjectAtIndex:(NSUInteger)index {
    BRIDGED_THROW_IF_IMMUTABLE(_CFArrayIsMutable, CFArrayRef);
    CFArrayRemoveValueAtIndex(static_cast<CFMutableArrayRef>(self), index);
}

- (void)removeLastObject {
    BRIDGED_THROW_IF_IMMUTABLE(_CFArrayIsMutable, CFArrayRef);
    NSUInteger count = [self count];

    if (count > 0) {
        CFArrayRemoveValueAtIndex(static_cast<CFMutableArrayRef>(self), count - 1);
    }
}

- (void)replaceObjectAtIndex:(NSUInteger)index withObject:(NSObject*)obj {
    BRIDGED_THROW_IF_IMMUTABLE(_CFArrayIsMutable, CFArrayRef);
    NS_COLLECTION_THROW_IF_NULL_REASON(obj, [NSString stringWithFormat:@"*** %@ object cannot be nil", NSStringFromSelector(_cmd)]);
    //  Fastpath
    CFRange range;
    range.location = index;
    range.length = 1;
    _CFArrayReplaceValues(static_cast<CFMutableArrayRef>(self), range, (const void**)(&obj), 1);
}

- (void)insertObject:(NSObject*)objAddr atIndex:(NSUInteger)index {
    BRIDGED_THROW_IF_IMMUTABLE(_CFArrayIsMutable, CFArrayRef);
    NS_COLLECTION_THROW_IF_NULL_REASON(objAddr, [NSString stringWithFormat:@"*** %@ object cannot be nil", NSStringFromSelector(_cmd)]);
    CFArrayInsertValueAtIndex(static_cast<CFMutableArrayRef>(self), index, reinterpret_cast<const void*>(objAddr));
}

- (void)exchangeObjectAtIndex:(NSUInteger)atIndex withObjectAtIndex:(NSUInteger)withIndex {
    BRIDGED_THROW_IF_IMMUTABLE(_CFArrayIsMutable, CFArrayRef);
    CFArrayExchangeValuesAtIndices(static_cast<CFMutableArrayRef>(self), atIndex, withIndex);
}

- (void)removeAllObjects {
    BRIDGED_THROW_IF_IMMUTABLE(_CFArrayIsMutable, CFArrayRef);
    CFArrayRemoveAllValues((CFMutableArrayRef)self);
}

- (void)addObject:(NSObject*)objAddr {
    BRIDGED_THROW_IF_IMMUTABLE(_CFArrayIsMutable, CFArrayRef);
    NS_COLLECTION_THROW_IF_NULL_REASON(objAddr, [NSString stringWithFormat:@"*** %@ object cannot be nil", NSStringFromSelector(_cmd)]);
    CFArrayAppendValue((CFMutableArrayRef)self, (const void*)objAddr);
}

- (NSObject*)copyWithZone:(NSZone*)zone {
    if (_CFArrayIsMutable((CFMutableArrayRef)self)) {
        return (NSObject*)CFArrayCreateCopy(kCFAllocatorDefault, (CFArrayRef)self);
    }

    return [self retain];
}

- (NSObject*)mutableCopyWithZone:(NSZone*)zone {
    return (NSObject*)CFArrayCreateMutableCopy(kCFAllocatorDefault, 0, (CFArrayRef)self);
}

- BRIDGED_COLLECTION_FAST_ENUMERATION(CFArray);

@end
#pragma endregion
