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

#include <windows.h>
#include <TestFramework.h>
#include <memory>
#include <roapi.h>
#include <WexTestClass.h>
#include <wrl\client.h>
#include <wrl\wrappers\corewrappers.h>
#include <windows.storage.h>

#include <CoreFoundation/CoreFoundation.h>

#include "DrawingTestConfig.h"

using namespace ABI::Windows::Storage;
using namespace Microsoft::WRL;
using namespace Windows::Foundation;

Wrappers::HString GetAppDataPath() {
    Wrappers::HString toReturn;
    ComPtr<IStorageFolder> folder;
    ComPtr<IApplicationDataStatics> applicationDataStatics;
    ComPtr<IApplicationData> applicationData;
    ComPtr<IStorageItem> storageItem;

    if (FAILED(Windows::Foundation::GetActivationFactory(Wrappers::HStringReference(RuntimeClass_Windows_Storage_ApplicationData).Get(),
                                                         &applicationDataStatics))) {
        return toReturn;
    }

    if (FAILED(applicationDataStatics->get_Current(&applicationData))) {
        return toReturn;
    }

    if (FAILED(applicationData->get_LocalFolder(&folder))) {
        return toReturn;
    }

    if (FAILED(folder.As<IStorageItem>(&storageItem))) {
        return toReturn;
    }

    if (FAILED(storageItem->get_Path(toReturn.GetAddressOf()))) {
        return toReturn;
    }

    return toReturn;
}

static std::string __ModuleDirectory() {
    static std::string modulePath = GetCurrentTestDirectory();
    return modulePath;
}

static std::string __OutputDirectory() {
    static std::wstring_convert<std::codecvt_utf8_utf16<wchar_t>> converter;
    Wrappers::HString appDataDirectory = GetAppDataPath();
    return converter.to_bytes(WindowsGetStringRawBuffer(appDataDirectory.Get(), nullptr));
}

class TAEFDrawingTestConfigImpl : public DrawingTestConfigImpl {
private:
    DrawingTestMode _mode;
    std::string _outputPath;
    std::string _comparisonPath;

public:
    TAEFDrawingTestConfigImpl()
        : _mode(DrawingTestMode::Compare),
          _outputPath(__OutputDirectory()),
          _comparisonPath(GetCurrentTestDirectory() + "/data/reference") {
        static std::wstring_convert<std::codecvt_utf8_utf16<wchar_t>> converter;

        WEX::Common::String outputPath;
        WEX::TestExecution::RuntimeParameters::TryGetValue(L"out", outputPath);
        if (!outputPath.IsEmpty()) {
            _outputPath = converter.to_bytes(std::wstring(outputPath));
        }

        WEX::Common::String comparisonPath;
        WEX::TestExecution::RuntimeParameters::TryGetValue(L"compare", comparisonPath);
        if (!comparisonPath.IsEmpty()) {
            _comparisonPath = converter.to_bytes(std::wstring(comparisonPath));
        }

        WEX::Common::String generateMode;
        WEX::TestExecution::RuntimeParameters::TryGetValue(L"generate", generateMode);
        if (generateMode.CompareNoCase(L"true") == 0 || generateMode.CompareNoCase(L"yes") == 0) {
            _mode = DrawingTestMode::Generate;
        }
    }

    virtual DrawingTestMode GetMode() override {
        return _mode;
    }

    virtual std::string GetOutputPath() override {
        return _outputPath;
    }

    virtual std::string GetComparisonPath() override {
        return _comparisonPath;
    }

    virtual std::string GetResourcePath(const std::string& resource) override {
        // Using / as a path separator is valid on both Windows and OS X.
        return __ModuleDirectory() + "/data/" + resource;
    }
};

std::shared_ptr<DrawingTestConfigImpl> _configImpl;
/* static */ DrawingTestConfigImpl* DrawingTestConfig::Get() {
    return _configImpl.get();
}

BEGIN_MODULE()
MODULE_PROPERTY(L"RunAs", L"UAP")
MODULE_PROPERTY(L"UAP:AppXManifest", L"Default.AppxManifest.xml")
END_MODULE()

MODULE_SETUP(ModuleSetup) {
    if (FAILED(RoInitialize(RO_INIT_MULTITHREADED))) {
        return FALSE;
    }

    Wrappers::HString path = GetAppDataPath();
    if (path.IsValid()) {
        unsigned int rawLength;
        _wchdir(WindowsGetStringRawBuffer(path.Get(), &rawLength));
    }

    int argc = 1;
    char* argv[] = { "UnitTests" };
    testing::InitGoogleTest(&argc, argv);

    _configImpl = std::move(std::make_shared<TAEFDrawingTestConfigImpl>());

    return TRUE;
}

MODULE_CLEANUP(ModuleCleanup) {
    RoUninitialize();
    return true;
}