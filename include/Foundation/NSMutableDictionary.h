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
#pragma once

#import <Foundation/FoundationExport.h>
#import <Foundation/NSFastEnumeration.h>
#import <Foundation/NSObject.h>

#import <Foundation/NSDictionary.h>

@class NSString;
@class NSArray<ObjectType>;

FOUNDATION_EXPORT_CLASS
@interface NSMutableDictionary <KeyType, ObjectType> : NSDictionary <KeyType, ObjectType>
+ (instancetype)dictionaryWithCapacity:(NSUInteger)numItems;
- (instancetype)initWithCapacity:(NSUInteger)numItems;
+ (NSMutableDictionary*)dictionaryWithSharedKeySet:(id)keyset;
- (void)setObject:(ObjectType)anObject forKey:(id<NSCopying>)aKey;
- (void)setObject:(ObjectType)object forKeyedSubscript:(id<NSCopying>)aKey;
- (void)setValue:(ObjectType)value forKey:(NSString*)key;
- (void)addEntriesFromDictionary:(NSDictionary<KeyType, ObjectType>*)otherDictionary;
- (void)setDictionary:(NSDictionary<KeyType, ObjectType>*)otherDictionary;
- (void)removeObjectForKey:(KeyType)aKey;
- (void)removeAllObjects;
- (void)removeObjectsForKeys:(NSArray<KeyType>*)keyArray;
@end
