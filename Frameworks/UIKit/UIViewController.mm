//******************************************************************************
//
// Copyright (c) Microsoft Corporation. All rights reserved.
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
#import "Starboard.h"

#import "StringHelpers.h"
#import "XamlControls.h"
#import "XamlUtilities.h"

#import "Foundation/NSBundle.h"
#import "Foundation/NSMutableArray.h"
#import "Foundation/NSMutableDictionary.h"
#import "Foundation/NSNumber.h"
#import "Foundation/NSNotificationCenter.h"
#import "Foundation/NSString.h"
#import "Foundation/NSValue.h"

#import <UIKit/NSValue+UIKitAdditions.h>
#import <UIKit/UIApplication.h>
#import <UIKit/UIBarButtonItem.h>
#import <UIKit/UIDevice.h>
#import <UIKit/UINavigationController.h>
#import <UIKit/UINavigationItem.h>
#import <UIKit/UINib.h>
#import <UIKit/UIScreen.h>
#import <UIKit/UIPopoverPresentationController.h>
#import <UIKit/UIStoryboardSegue.h>
#import <UIKit/UIStoryboardSegueTemplate.h>
#import <UIKit/UIStoryboardPushSegueTemplate.h>
#import <UIKit/UITabBarController.h>
#import <UIKit/UIView.h>
#import <UIKit/UIWindow.h>
#import <UIKit/UIColor.h>
#import <UIKit/UIViewController.h>

#import "AutoLayout.h"
#import "StarboardXaml/DisplayProperties.h"

#import <CoreGraphics/CGContext.h>
#import <CoreGraphics/CGAffineTransform.h>

#import <QuartzCore/CAAnimation.h>
#import <QuartzCore/CABasicAnimation.h>
#import <QuartzCore/CALayer.h>
#import <QuartzCore/CoreAnimationFunctions.h>

#import "_UIPopupViewController.h"
#import "CACompositor.h"
#import "UIApplicationInternal.h"
#import "UIEmptyView.h"
#import "UIViewInternal.h"
#import "UIViewControllerInternal.h"
#import "UIPopoverPresentationControllerInternal.h"
#import "UIStoryboardInternal.h"
#import "UIResponderInternal.h"
#import "NSCoderInternal.h"
#import "CppWinRTHelpers.h"

#include "COMIncludes.h"
#import <winrt/Windows.UI.Xaml.h>
#import <winrt/Windows.UI.Xaml.Navigation.h>
#include "COMIncludes_End.h"

#import <ErrorHandling.h>
#import <unordered_map>

using namespace winrt::Windows::UI::Xaml;

extern BOOL g_presentingAnimated;

static const wchar_t* TAG = L"UIViewController";

NSString* const UIViewControllerHierarchyInconsistencyException = @"UIViewControllerHierarchyInconsistencyException";
NSString* const UIViewControllerShowDetailTargetDidChangeNotification = @"UIViewControllerShowDetailTargetDidChangeNotification";

namespace {
std::unordered_map<UIView*, UIViewController*> viewMap;
pthread_mutex_t mutex = PTHREAD_MUTEX_INITIALIZER;

void addViewMapping(UIView* view, UIViewController* controller) {
    pthread_mutex_lock(&mutex);
    assert(viewMap.find(view) == viewMap.end());
    viewMap[view] = controller;
    pthread_mutex_unlock(&mutex);
}

void removeViewMapping(UIView* view) {
    pthread_mutex_lock(&mutex);
    auto it = viewMap.find(view);
    assert(it != viewMap.end());
    viewMap.erase(it);
    pthread_mutex_unlock(&mutex);
}

UIViewController* lookupViewController(UIView* view) {
    pthread_mutex_lock(&mutex);
    auto it = viewMap.find(view);

    UIViewController* ret = nil;
    if (it != viewMap.end())
        ret = it->second;
    pthread_mutex_unlock(&mutex);

    return ret;
}
};

bool isSupportedControllerOrientation(UIViewController* controller, UIInterfaceOrientation orientation) {
    NSDictionary* infoDict = [[NSBundle mainBundle] infoDictionary];
    NSArray* orientations = 0;

    if (DisplayProperties::IsTablet()) {
        orientations = [infoDict objectForKey:@"UISupportedInterfaceOrientations~ipad"];
    }
    if (!orientations) {
        orientations = [infoDict objectForKey:@"UISupportedInterfaceOrientations"];
    }

    if (orientations != nil) {
        if (![controller shouldAutorotate])
            return false;

        int supportedOrientations = 0;

        for (NSString* curstr in orientations) {
            if ([curstr isEqualToString:@"UIInterfaceOrientationPortrait"])
                supportedOrientations |= UIInterfaceOrientationMaskPortrait;
            if ([curstr isEqualToString:@"UIInterfaceOrientationPortraitUpsideDown"])
                supportedOrientations |= UIInterfaceOrientationMaskPortraitUpsideDown;
            if ([curstr isEqualToString:@"UIInterfaceOrientationLandscapeLeft"])
                supportedOrientations |= UIInterfaceOrientationMaskLandscapeLeft;
            if ([curstr isEqualToString:@"UIInterfaceOrientationLandscapeRight"])
                supportedOrientations |= UIInterfaceOrientationMaskLandscapeRight;
        }

        int windowSupported = [controller supportedInterfaceOrientations];
        supportedOrientations &= windowSupported;

        if (supportedOrientations & (1 << orientation)) {
            return true;
        } else {
            return false;
        }
    } else {
        return [controller shouldAutorotateToInterfaceOrientation:orientation] != FALSE;
    }
}

UIInterfaceOrientation supportedOrientationForOrientation(UIViewController* controller, UIInterfaceOrientation orientation) {
    NSDictionary* infoDict = [[NSBundle mainBundle] infoDictionary];
    NSArray* orientations = 0;
    if (DisplayProperties::IsTablet()) {
        orientations = [infoDict objectForKey:@"UISupportedInterfaceOrientations~ipad"];
    }
    if (!orientations) {
        orientations = [infoDict objectForKey:@"UISupportedInterfaceOrientations"];
    }

    if (orientations != nil) {
        int supportedOrientations = 0;

        if (![controller shouldAutorotate])
            return UIInterfaceOrientationUnknown;

        for (NSString* curstr in orientations) {
            if ([curstr isEqualToString:@"UIInterfaceOrientationPortrait"])
                supportedOrientations |= UIInterfaceOrientationMaskPortrait;
            if ([curstr isEqualToString:@"UIInterfaceOrientationPortraitUpsideDown"])
                supportedOrientations |= UIInterfaceOrientationMaskPortraitUpsideDown;
            if ([curstr isEqualToString:@"UIInterfaceOrientationLandscapeLeft"])
                supportedOrientations |= UIInterfaceOrientationMaskLandscapeLeft;
            if ([curstr isEqualToString:@"UIInterfaceOrientationLandscapeRight"])
                supportedOrientations |= UIInterfaceOrientationMaskLandscapeRight;
        }

        int windowSupported = [controller supportedInterfaceOrientations];
        supportedOrientations &= windowSupported;

        if (supportedOrientations & (1 << orientation)) {
            return orientation;
        } else {
            //  Go with any valid orientation
            if (supportedOrientations & UIInterfaceOrientationMaskPortrait) {
                return UIInterfaceOrientationPortrait;
            }
            if (supportedOrientations & UIInterfaceOrientationMaskPortraitUpsideDown) {
                return UIInterfaceOrientationPortraitUpsideDown;
            }
            if (supportedOrientations & UIInterfaceOrientationMaskLandscapeRight) {
                return UIInterfaceOrientationLandscapeRight;
            }
            if (supportedOrientations & UIInterfaceOrientationMaskLandscapeLeft) {
                return UIInterfaceOrientationLandscapeLeft;
            }
            return UIInterfaceOrientationUnknown;
        }
    } else {
        if ([controller shouldAutorotateToInterfaceOrientation:orientation]) {
            return orientation;
        } else {
            //  Try to find any valid orientation
            static const UIInterfaceOrientation orientations[] = { UIInterfaceOrientationPortrait,
                                                                   UIInterfaceOrientationPortraitUpsideDown,
                                                                   UIInterfaceOrientationLandscapeRight,
                                                                   UIInterfaceOrientationLandscapeLeft };

            for (int i = 0; i < 4; i++) {
                orientation = orientations[i];

                if ([controller shouldAutorotateToInterfaceOrientation:orientation]) {
                    return orientation;
                }
            }
        }

        return UIInterfaceOrientationUnknown;
    }
}

@interface _UILayoutSupportConstraint : NSLayoutConstraint
@end

// Not convinced this is here for anything but a rename.
@implementation _UILayoutSupportConstraint
@end

@implementation _UILayoutGuide {
@public
    CGFloat _length;
    StrongId<NSString> _identifier;
}

- (instancetype)init {
    self.translatesAutoresizingMaskIntoConstraints = NO;
    return self;
}

- (instancetype)initWithIdentifier:(NSString*)identifier {
    if (self = [super init]) {
        _identifier = identifier;
        self.translatesAutoresizingMaskIntoConstraints = NO;
    }

    return self;
}

- (NSString*)description {
    NSString* ret = [super description];
    return [NSString stringWithFormat:@"%@:%@", ret, (id)_identifier];
}

- (instancetype)initWithCoder:(NSCoder*)coder {
    if (self = [super initWithCoder:coder]) {
        _identifier = [coder decodeObjectForKey:@"_UILayoutGuideIdentifier"];
        self.translatesAutoresizingMaskIntoConstraints = NO;
        assert(_identifier);
    }

    return self;
}

- (CGFloat)length {
    // TODO: Search up the hierarchy for the controller, look for nav/tab bars, return height + status bar
    return _length;
}
@end

// Proxy class that wraps up parent INavigationEventArgs which is later used to trigger OnNavigatedTo in viewWillAppear
class EventArgs : public ABI::Windows::UI::Xaml::Navigation::INavigationEventArgs {
public:
    EventArgs() {
    }

    virtual HRESULT STDMETHODCALLTYPE QueryInterface(
        /* [in] */ REFIID riid,
        /* [iid_is][out] */ _COM_Outptr_ void __RPC_FAR* __RPC_FAR* ppvObject) {
        if (memcmp(&riid, &ABI::Windows::UI::Xaml::Navigation::IID_INavigationEventArgs, sizeof(IID)) == 0) {
            *ppvObject = (void**)this;
            return S_OK;
        }
        return E_NOTIMPL;
    }

    virtual ULONG STDMETHODCALLTYPE AddRef(void) {
        return 1;
    }

    virtual ULONG STDMETHODCALLTYPE Release(void) {
        return 1;
    }

    virtual HRESULT STDMETHODCALLTYPE GetIids(
        /* [out] */ __RPC__out ULONG* iidCount,
        /* [size_is][size_is][out] */ __RPC__deref_out_ecount_full_opt(*iidCount) IID** iids) {
        *iidCount = 0;

        return S_OK;
    }

    virtual HRESULT STDMETHODCALLTYPE GetRuntimeClassName(
        /* [out] */ __RPC__deref_out_opt HSTRING* className) {
        return E_FAIL;
    }

    virtual HRESULT STDMETHODCALLTYPE GetTrustLevel(
        /* [out] */ __RPC__out TrustLevel* trustLevel) {
        return S_OK;
    }

    virtual /* [propget] */ HRESULT STDMETHODCALLTYPE get_Content(
        /* [out][retval] */ __RPC__deref_out_opt IInspectable** value) {
        return S_OK;
    }

    virtual /* [propget] */ HRESULT STDMETHODCALLTYPE get_Parameter(
        /* [out][retval] */ __RPC__deref_out_opt IInspectable** value) {
        return S_OK;
    }

    virtual /* [propget] */ HRESULT STDMETHODCALLTYPE get_SourcePageType(
        /* [out][retval] */ __RPC__out ABI::Windows::UI::Xaml::Interop::TypeName* value) {
        return S_OK;
    }

    virtual /* [propget] */ HRESULT STDMETHODCALLTYPE get_NavigationMode(
        /* [out][retval] */ __RPC__out ABI::Windows::UI::Xaml::Navigation::NavigationMode* value) {
        return S_OK;
    }

    virtual /* [propget] */ HRESULT STDMETHODCALLTYPE get_Uri(
        /* [out][retval] */ __RPC__deref_out_opt ABI::Windows::Foundation::IUriRuntimeClass** value) {
        return S_OK;
    }

    virtual /* [propput] */ HRESULT STDMETHODCALLTYPE put_Uri(
        /* [in] */ __RPC__in_opt ABI::Windows::Foundation::IUriRuntimeClass* value) {
        return S_OK;
    }
};

NSMutableDictionary* _pageMappings;

@implementation UIViewController : UIResponder

@synthesize preferredFocusedView;
@synthesize traitCollection;

/**
 @Status Stub
*/
- (void)encodeWithCoder:(NSCoder*)encoder {
    UNIMPLEMENTED();
}

/**
 @Status Interoperable
*/
- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation {
    return [[UIApplication sharedApplication] statusBarOrientation];
}

/**
 @Status Interoperable
*/
- (void)willAnimateFirstHalfOfRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
                                                    duration:(NSTimeInterval)duration {
}

/**
 @Status Stub
*/
- (void)encodeRestorableStateWithCoder:(NSCoder*)coder {
    UNIMPLEMENTED();
}

/**
 @Status Stub
*/
- (void)decodeRestorableStateWithCoder:(NSCoder*)coder {
    UNIMPLEMENTED();
}

/**
 @Status Interoperable
*/
+ (instancetype)allocWithZone:(NSZone*)zone {
    UIViewController* ret = [super allocWithZone:zone];

    ret->priv = (UIViewControllerPriv*)calloc(1, sizeof(UIViewControllerPriv));
    ret->priv->_curOrientation = UIInterfaceOrientationPortrait;
    ret->priv->_edgesForExtendedLayout = 0xF;
    ret->priv->_contentSizeForViewInPopover.width = 320.0f;
    ret->priv->_contentSizeForViewInPopover.height = 1100.0f;

    [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];

    return ret;
}

- (CGRect)_orientationRect:(UIInterfaceOrientation)orientation {
    CGRect appFrame;

    appFrame = [[UIScreen mainScreen] applicationFrame];

    if ([self modalPresentationStyle] == UIModalPresentationFormSheet) {
        appFrame = [self _modalPresentationFormSheetFrame];
    }

    CGRect rect;

    switch (orientation) {
        case UIInterfaceOrientationPortrait: {
            rect.origin.x = appFrame.origin.x;
            rect.origin.y = appFrame.origin.y;
            rect.size.width = appFrame.size.width;
            rect.size.height = appFrame.size.height;
        } break;

        case UIInterfaceOrientationLandscapeRight: {
            rect.origin.x = appFrame.origin.y;
            rect.origin.y = appFrame.origin.x;
            rect.size.width = appFrame.size.height;
            rect.size.height = appFrame.size.width;
        } break;

        case UIInterfaceOrientationLandscapeLeft: {
            rect.origin.x = appFrame.origin.y;
            rect.origin.y = appFrame.origin.x;
            rect.size.width = appFrame.size.height;
            rect.size.height = appFrame.size.width;
        } break;

        default:
            assert(0);
            break;
    }

    return rect;
}

- (CGRect)_modalPresentationFormSheetFrame {
    if (!DisplayProperties::IsTablet()) {
        // fullscreen on non-tablets
        return [[UIScreen mainScreen] applicationFrame];
    }

    CGRect frame;
    if (!CGSizeEqualToSize([self preferredContentSize], CGSizeZero)) {
        frame.size = [self preferredContentSize];
    } else {
        frame.size.width = 540;
        frame.size.height = 620;
    }

    CGRect screenFrame = [[UIScreen mainScreen] applicationFrame];
    frame.origin.x = screenFrame.origin.x + screenFrame.size.width / 2.0f - frame.size.width / 2.0f;
    frame.origin.y = screenFrame.origin.y + screenFrame.size.height / 2.0f - frame.size.height / 2.0f;

    return frame;
}

- (BOOL)_hidesParent {
    UIModalPresentationStyle style = [self modalPresentationStyle];

    if (style == UIModalPresentationPopover) {
        // Popovers (which don't hide their parent) are always shown regardless of tablet mode.
        return NO;
    } else if (style == UIModalPresentationFormSheet && DisplayProperties::IsTablet()) {
        // FormSheet modals (which don't hide their parent) are only presented with tablet mode enabled.
        return NO;
    }

    return YES;
}

- (void)_setResizeToScreen:(BOOL)resize {
    priv->_resizeToScreen = TRUE;
}

- (void)setOrientationInternal:(UIInterfaceOrientation)orientation animated:(BOOL)animated {
    CGRect appFrame;

#ifndef USE_HOST_ROTATION
    if (animated) {
        [UIView beginAnimations:@"Rotation" context:nil];
        [UIView setAnimationDuration:0.25f];
    }
#endif

    [[UIApplication sharedApplication] setStatusBarOrientation:orientation animated:FALSE];

    if ([self wantsFullScreenLayout]) {
        appFrame = [[UIScreen mainScreen] bounds];
    } else {
        appFrame = [[UIScreen mainScreen] applicationFrame];
    }
    if ([self modalPresentationStyle] == UIModalPresentationFormSheet) {
        appFrame = [self _modalPresentationFormSheetFrame];
    }

    switch (orientation) {
        case UIInterfaceOrientationPortrait: {
            CGRect rect;

            rect.origin.x = appFrame.origin.x;
            rect.origin.y = appFrame.origin.y;
            rect.size.width = appFrame.size.width;
            rect.size.height = appFrame.size.height;

            [priv->view
                setCenter:CGPointMake(appFrame.origin.x + appFrame.size.width / 2.0f, appFrame.origin.y + appFrame.size.height / 2.0f)];
            rect.origin.x = 0.0f;
            rect.origin.y = 0.0f;
            [priv->view setBounds:rect];

            CGAffineTransform trans;

            trans = CGAffineTransformMakeTranslation(0.0f, 0.0f);
            [priv->view setTransform:trans];
        } break;

        case UIInterfaceOrientationPortraitUpsideDown: {
            CGRect rect;

            rect.origin.x = appFrame.origin.x;
            rect.origin.y = appFrame.origin.y;
            rect.size.width = appFrame.size.width;
            rect.size.height = appFrame.size.height;

            [priv->view
                setCenter:CGPointMake(appFrame.origin.x + appFrame.size.width / 2.0f, appFrame.origin.y + appFrame.size.height / 2.0f)];
            rect.origin.x = 0.0f;
            rect.origin.y = 0.0f;
            [priv->view setBounds:rect];

            CGAffineTransform trans;

            trans = CGAffineTransformMakeRotation(kPi);
            [priv->view setTransform:trans];
        } break;

        case UIInterfaceOrientationLandscapeRight: {
            CGRect rect;

            rect.origin.x = appFrame.origin.y;
            rect.origin.y = appFrame.origin.x;
            rect.size.width = appFrame.size.height;
            rect.size.height = appFrame.size.width;

            [priv->view
                setCenter:CGPointMake(appFrame.origin.x + appFrame.size.width / 2.0f, appFrame.origin.y + appFrame.size.height / 2.0f)];
            rect.origin.x = 0.0f;
            rect.origin.y = 0.0f;
            [priv->view setBounds:rect];

            CGAffineTransform trans;

            trans = CGAffineTransformMakeRotation(kPi / 2);
            [priv->view setTransform:trans];
        } break;

        case UIInterfaceOrientationLandscapeLeft: {
            CGRect rect;

            rect.origin.x = appFrame.origin.y;
            rect.origin.y = appFrame.origin.x;
            rect.size.width = appFrame.size.height;
            rect.size.height = appFrame.size.width;

            [priv->view
                setCenter:CGPointMake(appFrame.origin.x + appFrame.size.width / 2.0f, appFrame.origin.y + appFrame.size.height / 2.0f)];
            rect.origin.x = 0.0f;
            rect.origin.y = 0.0f;
            [priv->view setBounds:rect];

            CGAffineTransform trans;

            trans = CGAffineTransformMakeRotation(270.0f / 180.0f * kPi);
            [priv->view setTransform:trans];
        } break;

            break;

        default:
            assert(0);
            break;
    }

    [priv->view setNeedsLayout];

    if (animated) {
        [priv->view layoutIfNeeded];
#ifndef USE_HOST_ROTATION
        [self willAnimateRotationToInterfaceOrientation:orientation duration:0.25f];
        [UIView commitAnimations];
#else
        [self willAnimateRotationToInterfaceOrientation:orientation duration:0.0];
#endif
    } else {
        [self willAnimateRotationToInterfaceOrientation:orientation duration:0.0f];
    }
}

- (void)_setRotation:(UIInterfaceOrientation)orientation animated:(BOOL)animated {
    if (([priv->view superview] == nil || (UIView*)[priv->view window] != [priv->view superview]) && !priv->_isRootView) {
        return;
    }

    if (orientation != UIInterfaceOrientationPortrait && orientation != UIInterfaceOrientationPortraitUpsideDown &&
        orientation != UIInterfaceOrientationLandscapeLeft && orientation != UIInterfaceOrientationLandscapeRight) {
        return;
    }

    UIInterfaceOrientation curOrientation = (UIInterfaceOrientation)[self interfaceOrientation];
    orientation = supportedOrientationForOrientation(self, orientation);

    if (orientation != -1) {
        if ((orientation != priv->_curOrientation) || !priv->_didSetRotation ||
            orientation != [[UIApplication sharedApplication] statusBarOrientation]) {
            bool sendEvent = orientation != priv->_curOrientation;
            if (sendEvent) {
                [self willRotateToInterfaceOrientation:orientation duration:0.25];
            }

            UIInterfaceOrientation oldOrientation = priv->_curOrientation;
            priv->_curOrientation = orientation;
            priv->_didSetRotation = true;
            [self setOrientationInternal:orientation animated:animated];

            if (sendEvent) {
                [self didRotateFromInterfaceOrientation:oldOrientation];
            }
        }
    }
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
/**
 @Status Caveat
 @Notes May not be fully implemented
*/
// TODO: File bug
- (instancetype)initWithCoder:(NSCoder*)coder {
    UIView* view = [coder decodeObjectForKey:@"UIView"];
    [self setView:view];

    priv->navigationItem = [coder decodeObjectForKey:@"UINavigationItem"];
    if (priv->navigationItem != nil) {
        TraceVerbose(TAG, L"UIVIewController navigationItem is %hs", object_getClassName(priv->navigationItem));
    }

    priv->nibName = [coder decodeObjectForKey:@"UINibName"];

    //  Attempt to locate resources from the same bundle as the unarchiver that's loading us
    if ([coder respondsToSelector:@selector(_bundle)]) {
        priv->nibBundle = [coder _bundle];
    }

    priv->tabBarItem = [coder decodeObjectForKey:@"UITabBarItem"];
    priv->toolbarItems = [coder decodeObjectForKey:@"UIToolbarItems"];

    if ([coder containsValueForKey:@"UIAutoresizesArchivedViewToFullSize"]) {
        priv->_autoresize = [coder decodeIntForKey:@"UIAutoresizesArchivedViewToFullSize"] != FALSE;
    } else {
        priv->_autoresize = true;
    }

    if ([coder containsValueForKey:@"UIWantsFullScreenLayout"]) {
        priv->_wantsFullScreenLayout = [coder decodeIntForKey:@"UIWantsFullScreenLayout"] != FALSE;
    };

    priv->_modalTemplates = [coder decodeObjectForKey:@"UIStoryboardSegueTemplates"];
    NSDictionary* objs = [coder decodeObjectForKey:@"UIExternalObjectsTableForViewLoading"];
    if (objs != nil) {
        priv->_externalObjects = objs;
    }

    priv->_childViewControllers = [coder decodeObjectForKey:@"UIChildViewControllers"];
    priv->_edgesForExtendedLayout = [coder decodeIntForKey:@"UIKeyEdgesForExtendedLayout"];

    return self;
}
#pragma clang diagnostic pop

/**
 @Status Interoperable
*/
- (void)awakeFromNib {
    if (priv->view != nil && priv->hasLoaded == FALSE) {
        priv->hasLoaded = TRUE;
        [self viewDidLoad];
    }
}

/**
 @Status Interoperable
*/
- (NSString*)nibName {
    if (priv->nibName == nil) {
        NSString* ret = nil;
        NSString* nibPath;

        const char* ourClass = object_getClassName(self);
        char tryClass[255];

        assert(strlen(ourClass) < 255);

        if (strlen(ourClass) > strlen("Controller")) {
            if (strcmp(&ourClass[strlen(ourClass) - strlen("Controller")], "Controller") == 0) {
                //  Try to find the name of just the controller
                strcpy_s(tryClass, sizeof(tryClass), ourClass);
                tryClass[strlen(tryClass) - strlen("Controller")] = 0;
                nibPath = [[NSBundle mainBundle] pathForResource:[NSString stringWithCString:tryClass] ofType:@"nib"];
                if (nibPath != nil) {
                    ret = [NSString stringWithCString:tryClass];
                }
            }
        }

        if (nibPath == nil) {
            nibPath = [[NSBundle mainBundle] pathForResource:[NSString stringWithCString:ourClass] ofType:@"nib"];
            if (nibPath != nil) {
                ret = [NSString stringWithCString:ourClass];
            }
        }

        return ret;
    }

    return (NSString*)(priv->nibName);
}

/**
 @Status Interoperable
*/
- (NSBundle*)nibBundle {
    return priv->nibBundle;
}

/**
 @Status Interoperable
*/
- (instancetype)initWithNibName:(NSString*)strNib bundle:(NSBundle*)bundle {
    if (self = [super init]) {
        if (!priv) {
            priv = (UIViewControllerPriv*)calloc(1, sizeof(UIViewControllerPriv));
            priv->_curOrientation = UIInterfaceOrientationPortrait;
            priv->_contentSizeForViewInPopover.width = 320.0f;
            priv->_contentSizeForViewInPopover.height = 1100.0f;
        }

        if (bundle == nil) {
            priv->nibBundle = [NSBundle mainBundle];
        } else {
            priv->nibBundle = bundle;
        }

        if ([strNib length] > 0) {
            priv->nibName.attach([strNib copy]);
        } else {
            priv->nibName = nil;
        }

        // Load the XAML version if found. First prepend the auto-generated XAML namespace to the XAML class name
        NSString* xamlClassName = [NSString stringWithFormat:@"%@.%@", XamlUtilities::XamlAutoGenNamespace, strNib];
        auto xamlType = XamlUtilities::ReturnXamlType(xamlClassName);
        if (xamlType.Get() != nullptr) {
            priv->_xamlClassName = xamlClassName;
        }
    }

    return self;
}

/**
 @Status Interoperable
*/
- (instancetype)init {
    return [self initWithNibName:nil bundle:nil];
}

/**
 @Status Interoperable
*/
- (void)loadView {
    if (priv->view != nil) {
        return;
    }

    if (priv->_xamlClassName != nil) {
        [self _loadXamlPage];
        return;
    }

    // Fallback to loading the NIB file
    NSString* nibPath = nil;
    if (priv->nibName != nil) {
        NSBundle* bundle = priv->nibBundle;

        //  Search the bundle we were passed on initialization for the .nib file given to us.
        //  If no bundle was specified, search the main application bundle.
        if (bundle == nil) {
            bundle = [NSBundle mainBundle];
        }

        nibPath = [bundle pathForResource:priv->nibName ofType:@"nib"];

        if (nibPath == nil) {
            //  If a storyboard was provided to us, use it as part of the search path
            NSString* storyboardPath = [priv->_storyboard _path];

            if (storyboardPath != nil) {
                NSString* runtimePath = [storyboardPath stringByAppendingPathComponent:priv->nibName];
                runtimePath = [runtimePath stringByAppendingString:@".nib"];

                TraceVerbose(TAG, L"Searching = %hs", (char*)[runtimePath UTF8String]);
                nibPath = [bundle pathForResource:@"runtime" ofType:@"nib" inDirectory:runtimePath];

                if (nibPath == nil) {
                    nibPath = [bundle pathForResource:priv->nibName ofType:@"nib" inDirectory:storyboardPath];
                }
            }
        }

        if (nibPath == nil) {
            TraceCritical(TAG, L"Couldn't find %hs", [priv->nibName UTF8String]);
            assert(0);
        }
    } else {
        char* ourClass = _strdup(object_getClassName(self));
        char tryClass[255];

        assert(strlen(ourClass) < 255);

        if (strlen(ourClass) > strlen("Controller")) {
            if (strcmp(&ourClass[strlen(ourClass) - strlen("Controller")], "Controller") == 0) {
                //  Try to find the name of just the controller
                strcpy_s(tryClass, sizeof(tryClass), ourClass);
                tryClass[strlen(tryClass) - strlen("Controller")] = 0;
                nibPath = [[NSBundle mainBundle] pathForResource:[NSString stringWithCString:tryClass] ofType:@"nib"];
            }
        }

        if (nibPath == nil) {
            nibPath = [[NSBundle mainBundle] pathForResource:[NSString stringWithCString:ourClass] ofType:@"nib"];
        }

        free(ourClass);
    }

    if (nibPath != nil) {
        char* openname = (char*)[nibPath UTF8String];
        if (EbrAccess(openname, 0) == -1) {
            nibPath = [nibPath stringByAppendingPathComponent:@"/runtime.nib"];
            openname = (char*)[nibPath UTF8String];
        }

        const char* name = (const char*)[nibPath UTF8String];

        TraceVerbose(TAG, L"Loading view %hs with owner=%hs", name ? name : "nil", object_getClassName(self));

        if (EbrAccess(openname, 0) != -1) {
            UIStoryboard* proxyObject = [self storyboard];
            NSString* proxyName = @"UIStoryboardPlaceholder";

            NSMutableDictionary* proxyObjectsDict = [NSMutableDictionary dictionary];
            if (proxyObject != nil) {
                [proxyObjectsDict setObject:proxyObject forKey:proxyName];
            }

            [proxyObjectsDict addEntriesFromDictionary:priv->_externalObjects];

            UINib* nib = [UINib nibWithNibName:[NSString stringWithCString:openname] bundle:priv->nibBundle];
            [nib instantiateWithOwner:self options:@{ UINibExternalObjects : proxyObjectsDict }];
            priv->_externalObjects = nil;
        } else {
            assert(0);
        }
    }

    if (priv->view == nil) {
        CGRect frame = { 0.0f, 0.0f, DisplayProperties::ScreenWidth(), DisplayProperties::ScreenHeight() };

        frame = [[UIScreen mainScreen] applicationFrame]; /** This is correct **/
        if ([self modalPresentationStyle] == UIModalPresentationFormSheet) {
            frame = [self _modalPresentationFormSheetFrame];
        }

        UIView* view = [[[UIEmptyView alloc] initWithFrame:frame] autorelease];
        [view setAutoresizingMask:UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth];
        [self setView:view];
    }

    [self _doResizeToScreen];
    priv->_externalObjects = nil;
}

- (void)_doResizeToScreen {
    if ((priv->_resizeToScreen && priv->view && priv->_autoresize) || [self wantsFullScreenLayout]) {
        CGRect frame = { 0.0f, 0.0f, DisplayProperties::ScreenHeight(), DisplayProperties::ScreenWidth() };

        if ([self wantsFullScreenLayout]) {
            frame = [[UIScreen mainScreen] bounds];
        } else {
            frame = [[UIScreen mainScreen] applicationFrame];
        }

        if ([self modalPresentationStyle] == UIModalPresentationFormSheet) {
            frame = [self _modalPresentationFormSheetFrame];
        }

        [priv->view setFrame:frame];
    }
}

/**
 @Status Interoperable
*/
- (UIView*)view {
    if (priv->view == nil) {
        priv->isLoading = TRUE;
        [self loadView];
        priv->isLoading = FALSE;

        if (priv->view == nil) {
            TraceVerbose(TAG, L"Class name=%hs", object_getClassName(self));
            CGRect frame = { 0.0f, 0.0f, DisplayProperties::ScreenHeight(), DisplayProperties::ScreenWidth() };

            frame = [[UIScreen mainScreen] applicationFrame];
            if ([self modalPresentationStyle] == UIModalPresentationFormSheet) {
                frame = [self _modalPresentationFormSheetFrame];
            }

            UIView* view = [[[UIEmptyView alloc] initWithFrame:frame] autorelease];
            [self setView:view];
        }
    }

    if (!priv->hasLoaded && priv->isLoading == FALSE) {
        priv->hasLoaded = TRUE;
        [self viewDidLoad];
    }

    return priv->view;
}

/**
 @Status Interoperable
*/
- (UINavigationItem*)navigationItem {
    if (priv->navigationItem == nil) {
        priv->navigationItem.attach([[UINavigationItem alloc] initWithTitle:nil]);
    }

    return priv->navigationItem;
}

/**
 @Status Interoperable
*/
- (UINavigationController*)navigationController {
    UIViewController* curController = [self parentViewController];
    while (curController != nil) {
        if ([curController isKindOfClass:[UINavigationController class]]) {
            return (UINavigationController*)curController;
        }
        curController = [curController parentViewController];
    }
    return nil;
}

/**
 @Status Interoperable
*/
- (UISearchDisplayController*)searchDisplayController {
    return priv->_searchDisplayController;
}

/**
 @Status Interoperable
*/
- (UIViewController*)modalViewController {
    return priv->_presentedViewController;
}

/**
 @Status Interoperable
*/
- (UIPopoverPresentationController*)popoverPresentationController {
    return priv->_popoverPresentationController;
}

/**
 @Status Interoperable
*/
- (UIPresentationController*)presentationController {
    // The presentationController property is currently used only as an alias
    // for the popoverPresentationController property.
    if (priv->_popoverPresentationController) {
        return priv->_popoverPresentationController;
    }

    // priv->_presentationController is always nil in current implementation.
    return priv->_presentationController;
}

/**
 @Status Interoperable
*/
- (void)setView:(UIView*)newView {
    // No work necessary if it's the same view we already have
    if (newView == priv->view) {
        return;
    }

    // Remove the existing view if it exists
    UIView* oldSuper = nil;
    UIView* oldView = nil;
    if (priv->view != nil) {
        oldView = priv->view;
        oldSuper = [oldView superview];
        removeViewMapping(priv->view);
    }

    // Store the new view
    priv->view = newView;
    if (priv->view != nil) {
        addViewMapping(priv->view, self);
        if (oldSuper != nil && oldSuper != priv->view) {
            [oldSuper insertSubview:priv->view aboveSubview:oldView];
            [priv->view setHidden:FALSE];
            [oldView removeFromSuperview];
            [oldSuper setNeedsLayout];
        }
    }
}

- (void)setNavigationItem:(UINavigationItem*)newItem {
    priv->navigationItem = newItem;
}

/**
 @Status Interoperable
*/
- (UITabBarItem*)tabBarItem {
    if (priv->tabBarItem == nil) {
        priv->tabBarItem.attach([[UITabBarItem alloc] initWithTitle:priv->_title image:nil tag:0]);
        TraceVerbose(TAG, L"New tab: %hs", object_getClassName(self));
    }

    return priv->tabBarItem;
}

- (UITabBarItem*)_tabBarItem {
    return priv->tabBarItem;
}

/**
 @Status Interoperable
*/
- (UIBarButtonItem*)editButtonItem {
    if (priv->editButtonItem == nil) {
        priv->editButtonItem.attach([[UIBarButtonItem alloc] initWithTitle:priv->_isEditing ? @"Done" : @"Edit"
                                                                     style:UIBarButtonItemStylePlain
                                                                    target:self
                                                                    action:@selector(_editPressed:)]);
    }

    return priv->editButtonItem;
}

- (void)_editPressed:(id)item {
    if (priv->_isEditing) {
        [self setEditing:FALSE animated:TRUE];
    } else {
        [self setEditing:TRUE animated:TRUE];
    }
}

/**
 @Status Interoperable
*/
- (void)setTabBarItem:(UITabBarItem*)newItem {
    priv->tabBarItem = newItem;
}

/**
 @Status Caveat
 @Notes Animated param disregared.
*/
- (void)setToolbarItems:(NSArray*)newItems animated:(BOOL)animated {
    priv->toolbarItems = newItems;
}

/**
 @Status Interoperable
*/
- (NSArray*)toolbarItems {
    return priv->toolbarItems;
}

/**
 @Status Interoperable
*/
- (void)setToolbarItems:(NSArray*)newItems {
    [self setToolbarItems:newItems animated:FALSE];
}

- (void)_setBeingPresented:(BOOL)beingPresented {
    _beingPresented = beingPresented;
}

- (void)_setBeingDismissed:(BOOL)beingDismissed {
    _beingDismissed = beingDismissed;
}

/**
 @Status Interoperable
*/
- (void)presentModalViewController:(UIViewController*)controller animated:(BOOL)animated {
    [self presentViewController:controller animated:animated completion:nil];
}

/**
 @Status Interoperable
*/
- (void)presentViewController:(UIViewController*)controller animated:(BOOL)animated completion:(void (^)(void))completion {
    if (!controller) {
        TraceWarning(TAG, L"Trying to present nil controller");
        return;
    }

    if (priv->_presentedViewController) {
        TraceWarning(TAG,
                     L"Can't present view controller %08x (%hs) - view controller %08x (%hs) already has a presented controller!",
                     controller,
                     object_getClassName(controller),
                     self,
                     object_getClassName(self));
        return;
    }

    UIViewController* visibleParent = self;
    bool shouldShow = false;

    // We have a special case for our _UIPopupViewController in middleware scenarios; in such cases
    // we won't have a visible parentViewController but we'll still want the present to succeed
    if (GetCACompositor()->IsRunningAsFramework() && [self isKindOfClass:[_UIPopupViewController class]]) {
        shouldShow = true;
    } else {
        do {
            // Allow presentation only if an ancestor is not NotVisible.
            shouldShow = visibleParent->priv->_visibility != controllerNotVisible;
        } while (!shouldShow && (visibleParent = [visibleParent parentViewController]));
    }

    if (!shouldShow) {
        TraceWarning(TAG, L"Controller is not visible!");
        return;
    }

    if (visibleParent->priv->_visibility != controllerVisible) {
        TraceWarning(
            TAG,
            L"Presenting view controller %08x (%hs) on view controller %08x (%hs) which is not yet fully visible - continuing anyway.",
            controller,
            object_getClassName(controller),
            visibleParent,
            object_getClassName(visibleParent));
    }

    if (visibleParent != self) {
        TraceWarning(TAG,
                     L"View controller %08x (%hs) not visible but ancestor %08x (%hs) is - continuing anyway.",
                     self,
                     object_getClassName(self),
                     visibleParent,
                     object_getClassName(visibleParent));
    }

    [[UIApplication sharedApplication] beginIgnoringInteractionEvents];

    // Ensure viewDidLoad precedes attachment of presentedViewController.
    [controller view];

    priv->_presentedViewController = controller;
    controller->priv->_parentViewController = self;
    controller->priv->_presentingViewController = self;

    if ([controller modalPresentationStyle] == UIModalPresentationPopover) {
        controller->priv->_popoverPresentationController.attach(
            [[UIPopoverPresentationController alloc] initWithPresentedViewController:controller presentingViewController:self]);

        // Keep popoverPresentationController alive until presentation complete. Fixes a corner case crash where the
        // popover is dismissed, without animation, in the presentViewController completion block itself.
        UIPopoverPresentationController* popover = [controller->priv->_popoverPresentationController retain];

        dispatch_block_t presentCompletion = ^{
            [controller _setBeingPresented:NO];

            [[UIApplication sharedApplication] endIgnoringInteractionEvents];

            if (completion) {
                completion();
            }

            [popover release];
        };

        dispatch_async(dispatch_get_main_queue(), ^{
            // Dispatch the presentation asynchronously so users have the opportunity to configure the
            // popoverPresentationController after presentViewController but before the actual popover is presented.
            [controller _setBeingPresented:YES];
            [controller->priv->_popoverPresentationController _presentAnimated:animated presentCompletion:presentCompletion];
        });
    } else {
        [controller _setBeingPresented:YES];
        [controller _addToTop:animated completion:completion];
    }
}

/**
 @Status Interoperable
*/
- (void)dismissModalViewControllerAnimated:(BOOL)animated {
    [self dismissViewControllerAnimated:animated completion:nil];
}

- (void)_notifyDidDisappear:(UIView*)view animated:(BOOL)animated {
    LLTREE_FOREACH(subview, view->priv) {
        [self _notifyDidDisappear:subview->self animated:animated];
    }

    UIViewController* controller = [UIViewController controllerForView:view];

    if (controller != nil) {
        [controller _notifyViewDidDisappear:animated];
    }
}

- (void)_unlinkPresentedController {
    // Tear down presenting-presented relationship.
    priv->_presentedViewController->priv->_parentViewController = nil;
    priv->_presentedViewController->priv->_presentingViewController = nil;

    // Destroy owning ref of presented popover.
    priv->_presentedViewController->priv->_popoverPresentationController = nil;

    // Destroy owning ref of presented modal.
    priv->_presentedViewController = nil;
}

- (void)_finishModalDismissAnimated:(BOOL)animated completion:(dispatch_block_t)completion {
    // Keep modal alive past completion despite unlinking from parent.
    StrongId<UIViewController> presented = self->priv->_presentedViewController;

    [presented->priv->_modalOverlayView removeFromSuperview];
    presented->priv->_modalOverlayView = nil;

    UIView* presentedView = [presented view];
    [presentedView removeFromSuperview];

    UIView* view = [self view];
    [[view superview] bringSubviewToFront:view];

    // Tear down of presenting-presented relationship must occur before viewDid(Dis)Appear
    // events and completion (e.g. the modal should have no parent on viewDidDisappear).
    [self _unlinkPresentedController];

    [[UIApplication sharedApplication] endIgnoringInteractionEvents];

    [self _notifyViewDidAppear:animated];

    [self _notifyDidDisappear:presentedView animated:animated];

    [presented _setBeingDismissed:NO];

    if (completion) {
        completion();
    }
}

/**
 @Status Interoperable
*/
- (void)dismissViewControllerAnimated:(BOOL)animated completion:(void (^)(void))completion {
    if (!priv->_presentedViewController) {
        // Calling dismiss on a view controller that hasn't presented additional view controllers itself should result in the parent
        // handling the dismissal.

        if ([self parentViewController]) {
            [[self parentViewController] dismissViewControllerAnimated:animated completion:completion];
        } else {
            TraceWarning(TAG, L"dismissViewController invalid - nothing to dismiss");
        }

        return;
    }

    UIViewController* presented = priv->_presentedViewController;

    // Handle multiple child dismissal:
    UIViewController* grandChild = presented->priv->_presentedViewController;

    if (grandChild) {
        while (UIViewController* next = grandChild->priv->_presentedViewController) {
            grandChild = next;
        }

        // Dismiss the youngest first with specified animation
        __unsafe_unretained __block UIViewController* parent = [grandChild parentViewController];
        [parent dismissViewControllerAnimated:animated
                                   completion:^{
                                       // Dismiss the remaining with no animation
                                       do {
                                           parent = [parent parentViewController];
                                           // We rely on dismissViewControllerAnimated:NO blocking until child dismissal
                                           [parent dismissViewControllerAnimated:NO completion:nil];
                                       } while (parent != self);

                                       if (completion) {
                                           completion();
                                       }
                                   }];

        return;
    }

    [[UIApplication sharedApplication] beginIgnoringInteractionEvents];

    UIPopoverPresentationController* popover = [presented popoverPresentationController];
    if (popover) {
        [popover _dismissAnimated:animated
                       completion:^{
                           [[UIApplication sharedApplication] endIgnoringInteractionEvents];
                           if (completion) {
                               completion();
                           }
                       }];
        return;
    }

    [presented _setBeingDismissed:YES];
    [presented _notifyViewWillDisappear:animated];
    [self _notifyViewWillAppear:animated];
    [[self view] setHidden:NO];

    if (animated) {
        UIView* presentedView = [presented view];
        CGPoint position = [presentedView center];

        UIInterfaceOrientation orientation = findOrientation(self);
        if (orientation == UIInterfaceOrientationPortrait) {
            position.y += DisplayProperties::ScreenHeight();
        } else if (orientation == UIInterfaceOrientationPortraitUpsideDown) {
            position.y -= DisplayProperties::ScreenHeight();
        } else if (orientation == UIInterfaceOrientationLandscapeLeft) {
            position.x += DisplayProperties::ScreenWidth();
        } else {
            position.x -= DisplayProperties::ScreenWidth();
        }

        [UIView animateWithDuration:0.2f
            delay:0.0f
            options:UIViewAnimationOptionCurveEaseInOut
            animations:^{
                presentedView.center = position;
                [presented->priv->_modalOverlayView setAlpha:0.0f];
            }
            completion:^(BOOL completed) {
                [self _finishModalDismissAnimated:YES completion:completion];
            }];
    } else {
        [self _finishModalDismissAnimated:NO completion:completion];
    }
}

- (void)_notifyDidAppear:(UIView*)view animated:(BOOL)animated {
    LLTREE_FOREACH(subview, view->priv) {
        [self _notifyDidAppear:subview->self animated:animated];
    }

    UIViewController* controller = [UIViewController controllerForView:view];
    if (controller != nil) {
        [controller _notifyViewDidAppear:animated];
    }
}

- (void)_finishAddToTopAnimated:(BOOL)animated completion:(dispatch_block_t)completion {
    g_presentingAnimated = NO;

    [self _notifyDidAppear:self.view animated:animated];

    [self _setBeingPresented:NO];

    if ([self _hidesParent]) {
        UIViewController* parent = [self parentViewController];
        parent.view.hidden = YES;
        [parent _notifyViewDidDisappear:animated];
    }

    [[UIApplication sharedApplication] endIgnoringInteractionEvents];

    if (completion) {
        completion();
    }
}

- (void)_addToTop:(BOOL)animated completion:(dispatch_block_t)completion {
    if (![self parentViewController]) {
        TraceError(TAG, L"Modal controller doesn't have a parent!");
        [[UIApplication sharedApplication] endIgnoringInteractionEvents];
        return;
    }

    priv->_isRootView = YES;

    UIViewController* parent = [self parentViewController];
    UIView* parentView = [parent view];
    UIWindow* parentWindow = [parentView window];

    if (parentWindow == nil) {
        TraceWarning(TAG, L"[parentView window] unexpectedly returned nil!  Defaulting to the application's keyWindow.");
        parentWindow = [[UIApplication sharedApplication] keyWindow];
    }

    g_presentingAnimated = animated;

    if ([self _hidesParent]) {
        [parent _notifyViewWillDisappear:animated];
    }

    [self _notifyViewWillAppear:animated];

    if ([self modalPresentationStyle] == UIModalPresentationFormSheet && ![self _hidesParent]) {
        CGRect overlayFrame = [[UIScreen mainScreen] applicationFrame];
        priv->_modalOverlayView.attach([[UIView alloc] initWithFrame:overlayFrame]);
        [priv->_modalOverlayView setBackgroundColor:[UIColor blackColor]];
        [priv->_modalOverlayView setAlpha:0.0f];
        [parentWindow addSubview:priv->_modalOverlayView];
    }

    UIView* view = [self view];
    [parentWindow addSubview:view];

    if (animated) {
        CGPoint origPos = [view center];
        CGPoint curPos = origPos;

        int orientation = findOrientation(self);
        if (orientation == UIInterfaceOrientationPortrait) {
            curPos.y += DisplayProperties::ScreenHeight();
        } else if (orientation == UIInterfaceOrientationPortraitUpsideDown) {
            curPos.y -= DisplayProperties::ScreenHeight();
        } else if (orientation == UIInterfaceOrientationLandscapeLeft) {
            curPos.x += DisplayProperties::ScreenWidth();
        } else {
            curPos.x -= DisplayProperties::ScreenWidth();
        }

        [view setCenter:curPos];

        [UIView animateWithDuration:0.2f
            delay:0.0f
            options:UIViewAnimationOptionCurveEaseInOut
            animations:^{
                [priv->_modalOverlayView setAlpha:.5f];
                [view setCenter:origPos];
            }
            completion:^(BOOL finished) {
                [self _finishAddToTopAnimated:YES completion:completion];
            }];
    } else {
        [priv->_modalOverlayView setAlpha:.5f];
        [self _finishAddToTopAnimated:NO completion:completion];
    }
}

- (void)setNavigationController:(id)controller {
    priv->navigationController = controller;
}

- (BOOL)_rotationLocked:(UIInterfaceOrientation)curOrientation {
    // By default our rotation is not locked:
    return FALSE;
}

/**
 @Status Interoperable
*/
- (BOOL)shouldAutorotate {
    return TRUE;
}

/**
 @Status Interoperable
*/
- (void)setModalInPopover:(BOOL)isModal {
    priv->_modalInPopover = isModal;
}

/**
 @Status Interoperable
*/
- (BOOL)isModalInPopover {
    return priv->_modalInPopover;
}

static UIInterfaceOrientation findOrientation(UIViewController* self) {
    UIInterfaceOrientation orientation = (UIInterfaceOrientation)[[UIDevice currentDevice] orientation];
    UIViewController* parent = [self parentViewController];
    if (parent != nil && [parent _rotationLocked:orientation]) {
        UIInterfaceOrientation parentOrientation = (UIInterfaceOrientation)[parent interfaceOrientation];
        if (parentOrientation != 0) {
            orientation = parentOrientation;
        }
    }

    return orientation;
}

- (void)_notifyViewWillAppear:(BOOL)isAnimated {
    switch (priv->_visibility) {
        case controllerNotVisible: {
            UIViewController* parent = self;
            UIViewController* nextParent = [parent parentViewController];
            while (nextParent != nil) {
                parent = nextParent;
                nextParent = [parent parentViewController];
            }

            UIInterfaceOrientation toOrientation = findOrientation(self);

            [self _setRotation:toOrientation animated:FALSE];
            [parent _setRotation:toOrientation animated:FALSE];

            if (isAnimated) {
                priv->_visibility = controllerWillAppearAnimated;
            } else {
                priv->_visibility = controllerWillAppear;
            }

            [self viewWillAppear:isAnimated];
        } break;

        case controllerWillAppear:
        case controllerWillAppearAnimated:
            break;

        case controllerVisible:
            break;

        case controllerWillDisappearAnimated:
        case controllerWillDisappear:
            break;

        default:
            assert(0);
            break;
    }

    if (priv->_didSetRotation && [self interfaceOrientation] != [[UIApplication sharedApplication] statusBarOrientation]) {
        [[UIApplication sharedApplication] setStatusBarOrientation:[self interfaceOrientation]];
    }
}

- (void)_doNotifyViewDidAppear:(BOOL)isAnimated {
    priv->_visibility = controllerVisible;
    [self viewDidAppear:isAnimated];
}

- (void)_notifyViewDidAppear:(BOOL)isAnimated {
    switch (priv->_visibility) {
        case controllerWillAppear:
            if (isAnimated == FALSE) {
                [self _doNotifyViewDidAppear:isAnimated];
            } else {
                assert(0);
            }
            break;

        case controllerWillAppearAnimated:
            if (isAnimated) {
                [self _doNotifyViewDidAppear:isAnimated];
            }
            break;

        case controllerWillDisappearAnimated:
        case controllerWillDisappear:
            TraceWarning(TAG, L"Warning: Can't notify controller appeared when disappearing");
            break;

        case controllerNotVisible:
            TraceWarning(TAG, L"Warning: Controller not visible");
            break;

        case controllerVisible:
            break;

        default:
            assert(0);
            break;
    }
}

- (void)_notifyViewWillDisappear:(BOOL)isAnimated {
    switch (priv->_visibility) {
        case controllerNotVisible:
            break;

        case controllerVisible:
            [UIResponder _resignCurResponder];

            if (isAnimated == FALSE) {
                priv->_visibility = controllerWillDisappear;
            } else {
                priv->_visibility = controllerWillDisappearAnimated;
            }
            [self viewWillDisappear:isAnimated];
            break;

        case controllerWillAppear:
        case controllerWillAppearAnimated:
        case controllerWillDisappear:
        case controllerWillDisappearAnimated:
            break;

        default:
            assert(0);
            break;
    }
}

- (void)_notifyViewDidDisappear:(BOOL)isAnimated {
    switch (priv->_visibility) {
        case controllerNotVisible:
            break;

        case controllerWillDisappear:
            if (isAnimated == FALSE) {
                priv->_visibility = controllerNotVisible;
                [self viewDidDisappear:isAnimated];
            } else {
                // assert(0);
            }
            break;

        case controllerWillDisappearAnimated:
            if (isAnimated) {
                priv->_visibility = controllerNotVisible;
                [self viewDidDisappear:isAnimated];
            }
            break;

        case controllerVisible:
            TraceWarning(TAG, L"Warning: Didn't notify view will disappear");
            priv->_visibility = controllerNotVisible;
            [self viewDidDisappear:isAnimated];
            break;

        case controllerWillAppearAnimated:
        case controllerWillAppear:
            break;

        default:
            assert(0);
            break;
    }
}

/**
 @Status Interoperable
*/
- (void)beginAppearanceTransition:(BOOL)appearing animated:(BOOL)isAnimated {
    if (appearing) {
        [self _notifyViewWillAppear:isAnimated];
    } else {
        [self _notifyViewWillDisappear:isAnimated];
    }
}

/**
 @Status Interoperable
*/
- (void)endAppearanceTransition {
    switch (priv->_visibility) {
        case controllerWillAppear:
            [self _notifyViewDidAppear:FALSE];
            break;

        case controllerWillAppearAnimated:
            [self _notifyViewDidAppear:TRUE];
            break;

        case controllerWillDisappear:
            [self _notifyViewDidDisappear:FALSE];
            break;

        case controllerWillDisappearAnimated:
            [self _notifyViewDidDisappear:TRUE];
            break;

        case controllerNotVisible:
        case controllerVisible:
            UNIMPLEMENTED_WITH_MSG("Visibility mode %u not handled", priv->_visibility);
            break;

        default:
            TraceWarning(TAG, L"Invalid visibility mode: %u", priv->_visibility);
    }
}

/**
 @Status Interoperable
*/
- (void)viewWillAppear:(BOOL)isAnimated {
    if (priv->_page) {
        static EventArgs eventArgs;
        Navigation::NavigationEventArgs navArgs = nullptr;
        winrt::attach_abi(navArgs, reinterpret_cast<winrt::ABI::Windows::UI::Xaml::Navigation::INavigationEventArgs*>(&eventArgs));

        priv->_page.OnNavigatedTo(navArgs);
    }
}

/**
 @Status Interoperable
*/
- (void)viewDidAppear:(BOOL)isAnimated {
}

/**
 @Status Interoperable
*/
- (void)viewWillDisappear:(BOOL)isAnimated {
}

/**
 @Status Interoperable
*/
- (void)viewDidDisappear:(BOOL)isAnimated {
}

/**
 @Status Interoperable
*/
- (void)setTitle:(NSString*)title {
    priv->_title = title;
    [[self navigationItem] setTitle:priv->_title];
    [[self tabBarItem] setTitle:priv->_title];
}

/**
 @Status Interoperable
*/
- (NSString*)title {
    return priv->_title;
}

/**
 @Status Interoperable
*/
- (void)setEditing:(BOOL)editing {
    [self setEditing:editing animated:FALSE];
}

/**
 @Status Caveat
 @Notes Animated param disregared.
*/
- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
    priv->_isEditing = editing;

    if (priv->editButtonItem != nil) {
        [priv->editButtonItem setTitle:priv->_isEditing ? @"Done" : @"Edit"];
    }
}

/**
 @Status Interoperable
*/
- (BOOL)isEditing {
    return priv->_isEditing;
}

- (void)_loadXamlPage {
    if (priv->_xamlClassName == nil) {
        return;
    }

    if (_pageMappings == nil) {
        _pageMappings = (NSMutableDictionary*)CFDictionaryCreateMutable(NULL, 10, NULL, NULL);
    }

    CGRect frame = [[UIScreen mainScreen] applicationFrame];
    if ([self modalPresentationStyle] == UIModalPresentationFormSheet) {
        frame = [self _modalPresentationFormSheetFrame];
    }

    // Activate an instance of the XAML class and its page
    Microsoft::WRL::ComPtr<IInspectable> pageObj = nullptr;
    auto xamlType = XamlUtilities::ReturnXamlType(priv->_xamlClassName);
    xamlType->ActivateInstance(pageObj.GetAddressOf());
    [_pageMappings setObject:self forKey:(id)(void*)pageObj.Get()];

    // Create a template UIView
    priv->_page = objcwinrt::from_insp<Controls::Page>(pageObj);
    UIView* view = [[[UIEmptyView alloc] initWithFrame:frame xamlElement:objcwinrt::to_rtobj(priv->_page)] autorelease];
    [view setAutoresizingMask:UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth];
    [self setView:view];

    // Walk the list of outlets and assign them to the corresponding XAML UIElement
    unsigned int propListCount = 0;
    objc_property_t* props = (objc_property_t*)class_copyPropertyList([self class], &propListCount);
    auto freeProps = wil::ScopeExit([&]() { free(props); });

    for (int i = 0; i < propListCount; i++) {
        objc_property_t curProp = props[i];
        const char* propName = property_getName(curProp);
        if (propName) {
            NSString* propNameString = [NSString stringWithCString:propName];
            auto obj = priv->_page.FindName(objcwinrt::string(propNameString));
            UIView* control = XamlUtilities::GenerateUIKitControlFromXamlType(obj);
            if (control != nil) {
                [self setValue:control forKey:propNameString];
            }
        }
    }
}

/**
 @Status Interoperable
*/
- (void)viewDidLoad {
}

/**
 @Status Stub
 @Notes Never gets called, but has also been deprecated.
*/
- (void)viewDidUnload {
}

/**
 @Status Stub
 @Notes Never gets called, but has also been deprecated.
*/
- (void)viewWillUnload {
}

/**
 @Status Interoperable
*/
- (void)viewDidLayoutSubviews {
}

/**
 @Status Interoperable
*/
- (BOOL)isViewLoaded {
    return priv->view != nil;
}

/**
 @Status Interoperable
*/
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAllButUpsideDown;
}

/**
 @Status Interoperable
*/
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)orientation {
    return orientation == UIInterfaceOrientationPortrait;
}

/**
 @Status Interoperable
*/
- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)orientation duration:(double)duration {
}

/**
 @Status Interoperable
*/
- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)orientation duration:(double)duration {
}

- (int)_edgesForExtendedLayout {
    return priv->_edgesForExtendedLayout;
}

/**
 @Status Interoperable
*/
- (UIInterfaceOrientation)interfaceOrientation {
    if (!priv->_didSetRotation) {
        return (UIInterfaceOrientation)[[UIApplication sharedApplication] statusBarOrientation];
    }

    return priv->_curOrientation;
}

/**
 @Status Interoperable
*/
- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)orientation {
}

/**
 @Status Interoperable
*/
- (void)willMoveToParentViewController:(UIViewController*)parent {
}

/**
 @Status Interoperable
*/
- (void)didMoveToParentViewController:(UIViewController*)parent {
}

/**
 @Status Interoperable
*/
+ (UIViewController*)controllerForView:(UIView*)view {
    return lookupViewController(view);
}

/**
 @Status Interoperable
*/
- (UIResponder*)nextResponder {
    if (priv->view != nil) {
        return [priv->view superview];
    }

    return nil;
}

/**
 @Status Interoperable
*/
- (UITabBarController*)tabBarController {
    UIViewController* cur = self;

    while (cur != nil) {
        TraceVerbose(TAG, L"Class is %hs", object_getClassName(cur));
        if ([cur isKindOfClass:[UITabBarController class]]) {
            return static_cast<UITabBarController*>(cur);
        }

        cur = [cur parentViewController];
    }

    return nil;
}

/**
 @Status Interoperable
*/
- (void)touchesBegan:(NSSet*)touches withEvent:(UIEvent*)event {
    id nextResponder = [self nextResponder];

    if (nextResponder != nil) {
        [nextResponder touchesBegan:touches withEvent:event];
    }
}

/**
 @Status Interoperable
*/
- (void)touchesMoved:(NSSet*)touches withEvent:(UIEvent*)event {
    UIResponder* nextResponder = [self nextResponder];

    if (nextResponder != nil) {
        [nextResponder touchesMoved:touches withEvent:event];
    }
}

/**
 @Status Interoperable
*/
- (void)touchesEnded:(NSSet*)touches withEvent:(UIEvent*)event {
    UIResponder* nextResponder = [self nextResponder];

    if (nextResponder != nil) {
        [nextResponder touchesEnded:touches withEvent:event];
    }
}

/**
 @Status Interoperable
*/
- (void)touchesCancelled:(NSSet*)touches withEvent:(UIEvent*)event {
    UIResponder* nextResponder = [self nextResponder];

    if (nextResponder != nil) {
        [nextResponder touchesCancelled:touches withEvent:event];
    }
}

/**
 @Status Interoperable
*/
- (void)setHidesBottomBarWhenPushed:(BOOL)hide {
    priv->_hidesBottomBar = hide != FALSE;
}

/**
 @Status Interoperable
*/
- (BOOL)hidesBottomBarWhenPushed {
    return priv->_hidesBottomBar;
}

/**
 @Status Stub
*/
- (void)setModalTransitionStyle:(UIModalTransitionStyle)style {
    UNIMPLEMENTED();
    priv->_modalTransitionStyle = style;
}

/**
 @Status Stub
*/
- (UIModalTransitionStyle)modalTransitionStyle {
    UNIMPLEMENTED();
    return priv->_modalTransitionStyle;
}

/**
 @Status Interoperable
*/
- (void)setWantsFullScreenLayout:(BOOL)wantsFullScreen {
    priv->_wantsFullScreenLayout = wantsFullScreen != FALSE;
}

/**
 @Status Interoperable
*/
- (void)setContentSizeForViewInPopover:(CGSize)size {
    priv->_contentSizeForViewInPopover = size;
}

/**
 @Status Interoperable
*/
- (CGSize)contentSizeForViewInPopover {
    return priv->_contentSizeForViewInPopover;
}

/**
 @Status Interoperable
*/
- (void)setPreferredContentSize:(CGSize)size {
    priv->_preferredContentSize = size;
}

/**
 @Status Interoperable
*/
- (CGSize)preferredContentSize {
    return priv->_preferredContentSize;
}

/**
 @Status Interoperable
*/
- (void)setModalPresentationStyle:(UIModalPresentationStyle)style {
    priv->_presentationStyle = style;
}

/**
 @Status Interoperable
*/
- (UIModalPresentationStyle)modalPresentationStyle {
    return priv->_presentationStyle;
}

/**
 WinObjC-only extension providing access to UIModalPresentationFormSheet overlay.
 It is not exposed in header; clients must access via performSelector.
*/
- (UIView*)_modalOverlayView {
    return priv->_modalOverlayView;
}

/**
 @Status Interoperable
*/
- (void)performSegueWithIdentifier:(NSString*)identifier sender:(id)sender {
    TraceVerbose(TAG, L"perform segue for %hs", [identifier UTF8String]);

    NSString* controllerName = nil;
    UIStoryboardSegueTemplate* segueTemplate = nil;

    for (UIStoryboardSegueTemplate* cur in (NSArray*)priv->_modalTemplates) {
        if ([[cur identifier] isEqualToString:identifier]) {
            controllerName = [cur destination];
            segueTemplate = cur;
            break;
        }
    }

    UIViewController* controller = [[self storyboard] instantiateViewControllerWithIdentifier:controllerName];
    UIStoryboardSegue* segue = [[UIStoryboardSegue alloc] initWithIdentifier:identifier source:self destination:controller];
    [self prepareForSegue:segue sender:sender];
    [controller _setResizeToScreen:TRUE];

    if ([segueTemplate isKindOfClass:[UIStoryboardPushSegueTemplate class]]) {
        [[self navigationController] pushViewController:controller animated:TRUE];
    } else {
        [self presentModalViewController:controller animated:TRUE];
    }

    [segue release];
}

/**
 @Status Interoperable
*/
- (void)performSegueWithDestination:(NSString*)destination sender:(id)sender {
    TraceVerbose(TAG, L"perform destination segue for %hs", [destination UTF8String]);

    NSString* controllerName = nil;
    UIStoryboardSegueTemplate* segueTemplate = nil;

    for (UIStoryboardSegueTemplate* cur in (NSArray*)priv->_modalTemplates) {
        if ([[cur destination] isEqualToString:destination]) {
            controllerName = [cur destination];
            segueTemplate = cur;
            break;
        }
    }

    UIViewController* controller = [[self storyboard] instantiateViewControllerWithIdentifier:controllerName];
    UIStoryboardSegue* segue = [[UIStoryboardSegue alloc] initWithIdentifier:nil source:self destination:controller];
    [self prepareForSegue:segue sender:sender];
    [controller _setResizeToScreen:TRUE];

    if ([segueTemplate isKindOfClass:[UIStoryboardPushSegueTemplate class]]) {
        [[self navigationController] pushViewController:controller animated:TRUE];
    } else {
        [self presentModalViewController:controller animated:TRUE];
    }
    [segue release];
}

/**
 @Status Interoperable
*/
- (void)prepareForSegue:(UIStoryboardSegue*)segue sender:(id)sender {
}

/**
 @Status Interoperable
*/
- (void)transitionFromViewController:(UIViewController*)fromController
                    toViewController:(UIViewController*)toController
                            duration:(double)duration
                             options:(unsigned)options
                          animations:(void (^)(void))animations // TODO(DH): animations
                          completion:(void (^)(BOOL finished))completion {
    UIView* fromView = [fromController view];
    [fromView removeFromSuperview];
    UIView* toView = [toController view];

    CGRect bounds;
    bounds = [[self view] bounds];
    [toView setFrame:bounds];
    [[self view] addSubview:toView];
    completion(YES); // TODO(DH) "finished"?
}

- (void)setStoryboard:(id)storyboard {
    priv->_storyboard = storyboard;
}

/**
 @Status Interoperable
*/
- (UIStoryboard*)storyboard {
    return priv->_storyboard;
}

/**
 @Status Interoperable
*/
- (BOOL)wantsFullScreenLayout {
    return priv->_wantsFullScreenLayout;
}

/**
 @Status Interoperable
*/
- (UIViewController*)parentViewController {
    return priv->_parentViewController;
}

/**
 @Status Interoperable
*/
- (UIViewController*)presentingViewController {
    if (priv->_presentingViewController == nil) {
        return [priv->_parentViewController presentingViewController];
    }

    return priv->_presentingViewController;
}

/**
 @Status Interoperable
 @Notes Contradictory documentation exists for this property:
        On the one hand:
        "When you present a view controller modally (either explicitly or
         implicitly) using the presentViewController:animated:completion:
         method, the view controller that called the method has this property
         set to the view controller that it presented. If the current view
         controller did not present another view controller modally, the value
         in this property is nil."
        This is contradicted by the statement that this property is:
        "The view controller that is presented by this view controller, or one
         of its ancestors in the view controller hierarchy."

        WinObjC is implementing the latter statement (requiring traversal of the
        parent hierarchy). For the former behaviour use the modalViewController
        property.

        Note that our underlying private ivar priv->_presentedViewController
        simply holds an instance of the controller presented on self via
        presentViewController:animated:completion: or nil if no view controller
        has been presented (note that the modalViewController property
        implementation simply returns this ivar).
*/
- (UIViewController*)presentedViewController {
    if (priv->_presentedViewController) {
        return priv->_presentedViewController;
    } else if ([priv->_parentViewController presentedViewController] != self) {
        return [priv->_parentViewController presentedViewController];
    }

    return nil;
}

/**
 @Status Interoperable
*/
- (void)dealloc {
    TraceVerbose(TAG, L"View controller dealloc: %hs", object_getClassName(self));
    if (priv->view != nil) {
        removeViewMapping(priv->view);
    }

    //  Don't remove our view from the heirarchy on dealloc
    //  since there could be animations being performed
    //  [Will this cause memory leaks?]
    //[priv->view removeFromSuperview];

    priv->view = nil;
    priv->navigationItem = nil;
    priv->tabBarItem = nil;
    priv->toolbarItems = nil;
    priv->editButtonItem = nil;
    priv->navigationController = nil;
    if (priv->_presentedViewController) {
        priv->_presentedViewController->priv->_parentViewController = nil;
    }
    priv->_parentViewController = nil;
    priv->nibName = nil;
    priv->nibBundle = nil;
    priv->_title = nil;
    priv->_externalObjects = nil;

    //  Remove us from being the parent of our child view controller.
    //  Should we call controller->removeFromParentViewController instead?
    for (UIViewController* curController in (NSArray*)priv->_childViewControllers) {
        curController->priv->_parentViewController = nil;
    }

    priv->_childViewControllers = nil;
    priv->_searchDisplayController = nil;
    priv->_modalTemplates = nil;
    free(priv);

    //  For safety since most people seem to forget
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    [super dealloc];
}

/**
 @Status Stub
*/
- (NSUndoManager*)undoManager {
    //  This should come from UIResponder, which we do not actually inherit from
    UNIMPLEMENTED_WITH_MSG("Undo manager not supported");
    return StubReturn();
}

/**
 @Status Interoperable
*/
- (void)didReceiveMemoryWarning {
}

/**
 @Status Stub
*/
- (void)setNeedsStatusBarAppearanceUpdate {
    UNIMPLEMENTED();
    TraceWarning(TAG, L"ignoring setNeedsStatusBarAppearanceUpdate!");
}

/**
 @Status Interoperable
*/
- (NSArray*)childViewControllers {
    if (priv->_childViewControllers == nil) {
        priv->_childViewControllers.attach([NSMutableArray new]);
    }
    return priv->_childViewControllers;
}

/**
 @Status Interoperable
*/
- (void)addChildViewController:(UIViewController*)controller {
    if (priv->_childViewControllers == nil) {
        priv->_childViewControllers.attach([NSMutableArray new]);
    }

    UIViewController* child = controller;
    if (child->priv->_parentViewController) {
        [controller removeFromParentViewController];
    }

    [priv->_childViewControllers addObject:controller];
    child->priv->_parentViewController = self;
}

/**
 @Status Interoperable
*/
- (void)removeFromParentViewController {
    UIViewController* parent = priv->_parentViewController;

    if (parent != nil)
        [parent->priv->_childViewControllers removeObject:self];
}

/**
 @Status Interoperable
*/
- (id<UILayoutSupport>)topLayoutGuide {
    UIView* view = priv->view;

    if (!view) {
        return nil;
    }

    for (int i = 0; i < [view.subviews count]; i++) {
        UIView* child = (UIView*)[view.subviews objectAtIndex:i];
        if ([child isKindOfClass:[_UILayoutGuide class]]) {
            _UILayoutGuide* guide = (_UILayoutGuide*)child;
            if ([guide->_identifier isEqual:@"_UIViewControllerTop"]) {
                return guide;
            }
        }
    }

    _UILayoutGuide* tlg = [[[_UILayoutGuide alloc] initWithIdentifier:@"_UIViewControllerTop"] autorelease];
    [view addSubview:tlg];
    [view addConstraint:[NSLayoutConstraint constraintWithItem:view
                                                     attribute:NSLayoutAttributeTop
                                                     relatedBy:NSLayoutRelationEqual
                                                        toItem:tlg
                                                     attribute:NSLayoutAttributeTop
                                                    multiplier:1.0f
                                                      constant:0]];
    [view addConstraint:[_UILayoutSupportConstraint constraintWithItem:tlg
                                                             attribute:NSLayoutAttributeHeight
                                                             relatedBy:NSLayoutRelationEqual
                                                                toItem:nil
                                                             attribute:NSLayoutAttributeNotAnAttribute
                                                            multiplier:1.0f
                                                              constant:0]];

    return tlg;
}

/**
 @Status Interoperable
*/
- (id<UILayoutSupport>)bottomLayoutGuide {
    UIView* view = priv->view;

    if (!view) {
        return nil;
    }

    for (int i = 0; i < [view.subviews count]; i++) {
        UIView* child = (UIView*)[view.subviews objectAtIndex:i];
        if ([child isKindOfClass:[_UILayoutGuide class]]) {
            _UILayoutGuide* guide = (_UILayoutGuide*)child;
            if ([guide->_identifier isEqual:@"_UIViewControllerBottom"]) {
                return guide;
            }
        }
    }

    _UILayoutGuide* blg = [[[_UILayoutGuide alloc] initWithIdentifier:@"_UIViewControllerBottom"] autorelease];
    [view addSubview:blg];
    [view addConstraint:[NSLayoutConstraint constraintWithItem:view
                                                     attribute:NSLayoutAttributeBottom
                                                     relatedBy:NSLayoutRelationEqual
                                                        toItem:blg
                                                     attribute:NSLayoutAttributeBottom
                                                    multiplier:1.0f
                                                      constant:0]];
    [view addConstraint:[_UILayoutSupportConstraint constraintWithItem:blg
                                                             attribute:NSLayoutAttributeHeight
                                                             relatedBy:NSLayoutRelationEqual
                                                                toItem:nil
                                                             attribute:NSLayoutAttributeNotAnAttribute
                                                            multiplier:1.0f
                                                              constant:0]];

    return blg;
}

/**
 @Status Interoperable
 @Notes Intended subclass override point
*/
- (void)viewWillLayoutSubviews {
}

/**
 @Status Interoperable
*/
- (void)updateViewConstraints {
    [priv->view _applyConstraints];
}

/**
 @Status Stub
*/
- (BOOL)automaticallyForwardAppearanceAndRotationMethodsToChildViewControllers {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
*/
- (BOOL)canPerformUnwindSegueAction:(SEL)action fromViewController:(UIViewController*)fromViewController withSender:(id)sender {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
*/
- (BOOL)disablesAutomaticKeyboardDismissal {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
*/
- (BOOL)isMovingFromParentViewController {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
*/
- (BOOL)isMovingToParentViewController {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
*/
- (BOOL)prefersStatusBarHidden {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
*/
- (BOOL)shouldAutomaticallyForwardAppearanceMethods {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
*/
- (BOOL)shouldAutomaticallyForwardRotationMethods {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
*/
- (BOOL)shouldPerformSegueWithIdentifier:(NSString*)identifier sender:(id)sender {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
*/
- (NSArray*)allowedChildViewControllersForUnwindingFromSource:(UIStoryboardUnwindSegueSource*)source {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
*/
- (NSArray*)previewActionItems {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
*/
- (UIStatusBarAnimation)preferredStatusBarUpdateAnimation {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
*/
- (UIStatusBarStyle)preferredStatusBarStyle {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
*/
- (UIStoryboardSegue*)segueForUnwindingToViewController:(UIViewController*)toViewController
                                     fromViewController:(UIViewController*)fromViewController
                                             identifier:(NSString*)identifier {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
*/
- (UITraitCollection*)overrideTraitCollectionForChildViewController:(UIViewController*)childViewController {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
*/
- (UIView*)rotatingFooterView {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
*/
- (UIView*)rotatingHeaderView {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
*/
- (UIViewController*)childViewControllerContainingSegueSource:(UIStoryboardUnwindSegueSource*)source {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
*/
- (UIViewController*)childViewControllerForStatusBarHidden {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
*/
- (UIViewController*)childViewControllerForStatusBarStyle {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
*/
- (UIViewController*)separateSecondaryViewControllerForSplitViewController:(UISplitViewController*)splitViewController {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
*/
- (UIViewController*)targetViewControllerForAction:(SEL)action sender:(id)sender {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
*/
- (UIViewController*)viewControllerForUnwindSegueAction:(SEL)action
                                     fromViewController:(UIViewController*)fromViewController
                                             withSender:(id)sender {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
*/
- (id<UIViewControllerPreviewing>)registerForPreviewingWithDelegate:(id<UIViewControllerPreviewingDelegate>)delegate
                                                         sourceView:(UIView*)sourceView {
    UNIMPLEMENTED();
    return nil; /* GH#2862 StubReturn() */
}

/**
 @Status Stub
*/
- (id<UIViewControllerTransitionCoordinator>)transitionCoordinator {
    UNIMPLEMENTED();
    return nil; /* GH#2862 StubReturn() */;
}

/**
 @Status Stub
*/
- (void)addKeyCommand:(UIKeyCommand*)keyCommand {
    UNIMPLEMENTED();
}

/**
 @Status Stub
*/
- (void)applicationFinishedRestoringState {
    UNIMPLEMENTED();
}

/**
 @Status Stub
*/
- (void)collapseSecondaryViewController:(UIViewController*)secondaryViewController
                 forSplitViewController:(UISplitViewController*)splitViewController {
    UNIMPLEMENTED();
}

/**
 @Status Stub
*/
- (void)didAnimateFirstHalfOfRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
    UNIMPLEMENTED();
}

/**
 @Status Stub
*/
- (void)loadViewIfNeeded {
    UNIMPLEMENTED();
}

/**
 @Status Stub
*/
- (void)removeKeyCommand:(UIKeyCommand*)keyCommand {
    UNIMPLEMENTED();
}

/**
 @Status Stub
*/
- (void)setOverrideTraitCollection:(UITraitCollection*)collection forChildViewController:(UIViewController*)childViewController {
    UNIMPLEMENTED();
}

/**
 @Status Stub
*/
- (void)showDetailViewController:(UIViewController*)vc sender:(id)sender {
    UNIMPLEMENTED();
}

/**
 @Status Stub
*/
- (void)showViewController:(UIViewController*)vc sender:(id)sender {
    UNIMPLEMENTED();
}

/**
 @Status Stub
*/
- (void)unregisterForPreviewingWithContext:(id<UIViewControllerPreviewing>)previewing {
    UNIMPLEMENTED();
}

/**
 @Status Stub
*/
- (void)unwindForSegue:(UIStoryboardSegue*)unwindSegue towardsViewController:(UIViewController*)subsequentVC {
    UNIMPLEMENTED();
}

/**
 @Status Stub
*/
- (void)willAnimateSecondHalfOfRotationFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
                                                       duration:(NSTimeInterval)duration {
    UNIMPLEMENTED();
}

/**
 @Status Stub
*/
+ (void)attemptRotationToDeviceOrientation {
    UNIMPLEMENTED();
}

/**
 @Status Stub
*/
- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    UNIMPLEMENTED();
}

/**
 @Status Stub
*/
- (void)willTransitionToTraitCollection:(UITraitCollection*)newCollection
              withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    UNIMPLEMENTED();
}

/**
 @Status Stub
*/
- (CGSize)sizeForChildContentContainer:(id<UIContentContainer>)container withParentContainerSize:(CGSize)parentSize {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
*/
- (void)preferredContentSizeDidChangeForChildContentContainer:(id<UIContentContainer>)container {
    UNIMPLEMENTED();
}

/**
 @Status Stub
*/
- (void)systemLayoutFittingSizeDidChangeForChildContentContainer:(id<UIContentContainer>)container {
    UNIMPLEMENTED();
}

/**
 @Status Stub
*/
- (void)setNeedsFocusUpdate {
    UNIMPLEMENTED();
}

/**
 @Status Stub
*/
- (void)updateFocusIfNeeded {
    UNIMPLEMENTED();
}

/**
 @Status Stub
*/
- (BOOL)shouldUpdateFocusInContext:(UIFocusUpdateContext*)context {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
*/
- (void)didUpdateFocusInContext:(UIFocusUpdateContext*)context withAnimationCoordinator:(UIFocusAnimationCoordinator*)coordinator {
    UNIMPLEMENTED();
}

/**
 @Status Stub
*/
- (void)traitCollectionDidChange:(UITraitCollection*)previousTraitCollection {
    UNIMPLEMENTED();
}

@end

extern "C" void UIViewControllerFirePageEvent(void* pageController, const char* selector) {
    id obj = [_pageMappings objectForKey:(id)pageController];
    SEL sel = sel_registerName(selector);
    [obj performSelector:sel withObject:nil];
}
