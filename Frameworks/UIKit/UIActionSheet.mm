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

#import "AssertARCEnabled.h"
#import "Starboard.h"

#import <UIKit/UIActionSheet.h>
#import <UIKit/UIControl.h>
#import <UIKit/UIColor.h>
#import <UIKit/UIImage.h>
#import <UIKit/UIView.h>
#import <UIKit/UIWindow.h>

#import <CoreGraphics/CGAffineTransform.h>
#import <CoreGraphics/CGContext.h>

#import "UIApplicationInternal.h"
#import "UIBarButtonItem+Internals.h"

#include "COMIncludes.h"
#import <winrt/Windows.Foundation.h>
#import <winrt/Windows.UI.Xaml.Controls.h>
#include "COMIncludes_End.h"

#import "XamlUtilities.h"
#import "XamlControls.h"
#import "CppWinRTHelpers.h"

#import "LoggingNative.h"

using namespace winrt::Windows::UI::Xaml;
namespace WF = winrt::Windows::Foundation;

static const wchar_t* TAG = L"UIActionSheet";

static const int s_InvalidButtonIndex = -1;

@implementation UIActionSheet {
    id<UIActionSheetDelegate> _delegate;

    // XAML ContentDialog
    TrivialDefaultConstructor<Controls::ContentDialog> _contentDialog;

    // Track these events on ContentDialog
    winrt::event_token _contentDialogOpenedEventToken;
    winrt::event_token _contentDialogClosingEventToken;
    winrt::event_token _contentDialogClosedEventToken;

    // Boolean to indicate whether ContentDialog is displayed or hidden
    BOOL _isContentDialogVisible;

    // TODO: We should remove these and move them into ContentDialog
    int _cancelButtonIndex;
    int _destructiveButtonIndex;

    // It seems that this index is static once set via initWithTitle:.... in iOS even if cancel or destructive indices are updated
    int _firstOtherButtonIndex;
}

- (void)_buttonClicked:(NSInteger)buttonIndex {
    TraceVerbose(TAG, L"_buttonClicked index: %ld", buttonIndex);

    // ActionSheetCancel is invoked before the action sheet is canceled
    if (buttonIndex == _cancelButtonIndex) {
        if ([_delegate respondsToSelector:@selector(actionSheetCancel:)]) {
            [_delegate actionSheetCancel:self];
        }
    }

    if ([_delegate respondsToSelector:@selector(actionSheet:clickedButtonAtIndex:)]) {
        [_delegate actionSheet:self clickedButtonAtIndex:buttonIndex];
    }

    if ([_delegate respondsToSelector:@selector(actionSheet:willDismissWithButtonIndex:)]) {
        [_delegate actionSheet:self willDismissWithButtonIndex:buttonIndex];
    }

    // This might be a no-op if the dialog has been dismissed already
    _contentDialog.Hide();

    // Technically the content dialog is only dismissed when the XAML thread get its chance because of its async nature
    if ([_delegate respondsToSelector:@selector(actionSheet:didDismissWithButtonIndex:)]) {
        [_delegate actionSheet:self didDismissWithButtonIndex:buttonIndex];
    }
}

- (void)_UIActionSheet_initInternal:(const FrameworkElement&)xamlElement {
    if (xamlElement) {
        _contentDialog = xamlElement.as<Controls::ContentDialog>();
    } else {
        _contentDialog = XamlControls::CreateContentDialog();
    }

    // Only used to update _isContentDialogVisible - if we move to XAML Popup, we might be able to leverage isOpen property instead
    __weak UIActionSheet* weakSelf = self;
    _contentDialogOpenedEventToken = _contentDialog.Opened(
        objcwinrt::callback([weakSelf] (const Controls::ContentDialog&, const Controls::ContentDialogOpenedEventArgs&) {
            __strong UIActionSheet* strongSelf = weakSelf;

            if (strongSelf != nil) {
                strongSelf->_isContentDialogVisible = YES;

                if ([strongSelf->_delegate respondsToSelector:@selector(didPresentActionSheet:)]) {
                    [strongSelf->_delegate didPresentActionSheet:strongSelf];
                }
            }
        }));

    // Block the closing of the dialog via ESC if _cancelButtonIndex is invalid
    _contentDialogClosingEventToken = _contentDialog.Closing(
        objcwinrt::callback([weakSelf] (const Controls::ContentDialog&, const Controls::ContentDialogClosingEventArgs& e) {
            __strong UIActionSheet* strongSelf = weakSelf;

            if (strongSelf != nil) {
                // Verify whether a button was pressed or if we dismissed the dialog via ESC
                int pressedIndex = XamlControls::XamlContentDialogPressedIndex(strongSelf->_contentDialog);
                if (pressedIndex == s_InvalidButtonIndex && strongSelf->_cancelButtonIndex == s_InvalidButtonIndex) {
                    // Cancel closing the dialog if ESC was pressed and cancelButtonIndex is invalid
                    e.Cancel(true);
                }
            }
        }));

    // Only used to update _isContentDialogVisible - if we move to XAML Popup, we might be able to leverage isOpen property instead
    _contentDialogClosedEventToken = _contentDialog.Closed(
        objcwinrt::callback([weakSelf] (const Controls::ContentDialog&, const Controls::ContentDialogClosedEventArgs&) {
            __strong UIActionSheet* strongSelf = weakSelf;

            if (strongSelf != nil) {
                strongSelf->_isContentDialogVisible = NO;
            }
        }));
}

/**
 @Status Interoperable
*/
- (instancetype)init {
    if (self = [super init]) {
        _isContentDialogVisible = NO;

        _cancelButtonIndex = s_InvalidButtonIndex;
        _destructiveButtonIndex = s_InvalidButtonIndex;
        _firstOtherButtonIndex = s_InvalidButtonIndex;

        // Create XAML-backing control
        [self _UIActionSheet_initInternal:nullptr];
    }

    return self;
}

/**
 @Status Interoperable
*/
- (instancetype)initWithTitle:(NSString*)title
                     delegate:(id<UIActionSheetDelegate>)delegate
            cancelButtonTitle:(NSString*)cancelButtonTitle
       destructiveButtonTitle:(NSString*)destructiveButtonTitle
            otherButtonTitles:(NSString*)otherButtonTitles, ... {
    if (self = [self init]) {
        [self setTitle:title];
        [self setDelegate:delegate];

        // The other button/s category
        __builtin_va_list pReader;
        __builtin_va_start(pReader, otherButtonTitles);

        id otherButtonTitle = otherButtonTitles;
        while (otherButtonTitle != nil) {
            NSInteger buttonIndex = [self addButtonWithTitle:otherButtonTitle];
            if (_firstOtherButtonIndex == s_InvalidButtonIndex) {
                _firstOtherButtonIndex = buttonIndex;
            }

            otherButtonTitle = __builtin_va_arg(pReader, id);
        }

        __builtin_va_end(pReader);

        // The destructive button category
        if (destructiveButtonTitle != nil) {
            _destructiveButtonIndex = [self addButtonWithTitle:destructiveButtonTitle];
        }

        // The cancel button category
        if (cancelButtonTitle != nil) {
            _cancelButtonIndex = [self addButtonWithTitle:cancelButtonTitle];
            XamlControls::XamlContentDialogSetCancelButtonIndex(_contentDialog, _cancelButtonIndex);
        }
    }

    return self;
}

- (void)dealloc {
    _delegate = nil;

    _contentDialog.Opened(_contentDialogOpenedEventToken);
    _contentDialog.Closing(_contentDialogClosingEventToken);
    _contentDialog.Closed(_contentDialogClosedEventToken);

    _contentDialog.Hide();
    _contentDialog = nullptr;
}

/**
@Status Interoperable
*/
- (NSInteger)addButtonWithTitle:(NSString*)title {
    unsigned int newIndex = XamlControls::XamlContentDialogAddButtonWithTitle(_contentDialog, title);

    // If cancel button is already set, we need to make sure it is the last item in the list
    if (_cancelButtonIndex != s_InvalidButtonIndex) {
        XamlControls::XamlContentDialogSetCancelButtonIndex(_contentDialog, _cancelButtonIndex);
    }

    // Return the index of the appended button (0-based index)
    return newIndex;
}

/**
 @Status Caveat
 @Notes The view parameter is not used to position the action sheet
*/
- (void)showInView:(id)view {
    if (view) {
        // TODO: Consider using XAML Popup instead of ContentDialog to remedy this issue
        UNIMPLEMENTED_WITH_MSG("showInView: does not currently use the view parameter to position the action sheet");
    }

    if ([_delegate respondsToSelector:@selector(willPresentActionSheet:)]) {
        [_delegate willPresentActionSheet:self];
    }

    // Prematurely indicate that action sheet is visible which is only confirmed after the asynchronous "Opened" event is triggered
    // However on iOS, a call to isVisible indicates it is visible almost as soon as showInView: is called
    _isContentDialogVisible = YES;

    // Display the ContentDialog and ultimately capture its dismissal event
    WF::IAsyncOperation<Controls::ContentDialogResult> async = _contentDialog.ShowAsync();

    async.Completed(objcwinrt::callback([self] (const WF::IAsyncOperation<Controls::ContentDialogResult>& operation, WF::AsyncStatus status) {
        if (status == WF::AsyncStatus::Completed) {
            int pressedIndex = XamlControls::XamlContentDialogPressedIndex(_contentDialog);
            if (pressedIndex != s_InvalidButtonIndex) {
                [self _buttonClicked:pressedIndex];
            } else {
                // Dismissed the dialog via ESC which imitates the cancel button being pressed
                [self _buttonClicked:_cancelButtonIndex];
            }
        } else {
            TraceVerbose(TAG, L"Failed with error code %u", (unsigned)status);
            _isContentDialogVisible = NO;
        }
    }));
}

/**
@Status Caveat
@Notes No animation support
*/
- (void)dismissWithClickedButtonIndex:(NSInteger)buttonIndex animated:(BOOL)animated {
    if (animated) {
        // TODO: No animation support when calling dismissedWithClickedButtonIndex:animated:
        UNIMPLEMENTED_WITH_MSG("dismissWithClickedButtonIndex with animation is not supported");
    }

    [self _buttonClicked:buttonIndex];
}

/**
 @Status Interoperable
*/
- (void)showFromToolbar:(id)toolbar {
    [self showInView:[toolbar superview]];
}

/**
 @Status Interoperable
*/
- (void)showFromTabBar:(id)tabbar {
    [self showInView:[tabbar window]];
}

/**
 @Status Interoperable
*/
- (void)showFromBarButtonItem:(UIBarButtonItem*)item animated:(BOOL)animated {
    [self showInView:[[[item _view] superview] superview]];
}

/**
 @Status Interoperable
*/
- (NSString*)title {
    return XamlUtilities::NSStringFromPropertyValue(_contentDialog.Title());
}

/**
@Status Interoperable
*/
- (void)setTitle:(NSString*)title {
    // Strings are passed via PropertyValues to C++/CX
    auto propVal = WF::PropertyValue::CreateString(objcwinrt::string(title));
    _contentDialog.Title(propVal);
}

/**
@Status Interoperable
*/
- (id<UIActionSheetDelegate>)delegate {
    return _delegate;
}

/**
@Status Interoperable
*/
- (void)setDelegate:(id<UIActionSheetDelegate>)delegate {
    _delegate = delegate;
}

/**
@Status Interoperable
*/
- (BOOL)isVisible {
    // TODO: If we move to XAML Popup, we might be able to leverage the IsOpen property
    return _isContentDialogVisible;
}

/**
 @Status Interoperable
*/
- (NSString*)buttonTitleAtIndex:(NSInteger)index {
    return XamlControls::XamlContentDialogButtonTitleAtIndex(_contentDialog, index);
}

/**
 @Status Interoperable
*/
- (NSInteger)numberOfButtons {
    return XamlControls::XamlContentDialogNumberOfButtons(_contentDialog);
}

/**
 @Status Interoperable
*/
- (NSInteger)cancelButtonIndex {
    return _cancelButtonIndex;
}

/**
 @Status Interoperable
*/
- (void)setCancelButtonIndex:(NSInteger)index {
    //
    // NOTE: Apple docs recommend this value should not be changed if the index was automatically generated within the initWithTitle....
    // initializer
    //
    if (_cancelButtonIndex != s_InvalidButtonIndex) {
        TraceVerbose(TAG, L"Cancel button index has already been set");
    }

    XamlControls::XamlContentDialogSetCancelButtonIndex(_contentDialog, index);
    _cancelButtonIndex = index;
}

/**
@Status Interoperable
*/
- (NSInteger)destructiveButtonIndex {
    return _destructiveButtonIndex;
}

/**
@Status Interoperable
*/
- (void)setDestructiveButtonIndex:(NSInteger)index {
    //
    // NOTE: Apple docs recommend this value should not be changed if the index was automatically generated within the initWithTitle....
    // initializer
    //
    if (_destructiveButtonIndex != s_InvalidButtonIndex) {
        TraceVerbose(TAG, L"Destructive button index has already been set");
    }

    XamlControls::XamlContentDialogSetDestructiveButtonIndex(_contentDialog, index);
    _destructiveButtonIndex = index;
}

/**
 @Status Interoperable
*/
- (NSInteger)firstOtherButtonIndex {
    return _firstOtherButtonIndex;
}

/**
@Status Stub
*/
- (void)showFromRect:(CGRect)rect inView:(UIView*)view animated:(BOOL)animated {
    UNIMPLEMENTED();
}

/**
@Status Stub
*/
- (void)setActionSheetStyle:(UIActionSheetStyle)style {
    UNIMPLEMENTED();
}

@end
