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

#include "Starboard.h"
#include "Platform/EbrPlatform.h"
#import <Foundation/NSLock.h>
#import <Foundation/NSConditionLock.h>

#include <math.h>
#include <pthread.h>

@implementation NSConditionLock {
    pthread_mutex_t _mutex;
    pthread_cond_t _cond;
    idretaintype(NSString) _name;
    NSInteger _value;
}

/**
 @Status Interoperable
*/
+ (instancetype)alloc {
    NSConditionLock* ret = [super alloc];
    return ret;
}

/**
 @Status Interoperable
*/
- (instancetype)init {
    return [self initWithCondition:0];
}

/**
@Status Interoperable
*/
- (instancetype)initWithCondition:(NSInteger)value {
    pthread_mutex_init(&_mutex, NULL);
    pthread_cond_init(&_cond, NULL);
    _value = value;

    return self;
}

/**
@Status Interoperable
*/
- (NSInteger)condition {
    return _value;
}

/**
 @Status Interoperable
*/
- (void)dealloc {
    int ret = pthread_mutex_destroy(&_mutex);
    assert(ret == 0);
    ret = pthread_cond_destroy(&_cond);
    assert(ret == 0);
    [super dealloc];
}

/**
 @Status Interoperable
*/
- (void)lock {
    pthread_mutex_lock(&_mutex);
}

/**
 @Status Interoperable
*/
- (void)unlock {
    pthread_mutex_unlock(&_mutex);
}

/**
 @Status Interoperable
*/
- (void)signal {
    pthread_cond_signal(&_cond);
}

/**
 @Status Interoperable
*/
- (void)broadcast {
    pthread_cond_broadcast(&_cond);
}

/**
 @Status Interoperable
*/
- (void)wait {
    pthread_cond_wait(&_cond, &_mutex);
}

/**
@Status Interoperable
*/
- (BOOL)tryLock {
    return pthread_mutex_trylock(&_mutex) == 0;
}

/**
@Status Stub
*/
- (BOOL)tryLockWhenCondition:(NSInteger)condition {
    UNIMPLEMENTED();
    return NO;
}

/**
 @Status Interoperable
*/
- (void)lockWhenCondition:(NSInteger)condition {
    int rc;

    if ((rc = pthread_mutex_lock(&_mutex)) != 0) {
        [NSException raise:NSInvalidArgumentException format:@"failed to lock %@ (errno: %d)", self, rc];
    }

    while (_value != condition) {
        switch ((rc = pthread_cond_wait(&_cond, &_mutex))) {
            case 0:
                break;

            default:
                if ((rc = pthread_mutex_unlock(&_mutex)) != 0) {
                    [NSException raise:NSInvalidArgumentException format:@"failed to unlock %@ (errno: %d)", self, rc];
                }
                [NSException raise:NSInvalidArgumentException format:@"failed to lock %@ (errno: %d)", self, rc];
        }
    }
}

/**
 @Status Interoperable
*/
- (BOOL)lockWhenCondition:(NSInteger)condition beforeDate:(NSDate*)date {
    int rc;
    struct timespec t = { 0 };
    struct EbrTimeval tv;
    NSTimeInterval d = [date timeIntervalSinceNow];

    EbrGetTimeOfDay(&tv);

    t.tv_sec = tv.tv_sec;
    t.tv_nsec = tv.tv_usec * 1000;

    t.tv_sec += (unsigned int)d;
    t.tv_nsec = (long)((double)t.tv_nsec + fmod(d, 1.0) * 1000000000.0);

    t.tv_sec += t.tv_nsec / 1000000000;
    t.tv_nsec %= 1000000000;

    if ((rc = pthread_mutex_lock(&_mutex)) != 0) {
        [NSException raise:NSInvalidArgumentException format:@"failed to lock %@ (errno: %d)", self, rc];
    }

    while (_value != condition) {
        switch ((rc = pthread_cond_timedwait(&_cond, &_mutex, &t))) {
            case 0:
                break;

            case ETIMEDOUT:
                if ((rc = pthread_mutex_unlock(&_mutex)) != 0) {
                    [NSException raise:NSInvalidArgumentException format:@"failed to unlock %@ before date %@ (errno: %d)", self, date, rc];
                }
                return NO;

            default:
                if ((rc = pthread_mutex_unlock(&_mutex)) != 0) {
                    [NSException raise:NSInvalidArgumentException format:@"failed to unlock %@ before date %@ (errno: %d)", self, date, rc];
                }
                [NSException raise:NSInvalidArgumentException format:@"failed to lock %@ before date %@ (errno: %d)", self, date, rc];
                return NO;
        }
    }
    
    return YES;
}

/**
@Status Stub
*/
- (BOOL)lockBeforeDate:(NSDate*)date {
    UNIMPLEMENTED();
    return NO;
}

/**
@Status Interoperable
*/
- (void)unlockWithCondition:(NSInteger)condition {
    _value = condition;
    int rc;
    if ((rc = pthread_cond_broadcast(&_cond)) != 0) {
        [NSException raise:NSInvalidArgumentException format:@"failed to broadcast %@ (errno: %d)", self, rc];
    }
    if ((rc = pthread_mutex_unlock(&_mutex)) != 0) {
        [NSException raise:NSInvalidArgumentException format:@"failed to unlock %@ (errno: %d)", self, rc];
    }
}

/**
@Status Interoperable
*/
- (void)setName:(NSString*)newName {
    _name = newName;
}

/**
@Status Interoperable
*/
- (NSString*)name {
    return _name;
}

@end
