//******************************************************************************
//
// Copyright Microsoft Corporation. All rights reserved.
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
#import <Foundation/NSThread.h>
#import <Starboard/SmartTypes.h>
#import <UIKit/UIView.h>
#import "UWP/WindowsUIXamlControls.h"

#import "FunctionalTestHelpers.h"
#import "UXTestHelpers.h"

#import "UIKitControls/UILabelViewController.h"
#import <ObjcXamlControls.h>
#import <../Frameworks/UIkit/XamlUtilities.h>

class UILabelTests {
    // array of dictionary for expected values from reference platform
    StrongId<NSMutableArray> expectedResultArray;

    // CGRect/CGSize allowedDifference when cmparing to x,y,width,height
    const float allowedDistance = 1.0f;

    int testId;

    // some test statistic counters
    int intrinsicContentSizeTestFailureCount;
    int intrinsicContentSizeTestIgoredCount;

    int sizeThatFitTestFailureCount;
    int sizeThatFitTestIgoreCount;

    int textRectForBoundsTestFailureCount;
    int textRectForBoundsTestIgnoreCount;

    BOOL isLabelVCPresented;

public:
    BEGIN_TEST_CLASS(UILabelTests)
    END_TEST_CLASS()

    TEST_CLASS_SETUP(UILabelTestsClassSetup) {
        // do one time loading for expected results from reference platform
        // uilabel-ios.xml is generated on reference platform using UILabelViewController
        StrongId<NSString> testFilePath = appendPathRelativeToFTModule(@"uilabel-ios.xml");
        expectedResultArray.attach([NSArray arrayWithContentsOfFile:testFilePath]);

        return FunctionalTestSetupUIApplication();
    }

    TEST_CLASS_CLEANUP(UILabelTestsClassCleanup) {
        return FunctionalTestCleanupUIApplication();
    }

    TEST_METHOD(UILabel_VerifyCriticalUILabelSizes) {
        // NOTE: this one test case actually comprises of 6300 sub tests

        StrongId<UILabelViewController> labelVC;
        labelVC.attach([[UILabelViewController alloc] init]);
        UXTestAPI::ViewControllerPresenter testHelper(labelVC);

        // enumerating UILabel on UILabelVC with combinatons of the following config
        // setAdjustFontSizeToFitWidth/minmumFontSize/MinimumScaleFactor/NumberOfLines/LineBreakMode/FontSize
        // and then calling IntrisincontentSize/sizeThatFits/textRectForBounds
        startTests(labelVC);
    }

    void startTests(UILabelViewController* self) {
        testId = 0;

        // initialize the counters
        intrinsicContentSizeTestFailureCount;
        intrinsicContentSizeTestIgoredCount;

        sizeThatFitTestFailureCount = 0;
        sizeThatFitTestIgoreCount = 0;

        textRectForBoundsTestFailureCount = 0;
        textRectForBoundsTestIgnoreCount = 0;

        if (self) {
            // use the default Label text which is the one used
            // to generate the expected value on reference platform
            dispatch_sync(dispatch_get_main_queue(), ^{
                self.label.text = self.defaultLabelText;
            });

            // enumerate the setAdjustFontSizeToFitWidth (or autoFit)
            for (int autoFit = 0; autoFit <= 1; autoFit++) {
                dispatch_sync(dispatch_get_main_queue(), ^{
                    self.autoShrink.on = (BOOL)autoFit;
                    [self autoShrinkChanged:self.autoShrink];
                });

                if (autoFit == 1) {
                    // setAdjustFontSizeToFitWidth is YES, enumerate miniFontSize or ScaleFactor
                    for (int useMinScaleFactor = 0; useMinScaleFactor <= 1; useMinScaleFactor++) {
                        if (useMinScaleFactor) {
                            for (float minScaleFactor = 0.1; minScaleFactor < 1.0; minScaleFactor += 0.4) {
                                dispatch_sync(dispatch_get_main_queue(), ^{
                                    self.minimumScaleFactor.text = [NSString stringWithFormat:@"%5.1f", minScaleFactor];
                                    [self textFieldEditDidEnd:self.minimumScaleFactor];
                                });

                                // enumerate NumberOfLines/LineBreak/FontSize
                                enumerateNumberOfLinesLinBreakFontSize(self);
                            }
                        } else {
                            float minFontSizeStep = self.label.font.pointSize / 3.0f;
                            for (float minFontSize = 0.1; minFontSize < self.label.font.pointSize; minFontSize += minFontSizeStep) {
                                dispatch_sync(dispatch_get_main_queue(), ^{
                                    self.minimumFontSize.text = [NSString stringWithFormat:@"%5.2f", minFontSize];
                                    [self textFieldEditDidEnd:self.minimumFontSize];
                                });

                                // enumerate NumberOfLines/LineBreak/FontSize
                                enumerateNumberOfLinesLinBreakFontSize(self);
                            }
                        }
                    }
                } else {
                    // setAdjustFontSizeToFitWidth is NO, enumerate NumberOfLines/LineBreak/FontSize
                    enumerateNumberOfLinesLinBreakFontSize(self);
                }
            }
        }

        // print out some test statistics
        int totalTestCount = testId * 3;
        int totoalTestIgnoredCount = intrinsicContentSizeTestIgoredCount + sizeThatFitTestIgoreCount + textRectForBoundsTestIgnoreCount;
        int totalTestFailureCount = intrinsicContentSizeTestFailureCount + sizeThatFitTestFailureCount + textRectForBoundsTestFailureCount;

        LOG_INFO("Total %d tests: %d failed , %d ignored , %d succeed",
                 totalTestCount,
                 totalTestFailureCount,
                 totoalTestIgnoredCount,
                 totalTestCount - totoalTestIgnoredCount - totalTestFailureCount);
        LOG_INFO("intrinsicContentSize Total %d tests failed, %d ignored, %d succeeded ",
                 intrinsicContentSizeTestFailureCount,
                 intrinsicContentSizeTestIgoredCount,
                 testId - intrinsicContentSizeTestFailureCount - intrinsicContentSizeTestIgoredCount);
        LOG_INFO("sizeThatFits total %d tests failed, %d ignored, %d succeeded ",
                 sizeThatFitTestFailureCount,
                 sizeThatFitTestIgoreCount,
                 testId - sizeThatFitTestFailureCount - sizeThatFitTestIgoreCount);
        LOG_INFO("TextRect total %d tests failed, %d ignored; %d succeeded ",
                 textRectForBoundsTestFailureCount,
                 textRectForBoundsTestIgnoreCount,
                 testId - textRectForBoundsTestFailureCount - textRectForBoundsTestIgnoreCount);
    }

    BOOL CGSizeIsWithInDistance(CGSize sizeA, CGSize sizeB, float delta) {
        float widthDifference = std::abs(sizeA.width - sizeB.width);
        float heightDifference = std::abs(sizeA.height - sizeB.height);
        if (widthDifference < delta && heightDifference < delta) {
            return YES;
        } else {
            LOG_WARNING("widthDifference %f or heightDifference %f is larger than allowed distance %f",
                        widthDifference,
                        heightDifference,
                        delta);
            return NO;
        }
    }

    BOOL CGRectIsWithInDistance(CGRect rectA, CGRect rectB, float delta) {
        float xDifference = std::abs(rectA.origin.x - rectB.origin.x);
        float yDifference = std::abs(rectA.origin.y - rectB.origin.y);

        if (xDifference < delta && yDifference < delta) {
            return CGSizeIsWithInDistance(rectA.size, rectB.size, delta);
        } else {
            LOG_WARNING("xDifference %f or yDifference %f is larger than allowed distance %f", xDifference, yDifference, delta);
        }

        return NO;
    }

    void enumerateNumberOfLinesLinBreakFontSize(UILabelViewController* self) {
        // enumerate numberOfLines
        for (int numberOfLines = 0; numberOfLines <= 4; numberOfLines++) {
            dispatch_sync(dispatch_get_main_queue(), ^{
                self.numberOfLines.text = [NSString stringWithFormat:@"%d", numberOfLines];
                [self textFieldEditDidEnd:self.numberOfLines];
            });

            // enumerate lineBreakMode
            for (int lineBreakMode = 0; lineBreakMode <= (int)NSLineBreakByTruncatingMiddle; lineBreakMode++) {
                dispatch_sync(dispatch_get_main_queue(), ^{
                    self.lineBreakMode.text = [NSString stringWithFormat:@"%d", lineBreakMode];
                    [self textFieldEditDidEnd:self.lineBreakMode];
                });

                // enumerate fontSize
                const float sizeIncreaseStep = 8.00f;

                __block float min;
                __block float max;
                dispatch_sync(dispatch_get_main_queue(), ^{
                    min = self.fontSize.minimumValue;
                    max = self.fontSize.maximumValue;
                });

                for (float size = min; size <= max; size += sizeIncreaseStep) {
                    dispatch_sync(dispatch_get_main_queue(), ^{
                        self.fontSize.value = size;

                        // this line trigger UILabel in LabelVC to apply the config set
                        [self fontSizeChanged:self.fontSize];

                        // triger VC to update sizes on UILabel that we want to compare
                        [self updateLog];

                        // locate the expected intrisincontentSize from expected result array
                        // and get the actual intrisincontentSize from UILabel in VC
                        CGSize expectedIntrinicContentSize =
                            CGSizeFromString([expectedResultArray[testId] objectForKey:@"IntrinicContentSize"]);
                        CGSize actualIntrinicContentSize = self.intrinsicContentSize;

                        // verify expected and actual intrisincontentSize are close enough
                        BOOL ret = CGSizeIsWithInDistance(expectedIntrinicContentSize, actualIntrinicContentSize, allowedDistance);
                        EXPECT_TRUE(ret);
                        if (!ret) {
                            intrinsicContentSizeTestFailureCount++;
                        }

                        // check if we need skip the test because of known gap or issues.

                        // #2157 UIlabel does not support the linebreak modes like characater wrap, head truncation, middle truncation.
                        // we will ignore tests for these lineBreakMode settings.
                        BOOL skipTest = (lineBreakMode == (int)NSLineBreakByCharWrapping) ||
                                        lineBreakMode == (int)NSLineBreakByTruncatingHead ||
                                        lineBreakMode == (int)NSLineBreakByTruncatingMiddle;

                        if (!skipTest) {
                            // #2158 UILabel:sizeThatFits has around 1/4 of functional test failure when numberOfLines is bigger than�1�(
                            // e.g., 2, 3 )
                            // we ignored these tests for now until #2158 is closed
                            skipTest = numberOfLines > 1;
                        }

                        if (!skipTest) {
                            CGSize expectedSizeThatFits = CGSizeFromString([expectedResultArray[testId] objectForKey:@"sizeThatFits"]);
                            CGRect expectedTextRect = CGRectFromString([expectedResultArray[testId] objectForKey:@"textRect"]);

                            // get the actual sizes or rect
                            CGSize actualSizeThatFits = self.sizeThatFits;
                            CGRect actualTextRect = self.textRect;

                            ret = CGSizeIsWithInDistance(expectedSizeThatFits, actualSizeThatFits, allowedDistance);
                            EXPECT_TRUE(ret);
                            if (!ret) {
                                sizeThatFitTestFailureCount++;
                            }

                            // #2159 UILabel:TextRectForBounds�tests has many failures in funtional tests
                            // we will re-open these tests until #2159 is closed.
                            const BOOL skipVerifyTextRectForBounds = YES;
                            if (!skipVerifyTextRectForBounds) {
                                ret = CGRectIsWithInDistance(expectedTextRect, actualTextRect, allowedDistance);
                                EXPECT_TRUE(ret);
                                if (!ret) {
                                    textRectForBoundsTestFailureCount++;
                                }
                            } else {
                                textRectForBoundsTestIgnoreCount++;
                            }
                        } else {
                            sizeThatFitTestIgoreCount++;
                            textRectForBoundsTestIgnoreCount++;
                        }

                        testId++;
                    });
                }
            }
        }
    }

    TEST_METHOD(UILabel_VerifyNumberOfLines) {
        StrongId<UILabelViewController> labelVC;
        labelVC.attach([[UILabelViewController alloc] init]);
        UXTestAPI::ViewControllerPresenter testHelper(labelVC);

        UILabel* label = [labelVC label];

        dispatch_sync(dispatch_get_main_queue(), ^{
            // get the backing xaml element, which is Grid contains textBlock
            WXCGrid* labelGrid = rt_dynamic_cast<WXCGrid>([label xamlElement]);
            Microsoft::WRL::ComPtr<IInspectable> inspectable(XamlGetLabelTextBlock([labelGrid comObj]));
            WXCTextBlock* textBlock = _createRtProxy([WXCTextBlock class], inspectable.Get());
            ASSERT_OBJCNE(textBlock, nil);

            // verify default value is 1
            ASSERT_TRUE(label.numberOfLines == 1);
            ASSERT_TRUE(textBlock.maxLines == 1);

            // verify setting to different values other than default
            label.numberOfLines = 0;
            ASSERT_TRUE(textBlock.maxLines == 0);

            label.numberOfLines = 3;
            ASSERT_TRUE(textBlock.maxLines == 3);

            label.numberOfLines = 7;
            ASSERT_TRUE(textBlock.maxLines == 7);

        });
    }

    TEST_METHOD(UILabel_VerifyLinBreakMode) {
        StrongId<UILabelViewController> labelVC;
        labelVC.attach([[UILabelViewController alloc] init]);
        UXTestAPI::ViewControllerPresenter testHelper(labelVC);

        UILabel* label = [labelVC label];

        dispatch_sync(dispatch_get_main_queue(), ^{
            // get the backing xaml element, which is Grid contains textBlock
            WXCGrid* labelGrid = rt_dynamic_cast<WXCGrid>([label xamlElement]);
            Microsoft::WRL::ComPtr<IInspectable> inspectable(XamlGetLabelTextBlock([labelGrid comObj]));
            WXCTextBlock* textBlock = _createRtProxy([WXCTextBlock class], inspectable.Get());
            ASSERT_OBJCNE(textBlock, nil);

            // verify default value is NSLineBreakByTruncatingTail
            // For xaml element, there is no wrapping and using character Ellipsis
            ASSERT_TRUE(label.numberOfLines == 1);
            ASSERT_TRUE(label.lineBreakMode == NSLineBreakByTruncatingTail);
            ASSERT_TRUE(textBlock.textWrapping = WXTextWrappingNoWrap);
            ASSERT_TRUE(textBlock.textTrimming = WXTextTrimmingCharacterEllipsis);

            // verify when numberOfLines is 1, setting linebreak mode to
            // either NSLineBreakByCharWrapping/NSLineBreakByWordWrapping
            // does not impact xaml element wrapping beahviour
            label.lineBreakMode = NSLineBreakByCharWrapping;
            ASSERT_TRUE(textBlock.textWrapping = WXTextWrappingNoWrap);

            label.lineBreakMode = NSLineBreakByWordWrapping;
            ASSERT_TRUE(textBlock.textWrapping = WXTextWrappingNoWrap);

            // change numberOfLines to 2 and set to NSLineBreakByWordWrapping/
            label.numberOfLines == 2;

            // verify textBlock wrapping property is set to WordWrap
            label.lineBreakMode = NSLineBreakByWordWrapping;
            ASSERT_TRUE(textBlock.textWrapping = WXTextWrappingWrap);

            // NOTE: vierfy textBlock wrapping property is also set to WXTextWrappingWrap
            // because of platform Gap
            label.lineBreakMode = NSLineBreakByCharWrapping;
            ASSERT_TRUE(textBlock.textWrapping = WXTextWrappingWrap);

            // NSLineBreakByClipping is supported
            label.lineBreakMode = NSLineBreakByClipping;
            ASSERT_TRUE(textBlock.textTrimming = WXTextTrimmingClip);

            // NOTE: verify when set to NSLineBreakByTruncatingHead/WXTextTrimmingCharacterEllipsis,
            // we overwrite it with TailTruncation on xaml because of platform gap
            label.lineBreakMode = NSLineBreakByTruncatingHead;
            ASSERT_TRUE(textBlock.textTrimming = WXTextTrimmingCharacterEllipsis);

            label.lineBreakMode = NSLineBreakByTruncatingMiddle;
            ASSERT_TRUE(textBlock.textTrimming = WXTextTrimmingCharacterEllipsis);
        });
    }

    TEST_METHOD(UILabel_VerifyTextAlignment) {
        StrongId<UILabelViewController> labelVC;
        labelVC.attach([[UILabelViewController alloc] init]);
        UXTestAPI::ViewControllerPresenter testHelper(labelVC);

        UILabel* label = [labelVC label];

        dispatch_sync(dispatch_get_main_queue(), ^{
            // get the backing xaml element, which is Grid contains textBlock
            WXCGrid* labelGrid = rt_dynamic_cast<WXCGrid>([label xamlElement]);
            Microsoft::WRL::ComPtr<IInspectable> inspectable(XamlGetLabelTextBlock([labelGrid comObj]));
            WXCTextBlock* textBlock = _createRtProxy([WXCTextBlock class], inspectable.Get());
            ASSERT_OBJCNE(textBlock, nil);

            // verify default value is left
            ASSERT_TRUE(textBlock.textAlignment == WXTextAlignmentLeft);

            // verify setting alignmnet to others
            label.textAlignment = UITextAlignmentRight;
            ASSERT_TRUE(textBlock.textAlignment == WXTextAlignmentRight);

            label.textAlignment = UITextAlignmentCenter;
            ASSERT_TRUE(textBlock.textAlignment == WXTextAlignmentCenter);

            label.textAlignment = UITextAlignmentLeft;
            ASSERT_TRUE(textBlock.textAlignment == WXTextAlignmentLeft);
        });
    }

    TEST_METHOD(UILabel_VerifyText) {
        StrongId<UILabelViewController> labelVC;
        labelVC.attach([[UILabelViewController alloc] init]);
        UXTestAPI::ViewControllerPresenter testHelper(labelVC);

        UILabel* label = [labelVC label];

        dispatch_sync(dispatch_get_main_queue(), ^{
            // get the backing xaml element, which is Grid contains textBlock
            WXCGrid* labelGrid = rt_dynamic_cast<WXCGrid>([label xamlElement]);
            Microsoft::WRL::ComPtr<IInspectable> inspectable(XamlGetLabelTextBlock([labelGrid comObj]));
            WXCTextBlock* textBlock = _createRtProxy([WXCTextBlock class], inspectable.Get());
            ASSERT_OBJCNE(textBlock, nil);

            label.text = @"short";
            ASSERT_OBJCEQ(textBlock.text, label.text);

            label.text = @"this is a long string for testing.";
            ASSERT_OBJCEQ(textBlock.text, label.text);

            label.text = nil;
            EXPECT_OBJCEQ(textBlock.text, label.text);

            // #2174 Projection: after setting text property of WXCTextBlock to empty string @"" and then try to access the property, the
            // value returns NULL
            // label.text = @"";
            // EXPECT_OBJCEQ(textBlock.text, label.text);
        });
    }

    TEST_METHOD(UILabel_VerifyTextColor) {
        StrongId<UILabelViewController> labelVC;
        labelVC.attach([[UILabelViewController alloc] init]);
        UXTestAPI::ViewControllerPresenter testHelper(labelVC);

        UILabel* label = [labelVC label];

        dispatch_sync(dispatch_get_main_queue(), ^{
            // get the backing xaml element, which is Grid contains textBlock
            WXCGrid* labelGrid = rt_dynamic_cast<WXCGrid>([label xamlElement]);
            Microsoft::WRL::ComPtr<IInspectable> inspectable(XamlGetLabelTextBlock([labelGrid comObj]));
            WXCTextBlock* textBlock = _createRtProxy([WXCTextBlock class], inspectable.Get());

            ASSERT_TRUE(!label.highlighted);

            ASSERT_OBJCNE(textBlock, nil);

            // Verify default textcolor
            EXPECT_OBJCEQ(label.textColor, [UIColor blackColor]);

            WUXMSolidColorBrush* colorBrush = rt_dynamic_cast<WUXMSolidColorBrush>(textBlock.foreground);
            ASSERT_TRUE(colorBrush != nil);
            EXPECT_OBJCEQ(UXTestAPI::ConvertWUColorToUIColor(colorBrush.color), label.textColor);

            // verify setting color to others
            label.textColor = [UIColor redColor];
            colorBrush = rt_dynamic_cast<WUXMSolidColorBrush>(textBlock.foreground);
            ASSERT_TRUE(colorBrush != nil);
            EXPECT_OBJCEQ(UXTestAPI::ConvertWUColorToUIColor(colorBrush.color), label.textColor);

            label.textColor = [UIColor greenColor];
            colorBrush = rt_dynamic_cast<WUXMSolidColorBrush>(textBlock.foreground);
            ASSERT_TRUE(colorBrush != nil);
            EXPECT_OBJCEQ(UXTestAPI::ConvertWUColorToUIColor(colorBrush.color), label.textColor);

            // verify setting highlightedColor without changing UILabel state to highlighted state
            // the label's text color should not change
            label.highlightedTextColor = [UIColor blueColor];
            colorBrush = rt_dynamic_cast<WUXMSolidColorBrush>(textBlock.foreground);
            ASSERT_TRUE(colorBrush != nil);
            EXPECT_OBJCEQ(UXTestAPI::ConvertWUColorToUIColor(colorBrush.color), label.textColor);

            // now change the UILabel's state to be highlighted, and textblock's foreground should be using highlightedTextColor
            label.highlighted = YES;
            colorBrush = rt_dynamic_cast<WUXMSolidColorBrush>(textBlock.foreground);
            ASSERT_TRUE(colorBrush != nil);
            EXPECT_OBJCEQ(UXTestAPI::ConvertWUColorToUIColor(colorBrush.color), label.highlightedTextColor);

            // now change the UILabel's state to be normal, verify textBlock's forground return to use original textColor
            label.highlighted = NO;
            colorBrush = rt_dynamic_cast<WUXMSolidColorBrush>(textBlock.foreground);
            ASSERT_TRUE(colorBrush != nil);
            EXPECT_OBJCEQ(UXTestAPI::ConvertWUColorToUIColor(colorBrush.color), label.textColor);
        });
    }

    TEST_METHOD(UILabel_VerifyFont) {
        StrongId<UILabelViewController> labelVC;
        labelVC.attach([[UILabelViewController alloc] init]);
        UXTestAPI::ViewControllerPresenter testHelper(labelVC);

        UILabel* label = [labelVC label];

        dispatch_sync(dispatch_get_main_queue(), ^{
            // get the backing xaml element, which is Grid contains textBlock
            WXCGrid* labelGrid = rt_dynamic_cast<WXCGrid>([label xamlElement]);
            Microsoft::WRL::ComPtr<IInspectable> inspectable(XamlGetLabelTextBlock([labelGrid comObj]));
            WXCTextBlock* textBlock = _createRtProxy([WXCTextBlock class], inspectable.Get());

            // verify default label font size
            ASSERT_TRUE([label.font pointSize] == [UIFont labelFontSize]);

            // change font size and verify label font has changed
            label.font = [label.font fontWithSize:100];
            ASSERT_TRUE([label.font pointSize] == 100);

            // set adjust font size to be TRUE, verify font size didn't change
            [label setAdjustsFontSizeToFitWidth:YES];
            ASSERT_TRUE([label.font pointSize] == 100);

            // turn off auto-fit and change font size to be very small
            [label setAdjustsFontSizeToFitWidth:NO];
            label.font = [label.font fontWithSize:1];

            // verify font didn't scale up when turn on autofit again
            [label setAdjustsFontSizeToFitWidth:YES];
            ASSERT_TRUE([label.font pointSize] == 1);
        });
    }
};