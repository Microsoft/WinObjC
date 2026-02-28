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

// Windows-only:
//      WinObjC_SetMissingSelectorFatal

#import <TestFramework.h>
#import <Foundation/Foundation.h>
#import <objc/encoding.h>

@interface NSObject (Nonexistent)
+ (void)nonexistentSelector;
+ (id)tryToReturnANonexistentThing;
@end

TEST(Sanity, NonFatalSelectors) {
    WinObjC_SetMissingSelectorFatal(NO);
    EXPECT_NO_THROW([NSObject nonexistentSelector]);
    EXPECT_OBJCEQ(nil, [NSObject tryToReturnANonexistentThing]);
    WinObjC_SetMissingSelectorFatal(YES);
    EXPECT_ANY_THROW([NSObject nonexistentSelector]);
}

class TypeSizeAlignmentTest : public ::testing::TestWithParam<const char*> {};

TEST_P(TypeSizeAlignmentTest, NSGetSizeAndAlignment) {
    NSUInteger size = 0;
    NSUInteger align = 0;
    const char* type = GetParam();
    ASSERT_NO_THROW(NSGetSizeAndAlignment(type, &size, &align));
    EXPECT_EQ(objc_sizeof_type(type), size);
    EXPECT_EQ(objc_alignof_type(type), align);

    NSUInteger singleSize = 0;
    ASSERT_NO_THROW(NSGetSizeAndAlignment(type, &singleSize, nullptr));
    EXPECT_EQ(size, singleSize);

    NSUInteger singleAlign = 0;
    ASSERT_NO_THROW(NSGetSizeAndAlignment(type, &singleAlign, nullptr));
    EXPECT_EQ(size, singleAlign);
}

struct struct1 {
    char a;
};

struct struct2 {
    char a, b;
};

struct struct3 {
    char a, b, c;
};

union union1 {
    char ch;
    void* vp;
};

const char* sc_sizeAlignTypes[24] = { @encode(char),
                                      @encode(int),
                                      @encode(short int),
                                      @encode(long int),
                                      @encode(long long int),
                                      @encode(unsigned char),
                                      @encode(unsigned int),
                                      @encode(unsigned short int),
                                      @encode(unsigned long int),
                                      @encode(unsigned long long int),
                                      @encode(float),
                                      @encode(double),
                                      @encode(bool),
                                      @encode(void),
                                      @encode(char*),
                                      @encode(NSObject*),
                                      @encode(int[5]),
                                      @encode(struct1),
                                      @encode(struct2),
                                      @encode(struct3),
                                      @encode(union1),
                                      @encode(struct1*),
                                      @encode(decltype(NSGetSizeAndAlignment)),
                                      @encode(void**) };
INSTANTIATE_TEST_CASE_P(Foundation, TypeSizeAlignmentTest, ::testing::ValuesIn(sc_sizeAlignTypes));
