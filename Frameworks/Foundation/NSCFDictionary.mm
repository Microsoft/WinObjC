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
#include "NSCFDictionary.h"
#include "NSCFCollectionSupport.h"
#include <Foundation/NSDictionary.h>
#include <CoreFoundation/CFDictionary.h>
#include <vector>

static const wchar_t* TAG = L"NSDictionary";

static CFDictionaryKeyCallBacks _NSCFDictionaryKeyCallBacks = {
    0, _NSCFCallbackCopy, _NSCFCallbackRelease, _NSCFCallbackCopyDescription, _NSCFCallbackEquals, _NSCFCallbackHash,
};

static CFDictionaryValueCallBacks _NSCFDictionaryValueCallBacks = {
    0, _NSCFCallbackRetain, _NSCFCallbackRelease, _NSCFCallbackCopyDescription, _NSCFCallbackEquals,
};

@interface NSCFDictionary : NSMutableDictionary
@end

#pragma region NSDictionaryPrototype
@implementation NSDictionaryPrototype

PROTOTYPE_CLASS_REQUIRED_IMPLS(NSCFDictionary)

- (_Nullable instancetype)init {
    return [self initWithObjects:nullptr forKeys:nullptr count:0];
}

- (_Nullable instancetype)initWithObjects:(const id*)vals forKeys:(const id<NSCopying> _Nonnull[])keys count:(NSUInteger)count {
    NSDictionary* dictionary = static_cast<NSDictionary*>(CFDictionaryCreate(kCFAllocatorDefault,
                                                                             (const void**)(keys),
                                                                             (const void**)(vals),
                                                                             count,
                                                                             &_NSCFDictionaryKeyCallBacks,
                                                                             &_NSCFDictionaryValueCallBacks));

    return reinterpret_cast<NSDictionaryPrototype*>(dictionary);
}

@end
#pragma endregion

#pragma region NSMutableDictionaryPrototype
@implementation NSMutableDictionaryPrototype

PROTOTYPE_CLASS_REQUIRED_IMPLS(NSCFDictionary)

- (_Nullable instancetype)init {
    return [self initWithCapacity:0];
}

- (_Nullable instancetype)initWithObjects:(const id*)vals forKeys:(const id<NSCopying> _Nonnull[])keys count:(NSUInteger)count {
    NSMutableDictionary* dictionary = [self initWithCapacity:count];
    for (unsigned i = 0; i < count; i++) {
        [dictionary setObject:vals[i] forKey:keys[i]];
    }

    return reinterpret_cast<NSMutableDictionaryPrototype*>(dictionary);
}

- (_Nullable instancetype)initWithCapacity:(NSUInteger)numItems {
    return reinterpret_cast<NSMutableDictionaryPrototype*>(
        CFDictionaryCreateMutable(kCFAllocatorDefault, numItems, &_NSCFDictionaryKeyCallBacks, &_NSCFDictionaryValueCallBacks));
}

@end
#pragma endregion

#pragma region NSCF Bridged Class
@implementation NSCFDictionary

BRIDGED_CLASS_REQUIRED_IMPLS(CFDictionaryRef, CFDictionaryGetTypeID, NSDictionary, NSCFDictionary)
BRIDGED_MUTABLE_CLASS_FOR_CODER(CFDictionaryRef, _CFDictionaryIsMutable, NSDictionary, NSMutableDictionary)

- (id)objectForKey:(id)key {
    if (key == nil) {
        TraceWarning(TAG, L"Warning: objectForKey called with nil\n");
        return nil;
    }

    return (id)CFDictionaryGetValue((CFDictionaryRef)self, (const void*)key);
}

- (NSUInteger)count {
    return CFDictionaryGetCount((CFDictionaryRef)self);
}

- (NSEnumerator*)keyEnumerator {
    // This snapshots the keys at this moment,
    // but mutation during enumeration is considered invalid, so it should be okay.
    return [[self allKeys] objectEnumerator];
}

- (void)setObject:(id)object forKey:(id)key {
    BRIDGED_THROW_IF_IMMUTABLE(_CFDictionaryIsMutable, CFDictionaryRef);
    NS_COLLECTION_THROW_IF_NULL_REASON(object,
                                       [NSString
                                           stringWithFormat:@"*** %@ object cannot be nil (key: %@)", NSStringFromSelector(_cmd), key]);
    CFDictionarySetValue((CFMutableDictionaryRef)self, (const void*)key, (void*)object);
}

- (void)removeObjectForKey:(id)key {
    BRIDGED_THROW_IF_IMMUTABLE(_CFDictionaryIsMutable, CFDictionaryRef);
    CFDictionaryRemoveValue((CFMutableDictionaryRef)self, (void*)key);
}

- (void)removeAllObjects {
    BRIDGED_THROW_IF_IMMUTABLE(_CFDictionaryIsMutable, CFDictionaryRef);
    CFDictionaryRemoveAllValues((CFMutableDictionaryRef)self);
}

- (NSArray*)allValues {
    int count = CFDictionaryGetCount(static_cast<CFDictionaryRef>(self));

    if (count == 0) {
        return [NSArray array];
    }

    std::vector<id> values(count);
    CFDictionaryGetKeysAndValues((CFDictionaryRef)self, nullptr, (const void**)values.data());

    return [NSArray arrayWithObjects:values.data() count:values.size()];
}

- (NSArray*)allKeys {
    int count = CFDictionaryGetCount(static_cast<CFDictionaryRef>(self));

    if (count == 0) {
        return [NSArray array];
    }

    std::vector<id> keys(count);
    CFDictionaryGetKeysAndValues((CFDictionaryRef)self, (const void**)keys.data(), nullptr);

    return [NSArray arrayWithObjects:keys.data() count:keys.size()];
}

- (NSObject*)copyWithZone:(NSZone*)zone {
    if (_CFDictionaryIsMutable((CFDictionaryRef)self)) {
        return (NSObject*)CFDictionaryCreateCopy(kCFAllocatorDefault, (CFDictionaryRef)self);
    }

    return [self retain];
}

- (NSObject*)mutableCopyWithZone:(NSZone*)zone {
    return (NSObject*)CFDictionaryCreateMutableCopy(kCFAllocatorDefault, 0, (CFDictionaryRef)self);
}

- BRIDGED_COLLECTION_FAST_ENUMERATION(CFDictionary);

@end
#pragma endregion
