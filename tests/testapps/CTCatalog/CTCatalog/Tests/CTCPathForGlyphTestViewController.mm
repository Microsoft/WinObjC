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
//*****************************************************************************

#import "CTCPathForGlyphTestViewController.h"

@interface GlyphAsPathView : UIView
@property UniChar character;
@property UIFont* font;
@end

@implementation GlyphAsPathView

- (void)drawRect:(CGRect)rect {
    UIColor* color = [UIColor blackColor];

    CGContextRef context = UIGraphicsGetCurrentContext();

    // Aligns origin for our frame
    CGContextTranslateCTM(context, 0.0f, self.bounds.size.height);

    // Flips y-axis for our frame
    CGContextScaleCTM(context, 1.0f, -1.0f);

    // Treat _character as a c-style array of size 1
    CGGlyph glyph;
    if (CTFontGetGlyphsForCharacters((__bridge CTFontRef)_font, &_character, &glyph, 1)) {
        // UILabel draws vertically centered
        // CTFontCreatePathForGlyph creates a path starting from lower left by default
        // Shift the path up by an eyeballed amount to make this roughly level
        CGAffineTransform shiftUp = CGAffineTransformMakeTranslation(0, 28);

        CGPathRef path = CTFontCreatePathForGlyph((__bridge CTFontRef)_font, glyph, &shiftUp);

        CGContextSetLineWidth(context, 1.0);
        CGContextSetStrokeColorWithColor(context, color.CGColor);
        CGContextAddPath(context, path);
        CGContextStrokePath(context);
    }
}

@end

@implementation CTCPathForGlyphTestViewController {
    // Input for what character to render
    UITextField* _textField;

    // Two render paths for the character
    UILabel* _glyphLabel; // 'control', using normal rendering
    GlyphAsPathView* _glyphAsPathView; // 'experiment', using CTFontCreatePathForGlyph, then drawing the path

    // Explanatory labels for the above views
    UILabel* _glyphLabelLabel;
    UILabel* _glyphAsPathViewLabel;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    CGFloat width = CGRectGetWidth(self.view.bounds);

    _textField = [[UITextField alloc] init];
    _textField.text = @"A";
    _textField.delegate = self; // Gives _textField textFieldDidEndEditing, textFieldShouldReturn callback
    [self.view addSubview:_textField];

    UIFont* font = [UIFont fontWithName:@"Times New Roman" size:200];

    _glyphLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, _textField.frame.size.height, width / 2, 200)];
    _glyphLabel.text = _textField.text;
    _glyphLabel.font = font;
    [self.view addSubview:_glyphLabel];

    _glyphAsPathView = [[GlyphAsPathView alloc] init];
    _glyphAsPathView.character = [_textField.text characterAtIndex:(_textField.text.length - 1)];
    _glyphAsPathView.backgroundColor = [UIColor whiteColor];
    _glyphAsPathView.font = font;
    [self.view addSubview:_glyphAsPathView];

    _glyphLabelLabel = [[UILabel alloc] init];
    _glyphLabelLabel.text = @"UILabel rendering of the last character in the text field";
    [self.view addSubview:_glyphLabelLabel];

    _glyphAsPathViewLabel = [[UILabel alloc] init];
    _glyphAsPathViewLabel.text = @"CTFontCreatePathForGlyph of the last character in the text field";
    [self.view addSubview:_glyphAsPathViewLabel];
}

- (void)viewDidLayoutSubviews {
    CGFloat width = CGRectGetWidth(self.view.bounds);

    _textField.frame = CGRectMake(0, 0, width, 50);
    [_textField setNeedsDisplay];

    _glyphLabel.frame = CGRectMake(0, _textField.frame.size.height, width / 2, 200);

    _glyphAsPathView.frame = CGRectMake(_glyphLabel.frame.origin.x + _glyphLabel.frame.size.width,
                                        _glyphLabel.frame.origin.y,
                                        _glyphLabel.frame.size.width,
                                        _glyphLabel.frame.size.height);
    [_glyphAsPathView setNeedsDisplay];

    _glyphLabelLabel.frame = CGRectMake(_glyphLabel.frame.origin.x,
                                        _glyphLabel.frame.origin.y + _glyphLabel.frame.size.height,
                                        _glyphLabel.frame.size.width,
                                        100);
    [_glyphLabelLabel setNeedsDisplay];

    _glyphAsPathViewLabel.frame = CGRectMake(_glyphAsPathView.frame.origin.x,
                                             _glyphAsPathView.frame.origin.y + _glyphAsPathView.frame.size.height,
                                             _glyphAsPathView.frame.size.width,
                                             _glyphLabelLabel.frame.size.height);
    [_glyphAsPathViewLabel setNeedsDisplay];
}

- (BOOL)textFieldShouldReturn:(UITextField*)textField {
    [self textFieldDidEndEditing:textField];
    return NO;
}

- (void)textFieldDidEndEditing:(UITextField*)textField {
    NSUInteger length = textField.text.length;
    if (length > 0) {
        // Update both views of the glyph
        _glyphLabel.text = [textField.text substringFromIndex:(length - 1)];
        [_glyphLabel setNeedsDisplay];

        _glyphAsPathView.character = [textField.text characterAtIndex:(length - 1)];
        [_glyphAsPathView setNeedsDisplay];
    }
}

@end
