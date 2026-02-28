//******************************************************************************
//
// Copyright (c) 2016 Microsoft Corporation. All rights reserved.
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
#import <Starboard/SmartTypes.h>
#import <windows.h>
#import "TestUtils.h"

void assertOrderedSetContent(NSOrderedSet* set, NSObject* first, ...) {
    va_list args;
    va_start(args, first);

    id curVal = first;

    size_t i = 0;
    while (curVal != nil) {
        ASSERT_OBJCEQ(curVal, [set objectAtIndex:i++]);
        curVal = va_arg(args, id);
    }

    va_end(args);

    ASSERT_EQ(i, [set count]);
}

NSString* getPathToFile(NSString* fileName) {
    return [[[NSFileManager defaultManager] currentDirectoryPath] stringByAppendingPathComponent:fileName];
}

void createFileWithContentAndVerify(NSString* fileName, NSString* content) {
    NSString* fullPath = getPathToFile(fileName);
    NSError* error = nil;
    ASSERT_TRUE([content writeToFile:fullPath atomically:NO encoding:NSUTF8StringEncoding error:&error]);
    ASSERT_EQ(nil, error);
    ASSERT_TRUE([[NSFileManager defaultManager] fileExistsAtPath:fullPath]);
}

void deleteFile(NSString* name) {
    NSString* fullPath = getPathToFile(name);
    if ([[NSFileManager defaultManager] fileExistsAtPath:fullPath]) {
        [[NSFileManager defaultManager] removeItemAtPath:fullPath error:nullptr];
    }
};
