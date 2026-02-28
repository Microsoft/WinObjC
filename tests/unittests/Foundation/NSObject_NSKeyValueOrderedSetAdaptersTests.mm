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

#import <Foundation/Foundation.h>
#include <TestFramework.h>

@interface TestOrderedSetAdapterObject : NSObject {
    NSMutableOrderedSet* alreadyMutable;
    NSOrderedSet* immutable;
    NSObject* notAnOrderedSet;

    BOOL fakeMutableInserted;
    BOOL fakeMutableRemoved;
    BOOL fakeMutableInsertedAtIndexes;
    BOOL fakeMutableRemovedAtIndexes;

    // Named such to hide it from KVC.
    NSOrderedSet* _internal_immutableWithAccessors;
    BOOL immutableWithAccessorsOrderedSet;
    NSOrderedSet* _internal_immutableThroughKVC;
    BOOL immutableThroughKVCOrderedSet;

    NSObject* backedByIvar;
}
@end

@implementation TestOrderedSetAdapterObject
- (id)init {
    if (self = [super init]) {
        alreadyMutable = [[NSMutableOrderedSet alloc] init];
        [alreadyMutable addObject:@"y"];
        immutable = [[NSOrderedSet alloc] initWithObjects:@"y", nil];
        _internal_immutableWithAccessors = [[NSOrderedSet alloc] initWithObjects:@"y", nil];
        _internal_immutableThroughKVC = [[NSOrderedSet alloc] initWithObjects:@"y", nil];
        notAnOrderedSet = [NSObject new];
    }

    return self;
}

- (void)dealloc {
    [alreadyMutable release];
    [immutable release];
    [notAnOrderedSet release];
    [_internal_immutableWithAccessors release];
    [_internal_immutableThroughKVC release];
    [backedByIvar release];
    [super dealloc];
}

+ (instancetype)test {
    return [[[self alloc] init] autorelease];
}
- (NSUInteger)countOfFakeCollection {
    return 10;
}

- (NSObject*)objectInFakeCollectionAtIndex:(NSUInteger)index {
    return @(index);
}

- (NSUInteger)countOfFakeMutableCollection {
    return 10;
}

- (NSObject*)objectInFakeMutableCollectionAtIndex:(NSUInteger)index {
    return @(index);
}

- (void)insertObject:(id)object inFakeMutableCollectionAtIndex:(NSUInteger)index {
    fakeMutableInserted = YES;
}

- (void)removeObjectFromFakeMutableCollectionAtIndex:(NSUInteger)index {
    fakeMutableRemoved = YES;
}

- (void)insertFakeMutableCollection:(NSArray*)objects atIndexes:(NSIndexSet*)indexes {
    fakeMutableInsertedAtIndexes = YES;
}

- (void)removeFakeMutableCollectionAtIndexes:(NSIndexSet*)indexes {
    fakeMutableRemovedAtIndexes = YES;
}

- (BOOL)fakeMutableInserted {
    return fakeMutableInserted;
}

- (BOOL)fakeMutableRemoved {
    return fakeMutableRemoved;
}

- (BOOL)fakeMutableInsertedAtIndexes {
    return fakeMutableInsertedAtIndexes;
}

- (BOOL)fakeMutableRemovedAtIndexes {
    return fakeMutableRemovedAtIndexes;
}

- (NSOrderedSet*)immutableWithAccessors {
    return [[_internal_immutableWithAccessors retain] autorelease];
}

- (void)setImmutableWithAccessors:(NSOrderedSet*)value {
    [_internal_immutableWithAccessors release];
    _internal_immutableWithAccessors = [value copy];
    immutableWithAccessorsOrderedSet = YES;
}

- (BOOL)immutableWithAccessorsOrderedSet {
    return immutableWithAccessorsOrderedSet;
}

- (id)valueForKey:(NSString*)key {
    if ([@"immutableThroughKVC" isEqual:key]) {
        return [[_internal_immutableThroughKVC retain] autorelease];
    }
    return [super valueForKey:key];
}

- (void)setValue:(id)value forKey:(NSString*)key {
    if ([@"immutableThroughKVC" isEqual:key]) {
        [_internal_immutableThroughKVC release];
        _internal_immutableThroughKVC = [value copy];
        immutableThroughKVCOrderedSet = YES;
        return;
    }
    return [super setValue:value forKey:key];
}

- (BOOL)immutableThroughKVCOrderedSet {
    return immutableThroughKVCOrderedSet;
}
@end

TEST(NSObject, KVCOrderedSetMutableAdapters_CompliantIndexedAccessors) {
    TestOrderedSetAdapterObject* testObject = [[[TestOrderedSetAdapterObject alloc] init] autorelease];
    NSMutableOrderedSet* fakeMutableCollection = [testObject mutableOrderedSetValueForKey:@"fakeMutableCollection"];
    EXPECT_TRUE([fakeMutableCollection isKindOfClass:[NSMutableOrderedSet class]]);

    EXPECT_EQ(10, [fakeMutableCollection count]);
    EXPECT_OBJCEQ(@5, [fakeMutableCollection objectAtIndex:5]);
}

TEST(NSObject, KVCOrderedSetMutableAdapters_InsertObject) {
    TestOrderedSetAdapterObject* testObject = [[[TestOrderedSetAdapterObject alloc] init] autorelease];
    NSMutableOrderedSet* fakeCollection = [testObject mutableOrderedSetValueForKey:@"fakeMutableCollection"];
    EXPECT_NO_THROW([fakeCollection insertObject:@"TEST" atIndex:0]);
    EXPECT_TRUE([testObject fakeMutableInserted]);
}

TEST(NSObject, KVCOrderedSetMutableAdapters_RemoveObject) {
    TestOrderedSetAdapterObject* testObject = [[[TestOrderedSetAdapterObject alloc] init] autorelease];
    id fakeCollection = [testObject mutableOrderedSetValueForKey:@"fakeMutableCollection"];
    EXPECT_NO_THROW([fakeCollection removeObjectAtIndex:0]);
    EXPECT_TRUE([testObject fakeMutableRemoved]);
}

TEST(NSObject, KVCOrderedSetMutableAdapters_InsertObjects) {
    TestOrderedSetAdapterObject* testObject = [[[TestOrderedSetAdapterObject alloc] init] autorelease];
    id fakeCollection = [testObject mutableOrderedSetValueForKey:@"fakeMutableCollection"];
    EXPECT_NO_THROW([fakeCollection insertObjects:@[ @1 ] atIndexes:[NSIndexSet indexSetWithIndex:5]]);
    EXPECT_TRUE([testObject fakeMutableInsertedAtIndexes]);
}

TEST(NSObject, KVCOrderedSetMutableAdapters_RemoveObjects) {
    TestOrderedSetAdapterObject* testObject = [[[TestOrderedSetAdapterObject alloc] init] autorelease];
    id fakeCollection = [testObject mutableOrderedSetValueForKey:@"fakeMutableCollection"];
    EXPECT_NO_THROW([fakeCollection removeObjectsAtIndexes:[NSIndexSet indexSetWithIndex:5]]);
    EXPECT_TRUE([testObject fakeMutableRemovedAtIndexes]);
}

TEST(NSObject, KVCOrderedSetMutableAdapters_ImmutableWithBasicAccessors) {
    TestOrderedSetAdapterObject* testObject = [[[TestOrderedSetAdapterObject alloc] init] autorelease];
    id mutableImmutable = [testObject mutableOrderedSetValueForKey:@"immutableWithAccessors"];
    EXPECT_TRUE([mutableImmutable isKindOfClass:[NSMutableOrderedSet class]]);
    EXPECT_NO_THROW([mutableImmutable addObject:@"Whatever"]);

    ASSERT_TRUE([testObject immutableWithAccessorsOrderedSet]);
    EXPECT_TRUE([[testObject immutableWithAccessors] containsObject:@"Whatever"]);
}

TEST(NSObject, KVCOrderedSetMutableAdapters_ImmutableThroughKVC) {
    TestOrderedSetAdapterObject* testObject = [[[TestOrderedSetAdapterObject alloc] init] autorelease];
    id mutableImmutable = [testObject mutableOrderedSetValueForKey:@"immutableThroughKVC"];
    EXPECT_TRUE([mutableImmutable isKindOfClass:[NSMutableOrderedSet class]]);
    EXPECT_NO_THROW([mutableImmutable addObject:@"Whatever"]);

    ASSERT_TRUE([testObject immutableThroughKVCOrderedSet]);
    EXPECT_TRUE([[testObject valueForKey:@"immutableThroughKVC"] containsObject:@"Whatever"]);
}

TEST(NSObject, KVCOrderedSetMutableAdapters_MutableOrderedSetIvar) {
    TestOrderedSetAdapterObject* testObject = [[[TestOrderedSetAdapterObject alloc] init] autorelease];
    id mutableMutable = [testObject mutableOrderedSetValueForKey:@"alreadyMutable"];
    EXPECT_TRUE([mutableMutable isKindOfClass:[NSMutableOrderedSet class]]);
}

TEST(NSObject, KVCOrderedSetMutableAdapters_ImmutableOrderedSetIvar) {
    TestOrderedSetAdapterObject* testObject = [[[TestOrderedSetAdapterObject alloc] init] autorelease];
    id mutableImmutable = [testObject mutableOrderedSetValueForKey:@"immutable"];
    EXPECT_TRUE([mutableImmutable isKindOfClass:[NSMutableOrderedSet class]]);
    EXPECT_ANY_THROW([mutableImmutable addObject:@"Whatever"]);

    // The setter should have not stomped the original value of immutable, since it is an ivar.
    EXPECT_FALSE([[testObject valueForKey:@"immutable"] containsObject:@"Whatever"]);
}

TEST(NSObject, KVCOrderedSetMutableAdapters_NonOrderedSetIvar) {
    TestOrderedSetAdapterObject* testObject = [[[TestOrderedSetAdapterObject alloc] init] autorelease];
    id mutableObject = [testObject mutableOrderedSetValueForKey:@"notAnOrderedSet"];
    EXPECT_TRUE([mutableObject isKindOfClass:[NSMutableOrderedSet class]]);
    EXPECT_ANY_THROW([mutableObject addObject:@"Whatever"]);
}

TEST(NSObject, KVCOrderedSetMutableAdapters_ImmutableOrderedSetDictionaryLeaf) {
    NSDictionary* testDictionary = @{ @"key" : @{ @"subkey" : @{ @"subkey2" : @[ @"hello" ] } } };
    NSMutableOrderedSet* mutableSubOrderedSet = [testDictionary mutableOrderedSetValueForKeyPath:@"key.subkey.subkey2"];
    EXPECT_TRUE([mutableSubOrderedSet isKindOfClass:[NSMutableOrderedSet class]]);
    EXPECT_ANY_THROW([mutableSubOrderedSet addObject:@"Invalid"]);
}

TEST(NSObject, KVCOrderedSetMutableAdapters_EmptyIvar) {
    TestOrderedSetAdapterObject* testObject = [[[TestOrderedSetAdapterObject alloc] init] autorelease];
    NSMutableOrderedSet* mutableWasNil = [testObject mutableOrderedSetValueForKey:@"backedByIvar"];
    EXPECT_NO_THROW([mutableWasNil addObject:@"Hello"]);
    EXPECT_OBJCEQ(@"Hello", [[testObject valueForKey:@"backedByIvar"] firstObject]);
}

TEST(NSObject, KVCOrderedSetChangePropagation) {
    NSMutableDictionary* dictionary = [NSMutableDictionary dictionary];
    [dictionary setObject:@[ @"1" ] forKey:@"orderedSet"];

    NSMutableOrderedSet* mutableVersionOfDictionaryOrderedSet = [dictionary mutableOrderedSetValueForKeyPath:@"orderedSet"];

    EXPECT_OBJCEQ(@"1", [mutableVersionOfDictionaryOrderedSet objectAtIndex:0]);

    [dictionary setObject:@[ @"2" ] forKey:@"orderedSet"];

    // The value in index 0 should be updated even though we only requested mutableOrderedSet* once.
    EXPECT_OBJCEQ(@"2", [mutableVersionOfDictionaryOrderedSet objectAtIndex:0]);
}

TEST(NSObject, KVCOrderedSetAutovivification) {
    NSMutableDictionary* dictionary = [NSMutableDictionary dictionary];
    NSMutableOrderedSet* nonexistentMutableOrderedSet = [dictionary mutableOrderedSetValueForKey:@"new"];
    EXPECT_NO_THROW([nonexistentMutableOrderedSet addObject:@"Hello"]);
    EXPECT_EQ(1, [[dictionary objectForKey:@"new"] count]);
    EXPECT_OBJCEQ(@"Hello", [[dictionary objectForKey:@"new"] firstObject]);
}
