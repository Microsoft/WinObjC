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
#import <CoreGraphics/CGGradient.h>
#import <CoreGraphics/CGColor.h>
#import <CoreFoundation/CFArray.h>

TEST(CGGradient, NULLColorSpaceColors) {
    auto colorspace = woc::MakeStrongCF<CGColorSpaceRef>(CGColorSpaceCreateDeviceRGB());

    CGFloat compCol1[4] = { 1, 1, 1, 0.5 };
    CGFloat compCol2[4] = { 0.628, 0.628, 0.628, 1 };

    auto col1 = woc::MakeStrongCF<CGColorRef>(CGColorCreate(colorspace, compCol1));
    auto col2 = woc::MakeStrongCF<CGColorRef>(CGColorCreate(colorspace, compCol2));

    CGFloat locations[] = { 0, 1 };
    auto array = woc::MakeStrongCF<CFMutableArrayRef>(CFArrayCreateMutable(nullptr, 0, &kCFTypeArrayCallBacks));
    CFArrayAppendValue(array, col1);
    CFArrayAppendValue(array, col2);

    // NULL colorspace is valid for CGGradientCreateWithColors
    auto gradient = woc::MakeStrongCF<CGGradientRef>(CGGradientCreateWithColors(nullptr, array, locations));
    EXPECT_NE(gradient, nullptr);

    gradient = woc::MakeStrongCF<CGGradientRef>(CGGradientCreateWithColors(nullptr, array, nullptr));
    EXPECT_NE(gradient, nullptr);

    gradient = woc::MakeStrongCF<CGGradientRef>(CGGradientCreateWithColors(nullptr, nullptr, locations));
    EXPECT_EQ(gradient, nullptr);
}

TEST(CGGradient, NULLColorSpaceComponents) {
    CGFloat components[12] = { 1.0, 1.0, 1.0, 1.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0, 1.0, 1.0 };
    CGFloat locations[] = { 0, 0.5, 1 };
    auto gradient = woc::MakeStrongCF<CGGradientRef>(CGGradientCreateWithColorComponents(nullptr, components, locations, 3));
    EXPECT_EQ(gradient, nullptr);

    gradient = woc::MakeStrongCF<CGGradientRef>(CGGradientCreateWithColorComponents(nullptr, components, nullptr, 3));
    EXPECT_EQ(gradient, nullptr);

    gradient = woc::MakeStrongCF<CGGradientRef>(CGGradientCreateWithColorComponents(nullptr, nullptr, locations, 3));
    EXPECT_EQ(gradient, nullptr);
}

TEST(CGGradient, CreateWithColors) {
    auto colorspace = woc::MakeStrongCF<CGColorSpaceRef>(CGColorSpaceCreateDeviceRGB());
    CGFloat compCol1[4] = { 1, 1, 1, 0.5 };
    CGFloat compCol2[4] = { 0.628, 0.628, 0.628, 1 };
    auto col1 = woc::MakeStrongCF<CGColorRef>(CGColorCreate(colorspace, compCol1));
    auto col2 = woc::MakeStrongCF<CGColorRef>(CGColorCreate(colorspace, compCol2));

    CGFloat locations[] = { 0, 1 };
    auto array = woc::MakeStrongCF<CFMutableArrayRef>(CFArrayCreateMutable(nullptr, 0, &kCFTypeArrayCallBacks));
    CFArrayAppendValue(array, col1);
    CFArrayAppendValue(array, col2);

    auto gradient = woc::MakeStrongCF<CGGradientRef>(CGGradientCreateWithColors(colorspace, array, locations));
    ASSERT_NE(gradient, nullptr);

    gradient = woc::MakeStrongCF<CGGradientRef>(CGGradientCreateWithColors(colorspace, array, nullptr));
    ASSERT_NE(gradient, nullptr);
}

TEST(CGGradient, CreateWithColorComponents) {
    CGFloat components[12] = { 1.0, 1.0, 1.0, 1.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0, 1.0, 1.0 };
    CGFloat locations[] = { 0, 0.5, 1 };
    auto colorspace = woc::MakeStrongCF<CGColorSpaceRef>(CGColorSpaceCreateDeviceRGB());
    auto gradient = woc::MakeStrongCF<CGGradientRef>(CGGradientCreateWithColorComponents(colorspace, components, locations, 3));
    EXPECT_NE(gradient, nullptr);

    // Create with NULL locations
    gradient = woc::MakeStrongCF<CGGradientRef>(CGGradientCreateWithColorComponents(colorspace, components, nullptr, 3));
    EXPECT_NE(gradient, nullptr);
}
