//******************************************************************************
//
// Copyright (c) 2016 Microsoft Corporation. All rights reserved.
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
#import <Foundation/NSError.h>
#import <Foundation/NSString.h>
#import "NSCFError.h"
#import "LoggingNative.h"
#import "BridgeHelpers.h"
#import "CFFoundationInternal.h"

#pragma region NSCF Bridged Class
@implementation NSCFError

BRIDGED_CLASS_REQUIRED_IMPLS(CFErrorRef, CFErrorGetTypeID, NSError, NSCFError)
BRIDGED_CLASS_FOR_CODER(NSError)

- (NSString*)domain {
    return static_cast<NSString*>(CFErrorGetDomain(static_cast<CFErrorRef>(self)));
}

- (int)code {
    return CFErrorGetCode(static_cast<CFErrorRef>(self));
}

- (NSDictionary*)userInfo {
    return static_cast<NSDictionary*>(CFAutorelease(CFErrorCopyUserInfo(static_cast<CFErrorRef>(self))));
}

- (NSString*)localizedDescription {
    return static_cast<NSString*>(CFAutorelease(CFErrorCopyDescription(static_cast<CFErrorRef>(self))));
}

- (NSString*)localizedFailureReason {
    return static_cast<NSString*>(CFAutorelease(CFErrorCopyRecoverySuggestion(static_cast<CFErrorRef>(self))));
}

@end
