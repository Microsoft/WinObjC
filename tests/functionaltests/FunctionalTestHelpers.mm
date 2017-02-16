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

#import <Logger.h>
#import <FunctionalTestHelpers.h>
#import <AppDelegate.h>

#include "UIKit/UIApplication.h"
#include "UIViewInternal.h"

#import <Starboard/SmartTypes.h>
#import <StringHelpers.h>
#import <UWP/WindowsApplicationModel.h>

// This is a method that UIKit exposes for the test frameworks to use.
extern "C" void UIApplicationInitializeFunctionalTest(const wchar_t*, const wchar_t*);

// Launches the functional test app
bool FunctionalTestSetupUIApplication() {
    RunSynchronouslyOnMainThread(^{
        // The name of our default 'AppDelegate' class
        UIApplicationInitializeFunctionalTest(nullptr, Strings::NarrowToWide<std::wstring>(NSStringFromClass([AppDelegate class])).c_str());
    });

    return true;
}

// Terminates the functional test app
bool FunctionalTestCleanupUIApplication() {
    RunSynchronouslyOnMainThread(^{
        [[UIApplication sharedApplication] _destroy];
    });

    return true;
}

// Gets the path to the app installation location
// Returned path is formatted with double backslashes
NSString* getModulePath() {
    return [[[WAPackage current] installedLocation] path];
}

// Gets path to functional test module and appends path component
// Returned path is formatted with double backslashes
NSString* appendPathRelativeToFTModule(NSString* pathAppendage) {
    StrongId<NSString> refPath = getModulePath();
    refPath = [refPath stringByAppendingPathComponent:pathAppendage];

    return [refPath stringByReplacingOccurrencesOfString:@"/" withString:@"\\"];
}
