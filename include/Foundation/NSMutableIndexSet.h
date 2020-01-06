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
#import <Foundation/NSObject.h>

#import <Foundation/NSIndexSet.h>

FOUNDATION_EXPORT_CLASS
@interface NSMutableIndexSet : NSIndexSet
- (void)addIndex:(NSUInteger)index;
- (void)addIndexes:(NSIndexSet*)indexSet;
- (void)addIndexesInRange:(NSRange)indexRange;
- (void)removeIndex:(NSUInteger)index;
- (void)removeIndexes:(NSIndexSet*)indexSet;
- (void)removeAllIndexes;
- (void)removeIndexesInRange:(NSRange)indexRange;
- (void)shiftIndexesStartingAtIndex:(NSUInteger)startIndex by:(NSInteger)delta;
@end
