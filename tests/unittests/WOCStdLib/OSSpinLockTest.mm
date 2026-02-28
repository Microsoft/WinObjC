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
#import <dispatch/dispatch.h>
#import <libkern/OSAtomic.h>

// Create a 1 second end time for the test to timeout.
static dispatch_time_t _createEndTestTime() {
    return dispatch_time(DISPATCH_TIME_NOW, 1000000000);
}

TEST(OSSpinLock, SpinLockTests) {
    // Use two queues for concurrency as DISPATCH_QUEUE_CONCURRENT is not yet supported.
    dispatch_queue_t queue1 = dispatch_queue_create("queue", nullptr);
    dispatch_queue_t queue2 = dispatch_queue_create("queue", nullptr);
    dispatch_semaphore_t semaphore1 = dispatch_semaphore_create(0);
    dispatch_semaphore_t semaphore2 = dispatch_semaphore_create(0);

    __block OSSpinLock lock1 = OS_SPINLOCK_INIT;
    __block OSSpinLock lock2 = OS_SPINLOCK_INIT;
    __block OSSpinLock lock3 = OS_SPINLOCK_INIT;
    __block int spinValue = 0;

    OSSpinLockLock(&lock1);
    OSSpinLockLock(&lock2);
    OSSpinLockLock(&lock3);

    dispatch_async(queue1, ^{
        dispatch_semaphore_wait(semaphore1, _createEndTestTime());

        ASSERT_EQ(false, OSSpinLockTry(&lock1));
        ASSERT_EQ(0, spinValue);
        spinValue++;
        ASSERT_EQ(1, spinValue);
        OSSpinLockUnlock(&lock2);
        dispatch_semaphore_signal(semaphore2);
    });

    dispatch_async(queue2, ^{
        dispatch_semaphore_signal(semaphore1);

        OSSpinLockLock(&lock2);
        ASSERT_EQ(false, OSSpinLockTry(&lock1));
        ASSERT_EQ(1, spinValue);
        spinValue++;
        ASSERT_EQ(2, spinValue);
        OSSpinLockUnlock(&lock1);
        OSSpinLockUnlock(&lock2);
        OSSpinLockUnlock(&lock3);
        dispatch_semaphore_signal(semaphore2);
    });

    dispatch_semaphore_wait(semaphore2, _createEndTestTime());
    dispatch_semaphore_wait(semaphore2, _createEndTestTime());

    ASSERT_EQ(true, OSSpinLockTry(&lock3));
    ASSERT_EQ(false, OSSpinLockTry(&lock3));
    OSSpinLockUnlock(&lock3);

    dispatch_release(queue1);
    dispatch_release(queue2);
    dispatch_release(semaphore1);
    dispatch_release(semaphore2);
}