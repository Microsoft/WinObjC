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

#import <UWP/ObjCHelpers.h>
#import <UWP/interopBase.h>
#import "Starboard.h"

namespace CommonConvertors {
Microsoft::WRL::ComPtr<IInspectable> _convertNSArrayToPropertyValue(id obj);
Microsoft::WRL::ComPtr<IInspectable> _convertToPropertyValueType(id item);
id _convertInspectableArrayToNSArray(Microsoft::WRL::ComPtr<IPropertyValue> ip);
id _convertIntArrayToNSArray(Microsoft::WRL::ComPtr<IPropertyValue> ip);
id _convertUIntArrayToNSArray(Microsoft::WRL::ComPtr<IPropertyValue> ip);
id _convertSingleArrayToNSArray(Microsoft::WRL::ComPtr<IPropertyValue> ip);
id _convertDoubleArrayToNSArray(Microsoft::WRL::ComPtr<IPropertyValue> ip);
id _convertStringArrayToNSArray(Microsoft::WRL::ComPtr<IPropertyValue> ip);
id _convertMapToNSDictionary(Microsoft::WRL::ComPtr<IInspectable> ip);
id _convertPropertyValueToObjC(Microsoft::WRL::ComPtr<IPropertyValue> obj);

ComPtr<ABI::Windows::Foundation::IPropertyValueStatics> propertyValueCreator() {
    ComPtr<ABI::Windows::Foundation::IPropertyValueStatics> propValueCreator;
    THROW_NS_IF_FAILED(ABI::Windows::Foundation::GetActivationFactory(HString::MakeReference(L"Windows.Foundation.PropertyValue").Get(),
                                                                      &propValueCreator));
    return propValueCreator;
}

ComPtr<IInspectable> _convertToPropertyValueType(id item) {
    if (item == nil) {
        return nullptr;
    }
    ComPtr<ABI::Windows::Foundation::IPropertyValueStatics> propValueCreator = propertyValueCreator();
    ComPtr<IInspectable> propValue;
    if ([item isKindOfClass:[NSString class]]) {
        HSTRING hstr = ToWRLConvertor<HSTRING, dummyWRLCreator>::convert(item);
        THROW_NS_IF_FAILED(propValueCreator->CreateString(hstr, propValue.GetAddressOf()));
        WindowsDeleteString(hstr);
    } else if ([item isKindOfClass:[NSArray class]]) {
        propValue = _convertNSArrayToPropertyValue(item);
    } else if ([item isKindOfClass:[NSDictionary class]]) {
        propValue = convertNSDictionaryToPropertySet(item);
    } else if ([item isKindOfClass:[NSNumber class]]) {
        const char* type = [item objCType];
        if (strstr("cilsq", type) != NULL) {
            THROW_NS_IF_FAILED(
                propValueCreator->CreateInt64(ToWRLConvertor<int64_t, dummyWRLCreator>::convert(item), propValue.GetAddressOf()));
        } else if (strstr("CILSQ", type) != NULL) {
            THROW_NS_IF_FAILED(
                propValueCreator->CreateUInt64(ToWRLConvertor<uint64_t, dummyWRLCreator>::convert(item), propValue.GetAddressOf()));
        } else if (strcmp("f", type) == 0) {
            THROW_NS_IF_FAILED(
                propValueCreator->CreateSingle(ToWRLConvertor<float, dummyWRLCreator>::convert(item), propValue.GetAddressOf()));
        } else if (strcmp("d", type) == 0) {
            THROW_NS_IF_FAILED(
                propValueCreator->CreateDouble(ToWRLConvertor<double, dummyWRLCreator>::convert(item), propValue.GetAddressOf()));
        }
    }
    return propValue;
}

ComPtr<IInspectable> _convertNSArrayToPropertyValue(id obj) {
    if (obj == nil) {
        return nullptr;
    }
    ComPtr<ABI::Windows::Foundation::IPropertyValueStatics> propValueCreator = propertyValueCreator();
    // This array will maintain the lifetime of the ComPtrs till the function exits.
    std::vector<ComPtr<IInspectable>> arr;
    std::vector<IInspectable*> arrIInspectable;
    for (id item in obj) {
        ComPtr<IInspectable> comObj = _convertToPropertyValueType(item);
        arr.push_back(comObj.Get());
        arrIInspectable.push_back(comObj.Detach());
    }
    ComPtr<IInspectable> returnObj;
    if (arrIInspectable.size()) {
        THROW_NS_IF_FAILED(
            propValueCreator->CreateInspectableArray(arrIInspectable.size(), arrIInspectable.data(), returnObj.GetAddressOf()));
    }
    return returnObj;
}

ComPtr<IInspectable> convertNSDictionaryToPropertySet(id obj) {
    if (obj == nil) {
        return nullptr;
    }
    ComPtr<ABI::Windows::Foundation::Collections::IPropertySet> propertySet;
    Windows::Foundation::ActivateInstance(HString::MakeReference(L"Windows.Foundation.Collections.PropertySet").Get(), &propertySet);
    ComPtr<IMap<HSTRING, IInspectable*>> _map;
    ComPtr<IMapView<HSTRING, IInspectable*>> _mapView;
    THROW_NS_IF_FAILED(propertySet.As(&_map));
    boolean replaced;
    for (id key in obj) {
        if ([key isKindOfClass:[NSString class]]) {
            id value = obj[key];
            ComPtr<IInspectable> propValue = _convertToPropertyValueType(value);
            _map->Insert(nsStrToHstr(key).Get(), propValue.Get(), &replaced);
        }
    }
    THROW_NS_IF_FAILED(_map->GetView(_mapView.GetAddressOf()));
    return _mapView;
}

ComPtr<IInspectable> convertNSErrorToPropertySet(id obj) {
    if (obj == nil) {
        return nullptr;
    }
    ComPtr<ABI::Windows::Foundation::Collections::IPropertySet> propertySet;
    Windows::Foundation::ActivateInstance(HString::MakeReference(L"Windows.Foundation.Collections.PropertySet").Get(), &propertySet);
    ComPtr<IMap<HSTRING, IInspectable*>> _map;
    ComPtr<IMapView<HSTRING, IInspectable*>> _mapView;
    THROW_NS_IF_FAILED(propertySet.As(&_map));
    ComPtr<IInspectable> propValue = _convertToPropertyValueType([NSNumber numberWithLongLong:(int64_t)[obj code]]);
    NSString* code = @"code";
    boolean replaced;
    _map->Insert(nsStrToHstr(code).Get(), propValue.Get(), &replaced);
    id userInfo = [obj userInfo];
    for (id key in userInfo) {
        if ([key isKindOfClass:[NSString class]]) {
            id value = userInfo[key];
            propValue = _convertToPropertyValueType(value);
            _map->Insert(nsStrToHstr(key).Get(), propValue.Get(), &replaced);
        }
    }
    THROW_NS_IF_FAILED(_map->GetView(_mapView.GetAddressOf()));
    return _mapView;
}

id _convertMapToNSDictionary(ComPtr<IInspectable> ip) {
    if (ip == nullptr) {
        return nil;
    }
    id value;
    ComPtr<IMap<HSTRING, IInspectable*>> _map;
    ComPtr<IMapView<HSTRING, IInspectable*>> _mapView;
    if (SUCCEEDED(ip.As(&_map))) {
        THROW_NS_IF_FAILED(_map->GetView(_mapView.GetAddressOf()));
        value = convertPropertySetToNSDictionary(_mapView);
    } else if (SUCCEEDED(ip.As(&_mapView))) {
        value = convertPropertySetToNSDictionary(_mapView);
    } else {
        THROW_NS_HR(E_NOINTERFACE);
    }
    return value;
}

id _convertPropertyValueToObjC(ComPtr<IPropertyValue> obj) {
    if (obj == nullptr) {
        return nil;
    }
    PropertyType type;
    THROW_NS_IF_FAILED(obj->get_Type(&type));
    id value;
    switch (type) {
        case PropertyType_Inspectable: {
            value = _convertMapToNSDictionary(obj);
            break;
        }
        case PropertyType_InspectableArray: {
            value = _convertInspectableArrayToNSArray(obj);
            break;
        }
        case PropertyType_Int64Array:
        case PropertyType_Int32Array:
        case PropertyType_Int16Array:
        case PropertyType_Char16Array:
        case PropertyType_BooleanArray: {
            value = _convertIntArrayToNSArray(obj);
            break;
        }
        case PropertyType_UInt64Array:
        case PropertyType_UInt32Array:
        case PropertyType_UInt16Array:
        case PropertyType_UInt8Array: {
            value = _convertUIntArrayToNSArray(obj);
            break;
        }
        case PropertyType_SingleArray: {
            value = _convertSingleArrayToNSArray(obj);
            ;
            break;
        }
        case PropertyType_DoubleArray: {
            value = _convertDoubleArrayToNSArray(obj);
            break;
        }
        case PropertyType_StringArray: {
            value = _convertStringArrayToNSArray(obj);
            break;
        }
        case PropertyType_String: {
            HSTRING val;
            THROW_NS_IF_FAILED(obj->GetString(&val));
            value = hstrToNSStr(val, true);
            break;
        }
        case PropertyType_Single: {
            FLOAT val;
            THROW_NS_IF_FAILED(obj->GetSingle(&val));
            value = ToObjcConvertor<float, FLOAT, dummyObjCCreator>::convert(val);
            break;
        }
        case PropertyType_Double: {
            double val;
            THROW_NS_IF_FAILED(obj->GetDouble(&val));
            value = ToObjcConvertor<double, DOUBLE, dummyObjCCreator>::convert(val);
            break;
        }
        case PropertyType_Int64:
        case PropertyType_Int32:
        case PropertyType_Int16:
        case PropertyType_Char16:
        case PropertyType_Boolean: {
            INT64 val;
            THROW_NS_IF_FAILED(obj->GetInt64(&val));
            value = ToObjcConvertor<int64_t, INT64, dummyObjCCreator>::convert(val);
            break;
        }
        case PropertyType_UInt64:
        case PropertyType_UInt32:
        case PropertyType_UInt16:
        case PropertyType_UInt8: {
            UINT64 val;
            THROW_NS_IF_FAILED(obj->GetUInt64(&val));
            value = ToObjcConvertor<int64_t, INT64, dummyObjCCreator>::convert(val);
            break;
        }
        default:
            return nil;
    }
    return value;
}

id _convertStringArrayToNSArray(ComPtr<IPropertyValue> ip) {
    UINT32 length;
    HSTRING* arr;
    if (ip == nullptr) {
        return nil;
    }
    NSMutableArray* values = [[[NSMutableArray alloc] init] autorelease];
    THROW_NS_IF_FAILED(ip->GetStringArray(&length, &arr));
    for (UINT32 i = 0; i < length; i++) {
        [values addObject:hstrToNSStr(arr[i], true)];
    }
    NSArray* value = [NSArray arrayWithArray:values];
    CoTaskMemFree(arr);
    return value;
}

id _convertDoubleArrayToNSArray(ComPtr<IPropertyValue> ip) {
    UINT32 length;
    DOUBLE* arr;
    if (ip == nullptr) {
        return nil;
    }
    NSMutableArray* values = [[[NSMutableArray alloc] init] autorelease];
    THROW_NS_IF_FAILED(ip->GetDoubleArray(&length, &arr));
    for (UINT32 i = 0; i < length; i++) {
        [values addObject:[NSNumber numberWithDouble:arr[i]]];
    }
    NSArray* value = [NSArray arrayWithArray:values];
    CoTaskMemFree(arr);
    return value;
}

id _convertSingleArrayToNSArray(ComPtr<IPropertyValue> ip) {
    UINT32 length;
    FLOAT* arr;
    if (ip == nullptr) {
        return nil;
    }
    NSMutableArray* values = [[[NSMutableArray alloc] init] autorelease];
    THROW_NS_IF_FAILED(ip->GetSingleArray(&length, &arr));
    for (UINT32 i = 0; i < length; i++) {
        [values addObject:[NSNumber numberWithFloat:arr[i]]];
    }
    NSArray* value = [NSArray arrayWithArray:values];
    CoTaskMemFree(arr);
    return value;
}

id _convertUIntArrayToNSArray(ComPtr<IPropertyValue> ip) {
    UINT32 length;
    UINT64* arr;
    if (ip == nullptr) {
        return nil;
    }
    NSMutableArray* values = [[[NSMutableArray alloc] init] autorelease];
    THROW_NS_IF_FAILED(ip->GetUInt64Array(&length, &arr));
    for (UINT32 i = 0; i < length; i++) {
        [values addObject:[NSNumber numberWithUnsignedLongLong:arr[i]]];
    }
    NSArray* value = [NSArray arrayWithArray:values];
    CoTaskMemFree(arr);
    return value;
}

id _convertIntArrayToNSArray(ComPtr<IPropertyValue> ip) {
    UINT32 length;
    INT64* arr;
    if (ip == nullptr) {
        return nil;
    }
    NSMutableArray* values = [[[NSMutableArray alloc] init] autorelease];
    THROW_NS_IF_FAILED(ip->GetInt64Array(&length, &arr));
    for (UINT32 i = 0; i < length; i++) {
        [values addObject:[NSNumber numberWithLongLong:arr[i]]];
    }
    NSArray* value = [NSArray arrayWithArray:values];
    CoTaskMemFree(arr);
    return value;
}

id _convertInspectableArrayToNSArray(ComPtr<IPropertyValue> ip) {
    UINT32 length;
    IInspectable** arr;
    if (ip == nullptr) {
        return nil;
    }
    NSMutableArray* values = [[[NSMutableArray alloc] init] autorelease];
    THROW_NS_IF_FAILED(ip->GetInspectableArray(&length, &arr));
    for (UINT32 i = 0; i < length; i++) {
        ComPtr<IInspectable> com = arr[i];
        ComPtr<IPropertyValue> propValue;
        THROW_NS_IF_FAILED(com.As(&propValue));
        [values addObject:_convertPropertyValueToObjC(propValue)];
    }
    NSArray* value = [NSArray arrayWithArray:values];
    CoTaskMemFree(arr);
    return value;
}

id convertPropertySetToNSDictionary(ComPtr<IMapView<HSTRING, IInspectable*>> ip) {
    ComPtr<IIterable<IKeyValuePair<HSTRING, IInspectable*>*>> iterable;
    ComPtr<IIterator<IKeyValuePair<HSTRING, IInspectable*>*>> iterator;
    if (ip == nullptr) {
        return nil;
    }
    THROW_NS_IF_FAILED(ip.As(&iterable));
    THROW_NS_IF_FAILED(iterable->First(&iterator));
    boolean hasCurrent = false;
    THROW_NS_IF_FAILED(iterator->get_HasCurrent(&hasCurrent));
    NSMutableDictionary* _dictionary = [[[NSMutableDictionary alloc] init] autorelease];
    while (hasCurrent) {
        ComPtr<IKeyValuePair<HSTRING, IInspectable*>> kvp;
        THROW_NS_IF_FAILED(iterator->get_Current(&kvp));
        HSTRING keyHstr;
        THROW_NS_IF_FAILED(kvp->get_Key(&keyHstr));
        NSString* key = hstrToNSStr(keyHstr, true);
        id value;
        ComPtr<IInspectable> obj;
        THROW_NS_IF_FAILED(kvp->get_Value(obj.GetAddressOf()));
        ComPtr<IPropertyValue> obj1;
        ComPtr<IMap<HSTRING, IInspectable*>> obj2;
        ComPtr<IMapView<HSTRING, IInspectable*>> obj3;
        if (SUCCEEDED(obj.As(&obj1))) {
            value = _convertPropertyValueToObjC(obj1);
        } else if (SUCCEEDED(obj.As(&obj2)) || SUCCEEDED(obj.As(&obj3))) {
            value = _convertMapToNSDictionary(obj);
        } else {
            THROW_NS_HR(E_NOINTERFACE);
        }
        [_dictionary setObject:value forKey:key];
        THROW_NS_IF_FAILED(iterator->MoveNext(&hasCurrent));
    }
    NSDictionary* _ret = [NSDictionary dictionaryWithDictionary:_dictionary];
    return _ret;
}

ABI::Windows::Foundation::DateTime convertNSDateToWinRT(NSDate* obj) {
    const int64_t hundredNanoSecondsFactor = 10000000;
    // This constant is the summation of two 100 nanosecond ticks constants, first one (116444736000000000) is for
    // converting Windows epoch (Jan 1 1601 00:00:00) to Unix epoch (Jan 1 1970 00:00:00) and
    // the other (9783072000000000) is for converting from Unix epoch to NSDate's reference date (Jan 1 2001 00:00:00).
    const int64_t hundredNanoSecondTicksFromWindowsEpochToNSDateReferenceDate = 126227808000000000;
    // The time interval we get from NSDate is in seconds. We convert it to 100 nanoseconds ticks.
    int64_t timeInterval = (int64_t)([obj timeIntervalSinceReferenceDate] * hundredNanoSecondsFactor);
    timeInterval = timeInterval + hundredNanoSecondTicksFromWindowsEpochToNSDateReferenceDate;
    ABI::Windows::Foundation::DateTime date;
    date.UniversalTime = timeInterval;
    return date;
}

NSDate* convertWinRTToNSDate(ABI::Windows::Foundation::DateTime dt) {
    const int64_t hundredNanoSecondsFactor = 10000000;
    const int64_t hundredNanoSecondTicksFromWindowsEpochToNSDateReferenceDate = 126227808000000000;
    // timeInterval is 100 nanosecond ticks from Jan 1 1601 00:00.
    // Convert timeInterval to 100 nanosecond ticks from Jan 1 2001.
    double timeInterval = dt.UniversalTime - hundredNanoSecondTicksFromWindowsEpochToNSDateReferenceDate;
    // Convert 100 nanosecond ticks to seconds;
    timeInterval = timeInterval / hundredNanoSecondsFactor;
    NSDate* date = [NSDate dateWithTimeIntervalSinceReferenceDate:timeInterval];
    return date;
}

ComPtr<ABI::Windows::Storage::IStorageFile> convertNSURLToWinRTStorageFile(NSURL* obj) {
    return nullptr;
}

ComPtr<ABI::Windows::Foundation::IUriRuntimeClass> convertNSURLToWinRTUri(NSURL* obj) {
    ComPtr<ABI::Windows::Foundation::IUriRuntimeClassFactory> uriFactory;
    ComPtr<ABI::Windows::Foundation::IUriRuntimeClass> comObj;
    THROW_NS_IF_FAILED(
        ABI::Windows::Foundation::GetActivationFactory(HString::MakeReference(L"Windows.Foundation.Uri").Get(), &uriFactory));
    THROW_NS_IF_FAILED(uriFactory->CreateUri(nsStrToHstr([obj absoluteString]).Get(), comObj.GetAddressOf()));
    return comObj;
}

NSURL* convertWinRTStorageFileToNSURL(const ComPtr<ABI::Windows::Storage::IStorageFile> storageFile) {
    NSURL* n = [NSURL URLWithStorageFile:storageFile.Get()];
    return n;
}

NSURL* convertWinRTUriToNSURL(const ComPtr<ABI::Windows::Foundation::IUriRuntimeClass> uri) {
    HSTRING hstr;
    THROW_NS_IF_FAILED(uri->get_AbsoluteUri(&hstr));
    return [NSURL URLWithString:hstrToNSStr(hstr, true)];
}

ComPtr<IInspectable> convertNSNumberToPropertyValue(NSNumber* obj) {
    ComPtr<ABI::Windows::Foundation::IPropertyValueStatics> inst;
    THROW_NS_IF_FAILED(
        ABI::Windows::Foundation::GetActivationFactory(HString::MakeReference(L"Windows.Foundation.PropertyValue").Get(), &inst));
    ComPtr<IInspectable> ret;
    const char* type = [obj objCType];
    if (strstr("cC", type) != NULL) {
        THROW_NS_IF_FAILED(inst->CreateUInt8(ToWRLConvertor<uint8_t, dummyWRLCreator>::convert(obj), ret.GetAddressOf()));
        return ret;
    }

    if (strstr("il", type) != NULL) {
        THROW_NS_IF_FAILED(inst->CreateInt32(ToWRLConvertor<int32_t, dummyWRLCreator>::convert(obj), ret.GetAddressOf()));
        return ret;
    }

    if (strstr("s", type) != NULL) {
        THROW_NS_IF_FAILED(inst->CreateInt16(ToWRLConvertor<int16_t, dummyWRLCreator>::convert(obj), ret.GetAddressOf()));
        return ret;
    }

    if (strstr("q", type) != NULL) {
        THROW_NS_IF_FAILED(inst->CreateInt64(ToWRLConvertor<int64_t, dummyWRLCreator>::convert(obj), ret.GetAddressOf()));
        return ret;
    }

    if (strstr("IL", type) != NULL) {
        THROW_NS_IF_FAILED(inst->CreateUInt32(ToWRLConvertor<uint32_t, dummyWRLCreator>::convert(obj), ret.GetAddressOf()));
        return ret;
    }

    if (strstr("S", type) != NULL) {
        THROW_NS_IF_FAILED(inst->CreateUInt16(ToWRLConvertor<uint16_t, dummyWRLCreator>::convert(obj), ret.GetAddressOf()));
        return ret;
    }

    if (strstr("Q", type) != NULL) {
        THROW_NS_IF_FAILED(inst->CreateUInt64(ToWRLConvertor<uint64_t, dummyWRLCreator>::convert(obj), ret.GetAddressOf()));
        return ret;
    }

    if (strcmp("f", type) == 0) {
        THROW_NS_IF_FAILED(inst->CreateSingle(ToWRLConvertor<float, dummyWRLCreator>::convert(obj), ret.GetAddressOf()));
        return ret;
    }

    if (strcmp("d", type) == 0) {
        THROW_NS_IF_FAILED(inst->CreateDouble(ToWRLConvertor<double, dummyWRLCreator>::convert(obj), ret.GetAddressOf()));
        return ret;
    }

    return nullptr;
}

ComPtr<IInspectable> convertNSStringToPropertyValue(NSString* obj) {
    ComPtr<ABI::Windows::Foundation::IPropertyValueStatics> inst;
    THROW_NS_IF_FAILED(
        ABI::Windows::Foundation::GetActivationFactory(HString::MakeReference(L"Windows.Foundation.PropertyValue").Get(), &inst));
    ComPtr<IInspectable> ret;
    Microsoft::WRL::Wrappers::HString hstr;
    hstr.Attach(ToWRLConvertor<HSTRING, dummyWRLCreator>::convert(obj));
    THROW_NS_IF_FAILED(inst->CreateString(hstr.Get(), ret.GetAddressOf()));
    return ret;
}
} // namespace CommonConvertors
