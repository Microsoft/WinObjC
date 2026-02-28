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
#include "StubReturn.h"
#include "CFHelpers.h"
#include "CFFoundationInternal.h"
#include "NSCFSet.h"
#include "NSCFCollectionSupport.h"
#include <CoreFoundation/CFSet.h>
#include <vector>

static CFSetCallBacks _NSCFSetCallBacks = {
    0, _NSCFCallbackRetain, _NSCFCallbackRelease, _NSCFCallbackCopyDescription, _NSCFCallbackEquals, _NSCFCallbackHash,
};

@interface NSCFSet : NSMutableSet
@end

#pragma region NSSetPrototype
@implementation NSSetPrototype

PROTOTYPE_CLASS_REQUIRED_IMPLS(NSCFSet)

- (_Nullable instancetype)init {
    return [self initWithObjects:nullptr count:0];
}

- (_Nullable instancetype)initWithObjects:(id _Nonnull const*)objs count:(NSUInteger)count {
    return reinterpret_cast<NSSetPrototype*>(
        static_cast<NSSet*>((CFSetCreate(kCFAllocatorDefault, (const void**)(objs), count, &_NSCFSetCallBacks))));
}

@end

#pragma endregion

#pragma region NSMutableSetPrototype

@implementation NSMutableSetPrototype

PROTOTYPE_CLASS_REQUIRED_IMPLS(NSCFSet)

- (_Nullable instancetype)init {
    return [self initWithObjects:nullptr count:0];
}

- (_Nullable instancetype)initWithObjects:(id _Nonnull const*)objs count:(NSUInteger)count {
    NSMutableSet* set = [self initWithCapacity:count];
    for (unsigned i = 0; i < count; i++) {
        [set addObject:objs[i]];
    }

    return reinterpret_cast<NSMutableSetPrototype*>(set);
}

- (_Nullable instancetype)initWithCapacity:(NSUInteger)numItems {
    return reinterpret_cast<NSMutableSetPrototype*>((CFSetCreateMutable(kCFAllocatorDefault, numItems, &_NSCFSetCallBacks)));
}

@end
#pragma endregion

#pragma region NSCF Bridged Class
@implementation NSCFSet

BRIDGED_CLASS_REQUIRED_IMPLS(CFSetRef, CFSetGetTypeID, NSSet, NSCFSet)
BRIDGED_MUTABLE_CLASS_FOR_CODER(CFSetRef, _CFSetIsMutable, NSSet, NSMutableSet)

- (unsigned)count {
    return CFSetGetCount(static_cast<CFSetRef>(self));
}

- (NSEnumerator*)objectEnumerator {
    std::vector<id> values([self count]);
    CFSetGetValues(static_cast<CFSetRef>(self), (const void**)values.data());

    return [[NSArray arrayWithObjects:values.data() count:values.size()] objectEnumerator];
}

- (id)member:(id)object {
    if (object == nil) {
        return nil;
    }

    id objectToReturn = nil;

    if (CFSetGetValueIfPresent(static_cast<CFSetRef>(self), (void*)object, (const void**)&objectToReturn)) {
        return objectToReturn;
    }

    return nil;
}

- (void)addObject:(id)object {
    BRIDGED_THROW_IF_IMMUTABLE(_CFSetIsMutable, CFSetRef);
    NS_COLLECTION_THROW_IF_NULL_REASON(object, [NSString stringWithFormat:@"*** %@ object cannot be nil", NSStringFromSelector(_cmd)]);
    CFSetAddValue(static_cast<CFMutableSetRef>(self), object);
}

- (void)removeObject:(id)object {
    BRIDGED_THROW_IF_IMMUTABLE(_CFSetIsMutable, CFSetRef);
    CFSetRemoveValue(static_cast<CFMutableSetRef>(self), object);
}

- (void)removeAllObjects {
    BRIDGED_THROW_IF_IMMUTABLE(_CFSetIsMutable, CFSetRef);
    CFSetRemoveAllValues(static_cast<CFMutableSetRef>(self));
}

- (NSObject*)copyWithZone:(NSZone*)zone {
    if (_CFSetIsMutable((CFSetRef)self)) {
        return (NSObject*)CFSetCreateCopy(kCFAllocatorDefault, (CFSetRef)self);
    }

    return [self retain];
}

- (NSObject*)mutableCopyWithZone:(NSZone*)zone {
    return (NSObject*)CFSetCreateMutableCopy(kCFAllocatorDefault, 0, (CFSetRef)self);
}

- BRIDGED_COLLECTION_FAST_ENUMERATION(CFSet);

@end
#pragma endregion
