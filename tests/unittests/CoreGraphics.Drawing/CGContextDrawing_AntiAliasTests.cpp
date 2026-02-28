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
#include <Starboard/SmartTypes.h>
#include <CoreText/CoreText.h>

class CGContextArcAA : public WhiteBackgroundTest<>, public ::testing::WithParamInterface<::testing::tuple<int, CGPoint>> {
    CFStringRef CreateOutputFilename() {
        int useAA = ::testing::get<0>(GetParam());
        CGPoint origin = ::testing::get<1>(GetParam());
        return CFStringCreateWithFormat(nullptr, nullptr, CFSTR("ArcAA_%d_%f.png"), useAA, origin.x);
    }
};

class CGContextLineAA : public WhiteBackgroundTest<>, public ::testing::WithParamInterface<::testing::tuple<int, CGPoint>> {
    CFStringRef CreateOutputFilename() {
        int useAA = ::testing::get<0>(GetParam());
        CGPoint origin = ::testing::get<1>(GetParam());
        return CFStringCreateWithFormat(nullptr, nullptr, CFSTR("LineAA_%d_%f.png"), useAA, origin.x);
    }
};

class CGContextTextAA : public WhiteBackgroundTest<>, public ::testing::WithParamInterface<::testing::tuple<int, int, int, int, CGPoint>> {
    CFStringRef CreateOutputFilename() {
        int useAA = ::testing::get<0>(GetParam());
        int useSmoothing = ::testing::get<1>(GetParam());
        int useSubpixel = ::testing::get<2>(GetParam());
        int useQuantization = ::testing::get<3>(GetParam());
        CGPoint origin = ::testing::get<4>(GetParam());
        return CFStringCreateWithFormat(
            nullptr, nullptr, CFSTR("TextAA_%d_%d_%d_%d_%f.png"), useAA, useSmoothing, useSubpixel, useQuantization, origin.x);
    }
};

static std::vector<CGGlyph> __CreateGlyphs() {
    UniChar chars[4] = { 'T', 'E', 'S', 'T' };
    std::vector<CGGlyph> glyphs(4);
    woc::unique_cf<CTFontRef> ctfont{ CTFontCreateWithName(CFSTR("Arial"), 144, nullptr) };
    CTFontGetGlyphsForCharacters(ctfont.get(), chars, glyphs.data(), 4);
    return glyphs;
}

static void __SetFontForContext(CGContextRef context) {
    woc::unique_cf<CGFontRef> font{ CGFontCreateWithFontName(CFSTR("Arial")) };
    CGContextSetFont(context, font.get());
    CGContextSetFontSize(context, 144);
}

static void __SetContextToggles(CGContextRef context, int useAA, int useSmoothing, int useSubpixel, int useQuantization) {
    // General AA
    if (useAA != 2) {
        CGContextSetAllowsAntialiasing(context, useAA == 1);
        CGContextSetShouldAntialias(context, useAA == 1);
    }

    // Smoothing
    if (useSmoothing != 2) {
        CGContextSetAllowsFontSmoothing(context, useSmoothing == 1);
        CGContextSetShouldSmoothFonts(context, useSmoothing == 1);
    }

    // SubPixel
    if (useSubpixel != 2) {
        CGContextSetAllowsFontSubpixelPositioning(context, useSubpixel == 1);
        CGContextSetShouldSubpixelPositionFonts(context, useSubpixel == 1);
    }

    // Quantization
    if (useQuantization != 2) {
        CGContextSetAllowsFontSubpixelQuantization(context, useQuantization == 1);
        CGContextSetShouldSubpixelQuantizeFonts(context, useQuantization == 1);
    }
}

DRAW_TEST_P(CGContextArcAA, ContextAntialiasArcs) {
    CGContextRef context = GetDrawingContext();

    int useAA = ::testing::get<0>(GetParam());
    CGPoint origin = ::testing::get<1>(GetParam());
    __SetContextToggles(context, useAA, 2, 2, 2);

    CGRect bounds = GetDrawingBounds();
    CGFloat width = bounds.size.width;
    CGFloat height = bounds.size.height;
    CGFloat xstart = bounds.origin.x + origin.x;
    CGFloat ystart = bounds.origin.y + origin.y;

    CGMutablePathRef thepath = CGPathCreateMutable();

    CGAffineTransform transformation = CGAffineTransformIdentity;
    transformation = CGAffineTransformScale(transformation, .8, .8);
    transformation = CGAffineTransformTranslate(transformation, .1 * width, .1 * height);

    CGPathMoveToPoint(thepath, &transformation, xstart + .75 * width, ystart + .5 * height);
    CGPathAddArc(thepath, &transformation, xstart + .5 * width, ystart + .5 * height, .5 * height, 0, M_PI / 2, true);
    CGPathAddArc(thepath, &transformation, xstart + .5 * width, ystart + .5 * height, .5 * height, M_PI / 2, 0, true);
    CGPathMoveToPoint(thepath, &transformation, xstart + .25 * width, ystart + .5 * height);
    CGPathAddArc(thepath, &transformation, xstart + .375 * width, ystart + .5 * height, .25 * height, M_PI, 0, false);
    CGPathMoveToPoint(thepath, &transformation, xstart + .5 * width, ystart + .5 * height);
    CGPathAddArc(thepath, &transformation, xstart + .625 * width, ystart + .5 * height, .25 * height, M_PI, 0, true);
    CGPathMoveToPoint(thepath, &transformation, xstart + .4375 * width, ystart + .5 * height);
    CGPathAddArc(thepath, &transformation, xstart + .375 * width, ystart + .5 * height, .125 * height, 0, M_PI / 2, true);
    CGPathAddArc(thepath, &transformation, xstart + .375 * width, ystart + .5 * height, .125 * height, M_PI / 2, 0, true);
    CGPathMoveToPoint(thepath, &transformation, xstart + .6875 * width, ystart + .5 * height);
    CGPathAddArc(thepath, &transformation, xstart + .625 * width, ystart + .5 * height, .125 * height, 0, M_PI / 2, true);
    CGPathAddArc(thepath, &transformation, xstart + .625 * width, ystart + .5 * height, .125 * height, M_PI / 2, 0, true);

    CGContextAddPath(context, thepath);
    CGContextStrokePath(context);

    CGPathRelease(thepath);
}

DRAW_TEST_P(CGContextLineAA, ContextAntialiasLines) {
    CGContextRef context = GetDrawingContext();

    int useAA = ::testing::get<0>(GetParam());
    CGPoint origin = ::testing::get<1>(GetParam());
    __SetContextToggles(context, useAA, 2, 2, 2);

    CGMutablePathRef thepath = CGPathCreateMutable();
    CGPathMoveToPoint(thepath, NULL, origin.x + 200, origin.y + 35);
    CGPathAddLineToPoint(thepath, NULL, origin.x + 165, origin.y + 100);
    CGPathAddLineToPoint(thepath, NULL, origin.x + 100, origin.y + 100);
    CGPathAddLineToPoint(thepath, NULL, origin.x + 150, origin.y + 150);
    CGPathAddLineToPoint(thepath, NULL, origin.x + 135, origin.y + 225);
    CGPathAddLineToPoint(thepath, NULL, origin.x + 200, origin.y + 170);
    CGPathAddLineToPoint(thepath, NULL, origin.x + 265, origin.y + 225);
    CGPathAddLineToPoint(thepath, NULL, origin.x + 250, origin.y + 150);
    CGPathAddLineToPoint(thepath, NULL, origin.x + 300, origin.y + 100);
    CGPathAddLineToPoint(thepath, NULL, origin.x + 235, origin.y + 100);

    // Unnecessary as close subpath will finish this line off but for the sake of consistency, have this here.
    CGPathAddLineToPoint(thepath, NULL, origin.x + 200, origin.y + 35);

    CGPathCloseSubpath(thepath);
    CGContextAddPath(context, thepath);
    CGContextStrokePath(context);

    CGPathRelease(thepath);
}

DRAW_TEST_P(CGContextTextAA, ContextAntialiasText) {
    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();

    int useAA = ::testing::get<0>(GetParam());
    int useSmoothing = ::testing::get<1>(GetParam());
    int useSubpixel = ::testing::get<2>(GetParam());
    int useQuantization = ::testing::get<3>(GetParam());
    CGPoint origin = ::testing::get<4>(GetParam());
    __SetContextToggles(context, useAA, useSmoothing, useSubpixel, useQuantization);

    std::vector<CGGlyph> glyphs{ __CreateGlyphs() };
    __SetFontForContext(context);
    CGContextSetTextPosition(context, origin.x, origin.y);
    CGContextShowGlyphs(context, glyphs.data(), glyphs.size());
}

int toggles[] = { 2, 1, 0 };
CGPoint points[] = { { 0, 0 }, { .25, .25 }, { .5, .5 }, { .75, .75 } };

// TODO GH#2107 These text antialiasing tests differ slightly on the build machine.
// However, the negative cases work properly.
// We can't add a threshold here since that would defeat the purpose of having them in the first place.
int positiveToggles[] = { 2, 1 };
DISABLED_INSTANTIATE_TEST_CASE_P(TextAntialias,
                                 CGContextTextAA,
                                 ::testing::Combine(::testing::Values(0),
                                                    ::testing::Values(0),
                                                    ::testing::Values(0),
                                                    ::testing::Values(0),
                                                    ::testing::ValuesIn(points)),
                                 ::testing::Combine(::testing::ValuesIn(positiveToggles),
                                                    ::testing::ValuesIn(positiveToggles),
                                                    ::testing::ValuesIn(positiveToggles),
                                                    ::testing::ValuesIn(positiveToggles),
                                                    ::testing::ValuesIn(points)));

INSTANTIATE_TEST_CASE_P(PathLineAntialias, CGContextLineAA, ::testing::Combine(::testing::ValuesIn(toggles), ::testing::ValuesIn(points)));

INSTANTIATE_TEST_CASE_P(PathArcAntialias, CGContextArcAA, ::testing::Combine(::testing::ValuesIn(toggles), ::testing::ValuesIn(points)));
