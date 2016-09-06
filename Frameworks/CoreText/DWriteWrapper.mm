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

// Do not move this block, it has to come first for some reason
#include <COMIncludes.h>
#import <wrl/implements.h>
#include <COMIncludes_End.h>

#import <CoreText/DWriteWrapper.h>
#import <Starboard.h>

#import <CoreFoundation/CFBase.h>
#import "CoreTextInternal.h"

#import <LoggingNative.h>
#import <vector>

using namespace std;
using namespace Microsoft::WRL;

static const wchar_t* TAG = L"_DWriteWrapper";
static const wchar_t* c_defaultUserLanguage = L"en-us";
static const wchar_t* c_defaultFontName = L"Segoe UI";

// TODO::
// These should be removed once CTFont and UIFont are bridged.
static IWLazyClassLookup s_lazyUIFont("UIFont");
static const float c_defaultSystemFontSize = 15.0f;

// Private helper for creating a DWriteFactory
static ComPtr<IDWriteFactory> __CreateDWriteFactoryInstance() {
    ComPtr<IDWriteFactory> dwriteFactory;
    THROW_IF_FAILED(DWriteCreateFactory(DWRITE_FACTORY_TYPE_SHARED, __uuidof(IDWriteFactory), &dwriteFactory));
    return dwriteFactory;
}

// Private helper for accessing a single static DWriteFactory instance
static ComPtr<IDWriteFactory> __GetDWriteFactoryInstance() {
    static ComPtr<IDWriteFactory> s_dwriteFactory = __CreateDWriteFactoryInstance();
    return s_dwriteFactory;
}

template <typename TElement>
bool __CloneArray(_In_reads_opt_(count) TElement const* source,
                  _In_ size_t count,
                  _Outptr_result_buffer_all_maybenull_(count) TElement const** result) {
    bool ret = true;

    *result = nullptr;

    if (source != nullptr) {
        TElement* array = new TElement[count];
        ret = (array != nullptr) ? true : false;
        if (ret) {
            memcpy(array, source, sizeof(TElement) * count);
            *result = array;
        }
    }

    return ret;
}

bool __CloneDWriteGlyphRun(_In_ DWRITE_GLYPH_RUN const* src, _Out_ DWRITE_GLYPH_RUN* dest) {
    bool ret = true;

    if (src) {
        dest->fontFace = src->fontFace;
        dest->fontFace->AddRef();

        dest->fontEmSize = src->fontEmSize;
        dest->glyphCount = src->glyphCount;
        dest->isSideways = src->isSideways;
        dest->bidiLevel = src->bidiLevel;

        bool ret = __CloneArray(src->glyphIndices, src->glyphCount, &dest->glyphIndices);
        if (ret) {
            ret = __CloneArray(src->glyphAdvances, src->glyphCount, &dest->glyphAdvances);
        }
        if (ret) {
            ret = __CloneArray(src->glyphOffsets, src->glyphCount, &dest->glyphOffsets);
        }
    }

    return ret;
}

/**
 * Helper method to return the user set default locale string.
 *
 * @return use set locale string as wstring.
 */
static wstring __GetUserDefaultLocaleName() {
    wchar_t localeName[LOCALE_NAME_MAX_LENGTH];
    int defaultLocaleSuccess = GetUserDefaultLocaleName(localeName, LOCALE_NAME_MAX_LENGTH);

    // If the default locale is returned, find that locale name, otherwise use "en-us".
    if (defaultLocaleSuccess) {
        return wstring(localeName);
    } else {
        return wstring(c_defaultUserLanguage);
    }
}

/**
 * Helper method to convert IDWriteLocalizedStrings object to CFString object.
 *
 * @parameter localizedString IDWriteLocalizedStrings object to convert.
 *
 * @return CFString object.
 */
static CFStringRef _CFStringFromLocalizedString(IDWriteLocalizedStrings* localizedString) {
    if (localizedString == NULL) {
        TraceError(TAG, L"The input parameter is invalid!");
        return nil;
    }

    // Get the default locale for this user.
    wstring localeName = __GetUserDefaultLocaleName();

    uint32_t index = 0;
    BOOL exists = false;

    // If the default locale is returned, find that locale name, otherwise use "en-us".
    THROW_IF_FAILED(localizedString->FindLocaleName(localeName.c_str(), &index, &exists));
    if (!exists) {
        THROW_IF_FAILED(localizedString->FindLocaleName(c_defaultUserLanguage, &index, &exists));
    }

    // If the specified locale doesn't exist, select the first on the list.
    if (!exists) {
        index = 0;
    }

    // Get the string length.
    uint32_t length = 0;
    THROW_IF_FAILED(localizedString->GetStringLength(index, &length));

    // Get the string.
    vector<wchar_t> wcharString = std::vector<wchar_t>(length + 1);
    THROW_IF_FAILED(localizedString->GetString(index, wcharString.data(), length + 1));

    // Strip out unnecessary null terminator
    return (CFStringRef)CFAutorelease(
        CFStringCreateWithCharacters(kCFAllocatorSystemDefault, reinterpret_cast<UniChar*>(wcharString.data()), wcharString.size() - 1));
}

/**
 * Helper method to create a IDWriteTextFormat object given _CTTypesetter object and string range.
 *
 * @parameter ts _CTTypesetter object.
 * @parameter range string range to consider for rendering.
 *
 * @return the created IDWriteTextFormat object.
 */
static ComPtr<IDWriteTextFormat> __CreateDWriteTextFormat(_CTTypesetter* ts, CFRange range) {
    // Get the direct write factory instance
    ComPtr<IDWriteFactory> dwriteFactory = __GetDWriteFactoryInstance();

    // TODO::
    // Get font family name details so that can be used here. For now this is hardcoded to "Gabriola".

    // Note here we only look at attribute value at first index of the specified range as we can get a default faont size to use here.
    // Per string range attribute handling will be done in _CreateDWriteTextLayout.

    // TODO: #1001 attribs can be nil here?
    NSDictionary* attribs = [ts->_attributedString attributesAtIndex:range.location effectiveRange:NULL];
    UIFont* font = [attribs objectForKey:static_cast<NSString*>(kCTFontAttributeName)];
    if (font == nil) {
        font = [s_lazyUIFont systemFontOfSize:c_defaultSystemFontSize];
    }
    float fontSize = [font pointSize];

    ComPtr<IDWriteTextFormat> textFormat;
    THROW_IF_FAILED(dwriteFactory->CreateTextFormat(c_defaultFontName,
                                                    NULL,
                                                    DWRITE_FONT_WEIGHT_REGULAR,
                                                    DWRITE_FONT_STYLE_NORMAL,
                                                    DWRITE_FONT_STRETCH_NORMAL,
                                                    fontSize,
                                                    c_defaultUserLanguage,
                                                    &textFormat));

    return textFormat;
}

// TODO::
// Create format with typesetter and range by calling into this method
/**
 * Helper method to create a IDWriteTextFormat object given NSAttributedString*
 *
 * @parameter string NSAttributedString with font attribute to use
 *
 * @return the created IDWriteTextFormat object.
 */
static ComPtr<IDWriteTextFormat> _CreateDWriteTextFormat(NSAttributedString* string) {
    // Get the direct write factory instance
    ComPtr<IDWriteFactory> dwriteFactory = GetDWriteFactoryInstance();

    // TODO::
    // Get font family name details so that can be used here. For now this is hardcoded to "Gabriola".

    // Note here we only look at attribute value at first index of the specified range as we can get a default faont size to use here.
    // Per string range attribute handling will be done in _createDWriteTextLayout.
    NSDictionary* attribs = [string attributesAtIndex:0 effectiveRange:NULL];
    UIFont* font = [attribs objectForKey:static_cast<NSString*>(kCTFontAttributeName)];
    if (font == nil) {
        font = [s_lazyUIFont systemFontOfSize:c_defaultSystemFontSize];
    }
    float fontSize = [font pointSize];

    ComPtr<IDWriteTextFormat> textFormat;
    THROW_IF_FAILED(dwriteFactory->CreateTextFormat(c_defaultFontName,
                                                    NULL,
                                                    DWRITE_FONT_WEIGHT_REGULAR,
                                                    DWRITE_FONT_STYLE_NORMAL,
                                                    DWRITE_FONT_STRETCH_NORMAL,
                                                    fontSize,
                                                    c_defaultUserLanguage,
                                                    &textFormat));

    return textFormat;
}

/**
 * Helper method to create a IDWriteTextLayout object given _CTTypesetter object, string range and frame size constrain.
 *
 * @parameter ts _CTTypesetter object.
 * @parameter range string range to consider for rendering.
 * @parameter frameSize frame constrains to render the text on.
 *
 * @return the created IDWriteTextLayout object.
 */
static ComPtr<IDWriteTextLayout> __CreateDWriteTextLayout(_CTTypesetter* ts, CFRange range, CGRect frameSize) {
    ComPtr<IDWriteTextFormat> textFormat = __CreateDWriteTextFormat(ts, range);

    // TODO::
    // Iterate through all attributed string ranges and identify attributes so they can be used to -
    //  - set indentation
    //  - set font characteristics
    //  - etc.
    //  These can be done using the DWrite IDWriteTextFormat range property methods.
    NSRange curRange = NSMakeRangeFromCF(range);
    /*
    NSDictionary* attribs = [ts->_attributedString attributesAtIndex:0 effectiveRange:&curRange];
    UIFont* font = [attribs objectForKey:static_cast<NSString*>(kCTFontAttributeName)];
    if (font == nil) {
        font = [s_lazyUIFont systemFontOfSize:c_defaultSystemFontSize];
    }
    float fontSize = [font pointSize];
    */

    wchar_t* wcharString = reinterpret_cast<wchar_t*>(
        const_cast<char*>([[ts->_string substringWithRange:curRange] cStringUsingEncoding:NSUTF16StringEncoding]));

    // TODO::
    // We need too support widthFunc semantic to be able to support NSLayout*. We could either change the API signature of this API or
    // create a new API to support dynamic width support.
    //
    // float width = widthFunc(widthParam, 0, 0, fontSize);

    // Get the direct write factory instance
    ComPtr<IDWriteFactory> dwriteFactory = __GetDWriteFactoryInstance();

    ComPtr<IDWriteTextLayout> textLayout;
    THROW_IF_FAILED(dwriteFactory->CreateTextLayout(
        wcharString, ts->_charactersLen, textFormat.Get(), frameSize.size.width, frameSize.size.height, &textLayout));

    return textLayout;
}

/**
 * Helper method to create a IDWriteTextLayout object given NSAttributedString* for creating a single line without typesetting
 *
 * @parameter string NSAttributedString* with text and attributes
 *
 * @return the created IDWriteTextLayout object.
 */
static ComPtr<IDWriteTextLayout> _CreateDWriteTextLayout(NSAttributedString* string) {
    ComPtr<IDWriteTextFormat> textFormat = _CreateDWriteTextFormat(string);

    wchar_t* wcharString = reinterpret_cast<wchar_t*>(const_cast<char*>([string.string cStringUsingEncoding:NSUTF16StringEncoding]));

    // Get the direct write factory instance
    ComPtr<IDWriteFactory> dwriteFactory = GetDWriteFactoryInstance();

    ComPtr<IDWriteTextLayout> textLayout;
    THROW_IF_FAILED(dwriteFactory->CreateTextLayout(wcharString, string.length, textFormat.Get(), FLT_MAX, FLT_MAX, &textLayout));

    // TODO::
    // Iterate through all attributed string ranges and identify attributes so they can be used to -
    //  - set indentation
    //  - set font characteristics
    //  - etc.
    //  These can be done using the DWrite IDWriteTextFormat range property methods.
    NSRange range;
    for (size_t i = 0; i < string.length; i += range.length) {
        NSDictionary* attribs = [string attributesAtIndex:i longestEffectiveRange:&range inRange:{ i, string.length - i }];
        UIFont* font = [attribs objectForKey:static_cast<NSString*>(kCTFontAttributeName)];
        if (font == nil) {
            font = [s_lazyUIFont systemFontOfSize:c_defaultSystemFontSize];
        }
        THROW_IF_FAILED(textLayout->SetFontSize([font pointSize], DWRITE_TEXT_RANGE{ range.location, range.length }));
    }
    return textLayout;
}

/**
 * Custom IDWriteTextRenderer class that captures the glyph runs generated by DWrite for the given TextLayout and TextRenderer constraints.
 */
class CustomDWriteTextRenderer : public RuntimeClass<RuntimeClassFlags<WinRtClassicComMix>, IDWriteTextRenderer> {
protected:
    InspectableClass(L"Windows.Bridge.DirectWrite", TrustLevel::BaseTrust);

public:
    CustomDWriteTextRenderer();

    HRESULT RuntimeClassInitialize();

    HRESULT STDMETHODCALLTYPE DrawGlyphRun(_In_ void* clientDrawingContext,
                                           _In_ float baselineOriginX,
                                           _In_ float baselineOriginY,
                                           DWRITE_MEASURING_MODE measuringMode,
                                           _In_ DWRITE_GLYPH_RUN const* glyphRun,
                                           _In_ DWRITE_GLYPH_RUN_DESCRIPTION const* glyphRunDescription,
                                           _In_ IUnknown* clientDrawingEffects) throw() {
        _DWriteGlyphRunDetails* glyphs = static_cast<_DWriteGlyphRunDetails*>(clientDrawingContext);

        DWRITE_GLYPH_RUN dwriteGlyphRun = {};
        __CloneDWriteGlyphRun(glyphRun, &dwriteGlyphRun);
        glyphs->_dwriteGlyphRun.push_back(dwriteGlyphRun);

        glyphs->_baselineOriginX.push_back(baselineOriginX);
        glyphs->_baselineOriginY.push_back(baselineOriginY);

        _DWriteGlyphRunDescription glyphRunDescriptionInfo;
        glyphRunDescriptionInfo._stringLength = glyphRunDescription->stringLength;
        glyphRunDescriptionInfo._textPosition = glyphRunDescription->textPosition;
        //TODO STRINGINDICES
        glyphs->_glyphRunDescriptions.push_back(glyphRunDescriptionInfo);

        return S_OK;
    };

    HRESULT STDMETHODCALLTYPE DrawUnderline(_In_ void* clientDrawingContext,
                                            _In_ float baselineOriginX,
                                            _In_ float baselineOriginY,
                                            _In_ DWRITE_UNDERLINE const* underline,
                                            _In_ IUnknown* clientDrawingEffects) throw() {
        return S_OK;
    };

    HRESULT STDMETHODCALLTYPE DrawStrikethrough(_In_ void* clientDrawingContext,
                                                _In_ float baselineOriginX,
                                                _In_ float baselineOriginY,
                                                _In_ DWRITE_STRIKETHROUGH const* strikethrough,
                                                _In_ IUnknown* clientDrawingEffects) throw() {
        return S_OK;
    };

    HRESULT STDMETHODCALLTYPE DrawInlineObject(_In_ void* clientDrawingContext,
                                               _In_ float originX,
                                               _In_ float originY,
                                               _In_ IDWriteInlineObject* inlineObject,
                                               _In_ BOOL isSideways,
                                               _In_ BOOL isRightToLeft,
                                               _In_ IUnknown* clientDrawingEffects) throw() {
        return S_OK;
    };

    HRESULT STDMETHODCALLTYPE IsPixelSnappingDisabled(_In_opt_ void* clientDrawingContext, _Out_ BOOL* isDisabled) throw() {
        *isDisabled = FALSE;
        return S_OK;
    };

    HRESULT STDMETHODCALLTYPE GetCurrentTransform(_In_opt_ void* clientDrawingContext, _Out_ DWRITE_MATRIX* transform) throw() {
        return S_OK;
    };

    HRESULT STDMETHODCALLTYPE GetPixelsPerDip(_In_opt_ void* clientDrawingContext, _Out_ float* pixelsPerDip) throw() {
        *pixelsPerDip = 1.0;
        return S_OK;
    };
};

CustomDWriteTextRenderer::CustomDWriteTextRenderer() {
}

HRESULT CustomDWriteTextRenderer::RuntimeClassInitialize() {
    return S_OK;
}

/**
 * Helper method that will create a TextLayout and TextRenderer object with the given _CTTypesetter object, string range and frame size
 * to render to.
 *
 * @parameter ts _CTTypesetter object.
 * @parameter range string range to consider for rendering.
 * @parameter frameSize frame constrains to render the text on.
 * @parameter glyphDetails pointer to the _DWriteGlyphRunDetails object that contains the glyph run details that was rendeered.
 */
static void __GetGlyphRunDetails(_CTTypesetter* ts, CFRange range, CGRect frameSize, _DWriteGlyphRunDetails* glyphDetails) {
    ComPtr<IDWriteTextLayout> textLayout = __CreateDWriteTextLayout(ts, range, frameSize);
    ComPtr<CustomDWriteTextRenderer> textRenderer = Make<CustomDWriteTextRenderer>();
    textLayout->Draw(glyphDetails, textRenderer.Get(), 0, 0);
}

/**
<<<<<<< 30ea1a26b7958aabec8324626dcc35d7242eeaf7
=======
 * Helper method that will create a TextLayout and TextRenderer object with the given _CTTypesetter object, string range and frame size
 * to render to.
 *
 * @parameter string NSAttributedString* with text and attributes for styling
 * @parameter glyphDetails pointer to the _DWriteGlyphRunDetails object that contains the glyph run details that was rendeered.
 */
static void _GetGlyphRunDetails(NSAttributedString* string, _DWriteGlyphRunDetails* glyphDetails) {
    ComPtr<IDWriteTextLayout> textLayout = _CreateDWriteTextLayout(string);
    ComPtr<CustomDWriteTextRenderer> textRenderer = Make<CustomDWriteTextRenderer>();
    textLayout->Draw(glyphDetails, textRenderer.Get(), 0, 0);
}

/**
 * Helper method to retrieve font fmaly names installed in the system.
 *
 * @return Unmutable array of font family name strings that are installed in the system.
 */
static NSArray<NSString*>* _DWriteGetFamilyNames() {
    NSMutableArray<NSString*>* fontFamilyNames = [NSMutableArray<NSString*> array];

    // Get the direct write factory instance
    ComPtr<IDWriteFactory> dwriteFactory = GetDWriteFactoryInstance();

    // Get the system font collection.
    ComPtr<IDWriteFontCollection> fontCollection;
    THROW_IF_FAILED(dwriteFactory->GetSystemFontCollection(&fontCollection));

    // Get the number of font families in the collection.
    uint32_t count = 0;
    count = fontCollection->GetFontFamilyCount();

    for (uint32_t i = 0; i < count; ++i) {
        // Get the font family.
        ComPtr<IDWriteFontFamily> fontFamily;
        THROW_IF_FAILED(fontCollection->GetFontFamily(i, &fontFamily));

        // Get a list of localized strings for the family name.
        ComPtr<IDWriteLocalizedStrings> familyNames;
        THROW_IF_FAILED(fontFamily->GetFamilyNames(&familyNames));

        [fontFamilyNames addObject:_ConvertLocalizedStringToNSString(familyNames.Get())];
    }

    return [fontFamilyNames autorelease];
}

/**
 * Helper method to create _CTLine object given a CFAttributedStringRef
 *
 * @parameter string CFAttributedStringRef containing text and styling
 *
 * @return Unmutable array of _CTLine objects created with the requested parameters.
 */
static _CTLine* _DWriteGetLine(CFAttributedStringRef string) {
    _CTLine* line = [_CTLine new];
    line->_runs = [NSMutableArray new];
    NSAttributedString* attrString = static_cast<NSAttributedString*>(string);
    if (attrString.length == 0) {
        return line;
    }

    // Call custom renderer to get all glyph run details
    _DWriteGlyphRunDetails glyphRunDetails;
    _GetGlyphRunDetails(attrString, &glyphRunDetails);

    line->_width = 0;
    line->_strRange = CFRangeMake(0, attrString.length);
    for (CFIndex i = 0; i < glyphRunDetails._glyphRuns.size(); ++i) {
        _CTRun* run = [[_CTRun new] autorelease];
        run->_range.location = glyphRunDetails._glyphRunDescriptions[i]._textPosition;
        run->_range.length = glyphRunDetails._glyphRunDescriptions[i]._stringLength;
        run->_xPos = glyphRunDetails._baselineOriginX[i];
        run->_yPos = glyphRunDetails._baselineOriginY[i];
        run->_stringFragment = [attrString.string substringWithRange:NSMakeRangeFromCF(run->_range)];
        run->_attributes = [attrString attributesAtIndex:run->_range.location effectiveRange:NULL];
        run->_glyphAdvances = move(glyphRunDetails._glyphRuns[i]._glyphAdvances);

        // TODO::
        // This is a temp workaround until we can have actual glyph origins
        for (auto i : run->_glyphAdvances) {
            run->_glyphOrigins.emplace_back(CGPoint{ line->_width + i.width, 0 });
            line->_width += i.width;
        }

        run->_stringIndices = move(glyphRunDetails._glyphRunDescriptions[i]._clusterMap);

        // TODO::
        // This is a temp workaround until we use DWrite fonts
        // run->_glyphs = move(glyphRunDetails._glyphRuns[i]._glyphIndices);
        id font = [run->_attributes objectForKey:static_cast<NSString*>(kCTFontAttributeName)];
        if (font == nil) {
            font = [s_lazyUIFont systemFontOfSize:c_defaultSystemFontSize];
            [run->_attributes setObject:font forKey:static_cast<NSString*>(kCTFontAttributeName)];
        }
        run->_glyphs.resize(run->_range.length);
        std::vector<WORD> characters(run->_range.length);
        [run->_stringFragment getCharacters:characters.data()];
        CTFontGetGlyphsForCharacters(static_cast<CTFontRef>(font), characters.data(), run->_glyphs.data(), run->_range.length);

        [line->_runs addObject:run];
    }

    return line;
}

/**
>>>>>>> Implement CTLineCreateWithAttributedString, CTRunGetGlyphs, CTRun GetPtr functions, and add CTLine tests
 * Helper method to create _CTLine objects given a _CTTypesetter, attributed string range to use and frame size to fit in.
 *
 * @parameter ts _CTTypesetter object to use.
 * @parameter range attributed string range to use.
 * @parameter frameSize size parameters of the frame to fit the text into.
 *
 * @return Unmutable array of _CTLine objects created with the requested parameters.
 */
static NSArray<_CTLine*>* _DWriteGetLines(_CTTypesetter* ts, CFRange range, CGRect frameSize) {
    NSMutableArray<_CTLine*>* lines = [NSMutableArray array];
    if (range.length == 0) {
        return lines;
    }
<<<<<<< 30ea1a26b7958aabec8324626dcc35d7242eeaf7

=======
>>>>>>> Implement CTLineCreateWithAttributedString, CTRunGetGlyphs, CTRun GetPtr functions, and add CTLine tests
    // Call custom renderer to get all glyph run details
    _DWriteGlyphRunDetails glyphRunDetails = {};
    __GetGlyphRunDetails(ts, range, frameSize, &glyphRunDetails);

    // Create _CTLine objects from the the obtained glyph run details
    int numOfGlyphRuns = glyphRunDetails._dwriteGlyphRun.size();
    int i = 0;
    int j = 0;

<<<<<<< 30ea1a26b7958aabec8324626dcc35d7242eeaf7
    // Relative offsets for each run and line that will be used by CTLineDraw and CTRunDRaw methods to render.
    float prevXPosForDraw = 0;
    float prevYPosForDraw = 0;

=======
>>>>>>> Implement CTLineCreateWithAttributedString, CTRunGetGlyphs, CTRun GetPtr functions, and add CTLine tests
    while (j < numOfGlyphRuns) {
        _CTLine* line = [[_CTLine new] autorelease];
        NSMutableArray<_CTRun*>* runs = [NSMutableArray array];
        uint32_t stringRange = 0;
        prevXPosForDraw = 0;

        float xPos;
        float yPos;

        // Glyph runs that have the same _baselineOriginY value are part of the the same Line.
        while ((j < numOfGlyphRuns) && (glyphRunDetails._baselineOriginY[i] == glyphRunDetails._baselineOriginY[j])) {
            j++;
        }
        while (i < j) {
            // Create _CTRun objects and make them part of _CTLine
            _CTRun* run = [[_CTRun new] autorelease];
            run->_range.location = glyphRunDetails._glyphRunDescriptions[i]._textPosition;
            run->_range.length = glyphRunDetails._glyphRunDescriptions[i]._stringLength;
            run->_stringFragment = [ts->_string substringWithRange:NSMakeRangeFromCF(run->_range)];
            run->_dwriteGlyphRun = move(glyphRunDetails._dwriteGlyphRun[i]);
            run->_attributes = [ts->_attributedString attributesAtIndex:run->_range.location effectiveRange:NULL];
<<<<<<< 30ea1a26b7958aabec8324626dcc35d7242eeaf7

            xPos = glyphRunDetails._baselineOriginX[i];
            yPos = glyphRunDetails._baselineOriginY[i];

            // Calculate the relative offset of each glyph run and store it. This will be useful while drawing individual glpyh runs or
            // lines.
            run->_relativeXOffset = xPos - prevXPosForDraw;
            run->_relativeYOffset = yPos - prevYPosForDraw;
            prevXPosForDraw = xPos;

            // TODO::
            // This is a temp workaround until we can have actual glyph origins
            run->_glyphOrigins.emplace_back(CGPoint{ xPos, yPos });
            for (int index = 0; index < glyphRunDetails._dwriteGlyphRun[i].glyphCount - 1; index++) {
                run->_glyphOrigins.emplace_back(CGPoint{ xPos + glyphRunDetails._dwriteGlyphRun[i].glyphAdvances[index], yPos });
                xPos += glyphRunDetails._dwriteGlyphRun[i].glyphAdvances[index];
                line->_width += glyphRunDetails._dwriteGlyphRun[i].glyphAdvances[index];
=======
            run->_glyphAdvances = move(glyphRunDetails._glyphRuns[i]._glyphAdvances);
            run->_stringIndices = move(glyphRunDetails._glyphRunDescriptions[i]._clusterMap);
            // TODO::
            // This is a temp workaround until we use DWrite fonts
            // run->_glyphs = move(glyphRunDetails._glyphRuns[i]._glyphIndices);
            id font = [run->_attributes objectForKey:static_cast<NSString*>(kCTFontAttributeName)];
            if (font == nil) {
                font = [s_lazyUIFont systemFontOfSize:c_defaultSystemFontSize];
                [run->_attributes setObject:font forKey:static_cast<NSString*>(kCTFontAttributeName)];
            }
            run->_glyphs.resize(glyphRunDetails._glyphRuns[i]._glyphIndices.size());
            std::vector<WORD> characters(run->_range.length);
            [run->_stringFragment getCharacters:characters.data()];
            CTFontGetGlyphsForCharacters(static_cast<CTFontRef>(font), characters.data(), run->_glyphs.data(), run->_range.length);

            // TODO::
            // This is a temp workaround until we can have actual glyph origins
            for (auto i : run->_glyphAdvances) {
                run->_glyphOrigins.emplace_back(CGPoint{ line->_width + i.width, 0 });
                line->_width += i.width;
>>>>>>> Implement CTLineCreateWithAttributedString, CTRunGetGlyphs, CTRun GetPtr functions, and add CTLine tests
            }

            [runs addObject:run];
            stringRange += run->_range.length;
            i++;
        }

        prevYPosForDraw = yPos;

        line->_runs = runs;
        line->_strRange.location = static_cast<_CTRun*>(line->_runs[0])->_range.location;
        line->_lineOrigin.x = static_cast<_CTRun*>(line->_runs[0])->_glyphOrigins[0].x;
        line->_lineOrigin.y = static_cast<_CTRun*>(line->_runs[0])->_glyphOrigins[0].y;
        line->_strRange.length = stringRange;
        line->_relativeXOffset = static_cast<_CTRun*>(line->_runs[0])->_relativeXOffset;
        line->_relativeYOffset = static_cast<_CTRun*>(line->_runs[0])->_relativeYOffset;
        [lines addObject:line];
    }

    return lines;
}

/**
 * Helper method to retrieve font family names installed in the system.
 *
 * @return Unmutable array of font family name strings that are installed in the system.
 */
static CFArrayRef _DWriteGetFontFamilyNames() {
    CFMutableArrayRef fontFamilyNames = CFArrayCreateMutable(kCFAllocatorSystemDefault, 0, &kCFTypeArrayCallBacks);
    CFAutorelease(fontFamilyNames);

    // Get the direct write factory instance
    ComPtr<IDWriteFactory> dwriteFactory = __GetDWriteFactoryInstance();

    // Get the system font collection.
    ComPtr<IDWriteFontCollection> fontCollection;
    THROW_IF_FAILED(dwriteFactory->GetSystemFontCollection(&fontCollection));

    // Get the number of font families in the collection.
    uint32_t count = 0;
    count = fontCollection->GetFontFamilyCount();

    for (uint32_t i = 0; i < count; ++i) {
        // Get the font family.
        ComPtr<IDWriteFontFamily> fontFamily;
        THROW_IF_FAILED(fontCollection->GetFontFamily(i, &fontFamily));

        // Get a list of localized strings for the family name.
        ComPtr<IDWriteLocalizedStrings> familyNames;
        THROW_IF_FAILED(fontFamily->GetFamilyNames(&familyNames));

        CFStringRef name = _CFStringFromLocalizedString(familyNames.Get());
        if (CFStringGetLength(name) == 0) {
            TraceError(TAG, L"Failed to convert the localized string to wide string.");
            return fontFamilyNames;
        }

        CFArrayAppendValue(fontFamilyNames, name);
    }

    return fontFamilyNames;
}

/**
 * Helper method to retrieve names of individual fonts under a font family.
 */
CFArrayRef _DWriteGetFontNamesForFamilyName(CFStringRef familyName) {
    CFMutableArrayRef fontNames = CFArrayCreateMutable(kCFAllocatorSystemDefault, 0, &kCFTypeArrayCallBacks);
    CFAutorelease(fontNames);

    ComPtr<IDWriteFactory> dwriteFactory = __GetDWriteFactoryInstance();

    // Get the system font collection.
    ComPtr<IDWriteFontCollection> fontCollection;
    THROW_IF_FAILED(dwriteFactory->GetSystemFontCollection(&fontCollection));

    // Get the font family.
    size_t index = 0;
    BOOL exists = false;

    CFIndex familyNameLength = CFStringGetLength(familyName);
    std::vector<UniChar> unicharFamilyName(familyNameLength + 1);
    CFStringGetCharacters(familyName, CFRangeMake(0, familyNameLength), unicharFamilyName.data());

    THROW_IF_FAILED(fontCollection->FindFamilyName(reinterpret_cast<wchar_t*>(unicharFamilyName.data()), &index, &exists));
    if (!exists) {
        TraceError(TAG, L"Failed to find the font family name.");
        return fontNames;
    }

    ComPtr<IDWriteFontFamily> fontFamily;
    THROW_IF_FAILED(fontCollection->GetFontFamily(index, &fontFamily));

    ComPtr<IDWriteFontList> fontList;
    THROW_IF_FAILED(
        fontFamily->GetMatchingFonts(DWRITE_FONT_WEIGHT_THIN, DWRITE_FONT_STRETCH_UNDEFINED, DWRITE_FONT_STYLE_NORMAL, &fontList));

    size_t count = fontList->GetFontCount();

    for (size_t i = 0; i < count; i++) {
        ComPtr<IDWriteFont> font;
        THROW_IF_FAILED(fontList->GetFont(i, &font));

        ComPtr<IDWriteLocalizedStrings> fullName;
        BOOL exist = FALSE;
        THROW_IF_FAILED(font->GetInformationalStrings(DWRITE_INFORMATIONAL_STRING_FULL_NAME, &fullName, &exist));

        if (exist) {
            CFStringRef name = _CFStringFromLocalizedString(fullName.Get());
            if (CFStringGetLength(name) == 0) {
                TraceError(TAG, L"Failed to convert the localized string to wide string.");
                return fontNames;
            }

            CFArrayAppendValue(fontNames, name);
        }
    }

    return fontNames;
}

/**
 * Helper method that maps a font name to the name of its family.
 *
 * Note: This function currently uses a cache, meaning that fonts installed during runtime will not be reflected
 */
CFStringRef _DWriteGetFamilyNameForFontName(CFStringRef fontName) {
    static CFDictionaryRef fontToFamilyMap = nullptr;

    static dispatch_once_t initOnce = 0;
    dispatch_once(&initOnce,
                  ^{
                      // initialize fontToFamilyMap
                      CFMutableDictionaryRef initMap = CFDictionaryCreateMutable(kCFAllocatorSystemDefault,
                                                                                 0,
                                                                                 &kCFTypeDictionaryKeyCallBacks,
                                                                                 &kCFTypeDictionaryValueCallBacks);
                      CFAutorelease(initMap);

                      CFArrayRef familyNames = _DWriteGetFontFamilyNames();

                      for (size_t i = 0; i < CFArrayGetCount(familyNames); ++i) {
                          CFStringRef familyName = static_cast<CFStringRef>(CFArrayGetValueAtIndex(familyNames, i));
                          CFArrayRef fontNames = _DWriteGetFontNamesForFamilyName(familyName);

                          for (size_t j = 0; j < CFArrayGetCount(fontNames); j++) {
                              CFDictionaryAddValue(initMap, static_cast<CFStringRef>(CFArrayGetValueAtIndex(fontNames, j)), familyName);
                          }
                      }

                      fontToFamilyMap = CFDictionaryCreateCopy(kCFAllocatorSystemDefault, initMap);
                  });

    return static_cast<CFStringRef>(CFDictionaryGetValue(fontToFamilyMap, fontName));
}

/**
 * Private helper that acquires an IDWriteFontFamily object for a given family name
 */
static ComPtr<IDWriteFontFamily> __GetDWriteFontFamily(CFStringRef familyName) {
    ComPtr<IDWriteFontFamily> fontFamily;

    ComPtr<IDWriteFactory> factory = __GetDWriteFactoryInstance();

    ComPtr<IDWriteFontCollection> systemFontCollection;
    THROW_IF_FAILED(factory->GetSystemFontCollection(&systemFontCollection));

    CFIndex familyNameLength = CFStringGetLength(familyName);
    std::vector<UniChar> unicharFamilyName(familyNameLength + 1);
    CFStringGetCharacters(familyName, CFRangeMake(0, familyNameLength), unicharFamilyName.data());

    size_t fontFamilyIndex;
    BOOL fontFamilyExists;

    THROW_IF_FAILED(systemFontCollection->FindFamilyName(reinterpret_cast<const wchar_t*>(unicharFamilyName.data()),
                                                         &fontFamilyIndex,
                                                         &fontFamilyExists));

    if (!fontFamilyExists) {
        TraceError(TAG, L"Unable to find font family \"%ws\"", unicharFamilyName.data());
        return fontFamily;
    }

    THROW_IF_FAILED(systemFontCollection->GetFontFamily(fontFamilyIndex, &fontFamily));
    return fontFamily;
}

/**
 * Private helper that parses a font name, and returns appropriate weight, stretch, and style values for DWrite accordingly
 */
static void __InitDWriteFontPropertiesFromName(CFStringRef fontName,
                                               DWRITE_FONT_WEIGHT* weight,
                                               DWRITE_FONT_STRETCH* stretch,
                                               DWRITE_FONT_STYLE* style) {
    // Set some defaults for when weight/stretch/style are not mentioned in the name
    // Since this is a file-private helper, assume the pointers are safe to dereference.
    *weight = DWRITE_FONT_WEIGHT_NORMAL;
    *stretch = DWRITE_FONT_STRETCH_NORMAL;
    *style = DWRITE_FONT_STYLE_NORMAL;

    CFStringRef familyName = _DWriteGetFamilyNameForFontName(fontName);

    // Relationship of family name -> font name not always consistent
    // Usually, properties are added to the end (eg: Arial -> Arial Narrow Bold)
    // However, this is not always the case (eg: Eras ITC -> Eras Bold ITC)
    // In addition, some fonts with properties are occasionally placed into their own family (eg: Segoe WP SemiLight -> Segoe WP SemiLight)
    // Try to be more prudent about these edge cases, by looking only at the difference between the font name and family name
    CFArrayRef fontNameTokens = CFStringCreateArrayBySeparatingStrings(kCFAllocatorDefault, fontName, CFSTR(" "));
    CFAutorelease(fontNameTokens);
    CFMutableSetRef propertyTokens = CFSetCreateMutable(kCFAllocatorDefault, 0, &kCFTypeSetCallBacks);
    CFAutorelease(propertyTokens);

    for (size_t i = 0; i < CFArrayGetCount(fontNameTokens); ++i) {
        CFSetAddValue(propertyTokens, CFArrayGetValueAtIndex(fontNameTokens, i));
    }

    if (familyName) {
        CFArrayRef familyNameTokens = CFStringCreateArrayBySeparatingStrings(kCFAllocatorDefault, familyName, CFSTR(" "));
        CFAutorelease(familyNameTokens);
        for (size_t i = 0; i < CFArrayGetCount(familyNameTokens); ++i) {
            CFSetRemoveValue(propertyTokens, CFArrayGetValueAtIndex(familyNameTokens, i));
        }
    }

    // Store weight, stretch, and style in a single struct to be passed into a CFSetApplierFunction's context
    struct PropertyContext {
        DWRITE_FONT_WEIGHT* weight;
        DWRITE_FONT_STRETCH* stretch;
        DWRITE_FONT_STYLE* style;
    };

    struct PropertyContext propertyContext = { weight, stretch, style };

    CFSetApplierFunction initPropertyFromToken = [](const void* value, void* context) {
        CFMutableStringRef propertyToken = CFStringCreateMutableCopy(kCFAllocatorDefault, 0, static_cast<CFStringRef>(value));
        struct PropertyContext* pPropertyContext = reinterpret_cast<struct PropertyContext*>(context);

        // Font names are not always consistent about capitalization (SemiLight vs Semilight)
        // Standardize on uppercase
        CFStringUppercase(propertyToken, CFLocaleGetSystem());

        // Possible optimization here that can be done by using a dictionary to functions,
        // but seems excessive given that font names generally don't have more than three modifiers
        if (CFEqual(propertyToken, CFSTR("THIN"))) {
            *pPropertyContext->weight = DWRITE_FONT_WEIGHT_THIN;
        } else if (CFEqual(propertyToken, CFSTR("EXTRALIGHT"))) {
            *pPropertyContext->weight = DWRITE_FONT_WEIGHT_EXTRA_LIGHT;
        } else if (CFEqual(propertyToken, CFSTR("ULTRALIGHT"))) {
            *pPropertyContext->weight = DWRITE_FONT_WEIGHT_ULTRA_LIGHT;
        } else if (CFEqual(propertyToken, CFSTR("LIGHT"))) {
            *pPropertyContext->weight = DWRITE_FONT_WEIGHT_LIGHT;
        } else if (CFEqual(propertyToken, CFSTR("SEMILIGHT"))) {
            *pPropertyContext->weight = DWRITE_FONT_WEIGHT_SEMI_LIGHT;
            // skip since this is the default
            // } else if (CFEqual(propertyToken, CFSTR("NORMAL"))) {
            //     *pPropertyContext->weight = DWRITE_FONT_WEIGHT_NORMAL;
        } else if (CFEqual(propertyToken, CFSTR("REGULAR"))) {
            *pPropertyContext->weight = DWRITE_FONT_WEIGHT_REGULAR;
        } else if (CFEqual(propertyToken, CFSTR("MEDIUM"))) {
            *pPropertyContext->weight = DWRITE_FONT_WEIGHT_MEDIUM;
        } else if (CFEqual(propertyToken, CFSTR("DEMIBOLD"))) {
            *pPropertyContext->weight = DWRITE_FONT_WEIGHT_DEMI_BOLD;
        } else if (CFEqual(propertyToken, CFSTR("SEMIBOLD"))) {
            *pPropertyContext->weight = DWRITE_FONT_WEIGHT_SEMI_BOLD;
        } else if (CFEqual(propertyToken, CFSTR("BOLD"))) {
            *pPropertyContext->weight = DWRITE_FONT_WEIGHT_BOLD;
        } else if (CFEqual(propertyToken, CFSTR("EXTRABOLD"))) {
            *pPropertyContext->weight = DWRITE_FONT_WEIGHT_EXTRA_BOLD;
        } else if (CFEqual(propertyToken, CFSTR("ULTRABOLD"))) {
            *pPropertyContext->weight = DWRITE_FONT_WEIGHT_ULTRA_BOLD;
        } else if (CFEqual(propertyToken, CFSTR("BLACK"))) {
            *pPropertyContext->weight = DWRITE_FONT_WEIGHT_BLACK;
        } else if (CFEqual(propertyToken, CFSTR("HEAVY"))) {
            *pPropertyContext->weight = DWRITE_FONT_WEIGHT_HEAVY;
        } else if (CFEqual(propertyToken, CFSTR("EXTRABLACK"))) {
            *pPropertyContext->weight = DWRITE_FONT_WEIGHT_EXTRA_BLACK;
        } else if (CFEqual(propertyToken, CFSTR("ULTRABLACK"))) {
            *pPropertyContext->weight = DWRITE_FONT_WEIGHT_ULTRA_BLACK;

        } else if (CFEqual(propertyToken, CFSTR("UNDEFINED"))) {
            *pPropertyContext->stretch = DWRITE_FONT_STRETCH_UNDEFINED;
        } else if (CFEqual(propertyToken, CFSTR("ULTRACONDENSED"))) {
            *pPropertyContext->stretch = DWRITE_FONT_STRETCH_ULTRA_CONDENSED;
        } else if (CFEqual(propertyToken, CFSTR("EXTRACONDENSED"))) {
            *pPropertyContext->stretch = DWRITE_FONT_STRETCH_EXTRA_CONDENSED;
        } else if (CFEqual(propertyToken, CFSTR("CONDENSED")) || CFEqual(propertyToken, CFSTR("NARROW"))) {
            *pPropertyContext->stretch = DWRITE_FONT_STRETCH_CONDENSED;
        } else if (CFEqual(propertyToken, CFSTR("SEMICONDENSED"))) {
            *pPropertyContext->stretch = DWRITE_FONT_STRETCH_SEMI_CONDENSED;
            // skip since this is the default
            // } else if (CFEqual(propertyToken, CFSTR("NORMAL"))) {
            //     *pPropertyContext->stretch = DWRITE_FONT_STRETCH_NORMAL;
        } else if (CFEqual(propertyToken, CFSTR("MEDIUM"))) {
            *pPropertyContext->stretch = DWRITE_FONT_STRETCH_MEDIUM;
        } else if (CFEqual(propertyToken, CFSTR("SEMIEXPANDED"))) {
            *pPropertyContext->stretch = DWRITE_FONT_STRETCH_SEMI_EXPANDED;
        } else if (CFEqual(propertyToken, CFSTR("EXPANDED"))) {
            *pPropertyContext->stretch = DWRITE_FONT_STRETCH_EXPANDED;
        } else if (CFEqual(propertyToken, CFSTR("EXTRAEXPANDED"))) {
            *pPropertyContext->stretch = DWRITE_FONT_STRETCH_EXTRA_EXPANDED;
        } else if (CFEqual(propertyToken, CFSTR("ULTRAEXPANDED"))) {
            *pPropertyContext->stretch = DWRITE_FONT_STRETCH_ULTRA_EXPANDED;

            // skip since this is the default
            // } else if (CFEqual(propertyToken, CFSTR("NORMAL"))) {
            //     *pPropertyContext->style = DWRITE_FONT_STYLE_NORMAL;
        } else if (CFEqual(propertyToken, CFSTR("OBLIQUE"))) {
            *pPropertyContext->style = DWRITE_FONT_STYLE_OBLIQUE;
        } else if (CFEqual(propertyToken, CFSTR("ITALIC"))) {
            *pPropertyContext->style = DWRITE_FONT_STYLE_ITALIC;
        }
    };

    CFSetApplyFunction(propertyTokens, initPropertyFromToken, &propertyContext);
}

/**
 * Helper function that creates an IDWriteFontFace object for a given font name.
 */
HRESULT _DWriteCreateFontFaceWithName(CFStringRef name, IDWriteFontFace** outFontFace) {
    // Parse the font name for font weight, stretch, and style
    // Eg: Bold, Condensed, Light, Italic
    DWRITE_FONT_WEIGHT weight = DWRITE_FONT_WEIGHT_NORMAL;
    DWRITE_FONT_STRETCH stretch = DWRITE_FONT_STRETCH_NORMAL;
    DWRITE_FONT_STYLE style = DWRITE_FONT_STYLE_NORMAL;

    __InitDWriteFontPropertiesFromName(name, &weight, &stretch, &style);

    CFStringRef familyName = _DWriteGetFamilyNameForFontName(name);
    if (!familyName) {
        TraceError(TAG, L"Unable to find family for font name \"%hs\"", [static_cast<NSString*>(name) UTF8String]);
        return E_INVALIDARG;
    }

    ComPtr<IDWriteFontFamily> fontFamily = __GetDWriteFontFamily(familyName);
    if (!fontFamily) {
        TraceError(TAG, L"Unable to find family for font name \"%hs\"", [static_cast<NSString*>(name) UTF8String]);
        return E_INVALIDARG;
    }

    ComPtr<IDWriteFont> font;
    HRESULT hr = fontFamily->GetFirstMatchingFont(weight, stretch, style, &font);
    if (FAILED(hr)) {
        TraceError(TAG, L"Unable to create font for name \"%hs\"", [static_cast<NSString*>(name) UTF8String]);
        return hr;
    }

    return font->CreateFontFace(outFontFace);
}