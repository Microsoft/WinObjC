//******************************************************************************
//
// Copyright (c) 2016 Microsoft Corporation. All rights reserved.
// Copyright (c) 2007 Dirk Theisen
// Portions Copyright (c) 2013 Peter Steinberger. All rights reserved.
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
#import <Foundation/NSObject.h>
#import <Foundation/NSRange.h>

FOUNDATION_EXPORT_CLASS
@interface NSIndexPath : NSObject <NSCopying, NSSecureCoding> {
    NSUInteger _length;
    NSUInteger* _indexes;
}

+ (instancetype)indexPathWithIndex:(NSUInteger)index;
+ (instancetype)indexPathWithIndexes:(const NSUInteger[])indexes length:(NSUInteger)length;
+ (instancetype)indexPathForRow:(NSInteger)row inSection:(NSInteger)section;
+ (instancetype)indexPathForItem:(NSInteger)item inSection:(NSInteger)section;
- (instancetype)initWithIndex:(NSUInteger)index;
- (instancetype)initWithIndexes:(const NSUInteger[])indexes length:(NSUInteger)length;
- (instancetype)init STUB_METHOD;
- (NSUInteger)indexAtPosition:(NSUInteger)node;
- (NSIndexPath*)indexPathByAddingIndex:(NSUInteger)index;
- (NSIndexPath*)indexPathByRemovingLastIndex STUB_METHOD;
@property (readonly) NSUInteger length;
- (void)getIndexes:(NSUInteger*)indexes range:(NSRange)positionRange STUB_METHOD;
- (void)getIndexes:(NSUInteger*)indexes;
@property (readonly, nonatomic) NSInteger section;
@property (readonly, nonatomic) NSInteger row;
@property (readonly, nonatomic) NSInteger item;
- (NSComparisonResult)compare:(NSIndexPath*)indexPath;
@end
