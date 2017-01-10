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

#import "DWriteWrapper_CoreText.h"

#import <LoggingNative.h>

using namespace Microsoft::WRL;

static const wchar_t* TAG = L"_DWriteWrapper_CTFont";

// Represents a mapping between multiple representations of the same font weight across DWrite and CoreText
// Some loss of precision here as CT presents fewer values than DWrite
// Note also that Thin and Ultra/Extra-Light are in opposite order in DWrite and CoreText/UIKit constants
// (However, "Thin" fonts on the reference platform have UIFontWeightUltraLight...)
static const struct {
    DWRITE_FONT_WEIGHT dwriteValue;
    CGFloat ctValue;
} c_weightMap[] = { { DWRITE_FONT_WEIGHT_THIN, kCTFontWeightUltraLight },    { DWRITE_FONT_WEIGHT_EXTRA_LIGHT, kCTFontWeightThin },
                    { DWRITE_FONT_WEIGHT_ULTRA_LIGHT, kCTFontWeightThin },   { DWRITE_FONT_WEIGHT_LIGHT, kCTFontWeightLight },
                    { DWRITE_FONT_WEIGHT_SEMI_LIGHT, kCTFontWeightLight },   { DWRITE_FONT_WEIGHT_NORMAL, kCTFontWeightRegular },
                    { DWRITE_FONT_WEIGHT_REGULAR, kCTFontWeightRegular },    { DWRITE_FONT_WEIGHT_MEDIUM, kCTFontWeightMedium },
                    { DWRITE_FONT_WEIGHT_DEMI_BOLD, kCTFontWeightSemibold }, { DWRITE_FONT_WEIGHT_SEMI_BOLD, kCTFontWeightSemibold },
                    { DWRITE_FONT_WEIGHT_BOLD, kCTFontWeightBold },          { DWRITE_FONT_WEIGHT_EXTRA_BOLD, kCTFontWeightHeavy },
                    { DWRITE_FONT_WEIGHT_ULTRA_BOLD, kCTFontWeightHeavy },   { DWRITE_FONT_WEIGHT_BLACK, kCTFontWeightBlack },
                    { DWRITE_FONT_WEIGHT_HEAVY, kCTFontWeightBlack },        { DWRITE_FONT_WEIGHT_EXTRA_BLACK, kCTFontWeightBlack },
                    { DWRITE_FONT_WEIGHT_ULTRA_BLACK, kCTFontWeightBlack } };

/**
 * Helper function that converts a DWRITE_FONT_WEIGHT into a float usable for kCTFontWeightTrait.
 */
static CGFloat __DWriteFontWeightToCT(DWRITE_FONT_WEIGHT weight) {
    for (const auto& weightMapping : c_weightMap) {
        if (weight == weightMapping.dwriteValue) {
            return weightMapping.ctValue;
        }
    }

    return kCTFontWeightRegular;
}

/**
 * Helper function that converts a kCTFontWeightTrait-eligible CGFloat into a DWRITE_FONT_WEIGHT
 */
static DWRITE_FONT_WEIGHT __CTFontWeightToDWrite(CGFloat weight) {
    for (const auto& weightMapping : c_weightMap) {
        if (weight == weightMapping.ctValue) {
            return weightMapping.dwriteValue;
        }
    }

    return DWRITE_FONT_WEIGHT_NORMAL;
}

/**
 * Helper function that converts a DWRITE_FONT_STRETCH into a float usable for kCTFontWidthTrait.
 */
static CGFloat __DWriteFontStretchToCT(DWRITE_FONT_STRETCH stretch) {
    // kCTFontWidthTrait is documented to range from -1.0 to 1.0, centered at 0,
    // with 'Condensed' fonts returning -0.2 on the reference platform
    // DWrite stretch ranges from 0-9, centered at 5

    // Reference platform lacks fonts with stretch besides 'normal' or 'condensed',
    // and it is not yet clear how these values are used
    // Do an approximate conversion for now
    return (static_cast<float>(stretch) / 10.0f) - 0.5f;
}

/**
 * Private helper that examines a traits dict, then returns a struct of DWRITE_FONT_WEIGHT, _STRETCH, _STYLE,
 * derived from that traits dict.
 *
 * Note that the name fields in the _DWriteFontProperties are left as blank
 */
static _DWriteFontProperties __DWriteFontPropertiesFromTraits(CFDictionaryRef traits) {
    _DWriteFontProperties ret = {};

    if (!traits) {
        return ret;
    }

    // kCTFontWeightTrait, kCTFontWidthTrait, kCTFontSlantTrait take precedence over symbolic traits
    CFNumberRef weightTrait = static_cast<CFNumberRef>(CFDictionaryGetValue(traits, kCTFontWeightTrait));
    CFNumberRef widthTrait = static_cast<CFNumberRef>(CFDictionaryGetValue(traits, kCTFontWidthTrait));
    CFNumberRef slantTrait = static_cast<CFNumberRef>(CFDictionaryGetValue(traits, kCTFontSlantTrait));

    CFNumberRef cfSymbolicTrait = static_cast<CFNumberRef>(CFDictionaryGetValue(traits, kCTFontSymbolicTrait));
    uint32_t symbolicTrait = cfSymbolicTrait ? _CTFontSymbolicTraitsFromCFNumber(cfSymbolicTrait) : 0;

    // Check numeric weightTrait first, otherwise defer to symbolic traits, otherwise leave as _NORMAL
    if (weightTrait) {
        CGFloat weightFloat;
        CFNumberGetValue(weightTrait, kCFNumberCGFloatType, &weightFloat);
        ret.weight = __CTFontWeightToDWrite(weightFloat);
    } else if (symbolicTrait & kCTFontBoldTrait) {
        ret.weight = DWRITE_FONT_WEIGHT_BOLD;
    }

    // Check numeric widthTrait first, otherwise defer to symbolic traits, otherwise leave as _NORMAL
    if (widthTrait) {
        CGFloat widthFloat;
        CFNumberGetValue(widthTrait, kCFNumberCGFloatType, &widthFloat);

        // Treat above 0 as expanded, below 0 as condensed
        if (widthFloat > 0) {
            ret.stretch = DWRITE_FONT_STRETCH_EXPANDED;
        } else if (widthFloat < 0) {
            ret.stretch = DWRITE_FONT_STRETCH_CONDENSED;
        }
    } else if (symbolicTrait & kCTFontExpandedTrait) {
        ret.stretch = DWRITE_FONT_STRETCH_EXPANDED;
    } else if (symbolicTrait & kCTFontCondensedTrait) {
        ret.stretch = DWRITE_FONT_STRETCH_CONDENSED;
    }

    // Check numeric slantTrait first, otherwise defer to symbolic traits, otherwise leave as _NORMAL
    if (slantTrait) {
        CGFloat slantFloat;
        CFNumberGetValue(slantTrait, kCFNumberCGFloatType, &slantFloat);

        // Treat anything above 0 as italic
        if (slantFloat > 0) {
            ret.style = DWRITE_FONT_STYLE_ITALIC;
        }
    } else if (symbolicTrait & kCTFontItalicTrait) {
        ret.style = DWRITE_FONT_STYLE_ITALIC;
    }

    return ret;
}

/**
 * Helper function to box a CTFontSymbolicTraits in a CFNumber
 */
CFNumberRef _CFNumberCreateFromSymbolicTraits(CTFontSymbolicTraits symbolicTraits) {
    // symbolic traits are an unsigned 32-bit int
    // CFNumber doesn't support unsigned ints
    // get around this by storing in a signed 64-bit int
    int64_t signedTraits = static_cast<int64_t>(symbolicTraits);
    return CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt64Type, &signedTraits);
}

/**
 * Helper function to unbox a CTFontSymbolicTraits from a CFNumber
 */
CTFontSymbolicTraits _CTFontSymbolicTraitsFromCFNumber(CFNumberRef num) {
    // symbolic traits are an unsigned 32-bit int, but were stored in a signed 64-bit int
    int64_t ret;
    CFNumberGetValue(static_cast<CFNumberRef>(num), kCFNumberSInt64Type, &ret);
    return static_cast<CTFontSymbolicTraits>(ret);
}

/**
 * Creates an IDWriteFontFace given the attributes of a CTFontDescriptor
 * Currently, font name, family name, kCTFontWeight/Slant/Width, and part of SymbolicTrait, are taken into account
 */
HRESULT _DWriteCreateFontFaceWithFontDescriptor(CTFontDescriptorRef fontDescriptor, IDWriteFontFace** fontFace) {
    woc::unique_cf<CFStringRef> fontName(static_cast<CFStringRef>(CTFontDescriptorCopyAttribute(fontDescriptor, kCTFontNameAttribute)));
    woc::unique_cf<CFStringRef> familyName(
        static_cast<CFStringRef>(CTFontDescriptorCopyAttribute(fontDescriptor, kCTFontFamilyNameAttribute)));

    // font name takes precedence
    if (fontName.get()) {
        if (familyName.get() && !CFEqual(familyName.get(), _DWriteGetFamilyNameForFontName(fontName.get()))) {
            TraceError(TAG,
                       L"Mismatched font name (kCTFontNameAttribute) and family name (kCTFontFamilyNameAttribute) in "
                       L"_DWriteCreateFontFaceWithFontDescriptor");
            return E_INVALIDARG;
        }

        // familyName is either valid for fontName, or unspecified
        // just use fontName, then
        return _DWriteCreateFontFaceWithName(fontName.get(), fontFace);
    }

    // otherwise, look at family name and other attributes
    if (familyName.get()) {
        ComPtr<IDWriteFontFamily> fontFamily;
        RETURN_IF_FAILED(_DWriteCreateFontFamilyWithName(familyName.get(), &fontFamily));
        RETURN_HR_IF_NULL(E_INVALIDARG, fontFamily);

        // Look for traits that may specify weight, stretch, style
        woc::unique_cf<CFDictionaryRef> traits(
            static_cast<CFDictionaryRef>(CTFontDescriptorCopyAttribute(fontDescriptor, kCTFontTraitsAttribute)));
        _DWriteFontProperties properties = __DWriteFontPropertiesFromTraits(traits.get());

        // Create a best matching font based on the family name and weight/stretch/style
        ComPtr<IDWriteFont> font;
        RETURN_IF_FAILED(fontFamily->GetFirstMatchingFont(properties.weight, properties.stretch, properties.style, &font));

        return font->CreateFontFace(fontFace);
    }

    TraceError(TAG, L"Must specify either kCTFontFamilyNameAttribute or kCTFontNameAttribute in font descriptor");
    return E_INVALIDARG;
}

/**
 * Helper function that reads certain properties from a DWrite font face,
 * then parses them into a dictionary suitable for kCTFontTraitsAttribute
 */
static CFDictionaryRef _DWriteFontCreateTraitsDict(const ComPtr<IDWriteFontFace>& fontFace) {
    // Get pointers for the additional FontFace interfaces
    ComPtr<IDWriteFontFace1> fontFace1;
    RETURN_NULL_IF_FAILED(fontFace.As(&fontFace1));
    ComPtr<IDWriteFontFace3> fontFace3;
    RETURN_NULL_IF_FAILED(fontFace.As(&fontFace3));

    DWRITE_FONT_WEIGHT weight = fontFace3->GetWeight();
    DWRITE_FONT_STRETCH stretch = fontFace3->GetStretch();
    DWRITE_FONT_STYLE style = fontFace3->GetStyle();

    CGFloat weightTrait = __DWriteFontWeightToCT(weight);
    CGFloat widthTrait = __DWriteFontStretchToCT(stretch);

    // kCTFontSlantTrait appears scaled to be 1.0 = 180 degrees, rather than = 30 degrees as documentation claims
    CGFloat slantTrait = _DWriteFontGetSlantDegrees(fontFace) / -180.0f; // kCTFontSlantTrait is positive for negative angles

    // symbolic traits are a bit mask - evaluate the trueness of each flag
    CTFontSymbolicTraits symbolicTraits = 0;

    if (style != DWRITE_FONT_STYLE_NORMAL) {
        symbolicTraits |= kCTFontItalicTrait;
    }

    if (weight > DWRITE_FONT_WEIGHT_MEDIUM) {
        symbolicTraits |= kCTFontBoldTrait;
    }

    if (stretch > DWRITE_FONT_STRETCH_MEDIUM) {
        symbolicTraits |= kCTFontExpandedTrait;
    } else if (stretch < DWRITE_FONT_STRETCH_NORMAL) {
        symbolicTraits |= kCTFontCondensedTrait;
    }

    if (fontFace1->IsMonospacedFont()) {
        symbolicTraits |= kCTFontMonoSpaceTrait;
    }

    if (fontFace1->HasVerticalGlyphVariants()) {
        symbolicTraits |= kCTFontVerticalTrait;
    }

    if (fontFace3->IsColorFont()) {
        symbolicTraits |= kCTFontColorGlyphsTrait;
    }

    // TODO: The symbolic traits below are poorly documented/have no clear DWrite mapping
    // kCTFontUIOptimizedTrait
    // kCTFontCompositeTrait

    // TODO: The upper 16 bits of symbolic traits describe stylistic aspects of a font, specifically its serifs,
    // such as modern, ornamental, or sans (no serifs)
    // DWrite has no such API for characterizing fonts

    // Keys and values for the final trait dictionary
    CFTypeRef traitKeys[] = { kCTFontSymbolicTrait, kCTFontWeightTrait, kCTFontWidthTrait, kCTFontSlantTrait };
    CFTypeRef traitValues[] = { CFAutorelease(_CFNumberCreateFromSymbolicTraits(symbolicTraits)),
                                CFAutorelease(CFNumberCreate(kCFAllocatorDefault, kCFNumberCGFloatType, &weightTrait)),
                                CFAutorelease(CFNumberCreate(kCFAllocatorDefault, kCFNumberCGFloatType, &widthTrait)),
                                CFAutorelease(CFNumberCreate(kCFAllocatorDefault, kCFNumberCGFloatType, &slantTrait)) };

    return CFDictionaryCreate(kCFAllocatorDefault,
                              traitKeys,
                              traitValues,
                              4,
                              &kCFTypeDictionaryKeyCallBacks,
                              &kCFTypeDictionaryValueCallBacks);
}

/**
 * Gets a name/informational string from a DWrite font face corresponding to a CTFont constant
 */
CFStringRef _DWriteFontCopyName(const ComPtr<IDWriteFontFace>& fontFace, CFStringRef nameKey) {
    if (nameKey == nullptr || fontFace == nullptr) {
        return nullptr;
    }

    DWRITE_INFORMATIONAL_STRING_ID informationalStringId;

    if (CFEqual(nameKey, kCTFontCopyrightNameKey)) {
        informationalStringId = DWRITE_INFORMATIONAL_STRING_COPYRIGHT_NOTICE;
    } else if (CFEqual(nameKey, kCTFontFamilyNameKey)) {
        informationalStringId = DWRITE_INFORMATIONAL_STRING_WIN32_FAMILY_NAMES;
    } else if (CFEqual(nameKey, kCTFontSubFamilyNameKey)) {
        informationalStringId = DWRITE_INFORMATIONAL_STRING_WIN32_SUBFAMILY_NAMES;
    } else if (CFEqual(nameKey, kCTFontStyleNameKey)) {
        ComPtr<IDWriteFontFace3> dwriteFontFace3;
        RETURN_NULL_IF_FAILED(fontFace.As(&dwriteFontFace3));
        ComPtr<IDWriteLocalizedStrings> name;
        RETURN_NULL_IF_FAILED(dwriteFontFace3->GetFaceNames(&name));
        return static_cast<CFStringRef>(CFRetain(_CFStringFromLocalizedString(name.Get())));

    } else if (CFEqual(nameKey, kCTFontUniqueNameKey)) {
        return CFStringCreateWithFormat(kCFAllocatorDefault,
                                        nullptr,
                                        CFSTR("%@ %@"),
                                        CFAutorelease(_DWriteFontCopyName(fontFace, kCTFontFullNameKey)),
                                        CFAutorelease(_DWriteFontCopyName(fontFace, kCTFontStyleNameKey)));

    } else if (CFEqual(nameKey, kCTFontFullNameKey)) {
        informationalStringId = DWRITE_INFORMATIONAL_STRING_FULL_NAME;
    } else if (CFEqual(nameKey, kCTFontVersionNameKey)) {
        informationalStringId = DWRITE_INFORMATIONAL_STRING_VERSION_STRINGS;
    } else if (CFEqual(nameKey, kCTFontPostScriptNameKey)) {
        informationalStringId = DWRITE_INFORMATIONAL_STRING_POSTSCRIPT_NAME;
    } else if (CFEqual(nameKey, kCTFontTrademarkNameKey)) {
        informationalStringId = DWRITE_INFORMATIONAL_STRING_TRADEMARK;
    } else if (CFEqual(nameKey, kCTFontManufacturerNameKey)) {
        informationalStringId = DWRITE_INFORMATIONAL_STRING_MANUFACTURER;
    } else if (CFEqual(nameKey, kCTFontDesignerNameKey)) {
        informationalStringId = DWRITE_INFORMATIONAL_STRING_DESIGNER;
    } else if (CFEqual(nameKey, kCTFontDescriptionNameKey)) {
        informationalStringId = DWRITE_INFORMATIONAL_STRING_DESCRIPTION;
    } else if (CFEqual(nameKey, kCTFontVendorURLNameKey)) {
        informationalStringId = DWRITE_INFORMATIONAL_STRING_FONT_VENDOR_URL;
    } else if (CFEqual(nameKey, kCTFontDesignerURLNameKey)) {
        informationalStringId = DWRITE_INFORMATIONAL_STRING_DESIGNER_URL;
    } else if (CFEqual(nameKey, kCTFontLicenseNameKey)) {
        informationalStringId = DWRITE_INFORMATIONAL_STRING_LICENSE_DESCRIPTION;
    } else if (CFEqual(nameKey, kCTFontLicenseURLNameKey)) {
        informationalStringId = DWRITE_INFORMATIONAL_STRING_LICENSE_INFO_URL;
    } else if (CFEqual(nameKey, kCTFontSampleTextNameKey)) {
        informationalStringId = DWRITE_INFORMATIONAL_STRING_SAMPLE_TEXT;
    } else if (CFEqual(nameKey, kCTFontPostScriptCIDNameKey)) {
        informationalStringId = DWRITE_INFORMATIONAL_STRING_POSTSCRIPT_CID_NAME;
    } else {
        informationalStringId = DWRITE_INFORMATIONAL_STRING_NONE;
    }

    return _DWriteFontCopyInformationalString(fontFace, informationalStringId);
}