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

#import <UIkit/UISlider.h>
#import "UILabelViewController.h"
#import <MobileCoreServices/MobileCoreServices.h>

@implementation UILabelViewController {
    int _eventId;
    MenuTableViewController* _menuTVC;

#ifndef WINOBJC
    // log array used only in reference platform to keep the expected values
    NSMutableArray* logArray;
#endif
}

// setting up the controls to update the UILabel config
- (void)_setup {
    _menuTVC = [[MenuTableViewController alloc] init];
    _menuTVC.view.frame = CGRectMake(0.0f, 108.0f, 200.0f, 0.0f /* setting it to 0 allows vertical scrolling */);
    _menuTVC.tableView.allowsSelection = NO;
    [self.view addSubview:_menuTVC.view];

    self.text = [[UITextField alloc] initWithFrame:CGRectMake(105.0f, 20.0f, 400.0f, 30.0f)];
    [_menuTVC addMenuItemView:self.text andTitle:@"text on label"];

    self.fontSize = [[UISlider alloc] initWithFrame:CGRectMake(101.0f, 54.0f, 187.0f, 31.0f)];
    self.fontSize.minimumValue = 4.01f;
    self.fontSize.maximumValue = 80;
    [_menuTVC addMenuItemView:self.fontSize andTitle:@"Font Size"];

    self.fontSizeLabel = [[UILabel alloc] initWithFrame:CGRectMake(297.0f, 57.0f, 53.0f, 25.0f)];
    [_menuTVC addMenuItemView:self.fontSizeLabel andTitle:@"current Font Size"];

    self.numberOfLines = [[UITextField alloc] initWithFrame:CGRectMake(104.0f, 132.0f, 32.0f, 30.0f)];
    [_menuTVC addMenuItemView:self.numberOfLines andTitle:@"Number of lines"];

    self.lineBreakMode = [[UITextField alloc] initWithFrame:CGRectMake(207.0f, 132.0f, 32.0f, 30.0f)];
    [_menuTVC addMenuItemView:self.lineBreakMode andTitle:@"line break Mode"];

    self.autoShrink = [[UISwitch alloc] initWithFrame:CGRectMake(310.0f, 131.0f, 51.0f, 31.0f)];
    [_menuTVC addMenuItemView:self.autoShrink andTitle:@"Adjust font size to fit width"];

    self.minimumFontSize = [[UITextField alloc] initWithFrame:CGRectMake(80.0f, 167.0f, 56.0f, 30.0f)];
    [_menuTVC addMenuItemView:self.minimumFontSize andTitle:@"Minimum font size"];

    self.minimumScaleFactor = [[UITextField alloc] initWithFrame:CGRectMake(239.0f, 167.0f, 56.0f, 30.0f)];
    [_menuTVC addMenuItemView:self.minimumScaleFactor andTitle:@"Minimum scale factor"];

    self.x = [[UITextField alloc] initWithFrame:CGRectMake(74.0f, 92.0f, 45.0f, 30.0f)];
    [_menuTVC addMenuItemView:self.x andTitle:@"Bounding Rect origin x"];

    self.y = [[UITextField alloc] initWithFrame:CGRectMake(141.0f, 92.0f, 45.0f, 30.0f)];
    [_menuTVC addMenuItemView:self.y andTitle:@"Bounding Rect origin y"];

    self.w = [[UITextField alloc] initWithFrame:CGRectMake(211.0f, 92.0f, 45.0f, 30.0f)];
    [_menuTVC addMenuItemView:self.w andTitle:@"Bounding Rect width"];

    self.h = [[UITextField alloc] initWithFrame:CGRectMake(293.0f, 92.0f, 45.0f, 30.0f)];
    [_menuTVC addMenuItemView:self.h andTitle:@"Bounding Rect height"];

    self.label = [[UILabel alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 353.0f, 107.0f)];
    [self.view addSubview:self.label];

    self.start = [[UIButton alloc] initWithFrame:CGRectMake(4.0f, 426.0f, 46.0f, 30.0f)];
    [self.start setTitle:@"Start" forState:UIControlStateNormal];
    [self.start setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
    [_menuTVC addMenuItemView:self.start andTitle:@"Click to generate test"];

    self.defaultLabelText = @"This is a test string used to test UILabel - and it should wrap and can be as long as three lines";
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor whiteColor];
    self.view.frame = CGRectMake(0.0f, 0.0f, 200.0f, 0.0f);

#ifndef WINOBJC
    // init the log array
    logArray = [[NSMutableArray alloc] init];
#endif

    // creating control default value using label value
    [self _setup];

    self.view.frame = CGRectMake(0.0f, 0.0f, 800.0f, 600.0f);
    self.view.backgroundColor = [UIColor grayColor];

    self.text.text = self.label.text;
    self.fontSize.value = self.label.font.pointSize;
    self.x.text = [NSString stringWithFormat:@"%3.0f", self.label.frame.origin.x];
    self.y.text = [NSString stringWithFormat:@"%3.0f", self.label.frame.origin.y];
    self.w.text = [NSString stringWithFormat:@"%3.0f", self.label.frame.size.width];
    self.h.text = [NSString stringWithFormat:@"%3.0f", self.label.frame.size.height];
    self.numberOfLines.text = [NSString stringWithFormat:@"%d", (int)self.label.numberOfLines];
    self.lineBreakMode.text = [NSString stringWithFormat:@"%d", (int)self.label.lineBreakMode];
    self.autoShrink.on = self.label.adjustsFontSizeToFitWidth;
    self.minimumFontSize.text = [NSString stringWithFormat:@"%3.0f", self.label.minimumFontSize];
    self.minimumScaleFactor.text = [NSString stringWithFormat:@"%3.0f", self.label.minimumScaleFactor];

    self.text.delegate = self;
    [self.text addTarget:self action:@selector(textFieldEditDidEnd:) forControlEvents:UIControlEventEditingDidEnd];

    self.x.delegate = self;
    self.x.keyboardType = UIKeyboardTypeNumberPad;
    [self.x addTarget:self action:@selector(textFieldEditDidEnd:) forControlEvents:UIControlEventEditingDidEnd];

    self.y.delegate = self;
    self.y.keyboardType = UIKeyboardTypeNumberPad;
    [self.y addTarget:self action:@selector(textFieldEditDidEnd:) forControlEvents:UIControlEventEditingDidEnd];

    self.w.delegate = self;
    self.w.keyboardType = UIKeyboardTypeNumberPad;
    [self.w addTarget:self action:@selector(textFieldEditDidEnd:) forControlEvents:UIControlEventEditingDidEnd];

    self.h.delegate = self;
    self.h.keyboardType = UIKeyboardTypeNumberPad;
    [self.h addTarget:self action:@selector(textFieldEditDidEnd:) forControlEvents:UIControlEventEditingDidEnd];

    self.numberOfLines.delegate = self;
    self.numberOfLines.keyboardType = UIKeyboardTypeNumberPad;
    [self.numberOfLines addTarget:self action:@selector(textFieldEditDidEnd:) forControlEvents:UIControlEventEditingDidEnd];

    self.lineBreakMode.delegate = self;
    self.lineBreakMode.keyboardType = UIKeyboardTypeNumberPad;
    [self.lineBreakMode addTarget:self action:@selector(textFieldEditDidEnd:) forControlEvents:UIControlEventEditingDidEnd];

    self.minimumFontSize.delegate = self;
    self.minimumFontSize.keyboardType = UIKeyboardTypeDecimalPad;
    [self.minimumFontSize addTarget:self action:@selector(textFieldEditDidEnd:) forControlEvents:UIControlEventEditingDidEnd];

    self.minimumScaleFactor.delegate = self;
    self.minimumScaleFactor.keyboardType = UIKeyboardTypeDecimalPad;
    [self.minimumScaleFactor addTarget:self action:@selector(textFieldEditDidEnd:) forControlEvents:UIControlEventEditingDidEnd];

    [self.fontSize addTarget:self action:@selector(fontSizeChanged:) forControlEvents:UIControlEventValueChanged];
    self.fontSize.continuous = YES;

    [self.autoShrink addTarget:self action:@selector(autoShrinkChanged:) forControlEvents:UIControlEventValueChanged];

    [self.start addTarget:self action:@selector(startTests:) forControlEvents:UIControlEventTouchUpInside];
}

- (void)startTests:(UIButton*)sender {
    // if user didn't provide any text for UILabel, use default labelText
    // in autoMode
    if ([self.label.text length] == 0) {
        self.label.text = self.defaultLabelText;
    }

    // reset the log
    _eventId = 0;

#if __has_feature(objc_arc)
    __weak UILabelViewController* weakSelf = self;
#else
    UILabelViewController* weakSelf = self;
#endif

    // push the enumeration to background thread so that main thread isn't caught
    // up with busy looping and enumerating all configurations
    dispatch_queue_t g = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0);
    dispatch_async(g, ^{
        __strong UILabelViewController* strongSelf = weakSelf;

        if (strongSelf) {
            // enumerate the autoFit
            for (int autoFit = 0; autoFit <= 1; autoFit++) {
                dispatch_sync(dispatch_get_main_queue(), ^{
                    strongSelf.autoShrink.on = (BOOL)autoFit;
                    [strongSelf autoShrinkChanged:strongSelf.autoShrink];
                });

                if (autoFit == 1) {
                    // autoFit is on, enumerate miniFontSize/ScaleFactor
                    for (int useMinScaleFactor = 0; useMinScaleFactor <= 1; useMinScaleFactor++) {
                        if (useMinScaleFactor) {
                            for (float minScaleFactor = 0.1; minScaleFactor < 1.0; minScaleFactor += 0.4) {
                                dispatch_sync(dispatch_get_main_queue(), ^{
                                    strongSelf.minimumScaleFactor.text = [NSString stringWithFormat:@"%5.1f", minScaleFactor];
                                    [strongSelf textFieldEditDidEnd:strongSelf.minimumScaleFactor];
                                });

                                [strongSelf enumerateNumberOfLinesLinBreakFontSize];
                            }
                        } else {
                            float minFontSizeStep = strongSelf.label.font.pointSize / 3.0f;
                            for (float minFontSize = 0.1; minFontSize < strongSelf.label.font.pointSize; minFontSize += minFontSizeStep) {
                                dispatch_sync(dispatch_get_main_queue(), ^{
                                    strongSelf.minimumFontSize.text = [NSString stringWithFormat:@"%5.2f", minFontSize];
                                    [strongSelf textFieldEditDidEnd:strongSelf.minimumFontSize];
                                });

                                [strongSelf enumerateNumberOfLinesLinBreakFontSize];
                            }
                        }
                    }
                } else {
                    [strongSelf enumerateNumberOfLinesLinBreakFontSize];
                }
            }

#ifndef WINOBJC
            // write log array to external file so that it can be used as expected value
            // we take advantage of the fact that app run iOS simulator is not sandboxed, thus
            // can write the log file to a specific location
            BOOL logPersisted = [self->logArray writeToFile:@"/Users/yiyang/temp/testlog.txt" atomically:YES];
            UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"Generate Log"
                                                                           message:logPersisted ? @"Succeeded" : @"Failed"
                                                                    preferredStyle:UIAlertControllerStyleAlert];

            UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:@"OK"
                                                                    style:UIAlertActionStyleDefault
                                                                  handler:^(UIAlertAction* action){
                                                                  }];

            [alert addAction:defaultAction];
            [self presentViewController:alert animated:YES completion:nil];
#endif
        }
    });
}

- (void)enumerateNumberOfLinesLinBreakFontSize {
    // enumerate different number of lines
    for (int numberOfLines = 0; numberOfLines <= 4; numberOfLines++) {
        dispatch_sync(dispatch_get_main_queue(), ^{
            self.numberOfLines.text = [NSString stringWithFormat:@"%d", numberOfLines];
            [self textFieldEditDidEnd:self.numberOfLines];
        });

        // enumerate different lineBreak
        for (int lineBreakMode = 0; lineBreakMode <= (int)NSLineBreakByTruncatingMiddle; lineBreakMode++) {
            dispatch_sync(dispatch_get_main_queue(), ^{
                self.lineBreakMode.text = [NSString stringWithFormat:@"%d", lineBreakMode];
                [self textFieldEditDidEnd:self.lineBreakMode];
            });

            // enumerate font size
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
                    [self fontSizeChanged:self.fontSize];
                    [self updateLog];
                });
            }
        }
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (BOOL)textFieldShouldReturn:(UITextField*)textField {
    [textField resignFirstResponder];
    return YES;
}

- (void)autoShrinkChanged:(UISwitch*)autoShrinkSwtich {
    self.minimumFontSize.enabled = self.minimumFontSize.enabled = self.autoShrink.on;
    self.label.adjustsFontSizeToFitWidth = self.autoShrink.on;
}

- (void)fontSizeChanged:(UISlider*)slider {
    self.label.font = [self.label.font fontWithSize:slider.value];
    self.fontSizeLabel.text = [NSString stringWithFormat:@"%5.2f", slider.value];
}

- (void)textFieldEditDidEnd:(UITextField*)sender {
    if (sender == self.text) {
        // update label text
        self.label.text = sender.text;
    } else if (sender == self.x) {
        // update bound rect x
        CGRect rect = self.label.frame;
        rect.origin.x = [self.x.text floatValue];
        self.label.frame = rect;
    } else if (sender == self.y) {
        // update bound rect y
        CGRect rect = self.label.frame;
        rect.origin.y = [self.y.text floatValue];
        self.label.frame = rect;
    } else if (sender == self.w) {
        // update bound rect width
        CGRect rect = self.label.frame;
        rect.size.width = [self.w.text floatValue];
        self.label.frame = rect;
    } else if (sender == self.h) {
        // update bound rect height
        CGRect rect = self.label.frame;
        rect.size.height = [self.h.text floatValue];
        self.label.frame = rect;
    } else if (sender == self.numberOfLines) {
        // update number of Lines
        self.label.numberOfLines = [self.numberOfLines.text intValue];
    } else if (sender == self.lineBreakMode) {
        // update line break mode
        self.label.lineBreakMode = (NSLineBreakMode)[self.lineBreakMode.text intValue];
    } else if (sender == self.minimumFontSize) {
        // update minimum font size
        self.label.minimumFontSize = [self.minimumFontSize.text floatValue];
    } else if (sender == self.minimumScaleFactor) {
        // update minimum font scale
        self.label.minimumScaleFactor = [self.minimumScaleFactor.text floatValue];
    }
}

- (void)updateLog {
    self.textRect = [self.label textRectForBounds:self.label.frame limitedToNumberOfLines:self.label.numberOfLines];
    self.sizeThatFits = [self.label sizeThatFits:self.label.frame.size];
    self.intrinsicContentSize = self.label.intrinsicContentSize;

    self.result = [NSString stringWithFormat:@"id=%04d, frame={%4.2f, %7.2f, %7.2f, %7.2f}, #OfLines=%d, fontSize=%5.2f, lineBreak=%d, "
                                             @"AutoShrink=%d, MinFontSize=%1.2f, MinScale=%1.2f, IntrinicContentSize={%7.2f, %7.2f}, "
                                             @"textRect={%7.2f, %7.2f, %7.2f, %7.2f}, sizeThatFits={%7.2f, %7.2f}",
                                             self->_eventId,
                                             self.label.frame.origin.x,
                                             self.label.frame.origin.y,
                                             self.label.frame.size.width,
                                             self.label.frame.size.height,
                                             (int)self.label.numberOfLines,
                                             self.label.font.pointSize,
                                             (int)self.label.lineBreakMode,
                                             self.autoShrink.on,
                                             self.label.minimumFontSize,
                                             self.label.minimumScaleFactor,
                                             self.intrinsicContentSize.width,
                                             self.intrinsicContentSize.height,
                                             self.textRect.origin.x,
                                             self.textRect.origin.y,
                                             self.textRect.size.width,
                                             self.textRect.size.height,
                                             self.sizeThatFits.width,
                                             self.sizeThatFits.height];

    NSLog(@"%@", self.result);

#ifndef WINOBJC
    // on reference platform, add expected result dictionary into log array so that it can
    // be serialized to a file and then compared to the actual result on our platform for the
    // the same config
    NSMutableDictionary* resultDict = [[NSMutableDictionary alloc] init];

    [resultDict setObject:[NSString stringWithFormat:@"%04d", self->_eventId] forKey:@"id"];
    [resultDict setObject:NSStringFromCGRect(self.label.frame) forKey:@"frame"];
    [resultDict setObject:[NSString stringWithFormat:@"%d", (int)self.label.numberOfLines] forKey:@"#OfLines"];
    [resultDict setObject:[NSString stringWithFormat:@"%5.2f", self.label.font.pointSize] forKey:@"fontSize"];
    [resultDict setObject:[NSString stringWithFormat:@"%d", (int)self.label.lineBreakMode] forKey:@"lineBreak"];
    [resultDict setObject:[NSString stringWithFormat:@"%d", self.autoShrink.on] forKey:@"AutoShrink"];
    [resultDict setObject:[NSString stringWithFormat:@"%5.2f", self.label.minimumFontSize] forKey:@"MinFontSize"];
    [resultDict setObject:[NSString stringWithFormat:@"%1.2f", self.label.minimumScaleFactor] forKey:@"MinScale"];
    [resultDict setObject:NSStringFromCGSize(self.intrinsicContentSize) forKey:@"IntrinicContentSize"];
    [resultDict setObject:NSStringFromCGRect(self.textRect) forKey:@"textRect"];
    [resultDict setObject:NSStringFromCGSize(self.sizeThatFits) forKey:@"sizeThatFits"];

    [self->logArray addObject:resultDict];
#endif

    self->_eventId++;
}

@end
