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

#include <UIKit/UIViewControllerContextTransitioning.h>
#include <UIKit/UIViewController.h>
#include "UIViewControllerInternal.h"

NSString* const UITransitionContextFromViewControllerKey = @"UITransitionContextFromViewControllerKey";
NSString* const UITransitionContextToViewControllerKey = @"UITransitionContextToViewControllerKey";
NSString* const UITransitionContextFromViewKey = @"UITransitionContextFromViewKey";
NSString* const UITransitionContextToViewKey = @"UITransitionContextToViewKey";

@implementation _UIViewControllerContextTransitioning {
    idretaintype(NSMutableDictionary) _viewControllers;
    idretaintype(NSMutableDictionary) _views;
    idretaintype(id<UIViewControllerAnimatedTransitioning>) _animator;
    BOOL isComplete;
    BOOL isCanceled;
    BOOL isInteractive;
    BOOL isAnimating;
    BOOL isFinished;
    UIView* _superView;
}

- (instancetype)initWithContainerView:(UIView*)containerView
                         withFromView:(UIView*)fromView
                           withToView:(UIView*)toView
               withFromViewController:(UIViewController*)fromViewController
                 withToViewController:(UIViewController*)toViewController
                         withAnimator:(id<UIViewControllerAnimatedTransitioning>)animator {
    _viewControllers.attach([NSMutableDictionary new]);
    _views.attach([NSMutableDictionary new]);
    isComplete = NO;
    isCanceled = NO;
    isAnimating = NO;
    isFinished = NO;
    isInteractive = NO;
    FAIL_FAST_HR_IF_NULL(E_UNEXPECTED, containerView);
    _superView = containerView;
    _animator = animator;

    [_viewControllers setObject:fromViewController forKey:UITransitionContextFromViewControllerKey];
    [_viewControllers setObject:toViewController forKey:UITransitionContextToViewControllerKey];
    [_views setObject:toView forKey:UITransitionContextToViewKey];
    [_views setObject:fromView forKey:UITransitionContextFromViewKey];
    return self;
}

/**
 @Status Interoperable
*/
- (UIView*)containerView {
    return _superView;
}

/**
 @Status Interoperable
*/
- (CGRect)initialFrameForViewController:(UIViewController*)viewController {
    return [[viewController view] frame];
}

/**
 @Status Interoperable
*/
- (CGRect)finalFrameForViewController:(UIViewController*)viewController {
    return [[viewController view] frame];
}

/**
   @Status Stub
*/
- (void)finishInteractiveTransition {
    UNIMPLEMENTED();
    isFinished = YES;
}

/**
   @Status Stub
*/
- (void)updateInteractiveTransition:(CGFloat)percentComplete {
    UNIMPLEMENTED();
}

/**
   @Status Stub
*/
- (void)cancelInteractiveTransition {
    UNIMPLEMENTED();
    isCanceled = YES;
}

/**
 @Status Interoperable
*/
- (void)completeTransition:(BOOL)didComplete {
    isComplete = didComplete;
}

/**
 @Status Interoperable
*/
- (BOOL)transitionWasCancelled {
    return isCanceled;
}

/**
   @Status Stub
*/
- (BOOL)isAnimated {
    UNIMPLEMENTED();
    return YES;
}

/**
   @Status Stub
*/
- (BOOL)isInteractive {
    UNIMPLEMENTED();
    return NO;
}

/**
 @Status Interoperable
*/
- (CGAffineTransform)targetTransform {
    return [_superView transform];
}

/**
 @Status Interoperable
*/
- (UIView*)viewForKey:(NSString*)key {
    return [_views objectForKey:key];
}

/**
 @Status Interoperable
*/
- (UIViewController*)viewControllerForKey:(NSString*)key {
    return [_viewControllers objectForKey:key];
}

/**
   @Status Stub
*/
- (UIModalPresentationStyle)presentationStyle {
    UNIMPLEMENTED();
    return UIModalPresentationOverFullScreen;
}

@end
