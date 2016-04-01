/* Copyright (c) 2006-2007 Christopher J. W. Lloyd
   Copyright (c) 2016 Microsoft Corporation. All rights reserved.

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
documentation files (the "Software"), to deal in the Software without restriction, including without limitation the
rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit
persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the
Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. */

// Original - Christopher Lloyd <cjwl@objc.net>

#include "Starboard.h"
#include "StubReturn.h"

#include "Foundation/NSString.h"
#include "Foundation/NSMutableData.h"
#include "Foundation/NSMutableDictionary.h"
#include "Foundation/NSNumber.h"
#include "Foundation/NSDate.h"
#include "Foundation/NSMutableArray.h"
#include "Foundation/NSNull.h"
#include "Foundation/NSPropertyListSerialization.h"
#include "Foundation/NSKeyedArchiver.h"
#include "NSPropertyListReader.h"
#include "NSPropertyListWriter_binary.h"

#import "NSXMLPropertyList.h"
#include "LoggingNative.h"

static const wchar_t* TAG = L"NSPropertyListSerialization";

void printContents(int level, id obj);

@implementation NSPropertyListSerialization

/**
 @Status Caveat
 @Notes mutability option not supported. Only binary, XML and text strings format supported.
*/
+ (id)propertyListFromData:(NSData*)data
          mutabilityOption:(unsigned)mutability
                    format:(NSPropertyListFormat*)formatOut
          errorDescription:(NSString**)error {
    if (data == nil) {
        TraceVerbose(TAG, L"propertyListFromData: data is nil!");
        if (error) {
            *error = @"Data was null.";
        }

        return nil;
    }

    unsigned len = [data length];
    if (len == 0) {
        TraceVerbose(TAG, L"propertyListFromData: data is too short!");
        if (error) {
            *error = @"Data is too short.";
        }

        return nil;
    }

    char* bytes = (char*)[data bytes];
    if (len >= 5 && memcmp(bytes, "<?xml", 5) == 0) {
        id ret = [NSXMLPropertyList propertyListFromData:data];

        if (ret == nil) {
            TraceVerbose(TAG, L"propertyListFromData: return is nil!");
            if (error) {
                *error = @"No objects.";
            }

            return nil;
        }

        if (formatOut) {
            *formatOut = NSPropertyListXMLFormat_v1_0;
        }

        return ret;
    } else if (len >= 6 && memcmp(bytes, "bplist", 6) == 0) {
        /*
        NSPropertyListReader* reader = [[NSPropertyListReader alloc] initWithData:data];
        [reader setMutabilityFlags:mutability];
        id ret = [reader read];
        [reader release];
        */
        NSPropertyListReaderA read;
        read.init(data);
        id ret = read.read();

        if (ret == nil) {
            TraceVerbose(TAG, L"propertyListFromData: return is nil!");
            if (error) {
                *error = @"No objects.";
            }

            return nil;
        }

        if (formatOut) {
            *formatOut = NSPropertyListBinaryFormat_v1_0;
        }

        return ret;
    } else if (len >= 2 && memcmp(bytes, "\xfe\xff", 2) == 0) {
        NSString* str = [[NSString alloc] initWithData:data encoding:NSUTF16BigEndianStringEncoding];
        id ret = [str propertyListFromStringsFileFormat];
        [str release];
        return ret;
    } else {
        return nil;
    }
}

/**
 @Status Caveat
 @Notes mutability option not supported. Only binary, XML and text strings format supported.
*/
+ (id)propertyListWithData:(NSData*)data options:(unsigned)options format:(NSPropertyListFormat*)formatOut error:(NSError**)error {
    // [TODO] Not that this uses a different error format than ours. Below takes a string, we return an NSError.
    return [self propertyListFromData:data mutabilityOption:options format:formatOut errorDescription:NULL];
}

/**
 @Status Caveat
 @Notes Only binary property list is supported
*/
+ (NSData*)dataFromPropertyList:(id)plist format:(NSPropertyListFormat)format errorDescription:(NSString**)error {
    switch (format) {
        case NSPropertyListOpenStepFormat:
            assert(0);
            break;

#if 0
case NSPropertyListXMLFormat_v1_0:
return [NSPropertyListWriter_xml dataWithPropertyList:plist];
#endif

        case NSPropertyListBinaryFormat_v1_0: {
            NSMutableData* data = [NSMutableData data];
            [NSPropertyListWriter_Binary serializePropertyList:plist intoData:data];
            return data;
        }

        default:
#if 0
TraceVerbose(TAG, L"Couldn't serialize to this format, defaulting to XML!");
return [NSPropertyListWriter_xml dataWithPropertyList:plist];
#endif
            break;
    }

    return nil;
}

/**
 @Status Stub
 @Notes
*/
+ (NSData*)dataWithPropertyList:(id)plist
                         format:(NSPropertyListFormat)format
                        options:(NSPropertyListWriteOptions)opt
                          error:(NSError* _Nullable*)error {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
+ (NSInteger)writePropertyList:(id)plist
                      toStream:(NSOutputStream*)stream
                        format:(NSPropertyListFormat)format
                       options:(NSPropertyListWriteOptions)opt
                         error:(NSError* _Nullable*)error {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
+ (id)propertyListWithStream:(NSInputStream*)stream
                     options:(NSPropertyListReadOptions)opt
                      format:(NSPropertyListFormat*)format
                       error:(NSError* _Nullable*)error {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
+ (BOOL)propertyList:(id)plist isValidForFormat:(NSPropertyListFormat)format {
    UNIMPLEMENTED();
    return StubReturn();
}

@end
