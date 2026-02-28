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

#import <StubReturn.h>
#import <vector>
#import <Starboard.h>

#import <Foundation/NSTimer.h>
#import <UIKit/UILongPressGestureRecognizer.h>
#import <UIKit/UIGestureRecognizerSubclass.h>
#import <UIKit/UITouch.h>
#import "UIGestureRecognizerInternal.h"

#include "LoggingNative.h"

static const wchar_t* TAG = L"UILongPressGestureRecognizer";

// used to track a single touch and its startPosition
typedef struct {
    UITouch* touch;
    CGPoint startPosition;
} TrackedTouch;

@implementation UILongPressGestureRecognizer {
    // tracking a list of tracked touch
    std::vector<TrackedTouch> _trackedTouches;

    // timer to fire when minimumPressDuration is reached
    idretaintype(NSTimer) _recognizeTimer;
}

@synthesize minimumPressDuration;
@synthesize allowableMovement;
@synthesize numberOfTapsRequired;
@synthesize numberOfTouchesRequired;

/**
 @Status Interoperable
*/
- (instancetype)initWithTarget:(id)target action:(SEL)selector {
    if (self = [super initWithTarget:target action:selector]) {
        [self _commonInit];
    }

    return self;
}

/**
 @Status Interoperable
*/
- (instancetype)init {
    if (self = [super init]) {
        [self _commonInit];
    }

    return self;
}

/**
 @Status Caveat
 @Notes May not be fully implemented
*/
- (instancetype)initWithCoder:(NSCoder*)coder {
    if (self = [super initWithCoder:coder]) {
        [self _commonInit];

        NSString* minimumPressDurationKey = @"UILongPressGestureRecognizer.minimumPressDuration";
        NSString* allowableMovementKey = @"UILongPressGestureRecognizer.allowableMovement";
        NSString* numberOfTapsRequiredKey = @"UILongPressGestureRecognizer.numberOfTapsRequired";
        NSString* numberOfTouchesRequiredKey = @"UILongPressGestureRecognizer.numberOfTouchesRequired";

        if ([coder containsValueForKey:minimumPressDurationKey]) {
            self->minimumPressDuration = [coder decodeIntForKey:minimumPressDurationKey];
        }

        if ([coder containsValueForKey:allowableMovementKey]) {
            self->allowableMovement = [coder decodeIntForKey:allowableMovementKey];
        }

        if ([coder containsValueForKey:numberOfTapsRequiredKey]) {
            self->numberOfTapsRequired = [coder decodeIntForKey:numberOfTapsRequiredKey];
        }

        if ([coder containsValueForKey:numberOfTouchesRequiredKey]) {
            self->numberOfTouchesRequired = [coder decodeIntForKey:numberOfTouchesRequiredKey];
        }
    }

    return self;
}

/**
 @Status Interoperable
*/
- (void)dealloc {
    if (_recognizeTimer != nil) {
        [_recognizeTimer invalidate];
    }
    [super dealloc];
}

/**
 @Status Interoperable
*/
- (void)touchesBegan:(NSSet*)touches withEvent:(UIEvent*)event {
    TraceVerbose(TAG, L"UILongPressGestureRecognizer:touchesBegan. begining state = %d", self.state);

    // Add each of the new presses to our list of tracked ones:
    for (UITouch* touch in touches) {
        FAIL_FAST_HR_IF(E_UNEXPECTED, [touch phase] != UITouchPhaseBegan);
        TrackedTouch curTouch;
        curTouch.touch = touch;
        curTouch.startPosition = [touch locationInView:nil];
        _trackedTouches.push_back(curTouch);
    }

    // when tracked touches met the minimum required, fire the timer
    if (_trackedTouches.size() >= numberOfTouchesRequired && _recognizeTimer == nil) {
        TraceVerbose(TAG, L"UILongPressGestureRecognizer:touchesBegan starting recognizer timer.");
        _recognizeTimer = [NSTimer scheduledTimerWithTimeInterval:minimumPressDuration
                                                           target:self
                                                         selector:@selector(_recognizeTimerFired)
                                                         userInfo:nil
                                                          repeats:FALSE];
    }

    TraceVerbose(TAG, L"UILongPressGestureRecognizer:touchesBegan. ending state = %d", self.state);
}

static TrackedTouch* findTouch(UITouch* touch, std::vector<TrackedTouch>& touches) {
    for (size_t i = 0; i < touches.size(); i++) {
        if (touches[i].touch == touch)
            return &touches[i];
    }

    return NULL;
}

/**
 @Status Interoperable
*/
- (void)touchesMoved:(NSSet*)touches withEvent:(UIEvent*)event {
    TraceVerbose(TAG, L"UILongPressGestureRecognizer:touchesMoved. begining state = %d", self.state);

    // for each of the touch, caculate the distance
    for (UITouch* touch in touches) {
        FAIL_FAST_HR_IF(E_UNEXPECTED, [touch phase] != UITouchPhaseMoved);
        TrackedTouch* originalTouch = findTouch(touch, _trackedTouches);
        if (!originalTouch) {
            continue;
        }

        CGPoint currentPosition = [touch locationInView:nil];
        CGPoint originalPostion = originalTouch->startPosition;

        if (sqrt(pow(currentPosition.x - originalPostion.x, 2) + pow(currentPosition.y - originalPostion.y, 2)) > allowableMovement) {
            // distance moved more than allowed for one touch, transit the state to corresponding state and invaldiate timer
            // if a gesture has already been UIGestureRecognizerStateBegan or UIGestureRecognizerStateChanged state
            // The gesture should transit to ended state .
            // if a gesture is in possible state, has not began yet, it will transit to failed state directly
            TraceVerbose(TAG, L"UILongPressGestureRecognizer:touchesMoved distance beyond allowable distance");

            if (self.state == UIGestureRecognizerStateBegan || self.state == UIGestureRecognizerStateChanged) {
                self.state = UIGestureRecognizerStateEnded;
            } else if (self.state == UIGestureRecognizerStatePossible) {
                self.state = UIGestureRecognizerStateFailed;
            }

            // in any case, invalidate the timer if necessary
            if (_recognizeTimer != nil) {
                [_recognizeTimer invalidate];
            }
            break;
        }
    }

    if ((self.state != UIGestureRecognizerStateEnded) && (self.state != UIGestureRecognizerStateFailed)) {
        // after distance calculation, if gesture didn't fail, transit state to change state if it is already Began state
        if (self.state == UIGestureRecognizerStateBegan) {
            self.state = UIGestureRecognizerStateChanged;
        } else {
            // otherwise, the gesture should must be in possible state or changed state and should continue to be so
            FAIL_FAST_HR_IF(E_UNEXPECTED, self.state != UIGestureRecognizerStatePossible && self.state != UIGestureRecognizerStateChanged);
        }
    }

    TraceVerbose(TAG, L"UILongPressGestureRecognizer:touchesMoved. ending state = %d", self.state);
}

/**
 @Status Interoperable
*/
- (void)touchesEnded:(NSSet*)touches withEvent:(UIEvent*)event {
    TraceVerbose(TAG, L"UILongPressGestureRecognizer:touchesEnded. begining state = %d", self.state);

    for (UITouch* touch in touches) {
        TrackedTouch* originalTouch = findTouch(touch, _trackedTouches);
        if (!originalTouch) {
            continue;
        }

        // otherwise, we found a tracked finger is lifted, end the gesture
        if (self.state == UIGestureRecognizerStateBegan || self.state == UIGestureRecognizerStateChanged) {
            self.state = UIGestureRecognizerStateEnded;
        } else if (self.state == UIGestureRecognizerStatePossible || self.state == UIGestureRecognizerStateChanged) {
            self.state = UIGestureRecognizerStateFailed;
        }
    }

    TraceVerbose(TAG, L"UILongPressGestureRecognizer:touchesEnded. ending state = %d", self.state);
}

/**
 @Status Interoperable
*/
- (void)reset {
    TraceVerbose(TAG, L"UILongPressGestureRecognizer:reset. begining state = %d", self.state);

    _trackedTouches.clear();

    if (_recognizeTimer != nil) {
        TraceVerbose(TAG, L"UILongPressGestureRecognizer:reset invalidate timer.");
        [_recognizeTimer invalidate];
        _recognizeTimer = nil;
    }

    [super reset];

    TraceVerbose(TAG, L"UILongPressGestureRecognizer:reset. ending state = %d", self.state);
}

/**
 @Status Interoperable
*/
- (void)touchesCancelled:(NSSet*)touches withEvent:(UIEvent*)event {
    TraceVerbose(TAG, L"[UILongPressGestureRecognizer:touchesCancelled.");
    self.state = UIGestureRecognizerStateCancelled;
    [self reset];
}

/**
 @Status Interoperable
*/
- (CGPoint)locationInView:(UIView*)view {
    if (_trackedTouches.size() > 0) {
        CGPoint averagePoint = { 0, 0 };
        for (TrackedTouch& trackedTouch : _trackedTouches) {
            CGPoint touchLocation = [trackedTouch.touch locationInView:view];
            averagePoint.x += touchLocation.x;
            averagePoint.y += touchLocation.y;
        }
        averagePoint.x /= _trackedTouches.size();
        averagePoint.y /= _trackedTouches.size();
        return averagePoint;
    }

    return { 0, 0 };
}

- (void)_commonInit {
    self->minimumPressDuration = 0.5f;
    self->numberOfTapsRequired = 0;
    self->numberOfTouchesRequired = 1;
    self->allowableMovement = 10;
}

- (void)_recognizeTimerFired {
    TraceVerbose(TAG, L"UILongPressGestureRecognizer:_recognizeTimerFired, current state %d.", self.state);
    // when timer fires, current staste must be possible, transit the state to Began state
    FAIL_FAST_HR_IF(E_UNEXPECTED, self.state != UIGestureRecognizerStatePossible);
    self.state = UIGestureRecognizerStateBegan;
    [self _fire];
}

@end
