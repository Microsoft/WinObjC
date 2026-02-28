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

#include <TestFramework.h>
#import <Foundation/Foundation.h>
#import <Foundation/NSURLCredential.h>

TEST(NSURLCredential, credentialWithUser) {
    NSString* user = @"user";
    NSString* pass = @"pass";
    NSURLCredential* credential = [NSURLCredential credentialWithUser:user password:pass persistence:NSURLCredentialPersistenceForSession];
    ASSERT_NE_MSG(nil, credential, "FAILED: credential should be non-null!");

    EXPECT_OBJCEQ_MSG(user, [credential user], "FAILED: User name is not valid");
    EXPECT_OBJCEQ_MSG(pass, [credential password], "FAILED: password is not valid");
    EXPECT_EQ_MSG(NSURLCredentialPersistenceForSession, [credential persistence], "FAILED: persistence is not valid");
    EXPECT_EQ_MSG(YES, [credential hasPassword], "FAILED: hasPassword is not the expected value");
    EXPECT_EQ_MSG(nullptr, [credential identity], "FAILED: identity not null");
    EXPECT_EQ_MSG(nil, [credential certificates], "FAILED: certificates not null");
}

// We do not currently have SecIdentity implemented so this cannot be tested further
TEST(NSURLCredential, credentialWithIdentity) {
    NSArray* certs = [NSMutableArray array];
    NSURLCredential* credential =
        [NSURLCredential credentialWithIdentity:nullptr certificates:(NSArray*)certs persistence:NSURLCredentialPersistencePermanent];

    NSURLCredential* initCredential =
        [[NSURLCredential alloc] initWithIdentity:nullptr certificates:(NSArray*)certs persistence:NSURLCredentialPersistencePermanent];

    EXPECT_EQ_MSG(nil, credential, "FAILED: credential should be null when created without any identity!");
    EXPECT_EQ_MSG(nil, initCredential, "FAILED: initCredential should be null when created without any identity!");
}

TEST(NSURLCredential, credentialForTrust) {
    NSURLCredential* credential = [NSURLCredential credentialForTrust:nullptr];

    ASSERT_NE_MSG(nil, credential, "FAILED: credential should be non-null!");
    EXPECT_EQ_MSG(nil, [credential user], "FAILED: User name is not null");
    EXPECT_EQ_MSG(nil, [credential password], "FAILED: password is not null");
    EXPECT_EQ_MSG(NSURLCredentialPersistenceForSession, [credential persistence], "FAILED: persistence is not valid");
    EXPECT_EQ_MSG(NO, [credential hasPassword], "FAILED: hasPassword is not the expected value");
    EXPECT_EQ_MSG(nullptr, [credential identity], "FAILED: identity not null");
}
