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

#include <TestFramework.h>
#import <Foundation/Foundation.h>

@interface TestAnimal : NSObject <NSCopying>
@property (assign) NSNumber* age;
@property (assign) NSNumber* speed;
@property (retain) NSString* name;
- (instancetype)initWithName:(NSString*)name age:(NSInteger)age speed:(NSInteger)speed;
@end

@implementation TestAnimal
- (instancetype)initWithName:(NSString*)name age:(NSInteger)age speed:(NSInteger)speed {
    if (self = [super init]) {
        _name = [name copy];
        _age = [NSNumber numberWithInt:age];
        _speed = [NSNumber numberWithInt:speed];
    }
    return self;
}

- (id)copyWithZone:(NSZone*)zone {
    return [self retain];
}

- (void)dealloc {
    [_name release];
    [super dealloc];
}
@end

// Note: All of these test NSExpression, NSPredicate, NSComparisonPredicate and NSCompoundPredicate.
TEST(NSComparisonPredicate, Complex_Expression) {
    // Filter using the following expression/Predicate:
    // " (NOT (AGE <= 100) OR ($NAME CONTAINS Alpha))  AND $SPEED BETWEEN { 0, 120 }"

    NSMutableArray* animals = [[[NSMutableArray alloc] init] autorelease];

    // Test animals to be filtered
    TestAnimal* animal1 = [[[TestAnimal alloc] initWithName:@"Alpha-1" age:20 speed:115] autorelease];
    [animals addObject:animal1];

    TestAnimal* animal2 = [[[TestAnimal alloc] initWithName:@"Beta-1" age:101 speed:120] autorelease];
    [animals addObject:animal2];

    TestAnimal* animal3 = [[[TestAnimal alloc] initWithName:@"Beta-2" age:120 speed:121] autorelease];
    [animals addObject:animal3];

    TestAnimal* animal4 = [[[TestAnimal alloc] initWithName:@"Alpha-4" age:100 speed:115] autorelease];
    [animals addObject:animal4];

    TestAnimal* animal5 = [[[TestAnimal alloc] initWithName:@"Beta-5" age:101 speed:0] autorelease];
    [animals addObject:animal5];

    // 1. NOT ($SPEED <= 100)
    NSExpression* ageExpLeft = [NSExpression expressionForKeyPath:@"age"];
    ASSERT_TRUE_MSG(ageExpLeft != nil, "FAILED: ageExpLeft should be non-null!");

    NSExpression* ageExpRight = [NSExpression expressionForConstantValue:@(100)];
    ASSERT_TRUE_MSG(ageExpRight != nil, "FAILED: ageExpRight should be non-null!");

    NSPredicate* agecomparisonPredicate = [NSComparisonPredicate predicateWithLeftExpression:ageExpLeft
                                                                             rightExpression:ageExpRight
                                                                                    modifier:NSDirectPredicateModifier
                                                                                        type:NSLessThanOrEqualToPredicateOperatorType
                                                                                     options:0];

    ASSERT_TRUE_MSG(agecomparisonPredicate != nil, "FAILED: agecomparisonPredicate should be non-null!");

    NSPredicate* NotAgecomparisonPredicate = [NSCompoundPredicate notPredicateWithSubpredicate:agecomparisonPredicate];

    //($NAME CONTAINS Alpha)
    NSExpression* ContainsExpLeft = [NSExpression expressionForKeyPath:@"name"];
    ASSERT_TRUE_MSG(ContainsExpLeft != nil, "FAILED: ContainsExpLeft should be non-null!");

    NSExpression* ContainsExpRight = [NSExpression expressionForConstantValue:@"Alpha"];
    ASSERT_TRUE_MSG(ContainsExpRight != nil, "FAILED: ContainsExpRight should be non-null!");

    NSPredicate* ContainscomparisonPredicate = [NSComparisonPredicate predicateWithLeftExpression:ContainsExpLeft
                                                                                  rightExpression:ContainsExpRight
                                                                                         modifier:NSDirectPredicateModifier
                                                                                             type:NSContainsPredicateOperatorType
                                                                                          options:NSCaseInsensitivePredicateOption];

    //(NOT ($AGE <= 100) OR ($NAME CONTAINS Mr))
    NSPredicate* NotAgeORcomparisonPredicate =
        [NSCompoundPredicate orPredicateWithSubpredicates:@[ NotAgecomparisonPredicate, ContainscomparisonPredicate ]];

    // $SPEED BETWEEN { 0, 120 }
    NSArray* validSpeedRange = @[ @(0), @(120) ];
    ASSERT_TRUE_MSG(validSpeedRange != nil, "FAILED: validSpeedRange should be non-null!");

    NSExpression* leftExpSpeedLimit = [NSExpression expressionForKeyPath:@"speed"];
    ASSERT_TRUE_MSG(leftExpSpeedLimit != nil, "FAILED: leftExpSpeedLimit should be non-null!");

    NSExpression* rightExpSpeedLimit = [NSExpression expressionForConstantValue:validSpeedRange];
    ASSERT_TRUE_MSG(rightExpSpeedLimit != nil, "FAILED: rightExpSpeedLimit should be non-null!");

    NSPredicate* ageBetweencomparisonPredicate = [NSComparisonPredicate predicateWithLeftExpression:leftExpSpeedLimit
                                                                                    rightExpression:rightExpSpeedLimit
                                                                                           modifier:NSDirectPredicateModifier
                                                                                               type:NSBetweenPredicateOperatorType
                                                                                            options:0];

    ASSERT_TRUE_MSG(ageBetweencomparisonPredicate != nil, "FAILED: ageBetweencomparisonPredicate should be non-null!");

    // Final: " (NOT (AGE <= 100) OR ($NAME CONTAINS Alpha))  AND $SPEED BETWEEN { 0, 120 }"
    NSPredicate* finalPredicate =
        [NSCompoundPredicate andPredicateWithSubpredicates:@[ NotAgeORcomparisonPredicate, ageBetweencomparisonPredicate ]];
    ASSERT_TRUE_MSG(finalPredicate != nil, "FAILED: compoundPredicate should be non-null!");

    NSArray* validTestAnimals = [animals filteredArrayUsingPredicate:finalPredicate];
    ASSERT_TRUE_MSG(validTestAnimals != nil, "FAILED: validTestAnimals should be non-null!");

    ASSERT_EQ_MSG(4,
                  [validTestAnimals count],
                  "Failed to filter array using: '(NOT (AGE <= 100) OR ($NAME CONTAINS Alpha))  AND $SPEED BETWEEN { 0, 120 }' ");

    ASSERT_EQ_MSG(NO,
                  [validTestAnimals containsObject:animal3],
                  "Failed to filter array using: '(NOT (AGE <= 100) OR ($NAME CONTAINS Alpha))  AND $SPEED BETWEEN { 0, 120 }' ");
}

// The is an issue on OSX, where the selector [NSConstantValueExpression compare:] is an unrecognized selector.
// This seems like it's hitting a bug with the internal implementation.
OSX_DISABLED_TEST(NSComparisonPredicate, NSAnyPredicateModifier) {
    // "ANY $AGE <= $VAL""

    NSMutableArray* expressions = [[[NSMutableArray alloc] init] autorelease];

    for (int i = 11; i < 20; i++) {
        NSExpression* exp = [NSExpression expressionForConstantValue:@(i)];
        ASSERT_TRUE_MSG(exp != nil, "FAILED: exp should be non-null!");
        [expressions addObject:exp];
    }

    NSExpression* exp = [NSExpression expressionForConstantValue:@(9)];
    ASSERT_TRUE_MSG(exp != nil, "FAILED: exp should be non-null!");
    [expressions addObject:exp];

    NSExpression* leftExp = [NSExpression expressionForConstantValue:expressions];
    ASSERT_TRUE_MSG(leftExp != nil, "FAILED: leftExp should be non-null!");

    NSExpression* rightExp = [NSExpression expressionForConstantValue:@(10)];
    ASSERT_TRUE_MSG(rightExp != nil, "FAILED: rightExp should be non-null!");

    NSPredicate* predicate = [NSComparisonPredicate predicateWithLeftExpression:leftExp
                                                                rightExpression:rightExp
                                                                       modifier:NSAnyPredicateModifier
                                                                           type:NSLessThanOrEqualToPredicateOperatorType
                                                                        options:0];
    ASSERT_TRUE_MSG(predicate != nil, "FAILED: predicate should be non-null!");

    // validate the expression.
    ASSERT_TRUE_MSG([predicate evaluateWithObject:nil substitutionVariables:nil], "FAILED: predicate failed.");
}

// The is an issue on OSX, where the selector [NSConstantValueExpression compare:] is an unrecognized selector.
// This seems like it's hitting a bug with the internal implementation.
OSX_DISABLED_TEST(NSComparisonPredicate, NSAllPredicateModifier) {
    // "ALL $AGE <= $VAL""

    NSMutableArray* expressions = [[[NSMutableArray alloc] init] autorelease];

    for (int i = 0; i < 11; i++) {
        NSExpression* exp = [NSExpression expressionForConstantValue:@(i)];
        ASSERT_TRUE_MSG(exp != nil, "FAILED: exp should be non-null!");
        [expressions addObject:exp];
    }

    NSExpression* leftExp = [NSExpression expressionForConstantValue:expressions];
    ASSERT_TRUE_MSG(leftExp != nil, "FAILED: leftExp should be non-null!");

    NSExpression* rightExp = [NSExpression expressionForConstantValue:@(10)];
    ASSERT_TRUE_MSG(rightExp != nil, "FAILED: rightExp should be non-null!");

    NSPredicate* predicate = [NSComparisonPredicate predicateWithLeftExpression:leftExp
                                                                rightExpression:rightExp
                                                                       modifier:NSAllPredicateModifier
                                                                           type:NSLessThanOrEqualToPredicateOperatorType
                                                                        options:0];
    ASSERT_TRUE_MSG(predicate != nil, "FAILED: predicate should be non-null!");

    // validate the expression.
    ASSERT_TRUE_MSG([predicate evaluateWithObject:nil substitutionVariables:nil], "FAILED: predicate failed.");
}

// The is an issue on OSX, where the selector [NSConstantValueExpression compare:] is an unrecognized selector.
// This seems like it's hitting a bug with the internal implementation.
OSX_DISABLED_TEST(NSComparisonPredicate, NSAllPredicateModifier2) {
    // "ALL $AGE <= $VAL""

    NSMutableArray* expressions = [[[NSMutableArray alloc] init] autorelease];

    for (int i = 0; i < 11; i++) {
        NSExpression* exp = [NSExpression expressionForConstantValue:@(i)];
        ASSERT_TRUE_MSG(exp != nil, "FAILED: exp should be non-null!");
        [expressions addObject:exp];
    }

    NSExpression* exp = [NSExpression expressionForConstantValue:@(11)];
    ASSERT_TRUE_MSG(exp != nil, "FAILED: exp should be non-null!");
    [expressions addObject:exp];

    NSExpression* leftExp = [NSExpression expressionForConstantValue:expressions];
    ASSERT_TRUE_MSG(leftExp != nil, "FAILED: leftExp should be non-null!");

    NSExpression* rightExp = [NSExpression expressionForConstantValue:@(10)];
    ASSERT_TRUE_MSG(rightExp != nil, "FAILED: rightExp should be non-null!");

    NSPredicate* predicate = [NSComparisonPredicate predicateWithLeftExpression:leftExp
                                                                rightExpression:rightExp
                                                                       modifier:NSAllPredicateModifier
                                                                           type:NSLessThanOrEqualToPredicateOperatorType
                                                                        options:0];
    ASSERT_TRUE_MSG(predicate != nil, "FAILED: predicate should be non-null!");

    // validate the expression.
    ASSERT_FALSE_MSG([predicate evaluateWithObject:nil substitutionVariables:nil], "FAILED: predicate failed.");
}

TEST(NSComparisonPredicate, NSLessThanPredicateOperatorType) {
    // The bison out for expressions such as [NSPredicate predicateWithFormat:@" 9 < 10"],
    //[NSPredicate predicateWithFormat:@"firstName < 10"], etc.

    NSExpression* largerExpression = [NSExpression expressionForConstantValue:[NSNumber numberWithInt:10]];
    ASSERT_TRUE_MSG(largerExpression != nil, "FAILED: largerExpression should be non-null!");

    NSExpression* lesserExpression = [NSExpression expressionForConstantValue:[NSNumber numberWithInt:9]];
    ASSERT_TRUE_MSG(lesserExpression != nil, "FAILED: lesserExpression should be non-null!");

    NSPredicate* comparisonPredicate = [NSComparisonPredicate predicateWithLeftExpression:lesserExpression
                                                                          rightExpression:largerExpression
                                                                                 modifier:NSDirectPredicateModifier
                                                                                     type:NSLessThanPredicateOperatorType
                                                                                  options:0];

    ASSERT_TRUE_MSG(comparisonPredicate != nil, "FAILED: comparisonPredicate should be non-null!");

    // validate the expression.
    ASSERT_TRUE_MSG([comparisonPredicate evaluateWithObject:nil substitutionVariables:nil], "FAILED: Comparison failed.");
}

TEST(NSComparisonPredicate, NSLessThanOrEqualToPredicateOperatorType) {
    // The bison out for expressions such as [NSPredicate predicateWithFormat:@" 9 <= 10"],
    //[NSPredicate predicateWithFormat:@"age <= 10"], etc.

    NSExpression* exp1 = [NSExpression expressionForConstantValue:[NSNumber numberWithInt:10]];
    ASSERT_TRUE_MSG(exp1 != nil, "FAILED: exp1 should be non-null!");

    NSExpression* exp2 = [NSExpression expressionForConstantValue:[NSNumber numberWithInt:10]];
    ASSERT_TRUE_MSG(exp2 != nil, "FAILED: exp2 should be non-null!");

    NSPredicate* comparisonPredicate = [NSComparisonPredicate predicateWithLeftExpression:exp1
                                                                          rightExpression:exp2
                                                                                 modifier:NSDirectPredicateModifier
                                                                                     type:NSLessThanOrEqualToPredicateOperatorType
                                                                                  options:0];

    ASSERT_TRUE_MSG(comparisonPredicate != nil, "FAILED: comparisonPredicate should be non-null!");

    ASSERT_TRUE_MSG([comparisonPredicate evaluateWithObject:nil substitutionVariables:nil], "FAILED: Comparison failed.");
}

TEST(NSComparisonPredicate, NSGreaterThanPredicateOperatorType) {
    // The bison out for expressions such as [NSPredicate predicateWithFormat:@" a[someValue] > 10"],
    //[NSPredicate predicateWithFormat:@"age > 10"], etc.

    NSExpression* largerExpression = [NSExpression expressionForConstantValue:[NSNumber numberWithInt:10]];
    ASSERT_TRUE_MSG(largerExpression != nil, "FAILED: largerExpression should be non-null!");

    NSExpression* lesserExpression = [NSExpression expressionForConstantValue:[NSNumber numberWithInt:9]];
    ASSERT_TRUE_MSG(lesserExpression != nil, "FAILED: lesserExpression should be non-null!");

    NSPredicate* comparisonPredicate = [NSComparisonPredicate predicateWithLeftExpression:largerExpression
                                                                          rightExpression:lesserExpression
                                                                                 modifier:NSDirectPredicateModifier
                                                                                     type:NSGreaterThanPredicateOperatorType
                                                                                  options:0];

    ASSERT_TRUE_MSG(comparisonPredicate != nil, "FAILED: comparisonPredicate should be non-null!");

    // validate the expression.
    ASSERT_TRUE_MSG([comparisonPredicate evaluateWithObject:nil substitutionVariables:nil], "FAILED: Comparison failed.");
}

TEST(NSComparisonPredicate, NSGreaterThanOrEqualToPredicateOperatorType) {
    // The bison out for expressions such as [NSPredicate predicateWithFormat:@" a[someValue] >= 10"],
    //[NSPredicate predicateWithFormat:@"age >= 10"], etc.

    NSExpression* largerExpression = [NSExpression expressionForConstantValue:[NSNumber numberWithInt:10]];
    ASSERT_TRUE_MSG(largerExpression != nil, "FAILED: largerExpression should be non-null!");

    NSExpression* lesserExpression = [NSExpression expressionForConstantValue:[NSNumber numberWithInt:10]];
    ASSERT_TRUE_MSG(lesserExpression != nil, "FAILED: lesserExpression should be non-null!");

    NSPredicate* comparisonPredicate = [NSComparisonPredicate predicateWithLeftExpression:largerExpression
                                                                          rightExpression:lesserExpression
                                                                                 modifier:NSDirectPredicateModifier
                                                                                     type:NSGreaterThanOrEqualToPredicateOperatorType
                                                                                  options:0];

    ASSERT_TRUE_MSG(comparisonPredicate != nil, "FAILED: comparisonPredicate should be non-null!");

    // validate the expression.
    ASSERT_TRUE_MSG([comparisonPredicate evaluateWithObject:nil substitutionVariables:nil], "FAILED: Comparison failed.");
}

TEST(NSComparisonPredicate, NSEqualToPredicateOperatorType) {
    // The bison out for expressions such as [NSPredicate predicateWithFormat:@" a[someValue] == b"],
    //[NSPredicate predicateWithFormat:@"age == x"], etc.

    NSExpression* exp1 = [NSExpression expressionForConstantValue:[NSNumber numberWithInt:10]];
    ASSERT_TRUE_MSG(exp1 != nil, "FAILED: exp1 should be non-null!");

    NSExpression* exp2 = [NSExpression expressionForConstantValue:[NSNumber numberWithInt:10]];
    ASSERT_TRUE_MSG(exp2 != nil, "FAILED: exp2 should be non-null!");

    NSPredicate* comparisonPredicate = [NSComparisonPredicate predicateWithLeftExpression:exp1
                                                                          rightExpression:exp2
                                                                                 modifier:NSDirectPredicateModifier
                                                                                     type:NSEqualToPredicateOperatorType
                                                                                  options:0];

    ASSERT_TRUE_MSG(comparisonPredicate != nil, "FAILED: comparisonPredicate should be non-null!");

    // validate the expression.
    ASSERT_TRUE_MSG([comparisonPredicate evaluateWithObject:nil substitutionVariables:nil], "FAILED: Comparison failed.");
}

TEST(NSComparisonPredicate, NSNotEqualToPredicateOperatorType) {
    // The bison out for expressions such as [NSPredicate predicateWithFormat:@" a[someValue] != b"],
    //[NSPredicate predicateWithFormat:@"age != x"], etc.

    NSExpression* exp1 = [NSExpression expressionForConstantValue:[NSNumber numberWithInt:10]];
    ASSERT_TRUE_MSG(exp1 != nil, "FAILED: exp1 should be non-null!");

    NSExpression* exp2 = [NSExpression expressionForConstantValue:[NSNumber numberWithInt:9]];
    ASSERT_TRUE_MSG(exp2 != nil, "FAILED: exp2 should be non-null!");

    NSPredicate* comparisonPredicate = [NSComparisonPredicate predicateWithLeftExpression:exp1
                                                                          rightExpression:exp2
                                                                                 modifier:NSDirectPredicateModifier
                                                                                     type:NSNotEqualToPredicateOperatorType
                                                                                  options:0];

    ASSERT_TRUE_MSG(comparisonPredicate != nil, "FAILED: comparisonPredicate should be non-null!");

    // validate the expression.
    ASSERT_TRUE_MSG([comparisonPredicate evaluateWithObject:nil substitutionVariables:nil], "FAILED: Comparison failed.");
}

@interface NSComparisonPredicateTestObj : NSObject
@property (assign) NSNumber* coinValue;
@property (assign) NSString* name;
- (instancetype)initWithValue:(NSInteger)value;
- (instancetype)initWithName:(NSString*)name;
- (BOOL)isValidCoin:(NSNumber*)maxValue;
@end

@implementation NSComparisonPredicateTestObj
- (instancetype)initWithValue:(NSInteger)value {
    if (self = [super init]) {
        _coinValue = [NSNumber numberWithInt:value];
    }
    return self;
}

- (instancetype)initWithName:(NSString*)name {
    if (self = [self initWithValue:0]) {
        _name = name;
    }
    return self;
}

- (BOOL)isValidCoin:(NSNumber*)maxValue {
    return ([_coinValue intValue] <= [maxValue intValue]);
}

- (id)copyWithZone:(NSZone*)zone {
    return [self retain];
}

- (void)dealloc {
    [super dealloc];
}
@end

TEST(NSComparisonPredicate, NSCustomSelectorPredicateOperatorType) {
    //"[Object function:x]"

    NSComparisonPredicateTestObj* coin = [[[NSComparisonPredicateTestObj alloc] initWithValue:99] autorelease];
    ASSERT_TRUE_MSG(coin != nil, "FAILED: coin should be non-null!");

    NSExpression* leftExp = [NSExpression expressionForConstantValue:coin];
    ASSERT_TRUE_MSG(leftExp != nil, "FAILED: leftExp should be non-null!");

    NSExpression* rightExp = [NSExpression expressionForConstantValue:[NSNumber numberWithInt:100]];
    ASSERT_TRUE_MSG(rightExp != nil, "FAILED: rightExp should be non-null!");

    SEL selector = NSSelectorFromString(@"isValidCoin:");
    ASSERT_TRUE_MSG(selector != nullptr, "FAILED: selector should be non-null!");

    NSPredicate* comparisonPredicate =
        [NSComparisonPredicate predicateWithLeftExpression:leftExp rightExpression:rightExp customSelector:selector];

    ASSERT_TRUE_MSG(comparisonPredicate != nil, "FAILED: comparisonPredicate should be non-null!");

    // validate the expression.
    ASSERT_TRUE_MSG([comparisonPredicate evaluateWithObject:nil substitutionVariables:nil], "FAILED: Comparison failed.");
}

TEST(NSComparisonPredicate, NSBeginsWithPredicateOperatorType) {
    // firstName BEGINSWITH[c/d] $FIRST_NAME., "SELF BEGINSWITH %@", "sampleString BEGINSWITH %@",

    NSExpression* leftExp = [NSExpression expressionForConstantValue:@"Hello, How are you?"];
    ASSERT_TRUE_MSG(leftExp != nil, "FAILED: leftExp should be non-null!");

    NSExpression* rightExp = [NSExpression expressionForConstantValue:@"Hello"];
    ASSERT_TRUE_MSG(rightExp != nil, "FAILED: rightExp should be non-null!");

    NSPredicate* comparisonPredicate = [NSComparisonPredicate predicateWithLeftExpression:leftExp
                                                                          rightExpression:rightExp
                                                                                 modifier:NSDirectPredicateModifier
                                                                                     type:NSBeginsWithPredicateOperatorType
                                                                                  options:0];

    ASSERT_TRUE_MSG(comparisonPredicate != nil, "FAILED: comparisonPredicate should be non-null!");

    ASSERT_TRUE_MSG([comparisonPredicate evaluateWithObject:nil substitutionVariables:nil], "FAILED: Comparison failed.");
}

TEST(NSComparisonPredicate, NSBeginsWithPredicateOperatorType_NSCaseInsensitivePredicateOption) {
    // firstName BEGINSWITH[c/d] $FIRST_NAME., "SELF BEGINSWITH %@", "sampleString BEGINSWITH %@",

    NSExpression* leftExp = [NSExpression expressionForConstantValue:@"HELLO, How are you?"];
    ASSERT_TRUE_MSG(leftExp != nil, "FAILED: leftExp should be non-null!");

    NSExpression* rightExp = [NSExpression expressionForConstantValue:@"Hello"];
    ASSERT_TRUE_MSG(rightExp != nil, "FAILED: rightExp should be non-null!");

    NSPredicate* comparisonPredicate = [NSComparisonPredicate predicateWithLeftExpression:leftExp
                                                                          rightExpression:rightExp
                                                                                 modifier:NSDirectPredicateModifier
                                                                                     type:NSBeginsWithPredicateOperatorType
                                                                                  options:NSCaseInsensitivePredicateOption];

    ASSERT_TRUE_MSG(comparisonPredicate != nil, "FAILED: comparisonPredicate should be non-null!");

    ASSERT_TRUE_MSG([comparisonPredicate evaluateWithObject:nil substitutionVariables:nil], "FAILED: Comparison failed.");
}

TEST(NSComparisonPredicate, NSEndsWithPredicateOperatorType) {
    // firstName ENDSWITH[c/d] $FIRST_NAME., "SELF ENDSWITH[c/d] %@" %@", "sampleString ENDSWITH %@",

    NSExpression* leftExp = [NSExpression expressionForConstantValue:@"A String that ends with a word dog"];
    ASSERT_TRUE_MSG(leftExp != nil, "FAILED: leftExp should be non-null!");

    NSExpression* rightExp = [NSExpression expressionForConstantValue:@"dog"];
    ASSERT_TRUE_MSG(rightExp != nil, "FAILED: rightExp should be non-null!");

    NSPredicate* comparisonPredicate = [NSComparisonPredicate predicateWithLeftExpression:leftExp
                                                                          rightExpression:rightExp
                                                                                 modifier:NSDirectPredicateModifier
                                                                                     type:NSEndsWithPredicateOperatorType
                                                                                  options:0];

    ASSERT_TRUE_MSG(comparisonPredicate != nil, "FAILED: comparisonPredicate should be non-null!");

    ASSERT_TRUE_MSG([comparisonPredicate evaluateWithObject:nil substitutionVariables:nil], "FAILED: Comparison failed.");
}

TEST(NSComparisonPredicate, NSEndsWithPredicateOperatorType_NSCaseInsensitivePredicateOption) {
    // firstName ENDSWITH[c/d] $FIRST_NAME., "SELF ENDSWITH[c/d] %@" %@", "sampleString ENDSWITH %@",

    NSExpression* leftExp = [NSExpression expressionForConstantValue:@"A String that ends with a word dog"];
    ASSERT_TRUE_MSG(leftExp != nil, "FAILED: leftExp should be non-null!");

    NSExpression* rightExp = [NSExpression expressionForConstantValue:@"DOG"];
    ASSERT_TRUE_MSG(rightExp != nil, "FAILED: rightExp should be non-null!");

    NSPredicate* comparisonPredicate = [NSComparisonPredicate predicateWithLeftExpression:leftExp
                                                                          rightExpression:rightExp
                                                                                 modifier:NSDirectPredicateModifier
                                                                                     type:NSEndsWithPredicateOperatorType
                                                                                  options:NSCaseInsensitivePredicateOption];

    ASSERT_TRUE_MSG(comparisonPredicate != nil, "FAILED: comparisonPredicate should be non-null!");

    ASSERT_TRUE_MSG([comparisonPredicate evaluateWithObject:nil substitutionVariables:nil], "FAILED: Comparison failed.");
}

TEST(NSComparisonPredicate, NSInPredicateOperatorType) {
    //"$name IN { 'Ben', 'Melissa', 'Nick' }", "var_name IN %@"
    // Left is in the right

    NSExpression* leftExp = [NSExpression expressionForConstantValue:@(10)];
    ASSERT_TRUE_MSG(leftExp != nil, "FAILED: leftExp should be non-null!");

    NSArray* exampleVals = @[ @(20), @(10), @(18) ];
    ASSERT_TRUE_MSG(exampleVals != nil, "FAILED: exampleVals should be non-null!");

    NSExpression* rightExp = [NSExpression expressionForConstantValue:exampleVals];
    ASSERT_TRUE_MSG(rightExp != nil, "FAILED: rightExp should be non-null!");

    NSPredicate* comparisonPredicate = [NSComparisonPredicate predicateWithLeftExpression:leftExp
                                                                          rightExpression:rightExp
                                                                                 modifier:NSDirectPredicateModifier
                                                                                     type:NSInPredicateOperatorType
                                                                                  options:NSCaseInsensitivePredicateOption];

    ASSERT_TRUE_MSG(comparisonPredicate != nil, "FAILED: comparisonPredicate should be non-null!");

    ASSERT_TRUE_MSG([comparisonPredicate evaluateWithObject:nil substitutionVariables:nil], "FAILED: Comparison failed.");
}

TEST(NSComparisonPredicate, NSInPredicateOperatorType_NSKeyPath) {
    //"$name IN { 'Ben', 'Melissa', 'Nick' }", "var_name IN %@"
    // Left is in the right
    NSComparisonPredicateTestObj* coin = [[[NSComparisonPredicateTestObj alloc] initWithValue:20] autorelease];
    ASSERT_TRUE_MSG(coin != nil, "FAILED: coin should be non-null!");

    NSExpression* leftExp = [NSExpression expressionForKeyPath:@"coinValue"];
    ASSERT_TRUE_MSG(leftExp != nil, "FAILED: leftExp should be non-null!");

    NSArray* exampleVals = @[ @(20), @(10), @(18) ];
    ASSERT_TRUE_MSG(exampleVals != nil, "FAILED: exampleVals should be non-null!");

    NSExpression* rightExp = [NSExpression expressionForConstantValue:exampleVals];
    ASSERT_TRUE_MSG(rightExp != nil, "FAILED: rightExp should be non-null!");

    NSPredicate* comparisonPredicate = [NSComparisonPredicate predicateWithLeftExpression:leftExp
                                                                          rightExpression:rightExp
                                                                                 modifier:NSDirectPredicateModifier
                                                                                     type:NSInPredicateOperatorType
                                                                                  options:NSCaseInsensitivePredicateOption];

    ASSERT_TRUE_MSG(comparisonPredicate != nil, "FAILED: comparisonPredicate should be non-null!");

    ASSERT_TRUE_MSG([comparisonPredicate evaluateWithObject:coin substitutionVariables:nil], "FAILED: Comparison failed.");
}

TEST(NSComparisonPredicate, NSInPredicateOperatorType_Set) {
    //"$name IN { 'Ben', 'Melissa', 'Nick' }", "var_name IN %@"
    // Left is in the right
    NSComparisonPredicateTestObj* coin = [[[NSComparisonPredicateTestObj alloc] initWithName:@"Gold"] autorelease];
    ASSERT_TRUE_MSG(coin != nil, "FAILED: coin should be non-null!");

    NSExpression* leftExp = [NSExpression expressionForKeyPath:@"name"];
    ASSERT_TRUE_MSG(leftExp != nil, "FAILED: leftExp should be non-null!");

    NSSet* exampleSet = [NSSet setWithObjects:@"Gold", @"Silver", @"Copper", nil];
    ASSERT_TRUE_MSG(exampleSet != nil, "FAILED: exampleSet should be non-null!");

    NSExpression* rightExp = [NSExpression expressionForConstantValue:exampleSet];
    ASSERT_TRUE_MSG(rightExp != nil, "FAILED: rightExp should be non-null!");

    NSPredicate* comparisonPredicate = [NSComparisonPredicate predicateWithLeftExpression:leftExp
                                                                          rightExpression:rightExp
                                                                                 modifier:NSDirectPredicateModifier
                                                                                     type:NSInPredicateOperatorType
                                                                                  options:NSCaseInsensitivePredicateOption];

    ASSERT_TRUE_MSG(comparisonPredicate != nil, "FAILED: comparisonPredicate should be non-null!");

    ASSERT_TRUE_MSG([comparisonPredicate evaluateWithObject:coin substitutionVariables:nil], "FAILED: Comparison failed.");
}

TEST(NSComparisonPredicate, NSInPredicateOperatorType_NSDictionary) {
    //"$name IN { 'Ben', 'Melissa', 'Nick' }", "var_name IN %@"
    // Left is in the right
    NSComparisonPredicateTestObj* coin = [[[NSComparisonPredicateTestObj alloc] initWithValue:9] autorelease];
    ASSERT_TRUE_MSG(coin != nil, "FAILED: coin should be non-null!");

    NSExpression* leftExp = [NSExpression expressionForKeyPath:@"coinValue"];
    ASSERT_TRUE_MSG(leftExp != nil, "FAILED: leftExp should be non-null!");

    NSDictionary* sampleDict = @{
        @"one" : [NSNumber numberWithInt:1],
        @"Two" : [NSNumber numberWithInt:2],
        @"nine" : [NSNumber numberWithInt:9],
    };

    ASSERT_TRUE_MSG(sampleDict != nil, "FAILED: sampleDict should be non-null!");

    NSExpression* rightExp = [NSExpression expressionForConstantValue:sampleDict];
    ASSERT_TRUE_MSG(rightExp != nil, "FAILED: rightExp should be non-null!");

    NSPredicate* comparisonPredicate = [NSComparisonPredicate predicateWithLeftExpression:leftExp
                                                                          rightExpression:rightExp
                                                                                 modifier:NSDirectPredicateModifier
                                                                                     type:NSInPredicateOperatorType
                                                                                  options:NSCaseInsensitivePredicateOption];

    ASSERT_TRUE_MSG(comparisonPredicate != nil, "FAILED: comparisonPredicate should be non-null!");

    ASSERT_TRUE_MSG([comparisonPredicate evaluateWithObject:coin substitutionVariables:nil], "FAILED: Comparison failed.");
}

TEST(NSComparisonPredicate, NSContainsPredicateOperatorType) {
    //"$name CONTAINS %2", "$varname contains $testSubString"
    // Left contains the right

    NSExpression* leftExp = [NSExpression expressionForConstantValue:@"Hello How Are You?"];
    ASSERT_TRUE_MSG(leftExp != nil, "FAILED: leftExp should be non-null!");

    NSExpression* rightExp = [NSExpression expressionForConstantValue:@"are"];
    ASSERT_TRUE_MSG(rightExp != nil, "FAILED: rightExp should be non-null!");

    NSPredicate* comparisonPredicate = [NSComparisonPredicate predicateWithLeftExpression:leftExp
                                                                          rightExpression:rightExp
                                                                                 modifier:NSDirectPredicateModifier
                                                                                     type:NSContainsPredicateOperatorType
                                                                                  options:0];

    ASSERT_TRUE_MSG(comparisonPredicate != nil, "FAILED: comparisonPredicate should be non-null!");

    ASSERT_FALSE_MSG([comparisonPredicate evaluateWithObject:nil substitutionVariables:nil], "FAILED: Comparison failed.");
}

TEST(NSComparisonPredicate, NSContainsPredicateOperatorType_NSCaseInsensitivePredicateOption) {
    //"$name CONTAINS %2", "$varname contains $testSubString"
    // Left contains the right

    NSExpression* leftExp = [NSExpression expressionForConstantValue:@"Hello How Are You?"];
    ASSERT_TRUE_MSG(leftExp != nil, "FAILED: leftExp should be non-null!");

    NSExpression* rightExp = [NSExpression expressionForConstantValue:@"ARE"];
    ASSERT_TRUE_MSG(rightExp != nil, "FAILED: rightExp should be non-null!");

    NSPredicate* comparisonPredicate = [NSComparisonPredicate predicateWithLeftExpression:leftExp
                                                                          rightExpression:rightExp
                                                                                 modifier:NSDirectPredicateModifier
                                                                                     type:NSContainsPredicateOperatorType
                                                                                  options:NSCaseInsensitivePredicateOption];

    ASSERT_TRUE_MSG(comparisonPredicate != nil, "FAILED: comparisonPredicate should be non-null!");

    ASSERT_TRUE_MSG([comparisonPredicate evaluateWithObject:nil substitutionVariables:nil], "FAILED: Comparison failed.");
}

TEST(NSComparisonPredicate, NSBetweenPredicateOperatorType) {
    // "$INPUT BETWEEN { $LOWER, $UPPER }."

    NSArray* exampleVals = @[ @(0), @(33) ];
    ASSERT_TRUE_MSG(exampleVals != nil, "FAILED: exampleVals should be non-null!");

    NSExpression* leftExp = [NSExpression expressionForConstantValue:@(15)];
    ASSERT_TRUE_MSG(leftExp != nil, "FAILED: leftExp should be non-null!");

    NSExpression* rightExp = [NSExpression expressionForConstantValue:exampleVals];
    ASSERT_TRUE_MSG(rightExp != nil, "FAILED: rightExp should be non-null!");

    NSPredicate* comparisonPredicate = [NSComparisonPredicate predicateWithLeftExpression:leftExp
                                                                          rightExpression:rightExp
                                                                                 modifier:NSDirectPredicateModifier
                                                                                     type:NSBetweenPredicateOperatorType
                                                                                  options:NSCaseInsensitivePredicateOption];

    ASSERT_TRUE_MSG(comparisonPredicate != nil, "FAILED: comparisonPredicate should be non-null!");

    ASSERT_TRUE_MSG([comparisonPredicate evaluateWithObject:nil substitutionVariables:nil], "FAILED: Comparison failed.");
}

TEST(NSComparisonPredicate, ArchiveAndUnarchiveObject) {
    NSArray* exampleVals = @[ @(0), @(33) ];
    NSExpression* leftExp = [NSExpression expressionForConstantValue:@(15)];
    NSExpression* rightExp = [NSExpression expressionForConstantValue:exampleVals];

    NSPredicate* comparisonPredicate = [NSComparisonPredicate predicateWithLeftExpression:leftExp
                                                                          rightExpression:rightExp
                                                                                 modifier:NSDirectPredicateModifier
                                                                                     type:NSBetweenPredicateOperatorType
                                                                                  options:NSCaseInsensitivePredicateOption];
    ASSERT_TRUE_MSG(comparisonPredicate != nil, "FAILED: comparisonPredicate should be non-null!");

    // archive the object
    NSData* data = [NSKeyedArchiver archivedDataWithRootObject:comparisonPredicate];
    ASSERT_TRUE_MSG(data != nil, "FAILED: archived data should be non-null!");
    // unarchive
    NSComparisonPredicate* unArchivedcomparisonPredicate = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    ASSERT_TRUE_MSG(unArchivedcomparisonPredicate != nil, "FAILED: unArchivedcomparisonPredicate should be non-null!");
}

TEST(NSComparisonPredicate, copy) {
    NSArray* exampleVals = @[ @(0), @(33) ];
    NSExpression* leftExp = [NSExpression expressionForConstantValue:@(15)];
    NSExpression* rightExp = [NSExpression expressionForConstantValue:exampleVals];

    NSPredicate* comparisonPredicate = [NSComparisonPredicate predicateWithLeftExpression:leftExp
                                                                          rightExpression:rightExp
                                                                                 modifier:NSDirectPredicateModifier
                                                                                     type:NSBetweenPredicateOperatorType
                                                                                  options:NSCaseInsensitivePredicateOption];

    ASSERT_TRUE_MSG(comparisonPredicate != nil, "FAILED: comparisonPredicate should be non-null!");

    NSComparisonPredicate* copyObj = [comparisonPredicate copy];
    ASSERT_TRUE_MSG(copyObj != nil, "FAILED: copyObj should be non-null!");

    ASSERT_OBJCEQ_MSG(comparisonPredicate, copyObj, "FAILED: objects do not match.");

    [copyObj release];
}
