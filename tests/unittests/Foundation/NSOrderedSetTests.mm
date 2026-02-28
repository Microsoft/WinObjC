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

TEST(NSOrderedSet, Init) {
    NSOrderedSet* orderedSet = [[NSOrderedSet alloc] init];
    ASSERT_TRUE_MSG(orderedSet != nil, "FAILED: orderedSet should be non-null!");
    [orderedSet release];
}

TEST(NSOrderedSet, OrderedSet) {
    NSOrderedSet* orderedSet = [NSOrderedSet orderedSet];
    ASSERT_TRUE_MSG(orderedSet != nil, "FAILED: orderedSet should be non-null!");
    ASSERT_EQ(0, [orderedSet count]);
}

TEST(NSOrderedSet, Contains) {
    NSOrderedSet* orderedSet = [NSOrderedSet orderedSetWithObjects:@"Acura", @"Benz", nil];
    ASSERT_NE(nil, orderedSet);
    ASSERT_TRUE([orderedSet containsObject:@"Benz"]);
}

TEST(NSOrderedSet, OrderedSetWithArray) {
    NSArray* array = @[ @1, @1, @1, @2, @2, @3 ];
    NSOrderedSet* orderedSet = [NSOrderedSet orderedSetWithArray:array];
    ASSERT_TRUE_MSG(orderedSet != nil, "FAILED: orderedSet should be non-null!");

    ASSERT_EQ(3, [orderedSet count]);
    ASSERT_OBJCEQ(@1, [orderedSet firstObject]);
    ASSERT_OBJCEQ(@3, [orderedSet lastObject]);
}

TEST(NSOrderedSet, OrderedSetWithArrayWithOptions) {
    NSArray* array = @[ @1, @2, @3, @4, @5, @6 ];
    NSOrderedSet* orderedSet = [NSOrderedSet orderedSetWithArray:array range:NSMakeRange(2, 3) copyItems:YES];
    ASSERT_TRUE_MSG(orderedSet != nil, "FAILED: orderedSet should be non-null!");

    ASSERT_EQ(3, [orderedSet count]);
    ASSERT_OBJCEQ(@3, [orderedSet firstObject]);
    ASSERT_OBJCEQ(@5, [orderedSet lastObject]);
}

TEST(NSOrderedSet, OrderedSetWithArrayWithOptions2) {
    NSArray* array = @[ @5, @5, @5, @5, @7, @6, @2, @3 ];
    NSOrderedSet* orderedSet = [NSOrderedSet orderedSetWithArray:array range:NSMakeRange(0, 8) copyItems:YES];
    ASSERT_TRUE_MSG(orderedSet != nil, "FAILED: orderedSet should be non-null!");

    ASSERT_EQ(5, [orderedSet count]);
    ASSERT_OBJCEQ(@5, [orderedSet firstObject]);
    ASSERT_OBJCEQ(@3, [orderedSet lastObject]);
}

TEST(NSOrderedSet, OrderedSetWithObjects) {
    id array[3] = { @2, @1, @1 };
    NSOrderedSet* orderedSet = [NSOrderedSet orderedSetWithObjects:array count:3];
    ASSERT_EQ(2, [orderedSet count]);
    ASSERT_OBJCEQ(@2, [orderedSet firstObject]);
    ASSERT_OBJCEQ(@1, [orderedSet lastObject]);
}

TEST(NSOrderedSet, OrderedSetWithOrderedSet) {
    id array[3] = { @2, @1, @1 };
    NSOrderedSet* set = [NSOrderedSet orderedSetWithObjects:array count:3];

    NSOrderedSet* orderedSet = [NSOrderedSet orderedSetWithOrderedSet:set range:NSMakeRange(0, [set count]) copyItems:NO];
    ASSERT_EQ(2, [orderedSet count]);
    ASSERT_OBJCEQ(@2, [orderedSet firstObject]);
    ASSERT_OBJCEQ(@1, [orderedSet lastObject]);
}

TEST(NSOrderedSet, OrderedSetWithSet) {
    NSSet* set = [NSSet setWithObjects:@"Tesla", @"Benz", @"BMW", @"Acura", @"Audi", nil];
    NSOrderedSet* orderedSet = [NSOrderedSet orderedSetWithSet:set copyItems:YES];
    ASSERT_EQ(5, [orderedSet count]);
    ASSERT_TRUE([orderedSet containsObject:@"Tesla"]);
}

TEST(NSOrderedSet, CheckFullOrder) {
    NSArray* array = @[ @1, @2, @3, @4, @5, @5, @5 ];
    NSOrderedSet* orderedSet = [NSOrderedSet orderedSetWithArray:array range:NSMakeRange(0, 7) copyItems:YES];
    ASSERT_TRUE_MSG(orderedSet != nil, "FAILED: orderedSet should be non-null!");

    ASSERT_EQ(5, [orderedSet count]);
    NSUInteger count = [orderedSet count];
    for (NSUInteger i = 0; i < count; ++i) {
        ASSERT_OBJCEQ([orderedSet objectAtIndex:i], array[i]);
    }
}

TEST(NSOrderedSet, CheckOrder) {
    // Empty list
    NSOrderedSet* orderedSet = [NSOrderedSet orderedSetWithObjects:nil];
    ASSERT_NE(nil, orderedSet);
    ASSERT_EQ(0, [orderedSet count]);

    // Single element
    assertOrderedSetContent([NSOrderedSet orderedSetWithObjects:@1, nil], @1, nil);

    // Multiple elements
    assertOrderedSetContent([NSOrderedSet orderedSetWithObjects:@1, @2, @3, nil], @1, @2, @3, nil);
}

TEST(NSOrderedSet, Array) {
    NSArray* array = @[ @1, @2, @3, @4, @5, @5, @5 ];
    NSOrderedSet* orderedSet = [NSOrderedSet orderedSetWithArray:array];
    ASSERT_TRUE_MSG(orderedSet != nil, "FAILED: orderedSet should be non-null!");

    ASSERT_EQ(5, [orderedSet count]);
    NSArray* setArray = [orderedSet array];
    ASSERT_NE(nil, setArray);

    NSUInteger count = [setArray count];
    for (NSUInteger i = 0; i < count; ++i) {
        ASSERT_OBJCEQ([setArray objectAtIndex:i], array[i]);
    }
}

TEST(NSOrderedSet, ObjectEnumerator) {
    NSArray* array = @[ @"Tom", @"Bob", @"Ann", @"Ann" ];
    NSOrderedSet* orderedSet = [NSOrderedSet orderedSetWithArray:array];
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

TEST(NSOrderedSet, ReverseObjectEnumerator) {
    NSArray* array = @[ @"Tom", @"Bob", @"Ann", @"Ann" ];
    NSOrderedSet* orderedSet = [NSOrderedSet orderedSetWithArray:array];
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

TEST(NSOrderedSet, IntersectsSet) {
    NSSet* set = [NSSet setWithObjects:@"Tesla", @"Benz", @"BMW", @"Acura", @"Audi", nil];
    ASSERT_NE(nil, set);
    NSOrderedSet* orderedSet = [NSOrderedSet orderedSetWithObject:@"Benz"];
    ASSERT_NE(nil, orderedSet);
    ASSERT_TRUE([orderedSet intersectsSet:set]);
}

TEST(NSOrderedSet, IntersectsOrderedSet) {
    NSOrderedSet* orderedSet0 = [NSOrderedSet orderedSetWithObject:@"Benz"];
    ASSERT_NE(nil, orderedSet0);
    NSOrderedSet* orderedSet1 = [NSOrderedSet orderedSetWithObjects:@"Benz", @"Acura", nil];
    ASSERT_NE(nil, orderedSet1);
    ASSERT_TRUE([orderedSet0 intersectsOrderedSet:orderedSet1]);
}

TEST(NSOrderedSet, IsSubsetOfOrderedSet) {
    NSOrderedSet* orderedSet0 = [NSOrderedSet orderedSetWithObjects:@"Acura", @"Benz", nil];
    ASSERT_NE(nil, orderedSet0);
    NSOrderedSet* orderedSet1 = [NSOrderedSet orderedSetWithObjects:@"Benz", @"Acura", @"Tesla", nil];
    ASSERT_NE(nil, orderedSet1);
    ASSERT_TRUE([orderedSet0 isSubsetOfOrderedSet:orderedSet1]);
}

TEST(NSOrderedSet, ContainsNil) {
    NSOrderedSet* orderedSet = [NSOrderedSet orderedSetWithObjects:@"Acura", @"Benz", nil];
    ASSERT_NE(nil, orderedSet);
    ASSERT_FALSE([orderedSet containsObject:nil]);
}

TEST(NSOrderedSet, IsSubsetOfSet) {
    NSSet* set = [NSSet setWithObjects:@"Tesla", @"Benz", @"BMW", @"Acura", nil];
    ASSERT_NE(nil, set);
    NSOrderedSet* orderedSet = [NSOrderedSet orderedSetWithObjects:@"Tesla", @"Benz", @"BMW", @"Acura", @"Audi", nil];
    ASSERT_NE(nil, orderedSet);
    ASSERT_FALSE([orderedSet isSubsetOfSet:set]);
}

TEST(NSOrderedSet, IsSubsetOfSet2) {
    NSSet* set = [NSSet setWithObjects:@"Tesla", @"Benz", @"BMW", @"Acura", @"Toyota", @"Audi", nil];
    ASSERT_NE(nil, set);
    NSOrderedSet* orderedSet = [NSOrderedSet orderedSetWithObjects:@"Tesla", @"Benz", @"BMW", @"Acura", @"Audi", nil];
    ASSERT_NE(nil, orderedSet);
    ASSERT_TRUE([orderedSet isSubsetOfSet:set]);
}

TEST(NSOrderedSet, GetObjects) {
    NSOrderedSet* orderedSet = [NSOrderedSet orderedSetWithObjects:@"Tesla", @"Benz", @"BMW", @"Acura", nil];
    ASSERT_NE(nil, orderedSet);

    id* objects = (id*)malloc(sizeof(id) * 4);
    ASSERT_NE(nullptr, objects);
    [orderedSet getObjects:objects range:NSMakeRange(0, 4)];

    for (int i = 0; i < 4; i++) {
        ASSERT_OBJCEQ(objects[i], [orderedSet objectAtIndex:i]);
    }
    free(objects);
}

TEST(NSOrderedSet, GetObjects2) {
    NSOrderedSet* orderedSet = [NSOrderedSet orderedSetWithObjects:@"Tesla", @"Benz", @"BMW", @"Acura", nil];
    ASSERT_NE(nil, orderedSet);

    id* objects = (id*)malloc(sizeof(id) * 2);
    ASSERT_NE(nullptr, objects);
    [orderedSet getObjects:objects range:NSMakeRange(1, 2)];

    for (int i = 0; i < 2; ++i) {
        ASSERT_OBJCEQ(objects[i], [orderedSet objectAtIndex:i + 1]);
    }

    free(objects);
}

TEST(NSOrderedSet, IsEqualToOrderedSet) {
    NSOrderedSet* orderedSet0 = [NSOrderedSet orderedSetWithObjects:@"Tesla", @"Benz", @"BMW", @"Acura", @"Acura", nil];
    ASSERT_NE(nil, orderedSet0);

    NSOrderedSet* orderedSet1 = [NSOrderedSet orderedSetWithArray:@[ @"Tesla", @"Benz", @"BMW", @"Acura" ]];
    ASSERT_NE(nil, orderedSet1);
    ASSERT_TRUE([orderedSet0 isEqualToOrderedSet:orderedSet1]);
    ASSERT_FALSE([orderedSet0 isEqualToOrderedSet:[NSOrderedSet orderedSet]]);
}

TEST(NSOrderedSet, initWithObjects) {
    NSOrderedSet* orderedSet = [[[NSOrderedSet alloc] initWithObjects:NULL count:0] autorelease];
    ASSERT_NE(nil, orderedSet);
    ASSERT_ANY_THROW({ orderedSet = [[NSOrderedSet alloc] initWithObjects:NULL count:1]; });
}

@interface TestPersonOrderedSet : NSObject
- (instancetype)initWithName:(NSString*)name age:(NSUInteger)age;
@property (copy) NSString* name;
@property (assign) NSUInteger age;
@end

@implementation TestPersonOrderedSet
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

    return ([_name isEqual:((TestPersonOrderedSet*)other).name] && (_age == ((TestPersonOrderedSet*)other).age));
}

- (void)dealloc {
    [_name release];
    [super dealloc];
}
@end

TEST(NSOrderedSet, TestPersonOrderedSet) {
    NSMutableArray* array = [NSMutableArray array];
    ASSERT_NE(nil, array);
    for (int i = 0; i < 5; i++) {
        TestPersonOrderedSet* p = [[[TestPersonOrderedSet alloc] initWithName:@"Bob" age:i] autorelease];
        ASSERT_NE(nil, p);
        [array addObject:p];
    }
    NSSet* set = [NSSet setWithArray:array];
    ASSERT_NE(nil, set);

    NSOrderedSet* orderedSet = [NSOrderedSet orderedSetWithSet:set];
    TestPersonOrderedSet* person = [[TestPersonOrderedSet alloc] initWithName:@"Bob" age:1];
    ASSERT_NE(nil, person);
    ASSERT_TRUE([orderedSet containsObject:person]);
    [person release];
}
