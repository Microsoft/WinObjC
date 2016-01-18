/* Copyright (c) 2006-2007 Christopher J. W. Lloyd

Copyright (c) 2015 Microsoft Corporation. All rights reserved.

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the
following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. */

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

#import <Foundation/NSObject.h>
#import <Foundation/NSDate.h>

@class NSArray, NSDate, NSData, NSDictionary, NSLocale, NSString, NSMutableArray;

typedef NS_ENUM(NSInteger, NSTimeZoneNameStyle) {
    NSTimeZoneNameStyleStandard,
    NSTimeZoneNameStyleShortStandard,
    NSTimeZoneNameStyleDaylightSaving,
    NSTimeZoneNameStyleShortDaylightSaving,
    NSTimeZoneNameStyleGeneric,
    NSTimeZoneNameStyleShortGeneric
};

FOUNDATION_EXPORT NSString* const NSSystemTimeZoneDidChangeNotification;

FOUNDATION_EXPORT_CLASS
@interface NSTimeZone : NSObject <NSSecureCoding, NSCopying>

+ (NSTimeZone*)localTimeZone;
+ (NSTimeZone*)systemTimeZone;
+ (NSTimeZone*)defaultTimeZone;
+ (NSString*)timeZoneDataVersion;

+ (void)resetSystemTimeZone;

+ (void)setDefaultTimeZone:(NSTimeZone*)timeZone;

+ (NSArray*)knownTimeZoneNames;

+ (NSDictionary*)abbreviationDictionary;

- initWithName:(NSString*)name data:(NSData*)data;
- initWithName:(NSString*)name;

+ (NSTimeZone*)timeZoneWithName:(NSString*)name data:(NSData*)data;
+ (NSTimeZone*)timeZoneWithName:(NSString*)name;

+ (NSTimeZone*)timeZoneForSecondsFromGMT:(NSInteger)seconds;
+ (NSTimeZone*)timeZoneWithAbbreviation:(NSString*)abbreviation;

- (BOOL)isEqualToTimeZone:(NSTimeZone*)timeZone;

- (NSInteger)secondsFromGMTForDate:(NSDate*)date;
- (NSString*)abbreviationForDate:(NSDate*)date;
- (BOOL)isDaylightSavingTimeForDate:(NSDate*)date;
- (NSTimeInterval)daylightSavingTimeOffsetForDate:(NSDate*)date;
- (NSDate*)nextDaylightSavingTimeTransitionAfterDate:(NSDate*)date;

- (NSString*)localizedName:(NSTimeZoneNameStyle)style locale:(NSLocale*)locale;

// Properties
@property (nonatomic, readonly, copy) NSString* description;
@property (nonatomic, readonly, copy) NSDate* nextDaylightSavingTimeTransition;
@property (nonatomic, readonly, copy) NSString* abbreviation;
@property (nonatomic, readonly, copy) NSString* name;
@property (nonatomic, readonly, copy) NSData* data;
@property (nonatomic, readonly) NSInteger secondsFromGMT;
@property (nonatomic, readonly) NSTimeInterval daylightSavingTimeOffset;
@property (nonatomic, readonly) BOOL isDaylightSavingTime;

@end
