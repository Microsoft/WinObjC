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

// WindowsUICompositionInteractions.h
// Generated from winmd2objc

#pragma once

#ifndef OBJCUWP_WINDOWS_UI_COMPOSITION_INTERACTIONS_EXPORT
#define OBJCUWP_WINDOWS_UI_COMPOSITION_INTERACTIONS_EXPORT __declspec(dllimport)
#ifndef IN_OBJCUWP_BUILD
#pragma comment(lib, "ObjCUWP_Windows_UI_Composition_Interactions.lib")
#endif
#endif
#include <UWP/interopBase.h>

@class WUCIInteractionTrackerCustomAnimationStateEnteredArgs, WUCIInteractionTrackerIdleStateEnteredArgs, WUCIInteractionTrackerInertiaStateEnteredArgs, WUCIInteractionTrackerInteractingStateEnteredArgs, WUCIInteractionTrackerRequestIgnoredArgs, WUCIInteractionTrackerValuesChangedArgs, WUCIInteractionTracker, WUCICompositionInteractionSourceCollection, WUCIInteractionTrackerInertiaModifier, WUCIInteractionTrackerInertiaRestingValue, WUCIInteractionTrackerInertiaMotion, WUCIVisualInteractionSource;
@protocol WUCIICompositionInteractionSource, WUCIICompositionInteractionSourceCollection, WUCIIInteractionTrackerStatics, WUCIIInteractionTrackerOwner, WUCIIInteractionTracker, WUCIIInteractionTrackerCustomAnimationStateEnteredArgs, WUCIIInteractionTrackerIdleStateEnteredArgs, WUCIIInteractionTrackerInteractingStateEnteredArgs, WUCIIInteractionTrackerInertiaModifier, WUCIIInteractionTrackerInertiaRestingValueStatics, WUCIIInteractionTrackerInertiaRestingValue, WUCIIInteractionTrackerInertiaMotionStatics, WUCIIInteractionTrackerInertiaMotion, WUCIIInteractionTrackerInertiaStateEnteredArgs, WUCIIInteractionTrackerRequestIgnoredArgs, WUCIIInteractionTrackerValuesChangedArgs, WUCIIVisualInteractionSourceStatics, WUCIIVisualInteractionSource, WUCIIInteractionTrackerInertiaModifierFactory;

// Windows.UI.Composition.Interactions.InteractionChainingMode
enum _WUCIInteractionChainingMode {
    WUCIInteractionChainingModeAuto = 0,
    WUCIInteractionChainingModeAlways = 1,
    WUCIInteractionChainingModeNever = 2,
};
typedef unsigned WUCIInteractionChainingMode;

// Windows.UI.Composition.Interactions.InteractionSourceMode
enum _WUCIInteractionSourceMode {
    WUCIInteractionSourceModeDisabled = 0,
    WUCIInteractionSourceModeEnabledWithInertia = 1,
    WUCIInteractionSourceModeEnabledWithoutInertia = 2,
};
typedef unsigned WUCIInteractionSourceMode;

// Windows.UI.Composition.Interactions.VisualInteractionSourceRedirectionMode
enum _WUCIVisualInteractionSourceRedirectionMode {
    WUCIVisualInteractionSourceRedirectionModeOff = 0,
    WUCIVisualInteractionSourceRedirectionModeCapableTouchpadOnly = 1,
};
typedef unsigned WUCIVisualInteractionSourceRedirectionMode;

#include "WindowsFoundationNumerics.h"
#include "WindowsUIComposition.h"
#include "WindowsUIInput.h"
#include "WindowsUICore.h"
#include "WindowsFoundation.h"

#import <Foundation/Foundation.h>

// Windows.UI.Composition.Interactions.ICompositionInteractionSource
#ifndef __WUCIICompositionInteractionSource_DEFINED__
#define __WUCIICompositionInteractionSource_DEFINED__

@protocol WUCIICompositionInteractionSource
@end

OBJCUWP_WINDOWS_UI_COMPOSITION_INTERACTIONS_EXPORT
@interface WUCIICompositionInteractionSource : RTObject <WUCIICompositionInteractionSource>
@end

#endif // __WUCIICompositionInteractionSource_DEFINED__

// Windows.UI.Composition.Interactions.IInteractionTrackerOwner
#ifndef __WUCIIInteractionTrackerOwner_DEFINED__
#define __WUCIIInteractionTrackerOwner_DEFINED__

@protocol WUCIIInteractionTrackerOwner
- (void)customAnimationStateEntered:(WUCIInteractionTracker*)sender args:(WUCIInteractionTrackerCustomAnimationStateEnteredArgs*)args;
- (void)idleStateEntered:(WUCIInteractionTracker*)sender args:(WUCIInteractionTrackerIdleStateEnteredArgs*)args;
- (void)inertiaStateEntered:(WUCIInteractionTracker*)sender args:(WUCIInteractionTrackerInertiaStateEnteredArgs*)args;
- (void)interactingStateEntered:(WUCIInteractionTracker*)sender args:(WUCIInteractionTrackerInteractingStateEnteredArgs*)args;
- (void)requestIgnored:(WUCIInteractionTracker*)sender args:(WUCIInteractionTrackerRequestIgnoredArgs*)args;
- (void)valuesChanged:(WUCIInteractionTracker*)sender args:(WUCIInteractionTrackerValuesChangedArgs*)args;
@end

OBJCUWP_WINDOWS_UI_COMPOSITION_INTERACTIONS_EXPORT
@interface WUCIIInteractionTrackerOwner : RTObject <WUCIIInteractionTrackerOwner>
@end

#endif // __WUCIIInteractionTrackerOwner_DEFINED__

// Windows.UI.Composition.Interactions.InteractionTrackerCustomAnimationStateEnteredArgs
#ifndef __WUCIInteractionTrackerCustomAnimationStateEnteredArgs_DEFINED__
#define __WUCIInteractionTrackerCustomAnimationStateEnteredArgs_DEFINED__

OBJCUWP_WINDOWS_UI_COMPOSITION_INTERACTIONS_EXPORT
@interface WUCIInteractionTrackerCustomAnimationStateEnteredArgs : RTObject
#if defined(__cplusplus)
+ (instancetype)createWith:(IInspectable*)obj __attribute__ ((ns_returns_autoreleased));
#endif
@property (readonly) int requestId;
@end

#endif // __WUCIInteractionTrackerCustomAnimationStateEnteredArgs_DEFINED__

// Windows.UI.Composition.Interactions.InteractionTrackerIdleStateEnteredArgs
#ifndef __WUCIInteractionTrackerIdleStateEnteredArgs_DEFINED__
#define __WUCIInteractionTrackerIdleStateEnteredArgs_DEFINED__

OBJCUWP_WINDOWS_UI_COMPOSITION_INTERACTIONS_EXPORT
@interface WUCIInteractionTrackerIdleStateEnteredArgs : RTObject
#if defined(__cplusplus)
+ (instancetype)createWith:(IInspectable*)obj __attribute__ ((ns_returns_autoreleased));
#endif
@property (readonly) int requestId;
@end

#endif // __WUCIInteractionTrackerIdleStateEnteredArgs_DEFINED__

// Windows.UI.Composition.Interactions.InteractionTrackerInertiaStateEnteredArgs
#ifndef __WUCIInteractionTrackerInertiaStateEnteredArgs_DEFINED__
#define __WUCIInteractionTrackerInertiaStateEnteredArgs_DEFINED__

OBJCUWP_WINDOWS_UI_COMPOSITION_INTERACTIONS_EXPORT
@interface WUCIInteractionTrackerInertiaStateEnteredArgs : RTObject
#if defined(__cplusplus)
+ (instancetype)createWith:(IInspectable*)obj __attribute__ ((ns_returns_autoreleased));
#endif
@property (readonly) id /* WFNVector3* */ modifiedRestingPosition;
@property (readonly) id /* float */ modifiedRestingScale;
@property (readonly) WFNVector3* naturalRestingPosition;
@property (readonly) float naturalRestingScale;
@property (readonly) WFNVector3* positionVelocityInPixelsPerSecond;
@property (readonly) int requestId;
@property (readonly) float scaleVelocityInPercentPerSecond;
@end

#endif // __WUCIInteractionTrackerInertiaStateEnteredArgs_DEFINED__

// Windows.UI.Composition.Interactions.InteractionTrackerInteractingStateEnteredArgs
#ifndef __WUCIInteractionTrackerInteractingStateEnteredArgs_DEFINED__
#define __WUCIInteractionTrackerInteractingStateEnteredArgs_DEFINED__

OBJCUWP_WINDOWS_UI_COMPOSITION_INTERACTIONS_EXPORT
@interface WUCIInteractionTrackerInteractingStateEnteredArgs : RTObject
#if defined(__cplusplus)
+ (instancetype)createWith:(IInspectable*)obj __attribute__ ((ns_returns_autoreleased));
#endif
@property (readonly) int requestId;
@end

#endif // __WUCIInteractionTrackerInteractingStateEnteredArgs_DEFINED__

// Windows.UI.Composition.Interactions.InteractionTrackerRequestIgnoredArgs
#ifndef __WUCIInteractionTrackerRequestIgnoredArgs_DEFINED__
#define __WUCIInteractionTrackerRequestIgnoredArgs_DEFINED__

OBJCUWP_WINDOWS_UI_COMPOSITION_INTERACTIONS_EXPORT
@interface WUCIInteractionTrackerRequestIgnoredArgs : RTObject
#if defined(__cplusplus)
+ (instancetype)createWith:(IInspectable*)obj __attribute__ ((ns_returns_autoreleased));
#endif
@property (readonly) int requestId;
@end

#endif // __WUCIInteractionTrackerRequestIgnoredArgs_DEFINED__

// Windows.UI.Composition.Interactions.InteractionTrackerValuesChangedArgs
#ifndef __WUCIInteractionTrackerValuesChangedArgs_DEFINED__
#define __WUCIInteractionTrackerValuesChangedArgs_DEFINED__

OBJCUWP_WINDOWS_UI_COMPOSITION_INTERACTIONS_EXPORT
@interface WUCIInteractionTrackerValuesChangedArgs : RTObject
#if defined(__cplusplus)
+ (instancetype)createWith:(IInspectable*)obj __attribute__ ((ns_returns_autoreleased));
#endif
@property (readonly) WFNVector3* position;
@property (readonly) int requestId;
@property (readonly) float scale;
@end

#endif // __WUCIInteractionTrackerValuesChangedArgs_DEFINED__

// Windows.Foundation.IClosable
#ifndef __WFIClosable_DEFINED__
#define __WFIClosable_DEFINED__

@protocol WFIClosable
- (void)close;
@end

OBJCUWP_WINDOWS_UI_COMPOSITION_INTERACTIONS_EXPORT
@interface WFIClosable : RTObject <WFIClosable>
@end

#endif // __WFIClosable_DEFINED__

// Windows.UI.Composition.CompositionObject
#ifndef __WUCCompositionObject_DEFINED__
#define __WUCCompositionObject_DEFINED__

OBJCUWP_WINDOWS_UI_COMPOSITION_INTERACTIONS_EXPORT
@interface WUCCompositionObject : RTObject <WFIClosable>
#if defined(__cplusplus)
+ (instancetype)createWith:(IInspectable*)obj __attribute__ ((ns_returns_autoreleased));
#endif
@property (readonly) WUCCompositor* compositor;
@property (readonly) WUCCoreDispatcher* dispatcher;
@property (readonly) WUCCompositionPropertySet* properties;
@property (retain) WUCImplicitAnimationCollection* implicitAnimations;
@property (retain) NSString * comment;
- (void)startAnimation:(NSString *)propertyName animation:(WUCCompositionAnimation*)animation;
- (void)stopAnimation:(NSString *)propertyName;
- (void)close;
- (void)startAnimationGroup:(RTObject<WUCICompositionAnimationBase>*)value;
- (void)stopAnimationGroup:(RTObject<WUCICompositionAnimationBase>*)value;
@end

#endif // __WUCCompositionObject_DEFINED__

// Windows.UI.Composition.Interactions.InteractionTracker
#ifndef __WUCIInteractionTracker_DEFINED__
#define __WUCIInteractionTracker_DEFINED__

OBJCUWP_WINDOWS_UI_COMPOSITION_INTERACTIONS_EXPORT
@interface WUCIInteractionTracker : WUCCompositionObject
+ (WUCIInteractionTracker*)create:(WUCCompositor*)compositor;
+ (WUCIInteractionTracker*)createWithOwner:(WUCCompositor*)compositor owner:(RTObject<WUCIIInteractionTrackerOwner>*)owner;
#if defined(__cplusplus)
+ (instancetype)createWith:(IInspectable*)obj __attribute__ ((ns_returns_autoreleased));
#endif
@property (retain) id /* float */ scaleInertiaDecayRate;
@property (retain) id /* WFNVector3* */ positionInertiaDecayRate;
@property float maxScale;
@property float minScale;
@property (retain) WFNVector3* maxPosition;
@property (retain) WFNVector3* minPosition;
@property (readonly) WFNVector3* naturalRestingPosition;
@property (readonly) float naturalRestingScale;
@property (readonly) RTObject<WUCIIInteractionTrackerOwner>* owner;
@property (readonly) WFNVector3* position;
@property (readonly) WUCICompositionInteractionSourceCollection* interactionSources;
@property (readonly) WFNVector3* positionVelocityInPixelsPerSecond;
@property (readonly) float scale;
@property (readonly) BOOL isPositionRoundingSuggested;
@property (readonly) float scaleVelocityInPercentPerSecond;
- (void)adjustPositionXIfGreaterThanThreshold:(float)adjustment positionThreshold:(float)positionThreshold;
- (void)adjustPositionYIfGreaterThanThreshold:(float)adjustment positionThreshold:(float)positionThreshold;
- (void)configurePositionXInertiaModifiers:(id<NSFastEnumeration> /* WUCIInteractionTrackerInertiaModifier* */)modifiers;
- (void)configurePositionYInertiaModifiers:(id<NSFastEnumeration> /* WUCIInteractionTrackerInertiaModifier* */)modifiers;
- (void)configureScaleInertiaModifiers:(id<NSFastEnumeration> /* WUCIInteractionTrackerInertiaModifier* */)modifiers;
- (int)tryUpdatePosition:(WFNVector3*)value;
- (int)tryUpdatePositionBy:(WFNVector3*)amount;
- (int)tryUpdatePositionWithAnimation:(WUCCompositionAnimation*)animation;
- (int)tryUpdatePositionWithAdditionalVelocity:(WFNVector3*)velocityInPixelsPerSecond;
- (int)tryUpdateScale:(float)value centerPoint:(WFNVector3*)centerPoint;
- (int)tryUpdateScaleWithAnimation:(WUCCompositionAnimation*)animation centerPoint:(WFNVector3*)centerPoint;
- (int)tryUpdateScaleWithAdditionalVelocity:(float)velocityInPercentPerSecond centerPoint:(WFNVector3*)centerPoint;
@end

#endif // __WUCIInteractionTracker_DEFINED__

// Windows.UI.Composition.Interactions.CompositionInteractionSourceCollection
#ifndef __WUCICompositionInteractionSourceCollection_DEFINED__
#define __WUCICompositionInteractionSourceCollection_DEFINED__

OBJCUWP_WINDOWS_UI_COMPOSITION_INTERACTIONS_EXPORT
@interface WUCICompositionInteractionSourceCollection : WUCCompositionObject
#if defined(__cplusplus)
+ (instancetype)createWith:(IInspectable*)obj __attribute__ ((ns_returns_autoreleased));
#endif
@property (readonly) int count;
- (void)add:(RTObject<WUCIICompositionInteractionSource>*)value;
- (void)remove:(RTObject<WUCIICompositionInteractionSource>*)value;
- (void)removeAll;
@end

#endif // __WUCICompositionInteractionSourceCollection_DEFINED__

// Windows.UI.Composition.Interactions.InteractionTrackerInertiaModifier
#ifndef __WUCIInteractionTrackerInertiaModifier_DEFINED__
#define __WUCIInteractionTrackerInertiaModifier_DEFINED__

OBJCUWP_WINDOWS_UI_COMPOSITION_INTERACTIONS_EXPORT
@interface WUCIInteractionTrackerInertiaModifier : WUCCompositionObject
#if defined(__cplusplus)
+ (instancetype)createWith:(IInspectable*)obj __attribute__ ((ns_returns_autoreleased));
#endif
@end

#endif // __WUCIInteractionTrackerInertiaModifier_DEFINED__

// Windows.UI.Composition.Interactions.InteractionTrackerInertiaRestingValue
#ifndef __WUCIInteractionTrackerInertiaRestingValue_DEFINED__
#define __WUCIInteractionTrackerInertiaRestingValue_DEFINED__

OBJCUWP_WINDOWS_UI_COMPOSITION_INTERACTIONS_EXPORT
@interface WUCIInteractionTrackerInertiaRestingValue : WUCIInteractionTrackerInertiaModifier
+ (WUCIInteractionTrackerInertiaRestingValue*)create:(WUCCompositor*)compositor;
#if defined(__cplusplus)
+ (instancetype)createWith:(IInspectable*)obj __attribute__ ((ns_returns_autoreleased));
#endif
@property (retain) WUCExpressionAnimation* restingValue;
@property (retain) WUCExpressionAnimation* condition;
@end

#endif // __WUCIInteractionTrackerInertiaRestingValue_DEFINED__

// Windows.UI.Composition.Interactions.InteractionTrackerInertiaMotion
#ifndef __WUCIInteractionTrackerInertiaMotion_DEFINED__
#define __WUCIInteractionTrackerInertiaMotion_DEFINED__

OBJCUWP_WINDOWS_UI_COMPOSITION_INTERACTIONS_EXPORT
@interface WUCIInteractionTrackerInertiaMotion : WUCIInteractionTrackerInertiaModifier
+ (WUCIInteractionTrackerInertiaMotion*)create:(WUCCompositor*)compositor;
#if defined(__cplusplus)
+ (instancetype)createWith:(IInspectable*)obj __attribute__ ((ns_returns_autoreleased));
#endif
@property (retain) WUCExpressionAnimation* motion;
@property (retain) WUCExpressionAnimation* condition;
@end

#endif // __WUCIInteractionTrackerInertiaMotion_DEFINED__

// Windows.UI.Composition.Interactions.VisualInteractionSource
#ifndef __WUCIVisualInteractionSource_DEFINED__
#define __WUCIVisualInteractionSource_DEFINED__

OBJCUWP_WINDOWS_UI_COMPOSITION_INTERACTIONS_EXPORT
@interface WUCIVisualInteractionSource : WUCCompositionObject <WUCIICompositionInteractionSource>
+ (WUCIVisualInteractionSource*)create:(WUCVisual*)source;
#if defined(__cplusplus)
+ (instancetype)createWith:(IInspectable*)obj __attribute__ ((ns_returns_autoreleased));
#endif
@property WUCIInteractionSourceMode scaleSourceMode;
@property WUCIInteractionChainingMode scaleChainingMode;
@property WUCIInteractionSourceMode positionYSourceMode;
@property WUCIInteractionChainingMode positionYChainingMode;
@property WUCIInteractionSourceMode positionXSourceMode;
@property WUCIInteractionChainingMode positionXChainingMode;
@property WUCIVisualInteractionSourceRedirectionMode manipulationRedirectionMode;
@property BOOL isPositionYRailsEnabled;
@property BOOL isPositionXRailsEnabled;
@property (readonly) WUCVisual* source;
- (void)tryRedirectForManipulation:(WUIPointerPoint*)pointerPoint;
@end

#endif // __WUCIVisualInteractionSource_DEFINED__

