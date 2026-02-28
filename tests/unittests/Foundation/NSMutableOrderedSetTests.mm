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
#import <TestFramework.h>
#import "TestUtils.h"

TEST(NSMutableOrderedSet, Init) {
    NSMutableOrderedSet* orderedSet = [[NSMutableOrderedSet alloc] init];
    ASSERT_TRUE_MSG(orderedSet != nil, "FAILED: orderedSet should be non-null!");
    [orderedSet release];
}

TEST(NSMutableOrderedSet, OrderedSet) {
    NSMutableOrderedSet* orderedSet = [NSMutableOrderedSet orderedSet];
    ASSERT_TRUE_MSG(orderedSet != nil, "FAILED: orderedSet should be non-null!");
    ASSERT_EQ(0, [orderedSet count]);
}

TEST(NSMutableOrderedSet, Contains) {
    NSMutableOrderedSet* orderedSet = [NSMutableOrderedSet orderedSetWithObjects:@"Acura", @"Benz", nil];
    ASSERT_NE(nil, orderedSet);
    ASSERT_TRUE([orderedSet containsObject:@"Benz"]);
}

TEST(NSMutableOrderedSet, OrderedSetWithArray) {
    NSArray* array = @[ @1, @1, @1, @2, @2, @3 ];
    NSMutableOrderedSet* orderedSet = [NSMutableOrderedSet orderedSetWithArray:array];
    ASSERT_TRUE_MSG(orderedSet != nil, "FAILED: orderedSet should be non-null!");

    ASSERT_EQ(3, [orderedSet count]);
    ASSERT_OBJCEQ(@1, [orderedSet firstObject]);
    ASSERT_OBJCEQ(@3, [orderedSet lastObject]);
}

TEST(NSMutableOrderedSet, OrderedSetWithArrayWithOptions) {
    NSArray* array = @[ @1, @2, @3, @4, @5, @6 ];
    NSMutableOrderedSet* orderedSet = [NSMutableOrderedSet orderedSetWithArray:array range:NSMakeRange(2, 3) copyItems:YES];
    ASSERT_TRUE_MSG(orderedSet != nil, "FAILED: orderedSet should be non-null!");

    ASSERT_EQ(3, [orderedSet count]);
    ASSERT_OBJCEQ(@3, [orderedSet firstObject]);
    ASSERT_OBJCEQ(@5, [orderedSet lastObject]);
}

TEST(NSMutableOrderedSet, OrderedSetWithArrayWithOptions2) {
    NSArray* array = @[ @5, @5, @5, @5, @7, @6, @2, @3 ];
    NSMutableOrderedSet* orderedSet = [NSMutableOrderedSet orderedSetWithArray:array range:NSMakeRange(0, 8) copyItems:YES];
    ASSERT_TRUE_MSG(orderedSet != nil, "FAILED: orderedSet should be non-null!");

    ASSERT_EQ(5, [orderedSet count]);
    ASSERT_OBJCEQ(@5, [orderedSet firstObject]);
    ASSERT_OBJCEQ(@3, [orderedSet lastObject]);
}

TEST(NSMutableOrderedSet, OrderedSetWithObjects) {
    id array[3] = { @2, @1, @1 };
    NSMutableOrderedSet* orderedSet = [NSMutableOrderedSet orderedSetWithObjects:array count:3];
    ASSERT_EQ(2, [orderedSet count]);
    ASSERT_OBJCEQ(@2, [orderedSet firstObject]);
    ASSERT_OBJCEQ(@1, [orderedSet lastObject]);
}

TEST(NSMutableOrderedSet, OrderedSetWithOrderedSet) {
    id array[3] = { @2, @1, @1 };
    NSMutableOrderedSet* set = [NSMutableOrderedSet orderedSetWithObjects:array count:3];

    NSMutableOrderedSet* orderedSet = [NSMutableOrderedSet orderedSetWithOrderedSet:set range:NSMakeRange(0, [set count]) copyItems:NO];
    ASSERT_EQ(2, [orderedSet count]);
    ASSERT_OBJCEQ(@2, [orderedSet firstObject]);
    ASSERT_OBJCEQ(@1, [orderedSet lastObject]);
}

TEST(NSMutableOrderedSet, OrderedSetWithSet) {
    NSSet* set = [NSSet setWithObjects:@"Tesla", @"Benz", @"BMW", @"Acura", @"Audi", nil];
    NSMutableOrderedSet* orderedSet = [NSMutableOrderedSet orderedSetWithSet:set copyItems:YES];
    ASSERT_EQ(5, [orderedSet count]);
    ASSERT_TRUE([orderedSet containsObject:@"Tesla"]);
}

TEST(NSMutableOrderedSet, CheckFullOrder) {
    NSArray* array = @[ @1, @2, @3, @4, @5, @5, @5 ];
    NSMutableOrderedSet* orderedSet = [NSMutableOrderedSet orderedSetWithArray:array range:NSMakeRange(0, 7) copyItems:YES];
    ASSERT_TRUE_MSG(orderedSet != nil, "FAILED: orderedSet should be non-null!");

    ASSERT_EQ(5, [orderedSet count]);
    NSUInteger count = [orderedSet count];
    for (NSUInteger i = 0; i < count; ++i) {
        ASSERT_OBJCEQ([orderedSet objectAtIndex:i], array[i]);
    }
}

TEST(NSMutableOrderedSet, CheckOrder) {
    // Empty list
    NSMutableOrderedSet* orderedSet = [NSMutableOrderedSet orderedSetWithObjects:nil];
    ASSERT_NE(nil, orderedSet);
    ASSERT_EQ(0, [orderedSet count]);

    // Single element
    assertOrderedSetContent([NSMutableOrderedSet orderedSetWithObjects:@1, nil], @1, nil);

    // Multiple elements
    assertOrderedSetContent([NSMutableOrderedSet orderedSetWithObjects:@1, @2, @3, nil], @1, @2, @3, nil);
}

TEST(NSMutableOrderedSet, Array) {
    NSArray* array = @[ @1, @2, @3, @4, @5, @5, @5 ];
    NSMutableOrderedSet* orderedSet = [NSMutableOrderedSet orderedSetWithArray:array];
    ASSERT_TRUE_MSG(orderedSet != nil, "FAILED: orderedSet should be non-null!");

    ASSERT_EQ(5, [orderedSet count]);
    NSArray* setArray = [orderedSet array];
    ASSERT_NE(nil, setArray);

    NSUInteger count = [setArray count];
    for (NSUInteger i = 0; i < count; ++i) {
        ASSERT_OBJCEQ([setArray objectAtIndex:i], array[i]);
    }
}

TEST(NSMutableOrderedSet, ObjectEnumerator) {
    NSArray* array = @[ @"Tom", @"Bob", @"Ann", @"Ann" ];
    NSMutableOrderedSet* orderedSet = [NSMutableOrderedSet orderedSetWithArray:array];
    ASSERT_TRUE_MSG(orderedSet != nil, "FAILED: orderedSet should be non-null!");

    ASSERT_EQ(3, [orderedSet count]);
    NSEnumerator* enumerator = [orderedSet objectEnumerator];
    ASSERT_NE(nil, enumerator);

    NSUInteger i = 0;
    while (id object = [enumerator nextObject]) {
        ASSERT_OBJCEQ(object, array[i]);
        i++;
    }
}

TEST(NSMutableOrderedSet, ReverseObjectEnumerator) {
    NSArray* array = @[ @"Tom", @"Bob", @"Ann", @"Ann" ];
    NSMutableOrderedSet* orderedSet = [NSMutableOrderedSet orderedSetWithArray:array];
    ASSERT_TRUE_MSG(orderedSet != nil, "FAILED: orderedSet should be non-null!");

    ASSERT_EQ(3, [orderedSet count]);
    NSEnumerator* enumerator = [orderedSet reverseObjectEnumerator];
    ASSERT_NE(nil, enumerator);

    NSUInteger i = [array count] - 2;
    while (id object = [enumerator nextObject]) {
        ASSERT_OBJCEQ(object, array[i]);
        i--;
    }
}

TEST(NSMutableOrderedSet, IntersectsSet) {
    NSSet* set = [NSSet setWithObjects:@"Tesla", @"Benz", @"BMW", @"Acura", @"Audi", nil];
    ASSERT_NE(nil, set);
    NSMutableOrderedSet* orderedSet = [NSMutableOrderedSet orderedSetWithObject:@"Benz"];
    ASSERT_NE(nil, orderedSet);
    ASSERT_TRUE([orderedSet intersectsSet:set]);
}

TEST(NSMutableOrderedSet, IntersectsOrderedSet) {
    NSMutableOrderedSet* orderedSet0 = [NSMutableOrderedSet orderedSetWithObject:@"Benz"];
    ASSERT_NE(nil, orderedSet0);
    NSMutableOrderedSet* orderedSet1 = [NSMutableOrderedSet orderedSetWithObjects:@"Benz", @"Acura", nil];
    ASSERT_NE(nil, orderedSet1);
    ASSERT_TRUE([orderedSet0 intersectsOrderedSet:orderedSet1]);
}

TEST(NSMutableOrderedSet, IsSubsetOfOrderedSet) {
    NSMutableOrderedSet* orderedSet0 = [NSMutableOrderedSet orderedSetWithObjects:@"Acura", @"Benz", nil];
    ASSERT_NE(nil, orderedSet0);
    NSMutableOrderedSet* orderedSet1 = [NSMutableOrderedSet orderedSetWithObjects:@"Benz", @"Acura", @"Tesla", nil];
    ASSERT_NE(nil, orderedSet1);
    ASSERT_TRUE([orderedSet0 isSubsetOfOrderedSet:orderedSet1]);
}

TEST(NSMutableOrderedSet, ContainsNil) {
    NSMutableOrderedSet* orderedSet = [NSMutableOrderedSet orderedSetWithObjects:@"Acura", @"Benz", nil];
    ASSERT_NE(nil, orderedSet);
    ASSERT_FALSE([orderedSet containsObject:nil]);
}

TEST(NSMutableOrderedSet, IsSubsetOfSet) {
    NSSet* set = [NSSet setWithObjects:@"Tesla", @"Benz", @"BMW", @"Acura", nil];
    ASSERT_NE(nil, set);
    NSMutableOrderedSet* orderedSet = [NSMutableOrderedSet orderedSetWithObjects:@"Tesla", @"Benz", @"BMW", @"Acura", @"Audi", nil];
    ASSERT_NE(nil, orderedSet);
    ASSERT_FALSE([orderedSet isSubsetOfSet:set]);
}

TEST(NSMutableOrderedSet, IsSubsetOfSet2) {
    NSSet* set = [NSSet setWithObjects:@"Tesla", @"Benz", @"BMW", @"Acura", @"Toyota", @"Audi", nil];
    ASSERT_NE(nil, set);
    NSMutableOrderedSet* orderedSet = [NSMutableOrderedSet orderedSetWithObjects:@"Tesla", @"Benz", @"BMW", @"Acura", @"Audi", nil];
    ASSERT_NE(nil, orderedSet);
    ASSERT_TRUE([orderedSet isSubsetOfSet:set]);
}

TEST(NSMutableOrderedSet, GetObjects) {
    NSMutableOrderedSet* orderedSet = [NSMutableOrderedSet orderedSetWithObjects:@"Tesla", @"Benz", @"BMW", @"Acura", nil];
    ASSERT_NE(nil, orderedSet);

    id* objects = (id*)malloc(sizeof(id) * 4);
    ASSERT_NE(nullptr, objects);
    [orderedSet getObjects:objects range:NSMakeRange(0, 4)];

    for (int i = 0; i < 4; i++) {
        ASSERT_OBJCEQ(objects[i], [orderedSet objectAtIndex:i]);
    }
    free(objects);
}

TEST(NSMutableOrderedSet, GetObjects2) {
    NSMutableOrderedSet* orderedSet = [NSMutableOrderedSet orderedSetWithObjects:@"Tesla", @"Benz", @"BMW", @"Acura", nil];
    ASSERT_NE(nil, orderedSet);

    id* objects = (id*)malloc(sizeof(id) * 2);
    ASSERT_NE(nullptr, objects);
    [orderedSet getObjects:objects range:NSMakeRange(1, 2)];

    for (int i = 0; i < 2; ++i) {
        ASSERT_OBJCEQ(objects[i], [orderedSet objectAtIndex:i + 1]);
    }

    free(objects);
}

TEST(NSMutableOrderedSet, IsEqualToOrderedSet) {
    NSMutableOrderedSet* orderedSet0 = [NSMutableOrderedSet orderedSetWithObjects:@"Tesla", @"Benz", @"BMW", @"Acura", @"Acura", nil];
    ASSERT_NE(nil, orderedSet0);

    NSMutableOrderedSet* orderedSet1 = [NSMutableOrderedSet orderedSetWithArray:@[ @"Tesla", @"Benz", @"BMW", @"Acura" ]];
    ASSERT_NE(nil, orderedSet1);
    ASSERT_TRUE([orderedSet0 isEqualToOrderedSet:orderedSet1]);
    ASSERT_FALSE([orderedSet0 isEqualToOrderedSet:[NSMutableOrderedSet orderedSet]]);
}

@interface TestPersonMutableOrderedSet : NSObject
- (instancetype)initWithName:(NSString*)name age:(NSUInteger)age;
@property (copy) NSString* name;
@property (assign) NSUInteger age;
@end

@implementation TestPersonMutableOrderedSet
- (instancetype)initWithName:(NSString*)name age:(NSUInteger)age {
    if (self = [super init]) {
        _name = [name copy];
        _age = age;
    }
    return self;
}

- (NSUInteger)hash {
    NSUInteger sum = 0;
    sum += _age;
    sum += [_name hash];

    return sum;
}

- (BOOL)isEqual:(id)other {
    if (other == nil) {
        return NO;
    }

    if (other == self) {
        return YES;
    }

    return ([_name isEqual:((TestPersonMutableOrderedSet*)other).name] && (_age == ((TestPersonMutableOrderedSet*)other).age));
}

- (void)dealloc {
    [_name release];
    [super dealloc];
}
@end

TEST(NSMutableOrderedSet, TestPersonMutableOrderedSet) {
    NSMutableArray* array = [NSMutableArray array];
    ASSERT_NE(nil, array);
    for (int i = 0; i < 5; i++) {
        TestPersonMutableOrderedSet* p = [[[TestPersonMutableOrderedSet alloc] initWithName:@"Bob" age:i] autorelease];
        ASSERT_NE(nil, p);
        [array addObject:p];
    }
    NSSet* set = [NSSet setWithArray:array];
    ASSERT_NE(nil, set);

    NSMutableOrderedSet* orderedSet = [NSMutableOrderedSet orderedSetWithSet:set];
    TestPersonMutableOrderedSet* p = [[[TestPersonMutableOrderedSet alloc] initWithName:@"Bob" age:1] autorelease];
    ASSERT_NE(nil, p);
    ASSERT_TRUE([orderedSet containsObject:p]);
}

TEST(NSMutableOrderedSet, InsertObject) {
    NSMutableOrderedSet* orderedSet = [NSMutableOrderedSet orderedSetWithObjects:@"Tesla", @"Benz", @"BMW", @"Acura", @"Acura", nil];
    ASSERT_NE(nil, orderedSet);
    ASSERT_EQ(4, [orderedSet count]);
    ASSERT_EQ(0, [orderedSet indexOfObject:@"Tesla"]);

    // insert duplicate
    [orderedSet insertObject:@"Acura" atIndex:0];

    ASSERT_EQ(4, [orderedSet count]);
    ASSERT_EQ(0, [orderedSet indexOfObject:@"Tesla"]);

    [orderedSet insertObject:@"Ford" atIndex:0];

    ASSERT_EQ(5, [orderedSet count]);
    ASSERT_EQ(0, [orderedSet indexOfObject:@"Ford"]);

    assertOrderedSetContent(orderedSet, @"Ford", @"Tesla", @"Benz", @"BMW", @"Acura", nil);

    [orderedSet insertObject:@"Toyota" atIndex:1];

    ASSERT_EQ(6, [orderedSet count]);
    assertOrderedSetContent(orderedSet, @"Ford", @"Toyota", @"Tesla", @"Benz", @"BMW", @"Acura", nil);
}

TEST(NSMutableOrderedSet, AddObject) {
    NSMutableOrderedSet* orderedSet = [NSMutableOrderedSet orderedSetWithObjects:@"Tesla", @"Benz", @"BMW", @"Acura", @"Acura", nil];
    ASSERT_NE(nil, orderedSet);
    ASSERT_EQ(4, [orderedSet count]);

    [orderedSet addObject:@"Ford"];

    ASSERT_EQ(5, [orderedSet count]);
    assertOrderedSetContent(orderedSet, @"Tesla", @"Benz", @"BMW", @"Acura", @"Ford", nil);
}

TEST(NSMutableOrderedSet, oneWayArray) {
    NSMutableOrderedSet* orderedSet = [NSMutableOrderedSet orderedSetWithObjects:@"Tesla", @"Benz", @"BMW", @"Acura", @"Acura", nil];
    ASSERT_NE(nil, orderedSet);

    NSArray* arrayObjs = [orderedSet array];
    ASSERT_NE(nil, arrayObjs);

    ASSERT_EQ(4, [orderedSet count]);

    // Adding the object to the set to see changes in the array.
    [orderedSet addObject:@"i5"];

    ASSERT_EQ(4, [arrayObjs indexOfObject:@"i5"]);
    ASSERT_EQ(5, [arrayObjs count]);
    ASSERT_TRUE([arrayObjs containsObject:@"i5"]);

    ASSERT_ANY_THROW([((NSMutableArray*)arrayObjs) addObject:@"test"]);
}

TEST(NSMutableOrderedSet, unionOrderedSet) {
    NSMutableOrderedSet* orderedSet1 = [NSMutableOrderedSet orderedSetWithObjects:@"Tesla", @"Benz", @"BMW", @"Acura", @"Acura", nil];
    NSMutableOrderedSet* orderedSet2 = [NSMutableOrderedSet orderedSetWithObjects:@"GM", @"Elio", nil];
    ASSERT_NE(nil, orderedSet1);
    ASSERT_NE(nil, orderedSet2);

    [orderedSet1 unionOrderedSet:orderedSet2];
    ASSERT_NE(nil, orderedSet1);
    ASSERT_NE(nil, orderedSet2);
    ASSERT_EQ(6, [orderedSet1 count]);
}

TEST(NSMutableOrderedSet, removeObject) {
    NSMutableOrderedSet* orderedSet = [NSMutableOrderedSet orderedSetWithObjects:@"Tesla", @"Benz", @"BMW", @"Acura", nil];
    ASSERT_NE(nil, orderedSet);
    [orderedSet removeObject:@"Tesla"];
    ASSERT_EQ(3, [orderedSet count]);
    ASSERT_FALSE([orderedSet containsObject:@"Tesla"]);
}

TEST(NSMutableOrderedSet, minusOrderedSet) {
    NSMutableOrderedSet* orderedSet = [NSMutableOrderedSet orderedSetWithObjects:@"Tesla", @"Benz", @"BMW", @"Acura", nil];
    NSMutableOrderedSet* orderedSetToRemove = [NSMutableOrderedSet orderedSetWithObjects:@"BMW", @"Acura", nil];
    ASSERT_NE(nil, orderedSet);
    ASSERT_NE(nil, orderedSetToRemove);
    [orderedSet minusOrderedSet:orderedSetToRemove];
    ASSERT_EQ(2, [orderedSet count]);
    ASSERT_FALSE([orderedSet containsObject:@"BMW"]);
    ASSERT_FALSE([orderedSet containsObject:@"Acura"]);
}
