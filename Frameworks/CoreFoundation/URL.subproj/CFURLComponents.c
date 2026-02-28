// clang-format off

// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2015 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//


/*  CFURLComponents.c
    Copyright (c) 2015, Apple Inc. All rights reserved.
    Responsibility: Jim Luther/Chris Linn
*/


#include <CoreFoundation/CFURLComponents.h>
#include "CFInternal.h"
#include "CFURLComponents_Internal.h"

static CFTypeID __kCFURLComponentsTypeID = _kCFRuntimeNotATypeID;

struct __CFURLComponents {
    CFRuntimeBase _base;
    
    CFLock_t _lock;
    
    // if inited from URL, I need to keep the URL string and the parsing info
    CFStringRef _urlString;
    struct _URIParseInfo _parseInfo;
    
    /*
     Getters will get from either the URL or the set value, so if there's a url string, I need to know if we've attempted to get the value from the url. These flags indicate if the NSURLComponents' _xxxxComponent instance variables can be used.
     
     Setters will set the _xxxxComponent ivar. Components that can be percent-encoded will be percent-encoded in the _xxxxComponent ivar. For example, [NSURLComponents setPath:] will percent-encode the path argument and set _pathComponent; [NSURLComponents setPercentEncodedPath:] will simply copy the path argument and set _pathComponent.
     
     [NSURLComponents URL] and [NSURLComponents URLRelativeToURL:] will first set all components and mark them all valid.
     
     [NSURLComponents init] will set _urlString to nil, all _XXXXComponentValid flags to true, and all _XXXXComponent ivars to nil.
     */
    
    // these flags indicate if the _schemeComponent through _fragmentComponent ivars are valid or not.
    uint32_t    _schemeComponentValid   : 1;
    uint32_t    _userComponentValid     : 1;
    uint32_t    _passwordComponentValid : 1;
    uint32_t    _hostComponentValid     : 1;
    uint32_t    _portComponentValid     : 1;
    uint32_t    _pathComponentValid     : 1;
    uint32_t    _queryComponentValid    : 1;
    uint32_t    _fragmentComponentValid : 1;
    
    // These ivars are used by the getters and by [NSURLComponents URL] and [NSURLComponents URLRelativeToURL:]. The values (if not nil) are always correctly percent-encoded.
    CFStringRef _schemeComponent;
    CFStringRef _userComponent;
    CFStringRef _passwordComponent;
    CFStringRef _hostComponent;
    CFNumberRef _portComponent;
    CFStringRef _pathComponent;
    CFStringRef _queryComponent;
    CFStringRef _fragmentComponent;
};

static Boolean __CFURLComponentsEqual(CFTypeRef left, CFTypeRef right);

static CFStringRef __CFURLComponentsCopyDescription(CFTypeRef cf) {
    return CFSTR("A really nice CFURLComponents object");
}

static void __CFURLComponentsDeallocate(CFTypeRef cf) {
    CFURLComponentsRef instance = (CFURLComponentsRef)cf;
    __CFGenericValidateType(cf, _CFURLComponentsGetTypeID());
    
    if (instance->_urlString) CFRelease(instance->_urlString);
    if (instance->_schemeComponent) CFRelease(instance->_schemeComponent);
    if (instance->_userComponent) CFRelease(instance->_userComponent);
    if (instance->_passwordComponent) CFRelease(instance->_passwordComponent);
    if (instance->_hostComponent) CFRelease(instance->_hostComponent);
    if (instance->_pathComponent) CFRelease(instance->_pathComponent);
    if (instance->_queryComponent) CFRelease(instance->_queryComponent);
    if (instance->_fragmentComponent) CFRelease(instance->_fragmentComponent);
}

static const CFRuntimeClass __CFURLComponentsClass = {
    0,
    "CFURLComponents",
    NULL,      // init
    NULL,      // copy
    __CFURLComponentsDeallocate,
    __CFURLComponentsEqual,
    NULL,      // hash
    NULL,      //
    __CFURLComponentsCopyDescription
};

CFTypeID _CFURLComponentsGetTypeID(void) {
    static dispatch_once_t initOnce;
    dispatch_once(&initOnce, ^{ __kCFURLComponentsTypeID = _CFRuntimeRegisterClass(&__CFURLComponentsClass); });
    return __kCFURLComponentsTypeID;
}

CF_EXPORT CFURLComponentsRef _CFURLComponentsCreate(CFAllocatorRef alloc) {
    CFIndex size = sizeof(struct __CFURLComponents) - sizeof(CFRuntimeBase);
    CFURLComponentsRef memory = (CFURLComponentsRef)_CFRuntimeCreateInstance(alloc, _CFURLComponentsGetTypeID(), size, NULL);
    if (NULL == memory) {
        return NULL;
    }
    
    memory->_lock = CFLockInit;
    
    memory->_urlString = NULL;
    memory->_schemeComponentValid = true;
    memory->_userComponentValid = true;
    memory->_passwordComponentValid = true;
    memory->_hostComponentValid = true;
    memory->_portComponentValid = true;
    memory->_pathComponentValid = true;
    memory->_queryComponentValid = true;
    memory->_fragmentComponentValid = true;
    
    memory->_schemeComponent = NULL;
    memory->_userComponent = NULL;
    memory->_passwordComponent = NULL;
    memory->_hostComponent = NULL;
    memory->_portComponent = NULL;
    memory->_pathComponent = NULL;
    memory->_queryComponent = NULL;
    memory->_fragmentComponent = NULL;
    
    return memory;
}

CF_EXPORT CFURLComponentsRef _CFURLComponentsCreateWithURL(CFAllocatorRef alloc, CFURLRef url, Boolean resolveAgainstBaseURL) {
    CFURLComponentsRef result = NULL;
    if (resolveAgainstBaseURL) {
        CFURLRef absoluteURL = CFURLCopyAbsoluteURL(url);
        if (absoluteURL) {
            result = _CFURLComponentsCreateWithString(alloc, CFURLGetString(absoluteURL));
            CFRelease(absoluteURL);
        }
    } else {
        result = _CFURLComponentsCreateWithString(alloc, CFURLGetString(url));
    }
    return result;
}

CF_EXPORT CFURLComponentsRef _CFURLComponentsCreateWithString(CFAllocatorRef alloc, CFStringRef string) {
    CFIndex size = sizeof(struct __CFURLComponents) - sizeof(CFRuntimeBase);
    CFURLComponentsRef memory = (CFURLComponentsRef)_CFRuntimeCreateInstance(alloc, _CFURLComponentsGetTypeID(), size, NULL);
    if (NULL == memory) {
        return NULL;
    }
    
    _CFURIParserParseURIReference(string, &memory->_parseInfo);
    if (!_CFURIParserURLStringIsValid(string, &memory->_parseInfo)) {
        CFAllocatorDeallocate(alloc, memory);
        return NULL;
    }
    
    memory->_lock = CFLockInit;
    
    memory->_urlString = CFStringCreateCopy(alloc, string);
    memory->_schemeComponentValid = false;
    memory->_userComponentValid = false;
    memory->_passwordComponentValid = false;
    memory->_hostComponentValid = false;
    memory->_portComponentValid = false;
    memory->_pathComponentValid = false;
    memory->_queryComponentValid = false;
    memory->_fragmentComponentValid = false;
    
    memory->_schemeComponent = NULL;
    memory->_userComponent = NULL;
    memory->_passwordComponent = NULL;
    memory->_hostComponent = NULL;
    memory->_portComponent = NULL;
    memory->_pathComponent = NULL;
    memory->_queryComponent = NULL;
    memory->_fragmentComponent = NULL;
    
    // if paramExists, there's a semi-colon in the path
    if (memory->_parseInfo.paramExists) {
        CFStringRef path = _CFURLComponentsCopyPath(memory);
        _CFURLComponentsSetPath(memory, path);
        CFRelease(path);
    }
    
    return memory;
}

CF_EXPORT CFURLComponentsRef _CFURLComponentsCreateCopy(CFAllocatorRef alloc, CFURLComponentsRef components) {
    CFIndex size = sizeof(struct __CFURLComponents) - sizeof(CFRuntimeBase);
    CFURLComponentsRef memory = (CFURLComponentsRef)_CFRuntimeCreateInstance(alloc, _CFURLComponentsGetTypeID(), size, NULL);
    if (NULL == memory) {
        return NULL;
    }
    
    __CFLock(&components->_lock);
    memory->_lock = CFLockInit;
    memory->_urlString = components->_urlString ? CFStringCreateCopy(alloc, components->_urlString) : NULL;
    
    memory->_schemeComponentValid = components->_schemeComponentValid;
    memory->_userComponentValid = components->_userComponentValid;
    memory->_hostComponentValid = components->_hostComponentValid;
    memory->_portComponentValid = components->_portComponentValid;
    memory->_pathComponentValid = components->_pathComponentValid;
    memory->_queryComponentValid = components->_queryComponentValid;
    memory->_fragmentComponentValid = components->_fragmentComponentValid;

    memory->_schemeComponent = components->_schemeComponent ? CFStringCreateCopy(alloc, components->_schemeComponent) : NULL;
    memory->_userComponent = components->_userComponent ? CFStringCreateCopy(alloc, components->_userComponent) : NULL;;
    memory->_passwordComponent = components->_passwordComponent ? CFStringCreateCopy(alloc, components->_passwordComponent) : NULL;;
    memory->_hostComponent = components->_hostComponent ? CFStringCreateCopy(alloc, components->_hostComponent) : NULL;;
    if (components->_portComponent) {
        long long port = 0;
        CFNumberGetValue(components->_portComponent, kCFNumberLongLongType, &port);
        memory->_portComponent = CFNumberCreate(alloc, kCFNumberLongLongType, &port);
    } else {
        memory->_portComponent = NULL;
    }
    memory->_pathComponent = components->_pathComponent ? CFStringCreateCopy(alloc, components->_pathComponent) : NULL;;
    memory->_queryComponent = components->_queryComponent ? CFStringCreateCopy(alloc, components->_queryComponent) : NULL;;
    memory->_fragmentComponent = components->_fragmentComponent ? CFStringCreateCopy(alloc, components->_fragmentComponent) : NULL;;

    __CFUnlock(&components->_lock);
    
    return memory;
}

#pragma mark -

static Boolean __CFURLComponentsEqual(CFTypeRef cf1, CFTypeRef cf2) {
    CFURLComponentsRef left = (CFURLComponentsRef)cf1;
    CFURLComponentsRef right = (CFURLComponentsRef)cf2;
    
    __CFGenericValidateType(left, CFURLGetTypeID());
    __CFGenericValidateType(right, CFURLGetTypeID());
    
    if (left == right) {
        return true;
    }
    
    Boolean (^componentEqual)(CFTypeRef l, CFTypeRef r) = ^(CFTypeRef l, CFTypeRef r) {
        // if pointers are equal (including both nil), they are equal; otherwise, use isEqual
        if (l == r) {
            return (Boolean)true;
        } else {
            return CFEqual(left, r);
        }
    };
    
    CFStringRef leftPath = _CFURLComponentsCopyPercentEncodedPath(left);
    CFStringRef rightPath = _CFURLComponentsCopyPercentEncodedPath(right);
    
    CFStringRef leftHost = _CFURLComponentsCopyPercentEncodedHost(left);
    CFStringRef rightHost = _CFURLComponentsCopyPercentEncodedHost(right);
    
    CFStringRef leftQuery = _CFURLComponentsCopyPercentEncodedQuery(left);
    CFStringRef rightQuery = _CFURLComponentsCopyPercentEncodedQuery(right);
    
    CFStringRef leftFragment = _CFURLComponentsCopyPercentEncodedFragment(left);
    CFStringRef rightFragment = _CFURLComponentsCopyPercentEncodedFragment(right);
    
    CFStringRef leftUser = _CFURLComponentsCopyPercentEncodedUser(left);
    CFStringRef rightUser = _CFURLComponentsCopyPercentEncodedUser(right);
    
    CFStringRef leftPassword = _CFURLComponentsCopyPercentEncodedPassword(left);
    CFStringRef rightPassword = _CFURLComponentsCopyPercentEncodedPassword(right);
    
    
    Boolean result =
    componentEqual(left->_schemeComponent, right->_schemeComponent) &&
    componentEqual(leftPath, rightPath) &&
    componentEqual(leftHost, rightHost) &&
    componentEqual(left->_portComponent, right->_portComponent) &&
    componentEqual(leftQuery, rightQuery) &&
    componentEqual(leftFragment, rightFragment) &&
    componentEqual(leftUser, rightUser) &&
    componentEqual(leftPassword, rightPassword);
    
    if (leftPath) CFRelease(leftPath);
    if (rightPath) CFRelease(rightPath);
    
    if (leftHost) CFRelease(leftHost);
    if (rightHost) CFRelease(rightHost);
    
    if (leftQuery) CFRelease(leftQuery);
    if (rightQuery) CFRelease(rightQuery);
    
    if (leftFragment) CFRelease(leftFragment);
    if (rightFragment) CFRelease(rightFragment);
    
    if (leftUser) CFRelease(leftUser);
    if (rightUser) CFRelease(rightUser);
    
    if (leftPassword) CFRelease(leftPassword);
    if (rightPassword) CFRelease(rightPassword);
    
    return result;
}

CF_EXPORT CFURLRef _CFURLComponentsCopyURL(CFURLComponentsRef components) {
    return _CFURLComponentsCopyURLRelativeToURL(components, NULL);
}

CF_EXPORT CFURLRef _CFURLComponentsCopyURLRelativeToURL(CFURLComponentsRef components, CFURLRef relativeToURL) {
    CFStringRef urlString = _CFURLComponentsCopyString(components);
    if (urlString) {
        return CFURLCreateWithString(kCFAllocatorSystemDefault, urlString, relativeToURL);
    } else {
        return NULL;
    }
}

CF_EXPORT CFStringRef _CFURLComponentsCopyString(CFURLComponentsRef components) {
    CFStringRef result = NULL;
    
    // make sure all of the _XXXXComponent ivars are initialized
    if ( !components->_schemeComponentValid ) {
        CFStringRef temp = _CFURLComponentsCopyScheme(components);
        if (temp) CFRelease(temp);
    }
    if ( !components->_userComponentValid ) {
        CFStringRef temp = _CFURLComponentsCopyPercentEncodedUser(components);
        if (temp) CFRelease(temp);
    }
    if ( !components->_passwordComponentValid ) {
        CFStringRef temp = _CFURLComponentsCopyPercentEncodedPassword(components);
        if (temp) CFRelease(temp);
    }
    if ( !components->_hostComponentValid ) {
        CFStringRef temp = _CFURLComponentsCopyPercentEncodedHost(components);
        if (temp) CFRelease(temp);
    }
    if ( !components->_portComponentValid ) {
        CFNumberRef temp = _CFURLComponentsCopyPort(components);
        if (temp) CFRelease(temp);
    }
    if ( !components->_pathComponentValid ) {
        CFStringRef temp = _CFURLComponentsCopyPercentEncodedPath(components);
        if (temp) CFRelease(temp);
    }
    if ( !components->_queryComponentValid ) {
        CFStringRef temp = _CFURLComponentsCopyPercentEncodedQuery(components);
        if (temp) CFRelease(temp);
    }
    if ( !components->_fragmentComponentValid ) {
        CFStringRef temp = _CFURLComponentsCopyPercentEncodedFragment(components);
        if (temp) CFRelease(temp);
    }
    
    Boolean hasAuthority = (components->_userComponent || components->_passwordComponent || components->_hostComponent || components->_portComponent);
    // If there's an authority component and a path component, then the path must either begin with "/" or be an empty string.
    if ( hasAuthority && components->_pathComponent && CFStringGetLength(components->_pathComponent) && (CFStringGetCharacterAtIndex(components->_pathComponent, 0) != '/') ) {
        result = NULL;
    }
    // If there's no authority component and a path component, the path component must not start with "//".
    else if ( !hasAuthority && components->_pathComponent && CFStringGetLength(components->_pathComponent) >= 2 && (CFStringGetCharacterAtIndex(components->_pathComponent, 0) == '/') && (CFStringGetCharacterAtIndex(components->_pathComponent, 1) == '/') ) {
        result = NULL;
    }
    else {
        __CFLock(&components->_lock);
        
        CFStringAppendBuffer buf;
        UniChar chars[2];
        
        // create the URL string
        CFStringInitAppendBuffer(kCFAllocatorDefault, &buf);
        
        if ( components->_schemeComponent ) {
            // append "<scheme>:"
            CFStringAppendStringToAppendBuffer(&buf, components->_schemeComponent);
            chars[0] = ':';
            CFStringAppendCharactersToAppendBuffer(&buf, chars, 1);
        }
        if ( components->_userComponent || components->_passwordComponent || components->_hostComponent || components->_portComponent ) {
            // append "//"
            chars[0] = chars[1] = '/';
            CFStringAppendCharactersToAppendBuffer(&buf, chars, 2);
        }
        if ( components->_userComponent ) {
            // append "<user>"
            CFStringAppendStringToAppendBuffer(&buf, components->_userComponent);
        }
        if ( components->_passwordComponent ) {
            // append ":<password>"
            chars[0] = ':';
            CFStringAppendCharactersToAppendBuffer(&buf, chars, 1);
            CFStringAppendStringToAppendBuffer(&buf, components->_passwordComponent);
        }
        if ( components->_userComponent || components->_passwordComponent ) {
            // append "@"
            chars[0] = '@';
            CFStringAppendCharactersToAppendBuffer(&buf, chars, 1);
        }
        if ( components->_hostComponent ) {
            // append "<host>"
            CFStringAppendStringToAppendBuffer(&buf, components->_hostComponent);
        }
        if ( components->_portComponent ) {
            // append ":<port>"
            chars[0] = ':';
            CFStringAppendCharactersToAppendBuffer(&buf, chars, 1);
#define LONG_LONG_MAX_DIGITS 19
            long long num;
            if (!CFNumberGetValue(components->_portComponent, kCFNumberLongLongType, &num)) {
                num = 0;
            }
            char numStr[LONG_LONG_MAX_DIGITS + 1] = {0};
            snprintf(numStr, LONG_LONG_MAX_DIGITS, "%lld", num);
            CFStringRef portStr = CFStringCreateWithBytes(kCFAllocatorSystemDefault, (const UInt8 *)numStr, strlen(numStr), kCFStringEncodingASCII, false);
            CFStringAppendStringToAppendBuffer(&buf, (CFStringRef)portStr);
            CFRelease(portStr);
#undef LONG_LONG_MAX_DIGITS
        }
        if ( components->_pathComponent ) {
            // append "<path>"
            CFStringAppendStringToAppendBuffer(&buf, components->_pathComponent);
        }
        if ( components->_queryComponent ) {
            // append "?<query>"
            chars[0] = '?';
            CFStringAppendCharactersToAppendBuffer(&buf, chars, 1);
            CFStringAppendStringToAppendBuffer(&buf, components->_queryComponent);
        }
        if ( components->_fragmentComponent ) {
            // append "#<fragment>"
            chars[0] = '#';
            CFStringAppendCharactersToAppendBuffer(&buf, chars, 1);
            CFStringAppendStringToAppendBuffer(&buf, components->_fragmentComponent);
        }
        result = CFStringCreateMutableWithAppendBuffer(&buf);
        __CFUnlock(&components->_lock);
    }
    
    return ( result );
}

static inline CFStringRef CreateComponentWithURLStringRange(CFStringRef urlString, CFRange range)
{
    // the component has never been set so no nee to release it
    if ( range.location != kCFNotFound ) {
        CFRange theRange;
        theRange.location = range.location;
        theRange.length = range.length;
        return CFStringCreateWithSubstring(kCFAllocatorSystemDefault, urlString, theRange);
    }
    else {
        return NULL;
    }
}

CF_EXPORT CFStringRef _CFURLComponentsCopyScheme(CFURLComponentsRef components) {
    CFStringRef result;
    
    __CFLock(&components->_lock);
    if ( !components->_schemeComponentValid ) {
        components->_schemeComponent = CreateComponentWithURLStringRange(components->_urlString, _CFURIParserGetSchemeRange(&components->_parseInfo, false));
        components->_schemeComponentValid = true;
    }
    result = static_cast<CFStringRef>(components->_schemeComponent ? CFRetain(components->_schemeComponent) : NULL);
    __CFUnlock(&components->_lock);
    
    return ( result );
}

CF_EXPORT CFStringRef _CFURLComponentsCopyUser(CFURLComponentsRef components) {
    CFStringRef result;
    
    __CFLock(&components->_lock);
    if ( !components->_userComponentValid ) {
        components->_userComponent = CreateComponentWithURLStringRange(components->_urlString, _CFURIParserGetUserinfoNameRange(&components->_parseInfo, false));
        components->_userComponentValid = true;
    }
    result = components->_userComponent ? _CFStringCreateByRemovingPercentEncoding(kCFAllocatorSystemDefault, components->_userComponent) : NULL;
    __CFUnlock(&components->_lock);
    
    return ( result );
}

CF_EXPORT CFStringRef _CFURLComponentsCopyPassword(CFURLComponentsRef components) {
    CFStringRef result;
    
    __CFLock(&components->_lock);
    if ( !components->_passwordComponentValid ) {
        components->_passwordComponent = CreateComponentWithURLStringRange(components->_urlString, _CFURIParserGetUserinfoPasswordRange(&components->_parseInfo, false));
        components->_passwordComponentValid = true;
    }
    result = components->_passwordComponent ? _CFStringCreateByRemovingPercentEncoding(kCFAllocatorSystemDefault, components->_passwordComponent) : NULL;
    __CFUnlock(&components->_lock);
    
    return ( result );
}

CF_EXPORT CFStringRef _CFURLComponentsCopyHost(CFURLComponentsRef components) {
    CFStringRef result;
    
    __CFLock(&components->_lock);
    if ( !components->_hostComponentValid ) {
        components->_hostComponent = CreateComponentWithURLStringRange(components->_urlString, _CFURIParserGetHostRange(&components->_parseInfo, false));
        components->_hostComponentValid = true;
    }
    result = components->_hostComponent ? _CFStringCreateByRemovingPercentEncoding(kCFAllocatorSystemDefault, components->_hostComponent) : NULL;
    __CFUnlock(&components->_lock);
    
    return ( result );
}

CF_EXPORT CFNumberRef _CFURLComponentsCopyPort(CFURLComponentsRef components) {
    CFNumberRef result;
    
    __CFLock(&components->_lock);
    if ( !components->_portComponentValid ) {
        CFRange range = _CFURIParserGetPortRange(&components->_parseInfo, false);
        // rfc3986 says URI producers should omit the port component and its ":" delimiter if port is empty.
        if ( range.location != kCFNotFound && range.length != 0) {
            CFStringRef portString = CFStringCreateWithSubstring(kCFAllocatorSystemDefault, components->_urlString, CFRangeMake(range.location, range.length));
            char buf[16];
            if (!CFStringGetCString(portString, buf, 16, kCFStringEncodingASCII)) {
                HALT;
            }
            long long value;
#if DEPLOYMENT_TARGET_LINUX
            if (sscanf(buf, "%lld", &value) != 1) {
                HALT;
            }
#else
            if (_sscanf_s_l(buf, "%lld", NULL, &value) != 1) {
                HALT;
            }
#endif
            components->_portComponent = CFNumberCreate(kCFAllocatorSystemDefault, kCFNumberLongLongType, &value);
            CFRelease(portString);
        }
        else {
            components->_portComponent = NULL; // WINOBJC: nil->NULL
        }
        components->_portComponentValid = true;
    }
    result = static_cast<CFNumberRef>(components->_portComponent ? CFRetain(components->_portComponent) : NULL);
    __CFUnlock(&components->_lock);
    
    return ( result );
}

CF_EXPORT CFStringRef _CFURLComponentsCopyPath(CFURLComponentsRef components) {
    CFStringRef result;
    
    __CFLock(&components->_lock);
    if ( !components->_pathComponentValid ) {
        components->_pathComponent = CreateComponentWithURLStringRange(components->_urlString, _CFURIParserGetPathRange(&components->_parseInfo, false, false));
        components->_pathComponentValid = true;
    }
    if (!components->_pathComponent) {
        result = CFSTR("");
    } else {
        result = _CFStringCreateByRemovingPercentEncoding(kCFAllocatorSystemDefault, components->_pathComponent);
        if (!result) {
            result = CFSTR("");
        }
    }
    __CFUnlock(&components->_lock);
    
    return ( result );
}

CF_EXPORT CFStringRef _CFURLComponentsCopyQuery(CFURLComponentsRef components) {
    CFStringRef result;
    
    __CFLock(&components->_lock);
    if ( !components->_queryComponentValid ) {
        components->_queryComponent = CreateComponentWithURLStringRange(components->_urlString, _CFURIParserGetQueryRange(&components->_parseInfo, false));
        components->_queryComponentValid = true;
    }
    result = components->_queryComponent ? _CFStringCreateByRemovingPercentEncoding(kCFAllocatorSystemDefault, components->_queryComponent) : NULL;
    __CFUnlock(&components->_lock);
    
    return ( result );
}

CF_EXPORT CFStringRef _CFURLComponentsCopyFragment(CFURLComponentsRef components) {
    CFStringRef result;
    
    __CFLock(&components->_lock);
    if ( !components->_fragmentComponentValid ) {
        components->_fragmentComponent = CreateComponentWithURLStringRange(components->_urlString, _CFURIParserGetFragmentRange(&components->_parseInfo, false));
        components->_fragmentComponentValid = true;
    }
    result = components->_fragmentComponent ? _CFStringCreateByRemovingPercentEncoding(kCFAllocatorSystemDefault, components->_fragmentComponent) : NULL;
    __CFUnlock(&components->_lock);
    
    return ( result );
}

CF_EXPORT Boolean _CFURLComponentsSetScheme(CFURLComponentsRef components, CFStringRef scheme) {
    if ( scheme ) {
        Boolean valid = false;
        CFIndex length = CFStringGetLength(scheme);
        if ( length != 0 ) {
            UniChar ch = CFStringGetCharacterAtIndex(scheme, 0);
            valid = (ch <= 127) && _CFURIParserAlphaAllowed(ch) && _CFURIParserValidateComponent(scheme, CFRangeMake(1, length - 1), kURLSchemeAllowed, false);
        }
        if ( !valid ) {
            // invalid characters in scheme
            return false;
        }
    }
    __CFLock(&components->_lock);
    if (components->_schemeComponent) CFRelease(components->_schemeComponent);
    components->_schemeComponent = scheme ? CFStringCreateCopy(kCFAllocatorSystemDefault, scheme) : NULL;
    components->_schemeComponentValid = true;
    __CFUnlock(&components->_lock);
    return true;
}

CF_EXPORT Boolean _CFURLComponentsSetUser(CFURLComponentsRef components, CFStringRef user) {
    __CFLock(&components->_lock);
    if (components->_userComponent) CFRelease(components->_userComponent);
    components->_userComponent = user ? _CFStringCreateByAddingPercentEncodingWithAllowedCharacters(kCFAllocatorSystemDefault, user, _CFURLComponentsGetURLUserAllowedCharacterSet()) : NULL;
    components->_userComponentValid = true;
    __CFUnlock(&components->_lock);
    return true;
}

CF_EXPORT Boolean _CFURLComponentsSetPassword(CFURLComponentsRef components, CFStringRef password) {
    __CFLock(&components->_lock);
    if (components->_passwordComponent) CFRelease(components->_passwordComponent);
    components->_passwordComponent = password ? _CFStringCreateByAddingPercentEncodingWithAllowedCharacters(kCFAllocatorSystemDefault, password, _CFURLComponentsGetURLPasswordAllowedCharacterSet()) : NULL;
    components->_passwordComponentValid = true;
    __CFUnlock(&components->_lock);
    return true;
}

CF_EXPORT Boolean _CFURLComponentsSetHost(CFURLComponentsRef components, CFStringRef host) {
    __CFLock(&components->_lock);
    if (components->_hostComponent) CFRelease(components->_hostComponent);
    components->_hostComponent = host ? _CFStringCreateByAddingPercentEncodingWithAllowedCharacters(kCFAllocatorSystemDefault, host, _CFURLComponentsGetURLHostAllowedCharacterSet()) : NULL;
    components->_hostComponentValid = true;
    __CFUnlock(&components->_lock);
    return true;
}

CF_EXPORT Boolean _CFURLComponentsSetPort(CFURLComponentsRef components, CFNumberRef port) {
    long long portNumber = 0;
    if ( port ) {
        // make sure the port number is a non-negative integer
        if ( !CFNumberGetValue(port, kCFNumberLongLongType, &portNumber) || portNumber < 0 ) {
            // negative port number
            return false;
        }
    }
    __CFLock(&components->_lock);
    if (components->_portComponent) CFRelease(components->_portComponent);
    if (port) {
        components->_portComponent = CFNumberCreate(kCFAllocatorSystemDefault, kCFNumberLongLongType, &portNumber);
    } else {
        components->_portComponent = NULL;
    }
    // WINOBJC: should be _portComponentValid instead
    // components->_passwordComponentValid = true;
    components->_portComponentValid = true;
    __CFUnlock(&components->_lock);
    return true;
}

CF_EXPORT Boolean _CFURLComponentsSetPath(CFURLComponentsRef components, CFStringRef path) {
    __CFLock(&components->_lock);
    if (components->_pathComponent) CFRelease(components->_pathComponent);
    components->_pathComponent = path ? _CFStringCreateByAddingPercentEncodingWithAllowedCharacters(kCFAllocatorSystemDefault, path, _CFURLComponentsGetURLPathAllowedCharacterSet()) : NULL;
    components->_pathComponentValid = true;
    __CFUnlock(&components->_lock);
    return true;
}

CF_EXPORT Boolean _CFURLComponentsSetQuery(CFURLComponentsRef components, CFStringRef query) {
    __CFLock(&components->_lock);
    if (components->_queryComponent) CFRelease(components->_queryComponent);
    components->_queryComponent = query ? _CFStringCreateByAddingPercentEncodingWithAllowedCharacters(kCFAllocatorSystemDefault, query, _CFURLComponentsGetURLQueryAllowedCharacterSet()) : NULL;
    components->_queryComponentValid = true;
    __CFUnlock(&components->_lock);
    return true;
}

CF_EXPORT Boolean _CFURLComponentsSetFragment(CFURLComponentsRef components, CFStringRef fragment) {
    __CFLock(&components->_lock);
    if (components->_fragmentComponent) CFRelease(components->_fragmentComponent);
    components->_fragmentComponent = fragment ? _CFStringCreateByAddingPercentEncodingWithAllowedCharacters(kCFAllocatorSystemDefault, fragment, _CFURLComponentsGetURLFragmentAllowedCharacterSet()) : NULL;
    components->_fragmentComponentValid = true;
    __CFUnlock(&components->_lock);
    return true;
}

CF_EXPORT CFStringRef _CFURLComponentsCopyPercentEncodedUser(CFURLComponentsRef components) {
    CFStringRef result;

    __CFLock(&components->_lock);
    if ( !components->_userComponentValid ) {
        components->_userComponent = CreateComponentWithURLStringRange(components->_urlString, _CFURIParserGetUserinfoNameRange(&components->_parseInfo, false));
        components->_userComponentValid = true;
    }
    result = static_cast<CFStringRef>(components->_userComponent ? CFRetain(components->_userComponent) : NULL);
    __CFUnlock(&components->_lock);
    
    return ( result );
}

CF_EXPORT CFStringRef _CFURLComponentsCopyPercentEncodedPassword(CFURLComponentsRef components) {
    CFStringRef result;
    
    __CFLock(&components->_lock);
    if ( !components->_passwordComponentValid ) {
        components->_passwordComponent = CreateComponentWithURLStringRange(components->_urlString, _CFURIParserGetUserinfoPasswordRange(&components->_parseInfo, false));
        components->_passwordComponentValid = true;
    }
    result = static_cast<CFStringRef>(components->_passwordComponent ? CFRetain(components->_passwordComponent) : NULL);
    __CFUnlock(&components->_lock);
    
    return ( result );
}

CF_EXPORT CFStringRef _CFURLComponentsCopyPercentEncodedHost(CFURLComponentsRef components) {
    CFStringRef result;
    
    __CFLock(&components->_lock);
    if ( !components->_hostComponentValid ) {
        components->_hostComponent = CreateComponentWithURLStringRange(components->_urlString, _CFURIParserGetHostRange(&components->_parseInfo, false));
        components->_hostComponentValid = true;
    }
    result = static_cast<CFStringRef>(components->_hostComponent ? CFRetain(components->_hostComponent) : NULL);
    __CFUnlock(&components->_lock);
    
    return ( result );
}

CF_EXPORT CFStringRef _CFURLComponentsCopyPercentEncodedPath(CFURLComponentsRef components) {
    CFStringRef result;
    
    __CFLock(&components->_lock);
    if ( !components->_pathComponentValid ) {
        components->_pathComponent = CreateComponentWithURLStringRange(components->_urlString, _CFURIParserGetPathRange(&components->_parseInfo, false, false));
        components->_pathComponentValid = true;
    }
    result = static_cast<CFStringRef>(components->_pathComponent ? CFRetain(components->_pathComponent) : NULL);
    __CFUnlock(&components->_lock);
    
    if (!result) result = CFSTR("");
    
    return ( result );
}

CF_EXPORT CFStringRef _CFURLComponentsCopyPercentEncodedQuery(CFURLComponentsRef components) {
    CFStringRef result;
    
    __CFLock(&components->_lock);
    if ( !components->_queryComponentValid ) {
        components->_queryComponent = CreateComponentWithURLStringRange(components->_urlString, _CFURIParserGetQueryRange(&components->_parseInfo, false));
        components->_queryComponentValid = true;
    }
    result = static_cast<CFStringRef>(components->_queryComponent ? CFRetain(components->_queryComponent) : NULL);
    __CFUnlock(&components->_lock);
    
    return ( result );
}

CF_EXPORT CFStringRef _CFURLComponentsCopyPercentEncodedFragment(CFURLComponentsRef components) {
    CFStringRef result;
    
    __CFLock(&components->_lock);
    if ( !components->_fragmentComponentValid ) {
        components->_fragmentComponent = CreateComponentWithURLStringRange(components->_urlString, _CFURIParserGetFragmentRange(&components->_parseInfo, false));
        components->_fragmentComponentValid = true;
    }
    result = static_cast<CFStringRef>(components->_fragmentComponent ? CFRetain(components->_fragmentComponent) : NULL);
    __CFUnlock(&components->_lock);
    
    return ( result );
}

CF_EXPORT Boolean _CFURLComponentsSetPercentEncodedUser(CFURLComponentsRef components, CFStringRef percentEncodedUser) {
    if ( percentEncodedUser ) {
        if ( !_CFURIParserValidateComponent(percentEncodedUser, CFRangeMake(0, CFStringGetLength(percentEncodedUser)), kURLUserAllowed, true) ) {
            //  invalid characters in percentEncodedUser
            return false;
        }
    }
    __CFLock(&components->_lock);
    if (components->_userComponent) CFRelease(components->_userComponent);
    components->_userComponent = percentEncodedUser ? CFStringCreateCopy(kCFAllocatorSystemDefault, percentEncodedUser) : NULL;
    components->_userComponentValid = true;
    __CFUnlock(&components->_lock);
    return true;
}

CF_EXPORT Boolean _CFURLComponentsSetPercentEncodedPassword(CFURLComponentsRef components, CFStringRef percentEncodedPassword) {
    if ( percentEncodedPassword ) {
        if ( !_CFURIParserValidateComponent(percentEncodedPassword, CFRangeMake(0, CFStringGetLength(percentEncodedPassword)), kURLPasswordAllowed, true) ) {
            // invalid characters in percentEncodedPassword
            return false;
        }
    }
    __CFLock(&components->_lock);
    if (components->_passwordComponent) CFRelease(components->_passwordComponent);
    components->_passwordComponent = percentEncodedPassword ? CFStringCreateCopy(kCFAllocatorSystemDefault, percentEncodedPassword) : NULL;
    components->_passwordComponentValid = true;
    __CFUnlock(&components->_lock);
    return true;
}

CF_EXPORT Boolean _CFURLComponentsSetPercentEncodedHost(CFURLComponentsRef components, CFStringRef percentEncodedHost) {
    if ( percentEncodedHost ) {
        CFIndex length = CFStringGetLength(percentEncodedHost);
        CFRange componentRange;
        if ( (length >= 2) && (CFStringGetCharacterAtIndex(percentEncodedHost, 0) == '[') && (CFStringGetCharacterAtIndex(percentEncodedHost, length - 1) == ']') ) {
            // the host is an IP-Literal -- only validate the characters inside brackets
            componentRange = CFRangeMake(1, length - 2);
        }
        else {
            componentRange = CFRangeMake(0, length);
        }
        if ( !_CFURIParserValidateComponent(percentEncodedHost, componentRange, kURLHostAllowed, true) ) {
            // invalid characters in percentEncodedHost
            return false;
        }
    }
    __CFLock(&components->_lock);
    if (components->_hostComponent) CFRelease(components->_hostComponent);
    components->_hostComponent = percentEncodedHost ? CFStringCreateCopy(kCFAllocatorSystemDefault, percentEncodedHost) : NULL;
    components->_hostComponentValid = true;
    __CFUnlock(&components->_lock);
    return true;
}

CF_EXPORT Boolean _CFURLComponentsSetPercentEncodedPath(CFURLComponentsRef components, CFStringRef percentEncodedPath) {
    if ( percentEncodedPath ) {
        if ( !_CFURIParserValidateComponent(percentEncodedPath, CFRangeMake(0, CFStringGetLength(percentEncodedPath)), kURLPathAllowed, true) ) {
            // invalid characters in percentEncodedPath
            return false;
        }
    }
    __CFLock(&components->_lock);
    if (components->_pathComponent) CFRelease(components->_pathComponent);
    components->_pathComponent = percentEncodedPath ? CFStringCreateCopy(kCFAllocatorSystemDefault, percentEncodedPath) : NULL;
    components->_pathComponentValid = true;
    __CFUnlock(&components->_lock);
    return true;
}

CF_EXPORT Boolean _CFURLComponentsSetPercentEncodedQuery(CFURLComponentsRef components, CFStringRef percentEncodedQuery) {
    if ( percentEncodedQuery ) {
        if ( !_CFURIParserValidateComponent(percentEncodedQuery, CFRangeMake(0, CFStringGetLength(percentEncodedQuery)), kURLQueryAllowed, true) ) {
            // invalid characters in percentEncodedQuery
            return false;
        }
    }
    __CFLock(&components->_lock);
    if (components->_queryComponent) CFRelease(components->_queryComponent);
    components->_queryComponent = percentEncodedQuery ? CFStringCreateCopy(kCFAllocatorSystemDefault, percentEncodedQuery) : NULL;
    components->_queryComponentValid = true;
    __CFUnlock(&components->_lock);
    return true;
}

CF_EXPORT Boolean _CFURLComponentsSetPercentEncodedFragment(CFURLComponentsRef components, CFStringRef percentEncodedFragment) {
    if ( percentEncodedFragment ) {
        if ( !_CFURIParserValidateComponent(percentEncodedFragment, CFRangeMake(0, CFStringGetLength(percentEncodedFragment)), kURLFragmentAllowed, true) ) {
            // invalid characters in percentEncodedFragment
            return false;
        }
    }
    __CFLock(&components->_lock);
    if (components->_fragmentComponent) CFRelease(components->_fragmentComponent);
    components->_fragmentComponent = percentEncodedFragment ? CFStringCreateCopy(kCFAllocatorSystemDefault, percentEncodedFragment) : NULL;
    components->_fragmentComponentValid = true;
    __CFUnlock(&components->_lock);
    return true;
}

static Boolean _CFURLComponentsParseInfoIsValid(CFURLComponentsRef components) {
    // if all _xxxxComponentValid flags are false, then _urlString is the string and _parseInfo is valid
    return ( !components->_schemeComponentValid && !components->_userComponentValid && !components->_passwordComponentValid && !components->_hostComponentValid && !components->_portComponentValid && !components->_pathComponentValid && !components->_queryComponentValid && !components->_fragmentComponentValid);
}

CF_EXPORT CFRange _CFURLComponentsGetRangeOfScheme(CFURLComponentsRef components) {
    struct _URIParseInfo stringParseInfo;
    struct _URIParseInfo *theParseInfo;
    if ( _CFURLComponentsParseInfoIsValid(components) ) {
        // use the range info in _URIParseInfo is valid
        theParseInfo = &components->_parseInfo;
    }
    else {
        // we need to get the current string, parse it, and use its range info
        theParseInfo = &stringParseInfo;
        CFStringRef str = _CFURLComponentsCopyString(components);
        _CFURIParserParseURIReference(str, theParseInfo);
        CFRelease(str);
    }
    return ( _CFURIParserGetSchemeRange(theParseInfo, false) );
}

CF_EXPORT CFRange _CFURLComponentsGetRangeOfUser(CFURLComponentsRef components) {
    struct _URIParseInfo stringParseInfo;
    struct _URIParseInfo *theParseInfo;
    if ( _CFURLComponentsParseInfoIsValid(components) ) {
        // use the range info in _URIParseInfo is valid
        theParseInfo = &components->_parseInfo;
    }
    else {
        // we need to get the current string, parse it, and use its range info
        theParseInfo = &stringParseInfo;
        CFStringRef str = _CFURLComponentsCopyString(components);
        _CFURIParserParseURIReference(str, theParseInfo);
        CFRelease(str);
    }
    return ( _CFURIParserGetUserinfoNameRange(theParseInfo, false) );
}

CF_EXPORT CFRange _CFURLComponentsGetRangeOfPassword(CFURLComponentsRef components) {
    struct _URIParseInfo stringParseInfo;
    struct _URIParseInfo *theParseInfo;
    if ( _CFURLComponentsParseInfoIsValid(components) ) {
        // use the range info in _URIParseInfo is valid
        theParseInfo = &components->_parseInfo;
    }
    else {
        // we need to get the current string, parse it, and use its range info
        theParseInfo = &stringParseInfo;
        CFStringRef str = _CFURLComponentsCopyString(components);
        _CFURIParserParseURIReference(str, theParseInfo);
        CFRelease(str);
    }
    return ( _CFURIParserGetUserinfoPasswordRange(theParseInfo, false) );
}

CF_EXPORT CFRange _CFURLComponentsGetRangeOfHost(CFURLComponentsRef components) {
    struct _URIParseInfo stringParseInfo;
    struct _URIParseInfo *theParseInfo;
    if ( _CFURLComponentsParseInfoIsValid(components) ) {
        // use the range info in _URIParseInfo is valid
        theParseInfo = &components->_parseInfo;
    }
    else {
        // we need to get the current string, parse it, and use its range info
        theParseInfo = &stringParseInfo;
        CFStringRef str = _CFURLComponentsCopyString(components);
        _CFURIParserParseURIReference(str, theParseInfo);
        CFRelease(str);
    }
    return ( _CFURIParserGetHostRange(theParseInfo, false) );
}

CF_EXPORT CFRange _CFURLComponentsGetRangeOfPort(CFURLComponentsRef components) {
    struct _URIParseInfo stringParseInfo;
    struct _URIParseInfo *theParseInfo;
    if ( _CFURLComponentsParseInfoIsValid(components) ) {
        // use the range info in _URIParseInfo is valid
        theParseInfo = &components->_parseInfo;
    }
    else {
        // we need to get the current string, parse it, and use its range info
        theParseInfo = &stringParseInfo;
        CFStringRef str = _CFURLComponentsCopyString(components);
        _CFURIParserParseURIReference(str, theParseInfo);
        CFRelease(str);
    }
    return ( _CFURIParserGetPortRange(theParseInfo, false) );
}

CF_EXPORT CFRange _CFURLComponentsGetRangeOfPath(CFURLComponentsRef components) {
    struct _URIParseInfo stringParseInfo;
    struct _URIParseInfo *theParseInfo;
    if ( _CFURLComponentsParseInfoIsValid(components) ) {
        // use the range info in _URIParseInfo is valid
        theParseInfo = &components->_parseInfo;
    }
    else {
        // we need to get the current string, parse it, and use its range info
        theParseInfo = &stringParseInfo;
        CFStringRef str = _CFURLComponentsCopyString(components);
        _CFURIParserParseURIReference(str, theParseInfo);
        CFRelease(str);
    }
    return ( _CFURIParserGetPathRange(theParseInfo, false, false) );
}

CF_EXPORT CFRange _CFURLComponentsGetRangeOfQuery(CFURLComponentsRef components) {
    struct _URIParseInfo stringParseInfo;
    struct _URIParseInfo *theParseInfo;
    if ( _CFURLComponentsParseInfoIsValid(components) ) {
        // use the range info in _URIParseInfo is valid
        theParseInfo = &components->_parseInfo;
    }
    else {
        // we need to get the current string, parse it, and use its range info
        theParseInfo = &stringParseInfo;
        CFStringRef str = _CFURLComponentsCopyString(components);
        _CFURIParserParseURIReference(str, theParseInfo);
        CFRelease(str);
    }
    return ( _CFURIParserGetQueryRange(theParseInfo, false) );
}

CF_EXPORT CFRange _CFURLComponentsGetRangeOfFragment(CFURLComponentsRef components) {
    struct _URIParseInfo stringParseInfo;
    struct _URIParseInfo *theParseInfo;
    if ( _CFURLComponentsParseInfoIsValid(components) ) {
        // use the range info in _URIParseInfo is valid
        theParseInfo = &components->_parseInfo;
    }
    else {
        // we need to get the current string, parse it, and use its range info
        theParseInfo = &stringParseInfo;
        CFStringRef str = _CFURLComponentsCopyString(components);
        _CFURIParserParseURIReference(str, theParseInfo);
        CFRelease(str);
    }
    return ( _CFURIParserGetFragmentRange(theParseInfo, false) );
}

// Returns an array of dictionaries; each dictionary has two keys: "name", for the name, and "value" for the value. If one of the keys is missing then we did not populate that part of the entry.
CF_EXPORT CFArrayRef _CFURLComponentsCopyQueryItems(CFURLComponentsRef components) {
    CFStringRef queryString = _CFURLComponentsCopyPercentEncodedQuery(components);
    CFArrayRef result = NULL;
    
    if ( queryString ) {
        CFIndex len = CFStringGetLength(queryString);
        if ( len ) {
            CFMutableArrayRef intermediateResult = CFArrayCreateMutable(kCFAllocatorSystemDefault, 0, &kCFTypeArrayCallBacks);
            
            CFStringInlineBuffer buf;
            CFStringInitInlineBuffer((CFStringRef)queryString, &buf, CFRangeMake(0, len));
            CFStringRef nameString;
            CFStringRef valueString;
            CFRange nameRange;
            CFRange valueRange;
            nameRange.location = 0;
            valueRange.location = kCFNotFound;
            CFIndex idx = 0;
            Boolean sawPercent = false;
            for ( idx = 0; idx < len; ++idx ) {
                UniChar ch = CFStringGetCharacterFromInlineBuffer(&buf, idx);
                if ( ch == '=' ) {
                    if ( nameRange.location != kCFNotFound ) {
                        // found the end of the name string
                        nameRange.length = idx - nameRange.location;
                        if ( nameRange.length ) {
                            nameString = CFStringCreateWithSubstring(kCFAllocatorSystemDefault, queryString, nameRange);
                            if ( sawPercent ) {
                                CFStringRef temp = _CFStringCreateByRemovingPercentEncoding(kCFAllocatorSystemDefault, nameString);
                                CFRelease(nameString);
                                nameString = temp;
                                sawPercent = false;
                            }
                        }
                        else {
                            nameString = CFSTR("");
                        }
                        nameRange.location = kCFNotFound;
                        valueRange.location = idx + 1;
                    }
                    // else found an '=' that is part of the value string
                }
                else if ( ch == '&' ) {
                    // found end of name-value pair
                    if ( valueRange.location != kCFNotFound ) {
                        // found the end of the value string
                        valueRange.length = idx - valueRange.location;
                        if ( valueRange.length ) {
                            valueString = CFStringCreateWithSubstring(kCFAllocatorSystemDefault, queryString, valueRange);
                            if ( sawPercent ) {
                                CFStringRef temp = _CFStringCreateByRemovingPercentEncoding(kCFAllocatorSystemDefault, valueString);
                                CFRelease(valueString);
                                valueString = temp;
                                sawPercent = false;
                            }
                        }
                        else {
                            valueString = CFSTR("");
                        }
                        CFTypeRef keys[] = {CFSTR("name"), CFSTR("value")};
                        CFTypeRef values[] = {nameString, valueString};
                        CFDictionaryRef entry = CFDictionaryCreate(kCFAllocatorSystemDefault, keys, values, 2, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
                        CFArrayAppendValue(intermediateResult, entry);
                        CFRelease(entry);
                        valueRange.location = kCFNotFound;
                        CFRelease(nameString);
                        CFRelease(valueString);
                    }
                    else {
                        // there was no value string, so this was the end of the name string
                        nameRange.length = idx - nameRange.location;
                        if ( nameRange.length ) {
                            nameString = CFStringCreateWithSubstring(kCFAllocatorSystemDefault, queryString, nameRange);
                            if ( sawPercent ) {
                                CFStringRef temp = _CFStringCreateByRemovingPercentEncoding(kCFAllocatorSystemDefault, nameString);
                                CFRelease(nameString);
                                nameString = temp;
                                sawPercent = false;
                            }
                        }
                        else {
                            nameString =  CFSTR("");
                        }
                        CFTypeRef keys[] = {CFSTR("name")};
                        CFTypeRef values[] = {nameString};
                        CFDictionaryRef entry = CFDictionaryCreate(kCFAllocatorSystemDefault, keys, values, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
                        CFArrayAppendValue(intermediateResult, entry);
                        CFRelease(entry);
                        CFRelease(nameString);
                    }
                    nameRange.location = idx + 1;
                }
                else if ( ch == '%' ) {
                    sawPercent = YES;
                }
            }
            
            if ( valueRange.location != kCFNotFound ) {
                // at end of query while parsing the value string
                valueRange.length = idx - valueRange.location;
                if ( valueRange.length ) {
                    valueString = CFStringCreateWithSubstring(kCFAllocatorSystemDefault, queryString, valueRange);
                    if ( sawPercent ) {
                        CFStringRef temp = _CFStringCreateByRemovingPercentEncoding(kCFAllocatorSystemDefault, valueString);
                        CFRelease(valueString);
                        valueString = temp;
                        sawPercent = false;
                    }
                }
                else {
                    valueString = CFSTR("");
                }
                CFTypeRef keys[] = {CFSTR("name"), CFSTR("value")};
                CFTypeRef values[] = {nameString, valueString};
                CFDictionaryRef entry = CFDictionaryCreate(kCFAllocatorSystemDefault, keys, values, 2, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
                CFArrayAppendValue(intermediateResult, entry);
                CFRelease(entry);
                CFRelease(nameString);
            }
            else {
                // at end of query while parsing the name string
                nameRange.length = idx - nameRange.location;
                if ( nameRange.length ) {
                    nameString = CFStringCreateWithSubstring(kCFAllocatorSystemDefault, queryString, nameRange);
                    if ( sawPercent ) {
                        CFStringRef temp = _CFStringCreateByRemovingPercentEncoding(kCFAllocatorSystemDefault, nameString);
                        CFRelease(nameString);
                        nameString = temp;
                        sawPercent = false;
                    }
                }
                else {
                    nameString =  CFSTR("");
                }
                CFTypeRef keys[] = {CFSTR("name")};
                CFTypeRef values[] = {nameString};
                CFDictionaryRef entry = CFDictionaryCreate(kCFAllocatorSystemDefault, keys, values, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
                CFArrayAppendValue(intermediateResult, entry);
                CFRelease(entry);
                CFRelease(nameString);
            }
            
            result = (CFArrayRef)intermediateResult;
        }
        else {
            // If the query component is an empty string, return an empty array
            result = CFArrayCreate(kCFAllocatorSystemDefault, NULL, 0, &kCFTypeArrayCallBacks);
        }
        
        CFRelease(queryString);
    }
    else {
        // If there is no query component, return nothing
    }
    return ( result );
}

// n.b. names and values must have the same length
CF_EXPORT void _CFURLComponentsSetQueryItems(CFURLComponentsRef components, CFArrayRef names, CFArrayRef values) {
    if ( names != NULL ) {
        if ( CFArrayGetCount(names) != CFArrayGetCount(values) ) HALT;
        if ( CFArrayGetCount(names) ) {
            CFStringAppendBuffer buf;
            CFStringInitAppendBuffer(kCFAllocatorDefault, &buf);
            UniChar chars[1];
            static CFMutableCharacterSetRef queryNameValueAllowed = NULL;
            static dispatch_once_t onceToken;
            dispatch_once(&onceToken, ^{
                queryNameValueAllowed = CFCharacterSetCreateMutableCopy(kCFAllocatorSystemDefault, _CFURLComponentsGetURLQueryAllowedCharacterSet());
                CFCharacterSetRemoveCharactersInString(queryNameValueAllowed, CFSTR("&="));
            });
            CFIndex namesLength = CFArrayGetCount(names);
            Boolean first = true;
            for (CFIndex i = 0; i < namesLength; i++) {
                if ( !first ) {
                    chars[0] = '&';
                    CFStringAppendCharactersToAppendBuffer(&buf, chars, 1);
                }
                else {
                    first = false;
                }
                CFTypeRef name = CFArrayGetValueAtIndex(names, i);
                CFTypeRef value = CFArrayGetValueAtIndex(values, i);
                if ( name && name != kCFNull ) {
                    CFStringRef stringWithPercentEncoding = _CFStringCreateByAddingPercentEncodingWithAllowedCharacters(kCFAllocatorSystemDefault, static_cast<CFStringRef>(name), queryNameValueAllowed);
                    CFStringAppendStringToAppendBuffer(&buf, stringWithPercentEncoding);
                    CFRelease(stringWithPercentEncoding);
                }
                if ( value && value != kCFNull ) {
                    chars[0] = '=';
                    CFStringAppendCharactersToAppendBuffer(&buf, chars, 1);
                    CFStringRef stringWithPercentEncoding = _CFStringCreateByAddingPercentEncodingWithAllowedCharacters(kCFAllocatorSystemDefault, static_cast<CFStringRef>(value), queryNameValueAllowed);
                    // WINOBJC: Make sure the string we append is percent-encoded
                    CFStringAppendStringToAppendBuffer(&buf, stringWithPercentEncoding);
                    CFRelease(stringWithPercentEncoding);
                }
                // else the query item string will be simply "name"
            }
            CFStringRef queryString = CFStringCreateMutableWithAppendBuffer(&buf);
            _CFURLComponentsSetPercentEncodedQuery(components, queryString);
            CFRelease(queryString);
        }
        else {
            // If there's an array but the count is zero, set the query to a zero length string
            _CFURLComponentsSetPercentEncodedQuery(components, CFSTR(""));
        }
    }
    else {
        // If there is no items array, set the query to nil
        _CFURLComponentsSetPercentEncodedQuery(components, NULL);
    }
}

// clang-format on
