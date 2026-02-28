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

#include <TestFramework.h>
#include <Foundation/Foundation.h>

@interface NSRunLoopTest : NSObject
- (void)shouldNotBeCalled;
@end

@implementation NSRunLoopTest

- (void)shouldNotBeCalled {
    FAIL();
}

@end

TEST(NSRunLoop, CancelPerformSelector) {
    dispatch_group_t group = dispatch_group_create();
    dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSRunLoop* runLoop = [NSRunLoop currentRunLoop];
        ASSERT_NE(nil, runLoop);

        NSArray* modes = @[NSDefaultRunLoopMode, NSRunLoopCommonModes];
        NSRunLoopTest* test = [[NSRunLoopTest new] autorelease];

        [runLoop performSelector:@selector(shouldNotBeCalled) target:test argument:nil order:1 modes:modes];
        [runLoop cancelPerformSelector:@selector(shouldNotBeCalled) target:test argument:nil];
        [runLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];
    });

    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    dispatch_release(group);
}