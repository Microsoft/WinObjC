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

#import "TextDisplayViewController.h"

#import <CoreText/CoreText.h>

int const NumberOfDrawWithAttrTestCases = 4;
int const NumberOfSizeWithAttrTestCases = 5;
int const DefaultHeightOfCell = 70;
int const DefaultWidthOfCell = 300;
int const DefaultHeightOfDrawArea = 60;
int const DefaultWidthOfDrawArea = 300;
int const CharsToDisplayInRing = 26;
int const DefaultFontSize = 16;
int const DefaultShadowWidth = 10;
int const DefaultShadowHeight = 10;
NSString* const TestParagraph =
    @"Lorem ipsum dolor sit amet lorem a ut massa quam tempus maecenas. Eu consequat ipsum magnis quisque. Etiam luctus "
    @"dictum natoque ullamcorper dolor quam quisque metus. Dui imperdiet eget ante tellus. Nullam sem aenean. Pede "
    @"donec lorem ultricies eleifend imperdiet integer phasellus blandit dictum nulla eget. Nulla fringilla sit "
    @"pulvinar eu vel semper orci. Vel lorem ante ut. Eleifend vulputate rhoncus. Ultricies dolor venenatis amet sit "
    @"aenean ante magnis imperdiet rhoncus tellus elementum. Etiam amet ante enim. Tellus adipiscing consequat. Dolor "
    @"justo adipiscing nisi amet. Adipiscing aliquam eleifend lorem ante fringilla integer elementum quis felis libero "
    @"pretium justo. Veni tellus id. Etiam quam vitae leo aenean et vivamus rhoncus nec. Nulla adipiscing parturient "
    @"sit porttitor et nec quam ultricies integer nullam. Lorem dui eu vitae ultricies tellus eget quis felis dolor "
    @"tincidunt aenean semper. Vitae quis dolor natoque eleifend justo phasellus mollis pulvinar venenatis ac pede sem "
    @"pellentesque. Eget commodo nam quam sem ipsum vici ligula ante.";
NSString* const TestString = @"ABCDEFGHIJKLMNOPQRSTUVWXYZ";
NSMutableArray* rows;

typedef enum { shapeRectangle, shapeTriangle } ShapeType;

@interface MovableShape : UIView <UIGestureRecognizerDelegate> {
    CGPoint _origin;
    CGSize _shapeSize;
    ShapeType _shapeType;

    UIPanGestureRecognizer* _panGesture;
}
@property (nonatomic, retain) UIBezierPath* path;
@property (nonatomic, retain) NSTextContainer* textContainer;
@property (nonatomic) CGPoint offset;
@end

@implementation MovableShape
- (UIBezierPath*)bezierPathWithOffset:(CGPoint)offset {
    switch (_shapeType) {
        case shapeRectangle: {
            CGRect rect;
            rect.origin = offset;
            rect.size = _shapeSize;

            return [UIBezierPath bezierPathWithRect:rect];
        } break;

        case shapeTriangle: {
            CGMutablePathRef path = CGPathCreateMutable();
            CGPathMoveToPoint(path, NULL, _shapeSize.width / 2.0f + offset.x, offset.y);
            CGPathAddLineToPoint(path, NULL, _shapeSize.width + offset.x, _shapeSize.height + offset.y);
            CGPathAddLineToPoint(path, NULL, offset.x, _shapeSize.height + offset.y);
            CGPathAddLineToPoint(path, NULL, _shapeSize.width / 2.0f + offset.x, offset.y);

            UIBezierPath* ret = [UIBezierPath bezierPathWithCGPath:path];
            CGPathRelease(path);

            return ret;
        } break;
    }

    return nil;
}

- (void)setOffset:(CGPoint)offset {
    CGPoint newPosition = self.layer.position;
    newPosition.x += offset.x;
    newPosition.y += offset.y;
    self.layer.position = newPosition;

    _origin = offset;
    [self _updateTextContainer];
}

- (void)_updateTextContainer {
    NSMutableArray* arr = [self.textContainer.exclusionPaths mutableCopy];
    if (arr == nil)
        arr = [NSMutableArray new];

    if (self.path)
        [arr removeObject:self.path];

    self.path = [self bezierPathWithOffset:_origin];
    [arr addObject:self.path];

    self.textContainer.exclusionPaths = arr;

    CAShapeLayer* layer = (CAShapeLayer*)self.layer;
    if (layer.path == nil) {
        layer.path = [self bezierPathWithOffset:CGPointMake(0, 0)].CGPath;
        layer.fillColor = [UIColor cyanColor].CGColor;
        layer.strokeColor = [UIColor blueColor].CGColor;
        layer.lineWidth = 1.0f;
    }
}

- (instancetype)initWithRectangle:(CGSize)size textContainer:(NSTextContainer*)tc {
    self = [super initWithFrame:CGRectMake(0, 0, size.width, size.height)];
    self.textContainer = tc;
    _shapeSize = size;
    _shapeType = shapeRectangle;
    [self _updateTextContainer];

    _panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(_didPan:)];
    [_panGesture setDelegate:self];
    [self addGestureRecognizer:_panGesture];

    return self;
}

- (instancetype)initWithTriangle:(CGSize)size textContainer:(NSTextContainer*)tc {
    self = [super initWithFrame:CGRectMake(0, 0, size.width, size.height)];
    self.textContainer = tc;
    _shapeSize = size;
    _shapeType = shapeTriangle;
    [self _updateTextContainer];

    _panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(_didPan:)];
    [_panGesture setDelegate:self];
    [self addGestureRecognizer:_panGesture];

    return self;
}

- (void)_didPan:(UIGestureRecognizer*)gesture {
    UIGestureRecognizerState state = [gesture state];

    CGPoint amt;
    amt = [_panGesture translationInView:self];
    [_panGesture setTranslation:CGPointMake(0, 0) inView:self];

    if (state == UIGestureRecognizerStateBegan || state == UIGestureRecognizerStateChanged) {
        _origin.x += amt.x;
        _origin.y += amt.y;

        CGPoint newPosition = self.layer.position;
        newPosition.x += amt.x;
        newPosition.y += amt.y;
        self.layer.position = newPosition;
        [self _updateTextContainer];
    }
}

+ (Class)layerClass {
    return [CAShapeLayer class];
}
@end

@implementation TextDrawerController {
}

- (id)init {
    self = [super init];
    rows = [NSMutableArray new];

    NSString* title;

    // Add new test cases here order can effect cell height
    title = @"Blue Bold System Font Of Size 16";
    [rows addObject:[self makeTestCellWithTitle:title WithAccessoryUIView:[self makeTextDrawer:0]]];
    title = @"CGSize";
    [rows addObject:[self makeTestCellWithTitle:title WithAccessoryUIView:[self makeTextDrawer:1]]];

    title = @"Green Ariel System Font Of Size 16";
    [rows addObject:[self makeTestCellWithTitle:title WithAccessoryUIView:[self makeTextDrawer:2]]];
    title = @"CGSize";
    [rows addObject:[self makeTestCellWithTitle:title WithAccessoryUIView:[self makeTextDrawer:3]]];

    title = @"Default Bold Font of Size 16";
    [rows addObject:[self makeTestCellWithTitle:title WithAccessoryUIView:[self makeTextDrawer:4]]];
    title = @"CGSizet";
    [rows addObject:[self makeTestCellWithTitle:title WithAccessoryUIView:[self makeTextDrawer:5]]];

    title = @"Capatalized Alphabet Drawn in a circle. Black Background Green Text Size 12 Default Font";
    [rows
        addObject:[self makeTestCellWithTitle:title
                          WithAccessoryUIView:[self makeTextDrawer:8 WithCustomHeight:300 WithCustomBackgroundColor:[UIColor blackColor]]]];

    title = @"UITextView with 18pt Ariel Font Scrollable White Text";
    [rows addObject:[self makeTestCellWithTitle:title WithSubUIView:[self basicUITextView]]];

    title = @"UITextView with 18pt Ariel Font Scrollable Red Text";
    [rows addObject:[self makeTestCellWithTitle:title WithSubUIView:[self basicUITextView2]]];

    title = @"Red Bold System Font Of Size 16";
    [rows addObject:[self makeTestCellWithTitle:title WithAccessoryUIView:[self makeTextDrawer:10]]];

    title = @"boundingRectWithSize of testParagraph";
    [rows addObject:[self makeTestCellWithTitle:title WithAccessoryUIView:[self makeTextDrawer:11]]];

    title = @"CTFontCreateCopyWithSymbolicTraits (With and without bold trait)";
    [rows addObject:[self makeTestCellWithTitle:title WithAccessoryUIView:[self makeTextDrawer:12]]];

    title = @"CTLineCreateTruncatedLine:\nLine 1: Original line, \nLine2:(from left to right) truncationType:Start, middle and end with "
            @"truncationToken as string with two dots \"..\", \nLine3:(from left to right) truncationType:Start, middle and end with no "
            @"truncationToken";
    [rows
        addObject:[self makeTestCellWithTitle:title
                          WithAccessoryUIView:[self makeTextDrawer:13 WithCustomHeight:130 WithCustomBackgroundColor:[UIColor grayColor]]]];

    title = @"CTFontManagerRegisterFontsForURL: (Register different fonts familys)\nfont 1: Times New Roman\nfont 2: Gadugi";
    [rows addObject:[self makeTestCellWithTitle:title WithAccessoryUIView:[self makeTextDrawer:14]]];

    return self;
}

- (TextDrawer*)makeTextDrawer:(int)testNumber {
    return [self makeTextDrawer:testNumber WithCustomHeight:DefaultHeightOfDrawArea WithCustomBackgroundColor:[UIColor whiteColor]];
}

- (TextDrawer*)makeTextDrawer:(int)testNumber WithCustomHeight:(int)customeHeight WithCustomBackgroundColor:(UIColor*)backgroundColor {
    TextDrawer* uiview;
    uiview = [[TextDrawer alloc] initWithFrame:CGRectMake(0, 0, DefaultWidthOfDrawArea, customeHeight) WithUICase:testNumber];
    uiview.backgroundColor = backgroundColor;
    return uiview;
}

- (UITableViewCell*)makeTestCellWithTitle:(NSString*)title WithSubUIView:(UIView*)uiView {
    UITableViewCell* cell = [self makeTestCellTitle:title];
    UIView* uiView2 = [[UIView alloc] initWithFrame:CGRectMake(0, 0, DefaultWidthOfDrawArea, 300)];
    [uiView2 addSubview:uiView];
    cell.accessoryView = uiView2;
    return cell;
}

- (UITableViewCell*)makeTestCellWithTitle:(NSString*)title WithAccessoryUIView:(UIView*)uiView {
    UITableViewCell* cell = [self makeTestCellTitle:title];
    cell.accessoryView = uiView;
    return cell;
}
- (UITableViewCell*)makeTestCellTitle:(NSString*)title {
    UITableViewCell* cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"MenuCell"];
    cell.backgroundColor = [UIColor whiteColor];
    cell.textLabel.text = title;
    cell.textLabel.textColor = [UIColor blackColor];
    return cell;
}

+ (NSAttributedString*)colorizedStringFromString:(NSString*)text withFont:(UIFont*)font textColor:(UIColor*)textColor {
    NSCharacterSet* upperCaseSet = [NSCharacterSet uppercaseLetterCharacterSet];
    NSMutableAttributedString* ret =
        [[NSMutableAttributedString alloc] initWithString:text
                                               attributes:@{ NSFontAttributeName : font, NSForegroundColorAttributeName : textColor }];
    UIFont* uppercaseFont = [font fontWithSize:font.pointSize * 1.10f];

    for (int i = 0; i < [text length]; i++) {
        if ([upperCaseSet characterIsMember:[text characterAtIndex:i]]) {
            [ret addAttribute:NSFontAttributeName value:uppercaseFont range:NSMakeRange(i, 1)];
            [ret addAttribute:NSForegroundColorAttributeName value:[UIColor redColor] range:NSMakeRange(i, 1)];
        }
    }

    return ret;
}

- (UITextView*)basicUITextView {
    UITextView* uiTextView = [[UITextView alloc] initWithFrame:CGRectMake(0, 0, DefaultWidthOfDrawArea, 300)];
    uiTextView.textColor = [UIColor blackColor];
    uiTextView.font = [UIFont fontWithName:@"Arial" size:18.0];
    uiTextView.backgroundColor = [UIColor whiteColor];

    uiTextView.text = TestParagraph;

    uiTextView.returnKeyType = UIReturnKeyDefault;
    uiTextView.keyboardType = UIKeyboardTypeDefault;
    uiTextView.scrollEnabled = YES;
    uiTextView.editable = YES;
    uiTextView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    MovableShape* triangleShape = [[MovableShape alloc] initWithTriangle:CGSizeMake(70, 70) textContainer:uiTextView.textContainer];
    MovableShape* rectangleShape = [[MovableShape alloc] initWithRectangle:CGSizeMake(70, 70) textContainer:uiTextView.textContainer];
    triangleShape.offset = CGPointMake(150, 0);
    rectangleShape.offset = CGPointMake(50, 140);
    [uiTextView addSubview:triangleShape];
    [uiTextView addSubview:rectangleShape];

    return uiTextView;
}

- (UITextView*)basicUITextView2 {
    UITextView* uiTextView = [[UITextView alloc] initWithFrame:CGRectMake(0, 0, DefaultWidthOfDrawArea, 300)];
    uiTextView.font = [UIFont fontWithName:@"Arial" size:18.0];
    uiTextView.backgroundColor = [UIColor whiteColor];

    uiTextView.text = TestParagraph;

    // intentionally setting text color after setting text
    uiTextView.textColor = [UIColor blueColor];

    uiTextView.returnKeyType = UIReturnKeyDefault;
    uiTextView.keyboardType = UIKeyboardTypeDefault;
    uiTextView.scrollEnabled = YES;
    uiTextView.editable = YES;
    uiTextView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    return uiTextView;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"Text Display Mode";

    [self tableView].allowsSelection = NO;
}

- (float)tableView:(UITableView*)tableView heightForRowAtIndexPath:(NSIndexPath*)indexPath {
    // Special height for circular word display
    if (indexPath.row == 6 || indexPath.row == 7 || indexPath.row == 8) {
        //  Circular letter view and UITextView row need more height
        return 350.0f;
    } else if (indexPath.row == 12) {
        return 200.0f;
    }

    return DefaultHeightOfCell;
}

- (NSInteger)tableView:(UITableView*)tableView numberOfRowsInSection:(NSInteger)section {
    return [rows count];
}

- (UITableViewCell*)tableView:(UITableView*)tableView cellForRowAtIndexPath:(NSIndexPath*)indexPath {
    return [rows objectAtIndex:indexPath.row];
}

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView*)pickerView {
    return 0;
}

- (NSInteger)pickerView:(UIPickerView*)pickerView numberOfRowsInComponent:(NSInteger)component {
    return 0;
}

@end

@implementation TextDrawer {
    // Which test to run
    int testNumber;
}
- (id)initWithFrame:(CGRect)rect WithUICase:(int)testChoice {
    testNumber = testChoice;
    return [super initWithFrame:rect];
}

- (void)drawRect:(CGRect)rect {
    // Chooses which test to run
    switch (testNumber) {
        case 0:
            [self drawBasicAtPoint:rect];
            break;
        case 1:
            [self sizeBasic:rect];
            break;
        case 2:
            [self drawAtPointWithFont:rect];
            break;
        case 3:
            [self sizeWithFont:rect];
            break;
        case 4:
            [self drawAtPointWithShadowColorWithOffset:rect];
            break;
        case 5:
            [self sizeWithShadowColorWithOffset:rect];
            break;
        case 6:
            [self drawAtPointWithOffset:rect];
            break;
        case 7:
            [self sizeWithOffset:rect];
            break;
        case 8:
            [self drawAtPointCircleText:rect];
            break;
        case 10:
            [self drawInRectWithAttributes:rect];
            break;
        case 11:
            [self boundingRectWithSize:rect];
            break;
        case 12:
            [self testCTFontCreateCopyWithSymbolicTraits:rect];
            break;
        case 13:
            [self testCTLineCreateTruncatedLine:rect];
            break;
        case 14:
            [self testCTFontManagerRegisterFontsForURL:rect];
            break;
    }
}

- (void)testCTLineCreateTruncatedLine:(CGRect)rect {
    // creating an attributed string
    UIFontDescriptor* descriptor = [UIFontDescriptor fontDescriptorWithName:@"Arial" size:24];
    UIFont* font = [UIFont fontWithDescriptor:descriptor size:24];
    NSMutableAttributedString* string = [[NSMutableAttributedString alloc] initWithString:@"hello world"];
    NSRange range = NSMakeRange(0, 11);
    [string addAttribute:(NSString*)kCTFontAttributeName value:font range:range];
    range = NSMakeRange(5, 6);
    [string addAttribute:(NSString*)kCTForegroundColorAttributeName value:[UIColor redColor] range:range];
    CFAttributedStringRef str = (__bridge CFAttributedStringRef)string;
    CTTypesetterRef ts = CTTypesetterCreateWithAttributedString(str);
    CFRange range2 = { 0, 11 };
    CTLineRef line = CTTypesetterCreateLineWithOffset(ts, range2, 0.0f);

    // context setting
    CGContextRef context = UIGraphicsGetCurrentContext();
    // Flip the context coordinates, in iOS only.
    CGContextTranslateCTM(context, 0, self.bounds.size.height);
    CGContextScaleCTM(context, 1.0, -1.0);

    // case 0: draw the whole line
    CGContextSetTextPosition(context, 0.0, 100.0);
    CTLineDraw(line, context);

    CTLineRef truncatedline;
    // case 1: without truncation token, truncationType = kCTLineTruncationStart
    truncatedline = CTLineCreateTruncatedLine(line, 28, kCTLineTruncationStart, NULL);
    CGContextSetTextPosition(context, 0.0, 10.0);
    CTLineDraw(truncatedline, context);

    // case 2: without truncation token, truncationType = kCTLineTruncationMiddle
    truncatedline = CTLineCreateTruncatedLine(line, 28, kCTLineTruncationMiddle, NULL);
    CGContextSetTextPosition(context, 100.0, 10.0);
    CTLineDraw(truncatedline, context);

    // case 3: without truncation token, truncationType = kCTLineTruncationEnd
    truncatedline = CTLineCreateTruncatedLine(line, 28, kCTLineTruncationEnd, NULL);
    CGContextSetTextPosition(context, 200.0, 10.0);
    CTLineDraw(truncatedline, context);

    CTLineRef trunToken = getTruncationToken();

    // case 4 : with the truncation token, truncationType = kCTLineTruncationStart
    truncatedline = CTLineCreateTruncatedLine(line, 28, kCTLineTruncationStart, trunToken);
    CGContextSetTextPosition(context, 0.0, 50.0);
    CTLineDraw(truncatedline, context);

    // case 5 : with the truncation token, truncationType = kCTLineTruncationMiddle
    truncatedline = CTLineCreateTruncatedLine(line, 28, kCTLineTruncationMiddle, trunToken);
    CGContextSetTextPosition(context, 100.0, 50.0);
    CTLineDraw(truncatedline, context);

    // case 6 : with the truncation token, truncationType = kCTLineTruncationEnd
    truncatedline = CTLineCreateTruncatedLine(line, 28, kCTLineTruncationEnd, trunToken);
    CGContextSetTextPosition(context, 200.0, 50.0);
    CTLineDraw(truncatedline, context);
}

- (void)testCTFontManagerRegisterFontsForURL:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    // Flip the context coordinates, in iOS only.
    CGContextTranslateCTM(context, 0, self.bounds.size.height);
    CGContextScaleCTM(context, 1.0, -1.0);

    // font 1
    NSURL* url = [NSURL fileURLWithPath:@"C:/Windows/Fonts/gadugi.ttf"];
    bool result = CTFontManagerRegisterFontsForURL((__bridge CFURLRef)(url), kCTFontManagerScopeProcess, NULL);
    if (result) {
        UIFont* font = [UIFont fontWithName:@"Gadugi" size:22.0];
        CTTypesetterRef typesetter =
            CTTypesetterCreateWithAttributedString((__bridge CFAttributedStringRef)[self getAttributedStringForFont:font]);
        CFRange range = { 0, 11 };
        CTLineRef line = CTTypesetterCreateLineWithOffset(typesetter, range, 0.0f);
        CTLineDraw(line, context);
        CFRelease(typesetter);
        CFRelease(line);
    }

    // font 2
    url = [NSURL fileURLWithPath:@"C:/Windows/Fonts/times.ttf"];
    result = CTFontManagerRegisterFontsForURL((__bridge CFURLRef)(url), kCTFontManagerScopeProcess, NULL);
    if (result) {
        UIFont* font = [UIFont fontWithName:@"Times New Roman" size:22.0];
        CTTypesetterRef typesetter =
            CTTypesetterCreateWithAttributedString((__bridge CFAttributedStringRef)[self getAttributedStringForFont:font]);
        CFRange range = CFRangeMake(0, 11);
        CTLineRef line = CTTypesetterCreateLineWithOffset(typesetter, range, 0.0f);
        CGContextSetTextPosition(context, 0.0, 25.0);

        CTLineDraw(line, context);
        CFRelease(typesetter);
        CFRelease(line);
    }
}

- (NSAttributedString*)getAttributedStringForFont:(UIFont*)font {
    NSRange wholeRange = NSMakeRange(0, 11);
    NSMutableAttributedString* string = [[NSMutableAttributedString alloc] initWithString:@"hello world"];
    [string addAttribute:(NSString*)kCTForegroundColorAttributeName value:[UIColor blueColor] range:wholeRange];
    [string addAttribute:(NSString*)kCTFontAttributeName value:font range:wholeRange];

    return string;
}

- (void)testCTFontCreateCopyWithSymbolicTraits:(CGRect)rect {
    // Right now we do not have support for symbolicTraits, so both the strings will appear visually the same.
    // In future when we support symbolic traits for eg: italic,etc they  will appear correctly.
    CFAttributedStringRef string1 = (__bridge CFAttributedStringRef)[self getAttributedString];
    CFAttributedStringRef string2 = (__bridge CFAttributedStringRef)[self getAttributedStringWithTraits];

    CGContextRef context = UIGraphicsGetCurrentContext();
    // Flip the context coordinates, in iOS only.
    CGContextTranslateCTM(context, 0, self.bounds.size.height);
    CGContextScaleCTM(context, 1.0, -1.0);

    CTTypesetterRef ts1 = CTTypesetterCreateWithAttributedString(string1);
    CTTypesetterRef ts2 = CTTypesetterCreateWithAttributedString(string2);

    CFRange range = { 0, 11 };
    CTLineRef line1 = CTTypesetterCreateLineWithOffset(ts1, range, 0.0f);
    CTLineRef line2 = CTTypesetterCreateLineWithOffset(ts2, range, 0.0f);

    CTLineDraw(line1, context);
    CGContextSetTextPosition(context, 0.0, 25.0);
    CTLineDraw(line2, context);
}

- (NSAttributedString*)getAttributedString {
    CGFloat fontsize = 20;
    UIFontDescriptor* fontDescriptor = [UIFontDescriptor fontDescriptorWithName:@"Times New Roman" size:fontsize];
    UIFont* font = [UIFont fontWithDescriptor:fontDescriptor size:fontsize];

    NSRange wholeRange = NSMakeRange(0, 11);
    NSMutableAttributedString* string = [[NSMutableAttributedString alloc] initWithString:@"hello world"];
    [string addAttribute:(NSString*)kCTForegroundColorAttributeName value:[UIColor blueColor] range:wholeRange];
    [string addAttribute:(NSString*)kCTFontAttributeName value:font range:wholeRange];

    return string;
}

CTLineRef getTruncationToken() {
    UIFont* font = [UIFont systemFontOfSize:16];
    NSRange wholeRange = NSMakeRange(0, 2);
    NSMutableAttributedString* string = [[NSMutableAttributedString alloc] initWithString:@".."];
    [string addAttribute:NSFontAttributeName value:font range:wholeRange];

    CTTypesetterRef ts = CTTypesetterCreateWithAttributedString((__bridge CFAttributedStringRef)string);
    CFRange range = { 0, 2 };
    CTLineRef token = CTTypesetterCreateLineWithOffset(ts, range, 0.0f);

    return token;
}

- (NSAttributedString*)getAttributedStringWithTraits {
    CGFloat fontsize = 20;
    UIFontDescriptor* fontDescriptor = [UIFontDescriptor fontDescriptorWithName:@"Times New Roman" size:fontsize];
    UIFont* font = [UIFont fontWithDescriptor:fontDescriptor size:fontsize];

    CTFontRef fontref = CTFontCreateCopyWithSymbolicTraits((__bridge CTFontRef)font, fontsize, NULL, kCTFontTraitBold, kCTFontTraitBold);
    NSRange wholeRange = NSMakeRange(0, 11);
    NSMutableAttributedString* string = [[NSMutableAttributedString alloc] initWithString:@"hello world"];
    [string addAttribute:(NSString*)kCTForegroundColorAttributeName value:[UIColor blueColor] range:wholeRange];
    [string addAttribute:(NSString*)kCTFontAttributeName value:(__bridge UIFont*)fontref range:wholeRange];

    return string;
}
- (void)boundingRectWithSize:(CGRect)rect {
    UIFont* font = [UIFont boldSystemFontOfSize:DefaultFontSize];
    UIColor* color = [UIColor blackColor];
    NSDictionary* attrs = [NSDictionary dictionaryWithObjectsAndKeys:font, UITextAttributeFont, color, UITextAttributeTextColor, nil];
    NSStringDrawingContext* context = nil;
    NSStringDrawingOptions options = NSStringDrawingUsesLineFragmentOrigin;
    CGRect rectResult = [TestParagraph boundingRectWithSize:rect.size options:options attributes:attrs context:context];
    [[NSString stringWithFormat:@"%f, %f, %f, %f", rectResult.origin.x, rectResult.origin.y, rectResult.size.width, rectResult.size.height]
           drawAtPoint:CGPointMake(rect.origin.x, rect.size.height / 2)
        withAttributes:attrs];
}

- (void)drawBasicAtPoint:(CGRect)rect {
    UIFont* font = [UIFont boldSystemFontOfSize:DefaultFontSize];
    UIColor* color = [UIColor blueColor];
    NSDictionary* attrs = [NSDictionary dictionaryWithObjectsAndKeys:font, UITextAttributeFont, color, UITextAttributeTextColor, nil];
    [TestString drawAtPoint:CGPointMake(rect.origin.x, rect.size.height / 2) withAttributes:attrs];
}

- (void)drawAtPointWithFont:(CGRect)rect {
    UIFont* font = [UIFont fontWithName:@"Arial" size:18];
    UIColor* color = [UIColor greenColor];
    NSDictionary* attrs = [NSDictionary dictionaryWithObjectsAndKeys:font, UITextAttributeFont, color, UITextAttributeTextColor, nil];
    [TestString drawAtPoint:CGPointMake(rect.origin.x, rect.size.height / 2) withAttributes:attrs];
}

// ShadowColor and ShadowOffset is currently Unsupported
- (void)drawAtPointWithShadowColorWithOffset:(CGRect)rect {
    UIFont* font = [UIFont boldSystemFontOfSize:DefaultFontSize];
    UIColor* color = [UIColor blackColor];
    UIColor* shadowColor = [UIColor greenColor];
    CGSize size = CGSizeMake(DefaultShadowWidth, DefaultShadowHeight);
    NSValue* shadowOffset = [NSValue valueWithCGSize:size];
    NSDictionary* attrs = [NSDictionary dictionaryWithObjectsAndKeys:font,
                                                                     UITextAttributeFont,
                                                                     color,
                                                                     UITextAttributeTextColor,
                                                                     shadowColor,
                                                                     UITextAttributeTextShadowColor,
                                                                     shadowOffset,
                                                                     UITextAttributeTextShadowOffset,
                                                                     nil];
    [TestString drawAtPoint:CGPointMake(rect.origin.x, rect.size.height / 2) withAttributes:attrs];
}

// ShadowOffset is currently Unsupported
- (void)drawAtPointWithOffset:(CGRect)rect {
    UIFont* font = [UIFont boldSystemFontOfSize:DefaultFontSize];
    UIColor* color = [UIColor blackColor];
    CGSize size = CGSizeMake(DefaultShadowWidth, DefaultShadowHeight);
    NSValue* shadowOffset = [NSValue valueWithCGSize:size];
    NSDictionary* attrs = [NSDictionary dictionaryWithObjectsAndKeys:font,
                                                                     UITextAttributeFont,
                                                                     color,
                                                                     UITextAttributeTextColor,
                                                                     shadowOffset,
                                                                     UITextAttributeTextShadowOffset,
                                                                     nil];
    [TestString drawAtPoint:CGPointMake(rect.origin.x, rect.size.height / 2) withAttributes:attrs];
}

- (void)sizeBasic:(CGRect)rect {
    UIFont* font = [UIFont boldSystemFontOfSize:DefaultFontSize];
    UIColor* color = [UIColor blackColor];
    NSDictionary* attrs = [NSDictionary dictionaryWithObjectsAndKeys:font, UITextAttributeFont, color, UITextAttributeTextColor, nil];
    CGSize cgSize = [TestString sizeWithAttributes:attrs];
    [[NSString stringWithFormat:@"%f, %f", cgSize.width, cgSize.height] drawAtPoint:CGPointMake(rect.origin.x, rect.size.height / 2)
                                                                     withAttributes:attrs];
}

- (void)sizeWithFont:(CGRect)rect {
    UIFont* font = [UIFont fontWithName:@"Arial" size:18];
    UIColor* color = [UIColor blackColor];
    NSDictionary* attrs = [NSDictionary dictionaryWithObjectsAndKeys:font, UITextAttributeFont, color, UITextAttributeTextColor, nil];
    CGSize cgSize = [TestString sizeWithAttributes:attrs];
    [[NSString stringWithFormat:@"%f, %f", cgSize.width, cgSize.height] drawAtPoint:CGPointMake(rect.origin.x, rect.size.height / 2)
                                                                     withAttributes:attrs];
}

// ShadowColor and ShadowOffset is currently Unsupported
- (void)sizeWithShadowColorWithOffset:(CGRect)rect {
    UIFont* font = [UIFont boldSystemFontOfSize:DefaultFontSize];
    UIColor* color = [UIColor blackColor];
    UIColor* shadowColor = [UIColor greenColor];

    CGSize size = CGSizeMake(DefaultShadowWidth, DefaultShadowHeight);
    NSValue* shadowOffset = [NSValue valueWithCGSize:size];

    NSDictionary* attrs = [NSDictionary dictionaryWithObjectsAndKeys:font,
                                                                     UITextAttributeFont,
                                                                     color,
                                                                     UITextAttributeTextColor,
                                                                     shadowColor,
                                                                     UITextAttributeTextShadowColor,
                                                                     shadowOffset,
                                                                     UITextAttributeTextShadowOffset,
                                                                     nil];
    CGSize cgSize = [TestString sizeWithAttributes:attrs];
    [[NSString stringWithFormat:@"%f, %f", cgSize.width, cgSize.height] drawAtPoint:CGPointMake(rect.origin.x, rect.size.height / 2)
                                                                     withAttributes:attrs];
}

// ShadowColor and ShadowOffset is currently Unsupported
- (void)drawInRectWithAttributes:(CGRect)rect {
    UIFont* font = [UIFont boldSystemFontOfSize:DefaultFontSize];
    UIColor* color = [UIColor redColor];
    NSDictionary* attrs = [NSDictionary dictionaryWithObjectsAndKeys:font, UITextAttributeFont, color, UITextAttributeTextColor, nil];
    NSStringDrawingContext* context = nil;
    NSStringDrawingOptions options = NSStringDrawingUsesLineFragmentOrigin;
    [TestString drawInRect:rect withAttributes:attrs];
}

// ShadowOffset is currently Unsupported
- (void)sizeWithOffset:(CGRect)rect {
    UIFont* font = [UIFont boldSystemFontOfSize:DefaultFontSize];
    UIColor* color = [UIColor blackColor];

    CGSize size = CGSizeMake(DefaultShadowWidth, DefaultShadowHeight);
    NSValue* shadowOffset = [NSValue valueWithCGSize:size];
    NSDictionary* attrs = [NSDictionary dictionaryWithObjectsAndKeys:font,
                                                                     UITextAttributeFont,
                                                                     color,
                                                                     UITextAttributeTextColor,
                                                                     shadowOffset,
                                                                     UITextAttributeTextShadowOffset,
                                                                     nil];
    CGSize cgSize = [TestString sizeWithAttributes:attrs];
    [[NSString stringWithFormat:@"%f, %f", cgSize.width, cgSize.height] drawAtPoint:CGPointMake(rect.origin.x, rect.size.height / 2)
                                                                     withAttributes:attrs];
}

- (void)drawAtPointCircleText:(CGRect)rect {
    UIFont* font = [UIFont boldSystemFontOfSize:12];
    UIColor* color = [UIColor greenColor];
    NSDictionary* attrs = [NSDictionary dictionaryWithObjectsAndKeys:font, UITextAttributeFont, color, UITextAttributeTextColor, nil];

    CGPoint center = CGPointMake(rect.size.width / 2, rect.size.height / 2);
    CGFloat radius = center.x * 0.50f;

    // Loop through each char in the string and place it around the center point.
    for (int i = 0; i < TestString.length; i++) {
        UIFont* font = [UIFont boldSystemFontOfSize:14];
        NSString* letter = [TestString substringWithRange:NSMakeRange(i, 1)];

        CGSize letterSize = [letter sizeWithAttributes:@{ UITextAttributeFont : font }];
        CGFloat temp = M_PI - (i * (2 * M_PI / CharsToDisplayInRing));
        CGFloat xCord = center.x + (radius * sin(temp)) - (letterSize.width / 2.0);
        CGFloat yCord = center.y + (radius * cos(temp)) - (letterSize.height / 2.0);

        [letter drawAtPoint:CGPointMake(xCord, yCord) withAttributes:attrs];
    }
}
@end