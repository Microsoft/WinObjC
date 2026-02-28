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

#include <Foundation/Foundation.h>
#include <TestFramework.h>

@interface TestSetAdapterObject : NSObject {
    NSMutableSet* alreadyMutable;
    NSSet* immutable;
    NSObject* notASet;

    BOOL fakeMutableAdded;
    BOOL fakeMutableRemoved;
    BOOL fakeMutableUnioned;
    BOOL fakeMutableMinused;
    BOOL fakeMutableIntersected;
    BOOL fakeMutableSetCalled;

    // Named such to hide it from KVC.
    NSSet* _internal_immutableWithAccessors;
    BOOL immutableWithAccessorsSet;
    NSSet* _internal_immutableThroughKVC;
    BOOL immutableThroughKVCSet;

    NSObject* backedByIvar;
}
@end

@implementation TestSetAdapterObject
- (id)init {
    if (self = [super init]) {
        alreadyMutable = [[NSMutableSet alloc] init];
        [alreadyMutable addObject:@"y"];
        immutable = [[NSSet alloc] initWithObjects:@"y", nil];
        _internal_immutableWithAccessors = [[NSSet alloc] initWithObjects:@"y", nil];
        _internal_immutableThroughKVC = [[NSSet alloc] initWithObjects:@"y", nil];
        notASet = [NSObject new];
    }

    return self;
}

- (void)dealloc {
    [alreadyMutable release];
    [immutable release];
    [notASet release];
    [_internal_immutableWithAccessors release];
    [_internal_immutableThroughKVC release];
    [backedByIvar release];
    [super dealloc];
}

+ (instancetype)test {
    return [[[self alloc] init] autorelease];
}

- (NSUInteger)countOfFakeCollection {
    return [immutable count];
}

- (NSUInteger)countOfFakeMutableCollection {
    return [alreadyMutable count];
}

- (NSEnumerator*)enumeratorOfFakeCollection {
    return [immutable objectEnumerator];
}

- (NSEnumerator*)enumeratorOfFakeMutableCollection {
    return [alreadyMutable objectEnumerator];
}

- (id)memberOfFakeCollection:(id)obj {
    return [immutable member:obj];
}

- (id)memberOfFakeMutableCollection:(id)obj {
    return [alreadyMutable member:obj];
}

- (void)addFakeMutableCollectionObject:(id)obj {
    fakeMutableAdded = YES;
}

- (void)removeFakeMutableCollectionObject:(id)obj {
    fakeMutableRemoved = YES;
}

- (void)addFakeMutableCollection:(NSSet*)set {
    fakeMutableUnioned = YES;
}

- (void)removeFakeMutableCollection:(NSSet*)set {
    fakeMutableMinused = YES;
}

- (void)intersectFakeMutableCollection:(NSSet*)set {
    fakeMutableIntersected = YES;
}

- (void)setFakeMutableCollection:(NSSet*)set {
    fakeMutableSetCalled = YES;
}

- (BOOL)fakeMutableAdded {
    return fakeMutableAdded;
}

- (BOOL)fakeMutableRemoved {
    return fakeMutableRemoved;
}

- (BOOL)fakeMutableUnioned {
    return fakeMutableUnioned;
}

- (BOOL)fakeMutableMinused {
    return fakeMutableMinused;
}

- (BOOL)fakeMutableIntersected {
    return fakeMutableIntersected;
}

- (BOOL)fakeMutableSetCalled {
    return fakeMutableSetCalled;
}

- (NSSet*)immutableWithAccessors {
    return [[_internal_immutableWithAccessors retain] autorelease];
}

- (void)setImmutableWithAccessors:(NSSet*)value {
    [_internal_immutableWithAccessors release];
    _internal_immutableWithAccessors = [value copy];
    immutableWithAccessorsSet = YES;
}

- (BOOL)immutableWithAccessorsSet {
    return immutableWithAccessorsSet;
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
        immutableThroughKVCSet = YES;
        return;
    }
    return [super setValue:value forKey:key];
}

- (BOOL)immutableThroughKVCSet {
    return immutableThroughKVCSet;
}
@end

TEST(NSObject, KVCSetAdapters_CompliantAccessor) {
    auto test = [TestSetAdapterObject test];
    NSSet* fakeCollection = [test valueForKey:@"fakeCollection"];
    EXPECT_TRUE([fakeCollection isKindOfClass:[NSSet class]]);

    // Tests calling countOfKey, memberOfKey, and enumeratorOfKey selectors
    EXPECT_EQ(1, [fakeCollection count]);
    EXPECT_TRUE([fakeCollection member:@"y"]);

    EXPECT_OBJCEQ([NSSet setWithObject:@"y"], fakeCollection);
    EXPECT_OBJCEQ(fakeCollection, [NSSet setWithObject:@"y"]);
}

TEST(NSObject, KVCMutableSetAdapters_CompliantAccessors) {
    auto test = [TestSetAdapterObject test];
    NSMutableSet* fakeCollection = [test mutableSetValueForKey:@"fakeMutableCollection"];
    EXPECT_TRUE([fakeCollection isKindOfClass:[NSMutableSet class]]);

    // Tests calling countOfKey, memberOfKey, and enumeratorOfKey selectors
    EXPECT_EQ(1, [fakeCollection count]);
    EXPECT_OBJCEQ(@"y", [fakeCollection member:@"y"]);
    EXPECT_OBJCEQ([NSMutableSet setWithObject:@"y"], fakeCollection);
    EXPECT_OBJCEQ(fakeCollection, [NSMutableSet setWithObject:@"y"]);
}

TEST(NSObject, KVCMutableSetAdapters_AddObject) {
    auto test = [TestSetAdapterObject test];
    NSMutableSet* fakeCollection = [test mutableSetValueForKey:@"fakeMutableCollection"];
    EXPECT_NO_THROW([fakeCollection addObject:@"TEST"]);
    EXPECT_TRUE([test fakeMutableAdded]);
}

TEST(NSObject, KVCMutableSetAdapters_RemoveObject) {
    auto test = [TestSetAdapterObject test];
    NSMutableSet* fakeCollection = [test mutableSetValueForKey:@"fakeMutableCollection"];
    [fakeCollection removeObject:@"TEST"];
    EXPECT_TRUE([test fakeMutableRemoved]);
}

TEST(NSObject, KVCMutableSetAdapters_UnionSet) {
    auto test = [TestSetAdapterObject test];
    NSMutableSet* fakeCollection = [test mutableSetValueForKey:@"fakeMutableCollection"];
    [fakeCollection unionSet:[NSSet setWithObject:@"TEST"]];
    EXPECT_TRUE([test fakeMutableUnioned]);
}

TEST(NSObject, KVCMutableSetAdapters_MinusSet) {
    auto test = [TestSetAdapterObject test];
    NSMutableSet* fakeCollection = [test mutableSetValueForKey:@"fakeMutableCollection"];
    [fakeCollection minusSet:[NSSet setWithObject:@"TEST"]];
    EXPECT_TRUE([test fakeMutableMinused]);
}

TEST(NSObject, KVCMutableSetAdapters_IntersectSet) {
    auto test = [TestSetAdapterObject test];
    NSMutableSet* fakeCollection = [test mutableSetValueForKey:@"fakeMutableCollection"];
    [fakeCollection intersectSet:[NSSet setWithObject:@"TEST"]];
    EXPECT_TRUE([test fakeMutableIntersected]);
}

TEST(NSObject, KVCMutableSetAdapters_SetSet) {
    auto test = [TestSetAdapterObject test];
    NSMutableSet* fakeCollection = [test mutableSetValueForKey:@"fakeMutableCollection"];
    [fakeCollection setSet:[NSSet setWithObject:@"TEST"]];
    EXPECT_TRUE([test fakeMutableSetCalled]);
}

TEST(NSObject, KVCSetMutableAdapters_ImmutableWithBasicAccessors) {
    TestSetAdapterObject* testObject = [TestSetAdapterObject test];
    id mutableImmutable = [testObject mutableSetValueForKey:@"immutableWithAccessors"];
    EXPECT_TRUE([mutableImmutable isKindOfClass:[NSMutableSet class]]);
    EXPECT_NO_THROW([mutableImmutable addObject:@"Whatever"]);

    EXPECT_TRUE([testObject immutableWithAccessorsSet]);
    EXPECT_TRUE([[testObject immutableWithAccessors] containsObject:@"Whatever"]);
}

TEST(NSObject, KVCSetMutableAdapters_ImmutableThroughKVC) {
    TestSetAdapterObject* testObject = [TestSetAdapterObject test];
    id mutableImmutable = [testObject mutableSetValueForKey:@"immutableThroughKVC"];
    EXPECT_TRUE([mutableImmutable isKindOfClass:[NSMutableSet class]]);
    EXPECT_NO_THROW([mutableImmutable addObject:@"Whatever"]);

    EXPECT_TRUE([testObject immutableThroughKVCSet]);
    EXPECT_TRUE([[testObject valueForKey:@"immutableThroughKVC"] containsObject:@"Whatever"]);
}

TEST(NSObject, KVCSetMutableAdapters_MutableSetIvar) {
    TestSetAdapterObject* testObject = [TestSetAdapterObject test];
    id mutableMutable = [testObject mutableSetValueForKey:@"alreadyMutable"];
    EXPECT_TRUE([mutableMutable isKindOfClass:[NSMutableSet class]]);
}

TEST(NSObject, KVCSetMutableAdapters_ImmutableSetIvar) {
    TestSetAdapterObject* testObject = [TestSetAdapterObject test];
    id mutableImmutable = [testObject mutableSetValueForKey:@"immutable"];
    EXPECT_TRUE([mutableImmutable isKindOfClass:[NSMutableSet class]]);
    EXPECT_ANY_THROW([mutableImmutable addObject:@"Whatever"]);

    // The setter should have not stomped the original value of immutable, since it is an ivar.
    EXPECT_FALSE([[testObject valueForKey:@"immutable"] containsObject:@"Whatever"]);
}

TEST(NSObject, KVCSetMutableAdapters_NonSetIvar) {
    TestSetAdapterObject* testObject = [TestSetAdapterObject test];
    id mutableObject = [testObject mutableSetValueForKey:@"notAnSet"];
    EXPECT_TRUE([mutableObject isKindOfClass:[NSMutableSet class]]);
    EXPECT_ANY_THROW([mutableObject addObject:@"Whatever"]);
}

TEST(NSObject, KVCSetMutableAdapters_ImmutableSetDictionaryLeaf) {
    NSDictionary* testDictionary = @{ @"key" : @{ @"subkey" : @{ @"subkey2" : @[ @"hello" ] } } };
    NSMutableSet* mutableSubSet = [testDictionary mutableSetValueForKeyPath:@"key.subkey.subkey2"];
    EXPECT_TRUE([mutableSubSet isKindOfClass:[NSMutableSet class]]);
    EXPECT_ANY_THROW([mutableSubSet addObject:@"Invalid"]);
}

TEST(NSObject, KVCSetMutableAdapters_EmptyIvar) {
    TestSetAdapterObject* testObject = [TestSetAdapterObject test];
    NSMutableSet* mutableWasNil = [testObject mutableSetValueForKey:@"backedByIvar"];
    EXPECT_NO_THROW([mutableWasNil addObject:@"Hello"]);
    EXPECT_OBJCEQ(@"Hello", [[testObject valueForKey:@"backedByIvar"] anyObject]);
}

TEST(NSObject, KVCSetChangePropagation) {
    NSMutableDictionary* dictionary = [NSMutableDictionary dictionary];
    [dictionary setObject:@[ @"1" ] forKey:@"set"];

    NSMutableSet* mutableVersionOfDictionarySet = [dictionary mutableSetValueForKeyPath:@"set"];

    EXPECT_OBJCEQ(@"1", [mutableVersionOfDictionarySet anyObject]);

    [dictionary setObject:@[ @"2" ] forKey:@"set"];

    // The value in index 0 should be updated even though we only requested mutableSet* once.
    EXPECT_OBJCEQ(@"2", [mutableVersionOfDictionarySet anyObject]);
}

TEST(NSObject, KVCSetAutovivification) {
    NSMutableDictionary* dictionary = [NSMutableDictionary dictionary];
    NSMutableSet* nonexistentMutableSet = [dictionary mutableSetValueForKey:@"new"];
    EXPECT_NO_THROW([nonexistentMutableSet addObject:@"Hello"]);
    EXPECT_EQ(1, [[dictionary objectForKey:@"new"] count]);
    EXPECT_OBJCEQ(@"Hello", [[dictionary objectForKey:@"new"] anyObject]);
}