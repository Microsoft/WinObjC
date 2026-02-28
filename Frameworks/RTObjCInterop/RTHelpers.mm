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

#import <UWP/RTHelpers.h>
#import <UWP/interopBase.h>
#import <Foundation/Foundation.h>
#import "Starboard.h"

using namespace Microsoft::WRL;

NSUInteger fastEnumArrayImpl(id self, NSFastEnumerationState* state, id* buffer, NSUInteger len) {
    NSUInteger count = 0;
    NSUInteger first = state->state;
    NSUInteger arrayLen = [self count];

    if (first == 0) {
        state->itemsPtr = buffer;
        state->mutationsPtr = &state->extra[0];
    }

    while ((count < len) && ((first + count) < arrayLen)) {
        buffer[count] = [self objectAtIndex:first + count];
        count++;
    }

    state->state = first + count;
    return count;
}

NSUInteger fastEnumIteratorImpl(id self, NSFastEnumerationState* state, id* buffer, NSUInteger len) {
    NSUInteger count = 0;

    if (state->state == 0) {
        state->itemsPtr = buffer;
        state->mutationsPtr = &state->extra[0];

        state->state = 1;
        buffer[count] = [self first];
        if (buffer[count] == nil) {
            state->state = 2;
            return 0;
        }
        count++;
    }

    if (state->state == 1) {
        while (count < len) {
            buffer[count] = [self next];
            if (buffer[count] == nil) {
                state->state = 2;
                break;
            }
            count++;
        }
    }

    return count;
}

UINT32 SizeByEnumeration(id<NSFastEnumeration> obj) {
    NSFastEnumerationState state = { 0 };
    UINT32 totalCount = 0;
    id items[16] = { 0 };
    for (;;) {
        int count = [obj countByEnumeratingWithState:&state objects:items count:ARRAY_COUNT(items)];
        if (!count)
            break;
        totalCount += (UINT32)count;
    }
    return totalCount;
}

void getPropertyValueArrayInfo(ComPtr<IPropertyValue> comPtr, unsigned int& res, void** resPtr) {
    PropertyType type;
    THROW_NS_IF_FAILED(comPtr->get_Type(&type));
    switch (type) {
        case PropertyType_UInt8Array:
            comPtr->GetUInt8Array(&res, (BYTE**)resPtr);
            break;
        case PropertyType_Int16Array:
            comPtr->GetInt16Array(&res, (INT16**)resPtr);
            break;
        case PropertyType_UInt16Array:
            comPtr->GetUInt16Array(&res, (UINT16**)resPtr);
            break;
        case PropertyType_Int32Array:
            comPtr->GetInt32Array(&res, (INT32**)resPtr);
            break;
        case PropertyType_UInt32Array:
            comPtr->GetUInt32Array(&res, (UINT32**)resPtr);
            break;
        case PropertyType_Int64Array:
            comPtr->GetInt64Array(&res, (INT64**)resPtr);
            break;
        case PropertyType_UInt64Array:
            comPtr->GetUInt64Array(&res, (UINT64**)resPtr);
            break;
        case PropertyType_SingleArray:
            comPtr->GetSingleArray(&res, (FLOAT**)resPtr);
            break;
        case PropertyType_DoubleArray:
            comPtr->GetDoubleArray(&res, (DOUBLE**)resPtr);
            break;
        case PropertyType_Char16Array:
            comPtr->GetChar16Array(&res, (WCHAR**)resPtr);
            break;
        case PropertyType_BooleanArray:
            comPtr->GetBooleanArray(&res, (BOOLEAN**)resPtr);
            break;
        case PropertyType_StringArray:
            comPtr->GetStringArray(&res, (HSTRING**)resPtr);
            break;
        case PropertyType_InspectableArray:
            comPtr->GetInspectableArray(&res, (IInspectable***)resPtr);
            break;

        default:
            THROW_NS_HR(E_NOTIMPL);
            break;
    }
}

@implementation RTProxiedNSArray
- (ComPtr<IInspectable>)getInternalComObj {
    return adapter->getInternalComObj();
}

- (instancetype)initWithAdapter:(std::unique_ptr<ArrayAdapter>)arrayAdapter {
    if (self = [super init]) {
        adapter = std::move(arrayAdapter);
    }
    return self;
}

- (NSUInteger)count {
    return adapter->count();
}

- (id)objectAtIndex:(NSUInteger)index {
    return adapter->objectAtIndex(index);
}

- (BOOL)isCArray {
    return adapter->isCArray();
}

- (void*)ptr {
    return adapter->ptr();
}
@end

@implementation RTProxiedNSArrayFull
- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState*)state objects:(id __unsafe_unretained[])buffer count:(NSUInteger)len {
    return fastEnumArrayImpl(self, state, buffer, len);
}
@end

@implementation RTProxiedNSMutableArray
- (ComPtr<IInspectable>)getInternalComObj {
    return adapter->getInternalComObj();
}

- (instancetype)initWithAdapter:(std::unique_ptr<MutableArrayAdapter>)arrayAdapter {
    if (self = [super init]) {
        adapter = std::move(arrayAdapter);
    }
    return self;
}

- (NSUInteger)count {
    return adapter->count();
}

- (id)objectAtIndex:(NSUInteger)index {
    return adapter->objectAtIndex(index);
}

- (BOOL)isCArray {
    return adapter->isCArray();
}

- (void*)ptr {
    return adapter->ptr();
}

- (void)insertObject:(id)obj atIndex:(NSUInteger)idx {
    adapter->insertObjectAtIndex(obj, idx);
}

- (void)removeObjectAtIndex:(NSUInteger)idx {
    adapter->removeObjectAtIndex(idx);
}

- (void)addObject:(id)anObject {
    adapter->appendObject(anObject);
}

- (void)removeLastObject {
    [self removeObjectAtIndex:[self count] - 1];
}

- (void)replaceObjectAtIndex:(NSUInteger)idx withObject:(id)obj {
    adapter->replaceObjectAtIndexWithObject(idx, obj);
}
@end

@implementation RTProxiedObservableNSMutableArray {
    StrongId<ListenerMgr> _mgr;
}

- (ComPtr<IInspectable>)getInternalComObj {
    return adapter->getInternalComObj();
}

- (instancetype)initWithAdapter:(std::unique_ptr<ObservableArrayAdapter>)arrayAdapter {
    if (self = [super init]) {
        _mgr.attach([[ListenerMgr alloc] initWith:self]);
        adapter = std::move(arrayAdapter);
    }
    return self;
}

- (NSUInteger)count {
    return adapter->count();
}

- (id)objectAtIndex:(NSUInteger)index {
    return adapter->objectAtIndex(index);
}

- (BOOL)isCArray {
    return adapter->isCArray();
}

- (void*)ptr {
    return adapter->ptr();
}

- (void)insertObject:(id)obj atIndex:(NSUInteger)idx {
    adapter->insertObjectAtIndex(obj, idx);
}

- (void)removeObjectAtIndex:(NSUInteger)idx {
    adapter->removeObjectAtIndex(idx);
}

- (void)addObject:(id)anObject {
    adapter->appendObject(anObject);
}

- (void)removeLastObject {
    [self removeObjectAtIndex:[self count] - 1];
}

- (void)replaceObjectAtIndex:(NSUInteger)idx withObject:(id)obj {
    adapter->replaceObjectAtIndexWithObject(idx, obj);
}

- (void)registerSelf {
    adapter->registerSelf(self);
}

- (void)unregisterSelf {
    adapter->unregisterSelf();
}

- (EventRegistrationToken)addObserver:(RTCollectionListener)receiver {
    return [_mgr addObserver:receiver];
}

- (void)removeObserver:(EventRegistrationToken)receiverToken {
    [_mgr removeObserver:receiverToken];
}

- (void)notify:(RTCollectionOperation)op at:(unsigned int)idx {
    [_mgr notify:op value:[NSNumber numberWithUnsignedInt:idx]];
}
@end

@implementation RTProxiedObservableNSMutableDictionary {
    StrongId<ListenerMgr> _mgr;
}

- (ComPtr<IInspectable>)getInternalComObj {
    return adapter->getInternalComObj();
}

- (instancetype)initWithAdapter:(std::unique_ptr<ObservableDictionaryAdapter>)dictionaryAdapter {
    if (self = [super init]) {
        _mgr.attach([[ListenerMgr alloc] initWith:self]);
        adapter = std::move(dictionaryAdapter);
    }
    return self;
}

- (id)objectForKey:(id)key {
    return adapter->objectForKey(key);
}

- (id)keyEnumerator {
    return adapter->keyEnumerator();
}

- (unsigned int)count {
    return adapter->count();
}

- (NSArray*)allKeys {
    return adapter->allKeys();
}

- (NSArray*)allKeysForObject:(id)obj {
    return adapter->allKeysForObject(obj);
}

- (NSArray*)allValues {
    return adapter->allValues();
}

- (void)setObject:(id)obj forKey:(id)key {
    adapter->setObject(obj, key);
}

- (void)setObject:(id)obj forKeyedSubscript:(id)key {
    adapter->setObject(obj, key);
}

- (void)removeObjectForKey:(id)key {
    adapter->removeObjectForKey(key);
}

- (void)removeAllObjects {
    adapter->removeAllObjects();
}

- (void)removeObjectsForKeys:(NSArray*)keys {
    adapter->removeObjectsForKeys(keys);
}

- (void)addEntriesFromDictionary:(NSDictionary*)otherDict {
    adapter->addEntriesFromDictionary(otherDict);
}

- (void)addEntriesFromDictionaryNoReplace:(NSDictionary*)otherDict {
    adapter->addEntriesFromDictionaryNoReplace(otherDict);
}

- (void)setDictionary:(NSDictionary*)otherDict {
    adapter->setDictionary(otherDict);
}

- (void)registerSelf {
    adapter->registerSelf(self);
}

- (void)unregisterSelf {
    adapter->unregisterSelf();
}

- (EventRegistrationToken)addObserver:(RTCollectionListener)receiver {
    return [_mgr addObserver:receiver];
}

- (void)removeObserver:(EventRegistrationToken)receiverToken {
    [_mgr removeObserver:receiverToken];
}

- (void)notify:(RTCollectionOperation)op atKey:(id)key {
    [_mgr notify:op value:key];
}
@end

@implementation RTProxiedNSMutableArrayFull
- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState*)state objects:(id __unsafe_unretained[])buffer count:(NSUInteger)len {
    return fastEnumArrayImpl(self, state, buffer, len);
}
@end

@implementation RTProxiedIterableNSArray
- (ComPtr<IInspectable>)getInternalComObj {
    return adapter->getInternalComObj();
}

- (instancetype)initWithAdapter:(std::unique_ptr<IterableArrayAdapter>)arrayAdapter {
    if (self = [super init]) {
        adapter = std::move(arrayAdapter);
    }
    return self;
}

- (NSUInteger)count {
    return adapter->count();
}

- (id)objectAtIndex:(NSUInteger)index {
    return adapter->objectAtIndex(index);
}

- (BOOL)isCArray {
    return adapter->isCArray();
}

- (void*)ptr {
    return adapter->ptr();
}

- (id)first {
    return adapter->first();
}

- (id)next {
    return adapter->next();
}
@end

@implementation RTProxiedIterableNSArrayFull
- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState*)state objects:(id __unsafe_unretained[])buffer count:(NSUInteger)len {
    return fastEnumArrayImpl(self, state, buffer, len);
}
@end

@implementation RTProxiedNSDictionaryKeyEnumerator
- (id)initWithMap:(IInspectable*)map adapter:(std::unique_ptr<DictionaryKeyEnumeratorAdapter>)enumeratorAdapter {
    if (self = [super init]) {
        adapter = std::move(enumeratorAdapter);
        adapter->initWithMap(map);
    }

    return self;
}

- (id)nextObject {
    return adapter->nextObject();
}
@end

@implementation RTProxiedNSDictionary
- (ComPtr<IInspectable>)getInternalComObj {
    return adapter->getInternalComObj();
}

- (instancetype)initWithAdapter:(std::unique_ptr<DictionaryAdapter>)dictionaryAdapter {
    if (self = [super init]) {
        adapter = std::move(dictionaryAdapter);
    }

    return self;
}

- (id)objectForKey:(id)key {
    return adapter->objectForKey(key);
}

- (id)keyEnumerator {
    return adapter->keyEnumerator();
}

- (unsigned int)count {
    return adapter->count();
}

- (NSArray*)allKeys {
    return adapter->allKeys();
}

- (NSArray*)allKeysForObject:(id)obj {
    return adapter->allKeysForObject(obj);
}

- (NSArray*)allValues {
    return adapter->allValues();
}
@end

@implementation RTProxiedNSMutableDictionary
- (ComPtr<IInspectable>)getInternalComObj {
    return adapter->getInternalComObj();
}

- (instancetype)initWithAdapter:(std::unique_ptr<MutableDictionaryAdapter>)dictionaryAdapter {
    if (self = [super init]) {
        adapter = std::move(dictionaryAdapter);
    }

    return self;
}

- (id)objectForKey:(id)key {
    return adapter->objectForKey(key);
}

- (id)keyEnumerator {
    return adapter->keyEnumerator();
}

- (unsigned int)count {
    return adapter->count();
}

- (NSArray*)allKeys {
    return adapter->allKeys();
}

- (NSArray*)allKeysForObject:(id)obj {
    return adapter->allKeysForObject(obj);
}

- (NSArray*)allValues {
    return adapter->allValues();
}

- (void)setObject:(id)obj forKey:(id)key {
    adapter->setObject(obj, key);
}

- (void)setObject:(id)obj forKeyedSubscript:(id)key {
    adapter->setObject(obj, key);
}

- (void)removeObjectForKey:(id)key {
    adapter->removeObjectForKey(key);
}

- (void)removeAllObjects {
    adapter->removeAllObjects();
}

- (void)removeObjectsForKeys:(NSArray*)keys {
    adapter->removeObjectsForKeys(keys);
}

- (void)addEntriesFromDictionary:(NSDictionary*)otherDict {
    adapter->addEntriesFromDictionary(otherDict);
}

- (void)addEntriesFromDictionaryNoReplace:(NSDictionary*)otherDict {
    adapter->addEntriesFromDictionaryNoReplace(otherDict);
}

- (void)setDictionary:(NSDictionary*)otherDict {
    adapter->setDictionary(otherDict);
}
@end

@implementation RTProxiedKeyValuePair
- (void)setAdapter:(std::unique_ptr<KeyValuePairAdapter>)keyValuePairAdapter {
    adapter = std::move(keyValuePairAdapter);
}

- (id)key {
    return adapter->key(self.comObj);
}

- (id)value {
    return adapter->value(self.comObj);
}
@end

@implementation ListenerMgr {
    id _owner;
    StrongId<NSMutableDictionary> _listeners;
    __int64 _nextToken;
}

- (id)init {
    [super init];
    _listeners.attach([[NSMutableDictionary alloc] init]);
    _nextToken = 1;
    return self;
}

- (id)initWith:(id)owner {
    [self init];
    _owner = owner;
    return self;
}

- (void)setOwner:(id)owner {
    _owner = owner;
}

- (EventRegistrationToken)addObserver:(RTCollectionListener)receiver {
    EventRegistrationToken t;
    t.value = _nextToken;

    [receiver retain];
    [_listeners setObject:receiver forKey:[NSNumber numberWithLongLong:t.value]];
    _nextToken++;

    if ([_listeners count] == 1) {
        [_owner registerSelf];
    }

    return t;
}

- (void)removeObserver:(EventRegistrationToken)receiverToken {
    NSNumber* k = [NSNumber numberWithLongLong:receiverToken.value];
    RTCollectionListener receiver = [_listeners objectForKey:k];
    if (receiver != nil) {
        [_listeners removeObjectForKey:k];
        [receiver release];
        if ([_listeners count] == 0) {
            [_owner unregisterSelf];
        }
    }
}

- (void)notify:(RTCollectionOperation)op value:(id)val {
    for (RTCollectionListener listener in [_listeners objectEnumerator]) {
        listener(_owner, op, val);
    }
}

- (NSArray*)listeners {
    return [_listeners allValues];
}
@end
