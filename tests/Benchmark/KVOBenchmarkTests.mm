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

#import <Starboard/SmartTypes.h>
#import "Benchmark.h"
#import <CppUtils.h>
#import <atomic>

// Minimal object that supports KVO notifications for a property
@interface TestKVOObject : NSObject
@property NSInteger intProperty;
@end

@implementation TestKVOObject
@end

// Minimal object for observing to TestKVOObject
static std::atomic<size_t> s_observedCount;
@interface TestKVOObserver : NSObject
@end

@implementation TestKVOObserver
- (void)observeValueForKeyPath:(NSString*)keyPath ofObject:(id)object change:(NSDictionary*)change context:(void*)context {
    ++s_observedCount;
}
@end

class AddObservers : public ::benchmark::BenchmarkCaseBase {
    StrongId<TestKVOObject> _testKVOObject;
    StrongId<NSMutableArray> _testObservers;

public:
    void PreRun() {
        _testKVOObject.attach([TestKVOObject new]);
        _testObservers.attach([NSMutableArray new]);
        @autoreleasepool {
            for (size_t i = 0; i < 1000; ++i) {
                [_testObservers addObject:[[NSObject new] autorelease]];
            }
        }
    }

    inline void Run() {
        for (NSObject* obj in _testObservers.get()) {
            [_testKVOObject addObserver:obj forKeyPath:@"intProperty" options:0 context:nullptr];
        }
    }

    void PostRun() {
        for (NSObject* obj in _testObservers.get()) {
            [_testKVOObject removeObserver:obj forKeyPath:@"intProperty" context:nullptr];
        }
    }

    size_t GetRunCount() const {
        return 30;
    }
};

BENCHMARK_F(KVO, AddObservers)

class RemoveObservers : public ::benchmark::BenchmarkCaseBase {
    StrongId<TestKVOObject> _testKVOObject;
    StrongId<NSMutableArray> _testObservers;

public:
    void PreRun() {
        _testKVOObject.attach([TestKVOObject new]);
        _testObservers.attach([NSMutableArray new]);
        @autoreleasepool {
            for (size_t i = 0; i < 1000; ++i) {
                [_testObservers addObject:[[NSObject new] autorelease]];
            }
        }

        for (NSObject* obj in _testObservers.get()) {
            [_testKVOObject addObserver:obj forKeyPath:@"intProperty" options:0 context:nullptr];
        }
    }

    inline void Run() {
        for (NSObject* obj in _testObservers.get()) {
            [_testKVOObject removeObserver:obj forKeyPath:@"intProperty" context:nullptr];
        }
    }

    size_t GetRunCount() const {
        return 30;
    }
};

BENCHMARK_F(KVO, RemoveObservers)

class ObserveChange : public ::benchmark::BenchmarkCaseBase {
    StrongId<TestKVOObject> _testKVOObject;
    // GH#2862
    // https://bugs.llvm.org/show_bug.cgi?id=25343
    // New template rules in Clang >= 6.0.0 combined with a _lack_ of
    // new mangling rules for Objective-C generics causes this to emit
    // a spurious "definition with same mangled name as another definition"
    // in SmartTypes.h.
    StrongId<NSMutableArray/*<TestKVOObserver*>*/> _testObservers;

public:
    void PreRun() {
        _testKVOObject.attach([TestKVOObject new]);
        _testObservers = [NSMutableArray<TestKVOObserver*> arrayWithCapacity:1000];

        @autoreleasepool {
            for (size_t i = 0; i < 1000; ++i) {
                TestKVOObserver* observer = [[TestKVOObserver new] autorelease];
                [_testKVOObject addObserver:observer forKeyPath:@"intProperty" options:0 context:nullptr];
                [_testObservers addObject:observer];
            }
        }
    }

    inline void Run() {
        for (size_t i = 0; i < 100; ++i) {
            [_testKVOObject setIntProperty:([_testKVOObject intProperty] + 1)];

            // wait for kvo notifications to propagate
            while (s_observedCount < 1000) {
            }
            s_observedCount = 0;
        }
    }

    void PostRun() {
        for (TestKVOObserver* observer in _testObservers.get()) {
            [_testKVOObject removeObserver:observer forKeyPath:@"intProperty" context:nullptr];
        }
    }

    size_t GetRunCount() const {
        return 20;
    }
};

BENCHMARK_F(KVO, ObserveChange)