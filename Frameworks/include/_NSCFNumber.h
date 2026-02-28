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
#pragma once
#include <Foundation/NSNumber.h>
#include "_NSCFTemporaryRootObject.h"

#pragma region _NSCFNumber

// _NSCFTemporaryRootObject will be replaced with NSNumber at Foundation load time
@interface _NSCFNumberSuperclassAnchor : _NSCFTemporaryRootObject
@end

@interface _NSCFNumber : _NSCFNumberSuperclassAnchor

- (_Nonnull instancetype)retain;
- (oneway void)release;
- (_Nonnull instancetype)autorelease;
- (NSUInteger)retainCount;
- (void)dealloc;
+ (_Nonnull instancetype)allocWithZone:(NSZone* _Nullable)zone;

- (void)getValue:(void* _Nonnull)dest;
- (NSComparisonResult)compare:(NSNumber* _Nullable)aNumber;
- (BOOL)isEqual:(NSObject* _Nullable)obj;
- (const char* _Nonnull)objCType;

@property (readonly) BOOL boolValue;
@property (readonly) char charValue;
@property (readonly) double doubleValue;
@property (readonly) float floatValue;
@property (readonly) int intValue;
@property (readonly) NSInteger integerValue;
@property (readonly) long long longLongValue;
@property (readonly) long longValue;
@property (readonly) short shortValue;
@property (readonly) unsigned char unsignedCharValue;
@property (readonly) NSUInteger unsignedIntegerValue;
@property (readonly) unsigned int unsignedIntValue;
@property (readonly) unsigned long long unsignedLongLongValue;
@property (readonly) unsigned long unsignedLongValue;
@property (readonly) unsigned short unsignedShortValue;

@end

#pragma endregion

#pragma region _NSCFBoolean

// Subclass for bools only
@interface _NSCFBoolean : _NSCFNumberSuperclassAnchor

- (_Nonnull instancetype)retain;
- (oneway void)release;
- (_Nonnull instancetype)autorelease;
- (NSUInteger)retainCount;
- (void)dealloc;
+ (_Nonnull instancetype)allocWithZone:(NSZone* _Nullable)zone;

- (void)getValue:(void* _Nonnull)dest;
- (NSComparisonResult)compare:(NSNumber* _Nullable)aNumber;
- (BOOL)isEqual:(NSObject* _Nullable)obj;
- (const char* _Nonnull)objCType;

@property (readonly) BOOL boolValue;
@property (readonly) char charValue;
@property (readonly) double doubleValue;
@property (readonly) float floatValue;
@property (readonly) int intValue;
@property (readonly) NSInteger integerValue;
@property (readonly) long long longLongValue;
@property (readonly) long longValue;
@property (readonly) short shortValue;
@property (readonly) unsigned char unsignedCharValue;
@property (readonly) NSUInteger unsignedIntegerValue;
@property (readonly) unsigned int unsignedIntValue;
@property (readonly) unsigned long long unsignedLongLongValue;
@property (readonly) unsigned long unsignedLongValue;
@property (readonly) unsigned short unsignedShortValue;

@end

#pragma endregion