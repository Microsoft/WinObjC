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

#pragma once

#include <TestFramework.h>
#include <CoreGraphics/CoreGraphics.h>

#include <Starboard/SmartTypes.h>
#include "ImageComparison.h"

// Due to how templates are compiled as needed, any new usage of templates needs to be "forced" in DrawingTest.cpp

namespace testing {
template <typename TComparator = PixelByPixelImageComparator<>>
class DrawTest : public ::testing::Test {
private:
    woc::unique_cf<CGContextRef> _context;
    CGRect _bounds;
    void* _opaqueAutoreleasePool;

public:
    virtual CFStringRef CreateAdditionalTestDescription();
    virtual CFStringRef CreateOutputFilename();
    virtual CGSize CanvasSize();
    virtual void SetUpContext();

    virtual void SetUp();
    virtual void PreDraw();
    virtual void Draw();
    virtual void PostDraw();
    virtual void TearDown();

    virtual void TestBody();

    CGContextRef GetDrawingContext();
    void SetDrawingBounds(CGRect bounds);
    CGRect GetDrawingBounds();
};
}

inline CGPoint _CGRectGetCenter(CGRect rect) {
    return {
        rect.origin.x + (rect.size.width / 2.f), rect.origin.y + (rect.size.height / 2.f),
    };
}

inline CGRect _CGRectCenteredOnPoint(CGSize size, CGPoint point) {
    return {
        {
            point.x - (size.width / 2.f), point.y - (size.height / 2.f),
        },
        size,
    };
}

template <typename TComparator = PixelByPixelImageComparator<>>
class WhiteBackgroundTest : public ::testing::DrawTest<TComparator> {
protected:
    virtual void SetUpContext();
};

template <typename TComparator = PixelByPixelImageComparator<>>
class UIKitMimicTest : public WhiteBackgroundTest<TComparator> {
protected:
    virtual CGSize CanvasSize();
    virtual void SetUpContext();
};

#define _DRAW_TEST_INTERSTITIAL_CLASS_NAME(test_case_name, test_name) test_case_name##_##test_name##_Drawing
#define _DRAW_TEST_INTERSTITIAL_CLASS(test_case_name, test_name, test_fixture)                  \
    class _DRAW_TEST_INTERSTITIAL_CLASS_NAME(test_case_name, test_name) : public test_fixture { \
    public:                                                                                     \
        virtual void Draw();                                                                    \
    };
#define _DRAW_TEST_INTERSTITIAL_BODY \
    {                                \
        PreDraw();                   \
        Draw();                      \
        PostDraw();                  \
    \
}

#define DRAW_TEST_F(test_case_name, test_name, test_fixture)                   \
    _DRAW_TEST_INTERSTITIAL_CLASS(test_case_name, test_name, test_fixture)     \
    GTEST_TEST_(test_case_name,                                                \
                test_name,                                                     \
                _DRAW_TEST_INTERSTITIAL_CLASS_NAME(test_case_name, test_name), \
                ::testing::internal::GetTestTypeId())                          \
    _DRAW_TEST_INTERSTITIAL_BODY                                               \
    void _DRAW_TEST_INTERSTITIAL_CLASS_NAME(test_case_name, test_name)::Draw()

#define DRAW_TEST(test_case_name, test_name) DRAW_TEST_F(test_case_name, test_name, ::testing::DrawTest<>)

#define DISABLED_DRAW_TEST(test_case_name, test_name) DRAW_TEST(test_case_name, DISABLED_##test_name)
#define DISABLED_DRAW_TEST_F(test_case_name, test_name, test_fixture) DRAW_TEST_F(test_case_name, DISABLED_##test_name, test_fixture)

#define DRAW_TEST_P(test_case_name, test_name)                                                              \
    _DRAW_TEST_INTERSTITIAL_CLASS(test_case_name, test_name, test_case_name)                                \
    GTEST_TEST_P_(test_case_name, test_name, _DRAW_TEST_INTERSTITIAL_CLASS_NAME(test_case_name, test_name)) \
    _DRAW_TEST_INTERSTITIAL_BODY                                                                            \
    void _DRAW_TEST_INTERSTITIAL_CLASS_NAME(test_case_name, test_name)::Draw()
#define DISABLED_DRAW_TEST_P(test_case_name, test_name) DRAW_TEST_P(test_case_name, DISABLED_##test_name)

#define TEXT_DRAW_TEST(test_case_name, test_name) DRAW_TEST_F(test_case_name, test_name, ::testing::DrawTest<>)
#define TEXT_DRAW_TEST_F(test_case_name, test_name, test_fixture) DRAW_TEST_F(test_case_name, test_name, test_fixture)

#ifdef WINOBJC_DISABLE_TESTS
#define ARM_DISABLED_TEXT_DRAW_TEST_F(test_case_name, test_name, test_fixture) \
    DISABLED_DRAW_TEST_F(test_case_name, DISABLED_##test_name, test_fixture)
#else
#define ARM_DISABLED_TEXT_DRAW_TEST_F(test_case_name, test_name, test_fixture) TEXT_DRAW_TEST_F(test_case_name, test_name, test_fixture)
#endif

#define DISABLED_TEXT_DRAW_TEST(test_case_name, test_name) TEXT_DRAW_TEST(test_case_name, DISABLED_##test_name)
#define DISABLED_TEXT_DRAW_TEST_F(test_case_name, test_name, test_fixture) \
    TEXT_DRAW_TEST_F(test_case_name, DISABLED_##test_name, test_fixture)

#define TEXT_DRAW_TEST_P(test_case_name, test_name) DRAW_TEST_P(test_case_name, test_name)
#define DISABLED_TEXT_DRAW_TEST_P(test_case_name, test_name) TEXT_DRAW_TEST_P(test_case_name, DISABLED_##test_name)