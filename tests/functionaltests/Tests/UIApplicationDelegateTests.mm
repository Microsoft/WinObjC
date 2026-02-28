//******************************************************************************
//
// Copyright (c) 2016 Microsoft Corporation. All rights reserved.
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

#include <TestFramework.h>
#import <Foundation/NSBundle.h>
#import <StringHelpers.h>
#import <UIViewInternal.h>
#import <UIKit/UIKit.h>

@interface TestAppDelegate : UIResponder <UIApplicationDelegate>
    @property (strong, nonatomic) UIWindow* window;
@end

TestAppDelegate* g_currentAppDelegate = nil;

UIWindow*(^g_getWindowCallback)() = nil;
BOOL(^g_willFinishLaunchingCallback)(UIApplication* application, NSDictionary* launchOptions) = nil;
BOOL(^g_didFinishLaunchingWithOptionsCallback)(UIApplication* application, NSDictionary* launchOptions) = nil;

@implementation TestAppDelegate {
@public
    UIWindow* _window;
}

-(instancetype)init {
    if (self = [super init]) {
        g_currentAppDelegate = self;
    }

    return self;
}

-(UIWindow*)window {
    if (g_getWindowCallback) {
        _window = g_getWindowCallback();
    }

    return _window;
}

-(void)setWindow:(UIWindow*)window {
    _window = window;
}

- (BOOL)application:(UIApplication*)application willFinishLaunchingWithOptions:(NSDictionary*)launchOptions {
    if (g_willFinishLaunchingCallback) {
        return g_willFinishLaunchingCallback(application, launchOptions);
    }

    return YES;
}

- (BOOL)application:(UIApplication*)application didFinishLaunchingWithOptions:(NSDictionary*)launchOptions {
    if (g_didFinishLaunchingWithOptionsCallback) {
        return g_didFinishLaunchingWithOptionsCallback(application, launchOptions);
    }

    return YES;
}

- (void)applicationWillResignActive:(UIApplication*)application {
}

- (void)applicationDidEnterBackground:(UIApplication*)application {
}

- (void)applicationWillEnterForeground:(UIApplication*)application {
}

- (void)applicationDidBecomeActive:(UIApplication*)application {
}

- (void)applicationWillTerminate:(UIApplication*)application {
}

@end

// NSBundle mocking support
NSDictionary* g_mainInfoDictionary = nil;
@interface NSBundleMock : NSObject

- (NSDictionary*)mockInfoDictionary;

@end

@implementation NSBundleMock

- (NSDictionary*)mockInfoDictionary {
    return g_mainInfoDictionary;
}

@end

// UIStoryboard mocking support
@interface UIStoryboardMock : UIStoryboard

- (NSDictionary*)mockInfoDictionary;

@end

@implementation UIStoryboardMock

+ (UIStoryboard*)mockStoryboardWithName:(NSString*)name bundle:(NSBundle*)bundle {
    // Return an instance to the mock class
    return [UIStoryboardMock alloc];
}

- (UIViewController*)instantiateInitialViewController {
    // Return an arbitrary UIViewController
    return [[UIViewController alloc] init];
}

@end

class UIApplicationDelegateTests {
public:
    BEGIN_TEST_CLASS(UIApplicationDelegateTests)
    END_TEST_CLASS()

    TEST_CLASS_SETUP(UIApplicationDelegateTestsClassSetup) {
        // Set up NSBundle mocking so we can dynamically inject varying Info.plist dictionaries
        _mockNSBundle();
        return true;
    }

    TEST_CLASS_CLEANUP(UIApplicationDelegateTestsClassCleanup) {
        _unMockNSBundle();
        return FunctionalTestCleanupUIApplication();
    }

    TEST_METHOD_SETUP(UIApplicationDelegateTestsMethodSetup) {
        // No method setup necessary; actual app launch happens per-test
        return true;
    }

    TEST_METHOD_CLEANUP(UIApplicationDelegateTestsMethodCleanup) {
        // Reset static AppDelegate state between tests
        g_currentAppDelegate = nil;
        g_mainInfoDictionary = nil;
        g_getWindowCallback = nil;
        g_willFinishLaunchingCallback = nil;
        g_didFinishLaunchingWithOptionsCallback = nil;

        // Remove mock for UIStoryboard (if one exists)
        _unMockUIStoryboard();

        return FunctionalTestCleanupUIApplication();
    }

    void _StoryboardWindowTest(UIWindow*(^getWindowCallback)()) {
        // Populate the main info dictionary with our test storyboard file
        g_mainInfoDictionary = [[NSDictionary alloc] initWithDictionary:@{ @"UIMainStoryboardFile" : @"AppDelegateTests" }];

        // Set up mock for UIStoryboard
        _mockUIStoryboard();

        // Populate the AppDelegate blocks
        g_getWindowCallback = getWindowCallback;

        __block UIApplication* willFinishApplication = nil;
        g_willFinishLaunchingCallback = ^(UIApplication* application, NSDictionary* launchOptions) {
            // Sanity test to make sure we're working the the same AppDelegate instance as the UIApplication launch path
            ASSERT_EQ(application.delegate, g_currentAppDelegate);

            // Make sure we got a non-nil window
            ASSERT_TRUE(application.delegate.window != nil);

            // Grab the application object that we were passed
            willFinishApplication = application;

            return YES;
        };

        __block UIApplication* didFinishApplication = nil;
        g_didFinishLaunchingWithOptionsCallback = ^(UIApplication* application, NSDictionary* launchOptions) {
            // Make sure we got a non-nil window
            ASSERT_TRUE(application.delegate.window != nil);

            // Make our window key and visible
            [application.delegate.window makeKeyAndVisible];

            // Grab the application object that we were passed
            didFinishApplication = application;

            return YES;
        };

        // Launch with storyboard
        UIApplicationInitializeFunctionalTest(nullptr, Strings::NarrowToWide<std::wstring>(NSStringFromClass([TestAppDelegate class])).c_str());

        // Confirms that our expected callbacks were invoked
        ASSERT_TRUE(willFinishApplication != nil);
        ASSERT_TRUE(didFinishApplication != nil);

        // Validate the sharedApplication's UIWindow
        ASSERT_EQ(willFinishApplication, didFinishApplication);
        ASSERT_EQ([willFinishApplication.windows count], 1);

        // If this method was passed a test UIWindow callback, confirm that the sharedApplication used it
        if (getWindowCallback) {
            ASSERT_EQ(getWindowCallback(), [willFinishApplication.windows objectAtIndex:0]);
        }
    }

    TEST_METHOD(StoryboardAppDefaultWindow) {
        // Test default UIWindow usage in storyboard apps
        _StoryboardWindowTest(nil);
    }

    TEST_METHOD(StoryboardAppWithCustomWindow) {
        // Test custom UIWindow usage in storyboard apps
        _StoryboardWindowTest(^() { 
            static UIWindow* testWindow = [[UIWindow alloc] init];
            return testWindow;
        });
    }

    void _NonStoryboardWindowTest() {
        // Populate the AppDelegate blocks
        g_getWindowCallback = nil; // We don't need to inject a UIWindow

        __block UIApplication* willFinishApplication = nil;
        g_willFinishLaunchingCallback = ^(UIApplication* application, NSDictionary* launchOptions) {
            // Sanity test to make sure we're working the the same AppDelegate instance as the UIApplication launch path
            ASSERT_EQ(application.delegate, g_currentAppDelegate);

            // Make sure we got a nil window
            ASSERT_TRUE(application.delegate.window == nil);

            // Grab the application object that we were passed
            willFinishApplication = application;

            return YES;
        };

        __block UIApplication* didFinishApplication = nil;
        g_didFinishLaunchingWithOptionsCallback = ^(UIApplication* application, NSDictionary* launchOptions) {
            // Make sure we got a nil window
            ASSERT_TRUE(application.delegate.window == nil);

            // Make our window key and visible
            [application.delegate.window makeKeyAndVisible];

            // Grab the application object that we were passed
            didFinishApplication = application;

            return YES;
        };

        // Launch with storyboard
        UIApplicationInitializeFunctionalTest(nullptr, Strings::NarrowToWide<std::wstring>(NSStringFromClass([TestAppDelegate class])).c_str());

        // Confirms that our expected callbacks were invoked
        ASSERT_TRUE(willFinishApplication != nil);
        ASSERT_TRUE(didFinishApplication != nil);

        // Validate the sharedApplication's lack of a UIWindow
        ASSERT_EQ(willFinishApplication, didFinishApplication);
        ASSERT_EQ([willFinishApplication.windows count], 0);
    }

    TEST_METHOD(XibAppDefaultWindow) {
        // Populate the main info dictionary with our test Xib file
        g_mainInfoDictionary = [[NSDictionary alloc] initWithDictionary:@{ @"NSMainNibFile" : @"AppDelegateTests" }];

        _NonStoryboardWindowTest();
    }

    TEST_METHOD(NonMarkupAppDefaultWindow) {
        // No Xib or storyboard override
        g_mainInfoDictionary = nil;

        _NonStoryboardWindowTest();
    }

private:
    Method _originalNSBundleMethod = nullptr;
    Method _swizzledNSBundleMethod = nullptr;

    void _mockNSBundle() {
        ASSERT_TRUE(!_originalNSBundleMethod && !_swizzledNSBundleMethod);
        _originalNSBundleMethod = class_getInstanceMethod([NSBundle class], @selector(infoDictionary));
        _swizzledNSBundleMethod = class_getInstanceMethod([NSBundleMock class], @selector(mockInfoDictionary));
        method_exchangeImplementations(_originalNSBundleMethod, _swizzledNSBundleMethod);
    }

    void _unMockNSBundle() {
        if (_originalNSBundleMethod) {
            method_exchangeImplementations(_swizzledNSBundleMethod, _originalNSBundleMethod);
            _originalNSBundleMethod = nullptr;
            _swizzledNSBundleMethod = nullptr;
        }
    }

    Method _originalUIStoryboardMethod = nullptr;
    Method _swizzledUIStoryboardMethod = nullptr;

    void _mockUIStoryboard() {
        ASSERT_TRUE(!_originalUIStoryboardMethod && !_swizzledUIStoryboardMethod);
        _originalUIStoryboardMethod = class_getClassMethod([UIStoryboard class], @selector(storyboardWithName:bundle:));
        _swizzledUIStoryboardMethod = class_getClassMethod([UIStoryboardMock class], @selector(mockStoryboardWithName:bundle:));

        class_replaceMethod(
            object_getClass([UIStoryboard class]), @selector(storyboardWithName:bundle:), method_getImplementation(_swizzledUIStoryboardMethod), method_getTypeEncoding(_swizzledUIStoryboardMethod));
    }

    void _unMockUIStoryboard() {
        if (_originalUIStoryboardMethod) {
            class_replaceMethod([UIStoryboard class], @selector(storyboardWithName:bundle:), method_getImplementation(_originalUIStoryboardMethod), method_getTypeEncoding(_originalUIStoryboardMethod));
            _originalUIStoryboardMethod = nullptr;
            _swizzledUIStoryboardMethod = nullptr;
        }
    }
};
