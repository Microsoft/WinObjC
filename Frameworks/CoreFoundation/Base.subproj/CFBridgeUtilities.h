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

// WINOBJC: The following functions/macros were originally from CFInternal.h, or CFFoundationInternal.h
// They have been separated into this header, so that their code can be more broadly reused among the other
// Core* (CoreText, CoreGraphics) frameworks with bridged types.

#pragma once

#if !defined(CF_PRIVATE)
#define CF_PRIVATE __attribute__((__visibility__("hidden")))
#endif

CF_EXTERN_C_BEGIN
CF_PRIVATE void _CFRuntimeBridgeTypeToClass(CFTypeID type, const void* isa);
CF_PRIVATE uintptr_t __CFISAForTypeID(CFTypeID typeID);

// WINOBJC:
// Because registration happens at runtime, static constant CFStrings don't have yet have type ids in the class table when initialized
// NSCFString thus requires explicit handling below
// The reference platform uses a special compiler option not available to us to
// get __CFConstantStringClassReferencePtr filled out with the correct "Class". Since this isn't
// an option here, use &$_OBJC_CLASS__NSCFString instead.
// CF_EXPORT void * __CFConstantStringClassReferencePtrPtr;
// CF_EXPORT void *__CFConstantStringClassReferencePtr[];
CF_EXPORT Class $_OBJC_CLASS__NSCFString;
CF_EXPORT Class $_OBJC_CLASS__NSCFType;

// For bridged classes, which under certain circumstances, dispatch a function from C side to Objective-C side
#define CF_OBJC_FUNCDISPATCHV(type, ret, obj, ...)         \
    do {                                                   \
        if (CF_IS_OBJC(type, obj)) {                       \
            return (ret)CF_OBJC_CALLV(obj, ##__VA_ARGS__); \
        }                                                  \
    } while (0)

#define CF_OBJC_CALLV(obj, ...) [(obj)__VA_ARGS__]

// easier to read without clang-format here
// clang-format off
#define CF_IS_OBJC(typeID, obj) ( \
    /* Treat nil as ObjC */ \
    (!obj) || \
    /* Any isa means ObjC but make sure it isn't a bridge */ \
    ((((CFRuntimeBase*)(obj))->_cfisa != 0) && \
    /* Special handling for CFType  */ \
    (((CFRuntimeBase*)(obj))->_cfisa != (uintptr_t)(&$_OBJC_CLASS__NSCFType)) && \
    /* Special handling for String (see above) */ \
    (((CFRuntimeBase*)(obj))->_cfisa != (uintptr_t)(&$_OBJC_CLASS__NSCFString)) &&  \
    /* Make sure that obj isn't the concrete impl, otherwise FUNCDISPATCHV would infinitely recurse */ \
    (__CFISAForTypeID(typeID) != ((CFRuntimeBase*)(obj))->_cfisa) &&  \
    /* Make sure obj isn't a subclass (should only be KVO of the concrete bridged impl) */ \
    (![(id)(((CFRuntimeBase*)(obj)))->_cfisa isSubclassOfClass:(Class)__CFISAForTypeID(typeID)])))
// clang-format on

CF_EXTERN_C_END
