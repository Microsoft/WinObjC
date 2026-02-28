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

#import "Foundation/Foundation.h"
#import "TestFramework.h"

// Some of NSPointerFunctions is implicitly tested in NSMapTableTests - this file is primarily aimed at the remainder

// Helper that tests the isEqualFunction of a NSPointerFunctions instance
// item1 is expected to be equal to item2, where as item3 is different
void testEqualFunction(NSPointerFunctions* functions, const void* item1, const void* item2, const void* item3) {
    auto isEqualFunction = functions.isEqualFunction;
    auto sizeFunction = functions.sizeFunction;
    ASSERT_EQ(YES, isEqualFunction(item1, item2, sizeFunction));
    ASSERT_EQ(NO, isEqualFunction(item1, item3, sizeFunction));
}

// Helper that tests hashFunction of a NSPointerFunctions instance
// item1 is expected to be equal to item2, where as item3 is different
void testHashFunction(NSPointerFunctions* functions, const void* item1, const void* item2, const void* item3) {
    auto hashFunction = functions.hashFunction;
    auto sizeFunction = functions.sizeFunction;
    ASSERT_EQ(hashFunction(item1, sizeFunction), hashFunction(item2, sizeFunction));
    ASSERT_NE(hashFunction(item1, sizeFunction), hashFunction(item3, sizeFunction));
}

TEST(NSPointerFunctions, StringPersonality) {
    NSPointerFunctions* functions = [NSPointerFunctions pointerFunctionsWithOptions:NSPointerFunctionsCStringPersonality];

    const char* str1 = "objc";
    const char* str2 = "objc";
    const char* str3 = "not objc";

    testEqualFunction(functions, str1, str2, str3);
    testHashFunction(functions, str1, str2, str3);

    ASSERT_OBJCEQ([NSString stringWithUTF8String:str1], functions.descriptionFunction(str1));
}

// Test struct & size function for testing struct personality
typedef struct {
    int anInt;
    bool aBool;
    char aChar;
} NSPointerFunctionsTestStruct;

NSUInteger NSPointerFunctionsTestStructSizeFunction(const void* item) {
    return sizeof(NSPointerFunctionsTestStruct);
}

TEST(NSPointerFunctions, StructPersonality) {
    NSPointerFunctions* functions = [NSPointerFunctions pointerFunctionsWithOptions:NSPointerFunctionsStructPersonality];
    [functions setSizeFunction:&NSPointerFunctionsTestStructSizeFunction];

    NSPointerFunctionsTestStruct struct1 = { 37, false, 'c' };
    NSPointerFunctionsTestStruct struct2 = { 37, false, 'c' };
    NSPointerFunctionsTestStruct struct3 = { 24, true, 'e' };

    testEqualFunction(functions, &struct1, &struct2, &struct3);
}

TEST(NSPointerFunctions, OpaquePersonality) {
    NSPointerFunctions* functions = [NSPointerFunctions pointerFunctionsWithOptions:NSPointerFunctionsOpaquePersonality];

    const void* ptr1 = (void*)0x3;
    const void* ptr2 = ptr1;
    const void* ptr3 = (void*)((long)ptr1 + 1);

    testEqualFunction(functions, ptr1, ptr2, ptr3);
    // Disabling hash function check here as performing hash on opaque values cannot be accurately matched with the reference platform.
    // testHashFunction(functions, ptr1, ptr2, ptr3);
}

TEST(NSPointerFunctions, IntegerPersonality) {
    NSPointerFunctions* functions =
        [NSPointerFunctions pointerFunctionsWithOptions:NSPointerFunctionsOpaqueMemory | NSPointerFunctionsIntegerPersonality];

    long int1 = 3425;
    long int2 = 3425;
    long int3 = 23526526;

    testEqualFunction(functions, (void*)int1, (void*)int2, (void*)int3);
    testHashFunction(functions, (void*)int1, (void*)int2, (void*)int3);
}

// Disabling test from running on OSX as the reference platform behavior is to log error and then return a nil when an invalid config
// is used. We have decided to be a little more strict on our platform by throwing an exception instead.
OSX_DISABLED_TEST(NSPointerFunctions, InvalidConfig) {
    LOG_INFO("Invalid config messages during this test are expected:");

    // Not a value of NSPointerFunctionsOptions
    ASSERT_ANY_THROW([NSPointerFunctions pointerFunctionsWithOptions:7]);

    // Weak & CopyIn
    ASSERT_ANY_THROW([NSPointerFunctions pointerFunctionsWithOptions:NSPointerFunctionsWeakMemory | NSPointerFunctionsCopyIn]);

    // Integer personality without opaque memory
    ASSERT_ANY_THROW([NSPointerFunctions pointerFunctionsWithOptions:NSPointerFunctionsIntegerPersonality]);
}

TEST(NSPointerFunctions, Copy) {
    NSPointerFunctions* functions =
        [NSPointerFunctions pointerFunctionsWithOptions:NSPointerFunctionsOpaqueMemory | NSPointerFunctionsIntegerPersonality];

    NSPointerFunctions* functionsCopy = [[functions copy] autorelease];

    ASSERT_EQ(functions.hashFunction, functionsCopy.hashFunction);
    ASSERT_EQ(functions.isEqualFunction, functionsCopy.isEqualFunction);
    ASSERT_EQ(functions.acquireFunction, functionsCopy.acquireFunction);
    ASSERT_EQ(functions.relinquishFunction, functionsCopy.relinquishFunction);
    ASSERT_EQ(functions.descriptionFunction, functionsCopy.descriptionFunction);
    ASSERT_EQ(functions.sizeFunction, functionsCopy.sizeFunction);
    ASSERT_EQ(functions.usesStrongWriteBarrier, functionsCopy.usesStrongWriteBarrier);
    ASSERT_EQ(functions.usesWeakReadAndWriteBarriers, functionsCopy.usesWeakReadAndWriteBarriers);
}