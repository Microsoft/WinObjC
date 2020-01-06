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
#import <Foundation/NSOrderedSet.h>

@class NSArray<ObjectType>;
@class NSIndexSet;
@class NSPredicate;
@class NSSet<ObjectType>;

FOUNDATION_EXPORT_CLASS
@interface NSMutableOrderedSet <ObjectType> : NSOrderedSet <ObjectType>
+(instancetype)orderedSetWithCapacity : (NSUInteger)numItems STUB_METHOD;
- (instancetype)initWithCapacity:(NSUInteger)numItems STUB_METHOD;
- (instancetype)init;
- (void)addObject:(ObjectType)object;
- (void)addObjects:(const ObjectType _Nonnull[])objects count:(NSUInteger)count STUB_METHOD;
- (void)addObjectsFromArray:(NSArray<ObjectType>*)array STUB_METHOD;
- (void)insertObject:(ObjectType)object atIndex:(NSUInteger)idx;
- (void)setObject:(ObjectType)object atIndexedSubscript:(NSUInteger)idx STUB_METHOD;
- (void)insertObjects:(NSArray<ObjectType>*)objects atIndexes:(NSIndexSet*)indexes STUB_METHOD;
- (void)removeObject:(ObjectType)object;
- (void)removeObjectAtIndex:(NSUInteger)idx STUB_METHOD;
- (void)removeObjectsAtIndexes:(NSIndexSet*)indexes STUB_METHOD;
- (void)removeObjectsInArray:(NSArray<ObjectType>*)array STUB_METHOD;
- (void)removeObjectsInRange:(NSRange)range STUB_METHOD;
- (void)removeAllObjects STUB_METHOD;
- (void)replaceObjectAtIndex:(NSUInteger)idx withObject:(ObjectType)object STUB_METHOD;
- (void)replaceObjectsAtIndexes:(NSIndexSet*)indexes withObjects:(NSArray<ObjectType>*)objects STUB_METHOD;
- (void)replaceObjectsInRange:(NSRange)range withObjects:(const ObjectType _Nonnull[])objects count:(NSUInteger)count STUB_METHOD;
- (void)setObject:(ObjectType)obj atIndex:(NSUInteger)idx STUB_METHOD;
- (void)moveObjectsAtIndexes:(NSIndexSet*)indexes toIndex:(NSUInteger)idx STUB_METHOD;
- (void)exchangeObjectAtIndex:(NSUInteger)idx1 withObjectAtIndex:(NSUInteger)idx2 STUB_METHOD;
- (void)filterUsingPredicate:(NSPredicate*)predicate STUB_METHOD;
- (void)sortUsingDescriptors:(NSArray<ObjectType>*)sortDescriptors STUB_METHOD;
- (void)sortUsingComparator:(NSComparator)cmptr STUB_METHOD;
- (void)sortWithOptions:(NSSortOptions)opts usingComparator:(NSComparator)cmptr STUB_METHOD;
- (void)sortRange:(NSRange)range options:(NSSortOptions)opts usingComparator:(NSComparator)cmptr STUB_METHOD;
- (void)intersectOrderedSet:(NSOrderedSet<ObjectType>*)other STUB_METHOD;
- (void)intersectSet:(NSSet<ObjectType>*)other STUB_METHOD;
- (void)minusOrderedSet:(NSOrderedSet<ObjectType>*)other;
- (void)minusSet:(NSSet<ObjectType>*)other STUB_METHOD;
- (void)unionOrderedSet:(NSOrderedSet<ObjectType>*)other;
- (void)unionSet:(NSSet<ObjectType>*)other STUB_METHOD;
@end
