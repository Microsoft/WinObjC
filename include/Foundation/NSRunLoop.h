//******************************************************************************
//
// Copyright (c) Microsoft. All rights reserved.
// Copyright (c) 2006-2007 Christopher J. W. Lloyd
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
#import <pthread.h>
#import <CoreFoundation/CFRunLoop.h>

@class NSString;
@class NSDate;
@class NSTimer;
@class NSPort;
@class NSArray;

typedef NSString* NSRunLoopMode;

FOUNDATION_EXPORT const NSRunLoopMode NSDefaultRunLoopMode;
FOUNDATION_EXPORT const NSRunLoopMode NSRunLoopCommonModes;

FOUNDATION_EXPORT_CLASS
@interface NSRunLoop : NSObject

+ (NSRunLoop*)currentRunLoop;
@property (readonly, copy) NSRunLoopMode currentMode;
- (NSDate*)limitDateForMode:(NSRunLoopMode)mode;
+ (NSRunLoop*)mainRunLoop;
- (CFRunLoopRef)getCFRunLoop;
- (void)addTimer:(NSTimer*)aTimer forMode:(NSRunLoopMode)mode;
- (void)addPort:(NSPort*)aPort forMode:(NSRunLoopMode)mode;
- (void)removePort:(NSPort*)aPort forMode:(NSRunLoopMode)mode STUB_METHOD;
- (void)run;
- (BOOL)runMode:(NSRunLoopMode)mode beforeDate:(NSDate*)limitDate;
- (void)runUntilDate:(NSDate*)limitDate;
- (void)acceptInputForMode:(NSRunLoopMode)mode beforeDate:(NSDate*)limitDate;
- (void)performSelector:(SEL)aSelector target:(id)target argument:(id)anArgument order:(NSUInteger)order modes:(NSArray*)modes;
- (void)cancelPerformSelector:(SEL)aSelector target:(id)target argument:(id)arg;
@end
