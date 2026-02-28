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

#include <TestFramework.h>
#import <Foundation/Foundation.h>
#import <Starboard/SmartTypes.h>

TEST(NSIndexPath, Init) {
    NSIndexPath* path = [[[NSIndexPath alloc] init] autorelease];
    ASSERT_NE(nil, path);
    EXPECT_EQ(0, [path length]);
    EXPECT_EQ(NSNotFound, [path indexAtPosition:0]);
}

TEST(NSIndexPath, InitWithIndex) {
    NSIndexPath* path = [[[NSIndexPath alloc] initWithIndex:5] autorelease];
    ASSERT_NE(nil, path);
    EXPECT_EQ(1, [path length]);
    EXPECT_EQ(5, [path indexAtPosition:0]);
    EXPECT_EQ(NSNotFound, [path indexAtPosition:1]);

    NSIndexPath* other = [NSIndexPath indexPathWithIndex:5];
    EXPECT_OBJCEQ(path, other);
}

TEST(NSIndexPath, InitWithIndexes) {
    NSUInteger indexes[3] = { 1, 2, 3 };
    NSIndexPath* path = [[[NSIndexPath alloc] initWithIndexes:indexes length:3] autorelease];
    ASSERT_NE(nil, path);
    EXPECT_EQ(3, [path length]);
    EXPECT_EQ(1, [path indexAtPosition:0]);
    EXPECT_EQ(2, [path indexAtPosition:1]);
    EXPECT_EQ(3, [path indexAtPosition:2]);
    EXPECT_EQ(NSNotFound, [path indexAtPosition:4]);

    NSIndexPath* other = [NSIndexPath indexPathWithIndexes:indexes length:3];
    EXPECT_OBJCEQ(path, other);
}

TEST(NSIndexPath, IndexPathByAddingIndex) {
    NSIndexPath* path = [[[NSIndexPath alloc] init] autorelease];
    NSIndexPath* other = [path indexPathByAddingIndex:1];
    EXPECT_EQ(0, [path length]);
    EXPECT_EQ(1, [other length]);
    EXPECT_EQ(1, [other indexAtPosition:0]);

    NSUInteger indexes[3] = { 1, 2, 3 };
    path = [[[NSIndexPath alloc] initWithIndexes:indexes length:3] autorelease];
    other = [path indexPathByAddingIndex:4];
    EXPECT_EQ(3, [path length]);
    EXPECT_EQ(4, [other length]);
    EXPECT_EQ(1, [other indexAtPosition:0]);
    EXPECT_EQ(2, [other indexAtPosition:1]);
    EXPECT_EQ(3, [other indexAtPosition:2]);
    EXPECT_EQ(4, [other indexAtPosition:3]);
}

TEST(NSIndexPath, IndexPathByRemovingLastIndex) {
    NSIndexPath* path = [[[NSIndexPath alloc] init] autorelease];
    NSIndexPath* other = [path indexPathByRemovingLastIndex];
    EXPECT_OBJCEQ(path, other);

    NSUInteger indexes[3] = { 1, 2, 3 };
    path = [[[NSIndexPath alloc] initWithIndexes:indexes length:3] autorelease];
    other = [path indexPathByRemovingLastIndex];
    EXPECT_EQ(3, [path length]);
    EXPECT_EQ(2, [other length]);
    EXPECT_EQ(1, [other indexAtPosition:0]);
    EXPECT_EQ(2, [other indexAtPosition:1]);
    EXPECT_EQ(NSNotFound, [other indexAtPosition:2]);
}

TEST(NSIndexPath, Copy) {
    NSIndexPath* path = [[[NSIndexPath alloc] init] autorelease];
    NSIndexPath* copyPath = [[path copy] autorelease];
    EXPECT_OBJCEQ(path, copyPath);

    NSUInteger indexes[3] = { 1, 2, 3 };
    path = [[[NSIndexPath alloc] initWithIndexes:indexes length:3] autorelease];
    copyPath = [[path copy] autorelease];
    EXPECT_OBJCEQ(path, copyPath);
}

TEST(NSIndexPath, GetIndexes) {
    NSUInteger indexes[3] = { 1, 2, 3 };
    NSUInteger values[4] = { 12345, 12345, 12345, 12345 };
    NSIndexPath* path = [[[NSIndexPath alloc] init] autorelease];
    [path getIndexes:values];
    EXPECT_EQ(12345, values[0]);

    path = [[[NSIndexPath alloc] initWithIndexes:indexes length:3] autorelease];
    [path getIndexes:values];
    EXPECT_EQ(1, values[0]);
    EXPECT_EQ(2, values[1]);
    EXPECT_EQ(3, values[2]);
    EXPECT_EQ(12345, values[3]);
}

TEST(NSIndexPath, GetIndexesRange) {
    NSUInteger indexes[3] = { 1, 2, 3 };
    NSIndexPath* path = [[[NSIndexPath alloc] initWithIndexes:indexes length:3] autorelease];

    NSUInteger values[4] = { 12345, 12345, 12345, 12345 };
    EXPECT_ANY_THROW([path getIndexes:values range:NSMakeRange(0, 4)]);
    EXPECT_ANY_THROW([path getIndexes:values range:NSMakeRange(4, 1)]);
    EXPECT_ANY_THROW([path getIndexes:values range:NSMakeRange(2, 2)]);
    EXPECT_NO_THROW([path getIndexes:values range:NSMakeRange(1, 1)]);
    EXPECT_EQ(2, values[0]);
    EXPECT_EQ(12345, values[1]);

    EXPECT_NO_THROW([path getIndexes:values range:NSMakeRange(0, 3)]);
    EXPECT_EQ(1, values[0]);
    EXPECT_EQ(2, values[1]);
    EXPECT_EQ(3, values[2]);
    EXPECT_EQ(12345, values[3]);
}

TEST(NSIndexPath, EncodeDecodeEmpty) {
    EXPECT_TRUE([NSIndexPath supportsSecureCoding]);
    NSIndexPath* path = [[[NSIndexPath alloc] init] autorelease];
    NSMutableData* data = [NSMutableData data];
    NSKeyedArchiver* coder = [[[NSKeyedArchiver alloc] initForWritingWithMutableData:data] autorelease];
    [path encodeWithCoder:coder];
    [coder finishEncoding];
    NSKeyedUnarchiver* decoder = [[[NSKeyedUnarchiver alloc] initForReadingWithData:data] autorelease];
    NSIndexPath* decoded = [[[NSIndexPath alloc] initWithCoder:decoder] autorelease];
    EXPECT_OBJCEQ(path, decoded);
}

TEST(NSIndexPath, EncodeDecodeNonempty) {
    EXPECT_TRUE([NSIndexPath supportsSecureCoding]);
    NSUInteger indexes[3] = { 1, 2, 3 };
    NSIndexPath* path = [NSIndexPath indexPathWithIndexes:indexes length:3];
    NSMutableData* data = [NSMutableData data];
    NSKeyedArchiver* coder = [[[NSKeyedArchiver alloc] initForWritingWithMutableData:data] autorelease];
    [path encodeWithCoder:coder];
    [coder finishEncoding];
    NSKeyedUnarchiver* decoder = [[[NSKeyedUnarchiver alloc] initForReadingWithData:data] autorelease];
    NSIndexPath* decoded = [[[NSIndexPath alloc] initWithCoder:decoder] autorelease];
    EXPECT_OBJCEQ(path, decoded);
}

TEST(NSIndexPath, InitInvalid) {
    NSIndexPath* invalid = [[[NSIndexPath alloc] initWithIndexes:nullptr length:0] autorelease];
    EXPECT_NE(nil, invalid);
}
