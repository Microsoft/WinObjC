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

// WindowsUIXamlHosting.h
// Generated from winmd2objc

#pragma once

#ifndef OBJCUWP_WINDOWS_UI_XAML_HOSTING_EXPORT
#define OBJCUWP_WINDOWS_UI_XAML_HOSTING_EXPORT __declspec(dllimport)
#ifndef IN_OBJCUWP_BUILD
#pragma comment(lib, "ObjCUWP_Windows_UI_Xaml_Hosting.lib")
#endif
#endif
#include <UWP/interopBase.h>

@class WUXHElementCompositionPreview, WUXHXamlUIPresenter;
@protocol WUXHIElementCompositionPreview, WUXHIElementCompositionPreviewStatics, WUXHIXamlUIPresenterHost, WUXHIXamlUIPresenterHost2, WUXHIXamlUIPresenterHost3, WUXHIXamlUIPresenter, WUXHIXamlUIPresenterStatics, WUXHIXamlUIPresenterStatics2;

#include "WindowsUIXamlControlsPrimitives.h"
#include "WindowsUIComposition.h"
#include "WindowsUIXaml.h"
#include "WindowsUIXamlControls.h"
#include "WindowsFoundation.h"

#import <Foundation/Foundation.h>

// Windows.UI.Xaml.Hosting.IXamlUIPresenterHost
#ifndef __WUXHIXamlUIPresenterHost_DEFINED__
#define __WUXHIXamlUIPresenterHost_DEFINED__

@protocol WUXHIXamlUIPresenterHost
- (NSString *)resolveFileResource:(NSString *)path;
@end

OBJCUWP_WINDOWS_UI_XAML_HOSTING_EXPORT
@interface WUXHIXamlUIPresenterHost : RTObject <WUXHIXamlUIPresenterHost>
@end

#endif // __WUXHIXamlUIPresenterHost_DEFINED__

// Windows.UI.Xaml.Hosting.IXamlUIPresenterHost2
#ifndef __WUXHIXamlUIPresenterHost2_DEFINED__
#define __WUXHIXamlUIPresenterHost2_DEFINED__

@protocol WUXHIXamlUIPresenterHost2
- (NSString *)getGenericXamlFilePath;
@end

OBJCUWP_WINDOWS_UI_XAML_HOSTING_EXPORT
@interface WUXHIXamlUIPresenterHost2 : RTObject <WUXHIXamlUIPresenterHost2>
@end

#endif // __WUXHIXamlUIPresenterHost2_DEFINED__

// Windows.UI.Xaml.Hosting.IXamlUIPresenterHost3
#ifndef __WUXHIXamlUIPresenterHost3_DEFINED__
#define __WUXHIXamlUIPresenterHost3_DEFINED__

@protocol WUXHIXamlUIPresenterHost3
- (RTObject*)resolveDictionaryResource:(WXResourceDictionary*)dictionary dictionaryKey:(RTObject*)dictionaryKey suggestedValue:(RTObject*)suggestedValue;
@end

OBJCUWP_WINDOWS_UI_XAML_HOSTING_EXPORT
@interface WUXHIXamlUIPresenterHost3 : RTObject <WUXHIXamlUIPresenterHost3>
@end

#endif // __WUXHIXamlUIPresenterHost3_DEFINED__

// Windows.UI.Xaml.Hosting.ElementCompositionPreview
#ifndef __WUXHElementCompositionPreview_DEFINED__
#define __WUXHElementCompositionPreview_DEFINED__

OBJCUWP_WINDOWS_UI_XAML_HOSTING_EXPORT
@interface WUXHElementCompositionPreview : RTObject
+ (WUCVisual*)getElementVisual:(WXUIElement*)element;
+ (WUCVisual*)getElementChildVisual:(WXUIElement*)element;
+ (void)setElementChildVisual:(WXUIElement*)element visual:(WUCVisual*)visual;
+ (WUCCompositionPropertySet*)getScrollViewerManipulationPropertySet:(WXCScrollViewer*)scrollViewer;
#if defined(__cplusplus)
+ (instancetype)createWith:(IInspectable*)obj;
#endif
@end

#endif // __WUXHElementCompositionPreview_DEFINED__

// Windows.UI.Xaml.Hosting.XamlUIPresenter
#ifndef __WUXHXamlUIPresenter_DEFINED__
#define __WUXHXamlUIPresenter_DEFINED__

OBJCUWP_WINDOWS_UI_XAML_HOSTING_EXPORT
@interface WUXHXamlUIPresenter : RTObject
+ (void)setHost:(RTObject<WUXHIXamlUIPresenterHost>*)host;
+ (void)notifyWindowSizeChanged;
+ (WFRect*)getFlyoutPlacementTargetInfo:(WXFrameworkElement*)placementTarget preferredPlacement:(WUXCPFlyoutPlacementMode)preferredPlacement targetPreferredPlacement:(WUXCPFlyoutPlacementMode*)targetPreferredPlacement allowFallbacks:(BOOL*)allowFallbacks;
+ (WFRect*)getFlyoutPlacement:(WFRect*)placementTargetBounds controlSize:(WFSize*)controlSize minControlSize:(WFSize*)minControlSize containerRect:(WFRect*)containerRect targetPreferredPlacement:(WUXCPFlyoutPlacementMode)targetPreferredPlacement allowFallbacks:(BOOL)allowFallbacks chosenPlacement:(WUXCPFlyoutPlacementMode*)chosenPlacement;
#if defined(__cplusplus)
+ (instancetype)createWith:(IInspectable*)obj;
#endif
@property (retain) NSString * themeResourcesXaml;
@property (retain) NSString * themeKey;
@property (retain) WXUIElement* rootElement;
+ (BOOL)completeTimelinesAutomatically;
+ (void)setCompleteTimelinesAutomatically:(BOOL)value;
- (void)setSize:(int)width height:(int)height;
- (void)render;
- (void)present;
@end

#endif // __WUXHXamlUIPresenter_DEFINED__

