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
#import <Starboard/SmartTypes.h>
#import <Foundation/Foundation.h>

// Avoid "property access result unused" warnings by _consume-ing the value of a property accessor.
template <typename... T>
static inline void _consume(T&&...) {
}

TEST(NSNotification, CanCreate) {
    EXPECT_OBJCNE(nil, [NSNotification notificationWithName:@"name" object:nil userInfo:nil]);
}

@interface BadNSNotificationSubclass : NSNotification
@end
@implementation BadNSNotificationSubclass
- (id)init {
    // NSNotification subclasses are barred from calling [super init].
    return self;
}
@end

TEST(NSNotification, InvalidSubclassThrows) {
    EXPECT_ANY_THROW([BadNSNotificationSubclass notificationWithName:@"name" object:nil userInfo:nil]);

    BadNSNotificationSubclass* bad = [[BadNSNotificationSubclass alloc] init];
    EXPECT_ANY_THROW(_consume(bad.name));
    EXPECT_ANY_THROW(_consume(bad.userInfo));
    EXPECT_ANY_THROW(_consume(bad.object));

    [bad release];
}

TEST(NSNotification, CanEncodeAndDecode) {
    NSNotification* notification = [NSNotification notificationWithName:@"Name1" object:@"Object1" userInfo:@{ @"Key1" : @"Value1" }];
    NSData* data = nil;
    ASSERT_NO_THROW(data = [NSKeyedArchiver archivedDataWithRootObject:notification]);

    NSNotification* newNotification = nil;
    ASSERT_NO_THROW(newNotification = [NSKeyedUnarchiver unarchiveObjectWithData:data]);

    EXPECT_NE(notification,
              newNotification); // pointer comparison: notifications cannot be compared with isEqual:, and this should be a new instance.

    EXPECT_OBJCEQ(notification.name, newNotification.name);
    EXPECT_OBJCEQ(notification.object, newNotification.object);
    EXPECT_OBJCEQ(notification.userInfo, newNotification.userInfo);
}

@interface TestObjectA : NSObject
@end

@implementation TestObjectA
- (void)dealloc {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"MOOSENOTIFICATION" object:self];
    [super dealloc];
}

@end

TEST(NSNotificationCenter, PostNotificationFromDealloc) {
    @autoreleasepool {
        TestObjectA* obj = [[TestObjectA new] autorelease];
    }
}

TEST(NSNotificationCenter, BlockRegistrationDeregistration) {
    static NSString* s_TestNotificationName = @(GetTestFullName().c_str());
    NSNotificationCenter* notificationCenter = [[NSNotificationCenter new] autorelease];
    __block int counter = 0;

    id token = [notificationCenter addObserverForName:s_TestNotificationName
                                               object:nil
                                                queue:nil
                                           usingBlock:^(NSNotification* note) {
                                               ++counter;
                                               ASSERT_OBJCEQ(s_TestNotificationName, note.name);
                                           }];

    EXPECT_OBJCNE(nil, token);
    ASSERT_EQ(0, counter); // Adding a notification should not fire it.

    [notificationCenter postNotificationName:s_TestNotificationName object:nil];
    ASSERT_EQ(1, counter);

    [notificationCenter postNotificationName:@"UnrelatedNotification" object:nil];
    ASSERT_EQ(1, counter); // An unrelated notification should not fire this token.

    [notificationCenter removeObserver:token]; // Unregister this observer from every named notification.
    [notificationCenter postNotificationName:s_TestNotificationName object:nil];
    ASSERT_EQ(1, counter); // An unregistered observer should never fire.
}

// Like the above test, but the block unregisters the observer immediately.
TEST(NSNotificationCenter, BlockFireOnce) {
    static NSString* s_TestNotificationName = @(GetTestFullName().c_str());
    NSNotificationCenter* notificationCenter = [[NSNotificationCenter new] autorelease];
    __block int counter = 0;

    __block id token = [notificationCenter addObserverForName:s_TestNotificationName
                                                       object:nil
                                                        queue:nil
                                                   usingBlock:^(NSNotification* note) {
                                                       ++counter;
                                                       ASSERT_OBJCEQ(s_TestNotificationName, note.name);
                                                       [notificationCenter removeObserver:token];
                                                   }];

    EXPECT_OBJCNE(nil, token);
    ASSERT_EQ(0, counter); // Adding a notification should not fire it.

    [notificationCenter postNotificationName:s_TestNotificationName object:nil];
    [notificationCenter postNotificationName:s_TestNotificationName object:nil];
    [notificationCenter postNotificationName:s_TestNotificationName object:nil];
    ASSERT_EQ(1, counter);

    EXPECT_NO_THROW([notificationCenter removeObserver:token]); // Double-unregistering this observer should not fail.

    [notificationCenter postNotificationName:s_TestNotificationName object:nil];
    ASSERT_EQ(1, counter); // An unregistered observer should never fire.
}

TEST(NSNotificationCenter, BlockWithQueue) {
    static NSString* s_TestNotificationName = @(GetTestFullName().c_str());
    NSNotificationCenter* notificationCenter = [[NSNotificationCenter new] autorelease];
    __block int counter = 0;

    NSOperationQueue* queue = [[NSOperationQueue new] autorelease];
    queue.maxConcurrentOperationCount = 1;

    __block id token = [notificationCenter addObserverForName:s_TestNotificationName
                                                       object:nil
                                                        queue:queue
                                                   usingBlock:^(NSNotification* note) {
                                                       ++counter;
                                                       ASSERT_OBJCEQ(s_TestNotificationName, note.name);
                                                       [notificationCenter removeObserver:token];
                                                   }];

    [queue addOperationWithBlock:^{
        ASSERT_EQ(0, counter);
    }];

    [notificationCenter postNotificationName:s_TestNotificationName object:nil];

    [queue waitUntilAllOperationsAreFinished];

    ASSERT_EQ_MSG(1, counter, "the block should not have fired; its queue is suspended.");
}

// NSNotificationTestObserver resopnds to all selectors and keeps track of them.
@interface NSNotificationTestObserver : NSObject {
    NSMutableDictionary<NSString*, NSNumber*>* _selectorHits;
}
@end

@implementation NSNotificationTestObserver
- (BOOL)respondsToSelector:(SEL)selector {
    return YES;
}

- (NSMethodSignature*)methodSignatureForSelector:(SEL)selector {
    return [NSMethodSignature signatureWithObjCTypes:"v@:@"];
}

- (void)forwardInvocation:(NSInvocation*)invocation {
    NSString* key = NSStringFromSelector(invocation.selector);
    @synchronized(self) {
        if (!_selectorHits) {
            _selectorHits = [NSMutableDictionary new];
        }
        _selectorHits[key] = @([_selectorHits[key] unsignedIntegerValue] + 1);
    }
}

- (void)dealloc {
    [_selectorHits release];
    [super dealloc];
}

- (NSUInteger)hitsForSelector:(SEL)selector {
    NSString* key = NSStringFromSelector(selector);
    return [_selectorHits[key] unsignedIntegerValue];
}

- (NSUInteger)uniqueHits {
    return _selectorHits.count;
}

- (NSUInteger)totalHits {
    __block NSUInteger count = 0;
    [_selectorHits enumerateKeysAndObjectsUsingBlock:^(NSString* key, NSNumber* value, BOOL* stop) {
        count += [value unsignedIntegerValue];
    }];
    return count;
}
@end

TEST(NSNotificationCenter, SingleNonspecificDelivery) {
    static NSString* s_TestNotificationName = @(GetTestFullName().c_str());
    NSNotificationCenter* notificationCenter = [[NSNotificationCenter new] autorelease];
    NSNotificationTestObserver* observer = [[NSNotificationTestObserver new] autorelease];

    [notificationCenter addObserver:observer selector:@selector(uniqueSelector1:) name:s_TestNotificationName object:nil];

    [notificationCenter postNotificationName:s_TestNotificationName object:nil];

    EXPECT_EQ(1, [observer hitsForSelector:@selector(uniqueSelector1:)]);
    EXPECT_EQ(1, [observer uniqueHits]);
    EXPECT_EQ(1, [observer totalHits]);
}

TEST(NSNotificationCenter, SingleSpecificDelivery) {
    static NSString* s_TestNotificationName = @(GetTestFullName().c_str());
    NSNotificationCenter* notificationCenter = [[NSNotificationCenter new] autorelease];
    NSNotificationTestObserver* observer = [[NSNotificationTestObserver new] autorelease];

    NSObject* object1 = [[NSObject new] autorelease];
    NSObject* object2 = [[NSObject new] autorelease];

    [notificationCenter addObserver:observer selector:@selector(listeningForObject1:) name:s_TestNotificationName object:object1];
    [notificationCenter addObserver:observer selector:@selector(listeningForObject2:) name:s_TestNotificationName object:object2];
    [notificationCenter addObserver:observer selector:@selector(listeningForNoObject:) name:s_TestNotificationName object:nil];

    [notificationCenter postNotificationName:s_TestNotificationName object:object1];
    [notificationCenter postNotificationName:s_TestNotificationName object:object2];
    [notificationCenter postNotificationName:s_TestNotificationName object:nil];

    EXPECT_EQ(1, [observer hitsForSelector:@selector(listeningForObject1:)]);
    EXPECT_EQ(1, [observer hitsForSelector:@selector(listeningForObject2:)]);
    EXPECT_EQ(3, [observer hitsForSelector:@selector(listeningForNoObject:)]);
    EXPECT_EQ(3, [observer uniqueHits]);
    EXPECT_EQ(5, [observer totalHits]);

    [notificationCenter removeObserver:observer name:s_TestNotificationName object:object1]; // Remove only the object1 observer.

    [notificationCenter postNotificationName:s_TestNotificationName object:object1];
    [notificationCenter postNotificationName:s_TestNotificationName object:object2];
    [notificationCenter postNotificationName:s_TestNotificationName object:nil];

    EXPECT_EQ(1, [observer hitsForSelector:@selector(listeningForObject1:)]);
    EXPECT_EQ(2, [observer hitsForSelector:@selector(listeningForObject2:)]);
    EXPECT_EQ(6, [observer hitsForSelector:@selector(listeningForNoObject:)]);
    EXPECT_EQ(3, [observer uniqueHits]);
    EXPECT_EQ(9, [observer totalHits]);

    [notificationCenter removeObserver:observer
                                  name:s_TestNotificationName
                                object:nil]; // Remove both remaining listeners (object=nil: no object criterion)

    [notificationCenter postNotificationName:s_TestNotificationName object:object1];
    [notificationCenter postNotificationName:s_TestNotificationName object:object2];
    [notificationCenter postNotificationName:s_TestNotificationName object:nil];

    EXPECT_EQ(1, [observer hitsForSelector:@selector(listeningForObject1:)]); // Same values as above.
    EXPECT_EQ(2, [observer hitsForSelector:@selector(listeningForObject2:)]);
    EXPECT_EQ(6, [observer hitsForSelector:@selector(listeningForNoObject:)]);
    EXPECT_EQ(3, [observer uniqueHits]);
    EXPECT_EQ(9, [observer totalHits]);
}

TEST(NSNotificationCenter, MultipleNonspecificDelivery) {
    static NSString* s_TestNotificationName1 = @(GetTestFullName().c_str());
    static NSString* s_TestNotificationName2 = [@(GetTestFullName().c_str()) stringByAppendingString:@"Two"];
    NSNotificationCenter* notificationCenter = [[NSNotificationCenter new] autorelease];
    NSNotificationTestObserver* observer = [[NSNotificationTestObserver new] autorelease];

    [notificationCenter addObserver:observer selector:@selector(listeningForNotification1:) name:s_TestNotificationName1 object:nil];
    [notificationCenter addObserver:observer selector:@selector(listeningForNotification2:) name:s_TestNotificationName2 object:nil];

    [notificationCenter postNotificationName:s_TestNotificationName1 object:nil];
    [notificationCenter postNotificationName:s_TestNotificationName2 object:nil];

    EXPECT_EQ(1, [observer hitsForSelector:@selector(listeningForNotification1:)]);
    EXPECT_EQ(1, [observer hitsForSelector:@selector(listeningForNotification2:)]);
    EXPECT_EQ(2, [observer uniqueHits]);
    EXPECT_EQ(2, [observer totalHits]);

    [notificationCenter removeObserver:observer name:s_TestNotificationName2 object:nil]; // Remove the notification2 listener.

    [notificationCenter postNotificationName:s_TestNotificationName1 object:nil];
    [notificationCenter postNotificationName:s_TestNotificationName2 object:nil];

    EXPECT_EQ(2, [observer hitsForSelector:@selector(listeningForNotification1:)]);
    EXPECT_EQ(1, [observer hitsForSelector:@selector(listeningForNotification2:)]);
    EXPECT_EQ(2, [observer uniqueHits]);
    EXPECT_EQ(3, [observer totalHits]);

    [notificationCenter removeObserver:observer name:nil object:nil]; // Remove the other remaining listener (name=nil: no name criterion)

    [notificationCenter postNotificationName:s_TestNotificationName1 object:nil];
    [notificationCenter postNotificationName:s_TestNotificationName2 object:nil];

    EXPECT_EQ(2, [observer hitsForSelector:@selector(listeningForNotification1:)]); // Same values as above.
    EXPECT_EQ(1, [observer hitsForSelector:@selector(listeningForNotification2:)]);
    EXPECT_EQ(2, [observer uniqueHits]);
    EXPECT_EQ(3, [observer totalHits]);
}

TEST(NSNotificationCenter, MultipleSpecificDelivery) {
    static NSString* s_TestNotificationName1 = @(GetTestFullName().c_str());
    static NSString* s_TestNotificationName2 = [@(GetTestFullName().c_str()) stringByAppendingString:@"Two"];
    NSNotificationCenter* notificationCenter = [[NSNotificationCenter new] autorelease];
    NSNotificationTestObserver* observer = [[NSNotificationTestObserver new] autorelease];

    NSObject* object1 = [[NSObject new] autorelease];
    NSObject* object2 = [[NSObject new] autorelease];

    [notificationCenter addObserver:observer
                           selector:@selector(listeningForNotification1Object1:)
                               name:s_TestNotificationName1
                             object:object1];
    [notificationCenter addObserver:observer
                           selector:@selector(listeningForNotification2Object1:)
                               name:s_TestNotificationName2
                             object:object1];
    [notificationCenter addObserver:observer
                           selector:@selector(listeningForNotification1Object2:)
                               name:s_TestNotificationName1
                             object:object2];
    [notificationCenter addObserver:observer
                           selector:@selector(listeningForNotification2Object2:)
                               name:s_TestNotificationName2
                             object:object2];

    [notificationCenter postNotificationName:s_TestNotificationName1 object:object1];
    EXPECT_EQ(1, [observer hitsForSelector:@selector(listeningForNotification1Object1:)]);
    EXPECT_EQ(1, [observer uniqueHits]);
    EXPECT_EQ(1, [observer totalHits]);

    [notificationCenter postNotificationName:s_TestNotificationName1 object:object2];
    EXPECT_EQ(1, [observer hitsForSelector:@selector(listeningForNotification1Object2:)]);
    EXPECT_EQ(2, [observer uniqueHits]);
    EXPECT_EQ(2, [observer totalHits]);

    [notificationCenter postNotificationName:s_TestNotificationName2 object:nil];
    EXPECT_EQ(2, [observer totalHits]); // No more hits: no listeners for nil object.

    [notificationCenter removeObserver:observer name:s_TestNotificationName1 object:nil]; // Remove the notification1 listener entirely.

    [notificationCenter postNotificationName:s_TestNotificationName1 object:object1];
    EXPECT_EQ(2, [observer totalHits]); // No more hits: all notification1 listeners removed.

    [notificationCenter removeObserver:observer name:nil object:object2]; // Remove the all object2 listeners.

    [notificationCenter postNotificationName:s_TestNotificationName2 object:object2];
    EXPECT_EQ(2, [observer totalHits]); // No more hits: all object2 listeners removed.

    [notificationCenter postNotificationName:s_TestNotificationName2 object:object1];
    EXPECT_EQ(3, [observer totalHits]); // One more hit: object1+notification2 still registered.
}

TEST(NSNotificationCenter, ContentiousDelivery) {
    static NSString* s_TestNotificationName = @(GetTestFullName().c_str());
    NSNotificationCenter* notificationCenter = [[NSNotificationCenter new] autorelease];
    NSNotificationTestObserver* observer = [[NSNotificationTestObserver new] autorelease];

    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    dispatch_group_t group = dispatch_group_create();

    dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER); // wait to start
        for (int i = 0; i < 100; ++i) {
            [notificationCenter addObserver:observer selector:@selector(deliveredNotification:) name:s_TestNotificationName object:nil];
        }
    });

    dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER); // wait to start
        for (int i = 0; i < 100; ++i) {
            [notificationCenter postNotificationName:s_TestNotificationName object:nil];
        }
    });

    dispatch_semaphore_signal(sem);
    dispatch_semaphore_signal(sem); // Trigger starts

    dispatch_group_wait(group, DISPATCH_TIME_FOREVER); // Wait for completion.

    // Between 0 and 10000 notifications should have fired; this stress test simply proves that we can manipulate the three states
    // simultaneously.
    EXPECT_LT(0, observer.totalHits);
    ASSERT_GE(100 * 100, observer.totalHits);
}

TEST(NSNotificationCenter, ContentiousDeliveryRemoval) {
    static NSString* s_TestNotificationName = @(GetTestFullName().c_str());
    NSNotificationCenter* notificationCenter = [[NSNotificationCenter new] autorelease];
    NSNotificationTestObserver* observer = [[NSNotificationTestObserver new] autorelease];

    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    dispatch_group_t group = dispatch_group_create();

    dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER); // wait to start
        for (int i = 0; i < 100; ++i) {
            [notificationCenter addObserver:observer selector:@selector(deliveredNotification:) name:s_TestNotificationName object:nil];
        }
    });

    dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER); // wait to start
        for (int i = 0; i < 100; ++i) {
            [notificationCenter removeObserver:observer];
        }
    });

    dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER); // wait to start
        for (int i = 0; i < 100; ++i) {
            [notificationCenter postNotificationName:s_TestNotificationName object:nil];
        }
    });

    dispatch_semaphore_signal(sem);
    dispatch_semaphore_signal(sem);
    dispatch_semaphore_signal(sem); // Trigger starts

    dispatch_group_wait(group, DISPATCH_TIME_FOREVER); // Wait for completion.

    // Between 0 and 10000 notifications should have fired; this stress test simply proves that we can manipulate the three states
    // simultaneously.
    EXPECT_LE(0, observer.totalHits);
    ASSERT_GE(100 * 100, observer.totalHits);
}

TEST(NSNotificationCenter, UserInfo) {
    static NSString* s_TestNotificationName = @(GetTestFullName().c_str());
    NSNotificationCenter* notificationCenter = [[NSNotificationCenter new] autorelease];
    __block int counter = 0;

    __block id token = [notificationCenter addObserverForName:s_TestNotificationName
                                                       object:nil
                                                        queue:nil
                                                   usingBlock:^(NSNotification* note) {
                                                       ++counter;
                                                       ASSERT_OBJCEQ(s_TestNotificationName, note.name);
                                                       ASSERT_OBJCEQ(@{ @"Hello" : @"World" }, note.userInfo);
                                                       [notificationCenter removeObserver:token];
                                                   }];

    [notificationCenter postNotificationName:s_TestNotificationName object:nil userInfo:@{ @"Hello" : @"World" }];
    ASSERT_EQ(1, counter);
}

TEST(NSNotificationCenter, ManuallyCreatedNotification) {
    static NSString* s_TestNotificationName = @(GetTestFullName().c_str());
    NSNotificationCenter* notificationCenter = [[NSNotificationCenter new] autorelease];
    __block int counter = 0;

    __block NSNotification* notification = [NSNotification notificationWithName:s_TestNotificationName object:nil userInfo:@{}];

    __block id token = [notificationCenter addObserverForName:s_TestNotificationName
                                                       object:nil
                                                        queue:nil
                                                   usingBlock:^(NSNotification* note) {
                                                       ++counter;
                                                       ASSERT_OBJCEQ(notification, note);
                                                       [notificationCenter removeObserver:token];
                                                   }];

    [notificationCenter postNotification:notification];
    ASSERT_EQ(1, counter);
}

TEST(NSNotificationCenter, InvalidStates) {
    static NSString* s_TestNotificationName = @(GetTestFullName().c_str());
    NSNotificationCenter* notificationCenter = [[NSNotificationCenter new] autorelease];

    EXPECT_NO_THROW([notificationCenter postNotificationName:nil object:nil]);
    // It looks like adding an observer for a nil notification _does_ return an observation token.
    EXPECT_OBJCNE(nil, [notificationCenter addObserverForName:nil object:nil queue:nil usingBlock:^(id){}]);
    EXPECT_ANY_THROW([notificationCenter addObserverForName:nil object:nil queue:nil usingBlock:nil]);
    EXPECT_ANY_THROW([notificationCenter addObserverForName:s_TestNotificationName object:nil queue:nil usingBlock:nil]);
    EXPECT_ANY_THROW([notificationCenter postNotification:nil]);
}
