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

#include <TestFramework.h>
#include <Foundation/Foundation.h>
#include <Starboard/SmartTypes.h>

void assertArrayContents(NSArray* array, NSObject* first, ...) {
    va_list args;
    va_start(args, first);

    id curVal = first;

    size_t i = 0;
    while (curVal != nil) {
        ASSERT_OBJCEQ(curVal, [array objectAtIndex:i++]);
        curVal = va_arg(args, id);
    }

    va_end(args);

    ASSERT_EQ(i, [array count]);
}

TEST(NSArray, ArrayWithObjects) {
    // Empty list
    assertArrayContents([NSArray arrayWithObjects:nil], nil);

    // Single element
    assertArrayContents([NSArray arrayWithObjects:@1, nil], @1, nil);

    // Multiple elements
    assertArrayContents([NSArray arrayWithObjects:@1, @2, @3, nil], @1, @2, @3, nil);
}

TEST(NSArray, InitWithObjects) {
    // Empty list
    assertArrayContents([[NSArray alloc] initWithObjects:nil], nil);

    // Single element
    assertArrayContents([[NSArray alloc] initWithObjects:@1, nil], @1, nil);

    // Multiple elements
    assertArrayContents([[NSArray alloc] initWithObjects:@1, @2, @3, nil], @1, @2, @3, nil);
}

@interface NSTestArray : NSArray
@end

@implementation NSTestArray
- (NSUInteger)count {
    return 5;
}

- (id)objectAtIndex:(NSUInteger)index {
    return @2;
}
@end

TEST(NSArray, Subclassable) {
    NSArray* testArray = [NSTestArray new];
    ASSERT_EQ(@2, testArray[0]);
    int sum = 0;
    for (id val in testArray) {
        sum += [(NSNumber*)val integerValue];
    }
    ASSERT_EQ(10, sum);

    NSArray* testArray2 = @[ @2, @2, @2, @2, @2 ];

    ASSERT_OBJCEQ(testArray, testArray2);
}

NS_OPTIONS(NSUInteger, NSMutableTestArrayCalls){ countCalled,     objectAtIndexCalled,       insertObjectCalled,
                                                 addObjectCalled, removeObjectAtIndexCalled, replaceObjectAtIndexCalled };

@interface NSMutableTestArray : NSMutableArray
@property unsigned int calledMethods;
@end

@implementation NSMutableTestArray
- (NSUInteger)count {
    _calledMethods |= countCalled;
    return 5;
}

- (id)objectAtIndex:(NSUInteger)index {
    _calledMethods |= objectAtIndexCalled;
    return @2;
}

- (void)insertObject:(id)object atIndex:(NSUInteger)index {
    _calledMethods |= insertObjectCalled;
}

- (void)addObject:(id)anObject {
    _calledMethods |= addObjectCalled;
}

- (void)removeLastObject {
    // No test/flags for removeLastObject because it isn't called from any CF methods.
}

- (void)removeObjectAtIndex:(NSUInteger)index {
    _calledMethods |= removeObjectAtIndexCalled;
}
- (void)replaceObjectAtIndex:(NSUInteger)index withObject:(id)anObject {
    _calledMethods |= replaceObjectAtIndexCalled;
}

- (void)verifyAndResetFlags:(unsigned int)expectedCalls {
    ASSERT_EQ(expectedCalls & countCalled, _calledMethods & countCalled);
    ASSERT_EQ(expectedCalls & objectAtIndexCalled, _calledMethods & objectAtIndexCalled);
    ASSERT_EQ(expectedCalls & insertObjectCalled, _calledMethods & insertObjectCalled);
    ASSERT_EQ(expectedCalls & addObjectCalled, _calledMethods & addObjectCalled);
    ASSERT_EQ(expectedCalls & removeObjectAtIndexCalled, _calledMethods & removeObjectAtIndexCalled);
    ASSERT_EQ(expectedCalls & replaceObjectAtIndexCalled, _calledMethods & replaceObjectAtIndexCalled);
    _calledMethods = 0;
}
@end

TEST(NSArray, NSMutableArray_Subclassable) {
    NSMutableTestArray* testArray = [NSMutableTestArray new];
    CFMutableArrayRef test = (CFMutableArrayRef)testArray;

    CFArrayGetCount(test);
    [testArray verifyAndResetFlags:countCalled];

    CFArrayGetValueAtIndex(test, 2);
    [testArray verifyAndResetFlags:objectAtIndexCalled];

    CFArrayInsertValueAtIndex(test, 2, @2);
    [testArray verifyAndResetFlags:insertObjectCalled];

    CFArrayAppendValue(test, @2);
    [testArray verifyAndResetFlags:addObjectCalled];

    CFArrayRemoveValueAtIndex(test, 5);
    [testArray verifyAndResetFlags:removeObjectAtIndexCalled];

    CFArraySetValueAtIndex(test, 4, @3);
    [testArray verifyAndResetFlags:replaceObjectAtIndexCalled];
}

TEST(NSArray, NSArray_initWithContentsOfFile) {
    NSArray* expectedArray = @[ @1, @2, @3, @4, @5 ];

    NSArray* cachesPaths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSAllDomainsMask, YES);
    ASSERT_NE(0, [cachesPaths count]);
    NSString* path = cachesPaths[0];
    NSString* file = [path stringByAppendingPathComponent:@"array.data"];
    [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nullptr];
    [expectedArray writeToFile:file atomically:NO];
    NSArray* actualArray = [[NSArray alloc] initWithContentsOfFile:file];
    ASSERT_OBJCEQ(expectedArray, actualArray);
    [[NSFileManager defaultManager] removeItemAtPath:file error:nullptr];
}

TEST(NSArray, Enumerate) {
    __block NSArray* testArray = @[ @0, @1, @2, @3 ];

    [testArray enumerateObjectsWithOptions:0
                                usingBlock:^(id object, NSUInteger index, BOOL* stop) {
                                    ASSERT_EQ((unsigned)[(NSNumber*)[testArray objectAtIndex:index] integerValue], (unsigned)index);
                                }];

    __block unsigned expectedIndex = 3;
    // Verify that the NSReverseEnumeration option iterates in reverse
    [testArray enumerateObjectsWithOptions:NSEnumerationReverse
                                usingBlock:^(id object, NSUInteger index, BOOL* stop) {
                                    ASSERT_EQ(expectedIndex, index);
                                    ASSERT_EQ((unsigned)[(NSNumber*)[testArray objectAtIndex:index] integerValue], (unsigned)index);
                                    expectedIndex--;
                                }];

    // Verify that the NSEnumerationConcurrent option executes the blocks concurrently
    __block NSCondition* condition = [NSCondition new];
    __block unsigned waitingCount = 0;
    [testArray enumerateObjectsWithOptions:NSEnumerationConcurrent
                                usingBlock:^(id object, NSUInteger index, BOOL* stop) {
                                    [condition lock];
                                    waitingCount++;
                                    if (waitingCount == 4) {
                                        waitingCount--;
                                        [condition signal];
                                        [condition unlock];
                                        return;
                                    }
                                    [condition wait];
                                    waitingCount--;
                                    [condition signal];
                                    [condition unlock];
                                    ASSERT_EQ(index, [object integerValue]);
                                }];

    ASSERT_EQ(0, waitingCount);
}

TEST(NSArray, RemoveObjectsAtIndexes) {
    NSMutableIndexSet* indexSet = [[NSMutableIndexSet new] autorelease];
    [indexSet addIndexesInRange:NSMakeRange(2, 4)]; // [2-5]
    [indexSet addIndexesInRange:NSMakeRange(7, 2)]; // [7-8]

    NSMutableArray* testArray = [[NSMutableArray new] autorelease];
    for (NSUInteger i = 0; i < 10; i++) {
        [testArray addObject:@(i)];
    }

    [testArray removeObjectsAtIndexes:indexSet];

    NSArray* expectedArray = @[ @0, @1, @6, @9 ];

    ASSERT_OBJCEQ(testArray, expectedArray);
}

TEST(NSArray, Description) {
    NSArray* testArray = @[ @1, @2, @3 ];
    EXPECT_OBJCEQ(@"(\n    1,\n    2,\n    3\n)", [testArray description]);

    NSArray* testArray2 = [NSArray array];
    EXPECT_OBJCEQ(@"(\n)", [testArray2 description]);

    NSArray* testArray3 = @[ @1 ];
    EXPECT_OBJCEQ(@"(\n    1\n)", [testArray3 description]);

    NSArray* testArray4 = @[
        @1,
        testArray3,
        @"TEST",
        @[ @[ @[ @"VALUE" ] ] ],
    ];
    NSString* testValue4 = @"(\n"
                            "    1,\n"
                            "        (\n"
                            "        1\n"
                            "    ),\n"
                            "    TEST,\n"
                            "        (\n"
                            "                (\n"
                            "                        (\n"
                            "                VALUE\n"
                            "            )\n"
                            "        )\n"
                            "    )\n"
                            ")";
    EXPECT_OBJCEQ(testValue4, [testArray4 description]);
}

@interface NSArrayDescriptionTest : NSObject
+ (NSArrayDescriptionTest*)test;
- (NSString*)descriptionWithLocale:(id)locale indent:(NSUInteger)level;
- (NSString*)fakeDescriptionWithLocale:(id)locale indent:(NSUInteger)level;
- (NSString*)descriptionWithLocale:(id)locale;
- (NSString*)fakeDescriptionWithLocale:(id)locale;
- (NSString*)description;
@end

@implementation NSArrayDescriptionTest
+ (NSArrayDescriptionTest*)test {
    return [[NSArrayDescriptionTest new] autorelease];
}

- (NSString*)descriptionWithLocale:(id)locale indent:(NSUInteger)level {
    if (locale) {
        if (level > 1) {
            return @"Both";
        }

        return @"JustLocale";
    } else {
        if (level > 1) {
            return @"JustLevel";
        }

        return @"Neither";
    }
}
- (NSString*)fakeDescriptionWithLocale:(id)locale indent:(NSUInteger)level {
    return nil;
}

- (NSString*)descriptionWithLocale:(id)locale {
    if (locale) {
        return @"Locale";
    }

    return @"NoLocale";
}

- (NSString*)fakeDescriptionWithLocale:(id)locale {
    return nil;
}

- (NSString*)description {
    return @"Description";
}
@end

// Unfortunately despite what documentation suggests [NSArray descriptionWithLocale:] and [NSArray descriptionWithLocale:indent:]
// do not actually call descriptionWithLocale:indent: and descriptionWithLocale: when available (and does not follow the ordering
// specified to check for availability) so we are opting to implement this correctly and not test on the reference platform
OSX_DISABLED_TEST(NSArray, DescriptionWithLocale) {
    NSArray* testArray = @[ @"HI", [NSArrayDescriptionTest test] ];

    // Should default to descriptionWithLocale:indent:
    EXPECT_OBJCEQ(@"(\n    HI,\n    JustLocale\n)", [testArray descriptionWithLocale:[NSLocale currentLocale]]);
    EXPECT_OBJCEQ(@"(\n    HI,\n    Neither\n)", [testArray descriptionWithLocale:nil]);

    Method originalDescWithLocaleIndent = class_getInstanceMethod([NSArrayDescriptionTest class], @selector(descriptionWithLocale:indent:));
    Method fakeDescWithLocaleIndent = class_getInstanceMethod([NSArrayDescriptionTest class], @selector(fakeDescriptionWithLocale:indent:));
    method_exchangeImplementations(originalDescWithLocaleIndent, fakeDescWithLocaleIndent);

    // Should that fail then to descriptionWithLocale:
    EXPECT_OBJCEQ(@"(\n    HI,\n    Locale\n)", [testArray descriptionWithLocale:[NSLocale currentLocale]]);
    EXPECT_OBJCEQ(@"(\n    HI,\n    NoLocale\n)", [testArray descriptionWithLocale:nil]);

    Method originalDescWithLocale = class_getInstanceMethod([NSArrayDescriptionTest class], @selector(descriptionWithLocale:));
    Method fakeDescWithLocale = class_getInstanceMethod([NSArrayDescriptionTest class], @selector(fakeDescriptionWithLocale:));
    method_exchangeImplementations(originalDescWithLocale, fakeDescWithLocale);

    // Should that fail then to description
    EXPECT_OBJCEQ(@"(\n    HI,\n    Description\n)", [testArray descriptionWithLocale:[NSLocale currentLocale]]);
    EXPECT_OBJCEQ(@"(\n    HI,\n    Description\n)", [testArray descriptionWithLocale:nil]);

    method_exchangeImplementations(originalDescWithLocaleIndent, fakeDescWithLocaleIndent);
    method_exchangeImplementations(originalDescWithLocale, fakeDescWithLocale);
}

OSX_DISABLED_TEST(NSArray, DescriptionWithLocaleIndent) {
    NSArray* testArray = @[ @"HI", [NSArrayDescriptionTest test] ];

    // Should default to descriptionWithLocale:indent:
    EXPECT_OBJCEQ(@"    (\n        HI,\n        Both\n    )", [testArray descriptionWithLocale:[NSLocale currentLocale] indent:1]);
    EXPECT_OBJCEQ(@"(\n    HI,\n    JustLocale\n)", [testArray descriptionWithLocale:[NSLocale currentLocale] indent:0]);
    EXPECT_OBJCEQ(@"    (\n        HI,\n        JustLevel\n    )", [testArray descriptionWithLocale:nil indent:1]);
    EXPECT_OBJCEQ(@"(\n    HI,\n    Neither\n)", [testArray descriptionWithLocale:nil indent:0]);

    Method originalDescWithLocaleIndent = class_getInstanceMethod([NSArrayDescriptionTest class], @selector(descriptionWithLocale:indent:));
    Method fakeDescWithLocaleIndent = class_getInstanceMethod([NSArrayDescriptionTest class], @selector(fakeDescriptionWithLocale:indent:));
    method_exchangeImplementations(originalDescWithLocaleIndent, fakeDescWithLocaleIndent);

    // Should that fail then to descriptionWithLocale:
    EXPECT_OBJCEQ(@"(\n    HI,\n    Locale\n)", [testArray descriptionWithLocale:[NSLocale currentLocale] indent:0]);
    EXPECT_OBJCEQ(@"    (\n        HI,\n        Locale\n    )", [testArray descriptionWithLocale:[NSLocale currentLocale] indent:1]);
    EXPECT_OBJCEQ(@"(\n    HI,\n    NoLocale\n)", [testArray descriptionWithLocale:nil indent:0]);
    EXPECT_OBJCEQ(@"    (\n        HI,\n        NoLocale\n    )", [testArray descriptionWithLocale:nil indent:1]);

    Method originalDescWithLocale = class_getInstanceMethod([NSArrayDescriptionTest class], @selector(descriptionWithLocale:));
    Method fakeDescWithLocale = class_getInstanceMethod([NSArrayDescriptionTest class], @selector(fakeDescriptionWithLocale:));
    method_exchangeImplementations(originalDescWithLocale, fakeDescWithLocale);

    // Should that fail then to description
    EXPECT_OBJCEQ(@"(\n    HI,\n    Description\n)", [testArray descriptionWithLocale:[NSLocale currentLocale] indent:0]);
    EXPECT_OBJCEQ(@"    (\n        HI,\n        Description\n    )", [testArray descriptionWithLocale:[NSLocale currentLocale] indent:1]);
    EXPECT_OBJCEQ(@"(\n    HI,\n    Description\n)", [testArray descriptionWithLocale:nil indent:0]);
    EXPECT_OBJCEQ(@"    (\n        HI,\n        Description\n    )", [testArray descriptionWithLocale:nil indent:1]);

    method_exchangeImplementations(originalDescWithLocaleIndent, fakeDescWithLocaleIndent);
    method_exchangeImplementations(originalDescWithLocale, fakeDescWithLocale);
}

TEST(NSArray, Autorelease) {
    NSArray* array;
    NSObject* object = [NSObject new];
    ASSERT_EQ(1, [object retainCount]);
    {
        NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
        array = [NSArray arrayWithObject:object];
        [pool release];
    }

    ASSERT_EQ(1, [object retainCount]);
}

TEST(NSArray, ExpandBeyondCapacity) {
    NSMutableArray* array = [NSMutableArray arrayWithCapacity:1];

    NSUInteger expectedCount = 10;
    for (NSUInteger i = 0; i < expectedCount; i++) {
        [array addObject:[NSNumber numberWithInt:i]];
    }

    ASSERT_EQ(expectedCount, [array count]);
}

TEST(NSArray, AddingObjects) {
    assertArrayContents([@[ @1, @2 ] arrayByAddingObjectsFromArray:@[ @3, @4 ]], @1, @2, @3, @4, nil);
}

static unsigned long int objectIndexInArray(NSArray* array, int value, int startingFrom, int length, NSBinarySearchingOptions options = 0) {
    return [array indexOfObject:[NSNumber numberWithInteger:value]
                  inSortedRange:NSMakeRange(startingFrom, length)
                        options:options
                usingComparator:^(NSNumber* a, NSNumber* b) {
                    return [a compare:b];
                }];
}

TEST(NSArray, BinarySearchInsertionIndex) {
    NSArray* array = @[ @0, @1, @2, @2, @3, @4, @4, @6, @7, @7, @7, @8, @9, @9 ];

    EXPECT_TRUE_MSG(objectIndexInArray(array, 11, 0, array.count, 0) == NSNotFound, @"NSArray return NSNotFound if object is not found.");

    EXPECT_TRUE_MSG(objectIndexInArray(array, 11, 0, array.count, NSBinarySearchingFirstEqual) == NSNotFound,
                    @"NSArray return NSNotFound if object is not found.");

    EXPECT_TRUE_MSG(objectIndexInArray(array, 11, 0, array.count, NSBinarySearchingLastEqual) == NSNotFound,
                    @"NSArray return NSNotFound if object is not found.");

    auto notFoundInRange = objectIndexInArray(array, 7, 0, 5);
    EXPECT_TRUE_MSG(notFoundInRange == NSNotFound, @"NSArray return NSNotFound if object is not found.");

    auto indexOfAnySeven = objectIndexInArray(array, 7, 0, array.count);
    EXPECT_TRUE_MSG((indexOfAnySeven >= 8) && (indexOfAnySeven <= 10),
                    @"If no options provided NSArray returns an arbitrary matching object's index.");

    auto indexOfFirstNine = objectIndexInArray(array, 9, 7, array.count - 7, NSBinarySearchingFirstEqual);
    EXPECT_TRUE_MSG(indexOfFirstNine == 12, @"If NSBinarySearchingFirstEqual is set NSArray returns the lowest index of equal objects.");

    auto indexOfLastTwo = objectIndexInArray(array, 2, 1, 7, NSBinarySearchingLastEqual);
    EXPECT_TRUE_MSG(indexOfLastTwo == 3, @"If NSBinarySearchingLastEqual is set NSArray returns the highest index of equal objects.");

    auto anyIndexToInsertNine = objectIndexInArray(array, 9, 0, array.count, NSBinarySearchingInsertionIndex);
    EXPECT_TRUE_MSG(
        (anyIndexToInsertNine >= 12) && (anyIndexToInsertNine <= 14),
        @"If NSBinarySearchingInsertionIndex is specified and no other options provided NSArray returns any equal or one larger "
        @"index than any matching object’s index.");

    auto anyIndexToInsertNineteen = objectIndexInArray(array, 19, 0, array.count, NSBinarySearchingInsertionIndex);
    EXPECT_TRUE_MSG(
        anyIndexToInsertNineteen == array.count,
        @"If NSBinarySearchingInsertionIndex is specified and the value is greater than any objects of the array, the returned insertion "
        @"index is at the end of the array.");

    auto lowestIndexToInsertTwo = objectIndexInArray(array, 2, 0, 5, NSBinarySearchingInsertionIndex | NSBinarySearchingFirstEqual);
    EXPECT_TRUE_MSG(lowestIndexToInsertTwo == 2,
                    @"If both NSBinarySearchingInsertionIndex and NSBinarySearchingFirstEqual are specified "
                    @"NSArray returns the lowest index of equal objects.");

    auto highestIndexToInsertNine = objectIndexInArray(array, 9, 7, 6, NSBinarySearchingInsertionIndex | NSBinarySearchingLastEqual);
    EXPECT_TRUE_MSG(highestIndexToInsertNine == 13,
                    @"If both NSBinarySearchingInsertionIndex and NSBinarySearchingLastEqual are specified "
                    @"NSArray returns the index of the least greater object...");

    auto indexOfLeastGreaterObjectThanFive =
        objectIndexInArray(array, 5, 0, 10, NSBinarySearchingInsertionIndex | NSBinarySearchingLastEqual);
    EXPECT_TRUE_MSG(indexOfLeastGreaterObjectThanFive == 7,
                    @"If both NSBinarySearchingInsertionIndex and NSBinarySearchingLastEqual are "
                    @"specified NSArray returns the index of the least greater object...");

    auto rangeStart = 0;
    auto rangeLength = array.count;
    auto endOfArray = objectIndexInArray(array, 10, rangeStart, rangeLength, NSBinarySearchingInsertionIndex | NSBinarySearchingLastEqual);
    EXPECT_TRUE_MSG(endOfArray == (rangeStart + rangeLength),
                    @"...or the index at the end of the array if the object is larger than all other elements.");

    NSArray* arrayOfTwo = @[ @0, @2 ];
    auto indexInMiddle = objectIndexInArray(arrayOfTwo, 1, 0, 2, NSBinarySearchingInsertionIndex | NSBinarySearchingFirstEqual);
    EXPECT_EQ_MSG(indexInMiddle, 1, @"If no match found item should be inserted before least greater object");
    auto indexInMiddle2 = objectIndexInArray(arrayOfTwo, 1, 0, 2, NSBinarySearchingInsertionIndex | NSBinarySearchingLastEqual);
    EXPECT_EQ_MSG(indexInMiddle2, 1, @"If no match found item should be inserted before least greater object");
    auto indexInMiddle3 = objectIndexInArray(arrayOfTwo, 1, 0, 2, NSBinarySearchingInsertionIndex);
    EXPECT_EQ_MSG(indexInMiddle3, 1, @"If no match found item should be inserted before least greater object");
}

TEST(NSArray, MutateDuringEnumeration) {
    __block NSMutableArray* array = [NSMutableArray arrayWithObjects:@"A", @"B", @"C", nil];
    void (^enumerate)() = ^{
        for (id object in array) {
            [array addObject:@"<sound effects reminiscent of explosions>"];
        }
    };

    ASSERT_ANY_THROW(enumerate());
}

TEST(NSArray, SortedArrayWithOptions) {
    NSArray* unsortedArray = @[ @3, @11, @2, @12, @1, @13 ];

    NSArray* expectedSortedArray = @[ @1, @2, @3, @11, @12, @13 ];
    NSArray* actualSortedArray = [unsortedArray sortedArrayWithOptions:0
                                                       usingComparator:^NSComparisonResult(id obj1, id obj2) {
                                                           int val1 = [obj1 intValue];
                                                           int val2 = [obj2 intValue];

                                                           if (val1 == val2) {
                                                               return NSOrderedSame;
                                                           }

                                                           return (val1 > val2) ? NSOrderedDescending : NSOrderedAscending;
                                                       }];

    ASSERT_OBJCEQ(expectedSortedArray, actualSortedArray);

    // For our stable sort test, we compare using a comparator that treats 1, 2, and 3 as equal and 11, 12, and 13 as equal. Therefore
    // 3, 2, and 1 should be in original order.
    NSArray* expectedStableSort = @[ @3, @2, @1, @11, @12, @13 ];
    NSArray* actualStableSort = [unsortedArray sortedArrayWithOptions:NSSortStable
                                                      usingComparator:^NSComparisonResult(id obj1, id obj2) {
                                                          int val1 = [obj1 intValue];
                                                          int val2 = [obj2 intValue];

                                                          if (val1 < 10 && val2 < 10) {
                                                              return NSOrderedSame;
                                                          }

                                                          if (val1 > 10 && val2 > 10) {
                                                              return NSOrderedSame;
                                                          }

                                                          return (val1 > val2) ? NSOrderedDescending : NSOrderedAscending;
                                                      }];

    ASSERT_OBJCEQ(expectedStableSort, actualStableSort);
}

TEST(NSArray, MutableInstanceArchivesAsMutable) {
    NSMutableArray* input = [NSMutableArray arrayWithObject:@"hello"];

    NSData* data = [NSKeyedArchiver archivedDataWithRootObject:input];
    ASSERT_OBJCNE(nil, data);

    NSMutableArray* output = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    ASSERT_OBJCNE(nil, output);

    EXPECT_NO_THROW([output addObject:@"world"]);

    EXPECT_OBJCNE(input, output);
}

TEST(NSMutableArray, InsertingNilShouldThrow) {
    NSMutableArray* arr = [NSMutableArray arrayWithObject:@"hello"];
    EXPECT_ANY_THROW(arr[0] = nil);
    EXPECT_ANY_THROW([arr insertObject:nil atIndex:1]);
    EXPECT_ANY_THROW([arr addObject:nil]);
    EXPECT_ANY_THROW([arr replaceObjectAtIndex:0 withObject:nil]);
    EXPECT_OBJCEQ(@"hello", arr[0]);
    EXPECT_EQ(1, [arr count]);
}

TEST(NSArray, ReadWriteURL) {
    NSURL* url = [NSURL fileURLWithPath:@"arrayTestData.txt" isDirectory:NO];
    NSArray* arr = @[ @1, @[ @2, @"3" ], @"4", @{ @"5" : @6 } ];
    EXPECT_TRUE([arr writeToURL:url atomically:NO]);
    NSArray* read = [NSArray arrayWithContentsOfURL:url];
    EXPECT_OBJCEQ(arr, read);
}

TEST(NSArray, ShouldNotBeAbleToWriteInvalidToURL) {
    NSURL* url = [NSURL fileURLWithPath:@"arrayTestData.txt" isDirectory:NO];

    // Keys in dictionary must be NSString* to be written
    NSArray* arr = @[ @1, @{ @2 : @"3" } ];
    EXPECT_FALSE([arr writeToURL:url atomically:NO]);

    // NSURL* is not a PropertyList object so cannot be written
    NSArray* arr2 = @[ url, @1 ];
    EXPECT_FALSE([arr2 writeToURL:url atomically:NO]);

    // Array cannot have a circular dependency
    NSMutableArray* mutableArr = [NSMutableArray arrayWithObject:@1];
    [mutableArr addObject:mutableArr];
    EXPECT_FALSE([mutableArr writeToURL:url atomically:NO]);
}

TEST(NSArray, IndexOfObjectIdenticalTo) {
    NSArray* arr = @[ @"FIRST", @2, @3, @4, @4 ];

    EXPECT_EQ(NSNotFound, [arr indexOfObjectIdenticalTo:@6]);

    // Should not use isEqual, rather compare pointers
    UniChar chars[5] = { 'F', 'I', 'R', 'S', 'T' };
    EXPECT_EQ(NSNotFound, [arr indexOfObjectIdenticalTo:[NSString stringWithCharacters:chars length:5]]);

    EXPECT_EQ(0, [arr indexOfObjectIdenticalTo:arr[0]]);
    EXPECT_EQ(3, [arr indexOfObjectIdenticalTo:arr[4]]);
}

TEST(NSArray, IndexOfObjectIdenticalToInRange) {
    NSArray* arr = @[ @1, @2, @2, @4, @5 ];

    EXPECT_EQ(NSNotFound, [arr indexOfObjectIdenticalTo:arr[0] inRange:NSMakeRange(1, 3)]);
    EXPECT_EQ(NSNotFound, [arr indexOfObjectIdenticalTo:@0 inRange:NSMakeRange(0, 5)]);
    EXPECT_EQ(1, [arr indexOfObjectIdenticalTo:arr[1] inRange:NSMakeRange(1, 2)]);
    EXPECT_EQ(2, [arr indexOfObjectIdenticalTo:arr[1] inRange:NSMakeRange(2, 2)]);

    EXPECT_ANY_THROW([arr indexOfObjectIdenticalTo:@0 inRange:NSMakeRange(0, 7)]);
}

TEST(NSArray, IndexOfObjectPassingTest) {
    NSArray* arr = @[ @1, @2, @3, @4, @5 ];
    BOOL (^predicate)
    (id, NSUInteger, BOOL*) = ^(id obj, NSUInteger index, BOOL* stop) {
        return ([obj isEqual:@5] || index == 2) ? YES : NO;
    };

    NSMutableIndexSet* expected = [NSMutableIndexSet indexSetWithIndex:4];
    [expected addIndex:2];

    EXPECT_EQ(2, [arr indexOfObjectPassingTest:predicate]);
}

TEST(NSArray, IndexOfObjectWithOptionsPassingTest) {
    NSArray* arr = @[ @1, @4, @3, @4, @5 ];
    BOOL (^predicate)
    (id, NSUInteger, BOOL*) = ^(id obj, NSUInteger index, BOOL* stop) {
        if ([obj isEqual:@4]) {
            *stop = YES;
            return YES;
        }

        return NO;
    };

    EXPECT_EQ(1, [arr indexOfObjectWithOptions:0 passingTest:predicate]);
    EXPECT_EQ(3, [arr indexOfObjectWithOptions:NSEnumerationReverse passingTest:predicate]);
}

TEST(NSArray, IndexOfObjectAtIndexesOptionsPassingTest) {
    NSArray* arr = @[ @1, @4, @3, @4, @5 ];
    BOOL (^predicate)
    (id, NSUInteger, BOOL*) = ^(id obj, NSUInteger index, BOOL* stop) {
        if ([obj isEqual:@4]) {
            *stop = YES;
            return YES;
        }

        return NO;
    };

    NSIndexSet* ranges = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, 5)];
    EXPECT_EQ(1, [arr indexOfObjectAtIndexes:ranges options:0 passingTest:predicate]);
    EXPECT_EQ(3, [arr indexOfObjectAtIndexes:ranges options:NSEnumerationReverse passingTest:predicate]);

    NSIndexSet* illegal = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, 50)];
    EXPECT_ANY_THROW([arr indexOfObjectAtIndexes:illegal options:NSEnumerationReverse passingTest:predicate]);
}

TEST(NSArray, IndexesOfObjectsPassingTest) {
    NSArray* arr = @[ @1, @2, @3, @4, @5 ];
    BOOL (^predicate)
    (id, NSUInteger, BOOL*) = ^(id obj, NSUInteger index, BOOL* stop) {
        return ([obj isEqual:@5] || index == 2) ? YES : NO;
    };

    NSMutableIndexSet* expected = [NSMutableIndexSet indexSetWithIndex:4];
    [expected addIndex:2];

    EXPECT_OBJCEQ(expected, [arr indexesOfObjectsPassingTest:predicate]);
}

TEST(NSArray, IndexesOfObjectsWithOptionsPassingTest) {
    NSArray* arr = @[ @1, @4, @3, @4, @5 ];
    BOOL (^predicate)
    (id, NSUInteger, BOOL*) = ^(id obj, NSUInteger index, BOOL* stop) {
        if ([obj isEqual:@4]) {
            *stop = YES;
            return YES;
        }

        return NO;
    };

    NSIndexSet* expected = [NSIndexSet indexSetWithIndex:1];
    EXPECT_OBJCEQ(expected, [arr indexesOfObjectsWithOptions:0 passingTest:predicate]);

    expected = [NSIndexSet indexSetWithIndex:3];
    EXPECT_OBJCEQ(expected, [arr indexesOfObjectsWithOptions:NSEnumerationReverse passingTest:predicate]);
}

TEST(NSArray, IndexesOfObjectsAtIndexesOptionsPassingTest) {
    NSArray* arr = @[ @1, @4, @3, @4, @5 ];
    BOOL (^predicate)
    (id, NSUInteger, BOOL*) = ^(id obj, NSUInteger index, BOOL* stop) {
        if ([obj isEqual:@4]) {
            *stop = YES;
            return YES;
        }

        return NO;
    };

    NSIndexSet* expected = [NSIndexSet indexSetWithIndex:1];
    EXPECT_OBJCEQ(expected, [arr indexesOfObjectsAtIndexes:expected options:0 passingTest:predicate]);

    expected = [NSIndexSet indexSetWithIndex:3];
    EXPECT_OBJCEQ(expected, [arr indexesOfObjectsAtIndexes:expected options:NSEnumerationReverse passingTest:predicate]);

    NSIndexSet* ranges = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, 5)];
    EXPECT_OBJCEQ(expected, [arr indexesOfObjectsAtIndexes:ranges options:NSEnumerationReverse passingTest:predicate]);

    NSIndexSet* illegal = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, 50)];
    EXPECT_ANY_THROW([arr indexesOfObjectsAtIndexes:illegal options:NSEnumerationReverse passingTest:predicate]);
}

TEST(NSArray, EnumerateObjectsAtIndexesOptionsUsingBlock) {
    NSArray* arr = @[ @1, @2, @3, @4, @5 ];
    __block NSMutableArray* test = [NSMutableArray array];
    void (^block)(id, NSUInteger, BOOL*) = ^(id obj, NSUInteger index, BOOL* stop) {
        NSNumber* val = static_cast<NSNumber*>(obj);
        [test addObject:[NSNumber numberWithInt:val.intValue + index]];
    };

    NSIndexSet* indexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(1, 3)];
    [arr enumerateObjectsAtIndexes:indexes options:0 usingBlock:block];
    NSArray* expected = @[ @3, @5, @7 ];
    EXPECT_OBJCEQ(expected, test);

    test = [NSMutableArray array];
    [arr enumerateObjectsAtIndexes:indexes options:NSEnumerationReverse usingBlock:block];
    expected = @[ @7, @5, @3 ];
    EXPECT_OBJCEQ(expected, test);

    indexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(11, 11)];
    EXPECT_ANY_THROW([arr enumerateObjectsAtIndexes:indexes options:0 usingBlock:block]);
}

TEST(NSArray, RemoveObject) {
    StrongId<NSMutableArray*> array {
        woc::TakeOwnership, [@[ @1, @2, @1, @1, @3, @1, @4, @1, @5, @1, @1 ] mutableCopy]
    };

    [array removeObject:@1];
    NSArray* expected = @[ @2, @3, @4, @5 ];
    ASSERT_OBJCEQ(expected, array.get());
}

TEST(NSArray, RemoveObject_InRange) {
    StrongId<NSMutableArray*> array {
        woc::TakeOwnership, [@[ @1, @2, @1, @1, @3, @1, @4, @1, @5, @1, @1 ] mutableCopy]
    };

    [array removeObject:@1 inRange:NSRange{ 1, 9 }];
    NSArray* expected = @[ @1, @2, @3, @4, @5, @1 ];
    ASSERT_OBJCEQ(expected, array.get());
}

TEST(NSArray, RemoveObjectsInRange) {
    StrongId<NSMutableArray*> array {
        woc::TakeOwnership, [@[ @1, @2, @1, @3, @1, @4, @1, @5, @1 ] mutableCopy]
    };

    [array removeObjectsInRange:NSRange{ 1, 6 }];
    NSArray* expected = @[ @1, @5, @1 ];
    ASSERT_OBJCEQ(expected, array.get());
}

TEST(NSArray, RemoveObjectsInRange_Invalid) {
    StrongId<NSMutableArray*> array {
        woc::TakeOwnership, [@[ @1, @2, @1, @3, @1, @4, @1, @5, @1 ] mutableCopy]
    };

    NSRange range{ 10, 20 };
    EXPECT_ANY_THROW([array removeObjectsInRange:range]);
}

TEST(NSArray, RemoveObjectIdenticalTo) {
    NSNumber* one = @1; // Capture this here just to make sure it's the same pointer.
    StrongId<NSMutableArray*> array {
        woc::TakeOwnership, [@[ one, @2, one, one, @3, one, @4, one, @5, one, one ] mutableCopy]
    };

    [array removeObjectIdenticalTo:one];
    NSArray* expected = @[ @2, @3, @4, @5 ];
    ASSERT_OBJCEQ(expected, array.get());
}

TEST(NSArray, RemoveObjectIdenticalTo_InRange) {
    NSNumber* one = @1; // Capture this here just to make sure it's the same pointer.
    StrongId<NSMutableArray*> array {
        woc::TakeOwnership, [@[ one, @2, one, one, @3, one, @4, one, @5, one, one ] mutableCopy]
    };

    [array removeObjectIdenticalTo:one inRange:NSRange{ 1, 9 }];
    NSArray* expected = @[ one, @2, @3, @4, @5, one ];
    ASSERT_OBJCEQ(expected, array.get());
}

TEST(NSArray, ExchangeObjects) {
    StrongId<NSMutableArray*> array {
        woc::TakeOwnership, [@[ @1, @2, @3 ] mutableCopy]
    };

    [array exchangeObjectAtIndex:0 withObjectAtIndex:2];
    NSArray* expected = @[ @3, @2, @1 ];
    ASSERT_OBJCEQ(expected, array.get());
}

TEST(NSArray, RemoveObjectsRange_Sanity) {
    NSNumber* one = @1; // Capture this here just to make sure it's the same pointer.
    NSArray* original = @[ one, @2, @3 ];
    StrongId<NSMutableArray*> array{ woc::TakeOwnership, [original mutableCopy] };

    NSRange emptyRange{ 1, 0 };
    EXPECT_NO_THROW([array removeObjectsInRange:emptyRange]);
    EXPECT_OBJCEQ(original, array.get());

    EXPECT_NO_THROW([array removeObject:@2 inRange:emptyRange]);
    EXPECT_OBJCEQ(original, array.get());

    EXPECT_NO_THROW([array removeObjectIdenticalTo:one inRange:emptyRange]);
    EXPECT_OBJCEQ(original, array.get());
}
