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

#import <Foundation/NSCoder.h>

#import <Foundation/NSInvocation.h>
#import <Foundation/NSMethodSignature.h>
#import <Foundation/NSMutableArray.h>
#import <Foundation/NSException.h>

#import "NSExpressionFunction.h"
#import "NSExpressionDefaultFunctions.h"
#import "NSExpressionConstantValue.h"

@implementation NSExpressionFunction

/**
 @Status Interoperable
*/
- (id)initWithFunctionName:(NSString*)name arguments:(NSArray*)args {
    if (self = [super initWithExpressionType:NSFunctionExpressionType]) {
        _selector = NSSelectorFromString(name);
        if (!_selector) {
            [self release];
            return nil;
        }
        _args = [args copy];

        _target = [[NSExpressionConstantValue alloc] initWithConstValue:[[NSExpressionDefaultFunctions alloc] init]];
    }

    return self;
}

/**
 @Status Interoperable
*/
- (id)initWithExpressionTarget:(NSExpression*)target selectorName:(NSString*)name arguments:(NSArray*)parameters {
    if (self = [self initWithFunctionName:name arguments:parameters]) {
        _target = [target copy];
    }

    return self;
}

- (NSMutableArray*)_obtainExpressionResultForObject:(id)object context:(NSMutableDictionary*)context {
    NSMutableArray* expressionResults = [NSMutableArray arrayWithCapacity:[_args count]];

    // obtain the result of each of the expression.
    for (NSExpression* exp : _args) {
        id result = [exp expressionValueWithObject:object context:context];
        [expressionResults addObject:result];
    }

    return expressionResults;
}

/**
 @Status Interoperable
*/
- (id)expressionValueWithObject:(id)object context:(NSMutableDictionary*)context {
    NSObject* result = (NSObject*)[_target expressionValueWithObject:object context:context];
    // run the selector on the result.
    NSMethodSignature* sig = [result methodSignatureForSelector:_selector];
    NSInvocation* invocation = [NSInvocation invocationWithMethodSignature:sig];
    [invocation setSelector:_selector];
    [invocation setTarget:result];

    if ((_args) && ([_args count] > 0)) {
        if ([_args count] > [sig numberOfArguments]) {
            [NSException raise:NSInvalidArgumentException format:@"The number of arguments exceed the allowed limit."];
        }

        NSMutableArray* expressionResult = [self _obtainExpressionResultForObject:object context:context];
        NSUInteger count = [_args count];
        for (NSUInteger index = 0; index < count; index++) {
            // initial offset of 2 to skip the hidden arguments.
            id arg = [expressionResult objectAtIndex:index];
            [invocation setArgument:&arg atIndex:(index + 2)];
        }
    }

    [invocation invoke];

    id invocationResult;
    [invocation getReturnValue:&invocationResult];

    return invocationResult;
}

- (NSExpression*)expressionWithSubstitutionVariables:(NSDictionary*)variables {
    NSMutableArray* argsSub = [NSMutableArray arrayWithCapacity:[_args count]];

    NSExpression* targetSub = (_target != nil) ? [_target expressionWithSubstitutionVariables:variables] : nil;

    for (NSExpression* exp : _args) {
        [argsSub addObject:[exp expressionWithSubstitutionVariables:variables]];
    }

    return [[[[self class] alloc] initWithExpressionTarget:targetSub selectorName:NSStringFromSelector(_selector) arguments:argsSub]
        autorelease];
}

/**
 @Status Interoperable
*/
+ (BOOL)supportsSecureCoding {
    return YES;
}

/**
 @Status Interoperable
*/
- (void)encodeWithCoder:(NSCoder*)encoder {
    [encoder encodeObject:_args forKey:@"args"];
    [encoder encodeObject:NSStringFromSelector(_selector) forKey:@"selector"];
    [encoder encodeObject:_target forKey:@"target"];
    [super encodeWithCoder:encoder];
}

/**
 @Status Interoperable
*/
- (instancetype)initWithCoder:(NSCoder*)decoder {
    if (self = [super initWithCoder:decoder]) {
        _args = [[decoder decodeObjectOfClass:[NSArray class] forKey:@"args"] retain];
        _selector = NSSelectorFromString([decoder decodeObjectOfClass:[NSString class] forKey:@"selector"]);
        _target = [[decoder decodeObjectOfClass:[NSExpression class] forKey:@"target"] retain];
    }
    return self;
}

/**
 @Status Interoperable
*/
- (void)dealloc {
    [_args release];
    [_target release];
    [super dealloc];
}
@end
