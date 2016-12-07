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

#import <CoreFoundation/CoreFoundation.h>
#import <CoreGraphics/CoreGraphics.h>

#include <COMIncludes.h>
#import <DWrite_3.h>
#import <wrl/client.h>
#include <COMIncludes_End.h>

#import <Starboard.h>
#import <string>
#import <memory>

// General DWrite helpers
#ifdef __cplusplus
extern "C++" std::wstring _GetUserDefaultLocaleName();
#endif

static inline CFStringRef _CFStringCreateUppercaseCopy(CFStringRef string) {
    CFMutableStringRef ret = CFStringCreateMutableCopy(nullptr, CFStringGetLength(string), string);
    CFStringUppercase(ret, nullptr);
    return ret;
}

COREGRAPHICS_EXPORT CFStringRef _CFStringFromLocalizedString(IDWriteLocalizedStrings* localizedString);

struct _DWriteFontProperties {
    DWRITE_FONT_WEIGHT weight = DWRITE_FONT_WEIGHT_NORMAL;
    DWRITE_FONT_STRETCH stretch = DWRITE_FONT_STRETCH_NORMAL;
    DWRITE_FONT_STYLE style = DWRITE_FONT_STYLE_NORMAL;

    woc::unique_cf<CFStringRef> displayName;
    woc::unique_cf<CFStringRef> postScriptName;
    woc::unique_cf<CFStringRef> familyName;
};

// Font name <-> font family, font properties
#ifdef __cplusplus
extern "C++" std::shared_ptr<_DWriteFontProperties> _DWriteGetFontPropertiesFromName(CFStringRef fontName);
#endif

COREGRAPHICS_EXPORT CFArrayRef _DWriteCopyFontFamilyNames();
COREGRAPHICS_EXPORT CFArrayRef _DWriteCopyFontNamesForFamilyName(CFStringRef familyName);
COREGRAPHICS_EXPORT CFStringRef _DWriteGetFamilyNameForFontName(CFStringRef fontName);

// Creation of DWrite font face/family objects
COREGRAPHICS_EXPORT HRESULT _DWriteCreateFontFamilyWithName(CFStringRef familyName, IDWriteFontFamily** outFontFamily);
COREGRAPHICS_EXPORT HRESULT _DWriteCreateFontFaceWithName(CFStringRef name, IDWriteFontFace** outFontFace);
COREGRAPHICS_EXPORT HRESULT _DWriteCreateTextFormatWithFontNameAndSize(CFStringRef optionalFontName,
                                                                       CGFloat fontSize,
                                                                       IDWriteTextFormat** outTextFormat);

// DWriteFont getters that convert to a CF/CG object or struct
COREGRAPHICS_EXPORT CFStringRef _DWriteFontCopyInformationalString(const Microsoft::WRL::ComPtr<IDWriteFontFace>& fontFace,
                                                                   DWRITE_INFORMATIONAL_STRING_ID informationalStringId);
COREGRAPHICS_EXPORT CFDataRef _DWriteFontCopyTable(const Microsoft::WRL::ComPtr<IDWriteFontFace>& fontFace, uint32_t tag);
COREGRAPHICS_EXPORT CGFloat _DWriteFontGetSlantDegrees(const Microsoft::WRL::ComPtr<IDWriteFontFace>& fontFace);
COREGRAPHICS_EXPORT CGRect _DWriteFontGetBoundingBox(const Microsoft::WRL::ComPtr<IDWriteFontFace>& fontFace);
COREGRAPHICS_EXPORT HRESULT _DWriteFontGetBoundingBoxesForGlyphs(
    const Microsoft::WRL::ComPtr<IDWriteFontFace>& fontFace, const CGGlyph* glyphs, CGRect* boundingRects, size_t count, bool isSideways);

// DWrite functions relating to font binary data
COREGRAPHICS_EXPORT HRESULT _DWriteRegisterFontsWithDatas(CFArrayRef fontDatas, CFArrayRef* errors);
COREGRAPHICS_EXPORT HRESULT _DWriteUnregisterFontsWithDatas(CFArrayRef fontDatas, CFArrayRef* errors);
COREGRAPHICS_EXPORT HRESULT _DWriteCreateFontFaceWithData(CFDataRef data, IDWriteFontFace** outFontFace);