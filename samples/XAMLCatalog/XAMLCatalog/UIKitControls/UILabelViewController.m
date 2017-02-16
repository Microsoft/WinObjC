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

#import "UILabelViewController.h"

static const CGFloat c_originX = 5;
static const CGFloat c_originY = 8;
static const CGFloat c_width = 300;
static const CGFloat c_height = 50;
static const CGFloat c_labelFontSize = 17.0f;
static const int TAG_SUBVIEW_UILABEL = 1;

@implementation UILabelViewController {
@private
    NSMutableArray* _labels;
}

- (UILabel*)_createUILabelWithColor:(UIColor*)color
                               text:(NSString*)text
                      textAlignment:(NSTextAlignment)alignment
                      lineBreakMode:(UILineBreakMode)lineBreakMode
                      numberOfLines:(NSInteger)numberOfLines {
    CGRect frame = CGRectMake(c_originX, c_originY, c_width, c_height);
    UILabel* label = [[UILabel alloc] initWithFrame:frame];
    label.textColor = color;
    label.text = text;
    label.textAlignment = alignment;
    label.lineBreakMode = lineBreakMode;
    label.numberOfLines = numberOfLines;
    return label;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    // creating labels
    _labels = [[NSMutableArray alloc] init];

    [_labels addObject:[self _createUILabelWithColor:[UIColor blackColor]
                                                text:@"wordWrap test, You should see this string is wrapped around word"
                                       textAlignment:UITextAlignmentLeft
                                       lineBreakMode:UILineBreakModeWordWrap
                                       numberOfLines:0]];

    [_labels addObject:[self _createUILabelWithColor:[UIColor redColor]
                                                text:@"chararacterWrap is not supported, treated as wordWrap"
                                       textAlignment:UITextAlignmentLeft
                                       lineBreakMode:UILineBreakModeCharacterWrap
                                       numberOfLines:2]];

    [_labels addObject:[self _createUILabelWithColor:[UIColor blueColor]
                                                text:@"Clip and wrapping, the string is wrapped and clipped at the end of second line if "
                                                     @"the string is long enough"
                                       textAlignment:UITextAlignmentLeft
                                       lineBreakMode:UILineBreakModeClip
                                       numberOfLines:3]];

    [_labels
        addObject:[self _createUILabelWithColor:[UIColor grayColor]
                                           text:@"Clip and nowrapping, cliped at the end of first line and the rest will not wrap and show"
                                  textAlignment:UITextAlignmentLeft
                                  lineBreakMode:UILineBreakModeClip
                                  numberOfLines:1]];

    [_labels
        addObject:[self _createUILabelWithColor:[UIColor purpleColor]
                                           text:@"TailTruncation, this is a very long string, that we are using for testing TailTruncation"
                                  textAlignment:UITextAlignmentLeft
                                  lineBreakMode:UILineBreakModeTailTruncation
                                  numberOfLines:0]];

    [_labels addObject:[self _createUILabelWithColor:[UIColor blackColor]
                                                text:@"HeadTruncation but shown as TailTruncation, this is a very long string, that we are "
                                                     @"using for testing HeadTruncation"
                                       textAlignment:UITextAlignmentLeft
                                       lineBreakMode:UILineBreakModeHeadTruncation
                                       numberOfLines:2]];

    [_labels addObject:[self _createUILabelWithColor:[UIColor blackColor]
                                                text:@"MiddleTruncation but shown as TailTruncation, this is a very long string, that we "
                                                     @"are using for testing MiddleTruncation"
                                       textAlignment:UITextAlignmentLeft
                                       lineBreakMode:UILineBreakModeMiddleTruncation
                                       numberOfLines:3]];

    [self tableView].allowsSelection = NO;
}

- (NSInteger)tableView:(UITableView*)tableView numberOfRowsInSection:(NSInteger)section {
    return 36;
}

- (CGFloat)tableView:(UITableView*)tableView heightForRowAtIndexPath:(NSIndexPath*)indexPath {
    return 60;
}

- (UITableViewCell*)tableView:(UITableView*)tableView cellForRowAtIndexPath:(NSIndexPath*)indexPath {
    UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:@"MenuCell"];
    if (nil == cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"MenuCell"];
    } else {
        // Before reuse, check if any subview in contentview is tagged with TAG_SUBVIEW_UILABEL
        // if so, we know it is a custom view that we need to remove
        UIView* subView = (UIView*)[cell.contentView viewWithTag:TAG_SUBVIEW_UILABEL];
        [subView removeFromSuperview];

        cell.textLabel.text = nil;
        cell.textLabel.adjustsFontSizeToFitWidth = NO;
        cell.accessoryView = nil;
    }

    // Tag UILabel subview with TAG_SUBVIEW_UILABEL before adding this subview into contentview
    if (indexPath.row < 7) {
        // first 7 rows are for linkbreak testing
        UIView* subView = [_labels objectAtIndex:indexPath.row];
        subView.tag = TAG_SUBVIEW_UILABEL;
        [cell.contentView addSubview:subView];
    } else if (indexPath.row == 7) {
        cell.textLabel.text = @"SizeThatFits 1";
        cell.textLabel.numberOfLines = 2;
        UILabel* textLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, c_width / 2, c_height)];
        textLabel.text = @"short string";
        cell.accessoryView = textLabel;
    }
    if (indexPath.row == 8) {
        cell.textLabel.numberOfLines = 2;
        cell.textLabel.text = @"SizeThatFits 2";
        UILabel* textLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, c_width / 2, c_height)];
        textLabel.text = @"middle size string fits into label";
        textLabel.font = [textLabel.font fontWithSize:20.0];
        cell.accessoryView = textLabel;
    }
    if (indexPath.row == 9) {
        cell.textLabel.numberOfLines = 2;
        cell.textLabel.text = @"SizeThatFits 3";
        UILabel* textLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, c_width / 2, c_height)];
        textLabel.text = @"this is really really long string that size should fits into the label";
        cell.accessoryView = textLabel;
    } else if (indexPath.row == 10) {
        cell.textLabel.text = @"small string SizeThatFits";
        UILabel* textLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 60, c_height)];
        textLabel.numberOfLines = 2;
        textLabel.text = @"short string";
        cell.accessoryView = textLabel;
    }
    if (indexPath.row == 11) {
        cell.textLabel.text = @"longer string SizeThatFits";
        UILabel* textLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 60, c_height)];
        textLabel.text = @"middle size string fits into label";
        cell.accessoryView = textLabel;
    }
    if (indexPath.row == 12) {
        cell.textLabel.text = @"really long string SizeThatFits";
        UILabel* textLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 60, c_height)];
        textLabel.numberOfLines = 2;
        textLabel.text = @"this is really really long string that size should fits into the label";
        textLabel.lineBreakMode = UILineBreakModeWordWrap;
        cell.accessoryView = textLabel;
    }
    // AdjustFontSizeToFitWidth tests

    // testing single line, adjustFontSize to false
    if (indexPath.row == 13) {
        cell.accessoryView = [self _createLabelwithNumberOfLines:1
                                        AdjustFontSizeToFitWidth:NO
                                                   LineBreakMode:UILineBreakModeTailTruncation
                                                 MinimumFontSize:0.0f];
    }

    // testing single line, adjustFontSize to TRUE
    if (indexPath.row == 14) {
        cell.accessoryView = [self _createLabelwithNumberOfLines:1
                                        AdjustFontSizeToFitWidth:YES
                                                   LineBreakMode:UILineBreakModeTailTruncation
                                                 MinimumFontSize:0.0f];
    }

    // number of Lines = 2, unlimited, 3, 5 and adjustFontSize YES, TailTruncation
    if (indexPath.row == 15) {
        cell.accessoryView = [self _createLabelwithNumberOfLines:2
                                        AdjustFontSizeToFitWidth:YES
                                                   LineBreakMode:UILineBreakModeTailTruncation
                                                 MinimumFontSize:0.0f];
    }
    if (indexPath.row == 16) {
        cell.accessoryView = [self _createLabelwithNumberOfLines:0
                                        AdjustFontSizeToFitWidth:YES
                                                   LineBreakMode:UILineBreakModeTailTruncation
                                                 MinimumFontSize:0.0f];
    }
    if (indexPath.row == 17) {
        cell.accessoryView = [self _createLabelwithNumberOfLines:3
                                        AdjustFontSizeToFitWidth:YES
                                                   LineBreakMode:UILineBreakModeTailTruncation
                                                 MinimumFontSize:0.0f];
    }

    // number of Lines = 2, unlimited, 3 and adjustFontSize YES, wordWrapping
    if (indexPath.row == 18) {
        cell.accessoryView =
            [self _createLabelwithNumberOfLines:2 AdjustFontSizeToFitWidth:YES LineBreakMode:UILineBreakModeWordWrap MinimumFontSize:0.0f];
    }
    if (indexPath.row == 19) {
        cell.accessoryView =
            [self _createLabelwithNumberOfLines:0 AdjustFontSizeToFitWidth:YES LineBreakMode:UILineBreakModeWordWrap MinimumFontSize:0.0f];
    }
    if (indexPath.row == 20) {
        cell.accessoryView =
            [self _createLabelwithNumberOfLines:3 AdjustFontSizeToFitWidth:YES LineBreakMode:UILineBreakModeWordWrap MinimumFontSize:0.0f];
    }

    // number of Lines = 2, unlimited, 3 and adjustFontSize YES, CharacterWrap
    if (indexPath.row == 21) {
        cell.accessoryView = [self _createLabelwithNumberOfLines:2
                                        AdjustFontSizeToFitWidth:YES
                                                   LineBreakMode:UILineBreakModeCharacterWrap
                                                 MinimumFontSize:0.0f];
    }
    if (indexPath.row == 22) {
        cell.accessoryView = [self _createLabelwithNumberOfLines:0
                                        AdjustFontSizeToFitWidth:YES
                                                   LineBreakMode:UILineBreakModeCharacterWrap
                                                 MinimumFontSize:0.0f];
    }
    if (indexPath.row == 23) {
        cell.accessoryView = [self _createLabelwithNumberOfLines:3
                                        AdjustFontSizeToFitWidth:YES
                                                   LineBreakMode:UILineBreakModeCharacterWrap
                                                 MinimumFontSize:0.0f];
    }

    // number of Lines = 2, unlimited, 3 and adjustFontSize YES, Clipping
    if (indexPath.row == 24) {
        cell.accessoryView =
            [self _createLabelwithNumberOfLines:2 AdjustFontSizeToFitWidth:YES LineBreakMode:UILineBreakModeClip MinimumFontSize:0.0f];
    }
    if (indexPath.row == 25) {
        cell.accessoryView =
            [self _createLabelwithNumberOfLines:0 AdjustFontSizeToFitWidth:YES LineBreakMode:UILineBreakModeClip MinimumFontSize:0.0f];
    }
    if (indexPath.row == 26) {
        cell.accessoryView =
            [self _createLabelwithNumberOfLines:3 AdjustFontSizeToFitWidth:YES LineBreakMode:UILineBreakModeClip MinimumFontSize:0.0f];
    }

    // number of Lines = 2, unlimited, 3 and adjustFontSize YES, TailTruncation, change minimum size to different values
    if (indexPath.row == 27) {
        cell.accessoryView = [self _createLabelwithNumberOfLines:2
                                        AdjustFontSizeToFitWidth:YES
                                                   LineBreakMode:UILineBreakModeTailTruncation
                                                 MinimumFontSize:8.0f];
    }
    if (indexPath.row == 28) {
        cell.accessoryView = [self _createLabelwithNumberOfLines:0
                                        AdjustFontSizeToFitWidth:YES
                                                   LineBreakMode:UILineBreakModeTailTruncation
                                                 MinimumFontSize:17.0f];
    }
    if (indexPath.row == 29) {
        cell.accessoryView = [self _createLabelwithNumberOfLines:3
                                        AdjustFontSizeToFitWidth:YES
                                                   LineBreakMode:UILineBreakModeTailTruncation
                                                 MinimumFontSize:32.0f];
    }

    // number of Lines = 2, unlimited, 3 and adjustFontSize NO, wordWrapping
    if (indexPath.row == 30) {
        cell.accessoryView =
            [self _createLabelwithNumberOfLines:2 AdjustFontSizeToFitWidth:NO LineBreakMode:UILineBreakModeWordWrap MinimumFontSize:0.0f];
    }
    if (indexPath.row == 31) {
        cell.accessoryView =
            [self _createLabelwithNumberOfLines:0 AdjustFontSizeToFitWidth:NO LineBreakMode:UILineBreakModeWordWrap MinimumFontSize:0.0f];
    }
    if (indexPath.row == 32) {
        cell.accessoryView =
            [self _createLabelwithNumberOfLines:3 AdjustFontSizeToFitWidth:NO LineBreakMode:UILineBreakModeWordWrap MinimumFontSize:0.0f];
    }

    if (indexPath.row == 33) {
        cell.accessoryView = [self _createLabelwithNumberOfLines:2
                                        AdjustFontSizeToFitWidth:YES
                                                   LineBreakMode:UILineBreakModeTailTruncation
                                              MinimumScaleFactor:0.0f];
    }
    if (indexPath.row == 34) {
        cell.accessoryView = [self _createLabelwithNumberOfLines:2
                                        AdjustFontSizeToFitWidth:YES
                                                   LineBreakMode:UILineBreakModeTailTruncation
                                              MinimumScaleFactor:0.1];
    }
    if (indexPath.row == 35) {
        cell.accessoryView = [self _createLabelwithNumberOfLines:2
                                        AdjustFontSizeToFitWidth:YES
                                                   LineBreakMode:UILineBreakModeTailTruncation
                                              MinimumScaleFactor:0.9f];
    }

    return cell;
}

- (UILabel*)_createLabelwithNumberOfLines:(int)numberOfLine
                 AdjustFontSizeToFitWidth:(BOOL)adjustFontSizeToFitWidth
                            LineBreakMode:(UILineBreakMode)lineBreakMode
                          MinimumFontSize:(float)minimumFontSize {
    UILabel* textLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, c_width, c_height)];
    textLabel.numberOfLines = numberOfLine;
    textLabel.adjustsFontSizeToFitWidth = adjustFontSizeToFitWidth;
    textLabel.lineBreakMode = lineBreakMode;

    if (minimumFontSize > textLabel.minimumFontSize) {
        textLabel.minimumFontSize = minimumFontSize;
    }

    BOOL shouldAdjustSize = adjustFontSizeToFitWidth && (lineBreakMode != UILineBreakModeWordWrap) &&
                            (lineBreakMode != NSLineBreakByCharWrapping) && (minimumFontSize < 17.0);

    textLabel.text = [NSString
        stringWithFormat:@"adjustFontSize = %d, numberOflines = %d, linbreakMode=%d, text %@ adjust to fit the width of this UIlabel",
                         textLabel.adjustsFontSizeToFitWidth,
                         textLabel.numberOfLines,
                         textLabel.lineBreakMode,
                         shouldAdjustSize ? @"should" : @"should not"];

    return textLabel;
}

- (UILabel*)_createLabelwithNumberOfLines:(int)numberOfLine
                 AdjustFontSizeToFitWidth:(BOOL)adjustFontSizeToFitWidth
                            LineBreakMode:(UILineBreakMode)lineBreakMode
                       MinimumScaleFactor:(float)minimumScaleFactor {
    UILabel* textLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, c_width, c_height)];
    textLabel.numberOfLines = numberOfLine;
    textLabel.adjustsFontSizeToFitWidth = adjustFontSizeToFitWidth;
    textLabel.lineBreakMode = lineBreakMode;
    textLabel.minimumScaleFactor = minimumScaleFactor;

    BOOL shouldAdjustSize =
        adjustFontSizeToFitWidth && (lineBreakMode != UILineBreakModeWordWrap) && (lineBreakMode != NSLineBreakByCharWrapping);

    textLabel.text = [NSString
        stringWithFormat:@"adjustFontSize = %d, numberOflines = %d, linbreakMode=%d, text %@ adjust to fit the width of this UIlabel",
                         textLabel.adjustsFontSizeToFitWidth,
                         textLabel.numberOfLines,
                         textLabel.lineBreakMode,
                         shouldAdjustSize ? @"should" : @"should not"];

    return textLabel;
}

@end
