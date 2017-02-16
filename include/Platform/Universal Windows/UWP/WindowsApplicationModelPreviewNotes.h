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

// WindowsApplicationModelPreviewNotes.h
// Generated from winmd2objc

#pragma once

#ifndef OBJCUWP_WINDOWS_APPLICATIONMODEL_PREVIEW_NOTES_EXPORT
#define OBJCUWP_WINDOWS_APPLICATIONMODEL_PREVIEW_NOTES_EXPORT __declspec(dllimport)
#ifndef IN_OBJCUWP_BUILD
#pragma comment(lib, "ObjCUWP_Windows_ApplicationModel_Preview_Notes.lib")
#endif
#endif
#include <UWP/interopBase.h>

@class WAPNNotePlacementChangedPreviewEventArgs, WAPNNoteVisibilityChangedPreviewEventArgs, WAPNNotesWindowManagerPreview;
@protocol WAPNINotePlacementChangedPreviewEventArgs, WAPNINoteVisibilityChangedPreviewEventArgs, WAPNINotesWindowManagerPreview, WAPNINotesWindowManagerPreviewStatics;

#include "WindowsStorageStreams.h"
#include "WindowsFoundation.h"

#import <Foundation/Foundation.h>

// Windows.ApplicationModel.Preview.Notes.NotePlacementChangedPreviewEventArgs
#ifndef __WAPNNotePlacementChangedPreviewEventArgs_DEFINED__
#define __WAPNNotePlacementChangedPreviewEventArgs_DEFINED__

OBJCUWP_WINDOWS_APPLICATIONMODEL_PREVIEW_NOTES_EXPORT
@interface WAPNNotePlacementChangedPreviewEventArgs : RTObject
#if defined(__cplusplus)
+ (instancetype)createWith:(IInspectable*)obj __attribute__ ((ns_returns_autoreleased));
#endif
@property (readonly) int viewId;
@end

#endif // __WAPNNotePlacementChangedPreviewEventArgs_DEFINED__

// Windows.ApplicationModel.Preview.Notes.NoteVisibilityChangedPreviewEventArgs
#ifndef __WAPNNoteVisibilityChangedPreviewEventArgs_DEFINED__
#define __WAPNNoteVisibilityChangedPreviewEventArgs_DEFINED__

OBJCUWP_WINDOWS_APPLICATIONMODEL_PREVIEW_NOTES_EXPORT
@interface WAPNNoteVisibilityChangedPreviewEventArgs : RTObject
#if defined(__cplusplus)
+ (instancetype)createWith:(IInspectable*)obj __attribute__ ((ns_returns_autoreleased));
#endif
@property (readonly) BOOL isVisible;
@property (readonly) int viewId;
@end

#endif // __WAPNNoteVisibilityChangedPreviewEventArgs_DEFINED__

// Windows.ApplicationModel.Preview.Notes.NotesWindowManagerPreview
#ifndef __WAPNNotesWindowManagerPreview_DEFINED__
#define __WAPNNotesWindowManagerPreview_DEFINED__

OBJCUWP_WINDOWS_APPLICATIONMODEL_PREVIEW_NOTES_EXPORT
@interface WAPNNotesWindowManagerPreview : RTObject
+ (WAPNNotesWindowManagerPreview*)getForCurrentApp;
#if defined(__cplusplus)
+ (instancetype)createWith:(IInspectable*)obj __attribute__ ((ns_returns_autoreleased));
#endif
@property (readonly) BOOL isScreenLocked;
- (EventRegistrationToken)addNotePlacementChangedEvent:(void(^)(WAPNNotesWindowManagerPreview*, WAPNNotePlacementChangedPreviewEventArgs*))del;
- (void)removeNotePlacementChangedEvent:(EventRegistrationToken)tok;
- (EventRegistrationToken)addNoteVisibilityChangedEvent:(void(^)(WAPNNotesWindowManagerPreview*, WAPNNoteVisibilityChangedPreviewEventArgs*))del;
- (void)removeNoteVisibilityChangedEvent:(EventRegistrationToken)tok;
- (EventRegistrationToken)addSystemLockStateChangedEvent:(void(^)(WAPNNotesWindowManagerPreview*, RTObject*))del;
- (void)removeSystemLockStateChangedEvent:(EventRegistrationToken)tok;
- (void)showNote:(int)noteViewId;
- (void)showNoteRelativeTo:(int)noteViewId anchorNoteViewId:(int)anchorNoteViewId;
- (void)showNoteWithPlacement:(int)noteViewId data:(RTObject<WSSIBuffer>*)data;
- (void)hideNote:(int)noteViewId;
- (RTObject<WSSIBuffer>*)getNotePlacement:(int)noteViewId;
- (BOOL)trySetNoteSize:(int)noteViewId size:(WFSize*)size;
- (void)setFocusToNextView;
- (RTObject<WFIAsyncAction>*)setNotesThumbnailAsync:(RTObject<WSSIBuffer>*)thumbnail;
@end

#endif // __WAPNNotesWindowManagerPreview_DEFINED__

