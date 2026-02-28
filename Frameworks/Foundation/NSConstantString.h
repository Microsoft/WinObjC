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
#import <Foundation/NSString.h>
#import "NSStringAdditionsForCF.h"

#ifdef __OBJC_GNUSTEP_RUNTIME_ABI__
#if __OBJC_GNUSTEP_RUNTIME_ABI__ >= 20
#define WINOBJC_NEW_CONSTANT_STRINGS 1
#endif
#endif

@interface NSConstantString : NSString <NSStringAdditionsForCF> {
    // NOTE: The ivar layout for this class *must* be present to match the
    // compiler expected layout for constant strings.  This differs between the
    // GCC-compatible ABI and the GNUstep v2 ABI.
#ifdef WINOBJC_NEW_CONSTANT_STRINGS
    /**
     * Flags value.  The low 16 bits are reserved for the compiler, the top 16
     * for the class implementation.  Currently, only the low 2 bits are
     * defined by the compiler.
     */
    uint32_t flags;
    /**
     * The number of UTF-16 code units in the string.
     */
    uint32_t length;
    /**
     * The number of bytes occupied by the string.
     */
    uint32_t size;
    /**
     * Storage preallocated for the hash (not initialized by the compiler).
     */
    uint32_t hash;
    /**
     * Data pointer; format described by the bottom bits of `flags`.
     */
    const void* data;
#else
    char* c_string;
    unsigned int len;
#endif
}

- (instancetype)retain;
- (void)release;
- (instancetype)autorelease;
- (void)dealloc;

// NSString overrides
@property (readonly) NSUInteger length;
- (unichar)characterAtIndex:(NSUInteger)index;

// Private function for CF
- (const char*)_fastCStringContents:(CFStringEncoding)encoding;
- (const UniChar*)_fastCharacterContents;
- (Boolean)_encodingCantBeStoredInEightBitCFString;

@end
