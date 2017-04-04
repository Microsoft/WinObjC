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

// WindowsUIXamlInput.h
// Generated from winmd2objc

#pragma once

#ifndef OBJCUWPWINDOWSUIXAMLEXPORT
#define OBJCUWPWINDOWSUIXAMLEXPORT __declspec(dllimport)
#ifndef IN_WinObjC_Frameworks_UWP_BUILD
#pragma comment(lib, "ObjCUWPWindowsUIXaml.lib")
#endif
#endif
#include <UWP/interopBase.h>

@class WUXIPointer, WUXIAccessKeyDisplayRequestedEventArgs, WUXIAccessKeyDisplayDismissedEventArgs, WUXIAccessKeyInvokedEventArgs, WUXIAccessKeyManager, WUXIFocusManager, WUXIInertiaExpansionBehavior, WUXIInertiaRotationBehavior, WUXIInertiaTranslationBehavior, WUXIManipulationPivot, WUXIContextRequestedEventArgs, WUXIDoubleTappedRoutedEventArgs, WUXIHoldingRoutedEventArgs, WUXIInputScope, WUXIInputScopeName, WUXIKeyRoutedEventArgs, WUXIManipulationCompletedRoutedEventArgs, WUXIManipulationDeltaRoutedEventArgs, WUXIManipulationInertiaStartingRoutedEventArgs, WUXIManipulationStartedRoutedEventArgs, WUXIManipulationStartingRoutedEventArgs, WUXIPointerRoutedEventArgs, WUXIRightTappedRoutedEventArgs, WUXITappedRoutedEventArgs;
@protocol WUXIICommand, WUXIIAccessKeyDisplayDismissedEventArgs, WUXIIAccessKeyDisplayRequestedEventArgs, WUXIIAccessKeyInvokedEventArgs, WUXIIAccessKeyManager, WUXIIAccessKeyManagerStatics, WUXIIFocusManager, WUXIIFocusManagerStatics, WUXIIFocusManagerStatics2, WUXIIFocusManagerStatics3, WUXIIInertiaExpansionBehavior, WUXIIInertiaRotationBehavior, WUXIIInertiaTranslationBehavior, WUXIIManipulationPivot, WUXIIManipulationPivotFactory, WUXIIPointer, WUXIIContextRequestedEventArgs, WUXIIDoubleTappedRoutedEventArgs, WUXIIHoldingRoutedEventArgs, WUXIIInputScope, WUXIIInputScopeName, WUXIIInputScopeNameFactory, WUXIIKeyRoutedEventArgs, WUXIIKeyRoutedEventArgs2, WUXIIKeyRoutedEventArgs3, WUXIIManipulationCompletedRoutedEventArgs, WUXIIManipulationDeltaRoutedEventArgs, WUXIIManipulationInertiaStartingRoutedEventArgs, WUXIIManipulationStartedRoutedEventArgs, WUXIIManipulationStartedRoutedEventArgsFactory, WUXIIManipulationStartingRoutedEventArgs, WUXIIPointerRoutedEventArgs, WUXIIRightTappedRoutedEventArgs, WUXIITappedRoutedEventArgs;

// Windows.UI.Xaml.Input.FocusNavigationDirection
enum _WUXIFocusNavigationDirection {
    WUXIFocusNavigationDirectionNext = 0,
    WUXIFocusNavigationDirectionPrevious = 1,
    WUXIFocusNavigationDirectionUp = 2,
    WUXIFocusNavigationDirectionDown = 3,
    WUXIFocusNavigationDirectionLeft = 4,
    WUXIFocusNavigationDirectionRight = 5,
    WUXIFocusNavigationDirectionNone = 6,
};
typedef unsigned WUXIFocusNavigationDirection;

// Windows.UI.Xaml.Input.InputScopeNameValue
enum _WUXIInputScopeNameValue {
    WUXIInputScopeNameValueDefault = 0,
    WUXIInputScopeNameValueUrl = 1,
    WUXIInputScopeNameValueEmailSmtpAddress = 5,
    WUXIInputScopeNameValuePersonalFullName = 7,
    WUXIInputScopeNameValueCurrencyAmountAndSymbol = 20,
    WUXIInputScopeNameValueCurrencyAmount = 21,
    WUXIInputScopeNameValueDateMonthNumber = 23,
    WUXIInputScopeNameValueDateDayNumber = 24,
    WUXIInputScopeNameValueDateYear = 25,
    WUXIInputScopeNameValueDigits = 28,
    WUXIInputScopeNameValueNumber = 29,
    WUXIInputScopeNameValuePassword = 31,
    WUXIInputScopeNameValueTelephoneNumber = 32,
    WUXIInputScopeNameValueTelephoneCountryCode = 33,
    WUXIInputScopeNameValueTelephoneAreaCode = 34,
    WUXIInputScopeNameValueTelephoneLocalNumber = 35,
    WUXIInputScopeNameValueTimeHour = 37,
    WUXIInputScopeNameValueTimeMinutesOrSeconds = 38,
    WUXIInputScopeNameValueNumberFullWidth = 39,
    WUXIInputScopeNameValueAlphanumericHalfWidth = 40,
    WUXIInputScopeNameValueAlphanumericFullWidth = 41,
    WUXIInputScopeNameValueHiragana = 44,
    WUXIInputScopeNameValueKatakanaHalfWidth = 45,
    WUXIInputScopeNameValueKatakanaFullWidth = 46,
    WUXIInputScopeNameValueHanja = 47,
    WUXIInputScopeNameValueHangulHalfWidth = 48,
    WUXIInputScopeNameValueHangulFullWidth = 49,
    WUXIInputScopeNameValueSearch = 50,
    WUXIInputScopeNameValueFormula = 51,
    WUXIInputScopeNameValueSearchIncremental = 52,
    WUXIInputScopeNameValueChineseHalfWidth = 53,
    WUXIInputScopeNameValueChineseFullWidth = 54,
    WUXIInputScopeNameValueNativeScript = 55,
    WUXIInputScopeNameValueText = 57,
    WUXIInputScopeNameValueChat = 58,
    WUXIInputScopeNameValueNameOrPhoneNumber = 59,
    WUXIInputScopeNameValueEmailNameOrAddress = 60,
    WUXIInputScopeNameValueMaps = 62,
    WUXIInputScopeNameValueNumericPassword = 63,
    WUXIInputScopeNameValueNumericPin = 64,
    WUXIInputScopeNameValueAlphanumericPin = 65,
    WUXIInputScopeNameValueFormulaNumber = 67,
    WUXIInputScopeNameValueChatWithoutEmoji = 68,
};
typedef unsigned WUXIInputScopeNameValue;

// Windows.UI.Xaml.Input.KeyboardNavigationMode
enum _WUXIKeyboardNavigationMode {
    WUXIKeyboardNavigationModeLocal = 0,
    WUXIKeyboardNavigationModeCycle = 1,
    WUXIKeyboardNavigationModeOnce = 2,
};
typedef unsigned WUXIKeyboardNavigationMode;

// Windows.UI.Xaml.Input.ManipulationModes
enum _WUXIManipulationModes {
    WUXIManipulationModesNone = 0,
    WUXIManipulationModesTranslateX = 1,
    WUXIManipulationModesTranslateY = 2,
    WUXIManipulationModesTranslateRailsX = 4,
    WUXIManipulationModesTranslateRailsY = 8,
    WUXIManipulationModesRotate = 16,
    WUXIManipulationModesScale = 32,
    WUXIManipulationModesTranslateInertia = 64,
    WUXIManipulationModesRotateInertia = 128,
    WUXIManipulationModesScaleInertia = 256,
    WUXIManipulationModesAll = 65535,
    WUXIManipulationModesSystem = 65536,
};
typedef unsigned WUXIManipulationModes;

#include "WindowsUIXaml.h"
#include "WindowsDevicesInput.h"
#include "WindowsFoundation.h"
#include "WindowsUIInput.h"
#include "WindowsSystem.h"
#include "WindowsUICore.h"
// Windows.UI.Xaml.DependencyPropertyChangedCallback
#ifndef __WXDependencyPropertyChangedCallback__DEFINED
#define __WXDependencyPropertyChangedCallback__DEFINED
typedef void(^WXDependencyPropertyChangedCallback)(WXDependencyObject* sender, WXDependencyProperty* dp);
#endif // __WXDependencyPropertyChangedCallback__DEFINED


#import <Foundation/Foundation.h>

// Windows.UI.Xaml.Input.DoubleTappedEventHandler
#ifndef __WUXIDoubleTappedEventHandler__DEFINED
#define __WUXIDoubleTappedEventHandler__DEFINED
typedef void(^WUXIDoubleTappedEventHandler)(RTObject* sender, WUXIDoubleTappedRoutedEventArgs* e);
#endif // __WUXIDoubleTappedEventHandler__DEFINED

// Windows.UI.Xaml.Input.HoldingEventHandler
#ifndef __WUXIHoldingEventHandler__DEFINED
#define __WUXIHoldingEventHandler__DEFINED
typedef void(^WUXIHoldingEventHandler)(RTObject* sender, WUXIHoldingRoutedEventArgs* e);
#endif // __WUXIHoldingEventHandler__DEFINED

// Windows.UI.Xaml.Input.KeyEventHandler
#ifndef __WUXIKeyEventHandler__DEFINED
#define __WUXIKeyEventHandler__DEFINED
typedef void(^WUXIKeyEventHandler)(RTObject* sender, WUXIKeyRoutedEventArgs* e);
#endif // __WUXIKeyEventHandler__DEFINED

// Windows.UI.Xaml.Input.ManipulationCompletedEventHandler
#ifndef __WUXIManipulationCompletedEventHandler__DEFINED
#define __WUXIManipulationCompletedEventHandler__DEFINED
typedef void(^WUXIManipulationCompletedEventHandler)(RTObject* sender, WUXIManipulationCompletedRoutedEventArgs* e);
#endif // __WUXIManipulationCompletedEventHandler__DEFINED

// Windows.UI.Xaml.Input.ManipulationDeltaEventHandler
#ifndef __WUXIManipulationDeltaEventHandler__DEFINED
#define __WUXIManipulationDeltaEventHandler__DEFINED
typedef void(^WUXIManipulationDeltaEventHandler)(RTObject* sender, WUXIManipulationDeltaRoutedEventArgs* e);
#endif // __WUXIManipulationDeltaEventHandler__DEFINED

// Windows.UI.Xaml.Input.ManipulationInertiaStartingEventHandler
#ifndef __WUXIManipulationInertiaStartingEventHandler__DEFINED
#define __WUXIManipulationInertiaStartingEventHandler__DEFINED
typedef void(^WUXIManipulationInertiaStartingEventHandler)(RTObject* sender, WUXIManipulationInertiaStartingRoutedEventArgs* e);
#endif // __WUXIManipulationInertiaStartingEventHandler__DEFINED

// Windows.UI.Xaml.Input.ManipulationStartedEventHandler
#ifndef __WUXIManipulationStartedEventHandler__DEFINED
#define __WUXIManipulationStartedEventHandler__DEFINED
typedef void(^WUXIManipulationStartedEventHandler)(RTObject* sender, WUXIManipulationStartedRoutedEventArgs* e);
#endif // __WUXIManipulationStartedEventHandler__DEFINED

// Windows.UI.Xaml.Input.ManipulationStartingEventHandler
#ifndef __WUXIManipulationStartingEventHandler__DEFINED
#define __WUXIManipulationStartingEventHandler__DEFINED
typedef void(^WUXIManipulationStartingEventHandler)(RTObject* sender, WUXIManipulationStartingRoutedEventArgs* e);
#endif // __WUXIManipulationStartingEventHandler__DEFINED

// Windows.UI.Xaml.Input.PointerEventHandler
#ifndef __WUXIPointerEventHandler__DEFINED
#define __WUXIPointerEventHandler__DEFINED
typedef void(^WUXIPointerEventHandler)(RTObject* sender, WUXIPointerRoutedEventArgs* e);
#endif // __WUXIPointerEventHandler__DEFINED

// Windows.UI.Xaml.Input.RightTappedEventHandler
#ifndef __WUXIRightTappedEventHandler__DEFINED
#define __WUXIRightTappedEventHandler__DEFINED
typedef void(^WUXIRightTappedEventHandler)(RTObject* sender, WUXIRightTappedRoutedEventArgs* e);
#endif // __WUXIRightTappedEventHandler__DEFINED

// Windows.UI.Xaml.Input.TappedEventHandler
#ifndef __WUXITappedEventHandler__DEFINED
#define __WUXITappedEventHandler__DEFINED
typedef void(^WUXITappedEventHandler)(RTObject* sender, WUXITappedRoutedEventArgs* e);
#endif // __WUXITappedEventHandler__DEFINED

// Windows.UI.Xaml.Input.ICommand
#ifndef __WUXIICommand_DEFINED__
#define __WUXIICommand_DEFINED__

@protocol WUXIICommand
- (EventRegistrationToken)addCanExecuteChangedEvent:(void(^)(RTObject*, RTObject*))del;
- (void)removeCanExecuteChangedEvent:(EventRegistrationToken)tok;
- (BOOL)canExecute:(RTObject*)parameter;
- (void)execute:(RTObject*)parameter;
@end

OBJCUWPWINDOWSUIXAMLEXPORT
@interface WUXIICommand : RTObject <WUXIICommand>
@end

#endif // __WUXIICommand_DEFINED__

// Windows.UI.Xaml.Input.Pointer
#ifndef __WUXIPointer_DEFINED__
#define __WUXIPointer_DEFINED__

OBJCUWPWINDOWSUIXAMLEXPORT
@interface WUXIPointer : RTObject
#if defined(__cplusplus)
+ (instancetype)createWith:(IInspectable*)obj __attribute__ ((ns_returns_autoreleased));
#endif
@property (readonly) BOOL isInContact;
@property (readonly) BOOL isInRange;
@property (readonly) WDIPointerDeviceType pointerDeviceType;
@property (readonly) unsigned int pointerId;
@end

#endif // __WUXIPointer_DEFINED__

// Windows.UI.Xaml.Input.AccessKeyDisplayRequestedEventArgs
#ifndef __WUXIAccessKeyDisplayRequestedEventArgs_DEFINED__
#define __WUXIAccessKeyDisplayRequestedEventArgs_DEFINED__

OBJCUWPWINDOWSUIXAMLEXPORT
@interface WUXIAccessKeyDisplayRequestedEventArgs : RTObject
+ (instancetype)make __attribute__ ((ns_returns_retained));
#if defined(__cplusplus)
+ (instancetype)createWith:(IInspectable*)obj __attribute__ ((ns_returns_autoreleased));
#endif
@property (readonly) NSString * pressedKeys;
@end

#endif // __WUXIAccessKeyDisplayRequestedEventArgs_DEFINED__

// Windows.UI.Xaml.Input.AccessKeyDisplayDismissedEventArgs
#ifndef __WUXIAccessKeyDisplayDismissedEventArgs_DEFINED__
#define __WUXIAccessKeyDisplayDismissedEventArgs_DEFINED__

OBJCUWPWINDOWSUIXAMLEXPORT
@interface WUXIAccessKeyDisplayDismissedEventArgs : RTObject
+ (instancetype)make __attribute__ ((ns_returns_retained));
#if defined(__cplusplus)
+ (instancetype)createWith:(IInspectable*)obj __attribute__ ((ns_returns_autoreleased));
#endif
@end

#endif // __WUXIAccessKeyDisplayDismissedEventArgs_DEFINED__

// Windows.UI.Xaml.Input.AccessKeyInvokedEventArgs
#ifndef __WUXIAccessKeyInvokedEventArgs_DEFINED__
#define __WUXIAccessKeyInvokedEventArgs_DEFINED__

OBJCUWPWINDOWSUIXAMLEXPORT
@interface WUXIAccessKeyInvokedEventArgs : RTObject
+ (instancetype)make __attribute__ ((ns_returns_retained));
#if defined(__cplusplus)
+ (instancetype)createWith:(IInspectable*)obj __attribute__ ((ns_returns_autoreleased));
#endif
@property BOOL handled;
@end

#endif // __WUXIAccessKeyInvokedEventArgs_DEFINED__

// Windows.UI.Xaml.Input.AccessKeyManager
#ifndef __WUXIAccessKeyManager_DEFINED__
#define __WUXIAccessKeyManager_DEFINED__

OBJCUWPWINDOWSUIXAMLEXPORT
@interface WUXIAccessKeyManager : RTObject
+ (void)exitDisplayMode;
#if defined(__cplusplus)
+ (instancetype)createWith:(IInspectable*)obj __attribute__ ((ns_returns_autoreleased));
#endif
+ (BOOL)isDisplayModeEnabled;
+ (EventRegistrationToken)addIsDisplayModeEnabledChangedEvent:(void(^)(RTObject*, RTObject*))del;
+ (void)removeIsDisplayModeEnabledChangedEvent:(EventRegistrationToken)tok;
@end

#endif // __WUXIAccessKeyManager_DEFINED__

// Windows.UI.Xaml.Input.FocusManager
#ifndef __WUXIFocusManager_DEFINED__
#define __WUXIFocusManager_DEFINED__

OBJCUWPWINDOWSUIXAMLEXPORT
@interface WUXIFocusManager : RTObject
+ (RTObject*)getFocusedElement;
+ (BOOL)tryMoveFocus:(WUXIFocusNavigationDirection)focusNavigationDirection;
+ (WXUIElement*)findNextFocusableElement:(WUXIFocusNavigationDirection)focusNavigationDirection;
+ (WXUIElement*)findNextFocusableElementWithHint:(WUXIFocusNavigationDirection)focusNavigationDirection hintRect:(WFRect*)hintRect;
#if defined(__cplusplus)
+ (instancetype)createWith:(IInspectable*)obj __attribute__ ((ns_returns_autoreleased));
#endif
@end

#endif // __WUXIFocusManager_DEFINED__

// Windows.UI.Xaml.Input.InertiaExpansionBehavior
#ifndef __WUXIInertiaExpansionBehavior_DEFINED__
#define __WUXIInertiaExpansionBehavior_DEFINED__

OBJCUWPWINDOWSUIXAMLEXPORT
@interface WUXIInertiaExpansionBehavior : RTObject
#if defined(__cplusplus)
+ (instancetype)createWith:(IInspectable*)obj __attribute__ ((ns_returns_autoreleased));
#endif
@property double desiredExpansion;
@property double desiredDeceleration;
@end

#endif // __WUXIInertiaExpansionBehavior_DEFINED__

// Windows.UI.Xaml.Input.InertiaRotationBehavior
#ifndef __WUXIInertiaRotationBehavior_DEFINED__
#define __WUXIInertiaRotationBehavior_DEFINED__

OBJCUWPWINDOWSUIXAMLEXPORT
@interface WUXIInertiaRotationBehavior : RTObject
#if defined(__cplusplus)
+ (instancetype)createWith:(IInspectable*)obj __attribute__ ((ns_returns_autoreleased));
#endif
@property double desiredRotation;
@property double desiredDeceleration;
@end

#endif // __WUXIInertiaRotationBehavior_DEFINED__

// Windows.UI.Xaml.Input.InertiaTranslationBehavior
#ifndef __WUXIInertiaTranslationBehavior_DEFINED__
#define __WUXIInertiaTranslationBehavior_DEFINED__

OBJCUWPWINDOWSUIXAMLEXPORT
@interface WUXIInertiaTranslationBehavior : RTObject
#if defined(__cplusplus)
+ (instancetype)createWith:(IInspectable*)obj __attribute__ ((ns_returns_autoreleased));
#endif
@property double desiredDisplacement;
@property double desiredDeceleration;
@end

#endif // __WUXIInertiaTranslationBehavior_DEFINED__

// Windows.UI.Xaml.Input.ManipulationPivot
#ifndef __WUXIManipulationPivot_DEFINED__
#define __WUXIManipulationPivot_DEFINED__

OBJCUWPWINDOWSUIXAMLEXPORT
@interface WUXIManipulationPivot : RTObject
+ (instancetype)make __attribute__ ((ns_returns_retained));
+ (WUXIManipulationPivot*)makeInstanceWithCenterAndRadius:(WFPoint*)center radius:(double)radius ACTIVATOR;
#if defined(__cplusplus)
+ (instancetype)createWith:(IInspectable*)obj __attribute__ ((ns_returns_autoreleased));
#endif
@property double radius;
@property (retain) WFPoint* center;
@end

#endif // __WUXIManipulationPivot_DEFINED__

// Windows.UI.Xaml.RoutedEventArgs
#ifndef __WXRoutedEventArgs_DEFINED__
#define __WXRoutedEventArgs_DEFINED__

OBJCUWPWINDOWSUIXAMLEXPORT
@interface WXRoutedEventArgs : RTObject
+ (instancetype)make __attribute__ ((ns_returns_retained));
#if defined(__cplusplus)
+ (instancetype)createWith:(IInspectable*)obj __attribute__ ((ns_returns_autoreleased));
#endif
@property (readonly) RTObject* originalSource;
@end

#endif // __WXRoutedEventArgs_DEFINED__

// Windows.UI.Xaml.Input.ContextRequestedEventArgs
#ifndef __WUXIContextRequestedEventArgs_DEFINED__
#define __WUXIContextRequestedEventArgs_DEFINED__

OBJCUWPWINDOWSUIXAMLEXPORT
@interface WUXIContextRequestedEventArgs : WXRoutedEventArgs
+ (instancetype)make __attribute__ ((ns_returns_retained));
#if defined(__cplusplus)
+ (instancetype)createWith:(IInspectable*)obj __attribute__ ((ns_returns_autoreleased));
#endif
@property BOOL handled;
- (BOOL)tryGetPosition:(WXUIElement*)relativeTo point:(WFPoint**)point;
@end

#endif // __WUXIContextRequestedEventArgs_DEFINED__

// Windows.UI.Xaml.Input.DoubleTappedRoutedEventArgs
#ifndef __WUXIDoubleTappedRoutedEventArgs_DEFINED__
#define __WUXIDoubleTappedRoutedEventArgs_DEFINED__

OBJCUWPWINDOWSUIXAMLEXPORT
@interface WUXIDoubleTappedRoutedEventArgs : WXRoutedEventArgs
+ (instancetype)make __attribute__ ((ns_returns_retained));
#if defined(__cplusplus)
+ (instancetype)createWith:(IInspectable*)obj __attribute__ ((ns_returns_autoreleased));
#endif
@property BOOL handled;
@property (readonly) WDIPointerDeviceType pointerDeviceType;
- (WFPoint*)getPosition:(WXUIElement*)relativeTo;
@end

#endif // __WUXIDoubleTappedRoutedEventArgs_DEFINED__

// Windows.UI.Xaml.Input.HoldingRoutedEventArgs
#ifndef __WUXIHoldingRoutedEventArgs_DEFINED__
#define __WUXIHoldingRoutedEventArgs_DEFINED__

OBJCUWPWINDOWSUIXAMLEXPORT
@interface WUXIHoldingRoutedEventArgs : WXRoutedEventArgs
+ (instancetype)make __attribute__ ((ns_returns_retained));
#if defined(__cplusplus)
+ (instancetype)createWith:(IInspectable*)obj __attribute__ ((ns_returns_autoreleased));
#endif
@property BOOL handled;
@property (readonly) WUIHoldingState holdingState;
@property (readonly) WDIPointerDeviceType pointerDeviceType;
- (WFPoint*)getPosition:(WXUIElement*)relativeTo;
@end

#endif // __WUXIHoldingRoutedEventArgs_DEFINED__

// Windows.UI.Xaml.DependencyObject
#ifndef __WXDependencyObject_DEFINED__
#define __WXDependencyObject_DEFINED__

OBJCUWPWINDOWSUIXAMLEXPORT
@interface WXDependencyObject : RTObject
#if defined(__cplusplus)
+ (instancetype)createWith:(IInspectable*)obj __attribute__ ((ns_returns_autoreleased));
#endif
@property (readonly) WUCCoreDispatcher* dispatcher;
- (RTObject*)getValue:(WXDependencyProperty*)dp;
- (void)setValue:(WXDependencyProperty*)dp value:(RTObject*)value;
- (void)clearValue:(WXDependencyProperty*)dp;
- (RTObject*)readLocalValue:(WXDependencyProperty*)dp;
- (RTObject*)getAnimationBaseValue:(WXDependencyProperty*)dp;
- (int64_t)registerPropertyChangedCallback:(WXDependencyProperty*)dp callback:(WXDependencyPropertyChangedCallback)callback;
- (void)unregisterPropertyChangedCallback:(WXDependencyProperty*)dp token:(int64_t)token;
@end

#endif // __WXDependencyObject_DEFINED__

// Windows.UI.Xaml.Input.InputScope
#ifndef __WUXIInputScope_DEFINED__
#define __WUXIInputScope_DEFINED__

OBJCUWPWINDOWSUIXAMLEXPORT
@interface WUXIInputScope : WXDependencyObject
+ (instancetype)make __attribute__ ((ns_returns_retained));
#if defined(__cplusplus)
+ (instancetype)createWith:(IInspectable*)obj __attribute__ ((ns_returns_autoreleased));
#endif
@property (readonly) NSMutableArray* /* WUXIInputScopeName* */ names;
@end

#endif // __WUXIInputScope_DEFINED__

// Windows.UI.Xaml.Input.InputScopeName
#ifndef __WUXIInputScopeName_DEFINED__
#define __WUXIInputScopeName_DEFINED__

OBJCUWPWINDOWSUIXAMLEXPORT
@interface WUXIInputScopeName : WXDependencyObject
+ (instancetype)make __attribute__ ((ns_returns_retained));
+ (WUXIInputScopeName*)makeInstance:(WUXIInputScopeNameValue)nameValue ACTIVATOR;
#if defined(__cplusplus)
+ (instancetype)createWith:(IInspectable*)obj __attribute__ ((ns_returns_autoreleased));
#endif
@property WUXIInputScopeNameValue nameValue;
@end

#endif // __WUXIInputScopeName_DEFINED__

// Windows.UI.Xaml.Input.KeyRoutedEventArgs
#ifndef __WUXIKeyRoutedEventArgs_DEFINED__
#define __WUXIKeyRoutedEventArgs_DEFINED__

OBJCUWPWINDOWSUIXAMLEXPORT
@interface WUXIKeyRoutedEventArgs : WXRoutedEventArgs
#if defined(__cplusplus)
+ (instancetype)createWith:(IInspectable*)obj __attribute__ ((ns_returns_autoreleased));
#endif
@property BOOL handled;
@property (readonly) WSVirtualKey key;
@property (readonly) WUCCorePhysicalKeyStatus* keyStatus;
@property (readonly) WSVirtualKey originalKey;
@property (readonly) NSString * deviceId;
@end

#endif // __WUXIKeyRoutedEventArgs_DEFINED__

// Windows.UI.Xaml.Input.ManipulationCompletedRoutedEventArgs
#ifndef __WUXIManipulationCompletedRoutedEventArgs_DEFINED__
#define __WUXIManipulationCompletedRoutedEventArgs_DEFINED__

OBJCUWPWINDOWSUIXAMLEXPORT
@interface WUXIManipulationCompletedRoutedEventArgs : WXRoutedEventArgs
+ (instancetype)make __attribute__ ((ns_returns_retained));
#if defined(__cplusplus)
+ (instancetype)createWith:(IInspectable*)obj __attribute__ ((ns_returns_autoreleased));
#endif
@property BOOL handled;
@property (readonly) WXUIElement* container;
@property (readonly) WUIManipulationDelta* cumulative;
@property (readonly) BOOL isInertial;
@property (readonly) WDIPointerDeviceType pointerDeviceType;
@property (readonly) WFPoint* position;
@property (readonly) WUIManipulationVelocities* velocities;
@end

#endif // __WUXIManipulationCompletedRoutedEventArgs_DEFINED__

// Windows.UI.Xaml.Input.ManipulationDeltaRoutedEventArgs
#ifndef __WUXIManipulationDeltaRoutedEventArgs_DEFINED__
#define __WUXIManipulationDeltaRoutedEventArgs_DEFINED__

OBJCUWPWINDOWSUIXAMLEXPORT
@interface WUXIManipulationDeltaRoutedEventArgs : WXRoutedEventArgs
+ (instancetype)make __attribute__ ((ns_returns_retained));
#if defined(__cplusplus)
+ (instancetype)createWith:(IInspectable*)obj __attribute__ ((ns_returns_autoreleased));
#endif
@property BOOL handled;
@property (readonly) WXUIElement* container;
@property (readonly) WUIManipulationDelta* cumulative;
@property (readonly) WUIManipulationDelta* delta;
@property (readonly) BOOL isInertial;
@property (readonly) WDIPointerDeviceType pointerDeviceType;
@property (readonly) WFPoint* position;
@property (readonly) WUIManipulationVelocities* velocities;
- (void)complete;
@end

#endif // __WUXIManipulationDeltaRoutedEventArgs_DEFINED__

// Windows.UI.Xaml.Input.ManipulationInertiaStartingRoutedEventArgs
#ifndef __WUXIManipulationInertiaStartingRoutedEventArgs_DEFINED__
#define __WUXIManipulationInertiaStartingRoutedEventArgs_DEFINED__

OBJCUWPWINDOWSUIXAMLEXPORT
@interface WUXIManipulationInertiaStartingRoutedEventArgs : WXRoutedEventArgs
+ (instancetype)make __attribute__ ((ns_returns_retained));
#if defined(__cplusplus)
+ (instancetype)createWith:(IInspectable*)obj __attribute__ ((ns_returns_autoreleased));
#endif
@property (retain) WUXIInertiaTranslationBehavior* translationBehavior;
@property (retain) WUXIInertiaRotationBehavior* rotationBehavior;
@property BOOL handled;
@property (retain) WUXIInertiaExpansionBehavior* expansionBehavior;
@property (readonly) WXUIElement* container;
@property (readonly) WUIManipulationDelta* cumulative;
@property (readonly) WUIManipulationDelta* delta;
@property (readonly) WDIPointerDeviceType pointerDeviceType;
@property (readonly) WUIManipulationVelocities* velocities;
@end

#endif // __WUXIManipulationInertiaStartingRoutedEventArgs_DEFINED__

// Windows.UI.Xaml.Input.ManipulationStartedRoutedEventArgs
#ifndef __WUXIManipulationStartedRoutedEventArgs_DEFINED__
#define __WUXIManipulationStartedRoutedEventArgs_DEFINED__

OBJCUWPWINDOWSUIXAMLEXPORT
@interface WUXIManipulationStartedRoutedEventArgs : WXRoutedEventArgs
+ (instancetype)make __attribute__ ((ns_returns_retained));
#if defined(__cplusplus)
+ (instancetype)createWith:(IInspectable*)obj __attribute__ ((ns_returns_autoreleased));
#endif
@property BOOL handled;
@property (readonly) WXUIElement* container;
@property (readonly) WUIManipulationDelta* cumulative;
@property (readonly) WDIPointerDeviceType pointerDeviceType;
@property (readonly) WFPoint* position;
- (void)complete;
@end

#endif // __WUXIManipulationStartedRoutedEventArgs_DEFINED__

// Windows.UI.Xaml.Input.ManipulationStartingRoutedEventArgs
#ifndef __WUXIManipulationStartingRoutedEventArgs_DEFINED__
#define __WUXIManipulationStartingRoutedEventArgs_DEFINED__

OBJCUWPWINDOWSUIXAMLEXPORT
@interface WUXIManipulationStartingRoutedEventArgs : WXRoutedEventArgs
+ (instancetype)make __attribute__ ((ns_returns_retained));
#if defined(__cplusplus)
+ (instancetype)createWith:(IInspectable*)obj __attribute__ ((ns_returns_autoreleased));
#endif
@property (retain) WUXIManipulationPivot* pivot;
@property WUXIManipulationModes mode;
@property BOOL handled;
@property (retain) WXUIElement* container;
@end

#endif // __WUXIManipulationStartingRoutedEventArgs_DEFINED__

// Windows.UI.Xaml.Input.PointerRoutedEventArgs
#ifndef __WUXIPointerRoutedEventArgs_DEFINED__
#define __WUXIPointerRoutedEventArgs_DEFINED__

OBJCUWPWINDOWSUIXAMLEXPORT
@interface WUXIPointerRoutedEventArgs : WXRoutedEventArgs
#if defined(__cplusplus)
+ (instancetype)createWith:(IInspectable*)obj __attribute__ ((ns_returns_autoreleased));
#endif
@property BOOL handled;
@property (readonly) WSVirtualKeyModifiers keyModifiers;
@property (readonly) WUXIPointer* pointer;
- (WUIPointerPoint*)getCurrentPoint:(WXUIElement*)relativeTo;
- (NSMutableArray* /* WUIPointerPoint* */)getIntermediatePoints:(WXUIElement*)relativeTo;
@end

#endif // __WUXIPointerRoutedEventArgs_DEFINED__

// Windows.UI.Xaml.Input.RightTappedRoutedEventArgs
#ifndef __WUXIRightTappedRoutedEventArgs_DEFINED__
#define __WUXIRightTappedRoutedEventArgs_DEFINED__

OBJCUWPWINDOWSUIXAMLEXPORT
@interface WUXIRightTappedRoutedEventArgs : WXRoutedEventArgs
+ (instancetype)make __attribute__ ((ns_returns_retained));
#if defined(__cplusplus)
+ (instancetype)createWith:(IInspectable*)obj __attribute__ ((ns_returns_autoreleased));
#endif
@property BOOL handled;
@property (readonly) WDIPointerDeviceType pointerDeviceType;
- (WFPoint*)getPosition:(WXUIElement*)relativeTo;
@end

#endif // __WUXIRightTappedRoutedEventArgs_DEFINED__

// Windows.UI.Xaml.Input.TappedRoutedEventArgs
#ifndef __WUXITappedRoutedEventArgs_DEFINED__
#define __WUXITappedRoutedEventArgs_DEFINED__

OBJCUWPWINDOWSUIXAMLEXPORT
@interface WUXITappedRoutedEventArgs : WXRoutedEventArgs
+ (instancetype)make __attribute__ ((ns_returns_retained));
#if defined(__cplusplus)
+ (instancetype)createWith:(IInspectable*)obj __attribute__ ((ns_returns_autoreleased));
#endif
@property BOOL handled;
@property (readonly) WDIPointerDeviceType pointerDeviceType;
- (WFPoint*)getPosition:(WXUIElement*)relativeTo;
@end

#endif // __WUXITappedRoutedEventArgs_DEFINED__

