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

#include <CoreFoundation/CFCalendar.h>
#include <CoreFoundation/CFDateFormatter.h>
#include <Foundation/NSDate.h>
#include <Foundation/NSString.h>
#include <Foundation/NSCalendar.h>
#include "NSLocaleInternal.h"
#include "NSDateComponentsInternal.h"

#include "LoggingNative.h"
#include "BridgeHelpers.h"
#include "NSRaise.h"
#include "NSCFCalendar.h"

NSString* const NSCalendarIdentifierGregorian = static_cast<NSString*>(kCFGregorianCalendar);
NSString* const NSCalendarIdentifierBuddhist = static_cast<NSString*>(kCFBuddhistCalendar);
NSString* const NSCalendarIdentifierChinese = static_cast<NSString*>(kCFChineseCalendar);
NSString* const NSCalendarIdentifierCoptic = static_cast<NSString*>(kCFCopticCalendar);
NSString* const NSCalendarIdentifierEthiopicAmeteMihret = static_cast<NSString*>(kCFEthiopicAmeteMihretCalendar);
NSString* const NSCalendarIdentifierEthiopicAmeteAlem = static_cast<NSString*>(kCFEthiopicAmeteAlemCalendar);
NSString* const NSCalendarIdentifierHebrew = static_cast<NSString*>(kCFHebrewCalendar);
NSString* const NSCalendarIdentifierISO8601 = static_cast<NSString*>(kCFISO8601Calendar);
NSString* const NSCalendarIdentifierIndian = static_cast<NSString*>(kCFIndianCalendar);
NSString* const NSCalendarIdentifierIslamic = static_cast<NSString*>(kCFIslamicCalendar);
NSString* const NSCalendarIdentifierIslamicCivil = static_cast<NSString*>(kCFIslamicCivilCalendar);
NSString* const NSCalendarIdentifierJapanese = static_cast<NSString*>(kCFJapaneseCalendar);
NSString* const NSCalendarIdentifierPersian = static_cast<NSString*>(kCFPersianCalendar);
NSString* const NSCalendarIdentifierRepublicOfChina = static_cast<NSString*>(kCFRepublicOfChinaCalendar);
NSString* const NSCalendarIdentifierIslamicTabular = static_cast<NSString*>(kCFIslamicTabularCalendar);
NSString* const NSCalendarIdentifierIslamicUmmAlQura = static_cast<NSString*>(kCFIslamicUmmAlQuraCalendar);
NSString* const NSCalendarDayChangedNotification = @"NSCalendarDayChangedNotification";

static NSArray* _getFormatterSymbols(NSCalendar* self, CFStringRef keyName) {
    @synchronized(self) {
        woc::unique_cf<CFDateFormatterRef> dateFormatter(CFDateFormatterCreate(kCFAllocatorSystemDefault,
                                                                               static_cast<CFLocaleRef>([self locale]),
                                                                               kCFDateFormatterNoStyle,
                                                                               kCFDateFormatterNoStyle));
        CFDateFormatterSetProperty(dateFormatter.get(), kCFDateFormatterCalendar, static_cast<CFCalendarRef>(self));
        return static_cast<NSArray*>(CFAutorelease(CFDateFormatterCopyProperty(dateFormatter.get(), keyName)));
    }
}

static NSString* _getFormatterSymbol(NSCalendar* self, CFStringRef keyName) {
    @synchronized(self) {
        woc::unique_cf<CFDateFormatterRef> dateFormatter(CFDateFormatterCreate(kCFAllocatorSystemDefault,
                                                                               static_cast<CFLocaleRef>([self locale]),
                                                                               kCFDateFormatterNoStyle,
                                                                               kCFDateFormatterNoStyle));
        CFDateFormatterSetProperty(dateFormatter.get(), kCFDateFormatterCalendar, static_cast<CFCalendarRef>(self));
        return static_cast<NSString*>(CFAutorelease(CFDateFormatterCopyProperty(dateFormatter.get(), keyName)));
    }
}

@implementation NSCalendar

BASE_CLASS_REQUIRED_IMPLS(NSCalendar, NSCalendarPrototype, CFCalendarGetTypeID);

/**
 @Status Interoperable
*/
- (instancetype)copyWithZone:(NSZone*)zone {
    NSCalendar* result = [[NSCalendar alloc] initWithCalendarIdentifier:self.calendarIdentifier];
    result.locale = self.locale;
    result.timeZone = self.timeZone;
    result.firstWeekday = self.firstWeekday;
    result.minimumDaysInFirstWeek = self.minimumDaysInFirstWeek;

    return result;
}

/**
 @Status Interoperable
*/
+ (NSCalendar*)currentCalendar {
    return [static_cast<NSCalendar*>(CFCalendarCopyCurrent()) autorelease];
}

/**
 @Status Interoperable
*/
- (instancetype)initWithCalendarIdentifier:(NSString*)identifier {
    // Derived classes are required to implement this initializer.
    return NSInvalidAbstractInvocationReturn();
}

/**
 @Status Interoperable
*/
- (NSString*)calendarIdentifier {
    return NSInvalidAbstractInvocationReturn();
}

/**
 @Status Interoperable
*/
- (NSUInteger)firstWeekday {
    return NSInvalidAbstractInvocationReturn();
}

/**
 @Status Interoperable
*/
- (NSUInteger)minimumDaysInFirstWeek {
    return NSInvalidAbstractInvocationReturn();
}

/**
 @Status Interoperable
*/
- (NSTimeZone*)timeZone {
    return NSInvalidAbstractInvocationReturn();
}

/**
 @Status Interoperable
*/
- (NSLocale*)locale {
    return NSInvalidAbstractInvocationReturn();
}

/**
 @Status Interoperable
*/
- (void)setFirstWeekday:(NSUInteger)weekday {
    return NSInvalidAbstractInvocation();
}

/**
 @Status Interoperable
*/
- (void)setMinimumDaysInFirstWeek:(NSUInteger)days {
    return NSInvalidAbstractInvocation();
}

/**
 @Status Interoperable
*/
- (void)setTimeZone:(NSTimeZone*)timeZone {
    return NSInvalidAbstractInvocation();
}

/**
 @Status Interoperable
*/
- (void)setLocale:(NSLocale*)locale {
    return NSInvalidAbstractInvocation();
}

/**
 @Status Interoperable
*/
- (NSDate*)dateByAddingComponents:(NSDateComponents*)components toDate:(NSDate*)toDate options:(NSUInteger)options {
    return NSInvalidAbstractInvocationReturn();
}

/**
 @Status Interoperable
*/
- (NSDate*)dateFromComponents:(NSDateComponents*)components {
    return NSInvalidAbstractInvocationReturn();
}

/**
 @Status Interoperable
*/
- (NSDateComponents*)components:(NSCalendarUnit)unitFlags fromDate:(NSDate*)date {
    return NSInvalidAbstractInvocationReturn();
}

/**
 @Status Interoperable
*/
- (NSUInteger)ordinalityOfUnit:(NSCalendarUnit)inUnit inUnit:(NSCalendarUnit)larger forDate:(NSDate*)date {
    return NSInvalidAbstractInvocationReturn();
}

/**
 @Status Interoperable
*/
- (NSDateComponents*)components:(NSUInteger)unitFlags fromDate:(NSDate*)fromDate toDate:(NSDate*)toDate options:(NSUInteger)options {
    return NSInvalidAbstractInvocationReturn();
}

/**
 @Status Interoperable
*/
- (BOOL)rangeOfUnit:(NSCalendarUnit)unit startDate:(NSDate* _Nullable*)datep interval:(NSTimeInterval*)timep forDate:(NSDate*)date {
    return NSInvalidAbstractInvocationReturn();
}

/**
 @Status Interoperable
*/
- (NSRange)rangeOfUnit:(NSCalendarUnit)smaller inUnit:(NSCalendarUnit)larger forDate:(NSDate*)date {
    return NSInvalidAbstractInvocationReturn();
}

/**
 @Status Interoperable
*/
- (NSRange)maximumRangeOfUnit:(NSCalendarUnit)unit {
    return NSInvalidAbstractInvocationReturn();
}

/**
 @Status Interoperable
*/
- (NSRange)minimumRangeOfUnit:(NSCalendarUnit)unit {
    return NSInvalidAbstractInvocationReturn();
}

/**
 @Status Interoperable
*/
+ (NSCalendar*)calendarWithIdentifier:(NSString*)calendarIdentifierConstant {
    return [[[NSCalendar alloc] initWithCalendarIdentifier:calendarIdentifierConstant] autorelease];
}

/**
 @Status Interoperable
*/
+ (BOOL)supportsSecureCoding {
    return YES;
}

/**
 @Status Interoperable
*/
- (id)initWithCoder:(NSCoder*)decoder {
    NSString* calId = [decoder decodeObjectForKey:@"NS.calendarId"];
    if (self = [self initWithCalendarIdentifier:calId]) {
        [self setLocale:[decoder decodeObjectOfClass:[NSLocale class] forKey:@"NS.locale"]];
        [self setFirstWeekday:(NSUInteger)[decoder decodeIntegerForKey:@"NS.firstWeekDay"]];
        [self setMinimumDaysInFirstWeek:(NSUInteger)[decoder decodeIntegerForKey:@"NS.minimumDaysInFirstWeek"]];
        // TODO 7367076: When timezone is bridged this will work. Calendar is written to use CFTimeZone.
        //[self setTimeZone:[[decoder decodeObjectOfClass:[NSTimeZone class] forKey:@"NS.calendarTimeZone"] retain]];
    }

    return self;
}

/**
 @Status Interoperable
*/
- (void)encodeWithCoder:(NSCoder*)coder {
    [coder encodeObject:[self calendarIdentifier] forKey:@"NS.calendarId"];
    [coder encodeInteger:[self firstWeekday] forKey:@"NS.firstWeekDay"];
    [coder encodeObject:[self locale] forKey:@"NS.locale"];
    [coder encodeInteger:[self minimumDaysInFirstWeek] forKey:@"NS.minimumDaysInFirstWeek"];
    // TODO 7367076: When timezone is bridged this will work. Calendar is written to use CFTimeZone.
    //[coder encodeObject:[self timeZone] forKey:@"NS.calendarTimeZone"];
}

/**
 @Status Interoperable
 @Public No
 @Notes CF needs these to exist for derived implementations
*/
- (NSLocale*)_copyLocale {
    return [self.locale copy];
}

/**
 @Status Interoperable
 @Public No
 @Notes CF needs these to exist for derived implementations
*/
- (NSTimeZone*)_copyTimeZone {
    return [self.timeZone copy];
}

/**
 @Status Interoperable
*/
- (NSString*)AMSymbol {
    return _getFormatterSymbol(self, kCFDateFormatterAMSymbol);
}

/**
 @Status Interoperable
*/
- (NSString*)PMSymbol {
    return _getFormatterSymbol(self, kCFDateFormatterPMSymbol);
}

/**
 @Status Interoperable
*/
- (NSArray*)weekdaySymbols {
    return _getFormatterSymbols(self, kCFDateFormatterWeekdaySymbols);
}

/**
 @Status Interoperable
*/
- (NSArray*)shortWeekdaySymbols {
    return _getFormatterSymbols(self, kCFDateFormatterShortWeekdaySymbols);
}

/**
 @Status Interoperable
*/
- (NSArray*)veryShortWeekdaySymbols {
    return _getFormatterSymbols(self, kCFDateFormatterVeryShortWeekdaySymbols);
}

/**
 @Status Interoperable
*/
- (NSArray*)standaloneWeekdaySymbols {
    return _getFormatterSymbols(self, kCFDateFormatterStandaloneWeekdaySymbols);
}

/**
 @Status Interoperable
*/
- (NSArray*)shortStandaloneWeekdaySymbols {
    return _getFormatterSymbols(self, kCFDateFormatterShortStandaloneWeekdaySymbols);
}

/**
 @Status Interoperable
*/
- (NSArray*)veryShortStandaloneWeekdaySymbols {
    return _getFormatterSymbols(self, kCFDateFormatterVeryShortStandaloneWeekdaySymbols);
}

/**
 @Status Interoperable
*/
- (NSArray*)monthSymbols {
    return _getFormatterSymbols(self, kCFDateFormatterMonthSymbols);
}

/**
 @Status Interoperable
*/
- (NSArray*)shortMonthSymbols {
    return _getFormatterSymbols(self, kCFDateFormatterShortMonthSymbols);
}

/**
 @Status Interoperable
*/
- (NSArray*)veryShortMonthSymbols {
    return _getFormatterSymbols(self, kCFDateFormatterVeryShortMonthSymbols);
}

/**
 @Status Interoperable
*/
- (NSArray*)standaloneMonthSymbols {
    return _getFormatterSymbols(self, kCFDateFormatterStandaloneMonthSymbols);
}

/**
 @Status Interoperable
*/
- (NSArray*)shortStandaloneMonthSymbols {
    return _getFormatterSymbols(self, kCFDateFormatterShortStandaloneMonthSymbols);
}

/**
 @Status Interoperable
*/
- (NSArray*)veryShortStandaloneMonthSymbols {
    return _getFormatterSymbols(self, kCFDateFormatterVeryShortStandaloneMonthSymbols);
}

/**
 @Status Interoperable
*/
- (NSArray*)quarterSymbols {
    return _getFormatterSymbols(self, kCFDateFormatterQuarterSymbols);
}

/**
 @Status Interoperable
*/
- (NSArray*)shortQuarterSymbols {
    return _getFormatterSymbols(self, kCFDateFormatterShortQuarterSymbols);
}

/**
 @Status Interoperable
*/
- (NSArray*)standaloneQuarterSymbols {
    return _getFormatterSymbols(self, kCFDateFormatterStandaloneQuarterSymbols);
}

/**
 @Status Interoperable
*/
- (NSArray*)shortStandaloneQuarterSymbols {
    return _getFormatterSymbols(self, kCFDateFormatterShortStandaloneQuarterSymbols);
}

/**
 @Status Interoperable
*/
- (NSArray*)eraSymbols {
    return _getFormatterSymbols(self, kCFDateFormatterEraSymbols);
}

/**
 @Status Interoperable
*/
- (NSArray*)longEraSymbols {
    return _getFormatterSymbols(self, kCFDateFormatterLongEraSymbols);
}

/**
 @Status Caveat
 @Notes NSCalendarMatchLast ignored.
 Issue 648: NSCalendar MatchLast Unsupported
 Issue 650: NSCalendar Certain Units Need Optimized
*/
- (void)enumerateDatesStartingAfterDate:(NSDate*)start
                     matchingComponents:(NSDateComponents*)comps
                                options:(NSCalendarOptions)opts
                             usingBlock:(void (^)(NSDate*, BOOL, BOOL*))block {
    return NSInvalidAbstractInvocation();
}

/**
 @Status Interoperable
*/
- (BOOL)date:(NSDate*)date matchesComponents:(NSDateComponents*)comps {
    THROW_NS_IF_NULL(E_INVALIDARG, date);
    THROW_NS_IF_NULL(E_INVALIDARG, comps);

    int length = 0;
    NSCalendarUnit unitFlags = 0;

    for (int i = 0; i < _countof(s_NSDateComponentsIndividualFlags); i++) {
        if ([comps valueForComponent:s_NSDateComponentsIndividualFlags[i]] != NSDateComponentUndefined) {
            unitFlags |= s_NSDateComponentsIndividualFlags[i];
            length++;
        }
    }

    NSDateComponents* comp = [self components:unitFlags fromDate:date];
    return [comp _componentsMatch:comps forUnits:unitFlags];
}

/**
 @Status Interoperable
 @Notes
*/
- (NSDate*)nextDateAfterDate:(NSDate*)date matchingComponents:(NSDateComponents*)comps options:(NSCalendarOptions)options {
    __block NSDate* result = nil;

    [self enumerateDatesStartingAfterDate:date
                       matchingComponents:comps
                                  options:options
                               usingBlock:^(NSDate* date, BOOL exactMatch, BOOL* stop) {
                                   result = date;
                                   *stop = YES;
                               }];

    return result;
}

/**
 @Status Interoperable
*/
- (NSDate*)nextDateAfterDate:(NSDate*)date
                matchingHour:(NSInteger)hourValue
                      minute:(NSInteger)minuteValue
                      second:(NSInteger)secondValue
                     options:(NSCalendarOptions)options {
    NSDateComponents* comps = [[[NSDateComponents alloc] init] autorelease];
    comps.hour = hourValue;
    comps.minute = minuteValue;
    comps.second = secondValue;
    return [self nextDateAfterDate:date matchingComponents:comps options:options];
}

/**
 @Status Interoperable
*/
- (NSDate*)nextDateAfterDate:(NSDate*)date matchingUnit:(NSCalendarUnit)unit value:(NSInteger)value options:(NSCalendarOptions)options {
    NSDateComponents* comps = [[[NSDateComponents alloc] init] autorelease];
    [comps setValue:value forComponent:unit];
    return [self nextDateAfterDate:date matchingComponents:comps options:options];
}

/**
 @Status Interoperable
 @Notes
*/
- (BOOL)nextWeekendStartDate:(NSDate* _Nullable*)datep
                    interval:(NSTimeInterval*)tip
                     options:(NSCalendarOptions)options
                   afterDate:(NSDate*)date {
    return NSInvalidAbstractInvocationReturn();
}

/**
 @Status Interoperable
*/
- (NSDate*)startOfDayForDate:(NSDate*)date {
    NSDate* returnDate = nil;

    [self rangeOfUnit:NSCalendarUnitDay startDate:&returnDate interval:nullptr forDate:date];

    return returnDate;
}

/**
 @Status Interoperable
*/
- (NSComparisonResult)compareDate:(NSDate*)date1 toDate:(NSDate*)date2 toUnitGranularity:(NSCalendarUnit)unit {
    double factor = 60.0;
    switch (unit) {
        case NSCalendarUnitCalendar:
            return NSOrderedSame;
        case NSCalendarUnitTimeZone:
            return NSOrderedSame;
        case NSCalendarUnitDay:
        case NSCalendarUnitHour: {
            NSTimeInterval timeOfDate1;
            NSDate* startOfDate1 = nil;
            [self rangeOfUnit:unit startDate:&startOfDate1 interval:&timeOfDate1 forDate:date1];

            NSTimeInterval startOfDate1Time = startOfDate1.timeIntervalSinceReferenceDate;
            NSTimeInterval timeOfDate2 = date2.timeIntervalSinceReferenceDate;

            if (startOfDate1Time <= timeOfDate2 && timeOfDate2 < startOfDate1Time + timeOfDate1) {
                return NSOrderedSame;
            }
            if (timeOfDate2 < startOfDate1Time) {
                return NSOrderedDescending;
            }
            return NSOrderedAscending;
        }
        case NSCalendarUnitSecond:
            // Eliminate the factor step, we want to work with raw seconds.
            factor = 1;
        case NSCalendarUnitMinute: {
            NSTimeInterval date1value = 0;
            NSTimeInterval date2value = 0;
            modf(date1.timeIntervalSinceReferenceDate, &date1value);
            modf(date2.timeIntervalSinceReferenceDate, &date2value);
            date1value = floor(date1value / factor);
            date2value = floor(date2value / factor);
            if (date1value == date2value) {
                return NSOrderedSame;
            }
            if (date2value < date1value) {
                return NSOrderedDescending;
            }
            return NSOrderedAscending;
        }
        case NSCalendarUnitNanosecond: {
            float time1 = 0;
            float time2 = 0;
            double frac1 = modf(date1.timeIntervalSinceReferenceDate, &time1);
            double frac2 = modf(date2.timeIntervalSinceReferenceDate, &time2);

            if (time1 > time2) {
                return NSOrderedDescending;
            } else if (time1 < time2) {
                return NSOrderedAscending;
            }

            time1 = floor(frac1 * 1000000000.0);
            time2 = floor(frac2 * 1000000000.0);

            if (time1 > time2) {
                return NSOrderedDescending;
            } else if (time1 < time2) {
                return NSOrderedAscending;
            }
            return NSOrderedSame;
        }
    }

    int length = 4;
    NSCalendarUnit units[5];

    if (unit == NSCalendarUnitYearForWeekOfYear || unit == NSCalendarUnitWeekOfYear) {
        units[0] = NSCalendarUnitEra;
        units[1] = NSCalendarUnitYearForWeekOfYear;
        units[2] = NSCalendarUnitWeekOfYear;
        units[3] = NSCalendarUnitWeekday;
        units[4] = 0;
    } else if (unit == NSCalendarUnitWeekdayOrdinal) {
        units[0] = NSCalendarUnitEra;
        units[1] = NSCalendarUnitYear;
        units[2] = NSCalendarUnitMonth;
        units[3] = NSCalendarUnitWeekdayOrdinal;
        units[4] = NSCalendarUnitDay;
        length = 5;
    } else if (unit == NSCalendarUnitWeekday || unit == NSCalendarUnitWeekOfMonth) {
        units[0] = NSCalendarUnitEra;
        units[1] = NSCalendarUnitYear;
        units[2] = NSCalendarUnitMonth;
        units[3] = NSCalendarUnitWeekOfMonth;
        units[4] = NSCalendarUnitWeekday;
        length = 5;
    } else {
        units[0] = NSCalendarUnitEra;
        units[1] = NSCalendarUnitYear;
        units[2] = NSCalendarUnitMonth;
        units[3] = NSCalendarUnitDay;
        units[4] = 0;
    }

    NSCalendarUnit combinedUnits = units[0] | units[1] | units[2] | units[3] | units[4];
    NSDateComponents* comp1 = [self components:combinedUnits fromDate:date1];
    NSDateComponents* comp2 = [self components:combinedUnits fromDate:date2];

    for (int i = 0; i < length; i++) {
        NSCalendarUnit unit = units[i];
        NSInteger value1 = [comp1 valueForComponent:unit];
        NSInteger value2 = [comp2 valueForComponent:unit];
        if (value1 > value2) {
            return NSOrderedDescending;
        } else if (value1 < value2) {
            return NSOrderedAscending;
        }
        if (unit == NSCalendarUnitMonth && self.calendarIdentifier == NSCalendarIdentifierChinese) {
            BOOL leap1 = comp1.leapMonth;
            BOOL leap2 = comp2.leapMonth;
            if (!leap1 && leap2) {
                return NSOrderedAscending;
            } else if (leap1 && !leap2) {
                return NSOrderedDescending;
            }
        }
    }
    return NSOrderedSame;
}

/**
 @Status Interoperable
*/
- (BOOL)isDateInWeekend:(NSDate*)date {
    return NSInvalidAbstractInvocationReturn();
}

/**
 @Status Interoperable
*/
- (NSDateComponents*)components:(NSCalendarUnit)unitFlags
             fromDateComponents:(NSDateComponents*)startingDateComp
               toDateComponents:(NSDateComponents*)resultDateComp
                        options:(NSCalendarOptions)options {
    THROW_NS_IF_NULL(E_INVALIDARG, startingDateComp);
    THROW_NS_IF_NULL(E_INVALIDARG, resultDateComp);

    NSDate* fromDate = [self dateFromComponents:startingDateComp];
    NSDate* toDate = [self dateFromComponents:resultDateComp];

    return [self components:unitFlags fromDate:fromDate toDate:toDate options:options];
}

/**
 @Status Interoperable
*/
- (BOOL)rangeOfWeekendStartDate:(NSDate* _Nullable*)datep interval:(NSTimeInterval*)tip containingDate:(NSDate*)date {
    // If the target date is in a weekend
    if ([self isDateInWeekend:date]) {
        // Find start of weekend date by searching backwards from this date.
        if ([self nextWeekendStartDate:datep interval:tip options:NSCalendarSearchBackwards afterDate:date]) {
            return YES;
        }
    }
    return NO;
}

/**
 @Status Interoperable
*/
- (NSDate*)dateByAddingUnit:(NSCalendarUnit)unit value:(NSInteger)value toDate:(NSDate*)date options:(NSCalendarOptions)options {
    NSDateComponents* comps = [[[NSDateComponents alloc] init] autorelease];

    [comps setValue:value forComponent:unit];
    return [self dateByAddingComponents:comps to:date options:options];
}

/**
 @Status Interoperable
*/
- (NSDate*)dateBySettingHour:(NSInteger)h minute:(NSInteger)m second:(NSInteger)s ofDate:(NSDate*)date options:(NSCalendarOptions)opts {
    // Create components matching the time of this requested date
    NSDateComponents* comps = [[[NSDateComponents alloc] init] autorelease];

    comps.hour = h;
    comps.minute = m;
    comps.second = s;
    NSCalendarOptions options = NSCalendarMatchNextTime;
    if ((opts & NSCalendarMatchLast) != 0) {
        options |= NSCalendarMatchLast;
    } else {
        options |= NSCalendarMatchFirst;
    }

    if ((opts & NSCalendarMatchStrictly) != 0) {
        options |= NSCalendarMatchStrictly;
    }

    // Create a temporary date that exists just before the expected requested date
    NSDate* tempDate;

    [self rangeOfUnit:NSCalendarUnitDay startDate:&tempDate interval:nullptr forDate:date];

    // Find an exact date that matches this requested time
    NSDate* result = [self nextDateAfterDate:tempDate matchingComponents:comps options:options];

    return result;
}

/**
 @Status Interoperable
 @Notes
*/
- (NSDate*)dateBySettingUnit:(NSCalendarUnit)unit value:(NSInteger)v ofDate:(NSDate*)date options:(NSCalendarOptions)opts {
    // Create target components based on changed unit

    NSInteger currentValue = [self component:unit fromDate:date];

    if (currentValue == v) {
        return date;
    }

    NSDateComponents* targetComp = [[[NSDateComponents alloc] init] autorelease];

    [targetComp setValue:v forComponent:unit];

    // Validate that this target component actually resolves to a real date
    __block NSDate* result = nil;
    [self enumerateDatesStartingAfterDate:date
                       matchingComponents:targetComp
                                  options:(NSCalendarMatchNextTime | opts)
                               usingBlock:^(NSDate* date, BOOL exactMatch, BOOL* stop) {
                                   result = date;
                                   *stop = YES;
                               }];

    return result;
}

/**
 @Status Interoperable
*/
- (NSDate*)dateWithEra:(NSInteger)eraValue
                  year:(NSInteger)yearValue
                 month:(NSInteger)monthValue
                   day:(NSInteger)dayValue
                  hour:(NSInteger)hourValue
                minute:(NSInteger)minuteValue
                second:(NSInteger)secondValue
            nanosecond:(NSInteger)nanosecondValue {
    NSDateComponents* comps = [[[NSDateComponents alloc] init] autorelease];

    comps.era = eraValue;
    comps.year = yearValue;
    comps.month = monthValue;
    comps.day = dayValue;
    comps.hour = hourValue;
    comps.minute = minuteValue;
    comps.second = secondValue;
    comps.nanosecond = nanosecondValue;

    return [self dateFromComponents:comps];
}

/**
 @Status Interoperable
*/
- (NSDate*)dateWithEra:(NSInteger)eraValue
     yearForWeekOfYear:(NSInteger)yearValue
            weekOfYear:(NSInteger)weekValue
               weekday:(NSInteger)weekdayValue
                  hour:(NSInteger)hourValue
                minute:(NSInteger)minuteValue
                second:(NSInteger)secondValue
            nanosecond:(NSInteger)nanosecondValue {
    NSDateComponents* comps = [[[NSDateComponents alloc] init] autorelease];

    comps.era = eraValue;
    comps.yearForWeekOfYear = yearValue;
    comps.weekOfYear = weekValue;
    comps.weekday = weekdayValue;
    comps.hour = hourValue;
    comps.minute = minuteValue;
    comps.second = secondValue;
    comps.nanosecond = nanosecondValue;

    return [self dateFromComponents:comps];
}

/**
 @Status Interoperable
*/
- (BOOL)isDateInToday:(NSDate*)date {
    return [self compareDate:date toDate:[NSDate date] toUnitGranularity:NSCalendarUnitDay] == NSOrderedSame;
}

/**
 @Status Interoperable
*/
- (BOOL)isDate:(NSDate*)date1 equalToDate:(NSDate*)date2 toUnitGranularity:(NSCalendarUnit)unit {
    return [self compareDate:date1 toDate:date2 toUnitGranularity:unit] == NSOrderedSame;
}

/**
 @Status Interoperable
*/
- (BOOL)isDate:(NSDate*)date1 inSameDayAsDate:(NSDate*)date2 {
    return [self compareDate:date1 toDate:date2 toUnitGranularity:NSCalendarUnitDay] == NSOrderedSame;
}

/**
 @Status Interoperable
*/
- (BOOL)isDateInTomorrow:(NSDate*)date {
    NSDateComponents* oneDay = [[[NSDateComponents alloc] init] autorelease];
    oneDay.day = 1;
    NSDate* tomorrow = [self dateByAddingComponents:oneDay toDate:[NSDate date] options:0];
    return [self compareDate:tomorrow toDate:date toUnitGranularity:NSCalendarUnitDay] == NSOrderedSame;
}

/**
 @Status Interoperable
*/
- (BOOL)isDateInYesterday:(NSDate*)date {
    NSDateComponents* oneDay = [[[NSDateComponents alloc] init] autorelease];
    oneDay.day = -1;
    NSDate* yesterday = [self dateByAddingComponents:oneDay toDate:[NSDate date] options:0];
    return [self compareDate:yesterday toDate:date toUnitGranularity:NSCalendarUnitDay] == NSOrderedSame;
}

/**
 @Status Interoperable
*/
- (void)getEra:(NSInteger*)eraValuePointer
          year:(NSInteger*)yearValuePointer
         month:(NSInteger*)monthValuePointer
           day:(NSInteger*)dayValuePointer
      fromDate:(NSDate*)date {
    NSCalendarUnit unitFlags = NSCalendarUnitEra | NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay;
    NSDateComponents* comps = [self components:unitFlags fromDate:date];

    if (eraValuePointer != nullptr) {
        *eraValuePointer = comps.era;
    }
    if (yearValuePointer != nullptr) {
        *yearValuePointer = comps.year;
    }
    if (monthValuePointer != nullptr) {
        *monthValuePointer = comps.month;
    }
    if (dayValuePointer != nullptr) {
        *dayValuePointer = comps.day;
    }
}

/**
 @Status Interoperable
*/
- (void)getEra:(NSInteger*)eraValuePointer
    yearForWeekOfYear:(NSInteger*)yearValuePointer
           weekOfYear:(NSInteger*)weekValuePointer
              weekday:(NSInteger*)weekdayValuePointer
             fromDate:(NSDate*)date {
    NSCalendarUnit unitFlags = NSCalendarUnitEra | NSCalendarUnitYearForWeekOfYear | NSCalendarUnitWeekOfYear | NSCalendarUnitWeekday;
    NSDateComponents* comps = [self components:unitFlags fromDate:date];

    if (eraValuePointer != nullptr) {
        *eraValuePointer = comps.era;
    }
    if (yearValuePointer != nullptr) {
        *yearValuePointer = comps.yearForWeekOfYear;
    }
    if (weekValuePointer != nullptr) {
        *weekValuePointer = comps.weekOfYear;
    }
    if (weekdayValuePointer != nullptr) {
        *weekdayValuePointer = comps.weekday;
    }
}

/**
 @Status Interoperable
*/
- (NSInteger)component:(NSCalendarUnit)unit fromDate:(NSDate*)date {
    NSDateComponents* comps = [self components:unit fromDate:date];
    NSInteger result = [comps valueForComponent:unit];
    return result;
}

/**
 @Status Interoperable
*/
- (NSDateComponents*)componentsInTimeZone:(NSTimeZone*)timezone fromDate:(NSDate*)date {
    NSTimeZone* oldTz = self.timeZone;
    self.timeZone = timezone;

    NSDateComponents* comps = [self components:s_NSDateComponentsAllFlagOptions fromDate:date];
    self.timeZone = oldTz;

    return comps;
}

/**
 @Status Interoperable
*/
- (void)getHour:(NSInteger*)hourValuePointer
         minute:(NSInteger*)minuteValuePointer
         second:(NSInteger*)secondValuePointer
     nanosecond:(NSInteger*)nanosecondValuePointer
       fromDate:(NSDate*)date {
    NSCalendarUnit unitFlags = NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond | NSCalendarUnitNanosecond;
    NSDateComponents* comps = [self components:unitFlags fromDate:date];

    if (hourValuePointer != nullptr) {
        *hourValuePointer = comps.hour;
    }
    if (minuteValuePointer != nullptr) {
        *minuteValuePointer = comps.minute;
    }
    if (secondValuePointer != nullptr) {
        *secondValuePointer = comps.second;
    }
    if (nanosecondValuePointer != nullptr) {
        *nanosecondValuePointer = comps.nanosecond;
    }
}

@end
