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

#import <CoreText/CTFontManager.h>
#import <StubReturn.h>
#import <Starboard.h>
#import <CoreGraphics/DWriteWrapper.h>
#import <CoreGraphics/CGFontInternal.h>

const CFStringRef kCTFontManagerRegisteredFontsChangedNotification = CFSTR("kCTFontManagerRegisteredFontsChangedNotification");
const CFStringRef kCTFontManagerErrorDomain = CFSTR("kCTFontManagerErrorDomain");
const CFStringRef kCTFontManagerErrorFontURLsKey = CFSTR("kCTFontManagerErrorFontURLsKey");

/**
 @Status Stub
 @Notes
*/
CFArrayRef CTFontManagerCreateFontDescriptorsFromURL(CFURLRef fileURL) {
    UNIMPLEMENTED();
    return StubReturn();
}

#pragma region Helper Functions

// (Un)Registers font by creating temporary CFArray and calling into function for multiple fonts
// TLambda :: (CFArrayRef -> CTFontManagerScope -> CFArrayRef*) -> bool
template <typename TLambda>
static bool __CTFontManagerUpdateWithFont(CFURLRef fontURL, CTFontManagerScope scope, CFErrorRef _Nullable* error, TLambda&& func) {
    woc::unique_cf<CFArrayRef> fontURLs{ CFArrayCreate(nullptr, (const void**)&fontURL, 1, &kCFTypeArrayCallBacks) };
    CFArrayRef errors = nullptr;
    bool ret = func(fontURLs.get(), scope, &errors);
    if (error != nullptr && errors != nullptr && CFArrayGetCount(errors) > 0L) {
        *error = (CFErrorRef)CFRetain(CFArrayGetValueAtIndex(errors, 0));
    }

    CFRelease(errors);
    return ret;
}

// Converts CFURLs to CFDatas which are passed into DWriteWrapper methods
// TLambda :: (CFArrayRef -> CFArrayRef*) -> HRESULT
template <typename TLambda>
static bool __CTFontManagerUpdateWithFonts(CFArrayRef fontURLs, CTFontManagerScope scope, CFArrayRef _Nullable* errors, TLambda&& func) {
    CFIndex count = CFArrayGetCount(fontURLs);
    woc::unique_cf<CFMutableArrayRef> fontDatas{ CFArrayCreateMutable(nullptr, count, &kCFTypeArrayCallBacks) };
    for (size_t i = 0; i < count; ++i) {
        woc::unique_cf<CGDataProviderRef> data{ CGDataProviderCreateWithURL((CFURLRef)CFArrayGetValueAtIndex(fontURLs, i)) };
        CFArrayAppendValue(fontDatas.get(), data.get());
    }

    // S_FALSE represents partial failure so cannot use SUCCEEDED macro
    return func(fontDatas.get(), errors) == S_OK;
}

// Gets CFData from CGFontRef if available, which are passed into DWriteWrapper methods
// When graphics font was not created from data, return false with error containing error code
// TLambda :: (CFArrayRef -> CFArrayRef*) -> HRESULT
template <typename TLambda>
static bool __CTFontManagerUpdateWithGraphicsFont(CGFontRef font, CFErrorRef _Nullable* error, CFIndex errorCode, TLambda&& func) {
    CGDataProviderRef data = _CGFontGetData(font);
    if (data == nullptr) {
        // Font was created from registered font, not a custom font that can be (un)registered
        if (error) {
            *error = CFErrorCreate(nullptr, kCFErrorDomainCocoa, errorCode, nullptr);
        }

        return false;
    }

    woc::unique_cf<CFArrayRef> fontDatas{ CFArrayCreate(nullptr, (const void**)&data, 1, &kCFTypeArrayCallBacks) };
    CFArrayRef errors = nullptr;

    // S_FALSE represents partial failure so cannot use SUCCEEDED macro
    bool ret = func(fontDatas.get(), &errors) == S_OK;
    if (error != nullptr && errors != nullptr && CFArrayGetCount(errors) > 0L) {
        *error = (CFErrorRef)CFRetain(CFArrayGetValueAtIndex(errors, 0));
    }

    CFRelease(errors);
    return ret;
}

#pragma endregion Helper Functions

/**
 @Status Caveat
 @Notes scope unsupported
*/
bool CTFontManagerRegisterFontsForURL(CFURLRef fontURL, CTFontManagerScope scope, CFErrorRef _Nullable* error) {
    return __CTFontManagerUpdateWithFont(fontURL, scope, error, &CTFontManagerRegisterFontsForURLs);
}

/**
 @Status Caveat
 @Notes scope unsupported
*/
bool CTFontManagerUnregisterFontsForURL(CFURLRef fontURL, CTFontManagerScope scope, CFErrorRef _Nullable* error) {
    return __CTFontManagerUpdateWithFont(fontURL, scope, error, &CTFontManagerUnregisterFontsForURLs);
}

/**
 @Status Caveat
 @Notes scope unsupported
*/
bool CTFontManagerRegisterFontsForURLs(CFArrayRef fontURLs, CTFontManagerScope scope, CFArrayRef _Nullable* errors) {
    return __CTFontManagerUpdateWithFonts(fontURLs, scope, errors, &_DWriteRegisterFontsWithDatas);
}

/**
 @Status Caveat
 @Notes scope unsupported
*/
bool CTFontManagerUnregisterFontsForURLs(CFArrayRef fontURLs, CTFontManagerScope scope, CFArrayRef _Nullable* errors) {
    return __CTFontManagerUpdateWithFonts(fontURLs, scope, errors, &_DWriteUnregisterFontsWithDatas);
}

/**
 @Status Interoperable
 @Notes
*/
bool CTFontManagerRegisterGraphicsFont(CGFontRef font, CFErrorRef _Nullable* error) {
    return __CTFontManagerUpdateWithGraphicsFont(font, error, kCTFontManagerErrorAlreadyRegistered, &_DWriteRegisterFontsWithDatas);
}

/**
 @Status Interoperable
 @Notes
*/
bool CTFontManagerUnregisterGraphicsFont(CGFontRef font, CFErrorRef _Nullable* error) {
    return __CTFontManagerUpdateWithGraphicsFont(font, error, kCTFontManagerErrorNotRegistered, &_DWriteUnregisterFontsWithDatas);
}

/**
 @Status Stub
 @Notes
*/
bool CTFontManagerIsSupportedFont(CFURLRef fontURL) {
    UNIMPLEMENTED();
    return StubReturn();
}
