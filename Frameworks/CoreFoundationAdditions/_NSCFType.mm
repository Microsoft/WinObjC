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

#include <CoreFoundation/CFBase.h>
#include "CFFoundationInternal.h"
#include "CFInternal.h"

@interface _NSCFTypeSuperclassAnchor: _NSCFTemporaryRootObject
@end

@implementation _NSCFTypeSuperclassAnchor
@end

@interface _NSCFType: _NSCFTypeSuperclassAnchor
@end
@implementation _NSCFType

- (instancetype)retain {
    CFRetain(static_cast<CFTypeRef>(self));
    return self;
}

- (oneway void)release {
    CFRelease(static_cast<CFTypeRef>(self));
}

- (id)autorelease {
    return (id)(CFAutorelease(static_cast<CFTypeRef>(self)));
}

- (NSUInteger)retainCount {
    return CFGetRetainCount(static_cast<CFTypeRef>(self));
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-missing-super-calls"
- (void)dealloc {
    /* No-op for bridged classes. This is because the CF system is responsible for the allocation and dealloc of the backing memory. */
    /* This is all handled via the CFRelease calls. */
    /* When its CF ref count drops to 0 the CF version of dealloc is invoked */
    /* so by the time the NSObject dealloc is called, there is nothing left to do. */
}

+ (instancetype)allocWithZone:(NSZone*)zone {
    return nil;
}
#pragma clang diagnostic pop
@end
