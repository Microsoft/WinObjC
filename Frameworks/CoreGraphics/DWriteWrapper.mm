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
#import <wrl/implements.h>
#include <COMIncludes_End.h>

#import <CoreGraphics/DWriteWrapper.h>
#import <StringHelpers.h>

#import <functional>
#import <vector>
#import <type_traits>

#import "DWriteFontBinaryDataLoader.h"
#import "DWriteFontCollectionHelper.h"
#import "DWriteFontBinaryDataCollectionLoader.h"
#import "CGDataProviderInternal.h"

using namespace Microsoft::WRL;

static const wchar_t* TAG = L"_DWriteWrapper";
static const wchar_t* c_defaultUserLanguage = L"en-us";

/**
 * Private concrete implementation of DWriteFontCollectionHelper.
 * Wraps around the system font collection.
 * Intended as a singleton.
 */
class SystemFontCollectionHelper : public DWriteFontCollectionHelper {
public:
    ComPtr<IDWriteFontCollection> GetFontCollection() {
        // Seems okay to fail-fast in this case - hard to continue without any system font collection
        ComPtr<IDWriteFactory> dwriteFactory;
        THROW_IF_FAILED(DWriteCreateFactory(DWRITE_FACTORY_TYPE_SHARED, __uuidof(IDWriteFactory), &dwriteFactory));

        ComPtr<IDWriteFontCollection> fontCollection;
        THROW_IF_FAILED(dwriteFactory->GetSystemFontCollection(&fontCollection));

        return fontCollection;
    }
};

/**
 * Private concrete implementation of DWriteFontCollectionHelper.
 * Wraps around an in-memory font collection of fonts provided by the user.
 * Intended as a singleton.
 */
class UserFontCollectionHelper : public DWriteFontCollectionHelper {
public:
    HRESULT UpdateCollection(const ComPtr<IDWriteFactory>& dwriteFactory, const ComPtr<DWriteFontBinaryDataCollectionLoader>& loader) {
        std::lock_guard<std::recursive_mutex> lock(m_lock);

        // DWrite won't create a new font collection unless we provide a new key each time
        // So every time we modify the font collection increment the key
        static size_t s_collectionKey = 0;

        RETURN_IF_FAILED(
            dwriteFactory->CreateCustomFontCollection(loader.Get(), &(++s_collectionKey), sizeof(s_collectionKey), &m_fontCollection));
        // TODO #1374: Can reduce this to only update new/remove old fonts,
        // rather than leaving the whole map to regenerate
        m_propertiesMap.reset();

        return S_OK;
    }

    ComPtr<IDWriteFontCollection> GetFontCollection() {
        return m_fontCollection;
    }
    ComPtr<IDWriteFontCollection> m_fontCollection;
};

// Private helper which returns the singleton DWriteFontCollectionHelper for the system font collection.
static std::shared_ptr<SystemFontCollectionHelper> __GetSystemFontCollectionHelper() {
    // Function-local static for lazy initialization
    static auto s_systemFontCollection = std::make_shared<SystemFontCollectionHelper>();
    return s_systemFontCollection;
}

// Private helper which returns the singleton DWriteFontCollectionHelper for the user font collection.
static std::shared_ptr<UserFontCollectionHelper> __GetUserFontCollectionHelper() {
    // Function-local static for lazy initialization
    static auto s_userFontCollection = std::make_shared<UserFontCollectionHelper>();
    return s_userFontCollection;
}

// Private helper, wraps around GetUserDefaultLocaleName() and returns a default of "en-us" if it fails
static inline const wchar_t* __GetUserDefaultLocaleName(wchar_t* buf, size_t bufferSize) {
    int defaultLocaleSuccess = GetUserDefaultLocaleName(buf, bufferSize);
    return defaultLocaleSuccess ? buf : c_defaultUserLanguage;
}

/**
 * Helper method to convert IDWriteLocalizedStrings object to CFString object.
 *
 * @parameter localizedString IDWriteLocalizedStrings object to convert.
 *
 * @return CFString object.
 */
CFStringRef _CFStringFromLocalizedString(IDWriteLocalizedStrings* localizedString, CFStringRef* actualLanguage) {
    if (localizedString == NULL) {
        TraceError(TAG, L"The input parameter is invalid!");
        return nullptr;
    }

    wchar_t localeBuffer[LOCALE_NAME_MAX_LENGTH];
    const wchar_t* localeName = __GetUserDefaultLocaleName(localeBuffer, LOCALE_NAME_MAX_LENGTH);

    uint32_t index = 0;
    BOOL exists = FALSE;

    RETURN_NULL_IF_FAILED(localizedString->FindLocaleName(localeName, &index, &exists));
    if (!exists) {
        RETURN_NULL_IF_FAILED(localizedString->FindLocaleName(c_defaultUserLanguage, &index, &exists));
    }

    // If the specified locale doesn't exist, select the first on the list.
    if (!exists) {
        index = 0;
    }

    if (actualLanguage) {
        RETURN_NULL_IF_FAILED(localizedString->GetLocaleName(index, localeBuffer, LOCALE_NAME_MAX_LENGTH));
        *actualLanguage = CFStringCreateWithCharacters(nullptr, (const UniChar*)localeBuffer, wcslen(localeBuffer));
    }

    // Get the string length.
    uint32_t length = 0;
    RETURN_NULL_IF_FAILED(localizedString->GetStringLength(index, &length));

    // Get the string. Use length + 1 here as GetString requires room for the null terminator.
    std::unique_ptr<wchar_t, decltype(&free)> wcharString(static_cast<wchar_t*>(malloc(sizeof(wchar_t) * (length + 1))), free);
    RETURN_NULL_IF_FAILED(localizedString->GetString(index, wcharString.get(), length + 1));

    // Strip out unnecessary null terminator
    return (CFStringRef)CFAutorelease(CFStringCreateWithCharactersNoCopy(kCFAllocatorDefault,
                                                                         reinterpret_cast<UniChar*>(wcharString.release()),
                                                                         length,
                                                                         kCFAllocatorDefault));
}

/**
 * Helper that parses a font name, and returns appropriate weight, stretch, style, and family name values
 */
std::shared_ptr<const _DWriteFontProperties> _DWriteGetFontPropertiesFromName(CFStringRef fontName) {
    woc::unique_cf<CFStringRef> upperFontName(_CFStringCreateUppercaseCopy(fontName));

    const auto& info = __GetSystemFontCollectionHelper()->GetFontPropertiesFromUppercaseFontName(upperFontName);
    if (info) {
        return info;
    }

    const auto& userFontInfo = __GetUserFontCollectionHelper()->GetFontPropertiesFromUppercaseFontName(upperFontName);
    if (userFontInfo) {
        return userFontInfo;
    }

    return std::make_shared<const _DWriteFontProperties>();
}

HRESULT _DWriteGetAllFonts(std::vector<ComPtr<IDWriteFont>>& outList) {
    RETURN_IF_FAILED(__GetSystemFontCollectionHelper()->GetAvailableFonts(outList));
    std::vector<ComPtr<IDWriteFont>> userFonts;
    RETURN_IF_FAILED(__GetUserFontCollectionHelper()->GetAvailableFonts(userFonts));
    outList.insert(outList.end(), userFonts.cbegin(), userFonts.cend());
    return S_OK;
}

/**
 * Helper method to retrieve font family names installed in the system.
 *
 * @return Array of font family name strings that are installed in the system.
 */
CFArrayRef _DWriteCopyFontFamilyNames() {
    CFMutableArrayRef ret = __GetSystemFontCollectionHelper()->CopyFontFamilyNames();

    woc::unique_cf<CFArrayRef> userFamilyNames{ __GetUserFontCollectionHelper()->CopyFontFamilyNames() };
    CFArrayAppendArray(ret, userFamilyNames.get(), { 0, CFArrayGetCount(userFamilyNames.get()) });

    return ret;
}

/**
 * Helper method to retrieve names of individual fonts under a font family.
 */
CFArrayRef _DWriteCopyFontNamesForFamilyName(CFStringRef familyName) {
    CFMutableArrayRef ret = __GetSystemFontCollectionHelper()->CopyFontNamesForFamilyName(familyName);

    woc::unique_cf<CFArrayRef> userFontNames{ __GetUserFontCollectionHelper()->CopyFontNamesForFamilyName(familyName) };
    CFArrayAppendArray(ret, userFontNames.get(), { 0, CFArrayGetCount(userFontNames.get()) });
    return ret;
}

/**
 * Helper method that maps a font name to the name of its family.
 *
 * Note: This function currently uses a cache, meaning that fonts installed during runtime will not be reflected,
 * unless registered to the user font collection
 */
CFStringRef _DWriteGetXamlCompatibleFamilyName(CFStringRef fontName, IDWriteFontFace* fontFace) {
    woc::unique_cf<CFStringRef> upperFontName(_CFStringCreateUppercaseCopy(fontName));

    const auto& info = __GetSystemFontCollectionHelper()->GetFontPropertiesFromUppercaseFontName(upperFontName);
    if (info) {
        return info->familyName.get();
    }

    const auto& userFontInfo = __GetUserFontCollectionHelper()->GetFontPropertiesFromUppercaseFontName(upperFontName);
    if (userFontInfo) {
        RETURN_RESULT_IF(!fontFace, userFontInfo->familyName.get());

        // Retrieve the font file that was used to create this font face
        UINT32 fileCount;
        RETURN_RESULT_IF_FAILED(fontFace->GetFiles(&fileCount, nullptr), userFontInfo->familyName.get());
        RETURN_RESULT_IF(fileCount == 0, userFontInfo->familyName.get());
        if (fileCount > 1) {
            TraceWarning(TAG, L"The font has %d files, defaulting to the first file found", fileCount);

            // Set fileCount to 1 so we just get the first file
            fileCount = 1;
        }

        ComPtr<IDWriteFontFile> fontFile;
        RETURN_RESULT_IF_FAILED(fontFace->GetFiles(&fileCount, &fontFile), userFontInfo->familyName.get());

        // Get the CGDataProvider used to register this font
        // Note that GetReferenceKey will set fontProvider to a pointer to the file's internal CGDataProviderRef
        CGDataProviderRef* fontProvider = nullptr;
        UINT32 keySize;
        RETURN_RESULT_IF_FAILED(fontFile->GetReferenceKey((const void**)&fontProvider, &keySize), userFontInfo->familyName.get());
        RETURN_RESULT_IF(keySize != sizeof(fontProvider) || !fontProvider || !(*fontProvider), userFontInfo->familyName.get());

        // From the CGDataProvider get the URL
        CFURLRef fontURL = _CGDataProviderGetURL(*fontProvider);
        RETURN_RESULT_IF(!fontURL, userFontInfo->familyName.get());

        // Now construct the XAML compatible family name, which should be in the format
        // ms-appx:///[PATH TO FONT FILE]/font_file.ttf#family_name
        static const CFStringRef sc_format = CFSTR("ms-appx:///%@#%@");
        auto path = woc::MakeAutoCF<CFStringRef>(CFURLCopyFileSystemPath(fontURL, kCFURLWindowsPathStyle));
        auto ret =
            woc::MakeAutoCF<CFStringRef>(CFStringCreateWithFormat(nullptr, nullptr, sc_format, path.get(), userFontInfo->familyName.get()));
        return (CFStringRef)CFAutorelease(ret.detach());
    }

    return nullptr;
}

/**
 * Helper that creates a IDWriteFontFamily object for a given family name
 */
HRESULT _DWriteCreateFontFamilyWithName(CFStringRef familyName, IDWriteFontFamily** outFontFamily) {
    const auto& familyNameUnichars = Strings::VectorFromCFString(familyName);

    HRESULT result =
        __GetSystemFontCollectionHelper()->CreateFontFamilyWithName(reinterpret_cast<const wchar_t*>(familyNameUnichars.data()),
                                                                    outFontFamily);
    if (result != S_FALSE) {
        return result;
    }

    // S_FALSE represents 'not found'
    // No unexpected failure occurred, just couldn't find in the system font collection
    // Try the user font collection
    result = __GetUserFontCollectionHelper()->CreateFontFamilyWithName(reinterpret_cast<const wchar_t*>(familyNameUnichars.data()),
                                                                       outFontFamily);
    if (result != S_FALSE) {
        return result;
    }

    // Family name could not be found
    return E_INVALIDARG;
}

/**
 * Helper function that creates an IDWriteFont object for a given font name.
 */
HRESULT _DWriteCreateFontWithName(CFStringRef name, IDWriteFont** outFont) {
    // Parse the font name for font weight, stretch, and style
    // Eg: Bold, Condensed, Light, Italic
    std::shared_ptr<const _DWriteFontProperties> properties = _DWriteGetFontPropertiesFromName(name);

    // Need to be able to load fonts from the app's bundle
    // For now return a default font to avoid crashes in case of missing fonts
    if (!properties->familyName.get()) {
        name = CFSTR("Segoe UI");
        properties = _DWriteGetFontPropertiesFromName(name);
    }

    RETURN_HR_IF_NULL(E_INVALIDARG, properties->familyName.get());

    ComPtr<IDWriteFontFamily> fontFamily;
    RETURN_IF_FAILED(_DWriteCreateFontFamilyWithName(properties->familyName.get(), &fontFamily));
    RETURN_HR_IF_NULL(E_INVALIDARG, fontFamily);

    return fontFamily->GetFirstMatchingFont(properties->weight, properties->stretch, properties->style, outFont);
}

/**
 * Helper function that creates an IDWriteFontFace object for a given font name.
 */
HRESULT _DWriteCreateFontFaceWithName(CFStringRef name, IDWriteFontFace** outFontFace) {
    ComPtr<IDWriteFont> font;
    RETURN_IF_FAILED(_DWriteCreateFontWithName(name, &font));
    return font->CreateFontFace(outFontFace);
}

/**
 * Helper function that creates an IDWriteFontFormat object for a given font name.
 */
HRESULT _DWriteCreateTextFormatWithFontNameAndSize(CFStringRef optionalFontName, CGFloat fontSize, IDWriteTextFormat** outTextFormat) {
    RETURN_HR_IF_NULL(E_POINTER, outTextFormat);

    ComPtr<IDWriteFactory> dwriteFactory;
    RETURN_IF_FAILED(DWriteCreateFactory(DWRITE_FACTORY_TYPE_SHARED, __uuidof(IDWriteFactory), &dwriteFactory));

    ComPtr<IDWriteTextFormat> textFormat;
    std::shared_ptr<const _DWriteFontProperties> info;
    std::shared_ptr<const _DWriteFontProperties> userFontInfo;

    if (!optionalFontName) {
        info = std::make_shared<const _DWriteFontProperties>();
    } else {
        woc::unique_cf<CFStringRef> upperFontName(_CFStringCreateUppercaseCopy(optionalFontName));
        info = __GetSystemFontCollectionHelper()->GetFontPropertiesFromUppercaseFontName(upperFontName);
        userFontInfo = __GetUserFontCollectionHelper()->GetFontPropertiesFromUppercaseFontName(upperFontName);
    }

    wchar_t localeBuffer[LOCALE_NAME_MAX_LENGTH];
    const wchar_t* localeName = __GetUserDefaultLocaleName(localeBuffer, LOCALE_NAME_MAX_LENGTH);

    if (info) {
        RETURN_IF_FAILED(
            dwriteFactory->CreateTextFormat(reinterpret_cast<wchar_t*>(Strings::VectorFromCFString(info->familyName.get()).data()),
                                            nullptr,
                                            info->weight,
                                            info->style,
                                            info->stretch,
                                            fontSize,
                                            localeName,
                                            &textFormat));
    }

    // Try creating with the user font collection if creating with the system collection wasn't possible
    if (!textFormat && userFontInfo) {
        RETURN_IF_FAILED(
            dwriteFactory->CreateTextFormat(reinterpret_cast<wchar_t*>(Strings::VectorFromCFString(userFontInfo->familyName.get()).data()),
                                            __GetUserFontCollectionHelper()->GetFontCollection().Get(),
                                            userFontInfo->weight,
                                            userFontInfo->style,
                                            userFontInfo->stretch,
                                            fontSize,
                                            localeName,
                                            &textFormat));
    }

    RETURN_HR_IF_NULL(E_INVALIDARG, textFormat);

    *outTextFormat = textFormat.Detach();
    return S_OK;
}

/**
 * Gets an informational string as a CFString from a DWrite font face.
 */
CFStringRef _DWriteFontCopyInformationalString(const ComPtr<IDWriteFontFace>& fontFace,
                                               DWRITE_INFORMATIONAL_STRING_ID informationalStringId,
                                               CFStringRef* actualLanguage) {
    RETURN_NULL_IF(!fontFace);

    ComPtr<IDWriteFontFace3> dwriteFontFace3;
    RETURN_NULL_IF_FAILED(fontFace.As(&dwriteFontFace3));

    ComPtr<IDWriteLocalizedStrings> name;
    BOOL exists;

    RETURN_NULL_IF_FAILED(dwriteFontFace3->GetInformationalStrings(informationalStringId, &name, &exists));
    return exists ? static_cast<CFStringRef>(CFRetain(_CFStringFromLocalizedString(name.Get(), actualLanguage))) : nullptr;
}

/**
 * Gets a font table as a CFDataRef from a DWrite font face
 */
CFDataRef _DWriteFontCopyTable(const ComPtr<IDWriteFontFace>& fontFace, uint32_t tag) {
    const void* tableData;
    uint32_t tableSize;
    void* tableContext;
    BOOL exists;

    RETURN_NULL_IF_FAILED(fontFace->TryGetFontTable(_CTToDWriteFontTableTag(tag), &tableData, &tableSize, &tableContext, &exists));
    RETURN_NULL_IF(!exists);

    // Copy the font table's binary data to a CFDataRef
    woc::unique_cf<CFDataRef> ret(CFDataCreate(kCFAllocatorDefault, reinterpret_cast<const byte*>(tableData), tableSize));

    // As part of the contact for TryGetFontTable, tableContext must always be released via ReleaseFontTable
    if (tableContext) {
        fontFace->ReleaseFontTable(tableContext);
    }

    return ret.release();
}

/**
 * Helper function that gets the slant angle, in degrees, from a DWrite font face.
 */
CGFloat _DWriteFontGetSlantDegrees(const ComPtr<IDWriteFontFace>& fontFace) {
    ComPtr<IDWriteFontFace1> fontFace1;
    if (FAILED(fontFace.As(&fontFace1))) {
        return 0;
    }

    DWRITE_CARET_METRICS caretMetrics;
    fontFace1->GetCaretMetrics(&caretMetrics);
    if (caretMetrics.slopeRun && caretMetrics.slopeRise) {
        CGFloat riseOverRun = static_cast<CGFloat>(caretMetrics.slopeRise) / static_cast<CGFloat>(caretMetrics.slopeRun);
        return (atan(riseOverRun) * 180 / M_PI) - 90.0f; // Degrees returned by this function must be negative
    } else {
        // Avoid dividing by 0, skip math for dividing with 0
        return -0.0f;
    }
}

/**
 * Gets the accumulated bounding box of all the glyphs in a DWrite font face, as a CGRect
 * Returns in terms of design units
 */
CGRect _DWriteFontGetBoundingBox(const ComPtr<IDWriteFontFace>& fontFace) {
    ComPtr<IDWriteFontFace1> fontFace1;
    if (FAILED(fontFace.As(&fontFace1))) {
        return {};
    }

    DWRITE_FONT_METRICS1 fontMetrics;
    fontFace1->GetMetrics(&fontMetrics);

    // Convert from DWrite font metrics, which is in terms of top, left, right, and bottom,
    // to CGRect, which is in terms of origin and size.
    CGRect ret;
    ret.origin.x = fontMetrics.glyphBoxLeft;
    ret.origin.y = fontMetrics.glyphBoxBottom;
    ret.size.width = fontMetrics.glyphBoxRight - fontMetrics.glyphBoxLeft;
    ret.size.height = fontMetrics.glyphBoxTop - fontMetrics.glyphBoxBottom;

    return ret;
}

/**
 * Gets individual bounding boxes for specific glyphs in a DWrite font face, as a CGRect
 * Returns in terms of design units
 */
HRESULT _DWriteFontGetBoundingBoxesForGlyphs(
    const ComPtr<IDWriteFontFace>& fontFace, const CGGlyph* glyphs, CGRect* boundingRects, size_t count, bool isSideways) {
    std::vector<DWRITE_GLYPH_METRICS> glyphMetrics(count);

    HRESULT ret = fontFace->GetDesignGlyphMetrics(glyphs, count, glyphMetrics.data(), isSideways);
    RETURN_IF_FAILED(ret);

    // Convert from DWRITE_GLYPH_METRICS to CGRect
    std::transform(glyphMetrics.begin(), glyphMetrics.end(), boundingRects, [](DWRITE_GLYPH_METRICS metrics) {
        CGRect rect;
        rect.origin.x = metrics.leftSideBearing;

        // generally cast the unsigned advance width/height to signed to avoid underflow issues
        rect.origin.y = metrics.verticalOriginY - static_cast<int32_t>(metrics.advanceHeight) + metrics.bottomSideBearing;
        rect.size.width = static_cast<int32_t>(metrics.advanceWidth) - (metrics.leftSideBearing + metrics.rightSideBearing);
        rect.size.height = static_cast<int32_t>(metrics.advanceHeight) - (metrics.bottomSideBearing + metrics.topSideBearing);

        return rect;
    });

    return ret;
}

// TLambda is a member function of our FontCollectionLoader which updates the internal state of the loader
// TLambda :: (DWriteFontCollectionLoader -> CFArrayRef -> CFArrayRef*) -> HRESULT
template <typename TLambda>
static HRESULT __DWriteUpdateUserCreatedFontCollection(CFArrayRef datas, CFArrayRef* errors, TLambda&& func) {
    ComPtr<IDWriteFactory> dwriteFactory;
    RETURN_IF_FAILED(DWriteCreateFactory(DWRITE_FACTORY_TYPE_SHARED, __uuidof(IDWriteFactory), &dwriteFactory));

    // Create singleton Font Collection loader, which will be shared for registering/unregistering fonts
    static ComPtr<DWriteFontBinaryDataCollectionLoader> s_loader;
    static HRESULT s_loaderCreationResult = [](DWriteFontBinaryDataCollectionLoader** collectionLoader) {
        ComPtr<IDWriteFactory> dwriteFactory;
        RETURN_IF_FAILED(DWriteCreateFactory(DWRITE_FACTORY_TYPE_SHARED, __uuidof(IDWriteFactory), &dwriteFactory));
        RETURN_IF_FAILED(MakeAndInitialize<DWriteFontBinaryDataCollectionLoader>(collectionLoader));
        RETURN_IF_FAILED(dwriteFactory->RegisterFontCollectionLoader(*collectionLoader));
        return S_OK;
    }(&s_loader);
    RETURN_IF_FAILED(s_loaderCreationResult);

    // Call member function to update loader's font data
    // Still want to update font collection with whatever fonts succeeded, so return ret at end
    HRESULT ret = func(s_loader.Get(), datas, errors);

    // Update the user font collection
    RETURN_IF_FAILED(__GetUserFontCollectionHelper()->UpdateCollection(dwriteFactory, s_loader));

    return ret;
}

// Registers user defined fonts to a collection so they can be created later
// Expects datas to be array of CFDataRefs, errors to be out pointer to array of CFErrorRef
HRESULT _DWriteRegisterFontsWithDatas(CFArrayRef datas, CFArrayRef* errors) {
    return __DWriteUpdateUserCreatedFontCollection(datas, errors, std::mem_fn(&DWriteFontBinaryDataCollectionLoader::AddDatas));
}

// Unregisters user defined fonts to a collection so they can be created later
// Expects datas to be array of CFDataRefs, errors to be out pointer to array of CFErrorRef
HRESULT _DWriteUnregisterFontsWithDatas(CFArrayRef datas, CFArrayRef* errors) {
    return __DWriteUpdateUserCreatedFontCollection(datas, errors, std::mem_fn(&DWriteFontBinaryDataCollectionLoader::RemoveDatas));
}

/**
 * Creates an IDWriteFontFace by attempting to use a CFDataRef as a font file
 */
HRESULT _DWriteCreateFontFaceWithData(CGDataProviderRef data, IDWriteFontFace** outFontFace) {
    ComPtr<IDWriteFactory> dwriteFactory;
    RETURN_IF_FAILED(DWriteCreateFactory(DWRITE_FACTORY_TYPE_SHARED, __uuidof(IDWriteFactory), &dwriteFactory));

    ComPtr<IDWriteFontFileLoader> dwriteDataLoader;
    RETURN_IF_FAILED(MakeAndInitialize<DWriteFontBinaryDataLoader>(&dwriteDataLoader, data));

    RETURN_IF_FAILED(dwriteFactory->RegisterFontFileLoader(dwriteDataLoader.Get()));

    HRESULT createdFont = [&dwriteFactory, &dwriteDataLoader, outFontFace]() {
        ComPtr<IDWriteFontFile> fontFile;

        // First two params are not used (see DWriteFontBinaryDataLoader::CreateStreamFromKey())
        // However, CreateCustomFontFileReference throws E_INVALIDARG if null is passed for the first parameter
        // Pass in a pointer to an arbitrary, unused key, to get around this.
        int unusedKey;
        RETURN_IF_FAILED(dwriteFactory->CreateCustomFontFileReference(&unusedKey, sizeof(unusedKey), dwriteDataLoader.Get(), &fontFile));

        // Analyze the font file for creating a font face
        BOOL isSupportedFontType;
        DWRITE_FONT_FILE_TYPE fontFileType;
        DWRITE_FONT_FACE_TYPE fontFaceType;
        uint32_t numberOfFaces;
        RETURN_IF_FAILED(fontFile->Analyze(&isSupportedFontType, &fontFileType, &fontFaceType, &numberOfFaces));

        RETURN_HR_IF(E_INVALIDARG, !isSupportedFontType);
        RETURN_HR_IF(E_INVALIDARG, numberOfFaces == 0);

        IDWriteFontFile* fontFileArray[] = { fontFile.Get() };

        RETURN_IF_FAILED(dwriteFactory->CreateFontFace(fontFaceType,
                                                       1, // number of elements in fontFileArray
                                                       fontFileArray,
                                                       0, // Just use the first face
                                                       DWRITE_FONT_SIMULATIONS_NONE,
                                                       outFontFace));
        return S_OK;
    }();

    // Always try to unregister the font file loader, even if anything failed above
    // Just log the failure to unregister instead of failing the whole function, though -
    // Should be safe enough to continue even if this doesn't work out
    if (FAILED(dwriteFactory->UnregisterFontFileLoader(dwriteDataLoader.Get()))) {
        TraceError(TAG, L"Failed to unregister font file loader in _DWriteCreateFontFaceWithDataProvider");
    }

    RETURN_IF_FAILED(createdFont);

    return S_OK;
}
