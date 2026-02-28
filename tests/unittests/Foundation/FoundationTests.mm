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

#import <TestFramework.h>
#import <Foundation/Foundation.h>
#import <mach/mach_time.h>
#import <Starboard/SmartTypes.h>

TEST(Sanity, SanityTest) {
    LOG_INFO("Foundation sanity test: ");

    /*** NSArray ***/
    NSArray* arr1 = [NSArray arrayWithObject:@1];
    NSArray* arr2 = [NSArray arrayWithObject:@1];
    NSArray* arr3 = [NSArray arrayWithObject:@2];

    ASSERT_OBJCEQ_MSG(arr1, arr2, "FAILED: arr1 and arr2 should be equal!\n");
    ASSERT_OBJCNE_MSG(arr1, arr3, "FAILED: arr1 and arr2 should not be equal!\n");
    ASSERT_OBJCEQ_MSG(arr1[0], arr2[0], "FAILED: arr1[0] and arr2[0] should be equal!\n");
    ASSERT_OBJCNE_MSG(arr1[0], arr3[0], "FAILED: arr1[0] and arr3[0] should not be equal!\n");

    /*** NSCalendar ***/
    //  Feb 14, 2012 12:00 GMT (leap year)
    NSDate* startDate = [NSDate dateWithTimeIntervalSince1970:1329220800.0];
    //  Apr 1, 2012 12:00 GMT
    NSDate* endDate = [NSDate dateWithTimeIntervalSince1970:1333281600.0];

    NSTimeZone* curTZ = [NSTimeZone timeZoneWithName:@"America/Los_Angeles"];

    ASSERT_FALSE([curTZ isDaylightSavingTimeForDate:startDate]);
    ASSERT_TRUE([curTZ isDaylightSavingTimeForDate:endDate]);

    NSCalendar* curCal = [NSCalendar currentCalendar];
    [curCal setTimeZone:curTZ];

    // Disabled until bridging NSCalendar is complete: 7332396
    // NSDateComponents* component1 = [curCal components:NSSecondCalendarUnit | NSMinuteCalendarUnit | NSHourCalendarUnit |
    // NSDayCalendarUnit |
    //                                                   NSMonthCalendarUnit | NSYearCalendarUnit
    //                                          fromDate:startDate];
    // ASSERT_FALSE_MSG(component1.second != 0 || component1.minute != 0 || component1.hour != 4 || component1.day != 14 ||
    //                      component1.month != 2 || component1.year != 2012,
    //                  "FAILED: component1 not accurate: %d %d %d %d %d %d\n",
    //                  component1.second,
    //                  component1.minute,
    //                  component1.hour,
    //                  component1.day,
    //                  component1.month,
    //                  component1.year);
    //
    // NSDateComponents* comp1 = [curCal components:NSSecondCalendarUnit | NSMinuteCalendarUnit | NSHourCalendarUnit | NSDayCalendarUnit |
    //                                              NSMonthCalendarUnit | NSYearCalendarUnit
    //                                     fromDate:startDate
    //                                       toDate:endDate
    //                                      options:0];
    //
    // ASSERT_FALSE_MSG(comp1.second != 0 || comp1.minute != 0 || comp1.hour != 1 || comp1.day != 18 || comp1.month != 1 || comp1.year != 0,
    //                  "FAILED: component1 not accurate: %d %d %d %d %d %d\n",
    //                  component1.second,
    //                  component1.minute,
    //                  component1.hour,
    //                  component1.day,
    //                  component1.month,
    //                  component1.year);
    //
    // NSDateComponents* comp2 = [curCal components:NSSecondCalendarUnit fromDate:startDate toDate:endDate options:0];
    // ASSERT_EQ_MSG(comp2.second, 4060800, "FAILED: comp2 not accurate: %d\n", comp2.second);
    //
}

@interface TestKVOSelfObserver : NSObject {
    id _dummy;
}
@end
@implementation TestKVOSelfObserver
- (id)init {
    if (self = [super init]) {
        [self addObserver:self forKeyPath:@"dummy" options:0 context:nullptr];
    }
    return self;
}
- (void)dealloc {
    [self removeObserver:self forKeyPath:@"dummy"];
    [super dealloc];
}
@end

@interface TestKVOChange : NSObject
@property (nonatomic, copy) NSString* keypath;
@property (nonatomic, assign /*weak but no arc*/) id object;
@property (nonatomic, copy) NSDictionary* info;
@property (nonatomic, assign) void* context;
@end
@implementation TestKVOChange
+ (id)changeWithKeypath:(NSString*)keypath object:(id)object info:(NSDictionary*)info context:(void*)context {
    TestKVOChange* change = [[[self alloc] init] autorelease];
    change.keypath = keypath;
    change.object = object;
    change.info = info;
    change.context = context;
    return change;
}
@end

@interface TestKVOObserver : NSObject {
    NSMutableDictionary* _changedKeypaths;
}
- (void)observeValueForKeyPath:(NSString*)keypath ofObject:(id)object change:(NSDictionary*)change context:(void*)context;
- (NSSet*)changesForKeypath:(NSString*)keypath;
- (NSInteger)numberOfObservedChanges;
@end

@implementation TestKVOObserver
- (id)init {
    if (self = [super init]) {
        _changedKeypaths = [NSMutableDictionary dictionary];
    }
    return self;
}
- (void)observeValueForKeyPath:(NSString*)keypath ofObject:(id)object change:(NSDictionary*)change context:(void*)context {
    @synchronized(self) {
        NSMutableSet* changeSet = _changedKeypaths[keypath];
        if (!changeSet) {
            changeSet = [NSMutableSet set];
            _changedKeypaths[keypath] = changeSet;
        }
        [changeSet addObject:[TestKVOChange changeWithKeypath:keypath object:object info:change context:context]];
    }
}
- (NSSet*)changesForKeypath:(NSString*)keypath {
    @synchronized(self) {
        return [_changedKeypaths[keypath] copy];
    }
}
- (void)clear {
    @synchronized(self) {
        [_changedKeypaths removeAllObjects];
    }
}
- (NSInteger)numberOfObservedChanges {
    @synchronized(self) {
        NSInteger accumulator = 0;
        for (NSString* keypath in [_changedKeypaths allKeys]) {
            accumulator += [[_changedKeypaths objectForKey:keypath] count];
        }
        return accumulator;
    }
}
@end

struct TestKVOStruct {
    int a, b, c;
};

@interface TestKVOObject : NSObject {
    StrongId<NSString> _internal_derivedObjectProperty;
    StrongId<NSString> _internal_keyDerivedTwoTimes;
    int _manuallyNotifyingIntegerProperty;
    int _ivarWithoutSetter;
}

@property (nonatomic, retain) NSString* nonNotifyingObjectProperty;

@property (nonatomic, retain) NSString* basicObjectProperty;
@property (nonatomic, assign) uint32_t basicPodProperty;
@property (nonatomic, assign) TestKVOStruct structProperty;

// derivedObjectProperty is derived from basicObjectProperty.
@property (nonatomic, readonly) NSString* derivedObjectProperty;

@property (nonatomic, retain) TestKVOObject* cascadableKey;
@property (nonatomic, readonly) TestKVOObject* derivedCascadableKey;

@property (nonatomic, retain) id recursiveDependent1;
@property (nonatomic, retain) id recursiveDependent2;

@property (nonatomic, retain) NSMutableDictionary* dictionaryProperty;

@property (nonatomic, retain) id boolTrigger1;
@property (nonatomic, retain) id boolTrigger2;
@property (nonatomic, readonly) bool dependsOnTwoKeys;

// This modifies the internal integer property and notifies about it.
- (void)incrementManualIntegerProperty;
@end

@implementation TestKVOObject
- (void)dealloc {
    [_cascadableKey release];
    [_nonNotifyingObjectProperty release];
    [_basicObjectProperty release];
    [_recursiveDependent1 release];
    [_recursiveDependent2 release];
    [_dictionaryProperty release];
    [_boolTrigger1 release];
    [_boolTrigger2 release];
    [super dealloc];
}

+ (NSSet*)keyPathsForValuesAffectingDerivedObjectProperty {
    return [NSSet setWithObject:@"basicObjectProperty"];
}

+ (NSSet*)keyPathsForValuesAffectingRecursiveDependent1 {
    return [NSSet setWithObject:@"recursiveDependent2"];
}

+ (NSSet*)keyPathsForValuesAffectingRecursiveDependent2 {
    return [NSSet setWithObject:@"recursiveDependent1"];
}

+ (NSSet*)keyPathsForValuesAffectingDerivedCascadableKey {
    return [NSSet setWithObject:@"cascadableKey"];
}

+ (NSSet*)keyPathsForValuesAffectingKeyDependentOnSubKeypath {
    return [NSSet setWithObject:@"dictionaryProperty.subDictionary"];
}

+ (NSSet*)keyPathsForValuesAffectingKeyDerivedTwoTimes {
    return [NSSet setWithObject:@"derivedObjectProperty"];
}

+ (NSSet*)keyPathsForValuesAffectingDependsOnTwoKeys {
    return [NSSet setWithArray:@[ @"boolTrigger1", @"boolTrigger2" ]];
}

+ (NSSet*)keyPathsForValuesAffectingDependsOnTwoSubKeys {
    return [NSSet setWithArray:@[ @"cascadableKey.boolTrigger1", @"cascadableKey.boolTrigger2" ]];
}

- (bool)dependsOnTwoKeys {
    return _boolTrigger1 != nil && _boolTrigger2 != nil;
}

- (bool)dependsOnTwoSubKeys {
    return _cascadableKey.boolTrigger1 != nil && _cascadableKey.boolTrigger2 != nil;
}

- (id)keyDependentOnSubKeypath {
    return _dictionaryProperty[@"subDictionary"];
}

+ (BOOL)automaticallyNotifiesObserversOfManuallyNotifyingIntegerProperty {
    return NO;
}

+ (BOOL)automaticallyNotifiesObserversOfNonNotifyingObjectProperty {
    return NO;
}

- (NSString*)derivedObjectProperty {
    return _internal_derivedObjectProperty;
}

- (void)setBasicObjectProperty:(NSString*)basicObjectProperty {
    [_basicObjectProperty release];
    _basicObjectProperty = [basicObjectProperty retain];
    _internal_derivedObjectProperty = [NSString stringWithFormat:@"!!!%@!!!", _basicObjectProperty];
    _internal_keyDerivedTwoTimes = [NSString stringWithFormat:@"---%@---", [self derivedObjectProperty]];
}

- (NSString*)keyDerivedTwoTimes {
    return _internal_keyDerivedTwoTimes;
}

- (TestKVOObject*)derivedCascadableKey {
    return _cascadableKey;
}

- (void)incrementManualIntegerProperty {
    [self willChangeValueForKey:@"manuallyNotifyingIntegerProperty"];
    _manuallyNotifyingIntegerProperty++;
    [self didChangeValueForKey:@"manuallyNotifyingIntegerProperty"];
}
@end

@interface TestKVOObject2 : NSObject
@property (nonatomic, assign) float someFloat;
@end
@implementation TestKVOObject2
@end

TEST(KVO, BasicChangeNotification) { // Basic change notification
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    TestKVOObject* observed = [[[TestKVOObject alloc] init] autorelease];
    TestKVOObserver* observer = [[[TestKVOObserver alloc] init] autorelease];

    [observed addObserver:observer forKeyPath:@"basicObjectProperty" options:NSKeyValueObservingOptionNew context:NULL];
    observed.basicObjectProperty = @"Hello";

    EXPECT_EQ_MSG([[observer changesForKeypath:@"basicObjectProperty"] count], 1, "One change on basicObjectProperty should have fired.");
    EXPECT_EQ_MSG([[observer changesForKeypath:@"basicPodProperty"] count], 0, "Zero changes on basicPodProperty should have fired.");
    EXPECT_EQ_MSG([[observer changesForKeypath:@"derivedObjectProperty"] count],
                  0,
                  "Zero changes on derivedObjectProperty should have fired.");

    EXPECT_OBJCEQ_MSG([[[observer changesForKeypath:@"basicObjectProperty"] anyObject] object],
                      observed,
                      "The notification object should match the observed object.");
    EXPECT_OBJCEQ_MSG(nil,
                      [[[[observer changesForKeypath:@"basicObjectProperty"] anyObject] info] objectForKey:NSKeyValueChangeOldKey],
                      "There should be no old value included in the change notification.");
    EXPECT_OBJCEQ_MSG([[[[observer changesForKeypath:@"basicObjectProperty"] anyObject] info] objectForKey:NSKeyValueChangeNewKey],
                      @"Hello",
                      "The new value stored in the change notification should be Hello.");
    EXPECT_NO_THROW([observed removeObserver:observer forKeyPath:@"basicObjectProperty"]);
    EXPECT_NO_THROW([pool release]);
}

TEST(KVO, ExclusiveChangeNotification) { // Exclusive change notification
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    TestKVOObject* observed = [[[TestKVOObject alloc] init] autorelease];
    TestKVOObserver* observer = [[[TestKVOObserver alloc] init] autorelease];
    TestKVOObserver* observer2 = [[[TestKVOObserver alloc] init] autorelease];

    [observed addObserver:observer forKeyPath:@"basicObjectProperty" options:NSKeyValueObservingOptionNew context:NULL];
    [observed addObserver:observer2 forKeyPath:@"basicPodProperty" options:NSKeyValueObservingOptionNew context:NULL];
    observed.basicObjectProperty = @"Hello";
    observed.basicPodProperty = 1;

    EXPECT_EQ_MSG([[observer changesForKeypath:@"basicObjectProperty"] count], 1, "One change on basicObjectProperty should have fired.");
    EXPECT_EQ_MSG([[observer2 changesForKeypath:@"basicObjectProperty"] count],
                  0,
                  "No changes on basicObjectProperty for second observer should have fired.");
    EXPECT_EQ_MSG([[observer2 changesForKeypath:@"basicPodProperty"] count], 1, "One change on basicPodProperty should have fired.");
    EXPECT_EQ_MSG([[observer changesForKeypath:@"basicPodProperty"] count],
                  0,
                  "No changes on basicPodProperty for second observer should have fired.");

    EXPECT_NO_THROW([observed removeObserver:observer forKeyPath:@"basicObjectProperty"]);
    EXPECT_NO_THROW([observed removeObserver:observer2 forKeyPath:@"basicPodProperty"]);
    EXPECT_NO_THROW([pool release]);
}

TEST(KVO, ManualChangeNotification) { // Manual change notification.
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    TestKVOObject* observed = [[[TestKVOObject alloc] init] autorelease];
    TestKVOObserver* observer = [[[TestKVOObserver alloc] init] autorelease];

    [observed addObserver:observer forKeyPath:@"manuallyNotifyingIntegerProperty" options:NSKeyValueObservingOptionNew context:NULL];
    [observed incrementManualIntegerProperty];

    EXPECT_EQ_MSG([[observer changesForKeypath:@"manuallyNotifyingIntegerProperty"] count],
                  1,
                  "One change on manuallyNotifyingIntegerProperty should have fired.");

    EXPECT_OBJCEQ_MSG([[[[observer changesForKeypath:@"manuallyNotifyingIntegerProperty"] anyObject] info]
                          objectForKey:NSKeyValueChangeNewKey],
                      @(1),
                      "The new value stored in the change notification should be a boxed 1.");

    EXPECT_NO_THROW([observed removeObserver:observer forKeyPath:@"manuallyNotifyingIntegerProperty"]);
    EXPECT_NO_THROW([pool release]);
}

TEST(KVO, BasicChangeCaptureOld) { // Basic change notification with Old Value
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    TestKVOObject* observed = [[[TestKVOObject alloc] init] autorelease];
    TestKVOObserver* observer = [[[TestKVOObserver alloc] init] autorelease];

    [observed addObserver:observer forKeyPath:@"basicObjectProperty" options:NSKeyValueObservingOptionOld context:NULL];
    observed.basicObjectProperty = @"Hello";

    EXPECT_EQ_MSG([[observer changesForKeypath:@"basicObjectProperty"] count], 1, "One change on basicObjectProperty should have fired.");

    EXPECT_OBJCEQ_MSG([[[[observer changesForKeypath:@"basicObjectProperty"] anyObject] info] objectForKey:NSKeyValueChangeOldKey],
                      [NSNull null],
                      "The old value stored in the change notification should be null.");

    EXPECT_NO_THROW([observed removeObserver:observer forKeyPath:@"basicObjectProperty"]);
    EXPECT_NO_THROW([pool release]);
}

TEST(KVO, CascadingNotificationWithEmptyLeaf) { // Cascading change notification testing subscribing to nil AND
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    // property replacement
    TestKVOObject* observed = [[[TestKVOObject alloc] init] autorelease];
    TestKVOObserver* observer = [[[TestKVOObserver alloc] init] autorelease];

    [observed addObserver:observer
               forKeyPath:@"cascadableKey.basicObjectProperty"
                  options:NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew
                  context:NULL];

    TestKVOObject* subObject = [[[TestKVOObject alloc] init] autorelease];
    subObject.basicObjectProperty = @"Hello";
    observed.cascadableKey = subObject;

    EXPECT_EQ_MSG([[observer changesForKeypath:@"cascadableKey.basicObjectProperty"] count],
                  1,
                  "One change on cascadableKey.basicObjectProperty should have fired.");

    EXPECT_OBJCEQ_MSG([[[[observer changesForKeypath:@"cascadableKey.basicObjectProperty"] anyObject] info]
                          objectForKey:NSKeyValueChangeOldKey],
                      [NSNull null],
                      "The old value stored in the change notification should be null.");

    [observer clear];

    TestKVOObject* subObject2 = [[[TestKVOObject alloc] init] autorelease];
    subObject2.basicObjectProperty = @"Hello";
    observed.cascadableKey = subObject2;

    EXPECT_EQ_MSG([[observer changesForKeypath:@"cascadableKey.basicObjectProperty"] count],
                  1,
                  "A second change on cascadableKey.basicObjectProperty should have fired.");

    subObject.basicObjectProperty = @"Spurious?";

    EXPECT_NE_MSG([[observer changesForKeypath:@"cascadableKey.basicObjectProperty"] count],
                  2,
                  "A change to the detached subkey should not have triggered a spurious notification.");

    EXPECT_OBJCEQ_MSG([[[[observer changesForKeypath:@"cascadableKey.basicObjectProperty"] anyObject] info]
                          objectForKey:NSKeyValueChangeOldKey],
                      @"Hello",
                      "The old value stored in the change notification should be Hello.");

    EXPECT_NO_THROW([observed removeObserver:observer forKeyPath:@"cascadableKey.basicObjectProperty"]);
    EXPECT_NO_THROW([pool release]);
}

TEST(KVO, PriorNotification) { // Basic change notification with a Prior notification requested
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    TestKVOObject* observed = [[[TestKVOObject alloc] init] autorelease];
    TestKVOObserver* observer = [[[TestKVOObserver alloc] init] autorelease];

    [observed addObserver:observer
               forKeyPath:@"basicObjectProperty"
                  options:NSKeyValueObservingOptionOld | NSKeyValueObservingOptionPrior
                  context:NULL];
    observed.basicObjectProperty = @"Hello";

    EXPECT_EQ_MSG([[observer changesForKeypath:@"basicObjectProperty"] count],
                  2,
                  "Two changes on basicObjectProperty should have fired (one prior change).");

    EXPECT_OBJCEQ_MSG([[[[observer changesForKeypath:@"basicObjectProperty"] anyObject] info] objectForKey:NSKeyValueChangeOldKey],
                      [NSNull null],
                      "The old value stored in the change notification should be null or nil.");

    EXPECT_NO_THROW([observed removeObserver:observer forKeyPath:@"basicObjectProperty"]);
    EXPECT_NO_THROW([pool release]);
}

TEST(KVO, DependentKeyNotification) { // Derived change notification (dependent keys)
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    TestKVOObject* observed = [[[TestKVOObject alloc] init] autorelease];
    TestKVOObserver* observer = [[[TestKVOObserver alloc] init] autorelease];

    [observed addObserver:observer forKeyPath:@"derivedObjectProperty" options:NSKeyValueObservingOptionNew context:NULL];
    observed.basicObjectProperty = @"Hello";

    EXPECT_EQ_MSG([[observer changesForKeypath:@"basicObjectProperty"] count],
                  0,
                  "No changes on basicObjectProperty should have fired (we did not register for it).");
    EXPECT_EQ_MSG([[observer changesForKeypath:@"derivedObjectProperty"] count],
                  1,
                  "One change on derivedObjectProperty should have fired.");
    EXPECT_NO_THROW([observed removeObserver:observer forKeyPath:@"derivedObjectProperty"]);

    EXPECT_OBJCEQ_MSG([[[[observer changesForKeypath:@"derivedObjectProperty"] anyObject] info] objectForKey:NSKeyValueChangeNewKey],
                      @"!!!Hello!!!",
                      "The new value stored in the change notification should be !!!Hello!!! (the derived object).");
    EXPECT_NO_THROW([pool release]);
}

TEST(KVO, PODNotification) { // Notification on a plain old data property (non-object)
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    TestKVOObject* observed = [[[TestKVOObject alloc] init] autorelease];
    TestKVOObserver* observer = [[[TestKVOObserver alloc] init] autorelease];

    [observed addObserver:observer forKeyPath:@"basicPodProperty" options:NSKeyValueObservingOptionNew context:NULL];
    observed.basicPodProperty = 10;

    EXPECT_EQ_MSG([[observer changesForKeypath:@"basicPodProperty"] count], 1, "One change on basicPodProperty should have fired.");

    EXPECT_TRUE_MSG([[[[[observer changesForKeypath:@"basicPodProperty"] anyObject] info] objectForKey:NSKeyValueChangeNewKey]
                        isKindOfClass:[NSNumber class]],
                    "The new value stored in the change notification should be an NSNumber instance.");
    EXPECT_OBJCEQ_MSG([[[[observer changesForKeypath:@"basicPodProperty"] anyObject] info] objectForKey:NSKeyValueChangeNewKey],
                      @(10),
                      "The new value stored in the change notification should be a boxed 10.");

    EXPECT_NO_THROW([observed removeObserver:observer forKeyPath:@"basicPodProperty"]);
    EXPECT_NO_THROW([pool release]);
}

TEST(KVO, StructNotification) { // Basic change notification on a struct type
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    TestKVOObject* observed = [[[TestKVOObject alloc] init] autorelease];
    TestKVOObserver* observer = [[[TestKVOObserver alloc] init] autorelease];

    EXPECT_EQ_MSG([[observer changesForKeypath:@"basicObjectProperty"] count], 0, "No changes on basicObjectProperty should have fired.");
    [observed addObserver:observer forKeyPath:@"structProperty" options:NSKeyValueObservingOptionNew context:NULL];
    observed.structProperty = TestKVOStruct{ 1, 2, 3 };

    EXPECT_EQ_MSG([[observer changesForKeypath:@"structProperty"] count], 1, "One change on structProperty should have fired.");

    EXPECT_TRUE_MSG([[[[[observer changesForKeypath:@"structProperty"] anyObject] info] objectForKey:NSKeyValueChangeNewKey]
                        isKindOfClass:[NSValue class]],
                    "The new value stored in the change notification should be an NSValue instance.");
    EXPECT_STREQ_MSG([[[[[observer changesForKeypath:@"structProperty"] anyObject] info] objectForKey:NSKeyValueChangeNewKey] objCType],
                     @encode(TestKVOStruct),
                     "The new objc type stored in the change notification should have an objc type matching our Struct.");

    EXPECT_NO_THROW([observed removeObserver:observer forKeyPath:@"structProperty"]);
    EXPECT_NO_THROW([pool release]);
}

TEST(KVO, DisabledNotification) { // No notification for non-notifying keypaths.
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    TestKVOObject* observed = [[[TestKVOObject alloc] init] autorelease];
    TestKVOObserver* observer = [[[TestKVOObserver alloc] init] autorelease];

    [observed addObserver:observer forKeyPath:@"nonNotifyingObjectProperty" options:NSKeyValueObservingOptionNew context:NULL];
    observed.nonNotifyingObjectProperty = @"Whatever";

    EXPECT_EQ_MSG([[observer changesForKeypath:@"nonNotifyingObjectProperty"] count],
                  0,
                  "No changes for nonNotifyingObjectProperty should have fired.");

    EXPECT_NO_THROW([observed removeObserver:observer forKeyPath:@"nonNotifyingObjectProperty"]);
    EXPECT_NO_THROW([pool release]);
}

TEST(KVO, DisabledInitialNotification) { // Initial notification for non-notifying keypaths.
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    TestKVOObject* observed = [[[TestKVOObject alloc] init] autorelease];
    TestKVOObserver* observer = [[[TestKVOObserver alloc] init] autorelease];

    [observed addObserver:observer forKeyPath:@"nonNotifyingObjectProperty" options:NSKeyValueObservingOptionInitial context:NULL];
    observed.nonNotifyingObjectProperty = @"Whatever";

    EXPECT_EQ_MSG([[observer changesForKeypath:@"nonNotifyingObjectProperty"] count],
                  1,
                  "An INITIAL notification for nonNotifyingObjectProperty should have fired.");

    EXPECT_EQ(@(NSKeyValueChangeSetting),
              [[[[observer changesForKeypath:@"nonNotifyingObjectProperty"] anyObject] info] objectForKey:NSKeyValueChangeKindKey]);

    EXPECT_NO_THROW([observed removeObserver:observer forKeyPath:@"nonNotifyingObjectProperty"]);
    EXPECT_NO_THROW([pool release]);
}

TEST(KVO, SetValueForKeyIvarNotification) { // Notification of ivar change through setValue:forKey:
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    TestKVOObject* observed = [[[TestKVOObject alloc] init] autorelease];
    TestKVOObserver* observer = [[[TestKVOObserver alloc] init] autorelease];

    [observed addObserver:observer forKeyPath:@"ivarWithoutSetter" options:NSKeyValueObservingOptionNew context:NULL];
    [observed setValue:@(1024) forKey:@"ivarWithoutSetter"];

    EXPECT_EQ_MSG([[observer changesForKeypath:@"ivarWithoutSetter"] count],
                  1,
                  "One change on ivarWithoutSetter should have fired (using setValue:forKey:).");

    EXPECT_OBJCEQ_MSG([[[[observer changesForKeypath:@"ivarWithoutSetter"] anyObject] info] objectForKey:NSKeyValueChangeNewKey],
                      @(1024),
                      "The new value stored in the change notification should a boxed 1024.");

    EXPECT_NO_THROW([observed removeObserver:observer forKeyPath:@"ivarWithoutSetter"]);
    EXPECT_NO_THROW([pool release]);
}

TEST(KVO, SetValueForKeyPropertyNotification) { // Notification through setValue:forKey: to make sure that we do
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    // not get two notifications for the same change.
    TestKVOObject* observed = [[[TestKVOObject alloc] init] autorelease];
    TestKVOObserver* observer = [[[TestKVOObserver alloc] init] autorelease];

    [observed addObserver:observer forKeyPath:@"basicObjectProperty" options:NSKeyValueObservingOptionNew context:NULL];
    [observed setValue:@(1024) forKey:@"basicObjectProperty"];

    EXPECT_EQ_MSG([[observer changesForKeypath:@"basicObjectProperty"] count],
                  1,
                  "ONLY one change on basicObjectProperty should have fired (using setValue:forKey: should not fire twice).");

    EXPECT_OBJCEQ_MSG([[[[observer changesForKeypath:@"basicObjectProperty"] anyObject] info] objectForKey:NSKeyValueChangeNewKey],
                      @(1024),
                      "The new value stored in the change notification should a boxed 1024.");

    EXPECT_NO_THROW([observed removeObserver:observer forKeyPath:@"basicObjectProperty"]);
    EXPECT_NO_THROW([pool release]);
}

TEST(KVO, DictionaryNotification) { // Basic notification on a dictionary, which does not have properties or ivars.
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];

    NSMutableDictionary* observed = [NSMutableDictionary dictionary];
    TestKVOObserver* observer = [[[TestKVOObserver alloc] init] autorelease];

    [observed setObject:[[[TestKVOObject alloc] init] autorelease] forKey:@"subKey"];

    [observed addObserver:observer forKeyPath:@"arbitraryValue" options:NSKeyValueObservingOptionNew context:NULL];
    [observed addObserver:observer forKeyPath:@"subKey.basicObjectProperty" options:NSKeyValueObservingOptionNew context:NULL];

    [observed setObject:@"Whatever" forKey:@"arbitraryValue"];
    [observed setValue:@"Whatever2" forKeyPath:@"arbitraryValue"];
    [observed setValue:@"Whatever2" forKeyPath:@"subKey.basicObjectProperty"];

    EXPECT_EQ_MSG([[observer changesForKeypath:@"arbitraryValue"] count],
                  2,
                  "On a NSMutableDictionary, a change notification for arbitraryValue.");
    EXPECT_EQ_MSG([[observer changesForKeypath:@"subKey.basicObjectProperty"] count],
                  1,
                  "On a NSMutableDictionary, a change notification for subKey.basicObjectProperty.");

    EXPECT_NO_THROW([observed removeObserver:observer forKeyPath:@"arbitraryValue"]);
    EXPECT_NO_THROW([observed removeObserver:observer forKeyPath:@"subKey.basicObjectProperty"]);
    EXPECT_NO_THROW([pool release]);
}

TEST(KVO, BasicDeregistration) { // Deregistration test
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    TestKVOObject* observed = [[[TestKVOObject alloc] init] autorelease];
    TestKVOObserver* observer = [[[TestKVOObserver alloc] init] autorelease];

    [observed addObserver:observer forKeyPath:@"basicObjectProperty" options:NSKeyValueObservingOptionNew context:NULL];
    EXPECT_NO_THROW([observed removeObserver:observer forKeyPath:@"basicObjectProperty" context:NULL]);
    observed.basicObjectProperty = @"Hello";

    EXPECT_EQ_MSG([[observer changesForKeypath:@"basicObjectProperty"] count], 0, "No changes on basicObjectProperty should have fired.");

    TestKVOObject* subObject = [[[TestKVOObject alloc] init] autorelease];
    observed.cascadableKey = subObject;

    [observed addObserver:observer forKeyPath:@"cascadableKey.basicObjectProperty" options:NSKeyValueObservingOptionNew context:NULL];
    EXPECT_NO_THROW([observed removeObserver:observer forKeyPath:@"cascadableKey.basicObjectProperty" context:NULL]);

    subObject.basicObjectProperty = @"Hello";

    EXPECT_EQ_MSG([[observer changesForKeypath:@"cascadableKey.basicObjectProperty"] count],
                  0,
                  "No changes on cascadableKey.basicObjectProperty should have fired.");
    EXPECT_NO_THROW([pool release]);
}

TEST(KVO, DerivedKeyOnSubpath1) {
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];

    TestKVOObject* observed = [[TestKVOObject alloc] init];
    TestKVOObserver* observer = [[TestKVOObserver alloc] init];

    [observed addObserver:observer
               forKeyPath:@"cascadableKey.derivedObjectProperty.length"
                  options:NSKeyValueObservingOptionNew
                  context:NULL];

    TestKVOObject* subObject = [[TestKVOObject alloc] init];
    subObject.basicObjectProperty = @"Hello";
    observed.cascadableKey = subObject;

    EXPECT_EQ_MSG([[observer changesForKeypath:@"cascadableKey.derivedObjectProperty.length"] count],
                  1,
                  "One change on cascade.derived.length should have fired.");
    EXPECT_OBJCEQ_MSG([[[[observer changesForKeypath:@"cascadableKey.derivedObjectProperty.length"] anyObject] info]
                          objectForKey:NSKeyValueChangeNewKey],
                      @(11),
                      "The new value stored in the change notification should a boxed 11.");

    EXPECT_NO_THROW([observed removeObserver:observer forKeyPath:@"cascadableKey.derivedObjectProperty.length" context:NULL]);

    [observer clear];

    subObject.basicObjectProperty = @"Whatever";

    EXPECT_EQ_MSG([[observer changesForKeypath:@"cascadableKey.derivedObjectProperty.length"] count],
                  0,
                  "No additional changes on cascade.derived.length should have fired.");

    EXPECT_NO_THROW([subObject release]);
    EXPECT_NO_THROW([observer release]);
    EXPECT_NO_THROW([observed release]);

    EXPECT_NO_THROW([pool release]);
}

TEST(KVO, Subpath1) { // Test normally-nested observation and value replacement
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    TestKVOObject* observed = [[TestKVOObject alloc] init];
    TestKVOObserver* observer = [[TestKVOObserver alloc] init];
    [observed addObserver:observer forKeyPath:@"cascadableKey.cascadableKey" options:0 context:nil];

    TestKVOObject* child = [[TestKVOObject alloc] init];

    observed.cascadableKey = child;
    observed.cascadableKey = nil;

    EXPECT_EQ(2, [observer numberOfObservedChanges]);

    EXPECT_NO_THROW([observed removeObserver:observer forKeyPath:@"cascadableKey.cascadableKey"]);

    EXPECT_NO_THROW([child release]);
    EXPECT_NO_THROW([observer release]);
    EXPECT_NO_THROW([observed release]);
    EXPECT_NO_THROW([pool release]);
}

TEST(KVO, SubpathSubpath) { // Test deeply-nested observation
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    TestKVOObject* observed = [[TestKVOObject alloc] init];
    TestKVOObserver* observer = [[TestKVOObserver alloc] init];
    [observed addObserver:observer forKeyPath:@"cascadableKey.cascadableKey.cascadableKey" options:0 context:nil];

    TestKVOObject* child = [[[TestKVOObject alloc] init] autorelease];
    TestKVOObject* childChild = [[[TestKVOObject alloc] init] autorelease];

    observed.cascadableKey = child;
    observed.cascadableKey.cascadableKey = childChild;
    observed.cascadableKey.cascadableKey = nil;
    observed.cascadableKey = nil;

    EXPECT_EQ(4, [observer numberOfObservedChanges]);

    EXPECT_NO_THROW([observed removeObserver:observer forKeyPath:@"cascadableKey.cascadableKey.cascadableKey"]);

    EXPECT_NO_THROW([observer release]);
    EXPECT_NO_THROW([observed release]);
    EXPECT_NO_THROW([pool release]);
}

TEST(KVO, SubpathWithHeadReplacement) { // Test key value replacement and re-registration (1)
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    TestKVOObject* observed = [[TestKVOObject alloc] init];
    TestKVOObserver* observer = [[TestKVOObserver alloc] init];

    TestKVOObject* child = [[[TestKVOObject alloc] init] autorelease];
    observed.cascadableKey = child;

    [observed addObserver:observer forKeyPath:@"cascadableKey.cascadableKey" options:0 context:nil];

    observed.cascadableKey = nil;

    EXPECT_EQ(1, [observer numberOfObservedChanges]);

    EXPECT_NO_THROW([observed removeObserver:observer forKeyPath:@"cascadableKey.cascadableKey"]);

    EXPECT_NO_THROW([observer release]);
    EXPECT_NO_THROW([observed release]);
    EXPECT_NO_THROW([pool release]);
}

TEST(KVO, SubpathWithTailAndHeadReplacement) { // Test key value replacement and re-registration (2)
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    TestKVOObject* observed = [[TestKVOObject alloc] init];
    TestKVOObserver* observer = [[TestKVOObserver alloc] init];

    TestKVOObject* child = [[[TestKVOObject alloc] init] autorelease];
    observed.cascadableKey = child;

    TestKVOObject* childChild = [[[TestKVOObject alloc] init] autorelease];
    child.cascadableKey = childChild;

    [observed addObserver:observer forKeyPath:@"cascadableKey.cascadableKey.cascadableKey" options:0 context:nil];

    observed.cascadableKey.cascadableKey = nil;
    observed.cascadableKey = nil;

    EXPECT_EQ(2, [observer numberOfObservedChanges]);

    EXPECT_NO_THROW([observed removeObserver:observer forKeyPath:@"cascadableKey.cascadableKey.cascadableKey"]);

    EXPECT_NO_THROW([observer release]);
    EXPECT_NO_THROW([observed release]);
    EXPECT_NO_THROW([pool release]);
}

TEST(KVO, SubpathWithMultipleReplacement) { // Test key value replacement and re-registration (3)
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    TestKVOObject* observed = [[TestKVOObject alloc] init];
    TestKVOObserver* observer = [[TestKVOObserver alloc] init];
    TestKVOObject* child1 = [[[TestKVOObject alloc] init] autorelease];
    TestKVOObject* child2 = [[[TestKVOObject alloc] init] autorelease];

    [observed addObserver:observer forKeyPath:@"cascadableKey.cascadableKey" options:0 context:nil];

    observed.cascadableKey = child1;

    observed.cascadableKey = child2;

    observed.cascadableKey = nil;

    EXPECT_EQ(3, [observer numberOfObservedChanges]);

    EXPECT_NO_THROW([observed removeObserver:observer forKeyPath:@"cascadableKey.cascadableKey"]);

    EXPECT_NO_THROW([observer release]);
    EXPECT_NO_THROW([observed release]);
    EXPECT_NO_THROW([pool release]);
}

TEST(KVO, SubpathWithMultipleReplacement2) { // Test a more complex nested observation system
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    TestKVOObject* observed = [[TestKVOObject alloc] init];
    TestKVOObserver* observer = [[TestKVOObserver alloc] init];
    TestKVOObject* child1 = [[[TestKVOObject alloc] init] autorelease];
    TestKVOObject* child2 = [[[TestKVOObject alloc] init] autorelease];
    TestKVOObject* child3 = [[[TestKVOObject alloc] init] autorelease];
    TestKVOObject* child4 = [[[TestKVOObject alloc] init] autorelease];

    [observed addObserver:observer forKeyPath:@"cascadableKey.cascadableKey" options:0 context:nil];

    observed.cascadableKey = child1;

    observed.cascadableKey = nil;

    observed.cascadableKey = child2;

    observed.cascadableKey = nil;

    observed.cascadableKey = child3;
    child3.cascadableKey = child4;

    observed.cascadableKey = nil;

    EXPECT_EQ(7, [observer numberOfObservedChanges]);

    EXPECT_NO_THROW([observed removeObserver:observer forKeyPath:@"cascadableKey.cascadableKey"]);

    EXPECT_NO_THROW([observer release]);
    EXPECT_NO_THROW([observed release]);
    EXPECT_NO_THROW([pool release]);
}

TEST(KVO, SubpathsWithInitialNotification) { // Test initial observation on nested keys
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    TestKVOObject* observed = [[[TestKVOObject alloc] init] autorelease];
    TestKVOObserver* observer = [[[TestKVOObserver alloc] init] autorelease];
    TestKVOObject* child1 = [[[TestKVOObject alloc] init] autorelease];
    observed.cascadableKey = child1;

    [observed addObserver:observer
               forKeyPath:@"cascadableKey.basicObjectProperty"
                  options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                  context:nil];
    [observed addObserver:observer
               forKeyPath:@"cascadableKey.basicPodProperty"
                  options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                  context:nil];
    [observed addObserver:observer
               forKeyPath:@"cascadableKey.derivedObjectProperty"
                  options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                  context:nil];

    EXPECT_EQ(3, [observer numberOfObservedChanges]);
    EXPECT_OBJCEQ([NSNull null],
                  [[[[observer changesForKeypath:@"cascadableKey.basicObjectProperty"] anyObject] info]
                      objectForKey:NSKeyValueChangeNewKey]);
    EXPECT_OBJCEQ(@(0),
                  [[[[observer changesForKeypath:@"cascadableKey.basicPodProperty"] anyObject] info] objectForKey:NSKeyValueChangeNewKey]);
    EXPECT_OBJCEQ([NSNull null],
                  [[[[observer changesForKeypath:@"cascadableKey.derivedObjectProperty"] anyObject] info]
                      objectForKey:NSKeyValueChangeNewKey]);

    EXPECT_NO_THROW([observed removeObserver:observer forKeyPath:@"cascadableKey.basicObjectProperty"]);
    EXPECT_NO_THROW([observed removeObserver:observer forKeyPath:@"cascadableKey.basicPodProperty"]);
    EXPECT_NO_THROW([observed removeObserver:observer forKeyPath:@"cascadableKey.derivedObjectProperty"]);
    EXPECT_NO_THROW([pool release]);
}

TEST(KVO, CyclicDependency) { // Make sure that dependency loops don't cause crashes.
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    TestKVOObject* observed = [[TestKVOObject alloc] init];
    TestKVOObserver* observer = [[TestKVOObserver alloc] init];
    EXPECT_NO_THROW([observed addObserver:observer forKeyPath:@"recursiveDependent1" options:1 context:nil]);
    EXPECT_NO_THROW([observed addObserver:observer forKeyPath:@"recursiveDependent2" options:1 context:nil]);
    observed.recursiveDependent1 = @"x";
    observed.recursiveDependent2 = @"y";
    EXPECT_EQ(4, [observer numberOfObservedChanges]);
    EXPECT_NO_THROW([observed removeObserver:observer forKeyPath:@"recursiveDependent1"]);
    EXPECT_NO_THROW([observed removeObserver:observer forKeyPath:@"recursiveDependent2"]);

    EXPECT_NO_THROW([observer release]);
    EXPECT_NO_THROW([observed release]);
    EXPECT_NO_THROW([pool release]);
}

TEST(KVO, ObserveAllProperties) {
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    TestKVOObject* observed = [[TestKVOObject alloc] init];
    TestKVOObserver* observer = [[[TestKVOObserver alloc] init] autorelease];

    [observed addObserver:observer forKeyPath:@"basicObjectProperty" options:NSKeyValueObservingOptionNew context:NULL];
    [observed addObserver:observer forKeyPath:@"basicPodProperty" options:NSKeyValueObservingOptionNew context:NULL];
    [observed addObserver:observer forKeyPath:@"structProperty" options:NSKeyValueObservingOptionNew context:NULL];
    [observed addObserver:observer forKeyPath:@"derivedObjectProperty" options:NSKeyValueObservingOptionNew context:NULL];
    [observed addObserver:observer forKeyPath:@"cascadableKey" options:NSKeyValueObservingOptionNew context:NULL];
    [observed addObserver:observer forKeyPath:@"cascadableKey.basicObjectProperty" options:NSKeyValueObservingOptionNew context:NULL];

    observed.basicObjectProperty = @"WHAT"; // 2 here
    observed.basicPodProperty = 10; // 1
    observed.structProperty = TestKVOStruct{ 1, 2, 3 }; // 1

    TestKVOObject* subObject = [[[TestKVOObject alloc] init] autorelease];
    subObject.basicObjectProperty = @"Hello";
    observed.cascadableKey = subObject; // 2 here

    EXPECT_EQ_MSG([observer numberOfObservedChanges], 6, "There should have been 6 observed changes on the observer.");

    EXPECT_NO_THROW([observed removeObserver:observer forKeyPath:@"basicObjectProperty"]);
    EXPECT_NO_THROW([observed removeObserver:observer forKeyPath:@"basicPodProperty"]);
    EXPECT_NO_THROW([observed removeObserver:observer forKeyPath:@"structProperty"]);
    EXPECT_NO_THROW([observed removeObserver:observer forKeyPath:@"derivedObjectProperty"]);
    EXPECT_NO_THROW([observed removeObserver:observer forKeyPath:@"cascadableKey"]);
    EXPECT_NO_THROW([observed removeObserver:observer forKeyPath:@"cascadableKey.basicObjectProperty"]);
    EXPECT_NO_THROW([pool release]);
}

TEST(KVO, RemoveWithoutContext) { // Test removal without specifying context.
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    TestKVOObject* observed = [[TestKVOObject alloc] init];
    TestKVOObserver* observer = [[TestKVOObserver alloc] init];

    [observed addObserver:observer
               forKeyPath:@"basicObjectProperty"
                  options:NSKeyValueObservingOptionNew
                  context:reinterpret_cast<void*>(1)];
    [observed addObserver:observer
               forKeyPath:@"basicObjectProperty"
                  options:NSKeyValueObservingOptionNew
                  context:reinterpret_cast<void*>(2)];

    EXPECT_NO_THROW([observed removeObserver:observer forKeyPath:@"basicObjectProperty"]);

    observed.basicObjectProperty = @"";

    EXPECT_EQ_MSG([observer numberOfObservedChanges],
                  1,
                  "There should be only one change notification despite registering two with contexts.");

    EXPECT_NO_THROW([observed removeObserver:observer forKeyPath:@"basicObjectProperty"]);
    EXPECT_NO_THROW([observed release]);
    EXPECT_NO_THROW([observer release]);
    EXPECT_NO_THROW([pool release]);
}

TEST(KVO, RemoveWithDuplicateContext) { // Test adding duplicate contexts
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    TestKVOObject* observed = [[[TestKVOObject alloc] init] autorelease];
    TestKVOObserver* observer = [[[TestKVOObserver alloc] init] autorelease];

    [observed addObserver:observer
               forKeyPath:@"basicObjectProperty"
                  options:NSKeyValueObservingOptionNew
                  context:reinterpret_cast<void*>(1)];
    [observed addObserver:observer
               forKeyPath:@"basicObjectProperty"
                  options:NSKeyValueObservingOptionNew
                  context:reinterpret_cast<void*>(1)];

    observed.basicObjectProperty = @"";

    EXPECT_EQ_MSG([observer numberOfObservedChanges], 2, "There should be two observed changes, despite the identical registration.");

    EXPECT_NO_THROW([observed removeObserver:observer forKeyPath:@"basicObjectProperty" context:reinterpret_cast<void*>(1)]);

    observed.basicObjectProperty = @"";

    EXPECT_EQ_MSG([observer numberOfObservedChanges],
                  3,
                  "There should be one additional observed change; the removal should have only effected one.");

    EXPECT_NO_THROW([observed removeObserver:observer forKeyPath:@"basicObjectProperty" context:reinterpret_cast<void*>(1)]);
    EXPECT_NO_THROW([pool release]);
}

TEST(KVO, RemoveOneOfTwoObservers) { // Test adding duplicate contexts
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    TestKVOObject* observed = [[[TestKVOObject alloc] init] autorelease];
    TestKVOObserver* observer = [[[TestKVOObserver alloc] init] autorelease];
    TestKVOObserver* observer2 = [[[TestKVOObserver alloc] init] autorelease];

    [observed addObserver:observer forKeyPath:@"basicObjectProperty" options:NSKeyValueObservingOptionNew context:nullptr];
    [observed addObserver:observer2 forKeyPath:@"basicObjectProperty" options:NSKeyValueObservingOptionNew context:nullptr];

    observed.basicObjectProperty = @"";

    EXPECT_EQ_MSG([observer numberOfObservedChanges], 1, "There should be one observed change per observer.");
    EXPECT_EQ_MSG([observer2 numberOfObservedChanges], 1, "There should be one observed change per observer.");

    EXPECT_NO_THROW([observed removeObserver:observer2 forKeyPath:@"basicObjectProperty"]);

    observed.basicObjectProperty = @"";

    EXPECT_EQ_MSG([observer numberOfObservedChanges],
                  2,
                  "There should be one additional observed change; the removal should have only removed the second observer.");

    EXPECT_EQ([observer2 numberOfObservedChanges], 1);

    EXPECT_NO_THROW([observed removeObserver:observer forKeyPath:@"basicObjectProperty"]);
    EXPECT_NO_THROW([pool release]);
}

TEST(KVO, RemoveUnregistered) { // Test removing an urnegistered observer
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    TestKVOObject* observed = [[[TestKVOObject alloc] init] autorelease];
    TestKVOObserver* observer = [[[TestKVOObserver alloc] init] autorelease];

    EXPECT_ANY_THROW_MSG([observed removeObserver:observer forKeyPath:@"basicObjectProperty" context:reinterpret_cast<void*>(1)],
                         "Removing an unregistered observer should throw an exception.");
    EXPECT_NO_THROW([pool release]);
}

TEST(KVO, SelfObservationDealloc) { // Test deallocation of an object that is its own observer
    TestKVOSelfObserver* observed = [[TestKVOSelfObserver alloc] init];
    EXPECT_NO_THROW([observed release]);
}

TEST(KVO, DeepSubpathWithCompleteTree) {
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    TestKVOObject2* floatGuy = [[[TestKVOObject2 alloc] init] autorelease];
    floatGuy.someFloat = 1.234f;
    TestKVOObject* observed = [[[TestKVOObject alloc] init] autorelease];
    TestKVOObject* child = [[[TestKVOObject alloc] init] autorelease];
    TestKVOObserver* observer = [[[TestKVOObserver alloc] init] autorelease];
    child.dictionaryProperty = [NSMutableDictionary dictionaryWithObjectsAndKeys:floatGuy, @"floatGuy", nil];
    observed.cascadableKey = child;
    [observed addObserver:observer forKeyPath:@"cascadableKey.dictionaryProperty.floatGuy.someFloat" options:0 context:nil];
    observed.cascadableKey = child;
    EXPECT_EQ([observer numberOfObservedChanges], 1);

    EXPECT_NO_THROW([observed removeObserver:observer forKeyPath:@"cascadableKey.dictionaryProperty.floatGuy.someFloat"]);
    EXPECT_NO_THROW([pool release]);
}

TEST(KVO, DeepSubpathWithIncompleteTree) {
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    // The same test as above, but testing nil value reconstitution to ensure that the keypath is wired up properly.
    TestKVOObject* observed = [[[TestKVOObject alloc] init] autorelease];
    TestKVOObserver* observer = [[[TestKVOObserver alloc] init] autorelease];
    [observed addObserver:observer forKeyPath:@"cascadableKey.dictionaryProperty.floatGuy.someFloat" options:0 context:nil];

    TestKVOObject2* floatGuy = [[[TestKVOObject2 alloc] init] autorelease];
    floatGuy.someFloat = 1.234f;
    TestKVOObject* child = [[[TestKVOObject alloc] init] autorelease];
    child.dictionaryProperty = [NSMutableDictionary dictionaryWithObjectsAndKeys:floatGuy, @"floatGuy", nil];

    observed.cascadableKey = child;
    observed.cascadableKey = child;

    EXPECT_EQ([observer numberOfObservedChanges], 2);

    EXPECT_NO_THROW([observed removeObserver:observer forKeyPath:@"cascadableKey.dictionaryProperty.floatGuy.someFloat"]);
    EXPECT_NO_THROW([pool release]);
}

TEST(KVO, SubpathOnDerivedKey) {
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    TestKVOObject* observed = [[[TestKVOObject alloc] init] autorelease];
    TestKVOObject* child = [[[TestKVOObject alloc] init] autorelease];
    TestKVOObject* child2 = [[[TestKVOObject alloc] init] autorelease];
    TestKVOObserver* observer = [[[TestKVOObserver alloc] init] autorelease];

    observed.cascadableKey = child;
    child.dictionaryProperty = [NSMutableDictionary dictionaryWithDictionary:@{ @"Key1" : @"Value1" }];

    [observed addObserver:observer forKeyPath:@"derivedCascadableKey.dictionaryProperty.Key1" options:0 context:nil];

    observed.cascadableKey = child2;
    child2.dictionaryProperty = [NSMutableDictionary dictionaryWithDictionary:@{ @"Key1" : @"Value2" }];

    EXPECT_EQ(2, [observer numberOfObservedChanges]);

    EXPECT_NO_THROW([observed removeObserver:observer forKeyPath:@"derivedCascadableKey.dictionaryProperty.Key1"]);
    EXPECT_NO_THROW([pool release]);
}

TEST(KVO, SubpathWithDerivedKeyBasedOnSubpath) {
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    TestKVOObject* observed = [[[TestKVOObject alloc] init] autorelease];
    TestKVOObserver* observer = [[[TestKVOObserver alloc] init] autorelease];

    // key dependent on sub keypath is dependent upon dictionaryProperty.subDictionary
    NSMutableDictionary* mutableDictionary = [[@{ @"subDictionary" : @{ @"floatGuy" : @(1.234) } } mutableCopy] autorelease];
    observed.dictionaryProperty = mutableDictionary;

    [observed addObserver:observer forKeyPath:@"keyDependentOnSubKeypath.floatGuy" options:0 context:nil];

    mutableDictionary[@"subDictionary"] = @{ @"floatGuy" : @(3.456) }; // 1 notification

    NSMutableDictionary* mutableDictionary2 = [[@{ @"subDictionary" : @{ @"floatGuy" : @(5.678) } } mutableCopy] autorelease];

    observed.dictionaryProperty = mutableDictionary2; // 2nd notification

    mutableDictionary2[@"subDictionary"] = @{ @"floatGuy" : @(7.890) }; // 3rd notification

    EXPECT_EQ(3, [observer numberOfObservedChanges]);

    EXPECT_NO_THROW([observed removeObserver:observer forKeyPath:@"keyDependentOnSubKeypath.floatGuy"]);
    EXPECT_NO_THROW([pool release]);
}

TEST(KVO, MultipleObservers) {
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    TestKVOObject* observed = [[[TestKVOObject alloc] init] autorelease];
    TestKVOObserver* observer = [[[TestKVOObserver alloc] init] autorelease];
    TestKVOObserver* observer2 = [[[TestKVOObserver alloc] init] autorelease];

    [observed addObserver:observer forKeyPath:@"basicObjectProperty" options:NSKeyValueObservingOptionNew context:NULL];
    observed.basicObjectProperty = @"Hello";

    EXPECT_EQ_MSG([[observer changesForKeypath:@"basicObjectProperty"] count], 1, "One change on basicObjectProperty should have fired.");
    EXPECT_EQ_MSG([[observer changesForKeypath:@"basicPodProperty"] count], 0, "Zero changes on basicPodProperty should have fired.");
    EXPECT_EQ_MSG([[observer2 changesForKeypath:@"basicObjectProperty"] count],
                  0,
                  "Zero changes on basicObjectProperty should have fired (obs 2).");
    EXPECT_EQ_MSG([[observer2 changesForKeypath:@"basicPodProperty"] count],
                  0,
                  "Zero changes on basicPodProperty should have fired (obs 2).");

    [observed addObserver:observer2 forKeyPath:@"basicObjectProperty" options:NSKeyValueObservingOptionNew context:NULL];
    observed.basicObjectProperty = @"Goodbye";

    EXPECT_EQ([[observer changesForKeypath:@"basicObjectProperty"] count], 2);
    EXPECT_EQ([[observer changesForKeypath:@"basicPodProperty"] count], 0);
    EXPECT_EQ([[observer2 changesForKeypath:@"basicObjectProperty"] count], 1);
    EXPECT_EQ([[observer2 changesForKeypath:@"basicPodProperty"] count], 0);

    EXPECT_OBJCEQ_MSG([[[observer2 changesForKeypath:@"basicObjectProperty"] anyObject] object],
                      observed,
                      "The notification object should match the observed object.");
    EXPECT_OBJCEQ_MSG(nil,
                      [[[[observer2 changesForKeypath:@"basicObjectProperty"] anyObject] info] objectForKey:NSKeyValueChangeOldKey],
                      "There should be no old value included in the change notification.");
    EXPECT_OBJCEQ([[[[observer2 changesForKeypath:@"basicObjectProperty"] anyObject] info] objectForKey:NSKeyValueChangeNewKey],
                  @"Goodbye");
    EXPECT_NO_THROW([observed removeObserver:observer forKeyPath:@"basicObjectProperty"]);
    EXPECT_NO_THROW([observed removeObserver:observer2 forKeyPath:@"basicObjectProperty"]);

    EXPECT_NO_THROW([pool release]);
}

TEST(KVO, DerivedKeyDependentOnDerivedKey) {
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    TestKVOObject* observed = [[[TestKVOObject alloc] init] autorelease];
    TestKVOObject* child = [[[TestKVOObject alloc] init] autorelease];
    TestKVOObject* child2 = [[[TestKVOObject alloc] init] autorelease];
    TestKVOObserver* observer = [[[TestKVOObserver alloc] init] autorelease];

    observed.basicObjectProperty = @"Hello";

    [observed addObserver:observer forKeyPath:@"keyDerivedTwoTimes" options:NSKeyValueObservingOptionNew context:nil];

    observed.basicObjectProperty = @"KVO";

    EXPECT_EQ(1, [observer numberOfObservedChanges]);
    EXPECT_OBJCEQ([[[[observer changesForKeypath:@"keyDerivedTwoTimes"] anyObject] info] objectForKey:NSKeyValueChangeNewKey],
                  @"---!!!KVO!!!---");

    [observer clear];

    observed.basicObjectProperty = @"$$$";

    EXPECT_EQ(1, [observer numberOfObservedChanges]);
    EXPECT_OBJCEQ([[[[observer changesForKeypath:@"keyDerivedTwoTimes"] anyObject] info] objectForKey:NSKeyValueChangeNewKey],
                  @"---!!!$$$!!!---");

    EXPECT_NO_THROW([observed removeObserver:observer forKeyPath:@"keyDerivedTwoTimes"]);
    EXPECT_NO_THROW([pool release]);
}

TEST(KVO, DerivedKeyDependentOnTwoKeys) {
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    TestKVOObject* observed = [[[TestKVOObject alloc] init] autorelease];
    TestKVOObserver* observer = [[[TestKVOObserver alloc] init] autorelease];

    [observed addObserver:observer forKeyPath:@"dependsOnTwoKeys" options:NSKeyValueObservingOptionNew context:nil];

    observed.boolTrigger1 = @"firstObject";

    EXPECT_EQ(1, [observer numberOfObservedChanges]);
    EXPECT_OBJCEQ(@NO, [[[[observer changesForKeypath:@"dependsOnTwoKeys"] anyObject] info] objectForKey:NSKeyValueChangeNewKey]);

    [observer clear];
    observed.boolTrigger2 = @"secondObject";

    EXPECT_EQ(1, [observer numberOfObservedChanges]);
    EXPECT_OBJCEQ(@YES, [[[[observer changesForKeypath:@"dependsOnTwoKeys"] anyObject] info] objectForKey:NSKeyValueChangeNewKey]);

    EXPECT_NO_THROW([observed removeObserver:observer forKeyPath:@"dependsOnTwoKeys"]);
    EXPECT_NO_THROW([pool release]);
}

TEST(KVO, DerivedKeyDependentOnTwoSubKeys) {
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    TestKVOObject* observed = [[[TestKVOObject alloc] init] autorelease];
    TestKVOObject* child = [[[TestKVOObject alloc] init] autorelease];
    TestKVOObserver* observer = [[[TestKVOObserver alloc] init] autorelease];

    [observed addObserver:observer forKeyPath:@"dependsOnTwoSubKeys" options:NSKeyValueObservingOptionNew context:nil];

    observed.cascadableKey = child;
    EXPECT_EQ(1, [observer numberOfObservedChanges]);
    EXPECT_OBJCEQ(@NO, [[[[observer changesForKeypath:@"dependsOnTwoSubKeys"] anyObject] info] objectForKey:NSKeyValueChangeNewKey]);

    [observer clear];
    child.boolTrigger1 = @"firstObject";

    EXPECT_EQ(1, [observer numberOfObservedChanges]);
    EXPECT_OBJCEQ(@NO, [[[[observer changesForKeypath:@"dependsOnTwoSubKeys"] anyObject] info] objectForKey:NSKeyValueChangeNewKey]);

    [observer clear];
    child.boolTrigger2 = @"secondObject";

    EXPECT_EQ(1, [observer numberOfObservedChanges]);
    EXPECT_OBJCEQ(@YES, [[[[observer changesForKeypath:@"dependsOnTwoSubKeys"] anyObject] info] objectForKey:NSKeyValueChangeNewKey]);

    EXPECT_NO_THROW([observed removeObserver:observer forKeyPath:@"dependsOnTwoSubKeys"]);
    EXPECT_NO_THROW([pool release]);
}

TEST(KVO, ObserverInfoShouldNotStompOthers) {
    TestKVOObject* observed = [[[TestKVOObject alloc] init] autorelease];
    TestKVOObject* oldObj = [[[TestKVOObject alloc] init] autorelease];
    observed.cascadableKey = oldObj;
    observed.cascadableKey.basicObjectProperty = @"Original";
    TestKVOObserver* observer = [[[TestKVOObserver alloc] init] autorelease];

    [observed addObserver:observer
               forKeyPath:@"cascadableKey"
                  options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew)
                  context:nil];
    [observed addObserver:observer
               forKeyPath:@"cascadableKey.basicObjectProperty"
                  options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew)
                  context:nil];

    TestKVOObject* newObj = [[[TestKVOObject alloc] init] autorelease];
    newObj.basicObjectProperty = @"NewObj";
    observed.cascadableKey = newObj;

    NSDictionary* baseInfo = [[[observer changesForKeypath:@"cascadableKey"] anyObject] info];
    EXPECT_NE(nil, baseInfo);
    EXPECT_EQ(oldObj, baseInfo[NSKeyValueChangeOldKey]);
    EXPECT_EQ(newObj, baseInfo[NSKeyValueChangeNewKey]);

    NSDictionary* subInfo = [[[observer changesForKeypath:@"cascadableKey.basicObjectProperty"] anyObject] info];
    EXPECT_NE(nil, subInfo);
    EXPECT_OBJCEQ(@"Original", subInfo[NSKeyValueChangeOldKey]);
    EXPECT_OBJCEQ(@"NewObj", subInfo[NSKeyValueChangeNewKey]);

    EXPECT_NO_THROW([observed removeObserver:observer forKeyPath:@"cascadableKey"]);
    EXPECT_NO_THROW([observed removeObserver:observer forKeyPath:@"cascadableKey.basicObjectProperty"]);
}

TEST(Foundation, NSSearchPathForDirectoriesInDomains) {
    NSArray* documentPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSArray* cachesPaths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSAllDomainsMask, YES);
    NSArray* libraryPaths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSAllDomainsMask, YES);
    ASSERT_NE(0, [documentPaths count]);
    ASSERT_NE(0, [cachesPaths count]);
    ASSERT_NE(0, [libraryPaths count]);

    NSArray* paths = @[ documentPaths[0], cachesPaths[0], libraryPaths[0] ];

    for (NSString* path in paths) {
        NSString* filePath = [NSString stringWithFormat:@"%@/%@", path, @"NSSearchPathTestFile.txt"];
        NSError* error = nil;
        NSString* testOutput = @"Testing 1 2 3";
        EXPECT_NO_THROW([@"Testing 1 2 3" writeToFile:filePath atomically:NO encoding:NSUTF8StringEncoding error:&error]);
        ASSERT_OBJCEQ(nil, error);
    }
}

TEST(Foundation, NSSet_PerformSelector) {
    NSMutableArray* array = [NSMutableArray arrayWithCapacity:1];
    [array addObject:@1];
    NSSet* set = [NSSet setWithObject:array];

    EXPECT_EQ(1, [array count]);
    [set makeObjectsPerformSelector:@selector(removeAllObjects)];
    EXPECT_EQ(0, [array count]);
}

@protocol Protocol1
@end

@protocol Protocol2 <NSObject>
- (void)emptyMethod;
- (NSObject*)otherMethod:(id)arg1;
+ (id)classMethod;
@end

TEST(Foundation, NSStringFromProtocol) {
    EXPECT_OBJCEQ(@"Protocol1", NSStringFromProtocol(@protocol(Protocol1)));
    EXPECT_OBJCEQ(@"Protocol2", NSStringFromProtocol(@protocol(Protocol2)));
    EXPECT_OBJCEQ(@"nil", NSStringFromProtocol(nil));
}

TEST(Foundation, NSProtocolFromString) {
    EXPECT_EQ(@protocol(Protocol1), NSProtocolFromString(@"Protocol1"));
    EXPECT_EQ(@protocol(Protocol2), NSProtocolFromString(@"Protocol2"));
    EXPECT_EQ(nil, NSProtocolFromString(nil));
    EXPECT_EQ(nil,
              NSProtocolFromString(@"NonexistentProtocolOrAtLeastOneThatShouldNotEverEVERExistBecauseOfTheObnoxiouslyLongNameAsWellAsI"
                                   @"rrelevantToJustAboutAnythingAnyoneShouldEverBeDoing"));
}
