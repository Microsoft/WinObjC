//******************************************************************************
//
// Copyright (c) Microsoft Corporation. All rights reserved.
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

#import <Starboard.h>
#import <TestFramework.h>
#import <Foundation/Foundation.h>
#import <UWP/WindowsFoundation.h>
#import <UWP/WindowsStorage.h>

//
// NSURLStorageFileTests
//
extern void NSURLStorageFileURL();

class NSURLStorageFileTests {
public:
    BEGIN_TEST_CLASS(NSURLStorageFileTests)
    END_TEST_CLASS()

    TEST_CLASS_SETUP(NSURLStorageFileTestsSetup) {
        return FunctionalTestSetupUIApplication();
    }

    TEST_CLASS_CLEANUP(NSURLStorageFileTestsCleanup) {
        return FunctionalTestCleanupUIApplication();
    }

    TEST_METHOD(StorageFileURL) {
        // First up is to make a storage file for something. Lets create a new file and use that.
        __block WSStorageFile* storageFile = nil;
        __block bool signaled = false;
        __block NSCondition* condition = [NSCondition new];

        [[[WSApplicationData current] localFolder] createFileAsync:@"tempStorageFile.txt"
            options:WSCreationCollisionOptionOpenIfExists
            success:^void(WSStorageFile* file) {
                storageFile = file;
                [condition lock];
                signaled = true;
                [condition signal];
                [condition unlock];
            }

            failure:^void(NSError* error) {
                LOG_ERROR([[error description] UTF8String]);
                [condition lock];
                signaled = true;
                [condition signal];
                [condition unlock];
            }];

        [condition lock];
        ASSERT_TRUE(signaled || [condition waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:10]]);
        [condition unlock];

        ASSERT_NE(nil, storageFile);

        WSStorageFile* lambdaStorageFile = storageFile;

        // Now that a storage file is created. Lets make sure we delete it in case of test failure.
        auto deleter = wil::ScopeExit([&lambdaStorageFile]() {
            __block NSCondition* deleterCondition = [NSCondition new];
            __block bool deleterSignaled = false;
            [[lambdaStorageFile deleteAsyncOverloadDefaultOptions]
                setCompleted:^void(RTObject<WFIAsyncAction>* asyncInfo, WFAsyncStatus asyncStatus) {
                    [deleterCondition lock];
                    deleterSignaled = true;
                    [deleterCondition signal];
                    [deleterCondition unlock];
                }];

            [deleterCondition lock];
            ASSERT_TRUE(deleterSignaled || [deleterCondition waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:10]]);
            [deleterCondition unlock];
        });

        // Ok all the logistics are taken care of. Lets get to work on the meat of the test. mmmmm URLs.
        NSURL* storageUrl = [NSURL URLWithStorageFile:[storageFile comObj].Get()];

        // Lets write some data!!!!
        unsigned char rawDataToWrite[] = { 'a', 'b', 'c' };
        NSData* writeData = [NSData dataWithBytesNoCopy:rawDataToWrite length:_countof(rawDataToWrite) freeWhenDone:NO];
        ASSERT_TRUE([writeData writeToURL:storageUrl options:0 error:nullptr]);

        // Ok now lets read it out!!!
        NSData* readData = [NSData dataWithContentsOfURL:storageUrl];
        ASSERT_TRUE([readData isEqual:writeData]);

        // Try writing different data!!!
        unsigned char rawDataToWrite2[] = { 'e', 'f', 'g' };
        writeData = [NSData dataWithBytesNoCopy:rawDataToWrite2 length:_countof(rawDataToWrite2) freeWhenDone:NO];
        ASSERT_TRUE([writeData writeToURL:storageUrl options:0 error:nullptr]);

        readData = [NSData dataWithContentsOfURL:storageUrl];
        ASSERT_TRUE([readData isEqual:writeData]);

        // Now with appending!
        writeData = [NSData dataWithBytesNoCopy:rawDataToWrite length:_countof(rawDataToWrite) freeWhenDone:NO];
        ASSERT_TRUE([writeData writeToURL:storageUrl options:NSDataWritingWithoutOverwriting error:nullptr]);

        unsigned char rawDataToValidate[] = { 'e', 'f', 'g', 'a', 'b', 'c' };
        NSData* appendData = [NSData dataWithBytesNoCopy:rawDataToValidate length:_countof(rawDataToValidate) freeWhenDone:NO];

        readData = [NSData dataWithContentsOfURL:storageUrl];
        ASSERT_TRUE([readData isEqual:appendData]);
    }
};
