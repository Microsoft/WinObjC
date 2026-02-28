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

#import <vector>
#import <algorithm>
#include <TestFramework.h>
#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <Security/SecItem.h>

// (Security internal)
#import "GenericPasswordItemHandler.h"

#include "COMIncludes.h"
#import <wrl/implements.h>
#import <Windows.Security.Credentials.h>
#include "COMIncludes_End.h"

using namespace Microsoft::WRL;
using namespace winrt::Windows::Security::Credentials;
namespace WFC = winrt::Windows::Foundation::Collections;
namespace ABIWFC = ABI::Windows::Foundation::Collections;
namespace ABIWSC = ABI::Windows::Security::Credentials;
namespace RtABIWSC = winrt::ABI::Windows::Security::Credentials;

class MockVault : public RuntimeClass<RuntimeClassFlags<WinRt>, ABIWSC::IPasswordVault> {
public:

    STDMETHODIMP Add(ABIWSC::IPasswordCredential* cred) override {
        auto abiPtr = reinterpret_cast<RtABIWSC::IPasswordCredential*>(cred);
        PasswordCredential credential = nullptr;
        winrt::copy_from_abi(credential, abiPtr);

        credentialList.push_back(credential);
        return S_OK;
    }

    STDMETHODIMP Remove(ABIWSC::IPasswordCredential* cred) override {
        auto abiPtr = reinterpret_cast<RtABIWSC::IPasswordCredential*>(cred);
        PasswordCredential credential = nullptr;
        winrt::copy_from_abi(credential, abiPtr);

        auto it = std::find(credentialList.begin(), credentialList.end(), credential);

        if (it != credentialList.end()) {
            credentialList.erase(it);
        }

        return S_OK;
    }

    STDMETHODIMP Retrieve(HSTRING resource, HSTRING userName, ABIWSC::IPasswordCredential** cred) override {
        *cred = nullptr;
        return S_OK;
    }

    STDMETHODIMP FindAllByResource(HSTRING resource, ABIWFC::IVectorView<ABIWSC::PasswordCredential*>** credentials) override {
        *credentials = nullptr;
        return S_OK;
    }

    STDMETHODIMP FindAllByUserName(HSTRING userName, ABIWFC::IVectorView<ABIWSC::PasswordCredential*>** credentials) override {
        *credentials = nullptr;
        return S_OK;
    }

    STDMETHODIMP RetrieveAll(ABIWFC::IVectorView<ABIWSC::PasswordCredential*>** credentials) override {
        // Convert credentialList to IVector
        auto credVector = winrt::single_threaded_vector<PasswordCredential>(std::vector<PasswordCredential>(credentialList));

        // Detach ABI pointer
        winrt::abi<WFC::IVectorView<PasswordCredential>>* abiPtr = winrt::detach_abi(credVector.GetView());
        *credentials = reinterpret_cast<ABIWFC::IVectorView<ABIWSC::PasswordCredential*>*>(abiPtr);
        return S_OK;
    }

    static PasswordVault GetInstance() {
        PasswordVault vault = nullptr;
        ComPtr<MockVault> mockVault = Make<MockVault>();

        RtABIWSC::IPasswordVault* abiPtr =
            reinterpret_cast<RtABIWSC::IPasswordVault*>(
                static_cast<ABIWSC::IPasswordVault*>(mockVault.Detach()));

        winrt::attach_abi(vault, abiPtr);
        return vault;
    }

private:
    std::vector<PasswordCredential> credentialList;
};


TEST(Security, GenericPasswordHandler_Add) {
    GenericPasswordItemHandler* handler = [[GenericPasswordItemHandler alloc] initWithVault:MockVault::GetInstance()];

    // First try to add the credential.
    NSString* mockPassword = @"fak3Passw0rd";

    NSDictionary* dictionary = @{
        (__bridge id)(kSecClass) : (__bridge id)(kSecClassGenericPassword),
        (__bridge id)(kSecAttrAccount) : @"fakeAccount@fakeEmail.com",
        (__bridge id)(kSecAttrService) : @"www.fakeWebService.com",
        (__bridge id)(kSecValueData) : [mockPassword dataUsingEncoding:NSUTF8StringEncoding],
        (__bridge id)(kSecReturnAttributes) : (__bridge id)kCFBooleanTrue,
    };

    id idOutDictionary;
    [handler add:dictionary withResult:&idOutDictionary];

    NSDictionary* outDictionary = static_cast<NSDictionary*>(idOutDictionary);

    // Make sure that the returned attributes match what is set. NOTE: normally
    // extra read only attributes like creation time would have been added. This
    // is not possible with the current WinRT apis.
    ASSERT_OBJCEQ((__bridge id)(kSecClassGenericPassword), [outDictionary objectForKey:(__bridge id)(kSecClass)]);
    ASSERT_OBJCEQ(@"fakeAccount@fakeEmail.com", [outDictionary objectForKey:(__bridge id)(kSecAttrAccount)]);
    ASSERT_OBJCEQ(@"www.fakeWebService.com", [outDictionary objectForKey:(__bridge id)(kSecAttrService)]);

    [outDictionary release];
    [handler release];
}

TEST(Security, GenericPasswordHandler_AddEmpty) {
    GenericPasswordItemHandler* handler = [[GenericPasswordItemHandler alloc] initWithVault:MockVault::GetInstance()];

    // First try to add the credential.
    NSString* mockPassword = @"fak3Passw0rd";

    // Go Crazy and have empty username and service.
    NSDictionary* dictionary = @{
        (__bridge id)(kSecClass) : (__bridge id)(kSecClassGenericPassword),
        (__bridge id)(kSecAttrService) : @"",
        (__bridge id)(kSecValueData) : [mockPassword dataUsingEncoding:NSUTF8StringEncoding],
        (__bridge id)(kSecReturnAttributes) : (__bridge id)kCFBooleanTrue,
    };

    id idOutDictionary;
    [handler add:dictionary withResult:&idOutDictionary];

    NSDictionary* outDictionary = static_cast<NSDictionary*>(idOutDictionary);

    // Make sure that the returned attributes match what is set. NOTE: normally
    // extra read only attributes like creation time would have been added. This
    // is not possible with the current WinRT apis.
    ASSERT_OBJCEQ(@"", [outDictionary objectForKey:(__bridge id)(kSecAttrService)]);
    ASSERT_OBJCEQ((__bridge id)(kSecClassGenericPassword), [outDictionary objectForKey:(__bridge id)(kSecClass)]);

    [outDictionary release];
    [handler release];
}

TEST(Security, GenericPasswordHandler_Query) {
    GenericPasswordItemHandler* handler = [[GenericPasswordItemHandler alloc] initWithVault:MockVault::GetInstance()];

    // First try to add the credentials.
    NSString* mockPassword1 = @"fak3Passw0rd1";
    NSString* mockPassword2 = @"fak3Passw0rd2";
    NSString* mockPassword3 = @"fak3Passw0rd3";

    NSDictionary* credential1 = @{
        (__bridge id)(kSecClass) : (__bridge id)(kSecClassGenericPassword),
        (__bridge id)(kSecAttrAccount) : @"fakeAccount@fakeEmail.com",
        (__bridge id)(kSecAttrService) : @"www.fakeWebService.com",
        (__bridge id)(kSecValueData) : [mockPassword1 dataUsingEncoding:NSUTF8StringEncoding],
        (__bridge id)(kSecReturnAttributes) : (__bridge id)kCFBooleanTrue,
    };

    NSDictionary* credential2 = @{
        (__bridge id)(kSecClass) : (__bridge id)(kSecClassGenericPassword),
        (__bridge id)(kSecAttrAccount) : @"fakeAccount@fakeEmail.com",
        (__bridge id)(kSecAttrService) : @"www.ADifferentFakeWebService.com",
        (__bridge id)(kSecValueData) : [mockPassword2 dataUsingEncoding:NSUTF8StringEncoding],
        (__bridge id)(kSecReturnAttributes) : (__bridge id)kCFBooleanTrue,
    };

    NSDictionary* credential3 = @{
        (__bridge id)(kSecClass) : (__bridge id)(kSecClassGenericPassword),
        (__bridge id)(kSecAttrAccount) : @"ADifferentFakeAccount@fakeEmail.com",
        (__bridge id)(kSecAttrService) : @"www.fakeWebService.com",
        (__bridge id)(kSecValueData) : [mockPassword3 dataUsingEncoding:NSUTF8StringEncoding],
        (__bridge id)(kSecReturnAttributes) : (__bridge id)kCFBooleanTrue,
    };

    [handler add:credential1 withResult:nullptr];
    [handler add:credential2 withResult:nullptr];
    [handler add:credential3 withResult:nullptr];

    // Now that its added go ahead and query. Start with a basic query for the info set.
    NSDictionary* attrQuery1 = @{
        (__bridge id)(kSecClass) : (__bridge id)(kSecClassGenericPassword),
        (__bridge id)(kSecAttrService) : @"www.fakeWebService.com",
        (__bridge id)(kSecReturnAttributes) : (__bridge id)kCFBooleanTrue,
        (__bridge id)(kSecMatchLimit) : (__bridge id)kSecMatchLimitOne,
    };

    // limit one specified so just go directly to dictionary.
    NSDictionary* attributes;
    ASSERT_EQ(errSecSuccess, [handler query:attrQuery1 withResult:&attributes]);

    // Make sure that the returned attributes match what is set.
    // Note that this assumes return order is the same as add order which isn't necessarily true
    // but will be for the mock.
    ASSERT_OBJCEQ((__bridge id)(kSecClassGenericPassword), [attributes objectForKey:(__bridge id)(kSecClass)]);
    ASSERT_OBJCEQ(@"fakeAccount@fakeEmail.com", [attributes objectForKey:(__bridge id)(kSecAttrAccount)]);
    ASSERT_OBJCEQ(@"www.fakeWebService.com", [attributes objectForKey:(__bridge id)(kSecAttrService)]);

    [attributes release];

    // Query for the second item in the vault.
    NSDictionary* attrQuery2 = @{
        (__bridge id)(kSecClass) : (__bridge id)(kSecClassGenericPassword),
        (__bridge id)(kSecAttrService) : @"www.ADifferentFakeWebService.com",
        (__bridge id)(kSecReturnAttributes) : (__bridge id)kCFBooleanTrue,
        (__bridge id)(kSecMatchLimit) : (__bridge id)kSecMatchLimitOne,
    };

    // limit one specified so just go directly to dictionary.
    ASSERT_EQ(errSecSuccess, [handler query:attrQuery2 withResult:&attributes]);

    // Make sure that the returned attributes match what is set.
    ASSERT_OBJCEQ((__bridge id)(kSecClassGenericPassword), [attributes objectForKey:(__bridge id)(kSecClass)]);
    ASSERT_OBJCEQ(@"fakeAccount@fakeEmail.com", [attributes objectForKey:(__bridge id)(kSecAttrAccount)]);
    ASSERT_OBJCEQ(@"www.ADifferentFakeWebService.com", [attributes objectForKey:(__bridge id)(kSecAttrService)]);

    [attributes release];

    // Now query for password data and match multiple
    NSDictionary* dataQuery1 = @{
        (__bridge id)(kSecClass) : (__bridge id)(kSecClassGenericPassword),
        (__bridge id)(kSecAttrAccount) : @"fakeAccount@fakeEmail.com",
        (__bridge id)(kSecReturnData) : (__bridge id)kCFBooleanTrue,
        (__bridge id)(kSecMatchLimit) : (__bridge id)kSecMatchLimitAll,
    };

    NSArray* outArray;
    ASSERT_EQ(errSecSuccess, [handler query:dataQuery1 withResult:&outArray]);
    ASSERT_EQ(2, [outArray count]);

    // Note that this assumes return order is the same as add order which isn't necessarily true
    // but will be for the mock.
    ASSERT_OBJCEQ([mockPassword1 dataUsingEncoding:NSUTF8StringEncoding], [outArray objectAtIndex:0]);
    ASSERT_OBJCEQ([mockPassword2 dataUsingEncoding:NSUTF8StringEncoding], [outArray objectAtIndex:1]);

    [outArray release];
    outArray = nil;

    // Query for something not there.
    NSDictionary* attrQuery3 = @{
        (__bridge id)(kSecClass) : (__bridge id)(kSecClassGenericPassword),
        (__bridge id)(kSecAttrService) : @"www.aNonExistentWebService.com",
        (__bridge id)(kSecReturnAttributes) : (__bridge id)kCFBooleanTrue,
        (__bridge id)(kSecMatchLimit) : (__bridge id)kSecMatchLimitOne,
    };

    ASSERT_EQ(errSecItemNotFound, [handler query:attrQuery3 withResult:&outArray]);
    ASSERT_EQ(nil, outArray);

    [handler release];
}

TEST(Security, GenericPasswordHandler_Update) {
    GenericPasswordItemHandler* handler = [[GenericPasswordItemHandler alloc] initWithVault:MockVault::GetInstance()];

    // First try to add the credential.
    NSString* mockPassword = @"fak3Passw0rd";

    NSDictionary* dictionary = @{
        (__bridge id)(kSecClass) : (__bridge id)(kSecClassGenericPassword),
        (__bridge id)(kSecAttrAccount) : @"fakeAccount@fakeEmail.com",
        (__bridge id)(kSecAttrService) : @"www.fakeWebService.com",
        (__bridge id)(kSecValueData) : [mockPassword dataUsingEncoding:NSUTF8StringEncoding],
        (__bridge id)(kSecReturnAttributes) : (__bridge id)kCFBooleanTrue,
    };

    [handler add:dictionary withResult:nullptr];

    NSDictionary* updateDictionary = @{
        (__bridge id)(kSecAttrService) : @"www.anUpdatedFakeWebService.com",
    };

    NSDictionary* updateQuery = @{
        (__bridge id)(kSecClass) : (__bridge id)(kSecClassGenericPassword),
        (__bridge id)(kSecAttrService) : @"www.fakeWebService.com",
        (__bridge id)(kSecReturnAttributes) : (__bridge id)kCFBooleanTrue,
        (__bridge id)(kSecMatchLimit) : (__bridge id)kSecMatchLimitOne,
    };

    NSUInteger numUpdated = 0;
    [handler update:updateQuery withAttributes:updateDictionary attributesUpdated:&numUpdated];

    ASSERT_EQ(updateDictionary.count, numUpdated);

    // Query for results.
    NSDictionary* queryDictionary = @{
        (__bridge id)(kSecClass) : (__bridge id)(kSecClassGenericPassword),
        (__bridge id)(kSecAttrService) : @"www.anUpdatedFakeWebService.com",
        (__bridge id)(kSecReturnAttributes) : (__bridge id)kCFBooleanTrue,
        (__bridge id)(kSecMatchLimit) : (__bridge id)kSecMatchLimitOne,
    };

    NSDictionary* attributes;
    [handler query:queryDictionary withResult:&attributes];

    ASSERT_OBJCEQ((__bridge id)(kSecClassGenericPassword), [attributes objectForKey:(__bridge id)(kSecClass)]);
    ASSERT_OBJCEQ(@"fakeAccount@fakeEmail.com", [attributes objectForKey:(__bridge id)(kSecAttrAccount)]);
    ASSERT_OBJCEQ(@"www.anUpdatedFakeWebService.com", [attributes objectForKey:(__bridge id)(kSecAttrService)]);

    [attributes release];
    [handler release];
}

TEST(Security, GenericPasswordHandler_Remove) {
    GenericPasswordItemHandler* handler = [[GenericPasswordItemHandler alloc] initWithVault:MockVault::GetInstance()];

    NSString* mockPassword1 = @"fak3Passw0rd1";
    NSString* mockPassword2 = @"fak3Passw0rd2";
    NSString* mockPassword3 = @"fak3Passw0rd3";

    NSDictionary* credential1 = @{
        (__bridge id)(kSecClass) : (__bridge id)(kSecClassGenericPassword),
        (__bridge id)(kSecAttrAccount) : @"fakeAccount@fakeEmail.com",
        (__bridge id)(kSecAttrService) : @"www.fakeWebService.com",
        (__bridge id)(kSecValueData) : [mockPassword1 dataUsingEncoding:NSUTF8StringEncoding],
        (__bridge id)(kSecReturnAttributes) : (__bridge id)kCFBooleanTrue,
    };

    NSDictionary* credential2 = @{
        (__bridge id)(kSecClass) : (__bridge id)(kSecClassGenericPassword),
        (__bridge id)(kSecAttrAccount) : @"fakeAccount@fakeEmail.com",
        (__bridge id)(kSecAttrService) : @"www.ADifferentFakeWebService.com",
        (__bridge id)(kSecValueData) : [mockPassword2 dataUsingEncoding:NSUTF8StringEncoding],
        (__bridge id)(kSecReturnAttributes) : (__bridge id)kCFBooleanTrue,
    };

    NSDictionary* credential3 = @{
        (__bridge id)(kSecClass) : (__bridge id)(kSecClassGenericPassword),
        (__bridge id)(kSecAttrAccount) : @"ADifferentFakeAccount@fakeEmail.com",
        (__bridge id)(kSecAttrService) : @"www.fakeWebService.com",
        (__bridge id)(kSecValueData) : [mockPassword3 dataUsingEncoding:NSUTF8StringEncoding],
        (__bridge id)(kSecReturnAttributes) : (__bridge id)kCFBooleanTrue,
    };

    [handler add:credential1 withResult:nullptr];
    [handler add:credential2 withResult:nullptr];
    [handler add:credential3 withResult:nullptr];

    NSDictionary* removeQuery = @{
        (__bridge id)(kSecClass) : (__bridge id)(kSecClassGenericPassword),
    };

    [handler remove:removeQuery];

    // Query for results.
    NSDictionary* queryDictionary = @{
        (__bridge id)(kSecClass) : (__bridge id)(kSecClassGenericPassword),
        (__bridge id)(kSecReturnAttributes) : (__bridge id)kCFBooleanTrue,
        (__bridge id)(kSecMatchLimit) : (__bridge id)kSecMatchLimitAll,
    };

    NSArray* outArray = nil;
    OSStatus result = [handler query:queryDictionary withResult:&outArray];
    ASSERT_EQ(result, errSecItemNotFound);
    ASSERT_EQ(nil, outArray);

    [handler release];
}