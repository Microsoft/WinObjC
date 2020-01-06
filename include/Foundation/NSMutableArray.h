//******************************************************************************
//
// Copyright (c) 2016 Microsoft Corporation. All rights reserved.
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
#pragma once

#import <Foundation/FoundationExport.h>
#import <Foundation/NSFastEnumeration.h>
#import <Foundation/NSObject.h>

#import <Foundation/NSArray.h>

@class NSString;
@class NSURL;
@class NSIndexSet;
@class NSPredicate;
@class NSSortDescriptor;

FOUNDATION_EXPORT_CLASS
@interface NSMutableArray <ObjectType> : NSArray <ObjectType>
+ (instancetype)arrayWithCapacity:(NSUInteger)numItems;
- (instancetype)initWithCapacity:(NSUInteger)numItems;
- (void)addObject:(ObjectType)anObject;
- (void)addObjectsFromArray:(NSArray<ObjectType>*)otherArray;
- (void)insertObject:(ObjectType)anObject atIndex:(NSUInteger)index;
- (void)insertObjects:(NSArray<ObjectType>*)objects atIndexes:(NSIndexSet*)indexes;
- (void)removeAllObjects;
- (void)removeLastObject;
- (void)removeObject:(ObjectType)anObject;
- (void)removeObject:(ObjectType)anObject inRange:(NSRange)aRange;
- (void)removeObjectAtIndex:(NSUInteger)index;
- (void)removeObjectsAtIndexes:(NSIndexSet*)indexes;
- (void)removeObjectIdenticalTo:(ObjectType)anObject;
- (void)removeObjectIdenticalTo:(ObjectType)anObject inRange:(NSRange)aRange;
- (void)removeObjectsFromIndices:(NSUInteger*)indices numIndices:(NSUInteger)count STUB_METHOD;
- (void)removeObjectsInArray:(NSArray<ObjectType>*)otherArray;
- (void)removeObjectsInRange:(NSRange)aRange;
- (void)replaceObjectAtIndex:(NSUInteger)index withObject:(ObjectType)anObject;
- (void)setObject:(ObjectType)anObject atIndexedSubscript:(NSUInteger)index;
- (void)replaceObjectsAtIndexes:(NSIndexSet*)indexes withObjects:(NSArray<ObjectType>*)objects STUB_METHOD;
- (void)replaceObjectsInRange:(NSRange)aRange withObjectsFromArray:(NSArray<ObjectType>*)otherArray range:(NSRange)otherRange;
- (void)replaceObjectsInRange:(NSRange)aRange withObjectsFromArray:(NSArray<ObjectType>*)otherArray;
- (void)setArray:(NSArray<ObjectType>*)otherArray;
- (void)filterUsingPredicate:(NSPredicate*)predicate;
- (void)exchangeObjectAtIndex:(NSUInteger)idx1 withObjectAtIndex:(NSUInteger)idx2;
- (void)sortUsingDescriptors:(NSArray<NSSortDescriptor*>*)sortDescriptors;
- (void)sortUsingComparator:(NSComparator)cmptr;
- (void)sortWithOptions:(NSSortOptions)opts usingComparator:(NSComparator)cmptr;
- (void)sortUsingFunction:(NSInteger (*)(ObjectType, ObjectType, void*))compare context:(void*)context;
- (void)sortUsingSelector:(SEL)comparator;
@end
