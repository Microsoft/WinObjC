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
#include <Foundation/NSMutableString.h>
#include "_NSCFTemporaryRootObject.h"

@interface _NSCFStringSuperclassAnchor : _NSCFTemporaryRootObject
@end

// _NSCFTemporaryRootObject will be replaced with NSMutableString at Foundation load time
FOUNDATION_EXPORT_CLASS
@interface _NSCFString : _NSCFStringSuperclassAnchor

- (_Nonnull instancetype)retain;
- (oneway void)release;
- (_Nonnull instancetype)autorelease;
- (NSUInteger)retainCount;
- (void)dealloc;
+ (_Nonnull instancetype)allocWithZone:(NSZone* _Nullable)zone;

- (NSUInteger)length;
- (unichar)characterAtIndex:(NSUInteger)index;
- (void)getCharacters:(unichar* _Nonnull)buffer range:(NSRange)range;
- (void)replaceCharactersInRange:(NSRange)range withString:(NSString* _Nonnull)replacement;
- (_Nonnull instancetype)copyWithZone:(NSZone* _Nullable)zone;

@end
