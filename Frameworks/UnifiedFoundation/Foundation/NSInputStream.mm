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
#include "Foundation/NSStream.h"
#include "Foundation/NSString.h"
#include "Foundation/NSInputStream.h"
#include "NSStreamInternal.h"
#include "LoggingNative.h"

#ifdef WIN32
#include <io.h>
#elif defined(WINPHONE)
#else
//#include <unistd.h>
#endif

static const wchar_t* TAG = L"NSInputStream";

@implementation NSInputStream

/**
 @Status Interoperable
*/
+ (id)inputStreamWithFileAtPath:(id)file {
    NSInputStream* ret = [self alloc];

    ret->filename = file;
    if (EbrAccess([file UTF8String], 0) != 0) {
        TraceError(TAG, L"Open failed");
        return nil;
    }

    return ret;
}

/**
 @Status Interoperable
*/
+ (id)inputStreamWithData:(id)data {
    id ret = [self alloc];

    return [[ret initWithData:data] autorelease];
}

/**
 @Status Interoperable
*/
- (id)initWithData:(id)data {
    _data = data;

    return self;
}

/**
 @Status Interoperable
*/
- (id)initWithFileAtPath:(id)file {
    if (file == nil) {
        TraceVerbose(TAG, L"initWithFileAtPath: nil!");
        return nil;
    }

    filename = file;
    TraceVerbose(TAG, L"NSInputStream opening %hs", [file UTF8String]);
    if (EbrAccess([file UTF8String], 0) != 0) {
        TraceError(TAG, L"Open failed");
        return nil;
    }

    return self;
}

/**
 @Status Interoperable
*/
- (int)read:(char*)buf maxLength:(unsigned)maxLength {
    if (_data == nil) {
        int ret = EbrFread(buf, 1, maxLength, fp);

        if (EbrFeof(fp)) {
            _status = NSStreamStatusAtEnd;
        }

        return ret;
    } else {
        int toRead = [_data length] - curPos;

        assert(toRead >= 0);
        if (toRead > (int)maxLength) {
            toRead = (int)maxLength;
        }

        char* pBytes = (char*)[_data bytes];
        memcpy(buf, pBytes + curPos, toRead);
        curPos += toRead;

        return toRead;
    }
}

/**
 @Status Interoperable
*/
- (BOOL)hasBytesAvailable {
    if (_data == nil) {
        if (!fp) {
            return FALSE;
        }

        if (EbrFeof(fp)) {
            return FALSE;
        } else {
            return TRUE;
        }
    } else {
        if ([_data length] > curPos) {
            return TRUE;
        } else {
            return FALSE;
        }
    }
}

/**
 @Status Interoperable
*/
- (id) /* use typed version */ open {
    if (_data == nil) {
        TraceVerbose(TAG, L"Opening %hs", [filename UTF8String]);
        fp = EbrFopen([filename UTF8String], "rb");
        if (!fp) {
            TraceError(TAG, L"Open of %hs failed", [filename UTF8String]);
            _status = NSStreamStatusNotOpen;
        } else {
            _status = NSStreamStatusOpen;
        }
    } else {
        _status = NSStreamStatusOpen;
    }

    return self;
}

/**
 @Status Stub
 @Notes
*/
- (id)scheduleInRunLoop:(id)runLoop forMode:(id)mode {
    UNIMPLEMENTED();
    return 0;
}

/**
 @Status Stub
 @Notes
*/
- (instancetype)initWithURL:(NSURL*)url {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
- (BOOL)getBuffer:(uint8_t* _Nullable*)buffer length:(NSUInteger*)len {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
+ (instancetype)inputStreamWithURL:(NSURL*)url {
    UNIMPLEMENTED();
    return StubReturn();
}

@end
