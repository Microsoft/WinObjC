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

#import <TestFramework.h>
#import <Foundation/Foundation.h>

template <typename T>
static void testGetValue(NSNumber* number, T expected) {
    const char* encodedType = [number objCType];

    ASSERT_EQ_MSG(1, strlen(encodedType), "FAILED: Unexpected NSNumber type");

#define TYPE_CASE(code, type)                                                               \
    case code: {                                                                            \
        type value = 0;                                                                     \
        [number getValue:&value];                                                           \
        EXPECT_EQ_MSG(expected, value, "FAILED: Unexpected value from NSNumber getValue:"); \
        break;                                                                              \
    }

    switch (encodedType[0]) {
        TYPE_CASE('c', char)
        TYPE_CASE('C', unsigned char)
        TYPE_CASE('s', short)
        TYPE_CASE('S', unsigned short)
        TYPE_CASE('i', int)
        TYPE_CASE('I', unsigned int)
        TYPE_CASE('l', long)
        TYPE_CASE('L', unsigned long)
        TYPE_CASE('q', long long)
        TYPE_CASE('Q', unsigned long long)
        TYPE_CASE('f', float)
        TYPE_CASE('d', double)

        default:
            EXPECT_TRUE_MSG(false, "FAILED: Unknown NSNumber type code");
    }
}

TEST(NSNumber, NumberWithShortGetStringValueUnSigned) {
    NSNumber* number = [NSNumber numberWithShort:25];
    ASSERT_TRUE_MSG(number != nil, "FAILED: number should not be nil!");
    ASSERT_OBJCEQ_MSG(@"25", [number stringValue], "FAILED: values do not match as expected.");
}

TEST(NSNumber, NumberWithShortGetStringValueSigned) {
    NSNumber* number = [NSNumber numberWithShort:-12];
    ASSERT_TRUE_MSG(number != nil, "FAILED: number should not be nil!");
    ASSERT_OBJCEQ_MSG(@"-12", [number stringValue], "FAILED: values do not match as expected.");
}

TEST(NSNumber, NumberWithUnsignedShort) {
    NSNumber* number = [NSNumber numberWithUnsignedShort:25];
    ASSERT_TRUE_MSG(number != nil, "FAILED: number should not be nil!");
    ASSERT_OBJCEQ_MSG(@"25", [number stringValue], "FAILED: values do not match as expected.");
}

TEST(NSNumber, GetValueUnSigned) {
    NSNumber* number = [NSNumber numberWithUnsignedShort:25];
    ASSERT_TRUE_MSG(number != nil, "FAILED: number should not be nil!");
    testGetValue(number, static_cast<unsigned short>(25));
}

TEST(NSNumber, GetValueSigned) {
    NSNumber* number = [NSNumber numberWithShort:-12];
    ASSERT_TRUE_MSG(number != nil, "FAILED: number should not be nil!");
    testGetValue(number, static_cast<short>(-12));
}

TEST(NSNumber, GetValueOther) {
    testGetValue([NSNumber numberWithChar:'y'], 'y');
    testGetValue([NSNumber numberWithInt:-235], -235);
    testGetValue([NSNumber numberWithUnsignedLongLong:257260223451], (unsigned long long)257260223451);
    testGetValue([NSNumber numberWithBool:YES], YES);
    testGetValue([NSNumber numberWithDouble:-2352.26269435], (double)-2352.26269435);
}

TEST(NSNumber, NumberWithCharGetStringValueSigned) {
    NSNumber* number = [NSNumber numberWithChar:-5];
    ASSERT_TRUE_MSG(number != nil, "FAILED: number should not be nil!");
    ASSERT_OBJCEQ_MSG(@"-5", [number stringValue], "FAILED: values do not match as expected.");
}

TEST(NSNumber, NumberWithCharGetStringValueUnsigned) {
    NSNumber* number = [NSNumber numberWithUnsignedChar:5];
    ASSERT_TRUE_MSG(number != nil, "FAILED: number should not be nil!");
    ASSERT_OBJCEQ_MSG(@"5", [number stringValue], "FAILED: values do not match as expected.");
}

TEST(NSNumber, EncodeDecode) {
    NSArray* numberArray = @[
        @5,
        @500,
        @-5,
        @-50.7,
        [NSNumber numberWithBool:YES],
        [NSNumber numberWithShort:55],
        [NSNumber numberWithUnsignedChar:'a'],
        [NSNumber numberWithUnsignedInt:37],
        [NSNumber numberWithDouble:544325.1414]
    ];

    for (NSNumber* number in numberArray) {
        ASSERT_OBJCEQ(number, [NSKeyedUnarchiver unarchiveObjectWithData:[NSKeyedArchiver archivedDataWithRootObject:number]]);
    }
}

TEST(NSNumber, IsEqual) {
    // Test expected equality, even across data types
    ASSERT_OBJCEQ([NSNumber numberWithInt:50], [NSNumber numberWithInt:50]);
    ASSERT_OBJCEQ([NSNumber numberWithShort:50], [NSNumber numberWithInt:50]);
    ASSERT_OBJCEQ([NSNumber numberWithFloat:50.0], [NSNumber numberWithInt:50]);
    ASSERT_OBJCEQ([NSNumber numberWithUnsignedInt:50], [NSNumber numberWithInt:50]);
    ASSERT_OBJCEQ([NSNumber numberWithLongLong:50], [NSNumber numberWithInt:50]);

    // Test expected inequality, even across data types
    ASSERT_OBJCNE([NSNumber numberWithInt:51], [NSNumber numberWithInt:50]);
    ASSERT_OBJCNE([NSNumber numberWithShort:51], [NSNumber numberWithInt:50]);
    ASSERT_OBJCNE([NSNumber numberWithFloat:50.1], [NSNumber numberWithInt:50]);
    ASSERT_OBJCNE([NSNumber numberWithUnsignedInt:51], [NSNumber numberWithInt:50]);
    ASSERT_OBJCNE([NSNumber numberWithLongLong:51], [NSNumber numberWithInt:50]);
}

TEST(NSNumber, Compare) {
    // Test floating point comparisons
    ASSERT_EQ(NSOrderedAscending, [[NSNumber numberWithFloat:55.36] compare:[NSNumber numberWithDouble:37125.2]]);
    ASSERT_EQ(NSOrderedDescending, [[NSNumber numberWithFloat:55.36] compare:[NSNumber numberWithShort:26]]);
    ASSERT_EQ(NSOrderedSame, [[NSNumber numberWithDouble:55.0] compare:[NSNumber numberWithLong:55]]);
    ASSERT_EQ(NSOrderedSame, [[NSNumber numberWithDouble:55.0] compare:[NSNumber numberWithUnsignedLong:55]]);

    // Test negative number comparisons, both with signed and unsigned numbers
    ASSERT_EQ(NSOrderedAscending, [@-1 compare:@0]);
    ASSERT_EQ(NSOrderedAscending, [[NSNumber numberWithLongLong:-1515135] compare:[NSNumber numberWithInt:-252]]);
    ASSERT_EQ(NSOrderedAscending, [[NSNumber numberWithLongLong:-1515135] compare:[NSNumber numberWithUnsignedInt:0]]);
    ASSERT_EQ(NSOrderedDescending, [[NSNumber numberWithLongLong:-1515135] compare:[NSNumber numberWithLongLong:-2352356262]]);
    ASSERT_EQ(NSOrderedDescending, [[NSNumber numberWithLongLong:-15145] compare:[NSNumber numberWithDouble:-23425.24]]);
    ASSERT_EQ(NSOrderedAscending, [[NSNumber numberWithLongLong:-15145] compare:[NSNumber numberWithFloat:235.25]]);
    ASSERT_EQ(NSOrderedAscending, [[NSNumber numberWithLongLong:-15145] compare:[NSNumber numberWithBool:YES]]);
    ASSERT_EQ(NSOrderedAscending, [[NSNumber numberWithLongLong:-15145] compare:[NSNumber numberWithUnsignedLongLong:2352]]);
    ASSERT_EQ(NSOrderedAscending, [[NSNumber numberWithLongLong:-15145] compare:[NSNumber numberWithChar:'a']]);
    ASSERT_EQ(NSOrderedAscending, [[NSNumber numberWithLongLong:-15145] compare:[NSNumber numberWithUnsignedChar:'a']]);

    // Test comparison with negative floating point numbers
    ASSERT_EQ(NSOrderedAscending, [[NSNumber numberWithInt:-7] compare:[NSNumber numberWithFloat:-5.0]]);
    ASSERT_EQ(NSOrderedAscending, [[NSNumber numberWithInt:-7] compare:[NSNumber numberWithFloat:-5.1]]);
    ASSERT_EQ(NSOrderedAscending, [[NSNumber numberWithInt:-7] compare:[NSNumber numberWithFloat:-6.9]]);
    ASSERT_EQ(NSOrderedSame, [[NSNumber numberWithInt:-7] compare:[NSNumber numberWithFloat:-7.0]]);
    ASSERT_EQ(NSOrderedDescending, [[NSNumber numberWithInt:-7] compare:[NSNumber numberWithFloat:-7.1]]);
    ASSERT_EQ(NSOrderedDescending, [[NSNumber numberWithInt:-7] compare:[NSNumber numberWithFloat:-8.0]]);
    ASSERT_EQ(NSOrderedDescending, [[NSNumber numberWithInt:-7] compare:[NSNumber numberWithFloat:-8.1]]);

    // Test comparison with large numbers
    ASSERT_EQ(NSOrderedAscending, [[NSNumber numberWithInt:-7] compare:[NSNumber numberWithDouble:pow(2, 66)]]);
    ASSERT_EQ(NSOrderedDescending, [[NSNumber numberWithInt:-7] compare:[NSNumber numberWithDouble:-pow(2, 66)]]);
}

@interface TestNSNumberLongLongSubclass : NSNumber
@end

@implementation TestNSNumberLongLongSubclass {
    long long _value;
}

- (instancetype)initWithLongLong:(long long)val {
    if (self = [super init]) {
        _value = val;
    }
    return self;
}

- (long long)longLongValue {
    return _value;
}

- (const char*)objCType {
    return @encode(long long);
}

@end

@interface TestNSNumberFloatSubclass : NSNumber
@end

@implementation TestNSNumberFloatSubclass {
    float _value;
}

- (instancetype)initWithFloat:(float)val {
    if (self = [super init]) {
        _value = val;
    }
    return self;
}

- (float)floatValue {
    return _value;
}

- (const char*)objCType {
    return @encode(float);
}

@end

TEST(NSNumber, CFNumberGetValue_Integral) {
    long long expected = LLONG_MAX;
    NSNumber* numBaseClass = [NSNumber numberWithLongLong:expected];
    NSNumber* numDerived = [TestNSNumberLongLongSubclass numberWithLongLong:expected];

    long long result;

    ASSERT_TRUE(CFNumberGetValue(static_cast<CFNumberRef>(numBaseClass), kCFNumberLongLongType, &result));
    ASSERT_EQ(expected, result);

    ASSERT_TRUE(CFNumberGetValue(static_cast<CFNumberRef>(numDerived), kCFNumberLongLongType, &result));
    ASSERT_EQ(expected, result);
}

// Contrary to the documentation, which states that this function ought return false on out of range,
// neither OSX nor iOS actually does this.
// Since this seems like useful functionality, this test (and the false return) will remain on Windows.
OSX_DISABLED_TEST(NSNumber, CFNumberGetValue_OutOfRange) {
    long long expected = LLONG_MAX;
    NSNumber* numBaseClass = [NSNumber numberWithLongLong:expected];
    NSNumber* numDerived = [TestNSNumberLongLongSubclass numberWithLongLong:expected];

    // Too small an output type should return false
    long tooSmallResult;
    ASSERT_FALSE(CFNumberGetValue(static_cast<CFNumberRef>(numBaseClass), kCFNumberLongType, &tooSmallResult));
    ASSERT_FALSE(CFNumberGetValue(static_cast<CFNumberRef>(numDerived), kCFNumberLongType, &tooSmallResult));
}

TEST(NSNumber, CFNumberGetValue_Lossy) {
    float expected = 0.58f;
    NSNumber* num = [NSNumber numberWithFloat:expected];

    float result;
    ASSERT_TRUE(CFNumberGetValue(static_cast<CFNumberRef>(num), kCFNumberFloatType, &result));
    ASSERT_EQ(expected, result);

    // Loss of floating-point precision should return false
    long integralResult;
    ASSERT_FALSE(CFNumberGetValue(static_cast<CFNumberRef>(num), kCFNumberLongType, &integralResult));
}

// OSX seems to have a bug where this functionality doesn't work for subclasses
OSX_DISABLED_TEST(NSNumber, CFNumberGetValue_LossyDerived) {
    float expected = 0.58f;
    NSNumber* num = [TestNSNumberFloatSubclass numberWithFloat:expected];

    float result;
    ASSERT_TRUE(CFNumberGetValue(static_cast<CFNumberRef>(num), kCFNumberFloatType, &result));
    ASSERT_EQ(expected, result);

    // Loss of floating-point precision should return false
    long integralResult;
    ASSERT_FALSE(CFNumberGetValue(static_cast<CFNumberRef>(num), kCFNumberLongType, &integralResult));
}