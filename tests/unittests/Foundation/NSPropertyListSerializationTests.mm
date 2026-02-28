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

#include <TestFramework.h>
#import <Foundation/Foundation.h>

TEST(NSPropertyListSerialization, PropertyListForDate) {
    NSString* xml = @"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE plist PUBLIC \"-//Apple Computer//DTD PLIST 1.0//EN\" "
                    @"\"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n<plist version=\"1.0\">\n<dict>\n<key>Date "
                    @"Modified</key><date>2014-12-15T19:48:38Z</date>\n</dict>\n</plist>";

    NSDictionary* plistDict;
    ASSERT_NO_THROW({
        plistDict =
            [NSPropertyListSerialization propertyListWithData:[xml dataUsingEncoding:NSUTF8StringEncoding] options:0 format:nullptr error:nullptr];
    });
    ASSERT_NE(nil, plistDict);

    NSDate* date = [NSDate dateWithTimeIntervalSinceReferenceDate:440365718]; // Mon Dec 15 2014 19:48:38 GMT
    ASSERT_NE(nil, date);
    ASSERT_OBJCEQ(date, plistDict[@"Date Modified"]);

    ASSERT_NO_THROW({ plistDict = [xml propertyList]; });
    ASSERT_OBJCEQ(date, plistDict[@"Date Modified"]);
}

TEST(NSPropertyListSerialization, CanDeserializeCFUID) {
    // The only way to represent a raw CFKeyedArchiverUID is via binary property list.
    // This property list contains:
    // 0x00:        u8[8] header                       (bplist00)
    // -- object table --
    // 0x08: UID (0x80 0xFF)
    // -- offset table --
    // 0x0A: 0x08
    // -- plist trailer --
    // 0x0B - 0x0F: u8[5] unused                       (0x00 * 5)
    // 0x10:        u8    sort version                 (0x00)
    // 0x11:        u8    size of offset table entries (0x01)
    // 0x12:        u8    size of embedded objects     (0x01)
    // 0x13 - 0x1A: u64   number of objects            (0x01)
    // 0x1B - 0x22: u64   toplevel object              (0x00)
    // 0x23 - 0x2A: u64   offset to offset table       (0x0A)

    const unsigned char rawPlist[] = { 0x62, 0x70, 0x6c, 0x69, 0x73, 0x74, 0x30, 0x30, 0x80, 0xff, 0x08, 0x00, 0x00, 0x00, 0x00,
                                       0x00, 0x00, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00,
                                       0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0a };
    NSData* plistData = [NSData dataWithBytes:rawPlist length:std::extent<decltype(rawPlist)>::value];
    NSObject* UID = nil;
    ASSERT_NO_THROW(
        UID = [NSPropertyListSerialization propertyListFromData:plistData mutabilityOption:0 format:nullptr errorDescription:nullptr]);
    ASSERT_NE(nil, UID);

    // This is a comprehensive list of the non-UID property list types.
    // We cannot explicitly check if something is a UID (in a cross-platform way) without
    // introducing a private dependency.
    EXPECT_FALSE([UID isKindOfClass:[NSNumber class]]);
    EXPECT_FALSE([UID isKindOfClass:[NSString class]]);
    EXPECT_FALSE([UID isKindOfClass:[NSArray class]]);
    EXPECT_FALSE([UID isKindOfClass:[NSDictionary class]]);
    EXPECT_FALSE([UID isKindOfClass:[NSDate class]]);
    EXPECT_FALSE([UID isKindOfClass:[NSData class]]);
}

static id _NSRoundTripObjectThroughPlistSerialization(id object, NSPropertyListFormat outputFormat, NSError** error) {
    NSData* data = [NSPropertyListSerialization dataWithPropertyList:object format:outputFormat options:0 error:error];
    if (error && *error) {
        return nil;
    }

    NSString* errorDescription = nil;
    id otherObject =
        [NSPropertyListSerialization propertyListFromData:data mutabilityOption:0 format:nullptr errorDescription:&errorDescription];
    if (errorDescription) {
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:0 userInfo:@{ NSLocalizedDescriptionKey : errorDescription }];
        }
        return nil;
    }

    return otherObject;
}

TEST(NSPropertyListSerialization, DictionaryUIDRoundTripsThroughXMLAsUID) {
    // On the reference platform, deserializing a dictionary of the form
    // {
    //     "CF$UID" = 1;
    // }
    // *as XML* will result in a CFKeyedArchiverUID being created.
    NSError* error = nil;
    id newUid = _NSRoundTripObjectThroughPlistSerialization(@{ @"CF$UID" : @1 }, NSPropertyListXMLFormat_v1_0, &error);
    ASSERT_EQ(nil, error);
    ASSERT_NE(nil, newUid);
    EXPECT_FALSE([newUid isKindOfClass:[NSDictionary class]]);
}

TEST(NSPropertyListSerialization, DictionaryUIDRoundTripsThroughBinaryAsDictionary) {
    // Round-tripping the same dictionary as above via binary property list will
    // ensure that it remains a dictionary.
    NSError* error = nil;
    id newUid = _NSRoundTripObjectThroughPlistSerialization(@{ @"CF$UID" : @1 }, NSPropertyListBinaryFormat_v1_0, &error);
    ASSERT_EQ(nil, error);
    ASSERT_NE(nil, newUid);
    EXPECT_TRUE([newUid isKindOfClass:[NSDictionary class]]);
}
