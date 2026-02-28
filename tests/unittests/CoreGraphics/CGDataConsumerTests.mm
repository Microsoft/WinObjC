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
#import <CoreGraphics/CoreGraphics.h>
#import <Starboard/SmartTypes.h>
#import <CGDataConsumerInternal.h>

#import <vector>
#import <numeric>

TEST(CGDataConsumer, Create) {
    EXPECT_EQ(nullptr, CGDataConsumerCreate(nullptr, nullptr));

    char compareData[100]{ 0 };
    EXPECT_EQ(nullptr, CGDataConsumerCreate(compareData, nullptr));

    CGDataConsumerCallbacks emptyCallbacks{ nullptr, nullptr };
    auto consumer = woc::MakeAutoCF<CGDataConsumerRef>(CGDataConsumerCreate(compareData, &emptyCallbacks));
    EXPECT_NE(nullptr, consumer);

    CGDataConsumerCallbacks callbacks{ [](void* info, const void* buffer, size_t count) {
                                          memcpy(info, buffer, count);
                                          return count;
                                      },
                                       nullptr };

    consumer = woc::MakeAutoCF<CGDataConsumerRef>(CGDataConsumerCreate(compareData, &callbacks));

    // Validate that Create copies the callbacks
    callbacks = { nullptr, nullptr };

    char rawData[100];
    std::iota(rawData, rawData + 100, 0);
    size_t written = _CGDataConsumerWriteData(consumer, rawData, 50);
    EXPECT_EQ(50, written);
    EXPECT_EQ(0, compareData[0]);
    EXPECT_EQ(1, compareData[1]);
    EXPECT_EQ(49, compareData[49]);
    EXPECT_EQ(0, compareData[50]);

    uint8_t* largeCompareData = (uint8_t*)calloc(100000, sizeof(uint8_t));
    CGDataConsumerCallbacks largeCallbacks{ [](void* info, const void* buffer, size_t count) {
                                               static size_t total = 0;
                                               std::memset((char*)info + total, 0xFF, count);
                                               total += count;
                                               return count;
                                           },
                                            [](void* info) { free(info); } };
    consumer = woc::MakeAutoCF<CGDataConsumerRef>(CGDataConsumerCreate(largeCompareData, &largeCallbacks));
    written = _CGDataConsumerWriteData(consumer, rawData, 50000);
    EXPECT_EQ(50000, written);
    EXPECT_EQ(0xFF, largeCompareData[0]);
    EXPECT_EQ(0xFF, largeCompareData[49999]);
    EXPECT_EQ(0, largeCompareData[50000]);

    char smallData[100]{ 0 };
    CGDataConsumerCallbacks smallCallbacks{ [](void* info, const void* buffer, size_t count) -> size_t {
                                               memcpy(info, buffer, 50);
                                               return 50;
                                           },
                                            nullptr };

    consumer = woc::MakeAutoCF<CGDataConsumerRef>(CGDataConsumerCreate(smallData, &smallCallbacks));
    written = _CGDataConsumerWriteData(consumer, rawData, 50000);
    EXPECT_EQ(50, written);
    EXPECT_EQ(0, smallData[0]);
    EXPECT_EQ(1, smallData[1]);
    EXPECT_EQ(49, smallData[49]);
    EXPECT_EQ(0, smallData[50]);
}

TEST(CGDataConsumer, CreateWithCFData) {
    EXPECT_EQ(nullptr, CGDataConsumerCreateWithCFData(nullptr));

    auto data = woc::MakeAutoCF<CFMutableDataRef>(CFDataCreateMutable(nullptr, 0));
    auto consumer = woc::MakeAutoCF<CGDataConsumerRef>(CGDataConsumerCreateWithCFData(data));
    ASSERT_NE(nullptr, consumer);
    char rawData[100];
    std::iota(rawData, rawData + 100, 0);
    size_t written = _CGDataConsumerWriteData(consumer, rawData, 100);
    EXPECT_EQ(100, written);

    const UInt8* dataPtr = CFDataGetBytePtr(data);
    EXPECT_EQ(0, std::memcmp(rawData, dataPtr, 100));
}

TEST(CGDataConsumer, CreateWithURL) {
    EXPECT_EQ(nullptr, CGDataConsumerCreateWithURL(nullptr));

    auto url = woc::MakeAutoCF<CFURLRef>(CFURLCreateWithFileSystemPath(nullptr, CFSTR("./testfile.txt"), kCFURLWindowsPathStyle, NO));

    // Destroy consumer to guarantee data is flushed for testing values in URL
    {
        auto consumer = woc::MakeAutoCF<CGDataConsumerRef>(CGDataConsumerCreateWithURL(url));
        ASSERT_NE(nullptr, consumer);

        const char* dataToWrite = "TEST123";
        EXPECT_NE(0, _CGDataConsumerWriteData(consumer, dataToWrite, 7));
        EXPECT_NE(0, _CGDataConsumerWriteData(consumer, dataToWrite, 4));
    }

    auto provider = woc::MakeAutoCF<CGDataProviderRef>(CGDataProviderCreateWithURL(url));
    ASSERT_NE(nullptr, provider);

    auto data = woc::MakeAutoCF<CFDataRef>(CGDataProviderCopyData(provider));
    ASSERT_NE(nullptr, data);
    ASSERT_EQ(11L, CFDataGetLength(data));

    const UInt8* dataPtr = CFDataGetBytePtr(data);
    const char* expectedData = "TEST123TEST";
    EXPECT_EQ(0, std::memcmp(expectedData, dataPtr, 11));
}

TEST(CGDataConsumer, RetainReleaseShouldBeValidForNullConsumer) {
    EXPECT_EQ(nullptr, CGDataConsumerRetain(nullptr));
    EXPECT_NO_THROW(CGDataConsumerRelease(nullptr));
}
