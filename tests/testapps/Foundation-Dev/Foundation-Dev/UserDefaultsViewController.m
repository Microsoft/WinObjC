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

#import "UserDefaultsViewController.h"

static const CGFloat c_originX = 5;
static const CGFloat c_originY = 8;
static const CGFloat c_width = 460;
static const CGFloat c_height = 40;
static const int TAG_SUBVIEW_UITEXTFIELD = 1;

@implementation UserDefaultsViewController {
@private
    NSMutableArray* _textFields;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    NSUserDefaults* standardDefaults = [NSUserDefaults standardUserDefaults];
    NSDictionary* dict = @{ @"FavoriteWord" : @"ChangeAndRelaunchMe", @"FavoriteBool" : [NSNumber numberWithBool:YES] };
    [standardDefaults registerDefaults:dict];
    NSString* placeHolder = [NSString stringWithFormat:@"%@", [standardDefaults stringForKey:@"FavoriteWord"]];

    _textFields = [NSMutableArray new];

    // Text box for retrieving favorite string
    CGRect frame = CGRectMake(c_originX, c_originY, c_width, c_height);
    UITextField* textField = [[UITextField alloc] initWithFrame:frame];
    textField.placeholder = placeHolder;
    textField.keyboardType = UIKeyboardTypeASCIICapable;
    textField.textAlignment = UITextAlignmentLeft;
    textField.delegate = self;

    [_textFields addObject:textField];

    // Slider for retrieving favorite bool
    UISwitch* switchFavoriteBool = [[UISwitch alloc] initWithFrame:frame];
    [switchFavoriteBool setOn:[standardDefaults boolForKey:@"FavoriteBool"] animated:NO];
    [_textFields addObject:switchFavoriteBool];
    [switchFavoriteBool addTarget:self action:@selector(changeFavoriteBool) forControlEvents:UIControlEventValueChanged];

    [self tableView].allowsSelection = NO;
}

- (void)changeFavoriteBool {
    id newFavorite = [NSNumber numberWithBool:[[_textFields objectAtIndex:1] isOn]];
    NSUserDefaults* standardDefaults = [NSUserDefaults standardUserDefaults];
    [standardDefaults setObject:newFavorite forKey:@"FavoriteBool"];
}

- (NSInteger)tableView:(UITableView*)tableView numberOfRowsInSection:(NSInteger)section {
    return [_textFields count];
}

- (CGFloat)tableView:(UITableView*)tableView heightForRowAtIndexPath:(NSIndexPath*)indexPath {
    return 60;
}

// Asks the delegate if editing should begin in the specified text field.
- (BOOL)textFieldShouldBeginEditing:(UITextField*)textField {
    return YES;
}

- (BOOL)textFieldShouldEndEditing:(UITextField*)textField {
    return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField*)textField {
    return YES;
}

- (void)textFieldDidEndEditing:(UITextField*)textField {
    NSUserDefaults* standardDefaults = [NSUserDefaults standardUserDefaults];
    [standardDefaults setObject:textField.text forKey:@"FavoriteWord"];
}

- (UITableViewCell*)tableView:(UITableView*)tableView cellForRowAtIndexPath:(NSIndexPath*)indexPath {
    UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:@"MenuCell"];
    if (nil == cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"MenuCell"];
    } else {
        // Before reuse, check if any subview in contentview is tagged with TAG_SUBVIEW_UITEXTFIELD
        // if so, we know it is a custom view that we need to remove
        UIView* subView = (UIView*)[cell viewWithTag:TAG_SUBVIEW_UITEXTFIELD];
        [subView removeFromSuperview];
    }

    UIView* subview = [_textFields objectAtIndex:indexPath.row];
    subview.tag = TAG_SUBVIEW_UITEXTFIELD;
    [cell addSubview:subview];
    return cell;
}

@end
