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

// This has to be @impled in a .mm file because we need to create the ivars for the comptr.

#import <UWP/RTHelpers.h>
#import <UWP/interopBase.h>

#include <Windows.Foundation.h>

#import "Starboard.h"

@implementation RTObject
+ (instancetype)alloc {
    [NSException raise:NSInvalidArgumentException format:@"Cannot allocate WinRT components through alloc/new! Use static instantiators."];
    return nil;
}

+ (instancetype)createWith:(IInspectable*)obj {
    // We need to do no checking here since we're just mimicing a base object. The real testing happens in derived classes.
    return _createBareRTObj(obj);
}

@end

id rt_dynamic_cast(Class classType, RTObject* rtObject) {
    // Oddly, WinRT can return nullptr from successful function calls.
    // When this happens we simply return nil to objC users.
    // The user might not check if the object was nil and could make this call, which can result
    // in an exception when we try to get the underlying IInspectable from the comObj using Get() method.
    if (rtObject == nil) {
        return nil;
    }

    if ([rtObject comObj] == nullptr) {
        // This is unexpected.
        THROW_NS_HR_MSG(E_UNEXPECTED, "Underlying COM object is NULL");
    }

    return [classType createWith:[rtObject comObj].Get()];
}
