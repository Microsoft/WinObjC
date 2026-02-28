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
// Windows Internal Libraries (wil)
//! @file
//! Windows Error Handling Helpers: standard error handling mechanisms across return codes, fail fast, exceptions and logging

#pragma once

#ifndef __ERRORHANDLING_H
#error "Please include ErrorHandling.h rather than directly including Result.h"
#endif

#include <WinError.h>
#include <strsafe.h>
#include <stdlib.h> // malloc / free used for internal buffer management
#include <intrin.h> // provides the _ReturnAddress() intrinsic
#include "Common.h"
#if defined(WIL_ENABLE_EXCEPTIONS) && !defined(WIL_SUPPRESS_NEW)
#include <new> // provides std::bad_alloc in the windows and public CRT headers
#endif

#ifndef STATUS_SUCCESS
#define STATUS_SUCCESS ((NTSTATUS)0x00000000L)
#endif
#if !defined(_NTDEF_)
typedef _Return_type_success_(return >= 0) LONG NTSTATUS;
#endif

#pragma warning(push)
#pragma warning(disable : 4714) // __forceinline not honored

#ifndef WIL_IMPEXP
#define WIL_IMPEXP __declspec(dllimport)
#endif

#ifndef WIL_EXPORT
#ifdef __cplusplus
#define WIL_EXPORT extern "C" WIL_IMPEXP
#else
#define WIL_EXPORT extern WIL_IMPEXP
#endif
#endif

//*****************************************************************************
// Behavioral setup (error handling macro configuration)
//*****************************************************************************
// Set any of the following macros to the values given below before including Result.h to
// control the error handling macro's trade-offs between diagnostics and performance

// RESULT_DIAGNOSTICS_LEVEL
// This define controls the level of diagnostic instrumentation that is built into the binary as a
// byproduct of using the macros.  The amount of diagnostic instrumentation that is supplied is
// a trade-off between diagnosibility of issues and code size and performance.  The modes are:
//      0   - No diagnostics, smallest & fastest (subject to tail-merge)
//      1   - No diagnostics, unique call sites for each macro (defeat's tail-merge)
//      2   - Line number
//      3   - Line number + source filename
//      4   - Line number + source filename + function name
//      5   - Line number + source filename + function name + code within the macro
// By default, mode 3 is used in free builds and mode 5 is used in checked builds.  Note that the
// _ReturnAddress() will always be available through all modes when possible.

// RESULT_INCLUDE_CALLER_RETURNADDRESS
// This controls whether or not the _ReturnAddress() of the function that includes the macro will
// be reported to telemetry.  Note that this is in addition to the _ReturnAddress() of the actual
// macro position (which is always reported).  The values are:
//      0   - The address is not included
//      1   - The address is included
// The default value is '1'.

// RESULT_INLINE_ERROR_TESTS
// For conditional macros (other than RETURN_XXX), this controls whether branches will be evaluated
// within the call containing the macro or will be forced into the function called by the macros.
// Pushing branching into the called function reduces code size and the number of unique branches
// evaluated, but increases the instruction count executed per macro.
//      0   - Branching will not happen inline to the macros
//      1   - Branching is pushed into the calling function via __forceinline
// The default value is '1'.  Note that XXX_MSG functions are always effectively mode '0' due to the
// compiler's unwillingness to inline var-arg functions.

// RESULT_DIAGNOSTICS_LEVEL_FAIL_FAST
// RESULT_INCLUDE_CALLER_RETURNADDRESS_FAIL_FAST
// RESULT_INLINE_ERROR_TESTS_FAIL_FAST
// These defines are identical to those above in form/function, but only applicable to fail fast error
// handling allowing a process to have different diagnostic information and performance characteristics
// for fail fast than for other error handling given the different reporting infrastructure (Watson
// vs Telemetry).

// RESULT_SUPPRESS_PRERELEASE
// RESULT_FORCE_PRERELEASE
// Set one or the other to always force (or deny) pre-release behavior from within the WIL macros.
// Current pre-release behavioral differences are:
// * RETURN_XXX macros (without _MSG or _LOG suffix) include diagnostic information and report
//      telemetry (they will not do so in release)
// * More aggressive use of FailFast in scenarios where failures are uncommon to help find bugs
//      (an example is use of ::GetLastError() when the last error is not set).  This is elevated
//      to fail fast in pre-release to raise visibility.  In release it reports a generic error (and
//      telemetry) given that its likely the failure has gone undiscovered until then.
// * Default use of FailFast when converting an unknown exception to an HRESULT.  If the exception is
//      unknown, it's like a bug (or a situation where an exception conversion function should be
//      supported).  In release it reports a generic error given the possibility that the particular
//      exception type has not been seen until that point.
// By default, WIL picks up the PRERELEASE define and changes behavior accordingly.

// Setup the debug behavior
#ifndef RESULT_DEBUG
#if (DBG || defined(DEBUG) || defined(_DEBUG)) && !defined(NDEBUG)
#define RESULT_DEBUG
#endif
#endif

// Set the default diagnostic mode
// Note that RESULT_DEBUG_INFO and RESULT_SUPPRESS_DEBUG_INFO are older deprecated models of controlling mode
#ifndef RESULT_DIAGNOSTICS_LEVEL
#if (defined(DBG) || defined(_DEBUG) || defined(RESULT_DEBUG_INFO)) && !defined(RESULT_SUPPRESS_DEBUG_INFO)
#define RESULT_DIAGNOSTICS_LEVEL 5
#else
#define RESULT_DIAGNOSTICS_LEVEL 3
#endif
#endif
#ifndef RESULT_INCLUDE_CALLER_RETURNADDRESS
#define RESULT_INCLUDE_CALLER_RETURNADDRESS 1
#endif
#ifndef RESULT_INLINE_ERROR_TESTS
#define RESULT_INLINE_ERROR_TESTS 1
#endif
#ifndef RESULT_DIAGNOSTICS_LEVEL_FAIL_FAST
#define RESULT_DIAGNOSTICS_LEVEL_FAIL_FAST RESULT_DIAGNOSTICS_LEVEL
#endif
#ifndef RESULT_INCLUDE_CALLER_RETURNADDRESS_FAIL_FAST
#define RESULT_INCLUDE_CALLER_RETURNADDRESS_FAIL_FAST RESULT_INCLUDE_CALLER_RETURNADDRESS
#endif
#ifndef RESULT_INLINE_ERROR_TESTS_FAIL_FAST
#define RESULT_INLINE_ERROR_TESTS_FAIL_FAST RESULT_INLINE_ERROR_TESTS
#endif

// Lock to prerelease behavior.  This is a short-term fix to avoid ODR violations.
#define RESULT_FORCE_PRERELEASE

// Setup the default pre-release behavior
#ifndef RESULT_PRERELEASE
#if (defined(RESULT_FORCE_PRERELEASE) || ((defined(DBG) || defined(_DEBUG)) && !defined(RESULT_SUPPRESS_PRERELEASE)))
#define RESULT_PRERELEASE
#endif
#endif

//*****************************************************************************
// Win32 specific error macros
//*****************************************************************************

#define FAILED_WIN32(win32err) ((win32err) != 0)
#define SUCCEEDED_WIN32(win32err) ((win32err) == 0)

//*****************************************************************************
// NT_STATUS specific error macros
//*****************************************************************************

#define FAILED_NTSTATUS(status) (((NTSTATUS)(status)) < 0)
#define SUCCEEDED_NTSTATUS(status) (((NTSTATUS)(status)) >= 0)

//*****************************************************************************
// Testing helpers - redefine to run unit tests against fail fast
//*****************************************************************************

#ifndef RESULT_NORETURN
#define RESULT_NORETURN __declspec(noreturn)
#endif
#ifndef RESULT_NORETURN_NULL
#define RESULT_NORETURN_NULL _Ret_notnull_
#endif
#ifndef RESULT_RAISE_FAST_FAIL_EXCEPTION
#define RESULT_RAISE_FAST_FAIL_EXCEPTION __fastfail(FAST_FAIL_FATAL_APP_EXIT)
#endif

//*****************************************************************************
// Helpers to setup the macros and functions used below... do not directly use.
//*****************************************************************************

//! @cond
#define __R_FN_PARAMS_FULL                                                                                             \
    _In_opt_ void *callerReturnAddress, unsigned int lineNumber, _In_opt_ PCSTR fileName, _In_opt_ PCSTR functionName, \
        _In_opt_ PCSTR code, void *returnAddress
#define __R_FN_LOCALS_FULL_RA            \
    void* callerReturnAddress = nullptr; \
    unsigned int lineNumber = 0;         \
    PCSTR fileName = nullptr;            \
    PCSTR functionName = nullptr;        \
    PCSTR code = nullptr;                \
    void* returnAddress = _ReturnAddress();
#define __R_ENABLE_IF_IS_CLASS(ptrType) typename wistd::enable_if_t<wistd::is_class<ptrType>::value, void*> = nullptr
#define __R_ENABLE_IF_IS_NOT_CLASS(ptrType) typename wistd::enable_if_t<!wistd::is_class<ptrType>::value, void*> = nullptr
// NOTE: This BEGINs the common macro handling (__R_ prefix) for non-fail fast handled cases
//       This entire section will be repeated below for fail fast (__RFF_ prefix).
#define __R_COMMA ,
#define __R_FN_CALL_FULL callerReturnAddress, lineNumber, fileName, functionName, code, returnAddress
#define __R_FN_CALL_FULL_RA callerReturnAddress, lineNumber, fileName, functionName, code, _ReturnAddress()
// The following macros assemble the varying amount of data we want to collect from the macros, treating it uniformly
#if (RESULT_DIAGNOSTICS_LEVEL >= 2) // line number
#define __R_IF_LINE(term) term
#define __R_IF_NOT_LINE(term)
#define __R_IF_COMMA ,
#else
#define __R_IF_LINE(term)
#define __R_IF_NOT_LINE(term) term
#define __R_IF_COMMA
#endif
#if (RESULT_DIAGNOSTICS_LEVEL >= 3) // line number + file name
#define __R_IF_FILE(term) term
#define __R_IF_NOT_FILE(term)
#else
#define __R_IF_FILE(term)
#define __R_IF_NOT_FILE(term) term
#endif
#if (RESULT_DIAGNOSTICS_LEVEL >= 4) // line number + file name + function name
#define __R_IF_FUNCTION(term) term
#define __R_IF_NOT_FUNCTION(term)
#else
#define __R_IF_FUNCTION(term)
#define __R_IF_NOT_FUNCTION(term) term
#endif
#if (RESULT_DIAGNOSTICS_LEVEL >= 5) // line number + file name + function name + macro code
#define __R_IF_CODE(term) term
#define __R_IF_NOT_CODE(term)
#else
#define __R_IF_CODE(term)
#define __R_IF_NOT_CODE(term) term
#endif
#if (RESULT_INCLUDE_CALLER_RETURNADDRESS == 1)
#define __R_IF_CALLERADDRESS(term) term
#define __R_IF_NOT_CALLERADDRESS(term)
#else
#define __R_IF_CALLERADDRESS(term)
#define __R_IF_NOT_CALLERADDRESS(term) term
#endif
#if (RESULT_INCLUDE_CALLER_RETURNADDRESS == 1) || (RESULT_DIAGNOSTICS_LEVEL >= 2)
#define __R_IF_TRAIL_COMMA ,
#else
#define __R_IF_TRAIL_COMMA
#endif
// Assemble the varying amounts of data into a single macro
#define __R_INFO_ONLY(CODE)                             \
    __R_IF_CALLERADDRESS(_ReturnAddress() __R_IF_COMMA) \
    __R_IF_LINE(__LINE__) __R_IF_FILE(__R_COMMA __FILE__) __R_IF_FUNCTION(__R_COMMA __FUNCTION__) __R_IF_CODE(__R_COMMA CODE)
#define __R_INFO(CODE) __R_INFO_ONLY(CODE) __R_IF_TRAIL_COMMA
#define __R_FN_PARAMS_ONLY                                       \
    __R_IF_CALLERADDRESS(void* callerReturnAddress __R_IF_COMMA) \
    __R_IF_LINE(unsigned int lineNumber)                         \
    __R_IF_FILE(__R_COMMA _In_opt_ PCSTR fileName)               \
    __R_IF_FUNCTION(__R_COMMA _In_opt_ PCSTR functionName) __R_IF_CODE(__R_COMMA _In_opt_ PCSTR code)
#define __R_FN_PARAMS __R_FN_PARAMS_ONLY __R_IF_TRAIL_COMMA
#define __R_FN_CALL_ONLY                                   \
    __R_IF_CALLERADDRESS(callerReturnAddress __R_IF_COMMA) \
    __R_IF_LINE(lineNumber) __R_IF_FILE(__R_COMMA fileName) __R_IF_FUNCTION(__R_COMMA functionName) __R_IF_CODE(__R_COMMA code)
#define __R_FN_CALL __R_FN_CALL_ONLY __R_IF_TRAIL_COMMA
#define __R_FN_LOCALS                                              \
    __R_IF_NOT_CALLERADDRESS(void* callerReturnAddress = nullptr;) \
    __R_IF_NOT_LINE(unsigned int lineNumber = 0;)                  \
    __R_IF_NOT_FILE(PCSTR fileName = nullptr;) __R_IF_NOT_FUNCTION(PCSTR functionName = nullptr;) __R_IF_NOT_CODE(PCSTR code = nullptr;)
#define __R_FN_LOCALS_RA                                           \
    __R_IF_NOT_CALLERADDRESS(void* callerReturnAddress = nullptr;) \
    __R_IF_NOT_LINE(unsigned int lineNumber = 0;)                  \
    __R_IF_NOT_FILE(PCSTR fileName = nullptr;)                     \
    __R_IF_NOT_FUNCTION(PCSTR functionName = nullptr;) __R_IF_NOT_CODE(PCSTR code = nullptr;) void* returnAddress = _ReturnAddress();
#define __R_FN_UNREFERENCED                    \
    __R_IF_CALLERADDRESS(callerReturnAddress;) \
    __R_IF_LINE(lineNumber;) __R_IF_FILE(fileName;) __R_IF_FUNCTION(functionName;) __R_IF_CODE(code;)
// 1) Direct Methods
//      * Called Directly by Macros
//      * Always noinline
//      * May be template-driven to create unique call sites if (RESULT_DIAGNOSTICS_LEVEL == 1)
#if (RESULT_DIAGNOSTICS_LEVEL == 1)
#define __R_DIRECT_METHOD(RetType, MethodName) \
    template <unsigned int optimizerCounter>   \
    inline __declspec(noinline) RetType MethodName
#define __R_DIRECT_NORET_METHOD(RetType, MethodName) \
    template <unsigned int optimizerCounter>         \
    inline __declspec(noinline) RESULT_NORETURN RetType MethodName
#else
#define __R_DIRECT_METHOD(RetType, MethodName) inline __declspec(noinline) RetType MethodName
#define __R_DIRECT_NORET_METHOD(RetType, MethodName) inline __declspec(noinline) RESULT_NORETURN RetType MethodName
#endif
#define __R_DIRECT_FN_PARAMS __R_FN_PARAMS
#define __R_DIRECT_FN_PARAMS_ONLY __R_FN_PARAMS_ONLY
#define __R_DIRECT_FN_CALL __R_FN_CALL_FULL_RA __R_COMMA
#define __R_DIRECT_FN_CALL_ONLY __R_FN_CALL_FULL_RA
// 2) Internal Methods
//      * Only called by Conditional routines
//      * 'inline' when (RESULT_INLINE_ERROR_TESTS = 0 and RESULT_DIAGNOSTICS_LEVEL != 1), otherwise noinline (directly called by code when
//      branching is forceinlined)
//      * May be template-driven to create unique call sites if (RESULT_DIAGNOSTICS_LEVEL == 1 and RESULT_INLINE_ERROR_TESTS = 1)
#if (RESULT_DIAGNOSTICS_LEVEL == 1)
#define __R_INTERNAL_NOINLINE_METHOD(MethodName) inline __declspec(noinline) void MethodName
#define __R_INTERNAL_NOINLINE_NORET_METHOD(MethodName) inline __declspec(noinline) RESULT_NORETURN void MethodName
#define __R_INTERNAL_INLINE_METHOD(MethodName) \
    template <unsigned int optimizerCounter>   \
    inline __declspec(noinline) void MethodName
#define __R_INTERNAL_INLINE_NORET_METHOD(MethodName) \
    template <unsigned int optimizerCounter>         \
    inline __declspec(noinline) RESULT_NORETURN void MethodName
#define __R_CALL_INTERNAL_INLINE_METHOD(MethodName) MethodName<optimizerCounter>
#else
#define __R_INTERNAL_NOINLINE_METHOD(MethodName) inline void MethodName
#define __R_INTERNAL_NOINLINE_NORET_METHOD(MethodName) inline RESULT_NORETURN void MethodName
#define __R_INTERNAL_INLINE_METHOD(MethodName) inline __declspec(noinline) void MethodName
#define __R_INTERNAL_INLINE_NORET_METHOD(MethodName) inline __declspec(noinline) RESULT_NORETURN void MethodName
#define __R_CALL_INTERNAL_INLINE_METHOD(MethodName) MethodName
#endif
#define __R_CALL_INTERNAL_NOINLINE_METHOD(MethodName) MethodName
#define __R_INTERNAL_NOINLINE_FN_PARAMS __R_FN_PARAMS void* returnAddress __R_COMMA
#define __R_INTERNAL_NOINLINE_FN_PARAMS_ONLY __R_FN_PARAMS void* returnAddress
#define __R_INTERNAL_NOINLINE_FN_CALL __R_FN_CALL_FULL __R_COMMA
#define __R_INTERNAL_NOINLINE_FN_CALL_ONLY __R_FN_CALL_FULL
#define __R_INTERNAL_INLINE_FN_PARAMS __R_FN_PARAMS
#define __R_INTERNAL_INLINE_FN_PARAMS_ONLY __R_FN_PARAMS_ONLY
#define __R_INTERNAL_INLINE_FN_CALL __R_FN_CALL_FULL_RA __R_COMMA
#define __R_INTERNAL_INLINE_FN_CALL_ONLY __R_FN_CALL_FULL_RA
#if (RESULT_INLINE_ERROR_TESTS == 0)
#define __R_INTERNAL_METHOD __R_INTERNAL_NOINLINE_METHOD
#define __R_INTERNAL_NORET_METHOD __R_INTERNAL_NOINLINE_NORET_METHOD
#define __R_CALL_INTERNAL_METHOD __R_CALL_INTERNAL_NOINLINE_METHOD
#define __R_INTERNAL_FN_PARAMS __R_INTERNAL_NOINLINE_FN_PARAMS
#define __R_INTERNAL_FN_PARAMS_ONLY __R_INTERNAL_NOINLINE_FN_PARAMS_ONLY
#define __R_INTERNAL_FN_CALL __R_INTERNAL_NOINLINE_FN_CALL
#define __R_INTERNAL_FN_CALL_ONLY __R_INTERNAL_NOINLINE_FN_CALL_ONLY
#else
#define __R_INTERNAL_METHOD __R_INTERNAL_INLINE_METHOD
#define __R_INTERNAL_NORET_METHOD __R_INTERNAL_INLINE_NORET_METHOD
#define __R_CALL_INTERNAL_METHOD __R_CALL_INTERNAL_INLINE_METHOD
#define __R_INTERNAL_FN_PARAMS __R_INTERNAL_INLINE_FN_PARAMS
#define __R_INTERNAL_FN_PARAMS_ONLY __R_INTERNAL_INLINE_FN_PARAMS_ONLY
#define __R_INTERNAL_FN_CALL __R_INTERNAL_INLINE_FN_CALL
#define __R_INTERNAL_FN_CALL_ONLY __R_INTERNAL_INLINE_FN_CALL_ONLY
#endif
// 3) Conditional Methods
//      * Called Directly by Macros
//      * May be noinline or __forceinline depending upon (RESULT_INLINE_ERROR_TESTS)
//      * May be template-driven to create unique call sites if (RESULT_DIAGNOSTICS_LEVEL == 1)
#if (RESULT_DIAGNOSTICS_LEVEL == 1)
#define __R_CONDITIONAL_NOINLINE_METHOD(RetType, MethodName) \
    template <unsigned int optimizerCounter>                 \
    inline __declspec(noinline) RetType MethodName
#define __R_CONDITIONAL_NOINLINE_TEMPLATE_METHOD(RetType, MethodName) inline __declspec(noinline) RetType MethodName
#define __R_CONDITIONAL_INLINE_METHOD(RetType, MethodName) \
    template <unsigned int optimizerCounter>               \
    __forceinline RetType MethodName
#define __R_CONDITIONAL_INLINE_TEMPLATE_METHOD(RetType, MethodName) __forceinline RetType MethodName
#define __R_CONDITIONAL_PARTIAL_TEMPLATE unsigned int optimizerCounter __R_COMMA
#else
#define __R_CONDITIONAL_NOINLINE_METHOD(RetType, MethodName) inline __declspec(noinline) RetType MethodName
#define __R_CONDITIONAL_NOINLINE_TEMPLATE_METHOD(RetType, MethodName) inline __declspec(noinline) RetType MethodName
#define __R_CONDITIONAL_INLINE_METHOD(RetType, MethodName) __forceinline RetType MethodName
#define __R_CONDITIONAL_INLINE_TEMPLATE_METHOD(RetType, MethodName) __forceinline RetType MethodName
#define __R_CONDITIONAL_PARTIAL_TEMPLATE
#endif
#define __R_CONDITIONAL_NOINLINE_FN_CALL __R_FN_CALL _ReturnAddress() __R_COMMA
#define __R_CONDITIONAL_NOINLINE_FN_CALL_ONLY __R_FN_CALL _ReturnAddress()
#define __R_CONDITIONAL_INLINE_FN_CALL __R_FN_CALL
#define __R_CONDITIONAL_INLINE_FN_CALL_ONLY __R_FN_CALL_ONLY
#if (RESULT_INLINE_ERROR_TESTS == 0)
#define __R_CONDITIONAL_METHOD __R_CONDITIONAL_NOINLINE_METHOD
#define __R_CONDITIONAL_TEMPLATE_METHOD __R_CONDITIONAL_NOINLINE_TEMPLATE_METHOD
#define __R_CONDITIONAL_FN_CALL __R_CONDITIONAL_NOINLINE_FN_CALL
#define __R_CONDITIONAL_FN_CALL_ONLY __R_CONDITIONAL_NOINLINE_FN_CALL_ONLY
#else
#define __R_CONDITIONAL_METHOD __R_CONDITIONAL_INLINE_METHOD
#define __R_CONDITIONAL_TEMPLATE_METHOD __R_CONDITIONAL_INLINE_TEMPLATE_METHOD
#define __R_CONDITIONAL_FN_CALL __R_CONDITIONAL_INLINE_FN_CALL
#define __R_CONDITIONAL_FN_CALL_ONLY __R_CONDITIONAL_INLINE_FN_CALL_ONLY
#endif
#define __R_CONDITIONAL_FN_PARAMS __R_FN_PARAMS
#define __R_CONDITIONAL_FN_PARAMS_ONLY __R_FN_PARAMS_ONLY
// Macro call-site helpers
#define __R_NS_ASSEMBLE2(ri, rd) in##ri##diag##rd // Differing internal namespaces eliminate ODR violations between modes
#define __R_NS_ASSEMBLE(ri, rd) __R_NS_ASSEMBLE2(ri, rd)
#define __R_NS_NAME __R_NS_ASSEMBLE(RESULT_INLINE_ERROR_TESTS, RESULT_DIAGNOSTICS_LEVEL)
#define __R_NS wil::details::__R_NS_NAME
#if (RESULT_DIAGNOSTICS_LEVEL == 1)
#define __R_FN(MethodName) __R_NS::MethodName<__COUNTER__>
#else
#define __R_FN(MethodName) __R_NS::MethodName
#endif
// NOTE: This ENDs the common macro handling (__R_ prefix) for non-fail fast handled cases
//       This entire section is repeated below for fail fast (__RFF_ prefix).  For ease of editing this section, the
//       process is to copy/paste, and search and replace (__R_ -> __RFF_), (RESULT_DIAGNOSTICS_LEVEL ->
//       RESULT_DIAGNOSTICS_LEVEL_FAIL_FAST),
//       (RESULT_INLINE_ERROR_TESTS -> RESULT_INLINE_ERROR_TESTS_FAIL_FAST) and (RESULT_INCLUDE_CALLER_RETURNADDRESS ->
//       RESULT_INCLUDE_CALLER_RETURNADDRESS_FAIL_FAST)
#define __RFF_COMMA ,
#define __RFF_FN_CALL_FULL callerReturnAddress, lineNumber, fileName, functionName, code, returnAddress
#define __RFF_FN_CALL_FULL_RA callerReturnAddress, lineNumber, fileName, functionName, code, _ReturnAddress()
// The following macros assemble the varying amount of data we want to collect from the macros, treating it uniformly
#if (RESULT_DIAGNOSTICS_LEVEL_FAIL_FAST >= 2) // line number
#define __RFF_IF_LINE(term) term
#define __RFF_IF_NOT_LINE(term)
#define __RFF_IF_COMMA ,
#else
#define __RFF_IF_LINE(term)
#define __RFF_IF_NOT_LINE(term) term
#define __RFF_IF_COMMA
#endif
#if (RESULT_DIAGNOSTICS_LEVEL_FAIL_FAST >= 3) // line number + file name
#define __RFF_IF_FILE(term) term
#define __RFF_IF_NOT_FILE(term)
#else
#define __RFF_IF_FILE(term)
#define __RFF_IF_NOT_FILE(term) term
#endif
#if (RESULT_DIAGNOSTICS_LEVEL_FAIL_FAST >= 4) // line number + file name + function name
#define __RFF_IF_FUNCTION(term) term
#define __RFF_IF_NOT_FUNCTION(term)
#else
#define __RFF_IF_FUNCTION(term)
#define __RFF_IF_NOT_FUNCTION(term) term
#endif
#if (RESULT_DIAGNOSTICS_LEVEL_FAIL_FAST >= 5) // line number + file name + function name + macro code
#define __RFF_IF_CODE(term) term
#define __RFF_IF_NOT_CODE(term)
#else
#define __RFF_IF_CODE(term)
#define __RFF_IF_NOT_CODE(term) term
#endif
#if (RESULT_INCLUDE_CALLER_RETURNADDRESS_FAIL_FAST == 1)
#define __RFF_IF_CALLERADDRESS(term) term
#define __RFF_IF_NOT_CALLERADDRESS(term)
#else
#define __RFF_IF_CALLERADDRESS(term)
#define __RFF_IF_NOT_CALLERADDRESS(term) term
#endif
#if (RESULT_INCLUDE_CALLER_RETURNADDRESS_FAIL_FAST == 1) || (RESULT_DIAGNOSTICS_LEVEL_FAIL_FAST >= 2)
#define __RFF_IF_TRAIL_COMMA ,
#else
#define __RFF_IF_TRAIL_COMMA
#endif
// Assemble the varying amounts of data into a single macro
#define __RFF_INFO_ONLY(CODE)                               \
    __RFF_IF_CALLERADDRESS(_ReturnAddress() __RFF_IF_COMMA) \
    __RFF_IF_LINE(__LINE__) __RFF_IF_FILE(__RFF_COMMA __FILE__) __RFF_IF_FUNCTION(__RFF_COMMA __FUNCTION__) __RFF_IF_CODE(__RFF_COMMA CODE)
#define __RFF_INFO(CODE) __RFF_INFO_ONLY(CODE) __RFF_IF_TRAIL_COMMA
#define __RFF_FN_PARAMS_ONLY                                         \
    __RFF_IF_CALLERADDRESS(void* callerReturnAddress __RFF_IF_COMMA) \
    __RFF_IF_LINE(unsigned int lineNumber)                           \
    __RFF_IF_FILE(__RFF_COMMA _In_opt_ PCSTR fileName)               \
    __RFF_IF_FUNCTION(__RFF_COMMA _In_opt_ PCSTR functionName) __RFF_IF_CODE(__RFF_COMMA _In_opt_ PCSTR code)
#define __RFF_FN_PARAMS __RFF_FN_PARAMS_ONLY __RFF_IF_TRAIL_COMMA
#define __RFF_FN_CALL_ONLY                                     \
    __RFF_IF_CALLERADDRESS(callerReturnAddress __RFF_IF_COMMA) \
    __RFF_IF_LINE(lineNumber)                                  \
    __RFF_IF_FILE(__RFF_COMMA fileName) __RFF_IF_FUNCTION(__RFF_COMMA functionName) __RFF_IF_CODE(__RFF_COMMA code)
#define __RFF_FN_CALL __RFF_FN_CALL_ONLY __RFF_IF_TRAIL_COMMA
#define __RFF_FN_LOCALS                                              \
    __RFF_IF_NOT_CALLERADDRESS(void* callerReturnAddress = nullptr;) \
    __RFF_IF_NOT_LINE(unsigned int lineNumber = 0;)                  \
    __RFF_IF_NOT_FILE(PCSTR fileName = nullptr;)                     \
    __RFF_IF_NOT_FUNCTION(PCSTR functionName = nullptr;) __RFF_IF_NOT_CODE(PCSTR code = nullptr;)
#define __RFF_FN_UNREFERENCED                    \
    __RFF_IF_CALLERADDRESS(callerReturnAddress;) \
    __RFF_IF_LINE(lineNumber;) __RFF_IF_FILE(fileName;) __RFF_IF_FUNCTION(functionName;) __RFF_IF_CODE(code;)
// 1) Direct Methods
//      * Called Directly by Macros
//      * Always noinline
//      * May be template-driven to create unique call sites if (RESULT_DIAGNOSTICS_LEVEL_FAIL_FAST == 1)
#if (RESULT_DIAGNOSTICS_LEVEL_FAIL_FAST == 1)
#define __RFF_DIRECT_METHOD(RetType, MethodName) \
    template <unsigned int optimizerCounter>     \
    inline __declspec(noinline) RetType MethodName
#define __RFF_DIRECT_NORET_METHOD(RetType, MethodName) \
    template <unsigned int optimizerCounter>           \
    inline __declspec(noinline) RESULT_NORETURN RetType MethodName
#else
#define __RFF_DIRECT_METHOD(RetType, MethodName) inline __declspec(noinline) RetType MethodName
#define __RFF_DIRECT_NORET_METHOD(RetType, MethodName) inline __declspec(noinline) RESULT_NORETURN RetType MethodName
#endif
#define __RFF_DIRECT_FN_PARAMS __RFF_FN_PARAMS
#define __RFF_DIRECT_FN_PARAMS_ONLY __RFF_FN_PARAMS_ONLY
#define __RFF_DIRECT_FN_CALL __RFF_FN_CALL_FULL_RA __RFF_COMMA
#define __RFF_DIRECT_FN_CALL_ONLY __RFF_FN_CALL_FULL_RA
// 2) Internal Methods
//      * Only called by Conditional routines
//      * 'inline' when (RESULT_INLINE_ERROR_TESTS_FAIL_FAST = 0 and RESULT_DIAGNOSTICS_LEVEL_FAIL_FAST != 1), otherwise noinline (directly
//      called by code when branching is forceinlined)
//      * May be template-driven to create unique call sites if (RESULT_DIAGNOSTICS_LEVEL_FAIL_FAST == 1 and
//      RESULT_INLINE_ERROR_TESTS_FAIL_FAST = 1)
#if (RESULT_DIAGNOSTICS_LEVEL_FAIL_FAST == 1)
#define __RFF_INTERNAL_NOINLINE_METHOD(MethodName) inline __declspec(noinline) void MethodName
#define __RFF_INTERNAL_NOINLINE_NORET_METHOD(MethodName) inline __declspec(noinline) RESULT_NORETURN void MethodName
#define __RFF_INTERNAL_INLINE_METHOD(MethodName) \
    template <unsigned int optimizerCounter>     \
    inline __declspec(noinline) void MethodName
#define __RFF_INTERNAL_INLINE_NORET_METHOD(MethodName) \
    template <unsigned int optimizerCounter>           \
    inline __declspec(noinline) RESULT_NORETURN void MethodName
#define __RFF_CALL_INTERNAL_INLINE_METHOD(MethodName) MethodName<optimizerCounter>
#else
#define __RFF_INTERNAL_NOINLINE_METHOD(MethodName) inline void MethodName
#define __RFF_INTERNAL_NOINLINE_NORET_METHOD(MethodName) inline RESULT_NORETURN void MethodName
#define __RFF_INTERNAL_INLINE_METHOD(MethodName) inline __declspec(noinline) void MethodName
#define __RFF_INTERNAL_INLINE_NORET_METHOD(MethodName) inline __declspec(noinline) RESULT_NORETURN void MethodName
#define __RFF_CALL_INTERNAL_INLINE_METHOD(MethodName) MethodName
#endif
#define __RFF_CALL_INTERNAL_NOINLINE_METHOD(MethodName) MethodName
#define __RFF_INTERNAL_NOINLINE_FN_PARAMS __RFF_FN_PARAMS void* returnAddress __RFF_COMMA
#define __RFF_INTERNAL_NOINLINE_FN_PARAMS_ONLY __RFF_FN_PARAMS void* returnAddress
#define __RFF_INTERNAL_NOINLINE_FN_CALL __RFF_FN_CALL_FULL __RFF_COMMA
#define __RFF_INTERNAL_NOINLINE_FN_CALL_ONLY __RFF_FN_CALL_FULL
#define __RFF_INTERNAL_INLINE_FN_PARAMS __RFF_FN_PARAMS
#define __RFF_INTERNAL_INLINE_FN_PARAMS_ONLY __RFF_FN_PARAMS_ONLY
#define __RFF_INTERNAL_INLINE_FN_CALL __RFF_FN_CALL_FULL_RA __RFF_COMMA
#define __RFF_INTERNAL_INLINE_FN_CALL_ONLY __RFF_FN_CALL_FULL_RA
#if (RESULT_INLINE_ERROR_TESTS_FAIL_FAST == 0)
#define __RFF_INTERNAL_METHOD __RFF_INTERNAL_NOINLINE_METHOD
#define __RFF_INTERNAL_NORET_METHOD __RFF_INTERNAL_NOINLINE_NORET_METHOD
#define __RFF_CALL_INTERNAL_METHOD __RFF_CALL_INTERNAL_NOINLINE_METHOD
#define __RFF_INTERNAL_FN_PARAMS __RFF_INTERNAL_NOINLINE_FN_PARAMS
#define __RFF_INTERNAL_FN_PARAMS_ONLY __RFF_INTERNAL_NOINLINE_FN_PARAMS_ONLY
#define __RFF_INTERNAL_FN_CALL __RFF_INTERNAL_NOINLINE_FN_CALL
#define __RFF_INTERNAL_FN_CALL_ONLY __RFF_INTERNAL_NOINLINE_FN_CALL_ONLY
#else
#define __RFF_INTERNAL_METHOD __RFF_INTERNAL_INLINE_METHOD
#define __RFF_INTERNAL_NORET_METHOD __RFF_INTERNAL_INLINE_NORET_METHOD
#define __RFF_CALL_INTERNAL_METHOD __RFF_CALL_INTERNAL_INLINE_METHOD
#define __RFF_INTERNAL_FN_PARAMS __RFF_INTERNAL_INLINE_FN_PARAMS
#define __RFF_INTERNAL_FN_PARAMS_ONLY __RFF_INTERNAL_INLINE_FN_PARAMS_ONLY
#define __RFF_INTERNAL_FN_CALL __RFF_INTERNAL_INLINE_FN_CALL
#define __RFF_INTERNAL_FN_CALL_ONLY __RFF_INTERNAL_INLINE_FN_CALL_ONLY
#endif
// 3) Conditional Methods
//      * Called Directly by Macros
//      * May be noinline or __forceinline depending upon (RESULT_INLINE_ERROR_TESTS_FAIL_FAST)
//      * May be template-driven to create unique call sites if (RESULT_DIAGNOSTICS_LEVEL_FAIL_FAST == 1)
#if (RESULT_DIAGNOSTICS_LEVEL_FAIL_FAST == 1)
#define __RFF_CONDITIONAL_NOINLINE_METHOD(RetType, MethodName) \
    template <unsigned int optimizerCounter>                   \
    inline __declspec(noinline) RetType MethodName
#define __RFF_CONDITIONAL_NOINLINE_TEMPLATE_METHOD(RetType, MethodName) inline __declspec(noinline) RetType MethodName
#define __RFF_CONDITIONAL_INLINE_METHOD(RetType, MethodName) \
    template <unsigned int optimizerCounter>                 \
    __forceinline RetType MethodName
#define __RFF_CONDITIONAL_INLINE_TEMPLATE_METHOD(RetType, MethodName) __forceinline RetType MethodName
#define __RFF_CONDITIONAL_PARTIAL_TEMPLATE unsigned int optimizerCounter __RFF_COMMA
#else
#define __RFF_CONDITIONAL_NOINLINE_METHOD(RetType, MethodName) inline __declspec(noinline) RetType MethodName
#define __RFF_CONDITIONAL_NOINLINE_TEMPLATE_METHOD(RetType, MethodName) inline __declspec(noinline) RetType MethodName
#define __RFF_CONDITIONAL_INLINE_METHOD(RetType, MethodName) __forceinline RetType MethodName
#define __RFF_CONDITIONAL_INLINE_TEMPLATE_METHOD(RetType, MethodName) __forceinline RetType MethodName
#define __RFF_CONDITIONAL_PARTIAL_TEMPLATE
#endif
#define __RFF_CONDITIONAL_NOINLINE_FN_CALL __RFF_FN_CALL _ReturnAddress() __RFF_COMMA
#define __RFF_CONDITIONAL_NOINLINE_FN_CALL_ONLY __RFF_FN_CALL _ReturnAddress()
#define __RFF_CONDITIONAL_INLINE_FN_CALL __RFF_FN_CALL
#define __RFF_CONDITIONAL_INLINE_FN_CALL_ONLY __RFF_FN_CALL_ONLY
#if (RESULT_INLINE_ERROR_TESTS_FAIL_FAST == 0)
#define __RFF_CONDITIONAL_METHOD __RFF_CONDITIONAL_NOINLINE_METHOD
#define __RFF_CONDITIONAL_TEMPLATE_METHOD __RFF_CONDITIONAL_NOINLINE_TEMPLATE_METHOD
#define __RFF_CONDITIONAL_FN_CALL __RFF_CONDITIONAL_NOINLINE_FN_CALL
#define __RFF_CONDITIONAL_FN_CALL_ONLY __RFF_CONDITIONAL_NOINLINE_FN_CALL_ONLY
#else
#define __RFF_CONDITIONAL_METHOD __RFF_CONDITIONAL_INLINE_METHOD
#define __RFF_CONDITIONAL_TEMPLATE_METHOD __RFF_CONDITIONAL_INLINE_TEMPLATE_METHOD
#define __RFF_CONDITIONAL_FN_CALL __RFF_CONDITIONAL_INLINE_FN_CALL
#define __RFF_CONDITIONAL_FN_CALL_ONLY __RFF_CONDITIONAL_INLINE_FN_CALL_ONLY
#endif
#define __RFF_CONDITIONAL_FN_PARAMS __RFF_FN_PARAMS
#define __RFF_CONDITIONAL_FN_PARAMS_ONLY __RFF_FN_PARAMS_ONLY
// Macro call-site helpers
#define __RFF_NS_ASSEMBLE2(ri, rd) in##ri##diag##rd // Differing internal namespaces eliminate ODR violations between modes
#define __RFF_NS_ASSEMBLE(ri, rd) __RFF_NS_ASSEMBLE2(ri, rd)
#define __RFF_NS_NAME __RFF_NS_ASSEMBLE(RESULT_INLINE_ERROR_TESTS_FAIL_FAST, RESULT_DIAGNOSTICS_LEVEL_FAIL_FAST)
#define __RFF_NS wil::details::__RFF_NS_NAME
#if (RESULT_DIAGNOSTICS_LEVEL_FAIL_FAST == 1)
#define __RFF_FN(MethodName) __RFF_NS::MethodName<__COUNTER__>
#else
#define __RFF_FN(MethodName) __RFF_NS::MethodName
#endif
// end-of-repeated fail-fast handling macros
// Helpers for return macros
#define __RETURN_HR_LOG(hr, str)                   \
    do {                                           \
        HRESULT __hr = (hr);                       \
        if (FAILED(__hr)) {                        \
            __R_FN(Return_Hr)(__R_INFO(str) __hr); \
        }                                          \
        return __hr;                               \
    } while (0, 0)
#define __RETURN_HR_LOG_FAIL(hr, str)          \
    do {                                       \
        HRESULT __hr = (hr);                   \
        __R_FN(Return_Hr)(__R_INFO(str) __hr); \
        return __hr;                           \
    } while (0, 0)
#define __RETURN_WIN32_LOG(err, str)                          \
    do {                                                      \
        DWORD __err = (err);                                  \
        if (FAILED_WIN32(__err)) {                            \
            return __R_FN(Return_Win32)(__R_INFO(str) __err); \
        }                                                     \
        return S_OK;                                          \
    } while (0, 0)
#define __RETURN_WIN32_LOG_FAIL(err, str)                 \
    do {                                                  \
        DWORD __err = (err);                              \
        return __R_FN(Return_Win32)(__R_INFO(str) __err); \
    } while (0, 0)
#define __RETURN_GLE_LOG_FAIL(str) return __R_FN(Return_GetLastError)(__R_INFO_ONLY(str))
#define __RETURN_NTSTATUS_LOG(status, str)                          \
    do {                                                            \
        NTSTATUS __status = (status);                               \
        if (FAILED_NTSTATUS(__status)) {                            \
            return __R_FN(Return_NtStatus)(__R_INFO(str) __status); \
        }                                                           \
        return S_OK;                                                \
    } while (0, 0)
#define __RETURN_NTSTATUS_LOG_FAIL(status, str)                 \
    do {                                                        \
        NTSTATUS __status = (status);                           \
        return __R_FN(Return_NtStatus)(__R_INFO(str) __status); \
    } while (0, 0)
#define __RETURN_HR_MSG(hr, str, fmt, ...)                              \
    do {                                                                \
        HRESULT __hr = (hr);                                            \
        if (FAILED(__hr)) {                                             \
            __R_FN(Return_HrMsg)(__R_INFO(str) __hr, fmt, __VA_ARGS__); \
        }                                                               \
        return __hr;                                                    \
    } while (0, 0)
#define __RETURN_HR_MSG_FAIL(hr, str, fmt, ...)                     \
    do {                                                            \
        HRESULT __hr = (hr);                                        \
        __R_FN(Return_HrMsg)(__R_INFO(str) __hr, fmt, __VA_ARGS__); \
        return __hr;                                                \
    } while (0, 0)
#define __RETURN_WIN32_MSG(err, str, fmt, ...)                                     \
    do {                                                                           \
        DWORD __err = (err);                                                       \
        if (FAILED_WIN32(__err)) {                                                 \
            return __R_FN(Return_Win32Msg)(__R_INFO(str) __err, fmt, __VA_ARGS__); \
        }                                                                          \
        return S_OK;                                                               \
    } while (0, 0)
#define __RETURN_WIN32_MSG_FAIL(err, str, fmt, ...)                            \
    do {                                                                       \
        DWORD __err = (err);                                                   \
        return __R_FN(Return_Win32Msg)(__R_INFO(str) __err, fmt, __VA_ARGS__); \
    } while (0, 0)
#define __RETURN_GLE_MSG_FAIL(str, fmt, ...) return __R_FN(Return_GetLastErrorMsg)(__R_INFO(str) fmt, __VA_ARGS__)
#define __RETURN_NTSTATUS_MSG(status, str, fmt, ...)                                     \
    do {                                                                                 \
        NTSTATUS __status = (status);                                                    \
        if (FAILED_NTSTATUS(__status)) {                                                 \
            return __R_FN(Return_NtStatusMsg)(__R_INFO(str) __status, fmt, __VA_ARGS__); \
        }                                                                                \
        return S_OK;                                                                     \
    } while (0, 0)
#define __RETURN_NTSTATUS_MSG_FAIL(status, str, fmt, ...)                            \
    do {                                                                             \
        NTSTATUS __status = (status);                                                \
        return __R_FN(Return_NtStatusMsg)(__R_INFO(str) __status, fmt, __VA_ARGS__); \
    } while (0, 0)
#ifdef RESULT_PRERELEASE
#define __RETURN_HR(hr, str)                                 \
    do {                                                     \
        HRESULT __hr = (hr);                                 \
        if (FAILED(__hr)) {                                  \
            __R_FN(Return_HrPreRelease)(__R_INFO(str) __hr); \
        }                                                    \
        return __hr;                                         \
    } while (0, 0)
#define __RETURN_HR_FAIL(hr, str)                        \
    do {                                                 \
        HRESULT __hr = (hr);                             \
        __R_FN(Return_HrPreRelease)(__R_INFO(str) __hr); \
        return __hr;                                     \
    } while (0, 0)
#define __RETURN_NULL_FAIL(hr, str)                        \
    do {                                                   \
        HRESULT __hr = (hr);                               \
        __R_FN(Return_NullPreRelease)(__R_INFO(str) __hr); \
        return nullptr;                                    \
    } while (0, 0)
#define __RETURN_WIN32(err, str)                                        \
    do {                                                                \
        DWORD __err = (err);                                            \
        if (FAILED_WIN32(__err)) {                                      \
            return __R_FN(Return_Win32PreRelease)(__R_INFO(str) __err); \
        }                                                               \
        return S_OK;                                                    \
    } while (0, 0)
#define __RETURN_WIN32_FAIL(err, str)                               \
    do {                                                            \
        DWORD __err = (err);                                        \
        return __R_FN(Return_Win32PreRelease)(__R_INFO(str) __err); \
    } while (0, 0)
#define __RETURN_NULL_WIN32_FAIL(err, str)                       \
    do {                                                         \
        DWORD __err = (err);                                     \
        __R_FN(Return_NullWin32PreRelease)(__R_INFO(str) __err); \
        return nullptr;                                          \
    } while (0, 0)
#define __RETURN_GLE_FAIL(str) return __R_FN(Return_GetLastErrorPreRelease)(__R_INFO_ONLY(str))
#define __RETURN_NULL_GLE_FAIL(str) return __R_FN(Return_NullGetLastErrorPreRelease)(__R_INFO_ONLY(str))
#define __RETURN_NTSTATUS(status, str)                                        \
    do {                                                                      \
        NTSTATUS __status = (status);                                         \
        if (FAILED_NTSTATUS(__status)) {                                      \
            return __R_FN(Return_NtStatusPreRelease)(__R_INFO(str) __status); \
        }                                                                     \
        return S_OK;                                                          \
    } while (0, 0)
#define __RETURN_NTSTATUS_FAIL(status, str)                               \
    do {                                                                  \
        NTSTATUS __status = (status);                                     \
        return __R_FN(Return_NtStatusPreRelease)(__R_INFO(str) __status); \
    } while (0, 0)
#else
#define __RETURN_HR(hr, str) return (hr)
#define __RETURN_HR_FAIL(hr, str) return (hr)
#define __RETURN_NULL_FAIL(hr, str) return nullptr
#define __RETURN_WIN32(err, str) return (HRESULT_FROM_WIN32(err))
#define __RETURN_WIN32_FAIL(err, str) return (HRESULT_FROM_WIN32(err))
#define __RETURN_NULL_WIN32_FAIL(str) return nullptr
#define __RETURN_GLE_FAIL(str) return (wil::details::GetLastErrorFailHr())
#define __RETURN_NULL_GLE_FAIL(str) (wil::details::GetLastErrorFailHr(); return nullptr;)
#define __RETURN_NTSTATUS(status, str) return (wil::details::NtStatusToHr(status))
#define __RETURN_NTSTATUS_FAIL(status, str) return (wil::details::NtStatusToHr(status))
#endif
#if defined(_PREFAST_)
#define __WI_ANALYSIS_ASSUME(_exp) _Analysis_assume_(_exp)
#else
#ifdef RESULT_DEBUG
#define __WI_ANALYSIS_ASSUME(_exp) ((void)0)
#else
#define __WI_ANALYSIS_ASSUME(_exp) __noop(_exp)
#endif
#endif // _PREFAST_
//! @endcond

//*****************************************************************************
// Pre-release fail fast helpers (for use only internally to WIL)
//*****************************************************************************

//! @cond
#ifdef RESULT_PRERELEASE
#define __FAIL_FAST_PRERELEASE_ASSERT__(condition)                      \
    do {                                                                \
        if (!(condition)) {                                             \
            __RFF_FN(FailFast_Unexpected)(__RFF_INFO_ONLY(#condition)); \
        }                                                               \
    } while (0, 0)
#define __FAIL_FAST_PRERELEASE_ASSUME__(condition) __FAIL_FAST_PRERELEASE_ASSERT__(condition)
#define __FAIL_FAST_IMMEDIATE_PRERELEASE_ASSERT__(condition) \
    do {                                                     \
        if (!(condition)) {                                  \
            RESULT_RAISE_FAST_FAIL_EXCEPTION;                \
        }                                                    \
    } while (0, 0)
#define __FAIL_FAST_IMMEDIATE_PRERELEASE_ASSUME__(condition) __FAIL_FAST_IMMEDIATE_PRERELEASE_ASSERT__(condition)
#else
#define __FAIL_FAST_PRERELEASE_ASSERT__(condition)
#define __FAIL_FAST_PRERELEASE_ASSUME__(condition) (condition)
#define __FAIL_FAST_IMMEDIATE_PRERELEASE_ASSERT__(condition)
#define __FAIL_FAST_IMMEDIATE_PRERELEASE_ASSUME__(condition) (condition)
#endif
//! @endcond

//*****************************************************************************
// Macros for returning failures as HRESULTs
//*****************************************************************************

// Always returns a known result (HRESULT) - logs failures in pre-release
#define RETURN_HR(hr) __RETURN_HR(wil::verify_hresult(hr), #hr)
#define RETURN_LAST_ERROR() __RETURN_GLE_FAIL(nullptr)
#define RETURN_WIN32(win32err) __RETURN_WIN32(win32err, #win32err)
#define RETURN_NTSTATUS(status) __RETURN_NTSTATUS(status, #status)

// Conditionally returns failures (HRESULT) - logs failures in pre-release
#define RETURN_IF_FAILED(hr)                       \
    do {                                           \
        HRESULT __hrRet = wil::verify_hresult(hr); \
        if (FAILED(__hrRet)) {                     \
            __RETURN_HR_FAIL(__hrRet, #hr);        \
        }                                          \
    } while (0, 0)
#define RETURN_IF_WIN32_BOOL_FALSE(win32BOOL)         \
    do {                                              \
        BOOL __boolRet = wil::verify_BOOL(win32BOOL); \
        if (!__boolRet) {                             \
            __RETURN_GLE_FAIL(#win32BOOL);            \
        }                                             \
    } while (0, 0)
#define RETURN_IF_WIN32_ERROR(win32err)               \
    do {                                              \
        DWORD __errRet = (win32err);                  \
        if (FAILED_WIN32(__errRet)) {                 \
            __RETURN_WIN32_FAIL(__errRet, #win32err); \
        }                                             \
    } while (0, 0)
#define RETURN_IF_HANDLE_INVALID(handle)      \
    do {                                      \
        HANDLE __hRet = (handle);             \
        if (__hRet == INVALID_HANDLE_VALUE) { \
            __RETURN_GLE_FAIL(#handle);       \
        }                                     \
    } while (0, 0)
#define RETURN_IF_HANDLE_NULL(handle)   \
    do {                                \
        HANDLE __hRet = (handle);       \
        if (__hRet == nullptr) {        \
            __RETURN_GLE_FAIL(#handle); \
        }                               \
    } while (0, 0)
#define RETURN_IF_NULL_ALLOC(ptr)                  \
    do {                                           \
        if ((ptr) == nullptr) {                    \
            __RETURN_HR_FAIL(E_OUTOFMEMORY, #ptr); \
        }                                          \
    } while (0, 0)
#define RETURN_HR_IF(hr, condition)                           \
    do {                                                      \
        if (wil::verify_bool(condition)) {                    \
            __RETURN_HR(wil::verify_hresult(hr), #condition); \
        }                                                     \
    } while (0, 0)
#define RETURN_HR_IF_FALSE(hr, condition) RETURN_HR_IF(hr, !(wil::verify_bool(condition)))
#define RETURN_HR_IF_NULL(hr, ptr)                      \
    do {                                                \
        if ((ptr) == nullptr) {                         \
            __RETURN_HR(wil::verify_hresult(hr), #ptr); \
        }                                               \
    } while (0, 0)
#define RETURN_LAST_ERROR_IF(condition)    \
    do {                                   \
        if (wil::verify_bool(condition)) { \
            __RETURN_GLE_FAIL(#condition); \
        }                                  \
    } while (0, 0)
#define RETURN_LAST_ERROR_IF_FALSE(condition) RETURN_LAST_ERROR_IF(!(wil::verify_bool(condition)))
#define RETURN_LAST_ERROR_IF_NULL(ptr) \
    do {                               \
        if ((ptr) == nullptr) {        \
            __RETURN_GLE_FAIL(#ptr);   \
        }                              \
    } while (0, 0)
#define RETURN_IF_NTSTATUS_FAILED(status)                 \
    do {                                                  \
        NTSTATUS __statusRet = (status);                  \
        if (FAILED_NTSTATUS(__statusRet)) {               \
            __RETURN_NTSTATUS_FAIL(__statusRet, #status); \
        }                                                 \
    } while (0, 0)

// Always returns a known result (HRESULT) - always logs failures
#define RETURN_HR_LOG(hr) __RETURN_HR_LOG(wil::verify_hresult(hr), #hr)
#define RETURN_LAST_ERROR_LOG() __RETURN_GLE_LOG_FAIL(nullptr)
#define RETURN_WIN32_LOG(win32err) __RETURN_WIN32_LOG(win32err, #win32err)
#define RETURN_NTSTATUS_LOG(status) __RETURN_NTSTATUS_LOG(status, #status)

// Conditionally returns failures (HRESULT) - always logs failures
#define RETURN_IF_FAILED_LOG(hr)                \
    do {                                        \
        auto __hrRet = wil::verify_hresult(hr); \
        if (FAILED(__hrRet)) {                  \
            __RETURN_HR_LOG_FAIL(__hrRet, #hr); \
        }                                       \
    } while (0, 0)
#define RETURN_IF_WIN32_BOOL_FALSE_LOG(win32BOOL) \
    do {                                          \
        if (!wil::verify_BOOL(win32BOOL)) {       \
            __RETURN_GLE_LOG_FAIL(#win32BOOL);    \
        }                                         \
    } while (0, 0)
#define RETURN_IF_WIN32_ERROR_LOG(win32err)               \
    do {                                                  \
        auto __errRet = (win32err);                       \
        if (FAILED_WIN32(__errRet)) {                     \
            __RETURN_WIN32_LOG_FAIL(__errRet, #win32err); \
        }                                                 \
    } while (0, 0)
#define RETURN_IF_HANDLE_INVALID_LOG(handle)  \
    do {                                      \
        HANDLE __hRet = (handle);             \
        if (__hRet == INVALID_HANDLE_VALUE) { \
            __RETURN_GLE_LOG_FAIL(#handle);   \
        }                                     \
    } while (0, 0)
#define RETURN_IF_HANDLE_NULL_LOG(handle)   \
    do {                                    \
        HANDLE __hRet = (handle);           \
        if (__hRet == nullptr) {            \
            __RETURN_GLE_LOG_FAIL(#handle); \
        }                                   \
    } while (0, 0)
#define RETURN_IF_NULL_ALLOC_LOG(ptr)                  \
    do {                                               \
        if ((ptr) == nullptr) {                        \
            __RETURN_HR_LOG_FAIL(E_OUTOFMEMORY, #ptr); \
        }                                              \
    } while (0, 0)
#define RETURN_HR_IF_LOG(hr, condition)                           \
    do {                                                          \
        if (wil::verify_bool(condition)) {                        \
            __RETURN_HR_LOG(wil::verify_hresult(hr), #condition); \
        }                                                         \
    } while (0, 0)
#define RETURN_HR_IF_FALSE_LOG(hr, condition) RETURN_HR_IF_LOG(hr, !(wil::verify_bool(condition)))
#define RETURN_HR_IF_NULL_LOG(hr, ptr)                      \
    do {                                                    \
        if ((ptr) == nullptr) {                             \
            __RETURN_HR_LOG(wil::verify_hresult(hr), #ptr); \
        }                                                   \
    } while (0, 0)
#define RETURN_LAST_ERROR_IF_LOG(condition)    \
    do {                                       \
        if (wil::verify_bool(condition)) {     \
            __RETURN_GLE_LOG_FAIL(#condition); \
        }                                      \
    } while (0, 0)
#define RETURN_LAST_ERROR_IF_FALSE_LOG(condition) RETURN_LAST_ERROR_IF_LOG(!(wil::verify_bool(condition)))
#define RETURN_LAST_ERROR_IF_NULL_LOG(ptr) \
    do {                                   \
        if ((ptr) == nullptr) {            \
            __RETURN_GLE_LOG_FAIL(#ptr);   \
        }                                  \
    } while (0, 0)
#define RETURN_IF_NTSTATUS_FAILED_LOG(status)                 \
    do {                                                      \
        auto __statusRet = (status);                          \
        if (FAILED_NTSTATUS(__statusRet)) {                   \
            __RETURN_NTSTATUS_LOG_FAIL(__statusRet, #status); \
        }                                                     \
    } while (0, 0)

// Always returns a known failure (HRESULT) - always logs a var-arg message on failure
#define RETURN_HR_MSG(hr, fmt, ...) __RETURN_HR_MSG(wil::verify_hresult(hr), #hr, fmt, __VA_ARGS__)
#define RETURN_LAST_ERROR_MSG(fmt, ...) __RETURN_GLE_MSG_FAIL(nullptr, fmt, __VA_ARGS__)
#define RETURN_WIN32_MSG(win32err, fmt, ...) __RETURN_WIN32_MSG(win32err, #win32err, fmt, __VA_ARGS__)
#define RETURN_NTSTATUS_MSG(status, fmt, ...) __RETURN_NTSTATUS_MSG(status, #status, fmt, __VA_ARGS__)

// Conditionally returns failures (HRESULT) - always logs a var-arg message on failure
#define RETURN_IF_FAILED_MSG(hr, fmt, ...)                        \
    do {                                                          \
        auto __hrRet = wil::verify_hresult(hr);                   \
        if (FAILED(__hrRet)) {                                    \
            __RETURN_HR_MSG_FAIL(__hrRet, #hr, fmt, __VA_ARGS__); \
        }                                                         \
    } while (0, 0)
#define RETURN_IF_WIN32_BOOL_FALSE_MSG(win32BOOL, fmt, ...)      \
    do {                                                         \
        if (!wil::verify_BOOL(win32BOOL)) {                      \
            __RETURN_GLE_MSG_FAIL(#win32BOOL, fmt, __VA_ARGS__); \
        }                                                        \
    } while (0, 0)
#define RETURN_IF_WIN32_ERROR_MSG(win32err, fmt, ...)                       \
    do {                                                                    \
        auto __errRet = (win32err);                                         \
        if (FAILED_WIN32(__errRet)) {                                       \
            __RETURN_WIN32_MSG_FAIL(__errRet, #win32err, fmt, __VA_ARGS__); \
        }                                                                   \
    } while (0, 0)
#define RETURN_IF_HANDLE_INVALID_MSG(handle, fmt, ...)        \
    do {                                                      \
        HANDLE __hRet = (handle);                             \
        if (__hRet == INVALID_HANDLE_VALUE) {                 \
            __RETURN_GLE_MSG_FAIL(#handle, fmt, __VA_ARGS__); \
        }                                                     \
    } while (0, 0)
#define RETURN_IF_HANDLE_NULL_MSG(handle, fmt, ...)           \
    do {                                                      \
        HANDLE __hRet = (handle);                             \
        if (__hRet == nullptr) {                              \
            __RETURN_GLE_MSG_FAIL(#handle, fmt, __VA_ARGS__); \
        }                                                     \
    } while (0, 0)
#define RETURN_IF_NULL_ALLOC_MSG(ptr, fmt, ...)                          \
    do {                                                                 \
        if ((ptr) == nullptr) {                                          \
            __RETURN_HR_MSG_FAIL(E_OUTOFMEMORY, #ptr, fmt, __VA_ARGS__); \
        }                                                                \
    } while (0, 0)
#define RETURN_HR_IF_MSG(hr, condition, fmt, ...)                                   \
    do {                                                                            \
        if (wil::verify_bool(condition)) {                                          \
            __RETURN_HR_MSG(wil::verify_hresult(hr), #condition, fmt, __VA_ARGS__); \
        }                                                                           \
    } while (0, 0)
#define RETURN_HR_IF_FALSE_MSG(hr, condition, fmt, ...) RETURN_HR_IF_MSG(hr, !(wil::verify_bool(condition)), fmt, __VA_ARGS__)
#define RETURN_HR_IF_NULL_MSG(hr, ptr, fmt, ...)                              \
    do {                                                                      \
        if ((ptr) == nullptr) {                                               \
            __RETURN_HR_MSG(wil::verify_hresult(hr), #ptr, fmt, __VA_ARGS__); \
        }                                                                     \
    } while (0, 0)
#define RETURN_LAST_ERROR_IF_MSG(condition, fmt, ...)            \
    do {                                                         \
        if (wil::verify_bool(condition)) {                       \
            __RETURN_GLE_MSG_FAIL(#condition, fmt, __VA_ARGS__); \
        }                                                        \
    } while (0, 0)
#define RETURN_LAST_ERROR_IF_FALSE_MSG(condition, fmt, ...) RETURN_LAST_ERROR_IF_MSG(!(wil::verify_bool(condition)), fmt, __VA_ARGS__)
#define RETURN_LAST_ERROR_IF_NULL_MSG(ptr, fmt, ...)       \
    do {                                                   \
        if ((ptr) == nullptr) {                            \
            __RETURN_GLE_MSG_FAIL(#ptr, fmt, __VA_ARGS__); \
        }                                                  \
    } while (0, 0)
#define RETURN_IF_NTSTATUS_FAILED_MSG(status, fmt, ...)                         \
    do {                                                                        \
        NTSTATUS __statusRet = (status);                                        \
        if (FAILED_NTSTATUS(__statusRet)) {                                     \
            __RETURN_NTSTATUS_MSG_FAIL(__statusRet, #status, fmt, __VA_ARGS__); \
        }                                                                       \
    } while (0, 0)

// Conditionally returns failures (HRESULT) - use for failures that are expected in common use - failures are not logged - macros are only
// for control flow pattern
#define RETURN_IF_FAILED_EXPECTED(hr)           \
    do {                                        \
        auto __hrRet = wil::verify_hresult(hr); \
        if (FAILED(__hrRet)) {                  \
            return __hrRet;                     \
        }                                       \
    } while (0, 0)
#define RETURN_IF_WIN32_BOOL_FALSE_EXPECTED(win32BOOL) \
    do {                                               \
        if (!wil::verify_BOOL(win32BOOL)) {            \
            return wil::details::GetLastErrorFailHr(); \
        }                                              \
    } while (0, 0)
#define RETURN_IF_WIN32_ERROR_EXPECTED(win32err) \
    do {                                         \
        auto __errRet = (win32err);              \
        if (FAILED_WIN32(__errRet)) {            \
            return HRESULT_FROM_WIN32(__errRet); \
        }                                        \
    } while (0, 0)
#define RETURN_IF_HANDLE_INVALID_EXPECTED(handle)      \
    do {                                               \
        HANDLE __hRet = (handle);                      \
        if (__hRet == INVALID_HANDLE_VALUE) {          \
            return wil::details::GetLastErrorFailHr(); \
        }                                              \
    } while (0, 0)
#define RETURN_IF_HANDLE_NULL_EXPECTED(handle)         \
    do {                                               \
        HANDLE __hRet = (handle);                      \
        if (__hRet == nullptr) {                       \
            return wil::details::GetLastErrorFailHr(); \
        }                                              \
    } while (0, 0)
#define RETURN_IF_NULL_ALLOC_EXPECTED(ptr) \
    do {                                   \
        if ((ptr) == nullptr) {            \
            return E_OUTOFMEMORY;          \
        }                                  \
    } while (0, 0)
#define RETURN_HR_IF_EXPECTED(hr, condition) \
    do {                                     \
        if (wil::verify_bool(condition)) {   \
            return wil::verify_hresult(hr);  \
        }                                    \
    } while (0, 0)
#define RETURN_HR_IF_FALSE_EXPECTED(hr, condition) RETURN_HR_IF_EXPECTED(hr, !(wil::verify_bool(condition)))
#define RETURN_HR_IF_NULL_EXPECTED(hr, ptr) \
    do {                                    \
        if ((ptr) == nullptr) {             \
            return wil::verify_hresult(hr); \
        }                                   \
    } while (0, 0)
#define RETURN_LAST_ERROR_IF_EXPECTED(condition)       \
    do {                                               \
        if (wil::verify_bool(condition)) {             \
            return wil::details::GetLastErrorFailHr(); \
        }                                              \
    } while (0, 0)
#define RETURN_LAST_ERROR_IF_FALSE_EXPECTED(condition) RETURN_LAST_ERROR_IF_EXPECTED(!(wil::verify_bool(condition)))
#define RETURN_LAST_ERROR_IF_NULL_EXPECTED(ptr)        \
    do {                                               \
        if ((ptr) == nullptr) {                        \
            return wil::details::GetLastErrorFailHr(); \
        }                                              \
    } while (0, 0)
#define RETURN_IF_NTSTATUS_FAILED_EXPECTED(status)          \
    do {                                                    \
        auto __statusRet = (status);                        \
        if (FAILED_NTSTATUS(__statusRet)) {                 \
            return wil::details::NtStatusToHr(__statusRet); \
        }                                                   \
    } while (0, 0)
#define RETURN_NULL_IF_FAILED(hr)                  \
    do {                                           \
        HRESULT __hrRet = wil::verify_hresult(hr); \
        if (FAILED(__hrRet)) {                     \
            __RETURN_NULL_FAIL(__hrRet, #hr);      \
        }                                          \
    } while (0, 0)
#define RETURN_NULL_IF_WIN32_BOOL_FALSE(win32BOOL)    \
    do {                                              \
        BOOL __boolRet = wil::verify_BOOL(win32BOOL); \
        if (!__boolRet) {                             \
            __RETURN_NULL_GLE_FAIL(#win32BOOL);       \
        }                                             \
    } while (0, 0)
#define RETURN_NULL_IF_WIN32_ERROR(win32err)               \
    do {                                                   \
        DWORD __errRet = (win32err);                       \
        if (FAILED_WIN32(__errRet)) {                      \
            __RETURN_NULL_WIN32_FAIL(win32err, #win32err); \
        }                                                  \
    } while (0, 0)
#define RETURN_NULL_IF(condition)                   \
    do {                                            \
        if (wil::verify_bool(condition)) {          \
            __RETURN_NULL_FAIL(E_FAIL, #condition); \
        }                                           \
    } while (0, 0)
#define RETURN_NULL_IF_FALSE(condition) RETURN_NULL_IF(!(wil::verify_bool(condition)))
#define RETURN_NULL_IF_NULL_ALLOC(ptr)               \
    do {                                             \
        if ((ptr) == nullptr) {                      \
            wil::verify_hresult(E_OUTOFMEMORY);      \
            __RETURN_NULL_FAIL(E_OUTOFMEMORY, #ptr); \
        }                                            \
    } while (0, 0)
#define RETURN_FALSE_IF(condition) \
    do {                           \
        if (condition) {           \
            return false;          \
        }                          \
    } while (0, 0)
#define RETURN_IF(condition) \
    do {                     \
        if (condition) {     \
            return;          \
        }                    \
    } while (0, 0)
#define RETURN_RESULT_IF(condition, result) \
    do {                                    \
        if (condition) {                    \
            return result;                  \
        }                                   \
    } while (0, 0)

#define RETURN_FALSE_IF_FAILED(hr) RETURN_FALSE_IF(FAILED(hr));
#define RETURN_RESULT_IF_NULL(ptr, result) RETURN_RESULT_IF((ptr == nullptr), result);
#define RETURN_RESULT_IF_FAILED(hr, result) RETURN_RESULT_IF(FAILED(hr), result)
//*****************************************************************************
// Macros for logging failures (ignore or pass-through)
//*****************************************************************************

// Always logs a known failure
#define LOG_HR(hr) __R_FN(Log_Hr)(__R_INFO(#hr) wil::verify_hresult(hr))
#define LOG_LAST_ERROR() __R_FN(Log_GetLastError)(__R_INFO_ONLY(nullptr))
#define LOG_WIN32(win32err) __R_FN(Log_Win32)(__R_INFO(#win32err) win32err)
#define LOG_NTSTATUS(status) __R_FN(Log_NtStatus)(__R_INFO(#status) status)

// Conditionally logs failures - returns parameter value
#define LOG_IF_FAILED(hr) __R_FN(Log_IfFailed)(__R_INFO(#hr) wil::verify_hresult(hr))
#define LOG_IF_WIN32_BOOL_FALSE(win32BOOL) __R_FN(Log_IfWin32BoolFalse)(__R_INFO(#win32BOOL) wil::verify_BOOL(win32BOOL))
#define LOG_IF_WIN32_ERROR(win32err) __R_FN(Log_IfWin32Error)(__R_INFO(#win32err) win32err)
#define LOG_IF_HANDLE_INVALID(handle) __R_FN(Log_IfHandleInvalid)(__R_INFO(#handle) handle)
#define LOG_IF_HANDLE_NULL(handle) __R_FN(Log_IfHandleNull)(__R_INFO(#handle) handle)
#define LOG_IF_NULL_ALLOC(ptr) __R_FN(Log_IfNullAlloc)(__R_INFO(#ptr) ptr)
#define LOG_HR_IF(hr, condition) __R_FN(Log_HrIf)(__R_INFO(#condition) wil::verify_hresult(hr), wil::verify_bool(condition))
#define LOG_HR_IF_FALSE(hr, condition) __R_FN(Log_HrIfFalse)(__R_INFO(#condition) wil::verify_hresult(hr), wil::verify_bool(condition))
#define LOG_HR_IF_NULL(hr, ptr) __R_FN(Log_HrIfNull)(__R_INFO(#ptr) wil::verify_hresult(hr), ptr)
#define LOG_LAST_ERROR_IF(condition) __R_FN(Log_GetLastErrorIf)(__R_INFO(#condition) wil::verify_bool(condition))
#define LOG_LAST_ERROR_IF_FALSE(condition) __R_FN(Log_GetLastErrorIfFalse)(__R_INFO(#condition) wil::verify_bool(condition))
#define LOG_LAST_ERROR_IF_NULL(ptr) __R_FN(Log_GetLastErrorIfNull)(__R_INFO(#ptr) ptr)
#define LOG_IF_NTSTATUS_FAILED(status) __R_FN(Log_IfNtStatusFailed)(__R_INFO(#status) status)

// Alternatives for SUCCEEDED(hr) and FAILED(hr) that conditionally log failures
#define SUCCEEDED_LOG(hr) SUCCEEDED(LOG_IF_FAILED(hr))
#define FAILED_LOG(hr) FAILED(LOG_IF_FAILED(hr))

// Always logs a known failure - logs a var-arg message on failure
#define LOG_HR_MSG(hr, fmt, ...) __R_FN(Log_HrMsg)(__R_INFO(#hr) wil::verify_hresult(hr), fmt, __VA_ARGS__)
#define LOG_LAST_ERROR_MSG(fmt, ...) __R_FN(Log_GetLastErrorMsg)(__R_INFO(nullptr) fmt, __VA_ARGS__)
#define LOG_WIN32_MSG(win32err, fmt, ...) __R_FN(Log_Win32Msg)(__R_INFO(#win32err) win32err, fmt, __VA_ARGS__)
#define LOG_NTSTATUS_MSG(status, fmt, ...) __R_FN(Log_NtStatusMsg)(__R_INFO(#status) status, fmt, __VA_ARGS__)

// Conditionally logs failures - returns parameter value - logs a var-arg message on failure
#define LOG_IF_FAILED_MSG(hr, fmt, ...) __R_FN(Log_IfFailedMsg)(__R_INFO(#hr) wil::verify_hresult(hr), fmt, __VA_ARGS__)
#define LOG_IF_WIN32_BOOL_FALSE_MSG(win32BOOL, fmt, ...) \
    __R_FN(Log_IfWin32BoolFalseMsg)(__R_INFO(#win32BOOL) wil::verify_BOOL(win32BOOL), fmt, __VA_ARGS__)
#define LOG_IF_WIN32_ERROR_MSG(win32err, fmt, ...) __R_FN(Log_IfWin32ErrorMsg)(__R_INFO(#win32err) win32err, fmt, __VA_ARGS__)
#define LOG_IF_HANDLE_INVALID_MSG(handle, fmt, ...) __R_FN(Log_IfHandleInvalidMsg)(__R_INFO(#handle) handle, fmt, __VA_ARGS__)
#define LOG_IF_HANDLE_NULL_MSG(handle, fmt, ...) __R_FN(Log_IfHandleNullMsg)(__R_INFO(#handle) handle, fmt, __VA_ARGS__)
#define LOG_IF_NULL_ALLOC_MSG(ptr, fmt, ...) __R_FN(Log_IfNullAllocMsg)(__R_INFO(#ptr) ptr, fmt, __VA_ARGS__)
#define LOG_HR_IF_MSG(hr, condition, fmt, ...) \
    __R_FN(Log_HrIfMsg)(__R_INFO(#condition) wil::verify_hresult(hr), wil::verify_bool(condition), fmt, __VA_ARGS__)
#define LOG_HR_IF_FALSE_MSG(hr, condition, fmt, ...) \
    __R_FN(Log_HrIfFalseMsg)(__R_INFO(#condition) wil::verify_hresult(hr), wil::verify_bool(condition), fmt, __VA_ARGS__)
#define LOG_HR_IF_NULL_MSG(hr, ptr, fmt, ...) __R_FN(Log_HrIfNullMsg)(__R_INFO(#ptr) wil::verify_hresult(hr), ptr, fmt, __VA_ARGS__)
#define LOG_LAST_ERROR_IF_MSG(condition, fmt, ...) \
    __R_FN(Log_GetLastErrorIfMsg)(__R_INFO(#condition) wil::verify_bool(condition), fmt, __VA_ARGS__)
#define LOG_LAST_ERROR_IF_FALSE_MSG(condition, fmt, ...) \
    __R_FN(Log_GetLastErrorIfFalseMsg)(__R_INFO(#condition) wil::verify_bool(condition), fmt, __VA_ARGS__)
#define LOG_LAST_ERROR_IF_NULL_MSG(ptr, fmt, ...) __R_FN(Log_GetLastErrorIfNullMsg)(__R_INFO(#ptr) ptr, fmt, __VA_ARGS__)
#define LOG_IF_NTSTATUS_FAILED_MSG(status, fmt, ...) __R_FN(Log_IfNtStatusFailedMsg)(__R_INFO(#status) status, fmt, __VA_ARGS__)

//*****************************************************************************
// Macros to fail fast the process on failures
//*****************************************************************************

// Always fail fast a known failure
#define FAIL_FAST_HR(hr) __RFF_FN(FailFast_Hr)(__RFF_INFO(#hr) wil::verify_hresult(hr))
#define FAIL_FAST_LAST_ERROR() __RFF_FN(FailFast_GetLastError)(__RFF_INFO_ONLY(nullptr))
#define FAIL_FAST_WIN32(win32err) __RFF_FN(FailFast_Win32)(__RFF_INFO(#win32err) win32err)
#define FAIL_FAST_NTSTATUS(status) __RFF_FN(FailFast_NtStatus)(__RFF_INFO(#status) status)

// Conditionally fail fast failures - returns parameter value
#define FAIL_FAST_IF_FAILED(hr) __RFF_FN(FailFast_IfFailed)(__RFF_INFO(#hr) wil::verify_hresult(hr))
#define FAIL_FAST_IF_WIN32_BOOL_FALSE(win32BOOL) __RFF_FN(FailFast_IfWin32BoolFalse)(__RFF_INFO(#win32BOOL) wil::verify_BOOL(win32BOOL))
#define FAIL_FAST_IF_WIN32_ERROR(win32err) __RFF_FN(FailFast_IfWin32Error)(__RFF_INFO(#win32err) win32err)
#define FAIL_FAST_IF_HANDLE_INVALID(handle) __RFF_FN(FailFast_IfHandleInvalid)(__RFF_INFO(#handle) handle)
#define FAIL_FAST_IF_HANDLE_NULL(handle) __RFF_FN(FailFast_IfHandleNull)(__RFF_INFO(#handle) handle)
#define FAIL_FAST_IF_NULL_ALLOC(ptr) __RFF_FN(FailFast_IfNullAlloc)(__RFF_INFO(#ptr) ptr)
#define FAIL_FAST_HR_IF(hr, condition) __RFF_FN(FailFast_HrIf)(__RFF_INFO(#condition) wil::verify_hresult(hr), wil::verify_bool(condition))
#define FAIL_FAST_HR_IF_FALSE(hr, condition) \
    __RFF_FN(FailFast_HrIfFalse)(__RFF_INFO(#condition) wil::verify_hresult(hr), wil::verify_bool(condition))
#define FAIL_FAST_HR_IF_NULL(hr, ptr) __RFF_FN(FailFast_HrIfNull)(__RFF_INFO(#ptr) wil::verify_hresult(hr), ptr)
#define FAIL_FAST_LAST_ERROR_IF(condition) __RFF_FN(FailFast_GetLastErrorIf)(__RFF_INFO(#condition) wil::verify_bool(condition))
#define FAIL_FAST_LAST_ERROR_IF_FALSE(condition) __RFF_FN(FailFast_GetLastErrorIfFalse)(__RFF_INFO(#condition) wil::verify_bool(condition))
#define FAIL_FAST_LAST_ERROR_IF_NULL(ptr) __RFF_FN(FailFast_GetLastErrorIfNull)(__RFF_INFO(#ptr) ptr)
#define FAIL_FAST_IF_NTSTATUS_FAILED(status) __RFF_FN(FailFast_IfNtStatusFailed)(__RFF_INFO(#status) status)

// Always fail fast a known failure - fail fast a var-arg message on failure
#define FAIL_FAST_HR_MSG(hr, fmt, ...) __RFF_FN(FailFast_HrMsg)(__RFF_INFO(#hr) wil::verify_hresult(hr), fmt, __VA_ARGS__)
#define FAIL_FAST_LAST_ERROR_MSG(fmt, ...) __RFF_FN(FailFast_GetLastErrorMsg)(__RFF_INFO(nullptr) fmt, __VA_ARGS__)
#define FAIL_FAST_WIN32_MSG(win32err, fmt, ...) __RFF_FN(FailFast_Win32Msg)(__RFF_INFO(#win32err) win32err, fmt, __VA_ARGS__)
#define FAIL_FAST_NTSTATUS_MSG(status, fmt, ...) __RFF_FN(FailFast_NtStatusMsg)(__RFF_INFO(#status) status, fmt, __VA_ARGS__)

// Conditionally fail fast failures - returns parameter value - fail fast a var-arg message on failure
#define FAIL_FAST_IF_FAILED_MSG(hr, fmt, ...) __RFF_FN(FailFast_IfFailedMsg)(__RFF_INFO(#hr) wil::verify_hresult(hr), fmt, __VA_ARGS__)
#define FAIL_FAST_IF_WIN32_BOOL_FALSE_MSG(win32BOOL, fmt, ...) \
    __RFF_FN(FailFast_IfWin32BoolFalseMsg)(__RFF_INFO(#win32BOOL) wil::verify_BOOL(win32BOOL), fmt, __VA_ARGS__)
#define FAIL_FAST_IF_WIN32_ERROR_MSG(win32err, fmt, ...) \
    __RFF_FN(FailFast_IfWin32ErrorMsg)(__RFF_INFO(#win32err) win32err, fmt, __VA_ARGS__)
#define FAIL_FAST_IF_HANDLE_INVALID_MSG(handle, fmt, ...) \
    __RFF_FN(FailFast_IfHandleInvalidMsg)(__RFF_INFO(#handle) handle, fmt, __VA_ARGS__)
#define FAIL_FAST_IF_HANDLE_NULL_MSG(handle, fmt, ...) __RFF_FN(FailFast_IfHandleNullMsg)(__RFF_INFO(#handle) handle, fmt, __VA_ARGS__)
#define FAIL_FAST_IF_NULL_ALLOC_MSG(ptr, fmt, ...) __RFF_FN(FailFast_IfNullAllocMsg)(__RFF_INFO(#ptr) ptr, fmt, __VA_ARGS__)
#define FAIL_FAST_HR_IF_MSG(hr, condition, fmt, ...) \
    __RFF_FN(FailFast_HrIfMsg)(__RFF_INFO(#condition) wil::verify_hresult(hr), wil::verify_bool(condition), fmt, __VA_ARGS__)
#define FAIL_FAST_HR_IF_FALSE_MSG(hr, condition, fmt, ...) \
    __RFF_FN(FailFast_HrIfFalseMsg)(__RFF_INFO(#condition) wil::verify_hresult(hr), wil::verify_bool(condition), fmt, __VA_ARGS__)
#define FAIL_FAST_HR_IF_NULL_MSG(hr, ptr, fmt, ...) \
    __RFF_FN(FailFast_HrIfNullMsg)(__RFF_INFO(#ptr) wil::verify_hresult(hr), ptr, fmt, __VA_ARGS__)
#define FAIL_FAST_LAST_ERROR_IF_MSG(condition, fmt, ...) \
    __RFF_FN(FailFast_GetLastErrorIfMsg)(__RFF_INFO(#condition) wil::verify_bool(condition), fmt, __VA_ARGS__)
#define FAIL_FAST_LAST_ERROR_IF_FALSE_MSG(condition, fmt, ...) \
    __RFF_FN(FailFast_GetLastErrorIfFalseMsg)(__RFF_INFO(#condition) wil::verify_bool(condition), fmt, __VA_ARGS__)
#define FAIL_FAST_LAST_ERROR_IF_NULL_MSG(ptr, fmt, ...) __RFF_FN(FailFast_GetLastErrorIfNullMsg)(__RFF_INFO(#ptr) ptr, fmt, __VA_ARGS__)
#define FAIL_FAST_IF_NTSTATUS_FAILED_MSG(status, fmt, ...) \
    __RFF_FN(FailFast_IfNtStatusFailedMsg)(__RFF_INFO(#status) status, fmt, __VA_ARGS__)

// Always fail fast a known failure
#ifndef FAIL_FAST
#define FAIL_FAST() __RFF_FN(FailFast_Unexpected)(__RFF_INFO_ONLY(nullptr))
#endif

// Conditionally fail fast failures - returns parameter value
#define FAIL_FAST_IF(condition) __RFF_FN(FailFast_If)(__RFF_INFO(#condition) wil::verify_bool(condition))
#define FAIL_FAST_IF_FALSE(condition) __RFF_FN(FailFast_IfFalse)(__RFF_INFO(#condition) wil::verify_bool(condition))
#define FAIL_FAST_IF_NULL(ptr) __RFF_FN(FailFast_IfNull)(__RFF_INFO(#ptr) ptr)

// Always fail fast a known failure - fail fast a var-arg message on failure
#define FAIL_FAST_MSG(fmt, ...) __RFF_FN(FailFast_UnexpectedMsg)(__RFF_INFO(nullptr) fmt, __VA_ARGS__)

// Conditionally fail fast failures - returns parameter value - fail fast a var-arg message on failure
#define FAIL_FAST_IF_MSG(condition, fmt, ...) __RFF_FN(FailFast_IfMsg)(__RFF_INFO(#condition) wil::verify_bool(condition), fmt, __VA_ARGS__)
#define FAIL_FAST_IF_FALSE_MSG(condition, fmt, ...) \
    __RFF_FN(FailFast_IfFalseMsg)(__RFF_INFO(#condition) wil::verify_bool(condition), fmt, __VA_ARGS__)
#define FAIL_FAST_IF_NULL_MSG(ptr, fmt, ...) __RFF_FN(FailFast_IfNullMsg)(__RFF_INFO(#ptr) ptr, fmt, __VA_ARGS__)

// Immediate fail fast (no telemetry - use rarely / only when *already* in an undefined state)
#define FAIL_FAST_IMMEDIATE() __RFF_FN(FailFastImmediate_Unexpected)()

// Conditional immediate fail fast (no telemetry - use rarely / only when *already* in an undefined state)
#define FAIL_FAST_IMMEDIATE_IF_FAILED(hr) __RFF_FN(FailFastImmediate_IfFailed)(wil::verify_hresult(hr))
#define FAIL_FAST_IMMEDIATE_IF(condition) __RFF_FN(FailFastImmediate_If)(wil::verify_bool(condition))
#define FAIL_FAST_IMMEDIATE_IF_FALSE(condition) __RFF_FN(FailFastImmediate_IfFalse)(wil::verify_bool(condition))
#define FAIL_FAST_IMMEDIATE_IF_NULL(ptr) __RFF_FN(FailFastImmediate_IfNull)(ptr)
#define FAIL_FAST_IMMEDIATE_IF_NTSTATUS_FAILED(status) __RFF_FN(FailFastImmediate_IfNtStatusFailed)(status)

// Specializations
#define FAIL_FAST_IMMEDIATE_IF_IN_LOADER_CALLOUT()                   \
    do {                                                             \
        if (wil::details::g_pfnFailFastInLoaderCallout != nullptr) { \
            wil::details::g_pfnFailFastInLoaderCallout();            \
        }                                                            \
    } while (0, 0)

//*****************************************************************************
// Macros to throw exceptions on failure
//*****************************************************************************

#ifdef WIL_ENABLE_EXCEPTIONS

// Always throw a known failure
#define THROW_HR(hr) __R_FN(Throw_Hr)(__R_INFO(#hr) wil::verify_hresult(hr))
#define THROW_LAST_ERROR() __R_FN(Throw_GetLastError)(__R_INFO_ONLY(nullptr))
#define THROW_WIN32(win32err) __R_FN(Throw_Win32)(__R_INFO(#win32err) win32err)
#define THROW_EXCEPTION(exception) wil::details::ReportFailure_CustomException(__R_INFO(#exception) exception)
#define THROW_NTSTATUS(status) __R_FN(Throw_NtStatus)(__R_INFO(#status) status)

// Conditionally throw failures - returns parameter value
#define THROW_IF_FAILED(hr) __R_FN(Throw_IfFailed)(__R_INFO(#hr) wil::verify_hresult(hr))
#define THROW_IF_WIN32_BOOL_FALSE(win32BOOL) __R_FN(Throw_IfWin32BoolFalse)(__R_INFO(#win32BOOL) wil::verify_BOOL(win32BOOL))
#define THROW_IF_WIN32_ERROR(win32err) __R_FN(Throw_IfWin32Error)(__R_INFO(#win32err) win32err)
#define THROW_IF_HANDLE_INVALID(handle) __R_FN(Throw_IfHandleInvalid)(__R_INFO(#handle) handle)
#define THROW_IF_HANDLE_NULL(handle) __R_FN(Throw_IfHandleNull)(__R_INFO(#handle) handle)
#define THROW_IF_NULL_ALLOC(ptr) __R_FN(Throw_IfNullAlloc)(__R_INFO(#ptr) ptr)
#define THROW_HR_IF(hr, condition) __R_FN(Throw_HrIf)(__R_INFO(#condition) wil::verify_hresult(hr), wil::verify_bool(condition))
#define THROW_HR_IF_FALSE(hr, condition) __R_FN(Throw_HrIfFalse)(__R_INFO(#condition) wil::verify_hresult(hr), wil::verify_bool(condition))
#define THROW_HR_IF_NULL(hr, ptr) __R_FN(Throw_HrIfNull)(__R_INFO(#ptr) wil::verify_hresult(hr), ptr)
#define THROW_LAST_ERROR_IF(condition) __R_FN(Throw_GetLastErrorIf)(__R_INFO(#condition) wil::verify_bool(condition))
#define THROW_LAST_ERROR_IF_FALSE(condition) __R_FN(Throw_GetLastErrorIfFalse)(__R_INFO(#condition) wil::verify_bool(condition))
#define THROW_LAST_ERROR_IF_NULL(ptr) __R_FN(Throw_GetLastErrorIfNull)(__R_INFO(#ptr) ptr)
#define THROW_IF_NTSTATUS_FAILED(status) __R_FN(Throw_IfNtStatusFailed)(__R_INFO(#status) status)

// Always throw a known failure - throw a var-arg message on failure
#define THROW_HR_MSG(hr, fmt, ...) __R_FN(Throw_HrMsg)(__R_INFO(#hr) wil::verify_hresult(hr), fmt, __VA_ARGS__)
#define THROW_LAST_ERROR_MSG(fmt, ...) __R_FN(Throw_GetLastErrorMsg)(__R_INFO(nullptr) fmt, __VA_ARGS__)
#define THROW_WIN32_MSG(win32err, fmt, ...) __R_FN(Throw_Win32Msg)(__R_INFO(#win32err) win32err, fmt, __VA_ARGS__)
#define THROW_EXCEPTION_MSG(exception, fmt, ...) \
    wil::details::ReportFailure_CustomExceptionMsg(__R_INFO(#exception) exception, fmt, __VA_ARGS__)
#define THROW_NTSTATUS_MSG(status, fmt, ...) __R_FN(Throw_NtStatusMsg)(__R_INFO(#status) status, fmt, __VA_ARGS__)

// Conditionally throw failures - returns parameter value - throw a var-arg message on failure
#define THROW_IF_FAILED_MSG(hr, fmt, ...) __R_FN(Throw_IfFailedMsg)(__R_INFO(#hr) wil::verify_hresult(hr), fmt, __VA_ARGS__)
#define THROW_IF_WIN32_BOOL_FALSE_MSG(win32BOOL, fmt, ...) \
    __R_FN(Throw_IfWin32BoolFalseMsg)(__R_INFO(#win32BOOL) wil::verify_BOOL(win32BOOL), fmt, __VA_ARGS__)
#define THROW_IF_WIN32_ERROR_MSG(win32err, fmt, ...) __R_FN(Throw_IfWin32ErrorMsg)(__R_INFO(#win32err) win32err, fmt, __VA_ARGS__)
#define THROW_IF_HANDLE_INVALID_MSG(handle, fmt, ...) __R_FN(Throw_IfHandleInvalidMsg)(__R_INFO(#handle) handle, fmt, __VA_ARGS__)
#define THROW_IF_HANDLE_NULL_MSG(handle, fmt, ...) __R_FN(Throw_IfHandleNullMsg)(__R_INFO(#handle) handle, fmt, __VA_ARGS__)
#define THROW_IF_NULL_ALLOC_MSG(ptr, fmt, ...) __R_FN(Throw_IfNullAllocMsg)(__R_INFO(#ptr) ptr, fmt, __VA_ARGS__)
#define THROW_HR_IF_MSG(hr, condition, fmt, ...) \
    __R_FN(Throw_HrIfMsg)(__R_INFO(#condition) wil::verify_hresult(hr), wil::verify_bool(condition), fmt, __VA_ARGS__)
#define THROW_HR_IF_FALSE_MSG(hr, condition, fmt, ...) \
    __R_FN(Throw_HrIfFalseMsg)(__R_INFO(#condition) wil::verify_hresult(hr), wil::verify_bool(condition), fmt, __VA_ARGS__)
#define THROW_HR_IF_NULL_MSG(hr, ptr, fmt, ...) __R_FN(Throw_HrIfNullMsg)(__R_INFO(#ptr) wil::verify_hresult(hr), ptr, fmt, __VA_ARGS__)
#define THROW_LAST_ERROR_IF_MSG(condition, fmt, ...) \
    __R_FN(Throw_GetLastErrorIfMsg)(__R_INFO(#condition) wil::verify_bool(condition), fmt, __VA_ARGS__)
#define THROW_LAST_ERROR_IF_FALSE_MSG(condition, fmt, ...) \
    __R_FN(Throw_GetLastErrorIfFalseMsg)(__R_INFO(#condition) wil::verify_bool(condition), fmt, __VA_ARGS__)
#define THROW_LAST_ERROR_IF_NULL_MSG(ptr, fmt, ...) __R_FN(Throw_GetLastErrorIfNullMsg)(__R_INFO(#ptr) ptr, fmt, __VA_ARGS__)
#define THROW_IF_NTSTATUS_FAILED_MSG(status, fmt, ...) __R_FN(Throw_IfNtStatusFailedMsg)(__R_INFO(#status) status, fmt, __VA_ARGS__)

//*****************************************************************************
// Macros to catch and convert exceptions on failure
//*****************************************************************************

// Conditionally returns a known failure (HRESULT) (always place immediately after a try { } block)
#define CATCH_RETURN()                                                   \
    catch (...) {                                                        \
        __RETURN_HR_LOG_FAIL(wil::ResultFromCaughtException(), nullptr); \
    }
#define CATCH_RETURN_MSG(fmt, ...)                                                         \
    catch (...) {                                                                          \
        __RETURN_HR_MSG_FAIL(wil::ResultFromCaughtException(), nullptr, fmt, __VA_ARGS__); \
    }
#define CATCH_RETURN_EXPECTED()                  \
    catch (...) {                                \
        return wil::ResultFromCaughtException(); \
    }

// Conditionally logs a known failure (always place immediately after a try { } block)
#define CATCH_LOG()                                                         \
    catch (...) {                                                           \
        __R_FN(Log_Hr)(__R_INFO(nullptr) wil::ResultFromCaughtException()); \
    }
#define CATCH_LOG_MSG(fmt, ...)                                                                  \
    catch (...) {                                                                                \
        __R_FN(Log_HrMsg)(__R_INFO(nullptr) wil::ResultFromCaughtException(), fmt, __VA_ARGS__); \
    }

// Conditionally fail fast (always place immediately after a try { } block)
#define CATCH_FAIL_FAST()                                                        \
    catch (...) {                                                                \
        __R_FN(FailFast_Hr)(__R_INFO(nullptr) wil::ResultFromCaughtException()); \
    }
#define CATCH_FAIL_FAST_MSG(fmt, ...)                                                                 \
    catch (...) {                                                                                     \
        __R_FN(FailFast_HrMsg)(__R_INFO(nullptr) wil::ResultFromCaughtException(), fmt, __VA_ARGS__); \
    }

// Conditionally normalize (rethrow) a caught exception to ResultException or NSException (always place immediately after a try { }
// block)
#define CATCH_THROW_NORMALIZED()                                                \
    catch (...) {                                                               \
        wil::details::RethrowNormalizedCaughtException(__R_INFO_ONLY(nullptr)); \
    }
#define CATCH_THROW_NORMALIZED_MSG(fmt, ...)                                                   \
    catch (...) {                                                                              \
        wil::details::RethrowNormalizedCaughtExceptionMsg(__R_INFO(nullptr) fmt, __VA_ARGS__); \
    }

#endif // WIL_ENABLE_EXCEPTIONS

//*****************************************************************************
// Assert Macros
//*****************************************************************************

#ifdef RESULT_DEBUG
#define WI_ASSERT(condition)          \
    (__WI_ANALYSIS_ASSUME(condition), \
     ((!(condition)) ? (__annotation(L"Debug", L"AssertFail", L#condition), DbgRaiseAssertionFailure(), false) : true))
#define WI_ASSERT_MSG(condition, msg) \
    (__WI_ANALYSIS_ASSUME(condition), \
     ((!(condition)) ? (__annotation(L"Debug", L"AssertFail", L##msg), DbgRaiseAssertionFailure(), false) : true))
#define WI_ASSERT_NOASSUME WI_ASSERT
#define WI_ASSERT_MSG_NOASSUME WI_ASSERT_MSG
#define WI_VERIFY WI_ASSERT
#define WI_VERIFY_MSG WI_ASSERT_MSG
#else
#define WI_ASSERT(condition) (__WI_ANALYSIS_ASSUME(condition), 0)
#define WI_ASSERT_MSG(condition, msg) (__WI_ANALYSIS_ASSUME(condition), 0)
#define WI_ASSERT_NOASSUME(condition) ((void)0)
#define WI_ASSERT_MSG_NOASSUME(condition, msg) ((void)0)
#define WI_VERIFY(condition) (__WI_ANALYSIS_ASSUME(condition), ((condition) ? true : false))
#define WI_VERIFY_MSG(condition, msg) (__WI_ANALYSIS_ASSUME(condition), ((condition) ? true : false))
#endif // RESULT_DEBUG

//*****************************************************************************
// Usage Error Macros
//*****************************************************************************

#ifndef WI_USAGE_ASSERT
#define WI_USAGE_ASSERT(condition) WI_ASSERT(condition)
#endif
// #ifdef RESULT_DEBUG
// #define WI_USAGE_ERROR(msg, ...)                            do { LOG_HR_MSG(HRESULT_FROM_WIN32(ERROR_ASSERTION_FAILURE), msg,
// __VA_ARGS__); WI_USAGE_ASSERT(false); } while (0, 0)
// #define WI_USAGE_ERROR_FORWARD(msg, ...)                    do { ReportFailure_ReplaceMsg(__R_FN_CALL_FULL, FailureType::Log,
// HRESULT_FROM_WIN32(ERROR_ASSERTION_FAILURE), msg, __VA_ARGS__); WI_USAGE_ASSERT(false); } while (0, 0)
// #else
#define WI_USAGE_ERROR( \
    msg, ...) //                        do { LOG_HR(HRESULT_FROM_WIN32(ERROR_ASSERTION_FAILURE)); WI_USAGE_ASSERT(false); } while (0, 0)
#define WI_USAGE_ERROR_FORWARD(msg, ...) //                   do { ReportFailure_Hr(__R_FN_CALL_FULL, FailureType::Log,
//                   HRESULT_FROM_WIN32(ERROR_ASSERTION_FAILURE)); WI_USAGE_ASSERT(false); } while
//                   (0, 0)
// #endif
#define WI_USAGE_VERIFY(condition, msg, ...)         \
    do {                                             \
        auto __passed = wil::verify_bool(condition); \
        if (!__passed) {                             \
            WI_USAGE_ERROR(msg, __VA_ARGS__);        \
        }                                            \
    } while (0, 0)
#define WI_USAGE_VERIFY_FORWARD(condition, msg, ...)  \
    do {                                              \
        auto __passed = wil::verify_bool(condition);  \
        if (!__passed) {                              \
            WI_USAGE_ERROR_FORWARD(msg, __VA_ARGS__); \
        }                                             \
    } while (0, 0)

// [deprecated] Old macros names -- to be removed -- do not use
#define RETURN_HR_IF_TRUE RETURN_HR_IF
#define RETURN_LAST_ERROR_IF_TRUE RETURN_LAST_ERROR_IF
#define RETURN_HR_IF_TRUE_LOG RETURN_HR_IF_LOG
#define RETURN_HR_IF_TRUE_MSG RETURN_HR_IF_MSG
#define RETURN_HR_IF_TRUE_EXPECTED RETURN_HR_IF_EXPECTED
#define LOG_HR_IF_TRUE LOG_HR_IF
#define LOG_HR_IF_TRUE_MSG LOG_HR_IF_MSG
#define LOG_LAST_ERROR_IF_TRUE LOG_LAST_ERROR_IF
#define FAIL_FAST_HR_IF_TRUE FAIL_FAST_HR_IF
#ifdef WIL_ENABLE_EXCEPTIONS
#define THROW_HR_IF_TRUE THROW_HR_IF
#define THROW_LAST_ERROR_IF_TRUE THROW_LAST_ERROR_IF
#define THROW_HR_IF_TRUE_MSG THROW_HR_IF_MSG
#endif // WIL_ENABLE_EXCEPTIONS

//*****************************************************************************
// Objective-C Error Macros
//*****************************************************************************

__declspec(selectany) bool (*g_resultFromUncaughtExceptionObjC)(HRESULT* out) = nullptr;
__declspec(selectany) void (*g_rethrowAsNSException)() = nullptr;
__declspec(selectany) void (*g_objcThrowFailureInfo)(const wil::FailureInfo& fi) = nullptr;
__declspec(selectany) void (*g_rethrowNormalizedCaughtExceptionObjC)(__R_FN_PARAMS_FULL, _In_opt_ PCWSTR message) = nullptr;

#define THROW_NS_HR(hr) __R_FN(Objc_Throw_HrMsg)(__R_INFO(#hr) wil::verify_hresult(hr), nullptr)
#define THROW_NS_HR_MSG(hr, msg, ...) __R_FN(Objc_Throw_HrMsg)(__R_INFO(#hr) wil::verify_hresult(hr), msg, __VA_ARGS__)
#define THROW_NS_IF_FAILED(hr) __R_FN(Objc_Throw_IfFailed)(__R_INFO(#hr) wil::verify_hresult(hr))
#define THROW_NS_IF_FAILED_MSG(hr, fmt, ...) __R_FN(Objc_Throw_IfFailedMsg)(__R_INFO(#hr) wil::verify_hresult(hr), fmt, __VA_ARGS__)

#define THROW_NS_IF(hr, condition) __R_FN(Objc_Throw_HrIf)(__R_INFO(#condition) wil::verify_hresult(hr), wil::verify_bool(condition))
#define THROW_NS_IF_FALSE(hr, condition) \
    __R_FN(Objc_Throw_HrIfFalse)(__R_INFO(#condition) wil::verify_hresult(hr), wil::verify_bool(condition))
#define THROW_NS_IF_NULL(hr, ptr) __R_FN(Objc_Throw_HrIfNull)(__R_INFO(#ptr) wil::verify_hresult(hr), ptr)

#define THROW_NS_IF_MSG(hr, condition, fmt, ...) \
    __R_FN(Objc_Throw_HrIfMsg)(__R_INFO(#condition) wil::verify_hresult(hr), wil::verify_bool(condition), fmt, __VA_ARGS__)
#define THROW_NS_IF_FALSE_MSG(hr, condition, fmt, ...) \
    __R_FN(Objc_Throw_HrIfFalseMsg)(__R_INFO(#condition) wil::verify_hresult(hr), wil::verify_bool(condition), fmt, __VA_ARGS__)
#define THROW_NS_IF_NULL_MSG(hr, ptr, fmt, ...) \
    __R_FN(Objc_Throw_HrIfNullMsg)(__R_INFO(#ptr) wil::verify_hresult(hr), ptr, fmt, __VA_ARGS__)

#define CATCH_THROW_NSEXCEPTION() \
    catch (...) {                 \
        _rethrowAsNSException();  \
    }

#define CATCH_POPULATE_NSERROR(error)    \
    catch (...) {                        \
        _catchAndPopulateNSError(error); \
    }

namespace wil {
// Indicates the kind of message / failure type that was used to produce a given error
enum class FailureType {
    Exception, // THROW_...
    ObjCException, // THROW_NS_...
    Return, // RETURN_..._LOG or RETURN_..._MSG
    ReturnPreRelease, // RETURN_...
    Log, // LOG_...
    FailFast // FAIL_FAST_...
};

// Represents the call context information about a given failure
// No constructors, destructors or virtual members should be contained within
struct CallContextInfo {
    long contextId; // incrementing ID for this call context (unique across an individual module load within process)
    PCSTR contextName; // the explicit name given to this context
    PCWSTR contextMessage; // [optional] Message that can be associated with the call context
};

inline void ClearContext(_Out_ CallContextInfo* pContext) WI_NOEXCEPT {
    pContext->contextId = 0;
    pContext->contextName = nullptr;
    pContext->contextMessage = nullptr;
}

// Represents all context information about a given failure
// No constructors, destructors or virtual members should be contained within
struct FailureInfo {
    FailureType type;
    HRESULT hr;
    long failureId; // incrementing ID for this specific failure (unique across an individual module load within process)
    PCWSTR pszMessage; // Message is only present for _MSG logging (it's the Sprintf message)
    DWORD threadId; // the thread this failure was originally encountered on
    PCSTR pszCode; // [debug only] Capture code from the macro
    PCSTR pszFunction; // [debug only] The function name
    PCSTR pszFile;
    unsigned int uLineNumber;
    int cFailureCount; // How many failures of 'type' have been reported in this module so far
    PCSTR pszCallContext; // General breakdown of the call context stack that generated this failure
    CallContextInfo callContextOriginating; // The outermost (first seen) call context
    CallContextInfo callContextCurrent; // The most recently seen call context
    PCSTR pszModule; // The module where the failure originated
    void* returnAddress; // The return address to the point that called the macro
    void* callerReturnAddress; // The return address of the function that includes the macro
};

// [optionally] Plug in error logging
// Note:  This callback is deprecated.  Please use SetResultTelemetryFallback for telemetry or
// SetResultLoggingCallback for observation.
__declspec(selectany) void(__stdcall* g_pfnResultLoggingCallback)(_Inout_ wil::FailureInfo* pFailure,
                                                                  _Inout_updates_opt_z_(cchDebugMessage) PWSTR pszDebugMessage,
                                                                  _Pre_satisfies_(cchDebugMessage > 0)
                                                                      size_t cchDebugMessage) WI_NOEXCEPT = nullptr;

// [optional]
// This can be explicitly set to control whether or not error messages will be output to OutputDebugString.  It can also
// be set directly from within the debugger to force console logging for debugging purposes.
#if (defined(DBG) || defined(_DEBUG))
__declspec(selectany) bool g_fResultOutputDebugString = true;
#else
__declspec(selectany) bool g_fResultOutputDebugString = false;
#endif

// [optionally] Plug in additional exception-type support (return S_OK when *unable* to remap the exception)
__declspec(selectany) HRESULT(__stdcall* g_pfnResultFromCaughtException)() WI_NOEXCEPT = nullptr;

// [optionally] Use to configure fast fail of unknown exceptions (turn them off).
__declspec(selectany) bool g_fResultFailFastUnknownExceptions = true;

//! @cond
namespace details {
_Success_(true) _Ret_range_(dest, destEnd) inline PWSTR LogStringPrintf(_Out_writes_to_ptr_(destEnd) _Always_(_Post_z_) PWSTR dest,
                                                                        _Pre_satisfies_(destEnd >= dest) PCWSTR destEnd,
                                                                        _In_ _Printf_format_string_ PCWSTR format,
                                                                        ...) {
    va_list argList;
    va_start(argList, format);
    StringCchVPrintfW(dest, (destEnd - dest), format, argList);
    return (destEnd == dest) ? dest : (dest + wcslen(dest));
}
}
//! @endcond

// This call generates the default logging string that makes its way to OutputDebugString for
// any particular failure.  This string is also used to associate a failure with a PlatformException^ which
// only allows a single string to be associated with the exception.
inline HRESULT GetFailureLogString(_Out_writes_(cchDest) _Always_(_Post_z_) PWSTR pszDest,
                                   _Pre_satisfies_(cchDest > 0) _In_ size_t cchDest,
                                   _In_ FailureInfo const& failure) WI_NOEXCEPT {
    PCSTR pszType = "";
    switch (failure.type) {
        case FailureType::Exception:
            pszType = "Exception";
            break;
        case FailureType::ObjCException:
            pszType = "Objective-C Exception";
            break;
        case FailureType::Return:
            pszType = "ReturnHr";
            break;
        case FailureType::ReturnPreRelease:
            pszType = "ReturnHr[PreRelease]";
            break;
        case FailureType::Log:
            pszType = "LogHr";
            break;
        case FailureType::FailFast:
            pszType = "FailFast";
            break;
    }

    wchar_t szErrorText[256];
    szErrorText[0] = L'\0';
    FormatMessageW(FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS,
                   nullptr,
                   failure.hr,
                   MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
                   szErrorText,
                   ARRAYSIZE(szErrorText),
                   nullptr);

    // %FILENAME(%LINE): %TYPE(%count) tid(%threadid) %HRESULT %SystemMessage
    //     %Caller_MSG [%CODE(%FUNCTION)]

    PWSTR dest = pszDest;
    PCWSTR destEnd = (pszDest + cchDest);

    if (failure.pszFile != nullptr) {
        dest = details::LogStringPrintf(
            dest, destEnd, L"%hs(%d)\\%hs!%p: ", failure.pszFile, failure.uLineNumber, failure.pszModule, failure.returnAddress);
    } else {
        dest = details::LogStringPrintf(dest, destEnd, L"%hs!%p: ", failure.pszModule, failure.returnAddress);
    }

    if (failure.callerReturnAddress != nullptr) {
        dest = details::LogStringPrintf(dest, destEnd, L"(caller: %p) ", failure.callerReturnAddress);
    }

    dest = details::LogStringPrintf(
        dest, destEnd, L"%hs(%d) tid(%x) %08X %ws", pszType, failure.cFailureCount, ::GetCurrentThreadId(), failure.hr, szErrorText);

    if ((failure.pszMessage != nullptr) || (failure.pszCallContext != nullptr) || (failure.pszFunction != nullptr)) {
        dest = details::LogStringPrintf(dest, destEnd, L"    ");
        if (failure.pszMessage != nullptr) {
            dest = details::LogStringPrintf(dest, destEnd, L"Msg:[%ws] ", failure.pszMessage);
        }
        if (failure.pszCallContext != nullptr) {
            dest = details::LogStringPrintf(dest, destEnd, L"CallContext:[%hs] ", failure.pszCallContext);
        }

        if (failure.pszCode != nullptr) {
            dest = details::LogStringPrintf(dest, destEnd, L"[%hs(%hs)]\n", failure.pszFunction, failure.pszCode);
        } else if (failure.pszFunction != nullptr) {
            dest = details::LogStringPrintf(dest, destEnd, L"[%hs]\n", failure.pszFunction);
        } else {
            dest = details::LogStringPrintf(dest, destEnd, L"\n");
        }
    }

    // Explicitly choosing to return success in the event of truncation... Current callers
    // depend upon it or it would be eliminated.
    return S_OK;
}

//! @cond
namespace details {
#ifdef WIL_SUPPRESS_PRIVATE_API_USE
#pragma detect_mismatch("ODR_violation_WIL_SUPPRESS_PRIVATE_API_USE_mismatch", "1")
#else
#pragma detect_mismatch("ODR_violation_WIL_SUPPRESS_PRIVATE_API_USE_mismatch", "0")
#endif

#ifdef RESULT_PRERELEASE
#pragma detect_mismatch("ODR_violation_WIL_RESULT_PRERELEASE_mismatch", "1")
#else
#pragma detect_mismatch("ODR_violation_WIL_RESULT_PRERELEASE_mismatch", "0")
#endif

// Fallback telemetry provider callback (set with wil::SetResultTelemetryFallback)
__declspec(selectany) void(__stdcall* g_pfnTelemetryCallback)(bool alreadyReported, wil::FailureInfo const& failure) WI_NOEXCEPT = nullptr;

// Observe all errors flowing through the system with this callback (set with wil::SetResultLoggingCallback); use with custom logging
// WIL logging callback; exported from our logging binary so the same instance is shared across all of our modules in a given process.
WIL_EXPORT void(__stdcall* g_pfnLoggingCallback)(wil::FailureInfo const& failure) WI_NOEXCEPT;

// True if g_pfnResultLoggingCallback is set (allows cutting off backwards compat calls to the function)
__declspec(selectany) bool g_resultMessageCallbackSet = false;

// Desktop Only:  Module fetch function (automatically setup)
__declspec(selectany) PCSTR(__stdcall* g_pfnGetModuleName)() WI_NOEXCEPT = nullptr;

// Desktop Only:  Private module load fail fast function (automatically setup)
__declspec(selectany) void(__stdcall* g_pfnFailFastInLoaderCallout)() WI_NOEXCEPT = nullptr;

// Desktop Only:  Private module load convert NtStatus to HResult (automatically setup)
__declspec(selectany) ULONG(__stdcall* g_pfnRtlNtStatusToDosErrorNoTeb)(NTSTATUS) = nullptr;

enum class ReportFailureOptions { None = 0x00, ForceObjCException = 0x01, SuppressAction = 0x02 };
DEFINE_ENUM_FLAG_OPERATORS(ReportFailureOptions);

// Forward declarations to enable use of fail fast and reporting internally...
namespace __R_NS_NAME {
__R_DIRECT_METHOD(HRESULT, Log_Hr)(__R_DIRECT_FN_PARAMS HRESULT hr) WI_NOEXCEPT;
__R_DIRECT_METHOD(HRESULT, Log_HrMsg)(__R_DIRECT_FN_PARAMS HRESULT hr, _Printf_format_string_ PCSTR formatString, ...) WI_NOEXCEPT;
__R_DIRECT_METHOD(DWORD, Log_Win32Msg)(__R_DIRECT_FN_PARAMS DWORD err, _Printf_format_string_ PCSTR formatString, ...) WI_NOEXCEPT;
}
namespace __RFF_NS_NAME {
__RFF_DIRECT_NORET_METHOD(void, FailFast_Unexpected)(__RFF_DIRECT_FN_PARAMS_ONLY) WI_NOEXCEPT;
__RFF_CONDITIONAL_METHOD(bool, FailFast_If)(__RFF_CONDITIONAL_FN_PARAMS bool condition) WI_NOEXCEPT;
__RFF_CONDITIONAL_METHOD(bool, FailFast_HrIf)(__RFF_CONDITIONAL_FN_PARAMS HRESULT hr, bool condition) WI_NOEXCEPT;
__RFF_CONDITIONAL_METHOD(bool, FailFast_IfFalse)(__RFF_CONDITIONAL_FN_PARAMS bool condition) WI_NOEXCEPT;
}
__declspec(noinline) inline void ReportFailure(__R_FN_PARAMS_FULL,
                                               FailureType type,
                                               HRESULT hr,
                                               _In_opt_ PCWSTR message = nullptr,
                                               ReportFailureOptions options = ReportFailureOptions::None);
inline void ReportFailure_ReplaceMsg(__R_FN_PARAMS_FULL, FailureType type, HRESULT hr, _Printf_format_string_ PCSTR formatString, ...);
__declspec(noinline) inline void ReportFailure_Hr(__R_FN_PARAMS_FULL, FailureType type, HRESULT hr);
_Always_(_Post_satisfies_(return < 0)) inline HRESULT ResultFromUnknownCaughtException();

// A simple ref-counted buffer class.  The interface is very similar to shared_ptr<>, only it manages
// an allocated buffer (malloc) and maintains the size.

class shared_buffer {
public:
    shared_buffer() WI_NOEXCEPT : m_pCopy(nullptr), m_size(0) {
    }

    shared_buffer(shared_buffer const& other) WI_NOEXCEPT : m_pCopy(nullptr), m_size(0) {
        assign(other.m_pCopy, other.m_size);
    }

    shared_buffer(shared_buffer&& other) WI_NOEXCEPT : m_pCopy(other.m_pCopy), m_size(other.m_size) {
        other.m_pCopy = nullptr;
        other.m_size = 0;
    }

    ~shared_buffer() WI_NOEXCEPT {
        reset();
    }

    shared_buffer& operator=(shared_buffer const& other) WI_NOEXCEPT {
        assign(other.m_pCopy, other.m_size);
        return *this;
    }

    shared_buffer& operator=(shared_buffer&& other) WI_NOEXCEPT {
        reset();
        m_pCopy = other.m_pCopy;
        m_size = other.m_size;
        other.m_pCopy = nullptr;
        other.m_size = 0;
        return *this;
    }

    void reset() WI_NOEXCEPT {
        if (m_pCopy != nullptr) {
            if (0 == ::InterlockedDecrementRelease(m_pCopy)) {
                free(m_pCopy);
            }
            m_pCopy = nullptr;
            m_size = 0;
        }
    }

    bool create(_In_reads_bytes_opt_(cbData) void const* pData, size_t cbData) WI_NOEXCEPT {
        if (cbData == 0) {
            reset();
            return true;
        }

        long* pCopyRefCount = reinterpret_cast<long*>(malloc(sizeof(long) + cbData));
        if (pCopyRefCount == nullptr) {
            return false;
        }

        *pCopyRefCount = 0;
        if (pData != nullptr) {
            CopyMemory(pCopyRefCount + 1, pData, cbData); // +1 to advance past sizeof(long) counter
        }
        assign(pCopyRefCount, cbData);
        return true;
    }

    bool create(size_t cbData) WI_NOEXCEPT {
        return create(nullptr, cbData);
    }

    void* get(_Out_opt_ size_t* pSize = nullptr) const WI_NOEXCEPT {
        if (pSize != nullptr) {
            *pSize = m_size;
        }
        return (m_pCopy == nullptr) ? nullptr : (m_pCopy + 1);
    }

    size_t size() const WI_NOEXCEPT {
        return m_size;
    }

    explicit operator bool() const WI_NOEXCEPT {
        return (m_pCopy != nullptr);
    }

    bool unique() const WI_NOEXCEPT {
        return ((m_pCopy != nullptr) && (*m_pCopy == 1));
    }

private:
    long* m_pCopy; // pointer to allocation: refcount + data
    size_t m_size; // size of the data from m_pCopy

    void assign(_In_opt_ long* pCopy, size_t cbSize) WI_NOEXCEPT {
        reset();
        if (pCopy != nullptr) {
            m_pCopy = pCopy;
            m_size = cbSize;
            ::InterlockedIncrementNoFence(m_pCopy);
        }
    }
};

inline shared_buffer make_shared_buffer_nothrow(_In_reads_bytes_opt_(countBytes) void* pData, size_t countBytes) WI_NOEXCEPT {
    shared_buffer buffer;
    buffer.create(pData, countBytes);
    return buffer;
}

inline shared_buffer make_shared_buffer_nothrow(size_t countBytes) WI_NOEXCEPT {
    shared_buffer buffer;
    buffer.create(countBytes);
    return buffer;
}

// A small mimic of the STL shared_ptr class, but unlike shared_ptr, a pointer is not attached to the class, but is
// always simply contained within (it cannot be attached or detached).

template <typename object_t>
class shared_object {
public:
    shared_object() WI_NOEXCEPT : m_pCopy(nullptr) {
    }

    shared_object(shared_object const& other) WI_NOEXCEPT : m_pCopy(other.m_pCopy) {
        if (m_pCopy != nullptr) {
            ::InterlockedIncrementNoFence(&m_pCopy->m_refCount);
        }
    }

    shared_object(shared_object&& other) WI_NOEXCEPT : m_pCopy(other.m_pCopy) {
        other.m_pCopy = nullptr;
    }

    ~shared_object() WI_NOEXCEPT {
        reset();
    }

    shared_object& operator=(shared_object const& other) WI_NOEXCEPT {
        reset();
        m_pCopy = other.m_pCopy;
        if (m_pCopy != nullptr) {
            ::InterlockedIncrementNoFence(&m_pCopy->m_refCount);
        }
        return *this;
    }

    shared_object& operator=(shared_object&& other) WI_NOEXCEPT {
        reset();
        m_pCopy = other.m_pCopy;
        other.m_pCopy = nullptr;
        return *this;
    }

    void reset() WI_NOEXCEPT {
        if (m_pCopy != nullptr) {
            if (0 == ::InterlockedDecrementRelease(&m_pCopy->m_refCount)) {
                delete m_pCopy;
            }
            m_pCopy = nullptr;
        }
    }

    bool create() {
        RefAndObject* pObject = new (std::nothrow) RefAndObject();
        if (pObject == nullptr) {
            return false;
        }
        reset();
        m_pCopy = pObject;
        return true;
    }

    template <typename param_t>
    bool create(param_t&& param1) {
        RefAndObject* pObject = new (std::nothrow) RefAndObject(wistd::forward<param_t>(param1));
        if (pObject == nullptr) {
            return false;
        }
        reset();
        m_pCopy = pObject;
        return true;
    }

    object_t* get() const WI_NOEXCEPT {
        return (m_pCopy == nullptr) ? nullptr : &m_pCopy->m_object;
    }

    explicit operator bool() const WI_NOEXCEPT {
        return (m_pCopy != nullptr);
    }

    bool unique() const WI_NOEXCEPT {
        return ((m_pCopy != nullptr) && (m_pCopy->m_refCount == 1));
    }

    object_t* operator->() const WI_NOEXCEPT {
        return get();
    }

private:
    struct RefAndObject {
        long m_refCount;
        object_t m_object;

        RefAndObject() : m_refCount(1), m_object() {
        }

        template <typename param_t>
        RefAndObject(param_t&& param1) : m_refCount(1), m_object(wistd::forward<param_t>(param1)) {
        }
    };

    RefAndObject* m_pCopy;
};

template <typename object_t>
inline shared_object<object_t> make_shared_object_nothrow() {
    shared_object<object_t> object;
    object.create();
    return object;
}

// Note that this should eventually be switched to variadic template forwarding, but cannot be at the moment due
// to the use of this from Result.h and it's dependence upon an older compiler for the phone build
template <typename object_t, typename param_t>
inline shared_object<object_t> make_shared_object_nothrow(param_t&& param1) {
    shared_object<object_t> object;
    object.create(wistd::forward<param_t>(param1));
    return object;
}

// The following functions are basically the same, but are kept separated to:
// 1) Provide a unique count and last error code per-type
// 2) Avoid merging the types to allow easy debugging (breakpoints, conditional breakpoints based
//      upon count of errors from a particular type, etc)

__declspec(noinline) inline int RecordException(HRESULT hr) WI_NOEXCEPT {
    static HRESULT volatile s_hrErrorLast = S_OK;
    static long volatile s_cErrorCount = 0;
    s_hrErrorLast = hr;
    return ::InterlockedIncrementNoFence(&s_cErrorCount);
}

__declspec(noinline) inline int RecordReturn(HRESULT hr) WI_NOEXCEPT {
    static HRESULT volatile s_hrErrorLast = S_OK;
    static long volatile s_cErrorCount = 0;
    s_hrErrorLast = hr;
    return ::InterlockedIncrementNoFence(&s_cErrorCount);
}

__declspec(noinline) inline int RecordReturnPreRelease(HRESULT hr) WI_NOEXCEPT {
    static HRESULT volatile s_hrErrorLast = S_OK;
    static long volatile s_cErrorCount = 0;
    s_hrErrorLast = hr;
    return ::InterlockedIncrementNoFence(&s_cErrorCount);
}

__declspec(noinline) inline int RecordLog(HRESULT hr) WI_NOEXCEPT {
    static HRESULT volatile s_hrErrorLast = S_OK;
    static long volatile s_cErrorCount = 0;
    s_hrErrorLast = hr;
    return ::InterlockedIncrementNoFence(&s_cErrorCount);
}

__declspec(noinline) inline int RecordFailFast(HRESULT hr) WI_NOEXCEPT {
    static HRESULT volatile s_hrErrorLast = S_OK;
    s_hrErrorLast = hr;
    return 1;
}

__declspec(noinline) inline HRESULT NtStatusToHr(NTSTATUS status) {
    // The following conversions are the only known incorrect mappings in RtlNtStatusToDosErrorNoTeb
    if (SUCCEEDED_NTSTATUS(status)) {
        // All successful status codes have only one hresult equivalent, S_OK
        return S_OK;
    }
    if (status == STATUS_NO_MEMORY) {
        // RtlNtStatusToDosErrorNoTeb maps STATUS_NO_MEMORY to the less popular of two Win32 no memory error codes resulting in an
        // unexpected mapping
        return E_OUTOFMEMORY;
    }

    if (g_pfnRtlNtStatusToDosErrorNoTeb != nullptr) {
        DWORD err = g_pfnRtlNtStatusToDosErrorNoTeb(status);
        if (err != 0) {
            return HRESULT_FROM_WIN32(err);
        }
    }

    return HRESULT_FROM_NT(status);
}

// The following set of functions all differ only based upon number of arguments.  They are unified in their handling
// of data from each of the various error-handling types (fast fail, exceptions, etc.).

inline DWORD GetLastErrorFail(__R_FN_PARAMS_FULL) WI_NOEXCEPT {
    __R_FN_UNREFERENCED;
    auto err = ::GetLastError();
    if (SUCCEEDED_WIN32(err)) {
        // This function should only be called when GetLastError() is set to a FAILURE.
        // If you hit this assert (or are reviewing this failure telemetry), then there are one of three issues:
        //  1) Your code is using a macro (such as RETURN_IF_WIN32_BOOL_FALSE()) on a function that does not actually
        //      set the last error (consult MSDN).
        //  2) Your macro check against the error is not immediately after the API call.  Pushing it later can result
        //      in another API call between the previous one and the check resetting the last error.
        //  3) The API you're calling has a bug in it and does not accurately set the last error (there are a few
        //      examples here, such as SendMessageTimeout() that don't accurately set the last error).  For these,
        //      please send mail to 'wildisc' when found and work-around with win32errorhelpers.

        WI_USAGE_ERROR_FORWARD("CALLER BUG: Macro usage error detected.  GetLastError() does not have an error.");
        return ERROR_ASSERTION_FAILURE;
    }
    return err;
}

inline HRESULT GetLastErrorFailHr(__R_FN_PARAMS_FULL) WI_NOEXCEPT {
    return HRESULT_FROM_WIN32(GetLastErrorFail(__R_FN_CALL_FULL));
}

inline __declspec(noinline) HRESULT GetLastErrorFailHr() WI_NOEXCEPT {
    __R_FN_LOCALS_FULL_RA;
    return GetLastErrorFailHr(__R_FN_CALL_FULL);
}

inline void PrintLoggingMessage(_Out_writes_(cchDest) _Post_z_ PWSTR pszDest,
                                _Pre_satisfies_(cchDest > 0) size_t cchDest,
                                _In_opt_ _Printf_format_string_ PCSTR formatString,
                                _In_ va_list argList) WI_NOEXCEPT {
    if (formatString == nullptr) {
        pszDest[0] = L'\0';
    } else {
        wchar_t szFormatWide[2048];
        StringCchPrintfW(szFormatWide, ARRAYSIZE(szFormatWide), L"%hs", formatString);
        StringCchVPrintfW(pszDest, cchDest, szFormatWide, argList);
    }
}

#pragma warning(push)
#pragma warning(disable : __WARNING_RETURNING_BAD_RESULT)
// NOTE: The following two functions are unfortunate copies of strsafe.h functions that have been copied to reduce the friction associated
// with using
// Result.h and ResultException.h in a build that does not have WINAPI_PARTITION_DESKTOP defined (where these are conditionally enabled).

STRSAFEWORKERAPI WilStringLengthWorkerA(_In_reads_or_z_(cchMax) STRSAFE_PCNZCH psz,
                                        _In_ _In_range_(<=, STRSAFE_MAX_CCH) size_t cchMax,
                                        _Out_opt_ _Deref_out_range_(<, cchMax) _Deref_out_range_(<=, _String_length_(psz))
                                            size_t* pcchLength) {
    HRESULT hr = S_OK;
    size_t cchOriginalMax = cchMax;
    while (cchMax && (*psz != '\0')) {
        psz++;
        cchMax--;
    }
    if (cchMax == 0) {
        // the string is longer than cchMax
        hr = STRSAFE_E_INVALID_PARAMETER;
    }
    if (pcchLength) {
        if (SUCCEEDED(hr)) {
            *pcchLength = cchOriginalMax - cchMax;
        } else {
            *pcchLength = 0;
        }
    }
    return hr;
}

_Must_inspect_result_ STRSAFEAPI StringCchLengthA(_In_reads_or_z_(cchMax) STRSAFE_PCNZCH psz,
                                                  _In_ _In_range_(1, STRSAFE_MAX_CCH) size_t cchMax,
                                                  _Out_opt_ _Deref_out_range_(<, cchMax) _Deref_out_range_(<=, _String_length_(psz))
                                                      size_t* pcchLength) {
    HRESULT hr;
    if ((psz == NULL) || (cchMax > STRSAFE_MAX_CCH)) {
        hr = STRSAFE_E_INVALID_PARAMETER;
    } else {
        hr = WilStringLengthWorkerA(psz, cchMax, pcchLength);
    }
    if (FAILED(hr) && pcchLength) {
        *pcchLength = 0;
    }
    return hr;
}
#pragma warning(pop)

_Ret_range_(sizeof(char), (psz == nullptr) ? sizeof(char) : (_String_length_(psz) + sizeof(char))) inline size_t
    ResultStringSize(_In_opt_ PCSTR psz) {
    return (psz == nullptr) ? sizeof(char) : (strlen(psz) + sizeof(char));
}

_Ret_range_(sizeof(wchar_t), (psz == nullptr) ? sizeof(wchar_t) : ((_String_length_(psz) + 1) * sizeof(wchar_t))) inline size_t
    ResultStringSize(_In_opt_ PCWSTR psz) {
    return (psz == nullptr) ? sizeof(wchar_t) : (wcslen(psz) + 1) * sizeof(wchar_t);
}

template <typename TString>
_Ret_range_(pStart, pEnd) inline unsigned char* WriteResultString(_Out_writes_to_ptr_opt_(pEnd) unsigned char* pStart,
                                                                  _In_opt_ unsigned char* pEnd,
                                                                  _In_opt_ TString pszString,
                                                                  _Out_opt_ TString* ppszBufferString = nullptr) {
    decltype(pszString[0]) const cZero = 0;
    TString const pszLocal = (pszString == nullptr) ? &cZero : pszString;
    __analysis_assume(pszLocal != nullptr); // VS2015.RC CA tools don't understand that pszLocal is forcibly non-null due top
    size_t const cchWant = ResultStringSize(pszLocal) / sizeof(cZero);
    size_t const cchMax = static_cast<size_t>(pEnd - pStart) / sizeof(cZero);
    size_t const cchCopy = (cchWant < cchMax) ? cchWant : cchMax;
    ::CopyMemory(pStart, pszLocal, cchCopy * sizeof(cZero));
    wil::AssignToOptParam(ppszBufferString, (cchCopy > 1) ? reinterpret_cast<TString>(pStart) : nullptr);
    if ((cchCopy < cchWant) && (cchCopy > 0)) {
        auto pZero = pStart + ((cchCopy - 1) * sizeof(cZero));
        ::ZeroMemory(pZero, sizeof(cZero));
    }
#pragma warning(suppress : 28196) // Filed OSG bug 3026886 to address.
    return (pStart + (cchCopy * sizeof(cZero)));
}

_Ret_range_(0, (cchMax > 0) ? cchMax - 1 : 0) inline size_t UntrustedStringLength(_In_ PCSTR psz, _In_ size_t cchMax) {
    size_t cbLength;
    return SUCCEEDED(wil::details::StringCchLengthA(psz, cchMax, &cbLength)) ? cbLength : 0;
}
_Ret_range_(0, (cchMax > 0) ? cchMax - 1 : 0) inline size_t UntrustedStringLength(_In_ PCWSTR psz, _In_ size_t cchMax) {
    size_t cbLength;
    return SUCCEEDED(::StringCchLengthW(psz, cchMax, &cbLength)) ? cbLength : 0;
}

template <typename TString>
_Ret_range_(pStart, pEnd) inline unsigned char* GetResultString(_In_reads_to_ptr_opt_(pEnd) unsigned char* pStart,
                                                                _In_opt_ unsigned char* pEnd,
                                                                _Out_ TString* ppszBufferString) {
    size_t cchLen = UntrustedStringLength(reinterpret_cast<TString>(pStart), (pEnd - pStart) / sizeof((*ppszBufferString)[0]));
    *ppszBufferString = (cchLen > 0) ? reinterpret_cast<TString>(pStart) : nullptr;
    auto pReturn = min(pEnd, pStart + ((cchLen + 1) * sizeof((*ppszBufferString)[0])));
    __analysis_assume((pReturn >= pStart) && (pReturn <= pEnd));
    return pReturn;
}

// A small, no-dependency class meant to enable accessing lock-free thread local storage (roughly
// modeled after ppl::Combinable<>).  This is used to service thread-specific failure callbacks
// without requiring any locking when an error is fired.
// Note that *for now*, T must be POD and is ZERO'inited and will not have a constructor/destructor
// ran on it (easy to add, but code including this file does not enable/include placement new.

template <typename T, size_t threadCountEstimate = 20>
class ThreadStorage {
public:
    ThreadStorage() WI_NOEXCEPT {
        ::ZeroMemory(const_cast<Node**>(m_hashArray), sizeof(m_hashArray));
    }

    ~ThreadStorage() WI_NOEXCEPT {
        for (auto& entry : m_hashArray) {
            Node* pNode = entry;
            while (pNode != nullptr) {
                auto pCurrent = pNode;
                pNode = pNode->pNext;
                pCurrent->~Node();
                free(pCurrent);
            }
            entry = nullptr;
        }
    }

    // Note: Can return nullptr even when (shouldAllocate == true) upon allocation failure
    T* GetLocal(bool shouldAllocate = false) WI_NOEXCEPT {
        DWORD const threadId = ::GetCurrentThreadId();
        size_t const index = (threadId % ARRAYSIZE(m_hashArray));
        for (auto pNode = m_hashArray[index]; pNode != nullptr; pNode = pNode->pNext) {
            if (pNode->threadId == threadId) {
                return &pNode->value;
            }
        }
        if (shouldAllocate) {
            Node* pNew = reinterpret_cast<Node*>(malloc(sizeof(Node)));
            if (pNew != nullptr) {
                // placement new would be preferred, but components include this file that do not enable it
                pNew->Construct(threadId);
                Node* pFirst;
                do {
                    pFirst = m_hashArray[index];
                    pNew->pNext = pFirst;
                } while (::InterlockedCompareExchangePointer(reinterpret_cast<PVOID volatile*>(m_hashArray + index), pNew, pFirst) !=
                         pFirst);
                return &pNew->value;
            }
        }
        return nullptr;
    }

private:
    ThreadStorage(ThreadStorage const&);
    ThreadStorage& operator=(ThreadStorage const&);

    struct Node {
        T value;
        DWORD threadId;
        Node* pNext;

        void Construct(DWORD currentThreadId) {
            ::ZeroMemory(&value, sizeof(value));
            threadId = currentThreadId;
            pNext = nullptr;
        }
    };

    Node* volatile m_hashArray[threadCountEstimate];
};

struct IFailureCallback {
    virtual bool NotifyFailure(FailureInfo const& failure) WI_NOEXCEPT = 0;
};

class ThreadFailureCallbackHolder;
#ifndef RESULT_SUPPRESS_STATIC_INITIALIZERS
__declspec(selectany) ThreadStorage<ThreadFailureCallbackHolder*> g_threadFailureCallbacks;
__declspec(selectany) ThreadStorage<ThreadFailureCallbackHolder*>* g_pThreadFailureCallbacks = &g_threadFailureCallbacks;
#else
__declspec(selectany) ThreadStorage<ThreadFailureCallbackHolder*>* g_pThreadFailureCallbacks = nullptr;
#endif

class ThreadFailureCallbackHolder {
public:
    ThreadFailureCallbackHolder(_In_ IFailureCallback* pCallbackParam,
                                _In_opt_ CallContextInfo* pCallContext = nullptr,
                                bool watchNow = true) WI_NOEXCEPT : m_pCallback(pCallbackParam),
                                                                    m_ppThreadList(nullptr),
                                                                    m_pNext(nullptr),
                                                                    m_threadId(0),
                                                                    m_pCallContext(pCallContext) {
        if (watchNow) {
            StartWatching();
        }
    }

    ThreadFailureCallbackHolder(ThreadFailureCallbackHolder&& other) WI_NOEXCEPT : m_pCallback(other.m_pCallback),
                                                                                   m_ppThreadList(nullptr),
                                                                                   m_pNext(nullptr),
                                                                                   m_threadId(0),
                                                                                   m_pCallContext(other.m_pCallContext) {
        if (other.m_threadId != 0) {
            other.StopWatching();
            StartWatching();
        }
    }

    ~ThreadFailureCallbackHolder() WI_NOEXCEPT {
        if (m_threadId != 0) {
            StopWatching();
        }
    }

    void SetCallContext(_In_opt_ CallContextInfo* pCallContext) {
        m_pCallContext = pCallContext;
    }

    CallContextInfo* CallContextInfo() {
        return m_pCallContext;
    }

    void StartWatching() {
        // out-of balance Start/Stop calls?
        __FAIL_FAST_PRERELEASE_ASSERT__(m_threadId == 0);

        m_ppThreadList = (g_pThreadFailureCallbacks != nullptr) ? g_pThreadFailureCallbacks->GetLocal(true) :
                                                                  nullptr; // true = allocate thread list if missing
        if (m_ppThreadList) {
            m_pNext = *m_ppThreadList;
            *m_ppThreadList = this;
            m_threadId = ::GetCurrentThreadId();
        }
    }

    void StopWatching() {
        if (m_threadId != ::GetCurrentThreadId()) {
            // The thread-specific failure holder cannot be stopped on a different thread than it was started on or the
            // internal book-keeping list will be corrupted.  To fix this change the telemetry pattern in the calling code
            // to match one of the patterns available here:
            //    https://microsoft.sharepoint.com/teams/osg_development/Shared%20Documents/Windows%20TraceLogging%20Helpers.docx

            WI_USAGE_ERROR("MEMORY CORRUPTION: Calling code is leaking an activity thread-watcher and releasing it on another thread");
        }

        m_threadId = 0;

        while (*m_ppThreadList != nullptr) {
            if (*m_ppThreadList == this) {
                *m_ppThreadList = m_pNext;
                break;
            }
            m_ppThreadList = &((*m_ppThreadList)->m_pNext);
        }
        m_ppThreadList = nullptr;
    }

    bool IsWatching() {
        return (m_threadId != 0);
    }

    void SetWatching(bool shouldWatch) {
        if (shouldWatch && !IsWatching()) {
            StartWatching();
        } else if (!shouldWatch && IsWatching()) {
            StopWatching();
        }
    }

    static bool GetThreadContext(_Inout_ FailureInfo* pFailure,
                                 _In_opt_ ThreadFailureCallbackHolder* pCallback,
                                 _Out_writes_(callContextStringLength) _Post_z_ PSTR callContextString,
                                 _Pre_satisfies_(callContextStringLength > 0) size_t callContextStringLength) {
        *callContextString = '\0';
        bool foundContext = false;
        if (pCallback != nullptr) {
            foundContext = GetThreadContext(pFailure, pCallback->m_pNext, callContextString, callContextStringLength);

            if (pCallback->m_pCallContext != nullptr) {
                auto& context = *pCallback->m_pCallContext;

                // We generate the next telemetry ID only when we've found an error (avoid always incrementing)
                if (context.contextId == 0) {
                    context.contextId = ::InterlockedIncrementNoFence(&s_telemetryId);
                }

                if (pFailure->callContextOriginating.contextId == 0) {
                    pFailure->callContextOriginating = context;
                }

                pFailure->callContextCurrent = context;

                auto callContextStringEnd = callContextString + callContextStringLength;
                callContextString += strlen(callContextString);

                if ((callContextStringEnd - callContextString) > 2) // room for at least the slash + null
                {
                    *callContextString++ = '\\';
                    auto nameSizeBytes = strlen(context.contextName) + 1;
                    size_t remainingBytes = static_cast<size_t>(callContextStringEnd - callContextString);
                    auto copyBytes = (nameSizeBytes < remainingBytes) ? nameSizeBytes : remainingBytes;
                    memcpy(callContextString, context.contextName, copyBytes);
                    *(callContextString + (copyBytes - 1)) = '\0';
                }

                return true;
            }
        }
        return foundContext;
    }

    static void GetContextAndNotifyFailure(_Inout_ FailureInfo* pFailure,
                                           _Out_writes_(callContextStringLength) _Post_z_ PSTR callContextString,
                                           _Pre_satisfies_(callContextStringLength > 0) size_t callContextStringLength) WI_NOEXCEPT {
        *callContextString = '\0';
        bool reportedTelemetry = false;

        ThreadFailureCallbackHolder** ppListeners =
            (g_pThreadFailureCallbacks != nullptr) ? g_pThreadFailureCallbacks->GetLocal() : nullptr;
        if ((ppListeners != nullptr) && (*ppListeners != nullptr)) {
            callContextString[0] = '\0';
            if (GetThreadContext(pFailure, *ppListeners, callContextString, callContextStringLength)) {
                pFailure->pszCallContext = callContextString;
            }

            auto pNode = *ppListeners;
            do {
                reportedTelemetry |= pNode->m_pCallback->NotifyFailure(*pFailure);
                pNode = pNode->m_pNext;
            } while (pNode != nullptr);
        }

        if (g_pfnTelemetryCallback != nullptr) {
            g_pfnTelemetryCallback(reportedTelemetry, *pFailure);
        }
    }

    ThreadFailureCallbackHolder(ThreadFailureCallbackHolder const&) = delete;
    ThreadFailureCallbackHolder& operator=(ThreadFailureCallbackHolder const&) = delete;

private:
    static long volatile s_telemetryId;

    IFailureCallback* m_pCallback;
    ThreadFailureCallbackHolder** m_ppThreadList;
    ThreadFailureCallbackHolder* m_pNext;
    DWORD m_threadId;
    wil::CallContextInfo* m_pCallContext;
};

__declspec(selectany) long volatile ThreadFailureCallbackHolder::s_telemetryId = 1;

// returns true if telemetry was reported for this error
inline void GetContextAndNotifyFailure(_Inout_ FailureInfo* pFailure,
                                       _Out_writes_(callContextStringLength) _Post_z_ PSTR callContextString,
                                       _Pre_satisfies_(callContextStringLength > 0) size_t callContextStringLength) WI_NOEXCEPT {
    ThreadFailureCallbackHolder::GetContextAndNotifyFailure(pFailure, callContextString, callContextStringLength);
}

template <typename TLambda>
class ThreadFailureCallbackFn final : public IFailureCallback {
public:
    explicit ThreadFailureCallbackFn(_In_ CallContextInfo* pContext, _Inout_ TLambda&& errorFunction) WI_NOEXCEPT
        : m_errorFunction(wistd::move(errorFunction)),
          m_callbackHolder(this, pContext) {
    }

    ThreadFailureCallbackFn(_Inout_ ThreadFailureCallbackFn&& other) WI_NOEXCEPT
        : m_errorFunction(wistd::move(other.m_errorFunction)),
          m_callbackHolder(this, other.m_callbackHolder.CallContextInfo()) {
    }

    bool NotifyFailure(FailureInfo const& failure) WI_NOEXCEPT {
        return m_errorFunction(failure);
    }

private:
    ThreadFailureCallbackFn(_In_ ThreadFailureCallbackFn const&);
    ThreadFailureCallbackFn& operator=(_In_ ThreadFailureCallbackFn const&);

    TLambda m_errorFunction;
    ThreadFailureCallbackHolder m_callbackHolder;
};

template <typename TLambda>
class ScopeExitFn {
public:
    explicit ScopeExitFn(_Inout_ TLambda&& fnAtExit) WI_NOEXCEPT : m_fnAtExit(wistd::move(fnAtExit)), m_fRun(true) {
        static_assert(!wistd::is_lvalue_reference<TLambda>::value && !wistd::is_rvalue_reference<TLambda>::value,
                      "ScopeExit should only be directly used with R-Value lambdas");
    }

    ScopeExitFn(_Inout_ ScopeExitFn&& other) WI_NOEXCEPT : m_fnAtExit(wistd::move(other.m_fnAtExit)), m_fRun(other.m_fRun) {
        other.m_fRun = false;
    }

    ~ScopeExitFn() WI_NOEXCEPT {
        operator()();
    }

    void operator()() WI_NOEXCEPT {
        if (m_fRun) {
            m_fRun = false;
            m_fnAtExit();
        }
    }

    void Dismiss() WI_NOEXCEPT {
        m_fRun = false;
    }

private:
    ScopeExitFn(_In_ ScopeExitFn const&);
    ScopeExitFn& operator=(_In_ ScopeExitFn const&);

    TLambda m_fnAtExit;
    bool m_fRun;
};

#ifdef WIL_ENABLE_EXCEPTIONS
enum class GuardState { Done = 0, NeedsRunIgnore = 1, NeedsRunLog = 2, NeedsRunFailFast = 3 };

template <typename TLambda>
class ScopeExitFnGuard {
public:
    explicit ScopeExitFnGuard(GuardState state, _Inout_ TLambda&& fnAtExit) WI_NOEXCEPT : m_fnAtExit(wistd::move(fnAtExit)),
                                                                                          m_state(state) {
        static_assert(!wistd::is_lvalue_reference<TLambda>::value && !wistd::is_rvalue_reference<TLambda>::value,
                      "ScopeExit should only be directly used with R-Value lambdas");
    }

    ScopeExitFnGuard(ScopeExitFnGuard&& other) WI_NOEXCEPT : m_fnAtExit(wistd::move(other.m_fnAtExit)), m_state(other.m_state) {
        other.m_state = GuardState::Done;
    }

    ~ScopeExitFnGuard() WI_NOEXCEPT {
        operator()();
    }

    void operator()() WI_NOEXCEPT {
        if (m_state != GuardState::Done) {
            auto state = m_state;
            m_state = GuardState::Done;
            try {
                m_fnAtExit();
            } catch (...) {
                if (state == GuardState::NeedsRunFailFast) {
                    FAIL_FAST_HR(wil::ResultFromCaughtException());
                } else if (state == GuardState::NeedsRunLog) {
                    LOG_HR(wil::ResultFromCaughtException());
                }
                // GuardState::NeedsRunIgnore explicitly ignored
            }
        }
    }

    void Dismiss() WI_NOEXCEPT {
        m_state = GuardState::Done;
    }

private:
    ScopeExitFnGuard(ScopeExitFnGuard const&);
    ScopeExitFnGuard& operator=(ScopeExitFnGuard const&);

    TLambda m_fnAtExit;
    GuardState m_state;
};
#endif // WIL_ENABLE_EXCEPTIONS
} // details namespace
//! @endcond

//*****************************************************************************
// Public Error Handling Helpers
//*****************************************************************************

// [optionally] Plug in fallback telemetry reporting
// Normally, the callback is owned by including ResultLogging.h in the including module.  Alternatively a module
// could re-route fallback telemetry to any ONE specific provider by calling this method.

inline void SetResultTelemetryFallback(_In_opt_ decltype(details::g_pfnTelemetryCallback) callbackFunction) {
    // Only ONE telemetry provider can own the fallback telemetry callback.
    __FAIL_FAST_PRERELEASE_ASSERT__((details::g_pfnTelemetryCallback == nullptr) || (callbackFunction == nullptr));
    details::g_pfnTelemetryCallback = callbackFunction;
}

// [optionally] Plug in result logging (do not use for telemetry)
// This provides the ability for a module to hook all failures flowing through the system for inspection
// and/or logging.

inline void SetResultLoggingCallback(_In_opt_ decltype(details::g_pfnLoggingCallback) callbackFunction) {
    // Only ONE function can own the result logging callback
    __FAIL_FAST_PRERELEASE_ASSERT__((details::g_pfnLoggingCallback == nullptr) || (details::g_pfnLoggingCallback == callbackFunction) ||
                                    (callbackFunction == nullptr));
    details::g_pfnLoggingCallback = callbackFunction;
}

// [optionally] Plug in custom result messages
// There are some purposes that require translating the full information that is known about a failure
// into a message to be logged (either through the console for debugging OR as the message attached
// to a Platform::Exception^).  This callback allows a module to format the string itself away from the
// default.

inline void SetResultMessageCallback(_In_opt_ decltype(wil::g_pfnResultLoggingCallback) callbackFunction) {
    // Only ONE function can own the result message callback
    __FAIL_FAST_PRERELEASE_ASSERT__((g_pfnResultLoggingCallback == nullptr) || (callbackFunction == nullptr));
    details::g_resultMessageCallbackSet = true;
    g_pfnResultLoggingCallback = callbackFunction;
}

// [optionally] Plug in exception remapping
// A module can plug a callback in using this function to setup custom exception handling to allow any
// exception type to be converted into an HRESULT from exception barriers.

inline void SetResultFromCaughtExceptionCallback(_In_opt_ decltype(wil::g_pfnResultFromCaughtException) callbackFunction) {
    // Only ONE function can own the exception conversion
    __FAIL_FAST_PRERELEASE_ASSERT__((g_pfnResultFromCaughtException == nullptr) || (callbackFunction == nullptr));
    g_pfnResultFromCaughtException = callbackFunction;
}

// A RAII wrapper around the storage of a FailureInfo struct (which is normally meant to be consumed
// on the stack or from the caller).  The storage of FailureInfo needs to copy some data internally
// for lifetime purposes.

class StoredFailureInfo {
public:
    StoredFailureInfo() WI_NOEXCEPT {
        ::ZeroMemory(&m_failureInfo, sizeof(m_failureInfo));
    }

    StoredFailureInfo(FailureInfo const& other) WI_NOEXCEPT {
        SetFailureInfo(other);
    }

    FailureInfo const& GetFailureInfo() const WI_NOEXCEPT {
        return m_failureInfo;
    }

    void SetFailureInfo(FailureInfo const& failure) WI_NOEXCEPT {
        m_failureInfo = failure;

        size_t const cbNeed = details::ResultStringSize(failure.pszMessage) + details::ResultStringSize(failure.pszCode) +
                              details::ResultStringSize(failure.pszFunction) + details::ResultStringSize(failure.pszFile) +
                              details::ResultStringSize(failure.pszCallContext) + details::ResultStringSize(failure.pszModule) +
                              details::ResultStringSize(failure.callContextCurrent.contextName) +
                              details::ResultStringSize(failure.callContextCurrent.contextMessage) +
                              details::ResultStringSize(failure.callContextOriginating.contextName) +
                              details::ResultStringSize(failure.callContextOriginating.contextMessage);

        if (!m_spStrings.unique() || (m_spStrings.size() < cbNeed)) {
            m_spStrings.reset();
            m_spStrings.create(cbNeed);
        }

        size_t cbAlloc;
        unsigned char* pBuffer = static_cast<unsigned char*>(m_spStrings.get(&cbAlloc));
        unsigned char* pBufferEnd = (pBuffer != nullptr) ? pBuffer + cbAlloc : nullptr;

        pBuffer = details::WriteResultString(pBuffer, pBufferEnd, failure.pszMessage, &m_failureInfo.pszMessage);
        pBuffer = details::WriteResultString(pBuffer, pBufferEnd, failure.pszCode, &m_failureInfo.pszCode);
        pBuffer = details::WriteResultString(pBuffer, pBufferEnd, failure.pszFunction, &m_failureInfo.pszFunction);
        pBuffer = details::WriteResultString(pBuffer, pBufferEnd, failure.pszFile, &m_failureInfo.pszFile);
        pBuffer = details::WriteResultString(pBuffer, pBufferEnd, failure.pszCallContext, &m_failureInfo.pszCallContext);
        pBuffer = details::WriteResultString(pBuffer, pBufferEnd, failure.pszModule, &m_failureInfo.pszModule);
        pBuffer = details::WriteResultString(pBuffer,
                                             pBufferEnd,
                                             failure.callContextCurrent.contextName,
                                             &m_failureInfo.callContextCurrent.contextName);
        pBuffer = details::WriteResultString(pBuffer,
                                             pBufferEnd,
                                             failure.callContextCurrent.contextMessage,
                                             &m_failureInfo.callContextCurrent.contextMessage);
        pBuffer = details::WriteResultString(pBuffer,
                                             pBufferEnd,
                                             failure.callContextOriginating.contextName,
                                             &m_failureInfo.callContextOriginating.contextName);
        details::WriteResultString(pBuffer,
                                   pBufferEnd,
                                   failure.callContextOriginating.contextMessage,
                                   &m_failureInfo.callContextOriginating.contextMessage);
    }

    // Relies upon generated copy constructor and assignment operator

protected:
    FailureInfo m_failureInfo;
    details::shared_buffer m_spStrings;
};

// This is the default class thrown from all THROW_XXX macros.  It stores all of the FailureInfo context that
// is available when the exception is thrown.  It's also caught by exception guards for conversion to HRESULT.

class ResultException {
public:
    ResultException(FailureInfo const& failure) WI_NOEXCEPT : m_failure(failure) {
    }

    // This constructor should be used only for custom exception types
    ResultException(_Pre_satisfies_(hr < 0) HRESULT hr) WI_NOEXCEPT : m_failure(CustomExceptionFailureInfo(hr)) {
    }

    _Always_(_Post_satisfies_(return < 0)) HRESULT GetErrorCode() const WI_NOEXCEPT {
        HRESULT const hr = m_failure.GetFailureInfo().hr;
        __analysis_assume(hr < 0);
        return hr;
    }

    FailureInfo const& GetFailureInfo() const WI_NOEXCEPT {
        return m_failure.GetFailureInfo();
    }

    void SetFailureInfo(FailureInfo const& failure) WI_NOEXCEPT {
        m_failure.SetFailureInfo(failure);
    }

    // Relies upon auto-generated copy constructor and assignment operator
protected:
    StoredFailureInfo m_failure;

    static FailureInfo CustomExceptionFailureInfo(HRESULT hr) WI_NOEXCEPT {
        FailureInfo fi = {};
        fi.type = FailureType::Exception;
        fi.hr = hr;
        return fi;
    }
};

// This helper functions much like ScopeExit -- give it a lambda and get back a local object that can be used to
// catch all errors happening in your module through all WIL error handling mechanisms.  The lambda will be called
// once for each error throw, error return, or error catch that is handled while the returned object is still in
// scope.  Usage:
//
// auto monitor = wil::ThreadFailureCallback([](wil::FailureInfo const &failure)
// {
//     // Write your code that logs or cares about failure details here...
//     // It has access to HRESULT, filename, line number, etc through the failure param.
// });
//
// As long as the returned 'monitor' object remains in scope, the lambda will continue to receive callbacks for any
// failures that occur in this module on the calling thread.  Note that this will guarantee that the lambda will run
// for any failure that is through any of the WIL macros (THROW_XXX, RETURN_XXX, LOG_XXX, etc).

template <typename TLambda>
inline wil::details::ThreadFailureCallbackFn<TLambda> ThreadFailureCallback(_Inout_ TLambda&& fnAtExit) WI_NOEXCEPT {
    return wil::details::ThreadFailureCallbackFn<TLambda>(nullptr, wistd::forward<TLambda>(fnAtExit));
}

// Much like ThreadFailureCallback, this class will receive WIL failure notifications from the time it's instantiated
// until the time that it's destroyed.  At any point during that time you can ask for the last failure that was seen
// by any of the WIL macros (RETURN_XXX, THROW_XXX, LOG_XXX, etc) on the current thread.
//
// This class is most useful when utilized as a member of an RAII class that's dedicated to providing logging or
// telemetry.  In the destructor of that class, if the operation had not been completed successfully (it goes out of
// scope due to early return or exception unwind before success is acknowledged) then details about the last failure
// can be retrieved and appropriately logged.
//
// Usage:
//
// class MyLogger
// {
// public:
//     MyLogger() : m_fComplete(false) {}
//     ~MyLogger()
//     {
//         if (!m_fComplete)
//         {
//             FailureInfo *pFailure = m_cache.GetFailure();
//             if (pFailure != nullptr)
//             {
//                 // Log information about pFailure (pFileure->hr, pFailure->pszFile, pFailure->uLineNumber, etc)
//             }
//             else
//             {
//                 // It's possible that you get stack unwind from an exception that did NOT come through WIL
//                 // like (std::bad_alloc from the STL).  Use a reasonable default like:  HRESULT_FROM_WIN32(ERROR_UNHANDLED_EXCEPTION).
//             }
//         }
//     }
//     void Complete() { m_fComplete = true; }
// private:
//     bool m_fComplete;
//     ThreadFailureCache m_cache;
// };

class ThreadFailureCache final : public details::IFailureCallback {
public:
    ThreadFailureCache() : m_callbackHolder(this) {
    }

    ThreadFailureCache(ThreadFailureCache&& rhs) : m_failure(wistd::move(rhs.m_failure)), m_callbackHolder(this) {
    }

    ThreadFailureCache& operator=(ThreadFailureCache&& rhs) {
        m_failure = wistd::move(rhs.m_failure);
        return *this;
    }

    void WatchCurrentThread() {
        m_callbackHolder.StartWatching();
    }

    void IgnoreCurrentThread() {
        m_callbackHolder.StopWatching();
    }

    FailureInfo const* GetFailure() {
        return (FAILED(m_failure.GetFailureInfo().hr) ? &(m_failure.GetFailureInfo()) : nullptr);
    }

    bool NotifyFailure(FailureInfo const& failure) WI_NOEXCEPT {
        // When we "cache" a failure, we bias towards trying to find the origin of the last HRESULT
        // generated, so we ignore subsequent failures on the same error code (assuming propagation).

        if (failure.hr != m_failure.GetFailureInfo().hr) {
            m_failure.SetFailureInfo(failure);
        }
        return false;
    }

private:
    StoredFailureInfo m_failure;
    details::ThreadFailureCallbackHolder m_callbackHolder;
};

// The ScopeExit function accepts a lambda and returns an object meant to be captured in
// an auto variable.  That lambda will be run when the object goes out of scope.  For most
// begin/end pairings RAII techniques should be used instead, but occasionally there are
// uncommon cases where RAII techniques are impractical (ensuring a file is deleted after
// a test routine, etc).  Usage involves:
//
//      FunctionNeedingCleanup();       // start with a call to establish some state that requires cleanup
//      auto fnCleanup = ScopeExit([&]
//      {
//          // write cleanup code here
//      });
//
// When fnCleanup goes out of scope it will run its lambda.  Optionally, if the cleanup is
// no long needed, it can be dismissed (so that it is not run):
//
//      fnCleanup.Dismiss();
//
// If the cleanup is needed ahead of going out of scope it can be explicitly run:
//
//      fnCleanup();

template <typename TLambda>
inline wil::details::ScopeExitFn<TLambda> ScopeExit(_Inout_ TLambda&& fnAtExit) WI_NOEXCEPT {
    return wil::details::ScopeExitFn<TLambda>(wistd::forward<TLambda>(fnAtExit));
}

//*****************************************************************************
// Public Helpers that catch -- only enabled when exceptions are enabled
//*****************************************************************************

#ifdef WIL_ENABLE_EXCEPTIONS
// The ScopeExitXXX functions work identically to ScopeExit but add an exception guard for the lambda.  The different
// variants control what happens if an exception were actually thrown from the cleanup lambda.

// The ScopeExitNoExcept version should eventually be removed in favor of the simpler ScopeExit() once noexcept is
// fully implemented to provide fail fast handling of exceptions from the regular scope exit class.
template <typename TLambda>
inline wil::details::ScopeExitFnGuard<TLambda> ScopeExitNoExcept(TLambda&& fnAtExit) WI_NOEXCEPT {
    return wil::details::ScopeExitFnGuard<TLambda>(wil::details::GuardState::NeedsRunFailFast, wistd::forward<TLambda>(fnAtExit));
}

template <typename TLambda>
inline wil::details::ScopeExitFnGuard<TLambda> ScopeExitLog(TLambda&& fnAtExit) WI_NOEXCEPT {
    return wil::details::ScopeExitFnGuard<TLambda>(wil::details::GuardState::NeedsRunLog, wistd::forward<TLambda>(fnAtExit));
}

template <typename TLambda>
inline wil::details::ScopeExitFnGuard<TLambda> ScopeExitIgnore(TLambda&& fnAtExit) WI_NOEXCEPT {
    return wil::details::ScopeExitFnGuard<TLambda>(wil::details::GuardState::NeedsRunIgnore, wistd::forward<TLambda>(fnAtExit));
}

// ResultFromCaughtException is a function that is meant to be called from within a catch(...) block.  Internally
// it re-throws and catches the exception to convert it to an HRESULT.  If an exception is of an unrecognized type
// the function will fail fast.
//
// try
// {
//     // Code
// }
// catch (...)
// {
//     hr = wil::ResultFromCaughtException();
// }

_Always_(_Post_satisfies_(return < 0)) __declspec(noinline) inline HRESULT ResultFromCaughtException() WI_NOEXCEPT {
    HRESULT hr;
    if (g_resultFromUncaughtExceptionObjC && g_resultFromUncaughtExceptionObjC(&hr)) {
        return hr;
    }

    try {
        throw;
    } catch (const ResultException& re) {
        return re.GetErrorCode();
    } catch (std::bad_alloc) {
        return E_OUTOFMEMORY;
    } catch (...) {
        return details::ResultFromUnknownCaughtException();
    }
}

// ResultFromException serves as an exception guard.  Much like try/catch(...), this function accepts a lambda
// where all exceptions generated within will be caught and converted to their corresponding HRESULT.  If an
// exception is of an unrecognized type, then the guard will fail fast.
//
// HRESULT ErrorCodeReturningFunction()
// {
//     RETURN_HR(wil::ResultFromException([&])()
//     {
//         // Use of libraries or function calls that may throw
//         // exceptions...
//     }));
// }

template <typename Functor>
inline HRESULT ResultFromException(_Inout_ Functor&& functor) WI_NOEXCEPT {
    try {
        functor();
    } catch (...) {
        return ResultFromCaughtException();
    }
    return S_OK;
}

// NormalizeIfExceptionThrown serves as an exception guard built to normalize on one exception type.  This allows
// a C++/CX void returning function to normalize all exceptions thrown within to Platform::Exception^, even if
// STL is used within (std::bad_alloc) or a custom ResultException has been thrown within.  Thus when that C++/CX
// method is invoked by COM with a cross-apartment call, those exceptions will be caught and mapped correctly to
// an HRESULT.  From within straight C++, this normalization works identically, only remapping all known exception
// types to ResultException, rather than Platform::Exception^
//
// void MyFunction()
// {
//     wil::NormalizeIfExceptionThrown([&])()
//     {
//         // Use of libraries or function calls that may throw diverse
//         // exception types...
//     }));
// }

template <typename Functor>
inline void NormalizeIfExceptionThrown(_Inout_ Functor&& functor) {
    try {
        functor();
    } catch (...) {
        wil::details::RethrowNormalizedCaughtException(__R_INFO_ONLY(nullptr));
    }
}
#endif // WIL_ENABLE_EXCEPTIONS

//! @cond
namespace details {
//*****************************************************************************
// Private helpers to catch and propagate exceptions
//*****************************************************************************

#ifdef WIL_ENABLE_EXCEPTIONS
_declspec(noreturn) inline void RethrowUnknownCaughtException(__R_FN_PARAMS_FULL, _In_opt_ PCWSTR message) {
    if (g_pfnResultFromCaughtException != nullptr) {
        const HRESULT hr = g_pfnResultFromCaughtException();
        if (FAILED(hr)) {
            ReportFailure(__R_FN_CALL_FULL, FailureType::Exception, hr, message);
        }
    }

#ifdef RESULT_PRERELEASE
    if (g_fResultFailFastUnknownExceptions) {
        // Caller bug: an unknown exception was thrown
        ReportFailure(__R_FN_CALL_FULL, FailureType::FailFast, HRESULT_FROM_WIN32(ERROR_UNHANDLED_EXCEPTION), message);
    }
#endif
    ReportFailure(__R_FN_CALL_FULL, FailureType::Exception, HRESULT_FROM_WIN32(ERROR_UNHANDLED_EXCEPTION), message);
}

__declspec(noreturn) inline void RethrowNormalizedCaughtException_Helper(__R_FN_PARAMS_FULL, _In_opt_ PCWSTR message = nullptr) {
    if (g_rethrowNormalizedCaughtExceptionObjC) {
        g_rethrowNormalizedCaughtExceptionObjC(__R_FN_CALL_FULL, message);
    }

    try {
        throw;
    } catch (const ResultException& re) {
        ReportFailure(__R_FN_CALL_FULL, FailureType::Exception, re.GetErrorCode(), message, ReportFailureOptions::SuppressAction);

        // Outside of C++/CX, ResultException is our normalized exception.  Because it's our class
        // we can be confident that it has already been logged -- just re-throw it.
        throw;
    } catch (std::bad_alloc) {
        ReportFailure(__R_FN_CALL_FULL, FailureType::Exception, E_OUTOFMEMORY, message);
    } catch (...) {
        RethrowUnknownCaughtException(__R_FN_CALL_FULL, message);
    }
}

__declspec(noinline, noreturn) inline void RethrowNormalizedCaughtException(__R_FN_PARAMS_ONLY) {
    __R_FN_LOCALS;
    RethrowNormalizedCaughtException_Helper(__R_FN_CALL_FULL_RA);
}

__declspec(noinline, noreturn) inline void RethrowNormalizedCaughtExceptionMsg(__R_FN_PARAMS _In_ _Printf_format_string_ PCSTR formatString,
                                                                               ...) {
    va_list argList;
    va_start(argList, formatString);
    wchar_t message[2048];
    PrintLoggingMessage(message, ARRAYSIZE(message), formatString, argList);

    __R_FN_LOCALS;
    RethrowNormalizedCaughtException_Helper(__R_FN_CALL_FULL_RA, message);
}

_Always_(_Post_satisfies_(return < 0)) inline HRESULT ResultFromUnknownCaughtException() {
    if (g_pfnResultFromCaughtException != nullptr) {
        HRESULT hr = g_pfnResultFromCaughtException();
        if (FAILED(hr)) {
            return hr;
        }
    }

    // Caller bug: an unknown exception was thrown
    FAIL_FAST_HR_IF(HRESULT_FROM_WIN32(ERROR_UNHANDLED_EXCEPTION), g_fResultFailFastUnknownExceptions);

    return HRESULT_FROM_WIN32(ERROR_UNHANDLED_EXCEPTION);
}
#endif // WIL_ENABLE_EXCEPTIONS

//*****************************************************************************
// Shared Reporting -- all reporting macros bubble up through this codepath
//*****************************************************************************

inline void LogFailure(__R_FN_PARAMS_FULL,
                       FailureType type,
                       HRESULT hr,
                       _In_opt_ PCWSTR message,
                       bool fWantDebugString,
                       _Out_writes_(debugStringSizeChars) _Post_z_ PWSTR debugString,
                       _Pre_satisfies_(debugStringSizeChars > 0) size_t debugStringSizeChars,
                       _Out_writes_(callContextStringSizeChars) _Post_z_ PSTR callContextString,
                       _Pre_satisfies_(callContextStringSizeChars > 0) size_t callContextStringSizeChars,
                       _Out_ FailureInfo* failure) WI_NOEXCEPT {
    debugString[0] = L'\0';
    callContextString[0] = L'\0';

    static long volatile s_failureId = 0;

    int failureCount = 0;
    switch (type) {
        case FailureType::Exception:
        case FailureType::ObjCException:
            failureCount = RecordException(hr);
            break;
        case FailureType::Return:
            failureCount = RecordReturn(hr);
            break;
        case FailureType::ReturnPreRelease:
            failureCount = RecordReturnPreRelease(hr);
            break;
        case FailureType::Log:
            if (SUCCEEDED(hr)) {
                // If you hit this assert (or are reviewing this failure telemetry), then most likely you are trying to log success
                // using one of the WIL macros.  Example:
                //      LOG_HR(S_OK);
                // Instead, use one of the forms that conditionally logs based upon the error condition:
                //      LOG_IF_FAILED(hr);

                WI_USAGE_ERROR_FORWARD("CALLER BUG: Macro usage error detected.  Do not LOG_XXX success.");
                hr = HRESULT_FROM_WIN32(ERROR_ASSERTION_FAILURE);
            }
            failureCount = RecordLog(hr);
            break;
        case FailureType::FailFast:
            failureCount = RecordFailFast(hr);
            break;
    };

    failure->type = type;
    failure->hr = hr;
    failure->failureId = ::InterlockedIncrementNoFence(&s_failureId);
    failure->pszMessage = ((message != nullptr) && (message[0] != L'\0')) ? message : nullptr;
    failure->threadId = ::GetCurrentThreadId();
    failure->pszFile = fileName;
    failure->uLineNumber = lineNumber;
    failure->cFailureCount = failureCount;
    failure->pszCode = code;
    failure->pszFunction = functionName;
    failure->returnAddress = returnAddress;
    failure->callerReturnAddress = callerReturnAddress;
    failure->pszCallContext = nullptr;
    ClearContext(&failure->callContextCurrent);
    ClearContext(&failure->callContextOriginating);
    failure->pszModule = (g_pfnGetModuleName != nullptr) ? g_pfnGetModuleName() : nullptr;

    // Completes filling out failure, notifies thread-based callbacks and the telemetry callback
    GetContextAndNotifyFailure(failure, callContextString, callContextStringSizeChars);

    // Allow a hook to inspect the failure before acting upon it
    if (details::g_pfnLoggingCallback != nullptr) {
        details::g_pfnLoggingCallback(*failure);
    }

    // Caller bug: Leaking a success code into a failure-only function
    FAIL_FAST_IF(SUCCEEDED(failure->hr) && (type != FailureType::FailFast));

    // We need to generate the logging message if:
    // * The caller asked us to (generally for attaching to a C++/CX exception)
    if (fWantDebugString) {
        // Call the logging callback (if present) to allow them to generate the debug string that will be pushed to the console
        // or the platform exception object if the caller desires it.
        if (g_pfnResultLoggingCallback != nullptr) {
            g_pfnResultLoggingCallback(failure, debugString, debugStringSizeChars);
        }

        // The callback only optionally needs to supply the debug string -- if the callback didn't populate it, yet we still want
        // it for OutputDebugString or exception message, then generate the default string.
        if (debugString[0] == L'\0') {
            GetFailureLogString(debugString, debugStringSizeChars, *failure);
        }
    } else {
        // [deprecated behavior]
        // This callback was at one point *always* called for all failures, so we continue to call it for failures even when we don't
        // need to generate the debug string information (when the callback was supplied directly).  We can avoid this if the caller
        // used the explicit function (through g_resultMessageCallbackSet)
        if ((g_pfnResultLoggingCallback != nullptr) && !g_resultMessageCallbackSet) {
            g_pfnResultLoggingCallback(failure, nullptr, 0);
        }
    }
}

inline __declspec(noinline) void ReportFailure(
    __R_FN_PARAMS_FULL, FailureType type, HRESULT hr, _In_opt_ PCWSTR message, ReportFailureOptions options) {
    FailureInfo failure;
    wchar_t debugString[2048];
    char callContextString[1024];

    const bool forceObjCException = WI_IS_FLAG_SET(options, ReportFailureOptions::ForceObjCException);
    LogFailure(__R_FN_CALL_FULL,
               type,
               hr,
               message,
               forceObjCException, // Performs extra logging if we're forcing a conversion to ObjCException
               debugString,
               ARRAYSIZE(debugString),
               callContextString,
               ARRAYSIZE(callContextString),
               &failure);

    if (WI_IS_FLAG_CLEAR(options, ReportFailureOptions::SuppressAction)) {
        if (type == FailureType::FailFast) {
            // This is an explicit fail fast - examine the callstack to determine the precise reason for this failure
            RESULT_RAISE_FAST_FAIL_EXCEPTION;
        } else if (type == FailureType::ObjCException || forceObjCException) {
            if (!g_objcThrowFailureInfo) {
                LogFailure(__R_FN_CALL_FULL,
                           type,
                           E_UNEXPECTED,
                           L"Throwing an Objective C exception requires having Objective C code",
                           false,
                           debugString,
                           ARRAYSIZE(debugString),
                           callContextString,
                           ARRAYSIZE(callContextString),
                           &failure);
                RESULT_RAISE_FAST_FAIL_EXCEPTION;
            }

            g_objcThrowFailureInfo(failure);
        } else if (type == FailureType::Exception) {
            throw ResultException(failure);
        }
    }
}

inline void ReportFailure_Msg(
    __R_FN_PARAMS_FULL, FailureType type, HRESULT hr, _Printf_format_string_ PCSTR formatString, va_list argList) {
    wchar_t message[2048];
    PrintLoggingMessage(message, ARRAYSIZE(message), formatString, argList);
    ReportFailure(__R_FN_CALL_FULL, type, hr, message);
}

__declspec(noinline) inline void ReportFailure_ReplaceMsg(__R_FN_PARAMS_FULL, FailureType type, HRESULT hr, _Printf_format_string_ PCSTR formatString, ...) {
    va_list argList;
    va_start(argList, formatString);
    ReportFailure_Msg(__R_FN_CALL_FULL, type, hr, formatString, argList);
}

__declspec(noinline) inline void ReportFailure_Hr(__R_FN_PARAMS_FULL, FailureType type, HRESULT hr) {
    ReportFailure(__R_FN_CALL_FULL, type, hr);
}

__declspec(noinline) inline HRESULT ReportFailure_Win32(__R_FN_PARAMS_FULL, FailureType type, DWORD err) {
    auto hr = HRESULT_FROM_WIN32(err);
    ReportFailure(__R_FN_CALL_FULL, type, hr);
    return hr;
}

__declspec(noinline) inline DWORD ReportFailure_GetLastError(__R_FN_PARAMS_FULL, FailureType type) {
    auto err = GetLastErrorFail(__R_FN_CALL_FULL);
    ReportFailure(__R_FN_CALL_FULL, type, HRESULT_FROM_WIN32(err));
    return err;
}

__declspec(noinline) inline HRESULT ReportFailure_GetLastErrorHr(__R_FN_PARAMS_FULL, FailureType type) {
    auto hr = GetLastErrorFailHr(__R_FN_CALL_FULL);
    ReportFailure(__R_FN_CALL_FULL, type, hr);
    return hr;
}

__declspec(noinline) inline HRESULT ReportFailure_NtStatus(__R_FN_PARAMS_FULL, FailureType type, NTSTATUS status) {
    auto hr = wil::details::NtStatusToHr(status);
    ReportFailure(__R_FN_CALL_FULL, type, hr);
    return hr;
}

__declspec(noinline) inline void ReportFailure_HrMsg(
    __R_FN_PARAMS_FULL, FailureType type, HRESULT hr, _Printf_format_string_ PCSTR formatString, va_list argList) {
    ReportFailure_Msg(__R_FN_CALL_FULL, type, hr, formatString, argList);
}

__declspec(noinline) inline HRESULT
    ReportFailure_Win32Msg(__R_FN_PARAMS_FULL, FailureType type, DWORD err, _Printf_format_string_ PCSTR formatString, va_list argList) {
    auto hr = HRESULT_FROM_WIN32(err);
    ReportFailure_Msg(__R_FN_CALL_FULL, type, HRESULT_FROM_WIN32(err), formatString, argList);
    return hr;
}

__declspec(noinline) inline DWORD
    ReportFailure_GetLastErrorMsg(__R_FN_PARAMS_FULL, FailureType type, _Printf_format_string_ PCSTR formatString, va_list argList) {
    auto err = GetLastErrorFail(__R_FN_CALL_FULL);
    ReportFailure_Msg(__R_FN_CALL_FULL, type, HRESULT_FROM_WIN32(err), formatString, argList);
    return err;
}

__declspec(noinline) inline HRESULT
    ReportFailure_GetLastErrorHrMsg(__R_FN_PARAMS_FULL, FailureType type, _Printf_format_string_ PCSTR formatString, va_list argList) {
    auto hr = GetLastErrorFailHr(__R_FN_CALL_FULL);
    ReportFailure_Msg(__R_FN_CALL_FULL, type, hr, formatString, argList);
    return hr;
}

__declspec(noinline) inline HRESULT ReportFailure_NtStatusMsg(
    __R_FN_PARAMS_FULL, FailureType type, NTSTATUS status, _Printf_format_string_ PCSTR formatString, va_list argList) {
    auto hr = wil::details::NtStatusToHr(status);
    ReportFailure_Msg(__R_FN_CALL_FULL, type, hr, formatString, argList);
    return hr;
}

//*****************************************************************************
// Support for throwing custom exception types
//*****************************************************************************

inline HRESULT GetErrorCode(_In_ ResultException& exception) WI_NOEXCEPT {
    return exception.GetErrorCode();
}

inline void SetFailureInfo(_In_ FailureInfo const& failure, _Inout_ ResultException& exception) WI_NOEXCEPT {
    return exception.SetFailureInfo(failure);
}

#ifdef __cplusplus_winrt
inline HRESULT GetErrorCode(_In_ Platform::Exception ^ exception) WI_NOEXCEPT {
    return exception->HResult;
}

inline void SetFailureInfo(_In_ FailureInfo const&, _Inout_ Platform::Exception ^ exception) WI_NOEXCEPT {
    // no-op -- once a PlatformException^ is created, we can't modify the message, but this function must
    // exist to distinguish this from ResultException
}
#endif

template <typename T>
__declspec(noreturn) inline void ReportFailure_CustomExceptionHelper(_Inout_ T& exception,
                                                                     __R_FN_PARAMS_FULL,
                                                                     _In_opt_ PCWSTR message = nullptr) {
    // When seeing the error: "cannot convert parameter 1 from 'XXX' to 'wil::ResultException &'"
    // Custom exceptions must be based upon either ResultException or Platform::Exception^ to be used with ResultException.h.
    // This compilation error indicates an attempt to throw an incompatible exception type.
    const HRESULT hr = GetErrorCode(exception);

    FailureInfo failure;
    wchar_t debugString[2048];
    char callContextString[1024];

    LogFailure(__R_FN_CALL_FULL,
               FailureType::Exception,
               hr,
               message,
               false, // false = does not need debug string
               debugString,
               ARRAYSIZE(debugString),
               callContextString,
               ARRAYSIZE(callContextString),
               &failure);

    // push the failure info context into the custom exception class
    SetFailureInfo(failure, exception);

    throw exception;
}

template <typename T>
__declspec(noreturn, noinline) inline void ReportFailure_CustomException(__R_FN_PARAMS _In_ T exception) {
    __R_FN_LOCALS_RA;
    ReportFailure_CustomExceptionHelper(exception, __R_FN_CALL_FULL);
}

template <typename T>
__declspec(noreturn, noinline) inline void ReportFailure_CustomExceptionMsg(__R_FN_PARAMS _In_ T exception,
                                                                            _In_ _Printf_format_string_ PCSTR formatString,
                                                                            ...) {
    va_list argList;
    va_start(argList, formatString);
    wchar_t message[2048];
    PrintLoggingMessage(message, ARRAYSIZE(message), formatString, argList);

    __R_FN_LOCALS_RA;
    ReportFailure_CustomExceptionHelper(exception, __R_FN_CALL_FULL, message);
}

namespace __R_NS_NAME {
//*****************************************************************************
// Return Macros
//*****************************************************************************

__R_DIRECT_METHOD(void, Return_Hr)(__R_DIRECT_FN_PARAMS HRESULT hr) WI_NOEXCEPT {
    __R_FN_LOCALS;
    wil::details::ReportFailure_Hr(__R_DIRECT_FN_CALL FailureType::Return, hr);
}

__R_DIRECT_METHOD(HRESULT, Return_Win32)(__R_DIRECT_FN_PARAMS DWORD err) WI_NOEXCEPT {
    __R_FN_LOCALS;
    return wil::details::ReportFailure_Win32(__R_DIRECT_FN_CALL FailureType::Return, err);
}

__R_DIRECT_METHOD(HRESULT, Return_GetLastError)(__R_DIRECT_FN_PARAMS_ONLY) WI_NOEXCEPT {
    __R_FN_LOCALS;
    return wil::details::ReportFailure_GetLastErrorHr(__R_DIRECT_FN_CALL FailureType::Return);
}

__R_DIRECT_METHOD(HRESULT, Return_NtStatus)(__R_DIRECT_FN_PARAMS NTSTATUS status) WI_NOEXCEPT {
    __R_FN_LOCALS;
    return wil::details::ReportFailure_NtStatus(__R_DIRECT_FN_CALL FailureType::Return, status);
}

__R_DIRECT_METHOD(void, Return_HrMsg)(__R_DIRECT_FN_PARAMS HRESULT hr, _Printf_format_string_ PCSTR formatString, ...) WI_NOEXCEPT {
    va_list argList;
    va_start(argList, formatString);
    __R_FN_LOCALS;
    wil::details::ReportFailure_HrMsg(__R_DIRECT_FN_CALL FailureType::Return, hr, formatString, argList);
}

__R_DIRECT_METHOD(HRESULT, Return_Win32Msg)(__R_DIRECT_FN_PARAMS DWORD err, _Printf_format_string_ PCSTR formatString, ...) WI_NOEXCEPT {
    va_list argList;
    va_start(argList, formatString);
    __R_FN_LOCALS;
    return wil::details::ReportFailure_Win32Msg(__R_DIRECT_FN_CALL FailureType::Return, err, formatString, argList);
}

__R_DIRECT_METHOD(HRESULT, Return_GetLastErrorMsg)(__R_DIRECT_FN_PARAMS _Printf_format_string_ PCSTR formatString, ...) WI_NOEXCEPT {
    va_list argList;
    va_start(argList, formatString);
    __R_FN_LOCALS;
    return wil::details::ReportFailure_GetLastErrorHrMsg(__R_DIRECT_FN_CALL FailureType::Return, formatString, argList);
}

__R_DIRECT_METHOD(HRESULT, Return_NtStatusMsg)
(__R_DIRECT_FN_PARAMS NTSTATUS status, _Printf_format_string_ PCSTR formatString, ...) WI_NOEXCEPT {
    va_list argList;
    va_start(argList, formatString);
    __R_FN_LOCALS;
    return wil::details::ReportFailure_NtStatusMsg(__R_DIRECT_FN_CALL FailureType::Return, status, formatString, argList);
}

//*****************************************************************************
// Pre-release Return Macros
//*****************************************************************************

#ifdef RESULT_PRERELEASE
__R_DIRECT_METHOD(void, Return_HrPreRelease)(__R_DIRECT_FN_PARAMS HRESULT hr) WI_NOEXCEPT {
    __R_FN_LOCALS;
    wil::details::ReportFailure_Hr(__R_DIRECT_FN_CALL FailureType::ReturnPreRelease, hr);
}

__R_DIRECT_METHOD(void, Return_NullPreRelease)(__R_DIRECT_FN_PARAMS HRESULT hr) WI_NOEXCEPT {
    __R_FN_LOCALS;
    wil::details::ReportFailure_Hr(__R_DIRECT_FN_CALL FailureType::ReturnPreRelease, hr);
}

__R_DIRECT_METHOD(void, Return_NullWin32PreRelease)(__R_DIRECT_FN_PARAMS DWORD err) WI_NOEXCEPT {
    __R_FN_LOCALS;
    wil::details::ReportFailure_Win32(__R_DIRECT_FN_CALL FailureType::ReturnPreRelease, err);
}

__R_DIRECT_METHOD(HRESULT, Return_Win32PreRelease)(__R_DIRECT_FN_PARAMS DWORD err) WI_NOEXCEPT {
    __R_FN_LOCALS;
    return wil::details::ReportFailure_Win32(__R_DIRECT_FN_CALL FailureType::ReturnPreRelease, err);
}

__R_DIRECT_METHOD(HRESULT, Return_GetLastErrorPreRelease)(__R_DIRECT_FN_PARAMS_ONLY) WI_NOEXCEPT {
    __R_FN_LOCALS;
    return wil::details::ReportFailure_GetLastErrorHr(__R_DIRECT_FN_CALL FailureType::ReturnPreRelease);
}

__R_DIRECT_METHOD(void, Return_NullGetLastErrorPreRelease)(__R_DIRECT_FN_PARAMS_ONLY) WI_NOEXCEPT {
    __R_FN_LOCALS;
    wil::details::ReportFailure_GetLastErrorHr(__R_DIRECT_FN_CALL FailureType::ReturnPreRelease);
}

__R_DIRECT_METHOD(HRESULT, Return_NtStatusPreRelease)(__R_DIRECT_FN_PARAMS NTSTATUS status) WI_NOEXCEPT {
    __R_FN_LOCALS;
    return wil::details::ReportFailure_NtStatus(__R_DIRECT_FN_CALL FailureType::ReturnPreRelease, status);
}
#endif

//*****************************************************************************
// Log Macros
//*****************************************************************************

__R_DIRECT_METHOD(HRESULT, Log_Hr)(__R_DIRECT_FN_PARAMS HRESULT hr) WI_NOEXCEPT {
    __R_FN_LOCALS;
    wil::details::ReportFailure_Hr(__R_DIRECT_FN_CALL FailureType::Log, hr);
    return hr;
}

__R_DIRECT_METHOD(DWORD, Log_Win32)(__R_DIRECT_FN_PARAMS DWORD err) WI_NOEXCEPT {
    __R_FN_LOCALS;
    wil::details::ReportFailure_Win32(__R_DIRECT_FN_CALL FailureType::Log, err);
    return err;
}

__R_DIRECT_METHOD(DWORD, Log_GetLastError)(__R_DIRECT_FN_PARAMS_ONLY) WI_NOEXCEPT {
    __R_FN_LOCALS;
    return wil::details::ReportFailure_GetLastError(__R_DIRECT_FN_CALL FailureType::Log);
}

__R_DIRECT_METHOD(NTSTATUS, Log_NtStatus)(__R_DIRECT_FN_PARAMS NTSTATUS status) WI_NOEXCEPT {
    __R_FN_LOCALS;
    wil::details::ReportFailure_NtStatus(__R_DIRECT_FN_CALL FailureType::Log, status);
    return status;
}

__R_INTERNAL_METHOD(_Log_Hr)(__R_INTERNAL_FN_PARAMS HRESULT hr) WI_NOEXCEPT {
    __R_FN_LOCALS;
    wil::details::ReportFailure_Hr(__R_INTERNAL_FN_CALL FailureType::Log, hr);
}

__R_INTERNAL_METHOD(_Log_GetLastError)(__R_INTERNAL_FN_PARAMS_ONLY) WI_NOEXCEPT {
    __R_FN_LOCALS;
    wil::details::ReportFailure_GetLastError(__R_INTERNAL_FN_CALL FailureType::Log);
}

__R_INTERNAL_METHOD(_Log_Win32)(__R_INTERNAL_FN_PARAMS DWORD err) WI_NOEXCEPT {
    __R_FN_LOCALS;
    wil::details::ReportFailure_Win32(__R_INTERNAL_FN_CALL FailureType::Log, err);
}

__R_INTERNAL_METHOD(_Log_NullAlloc)(__R_INTERNAL_FN_PARAMS_ONLY) WI_NOEXCEPT {
    __R_FN_LOCALS;
    wil::details::ReportFailure_Hr(__R_INTERNAL_FN_CALL FailureType::Log, E_OUTOFMEMORY);
}

__R_INTERNAL_METHOD(_Log_NtStatus)(__R_INTERNAL_FN_PARAMS NTSTATUS status) WI_NOEXCEPT {
    __R_FN_LOCALS;
    wil::details::ReportFailure_NtStatus(__R_INTERNAL_FN_CALL FailureType::Log, status);
}

__R_CONDITIONAL_METHOD(HRESULT, Log_IfFailed)(__R_CONDITIONAL_FN_PARAMS HRESULT hr) WI_NOEXCEPT {
    if (FAILED(hr)) {
        __R_CALL_INTERNAL_METHOD(_Log_Hr)(__R_CONDITIONAL_FN_CALL hr);
    }
    return hr;
}

__R_CONDITIONAL_METHOD(BOOL, Log_IfWin32BoolFalse)(__R_CONDITIONAL_FN_PARAMS BOOL ret) WI_NOEXCEPT {
    if (!ret) {
        __R_CALL_INTERNAL_METHOD(_Log_GetLastError)(__R_CONDITIONAL_FN_CALL_ONLY);
    }
    return ret;
}

__R_CONDITIONAL_METHOD(DWORD, Log_IfWin32Error)(__R_CONDITIONAL_FN_PARAMS DWORD err) WI_NOEXCEPT {
    if (FAILED_WIN32(err)) {
        __R_CALL_INTERNAL_METHOD(_Log_Win32)(__R_CONDITIONAL_FN_CALL err);
    }
    return err;
}

__R_CONDITIONAL_METHOD(HANDLE, Log_IfHandleInvalid)(__R_CONDITIONAL_FN_PARAMS HANDLE handle) WI_NOEXCEPT {
    if (handle == INVALID_HANDLE_VALUE) {
        __R_CALL_INTERNAL_METHOD(_Log_GetLastError)(__R_CONDITIONAL_FN_CALL_ONLY);
    }
    return handle;
}

__R_CONDITIONAL_METHOD(HANDLE, Log_IfHandleNull)(__R_CONDITIONAL_FN_PARAMS HANDLE handle) WI_NOEXCEPT {
    if (handle == nullptr) {
        __R_CALL_INTERNAL_METHOD(_Log_GetLastError)(__R_CONDITIONAL_FN_CALL_ONLY);
    }
    return handle;
}

template <__R_CONDITIONAL_PARTIAL_TEMPLATE typename PointerT, __R_ENABLE_IF_IS_NOT_CLASS(PointerT)>
__R_CONDITIONAL_TEMPLATE_METHOD(PointerT, Log_IfNullAlloc)
(__R_CONDITIONAL_FN_PARAMS _Pre_maybenull_ PointerT pointer) WI_NOEXCEPT {
    if (pointer == nullptr) {
        __R_CALL_INTERNAL_METHOD(_Log_NullAlloc)(__R_CONDITIONAL_FN_CALL_ONLY);
    }
    return pointer;
}

template <__R_CONDITIONAL_PARTIAL_TEMPLATE typename PointerT, __R_ENABLE_IF_IS_CLASS(PointerT)>
__R_CONDITIONAL_TEMPLATE_METHOD(void, Log_IfNullAlloc)
(__R_CONDITIONAL_FN_PARAMS const PointerT& pointer) WI_NOEXCEPT {
    if (pointer == nullptr) {
        __R_CALL_INTERNAL_METHOD(_Log_NullAlloc)(__R_CONDITIONAL_FN_CALL_ONLY);
    }
}

__R_CONDITIONAL_METHOD(bool, Log_HrIf)(__R_CONDITIONAL_FN_PARAMS HRESULT hr, bool condition) WI_NOEXCEPT {
    if (condition) {
        __R_CALL_INTERNAL_METHOD(_Log_Hr)(__R_CONDITIONAL_FN_CALL hr);
    }
    return condition;
}

__R_CONDITIONAL_METHOD(bool, Log_HrIfFalse)(__R_CONDITIONAL_FN_PARAMS HRESULT hr, bool condition) WI_NOEXCEPT {
    if (!condition) {
        __R_CALL_INTERNAL_METHOD(_Log_Hr)(__R_CONDITIONAL_FN_CALL hr);
    }
    return condition;
}

template <__R_CONDITIONAL_PARTIAL_TEMPLATE typename PointerT, __R_ENABLE_IF_IS_NOT_CLASS(PointerT)>
__R_CONDITIONAL_TEMPLATE_METHOD(PointerT, Log_HrIfNull)
(__R_CONDITIONAL_FN_PARAMS HRESULT hr, _Pre_maybenull_ PointerT pointer) WI_NOEXCEPT {
    if (pointer == nullptr) {
        __R_CALL_INTERNAL_METHOD(_Log_Hr)(__R_CONDITIONAL_FN_CALL hr);
    }
    return pointer;
}

template <__R_CONDITIONAL_PARTIAL_TEMPLATE typename PointerT, __R_ENABLE_IF_IS_CLASS(PointerT)>
__R_CONDITIONAL_TEMPLATE_METHOD(void, Log_HrIfNull)
(__R_CONDITIONAL_FN_PARAMS HRESULT hr, _In_opt_ const PointerT& pointer) WI_NOEXCEPT {
    if (pointer == nullptr) {
        __R_CALL_INTERNAL_METHOD(_Log_Hr)(__R_CONDITIONAL_FN_CALL hr);
    }
}

__R_CONDITIONAL_METHOD(bool, Log_GetLastErrorIf)(__R_CONDITIONAL_FN_PARAMS bool condition) WI_NOEXCEPT {
    if (condition) {
        __R_CALL_INTERNAL_METHOD(_Log_GetLastError)(__R_CONDITIONAL_FN_CALL_ONLY);
    }
    return condition;
}

__R_CONDITIONAL_METHOD(bool, Log_GetLastErrorIfFalse)(__R_CONDITIONAL_FN_PARAMS bool condition) WI_NOEXCEPT {
    if (!condition) {
        __R_CALL_INTERNAL_METHOD(_Log_GetLastError)(__R_CONDITIONAL_FN_CALL_ONLY);
    }
    return condition;
}

template <__R_CONDITIONAL_PARTIAL_TEMPLATE typename PointerT, __R_ENABLE_IF_IS_NOT_CLASS(PointerT)>
__R_CONDITIONAL_TEMPLATE_METHOD(PointerT, Log_GetLastErrorIfNull)
(__R_CONDITIONAL_FN_PARAMS _Pre_maybenull_ PointerT pointer) WI_NOEXCEPT {
    if (pointer == nullptr) {
        __R_CALL_INTERNAL_METHOD(_Log_GetLastError)(__R_CONDITIONAL_FN_CALL_ONLY);
    }
    return pointer;
}

template <__R_CONDITIONAL_PARTIAL_TEMPLATE typename PointerT, __R_ENABLE_IF_IS_CLASS(PointerT)>
__R_CONDITIONAL_TEMPLATE_METHOD(void, Log_GetLastErrorIfNull)
(__R_CONDITIONAL_FN_PARAMS _In_opt_ const PointerT& pointer) WI_NOEXCEPT {
    if (pointer == nullptr) {
        __R_CALL_INTERNAL_METHOD(_Log_GetLastError)(__R_CONDITIONAL_FN_CALL_ONLY);
    }
}

__R_CONDITIONAL_METHOD(NTSTATUS, Log_IfNtStatusFailed)(__R_CONDITIONAL_FN_PARAMS NTSTATUS status) WI_NOEXCEPT {
    if (FAILED_NTSTATUS(status)) {
        __R_CALL_INTERNAL_METHOD(_Log_NtStatus)(__R_CONDITIONAL_FN_CALL status);
    }
    return status;
}

__R_DIRECT_METHOD(HRESULT, Log_HrMsg)(__R_DIRECT_FN_PARAMS HRESULT hr, _Printf_format_string_ PCSTR formatString, ...) WI_NOEXCEPT {
    va_list argList;
    va_start(argList, formatString);
    __R_FN_LOCALS;
    wil::details::ReportFailure_HrMsg(__R_DIRECT_FN_CALL FailureType::Log, hr, formatString, argList);
    return hr;
}

__R_DIRECT_METHOD(DWORD, Log_Win32Msg)(__R_DIRECT_FN_PARAMS DWORD err, _Printf_format_string_ PCSTR formatString, ...) WI_NOEXCEPT {
    va_list argList;
    va_start(argList, formatString);
    __R_FN_LOCALS;
    wil::details::ReportFailure_Win32Msg(__R_DIRECT_FN_CALL FailureType::Log, err, formatString, argList);
    return err;
}

__R_DIRECT_METHOD(DWORD, Log_GetLastErrorMsg)(__R_DIRECT_FN_PARAMS _Printf_format_string_ PCSTR formatString, ...) WI_NOEXCEPT {
    va_list argList;
    va_start(argList, formatString);
    __R_FN_LOCALS;
    return wil::details::ReportFailure_GetLastErrorMsg(__R_DIRECT_FN_CALL FailureType::Log, formatString, argList);
}

__R_DIRECT_METHOD(NTSTATUS, Log_NtStatusMsg)
(__R_DIRECT_FN_PARAMS NTSTATUS status, _Printf_format_string_ PCSTR formatString, ...) WI_NOEXCEPT {
    va_list argList;
    va_start(argList, formatString);
    __R_FN_LOCALS;
    wil::details::ReportFailure_NtStatusMsg(__R_DIRECT_FN_CALL FailureType::Log, status, formatString, argList);
    return status;
}

__R_INTERNAL_NOINLINE_METHOD(_Log_HrMsg)
(__R_INTERNAL_NOINLINE_FN_PARAMS HRESULT hr, _Printf_format_string_ PCSTR formatString, va_list argList) WI_NOEXCEPT {
    __R_FN_LOCALS;
    wil::details::ReportFailure_HrMsg(__R_INTERNAL_NOINLINE_FN_CALL FailureType::Log, hr, formatString, argList);
}

__R_INTERNAL_NOINLINE_METHOD(_Log_GetLastErrorMsg)
(__R_INTERNAL_NOINLINE_FN_PARAMS _Printf_format_string_ PCSTR formatString, va_list argList) WI_NOEXCEPT {
    __R_FN_LOCALS;
    wil::details::ReportFailure_GetLastErrorMsg(__R_INTERNAL_NOINLINE_FN_CALL FailureType::Log, formatString, argList);
}

__R_INTERNAL_NOINLINE_METHOD(_Log_Win32Msg)
(__R_INTERNAL_NOINLINE_FN_PARAMS DWORD err, _Printf_format_string_ PCSTR formatString, va_list argList) WI_NOEXCEPT {
    __R_FN_LOCALS;
    wil::details::ReportFailure_Win32Msg(__R_INTERNAL_NOINLINE_FN_CALL FailureType::Log, err, formatString, argList);
}

__R_INTERNAL_NOINLINE_METHOD(_Log_NullAllocMsg)
(__R_INTERNAL_NOINLINE_FN_PARAMS _Printf_format_string_ PCSTR formatString, va_list argList) WI_NOEXCEPT {
    __R_FN_LOCALS;
    wil::details::ReportFailure_HrMsg(__R_INTERNAL_NOINLINE_FN_CALL FailureType::Log, E_OUTOFMEMORY, formatString, argList);
}

__R_INTERNAL_NOINLINE_METHOD(_Log_NtStatusMsg)
(__R_INTERNAL_NOINLINE_FN_PARAMS NTSTATUS status, _Printf_format_string_ PCSTR formatString, va_list argList) WI_NOEXCEPT {
    __R_FN_LOCALS;
    wil::details::ReportFailure_NtStatusMsg(__R_INTERNAL_NOINLINE_FN_CALL FailureType::Log, status, formatString, argList);
}

__R_CONDITIONAL_NOINLINE_METHOD(HRESULT, Log_IfFailedMsg)
(__R_CONDITIONAL_FN_PARAMS HRESULT hr, _Printf_format_string_ PCSTR formatString, ...) WI_NOEXCEPT {
    if (FAILED(hr)) {
        va_list argList;
        va_start(argList, formatString);
        __R_CALL_INTERNAL_NOINLINE_METHOD(_Log_HrMsg)(__R_CONDITIONAL_NOINLINE_FN_CALL hr, formatString, argList);
    }
    return hr;
}

__R_CONDITIONAL_NOINLINE_METHOD(BOOL, Log_IfWin32BoolFalseMsg)
(__R_CONDITIONAL_FN_PARAMS BOOL ret, _Printf_format_string_ PCSTR formatString, ...) WI_NOEXCEPT {
    if (!ret) {
        va_list argList;
        va_start(argList, formatString);
        __R_CALL_INTERNAL_NOINLINE_METHOD(_Log_GetLastErrorMsg)(__R_CONDITIONAL_NOINLINE_FN_CALL formatString, argList);
    }
    return ret;
}

__R_CONDITIONAL_NOINLINE_METHOD(DWORD, Log_IfWin32ErrorMsg)
(__R_CONDITIONAL_FN_PARAMS DWORD err, _Printf_format_string_ PCSTR formatString, ...) WI_NOEXCEPT {
    if (FAILED_WIN32(err)) {
        va_list argList;
        va_start(argList, formatString);
        __R_CALL_INTERNAL_NOINLINE_METHOD(_Log_Win32Msg)(__R_CONDITIONAL_NOINLINE_FN_CALL err, formatString, argList);
    }
    return err;
}

__R_CONDITIONAL_NOINLINE_METHOD(HANDLE, Log_IfHandleInvalidMsg)
(__R_CONDITIONAL_FN_PARAMS HANDLE handle, _Printf_format_string_ PCSTR formatString, ...) WI_NOEXCEPT {
    if (handle == INVALID_HANDLE_VALUE) {
        va_list argList;
        va_start(argList, formatString);
        __R_CALL_INTERNAL_NOINLINE_METHOD(_Log_GetLastErrorMsg)(__R_CONDITIONAL_NOINLINE_FN_CALL formatString, argList);
    }
    return handle;
}

__R_CONDITIONAL_NOINLINE_METHOD(HANDLE, Log_IfHandleNullMsg)
(__R_CONDITIONAL_FN_PARAMS HANDLE handle, _Printf_format_string_ PCSTR formatString, ...) WI_NOEXCEPT {
    if (handle == nullptr) {
        va_list argList;
        va_start(argList, formatString);
        __R_CALL_INTERNAL_NOINLINE_METHOD(_Log_GetLastErrorMsg)(__R_CONDITIONAL_NOINLINE_FN_CALL formatString, argList);
    }
    return handle;
}

template <__R_CONDITIONAL_PARTIAL_TEMPLATE typename PointerT, __R_ENABLE_IF_IS_NOT_CLASS(PointerT)>
__R_CONDITIONAL_NOINLINE_TEMPLATE_METHOD(PointerT, Log_IfNullAllocMsg)
(__R_CONDITIONAL_FN_PARAMS _Pre_maybenull_ PointerT pointer, _Printf_format_string_ PCSTR formatString, ...) WI_NOEXCEPT {
    if (pointer == nullptr) {
        va_list argList;
        va_start(argList, formatString);
        __R_CALL_INTERNAL_NOINLINE_METHOD(_Log_NullAllocMsg)(__R_CONDITIONAL_NOINLINE_FN_CALL_ONLY, formatString, argList);
    }
    return pointer;
}

template <__R_CONDITIONAL_PARTIAL_TEMPLATE typename PointerT, __R_ENABLE_IF_IS_CLASS(PointerT)>
__R_CONDITIONAL_NOINLINE_TEMPLATE_METHOD(void, Log_IfNullAllocMsg)
(__R_CONDITIONAL_FN_PARAMS const PointerT& pointer, _Printf_format_string_ PCSTR formatString, ...) WI_NOEXCEPT {
    if (pointer == nullptr) {
        va_list argList;
        va_start(argList, formatString);
        __R_CALL_INTERNAL_NOINLINE_METHOD(_Log_NullAllocMsg)(__R_CONDITIONAL_NOINLINE_FN_CALL_ONLY, formatString, argList);
    }
}

__R_CONDITIONAL_NOINLINE_METHOD(bool, Log_HrIfMsg)
(__R_CONDITIONAL_FN_PARAMS HRESULT hr, bool condition, _Printf_format_string_ PCSTR formatString, ...) WI_NOEXCEPT {
    if (condition) {
        va_list argList;
        va_start(argList, formatString);
        __R_CALL_INTERNAL_NOINLINE_METHOD(_Log_HrMsg)(__R_CONDITIONAL_NOINLINE_FN_CALL hr, formatString, argList);
    }
    return condition;
}

__R_CONDITIONAL_NOINLINE_METHOD(bool, Log_HrIfFalseMsg)
(__R_CONDITIONAL_FN_PARAMS HRESULT hr, bool condition, _Printf_format_string_ PCSTR formatString, ...) WI_NOEXCEPT {
    if (!condition) {
        va_list argList;
        va_start(argList, formatString);
        __R_CALL_INTERNAL_NOINLINE_METHOD(_Log_HrMsg)(__R_CONDITIONAL_NOINLINE_FN_CALL hr, formatString, argList);
    }
    return condition;
}

template <__R_CONDITIONAL_PARTIAL_TEMPLATE typename PointerT, __R_ENABLE_IF_IS_NOT_CLASS(PointerT)>
__R_CONDITIONAL_NOINLINE_TEMPLATE_METHOD(PointerT, Log_HrIfNullMsg)
(__R_CONDITIONAL_FN_PARAMS HRESULT hr, _Pre_maybenull_ PointerT pointer, _Printf_format_string_ PCSTR formatString, ...) WI_NOEXCEPT {
    if (pointer == nullptr) {
        va_list argList;
        va_start(argList, formatString);
        __R_CALL_INTERNAL_NOINLINE_METHOD(_Log_HrMsg)(__R_CONDITIONAL_NOINLINE_FN_CALL hr, formatString, argList);
    }
    return pointer;
}

template <__R_CONDITIONAL_PARTIAL_TEMPLATE typename PointerT, __R_ENABLE_IF_IS_CLASS(PointerT)>
__R_CONDITIONAL_NOINLINE_TEMPLATE_METHOD(void, Log_HrIfNullMsg)
(__R_CONDITIONAL_FN_PARAMS HRESULT hr, _In_opt_ const PointerT& pointer, _Printf_format_string_ PCSTR formatString, ...) WI_NOEXCEPT {
    if (pointer == nullptr) {
        va_list argList;
        va_start(argList, formatString);
        __R_CALL_INTERNAL_NOINLINE_METHOD(_Log_HrMsg)(__R_CONDITIONAL_NOINLINE_FN_CALL hr, formatString, argList);
    }
}

__R_CONDITIONAL_NOINLINE_METHOD(bool, Log_GetLastErrorIfMsg)
(__R_CONDITIONAL_FN_PARAMS bool condition, _Printf_format_string_ PCSTR formatString, ...) WI_NOEXCEPT {
    if (condition) {
        va_list argList;
        va_start(argList, formatString);
        __R_CALL_INTERNAL_NOINLINE_METHOD(_Log_GetLastErrorMsg)(__R_CONDITIONAL_NOINLINE_FN_CALL formatString, argList);
    }
    return condition;
}

__R_CONDITIONAL_NOINLINE_METHOD(bool, Log_GetLastErrorIfFalseMsg)
(__R_CONDITIONAL_FN_PARAMS bool condition, _Printf_format_string_ PCSTR formatString, ...) WI_NOEXCEPT {
    if (!condition) {
        va_list argList;
        va_start(argList, formatString);
        __R_CALL_INTERNAL_NOINLINE_METHOD(_Log_GetLastErrorMsg)(__R_CONDITIONAL_NOINLINE_FN_CALL formatString, argList);
    }
    return condition;
}

template <__R_CONDITIONAL_PARTIAL_TEMPLATE typename PointerT, __R_ENABLE_IF_IS_NOT_CLASS(PointerT)>
__R_CONDITIONAL_NOINLINE_TEMPLATE_METHOD(PointerT, Log_GetLastErrorIfNullMsg)
(__R_CONDITIONAL_FN_PARAMS _Pre_maybenull_ PointerT pointer, _Printf_format_string_ PCSTR formatString, ...) WI_NOEXCEPT {
    if (pointer == nullptr) {
        va_list argList;
        va_start(argList, formatString);
        __R_CALL_INTERNAL_NOINLINE_METHOD(_Log_GetLastErrorMsg)(__R_CONDITIONAL_NOINLINE_FN_CALL formatString, argList);
    }
    return pointer;
}

template <__R_CONDITIONAL_PARTIAL_TEMPLATE typename PointerT, __R_ENABLE_IF_IS_CLASS(PointerT)>
__R_CONDITIONAL_NOINLINE_TEMPLATE_METHOD(void, Log_GetLastErrorIfNullMsg)
(__R_CONDITIONAL_FN_PARAMS _In_opt_ const PointerT& pointer, _Printf_format_string_ PCSTR formatString, ...) WI_NOEXCEPT {
    if (pointer == nullptr) {
        va_list argList;
        va_start(argList, formatString);
        __R_CALL_INTERNAL_NOINLINE_METHOD(_Log_GetLastErrorMsg)(__R_CONDITIONAL_NOINLINE_FN_CALL formatString, argList);
    }
}

__R_CONDITIONAL_NOINLINE_METHOD(NTSTATUS, Log_IfNtStatusFailedMsg)
(__R_CONDITIONAL_FN_PARAMS NTSTATUS status, _Printf_format_string_ PCSTR formatString, ...) WI_NOEXCEPT {
    if (FAILED_NTSTATUS(status)) {
        va_list argList;
        va_start(argList, formatString);
        __R_CALL_INTERNAL_NOINLINE_METHOD(_Log_NtStatusMsg)(__R_CONDITIONAL_NOINLINE_FN_CALL status, formatString, argList);
    }
    return status;
}
} // namespace __R_NS_NAME

namespace __RFF_NS_NAME {
//*****************************************************************************
// FailFast Macros
//*****************************************************************************

__RFF_DIRECT_NORET_METHOD(void, FailFast_Hr)(__RFF_DIRECT_FN_PARAMS HRESULT hr) WI_NOEXCEPT {
    __RFF_FN_LOCALS;
    wil::details::ReportFailure_Hr(__RFF_DIRECT_FN_CALL FailureType::FailFast, hr);
}

__RFF_DIRECT_NORET_METHOD(void, FailFast_Win32)(__RFF_DIRECT_FN_PARAMS DWORD err) WI_NOEXCEPT {
    __RFF_FN_LOCALS;
    wil::details::ReportFailure_Win32(__RFF_DIRECT_FN_CALL FailureType::FailFast, err);
}

__RFF_DIRECT_NORET_METHOD(void, FailFast_GetLastError)(__RFF_DIRECT_FN_PARAMS_ONLY) WI_NOEXCEPT {
    __RFF_FN_LOCALS;
    wil::details::ReportFailure_GetLastError(__RFF_DIRECT_FN_CALL FailureType::FailFast);
}

__RFF_DIRECT_NORET_METHOD(void, FailFast_NtStatus)(__RFF_DIRECT_FN_PARAMS NTSTATUS status) WI_NOEXCEPT {
    __RFF_FN_LOCALS;
    wil::details::ReportFailure_NtStatus(__RFF_DIRECT_FN_CALL FailureType::FailFast, status);
}

__RFF_INTERNAL_NORET_METHOD(_FailFast_Hr)(__RFF_INTERNAL_FN_PARAMS HRESULT hr) WI_NOEXCEPT {
    __RFF_FN_LOCALS;
    wil::details::ReportFailure_Hr(__RFF_INTERNAL_FN_CALL FailureType::FailFast, hr);
}

__RFF_INTERNAL_NORET_METHOD(_FailFast_GetLastError)(__RFF_INTERNAL_FN_PARAMS_ONLY) WI_NOEXCEPT {
    __RFF_FN_LOCALS;
    wil::details::ReportFailure_GetLastError(__RFF_INTERNAL_FN_CALL FailureType::FailFast);
}

__RFF_INTERNAL_NORET_METHOD(_FailFast_Win32)(__RFF_INTERNAL_FN_PARAMS DWORD err) WI_NOEXCEPT {
    __RFF_FN_LOCALS;
    wil::details::ReportFailure_Win32(__RFF_INTERNAL_FN_CALL FailureType::FailFast, err);
}

__RFF_INTERNAL_NORET_METHOD(_FailFast_NullAlloc)(__RFF_INTERNAL_FN_PARAMS_ONLY) WI_NOEXCEPT {
    __RFF_FN_LOCALS;
    wil::details::ReportFailure_Hr(__RFF_INTERNAL_FN_CALL FailureType::FailFast, E_OUTOFMEMORY);
}

__RFF_INTERNAL_NORET_METHOD(_FailFast_NtStatus)(__RFF_INTERNAL_FN_PARAMS NTSTATUS status) WI_NOEXCEPT {
    __RFF_FN_LOCALS;
    wil::details::ReportFailure_NtStatus(__RFF_INTERNAL_FN_CALL FailureType::FailFast, status);
}

__RFF_CONDITIONAL_METHOD(HRESULT, FailFast_IfFailed)(__RFF_CONDITIONAL_FN_PARAMS HRESULT hr) WI_NOEXCEPT {
    if (FAILED(hr)) {
        __RFF_CALL_INTERNAL_METHOD(_FailFast_Hr)(__RFF_CONDITIONAL_FN_CALL hr);
    }
    return hr;
}

__RFF_CONDITIONAL_METHOD(BOOL, FailFast_IfWin32BoolFalse)(__RFF_CONDITIONAL_FN_PARAMS BOOL ret) WI_NOEXCEPT {
    if (!ret) {
        __RFF_CALL_INTERNAL_METHOD(_FailFast_GetLastError)(__RFF_CONDITIONAL_FN_CALL_ONLY);
    }
    return ret;
}

__RFF_CONDITIONAL_METHOD(DWORD, FailFast_IfWin32Error)(__RFF_CONDITIONAL_FN_PARAMS DWORD err) WI_NOEXCEPT {
    if (FAILED_WIN32(err)) {
        __RFF_CALL_INTERNAL_METHOD(_FailFast_Win32)(__RFF_CONDITIONAL_FN_CALL err);
    }
    return err;
}

__RFF_CONDITIONAL_METHOD(HANDLE, FailFast_IfHandleInvalid)(__RFF_CONDITIONAL_FN_PARAMS HANDLE handle) WI_NOEXCEPT {
    if (handle == INVALID_HANDLE_VALUE) {
        __RFF_CALL_INTERNAL_METHOD(_FailFast_GetLastError)(__RFF_CONDITIONAL_FN_CALL_ONLY);
    }
    return handle;
}

__RFF_CONDITIONAL_METHOD(RESULT_NORETURN_NULL HANDLE, FailFast_IfHandleNull)(__RFF_CONDITIONAL_FN_PARAMS HANDLE handle) WI_NOEXCEPT {
    if (handle == nullptr) {
        __RFF_CALL_INTERNAL_METHOD(_FailFast_GetLastError)(__RFF_CONDITIONAL_FN_CALL_ONLY);
    }
    return handle;
}

template <__RFF_CONDITIONAL_PARTIAL_TEMPLATE typename PointerT, __R_ENABLE_IF_IS_NOT_CLASS(PointerT)>
__RFF_CONDITIONAL_TEMPLATE_METHOD(RESULT_NORETURN_NULL PointerT, FailFast_IfNullAlloc)
(__RFF_CONDITIONAL_FN_PARAMS _Pre_maybenull_ PointerT pointer) WI_NOEXCEPT {
    if (pointer == nullptr) {
        __RFF_CALL_INTERNAL_METHOD(_FailFast_NullAlloc)(__RFF_CONDITIONAL_FN_CALL_ONLY);
    }
    return pointer;
}

template <__RFF_CONDITIONAL_PARTIAL_TEMPLATE typename PointerT, __R_ENABLE_IF_IS_CLASS(PointerT)>
__RFF_CONDITIONAL_TEMPLATE_METHOD(RESULT_NORETURN_NULL void, FailFast_IfNullAlloc)
(__RFF_CONDITIONAL_FN_PARAMS const PointerT& pointer) WI_NOEXCEPT {
    if (pointer == nullptr) {
        __RFF_CALL_INTERNAL_METHOD(_FailFast_NullAlloc)(__RFF_CONDITIONAL_FN_CALL_ONLY);
    }
}

__RFF_CONDITIONAL_METHOD(bool, FailFast_HrIf)(__RFF_CONDITIONAL_FN_PARAMS HRESULT hr, bool condition) WI_NOEXCEPT {
    if (condition) {
        __RFF_CALL_INTERNAL_METHOD(_FailFast_Hr)(__RFF_CONDITIONAL_FN_CALL hr);
    }
    return condition;
}

__RFF_CONDITIONAL_METHOD(bool, FailFast_HrIfFalse)(__RFF_CONDITIONAL_FN_PARAMS HRESULT hr, bool condition) WI_NOEXCEPT {
    if (!condition) {
        __RFF_CALL_INTERNAL_METHOD(_FailFast_Hr)(__RFF_CONDITIONAL_FN_CALL hr);
    }
    return condition;
}

template <__RFF_CONDITIONAL_PARTIAL_TEMPLATE typename PointerT, __R_ENABLE_IF_IS_NOT_CLASS(PointerT)>
__RFF_CONDITIONAL_TEMPLATE_METHOD(RESULT_NORETURN_NULL PointerT, FailFast_HrIfNull)
(__RFF_CONDITIONAL_FN_PARAMS HRESULT hr, _Pre_maybenull_ PointerT pointer) WI_NOEXCEPT {
    if (pointer == nullptr) {
        __RFF_CALL_INTERNAL_METHOD(_FailFast_Hr)(__RFF_CONDITIONAL_FN_CALL hr);
    }
    return pointer;
}

template <__RFF_CONDITIONAL_PARTIAL_TEMPLATE typename PointerT, __R_ENABLE_IF_IS_CLASS(PointerT)>
__RFF_CONDITIONAL_TEMPLATE_METHOD(RESULT_NORETURN_NULL void, FailFast_HrIfNull)
(__RFF_CONDITIONAL_FN_PARAMS HRESULT hr, _In_opt_ const PointerT& pointer) WI_NOEXCEPT {
    if (pointer == nullptr) {
        __RFF_CALL_INTERNAL_METHOD(_FailFast_Hr)(__RFF_CONDITIONAL_FN_CALL hr);
    }
}

__RFF_CONDITIONAL_METHOD(bool, FailFast_GetLastErrorIf)(__RFF_CONDITIONAL_FN_PARAMS bool condition) WI_NOEXCEPT {
    if (condition) {
        __RFF_CALL_INTERNAL_METHOD(_FailFast_GetLastError)(__RFF_CONDITIONAL_FN_CALL_ONLY);
    }
    return condition;
}

__RFF_CONDITIONAL_METHOD(bool, FailFast_GetLastErrorIfFalse)(__RFF_CONDITIONAL_FN_PARAMS bool condition) WI_NOEXCEPT {
    if (!condition) {
        __RFF_CALL_INTERNAL_METHOD(_FailFast_GetLastError)(__RFF_CONDITIONAL_FN_CALL_ONLY);
    }
    return condition;
}

template <__RFF_CONDITIONAL_PARTIAL_TEMPLATE typename PointerT, __R_ENABLE_IF_IS_NOT_CLASS(PointerT)>
__RFF_CONDITIONAL_TEMPLATE_METHOD(RESULT_NORETURN_NULL PointerT, FailFast_GetLastErrorIfNull)
(__RFF_CONDITIONAL_FN_PARAMS _Pre_maybenull_ PointerT pointer) WI_NOEXCEPT {
    if (pointer == nullptr) {
        __RFF_CALL_INTERNAL_METHOD(_FailFast_GetLastError)(__RFF_CONDITIONAL_FN_CALL_ONLY);
    }
    return pointer;
}

template <__RFF_CONDITIONAL_PARTIAL_TEMPLATE typename PointerT, __R_ENABLE_IF_IS_CLASS(PointerT)>
__RFF_CONDITIONAL_TEMPLATE_METHOD(RESULT_NORETURN_NULL void, FailFast_GetLastErrorIfNull)
(__RFF_CONDITIONAL_FN_PARAMS _In_opt_ const PointerT& pointer) WI_NOEXCEPT {
    if (pointer == nullptr) {
        __RFF_CALL_INTERNAL_METHOD(_FailFast_GetLastError)(__RFF_CONDITIONAL_FN_CALL_ONLY);
    }
}

__RFF_CONDITIONAL_METHOD(NTSTATUS, FailFast_IfNtStatusFailed)(__RFF_CONDITIONAL_FN_PARAMS NTSTATUS status) WI_NOEXCEPT {
    if (FAILED_NTSTATUS(status)) {
        __RFF_CALL_INTERNAL_METHOD(_FailFast_NtStatus)(__RFF_CONDITIONAL_FN_CALL status);
    }
    return status;
}

__RFF_DIRECT_NORET_METHOD(void, FailFast_HrMsg)
(__RFF_DIRECT_FN_PARAMS HRESULT hr, _Printf_format_string_ PCSTR formatString, ...) WI_NOEXCEPT {
    va_list argList;
    va_start(argList, formatString);
    __RFF_FN_LOCALS;
    wil::details::ReportFailure_HrMsg(__RFF_DIRECT_FN_CALL FailureType::FailFast, hr, formatString, argList);
}

__RFF_DIRECT_NORET_METHOD(void, FailFast_Win32Msg)
(__RFF_DIRECT_FN_PARAMS DWORD err, _Printf_format_string_ PCSTR formatString, ...) WI_NOEXCEPT {
    va_list argList;
    va_start(argList, formatString);
    __RFF_FN_LOCALS;
    wil::details::ReportFailure_Win32Msg(__RFF_DIRECT_FN_CALL FailureType::FailFast, err, formatString, argList);
}

__RFF_DIRECT_NORET_METHOD(void, FailFast_GetLastErrorMsg)
(__RFF_DIRECT_FN_PARAMS _Printf_format_string_ PCSTR formatString, ...) WI_NOEXCEPT {
    va_list argList;
    va_start(argList, formatString);
    __RFF_FN_LOCALS;
    wil::details::ReportFailure_GetLastErrorMsg(__RFF_DIRECT_FN_CALL FailureType::FailFast, formatString, argList);
}

__RFF_DIRECT_NORET_METHOD(void, FailFast_NtStatusMsg)
(__RFF_DIRECT_FN_PARAMS NTSTATUS status, _Printf_format_string_ PCSTR formatString, ...) WI_NOEXCEPT {
    va_list argList;
    va_start(argList, formatString);
    __RFF_FN_LOCALS;
    wil::details::ReportFailure_NtStatusMsg(__RFF_DIRECT_FN_CALL FailureType::FailFast, status, formatString, argList);
}

__RFF_INTERNAL_NOINLINE_NORET_METHOD(_FailFast_HrMsg)
(__RFF_INTERNAL_NOINLINE_FN_PARAMS HRESULT hr, _Printf_format_string_ PCSTR formatString, va_list argList) WI_NOEXCEPT {
    __RFF_FN_LOCALS;
    wil::details::ReportFailure_HrMsg(__RFF_INTERNAL_NOINLINE_FN_CALL FailureType::FailFast, hr, formatString, argList);
}

__RFF_INTERNAL_NOINLINE_NORET_METHOD(_FailFast_GetLastErrorMsg)
(__RFF_INTERNAL_NOINLINE_FN_PARAMS _Printf_format_string_ PCSTR formatString, va_list argList) WI_NOEXCEPT {
    __RFF_FN_LOCALS;
    wil::details::ReportFailure_GetLastErrorMsg(__RFF_INTERNAL_NOINLINE_FN_CALL FailureType::FailFast, formatString, argList);
}

__RFF_INTERNAL_NOINLINE_NORET_METHOD(_FailFast_Win32Msg)
(__RFF_INTERNAL_NOINLINE_FN_PARAMS DWORD err, _Printf_format_string_ PCSTR formatString, va_list argList) WI_NOEXCEPT {
    __RFF_FN_LOCALS;
    wil::details::ReportFailure_Win32Msg(__RFF_INTERNAL_NOINLINE_FN_CALL FailureType::FailFast, err, formatString, argList);
}

__RFF_INTERNAL_NOINLINE_NORET_METHOD(_FailFast_NullAllocMsg)
(__RFF_INTERNAL_NOINLINE_FN_PARAMS _Printf_format_string_ PCSTR formatString, va_list argList) WI_NOEXCEPT {
    __RFF_FN_LOCALS;
    wil::details::ReportFailure_HrMsg(__RFF_INTERNAL_NOINLINE_FN_CALL FailureType::FailFast, E_OUTOFMEMORY, formatString, argList);
}

__RFF_INTERNAL_NOINLINE_NORET_METHOD(_FailFast_NtStatusMsg)
(__RFF_INTERNAL_NOINLINE_FN_PARAMS NTSTATUS status, _Printf_format_string_ PCSTR formatString, va_list argList) WI_NOEXCEPT {
    __RFF_FN_LOCALS;
    wil::details::ReportFailure_NtStatusMsg(__RFF_INTERNAL_NOINLINE_FN_CALL FailureType::FailFast, status, formatString, argList);
}

__RFF_CONDITIONAL_NOINLINE_METHOD(HRESULT, FailFast_IfFailedMsg)
(__RFF_CONDITIONAL_FN_PARAMS HRESULT hr, _Printf_format_string_ PCSTR formatString, ...) WI_NOEXCEPT {
    if (FAILED(hr)) {
        va_list argList;
        va_start(argList, formatString);
        __RFF_CALL_INTERNAL_NOINLINE_METHOD(_FailFast_HrMsg)(__RFF_CONDITIONAL_NOINLINE_FN_CALL hr, formatString, argList);
    }
    return hr;
}

__RFF_CONDITIONAL_NOINLINE_METHOD(BOOL, FailFast_IfWin32BoolFalseMsg)
(__RFF_CONDITIONAL_FN_PARAMS BOOL ret, _Printf_format_string_ PCSTR formatString, ...) WI_NOEXCEPT {
    if (!ret) {
        va_list argList;
        va_start(argList, formatString);
        __RFF_CALL_INTERNAL_NOINLINE_METHOD(_FailFast_GetLastErrorMsg)(__RFF_CONDITIONAL_NOINLINE_FN_CALL formatString, argList);
    }
    return ret;
}

__RFF_CONDITIONAL_NOINLINE_METHOD(DWORD, FailFast_IfWin32ErrorMsg)
(__RFF_CONDITIONAL_FN_PARAMS DWORD err, _Printf_format_string_ PCSTR formatString, ...) WI_NOEXCEPT {
    if (FAILED_WIN32(err)) {
        va_list argList;
        va_start(argList, formatString);
        __RFF_CALL_INTERNAL_NOINLINE_METHOD(_FailFast_Win32Msg)(__RFF_CONDITIONAL_NOINLINE_FN_CALL err, formatString, argList);
    }
    return err;
}

__RFF_CONDITIONAL_NOINLINE_METHOD(HANDLE, FailFast_IfHandleInvalidMsg)
(__RFF_CONDITIONAL_FN_PARAMS HANDLE handle, _Printf_format_string_ PCSTR formatString, ...) WI_NOEXCEPT {
    if (handle == INVALID_HANDLE_VALUE) {
        va_list argList;
        va_start(argList, formatString);
        __RFF_CALL_INTERNAL_NOINLINE_METHOD(_FailFast_GetLastErrorMsg)(__RFF_CONDITIONAL_NOINLINE_FN_CALL formatString, argList);
    }
    return handle;
}

__RFF_CONDITIONAL_NOINLINE_METHOD(RESULT_NORETURN_NULL HANDLE, FailFast_IfHandleNullMsg)
(__RFF_CONDITIONAL_FN_PARAMS HANDLE handle, _Printf_format_string_ PCSTR formatString, ...) WI_NOEXCEPT {
    if (handle == nullptr) {
        va_list argList;
        va_start(argList, formatString);
        __RFF_CALL_INTERNAL_NOINLINE_METHOD(_FailFast_GetLastErrorMsg)(__RFF_CONDITIONAL_NOINLINE_FN_CALL formatString, argList);
    }
    return handle;
}

template <__RFF_CONDITIONAL_PARTIAL_TEMPLATE typename PointerT, __R_ENABLE_IF_IS_NOT_CLASS(PointerT)>
__RFF_CONDITIONAL_NOINLINE_TEMPLATE_METHOD(RESULT_NORETURN_NULL PointerT, FailFast_IfNullAllocMsg)
(__RFF_CONDITIONAL_FN_PARAMS _Pre_maybenull_ PointerT pointer, _Printf_format_string_ PCSTR formatString, ...) WI_NOEXCEPT {
    if (pointer == nullptr) {
        va_list argList;
        va_start(argList, formatString);
        __RFF_CALL_INTERNAL_NOINLINE_METHOD(_FailFast_NullAllocMsg)(__RFF_CONDITIONAL_NOINLINE_FN_CALL_ONLY, formatString, argList);
    }
    return pointer;
}

template <__RFF_CONDITIONAL_PARTIAL_TEMPLATE typename PointerT, __R_ENABLE_IF_IS_CLASS(PointerT)>
__RFF_CONDITIONAL_NOINLINE_TEMPLATE_METHOD(RESULT_NORETURN_NULL void, FailFast_IfNullAllocMsg)
(__RFF_CONDITIONAL_FN_PARAMS const PointerT& pointer, _Printf_format_string_ PCSTR formatString, ...) WI_NOEXCEPT {
    if (pointer == nullptr) {
        va_list argList;
        va_start(argList, formatString);
        __RFF_CALL_INTERNAL_NOINLINE_METHOD(_FailFast_NullAllocMsg)(__RFF_CONDITIONAL_NOINLINE_FN_CALL_ONLY, formatString, argList);
    }
}

__RFF_CONDITIONAL_NOINLINE_METHOD(bool, FailFast_HrIfMsg)
(__RFF_CONDITIONAL_FN_PARAMS HRESULT hr, bool condition, _Printf_format_string_ PCSTR formatString, ...) WI_NOEXCEPT {
    if (condition) {
        va_list argList;
        va_start(argList, formatString);
        __RFF_CALL_INTERNAL_NOINLINE_METHOD(_FailFast_HrMsg)(__RFF_CONDITIONAL_NOINLINE_FN_CALL hr, formatString, argList);
    }
    return condition;
}

__RFF_CONDITIONAL_NOINLINE_METHOD(bool, FailFast_HrIfFalseMsg)
(__RFF_CONDITIONAL_FN_PARAMS HRESULT hr, bool condition, _Printf_format_string_ PCSTR formatString, ...) WI_NOEXCEPT {
    if (!condition) {
        va_list argList;
        va_start(argList, formatString);
        __RFF_CALL_INTERNAL_NOINLINE_METHOD(_FailFast_HrMsg)(__RFF_CONDITIONAL_NOINLINE_FN_CALL hr, formatString, argList);
    }
    return condition;
}

template <__RFF_CONDITIONAL_PARTIAL_TEMPLATE typename PointerT, __R_ENABLE_IF_IS_NOT_CLASS(PointerT)>
__RFF_CONDITIONAL_NOINLINE_TEMPLATE_METHOD(RESULT_NORETURN_NULL PointerT, FailFast_HrIfNullMsg)
(__RFF_CONDITIONAL_FN_PARAMS HRESULT hr, _Pre_maybenull_ PointerT pointer, _Printf_format_string_ PCSTR formatString, ...) WI_NOEXCEPT {
    if (pointer == nullptr) {
        va_list argList;
        va_start(argList, formatString);
        __RFF_CALL_INTERNAL_NOINLINE_METHOD(_FailFast_HrMsg)(__RFF_CONDITIONAL_NOINLINE_FN_CALL hr, formatString, argList);
    }
    return pointer;
}

template <__RFF_CONDITIONAL_PARTIAL_TEMPLATE typename PointerT, __R_ENABLE_IF_IS_CLASS(PointerT)>
__RFF_CONDITIONAL_NOINLINE_TEMPLATE_METHOD(RESULT_NORETURN_NULL void, FailFast_HrIfNullMsg)
(__RFF_CONDITIONAL_FN_PARAMS HRESULT hr, _In_opt_ const PointerT& pointer, _Printf_format_string_ PCSTR formatString, ...) WI_NOEXCEPT {
    if (pointer == nullptr) {
        va_list argList;
        va_start(argList, formatString);
        __RFF_CALL_INTERNAL_NOINLINE_METHOD(_FailFast_HrMsg)(__RFF_CONDITIONAL_NOINLINE_FN_CALL hr, formatString, argList);
    }
}

__RFF_CONDITIONAL_NOINLINE_METHOD(bool, FailFast_GetLastErrorIfMsg)
(__RFF_CONDITIONAL_FN_PARAMS bool condition, _Printf_format_string_ PCSTR formatString, ...) WI_NOEXCEPT {
    if (condition) {
        va_list argList;
        va_start(argList, formatString);
        __RFF_CALL_INTERNAL_NOINLINE_METHOD(_FailFast_GetLastErrorMsg)(__RFF_CONDITIONAL_NOINLINE_FN_CALL formatString, argList);
    }
    return condition;
}

__RFF_CONDITIONAL_NOINLINE_METHOD(bool, FailFast_GetLastErrorIfFalseMsg)
(__RFF_CONDITIONAL_FN_PARAMS bool condition, _Printf_format_string_ PCSTR formatString, ...) WI_NOEXCEPT {
    if (!condition) {
        va_list argList;
        va_start(argList, formatString);
        __RFF_CALL_INTERNAL_NOINLINE_METHOD(_FailFast_GetLastErrorMsg)(__RFF_CONDITIONAL_NOINLINE_FN_CALL formatString, argList);
    }
    return condition;
}

template <__RFF_CONDITIONAL_PARTIAL_TEMPLATE typename PointerT, __R_ENABLE_IF_IS_NOT_CLASS(PointerT)>
__RFF_CONDITIONAL_NOINLINE_TEMPLATE_METHOD(RESULT_NORETURN_NULL PointerT, FailFast_GetLastErrorIfNullMsg)
(__RFF_CONDITIONAL_FN_PARAMS _Pre_maybenull_ PointerT pointer, _Printf_format_string_ PCSTR formatString, ...) WI_NOEXCEPT {
    if (pointer == nullptr) {
        va_list argList;
        va_start(argList, formatString);
        __RFF_CALL_INTERNAL_NOINLINE_METHOD(_FailFast_GetLastErrorMsg)(__RFF_CONDITIONAL_NOINLINE_FN_CALL formatString, argList);
    }
    return pointer;
}

template <__RFF_CONDITIONAL_PARTIAL_TEMPLATE typename PointerT, __R_ENABLE_IF_IS_CLASS(PointerT)>
__RFF_CONDITIONAL_NOINLINE_TEMPLATE_METHOD(RESULT_NORETURN_NULL void, FailFast_GetLastErrorIfNullMsg)
(__RFF_CONDITIONAL_FN_PARAMS _In_opt_ const PointerT& pointer, _Printf_format_string_ PCSTR formatString, ...) WI_NOEXCEPT {
    if (pointer == nullptr) {
        va_list argList;
        va_start(argList, formatString);
        __RFF_CALL_INTERNAL_NOINLINE_METHOD(_FailFast_GetLastErrorMsg)(__RFF_CONDITIONAL_NOINLINE_FN_CALL formatString, argList);
    }
}

__RFF_CONDITIONAL_NOINLINE_METHOD(NTSTATUS, FailFast_IfNtStatusFailedMsg)
(__RFF_CONDITIONAL_FN_PARAMS NTSTATUS status, _Printf_format_string_ PCSTR formatString, ...) WI_NOEXCEPT {
    if (FAILED_NTSTATUS(status)) {
        va_list argList;
        va_start(argList, formatString);
        __RFF_CALL_INTERNAL_NOINLINE_METHOD(_FailFast_NtStatusMsg)(__RFF_CONDITIONAL_NOINLINE_FN_CALL status, formatString, argList);
    }
    return status;
}

__RFF_DIRECT_NORET_METHOD(void, FailFast_Unexpected)(__RFF_DIRECT_FN_PARAMS_ONLY) WI_NOEXCEPT {
    __RFF_FN_LOCALS;
    wil::details::ReportFailure_Hr(__RFF_DIRECT_FN_CALL FailureType::FailFast, E_UNEXPECTED);
}

__RFF_INTERNAL_NORET_METHOD(_FailFast_Unexpected)(__RFF_INTERNAL_FN_PARAMS_ONLY) WI_NOEXCEPT {
    __RFF_FN_LOCALS;
    wil::details::ReportFailure_Hr(__RFF_INTERNAL_FN_CALL FailureType::FailFast, E_UNEXPECTED);
}

__RFF_CONDITIONAL_METHOD(bool, FailFast_If)(__RFF_CONDITIONAL_FN_PARAMS bool condition) WI_NOEXCEPT {
    if (condition) {
        __RFF_CALL_INTERNAL_METHOD(_FailFast_Unexpected)(__RFF_CONDITIONAL_FN_CALL_ONLY);
    }
    return condition;
}

__RFF_CONDITIONAL_METHOD(bool, FailFast_IfFalse)(__RFF_CONDITIONAL_FN_PARAMS bool condition) WI_NOEXCEPT {
    if (!condition) {
        __RFF_CALL_INTERNAL_METHOD(_FailFast_Unexpected)(__RFF_CONDITIONAL_FN_CALL_ONLY);
    }
    return condition;
}

template <__RFF_CONDITIONAL_PARTIAL_TEMPLATE typename PointerT, __R_ENABLE_IF_IS_NOT_CLASS(PointerT)>
__RFF_CONDITIONAL_TEMPLATE_METHOD(RESULT_NORETURN_NULL PointerT, FailFast_IfNull)
(__RFF_CONDITIONAL_FN_PARAMS _Pre_maybenull_ PointerT pointer) WI_NOEXCEPT {
    if (pointer == nullptr) {
        __RFF_CALL_INTERNAL_METHOD(_FailFast_Unexpected)(__RFF_CONDITIONAL_FN_CALL_ONLY);
    }
    return pointer;
}

template <__RFF_CONDITIONAL_PARTIAL_TEMPLATE typename PointerT, __R_ENABLE_IF_IS_CLASS(PointerT)>
__RFF_CONDITIONAL_TEMPLATE_METHOD(RESULT_NORETURN_NULL void, FailFast_IfNull)
(__RFF_CONDITIONAL_FN_PARAMS _In_opt_ const PointerT& pointer) WI_NOEXCEPT {
    if (pointer == nullptr) {
        __RFF_CALL_INTERNAL_METHOD(_FailFast_Unexpected)(__RFF_CONDITIONAL_FN_CALL_ONLY);
    }
}

__RFF_DIRECT_NORET_METHOD(void, FailFast_UnexpectedMsg)
(__RFF_DIRECT_FN_PARAMS _Printf_format_string_ PCSTR formatString, ...) WI_NOEXCEPT {
    va_list argList;
    va_start(argList, formatString);
    __RFF_FN_LOCALS;
    wil::details::ReportFailure_HrMsg(__RFF_DIRECT_FN_CALL FailureType::FailFast, E_UNEXPECTED, formatString, argList);
}

__RFF_INTERNAL_NOINLINE_NORET_METHOD(_FailFast_UnexpectedMsg)
(__RFF_INTERNAL_NOINLINE_FN_PARAMS _Printf_format_string_ PCSTR formatString, va_list argList) WI_NOEXCEPT {
    __RFF_FN_LOCALS;
    wil::details::ReportFailure_HrMsg(__RFF_INTERNAL_NOINLINE_FN_CALL FailureType::FailFast, E_UNEXPECTED, formatString, argList);
}

__RFF_CONDITIONAL_NOINLINE_METHOD(bool, FailFast_IfMsg)
(__RFF_CONDITIONAL_FN_PARAMS bool condition, _Printf_format_string_ PCSTR formatString, ...) WI_NOEXCEPT {
    if (condition) {
        va_list argList;
        va_start(argList, formatString);
        __RFF_CALL_INTERNAL_NOINLINE_METHOD(_FailFast_UnexpectedMsg)(__RFF_CONDITIONAL_NOINLINE_FN_CALL formatString, argList);
    }
    return condition;
}

__RFF_CONDITIONAL_NOINLINE_METHOD(bool, FailFast_IfFalseMsg)
(__RFF_CONDITIONAL_FN_PARAMS bool condition, _Printf_format_string_ PCSTR formatString, ...) WI_NOEXCEPT {
    if (!condition) {
        va_list argList;
        va_start(argList, formatString);
        __RFF_CALL_INTERNAL_NOINLINE_METHOD(_FailFast_UnexpectedMsg)(__RFF_CONDITIONAL_NOINLINE_FN_CALL formatString, argList);
    }
    return condition;
}

template <__RFF_CONDITIONAL_PARTIAL_TEMPLATE typename PointerT, __R_ENABLE_IF_IS_NOT_CLASS(PointerT)>
__RFF_CONDITIONAL_NOINLINE_TEMPLATE_METHOD(RESULT_NORETURN_NULL PointerT, FailFast_IfNullMsg)
(__RFF_CONDITIONAL_FN_PARAMS _Pre_maybenull_ PointerT pointer, _Printf_format_string_ PCSTR formatString, ...) WI_NOEXCEPT {
    if (pointer == nullptr) {
        va_list argList;
        va_start(argList, formatString);
        __RFF_CALL_INTERNAL_NOINLINE_METHOD(_FailFast_UnexpectedMsg)(__RFF_CONDITIONAL_NOINLINE_FN_CALL formatString, argList);
    }
    return pointer;
}

template <__RFF_CONDITIONAL_PARTIAL_TEMPLATE typename PointerT, __R_ENABLE_IF_IS_CLASS(PointerT)>
__RFF_CONDITIONAL_NOINLINE_TEMPLATE_METHOD(RESULT_NORETURN_NULL void, FailFast_IfNullMsg)
(__RFF_CONDITIONAL_FN_PARAMS _In_opt_ const PointerT& pointer, _Printf_format_string_ PCSTR formatString, ...) WI_NOEXCEPT {
    if (pointer == nullptr) {
        va_list argList;
        va_start(argList, formatString);
        __RFF_CALL_INTERNAL_NOINLINE_METHOD(_FailFast_UnexpectedMsg)(__RFF_CONDITIONAL_NOINLINE_FN_CALL formatString, argList);
    }
}

//*****************************************************************************
// FailFast Immediate Macros
//*****************************************************************************

__RFF_DIRECT_NORET_METHOD(void, FailFastImmediate_Unexpected)() WI_NOEXCEPT {
    RESULT_RAISE_FAST_FAIL_EXCEPTION;
}

__RFF_INTERNAL_NORET_METHOD(_FailFastImmediate_Unexpected)() WI_NOEXCEPT {
    RESULT_RAISE_FAST_FAIL_EXCEPTION;
}

__RFF_CONDITIONAL_METHOD(HRESULT, FailFastImmediate_IfFailed)(HRESULT hr) WI_NOEXCEPT {
    if (FAILED(hr)) {
        __RFF_CALL_INTERNAL_METHOD(_FailFastImmediate_Unexpected)();
    }
    return hr;
}

__RFF_CONDITIONAL_METHOD(bool, FailFastImmediate_If)(bool condition) WI_NOEXCEPT {
    if (condition) {
        __RFF_CALL_INTERNAL_METHOD(_FailFastImmediate_Unexpected)();
    }
    return condition;
}

__RFF_CONDITIONAL_METHOD(bool, FailFastImmediate_IfFalse)(bool condition) WI_NOEXCEPT {
    if (!condition) {
        __RFF_CALL_INTERNAL_METHOD(_FailFastImmediate_Unexpected)();
    }
    return condition;
}

template <__RFF_CONDITIONAL_PARTIAL_TEMPLATE typename PointerT, __R_ENABLE_IF_IS_NOT_CLASS(PointerT)>
__RFF_CONDITIONAL_TEMPLATE_METHOD(RESULT_NORETURN_NULL PointerT, FailFastImmediate_IfNull)
(_Pre_maybenull_ PointerT pointer) WI_NOEXCEPT {
    if (pointer == nullptr) {
        __RFF_CALL_INTERNAL_METHOD(_FailFastImmediate_Unexpected)();
    }
    return pointer;
}

template <__RFF_CONDITIONAL_PARTIAL_TEMPLATE typename PointerT, __R_ENABLE_IF_IS_CLASS(PointerT)>
__RFF_CONDITIONAL_TEMPLATE_METHOD(RESULT_NORETURN_NULL void, FailFastImmediate_IfNull)
(_In_opt_ const PointerT& pointer) WI_NOEXCEPT {
    if (pointer == nullptr) {
        __RFF_CALL_INTERNAL_METHOD(_FailFastImmediate_Unexpected)();
    }
}

__RFF_CONDITIONAL_METHOD(NTSTATUS, FailFastImmediate_IfNtStatusFailed)(NTSTATUS status) WI_NOEXCEPT {
    if (FAILED_NTSTATUS(status)) {
        __RFF_CALL_INTERNAL_METHOD(_FailFastImmediate_Unexpected)();
    }
    return status;
}
} // namespace __RFF_NS_NAME

namespace __R_NS_NAME {
//*****************************************************************************
// Exception Macros
//*****************************************************************************

#ifdef WIL_ENABLE_EXCEPTIONS
__R_DIRECT_NORET_METHOD(void, Throw_Hr)(__R_DIRECT_FN_PARAMS HRESULT hr) {
    __R_FN_LOCALS;
    wil::details::ReportFailure_Hr(__R_DIRECT_FN_CALL FailureType::Exception, hr);
}

__R_DIRECT_NORET_METHOD(void, Throw_Win32)(__R_DIRECT_FN_PARAMS DWORD err) {
    __R_FN_LOCALS;
    wil::details::ReportFailure_Win32(__R_DIRECT_FN_CALL FailureType::Exception, err);
}

__R_DIRECT_NORET_METHOD(void, Throw_GetLastError)(__R_DIRECT_FN_PARAMS_ONLY) {
    __R_FN_LOCALS;
    wil::details::ReportFailure_GetLastError(__R_DIRECT_FN_CALL FailureType::Exception);
}

__R_DIRECT_NORET_METHOD(void, Throw_NtStatus)(__R_DIRECT_FN_PARAMS NTSTATUS status) {
    __R_FN_LOCALS;
    wil::details::ReportFailure_NtStatus(__R_DIRECT_FN_CALL FailureType::Exception, status);
}

__R_INTERNAL_NORET_METHOD(_Throw_Hr)(__R_INTERNAL_FN_PARAMS HRESULT hr) {
    __R_FN_LOCALS;
    wil::details::ReportFailure_Hr(__R_INTERNAL_FN_CALL FailureType::Exception, hr);
}

__R_INTERNAL_NORET_METHOD(_Throw_GetLastError)(__R_INTERNAL_FN_PARAMS_ONLY) {
    __R_FN_LOCALS;
    wil::details::ReportFailure_GetLastError(__R_INTERNAL_FN_CALL FailureType::Exception);
}

__R_INTERNAL_NORET_METHOD(_Throw_Win32)(__R_INTERNAL_FN_PARAMS DWORD err) {
    __R_FN_LOCALS;
    wil::details::ReportFailure_Win32(__R_INTERNAL_FN_CALL FailureType::Exception, err);
}

__R_INTERNAL_NORET_METHOD(_Throw_NullAlloc)(__R_INTERNAL_FN_PARAMS_ONLY) {
    __R_FN_LOCALS;
    wil::details::ReportFailure_Hr(__R_INTERNAL_FN_CALL FailureType::Exception, E_OUTOFMEMORY);
}

__R_INTERNAL_NORET_METHOD(_Throw_NtStatus)(__R_INTERNAL_FN_PARAMS NTSTATUS status) {
    __R_FN_LOCALS;
    wil::details::ReportFailure_NtStatus(__R_INTERNAL_FN_CALL FailureType::Exception, status);
}

__R_CONDITIONAL_METHOD(HRESULT, Throw_IfFailed)(__R_CONDITIONAL_FN_PARAMS HRESULT hr) {
    if (FAILED(hr)) {
        __R_CALL_INTERNAL_METHOD(_Throw_Hr)(__R_CONDITIONAL_FN_CALL hr);
    }
    return hr;
}

__R_CONDITIONAL_METHOD(BOOL, Throw_IfWin32BoolFalse)(__R_CONDITIONAL_FN_PARAMS BOOL ret) {
    if (!ret) {
        __R_CALL_INTERNAL_METHOD(_Throw_GetLastError)(__R_CONDITIONAL_FN_CALL_ONLY);
    }
    return ret;
}

__R_CONDITIONAL_METHOD(DWORD, Throw_IfWin32Error)(__R_CONDITIONAL_FN_PARAMS DWORD err) {
    if (FAILED_WIN32(err)) {
        __R_CALL_INTERNAL_METHOD(_Throw_Win32)(__R_CONDITIONAL_FN_CALL err);
    }
    return err;
}

__R_CONDITIONAL_METHOD(HANDLE, Throw_IfHandleInvalid)(__R_CONDITIONAL_FN_PARAMS HANDLE handle) {
    if (handle == INVALID_HANDLE_VALUE) {
        __R_CALL_INTERNAL_METHOD(_Throw_GetLastError)(__R_CONDITIONAL_FN_CALL_ONLY);
    }
    return handle;
}

__R_CONDITIONAL_METHOD(RESULT_NORETURN_NULL HANDLE, Throw_IfHandleNull)(__R_CONDITIONAL_FN_PARAMS HANDLE handle) {
    if (handle == nullptr) {
        __R_CALL_INTERNAL_METHOD(_Throw_GetLastError)(__R_CONDITIONAL_FN_CALL_ONLY);
    }
    return handle;
}

template <__R_CONDITIONAL_PARTIAL_TEMPLATE typename PointerT, __R_ENABLE_IF_IS_NOT_CLASS(PointerT)>
__R_CONDITIONAL_TEMPLATE_METHOD(RESULT_NORETURN_NULL PointerT, Throw_IfNullAlloc)
(__R_CONDITIONAL_FN_PARAMS _Pre_maybenull_ PointerT pointer) {
    if (pointer == nullptr) {
        __R_CALL_INTERNAL_METHOD(_Throw_NullAlloc)(__R_CONDITIONAL_FN_CALL_ONLY);
    }
    return pointer;
}

template <__R_CONDITIONAL_PARTIAL_TEMPLATE typename PointerT, __R_ENABLE_IF_IS_CLASS(PointerT)>
__R_CONDITIONAL_TEMPLATE_METHOD(void, Throw_IfNullAlloc)
(__R_CONDITIONAL_FN_PARAMS const PointerT& pointer) {
    if (pointer == nullptr) {
        __R_CALL_INTERNAL_METHOD(_Throw_NullAlloc)(__R_CONDITIONAL_FN_CALL_ONLY);
    }
}

__R_CONDITIONAL_METHOD(bool, Throw_HrIf)(__R_CONDITIONAL_FN_PARAMS HRESULT hr, bool condition) {
    if (condition) {
        __R_CALL_INTERNAL_METHOD(_Throw_Hr)(__R_CONDITIONAL_FN_CALL hr);
    }
    return condition;
}

__R_CONDITIONAL_METHOD(bool, Throw_HrIfFalse)(__R_CONDITIONAL_FN_PARAMS HRESULT hr, bool condition) {
    if (!condition) {
        __R_CALL_INTERNAL_METHOD(_Throw_Hr)(__R_CONDITIONAL_FN_CALL hr);
    }
    return condition;
}

template <__R_CONDITIONAL_PARTIAL_TEMPLATE typename PointerT, __R_ENABLE_IF_IS_NOT_CLASS(PointerT)>
__R_CONDITIONAL_TEMPLATE_METHOD(RESULT_NORETURN_NULL PointerT, Throw_HrIfNull)
(__R_CONDITIONAL_FN_PARAMS HRESULT hr, _Pre_maybenull_ PointerT pointer) {
    if (pointer == nullptr) {
        __R_CALL_INTERNAL_METHOD(_Throw_Hr)(__R_CONDITIONAL_FN_CALL hr);
    }
    return pointer;
}

template <__R_CONDITIONAL_PARTIAL_TEMPLATE typename PointerT, __R_ENABLE_IF_IS_CLASS(PointerT)>
__R_CONDITIONAL_TEMPLATE_METHOD(void, Throw_HrIfNull)
(__R_CONDITIONAL_FN_PARAMS HRESULT hr, _In_opt_ const PointerT& pointer) {
    if (pointer == nullptr) {
        __R_CALL_INTERNAL_METHOD(_Throw_Hr)(__R_CONDITIONAL_FN_CALL hr);
    }
}

__R_CONDITIONAL_METHOD(bool, Throw_GetLastErrorIf)(__R_CONDITIONAL_FN_PARAMS bool condition) {
    if (condition) {
        __R_CALL_INTERNAL_METHOD(_Throw_GetLastError)(__R_CONDITIONAL_FN_CALL_ONLY);
    }
    return condition;
}

__R_CONDITIONAL_METHOD(bool, Throw_GetLastErrorIfFalse)(__R_CONDITIONAL_FN_PARAMS bool condition) {
    if (!condition) {
        __R_CALL_INTERNAL_METHOD(_Throw_GetLastError)(__R_CONDITIONAL_FN_CALL_ONLY);
    }
    return condition;
}

template <__R_CONDITIONAL_PARTIAL_TEMPLATE typename PointerT, __R_ENABLE_IF_IS_NOT_CLASS(PointerT)>
__R_CONDITIONAL_TEMPLATE_METHOD(RESULT_NORETURN_NULL PointerT, Throw_GetLastErrorIfNull)
(__R_CONDITIONAL_FN_PARAMS _Pre_maybenull_ PointerT pointer) {
    if (pointer == nullptr) {
        __R_CALL_INTERNAL_METHOD(_Throw_GetLastError)(__R_CONDITIONAL_FN_CALL_ONLY);
    }
    return pointer;
}

template <__R_CONDITIONAL_PARTIAL_TEMPLATE typename PointerT, __R_ENABLE_IF_IS_CLASS(PointerT)>
__R_CONDITIONAL_TEMPLATE_METHOD(RESULT_NORETURN_NULL void, Throw_GetLastErrorIfNull)
(__R_CONDITIONAL_FN_PARAMS _In_opt_ const PointerT& pointer) {
    if (pointer == nullptr) {
        __R_CALL_INTERNAL_METHOD(_Throw_GetLastError)(__R_CONDITIONAL_FN_CALL_ONLY);
    }
}

__R_CONDITIONAL_METHOD(NTSTATUS, Throw_IfNtStatusFailed)(__R_CONDITIONAL_FN_PARAMS NTSTATUS status) {
    if (FAILED_NTSTATUS(status)) {
        __R_CALL_INTERNAL_METHOD(_Throw_NtStatus)(__R_CONDITIONAL_FN_CALL status);
    }
    return status;
}

__R_DIRECT_METHOD(void, Throw_HrMsg)(__R_DIRECT_FN_PARAMS HRESULT hr, _Printf_format_string_ PCSTR formatString, ...) {
    va_list argList;
    va_start(argList, formatString);
    __R_FN_LOCALS;
    wil::details::ReportFailure_HrMsg(__R_DIRECT_FN_CALL FailureType::Exception, hr, formatString, argList);
}

__R_DIRECT_METHOD(void, Throw_Win32Msg)(__R_DIRECT_FN_PARAMS DWORD err, _Printf_format_string_ PCSTR formatString, ...) {
    va_list argList;
    va_start(argList, formatString);
    __R_FN_LOCALS;
    wil::details::ReportFailure_Win32Msg(__R_DIRECT_FN_CALL FailureType::Exception, err, formatString, argList);
}

__R_DIRECT_METHOD(void, Throw_GetLastErrorMsg)(__R_DIRECT_FN_PARAMS _Printf_format_string_ PCSTR formatString, ...) {
    va_list argList;
    va_start(argList, formatString);
    __R_FN_LOCALS;
    wil::details::ReportFailure_GetLastErrorMsg(__R_DIRECT_FN_CALL FailureType::Exception, formatString, argList);
}

__R_DIRECT_METHOD(void, Throw_NtStatusMsg)(__R_DIRECT_FN_PARAMS NTSTATUS status, _Printf_format_string_ PCSTR formatString, ...) {
    va_list argList;
    va_start(argList, formatString);
    __R_FN_LOCALS;
    wil::details::ReportFailure_NtStatusMsg(__R_DIRECT_FN_CALL FailureType::Exception, status, formatString, argList);
}

__R_INTERNAL_NOINLINE_METHOD(_Throw_HrMsg)
(__R_INTERNAL_NOINLINE_FN_PARAMS HRESULT hr, _Printf_format_string_ PCSTR formatString, va_list argList) {
    __R_FN_LOCALS;
    wil::details::ReportFailure_HrMsg(__R_INTERNAL_NOINLINE_FN_CALL FailureType::Exception, hr, formatString, argList);
}

__R_INTERNAL_NOINLINE_METHOD(_Throw_GetLastErrorMsg)
(__R_INTERNAL_NOINLINE_FN_PARAMS _Printf_format_string_ PCSTR formatString, va_list argList) {
    __R_FN_LOCALS;
    wil::details::ReportFailure_GetLastErrorMsg(__R_INTERNAL_NOINLINE_FN_CALL FailureType::Exception, formatString, argList);
}

__R_INTERNAL_NOINLINE_METHOD(_Throw_Win32Msg)
(__R_INTERNAL_NOINLINE_FN_PARAMS DWORD err, _Printf_format_string_ PCSTR formatString, va_list argList) {
    __R_FN_LOCALS;
    wil::details::ReportFailure_Win32Msg(__R_INTERNAL_NOINLINE_FN_CALL FailureType::Exception, err, formatString, argList);
}

__R_INTERNAL_NOINLINE_METHOD(_Throw_NullAllocMsg)
(__R_INTERNAL_NOINLINE_FN_PARAMS _Printf_format_string_ PCSTR formatString, va_list argList) {
    __R_FN_LOCALS;
    wil::details::ReportFailure_HrMsg(__R_INTERNAL_NOINLINE_FN_CALL FailureType::Exception, E_OUTOFMEMORY, formatString, argList);
}

__R_INTERNAL_NOINLINE_METHOD(_Throw_NtStatusMsg)
(__R_INTERNAL_NOINLINE_FN_PARAMS NTSTATUS status, _Printf_format_string_ PCSTR formatString, va_list argList) {
    __R_FN_LOCALS;
    wil::details::ReportFailure_NtStatusMsg(__R_INTERNAL_NOINLINE_FN_CALL FailureType::Exception, status, formatString, argList);
}

__R_CONDITIONAL_NOINLINE_METHOD(HRESULT, Throw_IfFailedMsg)
(__R_CONDITIONAL_FN_PARAMS HRESULT hr, _Printf_format_string_ PCSTR formatString, ...) {
    if (FAILED(hr)) {
        va_list argList;
        va_start(argList, formatString);
        __R_CALL_INTERNAL_NOINLINE_METHOD(_Throw_HrMsg)(__R_CONDITIONAL_NOINLINE_FN_CALL hr, formatString, argList);
    }
    return hr;
}

__R_CONDITIONAL_NOINLINE_METHOD(BOOL, Throw_IfWin32BoolFalseMsg)
(__R_CONDITIONAL_FN_PARAMS BOOL ret, _Printf_format_string_ PCSTR formatString, ...) {
    if (!ret) {
        va_list argList;
        va_start(argList, formatString);
        __R_CALL_INTERNAL_NOINLINE_METHOD(_Throw_GetLastErrorMsg)(__R_CONDITIONAL_NOINLINE_FN_CALL formatString, argList);
    }
    return ret;
}

__R_CONDITIONAL_NOINLINE_METHOD(DWORD, Throw_IfWin32ErrorMsg)
(__R_CONDITIONAL_FN_PARAMS DWORD err, _Printf_format_string_ PCSTR formatString, ...) {
    if (FAILED_WIN32(err)) {
        va_list argList;
        va_start(argList, formatString);
        __R_CALL_INTERNAL_NOINLINE_METHOD(_Throw_Win32Msg)(__R_CONDITIONAL_NOINLINE_FN_CALL err, formatString, argList);
    }
    return err;
}

__R_CONDITIONAL_NOINLINE_METHOD(HANDLE, Throw_IfHandleInvalidMsg)
(__R_CONDITIONAL_FN_PARAMS HANDLE handle, _Printf_format_string_ PCSTR formatString, ...) {
    if (handle == INVALID_HANDLE_VALUE) {
        va_list argList;
        va_start(argList, formatString);
        __R_CALL_INTERNAL_NOINLINE_METHOD(_Throw_GetLastErrorMsg)(__R_CONDITIONAL_NOINLINE_FN_CALL formatString, argList);
    }
    return handle;
}

__R_CONDITIONAL_NOINLINE_METHOD(RESULT_NORETURN_NULL HANDLE, Throw_IfHandleNullMsg)
(__R_CONDITIONAL_FN_PARAMS HANDLE handle, _Printf_format_string_ PCSTR formatString, ...) {
    if (handle == nullptr) {
        va_list argList;
        va_start(argList, formatString);
        __R_CALL_INTERNAL_NOINLINE_METHOD(_Throw_GetLastErrorMsg)(__R_CONDITIONAL_NOINLINE_FN_CALL formatString, argList);
    }
    return handle;
}

template <__R_CONDITIONAL_PARTIAL_TEMPLATE typename PointerT, __R_ENABLE_IF_IS_NOT_CLASS(PointerT)>
__R_CONDITIONAL_NOINLINE_TEMPLATE_METHOD(RESULT_NORETURN_NULL PointerT, Throw_IfNullAllocMsg)
(__R_CONDITIONAL_FN_PARAMS _Pre_maybenull_ PointerT pointer, _Printf_format_string_ PCSTR formatString, ...) {
    if (pointer == nullptr) {
        va_list argList;
        va_start(argList, formatString);
        __R_CALL_INTERNAL_NOINLINE_METHOD(_Throw_NullAllocMsg)(__R_CONDITIONAL_NOINLINE_FN_CALL_ONLY, formatString, argList);
    }
    return pointer;
}

template <__R_CONDITIONAL_PARTIAL_TEMPLATE typename PointerT, __R_ENABLE_IF_IS_CLASS(PointerT)>
__R_CONDITIONAL_NOINLINE_TEMPLATE_METHOD(RESULT_NORETURN_NULL void, Throw_IfNullAllocMsg)
(__R_CONDITIONAL_FN_PARAMS const PointerT& pointer, _Printf_format_string_ PCSTR formatString, ...) {
    if (pointer == nullptr) {
        va_list argList;
        va_start(argList, formatString);
        __R_CALL_INTERNAL_NOINLINE_METHOD(_Throw_NullAllocMsg)(__R_CONDITIONAL_NOINLINE_FN_CALL_ONLY, formatString, argList);
    }
}

__R_CONDITIONAL_NOINLINE_METHOD(bool, Throw_HrIfMsg)
(__R_CONDITIONAL_FN_PARAMS HRESULT hr, bool condition, _Printf_format_string_ PCSTR formatString, ...) {
    if (condition) {
        va_list argList;
        va_start(argList, formatString);
        __R_CALL_INTERNAL_NOINLINE_METHOD(_Throw_HrMsg)(__R_CONDITIONAL_NOINLINE_FN_CALL hr, formatString, argList);
    }
    return condition;
}

__R_CONDITIONAL_NOINLINE_METHOD(bool, Throw_HrIfFalseMsg)
(__R_CONDITIONAL_FN_PARAMS HRESULT hr, bool condition, _Printf_format_string_ PCSTR formatString, ...) {
    if (!condition) {
        va_list argList;
        va_start(argList, formatString);
        __R_CALL_INTERNAL_NOINLINE_METHOD(_Throw_HrMsg)(__R_CONDITIONAL_NOINLINE_FN_CALL hr, formatString, argList);
    }
    return condition;
}

template <__R_CONDITIONAL_PARTIAL_TEMPLATE typename PointerT, __R_ENABLE_IF_IS_NOT_CLASS(PointerT)>
__R_CONDITIONAL_NOINLINE_TEMPLATE_METHOD(RESULT_NORETURN_NULL PointerT, Throw_HrIfNullMsg)
(__R_CONDITIONAL_FN_PARAMS HRESULT hr, _Pre_maybenull_ PointerT pointer, _Printf_format_string_ PCSTR formatString, ...) {
    if (pointer == nullptr) {
        va_list argList;
        va_start(argList, formatString);
        __R_CALL_INTERNAL_NOINLINE_METHOD(_Throw_HrMsg)(__R_CONDITIONAL_NOINLINE_FN_CALL hr, formatString, argList);
    }
    return pointer;
}

template <__R_CONDITIONAL_PARTIAL_TEMPLATE typename PointerT, __R_ENABLE_IF_IS_CLASS(PointerT)>
__R_CONDITIONAL_NOINLINE_TEMPLATE_METHOD(void, Throw_HrIfNullMsg)
(__R_CONDITIONAL_FN_PARAMS HRESULT hr, _In_opt_ const PointerT& pointer, _Printf_format_string_ PCSTR formatString, ...) {
    if (pointer == nullptr) {
        va_list argList;
        va_start(argList, formatString);
        __R_CALL_INTERNAL_NOINLINE_METHOD(_Throw_HrMsg)(__R_CONDITIONAL_NOINLINE_FN_CALL hr, formatString, argList);
    }
}

__R_CONDITIONAL_NOINLINE_METHOD(bool, Throw_GetLastErrorIfMsg)
(__R_CONDITIONAL_FN_PARAMS bool condition, _Printf_format_string_ PCSTR formatString, ...) {
    if (condition) {
        va_list argList;
        va_start(argList, formatString);
        __R_CALL_INTERNAL_NOINLINE_METHOD(_Throw_GetLastErrorMsg)(__R_CONDITIONAL_NOINLINE_FN_CALL formatString, argList);
    }
    return condition;
}

__R_CONDITIONAL_NOINLINE_METHOD(bool, Throw_GetLastErrorIfFalseMsg)
(__R_CONDITIONAL_FN_PARAMS bool condition, _Printf_format_string_ PCSTR formatString, ...) {
    if (!condition) {
        va_list argList;
        va_start(argList, formatString);
        __R_CALL_INTERNAL_NOINLINE_METHOD(_Throw_GetLastErrorMsg)(__R_CONDITIONAL_NOINLINE_FN_CALL formatString, argList);
    }
    return condition;
}

template <__R_CONDITIONAL_PARTIAL_TEMPLATE typename PointerT, __R_ENABLE_IF_IS_NOT_CLASS(PointerT)>
__R_CONDITIONAL_NOINLINE_TEMPLATE_METHOD(RESULT_NORETURN_NULL PointerT, Throw_GetLastErrorIfNullMsg)
(__R_CONDITIONAL_FN_PARAMS _Pre_maybenull_ PointerT pointer, _Printf_format_string_ PCSTR formatString, ...) {
    if (pointer == nullptr) {
        va_list argList;
        va_start(argList, formatString);
        __R_CALL_INTERNAL_NOINLINE_METHOD(_Throw_GetLastErrorMsg)(__R_CONDITIONAL_NOINLINE_FN_CALL formatString, argList);
    }
    return pointer;
}

template <__R_CONDITIONAL_PARTIAL_TEMPLATE typename PointerT, __R_ENABLE_IF_IS_CLASS(PointerT)>
__R_CONDITIONAL_NOINLINE_TEMPLATE_METHOD(RESULT_NORETURN_NULL void, Throw_GetLastErrorIfNullMsg)
(__R_CONDITIONAL_FN_PARAMS _In_opt_ const PointerT& pointer, _Printf_format_string_ PCSTR formatString, ...) {
    if (pointer == nullptr) {
        va_list argList;
        va_start(argList, formatString);
        __R_CALL_INTERNAL_NOINLINE_METHOD(_Throw_GetLastErrorMsg)(__R_CONDITIONAL_NOINLINE_FN_CALL formatString, argList);
    }
}

__R_CONDITIONAL_NOINLINE_METHOD(NTSTATUS, Throw_IfNtStatusFailedMsg)
(__R_CONDITIONAL_FN_PARAMS NTSTATUS status, _Printf_format_string_ PCSTR formatString, ...) {
    if (FAILED_NTSTATUS(status)) {
        va_list argList;
        va_start(argList, formatString);
        __R_CALL_INTERNAL_NOINLINE_METHOD(_Throw_NtStatusMsg)(__R_CONDITIONAL_NOINLINE_FN_CALL status, formatString, argList);
    }
    return status;
}

__R_DIRECT_NORET_METHOD(void, Objc_Throw_HrMsg)(__R_DIRECT_FN_PARAMS HRESULT hr, _Printf_format_string_ PCSTR formatString, ...) {
    __R_FN_LOCALS;
    va_list argList;
    va_start(argList, formatString);
    wil::details::ReportFailure_HrMsg(__R_DIRECT_FN_CALL FailureType::ObjCException, hr, formatString, argList);
}

__R_INTERNAL_NORET_METHOD(_Objc_Throw_Hr)(__R_INTERNAL_FN_PARAMS HRESULT hr) {
    __R_FN_LOCALS;
    wil::details::ReportFailure_Hr(__R_DIRECT_FN_CALL FailureType::ObjCException, hr);
}

__R_CONDITIONAL_METHOD(void, Objc_Throw_IfFailed)(__R_CONDITIONAL_FN_PARAMS HRESULT hr) {
    if (FAILED(hr)) {
        __R_CALL_INTERNAL_METHOD(_Objc_Throw_Hr)(__R_CONDITIONAL_FN_CALL hr);
    }
}

__R_INTERNAL_NOINLINE_METHOD(_Objc_Throw_HrMsg)
(__R_INTERNAL_NOINLINE_FN_PARAMS HRESULT hr, _Printf_format_string_ PCSTR formatString, va_list argList) {
    __R_FN_LOCALS;
    wil::details::ReportFailure_HrMsg(__R_INTERNAL_NOINLINE_FN_CALL FailureType::ObjCException, hr, formatString, argList);
}

__R_CONDITIONAL_NOINLINE_METHOD(void, Objc_Throw_IfFailedMsg)(__R_CONDITIONAL_FN_PARAMS HRESULT hr, _Printf_format_string_ PCSTR formatString, ...) {
    if (FAILED(hr)) {
        va_list argList;
        va_start(argList, formatString);
        __R_CALL_INTERNAL_NOINLINE_METHOD(_Objc_Throw_HrMsg)(__R_CONDITIONAL_NOINLINE_FN_CALL hr, formatString, argList);
    }
}

__R_CONDITIONAL_METHOD(bool, Objc_Throw_HrIf)(__R_CONDITIONAL_FN_PARAMS HRESULT hr, bool condition) {
    if (condition) {
        __R_CALL_INTERNAL_METHOD(_Objc_Throw_Hr)(__R_CONDITIONAL_FN_CALL hr);
    }
    return condition;
}

__R_CONDITIONAL_METHOD(bool, Objc_Throw_HrIfFalse)(__R_CONDITIONAL_FN_PARAMS HRESULT hr, bool condition) {
    if (!condition) {
        __R_CALL_INTERNAL_METHOD(_Objc_Throw_Hr)(__R_CONDITIONAL_FN_CALL hr);
    }
    return condition;
}

__R_CONDITIONAL_NOINLINE_METHOD(bool, Objc_Throw_HrIfMsg)
(__R_CONDITIONAL_FN_PARAMS HRESULT hr, bool condition, _Printf_format_string_ PCSTR formatString, ...) {
    if (condition) {
        va_list argList;
        va_start(argList, formatString);
        __R_CALL_INTERNAL_NOINLINE_METHOD(_Objc_Throw_HrMsg)(__R_CONDITIONAL_NOINLINE_FN_CALL hr, formatString, argList);
    }
    return condition;
}

__R_CONDITIONAL_NOINLINE_METHOD(bool, Objc_Throw_HrIfFalseMsg)
(__R_CONDITIONAL_FN_PARAMS HRESULT hr, bool condition, _Printf_format_string_ PCSTR formatString, ...) {
    if (!condition) {
        va_list argList;
        va_start(argList, formatString);
        __R_CALL_INTERNAL_NOINLINE_METHOD(_Objc_Throw_HrMsg)(__R_CONDITIONAL_NOINLINE_FN_CALL hr, formatString, argList);
    }
    return condition;
}

template <__R_CONDITIONAL_PARTIAL_TEMPLATE typename PointerT, __R_ENABLE_IF_IS_NOT_CLASS(PointerT)>
__R_CONDITIONAL_TEMPLATE_METHOD(RESULT_NORETURN_NULL PointerT, Objc_Throw_HrIfNull)
(__R_CONDITIONAL_FN_PARAMS HRESULT hr, _Pre_maybenull_ PointerT pointer) {
    if (pointer == nullptr) {
        __R_CALL_INTERNAL_METHOD(_Objc_Throw_Hr)(__R_CONDITIONAL_FN_CALL hr);
    }
    return pointer;
}

template <__R_CONDITIONAL_PARTIAL_TEMPLATE typename PointerT, __R_ENABLE_IF_IS_CLASS(PointerT)>
__R_CONDITIONAL_TEMPLATE_METHOD(void, Objc_Throw_HrIfNull)
(__R_CONDITIONAL_FN_PARAMS HRESULT hr, _In_opt_ const PointerT& pointer) {
    if (pointer == nullptr) {
        __R_CALL_INTERNAL_METHOD(_Objc_Throw_Hr)(__R_CONDITIONAL_FN_CALL hr);
    }
}

template <__R_CONDITIONAL_PARTIAL_TEMPLATE typename PointerT, __R_ENABLE_IF_IS_NOT_CLASS(PointerT)>
__R_CONDITIONAL_NOINLINE_TEMPLATE_METHOD(RESULT_NORETURN_NULL PointerT, Objc_Throw_HrIfNullMsg)
(__R_CONDITIONAL_FN_PARAMS HRESULT hr, _Pre_maybenull_ PointerT pointer, _Printf_format_string_ PCSTR formatString, ...) {
    if (pointer == nullptr) {
        va_list argList;
        va_start(argList, formatString);
        __R_CALL_INTERNAL_NOINLINE_METHOD(_Objc_Throw_HrMsg)(__R_CONDITIONAL_NOINLINE_FN_CALL hr, formatString, argList);
    }
    return pointer;
}

template <__R_CONDITIONAL_PARTIAL_TEMPLATE typename PointerT, __R_ENABLE_IF_IS_CLASS(PointerT)>
__R_CONDITIONAL_NOINLINE_TEMPLATE_METHOD(void, Objc_Throw_HrIfNullMsg)
(__R_CONDITIONAL_FN_PARAMS HRESULT hr, _In_opt_ const PointerT& pointer, _Printf_format_string_ PCSTR formatString, ...) {
    if (pointer == nullptr) {
        va_list argList;
        va_start(argList, formatString);
        __R_CALL_INTERNAL_NOINLINE_METHOD(_Objc_Throw_HrMsg)(__R_CONDITIONAL_NOINLINE_FN_CALL hr, formatString, argList);
    }
}

#endif // WIL_ENABLE_EXCEPTIONS

} // __R_NS_NAME namespace
} // details namespace
//! @endcond

//*****************************************************************************
// Error Handling Policies to switch between error-handling style
//*****************************************************************************
// The following policies are used as template policies for components that can support exception, fail-fast, and
// error-code based modes.

// Use for classes which should return HRESULTs as their error-handling policy
struct err_returncode_policy {
    typedef HRESULT result;

    __forceinline static HRESULT Win32BOOL(BOOL fReturn) {
        RETURN_IF_WIN32_BOOL_FALSE(fReturn);
        return S_OK;
    }
    __forceinline static HRESULT Win32Handle(HANDLE h, _Out_ HANDLE* ph) {
        *ph = h;
        RETURN_IF_HANDLE_NULL(h);
        return S_OK;
    }
    _Post_satisfies_(return == hr) __forceinline static HRESULT HResult(HRESULT hr) {
        RETURN_HR(hr);
    }
    __forceinline static HRESULT LastError() {
        RETURN_LAST_ERROR();
    }
    __forceinline static HRESULT LastErrorIfFalse(bool condition) {
        if (!condition) {
            RETURN_LAST_ERROR();
        }
        return S_OK;
    }
    _Post_satisfies_(return == S_OK) __forceinline static HRESULT OK() {
        return S_OK;
    }
};

// Use for classes which fail-fast on errors
struct err_failfast_policy {
    typedef _Return_type_success_(true) void result;
    __forceinline static result Win32BOOL(BOOL fReturn) {
        FAIL_FAST_IF_WIN32_BOOL_FALSE(fReturn);
    }
    __forceinline static result Win32Handle(HANDLE h, _Out_ HANDLE* ph) {
        *ph = h;
        FAIL_FAST_IF_HANDLE_NULL(h);
    }
    _When_(FAILED(hr), _Analysis_noreturn_) __forceinline static result HResult(HRESULT hr) {
        FAIL_FAST_IF_FAILED(hr);
    }
    __forceinline static result LastError() {
        FAIL_FAST_LAST_ERROR();
    }
    __forceinline static result LastErrorIfFalse(bool condition) {
        if (!condition) {
            FAIL_FAST_LAST_ERROR();
        }
    }
    __forceinline static result OK() {
    }
};

#ifdef WIL_ENABLE_EXCEPTIONS
// Use for classes which should return through exceptions as their error-handling policy
struct err_exception_policy {
    typedef _Return_type_success_(true) void result;
    __forceinline static result Win32BOOL(BOOL fReturn) {
        THROW_IF_WIN32_BOOL_FALSE(fReturn);
    }
    __forceinline static result Win32Handle(HANDLE h, _Out_ HANDLE* ph) {
        *ph = h;
        THROW_IF_HANDLE_NULL(h);
    }
    _When_(FAILED(hr), _Analysis_noreturn_) __forceinline static result HResult(HRESULT hr) {
        THROW_IF_FAILED(hr);
    }
    __forceinline static result LastError() {
        THROW_LAST_ERROR();
    }
    __forceinline static result LastErrorIfFalse(bool condition) {
        if (!condition) {
            THROW_LAST_ERROR();
        }
    }
    __forceinline static result OK() {
    }
};
#endif

} // namespace wil

#if defined(__OBJC__) && !defined(WIL_IGNORE_OBJC_EXCEPTIONS)

#import <Foundation/NSError.h>
#import <Foundation/NSNumber.h>
#import <Foundation/NSString.h>
#import <Foundation/NSException.h>
#import <Foundation/NSDictionary.h>

namespace {
static NSString* const g_winobjcDomain = @"WinObjCErrorDomain";
static NSString* const g_hresultDomain = @"HRESULTErrorDomain";
static NSString* const g_NSHResultErrorDictKey = @"hresult";

NSString* _NSStringFromHResult(HRESULT hr) {
    wchar_t errorText[256];
    errorText[0] = L'\0';
    auto strLen = FormatMessageW(FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS,
                                 nullptr,
                                 hr,
                                 MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
                                 errorText,
                                 ARRAYSIZE(errorText),
                                 nullptr);

    return [NSString stringWithCharacters:reinterpret_cast<const unichar*>(errorText) length:strLen];
}

// Create the extra information we can communicate as part of the exception:
NSDictionary* _createFailureInfoDict(const wil::FailureInfo& fi) {
    return @{
        @"file" : [NSString stringWithUTF8String:fi.pszFile],
        @"function" : [NSString stringWithUTF8String:fi.pszFunction],
        @"line" : [NSNumber numberWithInt:fi.uLineNumber],
        g_NSHResultErrorDictKey : [NSNumber numberWithInt:fi.hr],
        NSLocalizedDescriptionKey : [NSString stringWithFormat:@"0x%lx: %@", (unsigned long)fi.hr, _NSStringFromHResult(fi.hr)],
    };
}

// Construct an NSError for the out parameter representing a failure info from WRL:
NSError* _NSErrorFromFailureInfo(const wil::FailureInfo& fi) {
    return [NSError errorWithDomain:g_hresultDomain code:fi.hr userInfo:_createFailureInfoDict(fi)];
}

// This is a helper to create NSExceptions from HRESULTs:
NSException* _NSExceptionFromFailureInfo(const wil::FailureInfo& fi) {
    NSString* msg = [NSString string];
    if (fi.pszMessage) {
        msg = [NSString stringWithCharacters:reinterpret_cast<const unichar*>(fi.pszMessage) length:wcslen(fi.pszMessage)];
    }

    return [NSException _exceptionWithHRESULT:fi.hr reason:msg userInfo:_createFailureInfoDict(fi)];
}

bool _resultFromUncaughtExceptionObjC(HRESULT* out) {
    try {
        throw;
    } catch (NSException* e) {
        *out = [e _hresult];
        return true;
    }

    return false;
}

void _rethrowAsNSException() {
    try {
        throw;
    } catch (NSException*) {
        // Already an NSException and we need to catch it so the catch (...) doesn't:
        throw;
    } catch (const wil::ResultException& re) {
        @throw _NSExceptionFromFailureInfo(re.GetFailureInfo());
    } catch (...) {
        @throw [NSException _exceptionWithHRESULT:wil::ResultFromCaughtException()
                                           reason:_NSStringFromHResult(wil::ResultFromCaughtException())
                                         userInfo:nil];
    }
}

void _objcThrowFailureInfo(const wil::FailureInfo& fi) {
    @throw _NSExceptionFromFailureInfo(fi);
}

void __attribute__((unused)) _catchAndPopulateNSError(NSError** outError) {
    NSError* error;

    try {
        throw;
    } catch (NSException* e) {
        unsigned errorCode = E_UNEXPECTED;

        // If we have an hresult in our user dict, use that, otherwise this was unexpected:
        NSNumber* hresultValue = e.userInfo[g_NSHResultErrorDictKey];
        if (hresultValue) {
            errorCode = [hresultValue unsignedIntValue];
        }

        error = [NSError errorWithDomain:g_winobjcDomain code:errorCode userInfo:e.userInfo];
    } catch (const wil::ResultException& re) {
        error = _NSErrorFromFailureInfo(re.GetFailureInfo());
    } catch (...) {
        error = [NSError errorWithDomain:g_hresultDomain code:wil::ResultFromCaughtException() userInfo:nil];
    }

    if (outError) {
        *outError = error;
    } else {
        HRESULT code = error.code;
        LOG_HR_MSG(code, "NSError occurred where caller is ignoring value: %hs", [[error description] UTF8String]);
    }
}

void _rethrowNormalizedCaughtExceptionObjC(__R_FN_PARAMS_FULL, _In_opt_ PCWSTR message) {
    try {
        throw;
    } catch (const wil::ResultException& re) {
        // Report the exception
        auto& failure = re.GetFailureInfo();
        wil::details::ReportFailure(__R_FN_CALL_FULL,
                                    wil::FailureType::Exception,
                                    failure.hr,
                                    message,
                                    wil::details::ReportFailureOptions::SuppressAction);

        // Convert to an NSException by re-throwing with the existing failure information to maintain as much context as we can.
        wil::details::ReportFailure(failure.callerReturnAddress,
                                    failure.uLineNumber,
                                    failure.pszFile,
                                    failure.pszFunction,
                                    failure.pszCode,
                                    failure.returnAddress,
                                    wil::FailureType::Exception,
                                    failure.hr,
                                    failure.pszMessage,
                                    wil::details::ReportFailureOptions::ForceObjCException);
    } catch (NSException* e) {
        wchar_t messageString[2048];
        StringCchCopyW(messageString,
                       ARRAYSIZE(messageString),
                       reinterpret_cast<STRSAFE_LPCWSTR>([[e reason] cStringUsingEncoding:NSUnicodeStringEncoding]));
        if (message) {
            StringCchCatW(messageString, ARRAYSIZE(messageString), L" - ");
            StringCchCatW(messageString, ARRAYSIZE(messageString), message);
        }

        // Report the exception
        wil::details::ReportFailure(__R_FN_CALL_FULL,
                                    wil::FailureType::Exception,
                                    [e _hresult],
                                    messageString,
                                    wil::details::ReportFailureOptions::SuppressAction);

        // In ObjC, NSException is our normalized exception...we can re-throw it.
        throw;
    } catch (std::bad_alloc const&) {
        wil::details::ReportFailure(__R_FN_CALL_FULL, wil::FailureType::Exception, E_OUTOFMEMORY, message);
    } catch (...) {
        wil::details::RethrowUnknownCaughtException(__R_FN_CALL_FULL, message);
    }
    RESULT_RAISE_FAST_FAIL_EXCEPTION;
}
}

// Misspelling is intentional
WI_HEADER_INITITALIZATION_FUNCTION(InitializeObjCExceptions, [] {
    g_resultFromUncaughtExceptionObjC = _resultFromUncaughtExceptionObjC;
    g_rethrowAsNSException = _rethrowAsNSException;
    g_objcThrowFailureInfo = _objcThrowFailureInfo;
    g_rethrowNormalizedCaughtExceptionObjC = _rethrowNormalizedCaughtExceptionObjC;
    return 1;
});

#endif

#pragma warning(pop)
