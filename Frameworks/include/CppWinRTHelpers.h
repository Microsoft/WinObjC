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

#pragma once

#import <Foundation/Foundation.h>
#import "StringHelpers.h"

// TODO: Make RTHelpers.h includable from Objective-C++ without these gymnastics
#ifdef __OBJC__
#pragma push_macro("interface")
#ifndef interface
#define interface struct
#endif
#pragma push_macro("Nil")
#undef Nil
#endif
#include <UWP/RTHelpers.h>
#ifdef __OBJC__
#pragma pop_macro("Nil")
#pragma pop_macro("interface")
#endif

#include "COMIncludes.h"
#import <winrt/Windows.Foundation.h>
#import <winrt/Windows.UI.Xaml.Controls.h>
#import <wrl/client.h>
#include "COMIncludes_End.h"

namespace objcwinrt {

//
// Convert to and from IInspectable
//

// Returns an object's underlying IInspectable*.
// Return value is not AddRef'ed.
template <typename T>
IInspectable* to_insp(const T& t) {
    return reinterpret_cast<IInspectable*>(
        static_cast<winrt::ABI::Windows::Foundation::IInspectable*>(
            winrt::get_abi(t)));
}

template <typename T>
IInspectable* to_insp(const TrivialDefaultConstructor<T>& t) {
    return to_insp(static_cast<const T&>(t));
}

template <typename T>
T from_insp(IInspectable* insp) {
    T retval = nullptr;
    winrt::ABI::default_interface<winrt::abi<T>>* retvalAbi;

    if (SUCCEEDED(insp->QueryInterface(IID_PPV_ARGS(&retvalAbi)))) {
        winrt::attach_abi(retval, retvalAbi);
    }

    return retval;
}

template <typename T>
T from_insp(const Microsoft::WRL::ComPtr<IInspectable>& insp) {
    return from_insp<T>(insp.Get());
}

//
// Convert to and from RTObject
//

template <typename T>
RTObject* to_rtobj(const T& t) {
    return _createBareRTObj(to_insp(t));
}

template <typename T>
T from_rtobj(RTObject* obj) {
    return from_insp<T>([obj comObj]);
}


//
// Convert strings back and forth
//

inline
winrt::hstring string(NSString* str) {
    auto hstr1 = Strings::NarrowToWide<HSTRING>(str);

    winrt::hstring hstr2;
    winrt::attach_abi(hstr2, hstr1.Detach());

    return hstr2;
}

inline
NSString* string(winrt::hstring_view str) {
    return [NSString _stringWithHSTRING:winrt::get_abi(str)];
}


//
// Generate IReference<T> instances
//

template <typename T>
winrt::Windows::Foundation::IReference<T> optional(const T& t) {
    extern int not_implemented;
    return not_implemented;
}

template <>
inline
winrt::Windows::Foundation::IReference<double> optional<double>(const double& d) {
    auto ref = winrt::Windows::Foundation::PropertyValue::CreateDouble(d);
    return ref.as<winrt::Windows::Foundation::IReference<double>>();
}

template <>
inline
winrt::Windows::Foundation::IReference<float> optional<float>(const float& f) {
    auto ref = winrt::Windows::Foundation::PropertyValue::CreateSingle(f);
    return ref.as<winrt::Windows::Foundation::IReference<float>>();
}

}