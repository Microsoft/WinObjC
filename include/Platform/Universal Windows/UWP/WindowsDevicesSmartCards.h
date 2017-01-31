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

// WindowsDevicesSmartCards.h
// Generated from winmd2objc

#pragma once

#ifndef OBJCUWP_WINDOWS_DEVICES_SMARTCARDS_EXPORT
#define OBJCUWP_WINDOWS_DEVICES_SMARTCARDS_EXPORT __declspec(dllimport)
#ifndef IN_OBJCUWP_BUILD
#pragma comment(lib, "ObjCUWP_Windows_Devices_SmartCards.lib")
#endif
#endif
#include <UWP/interopBase.h>

@class WDSSmartCardTriggerDetails, WDSSmartCardEmulator, WDSSmartCardAppletIdGroupRegistration, WDSSmartCardAppletIdGroup, WDSSmartCardEmulatorApduReceivedEventArgs, WDSSmartCardEmulatorConnectionDeactivatedEventArgs, WDSSmartCardEmulatorConnectionProperties, WDSSmartCardAutomaticResponseApdu, WDSSmartCardCryptogramPlacementStep, WDSSmartCardCryptogramGenerator, WDSSmartCardCryptogramStorageKeyInfo, WDSSmartCardCryptogramMaterialPossessionProof, WDSSmartCardReader, WDSSmartCard, WDSCardAddedEventArgs, WDSCardRemovedEventArgs, WDSSmartCardProvisioning, WDSSmartCardPinPolicy, WDSSmartCardChallengeContext, WDSSmartCardPinResetRequest, WDSSmartCardPinResetDeferral, WDSSmartCardConnection;
@protocol WDSISmartCardTriggerDetails, WDSISmartCardTriggerDetails2, WDSISmartCardEmulatorStatics, WDSISmartCardEmulatorStatics2, WDSISmartCardEmulator, WDSISmartCardEmulator2, WDSISmartCardEmulatorApduReceivedEventArgs, WDSISmartCardEmulatorApduReceivedEventArgs2, WDSISmartCardEmulatorConnectionProperties, WDSISmartCardEmulatorConnectionDeactivatedEventArgs, WDSISmartCardAppletIdGroup, WDSISmartCardAppletIdGroupFactory, WDSISmartCardAppletIdGroupStatics, WDSISmartCardAppletIdGroupRegistration, WDSISmartCardAutomaticResponseApdu, WDSISmartCardAutomaticResponseApdu2, WDSISmartCardAutomaticResponseApdu3, WDSISmartCardAutomaticResponseApduFactory, WDSISmartCardEmulatorApduReceivedEventArgsWithCryptograms, WDSISmartCardCryptogramStorageKeyInfo, WDSISmartCardCryptogramStorageKeyInfo2, WDSISmartCardCryptogramMaterialPossessionProof, WDSISmartCardCryptogramPlacementStep, WDSISmartCardCryptogramGeneratorStatics, WDSISmartCardCryptogramGenerator, WDSISmartCardReaderStatics, WDSISmartCardReader, WDSICardAddedEventArgs, WDSICardRemovedEventArgs, WDSISmartCard, WDSISmartCardProvisioningStatics, WDSISmartCardProvisioningStatics2, WDSISmartCardProvisioning, WDSISmartCardProvisioning2, WDSISmartCardPinResetRequest, WDSISmartCardPinResetDeferral, WDSISmartCardPinPolicy, WDSISmartCardConnect, WDSISmartCardChallengeContext, WDSISmartCardConnection;

// Windows.Devices.SmartCards.SmartCardTriggerType
enum _WDSSmartCardTriggerType {
    WDSSmartCardTriggerTypeEmulatorTransaction = 0,
    WDSSmartCardTriggerTypeEmulatorNearFieldEntry = 1,
    WDSSmartCardTriggerTypeEmulatorNearFieldExit = 2,
    WDSSmartCardTriggerTypeEmulatorHostApplicationActivated = 3,
    WDSSmartCardTriggerTypeEmulatorAppletIdGroupRegistrationChanged = 4,
    WDSSmartCardTriggerTypeReaderCardAdded = 5,
};
typedef unsigned WDSSmartCardTriggerType;

// Windows.Devices.SmartCards.SmartCardLaunchBehavior
enum _WDSSmartCardLaunchBehavior {
    WDSSmartCardLaunchBehaviorDefault = 0,
    WDSSmartCardLaunchBehaviorAboveLock = 1,
};
typedef unsigned WDSSmartCardLaunchBehavior;

// Windows.Devices.SmartCards.SmartCardEmulatorEnablementPolicy
enum _WDSSmartCardEmulatorEnablementPolicy {
    WDSSmartCardEmulatorEnablementPolicyNever = 0,
    WDSSmartCardEmulatorEnablementPolicyAlways = 1,
    WDSSmartCardEmulatorEnablementPolicyScreenOn = 2,
    WDSSmartCardEmulatorEnablementPolicyScreenUnlocked = 3,
};
typedef unsigned WDSSmartCardEmulatorEnablementPolicy;

// Windows.Devices.SmartCards.SmartCardEmulationCategory
enum _WDSSmartCardEmulationCategory {
    WDSSmartCardEmulationCategoryOther = 0,
    WDSSmartCardEmulationCategoryPayment = 1,
};
typedef unsigned WDSSmartCardEmulationCategory;

// Windows.Devices.SmartCards.SmartCardEmulationType
enum _WDSSmartCardEmulationType {
    WDSSmartCardEmulationTypeHost = 0,
    WDSSmartCardEmulationTypeUicc = 1,
    WDSSmartCardEmulationTypeEmbeddedSE = 2,
};
typedef unsigned WDSSmartCardEmulationType;

// Windows.Devices.SmartCards.SmartCardAppletIdGroupActivationPolicy
enum _WDSSmartCardAppletIdGroupActivationPolicy {
    WDSSmartCardAppletIdGroupActivationPolicyDisabled = 0,
    WDSSmartCardAppletIdGroupActivationPolicyForegroundOverride = 1,
    WDSSmartCardAppletIdGroupActivationPolicyEnabled = 2,
};
typedef unsigned WDSSmartCardAppletIdGroupActivationPolicy;

// Windows.Devices.SmartCards.SmartCardActivationPolicyChangeResult
enum _WDSSmartCardActivationPolicyChangeResult {
    WDSSmartCardActivationPolicyChangeResultDenied = 0,
    WDSSmartCardActivationPolicyChangeResultAllowed = 1,
};
typedef unsigned WDSSmartCardActivationPolicyChangeResult;

// Windows.Devices.SmartCards.SmartCardEmulatorConnectionDeactivatedReason
enum _WDSSmartCardEmulatorConnectionDeactivatedReason {
    WDSSmartCardEmulatorConnectionDeactivatedReasonConnectionLost = 0,
    WDSSmartCardEmulatorConnectionDeactivatedReasonConnectionRedirected = 1,
};
typedef unsigned WDSSmartCardEmulatorConnectionDeactivatedReason;

// Windows.Devices.SmartCards.SmartCardEmulatorConnectionSource
enum _WDSSmartCardEmulatorConnectionSource {
    WDSSmartCardEmulatorConnectionSourceUnknown = 0,
    WDSSmartCardEmulatorConnectionSourceNfcReader = 1,
};
typedef unsigned WDSSmartCardEmulatorConnectionSource;

// Windows.Devices.SmartCards.SmartCardAutomaticResponseStatus
enum _WDSSmartCardAutomaticResponseStatus {
    WDSSmartCardAutomaticResponseStatusNone = 0,
    WDSSmartCardAutomaticResponseStatusSuccess = 1,
    WDSSmartCardAutomaticResponseStatusUnknownError = 2,
};
typedef unsigned WDSSmartCardAutomaticResponseStatus;

// Windows.Devices.SmartCards.SmartCardUnlockPromptingBehavior
enum _WDSSmartCardUnlockPromptingBehavior {
    WDSSmartCardUnlockPromptingBehaviorAllowUnlockPrompt = 0,
    WDSSmartCardUnlockPromptingBehaviorRequireUnlockPrompt = 1,
    WDSSmartCardUnlockPromptingBehaviorPreventUnlockPrompt = 2,
};
typedef unsigned WDSSmartCardUnlockPromptingBehavior;

// Windows.Devices.SmartCards.SmartCardCryptogramStorageKeyAlgorithm
enum _WDSSmartCardCryptogramStorageKeyAlgorithm {
    WDSSmartCardCryptogramStorageKeyAlgorithmNone = 0,
    WDSSmartCardCryptogramStorageKeyAlgorithmRsa2048 = 1,
};
typedef unsigned WDSSmartCardCryptogramStorageKeyAlgorithm;

// Windows.Devices.SmartCards.SmartCardCryptogramMaterialType
enum _WDSSmartCardCryptogramMaterialType {
    WDSSmartCardCryptogramMaterialTypeNone = 0,
    WDSSmartCardCryptogramMaterialTypeStaticDataAuthentication = 1,
    WDSSmartCardCryptogramMaterialTypeTripleDes112 = 2,
    WDSSmartCardCryptogramMaterialTypeAes = 3,
    WDSSmartCardCryptogramMaterialTypeRsaPkcs1 = 4,
};
typedef unsigned WDSSmartCardCryptogramMaterialType;

// Windows.Devices.SmartCards.SmartCardCryptogramAlgorithm
enum _WDSSmartCardCryptogramAlgorithm {
    WDSSmartCardCryptogramAlgorithmNone = 0,
    WDSSmartCardCryptogramAlgorithmCbcMac = 1,
    WDSSmartCardCryptogramAlgorithmCvc3Umd = 2,
    WDSSmartCardCryptogramAlgorithmDecimalizedMsd = 3,
    WDSSmartCardCryptogramAlgorithmCvc3MD = 4,
    WDSSmartCardCryptogramAlgorithmSha1 = 5,
    WDSSmartCardCryptogramAlgorithmSignedDynamicApplicationData = 6,
    WDSSmartCardCryptogramAlgorithmRsaPkcs1 = 7,
};
typedef unsigned WDSSmartCardCryptogramAlgorithm;

// Windows.Devices.SmartCards.SmartCardCryptogramMaterialPackageFormat
enum _WDSSmartCardCryptogramMaterialPackageFormat {
    WDSSmartCardCryptogramMaterialPackageFormatNone = 0,
    WDSSmartCardCryptogramMaterialPackageFormatJweRsaPki = 1,
};
typedef unsigned WDSSmartCardCryptogramMaterialPackageFormat;

// Windows.Devices.SmartCards.SmartCardCryptogramStorageKeyCapabilities
enum _WDSSmartCardCryptogramStorageKeyCapabilities {
    WDSSmartCardCryptogramStorageKeyCapabilitiesNone = 0,
    WDSSmartCardCryptogramStorageKeyCapabilitiesHardwareProtection = 1,
    WDSSmartCardCryptogramStorageKeyCapabilitiesUnlockPrompt = 2,
};
typedef unsigned WDSSmartCardCryptogramStorageKeyCapabilities;

// Windows.Devices.SmartCards.SmartCardCryptogramMaterialPackageConfirmationResponseFormat
enum _WDSSmartCardCryptogramMaterialPackageConfirmationResponseFormat {
    WDSSmartCardCryptogramMaterialPackageConfirmationResponseFormatNone = 0,
    WDSSmartCardCryptogramMaterialPackageConfirmationResponseFormatVisaHmac = 1,
};
typedef unsigned WDSSmartCardCryptogramMaterialPackageConfirmationResponseFormat;

// Windows.Devices.SmartCards.SmartCardCryptogramPlacementOptions
enum _WDSSmartCardCryptogramPlacementOptions {
    WDSSmartCardCryptogramPlacementOptionsNone = 0,
    WDSSmartCardCryptogramPlacementOptionsUnitsAreInNibbles = 1,
    WDSSmartCardCryptogramPlacementOptionsChainOutput = 2,
};
typedef unsigned WDSSmartCardCryptogramPlacementOptions;

// Windows.Devices.SmartCards.SmartCardCryptogramGeneratorOperationStatus
enum _WDSSmartCardCryptogramGeneratorOperationStatus {
    WDSSmartCardCryptogramGeneratorOperationStatusSuccess = 0,
    WDSSmartCardCryptogramGeneratorOperationStatusAuthorizationFailed = 1,
    WDSSmartCardCryptogramGeneratorOperationStatusAuthorizationCanceled = 2,
    WDSSmartCardCryptogramGeneratorOperationStatusAuthorizationRequired = 3,
    WDSSmartCardCryptogramGeneratorOperationStatusCryptogramMaterialPackageStorageKeyExists = 4,
    WDSSmartCardCryptogramGeneratorOperationStatusNoCryptogramMaterialPackageStorageKey = 5,
    WDSSmartCardCryptogramGeneratorOperationStatusNoCryptogramMaterialPackage = 6,
    WDSSmartCardCryptogramGeneratorOperationStatusUnsupportedCryptogramMaterialPackage = 7,
    WDSSmartCardCryptogramGeneratorOperationStatusUnknownCryptogramMaterialName = 8,
    WDSSmartCardCryptogramGeneratorOperationStatusInvalidCryptogramMaterialUsage = 9,
    WDSSmartCardCryptogramGeneratorOperationStatusApduResponseNotSent = 10,
    WDSSmartCardCryptogramGeneratorOperationStatusOtherError = 11,
};
typedef unsigned WDSSmartCardCryptogramGeneratorOperationStatus;

// Windows.Devices.SmartCards.SmartCardCryptographicKeyAttestationStatus
enum _WDSSmartCardCryptographicKeyAttestationStatus {
    WDSSmartCardCryptographicKeyAttestationStatusNoAttestation = 0,
    WDSSmartCardCryptographicKeyAttestationStatusSoftwareKeyWithoutTpm = 1,
    WDSSmartCardCryptographicKeyAttestationStatusSoftwareKeyWithTpm = 2,
    WDSSmartCardCryptographicKeyAttestationStatusTpmKeyUnknownAttestationStatus = 3,
    WDSSmartCardCryptographicKeyAttestationStatusTpmKeyWithoutAttestationCapability = 4,
    WDSSmartCardCryptographicKeyAttestationStatusTpmKeyWithTemporaryAttestationFailure = 5,
    WDSSmartCardCryptographicKeyAttestationStatusTpmKeyWithLongTermAttestationFailure = 6,
    WDSSmartCardCryptographicKeyAttestationStatusTpmKeyWithAttestation = 7,
};
typedef unsigned WDSSmartCardCryptographicKeyAttestationStatus;

// Windows.Devices.SmartCards.SmartCardReaderKind
enum _WDSSmartCardReaderKind {
    WDSSmartCardReaderKindAny = 0,
    WDSSmartCardReaderKindGeneric = 1,
    WDSSmartCardReaderKindTpm = 2,
    WDSSmartCardReaderKindNfc = 3,
    WDSSmartCardReaderKindUicc = 4,
    WDSSmartCardReaderKindEmbeddedSE = 5,
};
typedef unsigned WDSSmartCardReaderKind;

// Windows.Devices.SmartCards.SmartCardReaderStatus
enum _WDSSmartCardReaderStatus {
    WDSSmartCardReaderStatusDisconnected = 0,
    WDSSmartCardReaderStatusReady = 1,
    WDSSmartCardReaderStatusExclusive = 2,
};
typedef unsigned WDSSmartCardReaderStatus;

// Windows.Devices.SmartCards.SmartCardStatus
enum _WDSSmartCardStatus {
    WDSSmartCardStatusDisconnected = 0,
    WDSSmartCardStatusReady = 1,
    WDSSmartCardStatusShared = 2,
    WDSSmartCardStatusExclusive = 3,
    WDSSmartCardStatusUnresponsive = 4,
};
typedef unsigned WDSSmartCardStatus;

// Windows.Devices.SmartCards.SmartCardPinCharacterPolicyOption
enum _WDSSmartCardPinCharacterPolicyOption {
    WDSSmartCardPinCharacterPolicyOptionAllow = 0,
    WDSSmartCardPinCharacterPolicyOptionRequireAtLeastOne = 1,
    WDSSmartCardPinCharacterPolicyOptionDisallow = 2,
};
typedef unsigned WDSSmartCardPinCharacterPolicyOption;

#include "WindowsSecurityCryptographyCore.h"
#include "WindowsFoundation.h"
#include "WindowsStorageStreams.h"
// Windows.Devices.SmartCards.SmartCardPinResetHandler
#ifndef __WDSSmartCardPinResetHandler__DEFINED
#define __WDSSmartCardPinResetHandler__DEFINED
typedef void(^WDSSmartCardPinResetHandler)(WDSSmartCardProvisioning* sender, WDSSmartCardPinResetRequest* request);
#endif // __WDSSmartCardPinResetHandler__DEFINED


#import <Foundation/Foundation.h>

// Windows.Devices.SmartCards.SmartCardPinResetHandler
#ifndef __WDSSmartCardPinResetHandler__DEFINED
#define __WDSSmartCardPinResetHandler__DEFINED
typedef void(^WDSSmartCardPinResetHandler)(WDSSmartCardProvisioning* sender, WDSSmartCardPinResetRequest* request);
#endif // __WDSSmartCardPinResetHandler__DEFINED

// Windows.Devices.SmartCards.SmartCardTriggerDetails
#ifndef __WDSSmartCardTriggerDetails_DEFINED__
#define __WDSSmartCardTriggerDetails_DEFINED__

OBJCUWP_WINDOWS_DEVICES_SMARTCARDS_EXPORT
@interface WDSSmartCardTriggerDetails : RTObject
#if defined(__cplusplus)
+ (instancetype)createWith:(IInspectable*)obj __attribute__ ((ns_returns_autoreleased));
#endif
@property (readonly) RTObject<WSSIBuffer>* sourceAppletId;
@property (readonly) RTObject<WSSIBuffer>* triggerData;
@property (readonly) WDSSmartCardTriggerType triggerType;
@property (readonly) WDSSmartCardEmulator* emulator;
- (void)tryLaunchCurrentAppAsync:(NSString *)arguments success:(void (^)(BOOL))success failure:(void (^)(NSError*))failure;
- (void)tryLaunchCurrentAppWithBehaviorAsync:(NSString *)arguments behavior:(WDSSmartCardLaunchBehavior)behavior success:(void (^)(BOOL))success failure:(void (^)(NSError*))failure;
@end

#endif // __WDSSmartCardTriggerDetails_DEFINED__

// Windows.Devices.SmartCards.SmartCardEmulator
#ifndef __WDSSmartCardEmulator_DEFINED__
#define __WDSSmartCardEmulator_DEFINED__

OBJCUWP_WINDOWS_DEVICES_SMARTCARDS_EXPORT
@interface WDSSmartCardEmulator : RTObject
+ (void)getAppletIdGroupRegistrationsAsyncWithSuccess:(void (^)(NSArray* /* WDSSmartCardAppletIdGroupRegistration* */))success failure:(void (^)(NSError*))failure;
+ (void)registerAppletIdGroupAsync:(WDSSmartCardAppletIdGroup*)appletIdGroup success:(void (^)(WDSSmartCardAppletIdGroupRegistration*))success failure:(void (^)(NSError*))failure;
+ (RTObject<WFIAsyncAction>*)unregisterAppletIdGroupAsync:(WDSSmartCardAppletIdGroupRegistration*)registration;
+ (void)getDefaultAsyncWithSuccess:(void (^)(WDSSmartCardEmulator*))success failure:(void (^)(NSError*))failure;
#if defined(__cplusplus)
+ (instancetype)createWith:(IInspectable*)obj __attribute__ ((ns_returns_autoreleased));
#endif
@property (readonly) WDSSmartCardEmulatorEnablementPolicy enablementPolicy;
+ (unsigned short)maxAppletIdGroupRegistrations;
- (EventRegistrationToken)addApduReceivedEvent:(void(^)(WDSSmartCardEmulator*, WDSSmartCardEmulatorApduReceivedEventArgs*))del;
- (void)removeApduReceivedEvent:(EventRegistrationToken)tok;
- (EventRegistrationToken)addConnectionDeactivatedEvent:(void(^)(WDSSmartCardEmulator*, WDSSmartCardEmulatorConnectionDeactivatedEventArgs*))del;
- (void)removeConnectionDeactivatedEvent:(EventRegistrationToken)tok;
- (void)start;
- (BOOL)isHostCardEmulationSupported;
@end

#endif // __WDSSmartCardEmulator_DEFINED__

// Windows.Devices.SmartCards.SmartCardAppletIdGroupRegistration
#ifndef __WDSSmartCardAppletIdGroupRegistration_DEFINED__
#define __WDSSmartCardAppletIdGroupRegistration_DEFINED__

OBJCUWP_WINDOWS_DEVICES_SMARTCARDS_EXPORT
@interface WDSSmartCardAppletIdGroupRegistration : RTObject
#if defined(__cplusplus)
+ (instancetype)createWith:(IInspectable*)obj __attribute__ ((ns_returns_autoreleased));
#endif
@property (readonly) WDSSmartCardAppletIdGroupActivationPolicy activationPolicy;
@property (readonly) WDSSmartCardAppletIdGroup* appletIdGroup;
@property (readonly) WFGUID* id;
- (void)requestActivationPolicyChangeAsync:(WDSSmartCardAppletIdGroupActivationPolicy)policy success:(void (^)(WDSSmartCardActivationPolicyChangeResult))success failure:(void (^)(NSError*))failure;
- (RTObject<WFIAsyncAction>*)setAutomaticResponseApdusAsync:(id<NSFastEnumeration> /* WDSSmartCardAutomaticResponseApdu* */)apdus;
@end

#endif // __WDSSmartCardAppletIdGroupRegistration_DEFINED__

// Windows.Devices.SmartCards.SmartCardAppletIdGroup
#ifndef __WDSSmartCardAppletIdGroup_DEFINED__
#define __WDSSmartCardAppletIdGroup_DEFINED__

OBJCUWP_WINDOWS_DEVICES_SMARTCARDS_EXPORT
@interface WDSSmartCardAppletIdGroup : RTObject
+ (instancetype)make __attribute__ ((ns_returns_retained));
+ (WDSSmartCardAppletIdGroup*)make:(NSString *)displayName appletIds:(NSMutableArray* /* RTObject<WSSIBuffer>* */)appletIds emulationCategory:(WDSSmartCardEmulationCategory)emulationCategory emulationType:(WDSSmartCardEmulationType)emulationType ACTIVATOR;
#if defined(__cplusplus)
+ (instancetype)createWith:(IInspectable*)obj __attribute__ ((ns_returns_autoreleased));
#endif
@property WDSSmartCardEmulationType smartCardEmulationType;
@property WDSSmartCardEmulationCategory smartCardEmulationCategory;
@property (retain) NSString * displayName;
@property BOOL automaticEnablement;
@property (readonly) NSMutableArray* /* RTObject<WSSIBuffer>* */ appletIds;
+ (unsigned short)maxAppletIds;
@end

#endif // __WDSSmartCardAppletIdGroup_DEFINED__

// Windows.Devices.SmartCards.SmartCardEmulatorApduReceivedEventArgs
#ifndef __WDSSmartCardEmulatorApduReceivedEventArgs_DEFINED__
#define __WDSSmartCardEmulatorApduReceivedEventArgs_DEFINED__

OBJCUWP_WINDOWS_DEVICES_SMARTCARDS_EXPORT
@interface WDSSmartCardEmulatorApduReceivedEventArgs : RTObject
#if defined(__cplusplus)
+ (instancetype)createWith:(IInspectable*)obj __attribute__ ((ns_returns_autoreleased));
#endif
@property (readonly) WDSSmartCardAutomaticResponseStatus automaticResponseStatus;
@property (readonly) RTObject<WSSIBuffer>* commandApdu;
@property (readonly) WDSSmartCardEmulatorConnectionProperties* connectionProperties;
@property (readonly) unsigned int state;
- (void)tryRespondAsync:(RTObject<WSSIBuffer>*)responseApdu success:(void (^)(BOOL))success failure:(void (^)(NSError*))failure;
- (void)tryRespondWithCryptogramsAsync:(RTObject<WSSIBuffer>*)responseTemplate cryptogramPlacementSteps:(id<NSFastEnumeration> /* WDSSmartCardCryptogramPlacementStep* */)cryptogramPlacementSteps success:(void (^)(WDSSmartCardCryptogramGeneratorOperationStatus))success failure:(void (^)(NSError*))failure;
- (void)tryRespondWithCryptogramsAndStateAsync:(RTObject<WSSIBuffer>*)responseTemplate cryptogramPlacementSteps:(id<NSFastEnumeration> /* WDSSmartCardCryptogramPlacementStep* */)cryptogramPlacementSteps nextState:(id /* unsigned int */)nextState success:(void (^)(WDSSmartCardCryptogramGeneratorOperationStatus))success failure:(void (^)(NSError*))failure;
- (void)tryRespondWithStateAsync:(RTObject<WSSIBuffer>*)responseApdu nextState:(id /* unsigned int */)nextState success:(void (^)(BOOL))success failure:(void (^)(NSError*))failure;
@end

#endif // __WDSSmartCardEmulatorApduReceivedEventArgs_DEFINED__

// Windows.Devices.SmartCards.SmartCardEmulatorConnectionDeactivatedEventArgs
#ifndef __WDSSmartCardEmulatorConnectionDeactivatedEventArgs_DEFINED__
#define __WDSSmartCardEmulatorConnectionDeactivatedEventArgs_DEFINED__

OBJCUWP_WINDOWS_DEVICES_SMARTCARDS_EXPORT
@interface WDSSmartCardEmulatorConnectionDeactivatedEventArgs : RTObject
#if defined(__cplusplus)
+ (instancetype)createWith:(IInspectable*)obj __attribute__ ((ns_returns_autoreleased));
#endif
@property (readonly) WDSSmartCardEmulatorConnectionProperties* connectionProperties;
@property (readonly) WDSSmartCardEmulatorConnectionDeactivatedReason reason;
@end

#endif // __WDSSmartCardEmulatorConnectionDeactivatedEventArgs_DEFINED__

// Windows.Devices.SmartCards.SmartCardEmulatorConnectionProperties
#ifndef __WDSSmartCardEmulatorConnectionProperties_DEFINED__
#define __WDSSmartCardEmulatorConnectionProperties_DEFINED__

OBJCUWP_WINDOWS_DEVICES_SMARTCARDS_EXPORT
@interface WDSSmartCardEmulatorConnectionProperties : RTObject
#if defined(__cplusplus)
+ (instancetype)createWith:(IInspectable*)obj __attribute__ ((ns_returns_autoreleased));
#endif
@property (readonly) WFGUID* id;
@property (readonly) WDSSmartCardEmulatorConnectionSource source;
@end

#endif // __WDSSmartCardEmulatorConnectionProperties_DEFINED__

// Windows.Devices.SmartCards.SmartCardAutomaticResponseApdu
#ifndef __WDSSmartCardAutomaticResponseApdu_DEFINED__
#define __WDSSmartCardAutomaticResponseApdu_DEFINED__

OBJCUWP_WINDOWS_DEVICES_SMARTCARDS_EXPORT
@interface WDSSmartCardAutomaticResponseApdu : RTObject
+ (WDSSmartCardAutomaticResponseApdu*)make:(RTObject<WSSIBuffer>*)commandApdu responseApdu:(RTObject<WSSIBuffer>*)responseApdu ACTIVATOR;
#if defined(__cplusplus)
+ (instancetype)createWith:(IInspectable*)obj __attribute__ ((ns_returns_autoreleased));
#endif
@property BOOL shouldMatchLength;
@property (retain) RTObject<WSSIBuffer>* responseApdu;
@property (retain) RTObject<WSSIBuffer>* commandApduBitMask;
@property (retain) RTObject<WSSIBuffer>* commandApdu;
@property (retain) RTObject<WSSIBuffer>* appletId;
@property (retain) id /* unsigned int */ outputState;
@property (retain) id /* unsigned int */ inputState;
@property BOOL allowWhenCryptogramGeneratorNotPrepared;
@end

#endif // __WDSSmartCardAutomaticResponseApdu_DEFINED__

// Windows.Devices.SmartCards.SmartCardCryptogramPlacementStep
#ifndef __WDSSmartCardCryptogramPlacementStep_DEFINED__
#define __WDSSmartCardCryptogramPlacementStep_DEFINED__

OBJCUWP_WINDOWS_DEVICES_SMARTCARDS_EXPORT
@interface WDSSmartCardCryptogramPlacementStep : RTObject
+ (instancetype)make __attribute__ ((ns_returns_retained));
#if defined(__cplusplus)
+ (instancetype)createWith:(IInspectable*)obj __attribute__ ((ns_returns_autoreleased));
#endif
@property int templateOffset;
@property (retain) RTObject<WSSIBuffer>* sourceData;
@property WDSSmartCardCryptogramPlacementOptions cryptogramPlacementOptions;
@property int cryptogramOffset;
@property (retain) NSString * cryptogramMaterialPackageName;
@property (retain) NSString * cryptogramMaterialName;
@property int cryptogramLength;
@property (retain) WDSSmartCardCryptogramPlacementStep* chainedOutputStep;
@property WDSSmartCardCryptogramAlgorithm algorithm;
@end

#endif // __WDSSmartCardCryptogramPlacementStep_DEFINED__

// Windows.Devices.SmartCards.SmartCardCryptogramGenerator
#ifndef __WDSSmartCardCryptogramGenerator_DEFINED__
#define __WDSSmartCardCryptogramGenerator_DEFINED__

OBJCUWP_WINDOWS_DEVICES_SMARTCARDS_EXPORT
@interface WDSSmartCardCryptogramGenerator : RTObject
+ (void)getSmartCardCryptogramGeneratorAsyncWithSuccess:(void (^)(WDSSmartCardCryptogramGenerator*))success failure:(void (^)(NSError*))failure;
#if defined(__cplusplus)
+ (instancetype)createWith:(IInspectable*)obj __attribute__ ((ns_returns_autoreleased));
#endif
@property (readonly) NSArray* /* WDSSmartCardCryptogramAlgorithm */ supportedCryptogramAlgorithms;
@property (readonly) NSArray* /* WDSSmartCardCryptogramMaterialPackageConfirmationResponseFormat */ supportedCryptogramMaterialPackageConfirmationResponseFormats;
@property (readonly) NSArray* /* WDSSmartCardCryptogramMaterialPackageFormat */ supportedCryptogramMaterialPackageFormats;
@property (readonly) NSArray* /* WDSSmartCardCryptogramMaterialType */ supportedCryptogramMaterialTypes;
@property (readonly) NSArray* /* WDSSmartCardCryptogramStorageKeyCapabilities */ supportedSmartCardCryptogramStorageKeyCapabilities;
- (void)deleteCryptogramMaterialStorageKeyAsync:(NSString *)storageKeyName success:(void (^)(WDSSmartCardCryptogramGeneratorOperationStatus))success failure:(void (^)(NSError*))failure;
- (void)createCryptogramMaterialStorageKeyAsync:(WDSSmartCardUnlockPromptingBehavior)promptingBehavior storageKeyName:(NSString *)storageKeyName algorithm:(WDSSmartCardCryptogramStorageKeyAlgorithm)algorithm capabilities:(WDSSmartCardCryptogramStorageKeyCapabilities)capabilities success:(void (^)(WDSSmartCardCryptogramGeneratorOperationStatus))success failure:(void (^)(NSError*))failure;
- (void)requestCryptogramMaterialStorageKeyInfoAsync:(WDSSmartCardUnlockPromptingBehavior)promptingBehavior storageKeyName:(NSString *)storageKeyName format:(WSCCCryptographicPublicKeyBlobType)format success:(void (^)(WDSSmartCardCryptogramStorageKeyInfo*))success failure:(void (^)(NSError*))failure;
- (void)importCryptogramMaterialPackageAsync:(WDSSmartCardCryptogramMaterialPackageFormat)format storageKeyName:(NSString *)storageKeyName materialPackageName:(NSString *)materialPackageName cryptogramMaterialPackage:(RTObject<WSSIBuffer>*)cryptogramMaterialPackage success:(void (^)(WDSSmartCardCryptogramGeneratorOperationStatus))success failure:(void (^)(NSError*))failure;
- (void)tryProvePossessionOfCryptogramMaterialPackageAsync:(WDSSmartCardUnlockPromptingBehavior)promptingBehavior responseFormat:(WDSSmartCardCryptogramMaterialPackageConfirmationResponseFormat)responseFormat materialPackageName:(NSString *)materialPackageName materialName:(NSString *)materialName challenge:(RTObject<WSSIBuffer>*)challenge success:(void (^)(WDSSmartCardCryptogramMaterialPossessionProof*))success failure:(void (^)(NSError*))failure;
- (void)requestUnlockCryptogramMaterialForUseAsync:(WDSSmartCardUnlockPromptingBehavior)promptingBehavior success:(void (^)(WDSSmartCardCryptogramGeneratorOperationStatus))success failure:(void (^)(NSError*))failure;
- (void)deleteCryptogramMaterialPackageAsync:(NSString *)materialPackageName success:(void (^)(WDSSmartCardCryptogramGeneratorOperationStatus))success failure:(void (^)(NSError*))failure;
@end

#endif // __WDSSmartCardCryptogramGenerator_DEFINED__

// Windows.Devices.SmartCards.SmartCardCryptogramStorageKeyInfo
#ifndef __WDSSmartCardCryptogramStorageKeyInfo_DEFINED__
#define __WDSSmartCardCryptogramStorageKeyInfo_DEFINED__

OBJCUWP_WINDOWS_DEVICES_SMARTCARDS_EXPORT
@interface WDSSmartCardCryptogramStorageKeyInfo : RTObject
#if defined(__cplusplus)
+ (instancetype)createWith:(IInspectable*)obj __attribute__ ((ns_returns_autoreleased));
#endif
@property (readonly) RTObject<WSSIBuffer>* attestation;
@property (readonly) RTObject<WSSIBuffer>* attestationCertificateChain;
@property (readonly) WDSSmartCardCryptographicKeyAttestationStatus attestationStatus;
@property (readonly) WDSSmartCardCryptogramStorageKeyCapabilities capabilities;
@property (readonly) WDSSmartCardCryptogramGeneratorOperationStatus operationStatus;
@property (readonly) RTObject<WSSIBuffer>* publicKey;
@property (readonly) WSCCCryptographicPublicKeyBlobType publicKeyBlobType;
@property (readonly) NSString * operationalRequirements;
@end

#endif // __WDSSmartCardCryptogramStorageKeyInfo_DEFINED__

// Windows.Devices.SmartCards.SmartCardCryptogramMaterialPossessionProof
#ifndef __WDSSmartCardCryptogramMaterialPossessionProof_DEFINED__
#define __WDSSmartCardCryptogramMaterialPossessionProof_DEFINED__

OBJCUWP_WINDOWS_DEVICES_SMARTCARDS_EXPORT
@interface WDSSmartCardCryptogramMaterialPossessionProof : RTObject
#if defined(__cplusplus)
+ (instancetype)createWith:(IInspectable*)obj __attribute__ ((ns_returns_autoreleased));
#endif
@property (readonly) WDSSmartCardCryptogramGeneratorOperationStatus operationStatus;
@property (readonly) RTObject<WSSIBuffer>* proof;
@end

#endif // __WDSSmartCardCryptogramMaterialPossessionProof_DEFINED__

// Windows.Devices.SmartCards.SmartCardReader
#ifndef __WDSSmartCardReader_DEFINED__
#define __WDSSmartCardReader_DEFINED__

OBJCUWP_WINDOWS_DEVICES_SMARTCARDS_EXPORT
@interface WDSSmartCardReader : RTObject
+ (NSString *)getDeviceSelector;
+ (NSString *)getDeviceSelectorWithKind:(WDSSmartCardReaderKind)kind;
+ (void)fromIdAsync:(NSString *)deviceId success:(void (^)(WDSSmartCardReader*))success failure:(void (^)(NSError*))failure;
#if defined(__cplusplus)
+ (instancetype)createWith:(IInspectable*)obj __attribute__ ((ns_returns_autoreleased));
#endif
@property (readonly) NSString * deviceId;
@property (readonly) WDSSmartCardReaderKind kind;
@property (readonly) NSString * name;
- (EventRegistrationToken)addCardAddedEvent:(void(^)(WDSSmartCardReader*, WDSCardAddedEventArgs*))del;
- (void)removeCardAddedEvent:(EventRegistrationToken)tok;
- (EventRegistrationToken)addCardRemovedEvent:(void(^)(WDSSmartCardReader*, WDSCardRemovedEventArgs*))del;
- (void)removeCardRemovedEvent:(EventRegistrationToken)tok;
- (void)getStatusAsyncWithSuccess:(void (^)(WDSSmartCardReaderStatus))success failure:(void (^)(NSError*))failure;
- (void)findAllCardsAsyncWithSuccess:(void (^)(NSArray* /* WDSSmartCard* */))success failure:(void (^)(NSError*))failure;
@end

#endif // __WDSSmartCardReader_DEFINED__

// Windows.Devices.SmartCards.SmartCard
#ifndef __WDSSmartCard_DEFINED__
#define __WDSSmartCard_DEFINED__

OBJCUWP_WINDOWS_DEVICES_SMARTCARDS_EXPORT
@interface WDSSmartCard : RTObject
#if defined(__cplusplus)
+ (instancetype)createWith:(IInspectable*)obj __attribute__ ((ns_returns_autoreleased));
#endif
@property (readonly) WDSSmartCardReader* reader;
- (void)getStatusAsyncWithSuccess:(void (^)(WDSSmartCardStatus))success failure:(void (^)(NSError*))failure;
- (void)getAnswerToResetAsyncWithSuccess:(void (^)(RTObject<WSSIBuffer>*))success failure:(void (^)(NSError*))failure;
- (void)connectAsyncWithSuccess:(void (^)(WDSSmartCardConnection*))success failure:(void (^)(NSError*))failure;
@end

#endif // __WDSSmartCard_DEFINED__

// Windows.Devices.SmartCards.CardAddedEventArgs
#ifndef __WDSCardAddedEventArgs_DEFINED__
#define __WDSCardAddedEventArgs_DEFINED__

OBJCUWP_WINDOWS_DEVICES_SMARTCARDS_EXPORT
@interface WDSCardAddedEventArgs : RTObject
#if defined(__cplusplus)
+ (instancetype)createWith:(IInspectable*)obj __attribute__ ((ns_returns_autoreleased));
#endif
@property (readonly) WDSSmartCard* smartCard;
@end

#endif // __WDSCardAddedEventArgs_DEFINED__

// Windows.Devices.SmartCards.CardRemovedEventArgs
#ifndef __WDSCardRemovedEventArgs_DEFINED__
#define __WDSCardRemovedEventArgs_DEFINED__

OBJCUWP_WINDOWS_DEVICES_SMARTCARDS_EXPORT
@interface WDSCardRemovedEventArgs : RTObject
#if defined(__cplusplus)
+ (instancetype)createWith:(IInspectable*)obj __attribute__ ((ns_returns_autoreleased));
#endif
@property (readonly) WDSSmartCard* smartCard;
@end

#endif // __WDSCardRemovedEventArgs_DEFINED__

// Windows.Devices.SmartCards.SmartCardProvisioning
#ifndef __WDSSmartCardProvisioning_DEFINED__
#define __WDSSmartCardProvisioning_DEFINED__

OBJCUWP_WINDOWS_DEVICES_SMARTCARDS_EXPORT
@interface WDSSmartCardProvisioning : RTObject
+ (void)fromSmartCardAsync:(WDSSmartCard*)card success:(void (^)(WDSSmartCardProvisioning*))success failure:(void (^)(NSError*))failure;
+ (void)requestVirtualSmartCardCreationAsync:(NSString *)friendlyName administrativeKey:(RTObject<WSSIBuffer>*)administrativeKey pinPolicy:(WDSSmartCardPinPolicy*)pinPolicy success:(void (^)(WDSSmartCardProvisioning*))success failure:(void (^)(NSError*))failure;
+ (void)requestVirtualSmartCardCreationAsyncWithCardId:(NSString *)friendlyName administrativeKey:(RTObject<WSSIBuffer>*)administrativeKey pinPolicy:(WDSSmartCardPinPolicy*)pinPolicy cardId:(WFGUID*)cardId success:(void (^)(WDSSmartCardProvisioning*))success failure:(void (^)(NSError*))failure;
+ (void)requestVirtualSmartCardDeletionAsync:(WDSSmartCard*)card success:(void (^)(BOOL))success failure:(void (^)(NSError*))failure;
+ (void)requestAttestedVirtualSmartCardCreationAsync:(NSString *)friendlyName administrativeKey:(RTObject<WSSIBuffer>*)administrativeKey pinPolicy:(WDSSmartCardPinPolicy*)pinPolicy success:(void (^)(WDSSmartCardProvisioning*))success failure:(void (^)(NSError*))failure;
+ (void)requestAttestedVirtualSmartCardCreationAsyncWithCardId:(NSString *)friendlyName administrativeKey:(RTObject<WSSIBuffer>*)administrativeKey pinPolicy:(WDSSmartCardPinPolicy*)pinPolicy cardId:(WFGUID*)cardId success:(void (^)(WDSSmartCardProvisioning*))success failure:(void (^)(NSError*))failure;
#if defined(__cplusplus)
+ (instancetype)createWith:(IInspectable*)obj __attribute__ ((ns_returns_autoreleased));
#endif
@property (readonly) WDSSmartCard* smartCard;
- (void)getIdAsyncWithSuccess:(void (^)(WFGUID*))success failure:(void (^)(NSError*))failure;
- (void)getNameAsyncWithSuccess:(void (^)(NSString *))success failure:(void (^)(NSError*))failure;
- (void)getChallengeContextAsyncWithSuccess:(void (^)(WDSSmartCardChallengeContext*))success failure:(void (^)(NSError*))failure;
- (void)requestPinChangeAsyncWithSuccess:(void (^)(BOOL))success failure:(void (^)(NSError*))failure;
- (void)requestPinResetAsync:(WDSSmartCardPinResetHandler)handler success:(void (^)(BOOL))success failure:(void (^)(NSError*))failure;
- (void)getAuthorityKeyContainerNameAsyncWithSuccess:(void (^)(NSString *))success failure:(void (^)(NSError*))failure;
@end

#endif // __WDSSmartCardProvisioning_DEFINED__

// Windows.Devices.SmartCards.SmartCardPinPolicy
#ifndef __WDSSmartCardPinPolicy_DEFINED__
#define __WDSSmartCardPinPolicy_DEFINED__

OBJCUWP_WINDOWS_DEVICES_SMARTCARDS_EXPORT
@interface WDSSmartCardPinPolicy : RTObject
+ (instancetype)make __attribute__ ((ns_returns_retained));
#if defined(__cplusplus)
+ (instancetype)createWith:(IInspectable*)obj __attribute__ ((ns_returns_autoreleased));
#endif
@property WDSSmartCardPinCharacterPolicyOption uppercaseLetters;
@property WDSSmartCardPinCharacterPolicyOption specialCharacters;
@property unsigned int minLength;
@property unsigned int maxLength;
@property WDSSmartCardPinCharacterPolicyOption lowercaseLetters;
@property WDSSmartCardPinCharacterPolicyOption digits;
@end

#endif // __WDSSmartCardPinPolicy_DEFINED__

// Windows.Foundation.IClosable
#ifndef __WFIClosable_DEFINED__
#define __WFIClosable_DEFINED__

@protocol WFIClosable
- (void)close;
@end

OBJCUWP_WINDOWS_DEVICES_SMARTCARDS_EXPORT
@interface WFIClosable : RTObject <WFIClosable>
@end

#endif // __WFIClosable_DEFINED__

// Windows.Devices.SmartCards.SmartCardChallengeContext
#ifndef __WDSSmartCardChallengeContext_DEFINED__
#define __WDSSmartCardChallengeContext_DEFINED__

OBJCUWP_WINDOWS_DEVICES_SMARTCARDS_EXPORT
@interface WDSSmartCardChallengeContext : RTObject <WFIClosable>
#if defined(__cplusplus)
+ (instancetype)createWith:(IInspectable*)obj __attribute__ ((ns_returns_autoreleased));
#endif
@property (readonly) RTObject<WSSIBuffer>* challenge;
- (void)verifyResponseAsync:(RTObject<WSSIBuffer>*)response success:(void (^)(BOOL))success failure:(void (^)(NSError*))failure;
- (RTObject<WFIAsyncAction>*)provisionAsync:(RTObject<WSSIBuffer>*)response formatCard:(BOOL)formatCard;
- (RTObject<WFIAsyncAction>*)provisionAsyncWithNewCardId:(RTObject<WSSIBuffer>*)response formatCard:(BOOL)formatCard newCardId:(WFGUID*)newCardId;
- (RTObject<WFIAsyncAction>*)changeAdministrativeKeyAsync:(RTObject<WSSIBuffer>*)response newAdministrativeKey:(RTObject<WSSIBuffer>*)newAdministrativeKey;
- (void)close;
@end

#endif // __WDSSmartCardChallengeContext_DEFINED__

// Windows.Devices.SmartCards.SmartCardPinResetRequest
#ifndef __WDSSmartCardPinResetRequest_DEFINED__
#define __WDSSmartCardPinResetRequest_DEFINED__

OBJCUWP_WINDOWS_DEVICES_SMARTCARDS_EXPORT
@interface WDSSmartCardPinResetRequest : RTObject
#if defined(__cplusplus)
+ (instancetype)createWith:(IInspectable*)obj __attribute__ ((ns_returns_autoreleased));
#endif
@property (readonly) RTObject<WSSIBuffer>* challenge;
@property (readonly) WFDateTime* deadline;
- (WDSSmartCardPinResetDeferral*)getDeferral;
- (void)setResponse:(RTObject<WSSIBuffer>*)response;
@end

#endif // __WDSSmartCardPinResetRequest_DEFINED__

// Windows.Devices.SmartCards.SmartCardPinResetDeferral
#ifndef __WDSSmartCardPinResetDeferral_DEFINED__
#define __WDSSmartCardPinResetDeferral_DEFINED__

OBJCUWP_WINDOWS_DEVICES_SMARTCARDS_EXPORT
@interface WDSSmartCardPinResetDeferral : RTObject
#if defined(__cplusplus)
+ (instancetype)createWith:(IInspectable*)obj __attribute__ ((ns_returns_autoreleased));
#endif
- (void)complete;
@end

#endif // __WDSSmartCardPinResetDeferral_DEFINED__

// Windows.Devices.SmartCards.SmartCardConnection
#ifndef __WDSSmartCardConnection_DEFINED__
#define __WDSSmartCardConnection_DEFINED__

OBJCUWP_WINDOWS_DEVICES_SMARTCARDS_EXPORT
@interface WDSSmartCardConnection : RTObject <WFIClosable>
#if defined(__cplusplus)
+ (instancetype)createWith:(IInspectable*)obj __attribute__ ((ns_returns_autoreleased));
#endif
- (void)transmitAsync:(RTObject<WSSIBuffer>*)command success:(void (^)(RTObject<WSSIBuffer>*))success failure:(void (^)(NSError*))failure;
- (void)close;
@end

#endif // __WDSSmartCardConnection_DEFINED__

