//******************************************************************************
//
// Copyright (c) Microsoft. All rights reserved.
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

#include <COMIncludes.h>
#include "MockClass.h"
#include <windows.applicationModel.activation.h>
#include <COMIncludes_End.h>

#include <UWP/WindowsApplicationModelActivation.h>
#include <TestFramework.h>
#include <Foundation/Foundation.h>
#include "UIKit/UIApplication.h"
#include "StringHelpers.h"

using namespace ABI::Windows::ApplicationModel::Activation;
using namespace Microsoft::WRL;

// Method to call in tests to activate app
extern "C" void UIApplicationActivationTest(IInspectable* args, void* delegateClassName);

MOCK_CLASS(MockToastNotificationActivatedEventArgs,
           public RuntimeClass<RuntimeClassFlags<WinRtClassicComMix>, IToastNotificationActivatedEventArgs, IActivatedEventArgs> {

               // Claim to be the implementation for the real system RuntimeClass for VoiceCommandActivatedEventArgs.
               InspectableClass(RuntimeClass_Windows_ApplicationModel_Activation_ToastNotificationActivatedEventArgs, BaseTrust);

           public:
               MOCK_STDCALL_METHOD_1(get_Argument);
               MOCK_STDCALL_METHOD_1(get_UserInput);
               MOCK_STDCALL_METHOD_1(get_Kind);
               MOCK_STDCALL_METHOD_1(get_PreviousExecutionState);
               MOCK_STDCALL_METHOD_1(get_SplashScreen);
           });

@interface ToastNotificationForegroundActivationTestDelegate : NSObject <UIApplicationDelegate>
@property (nonatomic, readonly) NSMutableDictionary* methodsCalled;
@end

@implementation ToastNotificationForegroundActivationTestDelegate
- (id)init {
    self = [super init];
    if (self) {
        _methodsCalled = [NSMutableDictionary new];
    }
    return self;
}

- (BOOL)application:(UIApplication*)application willFinishLaunchingWithOptions:(NSDictionary*)launchOptions {
    ASSERT_TRUE(launchOptions[UIApplicationLaunchOptionsToastNotificationKey]);
    WAAToastNotificationActivatedEventArgs* args = launchOptions[UIApplicationLaunchOptionsToastNotificationKey];
    ASSERT_STREQ("TOAST_NOTIFICATION_TEST", [args.argument UTF8String]);
    _methodsCalled[NSStringFromSelector(_cmd)] = @(YES);
    return true;
}

- (BOOL)application:(UIApplication*)application didFinishLaunchingWithOptions:(NSDictionary*)launchOptions {
    ASSERT_TRUE(launchOptions[UIApplicationLaunchOptionsToastNotificationKey]);
    WAAToastNotificationActivatedEventArgs* args = launchOptions[UIApplicationLaunchOptionsToastNotificationKey];
    ASSERT_STREQ("TOAST_NOTIFICATION_TEST", [args.argument UTF8String]);
    _methodsCalled[NSStringFromSelector(_cmd)] = @(YES);
    return true;
}

- (BOOL)application:(UIApplication*)application didReceiveToastNotification:(WAAToastNotificationActivatedEventArgs*)args {
    // Delegate method should only be called once
    ASSERT_EQ([[self methodsCalled] objectForKey:NSStringFromSelector(_cmd)], nil);
    ASSERT_STREQ("TOAST_NOTIFICATION_TEST", [args.argument UTF8String]);
    _methodsCalled[NSStringFromSelector(_cmd)] = @(YES);
    return true;
}

@end

@interface ActivatedAppReceivesToastNotificationDelegate : NSObject <UIApplicationDelegate>
@property (nonatomic, readonly) NSMutableDictionary* methodsCalled;
@end

@implementation ActivatedAppReceivesToastNotificationDelegate
- (id)init {
    self = [super init];
    if (self) {
        _methodsCalled = [NSMutableDictionary new];
    }
    return self;
}

- (BOOL)application:(UIApplication*)application willFinishLaunchingWithOptions:(NSDictionary*)launchOptions {
    // This should never be called if we are already activated
    ADD_FAILURE();
    return true;
}

- (BOOL)application:(UIApplication*)application didFinishLaunchingWithOptions:(NSDictionary*)launchOptions {
    // This should never be called if we are already activated
    ADD_FAILURE();
    return true;
}

- (BOOL)application:(UIApplication*)application didReceiveToastNotification:(WAAToastNotificationActivatedEventArgs*)args {
    // Delegate method should only be called once
    ASSERT_EQ([[self methodsCalled] objectForKey:NSStringFromSelector(_cmd)], nil);
    ASSERT_STREQ("TOAST_NOTIFICATION_TEST", [args.argument UTF8String]);
    _methodsCalled[NSStringFromSelector(_cmd)] = @(YES);
    return true;
}

@end

// Creates test method which we call in TEST_CLASS_SETUP to activate app
TEST(ToastNotificationTest, ForegroundActivation) {
    LOG_INFO("Toast Notification Foreground Activation Test: ");

    auto fakeToastNotificationActivatedEventArgs = Make<MockToastNotificationActivatedEventArgs>();
    fakeToastNotificationActivatedEventArgs->Setget_Argument([](HSTRING* argument) {
        Wrappers::HString value;
        value.Set(L"TOAST_NOTIFICATION_TEST");
        *argument = value.Detach();
        return S_OK;
    });

    fakeToastNotificationActivatedEventArgs->Setget_Kind([](ActivationKind* kind) {
        *kind = ActivationKind_ToastNotification;
        return S_OK;
    });

    fakeToastNotificationActivatedEventArgs->Setget_PreviousExecutionState([](ApplicationExecutionState* state) {
        *state = ApplicationExecutionState_NotRunning;
        return S_OK;
    });

    // Pass activation argument to method which activates the app
    auto args = fakeToastNotificationActivatedEventArgs.Detach();
    UIApplicationActivationTest(reinterpret_cast<IInspectable*>(args),
                                NSStringFromClass([ToastNotificationForegroundActivationTestDelegate class]));
}

TEST(ToastNotificationTest, ForegroundActivationDelegateMethodsCalled) {
    ToastNotificationForegroundActivationTestDelegate* testDelegate = [[UIApplication sharedApplication] delegate];
    NSDictionary* methodsCalled = [testDelegate methodsCalled];
    ASSERT_TRUE(methodsCalled);
    ASSERT_TRUE([methodsCalled objectForKey:@"application:willFinishLaunchingWithOptions:"]);
    ASSERT_TRUE([methodsCalled objectForKey:@"application:didFinishLaunchingWithOptions:"]);
    ASSERT_TRUE([methodsCalled objectForKey:@"application:didReceiveToastNotification:"]);
}

TEST(ToastNotificationTest, ActivatedAppReceivesToastNotification) {
    LOG_INFO("Activated App Receives Toast Notification Test: ");

    ActivatedAppReceivesToastNotificationDelegate* testDelegate = [ActivatedAppReceivesToastNotificationDelegate new];
    [[UIApplication sharedApplication] setDelegate:testDelegate];

    auto fakeToastNotificationActivatedEventArgs = Make<MockToastNotificationActivatedEventArgs>();
    fakeToastNotificationActivatedEventArgs->Setget_Argument([](HSTRING* argument) {
        Wrappers::HString value;
        value.Set(L"TOAST_NOTIFICATION_TEST");
        *argument = value.Detach();
        return S_OK;
    });

    fakeToastNotificationActivatedEventArgs->Setget_Kind([](ActivationKind* kind) {
        *kind = ActivationKind_ToastNotification;
        return S_OK;
    });

    fakeToastNotificationActivatedEventArgs->Setget_PreviousExecutionState([](ApplicationExecutionState* state) {
        *state = ApplicationExecutionState_Running;
        return S_OK;
    });

    // Calls OnActivated, which should not go through activation because we are activated
    // But should still call our new delegate method
    auto args = fakeToastNotificationActivatedEventArgs.Detach();
    UIApplicationActivationTest(reinterpret_cast<IInspectable*>(args),
                                NSStringFromClass([ToastNotificationForegroundActivationTestDelegate class]));

    NSDictionary* methodsCalled = [testDelegate methodsCalled];
    ASSERT_TRUE(methodsCalled);
    ASSERT_TRUE([methodsCalled objectForKey:@"application:didReceiveToastNotification:"]);
}
