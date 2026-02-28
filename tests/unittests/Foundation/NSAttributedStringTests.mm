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
#import <CoreFoundation/CFAttributedString.h>
#import <Foundation/Foundation.h>
#import <windows.h>
#import <vector>

static NSString* c_defaultAttributeName = @"defaultAttributeName";

void assertAttributeAt(
    NSAttributedString* aStr, NSString* attrName, id expectedValue, NSUInteger expectedLocation, NSUInteger expectedLength) {
    NSRange outRange{};

    id attribute = [aStr attribute:attrName atIndex:expectedLocation effectiveRange:&outRange];
    ASSERT_EQ(expectedValue, attribute);
    ASSERT_EQ(expectedLocation, outRange.location);
    ASSERT_EQ(expectedLength, outRange.length);

    // Do a redundant check at the end of the range for safety
    attribute = [aStr attribute:attrName atIndex:(expectedLocation + expectedLength - 1) effectiveRange:&outRange];
    ASSERT_EQ(expectedValue, attribute);
    ASSERT_EQ(expectedLocation, outRange.location);
    ASSERT_EQ(expectedLength, outRange.length);
}

NSMutableAttributedString* SixCharacterTestString() {
    return [[[NSMutableAttributedString alloc] initWithString:@"AAAAAA"] autorelease];
}

// Exercise the CFAttrList functions

TEST(NSAttributedString, Add) {
    NSMutableAttributedString* aStr = SixCharacterTestString();
    [aStr addAttribute:c_defaultAttributeName value:@"value1" range:NSMakeRange(2, 2)];

    assertAttributeAt(aStr, c_defaultAttributeName, @"value1", 2, 2);
}

TEST(NSAttributedString, AddBeforeAndAfter) {
    NSMutableAttributedString* aStr = SixCharacterTestString();
    [aStr addAttribute:c_defaultAttributeName value:@"value1" range:NSMakeRange(2, 2)];
    [aStr addAttribute:c_defaultAttributeName value:@"value1" range:NSMakeRange(0, 1)];
    [aStr addAttribute:c_defaultAttributeName value:@"value1" range:NSMakeRange(5, 1)];

    assertAttributeAt(aStr, c_defaultAttributeName, @"value1", 0, 1);
    assertAttributeAt(aStr, c_defaultAttributeName, @"value1", 2, 2);
    assertAttributeAt(aStr, c_defaultAttributeName, @"value1", 5, 1);
}

// Conflict resolution occurs lazily on OSX, but immediately on iOS
OSX_DISABLED_TEST(NSAttributedString, CoalesceOverlapAfter) {
    NSMutableAttributedString* aStr = SixCharacterTestString();
    [aStr addAttribute:c_defaultAttributeName value:@"value1" range:NSMakeRange(2, 2)];
    [aStr addAttribute:c_defaultAttributeName value:@"value1" range:NSMakeRange(3, 2)];

    assertAttributeAt(aStr, c_defaultAttributeName, @"value1", 2, 3);
}

// Conflict resolution occurs lazily on OSX, but immediately on iOS
OSX_DISABLED_TEST(NSAttributedString, CoalesceAdjacentAfter) {
    NSMutableAttributedString* aStr = SixCharacterTestString();
    [aStr addAttribute:c_defaultAttributeName value:@"value1" range:NSMakeRange(2, 2)];
    [aStr addAttribute:c_defaultAttributeName value:@"value1" range:NSMakeRange(4, 2)];

    assertAttributeAt(aStr, c_defaultAttributeName, @"value1", 2, 4);
}

// Conflict resolution occurs lazily on OSX, but immediately on iOS
OSX_DISABLED_TEST(NSAttributedString, CoalesceOverlapBefore) {
    NSMutableAttributedString* aStr = SixCharacterTestString();
    [aStr addAttribute:c_defaultAttributeName value:@"value1" range:NSMakeRange(2, 2)];
    [aStr addAttribute:c_defaultAttributeName value:@"value1" range:NSMakeRange(1, 2)];

    assertAttributeAt(aStr, c_defaultAttributeName, @"value1", 1, 3);
}

// Conflict resolution occurs lazily on OSX, but immediately on iOS
OSX_DISABLED_TEST(NSAttributedString, CoalesceAdjacentBefore) {
    NSMutableAttributedString* aStr = SixCharacterTestString();
    [aStr addAttribute:c_defaultAttributeName value:@"value1" range:NSMakeRange(2, 2)];
    [aStr addAttribute:c_defaultAttributeName value:@"value1" range:NSMakeRange(0, 2)];

    assertAttributeAt(aStr, c_defaultAttributeName, @"value1", 0, 4);
}

// Conflict resolution occurs lazily on OSX, but immediately on iOS
OSX_DISABLED_TEST(NSAttributedString, CoalesceComplex) {
    NSMutableAttributedString* aStr = SixCharacterTestString();
    [aStr addAttribute:c_defaultAttributeName value:@"value1" range:NSMakeRange(2, 2)];
    [aStr addAttribute:c_defaultAttributeName value:@"value1" range:NSMakeRange(0, 2)];
    [aStr addAttribute:c_defaultAttributeName value:@"value1" range:NSMakeRange(4, 1)];
    [aStr addAttribute:c_defaultAttributeName value:@"value1" range:NSMakeRange(4, 2)];

    assertAttributeAt(aStr, c_defaultAttributeName, @"value1", 0, 6);
}

TEST(NSAttributedString, RemoveBefore) {
    NSMutableAttributedString* aStr = SixCharacterTestString();
    [aStr addAttribute:c_defaultAttributeName value:@"value1" range:NSMakeRange(2, 2)];
    [aStr removeAttribute:c_defaultAttributeName range:NSMakeRange(1, 2)];

    assertAttributeAt(aStr, c_defaultAttributeName, @"value1", 3, 1);
}

TEST(NSAttributedString, RemoveAfter) {
    NSMutableAttributedString* aStr = SixCharacterTestString();
    [aStr addAttribute:c_defaultAttributeName value:@"value1" range:NSMakeRange(2, 2)];
    [aStr removeAttribute:c_defaultAttributeName range:NSMakeRange(3, 2)];

    assertAttributeAt(aStr, c_defaultAttributeName, @"value1", 2, 1);
}

TEST(NSAttributedString, RemoveCenter) {
    NSMutableAttributedString* aStr = SixCharacterTestString();
    [aStr addAttribute:c_defaultAttributeName value:@"value1" range:NSMakeRange(1, 4)];
    [aStr removeAttribute:c_defaultAttributeName range:NSMakeRange(2, 2)];

    assertAttributeAt(aStr, c_defaultAttributeName, @"value1", 1, 1);
    assertAttributeAt(aStr, c_defaultAttributeName, @"value1", 4, 1);
}

TEST(NSAttributedString, RemoveAll) {
    NSMutableAttributedString* aStr = SixCharacterTestString();
    [aStr addAttribute:c_defaultAttributeName value:@"value1" range:NSMakeRange(1, 4)];
    [aStr removeAttribute:c_defaultAttributeName range:NSMakeRange(1, 4)];

    assertAttributeAt(aStr, c_defaultAttributeName, nil, 0, 6);

    [aStr addAttribute:c_defaultAttributeName value:@"value1" range:NSMakeRange(1, 4)];
    [aStr removeAttribute:c_defaultAttributeName range:NSMakeRange(0, 6)];
    assertAttributeAt(aStr, c_defaultAttributeName, nil, 0, 6);
}

// Conflict resolution occurs lazily on OSX, but immediately on iOS
OSX_DISABLED_TEST(NSAttributedString, OverwriteAfter) {
    NSMutableAttributedString* aStr = SixCharacterTestString();
    [aStr addAttribute:c_defaultAttributeName value:@"value1" range:NSMakeRange(2, 2)];
    [aStr addAttribute:c_defaultAttributeName value:@"value2" range:NSMakeRange(3, 2)];

    assertAttributeAt(aStr, c_defaultAttributeName, @"value1", 2, 1);
    assertAttributeAt(aStr, c_defaultAttributeName, @"value2", 3, 2);
}

// Conflict resolution occurs lazily on OSX, but immediately on iOS
OSX_DISABLED_TEST(NSAttributedString, OverwriteBefore) {
    NSMutableAttributedString* aStr = SixCharacterTestString();
    [aStr addAttribute:c_defaultAttributeName value:@"value2" range:NSMakeRange(2, 2)];
    [aStr addAttribute:c_defaultAttributeName value:@"value1" range:NSMakeRange(1, 2)];

    assertAttributeAt(aStr, c_defaultAttributeName, @"value2", 3, 1);
    assertAttributeAt(aStr, c_defaultAttributeName, @"value1", 1, 2);
}

TEST(NSAttributedString, NoOverwrite) {
    NSMutableAttributedString* aStr = SixCharacterTestString();
    [aStr addAttribute:c_defaultAttributeName value:@"value2" range:NSMakeRange(2, 2)];
    [aStr addAttribute:c_defaultAttributeName value:@"value1" range:NSMakeRange(0, 2)];
    [aStr addAttribute:c_defaultAttributeName value:@"value3" range:NSMakeRange(4, 2)];

    assertAttributeAt(aStr, c_defaultAttributeName, @"value1", 0, 2);
    assertAttributeAt(aStr, c_defaultAttributeName, @"value2", 2, 2);
    assertAttributeAt(aStr, c_defaultAttributeName, @"value3", 4, 2);
}

TEST(NSAttributedString, ReplaceConstantInner) {
    NSMutableAttributedString* aStr = SixCharacterTestString();
    [aStr addAttribute:c_defaultAttributeName value:@"value1" range:NSMakeRange(1, 4)];
    [aStr replaceCharactersInRange:NSMakeRange(2, 2) withString:@"BB"];

    assertAttributeAt(aStr, c_defaultAttributeName, @"value1", 1, 4);
    ASSERT_OBJCEQ(@"AABBAA", [aStr string]);
}

TEST(NSAttributedString, ReplaceExpandInner) {
    NSMutableAttributedString* aStr = SixCharacterTestString();
    [aStr addAttribute:c_defaultAttributeName value:@"value1" range:NSMakeRange(1, 4)];
    [aStr replaceCharactersInRange:NSMakeRange(2, 2) withString:@"BBBB"];

    assertAttributeAt(aStr, c_defaultAttributeName, @"value1", 1, 6);
    ASSERT_OBJCEQ(@"AABBBBAA", [aStr string]);
}

TEST(NSAttributedString, ReplaceContractInner) {
    NSMutableAttributedString* aStr = SixCharacterTestString();
    [aStr addAttribute:c_defaultAttributeName value:@"value1" range:NSMakeRange(1, 4)];
    [aStr replaceCharactersInRange:NSMakeRange(2, 2) withString:@""];

    assertAttributeAt(aStr, c_defaultAttributeName, @"value1", 1, 2);
    ASSERT_OBJCEQ(@"AAAA", [aStr string]);
}

TEST(NSAttributedString, ReplaceExpandOuter) {
    NSMutableAttributedString* aStr = SixCharacterTestString();
    [aStr addAttribute:c_defaultAttributeName value:@"value1" range:NSMakeRange(2, 2)];

    [aStr replaceCharactersInRange:NSMakeRange(3, 2) withString:@"BBBB"];
    assertAttributeAt(aStr, c_defaultAttributeName, @"value1", 2, 5); // +1 not originally in attribute range, +2 string length
    ASSERT_OBJCEQ(@"AAABBBBA", [aStr string]);

    [aStr replaceCharactersInRange:NSMakeRange(2, 2) withString:@"CCCC"];
    assertAttributeAt(aStr, c_defaultAttributeName, @"value1", 2, 7); // +2 string length
    ASSERT_OBJCEQ(@"AACCCCBBBA", [aStr string]);

    [aStr replaceCharactersInRange:NSMakeRange(0, 10) withString:@"DDDDDDDDDDDD"]; // 12 chars now
    assertAttributeAt(aStr, c_defaultAttributeName, nil, 0, 12);
    ASSERT_OBJCEQ(@"DDDDDDDDDDDD", [aStr string]);
}

TEST(NSAttributedString, ReplaceContractOuter) {
    NSMutableAttributedString* aStr = SixCharacterTestString();
    [aStr addAttribute:c_defaultAttributeName value:@"value1" range:NSMakeRange(1, 4)];

    [aStr replaceCharactersInRange:NSMakeRange(3, 2) withString:@"B"];
    assertAttributeAt(aStr, c_defaultAttributeName, @"value1", 1, 3); // -1 string length
    ASSERT_OBJCEQ(@"AAABA", [aStr string]);

    [aStr replaceCharactersInRange:NSMakeRange(0, 2) withString:@""];
    assertAttributeAt(aStr, c_defaultAttributeName, @"value1", 0, 2); // +1 not originally in attribute range, -2 string length
    ASSERT_OBJCEQ(@"ABA", [aStr string]);

    [aStr replaceCharactersInRange:NSMakeRange(0, 3) withString:@"D"];
    assertAttributeAt(aStr, c_defaultAttributeName, @"value1", 0, 1);
    ASSERT_OBJCEQ(@"D", [aStr string]);
}

TEST(NSAttributedString, ReplaceAdjacent) {
    NSMutableAttributedString* aStr = SixCharacterTestString();
    [aStr addAttribute:c_defaultAttributeName value:@"value1" range:NSMakeRange(2, 2)];

    [aStr replaceCharactersInRange:NSMakeRange(0, 2) withString:@"B"];
    assertAttributeAt(aStr, c_defaultAttributeName, @"value1", 1, 2); // Should not have expanded the attribute
    ASSERT_OBJCEQ(@"BAAAA", [aStr string]);
}

TEST(NSAttributedString, ReplaceOverwriteExpand) {
    NSMutableAttributedString* aStr = SixCharacterTestString();
    [aStr addAttribute:c_defaultAttributeName value:@"value1" range:NSMakeRange(0, 2)];
    [aStr addAttribute:c_defaultAttributeName value:@"value2" range:NSMakeRange(2, 2)];

    [aStr replaceCharactersInRange:NSMakeRange(1, 2) withString:@"BBBB"];
    assertAttributeAt(aStr, c_defaultAttributeName, @"value1", 0, 5);
    assertAttributeAt(aStr, c_defaultAttributeName, @"value2", 5, 1);
    ASSERT_OBJCEQ(@"ABBBBAAA", [aStr string]);
}

TEST(NSAttributedString, ReplaceOverwriteContract) {
    NSMutableAttributedString* aStr = SixCharacterTestString();
    [aStr addAttribute:c_defaultAttributeName value:@"value1" range:NSMakeRange(2, 2)];
    [aStr addAttribute:c_defaultAttributeName value:@"value2" range:NSMakeRange(4, 2)];

    [aStr replaceCharactersInRange:NSMakeRange(3, 2) withString:@"B"];
    assertAttributeAt(aStr, c_defaultAttributeName, @"value1", 2, 2);
    assertAttributeAt(aStr, c_defaultAttributeName, @"value2", 4, 1);
    ASSERT_OBJCEQ(@"AAABA", [aStr string]);
}

TEST(NSAttributedString, ReplaceOverwriteMultiple) {
    NSMutableAttributedString* aStr = SixCharacterTestString();
    [aStr addAttribute:c_defaultAttributeName value:@"value1" range:NSMakeRange(1, 1)];
    [aStr addAttribute:c_defaultAttributeName value:@"value2" range:NSMakeRange(2, 1)];
    [aStr addAttribute:c_defaultAttributeName value:@"value3" range:NSMakeRange(3, 1)];
    [aStr addAttribute:c_defaultAttributeName value:@"value4" range:NSMakeRange(4, 1)];

    [aStr replaceCharactersInRange:NSMakeRange(1, 4) withString:@"BBBBBBBB"];
    assertAttributeAt(aStr, c_defaultAttributeName, @"value1", 1, 8);
    ASSERT_OBJCEQ(@"ABBBBBBBBA", [aStr string]);
}

// Test unexercised exposed interfaces
TEST(NSAttributedString, AddAttributeToMultipleKeys) {
    NSMutableAttributedString* aStr = SixCharacterTestString();
    [aStr addAttribute:@"key1" value:@"value1" range:NSMakeRange(1, 1)];
    [aStr addAttribute:@"key2" value:@"value2" range:NSMakeRange(3, 1)];
    [aStr addAttribute:@"key3" value:@"value3" range:NSMakeRange(3, 1)];

    assertAttributeAt(aStr, @"key1", @"value1", 1, 1);
    assertAttributeAt(aStr, @"key2", @"value2", 3, 1);
    assertAttributeAt(aStr, @"key3", @"value3", 3, 1);
}

TEST(NSAttributedString, SetAttributes) {
    NSMutableAttributedString* aStr = SixCharacterTestString();
    [aStr addAttribute:@"key1" value:@"value1" range:NSMakeRange(1, 4)];
    [aStr addAttribute:@"key2" value:@"value2" range:NSMakeRange(1, 4)];

    NSDictionary* attrs = [NSDictionary dictionaryWithObjectsAndKeys:@"value1NEW", @"key1", @"value2NEW", @"key2", nil];

    [aStr setAttributes:attrs range:NSMakeRange(2, 2)];

    assertAttributeAt(aStr, @"key1", @"value1", 1, 1);
    assertAttributeAt(aStr, @"key1", @"value1NEW", 2, 2);
    assertAttributeAt(aStr, @"key1", @"value1", 4, 1);
    assertAttributeAt(aStr, @"key2", @"value2", 1, 1);
    assertAttributeAt(aStr, @"key2", @"value2NEW", 2, 2);
    assertAttributeAt(aStr, @"key2", @"value2", 4, 1);
    ASSERT_OBJCEQ(@"AAAAAA", [aStr string]);
}

TEST(NSAttributedString, AddAttributes) {
    NSMutableAttributedString* aStr = SixCharacterTestString();
    NSDictionary* attrs = [NSDictionary dictionaryWithObjectsAndKeys:@"value1", @"key1", @"value2", @"key2", nil];
    [aStr addAttributes:attrs range:NSMakeRange(2, 2)];

    assertAttributeAt(aStr, @"key1", @"value1", 2, 2);
    assertAttributeAt(aStr, @"key2", @"value2", 2, 2);
}

TEST(NSAttributedString, InitWithString) {
    NSAttributedString* aStr = [[[NSAttributedString alloc] initWithString:@"OBJ"] autorelease];
    ASSERT_OBJCEQ(@"OBJ", [aStr string]);
    ASSERT_EQ(3, [aStr length]);
    assertAttributeAt(aStr, c_defaultAttributeName, nil, 0, 3);
}

TEST(NSAttributedString, InitWithStringAttributes) {
    NSDictionary* attrs = [NSDictionary dictionaryWithObjectsAndKeys:@"value1", @"key1", @"value2", @"key2", nil];
    NSAttributedString* aStr = [[[NSAttributedString alloc] initWithString:@"OBJ" attributes:attrs] autorelease];

    ASSERT_OBJCEQ(@"OBJ", [aStr string]);
    ASSERT_EQ(3, [aStr length]);

    assertAttributeAt(aStr, @"key1", @"value1", 0, 3);
    assertAttributeAt(aStr, @"key2", @"value2", 0, 3);
    assertAttributeAt(aStr, @"keyThatShouldntBeThere", nil, 0, 3);
}

TEST(NSAttributedString, InitWithAttributedString) {
    NSDictionary* attrs = [NSDictionary dictionaryWithObjectsAndKeys:@"value1", @"key1", @"value2", @"key2", nil];
    NSAttributedString* aStrBase = [[[NSAttributedString alloc] initWithString:@"OBJ" attributes:attrs] autorelease];
    NSAttributedString* aStr = [[[NSAttributedString alloc] initWithAttributedString:aStrBase] autorelease];

    ASSERT_OBJCEQ(@"OBJ", [aStr string]);
    ASSERT_EQ(3, [aStr length]);

    assertAttributeAt(aStr, @"key1", @"value1", 0, 3);
    assertAttributeAt(aStr, @"key2", @"value2", 0, 3);
    assertAttributeAt(aStr, @"keyThatShouldntBeThere", nil, 0, 3);
}

TEST(NSAttributedString, AttributeAtIndexNoRange) {
    NSDictionary* attrs = [NSDictionary dictionaryWithObjectsAndKeys:@"value1", @"key1", @"value2", @"key2", nil];
    NSAttributedString* aStr = [[[NSAttributedString alloc] initWithString:@"OBJ" attributes:attrs] autorelease];

    ASSERT_OBJCEQ(@"value1", [aStr attribute:@"key1" atIndex:1 effectiveRange:nullptr]);
    ASSERT_OBJCEQ(@"value2", [aStr attribute:@"key2" atIndex:1 effectiveRange:nullptr]);
}

TEST(NSAttributedString, AttributeAtIndexInRange) {
    NSMutableAttributedString* aStr = SixCharacterTestString();
    [aStr addAttribute:@"key1" value:@"value1" range:NSMakeRange(2, 2)];

    NSRange outRange;
    id attribute = [aStr attribute:@"key1" atIndex:3 longestEffectiveRange:&outRange inRange:NSMakeRange(1, 2)];
    ASSERT_OBJCEQ(@"value1", attribute);
    ASSERT_EQ(2, outRange.location);
    ASSERT_EQ(1, outRange.length);
}

TEST(NSAttributedString, AttributesAtIndex) {
    NSMutableAttributedString* aStr = SixCharacterTestString();
    [aStr addAttribute:@"key1" value:@"value1" range:NSMakeRange(2, 2)];
    [aStr addAttribute:@"key2" value:@"value2" range:NSMakeRange(3, 2)];

    [aStr addAttribute:@"key1" value:@"value1" range:NSMakeRange(0, 1)];

    NSDictionary* attrsAt0 = [aStr attributesAtIndex:0 effectiveRange:nullptr];
    ASSERT_EQ(1, [attrsAt0 count]);
    ASSERT_OBJCEQ(@"value1", [attrsAt0 objectForKey:@"key1"]);

    NSRange outRange;
    NSDictionary* attrsAt3 = [aStr attributesAtIndex:3 effectiveRange:&outRange];
    ASSERT_EQ(2, [attrsAt3 count]);
    ASSERT_OBJCEQ(@"value1", [attrsAt3 objectForKey:@"key1"]);
    ASSERT_OBJCEQ(@"value2", [attrsAt3 objectForKey:@"key2"]);
    ASSERT_EQ(3, outRange.location);
    ASSERT_EQ(1, outRange.length);
}

TEST(NSAttributedString, AttributesAtIndexInRange) {
    NSMutableAttributedString* aStr = SixCharacterTestString();
    [aStr addAttribute:@"key1" value:@"value1" range:NSMakeRange(1, 3)];
    [aStr addAttribute:@"key2" value:@"value2" range:NSMakeRange(0, 4)];

    NSRange outRange;
    NSDictionary* attrsAt3 = [aStr attributesAtIndex:2 longestEffectiveRange:&outRange inRange:NSMakeRange(2, 1)];
    ASSERT_EQ(2, [attrsAt3 count]);
    ASSERT_OBJCEQ(@"value1", [attrsAt3 objectForKey:@"key1"]);
    ASSERT_OBJCEQ(@"value2", [attrsAt3 objectForKey:@"key2"]);
    ASSERT_EQ(2, outRange.location);
    ASSERT_EQ(1, outRange.length);
}

TEST(NSAttributedString, AppendAttributedString) {
    NSMutableAttributedString* aStr = SixCharacterTestString();
    [aStr addAttribute:@"key1" value:@"value1" range:NSMakeRange(2, 4)];
    [aStr addAttribute:@"key3" value:@"value3" range:NSMakeRange(2, 4)];

    NSDictionary* attrs = [NSDictionary dictionaryWithObjectsAndKeys:@"value1", @"key1", @"value2", @"key2", @"notvalue3", @"key3", nil];
    NSAttributedString* aStr2 = [[[NSAttributedString alloc] initWithString:@"OBJ" attributes:attrs] autorelease];

    [aStr appendAttributedString:aStr2];

    assertAttributeAt(aStr, @"key1", @"value1", 2, 4);
    assertAttributeAt(aStr, @"key1", @"value1", 6, 3);
    assertAttributeAt(aStr, @"key2", @"value2", 6, 3);
    assertAttributeAt(aStr, @"key3", @"value3", 2, 4);
    assertAttributeAt(aStr, @"key3", @"notvalue3", 6, 3);
    ASSERT_OBJCEQ(@"AAAAAAOBJ", [aStr string]);
}

TEST(NSAttributedString, DeleteCharactersInRange) {
    NSDictionary* attrs = [NSDictionary dictionaryWithObjectsAndKeys:@"value1", @"key1", @"value2", @"key2", nil];
    NSMutableAttributedString* aStr = [[[NSMutableAttributedString alloc] initWithString:@"OBJ" attributes:attrs] autorelease];

    [aStr deleteCharactersInRange:NSMakeRange(1, 1)];

    assertAttributeAt(aStr, @"key1", @"value1", 0, 2);
    assertAttributeAt(aStr, @"key2", @"value2", 0, 2);
    ASSERT_OBJCEQ(@"OJ", [aStr string]);
}

TEST(NSAttributedString, DeleteCharactersInRangeEmptyString) {
    NSMutableAttributedString* aStr = [[[NSMutableAttributedString alloc] initWithString:@""] autorelease];

    [aStr deleteCharactersInRange:NSMakeRange(0, 0)];
}

TEST(NSAttributedString, InsertAttributedString) {
    NSMutableAttributedString* aStr = SixCharacterTestString();
    [aStr addAttribute:@"key1" value:@"value1" range:NSMakeRange(2, 4)];

    NSDictionary* attrs = [NSDictionary dictionaryWithObjectsAndKeys:@"value1", @"key1", @"value2", @"key2", nil];
    NSMutableAttributedString* aStr2 = [[[NSMutableAttributedString alloc] initWithString:@"OBJ" attributes:attrs] autorelease];
    [aStr2 removeAttribute:@"key1" range:NSMakeRange(2, 1)];

    [aStr insertAttributedString:aStr2 atIndex:5];

    assertAttributeAt(aStr, @"key1", @"value1", 2, 3);
    assertAttributeAt(aStr, @"key1", @"value1", 5, 2);
    assertAttributeAt(aStr, @"key1", @"value1", 8, 1);
    assertAttributeAt(aStr, @"key2", @"value2", 5, 2);
    assertAttributeAt(aStr, @"key2", @"value2", 7, 1);
    ASSERT_OBJCEQ(@"AAAAAOBJA", [aStr string]);
}

TEST(NSAttributedString, IsEqualToAttributedString) {
    NSMutableAttributedString* firstStr = SixCharacterTestString();
    NSMutableAttributedString* secondStr = SixCharacterTestString();
    ASSERT_EQ(YES, [firstStr isEqualToAttributedString:secondStr]);
    ASSERT_EQ(YES, [secondStr isEqualToAttributedString:firstStr]);

    [firstStr addAttribute:@"key1" value:@"value1" range:NSMakeRange(2, 4)];
    ASSERT_EQ(NO, [firstStr isEqualToAttributedString:secondStr]);
    ASSERT_EQ(NO, [secondStr isEqualToAttributedString:firstStr]);

    [secondStr addAttribute:@"key1" value:@"value1" range:NSMakeRange(2, 4)];
    ASSERT_EQ(YES, [firstStr isEqualToAttributedString:secondStr]);
    ASSERT_EQ(YES, [secondStr isEqualToAttributedString:firstStr]);

    [firstStr addAttribute:@"key1" value:@"value1b" range:NSMakeRange(1, 2)];
    [secondStr addAttribute:@"key1" value:@"value1b" range:NSMakeRange(1, 2)];
    [firstStr addAttribute:@"key2" value:@"value2" range:NSMakeRange(0, 3)];
    [secondStr addAttribute:@"key2" value:@"value2" range:NSMakeRange(0, 3)];

    ASSERT_EQ(YES, [firstStr isEqualToAttributedString:secondStr]);
    ASSERT_EQ(YES, [secondStr isEqualToAttributedString:firstStr]);
}

TEST(NSAttributedString, ReplaceCharactersInRangeWithAttributedString) {
    NSMutableAttributedString* aStr = SixCharacterTestString();
    [aStr addAttribute:@"key1" value:@"value1" range:NSMakeRange(2, 4)];

    NSDictionary* attrs = [NSDictionary dictionaryWithObjectsAndKeys:@"value1", @"key1", @"value2", @"key2", nil];
    NSMutableAttributedString* aStr2 = [[[NSMutableAttributedString alloc] initWithString:@"OBJ" attributes:attrs] autorelease];
    [aStr2 removeAttribute:@"key1" range:NSMakeRange(2, 1)];

    [aStr replaceCharactersInRange:NSMakeRange(2, 2) withAttributedString:aStr2];

    assertAttributeAt(aStr, @"key1", @"value1", 2, 2);
    assertAttributeAt(aStr, @"key1", @"value1", 5, 2);
    assertAttributeAt(aStr, @"key2", @"value2", 2, 2);
    assertAttributeAt(aStr, @"key2", @"value2", 4, 1);
    ASSERT_OBJCEQ(@"AAOBJAA", [aStr string]);
}

TEST(NSAttributedString, SetAttributedString) {
    NSMutableAttributedString* aStr = SixCharacterTestString();
    [aStr addAttribute:@"key1" value:@"value1" range:NSMakeRange(2, 4)];
    [aStr addAttribute:@"key3" value:@"value3" range:NSMakeRange(2, 4)];

    NSDictionary* attrs = [NSDictionary dictionaryWithObjectsAndKeys:@"value1", @"key1", @"value2", @"key2", nil];
    NSMutableAttributedString* aStr2 = [[[NSMutableAttributedString alloc] initWithString:@"OBJ" attributes:attrs] autorelease];
    [aStr2 removeAttribute:@"key1" range:NSMakeRange(2, 1)];

    [aStr setAttributedString:aStr2];

    assertAttributeAt(aStr, @"key1", @"value1", 0, 2);
    assertAttributeAt(aStr, @"key2", @"value2", 0, 2);
    assertAttributeAt(aStr, @"key2", @"value2", 2, 1);
    assertAttributeAt(aStr, @"key3", nil, 0, 2);
    assertAttributeAt(aStr, @"key3", nil, 2, 1);
    ASSERT_OBJCEQ(@"OBJ", [aStr string]);
}

// This test is known to fail on Release builds
// TODO: 5902592 THROW_NS_HR does not throw on Release when called through Foundation from unit tests
ARM_DISABLED_TEST(NSAttributedString, ThrowsBounds) {
    NSMutableAttributedString* aStr = SixCharacterTestString();

    bool thrown = false;
    @try {
        [aStr addAttribute:@"key1" value:@"value1" range:NSMakeRange(2, 7)];
    } @catch (NSException* exception) {
        thrown = true;
    }
    ASSERT_TRUE(thrown);
}

TEST(NSAttributedString, AttributedSubstringFromRange) {
    NSMutableAttributedString* aStr = SixCharacterTestString();
    [aStr addAttribute:@"key1" value:@"value1" range:NSMakeRange(2, 2)];
    [aStr addAttribute:@"key2" value:@"value2" range:NSMakeRange(3, 2)];

    NSAttributedString* testString = [aStr attributedSubstringFromRange:NSMakeRange(1, 3)];

    ASSERT_OBJCEQ(@"AAA", [testString string]);
    assertAttributeAt(testString, @"key1", @"value1", 1, 1);
    assertAttributeAt(testString, @"key1", @"value1", 2, 1);
    assertAttributeAt(testString, @"key2", @"value2", 2, 1);
}

TEST(NSAttributedString, EnumerateAttribute) {
    NSMutableAttributedString* aStr = SixCharacterTestString();

    // 0) enumerate with zero attributes
    __block size_t timesEnumerated = 0;
    [aStr enumerateAttribute:@"key1"
                     inRange:NSMakeRange(1, 3)
                     options:NSAttributedStringEnumerationReverse
                  usingBlock:^void(NSDictionary* val, NSRange range, BOOL* stop) {
                      ++timesEnumerated;
                      ASSERT_EQ(0, [val count]);
                      ASSERT_TRUE(NSEqualRanges(NSMakeRange(1, 3), range));
                  }];
    ASSERT_EQ(1, timesEnumerated);

    // test block to pass to enumerateAttribute:
    // iterates through expected data and validates that it's the same as the returned data
    __block size_t index = 0;
    __block std::vector<std::pair<id, NSRange>> testAttributes;
    void (^testBlock)(id, NSRange, BOOL*) = ^void(id val, NSRange range, BOOL* stop) {
        ASSERT_TRUE(index < testAttributes.size());
        const auto& pair = testAttributes.at(index);
        ASSERT_OBJCEQ(pair.first, val);
        ASSERT_TRUE(NSEqualRanges(pair.second, range));
        index += 1;
    };

    // 1) basic test
    testAttributes.insert(testAttributes.end(),
                          { { nil, NSMakeRange(0, 1) },
                            { @"value1", NSMakeRange(1, 1) },
                            { @"value2", NSMakeRange(2, 2) },
                            { @"value3", NSMakeRange(4, 1) },
                            { @"value4", NSMakeRange(5, 1) } });
    for (const auto& pair : testAttributes) {
        if (pair.first) {
            [aStr addAttribute:@"key1" value:pair.first range:pair.second];
        }
    }

    [aStr enumerateAttribute:@"key1"
                     inRange:NSMakeRange(0, 6)
                     options:NSAttributedStringEnumerationLongestEffectiveRangeNotRequired
                  usingBlock:testBlock];
    ASSERT_EQ(testAttributes.size(), index);

    // 2) test with holes, limit the range
    aStr = [[[NSMutableAttributedString alloc] initWithString:@"AAAAAAAAAA"] autorelease]; // 10 characters

    testAttributes.clear();
    testAttributes.insert(testAttributes.end(),
                          { { @"value1", NSMakeRange(1, 1) },
                            { @"value2", NSMakeRange(2, 2) },
                            { nil, NSMakeRange(4, 1) },
                            { @"value3", NSMakeRange(5, 1) },
                            { nil, NSMakeRange(6, 1) },
                            { @"value4", NSMakeRange(7, 3) } });

    for (const auto& pair : testAttributes) {
        if (pair.first) {
            [aStr addAttribute:@"key1" value:pair.first range:pair.second];
        }
    }

    // limit range to {2, 7}, excluding the first attribute and clipping part of the last
    index = 1;
    testAttributes[5].second = NSMakeRange(7, 2);
    [aStr enumerateAttribute:@"key1"
                     inRange:NSMakeRange(2, 7)
                     options:NSAttributedStringEnumerationLongestEffectiveRangeNotRequired
                  usingBlock:testBlock];
    ASSERT_EQ(testAttributes.size(), index);

    // 3) iterate in reverse, use longestEffectiveRange
    aStr = [[[NSMutableAttributedString alloc] initWithString:@"AAAAAAAAAA"] autorelease]; // 10 characters

    testAttributes.clear();
    testAttributes.insert(testAttributes.end(),
                          { { @"value4", NSMakeRange(7, 3) },
                            { nil, NSMakeRange(6, 1) },
                            { @"value3", NSMakeRange(5, 1) },
                            { nil, NSMakeRange(4, 1) },
                            { @"value2", NSMakeRange(2, 2) },
                            { @"value1", NSMakeRange(1, 1) } });

    for (const auto& pair : testAttributes) {
        if (pair.first) {
            [aStr addAttribute:@"key1" value:pair.first range:pair.second];
        }
    }

    // due to longest effective range being used, the expected range is different from the input
    testAttributes.at(0).second = NSMakeRange(7, 2);

    index = 0;
    [aStr enumerateAttribute:@"key1" inRange:NSMakeRange(2, 7) options:NSAttributedStringEnumerationReverse usingBlock:testBlock];
    ASSERT_EQ(testAttributes.size() - 1, index); // last attribute is out of range
}

TEST(NSAttributedString, EnumerateAttributeAndChangeLength) {
    NSMutableAttributedString* baseStr = [[[NSMutableAttributedString alloc] initWithString:@"ABCDEF"] autorelease];
    [baseStr addAttribute:@"key1" value:@"value1" range:NSMakeRange(0, 1)];
    [baseStr addAttribute:@"key1" value:@"value2" range:NSMakeRange(1, 1)];
    [baseStr addAttribute:@"key1" value:@"value3" range:NSMakeRange(2, 1)];
    [baseStr addAttribute:@"key1" value:@"value4" range:NSMakeRange(3, 1)];
    [baseStr addAttribute:@"key1" value:@"value5" range:NSMakeRange(4, 1)];
    [baseStr addAttribute:@"key1" value:@"value6" range:NSMakeRange(5, 1)];

    // 1) increase length, forward
    __block NSMutableAttributedString* testString1 = [[[NSMutableAttributedString alloc] initWithAttributedString:baseStr] autorelease];
    [testString1 enumerateAttribute:@"key1"
                            inRange:NSMakeRange(2, 2)
                            options:NSAttributedStringEnumerationLongestEffectiveRangeNotRequired
                         usingBlock:^void(id val, NSRange range, BOOL* stop) {
                             [testString1 replaceCharactersInRange:range withString:@"ZZ"];
                         }];
    ASSERT_OBJCEQ(@"ABZZZZEF", [testString1 string]);

    // 2) increase length, reverse
    __block NSMutableAttributedString* testString2 = [[[NSMutableAttributedString alloc] initWithAttributedString:baseStr] autorelease];
    [testString2 enumerateAttribute:@"key1"
                            inRange:NSMakeRange(2, 2)
                            options:NSAttributedStringEnumerationLongestEffectiveRangeNotRequired | NSAttributedStringEnumerationReverse
                         usingBlock:^void(id val, NSRange range, BOOL* stop) {
                             [testString2 replaceCharactersInRange:range withString:@"ZZ"];
                         }];
    ASSERT_OBJCEQ(@"ABZZZZEF", [testString2 string]);

    // 3) decrease length, forward
    __block NSMutableAttributedString* testString3 = [[[NSMutableAttributedString alloc] initWithAttributedString:baseStr] autorelease];
    [testString3 enumerateAttribute:@"key1"
                            inRange:NSMakeRange(2, 2)
                            options:NSAttributedStringEnumerationLongestEffectiveRangeNotRequired
                         usingBlock:^void(id val, NSRange range, BOOL* stop) {
                             [testString3 deleteCharactersInRange:range];
                         }];
    ASSERT_OBJCEQ(@"ABEF", [testString3 string]);

    // 4) decrease length, reverse
    __block NSMutableAttributedString* testString4 = [[[NSMutableAttributedString alloc] initWithAttributedString:baseStr] autorelease];
    [testString4 enumerateAttribute:@"key1"
                            inRange:NSMakeRange(2, 2)
                            options:NSAttributedStringEnumerationLongestEffectiveRangeNotRequired | NSAttributedStringEnumerationReverse
                         usingBlock:^void(id val, NSRange range, BOOL* stop) {
                             [testString4 deleteCharactersInRange:range];
                         }];
    ASSERT_OBJCEQ(@"ABEF", [testString4 string]);

    // 5) decrease length, reverse, stop early
    __block NSMutableAttributedString* testString5 = [[[NSMutableAttributedString alloc] initWithAttributedString:baseStr] autorelease];
    [testString5 enumerateAttribute:@"key1"
                            inRange:NSMakeRange(1, 4)
                            options:NSAttributedStringEnumerationLongestEffectiveRangeNotRequired | NSAttributedStringEnumerationReverse
                         usingBlock:^void(id val, NSRange range, BOOL* stop) {
                             [testString5 deleteCharactersInRange:range];
                             *stop = YES;
                         }];
    ASSERT_OBJCEQ(@"ABCDF", [testString5 string]);
}

TEST(NSAttributedString, EnumerateAttributes) {
    NSMutableAttributedString* aStr = SixCharacterTestString();

    // enumerate with zero attributes
    __block size_t timesEnumerated = 0;
    [aStr enumerateAttributesInRange:NSMakeRange(1, 3)
                             options:0
                          usingBlock:^void(NSDictionary* val, NSRange range, BOOL* stop) {
                              ++timesEnumerated;
                              ASSERT_EQ(0, [val count]);
                              ASSERT_TRUE(NSEqualRanges(NSMakeRange(1, 3), range));
                          }];
    ASSERT_EQ(1, timesEnumerated);

    [aStr addAttribute:@"key1" value:@"value1" range:NSMakeRange(2, 2)];
    [aStr addAttribute:@"key2" value:@"value2" range:NSMakeRange(1, 2)];
    [aStr addAttribute:@"key3" value:@"value3" range:NSMakeRange(2, 4)];
    [aStr addAttribute:@"key2" value:@"value2" range:NSMakeRange(5, 1)];

    // test block to pass to enumerateAttributes:
    // iterates through expected data and validates that it's the same as the returned data
    __block size_t index = 0;
    __block auto expectedAttributes = std::vector<std::pair<NSDictionary*, NSRange>>(
        { { @{ @"key3" : @"value3" }, NSMakeRange(4, 1) },
          { @{ @"key1" : @"value1", @"key3" : @"value3" }, NSMakeRange(3, 1) },
          { @{ @"key1" : @"value1", @"key2" : @"value2", @"key3" : @"value3" }, NSMakeRange(2, 1) } });
    void (^testBlock)(NSDictionary*, NSRange, BOOL*) = ^void(NSDictionary* val, NSRange range, BOOL* stop) {
        ASSERT_TRUE(index < expectedAttributes.size());
        const auto& pair = expectedAttributes.at(index);
        ASSERT_OBJCEQ(pair.first, val);
        ASSERT_TRUE(NSEqualRanges(pair.second, range));
        index += 1;
    };

    [aStr enumerateAttributesInRange:NSMakeRange(2, 3) options:NSAttributedStringEnumerationReverse usingBlock:testBlock];
    ASSERT_EQ(expectedAttributes.size(), index);
}

@interface NSAttributedStringTestSubclassNoOverrides : NSAttributedString
@end

@implementation NSAttributedStringTestSubclassNoOverrides
@end

@interface NSAttributedStringTestSubclassMethodOverride : NSAttributedString
@property BOOL methodCalled;
@end

@implementation NSAttributedStringTestSubclassMethodOverride
- (NSUInteger)length {
    _methodCalled = YES;
    return 2;
}

@end

TEST(NSAttributedString, Subclass) {
    NSAttributedStringTestSubclassNoOverrides* noOverride = [[NSAttributedStringTestSubclassNoOverrides new] autorelease];
    EXPECT_ANY_THROW([noOverride length]);
    EXPECT_ANY_THROW(CFAttributedStringGetLength((__bridge CFAttributedStringRef)noOverride));

    NSAttributedStringTestSubclassMethodOverride* didOverride = [[NSAttributedStringTestSubclassMethodOverride new] autorelease];
    ASSERT_EQ(2, [didOverride length]);
    ASSERT_EQ(YES, [didOverride methodCalled]);

    [didOverride setMethodCalled:NO];
    ASSERT_EQ(2, CFAttributedStringGetLength((__bridge CFAttributedStringRef)didOverride));
    ASSERT_EQ(YES, [didOverride methodCalled]);
}

DISABLED_TEST(NSAttributedString, MutableInstanceArchivesAsMutable) {
    NSMutableAttributedString* input = [[[NSMutableAttributedString alloc] initWithString:@"hello"] autorelease];

    NSData* data = [NSKeyedArchiver archivedDataWithRootObject:input];
    ASSERT_OBJCNE(nil, data);

    NSMutableAttributedString* output = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    ASSERT_OBJCNE(nil, output);

    EXPECT_NO_THROW([output appendAttributedString:[[[NSMutableAttributedString alloc] initWithString:@" world"] autorelease]]);
    EXPECT_OBJCEQ(@"hello world", [output string]);

    EXPECT_OBJCNE(input, output);
}

TEST(NSMutableAttributedString, InsertingNilShouldThrow) {
    NSMutableAttributedString* string = [[[NSMutableAttributedString alloc] initWithString:@"hello"] autorelease];
    EXPECT_ANY_THROW([string addAttribute:@"attribute" value:nil range:NSMakeRange(0, 3)]);
}