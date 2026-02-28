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

// Windows-only:
//      NSExpressionConstantValue
//      NSExpressionVariable
//      NSExpressionFunction

#import <TestFramework.h>
#import <Foundation/Foundation.h>

#import "ExpressionHelpers.h"

void validateNSExpressionConstantValue(NSExpression* obj) {
    NSExpressionConstantValue* constVal = (NSExpressionConstantValue*)obj;
    ASSERT_TRUE_MSG([constVal value] != nil, "FAILED: value should be non-null!");
}

void validateNSExpressionVariable(NSExpression* obj) {
    NSExpressionVariable* constVal = (NSExpressionVariable*)obj;
    ASSERT_TRUE_MSG([constVal name] != nil, "FAILED: name should be non-null!");
}

void validateNSExpressionFunction(NSExpression* obj, NSArray* args, NSExpression* target) {
    NSExpressionFunction* functionExp = (NSExpressionFunction*)obj;

    ASSERT_TRUE_MSG([functionExp selector] != nullptr, "FAILED: selector should be non-null!");
    ASSERT_OBJCEQ_MSG([functionExp args], args, "FAILED: args is not valid.");
    ASSERT_OBJCEQ_MSG([functionExp target], target, "FAILED: target is not valid.");
}

@interface TestCoin : NSObject
@property (copy) NSNumber* coinValue;
- (instancetype)initWithValue:(NSInteger)value;
@end

@implementation TestCoin
- (instancetype)initWithValue:(NSInteger)value {
    if (self = [super init]) {
        _coinValue = [[NSNumber numberWithInt:value] retain];
    }
    return self;
}

- (NSNumber*)coinValue {
    return _coinValue;
}

- (id)copyWithZone:(NSZone*)zone {
    return [self retain];
}

- (void)dealloc {
    [_coinValue release];
    [super dealloc];
}
@end

TEST(NSExpression, InstanceNSExpressionConstantValue) {
    NSExpression* constObj = [NSExpression expressionForConstantValue:[NSNumber numberWithInt:5]];
    ASSERT_TRUE_MSG(constObj != nil, "FAILED: constObj should be non-null!");
    validateNSExpressionConstantValue(constObj);
}

TEST(NSExpression, InstanceNSExpressionConstantValueObject) {
    TestCoin* coin = [[TestCoin alloc] initWithValue:5];
    ASSERT_TRUE_MSG(coin != nil, "FAILED: coin should be non-null!");

    NSExpression* constCoinObj = [NSExpression expressionForConstantValue:coin];
    ASSERT_TRUE_MSG(constCoinObj != nil, "FAILED: constCoinObj should be non-null!");
    validateNSExpressionConstantValue(constCoinObj);
    [coin release];
}

TEST(NSExpression, InstanceNSExpressionFunctionTarget) {
    TestCoin* coin = [[TestCoin alloc] initWithValue:5];
    ASSERT_TRUE_MSG(coin != nil, "FAILED: coin should be non-null!");

    NSExpression* constCoinObj = [NSExpression expressionForConstantValue:coin];
    ASSERT_TRUE_MSG(constCoinObj != nil, "FAILED: constCoinObj should be non-null!");
    validateNSExpressionConstantValue(constCoinObj);

    NSExpression* expression = [NSExpression expressionForFunction:constCoinObj selectorName:@"coinValue" arguments:nil];
    ASSERT_TRUE_MSG(expression != nil, "FAILED: expression should be non-null!");
    validateNSExpressionFunction(expression, nil, constCoinObj);
    [coin release];
}

TEST(NSExpression, NSExpressionFunctionTarget) {
    TestCoin* coin = [[TestCoin alloc] initWithValue:5];
    ASSERT_TRUE_MSG(coin != nil, "FAILED: coin should be non-null!");

    NSExpression* constCoinObj = [NSExpression expressionForConstantValue:coin];
    ASSERT_TRUE_MSG(constCoinObj != nil, "FAILED: constCoinObj should be non-null!");
    validateNSExpressionConstantValue(constCoinObj);

    NSExpression* expression = [NSExpression expressionForFunction:constCoinObj selectorName:@"coinValue" arguments:nil];
    ASSERT_TRUE_MSG(expression != nil, "FAILED: expression should be non-null!");

    id value = [expression expressionValueWithObject:nil context:nil];
    ASSERT_TRUE_MSG(value != nil, "FAILED: value should be non-null!");
    ASSERT_TRUE_MSG([value isKindOfClass:[NSNumber class]], "FAILED: value is not NSNumber type.");

    ASSERT_EQ_MSG([value intValue], 5, "FAILED: result is not valid.");
    [coin release];
}

TEST(NSExpression, NSExpressionVariable) {
    NSExpression* expression = [NSExpression expressionForVariable:@"fooBar"];
    ASSERT_TRUE_MSG(expression != nil, "FAILED: expression should be non-null!");
    validateNSExpressionVariable(expression);
}

TEST(NSExpression, NSExpressionKeyPath) {
    NSExpressionKeyPath* expression = (NSExpressionKeyPath*)[NSExpression expressionForKeyPath:@"speed"];
    ASSERT_TRUE_MSG(expression != nil, "FAILED: expression should be non-null!");
    NSString* s = [expression keyPath];
    // ASSERT_TRUE_MSG(, "FAILED: key should be non-null!");
}

TEST(NSExpression, NSExpressionFunction_Sum) {
    NSArray* numbers = @[ @1, @2, @3, @4, @5 ];
    NSExpression* values = [NSExpression expressionForConstantValue:numbers];
    ASSERT_TRUE_MSG(values != nil, "FAILED: values should be non-null!");
    validateNSExpressionConstantValue(values);

    NSExpression* expression = [NSExpression expressionForFunction:@"sum:" arguments:@[ values ]];
    ASSERT_TRUE_MSG(expression != nil, "FAILED: expression should be non-null!");

    id value = [expression expressionValueWithObject:nil context:nil];
    ASSERT_TRUE_MSG(value != nil, "FAILED: value should be non-null!");

    ASSERT_TRUE_MSG([value isKindOfClass:[NSNumber class]], "FAILED: value is not NSNumber type.");
    ASSERT_OBJCEQ_MSG(value, [NSNumber numberWithFloat:15], "FAILED: result is not valid.");
}
