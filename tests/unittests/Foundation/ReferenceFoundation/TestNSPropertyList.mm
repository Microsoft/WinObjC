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
// Copyright (c) 2014 - 2015 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//

#import <Foundation/Foundation.h>
#import <TestFramework.h>
#import "TestUtils.h"

TEST(NSPropertyList, BasicConstruction) {
    NSMutableDictionary* dict = [NSMutableDictionary dictionaryWithCapacity:0];
    NSData* data = nil;
    NSError* error = nil;
    ASSERT_NO_THROW(
        data = [NSPropertyListSerialization dataWithPropertyList:dict format:NSPropertyListBinaryFormat_v1_0 options:0 error:&error]);
    ASSERT_OBJCEQ(error, nil);
    ASSERT_OBJCNE(data, nil);
    ASSERT_EQ_MSG(data.length, 42, @"empty dictionary should be 42 bytes");
}

TEST(NSPropertyList, Decode) {
    id decoded = nil;
    auto path = [testBundle() pathForResource:@"Test" ofType:@"plist"];

    NSData* data = [NSData dataWithContentsOfFile:path];
    NSError* error = nil;
    NSPropertyListFormat format{};
    ASSERT_NO_THROW(decoded = [NSPropertyListSerialization propertyListWithData:data options:0 format:&format error:&error]);
    ASSERT_EQ(format, NSPropertyListXMLFormat_v1_0);
    ASSERT_OBJCEQ(error, nil);
    ASSERT_OBJCNE(decoded, nil);

    NSDictionary* dict = (NSDictionary*)decoded;
    ASSERT_EQ(dict.count, 3);

    id val = dict[@"Foo"];
    ASSERT_OBJCNE(val, nil);
    ASSERT_TRUE_MSG([val isKindOfClass:[NSString class]], @"value stored is not a string");
    ASSERT_OBJCEQ((NSString*)val, @"Bar");
}

TEST(NSPropertyList, DecodeMutable) {
    id decoded = nil;
    auto path = [testBundle() pathForResource:@"Test" ofType:@"plist"];
    NSData* data = [NSData dataWithContentsOfFile:path];
    ASSERT_NO_THROW(decoded = [NSPropertyListSerialization propertyListFromData:data
                                                               mutabilityOption:NSPropertyListMutableContainers
                                                                         format:nullptr
                                                               errorDescription:nullptr]);
    ASSERT_OBJCNE(decoded, nil);

    NSDictionary* dict = (NSMutableDictionary*)decoded;
    ASSERT_EQ(dict.count, 3);

    id val = dict[@"Foo"];
    ASSERT_OBJCNE(val, nil);
    ASSERT_TRUE_MSG([val isKindOfClass:[NSString class]], @"value stored is not a string");
    ASSERT_OBJCEQ((NSString*)val, @"Bar");

    ASSERT_NO_THROW([dict setObject:@"test" forKey:@"object"]);
    val = dict[@"object"];
    ASSERT_OBJCNE(val, nil);
    ASSERT_TRUE_MSG([val isKindOfClass:[NSString class]], @"value stored is not a string");
    ASSERT_OBJCEQ((NSString*)val, @"test");
}
