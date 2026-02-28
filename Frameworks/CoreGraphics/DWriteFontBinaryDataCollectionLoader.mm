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

#import "DWriteFontBinaryDataCollectionLoader.h"
#import "DWriteFontBinaryDataLoader.h"
#import "CGDataProviderInternal.h"

#import <CoreFoundation/CFError.h>
#import <CoreText/CTFontManager.h>

using namespace Microsoft::WRL;

/**
 * Private helpers to append a CFErrorRef or nullptr to the end of a CFMutableArray if it exists
 */
static inline void __AppendErrorIfExists(CFMutableArrayRef errors, CFIndex errorCode) {
    if (errors) {
        woc::unique_cf<CFErrorRef> error{ CFErrorCreate(nullptr, kCFErrorDomainCocoa, errorCode, nullptr) };
        CFArrayAppendValue(errors, error.get());
    }
}

static inline void __AppendNullptrIfExists(CFMutableArrayRef errors) {
    if (errors) {
        CFArrayAppendValue(errors, nullptr);
    }
}

/**
 * Private class.
 * Custom implementation of IDWriteFontFileEnumerator, which enumerates over internal data and returns a font file
 */
class DWriteFontFileEnumerator : public RuntimeClass<RuntimeClassFlags<WinRtClassicComMix>, IDWriteFontFileEnumerator> {
protected:
    InspectableClass(L"Windows.Bridge.DirectWrite.DWriteFontFileEnumerator", TrustLevel::BaseTrust);

public:
    DWriteFontFileEnumerator(DWriteFontBinaryDataCollectionLoader* parent) {
        m_parent = parent;
    }

    HRESULT STDMETHODCALLTYPE GetCurrentFontFile(_Out_ IDWriteFontFile** outFontFile) {
        return m_parent->GetFontFileAt(m_iterator, outFontFile);
    }

    HRESULT STDMETHODCALLTYPE MoveNext(_Out_ BOOL* hasCurrentFile) {
        RETURN_HR_IF_NULL(E_POINTER, hasCurrentFile);
        if (m_beforeBegin) {
            m_beforeBegin = false;
            m_iterator = m_parent->GetDataBegin();
            *hasCurrentFile = (m_iterator != m_parent->GetDataEnd());
            return S_OK;
        }

        if (m_iterator == m_parent->GetDataEnd()) {
            *hasCurrentFile = FALSE;
        } else {
            m_iterator = std::next(m_iterator);
            *hasCurrentFile = (m_iterator != m_parent->GetDataEnd());
        }
        return S_OK;
    }

private:
    bool m_beforeBegin = true; // Marks the '-1' position of m_iterator. Set to false when m_iterator is set to GetDataBegin()
    decltype(std::declval<DWriteFontBinaryDataCollectionLoader>().GetDataBegin()) m_iterator;
    ComPtr<DWriteFontBinaryDataCollectionLoader> m_parent;
};

// DWriteFontBinaryDataCollectionLoader member functions

DWriteFontBinaryDataCollectionLoader::DWriteFontBinaryDataCollectionLoader() {
}

HRESULT STDMETHODCALLTYPE DWriteFontBinaryDataCollectionLoader::CreateEnumeratorFromKey(_In_ IDWriteFactory* factory,
                                                                                        _In_ const void* collectionKey,
                                                                                        _In_ UINT32 collectionKeySize,
                                                                                        _Out_ IDWriteFontFileEnumerator** enumerator) {
    *enumerator = Make<DWriteFontFileEnumerator>(this).Detach();
    return S_OK;
}

HRESULT DWriteFontBinaryDataCollectionLoader::AddDatas(CFArrayRef fontDatas, CFArrayRef* errors) {
    // Don't bother creating this array if errors is null
    CFMutableArrayRef outErrors = errors ? CFArrayCreateMutable(nullptr, 0, &kCFTypeArrayCallBacks) : nullptr;
    HRESULT ret = S_OK;

    CFIndex count = CFArrayGetCount(fontDatas);
    for (CFIndex i = 0; i < count; ++i) {
        woc::unique_cf<CGDataProviderRef> data((CGDataProviderRef)CFRetain(CFArrayGetValueAtIndex(fontDatas, i)));
        if (data.get() && _CGDataProviderGetSize(data.get()) != 0) {
            if (m_fontDatas.find(data) != m_fontDatas.end()) {
                __AppendErrorIfExists(outErrors, kCTFontManagerErrorAlreadyRegistered);
                ret = S_FALSE;
            } else {
                ComPtr<IDWriteFontFile> emptyFontFilePtr = nullptr;
                m_fontDatas.emplace(std::move(data), emptyFontFilePtr);
                __AppendNullptrIfExists(outErrors);
            }
        } else {
            __AppendErrorIfExists(outErrors, kCTFontManagerErrorInvalidFontData);
            ret = S_FALSE;
        }
    }

    if (errors) {
        *errors = outErrors;
    }

    return ret;
}

HRESULT DWriteFontBinaryDataCollectionLoader::RemoveDatas(CFArrayRef fontDatas, CFArrayRef* errors) {
    // Don't bother creating this array if errors is null
    CFMutableArrayRef outErrors = errors ? CFArrayCreateMutable(nullptr, 0, &kCFTypeArrayCallBacks) : nullptr;
    HRESULT ret = S_OK;

    CFIndex count = CFArrayGetCount(fontDatas);
    for (CFIndex i = 0; i < count; ++i) {
        woc::unique_cf<CGDataProviderRef> data((CGDataProviderRef)CFRetain(CFArrayGetValueAtIndex(fontDatas, i)));
        if (data.get() && _CGDataProviderGetSize(data.get()) != 0) {
            const auto it = m_fontDatas.find(data);
            if (it != m_fontDatas.end()) {
                m_fontDatas.erase(it);
                __AppendNullptrIfExists(outErrors);
            } else {
                __AppendErrorIfExists(outErrors, kCTFontManagerErrorNotRegistered);
                ret = S_FALSE;
            }
        } else {
            __AppendErrorIfExists(outErrors, kCTFontManagerErrorInvalidFontData);
            ret = S_FALSE;
        }
    }

    if (errors) {
        *errors = outErrors;
    }

    return ret;
}

decltype(DWriteFontBinaryDataCollectionLoader::m_fontDatas)::iterator DWriteFontBinaryDataCollectionLoader::GetDataBegin() {
    return m_fontDatas.begin();
}

decltype(DWriteFontBinaryDataCollectionLoader::m_fontDatas)::iterator DWriteFontBinaryDataCollectionLoader::GetDataEnd() {
    return m_fontDatas.end();
}

HRESULT DWriteFontBinaryDataCollectionLoader::GetFontFileAt(decltype(m_fontDatas)::iterator it, IDWriteFontFile** outFontFile) {
    RETURN_HR_IF_NULL(E_POINTER, outFontFile);
    RETURN_HR_IF(E_BOUNDS, it == m_fontDatas.end());

    // // Create the IDWriteFontFile in the cache, if it's not already cached
    if (!it->second) {
        ComPtr<IDWriteFactory> dwriteFactory;
        RETURN_IF_FAILED(DWriteCreateFactory(DWRITE_FACTORY_TYPE_SHARED, __uuidof(IDWriteFactory), &dwriteFactory));

        ComPtr<DWriteFontBinaryDataLoader> loader;
        RETURN_IF_FAILED(MakeAndInitialize<DWriteFontBinaryDataLoader>(&loader, it->first.get()));
        RETURN_IF_FAILED(dwriteFactory->RegisterFontFileLoader(loader.Get()));

        CGDataProviderRef reference = it->first.get();
        RETURN_IF_FAILED(dwriteFactory->CreateCustomFontFileReference(&reference, sizeof(&reference), loader.Get(), &it->second));
    }

    return it->second.CopyTo(outFontFile);
}
