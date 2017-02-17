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

// WindowsGamingInput.h
// Generated from winmd2objc

#pragma once

#ifndef OBJCUWP_WINDOWS_GAMING_INPUT_EXPORT
#define OBJCUWP_WINDOWS_GAMING_INPUT_EXPORT __declspec(dllimport)
#ifndef IN_OBJCUWP_BUILD
#pragma comment(lib, "ObjCUWP_Windows_Gaming_Input.lib")
#endif
#endif
#include <UWP/interopBase.h>

@class WGIHeadset, WGIArcadeStick, WGIGamepad, WGIRacingWheel, WGIUINavigationController;
@class WGIArcadeStickReading, WGIGamepadReading, WGIGamepadVibration, WGIRacingWheelReading, WGIUINavigationReading;
@protocol WGIIGameController, WGIIArcadeStick, WGIIArcadeStickStatics, WGIIGamepad, WGIIGamepad2, WGIIGamepadStatics, WGIIHeadset, WGIIRacingWheel, WGIIRacingWheelStatics, WGIIUINavigationController, WGIIUINavigationControllerStatics;

// Windows.Gaming.Input.ArcadeStickButtons
enum _WGIArcadeStickButtons {
    WGIArcadeStickButtonsNone = 0,
    WGIArcadeStickButtonsStickUp = 1,
    WGIArcadeStickButtonsStickDown = 2,
    WGIArcadeStickButtonsStickLeft = 4,
    WGIArcadeStickButtonsStickRight = 8,
    WGIArcadeStickButtonsAction1 = 16,
    WGIArcadeStickButtonsAction2 = 32,
    WGIArcadeStickButtonsAction3 = 64,
    WGIArcadeStickButtonsAction4 = 128,
    WGIArcadeStickButtonsAction5 = 256,
    WGIArcadeStickButtonsAction6 = 512,
    WGIArcadeStickButtonsSpecial1 = 1024,
    WGIArcadeStickButtonsSpecial2 = 2048,
};
typedef unsigned WGIArcadeStickButtons;

// Windows.Gaming.Input.GameControllerButtonLabel
enum _WGIGameControllerButtonLabel {
    WGIGameControllerButtonLabelNone = 0,
    WGIGameControllerButtonLabelXboxBack = 1,
    WGIGameControllerButtonLabelXboxStart = 2,
    WGIGameControllerButtonLabelXboxMenu = 3,
    WGIGameControllerButtonLabelXboxView = 4,
    WGIGameControllerButtonLabelXboxUp = 5,
    WGIGameControllerButtonLabelXboxDown = 6,
    WGIGameControllerButtonLabelXboxLeft = 7,
    WGIGameControllerButtonLabelXboxRight = 8,
    WGIGameControllerButtonLabelXboxA = 9,
    WGIGameControllerButtonLabelXboxB = 10,
    WGIGameControllerButtonLabelXboxX = 11,
    WGIGameControllerButtonLabelXboxY = 12,
    WGIGameControllerButtonLabelXboxLeftBumper = 13,
    WGIGameControllerButtonLabelXboxLeftTrigger = 14,
    WGIGameControllerButtonLabelXboxLeftStickButton = 15,
    WGIGameControllerButtonLabelXboxRightBumper = 16,
    WGIGameControllerButtonLabelXboxRightTrigger = 17,
    WGIGameControllerButtonLabelXboxRightStickButton = 18,
    WGIGameControllerButtonLabelXboxPaddle1 = 19,
    WGIGameControllerButtonLabelXboxPaddle2 = 20,
    WGIGameControllerButtonLabelXboxPaddle3 = 21,
    WGIGameControllerButtonLabelXboxPaddle4 = 22,
    WGIGameControllerButtonLabelMode = 23,
    WGIGameControllerButtonLabelSelect = 24,
    WGIGameControllerButtonLabelMenu = 25,
    WGIGameControllerButtonLabelView = 26,
    WGIGameControllerButtonLabelBack = 27,
    WGIGameControllerButtonLabelStart = 28,
    WGIGameControllerButtonLabelOptions = 29,
    WGIGameControllerButtonLabelShare = 30,
    WGIGameControllerButtonLabelUp = 31,
    WGIGameControllerButtonLabelDown = 32,
    WGIGameControllerButtonLabelLeft = 33,
    WGIGameControllerButtonLabelRight = 34,
    WGIGameControllerButtonLabelLetterA = 35,
    WGIGameControllerButtonLabelLetterB = 36,
    WGIGameControllerButtonLabelLetterC = 37,
    WGIGameControllerButtonLabelLetterL = 38,
    WGIGameControllerButtonLabelLetterR = 39,
    WGIGameControllerButtonLabelLetterX = 40,
    WGIGameControllerButtonLabelLetterY = 41,
    WGIGameControllerButtonLabelLetterZ = 42,
    WGIGameControllerButtonLabelCross = 43,
    WGIGameControllerButtonLabelCircle = 44,
    WGIGameControllerButtonLabelSquare = 45,
    WGIGameControllerButtonLabelTriangle = 46,
    WGIGameControllerButtonLabelLeftBumper = 47,
    WGIGameControllerButtonLabelLeftTrigger = 48,
    WGIGameControllerButtonLabelLeftStickButton = 49,
    WGIGameControllerButtonLabelLeft1 = 50,
    WGIGameControllerButtonLabelLeft2 = 51,
    WGIGameControllerButtonLabelLeft3 = 52,
    WGIGameControllerButtonLabelRightBumper = 53,
    WGIGameControllerButtonLabelRightTrigger = 54,
    WGIGameControllerButtonLabelRightStickButton = 55,
    WGIGameControllerButtonLabelRight1 = 56,
    WGIGameControllerButtonLabelRight2 = 57,
    WGIGameControllerButtonLabelRight3 = 58,
    WGIGameControllerButtonLabelPaddle1 = 59,
    WGIGameControllerButtonLabelPaddle2 = 60,
    WGIGameControllerButtonLabelPaddle3 = 61,
    WGIGameControllerButtonLabelPaddle4 = 62,
    WGIGameControllerButtonLabelPlus = 63,
    WGIGameControllerButtonLabelMinus = 64,
    WGIGameControllerButtonLabelDownLeftArrow = 65,
    WGIGameControllerButtonLabelDialLeft = 66,
    WGIGameControllerButtonLabelDialRight = 67,
    WGIGameControllerButtonLabelSuspension = 68,
};
typedef unsigned WGIGameControllerButtonLabel;

// Windows.Gaming.Input.GamepadButtons
enum _WGIGamepadButtons {
    WGIGamepadButtonsNone = 0,
    WGIGamepadButtonsMenu = 1,
    WGIGamepadButtonsView = 2,
    WGIGamepadButtonsA = 4,
    WGIGamepadButtonsB = 8,
    WGIGamepadButtonsX = 16,
    WGIGamepadButtonsY = 32,
    WGIGamepadButtonsDPadUp = 64,
    WGIGamepadButtonsDPadDown = 128,
    WGIGamepadButtonsDPadLeft = 256,
    WGIGamepadButtonsDPadRight = 512,
    WGIGamepadButtonsLeftShoulder = 1024,
    WGIGamepadButtonsRightShoulder = 2048,
    WGIGamepadButtonsLeftThumbstick = 4096,
    WGIGamepadButtonsRightThumbstick = 8192,
    WGIGamepadButtonsPaddle1 = 16384,
    WGIGamepadButtonsPaddle2 = 32768,
    WGIGamepadButtonsPaddle3 = 65536,
    WGIGamepadButtonsPaddle4 = 131072,
};
typedef unsigned WGIGamepadButtons;

// Windows.Gaming.Input.RacingWheelButtons
enum _WGIRacingWheelButtons {
    WGIRacingWheelButtonsNone = 0,
    WGIRacingWheelButtonsPreviousGear = 1,
    WGIRacingWheelButtonsNextGear = 2,
    WGIRacingWheelButtonsDPadUp = 4,
    WGIRacingWheelButtonsDPadDown = 8,
    WGIRacingWheelButtonsDPadLeft = 16,
    WGIRacingWheelButtonsDPadRight = 32,
    WGIRacingWheelButtonsButton1 = 64,
    WGIRacingWheelButtonsButton2 = 128,
    WGIRacingWheelButtonsButton3 = 256,
    WGIRacingWheelButtonsButton4 = 512,
    WGIRacingWheelButtonsButton5 = 1024,
    WGIRacingWheelButtonsButton6 = 2048,
    WGIRacingWheelButtonsButton7 = 4096,
    WGIRacingWheelButtonsButton8 = 8192,
    WGIRacingWheelButtonsButton9 = 16384,
    WGIRacingWheelButtonsButton10 = 32768,
    WGIRacingWheelButtonsButton11 = 65536,
    WGIRacingWheelButtonsButton12 = 131072,
    WGIRacingWheelButtonsButton13 = 262144,
    WGIRacingWheelButtonsButton14 = 524288,
    WGIRacingWheelButtonsButton15 = 1048576,
    WGIRacingWheelButtonsButton16 = 2097152,
};
typedef unsigned WGIRacingWheelButtons;

// Windows.Gaming.Input.RequiredUINavigationButtons
enum _WGIRequiredUINavigationButtons {
    WGIRequiredUINavigationButtonsNone = 0,
    WGIRequiredUINavigationButtonsMenu = 1,
    WGIRequiredUINavigationButtonsView = 2,
    WGIRequiredUINavigationButtonsAccept = 4,
    WGIRequiredUINavigationButtonsCancel = 8,
    WGIRequiredUINavigationButtonsUp = 16,
    WGIRequiredUINavigationButtonsDown = 32,
    WGIRequiredUINavigationButtonsLeft = 64,
    WGIRequiredUINavigationButtonsRight = 128,
};
typedef unsigned WGIRequiredUINavigationButtons;

// Windows.Gaming.Input.OptionalUINavigationButtons
enum _WGIOptionalUINavigationButtons {
    WGIOptionalUINavigationButtonsNone = 0,
    WGIOptionalUINavigationButtonsContext1 = 1,
    WGIOptionalUINavigationButtonsContext2 = 2,
    WGIOptionalUINavigationButtonsContext3 = 4,
    WGIOptionalUINavigationButtonsContext4 = 8,
    WGIOptionalUINavigationButtonsPageUp = 16,
    WGIOptionalUINavigationButtonsPageDown = 32,
    WGIOptionalUINavigationButtonsPageLeft = 64,
    WGIOptionalUINavigationButtonsPageRight = 128,
    WGIOptionalUINavigationButtonsScrollUp = 256,
    WGIOptionalUINavigationButtonsScrollDown = 512,
    WGIOptionalUINavigationButtonsScrollLeft = 1024,
    WGIOptionalUINavigationButtonsScrollRight = 2048,
};
typedef unsigned WGIOptionalUINavigationButtons;

#include "WindowsFoundation.h"
#include "WindowsSystem.h"
#include "WindowsGamingInputForceFeedback.h"

#import <Foundation/Foundation.h>

// [struct] Windows.Gaming.Input.ArcadeStickReading
OBJCUWP_WINDOWS_GAMING_INPUT_EXPORT
@interface WGIArcadeStickReading : NSObject
+ (instancetype)new;
@property uint64_t timestamp;
@property WGIArcadeStickButtons buttons;
@end

// [struct] Windows.Gaming.Input.GamepadReading
OBJCUWP_WINDOWS_GAMING_INPUT_EXPORT
@interface WGIGamepadReading : NSObject
+ (instancetype)new;
@property uint64_t timestamp;
@property WGIGamepadButtons buttons;
@property double leftTrigger;
@property double rightTrigger;
@property double leftThumbstickX;
@property double leftThumbstickY;
@property double rightThumbstickX;
@property double rightThumbstickY;
@end

// [struct] Windows.Gaming.Input.GamepadVibration
OBJCUWP_WINDOWS_GAMING_INPUT_EXPORT
@interface WGIGamepadVibration : NSObject
+ (instancetype)new;
@property double leftMotor;
@property double rightMotor;
@property double leftTrigger;
@property double rightTrigger;
@end

// [struct] Windows.Gaming.Input.RacingWheelReading
OBJCUWP_WINDOWS_GAMING_INPUT_EXPORT
@interface WGIRacingWheelReading : NSObject
+ (instancetype)new;
@property uint64_t timestamp;
@property WGIRacingWheelButtons buttons;
@property int patternShifterGear;
@property double wheel;
@property double throttle;
@property double brake;
@property double clutch;
@property double handbrake;
@end

// [struct] Windows.Gaming.Input.UINavigationReading
OBJCUWP_WINDOWS_GAMING_INPUT_EXPORT
@interface WGIUINavigationReading : NSObject
+ (instancetype)new;
@property uint64_t timestamp;
@property WGIRequiredUINavigationButtons requiredButtons;
@property WGIOptionalUINavigationButtons optionalButtons;
@end

// Windows.Gaming.Input.IGameController
#ifndef __WGIIGameController_DEFINED__
#define __WGIIGameController_DEFINED__

@protocol WGIIGameController
@property (readonly) WGIHeadset* headset;
@property (readonly) BOOL isWireless;
@property (readonly) WSUser* user;
- (EventRegistrationToken)addHeadsetConnectedEvent:(void(^)(RTObject<WGIIGameController>*, WGIHeadset*))del;
- (void)removeHeadsetConnectedEvent:(EventRegistrationToken)tok;
- (EventRegistrationToken)addHeadsetDisconnectedEvent:(void(^)(RTObject<WGIIGameController>*, WGIHeadset*))del;
- (void)removeHeadsetDisconnectedEvent:(EventRegistrationToken)tok;
- (EventRegistrationToken)addUserChangedEvent:(void(^)(RTObject<WGIIGameController>*, WSUserChangedEventArgs*))del;
- (void)removeUserChangedEvent:(EventRegistrationToken)tok;
@end

OBJCUWP_WINDOWS_GAMING_INPUT_EXPORT
@interface WGIIGameController : RTObject <WGIIGameController>
@end

#endif // __WGIIGameController_DEFINED__

// Windows.Gaming.Input.Headset
#ifndef __WGIHeadset_DEFINED__
#define __WGIHeadset_DEFINED__

OBJCUWP_WINDOWS_GAMING_INPUT_EXPORT
@interface WGIHeadset : RTObject
#if defined(__cplusplus)
+ (instancetype)createWith:(IInspectable*)obj __attribute__ ((ns_returns_autoreleased));
#endif
@property (readonly) NSString * captureDeviceId;
@property (readonly) NSString * renderDeviceId;
@end

#endif // __WGIHeadset_DEFINED__

// Windows.Gaming.Input.ArcadeStick
#ifndef __WGIArcadeStick_DEFINED__
#define __WGIArcadeStick_DEFINED__

OBJCUWP_WINDOWS_GAMING_INPUT_EXPORT
@interface WGIArcadeStick : RTObject <WGIIGameController>
#if defined(__cplusplus)
+ (instancetype)createWith:(IInspectable*)obj __attribute__ ((ns_returns_autoreleased));
#endif
@property (readonly) WGIHeadset* headset;
@property (readonly) BOOL isWireless;
@property (readonly) WSUser* user;
+ (NSArray* /* WGIArcadeStick* */)arcadeSticks;
- (EventRegistrationToken)addHeadsetConnectedEvent:(void(^)(RTObject<WGIIGameController>*, WGIHeadset*))del;
- (void)removeHeadsetConnectedEvent:(EventRegistrationToken)tok;
- (EventRegistrationToken)addHeadsetDisconnectedEvent:(void(^)(RTObject<WGIIGameController>*, WGIHeadset*))del;
- (void)removeHeadsetDisconnectedEvent:(EventRegistrationToken)tok;
- (EventRegistrationToken)addUserChangedEvent:(void(^)(RTObject<WGIIGameController>*, WSUserChangedEventArgs*))del;
- (void)removeUserChangedEvent:(EventRegistrationToken)tok;
+ (EventRegistrationToken)addArcadeStickAddedEvent:(void(^)(RTObject*, WGIArcadeStick*))del;
+ (void)removeArcadeStickAddedEvent:(EventRegistrationToken)tok;
+ (EventRegistrationToken)addArcadeStickRemovedEvent:(void(^)(RTObject*, WGIArcadeStick*))del;
+ (void)removeArcadeStickRemovedEvent:(EventRegistrationToken)tok;
- (WGIGameControllerButtonLabel)getButtonLabel:(WGIArcadeStickButtons)button;
- (WGIArcadeStickReading*)getCurrentReading;
@end

#endif // __WGIArcadeStick_DEFINED__

// Windows.Gaming.Input.Gamepad
#ifndef __WGIGamepad_DEFINED__
#define __WGIGamepad_DEFINED__

OBJCUWP_WINDOWS_GAMING_INPUT_EXPORT
@interface WGIGamepad : RTObject <WGIIGameController>
#if defined(__cplusplus)
+ (instancetype)createWith:(IInspectable*)obj __attribute__ ((ns_returns_autoreleased));
#endif
@property (readonly) WGIHeadset* headset;
@property (readonly) BOOL isWireless;
@property (readonly) WSUser* user;
@property (retain) WGIGamepadVibration* vibration;
+ (NSArray* /* WGIGamepad* */)gamepads;
- (EventRegistrationToken)addHeadsetConnectedEvent:(void(^)(RTObject<WGIIGameController>*, WGIHeadset*))del;
- (void)removeHeadsetConnectedEvent:(EventRegistrationToken)tok;
- (EventRegistrationToken)addHeadsetDisconnectedEvent:(void(^)(RTObject<WGIIGameController>*, WGIHeadset*))del;
- (void)removeHeadsetDisconnectedEvent:(EventRegistrationToken)tok;
- (EventRegistrationToken)addUserChangedEvent:(void(^)(RTObject<WGIIGameController>*, WSUserChangedEventArgs*))del;
- (void)removeUserChangedEvent:(EventRegistrationToken)tok;
+ (EventRegistrationToken)addGamepadAddedEvent:(void(^)(RTObject*, WGIGamepad*))del;
+ (void)removeGamepadAddedEvent:(EventRegistrationToken)tok;
+ (EventRegistrationToken)addGamepadRemovedEvent:(void(^)(RTObject*, WGIGamepad*))del;
+ (void)removeGamepadRemovedEvent:(EventRegistrationToken)tok;
- (WGIGamepadReading*)getCurrentReading;
- (WGIGameControllerButtonLabel)getButtonLabel:(WGIGamepadButtons)button;
@end

#endif // __WGIGamepad_DEFINED__

// Windows.Gaming.Input.RacingWheel
#ifndef __WGIRacingWheel_DEFINED__
#define __WGIRacingWheel_DEFINED__

OBJCUWP_WINDOWS_GAMING_INPUT_EXPORT
@interface WGIRacingWheel : RTObject <WGIIGameController>
#if defined(__cplusplus)
+ (instancetype)createWith:(IInspectable*)obj __attribute__ ((ns_returns_autoreleased));
#endif
@property (readonly) WGIHeadset* headset;
@property (readonly) BOOL isWireless;
@property (readonly) WSUser* user;
@property (readonly) BOOL hasClutch;
@property (readonly) BOOL hasHandbrake;
@property (readonly) BOOL hasPatternShifter;
@property (readonly) int maxPatternShifterGear;
@property (readonly) double maxWheelAngle;
@property (readonly) WGIFForceFeedbackMotor* wheelMotor;
+ (NSArray* /* WGIRacingWheel* */)racingWheels;
- (EventRegistrationToken)addHeadsetConnectedEvent:(void(^)(RTObject<WGIIGameController>*, WGIHeadset*))del;
- (void)removeHeadsetConnectedEvent:(EventRegistrationToken)tok;
- (EventRegistrationToken)addHeadsetDisconnectedEvent:(void(^)(RTObject<WGIIGameController>*, WGIHeadset*))del;
- (void)removeHeadsetDisconnectedEvent:(EventRegistrationToken)tok;
- (EventRegistrationToken)addUserChangedEvent:(void(^)(RTObject<WGIIGameController>*, WSUserChangedEventArgs*))del;
- (void)removeUserChangedEvent:(EventRegistrationToken)tok;
+ (EventRegistrationToken)addRacingWheelAddedEvent:(void(^)(RTObject*, WGIRacingWheel*))del;
+ (void)removeRacingWheelAddedEvent:(EventRegistrationToken)tok;
+ (EventRegistrationToken)addRacingWheelRemovedEvent:(void(^)(RTObject*, WGIRacingWheel*))del;
+ (void)removeRacingWheelRemovedEvent:(EventRegistrationToken)tok;
- (WGIGameControllerButtonLabel)getButtonLabel:(WGIRacingWheelButtons)button;
- (WGIRacingWheelReading*)getCurrentReading;
@end

#endif // __WGIRacingWheel_DEFINED__

// Windows.Gaming.Input.UINavigationController
#ifndef __WGIUINavigationController_DEFINED__
#define __WGIUINavigationController_DEFINED__

OBJCUWP_WINDOWS_GAMING_INPUT_EXPORT
@interface WGIUINavigationController : RTObject <WGIIGameController>
#if defined(__cplusplus)
+ (instancetype)createWith:(IInspectable*)obj __attribute__ ((ns_returns_autoreleased));
#endif
@property (readonly) WGIHeadset* headset;
@property (readonly) BOOL isWireless;
@property (readonly) WSUser* user;
+ (NSArray* /* WGIUINavigationController* */)uINavigationControllers;
- (EventRegistrationToken)addHeadsetConnectedEvent:(void(^)(RTObject<WGIIGameController>*, WGIHeadset*))del;
- (void)removeHeadsetConnectedEvent:(EventRegistrationToken)tok;
- (EventRegistrationToken)addHeadsetDisconnectedEvent:(void(^)(RTObject<WGIIGameController>*, WGIHeadset*))del;
- (void)removeHeadsetDisconnectedEvent:(EventRegistrationToken)tok;
- (EventRegistrationToken)addUserChangedEvent:(void(^)(RTObject<WGIIGameController>*, WSUserChangedEventArgs*))del;
- (void)removeUserChangedEvent:(EventRegistrationToken)tok;
+ (EventRegistrationToken)addUINavigationControllerAddedEvent:(void(^)(RTObject*, WGIUINavigationController*))del;
+ (void)removeUINavigationControllerAddedEvent:(EventRegistrationToken)tok;
+ (EventRegistrationToken)addUINavigationControllerRemovedEvent:(void(^)(RTObject*, WGIUINavigationController*))del;
+ (void)removeUINavigationControllerRemovedEvent:(EventRegistrationToken)tok;
- (WGIUINavigationReading*)getCurrentReading;
- (WGIGameControllerButtonLabel)getOptionalButtonLabel:(WGIOptionalUINavigationButtons)button;
- (WGIGameControllerButtonLabel)getRequiredButtonLabel:(WGIRequiredUINavigationButtons)button;
@end

#endif // __WGIUINavigationController_DEFINED__

