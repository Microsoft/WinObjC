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

// WindowsSecurityEnterpriseData.h
// Generated from winmd2objc

#pragma once

#ifndef OBJCUWP_WINDOWS_SECURITY_ENTERPRISEDATA_EXPORT
#define OBJCUWP_WINDOWS_SECURITY_ENTERPRISEDATA_EXPORT __declspec(dllimport)
#ifndef IN_OBJCUWP_BUILD
#pragma comment(lib, "ObjCUWP_Windows_Security_EnterpriseData.lib")
#endif
#endif
#include <UWP/interopBase.h>

@class WSEFileProtectionInfo, WSEProtectedContainerExportResult, WSEProtectedContainerImportResult, WSEProtectedFileCreateResult, WSEBufferProtectUnprotectResult, WSEDataProtectionInfo, WSEProtectionPolicyAuditInfo, WSEThreadNetworkContext, WSEProtectionPolicyManager, WSEProtectedAccessSuspendingEventArgs, WSEProtectedAccessResumedEventArgs, WSEProtectedContentRevokedEventArgs, WSEFileRevocationManager, WSEFileProtectionManager, WSEDataProtectionManager;
@protocol WSEIFileRevocationManagerStatics, WSEIFileProtectionManagerStatics, WSEIFileProtectionManagerStatics2, WSEIProtectedFileCreateResult, WSEIFileProtectionInfo, WSEIProtectedContainerExportResult, WSEIProtectedContainerImportResult, WSEIDataProtectionManagerStatics, WSEIDataProtectionInfo, WSEIBufferProtectUnprotectResult, WSEIProtectionPolicyAuditInfoFactory, WSEIProtectionPolicyAuditInfo, WSEIProtectionPolicyManager, WSEIProtectionPolicyManager2, WSEIProtectionPolicyManagerStatics, WSEIProtectionPolicyManagerStatics2, WSEIProtectionPolicyManagerStatics3, WSEIThreadNetworkContext, WSEIProtectedAccessSuspendingEventArgs, WSEIProtectedAccessResumedEventArgs, WSEIProtectedContentRevokedEventArgs;

// Windows.Security.EnterpriseData.ProtectionPolicyEvaluationResult
enum _WSEProtectionPolicyEvaluationResult {
    WSEProtectionPolicyEvaluationResultAllowed = 0,
    WSEProtectionPolicyEvaluationResultBlocked = 1,
    WSEProtectionPolicyEvaluationResultConsentRequired = 2,
};
typedef unsigned WSEProtectionPolicyEvaluationResult;

// Windows.Security.EnterpriseData.FileProtectionStatus
enum _WSEFileProtectionStatus {
    WSEFileProtectionStatusUndetermined = 0,
    WSEFileProtectionStatusUnknown = 0,
    WSEFileProtectionStatusUnprotected = 1,
    WSEFileProtectionStatusRevoked = 2,
    WSEFileProtectionStatusProtected = 3,
    WSEFileProtectionStatusProtectedByOtherUser = 4,
    WSEFileProtectionStatusProtectedToOtherEnterprise = 5,
    WSEFileProtectionStatusNotProtectable = 6,
    WSEFileProtectionStatusProtectedToOtherIdentity = 7,
    WSEFileProtectionStatusLicenseExpired = 8,
    WSEFileProtectionStatusAccessSuspended = 9,
    WSEFileProtectionStatusFileInUse = 10,
};
typedef unsigned WSEFileProtectionStatus;

// Windows.Security.EnterpriseData.ProtectedImportExportStatus
enum _WSEProtectedImportExportStatus {
    WSEProtectedImportExportStatusOk = 0,
    WSEProtectedImportExportStatusUndetermined = 1,
    WSEProtectedImportExportStatusUnprotected = 2,
    WSEProtectedImportExportStatusRevoked = 3,
    WSEProtectedImportExportStatusNotRoamable = 4,
    WSEProtectedImportExportStatusProtectedToOtherIdentity = 5,
    WSEProtectedImportExportStatusLicenseExpired = 6,
    WSEProtectedImportExportStatusAccessSuspended = 7,
};
typedef unsigned WSEProtectedImportExportStatus;

// Windows.Security.EnterpriseData.DataProtectionStatus
enum _WSEDataProtectionStatus {
    WSEDataProtectionStatusProtectedToOtherIdentity = 0,
    WSEDataProtectionStatusProtected = 1,
    WSEDataProtectionStatusRevoked = 2,
    WSEDataProtectionStatusUnprotected = 3,
    WSEDataProtectionStatusLicenseExpired = 4,
    WSEDataProtectionStatusAccessSuspended = 5,
};
typedef unsigned WSEDataProtectionStatus;

// Windows.Security.EnterpriseData.ProtectionPolicyAuditAction
enum _WSEProtectionPolicyAuditAction {
    WSEProtectionPolicyAuditActionDecrypt = 0,
    WSEProtectionPolicyAuditActionCopyToLocation = 1,
    WSEProtectionPolicyAuditActionSendToRecipient = 2,
    WSEProtectionPolicyAuditActionOther = 3,
};
typedef unsigned WSEProtectionPolicyAuditAction;

// Windows.Security.EnterpriseData.ProtectionPolicyRequestAccessBehavior
enum _WSEProtectionPolicyRequestAccessBehavior {
    WSEProtectionPolicyRequestAccessBehaviorDecrypt = 0,
    WSEProtectionPolicyRequestAccessBehaviorTreatOverridePolicyAsBlock = 1,
};
typedef unsigned WSEProtectionPolicyRequestAccessBehavior;

// Windows.Security.EnterpriseData.EnforcementLevel
enum _WSEEnforcementLevel {
    WSEEnforcementLevelNoProtection = 0,
    WSEEnforcementLevelSilent = 1,
    WSEEnforcementLevelOverride = 2,
    WSEEnforcementLevelBlock = 3,
};
typedef unsigned WSEEnforcementLevel;

#include "WindowsStorage.h"
#include "WindowsStorageStreams.h"
#include "WindowsNetworking.h"
#include "WindowsFoundation.h"

#import <Foundation/Foundation.h>

// Windows.Security.EnterpriseData.FileProtectionInfo
#ifndef __WSEFileProtectionInfo_DEFINED__
#define __WSEFileProtectionInfo_DEFINED__

OBJCUWP_WINDOWS_SECURITY_ENTERPRISEDATA_EXPORT
@interface WSEFileProtectionInfo : RTObject
#if defined(__cplusplus)
+ (instancetype)createWith:(IInspectable*)obj __attribute__ ((ns_returns_autoreleased));
#endif
@property (readonly) NSString * identity;
@property (readonly) BOOL isRoamable;
@property (readonly) WSEFileProtectionStatus status;
@end

#endif // __WSEFileProtectionInfo_DEFINED__

// Windows.Security.EnterpriseData.ProtectedContainerExportResult
#ifndef __WSEProtectedContainerExportResult_DEFINED__
#define __WSEProtectedContainerExportResult_DEFINED__

OBJCUWP_WINDOWS_SECURITY_ENTERPRISEDATA_EXPORT
@interface WSEProtectedContainerExportResult : RTObject
#if defined(__cplusplus)
+ (instancetype)createWith:(IInspectable*)obj __attribute__ ((ns_returns_autoreleased));
#endif
@property (readonly) WSStorageFile* file;
@property (readonly) WSEProtectedImportExportStatus status;
@end

#endif // __WSEProtectedContainerExportResult_DEFINED__

// Windows.Security.EnterpriseData.ProtectedContainerImportResult
#ifndef __WSEProtectedContainerImportResult_DEFINED__
#define __WSEProtectedContainerImportResult_DEFINED__

OBJCUWP_WINDOWS_SECURITY_ENTERPRISEDATA_EXPORT
@interface WSEProtectedContainerImportResult : RTObject
#if defined(__cplusplus)
+ (instancetype)createWith:(IInspectable*)obj __attribute__ ((ns_returns_autoreleased));
#endif
@property (readonly) WSStorageFile* file;
@property (readonly) WSEProtectedImportExportStatus status;
@end

#endif // __WSEProtectedContainerImportResult_DEFINED__

// Windows.Security.EnterpriseData.ProtectedFileCreateResult
#ifndef __WSEProtectedFileCreateResult_DEFINED__
#define __WSEProtectedFileCreateResult_DEFINED__

OBJCUWP_WINDOWS_SECURITY_ENTERPRISEDATA_EXPORT
@interface WSEProtectedFileCreateResult : RTObject
#if defined(__cplusplus)
+ (instancetype)createWith:(IInspectable*)obj __attribute__ ((ns_returns_autoreleased));
#endif
@property (readonly) WSStorageFile* file;
@property (readonly) WSEFileProtectionInfo* protectionInfo;
@property (readonly) RTObject<WSSIRandomAccessStream>* stream;
@end

#endif // __WSEProtectedFileCreateResult_DEFINED__

// Windows.Security.EnterpriseData.BufferProtectUnprotectResult
#ifndef __WSEBufferProtectUnprotectResult_DEFINED__
#define __WSEBufferProtectUnprotectResult_DEFINED__

OBJCUWP_WINDOWS_SECURITY_ENTERPRISEDATA_EXPORT
@interface WSEBufferProtectUnprotectResult : RTObject
#if defined(__cplusplus)
+ (instancetype)createWith:(IInspectable*)obj __attribute__ ((ns_returns_autoreleased));
#endif
@property (readonly) RTObject<WSSIBuffer>* buffer;
@property (readonly) WSEDataProtectionInfo* protectionInfo;
@end

#endif // __WSEBufferProtectUnprotectResult_DEFINED__

// Windows.Security.EnterpriseData.DataProtectionInfo
#ifndef __WSEDataProtectionInfo_DEFINED__
#define __WSEDataProtectionInfo_DEFINED__

OBJCUWP_WINDOWS_SECURITY_ENTERPRISEDATA_EXPORT
@interface WSEDataProtectionInfo : RTObject
#if defined(__cplusplus)
+ (instancetype)createWith:(IInspectable*)obj __attribute__ ((ns_returns_autoreleased));
#endif
@property (readonly) NSString * identity;
@property (readonly) WSEDataProtectionStatus status;
@end

#endif // __WSEDataProtectionInfo_DEFINED__

// Windows.Security.EnterpriseData.ProtectionPolicyAuditInfo
#ifndef __WSEProtectionPolicyAuditInfo_DEFINED__
#define __WSEProtectionPolicyAuditInfo_DEFINED__

OBJCUWP_WINDOWS_SECURITY_ENTERPRISEDATA_EXPORT
@interface WSEProtectionPolicyAuditInfo : RTObject
+ (WSEProtectionPolicyAuditInfo*)make:(WSEProtectionPolicyAuditAction)action dataDescription:(NSString *)dataDescription sourceDescription:(NSString *)sourceDescription targetDescription:(NSString *)targetDescription ACTIVATOR;
+ (WSEProtectionPolicyAuditInfo*)makeWithActionAndDataDescription:(WSEProtectionPolicyAuditAction)action dataDescription:(NSString *)dataDescription ACTIVATOR;
#if defined(__cplusplus)
+ (instancetype)createWith:(IInspectable*)obj __attribute__ ((ns_returns_autoreleased));
#endif
@property (retain) NSString * targetDescription;
@property (retain) NSString * sourceDescription;
@property (retain) NSString * dataDescription;
@property WSEProtectionPolicyAuditAction action;
@end

#endif // __WSEProtectionPolicyAuditInfo_DEFINED__

// Windows.Foundation.IClosable
#ifndef __WFIClosable_DEFINED__
#define __WFIClosable_DEFINED__

@protocol WFIClosable
- (void)close;
@end

OBJCUWP_WINDOWS_SECURITY_ENTERPRISEDATA_EXPORT
@interface WFIClosable : RTObject <WFIClosable>
@end

#endif // __WFIClosable_DEFINED__

// Windows.Security.EnterpriseData.ThreadNetworkContext
#ifndef __WSEThreadNetworkContext_DEFINED__
#define __WSEThreadNetworkContext_DEFINED__

OBJCUWP_WINDOWS_SECURITY_ENTERPRISEDATA_EXPORT
@interface WSEThreadNetworkContext : RTObject <WFIClosable>
#if defined(__cplusplus)
+ (instancetype)createWith:(IInspectable*)obj __attribute__ ((ns_returns_autoreleased));
#endif
- (void)close;
@end

#endif // __WSEThreadNetworkContext_DEFINED__

// Windows.Security.EnterpriseData.ProtectionPolicyManager
#ifndef __WSEProtectionPolicyManager_DEFINED__
#define __WSEProtectionPolicyManager_DEFINED__

OBJCUWP_WINDOWS_SECURITY_ENTERPRISEDATA_EXPORT
@interface WSEProtectionPolicyManager : RTObject
+ (BOOL)isIdentityManaged:(NSString *)identity;
+ (BOOL)tryApplyProcessUIPolicy:(NSString *)identity;
+ (void)clearProcessUIPolicy;
+ (WSEThreadNetworkContext*)createCurrentThreadNetworkContext:(NSString *)identity;
+ (void)getPrimaryManagedIdentityForNetworkEndpointAsync:(WNHostName*)endpointHost success:(void (^)(NSString *))success failure:(void (^)(NSError*))failure;
+ (void)revokeContent:(NSString *)identity;
+ (WSEProtectionPolicyManager*)getForCurrentView;
+ (WSEProtectionPolicyEvaluationResult)checkAccess:(NSString *)sourceIdentity targetIdentity:(NSString *)targetIdentity;
+ (void)requestAccessAsync:(NSString *)sourceIdentity targetIdentity:(NSString *)targetIdentity success:(void (^)(WSEProtectionPolicyEvaluationResult))success failure:(void (^)(NSError*))failure;
+ (BOOL)hasContentBeenRevokedSince:(NSString *)identity since:(WFDateTime*)since;
+ (WSEProtectionPolicyEvaluationResult)checkAccessForApp:(NSString *)sourceIdentity appPackageFamilyName:(NSString *)appPackageFamilyName;
+ (void)requestAccessForAppAsync:(NSString *)sourceIdentity appPackageFamilyName:(NSString *)appPackageFamilyName success:(void (^)(WSEProtectionPolicyEvaluationResult))success failure:(void (^)(NSError*))failure;
+ (WSEEnforcementLevel)getEnforcementLevel:(NSString *)identity;
+ (BOOL)isUserDecryptionAllowed:(NSString *)identity;
+ (BOOL)isProtectionUnderLockRequired:(NSString *)identity;
+ (void)requestAccessWithAuditingInfoAsync:(NSString *)sourceIdentity targetIdentity:(NSString *)targetIdentity auditInfo:(WSEProtectionPolicyAuditInfo*)auditInfo success:(void (^)(WSEProtectionPolicyEvaluationResult))success failure:(void (^)(NSError*))failure;
+ (void)requestAccessWithMessageAsync:(NSString *)sourceIdentity targetIdentity:(NSString *)targetIdentity auditInfo:(WSEProtectionPolicyAuditInfo*)auditInfo messageFromApp:(NSString *)messageFromApp success:(void (^)(WSEProtectionPolicyEvaluationResult))success failure:(void (^)(NSError*))failure;
+ (void)requestAccessForAppWithAuditingInfoAsync:(NSString *)sourceIdentity appPackageFamilyName:(NSString *)appPackageFamilyName auditInfo:(WSEProtectionPolicyAuditInfo*)auditInfo success:(void (^)(WSEProtectionPolicyEvaluationResult))success failure:(void (^)(NSError*))failure;
+ (void)requestAccessForAppWithMessageAsync:(NSString *)sourceIdentity appPackageFamilyName:(NSString *)appPackageFamilyName auditInfo:(WSEProtectionPolicyAuditInfo*)auditInfo messageFromApp:(NSString *)messageFromApp success:(void (^)(WSEProtectionPolicyEvaluationResult))success failure:(void (^)(NSError*))failure;
+ (void)logAuditEvent:(NSString *)sourceIdentity targetIdentity:(NSString *)targetIdentity auditInfo:(WSEProtectionPolicyAuditInfo*)auditInfo;
#if defined(__cplusplus)
+ (instancetype)createWith:(IInspectable*)obj __attribute__ ((ns_returns_autoreleased));
#endif
@property (retain) NSString * identity;
@property BOOL showEnterpriseIndicator;
+ (BOOL)isProtectionEnabled;
+ (EventRegistrationToken)addPolicyChangedEvent:(void(^)(RTObject*, RTObject*))del;
+ (void)removePolicyChangedEvent:(EventRegistrationToken)tok;
+ (EventRegistrationToken)addProtectedAccessResumedEvent:(void(^)(RTObject*, WSEProtectedAccessResumedEventArgs*))del;
+ (void)removeProtectedAccessResumedEvent:(EventRegistrationToken)tok;
+ (EventRegistrationToken)addProtectedAccessSuspendingEvent:(void(^)(RTObject*, WSEProtectedAccessSuspendingEventArgs*))del;
+ (void)removeProtectedAccessSuspendingEvent:(EventRegistrationToken)tok;
+ (EventRegistrationToken)addProtectedContentRevokedEvent:(void(^)(RTObject*, WSEProtectedContentRevokedEventArgs*))del;
+ (void)removeProtectedContentRevokedEvent:(EventRegistrationToken)tok;
@end

#endif // __WSEProtectionPolicyManager_DEFINED__

// Windows.Security.EnterpriseData.ProtectedAccessSuspendingEventArgs
#ifndef __WSEProtectedAccessSuspendingEventArgs_DEFINED__
#define __WSEProtectedAccessSuspendingEventArgs_DEFINED__

OBJCUWP_WINDOWS_SECURITY_ENTERPRISEDATA_EXPORT
@interface WSEProtectedAccessSuspendingEventArgs : RTObject
#if defined(__cplusplus)
+ (instancetype)createWith:(IInspectable*)obj __attribute__ ((ns_returns_autoreleased));
#endif
@property (readonly) WFDateTime* deadline;
@property (readonly) NSArray* /* NSString * */ identities;
- (WFDeferral*)getDeferral;
@end

#endif // __WSEProtectedAccessSuspendingEventArgs_DEFINED__

// Windows.Security.EnterpriseData.ProtectedAccessResumedEventArgs
#ifndef __WSEProtectedAccessResumedEventArgs_DEFINED__
#define __WSEProtectedAccessResumedEventArgs_DEFINED__

OBJCUWP_WINDOWS_SECURITY_ENTERPRISEDATA_EXPORT
@interface WSEProtectedAccessResumedEventArgs : RTObject
#if defined(__cplusplus)
+ (instancetype)createWith:(IInspectable*)obj __attribute__ ((ns_returns_autoreleased));
#endif
@property (readonly) NSArray* /* NSString * */ identities;
@end

#endif // __WSEProtectedAccessResumedEventArgs_DEFINED__

// Windows.Security.EnterpriseData.ProtectedContentRevokedEventArgs
#ifndef __WSEProtectedContentRevokedEventArgs_DEFINED__
#define __WSEProtectedContentRevokedEventArgs_DEFINED__

OBJCUWP_WINDOWS_SECURITY_ENTERPRISEDATA_EXPORT
@interface WSEProtectedContentRevokedEventArgs : RTObject
#if defined(__cplusplus)
+ (instancetype)createWith:(IInspectable*)obj __attribute__ ((ns_returns_autoreleased));
#endif
@property (readonly) NSArray* /* NSString * */ identities;
@end

#endif // __WSEProtectedContentRevokedEventArgs_DEFINED__

// Windows.Security.EnterpriseData.FileRevocationManager
#ifndef __WSEFileRevocationManager_DEFINED__
#define __WSEFileRevocationManager_DEFINED__

OBJCUWP_WINDOWS_SECURITY_ENTERPRISEDATA_EXPORT
@interface WSEFileRevocationManager : RTObject
+ (void)protectAsync:(RTObject<WSIStorageItem>*)storageItem enterpriseIdentity:(NSString *)enterpriseIdentity success:(void (^)(WSEFileProtectionStatus))success failure:(void (^)(NSError*))failure;
+ (void)copyProtectionAsync:(RTObject<WSIStorageItem>*)sourceStorageItem targetStorageItem:(RTObject<WSIStorageItem>*)targetStorageItem success:(void (^)(BOOL))success failure:(void (^)(NSError*))failure;
+ (void)revoke:(NSString *)enterpriseIdentity;
+ (void)getStatusAsync:(RTObject<WSIStorageItem>*)storageItem success:(void (^)(WSEFileProtectionStatus))success failure:(void (^)(NSError*))failure;
@end

#endif // __WSEFileRevocationManager_DEFINED__

// Windows.Security.EnterpriseData.FileProtectionManager
#ifndef __WSEFileProtectionManager_DEFINED__
#define __WSEFileProtectionManager_DEFINED__

OBJCUWP_WINDOWS_SECURITY_ENTERPRISEDATA_EXPORT
@interface WSEFileProtectionManager : RTObject
+ (void)protectAsync:(RTObject<WSIStorageItem>*)target identity:(NSString *)identity success:(void (^)(WSEFileProtectionInfo*))success failure:(void (^)(NSError*))failure;
+ (void)copyProtectionAsync:(RTObject<WSIStorageItem>*)source target:(RTObject<WSIStorageItem>*)target success:(void (^)(BOOL))success failure:(void (^)(NSError*))failure;
+ (void)getProtectionInfoAsync:(RTObject<WSIStorageItem>*)source success:(void (^)(WSEFileProtectionInfo*))success failure:(void (^)(NSError*))failure;
+ (void)saveFileAsContainerAsync:(RTObject<WSIStorageFile>*)protectedFile success:(void (^)(WSEProtectedContainerExportResult*))success failure:(void (^)(NSError*))failure;
+ (void)loadFileFromContainerAsync:(RTObject<WSIStorageFile>*)containerFile success:(void (^)(WSEProtectedContainerImportResult*))success failure:(void (^)(NSError*))failure;
+ (void)loadFileFromContainerWithTargetAsync:(RTObject<WSIStorageFile>*)containerFile target:(RTObject<WSIStorageItem>*)target success:(void (^)(WSEProtectedContainerImportResult*))success failure:(void (^)(NSError*))failure;
+ (void)createProtectedAndOpenAsync:(RTObject<WSIStorageFolder>*)parentFolder desiredName:(NSString *)desiredName identity:(NSString *)identity collisionOption:(WSCreationCollisionOption)collisionOption success:(void (^)(WSEProtectedFileCreateResult*))success failure:(void (^)(NSError*))failure;
+ (void)isContainerAsync:(RTObject<WSIStorageFile>*)file success:(void (^)(BOOL))success failure:(void (^)(NSError*))failure;
+ (void)loadFileFromContainerWithTargetAndNameCollisionOptionAsync:(RTObject<WSIStorageFile>*)containerFile target:(RTObject<WSIStorageItem>*)target collisionOption:(WSNameCollisionOption)collisionOption success:(void (^)(WSEProtectedContainerImportResult*))success failure:(void (^)(NSError*))failure;
+ (void)saveFileAsContainerWithSharingAsync:(RTObject<WSIStorageFile>*)protectedFile sharedWithIdentities:(id<NSFastEnumeration> /* NSString * */)sharedWithIdentities success:(void (^)(WSEProtectedContainerExportResult*))success failure:(void (^)(NSError*))failure;
@end

#endif // __WSEFileProtectionManager_DEFINED__

// Windows.Security.EnterpriseData.DataProtectionManager
#ifndef __WSEDataProtectionManager_DEFINED__
#define __WSEDataProtectionManager_DEFINED__

OBJCUWP_WINDOWS_SECURITY_ENTERPRISEDATA_EXPORT
@interface WSEDataProtectionManager : RTObject
+ (void)protectAsync:(RTObject<WSSIBuffer>*)data identity:(NSString *)identity success:(void (^)(WSEBufferProtectUnprotectResult*))success failure:(void (^)(NSError*))failure;
+ (void)unprotectAsync:(RTObject<WSSIBuffer>*)data success:(void (^)(WSEBufferProtectUnprotectResult*))success failure:(void (^)(NSError*))failure;
+ (void)protectStreamAsync:(RTObject<WSSIInputStream>*)unprotectedStream identity:(NSString *)identity protectedStream:(RTObject<WSSIOutputStream>*)protectedStream success:(void (^)(WSEDataProtectionInfo*))success failure:(void (^)(NSError*))failure;
+ (void)unprotectStreamAsync:(RTObject<WSSIInputStream>*)protectedStream unprotectedStream:(RTObject<WSSIOutputStream>*)unprotectedStream success:(void (^)(WSEDataProtectionInfo*))success failure:(void (^)(NSError*))failure;
+ (void)getProtectionInfoAsync:(RTObject<WSSIBuffer>*)protectedData success:(void (^)(WSEDataProtectionInfo*))success failure:(void (^)(NSError*))failure;
+ (void)getStreamProtectionInfoAsync:(RTObject<WSSIInputStream>*)protectedStream success:(void (^)(WSEDataProtectionInfo*))success failure:(void (^)(NSError*))failure;
@end

#endif // __WSEDataProtectionManager_DEFINED__

