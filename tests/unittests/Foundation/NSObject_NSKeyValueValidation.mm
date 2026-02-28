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

#include <Foundation/Foundation.h>
#include <TestFramework.h>

struct smolStruct {
    char a;
    char b;
};

struct yugeStruct {
    smolStruct a[88];
    void* b;
};

@interface ValidationObj : NSObject
+ (instancetype)test;

@property (readwrite, assign) NSObject* obj;
- (BOOL)validateObj:(NSObject**)value error:(NSError**)outError;
- (BOOL)validateValid1:(inout NSObject* _Nullable*)value error:(out NSError**)outError;
- (BOOL)validateValid2:(id*)value error:(NSError**)outError;
- (BOOL)validateValid3:(id**)value error:(NSError**)outError;
- (BOOL)validateValid4:(BOOL*)value error:(NSError**)outError;
- (BOOL)validateValid5:(id)value error:(NSError**)outError;
- (BOOL)validateValid6:(BOOL)value error:(NSError**)outError;
- (BOOL)validateValid7:(smolStruct*)value error:(NSError**)outError;
- (BOOL)validateValid8:(yugeStruct*)value error:(NSError**)outError;
- (BOOL)validateValid9:(id*)value error:(NSObject**)outError;
- (BOOL)validateValid10:(id*)value error:(NSError*)outError;
- (BOOL)validateValid11:(id*)value error:(NSError***)outError;
- (BOOL)validateValid12:(smolStruct)value error:(NSError**)outError;
- (BOOL)validateValid13:(yugeStruct)value error:(NSError**)outError;
- (BOOL)validateValid14:(id*)value error:(smolStruct)outError;
- (BOOL)validateValid15:(id*)value error:(smolStruct*)outError;
- (BOOL)validateValid16:(id*)value error:(yugeStruct)outError;
- (BOOL)validateValid17:(id*)value error:(yugeStruct*)outError;

- (BOOL)validateInvalid1:(id*)value errr:(NSError**)outError;
- (BOOL)validateInvalid2:(id*)value error:(NSError**)outError someOtherThing:(id)it;
- (void)validateInvalid3:(id*)value error:(NSError**)outError;
@end

@implementation ValidationObj
+ (instancetype)test {
    return [[[self alloc] init] autorelease];
}

- (BOOL)validateObj:(NSObject**)value error:(NSError**)outError {
    if (value) {
        *value = [NSData data];
        return YES;
    }

    return NO;
}

#pragma region valid

- (BOOL)validateValid1:(inout NSObject* _Nullable*)value error:(out NSError**)outError {
    return NO;
}

- (BOOL)validateValid2:(id*)value error:(NSError**)outError {
    return NO;
}

- (BOOL)validateValid3:(id**)value error:(NSError**)outError {
    return NO;
}

- (BOOL)validateValid4:(BOOL*)value error:(NSError**)outError {
    return NO;
}

- (BOOL)validateValid5:(id)value error:(NSError**)outError {
    return NO;
}

- (BOOL)validateValid6:(BOOL)value error:(NSError**)outError {
    return NO;
}

- (BOOL)validateValid7:(smolStruct*)value error:(NSError**)outError {
    return NO;
}

- (BOOL)validateValid8:(yugeStruct*)value error:(NSError**)outError {
    return NO;
}

- (BOOL)validateValid9:(id*)value error:(NSObject**)outError {
    return NO;
}

- (BOOL)validateValid10:(id*)value error:(NSError*)outError {
    return NO;
}

- (BOOL)validateValid11:(id*)value error:(NSError***)outError {
    return NO;
}

- (BOOL)validateValid12:(smolStruct)value error:(NSError**)outError {
    return NO;
}

- (BOOL)validateValid13:(yugeStruct)value error:(NSError**)outError {
    return NO;
}

- (BOOL)validateValid14:(id*)value error:(smolStruct)outError {
    return NO;
}

- (BOOL)validateValid15:(id*)value error:(smolStruct*)outError {
    return NO;
}

- (BOOL)validateValid16:(id*)value error:(yugeStruct)outError {
    return NO;
}

- (BOOL)validateValid17:(id*)value error:(yugeStruct*)outError {
    return NO;
}

#pragma endregion valid
#pragma region invalid

- (BOOL)validateInvalid1:(id*)value errr:(NSError**)outError {
    return NO;
}

- (BOOL)validateInvalid2:(id*)value error:(NSError**)outError someOtherThing:(id)it {
    return NO;
}

- (void)validateInvalid3:(id*)value error:(NSError**)outError {
}

#pragma endregion invalid

@end

TEST(NSObject, ValidateValueForKey) {
    auto test = [ValidationObj test];
    NSData* data = nil;
    NSError* error = nil;

    EXPECT_EQ(NO, [test validateValue:nullptr forKey:@"obj" error:&error]);
    EXPECT_EQ(YES, [test validateValue:&data forKey:@"obj" error:&error]);
    EXPECT_OBJCEQ([NSData data], data);
}

TEST(NSObject, ValidateValueForKeyShouldReturnNOForInvalidSelectors) {
    auto test = [ValidationObj test];
    NSData* data = [NSData data];
    NSError* error = nil;
    EXPECT_EQ(NO, [test validateValue:&data forKey:@"valid1" error:&error]);
    EXPECT_EQ(NO, [test validateValue:&data forKey:@"valid2" error:&error]);
    EXPECT_EQ(NO, [test validateValue:&data forKey:@"valid3" error:&error]);
    EXPECT_EQ(NO, [test validateValue:&data forKey:@"valid4" error:&error]);
    EXPECT_EQ(NO, [test validateValue:&data forKey:@"valid5" error:&error]);
    EXPECT_EQ(NO, [test validateValue:&data forKey:@"valid6" error:&error]);
    EXPECT_EQ(NO, [test validateValue:&data forKey:@"valid7" error:&error]);
    EXPECT_EQ(NO, [test validateValue:&data forKey:@"valid8" error:&error]);
    EXPECT_EQ(NO, [test validateValue:&data forKey:@"valid9" error:&error]);
    EXPECT_EQ(NO, [test validateValue:&data forKey:@"valid10" error:&error]);
    EXPECT_EQ(NO, [test validateValue:&data forKey:@"valid11" error:&error]);
    EXPECT_EQ(NO, [test validateValue:&data forKey:@"valid12" error:&error]);
    EXPECT_EQ(NO, [test validateValue:&data forKey:@"valid13" error:&error]);
    EXPECT_EQ(NO, [test validateValue:&data forKey:@"valid14" error:&error]);
    EXPECT_EQ(NO, [test validateValue:&data forKey:@"valid15" error:&error]);
    EXPECT_EQ(NO, [test validateValue:&data forKey:@"valid16" error:&error]);
    EXPECT_EQ(NO, [test validateValue:&data forKey:@"valid17" error:&error]);

    EXPECT_EQ(YES, [test validateValue:&data forKey:@"invalid1" error:&error]);
    EXPECT_EQ(YES, [test validateValue:&data forKey:@"invalid2" error:&error]);
    EXPECT_EQ(YES, [test validateValue:&data forKey:@"invalid3" error:&error]);

    EXPECT_EQ(YES, [test validateValue:&data forKey:@"nonexistent" error:&error]);
}

@interface ValidationHolder : NSObject {
    NSObject* ivar;
}
+ (instancetype)holder;
@property (readwrite, retain) ValidationObj* obj;
@property (readwrite, retain) Class cla;
@property (readwrite) int intVal;
@end

@implementation ValidationHolder

+ (instancetype)holder {
    return [[[self alloc] init] autorelease];
}

- (instancetype)init {
    if (self = [super init]) {
        _obj = [[ValidationObj alloc] init];
    }

    return self;
}

- (void)dealloc {
    [_obj release];
    [super dealloc];
}
@end

TEST(NSObject, ValidateValueForKeyPath) {
    ValidationHolder* test = [ValidationHolder holder];
    NSData* data = nil;
    NSError* error = nil;

    EXPECT_EQ(NO, [test validateValue:nullptr forKeyPath:@"obj.obj" error:&error]);
    EXPECT_EQ(YES, [test validateValue:&data forKeyPath:@"obj.obj" error:&error]);
    EXPECT_OBJCEQ([NSData data], data);
}

TEST(NSObject, ValidateValueForKeyPathShouldProperlyFollowKeyPath) {
    ValidationHolder* test = [ValidationHolder holder];
    NSData* data = [NSData data];
    NSError* error = nil;
    EXPECT_EQ(NO, [test validateValue:&data forKeyPath:@"obj.valid1" error:&error]);
    EXPECT_EQ(NO, [test.obj validateValue:&data forKeyPath:@"valid1" error:&error]);

    EXPECT_ANY_THROW([test validateValue:&data forKeyPath:@"nonexistent.valid1" error:&error]);

    EXPECT_EQ(YES, [test validateValue:&data forKeyPath:@"obj.invalid1" error:&error]);
    EXPECT_EQ(YES, [test validateValue:&data forKeyPath:@"obj.nonexistent" error:&error]);
}

TEST(NSObject, SetNilValueForKey) {
    ValidationHolder* test = [ValidationHolder holder];
    EXPECT_ANY_THROW([test setNilValueForKey:@"obj"]);
    EXPECT_ANY_THROW([test setNilValueForKey:@"intVal"]);
    EXPECT_ANY_THROW([test setNilValueForKey:@"ivar"]);
    EXPECT_ANY_THROW([test setNilValueForKey:@"cla"]);
    EXPECT_ANY_THROW([test setValue:nil forKey:@"intVal"]);

    EXPECT_NO_THROW([test setValue:nil forKey:@"obj"]);
    EXPECT_NO_THROW([test setValue:nil forKey:@"ivar"]);
    EXPECT_NO_THROW([test setValue:nil forKey:@"cla"]);
}
