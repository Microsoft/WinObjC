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

#pragma once

#include "Starboard/TypeTraits.h"

#if defined(__OBJC__)
#include <Foundation/Foundation.h>
#include <CoreFoundation/CFBase.h>
#endif

#if defined(__cplusplus)

#include <memory>
#include <type_traits>

// TakeOwnershipT is an empty struct tag type used to disambiguate between different constructors for
// AutoId<T> and AutoCF<T>.
//
// The constructor overloads that use TakeOwnershipT will _consume_ a +1 reference (and not lifetime-store
// the provided object.)
namespace woc {
struct TakeOwnershipT {};
constexpr TakeOwnershipT TakeOwnership{};
}

#if defined(__OBJC__)

extern "C" id objc_storeStrong(id* object, id value); // Forward decl for non-objc.h users.

// Puzzlingly, this checks whether ARC is enabled instead of whether the compiler supports it.
#if !__has_feature(objc_arc)

// The lifetime traits herein expose behaviour analogous to the Objective-C ARC runtime support methods.
// They're intended to be used in concert with AutoId<>, below, to provide ownership semantics.

// Unsafe - a direct non-refcounting store of a refcountable object.
struct LifetimeUnsafe {
    inline static id store(id* destination, id value) {
        *destination = value;
        return value;
    }
};

// Retain - a retaining/releasing store of a refcountable object.
//  - Releases the refcounted value at the destination while never allowing
//    *destination to hold a non-owning reference.
struct LifetimeRetain {
    inline static id store(id* destination, id value) {
        // objc_storeStrong(&x, nil) will release the value at x.
        // This is in line with the implementation of ARC.
        return objc_storeStrong(destination, value);
    }
};

template <typename TObj, typename TLifetimeTraits = LifetimeRetain>
class AutoId {
private:
    using TObjPointer = typename TypeTraits::MakeObjcPointer<TObj>::type;

    template <typename TOther>
    using TCanConvertFrom = std::is_convertible<TOther, TObjPointer>;

    template <typename TOther>
    using TCanConvertTo = std::is_convertible<TObjPointer, TOther>;

    id _val = reinterpret_cast<id>(0);

public:
    AutoId() : _val(nil) {
    }

    explicit AutoId(const TObjPointer& val) : _val(nil) {
        TLifetimeTraits::store(&_val, val);
    }

    explicit AutoId(woc::TakeOwnershipT, const TObjPointer& val) : _val(val) {
    }

    // Constructor for id only when TCapturedObjPtr!=id, to break ambiguity with the Any constructor.
    template <typename TCapturedObjPtr = TObjPointer,
              typename = typename std::enable_if<!std::is_same<TCapturedObjPtr, id>::value, id>::type>
    explicit AutoId(id val) : _val(nil) {
        TLifetimeTraits::store(&_val, val);
    }

    // Constructor for ownership+id only when TCapturedObjPtr!=id, to break ambiguity with the Any constructor.
    template <typename TCapturedObjPtr = TObjPointer,
              typename = typename std::enable_if<!std::is_same<TCapturedObjPtr, id>::value, id>::type>
    explicit AutoId(woc::TakeOwnershipT, id val) : _val(val) {
    }

    template <typename Any, typename = typename std::enable_if<TCanConvertFrom<Any>::value>::type>
    AutoId(const Any& val) : _val(nil) {
        TLifetimeTraits::store(&_val, val);
    }

    template <typename Any, typename = typename std::enable_if<TCanConvertFrom<Any>::value>::type>
    AutoId(woc::TakeOwnershipT, const Any& val) : _val(val) {
    }

    // Cross-lifetime copy initialization is okay iff the object types are convertible: the type of
    // other must be convertable to our type.
    template <typename TOtherObj, typename TOtherLifetime, typename = typename std::enable_if<TCanConvertFrom<TOtherObj>::value>::type>
    AutoId(const AutoId<TOtherObj, TOtherLifetime>& other) : _val(nil) {
        TLifetimeTraits::store(&_val, other._val);
    }

    AutoId(const AutoId<TObj, TLifetimeTraits>& other) : _val(nil) {
        TLifetimeTraits::store(&_val, other._val);
    }

    // We can only move from the same lifetime, and only with convertible objects.
    template <typename TOtherObj, typename TOtherLifetime, typename = typename std::enable_if<TCanConvertFrom<TOtherObj>::value>::type>
    AutoId(AutoId<TOtherObj, TOtherLifetime>&& other) {
        static_assert(std::is_same<TLifetimeTraits, TOtherLifetime>::value,
                      "AutoId can only move from another AutoId&& with the same lifetime.");
    }

    AutoId(AutoId<TObj, TLifetimeTraits>&& other) {
        _val = other._val;
        other._val = nil;
    }

    ~AutoId() {
        TLifetimeTraits::store(&_val, nil);
    }

    // operator Any() here allows an instance of AutoId<X> to be passed as any type to which X* can convert, such as:
    // void t(NSString* x);
    // AutoId<NSMutableString> y;
    // t(y); // <-- y is convertible to NSString*, and this call succeeds.
    // and
    // NSString* x() { return AutoId<NSString*>(); }
    //
    // Note that we specifically disallow this from being 'operator id', since that override will be chosen when sending messages
    // to our object, creating ambiguity in what message we're intending to invoke. AutoId is still coercible to id via the
    // TObjPointer overload, since id is creatable without casting from any Objective C object type.

    template <typename Any, typename = typename std::enable_if<TCanConvertTo<Any>::value && !std::is_same<Any, id>::value>::type>
    explicit operator Any() const {
        return reinterpret_cast<Any>(_val);
    }

    // The object conversion operator is primarily used when an AutoId<> is the destination of a message.
    operator TObjPointer() const {
        return _val;
    }

    explicit operator bool() const {
        return _val != nil;
    }

    // The attach function assumes ownership of an already-refcounted object.
    void attach(id val) {
        if (_val == val) {
            return;
        }

        TLifetimeTraits::store(&_val, nil);
        _val = val;
    }

    // The detach function disavows ownership of a refcounted object, returning to the caller both
    // the value and the burden of its memory management.
    TObjPointer detach() {
        TObjPointer val = _val;
        _val = nil;
        return val;
    }

    // Each of the copy and move assignment operators and constructors requires two specializations:
    // Any object type, any lifetime
    // Same object, same lifetime.
    // Without the second, MSVC and clang will generate a direct value copy for
    // AutoId<id> x, y; x = y;
    // thus breaking the refcounting on the contents of x.
    //
    // The cross-lifetime copy assignment operator and constructor allow for a retaining AutoId to take a +1
    // refcount on another weakly-held AutoId's value, or for a weak AutoId to hold a weak reference
    // to a retaining AutoId's value.
    template <typename TOtherObj, typename TOtherLifetime, typename = typename std::enable_if<TCanConvertFrom<TOtherObj>::value>::type>
    AutoId<TObj, TLifetimeTraits>& operator=(const AutoId<TOtherObj, TOtherLifetime>& other) {
        TLifetimeTraits::store(&_val, other._val);
        return *this;
    }

    AutoId<TObj, TLifetimeTraits>& operator=(const AutoId<TObj, TLifetimeTraits>& other) {
        TLifetimeTraits::store(&_val, other._val);
        return *this;
    }

    // The move constructor and assignment operator disallow moving across lifetimes for reasons similar to the
    // copy allowing them: It isn't reasonable to inherit a +0 refcount in a refcounting container, and neither is
    // the converse.
    template <typename TOtherObj, typename TOtherLifetime, typename = typename std::enable_if<TCanConvertFrom<TOtherObj>::value>::type>
    AutoId<TObj, TLifetimeTraits>& operator=(AutoId<TOtherObj, TOtherLifetime>&& other) {
        static_assert(std::is_same<TLifetimeTraits, TOtherLifetime>::value,
                      "AutoId can only move from another AutoId&& with the same lifetime.");
        return *this;
    }

    AutoId<TObj, TLifetimeTraits>& operator=(AutoId<TObj, TLifetimeTraits>&& other) {
        _val = other._val;
        other._val = nil;
        return *this;
    }

    template <typename Any, typename = typename std::enable_if</*std::is_pointer<Any>::value && */ TCanConvertFrom<Any>::value>::type>
    AutoId<TObj, TLifetimeTraits>& operator=(const Any& val) {
        id idValue = (id)val;
        if (idValue == _val) {
            return *this;
        }

        TLifetimeTraits::store(&_val, idValue);
        return *this;
    }

    template <typename Any>
    bool operator!=(const Any& other) const {
        // Use a C-style cast here because we want static_cast behaviour for convertible types and
        // reinterpret_cast behaviour for pointer/value types that can't be converted.
        return (id)other != _val;
    }

    template <typename Any>
    bool operator==(const Any& other) const {
        // As above.
        return (id)other == _val;
    }

    TObjPointer operator->() {
        return _val;
    }

    TObjPointer get() {
        return _val;
    }

    // Since blocks are reference-counted, they can be stored in AutoIds.
    // This conditionally-enabled operator() provides block calling semantics to AutoIds wrapping blocks.
    template <typename... Args>
    auto operator()(Args... args) -> decltype(std::declval<TObjPointer>()(args...)) {
        return static_cast<TObjPointer>(_val)(std::forward<Args>(args)...);
    }

    template <typename TOtherObj, typename TOtherLifetime>
    friend class AutoId;
};

// This header can be included without objc.h, so it needs to blank these keywords if ARC is off.
#ifndef __unsafe_unretained
#define __unsafe_unretained
#endif

#ifndef __strong
#define __strong
#endif
#else // else(__has_feature(objc_arc))
struct LifetimeUnsafe {};
struct LifetimeRetain {};

template <typename, typename>
struct _AutoIdArcLifetimeName {};
template <typename TObjPointer>
struct _AutoIdArcLifetimeName<TObjPointer, LifetimeUnsafe> {
    using type = __unsafe_unretained TObjPointer;
};
template <typename TObjPointer>
struct _AutoIdArcLifetimeName<TObjPointer, LifetimeRetain> {
    using type = __strong TObjPointer;
};

template <typename TObj, typename TLifetimeTraits = LifetimeRetain>
using AutoId = typename _AutoIdArcLifetimeName<typename TypeTraits::MakeObjcPointer<TObj>::type, TLifetimeTraits>::type;
#endif // objc_arc

// These are temporary compatibility aliases.
template <typename TObj>
using idretaint = AutoId<TObj, LifetimeRetain>;
template <typename TObj>
using idretainp = AutoId<TObj, LifetimeRetain>;

using idretain = AutoId<id, LifetimeRetain>;

template <typename TObj>
using idtype = AutoId<TObj, LifetimeUnsafe>;

// StrongId and UnsafeId are lifetime-bound id-like types.
template <typename TObj = id>
using StrongId = AutoId<TObj, LifetimeRetain>;
template <typename TObj = id>
using UnsafeId = AutoId<TObj, LifetimeUnsafe>;

template <typename Any, typename TObj, typename TLifetimeTraits, typename = typename std::enable_if<std::is_pointer<Any>::value>::type>
bool operator==(const Any& other, const AutoId<TObj, TLifetimeTraits>& val) {
    return static_cast<id>(other) == static_cast<id>(val);
}

template <typename Any, typename TObj, typename TLifetimeTraits, typename = typename std::enable_if<std::is_pointer<Any>::value>::type>
bool operator!=(const Any& other, const AutoId<TObj, TLifetimeTraits>& val) {
    return static_cast<id>(other) != static_cast<id>(val);
}

#define idretaintype(type) AutoId<type>
#define idretainproto(type) AutoId<id<type>>

#endif

#ifdef CF_EXPORT // Quick way to detect CoreFoundation.
namespace woc {
// Unsafe - a direct non-refcounting store of a refcountable object.
struct CFLifetimeUnsafe {
    inline static CFTypeRef store(CFTypeRef* destination, CFTypeRef value) {
        *destination = value;
        return value;
    }
};

// Retain - a retaining/releasing store of a refcountable object.
//  - Releases the refcounted value at the destination while never allowing
//    *destination to hold a non-owning reference.
struct CFLifetimeRetain {
    inline static CFTypeRef store(CFTypeRef* destination, CFTypeRef value) {
        if (*destination == value) {
            return value;
        }

        if (*destination) {
            CFRelease(static_cast<CFTypeRef>(*destination));
        }

        return *destination = ((value ? CFRetain(value) : nullptr));
    }
};

namespace details {
template <typename T, typename TWrapped>
class AutoCFRef {
private:
    T* ptr;

public:
    AutoCFRef(T* ptr) : ptr(ptr) {
    }

    operator TWrapped*() const {
        return ptr->releaseAndGetAddressOf();
    }

    operator void**() const {
        return reinterpret_cast<void**>(ptr->releaseAndGetAddressOf());
    }

    operator TWrapped() const {
        return ptr->get();
    }

    operator void*() const {
        return ptr->get();
    }
};
}

template <typename T, typename TLifetimeTraits = CFLifetimeRetain>
class AutoCF {
private:
    inline CFTypeRef* _addressof() {
        using TMutable = std::add_pointer_t<std::remove_const_t<std::remove_pointer_t<T>>>;
        return const_cast<CFTypeRef*>(reinterpret_cast<void**>(const_cast<TMutable*>(&_val)));
    }

    template <typename TOther>
    using TCanConvertFrom = std::is_convertible<TOther, T>;

    template <typename TOther>
    using TCanConvertTo = std::is_convertible<T, TOther>;

    T _val = reinterpret_cast<T>(0);

public:
    AutoCF() : _val(nullptr) {
    }

    explicit AutoCF(const T& val) : _val(nullptr) {
        TLifetimeTraits::store(_addressof(), static_cast<CFTypeRef>(val));
    }

    explicit AutoCF(TakeOwnershipT, const T& val) : _val(val) {
    }

    template <typename TOtherLifetime>
    AutoCF(const AutoCF<T, TOtherLifetime>& other) : _val(nullptr) {
        TLifetimeTraits::store(_addressof(), static_cast<CFTypeRef>(other._val));
    }

    // Copy from same lifetime.
    AutoCF(const AutoCF<T, TLifetimeTraits>& other) : _val(nullptr) {
        TLifetimeTraits::store(_addressof(), static_cast<CFTypeRef>(other._val));
    }

    // We can only move from the same lifetime, and only with convertible objects.
    template <typename TOtherLifetime>
    AutoCF(AutoCF<T, TOtherLifetime>&& other) {
        static_assert(std::is_same<TLifetimeTraits, TOtherLifetime>::value,
                      "AutoCF can only move from another AutoCF&& with the same lifetime.");
    }

    // Move from same lifetime.
    AutoCF(AutoCF<T, TLifetimeTraits>&& other) : _val(other._val) {
        other._val = nullptr;
    }

    ~AutoCF() {
        TLifetimeTraits::store(_addressof(), nullptr);
    }

    operator T() const {
        return _val;
    }

    explicit operator bool() const {
        return _val != nullptr;
    }

    // The attach function assumes ownership of an already-refcounted object.
    void attach(T val) {
        if (val == _val) {
            return;
        }

        TLifetimeTraits::store(_addressof(), nullptr);
        _val = val;
    }

    // The detach function disavows ownership of a refcounted object, returning to the caller both
    // the value and the burden of its memory management.
    T detach() {
        T val = _val;
        _val = nullptr;
        return val;
    }

    // Each of the copy and move assignment operators and constructors requires two specializations:
    // Any object type, any lifetime
    // Same object, same lifetime.
    // Without the second, MSVC and clang will generate a direct value copy for
    // AutoCF<T> x, y; x = y;
    // thus breaking the refcounting on the contents of x.
    //
    // The cross-lifetime copy assignment operator and constructor allow for a retaining AutoCF to take a +1
    // refcount on another weakly-held AutoCF's value.
    template <typename TOtherLifetime>
    AutoCF<T, TLifetimeTraits>& operator=(const AutoCF<T, TOtherLifetime>& other) {
        TLifetimeTraits::store(_addressof(), static_cast<CFTypeRef>(other._val));
        return *this;
    }

    AutoCF<T, TLifetimeTraits>& operator=(const AutoCF<T, TLifetimeTraits>& other) {
        TLifetimeTraits::store(_addressof(), static_cast<CFTypeRef>(other._val));
        return *this;
    }

    // The move constructor and assignment operator disallow moving across lifetimes for reasons similar to the
    // copy allowing them: It isn't reasonable to inherit a +0 refcount in a refcounting container, and neither is
    // the converse.
    template <typename TOtherLifetime>
    AutoCF<T, TLifetimeTraits>& operator=(AutoCF<T, TOtherLifetime>&& other) {
        static_assert(std::is_same<TLifetimeTraits, TOtherLifetime>::value,
                      "AutoCF can only move from another AutoCF&& with the same lifetime.");
        return *this;
    }

    AutoCF<T, TLifetimeTraits>& operator=(AutoCF<T, TLifetimeTraits>&& other) {
        _val = other._val;
        other._val = nullptr;
        return *this;
    }

    template <typename Any, typename = typename std::enable_if<TCanConvertFrom<Any>::value>::type>
    AutoCF<T>& operator=(const Any& val) {
        TLifetimeTraits::store(_addressof(), static_cast<CFTypeRef>(val));
        return *this;
    }

    template <typename Any>
    bool operator!=(const Any& other) const {
        // Use a C-style cast here because we want static_cast behaviour for convertible types and
        // reinterpret_cast behaviour for pointer/value types that can't be converted.
        return (T)other != _val;
    }

    template <typename Any>
    bool operator==(const Any& other) const {
        // As above.
        return (T)other == _val;
    }

    T operator->() {
        return _val;
    }

    T get() const {
        return _val;
    }

    details::AutoCFRef<AutoCF<T, TLifetimeTraits>, T> operator&() {
        return details::AutoCFRef<AutoCF<T, TLifetimeTraits>, T>(this);
    }

    T* releaseAndGetAddressOf() {
        TLifetimeTraits::store(_addressof(), static_cast<CFTypeRef>(nullptr));
        return &_val;
    }

    template <typename TOtherObj, typename TOtherLifetime>
    friend class AutoCF;
};

// unique_cf was once defined to be a std::unique_ptr<T, decltype(CFRelease)>.
// This compatibility definition mimics the common use cases for the unique_ptr version of unique_cf using AutoCF.
template <typename T>
class unique_cf : public AutoCF<T, CFLifetimeRetain> {
public:
    unique_cf() : AutoCF<T, CFLifetimeRetain>() {
    }

    // The default unary T constructor for unique_ptr/cf takes full ownership of the passed-in value,
    // but the same constructor on AutoCF takes shared ownership. AutoCF's move constructor, however,
    // takes full ownership.
    unique_cf(T val) : AutoCF<T, CFLifetimeRetain>(TakeOwnership, val) {
    }

    unique_cf(unique_cf<T>&& other) : AutoCF<T, CFLifetimeRetain>(std::move(other)) {
    }

    void reset(T val = nullptr) {
        AutoCF<T, CFLifetimeRetain>::attach(val);
    }

    T release() {
        return AutoCF<T, CFLifetimeRetain>::detach();
    }

    unique_cf<T>& operator=(T val) = delete;
    unique_cf<T>& operator=(const unique_cf<T>& other) = delete;

    unique_cf<T>& operator=(unique_cf<T>&& other) {
        this->AutoCF<T>::operator=(std::move(other));
        return *this;
    }
};

template <typename T = CFTypeRef>
using StrongCF = AutoCF<T, CFLifetimeRetain>;

template <typename T = CFTypeRef>
using UnsafeCF = AutoCF<T, CFLifetimeUnsafe>;

template <typename T, typename TLifetimeTraits = CFLifetimeRetain>
inline AutoCF<T, TLifetimeTraits> MakeAutoCF(T val) {
    return AutoCF<T, TLifetimeTraits>(TakeOwnership, val);
}

template <typename T>
inline StrongCF<T> MakeStrongCF(T val) {
    return MakeAutoCF<T, CFLifetimeRetain>(val);
}
}
#endif

#else // else(!defined(__cplusplus))

#if defined(__OBJC__)
// legacy macros used in non-C++ source and header files.
// We can't ascribe to them any particularly sound lifetime semantics,
// so we have to let the runtime decide.
typedef __strong id idretain;
#define idretainproto(type) id<type>
#else
typedef id idretain;
#define idretainproto(type) idretain
#endif

#define idretaintype(type) idretain

#endif // __cplusplus
