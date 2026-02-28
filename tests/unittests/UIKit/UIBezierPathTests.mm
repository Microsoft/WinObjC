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

#import <TestFramework.h>
#import <UIKit/UIBezierPath.h>
#import <Starboard/SmartTypes.h>

TEST(UIBezierPath, ContainsPoint) {
    UIBezierPath* path = [UIBezierPath bezierPathWithRect:CGRectMake(0, 0, 100, 100)];
    ASSERT_TRUE_MSG(path != nil, "Failed to instantiate UIBezierPath.");

    EXPECT_TRUE([path containsPoint:CGPointMake(50, 50)]);
    EXPECT_FALSE([path containsPoint:CGPointMake(150, 150)]);
}

TEST(UIBezierPath, IsEmpty) {
    UIBezierPath* path = [UIBezierPath bezierPath];
    EXPECT_TRUE([path isEmpty]);
    [path moveToPoint:CGPointMake(0, 0)];
    [path addLineToPoint:CGPointMake(100, 100)];
    [path closePath];
    EXPECT_FALSE([path isEmpty]);
}

TEST(UIBezierPath, CurrentPoint) {
    UIBezierPath* path = [UIBezierPath bezierPath];

    CGPoint currentPoint = CGPointMake(0, 0);
    [path moveToPoint:currentPoint];
    EXPECT_TRUE([path currentPoint] == currentPoint);

    currentPoint = CGPointMake(50, 50);
    [path addLineToPoint:currentPoint];
    EXPECT_TRUE([path currentPoint] == currentPoint);

    currentPoint = CGPointMake(100, 40);
    [path addQuadCurveToPoint:currentPoint controlPoint:CGPointMake(100, 50)];
    EXPECT_TRUE([path currentPoint] == currentPoint);

    currentPoint = CGPointMake(0, 0);
    [path closePath];
    EXPECT_TRUE([path currentPoint] == currentPoint);
}

TEST(UIBezierPath, GetDashPattern) {
    UIBezierPath* path = [UIBezierPath bezierPathWithRect:CGRectMake(100, 100, 100, 100)];
    const CGFloat pattern[] = { 5.0, 2.0 };
    [path setLineDash:pattern count:2 phase:7.0f];

    CGFloat outPattern[2];
    NSInteger count;
    CGFloat phase;
    [path getLineDash:outPattern count:&count phase:&phase];
    EXPECT_EQ(count, 2);
    EXPECT_EQ(phase, 7.0f);
    for (int i = 0; i < count; i++) {
        EXPECT_EQ(outPattern[i], pattern[i]);
    }

    [path setLineDash:nullptr count:0 phase:0];
    [path getLineDash:outPattern count:&count phase:&phase];
    EXPECT_EQ(count, 0);
    EXPECT_EQ(phase, 0.0f);
}

TEST(UIBezierPath, GetPath) {
    UIBezierPath* path1 = [UIBezierPath bezierPathWithRect:CGRectMake(100, 100, 100, 100)];
    CGPathRef path2 = CGPathCreateWithRect(CGRectMake(100, 100, 100, 100), nullptr);
    EXPECT_TRUE_MSG(CGPathEqualToPath(path1.CGPath, path2), "Paths were not equal.");
}
