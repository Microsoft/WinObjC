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

#import <TestFramework.h>
#import <Foundation/Foundation.h>
#import <complex>

struct ArbitrarilyComplexStruct {
    double i;
    std::complex<double> c;
};

TEST(NSValue, canStoreAPointer) {
    id val = [NSValue valueWithPointer:(void*)0x10101];
    ASSERT_OBJCNE(nil, val);
    ASSERT_EQ((void*)0x10101, [val pointerValue]);
}

TEST(NSValue, canStoreANullPointer) {
    id val;
    ASSERT_NO_THROW(val = [NSValue valueWithPointer:NULL]);
    ASSERT_OBJCNE(nil, val);
    ASSERT_EQ(NULL, [val pointerValue]);
}

TEST(NSValue, specializedInstanceIsStillAnNSValue) {
    id val = [NSValue valueWithPointer:(void*)0x10101];
    ASSERT_EQ(YES, [val isKindOfClass:[NSValue class]]);
}

TEST(NSValue, arbitraryStructCanBeStored) {
    using namespace std::complex_literals;
    ArbitrarilyComplexStruct acs{ 3.14, 1.9i };

    id val = [NSValue valueWithBytes:&acs objCType:@encode(ArbitrarilyComplexStruct)];
    ASSERT_OBJCNE(nil, val);
}

TEST(NSValue, arbitraryStructCanBeRetrieved) {
    using namespace std::complex_literals;
    ArbitrarilyComplexStruct acs{ 3.14, 1.9i };

    id val = [NSValue valueWithBytes:&acs objCType:@encode(ArbitrarilyComplexStruct)];
    ArbitrarilyComplexStruct acs2{};
    ASSERT_NO_THROW([val getValue:&acs2]);
    id val2 = [NSValue valueWithBytes:&acs2 objCType:@encode(ArbitrarilyComplexStruct)];
    ASSERT_OBJCEQ(val, val2);
}

TEST(NSValue, arbitraryStructCanBeSerializedAndDeserialized) {
    using namespace std::complex_literals;
    ArbitrarilyComplexStruct acs{ 3.14, 1.9i };

    id val = [NSValue valueWithBytes:&acs objCType:@encode(ArbitrarilyComplexStruct)];
    id data = [NSKeyedArchiver archivedDataWithRootObject:val];
    id val2 = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    ArbitrarilyComplexStruct acs2{};
    [val2 getValue:&acs2];
    ASSERT_EQ(acs.c, acs2.c);
}
