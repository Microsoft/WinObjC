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

#import <Foundation/NSSet.h>

@class NSPredicate;
@class NSArray<ObjectType>;

FOUNDATION_EXPORT_CLASS
@interface NSMutableSet <ObjectType> : NSSet <ObjectType>
+ (instancetype)setWithCapacity:(NSUInteger)numItems;
- (instancetype)initWithCapacity:(NSUInteger)numItems;
- (void)addObject:(ObjectType)object;
- (void)filterUsingPredicate:(NSPredicate*)predicate;
- (void)removeObject:(ObjectType)object;
- (void)removeAllObjects;
- (void)addObjectsFromArray:(NSArray<ObjectType>*)array;
- (void)unionSet:(NSSet<ObjectType>*)otherSet;
- (void)minusSet:(NSSet<ObjectType>*)otherSet;
- (void)intersectSet:(NSSet<ObjectType>*)otherSet;
- (void)setSet:(NSSet<ObjectType>*)otherSet;
@end
