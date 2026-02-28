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

#include "Precompiled.h"
#include <TypeInfo.h>
#include <Misc.h>
#include <Generics.h>
#include <ShimTracker.h>

using namespace std;
using namespace ObjectModel;

namespace {
std::map<wstring, wstring> toBasic{
    { L"Boolean", L"bool" },    { L"Int32", L"int" },     { L"UInt32", L"unsigned int" },
    { L"Int8", L"int8_t" },     { L"UInt8", L"uint8_t" }, { L"UInt16", L"unsigned short" },
    { L"Char16", L"wchar_t" },  { L"Int16", L"int16_t" }, { L"Int64", L"int64_t" },
    { L"UInt64", L"uint64_t" }, { L"Single", L"float" },  { L"Double", L"double" },
};

std::map<wstring, wstring> toWrt{
    { L"bool", L"Boolean" },        { L"boolean", L"Boolean" }, { L"BOOL", L"Boolean" },  { L"int", L"Int32" },
    { L"unsigned int", L"UInt32" }, { L"int8_t", L"Int8" },     { L"uint8_t", L"UInt8" }, { L"unsigned short", L"UInt16" },
    { L"wchar_t", L"Char16" },      { L"int16_t", L"Int16" },   { L"int64_t", L"Int64" }, { L"uint64_t", L"UInt64" },
    { L"float", L"Single" },        { L"double", L"Double" },
};

inline ToObjcTypeConvertor* builtin(const wstring& s) {
    return ToObjcTypeConvertor::builtinFor(s, false);
}
inline ToObjcTypeConvertor* func(const wstring& s) {
    return ToObjcTypeConvertor::builtinFor(s, true);
}
}

bool winrtToBasicType(wstring& basicType, const wstring& winrtType) {
    auto it = toBasic.find(winrtType);
    if (it == toBasic.end())
        return false;

    basicType = it->second;
    return true;
}

bool basicTypeToWinrt(wstring& wrtType, const wstring& basicType) {
    auto it = toWrt.find(basicType);
    if (it == toWrt.end())
        return false;

    wrtType = it->second;
    return true;
}

bool winrtTypeInfoBasic(const wstring& typeName, WinrtType* out) {
    if (typeName == L"String") {
        out->setWrlType(L"HSTRING");
        out->setObjcType(L"NSString *");
        out->isFundamentalType = false;

        out->toObjc = func(L"hstrToNSStr");
        out->convertFnWrl = [](const wstring& p, bool setter = false) {
            return L"nsStrToHstr(" + p + L")" + (setter ? L".Detach()" : L".Get()");
        };
        return true;
    }
    if (typeName == L"Boolean") {
        out->setWrlType(L"boolean", L"bool");
        out->setObjcType(L"BOOL");

        out->toObjc = builtin(L"(BOOL)");
        out->convertFnWrl = [](const wstring& p, bool setter = false) { return L"(boolean)" + p; };
        return true;
    }
    wstring basicName;
    if (winrtToBasicType(basicName, typeName)) {
        out->setBasicType(basicName);
        out->toObjc = builtin(L"");
        return true;
    }

    if (typeName == L"GUID") {
        out->setWrlType(L"GUID");
        out->setObjcType(L"WFGUID*");
        out->toObjc = func(getObjcConvertor(typeName));
        out->convertFnWrl = [](const wstring& p, bool setter = false) { return p + L".guidValue"; };
        return true;
    }
    if (typeName == L"Windows.Foundation.EventRegistrationToken") {
        out->setBasicType(L"EventRegistrationToken");
        out->toObjc = builtin(L"(EventRegistrationToken)");
        return true;
    }
    if (typeName == L"Windows.Foundation.HResult") {
        out->setBasicType(L"HRESULT");
        out->toObjc = builtin(L"(HRESULT)");
        return true;
    }
    if (typeName == L"Windows.Foundation.AsyncStatus") {
        out->setWrlType(L"AsyncStatus");
        out->setObjcType(L"WFAsyncStatus");

        out->toObjc = builtin(L"(unsigned)");
        out->convertFnWrl = [](const wstring& p, bool setter = false) { return L"(AsyncStatus)" + p; };
        return true;
    }

    if (typeName == L"System.Object") {
        out->setWrlType(L"IInspectable");
        out->setObjcType(L"RTObject*");

        out->toObjc = func(L"_createBareRTObj");
        out->convertFnWrl = [](const wstring& name, bool setter = false) {
            return L"[" + name + L" comObj]" + (setter ? L".Detach()" : L".Get()");
        };

        out->isValueType = false;
        out->isFundamentalType = false;
        return true;
    }
    return false;
}

// Create the ObjC-style type from the midl type:
wstring mapNamespacedType(const wstring& midlType) {
    if (midlType.find(L'.') == wstring::npos)
        return midlType;

    // Find a reasonable prefix for the enum field names:
    wstring uptoGeneric = midlType.substr(0, midlType.find(L'`'));
    auto lastDot = uptoGeneric.rfind(L'.');
    wstring typeName = uptoGeneric.substr(lastDot + 1);
    wstring ns = uptoGeneric.substr(0, lastDot);

    if (ns == L"Windows.ApplicationModel.Store")
        return L"WS" + typeName;
    if (ns == L"Windows.UI.Xaml")
        return L"WX" + typeName;
    if (ns == L"Windows.UI.Xaml.Controls")
        return L"WXC" + typeName;

    wstring shortNs(1, ns[0]);
    size_t offs = 0;
    while ((offs = ns.find(L'.', offs)) != wstring::npos) {
        shortNs += ns[offs + 1];
        ++offs;
    }

    return shortNs + typeName;
}

wstring midlToWrlType(const wstring& midlType) {
    // For some reason these are in MIDL as in namespaces but they aren't..
    if (midlType == L"Windows.Foundation.EventRegistrationToken")
        return L"EventRegistrationToken";
    if (midlType == L"Windows.Foundation.HResult")
        return L"HRESULT";

    return L"ABI::" + replace(midlType, L".", L"::");
}

ReturnHandler handleReturnType(const shared_ptr<MemberInfo>& memberInfo, const SymbolTable& types, ShimTracker& shims) {
    ReturnHandler ret;

    const auto& returnType = memberInfo->ReturnParameter.Type;

    // Handle the out parameters first:
    for (const auto& p : memberInfo->Parameters) {
        if (p.IsOutParam) {
            auto typeInfo = winrtTypeInfo(p.Type, types, shims);
            if (!typeInfo.isCArray()) {
                shims.addref(typeInfo);
                ret.header += L"    " + (typeInfo.isIInspectableType() ? L"ComPtr<" + typeInfo.wrlFullName(true, true) + L">" :
                                                                         typeInfo.wrlFullName()) +
                              L" " + p.Name + L"OutUnmarshaled;\n";
                ret.footer +=
                    L"    *" + p.Name + L" = " +
                    typeInfo.toObjc->call(typeInfo,
                                          p.Name + (typeInfo.isIInspectableType() ? L"OutUnmarshaled.Get()" : L"OutUnmarshaled")) +
                    L";\n";
            }
        }
    }

    // Void:
    if (!returnType) {
        ret.returnType = L"void";
        return ret;
    }

    //
    // These are only to handle the types that change the signature of the method call.
    // For example, for async calls we take success and failure blocks that are invoked
    // rather than returning an object you can do things with.
    //

    if (returnType->Category & WinRtGeneric) {
        auto genericType = dynamic_pointer_cast<Generic>(returnType);
        if (hasPrefix(returnType->Name, L"Windows.Foundation.IAsyncOperation`")) {
            assert(genericType->Parameters.size() == 1);

            //
            // Return an async operation is a very special operation. It doesn't actually return anything
            // but calls into success or failure functions to provide the result.
            //
            WinrtType enclosedInfo = winrtTypeInfo(genericType->Parameters[0], types, shims);
            shims.addref(enclosedInfo);

            ret.wrlType = L"ComPtr<ABI::Windows::Foundation::IAsyncOperation<" + enclosedInfo.wrlFullName(false) + L">>";
            ret.newParams.push_back({ L"success", L"void (^)(" + enclosedInfo.getObjcType() + L")", L"success" });
            ret.newParams.push_back({ L"failure", L"void (^)(NSError*)", L"failure" });

            // We need to call the success/failure callbacks as part of our footer (after the function is called):
            ret.footer =
                L"\n\
    decltype(success) successRc = [success copy];\n\
    decltype(failure) failureRc = [failure copy];\n\
    auto completionHandler =  ::Microsoft::WRL::Callback<\n\
        ::Microsoft::WRL::Implements<::Microsoft::WRL::RuntimeClassFlags<\n\
            ::Microsoft::WRL::WinRtClassicComMix>,\n\
                                     ABI::Windows::Foundation::IAsyncOperationCompletedHandler<" +
                enclosedInfo.wrlFullName(false) + L">, FtmBase>>([successRc, failureRc](ABI::Windows::Foundation::IAsyncOperation<" +
                enclosedInfo.wrlFullName(false) +
                L">* op, AsyncStatus status) {\n\
        @autoreleasepool { \n\
            if (!_handleAsyncErrorCode(op, failureRc)) {\n\
                return S_OK;\n\
            }\n\
            if (status == AsyncStatus::Completed) {\n\
                " +
                (enclosedInfo.isIInspectableType() ? L"ComPtr<" + enclosedInfo.wrlFullName(true, true) + L">" :
                                                     enclosedInfo.wrlFullName()) +
                L" result;\n\
                HRESULT hr = op->GetResults(" +
                (enclosedInfo.isIInspectableType() ? L"result.GetAddressOf()" : L"&result") +
                L");\n\
                if (SUCCEEDED(hr)) {\n\
                    if (successRc) {\n\
                        successRc(" +
                enclosedInfo.toObjc->call(enclosedInfo, (enclosedInfo.isIInspectableType() ? L"result.Get()" : L"result")) +
                L");\n\
                    }\n\
                } else { \n\
                    if (failureRc) {\n\
                        failureRc([NSError errorWithDomain:@\"HRESULT\" code:hr userInfo:nil]);\n\
                    }\n\
                }\n\
            } else {\n\
                if (failureRc) {\n\
                    failureRc([NSError errorWithDomain:@\"Async\" code:(int)status userInfo:nil]);\n\
                }\n\
            }\n\
            [successRc release]; [failureRc release];\n\
            return S_OK;\n\
        }\n\
    });\n\
\n\
    unmarshalledReturn->put_Completed(completionHandler.Get());\n";

            // we return nothing with async ops:
            ret.returnVal = L"";
            ret.returnType = L"void";

            return ret;
        } else if (hasPrefix(returnType->Name, L"Windows.Foundation.IAsyncOperationWithProgress`")) {
            assert(genericType->Parameters.size() == 2);

            //
            // Return an async operation is a very special operation. It doesn't actually return anything
            // but calls into success or failure functions to provide the result.
            //

            WinrtType enclosedInfo = winrtTypeInfo(genericType->Parameters[0], types, shims);
            WinrtType progressInfo = winrtTypeInfo(genericType->Parameters[1], types, shims);

            shims.addref(enclosedInfo);
            shims.addref(progressInfo);

            if (enclosedInfo.wrlFullName(false) == L"" || progressInfo.wrlFullName(false) == L"")
                DebugBreak();

            ret.wrlType = L"ComPtr<ABI::Windows::Foundation::IAsyncOperationWithProgress<" + enclosedInfo.wrlFullName(false) + L", " +
                          progressInfo.wrlFullName(false) + L">>";

            ret.newParams.push_back({ L"success", L"void (^)(" + enclosedInfo.getObjcType() + L")", L"success" });
            ret.newParams.push_back({ L"progress", L"void (^)(" + progressInfo.getObjcType() + L")", L"progress" });
            ret.newParams.push_back({ L"failure", L"void (^)(NSError*)", L"failure" });

            // We need to call the success/failure callbacks as part of our footer (after the function is called):
            ret.footer =
                L"\n\
    if (progress) {\n\
        decltype(progress) progressRc = [progress copy];\n\
        auto progressHandler = ::Microsoft::WRL::Callback<\n\
        ::Microsoft::WRL::Implements<::Microsoft::WRL::RuntimeClassFlags<\n\
            ::Microsoft::WRL::WinRtClassicComMix>,\n\
                                     ABI::Windows::Foundation::IAsyncOperationProgressHandler<" +
                enclosedInfo.wrlFullName(false) + L", " + progressInfo.wrlFullName(false) + L">, FtmBase>>([progressRc](" +
                L"ABI::Windows::Foundation::IAsyncOperationWithProgress<" + enclosedInfo.wrlFullName(false) + L", " +
                progressInfo.wrlFullName(false) + L"> *op, " + progressInfo.wrlFullName() +
                L" status) {\n\
            @autoreleasepool { \n\
                progressRc(" +
                progressInfo.toObjc->call(progressInfo, L"status") +
                L");\n \
                    [progressRc release];\n\
                    return S_OK;\n\
            }\n\
        });\n\
        unmarshalledReturn->put_Progress(progressHandler.Get());\n\
    }\n\
    decltype(success) successRc = [success copy];\n\
    decltype(failure) failureRc = [failure copy];\n\
    auto completionHandler = ::Microsoft::WRL::Callback<\n\
        ::Microsoft::WRL::Implements<::Microsoft::WRL::RuntimeClassFlags<\n\
            ::Microsoft::WRL::WinRtClassicComMix>,\n\
                                     ABI::Windows::Foundation::IAsyncOperationWithProgressCompletedHandler<" +
                enclosedInfo.wrlFullName(false) + L", " + progressInfo.wrlFullName(false) +
                L">>>([successRc, failureRc](ABI::Windows::Foundation::IAsyncOperationWithProgress<" + enclosedInfo.wrlFullName(false) +
                L", " + progressInfo.wrlFullName(false) +
                L"> *op, AsyncStatus status) {\n\
        @autoreleasepool { \n\
            if (!_handleAsyncErrorCode(op, failureRc)) {\n\
                return S_OK;\n\
            }\n\
            if (status == AsyncStatus::Completed) {\n\
                " +
                (enclosedInfo.isIInspectableType() ? L"ComPtr<" + enclosedInfo.wrlFullName(true, true) + L">" :
                                                     enclosedInfo.wrlFullName()) +
                L" result;\n\
                HRESULT hr = op->GetResults(" +
                (enclosedInfo.isIInspectableType() ? L"result.GetAddressOf()" : L"&result") +
                L");\n\
                if (SUCCEEDED(hr)) {\n\
                    if (successRc) {\n\
                        successRc(" +
                enclosedInfo.toObjc->call(enclosedInfo, (enclosedInfo.isIInspectableType() ? L"result.Get()" : L"result")) +
                L");\n\
                    }\n\
                } else {\n\
                    if (failureRc) {\n\
                        failureRc([NSError errorWithDomain:@\"HRESULT\" code:hr userInfo:nil]);\n\
                    }\n\
                }\n\
            } else {\n\
                if (failureRc) { failureRc([NSError errorWithDomain:@\"Async\" code:(int)status userInfo:nil]); }\n\
            }\n\
            [successRc release]; [failureRc release];\n\
            return S_OK;\n\
        }\n\
    });\n\
    unmarshalledReturn->put_Completed(completionHandler.Get());\n";

            // we return nothing with async ops:
            ret.returnVal = L"";
            ret.returnType = L"void";

            return ret;
        }
    }

    // Marshal the return value as any normal value:

    WinrtType info = winrtTypeInfo(returnType, types, shims);

    ret.wrlType = info.wrlFullName();
    ret.wrlBaseType = info.wrlFullName(true, true);
    ret.returnType = info.getObjcType();
    wstring winrtType;
    ret.needsARCAnnotation = !(basicTypeToWinrt(winrtType, info.getObjcType(false)) || ret.returnType == L"void" || info.isEnumType);

    shims.addref(info);
    if (info.toObjc) {
        wstring param = info.isIInspectableType() ? L"unmarshalledReturn.Get()" : L"unmarshalledReturn";
        ret.returnVal = info.toObjc->call(info, param);
    }

    return ret;
}

WinrtType winrtTypeInfo(const shared_ptr<Symbol>& internalType, const SymbolTable& types, ShimTracker& shims, bool box) {
    wstring typeName = internalType->Name;

    WinrtType ret;
    if (winrtTypeInfoBasic(typeName, &ret)) {
        if (box) {
            auto conv = getObjcConvertor(typeName);
            if (conv.empty())
                throw wstring(L"Convert function for boxed type ") + typeName + L" could not be resolved.";

            ret.toObjc = func(conv);
            ret.convertFnWrl = [typeName](wstring p, bool settter = false) { return getWRLConvertor(typeName) + L"(" + p + L")"; };
        }
        return ret;
    }

    wstring baseName = mapNamespacedType(typeName);
    ret.isFundamentalType = false;

    auto ty = internalType;

    // This seems like a bug in the project we based this off of. Sometimes we'll get unresolved
    // types that are actually in the type dict...
    auto it = types.find(typeName);
    if (ty->Category == UnresolvedType && it != types.end())
        ty = it->second;

    if (auto cls = dynamic_pointer_cast<ObjectModel::RuntimeClass>(ty)) {
        auto templateType = midlToWrlType(typeName);
        ret.isValueType = false;

        wstring wrlType;
        if (cls->InterfaceImplements.size() != 0) {
            // The default interface is the type that WRL uses to return/take in runtime classes.
            // If we're trying to find the wrl name for this type, it will be the default interface
            // so find that.
            for (auto imp : cls->InterfaceImplements) {
                auto defaultAttrIt = imp.Attributes.find(L"Windows.Foundation.Metadata.DefaultAttribute");
                if (defaultAttrIt != imp.Attributes.end()) {
                    // We may be inheriting off templated stuff here so decode into real WRL type:
                    // NOTE: used to be decodeWrlType, but now wrlFullName() does the same thing.
                    auto t = winrtTypeInfo(imp.Type, types, shims);
                    wrlType = t.wrlFullName(true, true);

                    auto objcIface = mapNamespacedType(imp.Type->Name);
                    ret.convertFnWrl = [wrlType](const wstring& n, bool setter = false) {
                        return L"_getRtInterface<" + wrlType + L">(" + n + L")" + (setter ? L".Detach()" : L".Get()");
                    };
                    break;
                }
            }

            assert(!wrlType.empty());

            // The conversion creates a proxy wrapping it:
            ret.toObjc = func(L"_createRtProxy<" + baseName + L">");
        } else {
            wrlType = midlToWrlType(typeName);
            ret.toObjc = builtin(L"");
        }

        ret.setObjcType(baseName + L"*");
        ret.setWrlType(wrlType, templateType);
        assert(ret.toObjc);
        return ret;
    } else if (auto iface = dynamic_pointer_cast<ObjectModel::Interface>(ty)) {
        auto wrlName = midlToWrlType(typeName);
        ret.setWrlType(wrlName);
        ret.isValueType = false;

        ret.toObjc = func(L"_createRtProxy<" + baseName + L">");
        ret.convertFnWrl = [wrlName](const wstring& n, bool setter = false) {
            return L"_getRtInterface<" + wrlName + L">(" + n + L")" + (setter ? L".Detach()" : L".Get()");
        };
        ret.setObjcType(L"RTObject<" + baseName + L">*");
        assert(ret.toObjc);
        return ret;
    } else if (auto unresolved = dynamic_pointer_cast<ObjectModel::UnresolvedSymbol>(ty)) {
        // Sadly we can't handle generating unresolved classes at all. Value types can't necessarily
        // be coerced to any common type because they could be both structures or fundamental types.

        // Similarly runtime classes can't be resolved because their type will be the default interface
        // in the WRL headers and we don't have that since we haven't resolved the type.

        // Win some, lose some.

        throw ty->Name + L" unresolved";
    } else if (auto en = dynamic_pointer_cast<ObjectModel::Enum>(ty)) {
        ret.setWrlType(midlToWrlType(typeName));

        if (box) {
            ret.toObjc = func(getObjcConvertor(L"Enum"));
            ret.convertFnWrl = [=](const wstring& p, bool setter = false) {
                return getWRLConvertor(L"Enum") + L"<" + ret.wrlFullName() + L">(" + p + L")";
            };
        } else {
            // Casts because they're just ints:
            ret.toObjc = builtin(L"(" + baseName + L")");
            ret.convertFnWrl = [=](const wstring& p, bool setter = false) { return L"(" + ret.wrlFullName() + L")" + p; };
        }
        ret.isEnumType = true;
        ret.setObjcType(baseName);
        assert(ret.toObjc);
        return ret;
    } else if (auto gen = dynamic_pointer_cast<ObjectModel::Generic>(ty)) {
        if (HandleTypedDelegates(gen, typeName, ret, types, shims))
            return ret;
        if (HandleContainer(gen, ret, types, shims))
            return ret;
    } else if (auto s = dynamic_pointer_cast<Struct>(ty)) {
        ret.setWrlType(midlToWrlType(typeName));
        ret.convertFnWrl = [ret](const wstring& name, bool setter = false) { return L"*[" + name + L" internalStruct]"; };
        ret.toObjc = &singleObjConv;
        ret.setObjcType(baseName + L"*");
        assert(ret.toObjc);
        return ret;
    } else if (auto arr = dynamic_pointer_cast<Array>(ty)) {
        if (HandleCArray(arr->Type, ret, types, shims))
            return ret;
    } else if (auto del = dynamic_pointer_cast<Delegate>(ty)) {
        auto delegateName = mapNamespacedType(del->Name);

        struct Parms {
            shared_ptr<Symbol> type;
            wstring name;
        };

        std::vector<Parms> parms;
        shared_ptr<Symbol> outType;

        // Find the invoke and make sure there's only one:
        // This is horrifically implicit..
        bool found = false;
        for (const auto& member : del->Members) {
            if (member.second->Name == L"Invoke") {
                assert(!found);
                found = true;
                outType = member.second->ReturnParameter.Type;
                for (const auto& p : member.second->Parameters) {
                    Parms parm = { p.Type, p.Name };
                    parms.push_back(parm);
                }
            }
        }
        assert(found);

        wstring args;
        for (auto p : parms) {
            if (args.size())
                args += L", ";

            auto typeInfo = winrtTypeInfo(p.type, types, shims);
            ret.templateParams.push_back(typeInfo);
            args += typeInfo.getObjcType() + L" " + p.name;
        }

        ret.setObjcType(delegateName);

        // Yes, we really just add an I in front of the class name to get the WRL version of the name.
        // For verification, see prttype.cxx:4255 in midlrt.
        auto wrlName = midlToWrlType(del->Name);
        wrlName.insert(wrlName.rfind(L"::") + 2, L"I");
        ret.setWrlType(wrlName);

        auto ourName = ret.getObjcType() + L"_shim";
        ret.convertFnWrl = [ourName](const wstring& n, bool setter = false) {
            return L"Make<" + ourName + L">(" + n + L")" + (setter ? L".Detach()" : L".Get()");
        };
        ret.isValueType = false;
        ret.toObjc = &nilConv;

        wstring outParamStr;

        if (outType) {
            auto retTypeInfo = winrtTypeInfo(outType, types, shims);
            if (retTypeInfo.getObjcType().size()) {
                outParamStr = retTypeInfo.wrlFullName() + L"*";
            }
        }

        DelegateShimInfo info = { ret, outParamStr };

        if (shims.delegateShims.find(ourName) == shims.delegateShims.end()) {
            shims.addref(ret);
            shims.delegateShims[ourName] = info;
        }

        return ret;
    }

    throw L"Can't marshal " + typeName;
}
