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
#import <Helpers/TestHelpers.h>

#import <thread>
#import <mutex>
#import <condition_variable>
#import <chrono>

static void (^_completionBlockPopulatingConditionAndFlag(void (^completionBlock)(), NSCondition** condition, BOOL* flag))() {
    NSCondition* cond = [[NSCondition new] autorelease];
    *condition = cond;
    return Block_copy(^{
        if (completionBlock) {
            completionBlock();
        }
        [cond lock];
        *flag = YES;
        [cond broadcast];
        [cond unlock];
    });
}

// Convenience class that executes a block on a separate thread
@interface BlockThread : NSThread
- (instancetype)initWithBlock:(void (^)())block;
@property (copy) void (^block)();
@property (readonly) THBooleanCondition* finishCondition;
@end

@implementation BlockThread
- (instancetype)initWithBlock:(void (^)())block {
    if (self = [super init]) {
        self.block = block;
        self->_finishCondition = [THBooleanCondition new];
    }
    return self;
}

- (void)dealloc {
    [_finishCondition release];
    [_block release];
    [super dealloc];
}

- (void)main {
    self.block();
    [_finishCondition broadcast];
}

@end

// Test helper that waits on a block to finish for a specified period of time
// Primarily intended to add a timeout to wait functions that could otherwise go on indefinitely
// Returns whether the block completed successfully
static inline BOOL _waitOnBlockToFinish(void (^block)(), NSTimeInterval secondsToWait) {
    BlockThread* blockThread = [[[BlockThread alloc] initWithBlock:block] autorelease];
    [blockThread start];
    return [blockThread.finishCondition waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:secondsToWait]];
}

TEST(NSOperation, NSOperationDealloc) {
    NSOperationQueue* queue = [[NSOperationQueue alloc] init];
    ASSERT_NO_THROW([queue release]);

    NSOperation* operation = [[NSOperation alloc] init];
    ASSERT_NO_THROW([operation release]);
}

TEST(NSOperation, NSOperation) {
    NSOperationQueue* queue = [[NSOperationQueue new] autorelease];

    NSOperation* operation = [[NSOperation new] autorelease];

    NSCondition* completionCondition = nil;
    BOOL completionBlockCalled = NO;
    [operation setCompletionBlock:_completionBlockPopulatingConditionAndFlag(
                                      ^{
                                          [operation waitUntilFinished]; // Should not deadlock, but we cannot test this
                                          ASSERT_TRUE([operation isFinished]);
                                      },
                                      &completionCondition,
                                      &completionBlockCalled)];

    [completionCondition lock];

    [queue addOperation:operation];

    [operation waitUntilFinished];

    [completionCondition waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:2]];
    [completionCondition unlock];

    ASSERT_TRUE(completionBlockCalled);
    ASSERT_TRUE([operation isFinished]);
    ASSERT_FALSE([operation isExecuting]);
}

TEST(NSOperation, CancelOutOfQueue) {
    NSOperation* operation = [[NSOperation new] autorelease];
    [operation cancel];
    EXPECT_TRUE([operation isCancelled]);
    EXPECT_FALSE([operation isExecuting]);
    EXPECT_FALSE([operation isFinished]);
}

TEST(NSOperation, NSOperationCancellation) {
    NSOperationQueue* queue = [[NSOperationQueue new] autorelease];

    NSOperation* cancelledOperation = [[NSOperation new] autorelease];

    NSCondition* completionCondition = nil;
    BOOL completionBlockCalled = NO;
    [cancelledOperation setCompletionBlock:_completionBlockPopulatingConditionAndFlag(
                                               ^{
                                                   [cancelledOperation waitUntilFinished]; // Should not deadlock, but we cannot test this
                                                   ASSERT_TRUE([cancelledOperation isFinished]);
                                               },
                                               &completionCondition,
                                               &completionBlockCalled)];

    [completionCondition lock];

    [cancelledOperation cancel];

    [queue addOperation:cancelledOperation];

    [cancelledOperation waitUntilFinished];

    [completionCondition waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:2]];
    [completionCondition unlock];

    ASSERT_TRUE(completionBlockCalled);
    ASSERT_FALSE([cancelledOperation isExecuting]);
    ASSERT_TRUE([cancelledOperation isCancelled]);
}

TEST(NSOperation, NSOperationSuspend) {
    NSOperationQueue* queue = [[NSOperationQueue alloc] init];

    NSOperation* suspendOperation = [[NSOperation alloc] init];

    __block NSCondition* suspendCondition = [NSCondition new];
    __block bool shouldBeTrue = false;

    [suspendOperation setCompletionBlock:^{
        [suspendOperation waitUntilFinished]; // Should not deadlock, but we cannot test this
        ASSERT_TRUE([suspendOperation isFinished]);

        [suspendCondition lock];
        ASSERT_TRUE(shouldBeTrue);
        [suspendCondition unlock];
    }];

    [queue setSuspended:YES];
    [queue addOperation:suspendOperation];

    std::this_thread::sleep_for(std::chrono::milliseconds(300));
    [suspendCondition lock];
    shouldBeTrue = true;
    [suspendCondition broadcast];
    [suspendCondition unlock];

    ASSERT_TRUE([queue isSuspended]);
    ASSERT_FALSE([suspendOperation isExecuting]);

    [queue setSuspended:NO];
    ASSERT_FALSE([queue isSuspended]);

    [suspendOperation waitUntilFinished];
}

@interface TestObserver : NSObject
@property BOOL didObserveCompletionBlock;
@property BOOL didObserveDependencies;
@property BOOL didObserveReady;
@property BOOL didObserveCancelled;
@property BOOL didObserveExecuting;
@property BOOL didObserveFinished;
@end

@implementation TestObserver
- (void)observeValueForKeyPath:(NSString*)keyPath ofObject:(id)object change:(NSDictionary*)change context:(void*)context {
    if ([keyPath isEqualToString:@"completionBlock"]) {
        _didObserveCompletionBlock = YES;
    } else if ([keyPath isEqualToString:@"dependencies"]) {
        _didObserveDependencies = YES;
    } else if ([keyPath isEqualToString:@"isReady"]) {
        _didObserveReady = YES;
    } else if ([keyPath isEqualToString:@"isCancelled"]) {
        _didObserveCancelled = YES;
    } else if ([keyPath isEqualToString:@"isExecuting"]) {
        _didObserveExecuting = YES;
    } else if ([keyPath isEqualToString:@"isFinished"]) {
        _didObserveFinished = YES;
    }
}

@end

// On the reference platform, we cannot observe isFinished immediately.
// There appears to be a marked laziness in signalling the finished status.
// waitUntilFinished triggers before didChangeValueForKey:@"isFinished" --
// sometimes long before it -- and we can jump the gun on the observation.
// WinObjC updates these flags immediately and only releases a waitUntilFinished when
// didChangeValueForKey: has already triggered.
OSX_DISABLED_TEST(NSOperation, NSOperationKVO) {
    NSOperationQueue* queue = [[NSOperationQueue new] autorelease];
    NSOperation* operation = [[NSOperation new] autorelease];
    TestObserver* observer = [[TestObserver new] autorelease];

    [operation addObserver:observer forKeyPath:@"completionBlock" options:0 context:NULL];
    [operation addObserver:observer forKeyPath:@"isCancelled" options:0 context:NULL];
    [operation addObserver:observer forKeyPath:@"isExecuting" options:0 context:NULL];
    [operation addObserver:observer forKeyPath:@"isFinished" options:0 context:NULL];

    [operation setCompletionBlock:^{
        // nothing to do here.
    }];

    ASSERT_TRUE([observer didObserveCompletionBlock]);
    [observer setDidObserveCompletionBlock:NO];

    ASSERT_FALSE([observer didObserveCompletionBlock]);
    ASSERT_FALSE([observer didObserveCancelled]);
    ASSERT_FALSE([observer didObserveExecuting]);
    ASSERT_FALSE([observer didObserveFinished]);

    [queue addOperation:operation];
    [operation waitUntilFinished];

    ASSERT_FALSE([observer didObserveCompletionBlock]);
    ASSERT_FALSE([observer didObserveCancelled]);
    ASSERT_TRUE([observer didObserveExecuting]);
    ASSERT_TRUE([observer didObserveFinished]);

    [operation removeObserver:observer forKeyPath:@"completionBlock" context:NULL];
    [operation removeObserver:observer forKeyPath:@"isCancelled" context:NULL];
    [operation removeObserver:observer forKeyPath:@"isExecuting" context:NULL];
    [operation removeObserver:observer forKeyPath:@"isFinished" context:NULL];
}

// Test asynchronous subclass for NSOperation
@interface MyConcurrentOperation : NSOperation
@property (assign, getter=isExecuting) BOOL executing;
@property (assign, getter=isFinished, readonly) BOOL finished;
@end

@implementation MyConcurrentOperation

@synthesize executing = _executing;
@synthesize finished = _finished;

- (void)setExecuting:(BOOL)executing {
    [self willChangeValueForKey:@"isExecuting"];
    [self willChangeValueForKey:@"isFinished"];

    _executing = executing;
    _finished = !executing;

    [self didChangeValueForKey:@"isExecuting"];
    [self didChangeValueForKey:@"isFinished"];
}

- (BOOL)isExecuting {
    return _executing;
}

- (BOOL)isFinished {
    return _finished;
}

- (void)start {
    if (self.cancelled) {
        return;
    }

    self.executing = YES;
    [self doSomething];
}

- (void)doSomething {
    // Do some async task.
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{

        // Do another async task
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
            // Do some async task.
            self.executing = NO;
        });
    });
}

@end

TEST(NSOperation, NSOperationConcurrentSubclass) {
    NSOperationQueue* queue = [[NSOperationQueue new] autorelease];

    NSOperation* operation = [MyConcurrentOperation new];

    NSCondition* completionCondition = nil;
    BOOL completionBlockCalled = NO;
    [operation setCompletionBlock:_completionBlockPopulatingConditionAndFlag(
                                      ^{
                                          [operation waitUntilFinished]; // Should not deadlock, but we cannot test this
                                          ASSERT_TRUE([operation isFinished]);
                                      },
                                      &completionCondition,
                                      &completionBlockCalled)];

    [completionCondition lock];

    [queue addOperation:operation];

    [operation waitUntilFinished];

    [completionCondition waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:2]];
    [completionCondition unlock];

    ASSERT_TRUE(completionBlockCalled);
    ASSERT_TRUE([operation isFinished]);
    ASSERT_FALSE([operation isExecuting]);
    ASSERT_NO_THROW([operation release]);
}

// Test synchronous subclass for NSOperation
@interface MyNonconcurrentOperation : NSOperation
@property BOOL didWork;
@end

@implementation MyNonconcurrentOperation

- (void)main {
    if (self.cancelled) {
        return;
    }

    _didWork = YES;
}

@end

TEST(NSOperation, NSOperationNonconcurrentSubclass) {
    NSOperationQueue* queue = [[NSOperationQueue new] autorelease];

    MyNonconcurrentOperation* operation = [MyNonconcurrentOperation new];

    NSCondition* completionCondition = nil;
    BOOL completionBlockCalled = NO;
    [operation setCompletionBlock:_completionBlockPopulatingConditionAndFlag(
                                      ^{
                                          [operation waitUntilFinished]; // Should not deadlock, but we cannot test this
                                          ASSERT_TRUE([operation isFinished]);
                                      },
                                      &completionCondition,
                                      &completionBlockCalled)];

    [completionCondition lock];

    [queue addOperation:operation];
    [operation waitUntilFinished];

    [completionCondition waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:2]];
    [completionCondition unlock];

    ASSERT_TRUE(completionBlockCalled);
    ASSERT_TRUE([operation isFinished]);
    ASSERT_FALSE([operation isExecuting]);
    ASSERT_TRUE([operation didWork]);
    ASSERT_NO_THROW([operation release]);

    MyNonconcurrentOperation* operation2 = [[MyNonconcurrentOperation new] autorelease];
    [operation2 cancel];

    [queue addOperation:operation2];
    [operation2 waitUntilFinished];
    ASSERT_TRUE([operation2 isCancelled]);
    ASSERT_TRUE([operation2 isFinished]);
    ASSERT_FALSE([operation2 isExecuting]);
    ASSERT_FALSE([operation2 didWork]);
}

TEST(NSOperation, NSOperationMultipleWaiters) {
    NSOperationQueue* queue = [[NSOperationQueue new] autorelease];

    NSOperation* operation = [[NSOperation new] autorelease];

    [operation setCompletionBlock:^{
        [operation waitUntilFinished]; // Should not deadlock, but we cannot test this
        ASSERT_TRUE([operation isFinished]);
    }];

    [operation performSelectorInBackground:@selector(waitUntilFinished) withObject:nil];
    [operation performSelectorInBackground:@selector(waitUntilFinished) withObject:nil];
    // Any lingering threads will make the test hang, unfortunately we have no way around this.

    [queue addOperation:operation];

    [operation waitUntilFinished];

    ASSERT_TRUE([operation isFinished]);
}

TEST(NSOperation, NSDependencyRemove) {
    // tests that nothing happens when a dependency is removed that was never added.
    NSOperation* operation = [[NSOperation new] autorelease];
    NSOperation* dependency = [[NSOperation new] autorelease];

    ASSERT_NO_THROW([operation removeDependency:dependency]);
}

TEST(NSOperation, NSOperationWithDependenciesDoesRun) {
    NSOperationQueue* queue = [[NSOperationQueue new] autorelease];
    TestObserver* observer = [[TestObserver new] autorelease];

    NSCondition* dep1Condition = nil;
    BOOL dep1Completed = NO;
    NSOperation* dependency1 = [[NSOperation new] autorelease];
    [dependency1 setCompletionBlock:_completionBlockPopulatingConditionAndFlag(nil, &dep1Condition, &dep1Completed)];

    NSCondition* dep2Condition = nil;
    BOOL dep2Completed = NO;
    NSOperation* dependency2 = [[NSOperation new] autorelease];
    [dependency2 setCompletionBlock:_completionBlockPopulatingConditionAndFlag(nil, &dep2Condition, &dep2Completed)];

    NSOperation* operation = [[NSOperation new] autorelease];
    NSCondition* completionCondition = nil;
    BOOL completionBlockCalled = NO;
    [operation setCompletionBlock:_completionBlockPopulatingConditionAndFlag(nil, &completionCondition, &completionBlockCalled)];

    [operation addDependency:dependency1];
    [operation addDependency:dependency2];

    EXPECT_FALSE([operation isReady]);

    // Stage the operation before its dependencies.
    [queue addOperation:operation];

    [dep1Condition lock];
    [queue addOperation:dependency1];
    [dep1Condition waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:2.0]];
    [dep1Condition unlock];
    EXPECT_TRUE(dep1Completed);
    EXPECT_FALSE(dep2Completed);
    EXPECT_FALSE(completionBlockCalled);

    [completionCondition lock]; // dep2 will trigger operation to complete.
    [dep2Condition lock];
    [queue addOperation:dependency2];
    [dep2Condition waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:2.0]];
    [dep2Condition unlock];
    EXPECT_TRUE(dep2Completed);

    [completionCondition waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:2.0]];
    [completionCondition unlock];
    EXPECT_TRUE(completionBlockCalled);
}

TEST(NSOperation, NSOperationWithDependenciesInDifferentPrioritiesDoesRun) {
    NSOperationQueue* queue = [[NSOperationQueue new] autorelease];
    TestObserver* observer = [[TestObserver new] autorelease];

    NSCondition* dep1Condition = nil;
    BOOL dep1Completed = NO;
    NSOperation* dependency1 = [[NSOperation new] autorelease];
    dependency1.queuePriority = NSOperationQueuePriorityVeryLow;
    [dependency1 setCompletionBlock:_completionBlockPopulatingConditionAndFlag(nil, &dep1Condition, &dep1Completed)];

    NSOperation* operation = [[NSOperation new] autorelease];
    operation.queuePriority = NSOperationQueuePriorityVeryHigh;
    NSCondition* completionCondition = nil;
    BOOL completionBlockCalled = NO;
    [operation setCompletionBlock:_completionBlockPopulatingConditionAndFlag(nil, &completionCondition, &completionBlockCalled)];

    [operation addDependency:dependency1];

    EXPECT_FALSE([operation isReady]);

    // Stage the operation before its dependencies.
    [queue addOperation:operation];

    [completionCondition lock]; // dep1 will trigger operation to complete.
    [dep1Condition lock];
    [queue addOperation:dependency1];
    [dep1Condition waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:2.0]];
    [dep1Condition unlock];
    EXPECT_TRUE(dep1Completed);
    EXPECT_FALSE(completionBlockCalled);

    [completionCondition waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:2.0]];
    [completionCondition unlock];
    EXPECT_TRUE(completionBlockCalled);
}

// On the reference platform, we cannot observe isReady immediately.
// There appears to be a marked laziness in signalling the ready status via
// dependency completion.
// waitUntilFinished (for dependency2) triggers before didChangeValueForKey:@"isFinished" --
// sometimes long before it -- and we can jump the gun on the ready observation.
// WinObjC updates these flags immediately and only releases a waitUntilFinished when
// didChangeValueForKey: has already triggered.
OSX_DISABLED_TEST(NSOperation, NSOperationIsReady) {
    NSOperationQueue* queue = [[NSOperationQueue new] autorelease];
    TestObserver* observer = [[TestObserver new] autorelease];
    NSOperation* dependency1 = [[NSOperation new] autorelease];
    NSOperation* dependency2 = [[NSOperation new] autorelease];
    NSOperation* dependency3 = [[NSOperation new] autorelease];

    NSOperation* operation = [[NSOperation new] autorelease];
    ASSERT_TRUE([operation isReady]);
    [operation addObserver:observer forKeyPath:@"isReady" options:0 context:NULL];
    ASSERT_FALSE([observer didObserveReady]);

    [operation addDependency:dependency1];
    [operation addDependency:dependency2];

    ASSERT_TRUE([observer didObserveReady]);
    ASSERT_FALSE([operation isReady]);
    [observer setDidObserveReady:NO];

    [queue addOperation:dependency1];
    [dependency1 waitUntilFinished];
    ASSERT_FALSE([observer didObserveReady]);
    ASSERT_FALSE([operation isReady]);

    [queue addOperation:dependency2];
    [dependency2 waitUntilFinished];

    ASSERT_TRUE([observer didObserveReady]);
    ASSERT_TRUE([operation isReady]);
    [observer setDidObserveReady:NO];

    [operation addDependency:dependency3];
    ASSERT_TRUE([observer didObserveReady]);
    ASSERT_FALSE([operation isReady]);
    [observer setDidObserveReady:NO];

    [operation cancel];
    ASSERT_TRUE([observer didObserveReady]);
    ASSERT_TRUE([operation isReady]);
    [observer setDidObserveReady:NO];

    [operation removeObserver:observer forKeyPath:@"isReady" context:NULL];
}

TEST(NSOperation, RunConcurrentOperationManually) {
    NSOperation* operation = [MyConcurrentOperation new];

    NSCondition* completionCondition = nil;
    BOOL completionBlockCalled = NO;
    [operation setCompletionBlock:_completionBlockPopulatingConditionAndFlag(
                                      ^{
                                          [operation waitUntilFinished]; // Should not deadlock, but we cannot test this
                                          ASSERT_TRUE([operation isFinished]);
                                      },
                                      &completionCondition,
                                      &completionBlockCalled)];

    [completionCondition lock];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [operation start];
    });

    [operation waitUntilFinished];

    [completionCondition waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:2]];
    [completionCondition unlock];

    ASSERT_TRUE(completionBlockCalled);
    ASSERT_TRUE([operation isFinished]);
    ASSERT_FALSE([operation isExecuting]);
    ASSERT_NO_THROW([operation release]);
}

TEST(NSOperation, RunNonconcurrentOperationManually) {
    NSOperation* operation = [MyNonconcurrentOperation new];

    NSCondition* completionCondition = nil;
    BOOL completionBlockCalled = NO;
    [operation setCompletionBlock:_completionBlockPopulatingConditionAndFlag(
                                      ^{
                                          [operation waitUntilFinished]; // Should not deadlock, but we cannot test this
                                          ASSERT_TRUE([operation isFinished]);
                                      },
                                      &completionCondition,
                                      &completionBlockCalled)];

    [completionCondition lock];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [operation start];
    });

    [operation waitUntilFinished];

    [completionCondition waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:2]];
    [completionCondition unlock];

    ASSERT_TRUE(completionBlockCalled);
    ASSERT_TRUE([operation isFinished]);
    ASSERT_FALSE([operation isExecuting]);
    ASSERT_NO_THROW([operation release]);
}

TEST(NSOperation, NSBlockOperationInQueue) {
    NSOperationQueue* queue = [[NSOperationQueue new] autorelease];

    __block BOOL executedBlock = NO;
    NSOperation* operation = [NSBlockOperation blockOperationWithBlock:^{
        executedBlock = YES;
    }];

    NSCondition* completionCondition = nil;
    BOOL completionBlockCalled = NO;
    [operation setCompletionBlock:_completionBlockPopulatingConditionAndFlag(
                                      ^{
                                          [operation waitUntilFinished]; // Should not deadlock, but we cannot test this
                                          ASSERT_TRUE([operation isFinished]);
                                          ASSERT_TRUE(executedBlock);
                                      },
                                      &completionCondition,
                                      &completionBlockCalled)];

    [completionCondition lock];

    [queue addOperation:operation];

    [operation waitUntilFinished];

    [completionCondition waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:2]];
    [completionCondition unlock];

    ASSERT_TRUE(completionBlockCalled);
    ASSERT_TRUE([operation isFinished]);
    ASSERT_FALSE([operation isExecuting]);
}

TEST(NSOperation, DeallocWithoutInit) {
    ASSERT_NO_THROW([[NSOperation alloc] release]);
}

TEST(NSOperation, QueuePriority) {
    NSOperation* op = [[NSOperation new] autorelease];

    // Past very low/high rounds to very low/high
    op.queuePriority = (NSOperationQueuePriority)-10;
    EXPECT_EQ(NSOperationQueuePriorityVeryLow, op.queuePriority);
    op.queuePriority = (NSOperationQueuePriority)10;
    EXPECT_EQ(NSOperationQueuePriorityVeryHigh, op.queuePriority);

    // Exact matches are accepted
    op.queuePriority = NSOperationQueuePriorityVeryLow; // -8
    EXPECT_EQ(NSOperationQueuePriorityVeryLow, op.queuePriority);
    op.queuePriority = NSOperationQueuePriorityVeryHigh; // 8
    EXPECT_EQ(NSOperationQueuePriorityVeryHigh, op.queuePriority);

    // Between very low/high and low/high rounds to just low/high
    op.queuePriority = (NSOperationQueuePriority)-7;
    EXPECT_EQ(NSOperationQueuePriorityLow, op.queuePriority);
    op.queuePriority = (NSOperationQueuePriority)7;
    EXPECT_EQ(NSOperationQueuePriorityHigh, op.queuePriority);
    op.queuePriority = (NSOperationQueuePriority)-6;
    EXPECT_EQ(NSOperationQueuePriorityLow, op.queuePriority);
    op.queuePriority = (NSOperationQueuePriority)6;
    EXPECT_EQ(NSOperationQueuePriorityHigh, op.queuePriority);
    op.queuePriority = (NSOperationQueuePriority)-5;
    EXPECT_EQ(NSOperationQueuePriorityLow, op.queuePriority);
    op.queuePriority = (NSOperationQueuePriority)5;
    EXPECT_EQ(NSOperationQueuePriorityHigh, op.queuePriority);
    op.queuePriority = NSOperationQueuePriorityLow; // -4
    EXPECT_EQ(NSOperationQueuePriorityLow, op.queuePriority);
    op.queuePriority = NSOperationQueuePriorityHigh; // 4
    EXPECT_EQ(NSOperationQueuePriorityHigh, op.queuePriority);

    // Everything between low and high rounds to normal
    op.queuePriority = (NSOperationQueuePriority)-3;
    EXPECT_EQ(NSOperationQueuePriorityNormal, op.queuePriority);
    op.queuePriority = (NSOperationQueuePriority)3;
    EXPECT_EQ(NSOperationQueuePriorityNormal, op.queuePriority);
    op.queuePriority = (NSOperationQueuePriority)-2;
    EXPECT_EQ(NSOperationQueuePriorityNormal, op.queuePriority);
    op.queuePriority = (NSOperationQueuePriority)2;
    EXPECT_EQ(NSOperationQueuePriorityNormal, op.queuePriority);
    op.queuePriority = (NSOperationQueuePriority)-1;
    EXPECT_EQ(NSOperationQueuePriorityNormal, op.queuePriority);
    op.queuePriority = (NSOperationQueuePriority)1;
    EXPECT_EQ(NSOperationQueuePriorityNormal, op.queuePriority);
    op.queuePriority = NSOperationQueuePriorityNormal; // 0
    EXPECT_EQ(NSOperationQueuePriorityNormal, op.queuePriority);
}

TEST(NSOperation, MainQueue) {
    NSOperationQueue* mainQueue = [NSOperationQueue mainQueue];

    ASSERT_OBJCNE(mainQueue, nil);

    // Quality of service can't be changed
    NSQualityOfService quality = mainQueue.qualityOfService;
    mainQueue.qualityOfService = NSQualityOfServiceBackground;
    EXPECT_EQ(quality, mainQueue.qualityOfService);

    // mainQueue has an unchangeable underlying queue
    ASSERT_NO_THROW([mainQueue setUnderlyingQueue:nullptr]);
    ASSERT_EQ([mainQueue underlyingQueue], dispatch_get_main_queue());
    ASSERT_NO_THROW([mainQueue setUnderlyingQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)]);
    ASSERT_EQ([mainQueue underlyingQueue], dispatch_get_main_queue());
    ASSERT_NO_THROW([mainQueue setUnderlyingQueue:dispatch_get_main_queue()]);
    ASSERT_EQ([mainQueue underlyingQueue], dispatch_get_main_queue());
}

TEST(NSOperation, CurrentQueue) {
    // Check that the current queue is correct at each stage
    __block NSOperationQueue* currentQueue;
    __block NSOperationQueue* queue = [[NSOperationQueue new] autorelease];
    __block NSOperation* operation = [NSBlockOperation blockOperationWithBlock:^{
        currentQueue = [NSOperationQueue currentQueue];
    }];

    __block NSOperationQueue* currentQueue2;
    NSOperationQueue* queue2 = [[NSOperationQueue new] autorelease];
    __block NSOperation* operation2 = [NSBlockOperation blockOperationWithBlock:^{
        [queue addOperation:operation];
        [operation waitUntilFinished];
        currentQueue2 = [NSOperationQueue currentQueue];
    }];

    [queue2 addOperation:operation2];
    ASSERT_TRUE_MSG(_waitOnBlockToFinish(
                        ^(void) {
                            [operation2 waitUntilFinished];
                        },
                        2),
                    "Operation did not finish in time.");
    EXPECT_OBJCEQ(queue, currentQueue);
    EXPECT_OBJCEQ(queue2, currentQueue2);
}

// Test observer for NSOperationQueue that counts the number of changes that occurred for each property
@interface NSOperationQueue_KeyObserver : NSObject
+ (instancetype)observerWithQueue:(NSOperationQueue*)queue;
- (void)observeValueForKeyPath:(NSString*)keyPath ofObject:(id)object change:(NSDictionary*)change context:(void*)context;
- (void)reset;
@property (readonly) NSUInteger suspendedChanges;
@property (readonly) NSUInteger operationsChanges;
@property (readonly) NSUInteger operationCountChanges;
@property (readonly, retain) NSOperationQueue* queue;
@end

@implementation NSOperationQueue_KeyObserver
+ (instancetype)observerWithQueue:(NSOperationQueue*)queue {
    NSOperationQueue_KeyObserver* ret = [[[self class] new] autorelease];
    if (ret) {
        ret->_queue = [queue retain];
        [queue addObserver:ret forKeyPath:@"suspended" options:0 context:nil];
        [queue addObserver:ret forKeyPath:@"operations" options:0 context:nil];
        [queue addObserver:ret forKeyPath:@"operationCount" options:0 context:nil];
    }
    return ret;
}

- (void)dealloc {
    [_queue removeObserver:self forKeyPath:@"suspended" context:nil];
    [_queue removeObserver:self forKeyPath:@"operations" context:nil];
    [_queue removeObserver:self forKeyPath:@"operationCount" context:nil];
    [_queue release];
    [super dealloc];
}

- (void)observeValueForKeyPath:(NSString*)keyPath ofObject:(id)object change:(NSDictionary*)change context:(void*)context {
    if ([keyPath isEqualToString:@"suspended"]) {
        ++_suspendedChanges;
    } else if ([keyPath isEqualToString:@"operations"]) {
        ++_operationsChanges;
    } else if ([keyPath isEqualToString:@"operationCount"]) {
        ++_operationCountChanges;
    } else {
        ASSERT_TRUE_MSG(false, "Observed an unexpected key change");
    }
}

- (void)reset {
    _suspendedChanges = 0;
    _operationsChanges = 0;
    _operationCountChanges = 0;
}

@end

TEST(NSOperation, AddOperation_AndValidateState) {
    __block NSOperationQueue* queue = [[NSOperationQueue new] autorelease];

    // Enable KVO observation
    NSOperationQueue_KeyObserver* observer = [NSOperationQueue_KeyObserver observerWithQueue:queue];

    [queue setSuspended:YES];
    EXPECT_EQ(1, observer.suspendedChanges);
    [observer reset];

    __block THBooleanCondition* startedCondition = [[THBooleanCondition new] autorelease];
    __block THBooleanCondition* finishCondition = [[THBooleanCondition new] autorelease];
    NSOperation* operation = [NSBlockOperation blockOperationWithBlock:^void() {
        [startedCondition broadcast];
        ASSERT_TRUE_MSG([finishCondition waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:2]],
                        "Operation was not allowed to finish in time.");
    }];

    // Validate the initial state of the queue and operation
    ASSERT_EQ(0, queue.operationCount);
    ASSERT_OBJCEQ(@[], queue.operations);
    ASSERT_FALSE(operation.executing);
    ASSERT_FALSE(operation.finished);

    // Add the operation to the queue. The operations/count should reflect the add, but the operation should not have started.
    [queue addOperation:operation];
    ASSERT_EQ(1, queue.operationCount);
    ASSERT_OBJCEQ(@[ operation ], queue.operations);
    ASSERT_FALSE(operation.executing);
    ASSERT_FALSE(operation.finished);
    EXPECT_EQ(1, observer.operationsChanges);
    EXPECT_EQ(1, observer.operationCountChanges);
    [observer reset];

    // Unsuspend the queue. The operation should start shortly.
    [queue setSuspended:NO];
    ASSERT_TRUE_MSG([startedCondition waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:2]], "Operation did not start in time.");
    ASSERT_EQ(1, queue.operationCount);
    ASSERT_OBJCEQ(@[ operation ], queue.operations);
    ASSERT_TRUE(operation.executing);
    ASSERT_FALSE(operation.finished);
    EXPECT_EQ(1, observer.suspendedChanges);
    EXPECT_EQ(0, observer.operationsChanges);
    EXPECT_EQ(0, observer.operationCountChanges);
    [observer reset];

    // Allow the operation to run. The operation should finish shortly.
    [finishCondition broadcast];
    ASSERT_TRUE_MSG(_waitOnBlockToFinish(
                        ^(void) {
                            [queue waitUntilAllOperationsAreFinished];
                        },
                        2),
                    "Operation did not finish in time.");
    ASSERT_EQ(0, queue.operationCount);
    ASSERT_OBJCEQ(@[], queue.operations);
    ASSERT_FALSE(operation.executing);
    ASSERT_TRUE(operation.finished);
    EXPECT_EQ(0, observer.suspendedChanges);
    EXPECT_EQ(1, observer.operationsChanges);
    EXPECT_EQ(1, observer.operationCountChanges);
    [observer reset];
}

TEST(NSOperation, AddOperation_AlreadyInQueue) {
    NSOperationQueue* queue1 = [[NSOperationQueue new] autorelease];
    NSOperationQueue* queue2 = [[NSOperationQueue new] autorelease];
    queue1.suspended = YES;
    queue2.suspended = YES;
    NSOperation* op = [[NSOperation new] autorelease];

    ASSERT_NO_THROW([queue1 addOperation:op]);
    ASSERT_ANY_THROW([queue2 addOperation:op]);

    // Same queue shouldn't work, either
    ASSERT_ANY_THROW([queue1 addOperation:op]);
}

TEST(NSOperation, AddOperationWithBlock) {
    __block NSOperationQueue* queue = [[NSOperationQueue new] autorelease];
    __block bool flag = false;
    [queue addOperationWithBlock:^void() {
        flag = true;
    }];
    ASSERT_TRUE_MSG(_waitOnBlockToFinish(
                        ^(void) {
                            [queue waitUntilAllOperationsAreFinished];
                        },
                        2),
                    "Operation did not finish in time.");
    ASSERT_TRUE(flag);
}

TEST(NSOperation, AddOperations) {
    __block NSOperationQueue* queue = [[NSOperationQueue new] autorelease];

    // Enable KVO observation
    __block NSOperationQueue_KeyObserver* observer = [NSOperationQueue_KeyObserver observerWithQueue:queue];

    __block size_t opsFinished = 0;
    __block THBooleanCondition* startCondition = [[THBooleanCondition new] autorelease];
    void (^incrementOpsFinished)() = ^void() {
        ASSERT_TRUE_MSG([startCondition waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:2]],
                        "Operation was not allowed to start in time.");
        ++opsFinished;
    };

    __block NSArray<NSOperation*>* ops = @[
        [NSBlockOperation blockOperationWithBlock:Block_copy(incrementOpsFinished)],
        [NSBlockOperation blockOperationWithBlock:Block_copy(incrementOpsFinished)],
        [NSBlockOperation blockOperationWithBlock:Block_copy(incrementOpsFinished)]
    ];

    // Add operations with waitUntilFinished:YES
    BlockThread* addOperationsThread = [[[BlockThread alloc] initWithBlock:^void() {
        [queue addOperations:ops waitUntilFinished:YES];
    }] autorelease];
    [addOperationsThread start];

    // Wait until the operations have all been added
    ASSERT_TRUE_MSG(_waitOnBlockToFinish(
                        ^(void) {
                            while (observer.operationsChanges == 0 || queue.operationCount < 3) {
                            }
                        },
                        2),
                    "Operations were not added in time.");

    ASSERT_OBJCEQ([NSSet setWithArray:ops], [NSSet setWithArray:[queue operations]]);
    ASSERT_EQ([ops count], [queue operationCount]);
    ASSERT_TRUE([addOperationsThread isExecuting]);
    ASSERT_FALSE([addOperationsThread isFinished]);
    ASSERT_EQ(0, opsFinished);
    EXPECT_EQ(1, observer.operationsChanges);
    EXPECT_EQ(1, observer.operationCountChanges);
    [observer reset];

    __block THBooleanCondition* startCondition2 = [[THBooleanCondition new] autorelease];
    void (^incrementOpsFinished2)() = ^void() {
        ASSERT_TRUE_MSG([startCondition2 waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:2]],
                        "Operation was not allowed to start in time.");
        ++opsFinished;
    };

    __block NSArray<NSOperation*>* ops2 = @[
        [NSBlockOperation blockOperationWithBlock:Block_copy(incrementOpsFinished2)],
        [NSBlockOperation blockOperationWithBlock:Block_copy(incrementOpsFinished2)],
    ];
    NSThread* addOperationsThread2 = [[[BlockThread alloc] initWithBlock:^void() {
        [queue addOperations:ops2 waitUntilFinished:NO];
    }] autorelease];
    [addOperationsThread2 start];

    // Wait until the operations have all been added
    ASSERT_TRUE_MSG(_waitOnBlockToFinish(
                        ^(void) {
                            while (observer.operationsChanges == 0 || queue.operationCount < 5) {
                            }
                        },
                        2),
                    "Operations were not added in time.");

    ASSERT_EQ(5, [queue operationCount]);
    ASSERT_EQ(0, opsFinished);
    EXPECT_EQ(1, observer.operationsChanges);
    EXPECT_EQ(1, observer.operationCountChanges);
    [observer reset];

    // Allow the first set of ops to start
    [startCondition broadcast];
    ASSERT_TRUE_MSG(_waitOnBlockToFinish(
                        ^(void) {
                            for (NSOperation* op in ops) {
                                [op waitUntilFinished];
                            }
                        },
                        2),
                    "Operations did not finish in time.");

    [addOperationsThread.finishCondition waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:2]];

    ASSERT_EQ(3, opsFinished);

    // Allow the second set of ops to start
    [startCondition2 broadcast];
    ASSERT_TRUE_MSG(_waitOnBlockToFinish(
                        ^(void) {
                            for (NSOperation* op in ops2) {
                                [op waitUntilFinished];
                            }
                        },
                        2),
                    "Operations did not finish in time.");
    ASSERT_EQ(5, opsFinished);
    EXPECT_LT(0, observer.operationsChanges); // Changes to operations may be batched together
    EXPECT_LT(0, observer.operationCountChanges);
    [observer reset];
}

TEST(NSOperation, CancelAllOperations_Suspended) {
    __block NSOperationQueue* queue = [[NSOperationQueue new] autorelease];

    // Enable KVO observation
    NSOperationQueue_KeyObserver* observer = [NSOperationQueue_KeyObserver observerWithQueue:queue];

    [queue setSuspended:YES];
    EXPECT_EQ(1, observer.suspendedChanges);
    [observer reset];

    for (size_t i = 0; i < 5; ++i) {
        [queue addOperation:[[NSOperation new] autorelease]];
    }
    EXPECT_EQ(5, observer.operationsChanges);
    EXPECT_EQ(5, observer.operationCountChanges);
    [observer reset];

    ASSERT_EQ(5, queue.operationCount);
    for (NSOperation* op in queue.operations) {
        ASSERT_FALSE(op.cancelled);
        ASSERT_FALSE(op.executing);
        ASSERT_FALSE(op.finished);
    }

    [queue cancelAllOperations];
    ASSERT_EQ(5, queue.operationCount);
    for (NSOperation* op in queue.operations) {
        ASSERT_TRUE(op.cancelled);
        ASSERT_FALSE(op.executing);
        ASSERT_FALSE(op.finished);
    }
    EXPECT_EQ(0, observer.operationsChanges);
    EXPECT_EQ(0, observer.operationCountChanges);
    [observer reset];

    [queue setSuspended:NO];
    ASSERT_TRUE_MSG(_waitOnBlockToFinish(
                        ^(void) {
                            [queue waitUntilAllOperationsAreFinished];
                        },
                        2),
                    "Operations did not cancel/finish in time.");
    ASSERT_EQ(0, queue.operationCount);
    for (NSOperation* op in queue.operations) {
        ASSERT_TRUE(op.cancelled);
        ASSERT_FALSE(op.executing);
        ASSERT_TRUE(op.finished);
    }

    EXPECT_EQ(1, observer.suspendedChanges);
    EXPECT_LT(0, observer.operationsChanges); // Changes to operations may be batched together
    EXPECT_LT(0, observer.operationCountChanges);
    [observer reset];
}

// An NSOperation for testing that only finishes if cancelled
@interface CancellableOperation : NSOperation
@property (retain, readonly) THBooleanCondition* started;
@end

@implementation CancellableOperation : NSOperation
- (instancetype)init {
    if (self = [super init]) {
        _started = [THBooleanCondition new];
    }
    return self;
}
- (void)main {
    [_started broadcast];
    while (!self.cancelled) {
    }
}
@end

TEST(NSOperation, CancelAllOperations_Running) {
    NSOperationQueue* queue = [[NSOperationQueue new] autorelease];

    for (size_t i = 0; i < 5; ++i) {
        [queue addOperation:[[CancellableOperation new] autorelease]];
    }

    ASSERT_EQ(5, queue.operationCount);

    [queue cancelAllOperations];
    ASSERT_TRUE_MSG(_waitOnBlockToFinish(
                        ^(void) {
                            [queue waitUntilAllOperationsAreFinished];
                        },
                        2),
                    "Operations did not cancel/finish in time.");
    ASSERT_EQ(0, queue.operationCount);
    for (NSOperation* op in queue.operations) {
        ASSERT_TRUE(op.cancelled);
        ASSERT_FALSE(op.executing);
        ASSERT_TRUE(op.finished);
    }
}

TEST(NSOperation, WaitUntilAllOperationsAreFinished) {
    __block NSOperationQueue* queue = [[NSOperationQueue new] autorelease];

    __block THBooleanCondition* startCondition = [[THBooleanCondition new] autorelease];
    void (^waitForStartCondition)() = ^void() {
        ASSERT_TRUE_MSG([startCondition waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:2]], "Operation did not start in time.");
    };

    __block NSArray<NSOperation*>* ops = @[
        [NSBlockOperation blockOperationWithBlock:Block_copy(waitForStartCondition)],
        [NSBlockOperation blockOperationWithBlock:Block_copy(waitForStartCondition)],
        [NSBlockOperation blockOperationWithBlock:Block_copy(waitForStartCondition)],
        [NSBlockOperation blockOperationWithBlock:Block_copy(waitForStartCondition)],
        [NSBlockOperation blockOperationWithBlock:Block_copy(waitForStartCondition)]
    ];

    // On a separate thread, add a bunch of operations, then wait until they're all finished
    __block THBooleanCondition* addedOperationsCondition = [[THBooleanCondition new] autorelease];
    __block THBooleanCondition* finishedWaitingCondition = [[THBooleanCondition new] autorelease];

    BlockThread* addOperationsAndWaitThread = [[[BlockThread alloc] initWithBlock:^void() {
        [queue addOperations:ops waitUntilFinished:NO];
        [addedOperationsCondition broadcast];
        [queue waitUntilAllOperationsAreFinished];
    }] autorelease];
    [addOperationsAndWaitThread start];
    ASSERT_TRUE_MSG([addedOperationsCondition waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:2]], "Operations were not added in time.");

    // Validate that at least one operation is currently running, with a little bit of leeway for time.
    bool atLeastOneOperationRunning = false;
    size_t numTries = 0;
    while ((!atLeastOneOperationRunning) && (numTries < 2)) {
        for (NSOperation* op in ops) {
            if (op.executing && !op.finished) {
                atLeastOneOperationRunning = true;
                break;
            }
        }

        if (!atLeastOneOperationRunning) {
            ++numTries;
            std::this_thread::sleep_for(std::chrono::milliseconds(10));
        }
    }
    ASSERT_TRUE(atLeastOneOperationRunning);

    // Validate the current state
    ASSERT_TRUE(addOperationsAndWaitThread.executing);
    ASSERT_FALSE(addOperationsAndWaitThread.finished);

    // Add an extra operation
    NSOperation* extraOperation = [[NSOperation new] autorelease];
    [queue addOperation:extraOperation];

    // Allow the operations to run
    [startCondition broadcast];

    // waitUntilAllOperationsAreFinished should stop blocking not long after
    ASSERT_TRUE_MSG([addOperationsAndWaitThread.finishCondition waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:2]],
                    "waitUntilAllOperationsAreFinished did not unblock in time.");
    ASSERT_FALSE(extraOperation.executing);
    ASSERT_TRUE(extraOperation.finished);
    for (NSOperation* op in ops) {
        ASSERT_FALSE(op.executing);
        ASSERT_TRUE(op.finished);
    }
}

TEST(NSOperation, UnderlyingQueue_QualityOfService) {
    NSOperationQueue* queue = [[NSOperationQueue new] autorelease];

    ASSERT_EQ(nullptr, queue.underlyingQueue);

    // Should not change underlyingQueue
    queue.qualityOfService = NSQualityOfServiceBackground;
    ASSERT_EQ(nullptr, queue.underlyingQueue);

    // Should not change quality of service
    dispatch_queue_t dispatchQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    queue.underlyingQueue = dispatchQueue;
    ASSERT_EQ(dispatchQueue, queue.underlyingQueue);
    ASSERT_EQ(NSQualityOfServiceBackground, queue.qualityOfService);
}

TEST(NSOperation, MaxConcurrentOperationCount) {
    __block NSOperationQueue* queue = [[NSOperationQueue new] autorelease];

    // Limit maxConcurrentOperationCount to 1
    queue.maxConcurrentOperationCount = 1;
    ASSERT_EQ(1, queue.maxConcurrentOperationCount);

    // Verify that only one operation is running at a time
    __block NSUInteger currentlyRunningOperations = 0;
    __block NSUInteger highestSimultaneousOperations = 0;

    void (^checkSimultaneousOperations)() = ^void() {
        ++currentlyRunningOperations;
        highestSimultaneousOperations = std::max(currentlyRunningOperations, highestSimultaneousOperations);
        --currentlyRunningOperations;
    };

    __block NSArray<NSOperation*>* ops = @[
        [NSBlockOperation blockOperationWithBlock:Block_copy(checkSimultaneousOperations)],
        [NSBlockOperation blockOperationWithBlock:Block_copy(checkSimultaneousOperations)],
        [NSBlockOperation blockOperationWithBlock:Block_copy(checkSimultaneousOperations)],
        [NSBlockOperation blockOperationWithBlock:Block_copy(checkSimultaneousOperations)],
        [NSBlockOperation blockOperationWithBlock:Block_copy(checkSimultaneousOperations)],
        [NSBlockOperation blockOperationWithBlock:Block_copy(checkSimultaneousOperations)]
    ];

    ASSERT_TRUE_MSG(_waitOnBlockToFinish(
                        ^(void) {
                            // EXPECT_TRUE(false);
                            [queue addOperations:ops waitUntilFinished:YES];
                            // EXPECT_TRUE(false);
                        },
                        2),
                    "Operations did not finish in time.");
    ASSERT_EQ(1, highestSimultaneousOperations);

    // Add one operation that's stuck
    CancellableOperation* cancellableOperation = [[CancellableOperation new] autorelease];
    [queue addOperation:cancellableOperation];

    // Add a bunch of empty operations
    __block NSArray<NSOperation*>* ops2 = @[
        [[NSOperation new] autorelease],
        [[NSOperation new] autorelease],
        [[NSOperation new] autorelease],
        [[NSOperation new] autorelease],
        [[NSOperation new] autorelease],
        [[NSOperation new] autorelease],
        [[NSOperation new] autorelease],
        [[NSOperation new] autorelease]
    ];
    [queue addOperations:ops2 waitUntilFinished:NO];

    // Wait until the stuck operation starts
    ASSERT_TRUE_MSG([cancellableOperation.started waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:2]],
                    "Operation did not start in time.");
    ASSERT_TRUE(cancellableOperation.executing);

    // The other operations should not be able to start
    for (NSOperation* op in ops2) {
        ASSERT_FALSE(op.executing);
        ASSERT_FALSE(op.finished);
    }

    // Raise the max concurrent operation count, which should allow the other operations to execute
    queue.maxConcurrentOperationCount = 3;
    ASSERT_EQ(3, queue.maxConcurrentOperationCount);

    ASSERT_TRUE_MSG(_waitOnBlockToFinish(
                        ^(void) {
                            for (NSOperation* op in ops2) {
                                [op waitUntilFinished];
                            }
                        },
                        2),
                    "Operations did not finish in time.");

    [cancellableOperation cancel]; // cleanup
}

// Testable NSOperation that has a mutable, KVO-compliant isReady property
@interface ReadiableOperation : NSOperation
@property (getter=isReady) BOOL ready;
@end

@implementation ReadiableOperation
@synthesize ready = _ready;

- (BOOL)isReady {
    return [super isReady] && _ready;
}

- (void)setReady:(BOOL)ready {
    [self willChangeValueForKey:@"isReady"];
    _ready = ready;
    [self didChangeValueForKey:@"isReady"];
}

@end

TEST(NSOperation, NotReady_SuspendedOperations) {
    NSOperationQueue* queue = [[NSOperationQueue new] autorelease];

    // A non-ready operation executes once it becomes ready
    __block ReadiableOperation* op1 = [[ReadiableOperation new] autorelease];

    [queue addOperation:op1];
    ASSERT_EQ(1, queue.operationCount);
    ASSERT_FALSE(op1.executing || op1.finished);
    ASSERT_FALSE(op1.ready);

    op1.ready = YES;
    ASSERT_TRUE_MSG(_waitOnBlockToFinish(
                        ^(void) {
                            [op1 waitUntilFinished];
                        },
                        2),
                    "Operation did not finish in time.");

    // Add a non-ready operation during a suspension
    __block ReadiableOperation* op2 = [[ReadiableOperation new] autorelease];

    queue.suspended = YES;
    [queue addOperation:op2];
    ASSERT_EQ(1, queue.operationCount);
    ASSERT_FALSE(op2.executing || op2.finished);

    // If the suspension is lifted, the operation still doesn't execute if not ready
    queue.suspended = NO;
    ASSERT_EQ(1, queue.operationCount);
    ASSERT_FALSE(op2.executing || op2.finished);

    // If the operation is ready but the queue is suspended, the operation still does not execute
    queue.suspended = YES;
    op2.ready = YES;
    ASSERT_EQ(1, queue.operationCount);
    ASSERT_FALSE(op2.executing || op2.finished);

    // If both conditions are lifted, the operation should execute
    queue.suspended = NO;
    ASSERT_TRUE_MSG(_waitOnBlockToFinish(
                        ^(void) {
                            [op2 waitUntilFinished];
                        },
                        2),
                    "Operation did not finish in time.");
}

TEST(NSOperation, OrderOfOperations_SamePriority) {
    __block NSOperationQueue* queue = [[NSOperationQueue new] autorelease];
    __block NSMutableArray* array = [[NSMutableArray new] autorelease];

    queue.suspended = YES;
    queue.maxConcurrentOperationCount = 1;

    [queue addOperationWithBlock:^void() {
        [array addObject:@0];
    }];
    [queue addOperationWithBlock:^void() {
        [array addObject:@1];
    }];
    [queue addOperationWithBlock:^void() {
        [array addObject:@2];
    }];
    [queue addOperationWithBlock:^void() {
        [array addObject:@3];
    }];
    [queue addOperationWithBlock:^void() {
        [array addObject:@4];
    }];

    queue.suspended = NO;
    ASSERT_TRUE_MSG(_waitOnBlockToFinish(
                        ^(void) {
                            [queue waitUntilAllOperationsAreFinished];
                        },
                        2),
                    "Operations did not finish in time.");

    // When operations are all the same priority, queue should execute first-in first-out
    NSArray* expected = @[ @0, @1, @2, @3, @4 ];
    EXPECT_OBJCEQ(expected, array);
    EXPECT_EQ(0, queue.operations.count);
}

TEST(NSOperation, OrderOfOperations_DifferentPriority) {
    __block NSOperationQueue* queue = [[NSOperationQueue new] autorelease];
    __block NSMutableArray* array = [[NSMutableArray new] autorelease];

    queue.suspended = YES;
    queue.maxConcurrentOperationCount = 1;
    NSBlockOperation* op0 = [NSBlockOperation blockOperationWithBlock:^void() {
        [array addObject:@0];
    }];
    NSBlockOperation* op1 = [NSBlockOperation blockOperationWithBlock:^void() {
        [array addObject:@1];
    }];
    NSBlockOperation* op2 = [NSBlockOperation blockOperationWithBlock:^void() {
        [array addObject:@2];
    }];
    NSBlockOperation* op3 = [NSBlockOperation blockOperationWithBlock:^void() {
        [array addObject:@3];
    }];
    NSBlockOperation* op4 = [NSBlockOperation blockOperationWithBlock:^void() {
        [array addObject:@4];
    }];
    NSBlockOperation* op5 = [NSBlockOperation blockOperationWithBlock:^void() {
        [array addObject:@5];
    }];

    op0.queuePriority = NSOperationQueuePriorityNormal;
    op1.queuePriority = NSOperationQueuePriorityLow;
    op2.queuePriority = NSOperationQueuePriorityVeryLow;
    op3.queuePriority = NSOperationQueuePriorityHigh;
    op4.queuePriority = NSOperationQueuePriorityHigh;
    op5.queuePriority = NSOperationQueuePriorityVeryLow;

    __block NSArray<NSOperation*>* ops = @[ op0, op1, op2, op3, op4, op5 ];

    queue.suspended = NO;
    ASSERT_TRUE_MSG(_waitOnBlockToFinish(
                        ^(void) {
                            [queue addOperations:ops waitUntilFinished:YES];
                        },
                        2),
                    "Operations did not finish in time.");

    // Should be sorted first by priority, then by first-in first out
    NSArray* expected = @[ @3, @4, @0, @1, @2, @5 ];
    ASSERT_OBJCEQ(expected, array);
}
