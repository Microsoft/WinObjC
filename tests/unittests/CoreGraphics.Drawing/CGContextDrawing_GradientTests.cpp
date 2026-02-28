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

#include "DrawingTest.h"

#pragma region LinearGradient

static void _drawLinearGradient(CGContextRef context,
                                CGPoint startPoint,
                                CGPoint endPoint,
                                CGFloat components[],
                                CGFloat locations[],
                                size_t count,
                                CGGradientDrawingOptions options) {
    auto colorspace = woc::MakeStrongCF<CGColorSpaceRef>(CGColorSpaceCreateDeviceRGB());
    auto gradient = woc::MakeStrongCF<CGGradientRef>(CGGradientCreateWithColorComponents(colorspace, components, locations, count));

    CGContextDrawLinearGradient(context, gradient, startPoint, endPoint, options);
}

static void _drawShortLinearGradientWithOptions(CGContextRef context, CGRect bounds, CGGradientDrawingOptions option) {
    CGFloat locations[2] = { 0, 1 };
    CGFloat components[8] = { 0.0, 1, 0.0, 1.0, 1.0, 0, 0, 1.0 };

    CGRect borderRect = CGRectInset(bounds, 30, 50);

    _drawLinearGradient(context,
                        borderRect.origin,
                        CGPointMake(borderRect.size.width, borderRect.size.height),
                        components,
                        locations,
                        std::extent<decltype(locations)>::value,
                        option);
}

DRAW_TEST_F(CGGradient, LinearGradient, UIKitMimicTest<PixelByPixelImageComparator<PixelComparisonModeDifferenceLimen<>>>) {
    CGFloat locations[2] = { 0, 1 };
    CGFloat components[8] = { 0.0, 0.0, 1, 1.0, 1.0, 0, 0, 1.0 };

    _drawLinearGradient(GetDrawingContext(),
                        CGPointMake(0, 0),
                        CGPointMake(512, 1024),
                        components,
                        locations,
                        std::extent<decltype(locations)>::value,
                        kCGGradientDrawsBeforeStartLocation);
}

DRAW_TEST_F(CGGradient, LinearGradientDrawWithCGColor, UIKitMimicTest<PixelByPixelImageComparator<PixelComparisonModeMask<64>>>) {
    CGFloat locations[2] = { 0, 1 };
    CGFloat components[8] = { 1.0, 0.0, 0.0, 1.0, 0.0, 0.0, 1.0, 1.0 };

    auto colorspace = woc::MakeStrongCF<CGColorSpaceRef>(CGColorSpaceCreateDeviceRGB());

    auto red = woc::MakeStrongCF<CGColorRef>(CGColorCreate(colorspace, &components[0]));
    auto blue = woc::MakeStrongCF<CGColorRef>(CGColorCreate(colorspace, &components[4]));

    CGColorRef colors[] = { red, blue };
    auto colArray = woc::MakeStrongCF<CFArrayRef>(
        CFArrayCreate(nullptr, (const void**)colors, std::extent<decltype(colors)>::value, &kCFTypeArrayCallBacks));
    auto gradient = woc::MakeStrongCF<CGGradientRef>(CGGradientCreateWithColors(colorspace, colArray, locations));
    CGContextDrawLinearGradient(GetDrawingContext(),
                                gradient,
                                CGPointMake(0, 0),
                                CGPointMake(512, 1024),
                                kCGGradientDrawsBeforeStartLocation);
}

class CGGradientLinearDiffColorSpace : public UIKitMimicTest<PixelByPixelImageComparator<PixelComparisonModeMask<64>>>,
                                       public ::testing::WithParamInterface<CGColorSpaceRef> {
    CFStringRef CreateOutputFilename() {
        CGColorSpaceRef colorSpace = GetParam();

        const char* optionsName;
        switch (CGColorSpaceGetModel(colorSpace)) {
            case kCGColorSpaceModelRGB:
                optionsName = "RGB";
                break;
            case kCGColorSpaceModelPattern:
                optionsName = "Pattern";
                break;
            case kCGColorSpaceModelMonochrome:
                optionsName = "MonoChrome";
                break;
            case kCGColorSpaceModelIndexed:
                optionsName = "Indexed";
                break;
            case kCGColorSpaceModelCMYK:
                optionsName = "CMYK";
                break;
            default:
                optionsName = "Unknown";
                break;
        }

        return CFStringCreateWithFormat(nullptr, nullptr, CFSTR("TestImage.CGGradient.Linear.DifferentColorSpace.%s.png"), optionsName);
    }
};

DRAW_TEST_P(CGGradientLinearDiffColorSpace, LinearGradientCGColorDifferentColorSpace) {
    CGColorSpaceRef colorSpace = GetParam();
    auto grayHalf = woc::MakeStrongCF<CGColorRef>(CGColorCreateGenericGray(0.5, 0.5));
    auto blue = woc::MakeStrongCF<CGColorRef>(CGColorCreateGenericRGB(0, 0, 1, 1));
    auto clear = woc::MakeStrongCF<CGColorRef>(CGColorCreateGenericGray(0.0, 0.0));
    auto red = woc::MakeStrongCF<CGColorRef>(CGColorCreateGenericRGB(1, 0, 0, 1));
    auto green = woc::MakeStrongCF<CGColorRef>(CGColorCreateGenericRGB(0, 1, 0, 1));

    CGColorRef colors[] = { grayHalf, red, clear, blue, green };
    CFArrayRef colArray = CFArrayCreate(nullptr, (const void**)colors, 5, &kCFTypeArrayCallBacks);

    CGGradientRef gradient = CGGradientCreateWithColors(colorSpace, colArray, nullptr);

    CGContextDrawLinearGradient(GetDrawingContext(),
                                gradient,
                                CGPointMake(0, 0),
                                CGPointMake(512, 1024),
                                kCGGradientDrawsBeforeStartLocation);
}

static const CGColorSpaceRef sc_RGBColorSpace = woc::MakeStrongCF<CGColorSpaceRef>(CGColorSpaceCreateDeviceRGB());
static const CGColorSpaceRef sc_ColorSpaces[] = { sc_RGBColorSpace, nullptr };

INSTANTIATE_TEST_CASE_P(CGGradient, CGGradientLinearDiffColorSpace, ::testing::ValuesIn(sc_ColorSpaces));

DRAW_TEST_F(CGGradient, LinearGradientShortBothSides_Options_0, UIKitMimicTest<PixelByPixelImageComparator<PixelComparisonModeMask<64>>>) {
    _drawShortLinearGradientWithOptions(GetDrawingContext(), GetDrawingBounds(), 0);
}

DRAW_TEST_F(CGGradient,
            LinearGradientShortBothSides_Options_kCGGradientDrawsBeforeStartLocation,
            UIKitMimicTest<PixelByPixelImageComparator<PixelComparisonModeMask<64>>>) {
    _drawShortLinearGradientWithOptions(GetDrawingContext(), GetDrawingBounds(), kCGGradientDrawsBeforeStartLocation);
}

DRAW_TEST_F(CGGradient,
            LinearGradientShortBothSides_Options_kCGGradientDrawsAfterEndLocation,
            UIKitMimicTest<PixelByPixelImageComparator<PixelComparisonModeMask<64>>>) {
    _drawShortLinearGradientWithOptions(GetDrawingContext(), GetDrawingBounds(), kCGGradientDrawsAfterEndLocation);
}

DRAW_TEST_F(CGGradient, LinearGradientInvalidCount, UIKitMimicTest<>) {
    CGFloat locations[] = { 0.0 };

    CGFloat components[] = {
        0.85, 0, 0, 1.0,
    };

    auto colorspace = woc::MakeStrongCF<CGColorSpaceRef>(CGColorSpaceCreateDeviceRGB());
    auto gradient = woc::MakeStrongCF<CGGradientRef>(CGGradientCreateWithColorComponents(colorspace, components, locations, 0));

    CGContextDrawLinearGradient(GetDrawingContext(),
                                gradient,
                                CGPointMake(0, 0),
                                CGPointMake(512, 1024),
                                kCGGradientDrawsBeforeStartLocation);
}

DRAW_TEST_F(CGGradient, LinearGradientOneLocation, UIKitMimicTest<>) {
    // Note if the location is 1, the actual value is ignored.
    CGFloat locations[] = { 0.20 };

    CGFloat components[] = {
        1, 0, 0, 1,
    };

    auto colorspace = woc::MakeStrongCF<CGColorSpaceRef>(CGColorSpaceCreateDeviceRGB());
    auto gradient = woc::MakeStrongCF<CGGradientRef>(
        CGGradientCreateWithColorComponents(colorspace, components, locations, std::extent<decltype(locations)>::value));

    CGContextDrawLinearGradient(GetDrawingContext(),
                                gradient,
                                CGPointMake(0, 0),
                                CGPointMake(512, 1024),
                                kCGGradientDrawsBeforeStartLocation);
}

DRAW_TEST_F(CGGradient, LinearGradient2, UIKitMimicTest<>) {
    CGFloat locations[] = { 0.0, 0.33, 0.66, 1.0 };

    CGFloat components[] = {
        0.85, 0, 0, 1.0, 1, 0, 0, 1.0, 0.85, 0.3, 0, 1.0, 0.1, 0, 0.9, 1.0,
    };

    _drawLinearGradient(GetDrawingContext(),
                        CGPointMake(0, 0),
                        CGPointMake(512, 1024),
                        components,
                        locations,
                        std::extent<decltype(locations)>::value,
                        kCGGradientDrawsBeforeStartLocation);
}

DRAW_TEST_F(CGGradient, LinearGradientNullLocations, UIKitMimicTest<PixelByPixelImageComparator<PixelComparisonModeDifferenceLimen<>>>) {
    CGFloat components[] = {
        0, 0, 1, 1.0, 1, 0, 0, 1.0, 0.85, 0.3, 0, 1.0, 1, 0, 1, 1.0,
    };

    auto colorspace = woc::MakeStrongCF<CGColorSpaceRef>(CGColorSpaceCreateDeviceRGB());
    auto gradient = woc::MakeStrongCF<CGGradientRef>(CGGradientCreateWithColorComponents(colorspace, components, NULL, 4));

    CGContextDrawLinearGradient(GetDrawingContext(),
                                gradient,
                                CGPointMake(0, 0),
                                CGPointMake(512, 1024),
                                kCGGradientDrawsBeforeStartLocation);
}

DRAW_TEST_F(CGGradient, LinearGradient2Short, UIKitMimicTest<>) {
    CGFloat locations[] = { 0.0, 0.33, 1.0 };

    CGFloat components[] = { 0.85, 0, 0, 1.0, 1, 0, 0, 1.0, 0.85, 0.3, 0, 1.0 };
    _drawLinearGradient(GetDrawingContext(),
                        CGPointMake(120, 200),
                        CGPointMake(350, 800),
                        components,
                        locations,
                        std::extent<decltype(locations)>::value,
                        kCGGradientDrawsBeforeStartLocation);
}

DRAW_TEST_F(CGGradient, LinearGradient3, UIKitMimicTest<PixelByPixelImageComparator<PixelComparisonModeMask<64>>>) {
    CGFloat locations[] = { 0.0, 0.5, 1 };

    CGFloat components[] = {
        1, 0, 0, 1.0, 0, 1, 0, 1.0, 0, 0, 1, 1.0,
    };
    _drawLinearGradient(GetDrawingContext(),
                        CGPointMake(0, 0),
                        CGPointMake(512, 1024),
                        components,
                        locations,
                        std::extent<decltype(locations)>::value,
                        kCGGradientDrawsBeforeStartLocation);
}

DRAW_TEST_F(CGGradient, LinearGradientWithLowOpacity, UIKitMimicTest<PixelByPixelImageComparator<PixelComparisonModeMask<64>>>) {
    CGFloat locations[] = { 0.0, 0.5, 1 };

    CGFloat components[] = {
        1, 0, 0, 0.1, 0, 1, 0, 0.9, 0, 0, 1, 0.8,
    };

    _drawLinearGradient(GetDrawingContext(),
                        CGPointMake(300, 750),
                        CGPointMake(0, 0),
                        components,
                        locations,
                        std::extent<decltype(locations)>::value,
                        kCGGradientDrawsBeforeStartLocation);
}

DRAW_TEST_F(CGGradient, LinearGradientWithAlpha, UIKitMimicTest<>) {
    CGFloat locations[] = { 0.0, 0.25, 0.5, 0.6, 0.8, 0.9, 1 };

    CGFloat components[] = {
        1, 0, 0, 1, 0.4, 0.1, 0.5, 1, 0.50, 0.2, 0.99, 1, 0.41, 0.56, 0, 1, 0.12, 0.12, .3, 1, 0.9, 0.4, 1, 1, 0.2, 0.3, 0.8, 1,
    };

    CGContextSetAlpha(GetDrawingContext(), 0.75);
    _drawLinearGradient(GetDrawingContext(),
                        CGPointMake(0, 0),
                        CGPointMake(512, 1024),
                        components,
                        locations,
                        std::extent<decltype(locations)>::value,
                        kCGGradientDrawsBeforeStartLocation);
}

DRAW_TEST_F(CGGradient, LinearGradientWithLowOpacityShort, UIKitMimicTest<PixelByPixelImageComparator<PixelComparisonModeMask<64>>>) {
    CGFloat locations[] = { 0.0, 0.5, 1 };

    CGFloat components[] = {
        1, 0, 0, 0.8, 0, 1, 0, 0.9, 0, 0, 1, 0.1,
    };

    _drawLinearGradient(GetDrawingContext(),
                        CGPointMake(250, 300),
                        CGPointMake(0, 0),
                        components,
                        locations,
                        std::extent<decltype(locations)>::value,
                        kCGGradientDrawsAfterEndLocation);
}

#pragma endregion LinearGradient

#pragma region RadialGradient

DRAW_TEST_F(CGGradient, RadialSimpleDraw, UIKitMimicTest<>) {
    CGFloat components[8] = { 1.0, 1.0, 1.0, 1.0, 0.0, 0.0, 0.0, 1.0 };
    CGPoint centerpoint = { 200.0, 200.0 };

    auto colorspace = woc::MakeStrongCF<CGColorSpaceRef>(CGColorSpaceCreateDeviceRGB());
    auto gradient = woc::MakeStrongCF<CGGradientRef>(CGGradientCreateWithColorComponents(colorspace, components, NULL, 2));

    CGContextDrawRadialGradient(GetDrawingContext(), gradient, centerpoint, 0.0, centerpoint, 50.0, 0);
}

DRAW_TEST_F(CGGradient, RadialOneColor, UIKitMimicTest<>) {
    CGFloat components[] = { 0, 1, 0, 1 };
    CGFloat locations[] = { 0.3 };
    CGPoint centerpoint = { 200.0, 200.0 };

    auto colorspace = woc::MakeStrongCF<CGColorSpaceRef>(CGColorSpaceCreateDeviceRGB());
    auto gradient = woc::MakeStrongCF<CGGradientRef>(CGGradientCreateWithColorComponents(colorspace, components, locations, 1));

    CGContextDrawRadialGradient(GetDrawingContext(), gradient, centerpoint, 0.0, centerpoint, 50.0, 0);
}

struct ColorComponents {
    const char* name;
    const CGFloat* components;
    const CGFloat* locations;
    size_t count;
};
class CGGradientRadial
    : public WhiteBackgroundTest<>,
      public ::testing::WithParamInterface<::testing::tuple<ColorComponents, CGPoint, CGFloat, CGGradientDrawingOptions>> {
    CFStringRef CreateOutputFilename() {
        ColorComponents components = ::testing::get<0>(GetParam());
        CGPoint startCenter = ::testing::get<1>(GetParam());
        CGFloat endRadius = ::testing::get<2>(GetParam());
        CGGradientDrawingOptions options = ::testing::get<3>(GetParam());

        const char* optionsName;
        if (options == kCGGradientDrawsBeforeStartLocation) {
            optionsName = "startLocation";
        } else if (options == kCGGradientDrawsAfterEndLocation) {
            optionsName = "endLocation";
        } else {
            optionsName = "Unknown";
        }

        return CFStringCreateWithFormat(nullptr,
                                        nullptr,
                                        CFSTR("TestImage.CGGradient.Radial.center.(%f, %f).radius.%f.color.%s.options.%s.png"),
                                        startCenter.x,
                                        startCenter.y,
                                        endRadius,
                                        components.name,
                                        optionsName);
    }
};

DRAW_TEST_P(CGGradientRadial, DrawGradients) {
    ColorComponents comps = ::testing::get<0>(GetParam());
    CGPoint startCenter = ::testing::get<1>(GetParam());
    CGFloat endRadius = ::testing::get<2>(GetParam());
    CGGradientDrawingOptions options = ::testing::get<3>(GetParam());

    CGContextRef context = GetDrawingContext();

    auto colorspace = woc::MakeStrongCF<CGColorSpaceRef>(CGColorSpaceCreateDeviceRGB());

    auto gradient =
        woc::MakeStrongCF<CGGradientRef>(CGGradientCreateWithColorComponents(colorspace, comps.components, comps.locations, comps.count));

    CGContextDrawRadialGradient(context, gradient, startCenter, 0.0, startCenter, endRadius, options);
}

static const CGFloat tealPurpleRedBlue[] = { 0, 0.5, 0.5, 1, 0.5, 0, 0.5, 1, 1, 0, 0, 1, 0, 0, 1, 1 };
static const CGFloat tealPurpleRedBlueLoc[] = { 0.0, 0.3, 1, 0.6 };

static const ColorComponents sc_colorComponents[] = {
    { "teal.purple.red.blue", tealPurpleRedBlue, tealPurpleRedBlueLoc, 4 },
};

static const CGPoint sc_CenterPoints[] = { { 60, 80 }, { 200, 10 } };
static const CGFloat circleRadius[] = { 200, 10, 0.9 };
static const CGGradientDrawingOptions drawingOptions[] = { kCGGradientDrawsAfterEndLocation, kCGGradientDrawsBeforeStartLocation };

INSTANTIATE_TEST_CASE_P(CGGradient,
                        CGGradientRadial,
                        ::testing::Combine(::testing::ValuesIn(sc_colorComponents),
                                           ::testing::ValuesIn(sc_CenterPoints),
                                           ::testing::ValuesIn(circleRadius),
                                           ::testing::ValuesIn(drawingOptions)));

#pragma endregion RadialGradient