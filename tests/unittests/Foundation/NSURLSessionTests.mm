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

#import <Foundation/NSURLSession.h>
#import <TestFramework.h>
#import <Starboard/SmartTypes.h>

TEST(NSURLSession, ShouldThrowForNilRequest) {
    NSURLSession* session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    EXPECT_ANY_THROW([session downloadTaskWithRequest:nil]);
    EXPECT_ANY_THROW([session dataTaskWithRequest:nil]);
}

TEST(NSURLSession, ShouldThrowForNilResumeData) {
    NSURLSession* session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    EXPECT_ANY_THROW([session downloadTaskWithResumeData:nil]);
}

TEST(NSURLSession, ShouldNOTThrowForNilURL) {
    NSURLSession* session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    EXPECT_NO_THROW([session downloadTaskWithURL:nil]);
    EXPECT_NO_THROW([session dataTaskWithURL:nil]);
}