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
#import <CoreGraphics/CoreGraphics.h>

TEST(CGColorSpace, BasicColorSpaces) {
    auto rgbColorSpace = woc::MakeStrongCF<CGColorSpaceRef>(CGColorSpaceCreateDeviceRGB());
    EXPECT_NE(nullptr, rgbColorSpace);
    EXPECT_EQ(kCGColorSpaceModelRGB, CGColorSpaceGetModel(rgbColorSpace));
    EXPECT_EQ(3, CGColorSpaceGetNumberOfComponents(rgbColorSpace));

    auto grayColorSpace = woc::MakeStrongCF<CGColorSpaceRef>(CGColorSpaceCreateDeviceGray());
    EXPECT_NE(nullptr, grayColorSpace);
    EXPECT_EQ(kCGColorSpaceModelMonochrome, CGColorSpaceGetModel(grayColorSpace));
    EXPECT_EQ(1, CGColorSpaceGetNumberOfComponents(grayColorSpace));

    auto coloredPatternColorSpace = woc::MakeStrongCF<CGColorSpaceRef>(CGColorSpaceCreatePattern(nullptr));
    EXPECT_NE(nullptr, coloredPatternColorSpace);
    EXPECT_EQ(kCGColorSpaceModelPattern, CGColorSpaceGetModel(coloredPatternColorSpace));
    EXPECT_EQ(0, CGColorSpaceGetNumberOfComponents(coloredPatternColorSpace));
    EXPECT_EQ(nullptr, CGColorSpaceGetBaseColorSpace(coloredPatternColorSpace));

    auto stencilPatternColorSpace = woc::MakeStrongCF<CGColorSpaceRef>(CGColorSpaceCreatePattern(rgbColorSpace));
    EXPECT_NE(nullptr, stencilPatternColorSpace);
    EXPECT_EQ(kCGColorSpaceModelPattern, CGColorSpaceGetModel(stencilPatternColorSpace));
    EXPECT_EQ(3, CGColorSpaceGetNumberOfComponents(stencilPatternColorSpace));
    EXPECT_EQ(CGColorSpaceGetModel(rgbColorSpace), CGColorSpaceGetModel(CGColorSpaceGetBaseColorSpace(stencilPatternColorSpace)));
}

TEST(CGColorSpace, IndexedColor) {
    auto rgbColorSpace = woc::MakeStrongCF<CGColorSpaceRef>(CGColorSpaceCreateDeviceRGB());
    EXPECT_NE(nullptr, rgbColorSpace);

    unsigned char table[] = { 255, 255, 255, 0, 0, 0 };

    auto indexedColorSpace = woc::MakeStrongCF<CGColorSpaceRef>(CGColorSpaceCreateIndexed(rgbColorSpace, 1, table));
    EXPECT_NE(nullptr, indexedColorSpace);
    EXPECT_EQ(kCGColorSpaceModelIndexed, CGColorSpaceGetModel(indexedColorSpace));
    EXPECT_EQ(1, CGColorSpaceGetNumberOfComponents(indexedColorSpace));
    EXPECT_EQ(CGColorSpaceGetModel(rgbColorSpace), CGColorSpaceGetModel(CGColorSpaceGetBaseColorSpace(indexedColorSpace)));

    auto grayColorSpace = woc::MakeStrongCF<CGColorSpaceRef>(CGColorSpaceCreateDeviceGray());
    EXPECT_NE(nullptr, grayColorSpace);

    auto indexedColorSpaceGray = woc::MakeStrongCF<CGColorSpaceRef>(CGColorSpaceCreateIndexed(grayColorSpace, 1, table));
    EXPECT_NE(nullptr, indexedColorSpaceGray);
    EXPECT_EQ(kCGColorSpaceModelIndexed, CGColorSpaceGetModel(indexedColorSpaceGray));
    EXPECT_EQ(1, CGColorSpaceGetNumberOfComponents(indexedColorSpaceGray));
    EXPECT_EQ(CGColorSpaceGetModel(grayColorSpace), CGColorSpaceGetModel(CGColorSpaceGetBaseColorSpace(indexedColorSpaceGray)));
}

TEST(CGColorSpace, CreateWithName) {
    auto colorSpaceRGB = woc::MakeStrongCF<CGColorSpaceRef>(CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB));
    EXPECT_NE(nullptr, colorSpaceRGB);
    EXPECT_EQ(kCGColorSpaceModelRGB, CGColorSpaceGetModel(colorSpaceRGB));
    EXPECT_EQ(3, CGColorSpaceGetNumberOfComponents(colorSpaceRGB));

    auto colorSpaceRGBLinear = woc::MakeStrongCF<CGColorSpaceRef>(CGColorSpaceCreateWithName(kCGColorSpaceGenericRGBLinear));
    EXPECT_NE(nullptr, colorSpaceRGBLinear);
    EXPECT_EQ(kCGColorSpaceModelRGB, CGColorSpaceGetModel(colorSpaceRGBLinear));
    EXPECT_EQ(3, CGColorSpaceGetNumberOfComponents(colorSpaceRGBLinear));

    auto colorSpaceGray = woc::MakeStrongCF<CGColorSpaceRef>(CGColorSpaceCreateWithName(kCGColorSpaceGenericGray));
    EXPECT_NE(nullptr, colorSpaceGray);
    EXPECT_EQ(kCGColorSpaceModelMonochrome, CGColorSpaceGetModel(colorSpaceGray));
    EXPECT_EQ(1, CGColorSpaceGetNumberOfComponents(colorSpaceGray));
}