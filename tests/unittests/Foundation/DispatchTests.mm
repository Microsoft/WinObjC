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

static const char* key = "Specific Key";
static const char* key2 = "Specific Key2";
static const char* key3 = "Specific Key3";
static char* context = "Specific Context 1";
static char* context2 = "Specific Context 2";
static char* context3 = "Specific Context 3";
static int destructorCount = 0;

// Create a 1 second end time for the test to timeout.
static dispatch_time_t _createEndTestTime() {
    return dispatch_time(DISPATCH_TIME_NOW, 1000000000);
}

static dispatch_semaphore_t destructorSemaphore;
static void destructor(void* x) {
    destructorCount++;
    if (destructorSemaphore) {
        dispatch_semaphore_signal(destructorSemaphore);
    }
}

TEST(DispatchTests, SimpleSpecific) {
    dispatch_queue_t queue = dispatch_queue_create("queue", nullptr);
    dispatch_group_t group = dispatch_group_create();

    dispatch_queue_set_specific(queue, key, context, nullptr);

    dispatch_group_async(group, queue, ^{
        EXPECT_EQ(context, dispatch_get_specific(key));
        dispatch_queue_set_specific(queue, key, context2, nullptr);
    });

    ASSERT_EQ(0, dispatch_group_wait(group, _createEndTestTime()));

    EXPECT_EQ(context2, dispatch_queue_get_specific(queue, key));

    dispatch_group_async(group, queue, ^{
        EXPECT_EQ(context2, dispatch_get_specific(key));
    });
    ASSERT_EQ(0, dispatch_group_wait(group, _createEndTestTime()));

    dispatch_release(group);
    dispatch_release(queue);
}

TEST(DispatchTests, MultipleSpecificKeys) {
    dispatch_queue_t queue = dispatch_queue_create("queue", nullptr);
    dispatch_group_t group = dispatch_group_create();

    dispatch_queue_set_specific(queue, key, context, nullptr);
    dispatch_queue_set_specific(queue, key2, context2, nullptr);

    dispatch_group_async(group, queue, ^{
        EXPECT_EQ(context, dispatch_get_specific(key));
        EXPECT_EQ(context2, dispatch_get_specific(key2));
        dispatch_queue_set_specific(queue, key, context2, nullptr);
        dispatch_queue_set_specific(queue, key2, context, nullptr);
    });
    ASSERT_EQ(0, dispatch_group_wait(group, _createEndTestTime()));

    EXPECT_EQ(context2, dispatch_queue_get_specific(queue, key));
    EXPECT_EQ(context, dispatch_queue_get_specific(queue, key2));

    dispatch_queue_set_specific(queue, key3, context3, nullptr);

    dispatch_group_async(group, queue, ^{
        EXPECT_EQ(context2, dispatch_get_specific(key));
        EXPECT_EQ(context, dispatch_get_specific(key2));
        EXPECT_EQ(context3, dispatch_get_specific(key3));
    });
    ASSERT_EQ(0, dispatch_group_wait(group, _createEndTestTime()));

    dispatch_release(queue);
    dispatch_release(group);
}

TEST(DispatchTests, SpecificDestructor) {
    dispatch_queue_t queue = dispatch_queue_create("queue", nullptr);
    dispatch_group_t group = dispatch_group_create();
    destructorSemaphore = dispatch_semaphore_create(0);

    dispatch_queue_set_specific(queue, key, context, destructor);

    EXPECT_EQ(0, destructorCount);

    dispatch_group_async(group, queue, ^{
        EXPECT_EQ(dispatch_get_specific(key), context);
        dispatch_queue_set_specific(queue, key, context2, destructor);
        // Destructor can be called asynchrounously. Wait for deestructor to be called.
        dispatch_semaphore_wait(destructorSemaphore, _createEndTestTime());
        EXPECT_EQ(1, destructorCount);
    });
    ASSERT_EQ(dispatch_group_wait(group, _createEndTestTime()), 0);

    EXPECT_EQ(context2, dispatch_queue_get_specific(queue, key));
    dispatch_queue_set_specific(queue, key, context, destructor);
    dispatch_semaphore_wait(destructorSemaphore, _createEndTestTime());
    EXPECT_EQ(2, destructorCount);

    dispatch_group_async(group, queue, ^{
        EXPECT_EQ(context, dispatch_get_specific(key));
        EXPECT_EQ(2, destructorCount);
    });
    ASSERT_EQ(0, dispatch_group_wait(group, _createEndTestTime()));

    dispatch_release(queue);
    dispatch_release(group);
    dispatch_release(destructorSemaphore);
    destructorSemaphore = nullptr;
}

TEST(DispatchTests, RemoveSpecific) {
    dispatch_queue_t queue = dispatch_queue_create("queue", nullptr);
    dispatch_group_t group = dispatch_group_create();

    dispatch_queue_set_specific(queue, key, context, nullptr);

    dispatch_group_async(group, queue, ^{
        EXPECT_EQ(context, dispatch_get_specific(key));
        dispatch_queue_set_specific(queue, key, nullptr, nullptr);
    });
    ASSERT_EQ(0, dispatch_group_wait(group, _createEndTestTime()));

    EXPECT_EQ(nullptr, dispatch_queue_get_specific(queue, key));

    dispatch_release(queue);
    dispatch_release(group);
}

TEST(DispatchTests, MultipleQueues) {
    dispatch_queue_t queue1 = dispatch_queue_create("queue1", nullptr);
    dispatch_queue_t queue2 = dispatch_queue_create("queue2", nullptr);
    dispatch_queue_t queue3 = dispatch_queue_create("queue3", nullptr);
    dispatch_group_t group = dispatch_group_create();

    dispatch_queue_set_specific(queue1, key, context, nullptr);
    dispatch_queue_set_specific(queue2, key, context2, nullptr);
    dispatch_queue_set_specific(queue3, key, context3, nullptr);

    dispatch_group_async(group, queue1, ^{
        EXPECT_EQ(context, dispatch_get_specific(key));
        dispatch_queue_set_specific(queue1, key, context2, nullptr);
    });
    dispatch_group_async(group, queue2, ^{
        EXPECT_EQ(context2, dispatch_get_specific(key));
        dispatch_queue_set_specific(queue2, key, context3, nullptr);
    });
    dispatch_group_async(group, queue3, ^{
        EXPECT_EQ(context3, dispatch_get_specific(key));
        dispatch_queue_set_specific(queue3, key, context, nullptr);
    });
    ASSERT_EQ(0, dispatch_group_wait(group, _createEndTestTime()));

    EXPECT_EQ(context2, dispatch_queue_get_specific(queue1, key));
    EXPECT_EQ(context3, dispatch_queue_get_specific(queue2, key));
    EXPECT_EQ(context, dispatch_queue_get_specific(queue3, key));

    dispatch_group_async(group, queue1, ^{
        EXPECT_EQ(context2, dispatch_get_specific(key));
    });
    dispatch_group_async(group, queue2, ^{
        EXPECT_EQ(context3, dispatch_get_specific(key));
    });
    dispatch_group_async(group, queue3, ^{
        EXPECT_EQ(context, dispatch_get_specific(key));
    });
    ASSERT_EQ(0, dispatch_group_wait(group, _createEndTestTime()));

    dispatch_queue_set_specific(queue1, key2, context, nullptr);
    dispatch_queue_set_specific(queue1, key2, context3, nullptr);
    dispatch_queue_set_specific(queue3, key3, context3, nullptr);

    dispatch_group_async(group, queue1, ^{
        EXPECT_EQ(context2, dispatch_get_specific(key));
        EXPECT_EQ(context3, dispatch_get_specific(key2));
    });
    dispatch_group_async(group, queue2, ^{
        EXPECT_EQ(context3, dispatch_get_specific(key));
    });
    dispatch_group_async(group, queue3, ^{
        EXPECT_EQ(context, dispatch_get_specific(key));
        EXPECT_EQ(context3, dispatch_get_specific(key3));
    });
    ASSERT_EQ(0, dispatch_group_wait(group, _createEndTestTime()));

    dispatch_release(queue1);
    dispatch_release(queue2);
    dispatch_release(queue3);
    dispatch_release(group);
}