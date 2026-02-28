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
#import <UIKit/UIKit.h>

TEST(NSIndexPath, IndexPathForRowInSection) {
    NSIndexPath* invalid = [NSIndexPath indexPathForRow:-1 inSection:-1];
    EXPECT_NE(nil, invalid);
    EXPECT_EQ(0, invalid.length);

    NSIndexPath* path = [NSIndexPath indexPathForRow:1 inSection:2];
    EXPECT_EQ(1, path.row);
    EXPECT_EQ(1, path.item);
    EXPECT_EQ(2, path.section);
}

TEST(NSIndexPath, IndexPathForItemInSection) {
    NSIndexPath* invalid = [NSIndexPath indexPathForItem:-1 inSection:-1];
    EXPECT_EQ(0, invalid.length);

    NSIndexPath* path = [NSIndexPath indexPathForItem:1 inSection:2];
    EXPECT_EQ(1, path.row);
    EXPECT_EQ(1, path.item);
    EXPECT_EQ(2, path.section);
}