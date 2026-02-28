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

#import <math.h>
#import <Starboard.h>
#import <CoreFoundation/CFArray.h>
#import <Foundation/NSRunLoop.h>
#import <Foundation/NSDate.h>
#import <Foundation/NSTimer.h>
#import "NSRunLoopState.h"
#import "NSRunLoop+Internal.h"
#include "LoggingNative.h"

static const wchar_t* TAG = L"NSTimer";

@implementation NSTimer {
    BOOL _repeats;
    BOOL _valid;
    BOOL _isDestroying;
    id _timerTarget;
    BOOL _timerTargetReleased;
    double _interval;
    double _nextFireTime;
    SEL _sel;
    NSObject* _userInfo;
    StrongId<NSMutableArray> _addedToModes;
    BOOL _canFire;
}

/**
 @Status Interoperable
*/
- (void)invalidate {
    if (_valid) {
        _valid = NO;
        [_timerTarget release];
        _timerTargetReleased = YES;
    }
}

/**
 @Status Interoperable
*/
- (BOOL)isValid {
    return _valid;
}

- (void)_addedToMode:(NSRunLoopState*)runLoopState {
    [_addedToModes addObject:runLoopState];
}

- (void)_removedFromMode:(NSRunLoopState*)runLoopState {
    [_addedToModes removeObject:runLoopState];
}

/**
 @Status Interoperable
*/
- (void)dealloc {
    if (_isDestroying) {
        TraceWarning(TAG, L"Warning: NSTimer over-released");
        return;
    }

    _isDestroying = YES;
    int count = [_addedToModes count] - 1;
    while (count >= 0) {
        NSRunLoopState* runLoopState = [_addedToModes objectForIndex:count];
        [runLoopState removeTimer:self];
        count--;
    }

    if (!_timerTargetReleased) {
        _timerTargetReleased = YES;
        [_timerTarget release];
    }

    if (_userInfo != nil) {
        [_userInfo release];
    }

    [super dealloc];
}

/**
 @Status Interoperable
*/
- (void)fire {
    [self retain];

    if (_canFire) {
        _canFire = NO;

        if (_valid) {
            if (_repeats) {
                double curTime = [NSDate timeIntervalSinceReferenceDate];
                if (_interval > 0.0) {
                    _nextFireTime += (floor((curTime - _nextFireTime) / _interval) + 1.0) * _interval;
                } else {
                    _nextFireTime = curTime;
                }
            }

            if (_sel != NULL) {
                [_timerTarget performSelector:_sel withObject:self];
            } else {
                [_timerTarget invoke];
            }

            if (!_repeats) {
                _valid = NO;
            }
        }

        _canFire = YES;
    }

    [self release];
}

/**
 @Status Interoperable
*/
- (NSObject*)userInfo {
    return _userInfo;
}

/**
 @Status Interoperable
*/
- (double)timeInterval {
    double ret;

    if (_repeats && _valid) {
        ret = _interval;
    } else {
        ret = 0;
    }
    return ret;
}

/**
 @Status Interoperable
*/
- (double)nextFireTime {
    double ret;

    if (!_valid) {
        ret = 0.0f;
    } else {
        ret = _nextFireTime;
    }

    return ret;
}

/**
 @Status Interoperable
*/
- (instancetype)initWithTimeInterval:(double)seconds
                              target:(id)target
                            selector:(SEL)selector
                            userInfo:(NSObject*)userInfo
                             repeats:(BOOL)repeats {
    if (self = [super init]) {
        _interval = ((seconds > 0.0) ? seconds : 0.0001);
        _timerTarget = [target retain];
        _sel = selector;
        _userInfo = [userInfo retain];
        _repeats = repeats;
        _canFire = YES;
        _valid = YES;
        _addedToModes.attach((NSMutableArray*)CFArrayCreateMutable(NULL, 0, NULL));
        _nextFireTime = [NSDate timeIntervalSinceReferenceDate] + _interval;
    }

    return self;
}

/**
 @Status Interoperable
*/
+ (NSTimer*)scheduledTimerWithTimeInterval:(double)seconds
                                    target:(id)target
                                  selector:(SEL)selector
                                  userInfo:(NSObject*)userInfo
                                   repeats:(BOOL)repeats {
    NSTimer* pNewTimer = [[self alloc] initWithTimeInterval:seconds target:target selector:selector userInfo:userInfo repeats:repeats];

    [[NSRunLoop currentRunLoop] addTimer:pNewTimer forMode:@"kCFRunLoopDefaultMode"];
    [[NSRunLoop currentRunLoop] _wakeUp];
    return [pNewTimer autorelease];
}

/**
 @Status Interoperable
*/
+ (NSTimer*)timerWithTimeInterval:(double)seconds
                           target:(id)target
                         selector:(SEL)selector
                         userInfo:(NSObject*)userInfo
                          repeats:(BOOL)repeats {
    return [[[self alloc] initWithTimeInterval:seconds target:target selector:selector userInfo:userInfo repeats:repeats] autorelease];
}

/**
 @Status Interoperable
*/
- (NSTimer*)initWithFireDate:(NSDate*)date
                    interval:(double)seconds
                      target:(id)target
                    selector:(SEL)selector
                    userInfo:(NSObject*)userInfo
                     repeats:(BOOL)repeats {
    if (self = [self initWithTimeInterval:seconds target:target selector:selector userInfo:userInfo repeats:repeats]) {
        _nextFireTime = [date timeIntervalSinceReferenceDate];
    }
    return self;
}

/**
 @Status Interoperable
*/
- (instancetype)initTimerWithTimeInterval:(double)seconds invocation:(NSInvocation*)target repeats:(BOOL)repeats {
    if (self = [self initWithTimeInterval:seconds target:nil selector:nullptr userInfo:nil repeats:repeats]) {
        [target retainArguments];
        _timerTarget = [target retain];
    }
    return self;
}

/**
 @Status Interoperable
*/
+ (NSTimer*)timerWithTimeInterval:(double)seconds invocation:(NSInvocation*)target repeats:(BOOL)repeats {
    return [[[self alloc] initTimerWithTimeInterval:seconds invocation:target repeats:repeats] autorelease];
}

/**
 @Status Interoperable
*/
+ (NSTimer*)scheduledTimerWithTimeInterval:(double)seconds invocation:(NSInvocation*)target repeats:(BOOL)repeats {
    NSTimer* pNewTimer = [[self alloc] initTimerWithTimeInterval:seconds invocation:target repeats:repeats];

    [[NSRunLoop currentRunLoop] addTimer:pNewTimer forMode:@"kCFRunLoopDefaultMode"];
    [[NSRunLoop currentRunLoop] _wakeUp];

    return [pNewTimer autorelease];
}

/**
 @Status Interoperable
*/
- (void)setFireDate:(NSDate*)date {
    _nextFireTime = [date timeIntervalSinceReferenceDate];
}

/**
 @Status Interoperable
*/
- (NSDate*)fireDate {
    return [NSDate dateWithTimeIntervalSinceReferenceDate:_nextFireTime];
}

@end
