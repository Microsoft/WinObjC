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

#include <Foundation/Foundation.h>
#import <UWP/interopBase.h>

// TODO[5668270] This could use NSUUID, which is backed by a GUID already.
@implementation WFGUID {
    GUID _guid;
}

- (unsigned long)Data1 {
    return _guid.Data1;
}

- (unsigned short)Data2 {
    return _guid.Data2;
}

- (unsigned short)Data3 {
    return _guid.Data3;
}

- (unsigned char*)Data4 {
    return _guid.Data4;
}

- (void)setData1:(unsigned long)val {
    _guid.Data1 = val;
}

- (void)setData2:(unsigned short)val {
    _guid.Data2 = val;
}

- (void)setData3:(unsigned short)val {
    _guid.Data3 = val;
}

+ (instancetype)guidWithGUID:(const GUID)guid {
    WFGUID* ret = [WFGUID alloc];
    [[ret initWithGUID:guid] autorelease];
    return ret;
}

- initWithGUID:(const GUID)guid {
    _guid = guid;
    return self;
}

- (GUID)guidValue {
    return _guid;
}

@end

@implementation RTKeyValuePair {
}

- (id)key {
    return nil;
}

- (id)value {
    return nil;
}

@end
