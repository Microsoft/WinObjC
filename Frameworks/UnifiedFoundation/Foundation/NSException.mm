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

#include "Starboard.h"
#include "StubReturn.h"
#import "Foundation/NSException.h"

NSString* const NSRangeException = @"NSRangeExcepton";
NSString* const NSGenericException = @"NSGenericException";
NSString* const NSInvalidArgumentException = @"NSInvalidArgumentException";
NSString* const NSInternalInconsistencyException = @"NSInternalInconsistencyException";
NSString* const NSObjectNotAvailableException = @"NSObjectNotAvailableException";
NSString* const NSDestinationInvalidException = @"NSDestinationInvalidException";
NSString* const NSURLErrorDomain = @"NSURLErrorDomain";
NSString* const NSOverflowException = @"NSOverflowException";
NSString* const NSObjectInaccessibleException = @"NSObjectInaccessibleException";
NSString* const NSMallocException = @"NSMallocException";
NSString* const WinObjCException = @"WinObjC Exception"; // not exported

/**
 @Status Stub
*/
void NSSetUncaughtExceptionHandler(NSUncaughtExceptionHandler*) {
    UNIMPLEMENTED();
}

/**
 @Status Stub
 @Notes
*/
NSUncaughtExceptionHandler* NSGetUncaughtExceptionHandler() {
    UNIMPLEMENTED();
    return StubReturn();
}

@implementation NSException

/**
 @Status Interoperable
*/
- (instancetype)initWithName:(NSString*)name reason:(NSString*)reason userInfo:(NSDictionary*)userInfo {
    if (self = [super init]) {
        _name = [name copy];
        _reason = [reason copy];
        _userInfo = [userInfo copy];
        _callStackReturnAddresses = [NSThread callStackReturnAddresses];
        _callStackSymbols = [NSThread callStackSymbols];
    }

    return self;
}

/**
 @Status Interoperable
*/
+ (instancetype)exceptionWithName:(NSString*)name reason:(NSString*)reason userInfo:(NSDictionary*)userInfo {
    NSException* ret = [[self alloc] initWithName:name reason:reason userInfo:userInfo];

    return [ret autorelease];
}

/**
 @Status Interoperable
*/
+ (void)raise:(NSString*)name format:(NSString*)format, ... {
    va_list reader;
    va_start(reader, format);

    NSString* reason = [[NSString alloc] initWithFormat:format arguments:reader];
    va_end(reader);

    NSException* exception = [self exceptionWithName:name reason:reason userInfo:nil];
    [reason release];
    [exception raise];
}

/**
 @Status Interoperable
*/
+ (void)raiseWithLogging:(NSString*)name format:(NSString*)format, ... {
    va_list reader;
    va_start(reader, format);

    NSString* reason = [[NSString alloc] initWithFormat:format arguments:reader];
    va_end(reader);

    NSLog(@"Exception %@ raised!\nReason: %@\n", name, reason);

    NSException* exception = [self exceptionWithName:name reason:reason userInfo:nil];
    [reason release];

    [exception raise];
}

/**
 @Status Interoperable
*/
+ (void)raise:(NSString*)name format:(NSString*)format arguments:(va_list)args {
    NSString* reason = [[NSString alloc] initWithFormat:format arguments:args];
    NSException* exception = [self exceptionWithName:name reason:reason userInfo:nil];
    [reason release];
    [exception raise];
}

/**
 @Status Interoperable
*/
- (void)raise {
    @throw self;
}

/**
 @Status Interoperable
*/
- (NSObject*)copyWithZone:(NSZone*)zone {
    return [self retain];
}

/**
 @Status Interoperable
*/
+ (BOOL)supportsSecureCoding {
    return YES;
}

/**
 @Status Interoperable
*/
- (instancetype)initWithCoder:(NSCoder*)coder {
    if (self = [super initWithCoder:coder]) {
        _name = [[coder decodeObjectOfClass:[NSString class] forKey:@"name"] retain];
        _reason = [[coder decodeObjectOfClass:[NSString class] forKey:@"reason"] retain];
        _userInfo = [[coder decodeObjectOfClass:[NSDictionary class] forKey:@"userInfo"] retain];
        _callStackReturnAddresses = [[coder decodeObjectOfClass:[NSArray class] forKey:@"callStackReturnAddresses"] retain];
        _callStackSymbols = [[coder decodeObjectOfClass:[NSArray class] forKey:@"callStackSymbols"] retain];
    }
    return self;
}

/**
 @Status Interoperable
*/
- (void)encodeWithCoder:(NSCoder*)coder {
    [coder encodeObject:_name forKey:@"name"];
    [coder encodeObject:_reason forKey:@"reason"];
    [coder encodeObject:_userInfo forKey:@"userInfo"];
    [coder encodeObject:_callStackReturnAddresses forKey:@"callStackReturnAddresses"];
    [coder encodeObject:_callStackSymbols forKey:@"callStackSymbols"];
}

- (void)dealloc {
    [_name release];
    [_reason release];
    [_userInfo release];
    [_callStackReturnAddresses release];
    [_callStackSymbols release];

    [super dealloc];
}

// Returns exception name from HRESULT.
+ (NSString*)_exceptionNameForHRESULT:(int)errorCode {
    switch (errorCode) {
        case E_INVALIDARG:
            return NSInvalidArgumentException;
        case E_FAIL:
            return NSGenericException;
        case E_BOUNDS:
            return NSRangeException;
        case E_ACCESSDENIED:
        case RPC_E_WRONG_THREAD:
            return NSObjectInaccessibleException;
        case E_UNEXPECTED:
            return NSInternalInconsistencyException;
        case E_OUTOFMEMORY:
            return NSMallocException;
        case __HRESULT_FROM_WIN32(ERROR_NOT_READY):
            return NSObjectNotAvailableException;
        default:
            break;
    }

    return WinObjCException;
}

// Returns exception with given HRESULT
+ (instancetype)_exceptionWithHRESULT:(int)errorCode reason:(NSString*)reason userInfo:(NSDictionary*)userInfo {
    NSException* ret = [[self alloc] initWithName:[self _exceptionNameForHRESULT:errorCode] reason:reason userInfo:userInfo];

    return [ret autorelease];
}
@end