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
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2016 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//

#import <Foundation/Foundation.h>
#import <TestFramework.h>

TEST(NSURLRequest, Construction) {
    NSURL* url = [NSURL URLWithString:@"http://swift.org"];
    NSURLRequest* request = [NSURLRequest requestWithURL:url];
    // Match OS X Foundation responses
    ASSERT_OBJCNE(request, nil);
    ASSERT_OBJCEQ(request.URL, url);
    ASSERT_OBJCEQ(request.HTTPMethod, @"GET");
    ASSERT_OBJCEQ(request.allHTTPHeaderFields, nil);
    ASSERT_OBJCEQ(request.mainDocumentURL, nil);
}

TEST(NSURLRequest, MutableConstruction) {
    NSURL* url = [NSURL URLWithString:@"http://swift.org"];
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:url];

    // Confirm initial state matches NSURLRequest responses
    ASSERT_OBJCNE(request, nil);
    ASSERT_OBJCEQ(request.URL, url);
    ASSERT_OBJCEQ(request.HTTPMethod, @"GET");
    ASSERT_OBJCEQ(request.allHTTPHeaderFields, nil);
    ASSERT_OBJCEQ(request.mainDocumentURL, nil);

    request.mainDocumentURL = url;
    ASSERT_OBJCEQ(request.mainDocumentURL, url);

    request.HTTPMethod = @"POST";
    ASSERT_OBJCEQ(request.HTTPMethod, @"POST");

    NSURL* newURL = [NSURL URLWithString:@"http://github.com"];
    request.URL = newURL;
    ASSERT_OBJCEQ(request.URL, newURL);
}

TEST(NSURLRequest, HeaderFields) {
    NSURL* url = [NSURL URLWithString:@"http://swift.org"];
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:url];

    // Setup a new field
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    ASSERT_OBJCNE(request.allHTTPHeaderFields, nil);
    ASSERT_OBJCEQ(request.allHTTPHeaderFields[@"Accept"], @"application/json");

    // Setting @"accept" should update @"Accept"
    [request setValue:@"application/xml" forHTTPHeaderField:@"accept"];
    ASSERT_OBJCEQ(request.allHTTPHeaderFields[@"Accept"], @"application/xml");
    ASSERT_OBJCEQ(request.allHTTPHeaderFields[@"accept"], @"application/xml");

    // Adding to @"Accept" should sync its value with @"accept"
    [request addValue:@"text/html" forHTTPHeaderField:@"Accept"];
    ASSERT_OBJCEQ(request.allHTTPHeaderFields[@"Accept"], @"application/xml,text/html");
    ASSERT_OBJCEQ(request.allHTTPHeaderFields[@"accept"], @"application/xml,text/html");

    // Setup a new field
    [request setValue:@"for=192.0.2.43" forHTTPHeaderField:@"Forwarded"];
    ASSERT_OBJCEQ(request.allHTTPHeaderFields[@"Forwarded"], @"for=192.0.2.43");

    // Adding to @forwarded should sync with @Forwarded
    [request addValue:@"by=203.0.113.43" forHTTPHeaderField:@"FORWARDED"];
    ASSERT_OBJCEQ(request.allHTTPHeaderFields[@"FORWARDED"], @"for=192.0.2.43,by=203.0.113.43");
    ASSERT_OBJCEQ(request.allHTTPHeaderFields[@"Forwarded"], @"for=192.0.2.43,by=203.0.113.43");

    // Setup a new field
    [request addValue:@"en.wikipedia.org:8080" forHTTPHeaderField:@"host"];
    ASSERT_OBJCEQ(request.allHTTPHeaderFields[@"host"], @"en.wikipedia.org:8080");
    ASSERT_OBJCEQ(request.allHTTPHeaderFields[@"Host"], @"en.wikipedia.org:8080");
}

TEST(NSURLRequest, Copy) {
    NSURL* url = [NSURL URLWithString:@"http://swift.org"];
    NSMutableURLRequest* mutableRequest = [NSMutableURLRequest requestWithURL:url];

    NSURL* urlA = [NSURL URLWithString:@"http://swift.org"];
    NSURL* urlB = [NSURL URLWithString:@"http://github.com"];
    mutableRequest.mainDocumentURL = urlA;
    mutableRequest.URL = urlB;
    mutableRequest.HTTPMethod = @"POST";
    [mutableRequest setValue:@"application/json" forHTTPHeaderField:@"Accept"];

    NSURLRequest* requestCopy1 = ([[mutableRequest copy] isKindOfClass:[NSURLRequest class]] ? (NSURLRequest*)[mutableRequest copy] : nil);
    ASSERT_OBJCNE(requestCopy1, nil);

    // Check that all attributes are copied and that the original ones are
    // unchanged:
    ASSERT_OBJCEQ(mutableRequest.mainDocumentURL, urlA);
    ASSERT_OBJCEQ(requestCopy1.mainDocumentURL, urlA);
    ASSERT_OBJCEQ(mutableRequest.HTTPMethod, @"POST");
    ASSERT_OBJCEQ(requestCopy1.HTTPMethod, @"POST");
    ASSERT_OBJCEQ(mutableRequest.URL, urlB);
    ASSERT_OBJCEQ(requestCopy1.URL, urlB);
    ASSERT_OBJCEQ(mutableRequest.allHTTPHeaderFields[@"Accept"], @"application/json");
    ASSERT_OBJCEQ(requestCopy1.allHTTPHeaderFields[@"Accept"], @"application/json");

    // Change the original, and check that the copy has unchanged
    // values:
    NSURL* urlC = [NSURL URLWithString:@"http://apple.com"];
    NSURL* urlD = [NSURL URLWithString:@"http://ibm.com"];
    mutableRequest.mainDocumentURL = urlC;
    mutableRequest.URL = urlD;
    mutableRequest.HTTPMethod = @"HEAD";
    [mutableRequest addValue:@"text/html" forHTTPHeaderField:@"Accept"];
    ASSERT_OBJCEQ(requestCopy1.mainDocumentURL, urlA);
    ASSERT_OBJCEQ(requestCopy1.HTTPMethod, @"POST");
    ASSERT_OBJCEQ(requestCopy1.URL, urlB);
    ASSERT_OBJCEQ(requestCopy1.allHTTPHeaderFields[@"Accept"], @"application/json");

    // Check that we can copy the copy:
    NSURLRequest* requestCopy2 = ([[requestCopy1 copy] isKindOfClass:[NSURLRequest class]] ? (NSURLRequest*)[requestCopy1 copy] : nil);
    ASSERT_OBJCNE(requestCopy2, nil);

    ASSERT_OBJCEQ(requestCopy2.mainDocumentURL, urlA);
    ASSERT_OBJCEQ(requestCopy2.HTTPMethod, @"POST");
    ASSERT_OBJCEQ(requestCopy2.URL, urlB);
    ASSERT_OBJCEQ(requestCopy2.allHTTPHeaderFields[@"Accept"], @"application/json");
}

TEST(NSURLRequest, MutableCopy_1) {
    NSURL* url = [NSURL URLWithString:@"http://swift.org"];
    NSMutableURLRequest* originalRequest = [NSMutableURLRequest requestWithURL:url];

    NSURL* urlA = [NSURL URLWithString:@"http://swift.org"];
    NSURL* urlB = [NSURL URLWithString:@"http://github.com"];
    originalRequest.mainDocumentURL = urlA;
    originalRequest.URL = urlB;
    originalRequest.HTTPMethod = @"POST";
    [originalRequest setValue:@"application/json" forHTTPHeaderField:@"Accept"];

    NSMutableURLRequest* requestCopy =
        ([[originalRequest mutableCopy] isKindOfClass:[NSMutableURLRequest class]] ? (NSMutableURLRequest*)[originalRequest mutableCopy] :
                                                                                     nil);
    ASSERT_OBJCNE(requestCopy, nil);

    // Change the original, and check that the copy has unchanged values:
    NSURL* urlC = [NSURL URLWithString:@"http://apple.com"];
    NSURL* urlD = [NSURL URLWithString:@"http://ibm.com"];
    originalRequest.mainDocumentURL = urlC;
    originalRequest.URL = urlD;
    originalRequest.HTTPMethod = @"HEAD";
    [originalRequest addValue:@"text/html" forHTTPHeaderField:@"Accept"];
    ASSERT_OBJCEQ(requestCopy.mainDocumentURL, urlA);
    ASSERT_OBJCEQ(requestCopy.HTTPMethod, @"POST");
    ASSERT_OBJCEQ(requestCopy.URL, urlB);
    ASSERT_OBJCEQ(requestCopy.allHTTPHeaderFields[@"Accept"], @"application/json");
}

TEST(NSURLRequest, MutableCopy_2) {
    NSURL* url = [NSURL URLWithString:@"http://swift.org"];
    NSMutableURLRequest* originalRequest = [NSMutableURLRequest requestWithURL:url];

    NSURL* urlA = [NSURL URLWithString:@"http://swift.org"];
    NSURL* urlB = [NSURL URLWithString:@"http://github.com"];
    originalRequest.mainDocumentURL = urlA;
    originalRequest.URL = urlB;
    originalRequest.HTTPMethod = @"POST";
    [originalRequest setValue:@"application/json" forHTTPHeaderField:@"Accept"];

    NSMutableURLRequest* requestCopy =
        ([[originalRequest mutableCopy] isKindOfClass:[NSMutableURLRequest class]] ? (NSMutableURLRequest*)[originalRequest mutableCopy] :
                                                                                     nil);
    ASSERT_OBJCNE(requestCopy, nil);

    // Change the copy, and check that the original has unchanged values:
    NSURL* urlC = [NSURL URLWithString:@"http://apple.com"];
    NSURL* urlD = [NSURL URLWithString:@"http://ibm.com"];
    requestCopy.mainDocumentURL = urlC;
    requestCopy.URL = urlD;
    requestCopy.HTTPMethod = @"HEAD";
    [requestCopy addValue:@"text/html" forHTTPHeaderField:@"Accept"];
    ASSERT_OBJCEQ(originalRequest.mainDocumentURL, urlA);
    ASSERT_OBJCEQ(originalRequest.HTTPMethod, @"POST");
    ASSERT_OBJCEQ(originalRequest.URL, urlB);
    ASSERT_OBJCEQ(originalRequest.allHTTPHeaderFields[@"Accept"], @"application/json");
}

TEST(NSURLRequest, MutableCopy_3) {
    NSURL* urlA = [NSURL URLWithString:@"http://swift.org"];
    NSURLRequest* originalRequest = [NSURLRequest requestWithURL:urlA];

    NSMutableURLRequest* requestCopy =
        ([[originalRequest mutableCopy] isKindOfClass:[NSMutableURLRequest class]] ? (NSMutableURLRequest*)[originalRequest mutableCopy] :
                                                                                     nil);
    ASSERT_OBJCNE(requestCopy, nil);

    // Change the copy, and check that the original has unchanged values:
    NSURL* urlC = [NSURL URLWithString:@"http://apple.com"];
    NSURL* urlD = [NSURL URLWithString:@"http://ibm.com"];
    requestCopy.mainDocumentURL = urlC;
    requestCopy.URL = urlD;
    requestCopy.HTTPMethod = @"HEAD";
    [requestCopy addValue:@"text/html" forHTTPHeaderField:@"Accept"];
    ASSERT_OBJCEQ(originalRequest.mainDocumentURL, nil);
    ASSERT_OBJCEQ(originalRequest.HTTPMethod, @"GET");
    ASSERT_OBJCEQ(originalRequest.URL, urlA);
    ASSERT_OBJCEQ(originalRequest.allHTTPHeaderFields, nil);
}
