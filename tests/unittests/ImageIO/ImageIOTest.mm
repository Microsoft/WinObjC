//******************************************************************************
//
// Copyright (c) 2016 Intel Corporation. All rights reserved.
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

#import <Starboard.h>
#import <TestFramework.h>
#import <CoreGraphics/CGImage.h>
#import <Foundation/Foundation.h>
#import <ImageIO/ImageIO.h>
#include <windows.h>


const CFStringRef kUTTypeJPEG = static_cast<const CFStringRef>(@"public.jpeg");
const CFStringRef kUTTypeTIFF = static_cast<const CFStringRef>(@"public.tiff");
const CFStringRef kUTTypeGIF = static_cast<const CFStringRef>(@"com.compuserve.gif");
const CFStringRef kUTTypePNG = static_cast<const CFStringRef>(@"public.png");
const CFStringRef kUTTypeBMP = static_cast<const CFStringRef>(@"com.microsoft.bmp");
const CFStringRef kUTTypeICO = static_cast<const CFStringRef>(@"com.microsoft.ico");
const CFStringRef kUTTypeData = static_cast<const CFStringRef>(@"public.data");

static NSString* getPathForFile(const wchar_t* fileName) {
    // get test startup full path
    wchar_t fullPath[_MAX_PATH];
    auto testDir = GetCurrentTestDirectory();
    std::mbstowcs(fullPath, testDir.c_str(), _MAX_PATH);

    // split test startup full path into components like drive, directory, filename and ext etc.
    wchar_t drive[_MAX_DRIVE];
    wchar_t directory[_MAX_DIR];
    ::_wsplitpath_s(fullPath, drive, _countof(drive), directory, _countof(directory), NULL, 0, NULL, 0);

    // reconstruct fullpath for test artifact file. e.g., C:\WinObjc\WinObjC\build\Debug\data\photo6_1024x670.jpg
    wcscpy_s(fullPath, _countof(fullPath), drive);
    wcscat_s(fullPath, _countof(fullPath), directory);
    wcscat_s(fullPath, _countof(fullPath), L"data\\");
    wcscat_s(fullPath, _countof(fullPath), fileName);

    return [NSString stringWithCharacters:(const unichar*)fullPath length:wcsnlen_s(fullPath, _MAX_PATH)];
}

static NSString* getPathForOutFile(const wchar_t* fileName) {
    return [[[NSFileManager defaultManager] currentDirectoryPath]
        stringByAppendingPathComponent:[NSString stringWithCharacters:(const unichar*)(fileName) length:wcsnlen_s(fileName, _MAX_PATH)]];
}

static NSData* getDataFromImageFile(const wchar_t* imageFilename) {
    NSString* testFileFullPath = getPathForFile(imageFilename);

    return [NSData dataWithContentsOfFile:testFileFullPath];
}

static NSData* getDataFromImageFile(CFURLRef imageURL) {
    return [NSData dataWithContentsOfURL:(NSURL*)imageURL];
}

static CFURLRef getURLRefFromFilename(const wchar_t* filename) {
    NSString* directoryWithFile = getPathForFile(filename);
    return (CFURLRef)[NSURL fileURLWithPath:directoryWithFile];
}

static CFURLRef getURLRefForOutFile(const wchar_t* filename) {
    NSString* testFileFullPath = getPathForOutFile(filename);
    [[NSFileManager defaultManager] removeItemAtPath:testFileFullPath error:nullptr];
    return (CFURLRef)[NSURL fileURLWithPath:testFileFullPath];
}

TEST(ImageIO, ImageAtIndexWithData) {
    const wchar_t* imageFile = L"photo6_1024x670.jpg";
    NSData* imageData = getDataFromImageFile(imageFile);
    ASSERT_NE_MSG(nullptr, imageData, "FAILED: ImageIOTest::Could not find file: [%s]", imageFile);
    NSDictionary* options = @{
        @"kCGImageSourceTypeIdentifierHint" : @"kUTTypeJPEG",
        @"kCGImageSourceShouldAllowFloat" : @"kCFBooleanTrue",
        @"kCGImageSourceShouldCache" : @"kCFBooleanTrue"
    };
    CGImageSourceRef imageSource = CGImageSourceCreateWithData((CFDataRef)imageData, (CFDictionaryRef)options);
    ASSERT_NE_MSG(nullptr, imageSource, "FAILED: ImageIOTest::CGImageSourceCreateWithData returned nullptr");
    CGImageRef imageRef = CGImageSourceCreateImageAtIndex(imageSource, 0, (CFDictionaryRef)options);
    ASSERT_NE_MSG(nullptr, imageRef, "FAILED: ImageIOTest::CGImageSourceCreateImageAtIndex returned nullptr");

    EXPECT_EQ(kCGImageAlphaNone, CGImageGetAlphaInfo(imageRef));
    EXPECT_EQ(kCGImageAlphaNone, CGImageGetBitmapInfo(imageRef));
    EXPECT_EQ(8, CGImageGetBitsPerComponent(imageRef));
    EXPECT_EQ(24, CGImageGetBitsPerPixel(imageRef));
    EXPECT_EQ(3, CGColorSpaceGetNumberOfComponents(CGImageGetColorSpace(imageRef)));
    EXPECT_EQ(670, CGImageGetHeight(imageRef));
    EXPECT_EQ(1024, CGImageGetWidth(imageRef));
    size_t frameCount = CGImageSourceGetCount(imageSource);
    EXPECT_EQ(1, frameCount);
    CFRelease(imageSource);
}

TEST(ImageIO, ImageAtIndexWithDataProvider) {
    const wchar_t* imageFile = L"photo6_1024x670.jpg";
    NSData* imageData = getDataFromImageFile(imageFile);
    ASSERT_NE_MSG(nullptr, imageData, "FAILED: ImageIOTest::Could not find file: [%s]", imageFile);
    NSDictionary* options = @{
        @"kCGImageSourceTypeIdentifierHint" : @"kUTTypeJPEG",
        @"kCGImageSourceShouldAllowFloat" : @"kCFBooleanTrue",
        @"kCGImageSourceShouldCache" : @"kCFBooleanTrue"
    };
    CGDataProviderRef imgDataProvider = CGDataProviderCreateWithCFData((CFDataRef)imageData);
    CGImageSourceRef imageSource = CGImageSourceCreateWithDataProvider(imgDataProvider, (CFDictionaryRef)options);
    ASSERT_NE_MSG(nullptr, imageSource, "FAILED: ImageIOTest::CGImageSourceCreateWithDataProvider returned nullptr");
    CGImageRef imageRef = CGImageSourceCreateImageAtIndex(imageSource, 0, (CFDictionaryRef)options);
    ASSERT_NE_MSG(nullptr, imageRef, "FAILED: ImageIOTest::CGImageSourceCreateImageAtIndex returned nullptr");
    EXPECT_EQ(kCGImageAlphaNone, CGImageGetAlphaInfo(imageRef));
    EXPECT_EQ(kCGImageAlphaNone, CGImageGetBitmapInfo(imageRef));
    EXPECT_EQ(8, CGImageGetBitsPerComponent(imageRef));
    EXPECT_EQ(24, CGImageGetBitsPerPixel(imageRef));
    EXPECT_EQ(3, CGColorSpaceGetNumberOfComponents(CGImageGetColorSpace(imageRef)));
    EXPECT_EQ(670, CGImageGetHeight(imageRef));
    EXPECT_EQ(1024, CGImageGetWidth(imageRef));
    size_t frameCount = CGImageSourceGetCount(imageSource);
    EXPECT_EQ(1, frameCount);
    CFRelease(imageSource);
}

TEST(ImageIO, ImageAtIndexWithUrl) {
    const wchar_t* imageFile = L"photo6_1024x670.jpg";
    CFURLRef imgUrl = getURLRefFromFilename(imageFile);

    NSDictionary* options = @{
        @"kCGImageSourceTypeIdentifierHint" : @"kUTTypeJPEG",
        @"kCGImageSourceShouldAllowFloat" : @"kCFBooleanTrue",
        @"kCGImageSourceShouldCache" : @"kCFBooleanTrue"
    };
    CGImageSourceRef imageSource = CGImageSourceCreateWithURL(imgUrl, (CFDictionaryRef)options);
    ASSERT_NE_MSG(nullptr, imageSource, "FAILED: ImageIOTest::CGImageSourceCreateWithURL returned nullptr");
    CGImageRef imageRef = CGImageSourceCreateImageAtIndex(imageSource, 0, (CFDictionaryRef)options);
    ASSERT_NE_MSG(nullptr, imageRef, "FAILED: ImageIOTest::CGImageSourceCreateImageAtIndex returned nullptr");
    EXPECT_EQ(kCGImageAlphaNone, CGImageGetAlphaInfo(imageRef));
    EXPECT_EQ(kCGImageAlphaNone, CGImageGetBitmapInfo(imageRef));
    EXPECT_EQ(8, CGImageGetBitsPerComponent(imageRef));
    EXPECT_EQ(24, CGImageGetBitsPerPixel(imageRef));
    EXPECT_EQ(3, CGColorSpaceGetNumberOfComponents(CGImageGetColorSpace(imageRef)));
    EXPECT_EQ(670, CGImageGetHeight(imageRef));
    EXPECT_EQ(1024, CGImageGetWidth(imageRef));
    size_t frameCount = CGImageSourceGetCount(imageSource);
    EXPECT_EQ(1, frameCount);
    CFRelease(imageSource);
}

TEST(ImageIO, ImageTypeTest) {
    const wchar_t* imageFile = L"photo6_1024x670.jpg";
    NSData* imageData = getDataFromImageFile(imageFile);
    ASSERT_NE_MSG(nullptr, imageData, "FAILED: ImageIOTest::Could not find file: [%s]", imageFile);
    CGImageSourceRef imageSource = CGImageSourceCreateWithData((CFDataRef)imageData, nullptr);
    ASSERT_NE_MSG(nullptr, imageSource, "FAILED: ImageIOTest::CGImageSourceCreateWithData returned nullptr");
    CFStringRef imageType = CGImageSourceGetType(imageSource);
    ASSERT_NE_MSG(nullptr, imageType, "FAILED: ImageIOTest::CGImageSourceGetType returned nullptr");
    ASSERT_OBJCEQ_MSG(static_cast<NSString*>(imageType), @"public.jpeg", "FAILED: ImageIOTest::Incorrect Image Type");
    CFRelease(imageSource);
}

TEST(ImageIO, ThumbnailAtIndexFromSrcWithoutThumbnail) {
    const wchar_t* imageFile = L"photo6_1024x670.jpg";
    NSData* imageData = getDataFromImageFile(imageFile);
    ASSERT_NE_MSG(nullptr, imageData, "FAILED: ImageIOTest::Could not find file: [%s]", imageFile);
    NSDictionary* options = @{
        @"kCGImageSourceTypeIdentifierHint" : @"kUTTypeJPEG",
        @"kCGImageSourceShouldAllowFloat" : @"kCFBooleanTrue",
        @"kCGImageSourceShouldCache" : @"kCFBooleanTrue",
        @"kCGImageSourceCreateThumbnailFromImageIfAbsent" : @"kCFBooleanTrue",
        @"kCGImageSourceCreateThumbnailFromImageAlways" : @"kCFBooleanTrue",
        @"kCGImageSourceThumbnailMaxPixelSize" : [NSNumber numberWithInt:1024],
        @"kCGImageSourceCreateThumbnailWithTransform" : @"kCFBooleanTrue"
    };
    CGImageSourceRef imageSource = CGImageSourceCreateWithData((CFDataRef)imageData, (CFDictionaryRef)options);
    ASSERT_NE_MSG(nullptr, imageSource, "FAILED: ImageIOTest::CGImageSourceCreateWithData returned nullptr");
    CGImageRef imageRef = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, (CFDictionaryRef)options);
    ASSERT_NE_MSG(nullptr, imageRef, "FAILED: ImageIOTest::CGImageSourceCreateThumbnailAtIndex returned nullptr");
    EXPECT_EQ(kCGImageAlphaNone, CGImageGetAlphaInfo(imageRef));
    EXPECT_EQ(kCGImageAlphaNone, CGImageGetBitmapInfo(imageRef));
    EXPECT_EQ(8, CGImageGetBitsPerComponent(imageRef));
    EXPECT_EQ(24, CGImageGetBitsPerPixel(imageRef));
    EXPECT_EQ(3, CGColorSpaceGetNumberOfComponents(CGImageGetColorSpace(imageRef)));
    EXPECT_EQ(670, CGImageGetHeight(imageRef));
    EXPECT_EQ(1024, CGImageGetWidth(imageRef));
    CFRelease(imageSource);
}

TEST(ImageIO, ThumbnailAtIndexFromAsymmetricSrcWithThumbnail) {
    const wchar_t* imageFile = L"photo6_1024x670_thumbnail_227x149.jpg";
    NSData* imageData = getDataFromImageFile(imageFile);
    ASSERT_NE_MSG(nullptr, imageData, "FAILED: ImageIOTest::Could not find file: [%s]", imageFile);
    NSDictionary* options = @{
        @"kCGImageSourceTypeIdentifierHint" : @"kUTTypeJPEG",
        @"kCGImageSourceShouldAllowFloat" : @"kCFBooleanTrue",
        @"kCGImageSourceShouldCache" : @"kCFBooleanTrue",
        @"kCGImageSourceCreateThumbnailFromImageIfAbsent" : @"kCFBooleanTrue",
        @"kCGImageSourceCreateThumbnailFromImageAlways" : @"kCFBooleanTrue",
        @"kCGImageSourceThumbnailMaxPixelSize" : [NSNumber numberWithInt:1024],
        @"kCGImageSourceCreateThumbnailWithTransform" : @"kCFBooleanTrue"
    };
    CGImageSourceRef imageSource = CGImageSourceCreateWithData((CFDataRef)imageData, (CFDictionaryRef)options);
    ASSERT_NE_MSG(nullptr, imageSource, "FAILED: ImageIOTest::CGImageSourceCreateWithData returned nullptr");
    CGImageRef imageRef = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, (CFDictionaryRef)options);
    ASSERT_NE_MSG(nullptr, imageRef, "FAILED: ImageIOTest::CGImageSourceCreateThumbnailAtIndex returned nullptr");
    EXPECT_EQ(kCGImageAlphaNone, CGImageGetAlphaInfo(imageRef));
    EXPECT_EQ(kCGImageAlphaNone, CGImageGetBitmapInfo(imageRef));
    EXPECT_EQ(8, CGImageGetBitsPerComponent(imageRef));
    EXPECT_EQ(24, CGImageGetBitsPerPixel(imageRef));
    EXPECT_EQ(3, CGColorSpaceGetNumberOfComponents(CGImageGetColorSpace(imageRef)));
    EXPECT_EQ(149, CGImageGetHeight(imageRef));
    EXPECT_EQ(227, CGImageGetWidth(imageRef));
    CFRelease(imageSource);
}

TEST(ImageIO, ThumbnailSizesRelativeToImage) {
    const wchar_t* imageFile = L"photo6_1024x670_thumbnail_227x149.jpg";
    NSData* imageData = getDataFromImageFile(imageFile);
    ASSERT_NE_MSG(nullptr, imageData, "FAILED: ImageIOTest::Could not find file: [%s]", imageFile);
    NSDictionary* options = @{
        @"kCGImageSourceTypeIdentifierHint" : @"kUTTypeJPEG",
        @"kCGImageSourceShouldAllowFloat" : @"kCFBooleanTrue",
        @"kCGImageSourceShouldCache" : @"kCFBooleanTrue",
        @"kCGImageSourceCreateThumbnailFromImageIfAbsent" : @"kCFBooleanTrue",
        @"kCGImageSourceCreateThumbnailFromImageAlways" : @"kCFBooleanTrue",
        @"kCGImageSourceThumbnailMaxPixelSize" : [NSNumber numberWithInt:10],
        @"kCGImageSourceCreateThumbnailWithTransform" : @"kCFBooleanTrue"
    };
    CGImageSourceRef imageSource = CGImageSourceCreateWithData((CFDataRef)imageData, (CFDictionaryRef)options);
    ASSERT_NE_MSG(nullptr, imageSource, "FAILED: ImageIOTest::CGImageSourceCreateWithData returned nullptr");
    CGImageRef imageRef = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, (CFDictionaryRef)options);
    ASSERT_NE_MSG(nullptr, imageRef, "FAILED: ImageIOTest::CGImageSourceCreateThumbnailAtIndex returned nullptr");
    EXPECT_EQ(kCGImageAlphaNone, CGImageGetAlphaInfo(imageRef));
    EXPECT_EQ(kCGImageAlphaNone, CGImageGetBitmapInfo(imageRef));
    EXPECT_EQ(8, CGImageGetBitsPerComponent(imageRef));
    EXPECT_EQ(24, CGImageGetBitsPerPixel(imageRef));
    EXPECT_EQ(3, CGColorSpaceGetNumberOfComponents(CGImageGetColorSpace(imageRef)));
    EXPECT_EQ(10, CGImageGetHeight(imageRef));
    EXPECT_EQ(10, CGImageGetWidth(imageRef));
    CFRelease(imageSource);

    options = @{
        @"kCGImageSourceTypeIdentifierHint" : @"kUTTypeJPEG",
        @"kCGImageSourceShouldAllowFloat" : @"kCFBooleanTrue",
        @"kCGImageSourceShouldCache" : @"kCFBooleanTrue",
        @"kCGImageSourceCreateThumbnailFromImageIfAbsent" : @"kCFBooleanTrue",
        @"kCGImageSourceCreateThumbnailFromImageAlways" : @"kCFBooleanTrue",
        @"kCGImageSourceThumbnailMaxPixelSize" : [NSNumber numberWithInt:1000],
        @"kCGImageSourceCreateThumbnailWithTransform" : @"kCFBooleanTrue"
    };
    imageSource = CGImageSourceCreateWithData((CFDataRef)imageData, (CFDictionaryRef)options);
    ASSERT_NE_MSG(nullptr, imageSource, "FAILED: ImageIOTest::CGImageSourceCreateWithData returned nullptr");
    imageRef = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, (CFDictionaryRef)options);
    ASSERT_NE_MSG(nullptr, imageRef, "FAILED: ImageIOTest::CGImageSourceCreateThumbnailAtIndex returned nullptr");
    EXPECT_EQ(kCGImageAlphaNone, CGImageGetAlphaInfo(imageRef));
    EXPECT_EQ(kCGImageAlphaNone, CGImageGetBitmapInfo(imageRef));
    EXPECT_EQ(8, CGImageGetBitsPerComponent(imageRef));
    EXPECT_EQ(24, CGImageGetBitsPerPixel(imageRef));
    EXPECT_EQ(3, CGColorSpaceGetNumberOfComponents(CGImageGetColorSpace(imageRef)));
    EXPECT_EQ(149, CGImageGetHeight(imageRef));
    EXPECT_EQ(227, CGImageGetWidth(imageRef));
    CFRelease(imageSource);
}

TEST(ImageIO, GIF_TIFF_MultiFrameSourceTest) {
    const wchar_t* imageFile = L"photo7_4layers_683x1024.gif";
    NSData* imageData = getDataFromImageFile(imageFile);
    ASSERT_NE_MSG(nullptr, imageData, "FAILED: ImageIOTest::Could not find file: [%s]", imageFile);
    NSDictionary* options = @{
        @"kCGImageSourceTypeIdentifierHint" : @"kUTTypeGIF",
        @"kCGImageSourceShouldAllowFloat" : @"kCFBooleanTrue",
        @"kCGImageSourceShouldCache" : @"kCFBooleanTrue"
    };
    CGImageSourceRef imageSource = CGImageSourceCreateWithData((CFDataRef)imageData, (CFDictionaryRef)options);
    ASSERT_NE_MSG(nullptr, imageSource, "FAILED: ImageIOTest::CGImageSourceCreateWithData returned nullptr");
    CGImageRef imageRef = CGImageSourceCreateImageAtIndex(imageSource, 2, (CFDictionaryRef)options);
    ASSERT_NE_MSG(nullptr, imageRef, "FAILED: ImageIOTest::CGImageSourceCreateImageAtIndex returned nullptr");
    CFStringRef imageType = CGImageSourceGetType(imageSource);
    ASSERT_NE_MSG(nullptr, imageType, "FAILED: ImageIOTest::CGImageSourceGetType returned nullptr");
    ASSERT_OBJCEQ_MSG(static_cast<NSString*>(imageType), @"com.compuserve.gif", "FAILED: ImageIOTest::Incorrect Image Type");
    size_t frameCount = CGImageSourceGetCount(imageSource);
    EXPECT_EQ(4, frameCount);
    EXPECT_EQ(kCGImageAlphaNone, CGImageGetAlphaInfo(imageRef));
    EXPECT_EQ(kCGImageAlphaNone, CGImageGetBitmapInfo(imageRef));
    EXPECT_EQ(8, CGImageGetBitsPerComponent(imageRef));
    EXPECT_EQ(8, CGImageGetBitsPerPixel(imageRef));
    // TODO: Check Paletted/Indexed color space.
    EXPECT_EQ(1024, CGImageGetHeight(imageRef));
    EXPECT_EQ(683, CGImageGetWidth(imageRef));

    imageFile = L"photo8_4layers_1024x683.tif";
    imageData = getDataFromImageFile(imageFile);
    ASSERT_NE_MSG(nullptr, imageData, "FAILED: ImageIOTest::Could not find file: [%s]", imageFile);
    options = @{
        @"kCGImageSourceTypeIdentifierHint" : @"kUTTypeTIFF",
        @"kCGImageSourceShouldAllowFloat" : @"kCFBooleanTrue",
        @"kCGImageSourceShouldCache" : @"kCFBooleanTrue"
    };
    imageSource = CGImageSourceCreateWithData((CFDataRef)imageData, (CFDictionaryRef)options);
    ASSERT_NE_MSG(nullptr, imageSource, "FAILED: ImageIOTest::CGImageSourceCreateWithData returned nullptr");
    imageRef = CGImageSourceCreateImageAtIndex(imageSource, 3, (CFDictionaryRef)options);
    ASSERT_NE_MSG(nullptr, imageRef, "FAILED: ImageIOTest::CGImageSourceCreateImageAtIndex returned nullptr");
    imageType = CGImageSourceGetType(imageSource);
    ASSERT_NE_MSG(nullptr, imageType, "FAILED: ImageIOTest::CGImageSourceGetType returned nullptr");
    ASSERT_OBJCEQ_MSG(static_cast<NSString*>(imageType), @"public.tiff", "FAILED: ImageIOTest::Incorrect Image Type");
    frameCount = CGImageSourceGetCount(imageSource);
    ASSERT_EQ_MSG(frameCount, 4, "FAILED: ImageIOTest::FrameCount");
    EXPECT_EQ(kCGImageAlphaNone, CGImageGetAlphaInfo(imageRef));
    EXPECT_EQ(kCGImageAlphaNone, CGImageGetBitmapInfo(imageRef));
    EXPECT_EQ(8, CGImageGetBitsPerComponent(imageRef));
    EXPECT_EQ(24, CGImageGetBitsPerPixel(imageRef));
    EXPECT_EQ(3, CGColorSpaceGetNumberOfComponents(CGImageGetColorSpace(imageRef)));
    EXPECT_EQ(1024, CGImageGetHeight(imageRef));
    EXPECT_EQ(683, CGImageGetWidth(imageRef));
    CFRelease(imageSource);
}

TEST(ImageIO, BMP_ICO_PNG_SingleFrameSourceTest) {
    const wchar_t* imageFile = L"testimg_227x149.bmp";
    NSData* imageData = getDataFromImageFile(imageFile);
    ASSERT_NE_MSG(nullptr, imageData, "FAILED: ImageIOTest::Could not find file: [%s]", imageFile);
    NSDictionary* options = @{
        @"kCGImageSourceTypeIdentifierHint" : @"kUTTypeBMP",
        @"kCGImageSourceShouldAllowFloat" : @"kCFBooleanTrue",
        @"kCGImageSourceShouldCache" : @"kCFBooleanTrue"
    };
    CGImageSourceRef imageSource = CGImageSourceCreateWithData((CFDataRef)imageData, (CFDictionaryRef)options);
    ASSERT_NE_MSG(nullptr, imageSource, "FAILED: ImageIOTest::CGImageSourceCreateWithData returned nullptr");
    CGImageRef imageRef = CGImageSourceCreateImageAtIndex(imageSource, 0, (CFDictionaryRef)options);
    ASSERT_NE_MSG(nullptr, imageRef, "FAILED: ImageIOTest::CGImageSourceCreateImageAtIndex returned nullptr");
    CFStringRef imageType = CGImageSourceGetType(imageSource);
    ASSERT_NE_MSG(nullptr, imageType, "FAILED: ImageIOTest::CGImageSourceGetType returned nullptr");
    ASSERT_OBJCEQ_MSG(static_cast<NSString*>(imageType), @"com.microsoft.bmp", "FAILED: ImageIOTest::Incorrect Image Type");
    size_t frameCount = CGImageSourceGetCount(imageSource);
    EXPECT_EQ(1, frameCount);
    EXPECT_EQ(kCGImageAlphaNone, CGImageGetAlphaInfo(imageRef));
    EXPECT_EQ(kCGImageAlphaNone, CGImageGetBitmapInfo(imageRef));
    EXPECT_EQ(8, CGImageGetBitsPerComponent(imageRef));
    EXPECT_EQ(8, CGImageGetBitsPerPixel(imageRef));
    // TODO: Check Paletted/Indexed color space.
    EXPECT_EQ(149, CGImageGetHeight(imageRef));
    EXPECT_EQ(227, CGImageGetWidth(imageRef));

    // RGBA 8-bit ICO frame
    imageFile = L"photo2_683x1024.ico";
    imageData = getDataFromImageFile(imageFile);
    ASSERT_NE_MSG(nullptr, imageData, "FAILED: ImageIOTest::Could not find file: [%s]", imageFile);
    options = @{
        @"kCGImageSourceTypeIdentifierHint" : @"kUTTypeICO",
        @"kCGImageSourceShouldAllowFloat" : @"kCFBooleanTrue",
        @"kCGImageSourceShouldCache" : @"kCFBooleanTrue"
    };
    imageSource = CGImageSourceCreateWithData((CFDataRef)imageData, (CFDictionaryRef)options);
    ASSERT_NE_MSG(nullptr, imageSource, "FAILED: ImageIOTest::CGImageSourceCreateWithData returned nullptr");
    imageRef = CGImageSourceCreateImageAtIndex(imageSource, 0, (CFDictionaryRef)options);
    ASSERT_NE_MSG(nullptr, imageRef, "FAILED: ImageIOTest::CGImageSourceCreateImageAtIndex returned nullptr");
    imageType = CGImageSourceGetType(imageSource);
    ASSERT_NE_MSG(nullptr, imageType, "FAILED: ImageIOTest::CGImageSourceGetType returned nullptr");
    ASSERT_OBJCEQ_MSG(static_cast<NSString*>(imageType), @"com.microsoft.ico", "FAILED: ImageIOTest::Incorrect Image Type");
    frameCount = CGImageSourceGetCount(imageSource);
    EXPECT_EQ(1, frameCount);
    EXPECT_EQ(kCGImageAlphaFirst, CGImageGetAlphaInfo(imageRef));
    EXPECT_EQ(kCGImageAlphaFirst | kCGBitmapByteOrder32Little, CGImageGetBitmapInfo(imageRef));
    EXPECT_EQ(8, CGImageGetBitsPerComponent(imageRef));
    EXPECT_EQ(32, CGImageGetBitsPerPixel(imageRef));
    EXPECT_EQ(3, CGColorSpaceGetNumberOfComponents(CGImageGetColorSpace(imageRef)));
    EXPECT_EQ(1024, CGImageGetHeight(imageRef));
    EXPECT_EQ(683, CGImageGetWidth(imageRef));

    // Paletted/Indexed PNG
    imageFile = L"seafloor_256x256.png";
    imageData = getDataFromImageFile(imageFile);
    ASSERT_NE_MSG(nullptr, imageData, "FAILED: ImageIOTest::Could not find file: [%s]", imageFile);
    options = @{
        @"kCGImageSourceTypeIdentifierHint" : @"kUTTypePNG",
        @"kCGImageSourceShouldAllowFloat" : @"kCFBooleanTrue",
        @"kCGImageSourceShouldCache" : @"kCFBooleanTrue"
    };
    imageSource = CGImageSourceCreateWithData((CFDataRef)imageData, (CFDictionaryRef)options);
    ASSERT_NE_MSG(nullptr, imageSource, "FAILED: ImageIOTest::CGImageSourceCreateWithData returned nullptr");
    imageRef = CGImageSourceCreateImageAtIndex(imageSource, 0, (CFDictionaryRef)options);
    ASSERT_NE_MSG(nullptr, imageRef, "FAILED: ImageIOTest::CGImageSourceCreateImageAtIndex returned nullptr");
    imageType = CGImageSourceGetType(imageSource);
    ASSERT_NE_MSG(nullptr, imageType, "FAILED: ImageIOTest::CGImageSourceGetType returned nullptr");
    ASSERT_OBJCEQ_MSG(static_cast<NSString*>(imageType), @"public.png", "FAILED: ImageIOTest::Incorrect Image Type");
    frameCount = CGImageSourceGetCount(imageSource);
    EXPECT_EQ(1, frameCount);
    EXPECT_EQ(kCGImageAlphaNone, CGImageGetAlphaInfo(imageRef));
    EXPECT_EQ(kCGImageAlphaNone, CGImageGetBitmapInfo(imageRef));
    EXPECT_EQ(8, CGImageGetBitsPerComponent(imageRef));
    EXPECT_EQ(8, CGImageGetBitsPerPixel(imageRef));
    // TODO: Check Paletted/Indexed color space.
    EXPECT_EQ(256, CGImageGetHeight(imageRef));
    EXPECT_EQ(256, CGImageGetWidth(imageRef));
    CFRelease(imageSource);
}

TEST(ImageIO, NegativeScenarioTest) {
    const wchar_t* imageFile = L"photo6_1024x670.jpg";
    NSData* imageData = getDataFromImageFile(imageFile);
    ASSERT_NE_MSG(nullptr, imageData, "FAILED: ImageIOTest::Could not find file: [%s]", imageFile);
    NSDictionary* options = @{
        @"kCGImageSourceTypeIdentifierHint" : @"kUTTypeJPEG",
        @"kCGImageSourceShouldAllowFloat" : @"kCFBooleanTrue",
        @"kCGImageSourceShouldCache" : @"kCFBooleanTrue"
    };
    CGImageSourceRef imageSource = CGImageSourceCreateWithData(nullptr, (CFDictionaryRef)options);
    ASSERT_EQ_MSG(nullptr, imageSource, "FAILED: ImageIOTest::CGImageSourceCreateWithData should return nullptr");

    imageSource = CGImageSourceCreateWithData((CFDataRef)imageData, nullptr);
    ASSERT_NE_MSG(nullptr, imageSource, "FAILED: ImageIOTest::CGImageSourceCreateWithData returned nullptr");

    imageSource = CGImageSourceCreateWithData(nullptr, nullptr);
    ASSERT_EQ_MSG(nullptr, imageSource, "FAILED: ImageIOTest::CGImageSourceCreateWithData should return nullptr");

    CGDataProviderRef imgDataProvider = CGDataProviderCreateWithCFData((CFDataRef)imageData);
    imageSource = CGImageSourceCreateWithDataProvider(nullptr, (CFDictionaryRef)options);
    ASSERT_EQ_MSG(nullptr, imageSource, "FAILED: ImageIOTest::CGImageSourceCreateWithDataProvider should return nullptr");

    imageSource = CGImageSourceCreateWithDataProvider(imgDataProvider, nullptr);
    ASSERT_NE_MSG(nullptr, imageSource, "FAILED: ImageIOTest::CGImageSourceCreateWithDataProvider returned nullptr");

    imageSource = CGImageSourceCreateWithDataProvider(nullptr, nullptr);
    ASSERT_EQ_MSG(nullptr, imageSource, "FAILED: ImageIOTest::CGImageSourceCreateWithDataProvider should return nullptr");

    // get test startup full path
    wchar_t fullPath[_MAX_PATH];
    auto testDir = GetCurrentTestDirectory();
    std::mbstowcs(fullPath, testDir.c_str(), _MAX_PATH);

    // split test startup full path into components like drive, directory, filename and ext etc.
    wchar_t drive[_MAX_DRIVE];
    wchar_t directory[_MAX_DIR];
    ::_wsplitpath_s(fullPath, drive, _countof(drive), directory, _countof(directory), NULL, 0, NULL, 0);

    // reconstruct fullpath for test artifact file. e.g., C:\WinObjc\WinObjC\build\Debug\data\photo6_1024x670.jpg
    wcscpy_s(fullPath, _countof(fullPath), drive);
    wcscat_s(fullPath, _countof(fullPath), directory);
    wcscat_s(fullPath, _countof(fullPath), L"data\\");
    wcscat_s(fullPath, _countof(fullPath), imageFile);
    NSString* directoryWithFile = [NSString stringWithCharacters:(const unichar*)fullPath length:wcsnlen_s(fullPath, _MAX_PATH)];

    CFURLRef imgUrl = (CFURLRef)[NSURL fileURLWithPath:directoryWithFile];
    imageSource = CGImageSourceCreateWithURL(nullptr, (CFDictionaryRef)options);
    ASSERT_EQ_MSG(nullptr, imageSource, "FAILED: ImageIOTest::CGImageSourceCreateWithURL should return nullptr");

    imageSource = CGImageSourceCreateWithURL(nullptr, nullptr);
    ASSERT_EQ_MSG(nullptr, imageSource, "FAILED: ImageIOTest::CGImageSourceCreateWithURL should return nullptr");

    imageSource = CGImageSourceCreateWithURL(imgUrl, nullptr);
    ASSERT_NE_MSG(nullptr, imageSource, "FAILED: ImageIOTest::CGImageSourceCreateWithURL returned nullptr");

    CGImageRef imageRef = CGImageSourceCreateImageAtIndex(imageSource, 5, (CFDictionaryRef)options);
    ASSERT_EQ_MSG(nullptr, imageRef, "FAILED: ImageIOTest::CGImageSourceCreateImageAtIndex should return nullptr");

    imageRef = CGImageSourceCreateImageAtIndex(imageSource, -1, (CFDictionaryRef)options);
    ASSERT_EQ_MSG(nullptr, imageRef, "FAILED: ImageIOTest::CGImageSourceCreateImageAtIndex should return nullptr");

    imageRef = CGImageSourceCreateImageAtIndex(imageSource, 0, nullptr);
    ASSERT_NE_MSG(nullptr, imageRef, "FAILED: ImageIOTest::CGImageSourceCreateImageAtIndex returned nullptr");

    imageRef = CGImageSourceCreateImageAtIndex(nullptr, 0, nullptr);
    ASSERT_EQ_MSG(nullptr, imageRef, "FAILED: ImageIOTest::CGImageSourceCreateImageAtIndex should return nullptr");

    size_t frameCount = CGImageSourceGetCount(nullptr);
    ASSERT_EQ_MSG(frameCount, 0, "FAILED: ImageIOTest::FrameCount");
    options = @{
        @"kCGImageSourceTypeIdentifierHint" : @"kUTTypeJPEG",
        @"kCGImageSourceShouldAllowFloat" : @"kCFBooleanTrue",
        @"kCGImageSourceShouldCache" : @"kCFBooleanTrue",
        @"kCGImageSourceCreateThumbnailFromImageIfAbsent" : @"kCFBooleanTrue",
        @"kCGImageSourceCreateThumbnailFromImageAlways" : @"kCFBooleanTrue",
        @"kCGImageSourceThumbnailMaxPixelSize" : [NSNumber numberWithInt:1024],
        @"kCGImageSourceCreateThumbnailWithTransform" : @"kCFBooleanTrue"
    };

    imageRef = CGImageSourceCreateThumbnailAtIndex(imageSource, 5, (CFDictionaryRef)options);
    ASSERT_EQ_MSG(nullptr, imageRef, "FAILED: ImageIOTest::CGImageSourceCreateThumbnailAtIndex should return nullptr");

    imageRef = CGImageSourceCreateThumbnailAtIndex(nullptr, 0, (CFDictionaryRef)options);
    ASSERT_EQ_MSG(nullptr, imageRef, "FAILED: ImageIOTest::CGImageSourceCreateThumbnailAtIndex should return nullptr");

    imageRef = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, nullptr);
    ASSERT_EQ_MSG(nullptr, imageRef, "FAILED: ImageIOTest::CGImageSourceCreateThumbnailAtIndex should return nullptr");
    CFRelease(imageSource);
}

TEST(ImageIO, TypeIdentifierTest) {
    NSArray* expectedTypeIdentifiers = [NSArray arrayWithObjects:@"public.png",
                                                                 @"public.jpeg",
                                                                 @"com.compuserve.gif",
                                                                 @"public.tiff",
                                                                 @"com.microsoft.ico",
                                                                 @"com.microsoft.bmp",
                                                                 nullptr];
    NSArray* actualTypeIdentifiers = (NSArray*)CGImageSourceCopyTypeIdentifiers();
    ASSERT_TRUE_MSG([expectedTypeIdentifiers isEqualToArray:actualTypeIdentifiers],
                    "FAILED: ImageIOTest::Incorrect TypeIdentifier list returned");
}

TEST(ImageIO, CopyJPEGPropertiesTest) {
    const wchar_t* imageFile = L"photo6_1024x670.jpg";
    NSData* imageData = getDataFromImageFile(imageFile);
    ASSERT_NE_MSG(nullptr, imageData, "FAILED: ImageIOTest::Could not find file: [%s]", imageFile);
    CGImageSourceRef imageSource = CGImageSourceCreateWithData((CFDataRef)imageData, nullptr);
    ASSERT_NE_MSG(nullptr, imageSource, "FAILED: ImageIOTest::CGImageSourceCreateWithData returned nullptr");
    CFDictionaryRef imageProperties = CGImageSourceCopyProperties(imageSource, nullptr);
    ASSERT_NE_MSG(nullptr, imageProperties, "FAILED: ImageIOTest::CGImageSourceCopyProperties returned nullptr");
    if (imageProperties && CFDictionaryContainsKey(imageProperties, kCGImagePropertyFileSize)) {
        int fileSize = [(id)CFDictionaryGetValue(imageProperties, kCGImagePropertyFileSize) intValue];
        EXPECT_EQ(218940, fileSize);
    }

    CFRelease(imageSource);
}

TEST(ImageIO, CopyGIFPropertiesTest) {
    const wchar_t* imageFile = L"photo7_4layers_683x1024.gif";
    NSData* imageData = getDataFromImageFile(imageFile);
    ASSERT_NE_MSG(nullptr, imageData, "FAILED: ImageIOTest::Could not find file: [%s]", imageFile);
    CGImageSourceRef imageSource = CGImageSourceCreateWithData((CFDataRef)imageData, nullptr);
    ASSERT_NE_MSG(nullptr, imageSource, "FAILED: ImageIOTest::CGImageSourceCreateWithData returned nullptr");
    CFDictionaryRef imageProperties = CGImageSourceCopyProperties(imageSource, nullptr);
    ASSERT_NE_MSG(nullptr, imageProperties, "FAILED: ImageIOTest::CGImageSourceCopyProperties returned nullptr");
    if (imageProperties && CFDictionaryContainsKey(imageProperties, kCGImagePropertyFileSize)) {
        int fileSize = [(id)CFDictionaryGetValue(imageProperties, kCGImagePropertyFileSize) intValue];
        EXPECT_EQ(669893, fileSize);
    }

    CFRelease(imageSource);
}

TEST(ImageIO, CopyTIFFPropertiesTest) {
    const wchar_t* imageFile = L"photo8_4layers_1024x683.tif";
    NSData* imageData = getDataFromImageFile(imageFile);
    ASSERT_NE_MSG(nullptr, imageData, "FAILED: ImageIOTest::Could not find file: [%s]", imageFile);
    CGImageSourceRef imageSource = CGImageSourceCreateWithData((CFDataRef)imageData, nullptr);
    ASSERT_NE_MSG(nullptr, imageSource, "FAILED: ImageIOTest::CGImageSourceCreateWithData returned nullptr");
    CFDictionaryRef imageProperties = CGImageSourceCopyProperties(imageSource, nullptr);
    ASSERT_NE_MSG(nullptr, imageProperties, "FAILED: ImageIOTest::CGImageSourceCopyProperties returned nullptr");
    if (imageProperties && CFDictionaryContainsKey(imageProperties, kCGImagePropertyFileSize)) {
        int fileSize = [(id)CFDictionaryGetValue(imageProperties, kCGImagePropertyFileSize) intValue];
        EXPECT_EQ(4187742, fileSize);
    }

    CFRelease(imageSource);
}

TEST(ImageIO, CopyPNGPropertiesTest) {
    const wchar_t* imageFile = L"seafloor_256x256.png";
    NSData* imageData = getDataFromImageFile(imageFile);
    ASSERT_NE_MSG(nullptr, imageData, "FAILED: ImageIOTest::Could not find file: [%s]", imageFile);
    CGImageSourceRef imageSource = CGImageSourceCreateWithData((CFDataRef)imageData, nullptr);
    ASSERT_NE_MSG(nullptr, imageSource, "FAILED: ImageIOTest::CGImageSourceCreateWithData returned nullptr");
    CFDictionaryRef imageProperties = CGImageSourceCopyProperties(imageSource, nullptr);
    ASSERT_NE_MSG(nullptr, imageProperties, "FAILED: ImageIOTest::CGImageSourceCopyProperties returned nullptr");
    if (imageProperties && CFDictionaryContainsKey(imageProperties, kCGImagePropertyFileSize)) {
        int fileSize = [(id)CFDictionaryGetValue(imageProperties, kCGImagePropertyFileSize) intValue];
        EXPECT_EQ(59506, fileSize);
    }

    CFRelease(imageSource);
}

TEST(ImageIO, CopyBMPPropertiesTest) {
    const wchar_t* imageFile = L"testimg_227x149.bmp";
    NSData* imageData = getDataFromImageFile(imageFile);
    ASSERT_NE_MSG(nullptr, imageData, "FAILED: ImageIOTest::Could not find file: [%s]", imageFile);
    CGImageSourceRef imageSource = CGImageSourceCreateWithData((CFDataRef)imageData, nullptr);
    ASSERT_NE_MSG(nullptr, imageSource, "FAILED: ImageIOTest::CGImageSourceCreateWithData returned nullptr");
    CFDictionaryRef imageProperties = CGImageSourceCopyProperties(imageSource, nullptr);
    ASSERT_NE_MSG(nullptr, imageProperties, "FAILED: ImageIOTest::CGImageSourceCopyProperties returned nullptr");
    if (imageProperties && CFDictionaryContainsKey(imageProperties, kCGImagePropertyFileSize)) {
        int fileSize = [(id)CFDictionaryGetValue(imageProperties, kCGImagePropertyFileSize) intValue];
        EXPECT_EQ(35050, fileSize);
    }

    CFRelease(imageSource);
}

TEST(ImageIO, CopyICOPropertiesTest) {
    const wchar_t* imageFile = L"photo2_683x1024.ico";
    NSData* imageData = getDataFromImageFile(imageFile);
    ASSERT_NE_MSG(nullptr, imageData, "FAILED: ImageIOTest::Could not find file: [%s]", imageFile);
    CGImageSourceRef imageSource = CGImageSourceCreateWithData((CFDataRef)imageData, nullptr);
    ASSERT_NE_MSG(nullptr, imageSource, "FAILED: ImageIOTest::CGImageSourceCreateWithData returned nullptr");
    CFDictionaryRef imageProperties = CGImageSourceCopyProperties(imageSource, nullptr);
    ASSERT_NE_MSG(nullptr, imageProperties, "FAILED: ImageIOTest::CGImageSourceCopyProperties returned nullptr");
    if (imageProperties && CFDictionaryContainsKey(imageProperties, kCGImagePropertyFileSize)) {
        int fileSize = [(id)CFDictionaryGetValue(imageProperties, kCGImagePropertyFileSize) intValue];
        EXPECT_EQ(1041876, fileSize);
    }

    CFRelease(imageSource);
}

TEST(ImageIO, CopyJPEGPropertiesAtIndexTest) {
    const wchar_t* imageFile = L"photo6_1024x670.jpg";
    NSData* imageData = getDataFromImageFile(imageFile);
    ASSERT_NE_MSG(nullptr, imageData, "FAILED: ImageIOTest::Could not find file: [%s]", imageFile);
    NSDictionary* options = @{
        @"kCGImageSourceTypeIdentifierHint" : @"kUTTypeJPEG",
        @"kCGImageSourceShouldAllowFloat" : @"kCFBooleanTrue",
        @"kCGImageSourceShouldCache" : @"kCFBooleanTrue"
    };
    CGImageSourceRef imageSource = CGImageSourceCreateWithData((CFDataRef)imageData, (CFDictionaryRef)options);
    ASSERT_NE_MSG(nullptr, imageSource, "FAILED: ImageIOTest::CGImageSourceCreateWithData returned nullptr");
    CFDictionaryRef imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, (CFDictionaryRef)options);
    ASSERT_NE_MSG(nullptr, imageProperties, "FAILED: ImageIOTest::CGImageSourceCopyPropertiesAtIndex returned nullptr");

    ASSERT_TRUE_MSG(CFDictionaryContainsKey(imageProperties, kCGImagePropertyJFIFDictionary),
                    "FAILED: ImageIOTest::JFIF dictionary not found");
    CFDictionaryRef jfifDictionary = (CFDictionaryRef)CFDictionaryGetValue(imageProperties, kCGImagePropertyJFIFDictionary);
    ASSERT_TRUE_MSG(CFDictionaryContainsKey(jfifDictionary, kCGImagePropertyJFIFXDensity),
                    "FAILED: ImageIOTest::JFIF dictionary does not contain XDensity");
    double actualXDensity = [(id)CFDictionaryGetValue(jfifDictionary, kCGImagePropertyJFIFXDensity) doubleValue];
    ASSERT_NEAR_MSG(actualXDensity, 72.0, 0.01, "FAILED: ImageIOTest::XDensity mismatch");

    CFRelease(imageSource);
}

TEST(ImageIO, CopyGIFPropertiesAtIndexTest) {
    const wchar_t* imageFile = L"photo7_4layers_683x1024.gif";
    NSData* imageData = getDataFromImageFile(imageFile);
    ASSERT_NE_MSG(nullptr, imageData, "FAILED: ImageIOTest::Could not find file: [%s]", imageFile);
    NSDictionary* options = @{
        @"kCGImageSourceTypeIdentifierHint" : @"kUTTypeGIF",
        @"kCGImageSourceShouldAllowFloat" : @"kCFBooleanTrue",
        @"kCGImageSourceShouldCache" : @"kCFBooleanTrue"
    };
    CGImageSourceRef imageSource = CGImageSourceCreateWithData((CFDataRef)imageData, (CFDictionaryRef)options);
    ASSERT_NE_MSG(nullptr, imageSource, "FAILED: ImageIOTest::CGImageSourceCreateWithData returned nullptr");
    CFDictionaryRef imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, (CFDictionaryRef)options);
    ASSERT_NE_MSG(nullptr, imageProperties, "FAILED: ImageIOTest::CGImageSourceCopyPropertiesAtIndex returned nullptr");

    ASSERT_TRUE_MSG(CFDictionaryContainsKey(imageProperties, kCGImagePropertyPixelHeight),
                    "FAILED: ImageIOTest::GIF PixelHeight Property not found");
    int actualHeight = [(id)CFDictionaryGetValue(imageProperties, kCGImagePropertyPixelHeight) intValue];
    EXPECT_EQ(1024, actualHeight);
    ASSERT_TRUE_MSG(CFDictionaryContainsKey(imageProperties, kCGImagePropertyGIFDictionary),
                    "FAILED: ImageIOTest::GIF Dictionary not found");
    CFDictionaryRef gifDictionary = (CFDictionaryRef)CFDictionaryGetValue(imageProperties, kCGImagePropertyGIFDictionary);
    ASSERT_TRUE_MSG(CFDictionaryContainsKey(gifDictionary, kCGImagePropertyGIFDelayTime),
                    "FAILED: ImageIOTest::GIF dictionary does not contain Delay Time");
    double actualDelayTime = [(id)CFDictionaryGetValue(gifDictionary, kCGImagePropertyGIFDelayTime) doubleValue];
    EXPECT_NEAR_MSG(actualDelayTime, 0.1, 0.01, "FAILED: ImageIOTest::Delay Time mismatch");

    CFRelease(imageSource);
}

TEST(ImageIO, CopyTIFFPropertiesAtIndexTest) {
    const wchar_t* imageFile = L"photo8_4layers_1024x683.tif";
    NSData* imageData = getDataFromImageFile(imageFile);
    ASSERT_NE_MSG(nullptr, imageData, "FAILED: ImageIOTest::Could not find file: [%s]", imageFile);
    NSDictionary* options = @{
        @"kCGImageSourceTypeIdentifierHint" : @"kUTTypeTIFF",
        @"kCGImageSourceShouldAllowFloat" : @"kCFBooleanTrue",
        @"kCGImageSourceShouldCache" : @"kCFBooleanTrue"
    };
    CGImageSourceRef imageSource = CGImageSourceCreateWithData((CFDataRef)imageData, (CFDictionaryRef)options);
    ASSERT_NE_MSG(nullptr, imageSource, "FAILED: ImageIOTest::CGImageSourceCreateWithData returned nullptr");
    CFDictionaryRef imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, (CFDictionaryRef)options);
    ASSERT_NE_MSG(nullptr, imageProperties, "FAILED: ImageIOTest::CGImageSourceCopyPropertiesAtIndex returned nullptr");

    ASSERT_TRUE_MSG(CFDictionaryContainsKey(imageProperties, kCGImagePropertyTIFFDictionary),
                    "FAILED: ImageIOTest::TIFF dictionary not found");
    CFDictionaryRef tiffDictionary = (CFDictionaryRef)CFDictionaryGetValue(imageProperties, kCGImagePropertyTIFFDictionary);
    ASSERT_TRUE_MSG(CFDictionaryContainsKey(tiffDictionary, kCGImagePropertyTIFFResolutionUnit),
                    "FAILED: ImageIOTest::TIFF dictionary does not contain Resolution Unit");
    int actualResolutionUnit = [(id)CFDictionaryGetValue(tiffDictionary, kCGImagePropertyTIFFResolutionUnit) intValue];
    EXPECT_EQ(2, actualResolutionUnit);

    CFRelease(imageSource);
}

TEST(ImageIO, CopyPNGPropertiesAtIndexTest) {
    const wchar_t* imageFile = L"seafloor_256x256.png";
    NSData* imageData = getDataFromImageFile(imageFile);
    ASSERT_NE_MSG(nullptr, imageData, "FAILED: ImageIOTest::Could not find file: [%s]", imageFile);
    NSDictionary* options = @{
        @"kCGImageSourceTypeIdentifierHint" : @"kUTTypePNG",
        @"kCGImageSourceShouldAllowFloat" : @"kCFBooleanTrue",
        @"kCGImageSourceShouldCache" : @"kCFBooleanTrue"
    };
    CGImageSourceRef imageSource = CGImageSourceCreateWithData((CFDataRef)imageData, (CFDictionaryRef)options);
    ASSERT_NE_MSG(nullptr, imageSource, "FAILED: ImageIOTest::CGImageSourceCreateWithData returned nullptr");
    CFDictionaryRef imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, (CFDictionaryRef)options);
    ASSERT_NE_MSG(nullptr, imageProperties, "FAILED: ImageIOTest::CGImageSourceCopyPropertiesAtIndex returned nullptr");

    ASSERT_TRUE_MSG(CFDictionaryContainsKey(imageProperties, kCGImagePropertyPNGDictionary),
                    "FAILED: ImageIOTest::PNG dictionary not found");
    CFDictionaryRef pngDictionary = (CFDictionaryRef)CFDictionaryGetValue(imageProperties, kCGImagePropertyPNGDictionary);
    ASSERT_TRUE_MSG(CFDictionaryContainsKey(pngDictionary, kCGImagePropertyPNGGamma),
                    "FAILED: ImageIOTest::PNG dictionary does not contain Gamma");
    int actualGamma = [(id)CFDictionaryGetValue(pngDictionary, kCGImagePropertyPNGGamma) intValue];
    EXPECT_EQ(45455, actualGamma);

    CFRelease(imageSource);
}

TEST(ImageIO, DestinationTest) {
    const wchar_t* imageFile = L"photo6_1024x670.jpg";
    NSData* imageData = getDataFromImageFile(imageFile);
    CGImageSourceRef imageSource = CGImageSourceCreateWithData((CFDataRef)imageData, NULL);
    CGImageRef imageRef = CGImageSourceCreateImageAtIndex(imageSource, 0, NULL);
    CFRelease(imageSource);

    // Written as BGRA
    const wchar_t* outFile = L"outphoto.tif";
    CFURLRef imgUrl = getURLRefForOutFile(outFile);

    // Here we do not release myImageDest right after use to check that images can be read immediately after Finalize
    CGImageDestinationRef myImageDest = CGImageDestinationCreateWithURL(imgUrl, kUTTypeTIFF, 1, NULL);
    CGImageDestinationAddImage(myImageDest, imageRef, NULL);
    CGImageDestinationFinalize(myImageDest);

    // Read back in the newly written image to check properties
    imageData = getDataFromImageFile(imgUrl);
    ASSERT_NE_MSG(nullptr, imageData, "FAILED: ImageIOTest::Could not find file: [%s]", outFile);
    imageSource = CGImageSourceCreateWithData((CFDataRef)imageData, NULL);
    ASSERT_NE_MSG(nullptr, imageSource, "FAILED: ImageIOTest::CGImageSourceCreateWithData returned nullptr");
    CGImageRef imageRefOut = CGImageSourceCreateImageAtIndex(imageSource, 0, NULL);
    ASSERT_NE_MSG(nullptr, imageRefOut, "FAILED: ImageIOTest::CGImageSourceCreateImageAtIndex returned nullptr");
    EXPECT_EQ(kCGImageAlphaFirst, CGImageGetAlphaInfo(imageRefOut));
    EXPECT_EQ(kCGImageAlphaFirst | kCGBitmapByteOrder32Little, CGImageGetBitmapInfo(imageRefOut));
    EXPECT_EQ(8, CGImageGetBitsPerComponent(imageRefOut));
    EXPECT_EQ(32, CGImageGetBitsPerPixel(imageRefOut));
    EXPECT_EQ(3, CGColorSpaceGetNumberOfComponents(CGImageGetColorSpace(imageRefOut)));
    EXPECT_EQ(670, CGImageGetHeight(imageRefOut));
    EXPECT_EQ(1024, CGImageGetWidth(imageRefOut));
    size_t frameCount = CGImageSourceGetCount(imageSource);
    EXPECT_EQ(1, frameCount);
    CFRelease(imageSource);

    // Written as RGB
    const wchar_t* outFile2 = L"outphoto.jpg";
    imgUrl = getURLRefForOutFile(outFile2);

    CFRelease(myImageDest);
    myImageDest = CGImageDestinationCreateWithURL(imgUrl, kUTTypeJPEG, 1, NULL);
    CGImageDestinationAddImage(myImageDest, imageRef, NULL);
    CGImageDestinationFinalize(myImageDest);

    // Read back in the newly written image to check properties
    imageData = getDataFromImageFile(imgUrl);
    ASSERT_NE_MSG(nullptr, imageData, "FAILED: ImageIOTest::Could not find file: [%s]", outFile2);
    imageSource = CGImageSourceCreateWithData((CFDataRef)imageData, NULL);
    ASSERT_NE_MSG(nullptr, imageSource, "FAILED: ImageIOTest::CGImageSourceCreateWithData returned nullptr");
    imageRefOut = CGImageSourceCreateImageAtIndex(imageSource, 0, NULL);
    ASSERT_NE_MSG(nullptr, imageRefOut, "FAILED: ImageIOTest::CGImageSourceCreateImageAtIndex returned nullptr");
    EXPECT_EQ(kCGImageAlphaNone, CGImageGetAlphaInfo(imageRefOut));
    EXPECT_EQ(kCGImageAlphaNone, CGImageGetBitmapInfo(imageRefOut));
    EXPECT_EQ(8, CGImageGetBitsPerComponent(imageRefOut));
    EXPECT_EQ(24, CGImageGetBitsPerPixel(imageRefOut));
    EXPECT_EQ(3, CGColorSpaceGetNumberOfComponents(CGImageGetColorSpace(imageRefOut)));
    EXPECT_EQ(670, CGImageGetHeight(imageRefOut));
    EXPECT_EQ(1024, CGImageGetWidth(imageRefOut));
    frameCount = CGImageSourceGetCount(imageSource);
    EXPECT_EQ(1, frameCount);
    CFRelease(imageSource);

    // Written as RGB
    const wchar_t* outFile3 = L"outphoto.png";
    imgUrl = getURLRefForOutFile(outFile3);

    CFRelease(myImageDest);
    myImageDest = CGImageDestinationCreateWithURL(imgUrl, kUTTypePNG, 1, NULL);
    CGImageDestinationAddImage(myImageDest, imageRef, NULL);
    CGImageDestinationFinalize(myImageDest);

    // Read back in the newly written image to check properties
    imageData = getDataFromImageFile(imgUrl);
    ASSERT_NE_MSG(nullptr, imageData, "FAILED: ImageIOTest::Could not find file: [%s]", outFile3);
    imageSource = CGImageSourceCreateWithData((CFDataRef)imageData, NULL);
    ASSERT_NE_MSG(nullptr, imageSource, "FAILED: ImageIOTest::CGImageSourceCreateWithData returned nullptr");
    imageRefOut = CGImageSourceCreateImageAtIndex(imageSource, 0, NULL);
    ASSERT_NE_MSG(nullptr, imageRefOut, "FAILED: ImageIOTest::CGImageSourceCreateImageAtIndex returned nullptr");
    EXPECT_EQ(kCGImageAlphaNone, CGImageGetAlphaInfo(imageRefOut));
    EXPECT_EQ(kCGImageAlphaNone, CGImageGetBitmapInfo(imageRefOut));
    EXPECT_EQ(8, CGImageGetBitsPerComponent(imageRefOut));
    EXPECT_EQ(24, CGImageGetBitsPerPixel(imageRefOut));
    EXPECT_EQ(3, CGColorSpaceGetNumberOfComponents(CGImageGetColorSpace(imageRefOut)));
    EXPECT_EQ(670, CGImageGetHeight(imageRefOut));
    EXPECT_EQ(1024, CGImageGetWidth(imageRefOut));
    frameCount = CGImageSourceGetCount(imageSource);
    EXPECT_EQ(1, frameCount);
    CFRelease(imageSource);

    // Written as BGRX
    const wchar_t* outFile4 = L"outphoto.bmp";
    imgUrl = getURLRefForOutFile(outFile4);

    CFRelease(myImageDest);
    myImageDest = CGImageDestinationCreateWithURL(imgUrl, kUTTypeBMP, 1, NULL);
    CGImageDestinationAddImage(myImageDest, imageRef, NULL);
    CGImageDestinationFinalize(myImageDest);

    // Read back in the newly written image to check properties
    imageData = getDataFromImageFile(imgUrl);
    ASSERT_NE_MSG(nullptr, imageData, "FAILED: ImageIOTest::Could not find file: [%s]", outFile4);
    imageSource = CGImageSourceCreateWithData((CFDataRef)imageData, NULL);
    ASSERT_NE_MSG(nullptr, imageSource, "FAILED: ImageIOTest::CGImageSourceCreateWithData returned nullptr");
    imageRefOut = CGImageSourceCreateImageAtIndex(imageSource, 0, NULL);
    ASSERT_NE_MSG(nullptr, imageRefOut, "FAILED: ImageIOTest::CGImageSourceCreateImageAtIndex returned nullptr");
    EXPECT_EQ(kCGImageAlphaNoneSkipFirst, CGImageGetAlphaInfo(imageRefOut));
    EXPECT_EQ(kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrder32Little, CGImageGetBitmapInfo(imageRefOut));
    EXPECT_EQ(8, CGImageGetBitsPerComponent(imageRefOut));
    EXPECT_EQ(32, CGImageGetBitsPerPixel(imageRefOut));
    EXPECT_EQ(3, CGColorSpaceGetNumberOfComponents(CGImageGetColorSpace(imageRefOut)));
    EXPECT_EQ(670, CGImageGetHeight(imageRefOut));
    EXPECT_EQ(1024, CGImageGetWidth(imageRefOut));
    frameCount = CGImageSourceGetCount(imageSource);
    EXPECT_EQ(1, frameCount);
    CFRelease(imageSource);

    // Written as Paletted/Indexed
    const wchar_t* outFile5 = L"outphoto.gif";
    imgUrl = getURLRefForOutFile(outFile5);

    CFRelease(myImageDest);
    myImageDest = CGImageDestinationCreateWithURL(imgUrl, kUTTypeGIF, 1, NULL);
    CGImageDestinationAddImage(myImageDest, imageRef, NULL);
    CGImageDestinationFinalize(myImageDest);

    // Read back in the newly written image to check properties
    imageData = getDataFromImageFile(imgUrl);
    ASSERT_NE_MSG(nullptr, imageData, "FAILED: ImageIOTest::Could not find file: [%s]", outFile5);
    imageSource = CGImageSourceCreateWithData((CFDataRef)imageData, NULL);
    ASSERT_NE_MSG(nullptr, imageSource, "FAILED: ImageIOTest::CGImageSourceCreateWithData returned nullptr");
    imageRefOut = CGImageSourceCreateImageAtIndex(imageSource, 0, NULL);
    ASSERT_NE_MSG(nullptr, imageRefOut, "FAILED: ImageIOTest::CGImageSourceCreateImageAtIndex returned nullptr");
    EXPECT_EQ(kCGImageAlphaNone, CGImageGetAlphaInfo(imageRefOut));
    EXPECT_EQ(kCGImageAlphaNone, CGImageGetBitmapInfo(imageRefOut));
    EXPECT_EQ(8, CGImageGetBitsPerComponent(imageRefOut));
    EXPECT_EQ(8, CGImageGetBitsPerPixel(imageRefOut));
    // TODO: Check Paletted/Indexed color space.
    EXPECT_EQ(670, CGImageGetHeight(imageRefOut));
    EXPECT_EQ(1024, CGImageGetWidth(imageRefOut));
    frameCount = CGImageSourceGetCount(imageSource);
    EXPECT_EQ(1, frameCount);
    CFRelease(imageSource);
    CFRelease(myImageDest);
}

TEST(ImageIO, DestinationFromSourceTest) {
    const wchar_t* imageFile = L"testimg_227x149.bmp";
    NSData* imageData = getDataFromImageFile(imageFile);
    CGImageSourceRef imageSource = CGImageSourceCreateWithData((CFDataRef)imageData, NULL);

    // Written as BGRA
    const wchar_t* outFile = L"outphoto2.tif";
    CFURLRef imgUrl = getURLRefForOutFile(outFile);

    CGImageDestinationRef myImageDest = CGImageDestinationCreateWithURL(imgUrl, kUTTypeTIFF, 1, NULL);
    CGImageDestinationAddImageFromSource(myImageDest, imageSource, 0, NULL);
    CGImageDestinationFinalize(myImageDest);
    CFRelease(myImageDest);

    // Read back in the newly written image to check properties
    CFRelease(imageSource);
    imageData = getDataFromImageFile(imgUrl);
    ASSERT_NE_MSG(nullptr, imageData, "FAILED: ImageIOTest::Could not find file: [%s]", outFile);
    imageSource = CGImageSourceCreateWithData((CFDataRef)imageData, NULL);
    ASSERT_NE_MSG(nullptr, imageSource, "FAILED: ImageIOTest::CGImageSourceCreateWithData returned nullptr");
    CGImageRef imageRefOut = CGImageSourceCreateImageAtIndex(imageSource, 0, NULL);
    ASSERT_NE_MSG(nullptr, imageRefOut, "FAILED: ImageIOTest::CGImageSourceCreateImageAtIndex returned nullptr");
    EXPECT_EQ(kCGImageAlphaFirst, CGImageGetAlphaInfo(imageRefOut));
    EXPECT_EQ(kCGImageAlphaFirst | kCGBitmapByteOrder32Little, CGImageGetBitmapInfo(imageRefOut));
    EXPECT_EQ(8, CGImageGetBitsPerComponent(imageRefOut));
    EXPECT_EQ(32, CGImageGetBitsPerPixel(imageRefOut));
    EXPECT_EQ(3, CGColorSpaceGetNumberOfComponents(CGImageGetColorSpace(imageRefOut)));
    EXPECT_EQ(149, CGImageGetHeight(imageRefOut));
    EXPECT_EQ(227, CGImageGetWidth(imageRefOut));
    size_t frameCount = CGImageSourceGetCount(imageSource);
    EXPECT_EQ(1, frameCount);

    // Written as RGB
    const wchar_t* outFile2 = L"outphoto2.jpg";
    imgUrl = getURLRefForOutFile(outFile2);

    myImageDest = CGImageDestinationCreateWithURL(imgUrl, kUTTypeJPEG, 1, NULL);
    CGImageDestinationAddImageFromSource(myImageDest, imageSource, 0, NULL);
    CGImageDestinationFinalize(myImageDest);
    CFRelease(imageSource);
    CFRelease(myImageDest);

    // Read back in the newly written image to check properties
    imageData = getDataFromImageFile(imgUrl);
    ASSERT_NE_MSG(nullptr, imageData, "FAILED: ImageIOTest::Could not find file: [%s]", outFile2);
    imageSource = CGImageSourceCreateWithData((CFDataRef)imageData, NULL);
    ASSERT_NE_MSG(nullptr, imageSource, "FAILED: ImageIOTest::CGImageSourceCreateWithData returned nullptr");
    imageRefOut = CGImageSourceCreateImageAtIndex(imageSource, 0, NULL);
    ASSERT_NE_MSG(nullptr, imageRefOut, "FAILED: ImageIOTest::CGImageSourceCreateImageAtIndex returned nullptr");
    EXPECT_EQ(kCGImageAlphaNone, CGImageGetAlphaInfo(imageRefOut));
    EXPECT_EQ(kCGImageAlphaNone, CGImageGetBitmapInfo(imageRefOut));
    EXPECT_EQ(8, CGImageGetBitsPerComponent(imageRefOut));
    EXPECT_EQ(24, CGImageGetBitsPerPixel(imageRefOut));
    EXPECT_EQ(3, CGColorSpaceGetNumberOfComponents(CGImageGetColorSpace(imageRefOut)));
    EXPECT_EQ(149, CGImageGetHeight(imageRefOut));
    EXPECT_EQ(227, CGImageGetWidth(imageRefOut));
    frameCount = CGImageSourceGetCount(imageSource);
    EXPECT_EQ(1, frameCount);

    // Written as RGB
    const wchar_t* outFile3 = L"outphoto2.png";
    imgUrl = getURLRefForOutFile(outFile3);

    myImageDest = CGImageDestinationCreateWithURL(imgUrl, kUTTypePNG, 1, NULL);
    CGImageDestinationAddImageFromSource(myImageDest, imageSource, 0, NULL);
    CGImageDestinationFinalize(myImageDest);
    CFRelease(imageSource);
    CFRelease(myImageDest);

    // Read back in the newly written image to check properties
    imageData = getDataFromImageFile(imgUrl);
    ASSERT_NE_MSG(nullptr, imageData, "FAILED: ImageIOTest::Could not find file: [%s]", outFile3);
    imageSource = CGImageSourceCreateWithData((CFDataRef)imageData, NULL);
    ASSERT_NE_MSG(nullptr, imageSource, "FAILED: ImageIOTest::CGImageSourceCreateWithData returned nullptr");
    imageRefOut = CGImageSourceCreateImageAtIndex(imageSource, 0, NULL);
    ASSERT_NE_MSG(nullptr, imageRefOut, "FAILED: ImageIOTest::CGImageSourceCreateImageAtIndex returned nullptr");
    EXPECT_EQ(kCGImageAlphaNone, CGImageGetAlphaInfo(imageRefOut));
    EXPECT_EQ(kCGImageAlphaNone, CGImageGetBitmapInfo(imageRefOut));
    EXPECT_EQ(8, CGImageGetBitsPerComponent(imageRefOut));
    EXPECT_EQ(24, CGImageGetBitsPerPixel(imageRefOut));
    EXPECT_EQ(3, CGColorSpaceGetNumberOfComponents(CGImageGetColorSpace(imageRefOut)));
    EXPECT_EQ(149, CGImageGetHeight(imageRefOut));
    EXPECT_EQ(227, CGImageGetWidth(imageRefOut));
    frameCount = CGImageSourceGetCount(imageSource);
    EXPECT_EQ(1, frameCount);

    // Written as BGRX
    const wchar_t* outFile4 = L"outphoto2.bmp";
    imgUrl = getURLRefForOutFile(outFile4);

    myImageDest = CGImageDestinationCreateWithURL(imgUrl, kUTTypeBMP, 1, NULL);
    CGImageDestinationAddImageFromSource(myImageDest, imageSource, 0, NULL);
    CGImageDestinationFinalize(myImageDest);
    CFRelease(imageSource);
    CFRelease(myImageDest);

    // Read back in the newly written image to check properties
    imageData = getDataFromImageFile(imgUrl);
    ASSERT_NE_MSG(nullptr, imageData, "FAILED: ImageIOTest::Could not find file: [%s]", outFile4);
    imageSource = CGImageSourceCreateWithData((CFDataRef)imageData, NULL);
    ASSERT_NE_MSG(nullptr, imageSource, "FAILED: ImageIOTest::CGImageSourceCreateWithData returned nullptr");
    imageRefOut = CGImageSourceCreateImageAtIndex(imageSource, 0, NULL);
    ASSERT_NE_MSG(nullptr, imageRefOut, "FAILED: ImageIOTest::CGImageSourceCreateImageAtIndex returned nullptr");
    EXPECT_EQ(kCGImageAlphaNoneSkipFirst, CGImageGetAlphaInfo(imageRefOut));
    EXPECT_EQ(kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrder32Little, CGImageGetBitmapInfo(imageRefOut));
    EXPECT_EQ(8, CGImageGetBitsPerComponent(imageRefOut));
    EXPECT_EQ(32, CGImageGetBitsPerPixel(imageRefOut));
    EXPECT_EQ(3, CGColorSpaceGetNumberOfComponents(CGImageGetColorSpace(imageRefOut)));
    EXPECT_EQ(149, CGImageGetHeight(imageRefOut));
    EXPECT_EQ(227, CGImageGetWidth(imageRefOut));
    frameCount = CGImageSourceGetCount(imageSource);
    EXPECT_EQ(1, frameCount);
    CFRelease(imageSource);
}

TEST(ImageIO, DestinationMultiFrameTest) {
    const wchar_t* imageFile = L"photo2_683x1024.ico";
    NSData* imageData = getDataFromImageFile(imageFile);
    CGImageSourceRef imageSource = CGImageSourceCreateWithData((CFDataRef)imageData, NULL);
    CGImageRef imageRef = CGImageSourceCreateImageAtIndex(imageSource, 0, NULL);

    const wchar_t* imageFile2 = L"photo8_4layers_1024x683.tif";
    NSData* imageData2 = getDataFromImageFile(imageFile2);
    CGImageSourceRef imageSource2 = CGImageSourceCreateWithData((CFDataRef)imageData2, NULL);
    CGImageRef imageRef2 = CGImageSourceCreateImageAtIndex(imageSource2, 0, NULL);

    // Written as BGRA
    const wchar_t* outFile = L"outphoto_multiframe.tif";
    CFURLRef imgUrl = getURLRefForOutFile(outFile);

    CGImageDestinationRef myImageDest = CGImageDestinationCreateWithURL(imgUrl, kUTTypeTIFF, 3, NULL);
    CGImageDestinationAddImage(myImageDest, imageRef, NULL);
    CGImageDestinationAddImageFromSource(myImageDest, imageSource2, 0, NULL);
    CGImageDestinationAddImageFromSource(myImageDest, imageSource2, 2, NULL);
    CGImageDestinationFinalize(myImageDest);
    CFRelease(imageSource);
    CFRelease(imageSource2);
    CFRelease(myImageDest);

    // Read back in the newly written image to check properties
    imageData = getDataFromImageFile(imgUrl);
    ASSERT_NE_MSG(nullptr, imageData, "FAILED: ImageIOTest::Could not find file: [%s]", outFile);
    imageSource = CGImageSourceCreateWithData((CFDataRef)imageData, NULL);
    ASSERT_NE_MSG(nullptr, imageSource, "FAILED: ImageIOTest::CGImageSourceCreateWithData returned nullptr");
    size_t frameCount = CGImageSourceGetCount(imageSource);
    ASSERT_EQ_MSG(frameCount, 3, "FAILED: ImageIOTest::FrameCount");

    CGImageRef imageRefOut = CGImageSourceCreateImageAtIndex(imageSource, 0, NULL);
    ASSERT_NE_MSG(nullptr, imageRefOut, "FAILED: ImageIOTest::CGImageSourceCreateImageAtIndex returned nullptr");
    EXPECT_EQ(kCGImageAlphaFirst, CGImageGetAlphaInfo(imageRefOut));
    EXPECT_EQ(kCGImageAlphaFirst | kCGBitmapByteOrder32Little, CGImageGetBitmapInfo(imageRefOut));
    EXPECT_EQ(8, CGImageGetBitsPerComponent(imageRefOut));
    EXPECT_EQ(32, CGImageGetBitsPerPixel(imageRefOut));
    EXPECT_EQ(3, CGColorSpaceGetNumberOfComponents(CGImageGetColorSpace(imageRefOut)));
    EXPECT_EQ(1024, CGImageGetHeight(imageRefOut));
    EXPECT_EQ(683, CGImageGetWidth(imageRefOut));

    imageRefOut = CGImageSourceCreateImageAtIndex(imageSource, 1, NULL);
    ASSERT_NE_MSG(nullptr, imageRefOut, "FAILED: ImageIOTest::CGImageSourceCreateImageAtIndex returned nullptr");
    EXPECT_EQ(kCGImageAlphaFirst, CGImageGetAlphaInfo(imageRefOut));
    EXPECT_EQ(kCGImageAlphaFirst | kCGBitmapByteOrder32Little, CGImageGetBitmapInfo(imageRefOut));
    EXPECT_EQ(8, CGImageGetBitsPerComponent(imageRefOut));
    EXPECT_EQ(32, CGImageGetBitsPerPixel(imageRefOut));
    EXPECT_EQ(3, CGColorSpaceGetNumberOfComponents(CGImageGetColorSpace(imageRefOut)));
    EXPECT_EQ(683, CGImageGetHeight(imageRefOut));
    EXPECT_EQ(1024, CGImageGetWidth(imageRefOut));

    imageRefOut = CGImageSourceCreateImageAtIndex(imageSource, 2, NULL);
    ASSERT_NE_MSG(nullptr, imageRefOut, "FAILED: ImageIOTest::CGImageSourceCreateImageAtIndex returned nullptr");
    EXPECT_EQ(kCGImageAlphaFirst, CGImageGetAlphaInfo(imageRefOut));
    EXPECT_EQ(kCGImageAlphaFirst | kCGBitmapByteOrder32Little, CGImageGetBitmapInfo(imageRefOut));
    EXPECT_EQ(8, CGImageGetBitsPerComponent(imageRefOut));
    EXPECT_EQ(32, CGImageGetBitsPerPixel(imageRefOut));
    EXPECT_EQ(3, CGColorSpaceGetNumberOfComponents(CGImageGetColorSpace(imageRefOut)));
    EXPECT_EQ(683, CGImageGetHeight(imageRefOut));
    EXPECT_EQ(1024, CGImageGetWidth(imageRefOut));

    CFRelease(imageSource);
}

TEST(ImageIO, DestinationMultiFrameGifTest) {
    const wchar_t* imageFile = L"photo2_683x1024.ico";
    NSData* imageData = getDataFromImageFile(imageFile);
    CGImageSourceRef imageSource = CGImageSourceCreateWithData((CFDataRef)imageData, NULL);
    CGImageRef imageRef = CGImageSourceCreateImageAtIndex(imageSource, 0, NULL);

    const wchar_t* imageFile2 = L"photo8_4layers_1024x683.tif";
    NSData* imageData2 = getDataFromImageFile(imageFile2);
    CGImageSourceRef imageSource2 = CGImageSourceCreateWithData((CFDataRef)imageData2, NULL);
    CGImageRef imageRef2 = CGImageSourceCreateImageAtIndex(imageSource2, 0, NULL);

    // Written as Paletted/Indexed
    const wchar_t* outFile = L"outphoto_multiframe.gif";
    CFURLRef imgUrl = getURLRefForOutFile(outFile);

    CGImageDestinationRef myImageDest = CGImageDestinationCreateWithURL(imgUrl, kUTTypeGIF, 3, NULL);
    CGImageDestinationAddImage(myImageDest, imageRef, NULL);
    CGImageDestinationAddImageFromSource(myImageDest, imageSource2, 0, NULL);
    CGImageDestinationAddImageFromSource(myImageDest, imageSource2, 2, NULL);
    CGImageDestinationFinalize(myImageDest);
    CFRelease(imageSource);
    CFRelease(imageSource2);
    CFRelease(myImageDest);

    // Read back in the newly written image to check properties
    imageData = getDataFromImageFile(imgUrl);
    ASSERT_NE_MSG(nullptr, imageData, "FAILED: ImageIOTest::Could not find file: [%s]", outFile);
    imageSource = CGImageSourceCreateWithData((CFDataRef)imageData, NULL);
    ASSERT_NE_MSG(nullptr, imageSource, "FAILED: ImageIOTest::CGImageSourceCreateWithData returned nullptr");
    size_t frameCount = CGImageSourceGetCount(imageSource);
    ASSERT_EQ_MSG(frameCount, 3, "FAILED: ImageIOTest::FrameCount");

    CGImageRef imageRefOut = CGImageSourceCreateImageAtIndex(imageSource, 0, NULL);
    ASSERT_NE_MSG(nullptr, imageRefOut, "FAILED: ImageIOTest::CGImageSourceCreateImageAtIndex returned nullptr");
    EXPECT_EQ(kCGImageAlphaNone, CGImageGetAlphaInfo(imageRefOut));
    EXPECT_EQ(kCGImageAlphaNone, CGImageGetBitmapInfo(imageRefOut));
    EXPECT_EQ(8, CGImageGetBitsPerComponent(imageRefOut));
    EXPECT_EQ(8, CGImageGetBitsPerPixel(imageRefOut));
    // TODO: Check Paletted/Indexed color space.
    EXPECT_EQ(1024, CGImageGetHeight(imageRefOut));
    EXPECT_EQ(683, CGImageGetWidth(imageRefOut));

    imageRefOut = CGImageSourceCreateImageAtIndex(imageSource, 1, NULL);
    ASSERT_NE_MSG(nullptr, imageRefOut, "FAILED: ImageIOTest::CGImageSourceCreateImageAtIndex returned nullptr");
    EXPECT_EQ(kCGImageAlphaNone, CGImageGetAlphaInfo(imageRefOut));
    EXPECT_EQ(kCGImageAlphaNone, CGImageGetBitmapInfo(imageRefOut));
    EXPECT_EQ(8, CGImageGetBitsPerComponent(imageRefOut));
    EXPECT_EQ(8, CGImageGetBitsPerPixel(imageRefOut));
    // TODO: Check Paletted/Indexed color space.
    EXPECT_EQ(683, CGImageGetHeight(imageRefOut));
    EXPECT_EQ(1024, CGImageGetWidth(imageRefOut));

    imageRefOut = CGImageSourceCreateImageAtIndex(imageSource, 2, NULL);
    ASSERT_NE_MSG(nullptr, imageRefOut, "FAILED: ImageIOTest::CGImageSourceCreateImageAtIndex returned nullptr");
    EXPECT_EQ(kCGImageAlphaNone, CGImageGetAlphaInfo(imageRefOut));
    EXPECT_EQ(kCGImageAlphaNone, CGImageGetBitmapInfo(imageRefOut));
    EXPECT_EQ(8, CGImageGetBitsPerComponent(imageRefOut));
    EXPECT_EQ(8, CGImageGetBitsPerPixel(imageRefOut));
    // TODO: Check Paletted/Indexed color space.
    EXPECT_EQ(683, CGImageGetHeight(imageRefOut));
    EXPECT_EQ(1024, CGImageGetWidth(imageRefOut));

    CFRelease(imageSource);
}

TEST(ImageIO, DestinationDataTest) {
    const wchar_t* imageFile = L"photo2_683x1024.ico";
    NSData* imageData = getDataFromImageFile(imageFile);
    CGImageSourceRef imageSource = CGImageSourceCreateWithData((CFDataRef)imageData, NULL);
    CGImageRef imageRef = CGImageSourceCreateImageAtIndex(imageSource, 0, NULL);
    CFRelease(imageSource);

    // Create buffer to hold destination image in
    NSMutableData* dataBuffer = [NSMutableData dataWithCapacity:10000000];

    CGImageDestinationRef myImageDest = CGImageDestinationCreateWithData((CFMutableDataRef)dataBuffer, kUTTypeTIFF, 1, NULL);
    CGImageDestinationAddImage(myImageDest, imageRef, NULL);
    CGImageDestinationFinalize(myImageDest);
    CFRelease(myImageDest);

    imageSource = CGImageSourceCreateWithData((CFDataRef)dataBuffer, NULL);
    ASSERT_NE_MSG(nullptr, imageSource, "FAILED: ImageIOTest::CGImageSourceCreateWithData returned nullptr");
    size_t frameCount = CGImageSourceGetCount(imageSource);
    ASSERT_EQ_MSG(frameCount, 1, "FAILED: ImageIOTest::FrameCount");
    CGImageRef imageRefOut = CGImageSourceCreateImageAtIndex(imageSource, 0, NULL);
    ASSERT_NE_MSG(nullptr, imageRefOut, "FAILED: ImageIOTest::CGImageSourceCreateImageAtIndex returned nullptr");
    EXPECT_EQ(kCGImageAlphaFirst, CGImageGetAlphaInfo(imageRefOut));
    EXPECT_EQ(kCGImageAlphaFirst | kCGBitmapByteOrder32Little, CGImageGetBitmapInfo(imageRefOut));
    EXPECT_EQ(8, CGImageGetBitsPerComponent(imageRefOut));
    EXPECT_EQ(32, CGImageGetBitsPerPixel(imageRefOut));
    EXPECT_EQ(3, CGColorSpaceGetNumberOfComponents(CGImageGetColorSpace(imageRef)));
    EXPECT_EQ(1024, CGImageGetHeight(imageRefOut));
    EXPECT_EQ(683, CGImageGetWidth(imageRefOut));
    CFRelease(imageSource);
}

TEST(ImageIO, DestinationMultiFrameDataTest) {
    const wchar_t* imageFile = L"photo2_683x1024.ico";
    NSData* imageData = getDataFromImageFile(imageFile);
    CGImageSourceRef imageSource = CGImageSourceCreateWithData((CFDataRef)imageData, NULL);
    CGImageRef imageRef = CGImageSourceCreateImageAtIndex(imageSource, 0, NULL);

    const wchar_t* imageFile2 = L"photo8_4layers_1024x683.tif";
    NSData* imageData2 = getDataFromImageFile(imageFile2);
    CGImageSourceRef imageSource2 = CGImageSourceCreateWithData((CFDataRef)imageData2, NULL);
    CGImageRef imageRef2 = CGImageSourceCreateImageAtIndex(imageSource2, 0, NULL);

    NSMutableData* dataBuffer = [NSMutableData dataWithCapacity:10000000];

    CGImageDestinationRef myImageDest = CGImageDestinationCreateWithData((CFMutableDataRef)dataBuffer, kUTTypeTIFF, 3, NULL);
    CGImageDestinationAddImage(myImageDest, imageRef, NULL);
    CGImageDestinationAddImageFromSource(myImageDest, imageSource2, 0, NULL);
    CGImageDestinationAddImageFromSource(myImageDest, imageSource2, 2, NULL);
    CGImageDestinationFinalize(myImageDest);
    CFRelease(imageSource);
    CFRelease(imageSource2);
    CFRelease(myImageDest);

    // Read back in the newly written image to check properties
    imageSource = CGImageSourceCreateWithData((CFDataRef)dataBuffer, NULL);
    ASSERT_NE_MSG(nullptr, imageSource, "FAILED: ImageIOTest::CGImageSourceCreateWithData returned nullptr");
    size_t frameCount = CGImageSourceGetCount(imageSource);
    ASSERT_EQ_MSG(frameCount, 3, "FAILED: ImageIOTest::FrameCount");

    CGImageRef imageRefOut = CGImageSourceCreateImageAtIndex(imageSource, 0, NULL);
    ASSERT_NE_MSG(nullptr, imageRefOut, "FAILED: ImageIOTest::CGImageSourceCreateImageAtIndex returned nullptr");
    EXPECT_EQ(kCGImageAlphaFirst, CGImageGetAlphaInfo(imageRefOut));
    EXPECT_EQ(kCGImageAlphaFirst | kCGBitmapByteOrder32Little, CGImageGetBitmapInfo(imageRefOut));
    EXPECT_EQ(8, CGImageGetBitsPerComponent(imageRefOut));
    EXPECT_EQ(32, CGImageGetBitsPerPixel(imageRefOut));
    EXPECT_EQ(3, CGColorSpaceGetNumberOfComponents(CGImageGetColorSpace(imageRefOut)));
    EXPECT_EQ(1024, CGImageGetHeight(imageRefOut));
    EXPECT_EQ(683, CGImageGetWidth(imageRefOut));

    imageRefOut = CGImageSourceCreateImageAtIndex(imageSource, 1, NULL);
    ASSERT_NE_MSG(nullptr, imageRefOut, "FAILED: ImageIOTest::CGImageSourceCreateImageAtIndex returned nullptr");
    EXPECT_EQ(kCGImageAlphaFirst, CGImageGetAlphaInfo(imageRefOut));
    EXPECT_EQ(kCGImageAlphaFirst | kCGBitmapByteOrder32Little, CGImageGetBitmapInfo(imageRefOut));
    EXPECT_EQ(8, CGImageGetBitsPerComponent(imageRefOut));
    EXPECT_EQ(32, CGImageGetBitsPerPixel(imageRefOut));
    EXPECT_EQ(3, CGColorSpaceGetNumberOfComponents(CGImageGetColorSpace(imageRefOut)));
    EXPECT_EQ(683, CGImageGetHeight(imageRefOut));
    EXPECT_EQ(1024, CGImageGetWidth(imageRefOut));

    imageRefOut = CGImageSourceCreateImageAtIndex(imageSource, 2, NULL);
    ASSERT_NE_MSG(nullptr, imageRefOut, "FAILED: ImageIOTest::CGImageSourceCreateImageAtIndex returned nullptr");
    EXPECT_EQ(kCGImageAlphaFirst, CGImageGetAlphaInfo(imageRefOut));
    EXPECT_EQ(kCGImageAlphaFirst | kCGBitmapByteOrder32Little, CGImageGetBitmapInfo(imageRefOut));
    EXPECT_EQ(8, CGImageGetBitsPerComponent(imageRefOut));
    EXPECT_EQ(32, CGImageGetBitsPerPixel(imageRefOut));
    EXPECT_EQ(3, CGColorSpaceGetNumberOfComponents(CGImageGetColorSpace(imageRefOut)));
    EXPECT_EQ(683, CGImageGetHeight(imageRefOut));
    EXPECT_EQ(1024, CGImageGetWidth(imageRefOut));

    CFRelease(imageSource);
}

TEST(ImageIO, DestinationOptionsTest) {
    const wchar_t* imageFile = L"photo6_1024x670.jpg";
    NSData* imageData = getDataFromImageFile(imageFile);
    CGImageSourceRef imageSource = CGImageSourceCreateWithData((CFDataRef)imageData, NULL);
    CGImageRef imageRef = CGImageSourceCreateImageAtIndex(imageSource, 0, NULL);
    CFRelease(imageSource);

    const wchar_t* outFile = L"outphotoLQ.jpg";
    CFURLRef imgUrl = getURLRefForOutFile(outFile);

    // Note that to verify quality is much lower with quality = 0.1, you have to open the image file.
    // There is no option for image quality stored with the file as that would not make sense.
    float quality = 0.1;
    NSNumber* encodeQuality = [NSNumber numberWithFloat:quality];
    NSDictionary* encodeOptions = @{ @"kCGImageDestinationLossyCompressionQuality" : encodeQuality };

    CGImageDestinationRef myImageDest = CGImageDestinationCreateWithURL(imgUrl, kUTTypeJPEG, 1, NULL);
    CGImageDestinationAddImage(myImageDest, imageRef, (CFDictionaryRef)encodeOptions);
    CGImageDestinationFinalize(myImageDest);
    CFRelease(myImageDest);

    // Read back in the newly written image to check properties
    imageData = getDataFromImageFile(imgUrl);
    ASSERT_NE_MSG(nullptr, imageData, "FAILED: ImageIOTest::Could not find file: [%s]", outFile);
    imageSource = CGImageSourceCreateWithData((CFDataRef)imageData, NULL);
    ASSERT_NE_MSG(nullptr, imageSource, "FAILED: ImageIOTest::CGImageSourceCreateWithData returned nullptr");
    CGImageRef imageRefOut = CGImageSourceCreateImageAtIndex(imageSource, 0, NULL);
    ASSERT_NE_MSG(nullptr, imageRefOut, "FAILED: ImageIOTest::CGImageSourceCreateImageAtIndex returned nullptr");
    EXPECT_EQ(kCGImageAlphaNone, CGImageGetAlphaInfo(imageRefOut));
    EXPECT_EQ(kCGImageAlphaNone, CGImageGetBitmapInfo(imageRefOut));
    EXPECT_EQ(8, CGImageGetBitsPerComponent(imageRefOut));
    EXPECT_EQ(24, CGImageGetBitsPerPixel(imageRefOut));
    EXPECT_EQ(3, CGColorSpaceGetNumberOfComponents(CGImageGetColorSpace(imageRefOut)));
    EXPECT_EQ(670, CGImageGetHeight(imageRefOut));
    EXPECT_EQ(1024, CGImageGetWidth(imageRefOut));
    size_t frameCount = CGImageSourceGetCount(imageSource);
    EXPECT_EQ(1, frameCount);
    CFRelease(imageSource);

    imageFile = L"photo2_683x1024.ico";
    imageData = getDataFromImageFile(imageFile);
    imageSource = CGImageSourceCreateWithData((CFDataRef)imageData, NULL);
    imageRef = CGImageSourceCreateImageAtIndex(imageSource, 0, NULL);

    const wchar_t* imageFile2 = L"photo8_4layers_1024x683.tif";
    NSData* imageData2 = getDataFromImageFile(imageFile2);
    CGImageSourceRef imageSource2 = CGImageSourceCreateWithData((CFDataRef)imageData2, NULL);
    CGImageRef imageRef2 = CGImageSourceCreateImageAtIndex(imageSource2, 0, NULL);

    const wchar_t* outFile2 = L"outphoto_loopcount.gif";
    imgUrl = getURLRefForOutFile(outFile2);

    int loopCount = 15;
    float delayTime = 0.5;
    NSDictionary* gifEncodeOptions = @{
        (id)kCGImagePropertyGIFLoopCount : [NSNumber numberWithInt:loopCount],
        (id)kCGImagePropertyGIFDelayTime : [NSNumber numberWithFloat:delayTime],
    };

    NSDictionary* encodeDictionary = @{
        (id)kCGImagePropertyGIFDictionary : gifEncodeOptions,
    };

    myImageDest = CGImageDestinationCreateWithURL(imgUrl, kUTTypeGIF, 3, NULL);
    CGImageDestinationSetProperties(myImageDest, (CFDictionaryRef)encodeDictionary);
    CGImageDestinationAddImage(myImageDest, imageRef, (CFDictionaryRef)encodeDictionary);
    CGImageDestinationAddImageFromSource(myImageDest, imageSource2, 0, (CFDictionaryRef)encodeDictionary);
    CGImageDestinationAddImageFromSource(myImageDest, imageSource2, 2, (CFDictionaryRef)encodeDictionary);
    CGImageDestinationFinalize(myImageDest);
    CFRelease(imageSource);
    CFRelease(imageSource2);
    CFRelease(myImageDest);

    // Read back in the newly written image to check properties
    imageData = getDataFromImageFile(imgUrl);
    ASSERT_NE_MSG(nullptr, imageData, "FAILED: ImageIOTest::Could not find file: [%s]", outFile2);
    imageSource = CGImageSourceCreateWithData((CFDataRef)imageData, NULL);
    ASSERT_NE_MSG(nullptr, imageSource, "FAILED: ImageIOTest::CGImageSourceCreateWithData returned nullptr");
    frameCount = CGImageSourceGetCount(imageSource);
    ASSERT_EQ_MSG(frameCount, 3, "FAILED: ImageIOTest::FrameCount");

    CFDictionaryRef imageProperties = CGImageSourceCopyProperties(imageSource, NULL);
    ASSERT_NE_MSG(nullptr, imageProperties, "FAILED: ImageIOTest::CGImageSourceCopyProperties returned nullptr");

    ASSERT_TRUE_MSG(CFDictionaryContainsKey(imageProperties, kCGImagePropertyGIFDictionary),
                    "FAILED: ImageIOTest::GIF dictionary not found");
    CFDictionaryRef gifDictionary = (CFDictionaryRef)CFDictionaryGetValue(imageProperties, kCGImagePropertyGIFDictionary);
    ASSERT_TRUE_MSG(CFDictionaryContainsKey(gifDictionary, kCGImagePropertyGIFLoopCount),
                    "FAILED: ImageIOTest::GIF dictionary does not contain Loop Count");
    int actualLoopCount = [(id)CFDictionaryGetValue(gifDictionary, kCGImagePropertyGIFLoopCount) intValue];
    EXPECT_EQ(loopCount, actualLoopCount);

    imageRefOut = CGImageSourceCreateImageAtIndex(imageSource, 0, NULL);
    ASSERT_NE_MSG(nullptr, imageRefOut, "FAILED: ImageIOTest::CGImageSourceCreateImageAtIndex returned nullptr");
    EXPECT_EQ(kCGImageAlphaNone, CGImageGetAlphaInfo(imageRefOut));
    EXPECT_EQ(kCGImageAlphaNone, CGImageGetBitmapInfo(imageRefOut));
    EXPECT_EQ(8, CGImageGetBitsPerComponent(imageRefOut));
    EXPECT_EQ(8, CGImageGetBitsPerPixel(imageRefOut));
    // TODO: Check Paletted/Indexed color space.
    EXPECT_EQ(1024, CGImageGetHeight(imageRefOut));
    EXPECT_EQ(683, CGImageGetWidth(imageRefOut));

    imageRefOut = CGImageSourceCreateImageAtIndex(imageSource, 1, NULL);
    ASSERT_NE_MSG(nullptr, imageRefOut, "FAILED: ImageIOTest::CGImageSourceCreateImageAtIndex returned nullptr");
    EXPECT_EQ(kCGImageAlphaNone, CGImageGetAlphaInfo(imageRefOut));
    EXPECT_EQ(kCGImageAlphaNone, CGImageGetBitmapInfo(imageRefOut));
    EXPECT_EQ(8, CGImageGetBitsPerComponent(imageRefOut));
    EXPECT_EQ(8, CGImageGetBitsPerPixel(imageRefOut));
    // TODO: Check Paletted/Indexed color space.
    EXPECT_EQ(683, CGImageGetHeight(imageRefOut));
    EXPECT_EQ(1024, CGImageGetWidth(imageRefOut));

    imageRefOut = CGImageSourceCreateImageAtIndex(imageSource, 2, NULL);
    ASSERT_NE_MSG(nullptr, imageRefOut, "FAILED: ImageIOTest::CGImageSourceCreateImageAtIndex returned nullptr");
    EXPECT_EQ(kCGImageAlphaNone, CGImageGetAlphaInfo(imageRefOut));
    EXPECT_EQ(kCGImageAlphaNone, CGImageGetBitmapInfo(imageRefOut));
    EXPECT_EQ(8, CGImageGetBitsPerComponent(imageRefOut));
    EXPECT_EQ(8, CGImageGetBitsPerPixel(imageRefOut));
    // TODO: Check Paletted/Indexed color space.
    EXPECT_EQ(683, CGImageGetHeight(imageRefOut));
    EXPECT_EQ(1024, CGImageGetWidth(imageRefOut));

    CFRelease(imageSource);
}

TEST(ImageIO, DestinationImageOptionsTIFFTest) {
    const wchar_t* imageFile = L"photo2_683x1024.ico";
    NSData* imageData = getDataFromImageFile(imageFile);
    CGImageSourceRef imageSource = CGImageSourceCreateWithData((CFDataRef)imageData, NULL);
    CGImageRef imageRef = CGImageSourceCreateImageAtIndex(imageSource, 0, NULL);
    CFRelease(imageSource);

    const wchar_t* outFile = L"outphoto_options.tif";
    CFURLRef imgUrl = getURLRefForOutFile(outFile);

    NSDictionary* gpsOptions = @{
        (id)kCGImagePropertyGPSLatitude : [NSNumber numberWithDouble:100.55],
        (id)kCGImagePropertyGPSLongitude : [NSNumber numberWithDouble:200.0],
        (id)kCGImagePropertyGPSLatitudeRef : @"N",
        (id)kCGImagePropertyGPSLongitudeRef : @"W",
        (id)kCGImagePropertyGPSAltitude : [NSNumber numberWithDouble:150.25],
        (id)kCGImagePropertyGPSAltitudeRef : [NSNumber numberWithShort:1],
        (id)kCGImagePropertyGPSImgDirection : [NSNumber numberWithFloat:2.4],
        (id)kCGImagePropertyGPSImgDirectionRef : @"test",
        (id)kCGImagePropertyGPSTimeStamp : @"04:30:51.71",
        (id)kCGImagePropertyGPSVersion : @"2.2.0.0",
    };

    NSDictionary* exifOptions = @{
        (id)kCGImagePropertyExifUserComment : @"Test2",
        (id)kCGImagePropertyExifExposureTime : [NSNumber numberWithDouble:12.34],
    };

    NSDictionary* tiffOptions = @{
        (id)kCGImagePropertyTIFFXResolution : [NSNumber numberWithDouble:100],
        (id)kCGImagePropertyTIFFYResolution : [NSNumber numberWithDouble:120],
        (id)kCGImagePropertyTIFFResolutionUnit : [NSNumber numberWithInt:1],
    };

    int orientation = 3;
    NSNumber* encodeOrientation = [NSNumber numberWithInt:orientation];

    NSDictionary* encodeOptions = @{
        (id)kCGImagePropertyGPSDictionary : gpsOptions,
        (id)kCGImagePropertyOrientation : encodeOrientation,
        (id)kCGImagePropertyExifDictionary : exifOptions,
        (id)kCGImagePropertyTIFFDictionary : tiffOptions,
        (id)kCGImagePropertyDPIWidth : [NSNumber numberWithDouble:1000],
        (id)kCGImagePropertyDPIHeight : [NSNumber numberWithDouble:200],
    };

    CGImageDestinationRef myImageDest = CGImageDestinationCreateWithURL(imgUrl, kUTTypeTIFF, 1, NULL);
    CGImageDestinationAddImage(myImageDest, imageRef, (CFDictionaryRef)encodeOptions);
    CGImageDestinationFinalize(myImageDest);
    CFRelease(myImageDest);

    imageData = getDataFromImageFile(imgUrl);
    ASSERT_NE_MSG(nullptr, imageData, "FAILED: ImageIOTest::Could not find file: [%s]", outFile);
    imageSource = CGImageSourceCreateWithData((CFDataRef)imageData, NULL);
    ASSERT_NE_MSG(nullptr, imageSource, "FAILED: ImageIOTest::CGImageSourceCreateWithData returned nullptr");
    CFDictionaryRef imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, NULL);
    ASSERT_NE_MSG(nullptr, imageProperties, "FAILED: ImageIOTest::CGImageSourceCopyPropertiesAtIndex returned nullptr");

    // Note that this XResolution was actually passed in as 100. This field aliases with DPIWidth.
    // As observed on iOS, for TIFF, DPIWidth takes precedence, while for JPEG, XResolution takes precedence.
    ASSERT_TRUE_MSG(CFDictionaryContainsKey(imageProperties, kCGImagePropertyTIFFDictionary),
                    "FAILED: ImageIOTest::TIFF dictionary not found");
    CFDictionaryRef tiffDictionary = (CFDictionaryRef)CFDictionaryGetValue(imageProperties, kCGImagePropertyTIFFDictionary);
    ASSERT_TRUE_MSG(CFDictionaryContainsKey(tiffDictionary, kCGImagePropertyTIFFXResolution),
                    "FAILED: ImageIOTest::TIFF dictionary does not contain XResolution");
    double actualXDensity = [(id)CFDictionaryGetValue(tiffDictionary, kCGImagePropertyTIFFXResolution) doubleValue];
    ASSERT_NEAR_MSG(actualXDensity, 1000.0, 0.01, "FAILED: ImageIOTest::XResolution mismatch");

    ASSERT_TRUE_MSG(CFDictionaryContainsKey(imageProperties, kCGImagePropertyExifDictionary),
                    "FAILED: ImageIOTest::Exif dictionary not found");
    CFDictionaryRef exifDictionary = (CFDictionaryRef)CFDictionaryGetValue(imageProperties, kCGImagePropertyExifDictionary);
    ASSERT_TRUE_MSG(CFDictionaryContainsKey(exifDictionary, kCGImagePropertyExifExposureTime),
                    "FAILED: ImageIOTest::Exif dictionary does not contain Exposure Time");
    double actualAltitude = [(id)CFDictionaryGetValue(exifDictionary, kCGImagePropertyExifExposureTime) doubleValue];
    ASSERT_NEAR_MSG(actualAltitude, 12.34, 0.01, "FAILED: ImageIOTest::Exposure Time mismatch");

    ASSERT_TRUE_MSG(CFDictionaryContainsKey(imageProperties, kCGImagePropertyPixelHeight), "FAILED: ImageIOTest::Pixel Height not found");
    int actualPixelHeight = [(id)CFDictionaryGetValue(imageProperties, kCGImagePropertyPixelHeight) intValue];
    EXPECT_EQ(1024, actualPixelHeight);

    ASSERT_TRUE_MSG(CFDictionaryContainsKey(imageProperties, kCGImagePropertyOrientation), "FAILED: ImageIOTest::Orientation not found");
    int actualOrientation = [(id)CFDictionaryGetValue(imageProperties, kCGImagePropertyOrientation) intValue];
    EXPECT_EQ(3, actualOrientation);

    CFRelease(imageSource);
}

TEST(ImageIO, DestinationImageOptionsJPEGTest) {
    const wchar_t* imageFile = L"photo2_683x1024.ico";
    NSData* imageData = getDataFromImageFile(imageFile);
    CGImageSourceRef imageSource = CGImageSourceCreateWithData((CFDataRef)imageData, NULL);
    CGImageRef imageRef = CGImageSourceCreateImageAtIndex(imageSource, 0, NULL);
    CFRelease(imageSource);

    const wchar_t* outFile = L"outphoto_options.jpg";
    CFURLRef imgUrl = getURLRefForOutFile(outFile);

    NSDictionary* gpsOptions = @{
        (id)kCGImagePropertyGPSLatitude : [NSNumber numberWithDouble:100.55],
        (id)kCGImagePropertyGPSLongitude : [NSNumber numberWithDouble:200.0],
        (id)kCGImagePropertyGPSLatitudeRef : @"N",
        (id)kCGImagePropertyGPSLongitudeRef : @"W",
        (id)kCGImagePropertyGPSAltitude : [NSNumber numberWithDouble:150.25],
        (id)kCGImagePropertyGPSAltitudeRef : [NSNumber numberWithShort:1],
        (id)kCGImagePropertyGPSImgDirection : [NSNumber numberWithFloat:2.4],
        (id)kCGImagePropertyGPSImgDirectionRef : @"test",
        (id)kCGImagePropertyGPSTimeStamp : @"04:30:51.71",
        (id)kCGImagePropertyGPSVersion : @"2.2.0.0",
    };

    NSDictionary* exifOptions = @{
        (id)kCGImagePropertyExifUserComment : @"Test2",
        (id)kCGImagePropertyExifExposureTime : [NSNumber numberWithDouble:12.34],
    };

    NSDictionary* tiffOptions = @{
        (id)kCGImagePropertyTIFFXResolution : [NSNumber numberWithDouble:100],
        (id)kCGImagePropertyTIFFYResolution : [NSNumber numberWithDouble:120],
        (id)kCGImagePropertyTIFFResolutionUnit : [NSNumber numberWithInt:1],
    };

    int orientation = 2;
    NSNumber* encodeOrientation = [NSNumber numberWithInt:orientation];

    NSDictionary* encodeOptions = @{
        (id)kCGImagePropertyGPSDictionary : gpsOptions,
        (id)kCGImagePropertyOrientation : encodeOrientation,
        (id)kCGImagePropertyExifDictionary : exifOptions,
        (id)kCGImagePropertyTIFFDictionary : tiffOptions,
        (id)kCGImagePropertyDPIWidth : [NSNumber numberWithDouble:1000],
        (id)kCGImagePropertyDPIHeight : [NSNumber numberWithDouble:200],
    };

    CGImageDestinationRef myImageDest = CGImageDestinationCreateWithURL(imgUrl, kUTTypeJPEG, 1, NULL);
    CGImageDestinationAddImage(myImageDest, imageRef, (CFDictionaryRef)encodeOptions);
    CGImageDestinationFinalize(myImageDest);
    CFRelease(myImageDest);

    imageData = getDataFromImageFile(imgUrl);
    ASSERT_NE_MSG(nullptr, imageData, "FAILED: ImageIOTest::Could not find file: [%s]", outFile);
    imageSource = CGImageSourceCreateWithData((CFDataRef)imageData, NULL);
    ASSERT_NE_MSG(nullptr, imageSource, "FAILED: ImageIOTest::CGImageSourceCreateWithData returned nullptr");
    CFDictionaryRef imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, NULL);
    ASSERT_NE_MSG(nullptr, imageProperties, "FAILED: ImageIOTest::CGImageSourceCopyPropertiesAtIndex returned nullptr");

    ASSERT_TRUE_MSG(CFDictionaryContainsKey(imageProperties, kCGImagePropertyJFIFDictionary),
                    "FAILED: ImageIOTest::JFIF dictionary not found");
    CFDictionaryRef jfifDictionary = (CFDictionaryRef)CFDictionaryGetValue(imageProperties, kCGImagePropertyJFIFDictionary);
    ASSERT_TRUE_MSG(CFDictionaryContainsKey(jfifDictionary, kCGImagePropertyJFIFXDensity),
                    "FAILED: ImageIOTest::JFIF dictionary does not contain XDensity");
    double actualXDensity = [(id)CFDictionaryGetValue(jfifDictionary, kCGImagePropertyJFIFXDensity) doubleValue];
    ASSERT_NEAR_MSG(actualXDensity, 96.0, 0.01, "FAILED: ImageIOTest::XDensity mismatch"); // By default, set to 96.0 (Windows Direct2D/WIC DPI)

    ASSERT_TRUE_MSG(CFDictionaryContainsKey(imageProperties, kCGImagePropertyGPSDictionary),
                    "FAILED: ImageIOTest::GPS dictionary not found");
    CFDictionaryRef gpsDictionary = (CFDictionaryRef)CFDictionaryGetValue(imageProperties, kCGImagePropertyGPSDictionary);
    ASSERT_TRUE_MSG(CFDictionaryContainsKey(gpsDictionary, kCGImagePropertyGPSAltitude),
                    "FAILED: ImageIOTest::GPS dictionary does not contain Altitude");
    double actualAltitude = [(id)CFDictionaryGetValue(gpsDictionary, kCGImagePropertyGPSAltitude) doubleValue];
    ASSERT_NEAR_MSG(actualAltitude, 150.25, 0.01, "FAILED: ImageIOTest::Altitude mismatch");

    ASSERT_TRUE_MSG(CFDictionaryContainsKey(imageProperties, kCGImagePropertyPixelHeight), "FAILED: ImageIOTest::Pixel Height not found");
    int actualPixelHeight = [(id)CFDictionaryGetValue(imageProperties, kCGImagePropertyPixelHeight) intValue];
    EXPECT_EQ(1024, actualPixelHeight);

    ASSERT_TRUE_MSG(CFDictionaryContainsKey(imageProperties, kCGImagePropertyOrientation), "FAILED: ImageIOTest::Orientation not found");
    int actualOrientation = [(id)CFDictionaryGetValue(imageProperties, kCGImagePropertyOrientation) intValue];
    EXPECT_EQ(2, actualOrientation);

    CFRelease(imageSource);
}

TEST(ImageIO, DestinationImageOptionsGIFTest) {
    const wchar_t* imageFile = L"photo2_683x1024.ico";
    NSData* imageData = getDataFromImageFile(imageFile);
    CGImageSourceRef imageSource = CGImageSourceCreateWithData((CFDataRef)imageData, NULL);
    CGImageRef imageRef = CGImageSourceCreateImageAtIndex(imageSource, 0, NULL);
    CFRelease(imageSource);

    const wchar_t* outFile = L"outphoto_options.gif";

    CFURLRef imgUrl = getURLRefForOutFile(outFile);

    NSDictionary* gifOptions = @{
        (id)kCGImagePropertyGIFDelayTime : [NSNumber numberWithFloat:0.05],
    };

    int orientation = 2;
    NSNumber* encodeOrientation = [NSNumber numberWithInt:orientation];

    NSDictionary* encodeOptions = @{
        (id)kCGImagePropertyOrientation : encodeOrientation,
        (id)kCGImagePropertyGIFDictionary : gifOptions,
        (id)kCGImagePropertyDPIWidth : [NSNumber numberWithDouble:1000],
        (id)kCGImagePropertyDPIHeight : [NSNumber numberWithDouble:200],
    };

    CGImageDestinationRef myImageDest = CGImageDestinationCreateWithURL(imgUrl, kUTTypeGIF, 1, NULL);
    CGImageDestinationAddImage(myImageDest, imageRef, (CFDictionaryRef)encodeOptions);
    CGImageDestinationFinalize(myImageDest);
    CFRelease(myImageDest);

    imageData = getDataFromImageFile(imgUrl);
    ASSERT_NE_MSG(nullptr, imageData, "FAILED: ImageIOTest::Could not find file: [%s]", outFile);
    imageSource = CGImageSourceCreateWithData((CFDataRef)imageData, NULL);
    ASSERT_NE_MSG(nullptr, imageSource, "FAILED: ImageIOTest::CGImageSourceCreateWithData returned nullptr");
    CFDictionaryRef imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, NULL);
    ASSERT_NE_MSG(nullptr, imageProperties, "FAILED: ImageIOTest::CGImageSourceCopyPropertiesAtIndex returned nullptr");

    ASSERT_TRUE_MSG(CFDictionaryContainsKey(imageProperties, kCGImagePropertyGIFDictionary),
                    "FAILED: ImageIOTest::GIF dictionary not found");
    CFDictionaryRef gifDictionary = (CFDictionaryRef)CFDictionaryGetValue(imageProperties, kCGImagePropertyGIFDictionary);
    ASSERT_TRUE_MSG(CFDictionaryContainsKey(gifDictionary, kCGImagePropertyGIFUnclampedDelayTime),
                    "FAILED: ImageIOTest::GIF dictionary does not contain Unclamped Delay Time");
    double actualUnclampedDelayTime = [(id)CFDictionaryGetValue(gifDictionary, kCGImagePropertyGIFUnclampedDelayTime) doubleValue];
    ASSERT_NEAR_MSG(actualUnclampedDelayTime, 0.05, 0.01, "FAILED: ImageIOTest::Unclamped Delay Time mismatch");
    ASSERT_TRUE_MSG(CFDictionaryContainsKey(gifDictionary, kCGImagePropertyGIFDelayTime),
                    "FAILED: ImageIOTest::GIF dictionary does not contain Delay Time");
    double actualDelayTime = [(id)CFDictionaryGetValue(gifDictionary, kCGImagePropertyGIFDelayTime) doubleValue];
    ASSERT_NEAR_MSG(actualDelayTime, 0.1, 0.01, "FAILED: ImageIOTest::Delay Time mismatch");

    ASSERT_TRUE_MSG(CFDictionaryContainsKey(imageProperties, kCGImagePropertyPixelHeight), "FAILED: ImageIOTest::Pixel Height not found");
    int actualPixelHeight = [(id)CFDictionaryGetValue(imageProperties, kCGImagePropertyPixelHeight) intValue];
    EXPECT_EQ(1024, actualPixelHeight);

    CFRelease(imageSource);
}

TEST(ImageIO, DestinationImageOptionsPNGTest) {
    const wchar_t* imageFile = L"photo2_683x1024.ico";
    NSData* imageData = getDataFromImageFile(imageFile);
    CGImageSourceRef imageSource = CGImageSourceCreateWithData((CFDataRef)imageData, NULL);
    CGImageRef imageRef = CGImageSourceCreateImageAtIndex(imageSource, 0, NULL);
    CFRelease(imageSource);

    const wchar_t* outFile = L"outphoto_options.png";

    CFURLRef imgUrl = getURLRefForOutFile(outFile);

    NSDictionary* pngOtions = @{
        (id)kCGImagePropertyPNGGamma : [NSNumber numberWithInt:45045],
    };

    int orientation = 2;
    NSNumber* encodeOrientation = [NSNumber numberWithInt:orientation];

    NSDictionary* encodeOptions = @{
        (id)kCGImagePropertyOrientation : encodeOrientation,
        (id)kCGImagePropertyPNGDictionary : pngOtions,
        (id)kCGImagePropertyDPIWidth : [NSNumber numberWithDouble:1000],
        (id)kCGImagePropertyDPIHeight : [NSNumber numberWithDouble:200],
    };

    CGImageDestinationRef myImageDest = CGImageDestinationCreateWithURL(imgUrl, kUTTypePNG, 1, NULL);
    CGImageDestinationAddImage(myImageDest, imageRef, (CFDictionaryRef)encodeOptions);
    CGImageDestinationFinalize(myImageDest);
    CFRelease(myImageDest);

    imageData = getDataFromImageFile(imgUrl);
    ASSERT_NE_MSG(nullptr, imageData, "FAILED: ImageIOTest::Could not find file: [%s]", outFile);
    imageSource = CGImageSourceCreateWithData((CFDataRef)imageData, NULL);
    ASSERT_NE_MSG(nullptr, imageSource, "FAILED: ImageIOTest::CGImageSourceCreateWithData returned nullptr");
    CFDictionaryRef imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, NULL);
    ASSERT_NE_MSG(nullptr, imageProperties, "FAILED: ImageIOTest::CGImageSourceCopyPropertiesAtIndex returned nullptr");

    ASSERT_TRUE_MSG(CFDictionaryContainsKey(imageProperties, kCGImagePropertyPNGDictionary),
                    "FAILED: ImageIOTest::PNG dictionary not found");
    CFDictionaryRef pngDictionary = (CFDictionaryRef)CFDictionaryGetValue(imageProperties, kCGImagePropertyPNGDictionary);
    ASSERT_TRUE_MSG(CFDictionaryContainsKey(pngDictionary, kCGImagePropertyPNGGamma),
                    "FAILED: ImageIOTest::PNG dictionary does not contain Gamma");
    int actualGamma = [(id)CFDictionaryGetValue(pngDictionary, kCGImagePropertyPNGGamma) intValue];
    EXPECT_EQ(45045, actualGamma);

    CFRelease(imageSource);
}

TEST(ImageIO, TypeIDTest) {
    ASSERT_EQ_MSG(CGImageSourceGetTypeID(), 286, "FAILED: ImageIOTest::SourceTypeID");
}

// Test for JPEG incremental source creation, data updation, frame extraction, container status, frame status and stream lengths
TEST(ImageIO, IncrementalJPEGImageWithFrameCheck) {
    const wchar_t* imageFile = L"photo6_1024x670.jpg";
    NSData* imageData = getDataFromImageFile(imageFile);
    ASSERT_NE_MSG(nullptr, imageData, "FAILED: ImageIOTest::Could not find file: [%s]", imageFile);
    NSUInteger imageLength = [imageData length];

    // Minimum Stream Length at which CGImageSourceCreateImageAtIndex returns valid image references
    static const int c_streamLengthForImage = 3851;

    // Container status change sequence and corresponding stream lengths
    static const std::vector<int> c_containerStatus = { kCGImageStatusInvalidData,
                                                        kCGImageStatusInvalidData,
                                                        kCGImageStatusIncomplete,
                                                        kCGImageStatusIncomplete,
                                                        kCGImageStatusComplete };
    static const std::vector<int> c_streamLengthForContainer = { 1, 95, 96, 218939, 218940 };

    // Frame status change sequence and corresponding stream lengths
    static const std::vector<int> c_frameStatus = { kCGImageStatusReadingHeader, kCGImageStatusReadingHeader, kCGImageStatusUnknownType,
                                                    kCGImageStatusUnknownType,   kCGImageStatusIncomplete,    kCGImageStatusIncomplete,
                                                    kCGImageStatusComplete };
    static const std::vector<int> c_streamLengthForFrame = { 1, 95, 96, 3850, 3851, 218939, 218940 };

    CGImageSourceRef imageRef = CGImageSourceCreateIncremental(nullptr);
    ASSERT_NE_MSG(nullptr, imageRef, "FAILED: CGImageSourceCreateIncremental returned nullptr");

    // Check container status change sequence at corresponding stream lengths
    for (int index = 0; index < c_streamLengthForContainer.size(); index++) {
        NSData* currentImageChunk =
            [NSData dataWithBytesNoCopy:(char*)[imageData bytes] length:c_streamLengthForContainer[index] freeWhenDone:NO];

        CGImageSourceUpdateData(imageRef, (CFDataRef)currentImageChunk, imageLength == c_streamLengthForContainer[index]);
        ASSERT_EQ_MSG(CGImageSourceGetStatus(imageRef), c_containerStatus[index], "FAILED: ImageIOTest::ContainerStatus");
    }

    // Check frame status change sequence at corresponding stream lengths
    bool imageStart = false;
    for (int index = 0; index < c_streamLengthForFrame.size(); index++) {
        NSData* currentImageChunk =
            [NSData dataWithBytesNoCopy:(char*)[imageData bytes] length:c_streamLengthForFrame[index] freeWhenDone:NO];

        CGImageSourceUpdateData(imageRef, (CFDataRef)currentImageChunk, imageLength == c_streamLengthForFrame[index]);
        CGImageRef incrementalImage = CGImageSourceCreateImageAtIndex(imageRef, 0, nullptr);

        // Check minimum stream length for valid image references
        if (incrementalImage && !imageStart) {
            ASSERT_EQ_MSG(c_streamLengthForImage, c_streamLengthForFrame[index], "FAILED: ImageIOTest::ValidImageLength");
            imageStart = true;
        }

        ASSERT_EQ_MSG(CGImageSourceGetStatusAtIndex(imageRef, 0), c_frameStatus[index], "FAILED: ImageIOTest::ImageStatusAtIndex");
    }

    CFRelease(imageRef);
}

// Test for BMP incremental source creation, data updation, frame extraction, container status, frame status and stream lengths
TEST(ImageIO, IncrementalBMPImageWithFrameCheck) {
    const wchar_t* imageFile = L"testimg_227x149.bmp";
    NSData* imageData = getDataFromImageFile(imageFile);
    ASSERT_NE_MSG(nullptr, imageData, "FAILED: ImageIOTest::Could not find file: [%s]", imageFile);
    NSUInteger imageLength = [imageData length];

    // Minimum Stream Length at which CGImageSourceCreateImageAtIndex returns valid image references
    static const int c_streamLengthForImage = 35050;

    // Container status change sequence and corresponding stream lengths
    static const std::vector<int> c_containerStatus = { kCGImageStatusInvalidData,
                                                        kCGImageStatusInvalidData,
                                                        kCGImageStatusIncomplete,
                                                        kCGImageStatusIncomplete,
                                                        kCGImageStatusComplete };
    static const std::vector<int> c_streamLengthForContainer = { 1, 95, 96, 35049, 35050 };

    // Frame status change sequence and corresponding stream lengths
    static const std::vector<int> c_frameStatus = { kCGImageStatusReadingHeader,
                                                    kCGImageStatusReadingHeader,
                                                    kCGImageStatusUnknownType,
                                                    kCGImageStatusUnknownType,
                                                    kCGImageStatusComplete };
    static const std::vector<int> c_streamLengthForFrame = { 1, 95, 96, 35049, 35050 };

    CGImageSourceRef imageRef = CGImageSourceCreateIncremental(nullptr);
    ASSERT_NE_MSG(nullptr, imageRef, "FAILED: CGImageSourceCreateIncremental returned nullptr");

    // Check container status change sequence at corresponding stream lengths
    for (int index = 0; index < c_streamLengthForContainer.size(); index++) {
        NSData* currentImageChunk =
            [NSData dataWithBytesNoCopy:(char*)[imageData bytes] length:c_streamLengthForContainer[index] freeWhenDone:NO];

        CGImageSourceUpdateData(imageRef, (CFDataRef)currentImageChunk, imageLength == c_streamLengthForContainer[index]);
        ASSERT_EQ_MSG(CGImageSourceGetStatus(imageRef), c_containerStatus[index], "FAILED: ImageIOTest::ContainerStatus");
    }

    // Check frame status change sequence at corresponding stream lengths
    bool imageStart = false;
    for (int index = 0; index < c_streamLengthForFrame.size(); index++) {
        NSData* currentImageChunk =
            [NSData dataWithBytesNoCopy:(char*)[imageData bytes] length:c_streamLengthForFrame[index] freeWhenDone:NO];

        CGImageSourceUpdateData(imageRef, (CFDataRef)currentImageChunk, imageLength == c_streamLengthForFrame[index]);
        CGImageRef incrementalImage = CGImageSourceCreateImageAtIndex(imageRef, 0, nullptr);

        // Check minimum stream length for valid image references
        if (incrementalImage && !imageStart) {
            ASSERT_EQ_MSG(c_streamLengthForImage, c_streamLengthForFrame[index], "FAILED: ImageIOTest::ValidImageLength");
            imageStart = true;
        }

        ASSERT_EQ_MSG(CGImageSourceGetStatusAtIndex(imageRef, 0), c_frameStatus[index], "FAILED: ImageIOTest::ImageStatusAtIndex");
    }

    CFRelease(imageRef);
}

// Test for PNG incremental source creation, data updation, frame extraction, container status, frame status and stream lengths
TEST(ImageIO, IncrementalPNGImageWithFrameCheck) {
    const wchar_t* imageFile = L"seafloor_256x256.png";
    NSData* imageData = getDataFromImageFile(imageFile);
    ASSERT_NE_MSG(nullptr, imageData, "FAILED: ImageIOTest::Could not find file: [%s]", imageFile);
    NSUInteger imageLength = [imageData length];

    // Minimum Stream Length at which CGImageSourceCreateImageAtIndex returns valid image references - 907 for Apple's implementation
    // During incremental loading of PNG images, decoder creation succeeds only when all image data is available
    static const int c_streamLengthForImage = 59505;

    // Container status change sequence and corresponding stream lengths
    static const std::vector<int> c_containerStatus = { kCGImageStatusInvalidData,
                                                        kCGImageStatusInvalidData,
                                                        kCGImageStatusIncomplete,
                                                        kCGImageStatusIncomplete,
                                                        kCGImageStatusComplete };
    static const std::vector<int> c_streamLengthForContainer = { 1, 95, 96, 59505, 59506 };

    // Frame status change sequence and corresponding stream lengths
    static const std::vector<int> c_frameStatus = { kCGImageStatusReadingHeader, kCGImageStatusReadingHeader, kCGImageStatusUnknownType,
                                                    kCGImageStatusUnknownType,   kCGImageStatusIncomplete,    kCGImageStatusIncomplete,
                                                    kCGImageStatusComplete };
    static const std::vector<int> c_streamLengthForFrame = { 1, 95, 96, 906, 907, 59505, 59506 };

    CGImageSourceRef imageRef = CGImageSourceCreateIncremental(nullptr);
    ASSERT_NE_MSG(nullptr, imageRef, "FAILED: CGImageSourceCreateIncremental returned nullptr");

    // Check container status change sequence at corresponding stream lengths
    for (int index = 0; index < c_streamLengthForContainer.size(); index++) {
        NSData* currentImageChunk =
            [NSData dataWithBytesNoCopy:(char*)[imageData bytes] length:c_streamLengthForContainer[index] freeWhenDone:NO];

        CGImageSourceUpdateData(imageRef, (CFDataRef)currentImageChunk, imageLength == c_streamLengthForContainer[index]);
        ASSERT_EQ_MSG(CGImageSourceGetStatus(imageRef), c_containerStatus[index], "FAILED: ImageIOTest::ContainerStatus");
    }

    // Check frame status change sequence at corresponding stream lengths
    bool imageStart = false;
    for (int index = 0; index < c_streamLengthForFrame.size(); index++) {
        NSData* currentImageChunk =
            [NSData dataWithBytesNoCopy:(char*)[imageData bytes] length:c_streamLengthForFrame[index] freeWhenDone:NO];

        CGImageSourceUpdateData(imageRef, (CFDataRef)currentImageChunk, imageLength == c_streamLengthForFrame[index]);
        CGImageRef incrementalImage = CGImageSourceCreateImageAtIndex(imageRef, 0, nullptr);

        // Check minimum stream length for valid image references
        if (incrementalImage && !imageStart) {
            ASSERT_EQ_MSG(c_streamLengthForImage, c_streamLengthForFrame[index], "FAILED: ImageIOTest::ValidImageLength");
            imageStart = true;
        }

        ASSERT_EQ_MSG(CGImageSourceGetStatusAtIndex(imageRef, 0), c_frameStatus[index], "FAILED: ImageIOTest::ImageStatusAtIndex");
    }

    CFRelease(imageRef);
}

// Test for TIFF incremental source creation, data updation, frame extraction, container status, frame status and stream lengths
TEST(ImageIO, IncrementalTIFFImageWithFrameCheck) {
    const wchar_t* imageFile = L"photo8_4layers_1024x683.tif";
    NSData* imageData = getDataFromImageFile(imageFile);
    ASSERT_NE_MSG(nullptr, imageData, "FAILED: ImageIOTest::Could not find file: [%s]", imageFile);
    NSUInteger imageLength = [imageData length];

    // Minimum Stream Length at which CGImageSourceCreateImageAtIndex returns valid image references
    static const int c_streamLengthForImage1 = 1151534;
    static const int c_streamLengthForImage2 = 1960686;
    static const int c_streamLengthForImage3 = 3129166;
    static const int c_streamLengthForImage4 = 4184268;

    // Container status change sequence and corresponding stream lengths
    static const std::vector<int> c_containerStatus = { kCGImageStatusInvalidData,
                                                        kCGImageStatusInvalidData,
                                                        kCGImageStatusIncomplete,
                                                        kCGImageStatusIncomplete,
                                                        kCGImageStatusComplete };
    static const std::vector<int> c_streamLengthForContainer = { 1, 95, 96, 4187741, 4187742 };

    // Frame1 status change sequence and corresponding stream lengths
    static const std::vector<int> c_frameStatus1 = { kCGImageStatusReadingHeader, kCGImageStatusReadingHeader, kCGImageStatusUnknownType,
                                                     kCGImageStatusUnknownType,   kCGImageStatusIncomplete,    kCGImageStatusIncomplete,
                                                     kCGImageStatusComplete };
    static const std::vector<int> c_streamLengthForFrame1 = { 1, 95, 96, 1151533, 1151534, 1960675, 1960676 };

    // Frame2 status change sequence and corresponding stream lengths
    static const std::vector<int> c_frameStatus2 = { kCGImageStatusReadingHeader, kCGImageStatusReadingHeader, kCGImageStatusUnknownType,
                                                     kCGImageStatusUnknownType,   kCGImageStatusIncomplete,    kCGImageStatusIncomplete,
                                                     kCGImageStatusComplete };
    static const std::vector<int> c_streamLengthForFrame2 = { 1, 95, 96, 1960685, 1960686, 3129155, 3129156 };

    // Frame3 status change sequence and corresponding stream lengths
    static const std::vector<int> c_frameStatus3 = { kCGImageStatusReadingHeader, kCGImageStatusReadingHeader, kCGImageStatusUnknownType,
                                                     kCGImageStatusUnknownType,   kCGImageStatusIncomplete,    kCGImageStatusIncomplete,
                                                     kCGImageStatusComplete };
    static const std::vector<int> c_streamLengthForFrame3 = { 1, 95, 96, 3129165, 3129166, 4184257, 4184258 };

    // Frame4 status change sequence and corresponding stream lengths
    static const std::vector<int> c_frameStatus4 = { kCGImageStatusReadingHeader, kCGImageStatusReadingHeader, kCGImageStatusUnknownType,
                                                     kCGImageStatusUnknownType,   kCGImageStatusIncomplete,    kCGImageStatusIncomplete,
                                                     kCGImageStatusComplete };
    static const std::vector<int> c_streamLengthForFrame4 = { 1, 95, 96, 4184267, 4184268, 4187741, 4187742 };

    CGImageSourceRef imageRef = CGImageSourceCreateIncremental(nullptr);
    ASSERT_NE_MSG(nullptr, imageRef, "FAILED: CGImageSourceCreateIncremental returned nullptr");

    // Check container status change sequence at corresponding stream lengths
    for (int index = 0; index < c_streamLengthForContainer.size(); index++) {
        NSData* currentImageChunk =
            [NSData dataWithBytesNoCopy:(char*)[imageData bytes] length:c_streamLengthForContainer[index] freeWhenDone:NO];

        CGImageSourceUpdateData(imageRef, (CFDataRef)currentImageChunk, imageLength == c_streamLengthForContainer[index]);
        ASSERT_EQ_MSG(CGImageSourceGetStatus(imageRef), c_containerStatus[index], "FAILED: ImageIOTest::ContainerStatus");
    }

    // Check frame1 status change sequence at corresponding stream lengths
    bool imageStart = false;
    for (int index = 0; index < c_streamLengthForFrame1.size(); index++) {
        NSData* currentImageChunk =
            [NSData dataWithBytesNoCopy:(char*)[imageData bytes] length:c_streamLengthForFrame1[index] freeWhenDone:NO];

        CGImageSourceUpdateData(imageRef, (CFDataRef)currentImageChunk, imageLength == c_streamLengthForFrame1[index]);
        CGImageRef incrementalImage = CGImageSourceCreateImageAtIndex(imageRef, 0, nullptr);

        // Check minimum stream length for valid image references
        if (incrementalImage && !imageStart) {
            ASSERT_EQ_MSG(c_streamLengthForImage1, c_streamLengthForFrame1[index], "FAILED: ImageIOTest::ValidImageLength");
            imageStart = true;
        }

        ASSERT_EQ_MSG(CGImageSourceGetStatusAtIndex(imageRef, 0), c_frameStatus1[index], "FAILED: ImageIOTest::ImageStatusAtIndex");
    }

    // Check frame2 status change sequence at corresponding stream lengths
    imageStart = false;
    for (int index = 0; index < c_streamLengthForFrame2.size(); index++) {
        NSData* currentImageChunk =
            [NSData dataWithBytesNoCopy:(char*)[imageData bytes] length:c_streamLengthForFrame2[index] freeWhenDone:NO];

        CGImageSourceUpdateData(imageRef, (CFDataRef)currentImageChunk, imageLength == c_streamLengthForFrame2[index]);
        CGImageRef incrementalImage = CGImageSourceCreateImageAtIndex(imageRef, 1, nullptr);

        // Check minimum stream length for valid image references
        if (incrementalImage && !imageStart) {
            ASSERT_EQ_MSG(c_streamLengthForImage2, c_streamLengthForFrame2[index], "FAILED: ImageIOTest::ValidImageLength");
            imageStart = true;
        }

        ASSERT_EQ_MSG(CGImageSourceGetStatusAtIndex(imageRef, 1), c_frameStatus2[index], "FAILED: ImageIOTest::ImageStatusAtIndex");
    }

    // Check frame3 status change sequence at corresponding stream lengths
    imageStart = false;
    for (int index = 0; index < c_streamLengthForFrame3.size(); index++) {
        NSData* currentImageChunk =
            [NSData dataWithBytesNoCopy:(char*)[imageData bytes] length:c_streamLengthForFrame3[index] freeWhenDone:NO];

        CGImageSourceUpdateData(imageRef, (CFDataRef)currentImageChunk, imageLength == c_streamLengthForFrame3[index]);
        CGImageRef incrementalImage = CGImageSourceCreateImageAtIndex(imageRef, 2, nullptr);

        // Check minimum stream length for valid image references
        if (incrementalImage && !imageStart) {
            ASSERT_EQ_MSG(c_streamLengthForImage3, c_streamLengthForFrame3[index], "FAILED: ImageIOTest::ValidImageLength");
            imageStart = true;
        }

        ASSERT_EQ_MSG(CGImageSourceGetStatusAtIndex(imageRef, 2), c_frameStatus3[index], "FAILED: ImageIOTest::ImageStatusAtIndex");
    }

    // Check frame4 status change sequence at corresponding stream lengths
    imageStart = false;
    for (int index = 0; index < c_streamLengthForFrame4.size(); index++) {
        NSData* currentImageChunk =
            [NSData dataWithBytesNoCopy:(char*)[imageData bytes] length:c_streamLengthForFrame4[index] freeWhenDone:NO];

        CGImageSourceUpdateData(imageRef, (CFDataRef)currentImageChunk, imageLength == c_streamLengthForFrame4[index]);
        CGImageRef incrementalImage = CGImageSourceCreateImageAtIndex(imageRef, 3, nullptr);

        // Check minimum stream length for valid image references
        if (incrementalImage && !imageStart) {
            ASSERT_EQ_MSG(c_streamLengthForImage4, c_streamLengthForFrame4[index], "FAILED: ImageIOTest::ValidImageLength");
            imageStart = true;
        }

        ASSERT_EQ_MSG(CGImageSourceGetStatusAtIndex(imageRef, 3), c_frameStatus4[index], "FAILED: ImageIOTest::ImageStatusAtIndex");
    }
    CFRelease(imageRef);
}

// Test for GIF incremental source creation, data updation, frame extraction, container status, frame status and stream lengths
TEST(ImageIO, IncrementalGIFImageWithFrameCheck) {
    const wchar_t* imageFile = L"photo7_4layers_683x1024.gif";
    NSData* imageData = getDataFromImageFile(imageFile);
    ASSERT_NE_MSG(nullptr, imageData, "FAILED: ImageIOTest::Could not find file: [%s]", imageFile);
    NSUInteger imageLength = [imageData length];

    // Minimum Stream Length at which CGImageSourceCreateImageAtIndex returns valid image references
    static const int c_streamLengthForImage1 = 1584;
    static const int c_streamLengthForImage2 = 334452;
    static const int c_streamLengthForImage3 = 462473;
    static const int c_streamLengthForImage4 = 614713;

    // Container status change sequence and corresponding stream lengths
    static const std::vector<int> c_containerStatus = { kCGImageStatusInvalidData,
                                                        kCGImageStatusInvalidData,
                                                        kCGImageStatusIncomplete,
                                                        kCGImageStatusIncomplete,
                                                        kCGImageStatusComplete };
    static const std::vector<int> c_streamLengthForContainer = { 1, 95, 96, 669892, 669893 };

    // Frame1 status change sequence and corresponding stream lengths
    static const std::vector<int> c_frameStatus1 = { kCGImageStatusReadingHeader, kCGImageStatusReadingHeader, kCGImageStatusUnknownType,
                                                     kCGImageStatusUnknownType,   kCGImageStatusReadingHeader, kCGImageStatusReadingHeader,
                                                     kCGImageStatusUnknownType,   kCGImageStatusUnknownType,   kCGImageStatusIncomplete,
                                                     kCGImageStatusIncomplete,    kCGImageStatusComplete };
    static const std::vector<int> c_streamLengthForFrame1 = { 1, 95, 96, 808, 809, 817, 818, 1583, 1584, 333676, 333677 };

    // Frame2 status change sequence and corresponding stream lengths
    static const std::vector<int> c_frameStatus2 = { kCGImageStatusReadingHeader, kCGImageStatusReadingHeader, kCGImageStatusUnknownType,
                                                     kCGImageStatusUnknownType,   kCGImageStatusIncomplete,    kCGImageStatusIncomplete,
                                                     kCGImageStatusUnknownType,   kCGImageStatusUnknownType,   kCGImageStatusIncomplete,
                                                     kCGImageStatusIncomplete,    kCGImageStatusComplete };
    static const std::vector<int> c_streamLengthForFrame2 = { 1, 95, 96, 333676, 333677, 333685, 333686, 334451, 334452, 461697, 461698 };

    // Frame3 status change sequence and corresponding stream lengths
    static const std::vector<int> c_frameStatus3 = { kCGImageStatusReadingHeader, kCGImageStatusReadingHeader, kCGImageStatusUnknownType,
                                                     kCGImageStatusUnknownType,   kCGImageStatusIncomplete,    kCGImageStatusIncomplete,
                                                     kCGImageStatusUnknownType,   kCGImageStatusUnknownType,   kCGImageStatusIncomplete,
                                                     kCGImageStatusIncomplete,    kCGImageStatusComplete };
    static const std::vector<int> c_streamLengthForFrame3 = { 1, 95, 96, 461697, 461698, 461706, 461707, 462472, 462473, 613937, 613938 };

    // Frame4 status change sequence and corresponding stream lengths
    static const std::vector<int> c_frameStatus4 = { kCGImageStatusReadingHeader, kCGImageStatusReadingHeader, kCGImageStatusUnknownType,
                                                     kCGImageStatusUnknownType,   kCGImageStatusIncomplete,    kCGImageStatusIncomplete,
                                                     kCGImageStatusUnknownType,   kCGImageStatusUnknownType,   kCGImageStatusIncomplete,
                                                     kCGImageStatusIncomplete,    kCGImageStatusComplete };
    static const std::vector<int> c_streamLengthForFrame4 = { 1, 95, 96, 613937, 613938, 613946, 613947, 614712, 614713, 669892, 669893 };

    CGImageSourceRef imageRef = CGImageSourceCreateIncremental(nullptr);
    ASSERT_NE_MSG(nullptr, imageRef, "FAILED: CGImageSourceCreateIncremental returned nullptr");

    // Check container status change sequence at corresponding stream lengths
    for (int index = 0; index < c_streamLengthForContainer.size(); index++) {
        NSData* currentImageChunk =
            [NSData dataWithBytesNoCopy:(char*)[imageData bytes] length:c_streamLengthForContainer[index] freeWhenDone:NO];

        CGImageSourceUpdateData(imageRef, (CFDataRef)currentImageChunk, imageLength == c_streamLengthForContainer[index]);
        ASSERT_EQ_MSG(CGImageSourceGetStatus(imageRef), c_containerStatus[index], "FAILED: ImageIOTest::ContainerStatus");
    }

    // Check frame1 status change sequence at corresponding stream lengths
    bool imageStart = false;
    for (int index = 0; index < c_streamLengthForFrame1.size(); index++) {
        NSData* currentImageChunk =
            [NSData dataWithBytesNoCopy:(char*)[imageData bytes] length:c_streamLengthForFrame1[index] freeWhenDone:NO];

        CGImageSourceUpdateData(imageRef, (CFDataRef)currentImageChunk, imageLength == c_streamLengthForFrame1[index]);
        CGImageRef incrementalImage = CGImageSourceCreateImageAtIndex(imageRef, 0, nullptr);

        // Check minimum stream length for valid image references
        if (incrementalImage && !imageStart) {
            ASSERT_EQ_MSG(c_streamLengthForImage1, c_streamLengthForFrame1[index], "FAILED: ImageIOTest::ValidImageLength");
            imageStart = true;
        }

        ASSERT_EQ_MSG(CGImageSourceGetStatusAtIndex(imageRef, 0), c_frameStatus1[index], "FAILED: ImageIOTest::ImageStatusAtIndex");
    }

    // Check frame2 status change sequence at corresponding stream lengths
    imageStart = false;
    for (int index = 0; index < c_streamLengthForFrame2.size(); index++) {
        NSData* currentImageChunk =
            [NSData dataWithBytesNoCopy:(char*)[imageData bytes] length:c_streamLengthForFrame2[index] freeWhenDone:NO];

        CGImageSourceUpdateData(imageRef, (CFDataRef)currentImageChunk, imageLength == c_streamLengthForFrame2[index]);
        CGImageRef incrementalImage = CGImageSourceCreateImageAtIndex(imageRef, 1, nullptr);

        // Check minimum stream length for valid image references
        if (incrementalImage && !imageStart) {
            ASSERT_EQ_MSG(c_streamLengthForImage2, c_streamLengthForFrame2[index], "FAILED: ImageIOTest::ValidImageLength");
            imageStart = true;
        }

        ASSERT_EQ_MSG(CGImageSourceGetStatusAtIndex(imageRef, 1), c_frameStatus2[index], "FAILED: ImageIOTest::ImageStatusAtIndex");
    }

    // Check frame3 status change sequence at corresponding stream lengths
    imageStart = false;
    for (int index = 0; index < c_streamLengthForFrame3.size(); index++) {
        NSData* currentImageChunk =
            [NSData dataWithBytesNoCopy:(char*)[imageData bytes] length:c_streamLengthForFrame3[index] freeWhenDone:NO];

        CGImageSourceUpdateData(imageRef, (CFDataRef)currentImageChunk, imageLength == c_streamLengthForFrame3[index]);
        CGImageRef incrementalImage = CGImageSourceCreateImageAtIndex(imageRef, 2, nullptr);

        // Check minimum stream length for valid image references
        if (incrementalImage && !imageStart) {
            ASSERT_EQ_MSG(c_streamLengthForImage3, c_streamLengthForFrame3[index], "FAILED: ImageIOTest::ValidImageLength");
            imageStart = true;
        }

        ASSERT_EQ_MSG(CGImageSourceGetStatusAtIndex(imageRef, 2), c_frameStatus3[index], "FAILED: ImageIOTest::ImageStatusAtIndex");
    }

    // Check frame4 status change sequence at corresponding stream lengths
    imageStart = false;
    for (int index = 0; index < c_streamLengthForFrame4.size(); index++) {
        NSData* currentImageChunk =
            [NSData dataWithBytesNoCopy:(char*)[imageData bytes] length:c_streamLengthForFrame4[index] freeWhenDone:NO];

        CGImageSourceUpdateData(imageRef, (CFDataRef)currentImageChunk, imageLength == c_streamLengthForFrame4[index]);
        CGImageRef incrementalImage = CGImageSourceCreateImageAtIndex(imageRef, 3, nullptr);

        // Check minimum stream length for valid image references
        if (incrementalImage && !imageStart) {
            ASSERT_EQ_MSG(c_streamLengthForImage4, c_streamLengthForFrame4[index], "FAILED: ImageIOTest::ValidImageLength");
            imageStart = true;
        }

        ASSERT_EQ_MSG(CGImageSourceGetStatusAtIndex(imageRef, 3), c_frameStatus4[index], "FAILED: ImageIOTest::ImageStatusAtIndex");
    }
    CFRelease(imageRef);
}

// Test for ICO incremental source creation, data updation, frame extraction, container status, frame status and stream lengths
TEST(ImageIO, IncrementalICOImageWithFrameCheck) {
    const wchar_t* imageFile = L"photo2_683x1024.ico";
    NSData* imageData = getDataFromImageFile(imageFile);
    ASSERT_NE_MSG(nullptr, imageData, "FAILED: ImageIOTest::Could not find file: [%s]", imageFile);
    NSUInteger imageLength = [imageData length];

    // Minimum Stream Length at which CGImageSourceCreateImageAtIndex returns valid image references
    static const int c_streamLengthForImage = 1041876;

    // Container status change sequence and corresponding stream lengths
    static const std::vector<int> c_containerStatus = { kCGImageStatusInvalidData,
                                                        kCGImageStatusInvalidData,
                                                        kCGImageStatusIncomplete,
                                                        kCGImageStatusIncomplete,
                                                        kCGImageStatusComplete };
    static const std::vector<int> c_streamLengthForContainer = { 1, 95, 96, 1041875, 1041876 };

    // Frame status change sequence and corresponding stream lengths
    static const std::vector<int> c_frameStatus = { kCGImageStatusReadingHeader,
                                                    kCGImageStatusReadingHeader,
                                                    kCGImageStatusUnknownType,
                                                    kCGImageStatusUnknownType,
                                                    kCGImageStatusComplete };
    static const std::vector<int> c_streamLengthForFrame = { 1, 95, 96, 1041875, 1041876 };

    CGImageSourceRef imageRef = CGImageSourceCreateIncremental(nullptr);
    ASSERT_NE_MSG(nullptr, imageRef, "FAILED: CGImageSourceCreateIncremental returned nullptr");

    // Check container status change sequence at corresponding stream lengths
    for (int index = 0; index < c_streamLengthForContainer.size(); index++) {
        NSData* currentImageChunk =
            [NSData dataWithBytesNoCopy:(char*)[imageData bytes] length:c_streamLengthForContainer[index] freeWhenDone:NO];

        CGImageSourceUpdateData(imageRef, (CFDataRef)currentImageChunk, imageLength == c_streamLengthForContainer[index]);
        ASSERT_EQ_MSG(CGImageSourceGetStatus(imageRef), c_containerStatus[index], "FAILED: ImageIOTest::ContainerStatus");
    }

    // Check frame status change sequence at corresponding stream lengths
    bool imageStart = false;
    for (int index = 0; index < c_streamLengthForFrame.size(); index++) {
        NSData* currentImageChunk =
            [NSData dataWithBytesNoCopy:(char*)[imageData bytes] length:c_streamLengthForFrame[index] freeWhenDone:NO];

        CGImageSourceUpdateData(imageRef, (CFDataRef)currentImageChunk, imageLength == c_streamLengthForFrame[index]);
        CGImageRef incrementalImage = CGImageSourceCreateImageAtIndex(imageRef, 0, nullptr);

        // Check minimum stream length for valid image references
        if (incrementalImage && !imageStart) {
            ASSERT_EQ_MSG(c_streamLengthForImage, c_streamLengthForFrame[index], "FAILED: ImageIOTest::ValidImageLength");
            imageStart = true;
        }

        ASSERT_EQ_MSG(CGImageSourceGetStatusAtIndex(imageRef, 0), c_frameStatus[index], "FAILED: ImageIOTest::ImageStatusAtIndex");
    }

    CFRelease(imageRef);
}

// Negative Scenario with a TIFF incremental source
TEST(ImageIO, IncrementalTIFFNegativeScenario) {
    const wchar_t* imageFile = L"photo8_4layers_1024x683.tif";
    NSData* imageData = getDataFromImageFile(imageFile);
    ASSERT_NE_MSG(nullptr, imageData, "FAILED: ImageIOTest::Could not find file: [%s]", imageFile);
    NSUInteger imageLength = [imageData length];

    // Minimum Stream Length at which CGImageSourceCreateImageAtIndex returns valid image references
    static const int c_streamLengthForImage1 = 1151534;
    static const int c_streamLengthForImage2 = 1960686;

    // Frame1 status change sequence and corresponding stream lengths
    static const std::vector<int> c_frameStatus1 = { kCGImageStatusReadingHeader, kCGImageStatusReadingHeader, kCGImageStatusUnknownType,
                                                     kCGImageStatusUnknownType,   kCGImageStatusUnknownType,   kCGImageStatusUnknownType,
                                                     kCGImageStatusUnknownType };
    static const std::vector<int> c_streamLengthForFrame1 = { 1, 95, 96, 1151533, 1151534, 1960675, 1960676 };

    // Frame2 status change sequence and corresponding stream lengths
    static const std::vector<int> c_frameStatus2 = { kCGImageStatusReadingHeader, kCGImageStatusReadingHeader, kCGImageStatusUnknownType,
                                                     kCGImageStatusUnknownType,   kCGImageStatusUnknownType,   kCGImageStatusUnknownType,
                                                     kCGImageStatusUnknownType };
    static const std::vector<int> c_streamLengthForFrame2 = { 1, 95, 96, 1960685, 1960686, 3129155, 3129156 };

    // Frame3 status change sequence and corresponding stream lengths
    static const std::vector<int> c_frameStatus3 = { kCGImageStatusReadingHeader, kCGImageStatusReadingHeader, kCGImageStatusUnknownType,
                                                     kCGImageStatusUnknownType,   kCGImageStatusUnknownType,   kCGImageStatusUnknownType,
                                                     kCGImageStatusUnknownType };
    static const std::vector<int> c_streamLengthForFrame3 = { 1, 95, 96, 3129165, 3129166, 4184257, 4184258 };

    CGImageSourceRef imageRef = CGImageSourceCreateIncremental(nullptr);
    ASSERT_NE_MSG(nullptr, imageRef, "FAILED: CGImageSourceCreateIncremental returned nullptr");

    // Different indices fed to CGImageSourceCreateImageAtIndex and CGImageSourceGetStatusAtIndex
    bool imageStart = false;
    for (int index = 0; index < c_streamLengthForFrame1.size(); index++) {
        NSData* currentImageChunk =
            [NSData dataWithBytesNoCopy:(char*)[imageData bytes] length:c_streamLengthForFrame1[index] freeWhenDone:NO];

        CGImageSourceUpdateData(imageRef, (CFDataRef)currentImageChunk, imageLength == c_streamLengthForFrame1[index]);
        CGImageRef incrementalImage = CGImageSourceCreateImageAtIndex(imageRef, 0, nullptr);

        // Check minimum stream length for valid image references
        if (incrementalImage && !imageStart) {
            ASSERT_EQ_MSG(c_streamLengthForImage1, c_streamLengthForFrame1[index], "FAILED: ImageIOTest::ValidImageLength");
            imageStart = true;
        }

        ASSERT_EQ_MSG(CGImageSourceGetStatusAtIndex(imageRef, 3), c_frameStatus1[index], "FAILED: ImageIOTest::ImageStatusAtIndex");
    }

    // Negative indices fed to CGImageSourceCreateImageAtIndex and CGImageSourceGetStatusAtIndex
    imageStart = false;
    for (int index = 0; index < c_streamLengthForFrame2.size(); index++) {
        NSData* currentImageChunk =
            [NSData dataWithBytesNoCopy:(char*)[imageData bytes] length:c_streamLengthForFrame2[index] freeWhenDone:NO];

        CGImageSourceUpdateData(imageRef, (CFDataRef)currentImageChunk, imageLength == c_streamLengthForFrame2[index]);
        CGImageRef incrementalImage = CGImageSourceCreateImageAtIndex(imageRef, -1, nullptr);

        // Check minimum stream length for valid image references
        if (incrementalImage && !imageStart) {
            ASSERT_EQ_MSG(c_streamLengthForImage2, c_streamLengthForFrame2[index], "FAILED: ImageIOTest::ValidImageLength");
            imageStart = true;
        }

        ASSERT_EQ_MSG(CGImageSourceGetStatusAtIndex(imageRef, -1), c_frameStatus2[index], "FAILED: ImageIOTest::ImageStatusAtIndex");
    }

    // Triggering CGImageSourceGetStatusAtIndex without an equivalent CGImageSourceCreateImageAtIndex
    imageStart = false;
    for (int index = 0; index < c_streamLengthForFrame3.size(); index++) {
        NSData* currentImageChunk =
            [NSData dataWithBytesNoCopy:(char*)[imageData bytes] length:c_streamLengthForFrame3[index] freeWhenDone:NO];

        CGImageSourceUpdateData(imageRef, (CFDataRef)currentImageChunk, imageLength == c_streamLengthForFrame3[index]);
        ASSERT_EQ_MSG(CGImageSourceGetStatusAtIndex(imageRef, 2), c_frameStatus3[index], "FAILED: ImageIOTest::ImageStatusAtIndex");
    }

    CFRelease(imageRef);
}

// Using Incremental Load APIs with non-incremental sources
TEST(ImageIO, NonIncrementalJPEGSource) {
    const wchar_t* imageFile = L"photo6_1024x670.jpg";
    NSData* imageData = getDataFromImageFile(imageFile);
    ASSERT_NE_MSG(nullptr, imageData, "FAILED: ImageIOTest::Could not find file: [%s]", imageFile);

    CGImageSourceRef imageSource = CGImageSourceCreateWithData((CFDataRef)imageData, nullptr);
    ASSERT_NE_MSG(nullptr, imageSource, "FAILED: ImageIOTest::CGImageSourceCreateWithData returned nullptr");

    EXPECT_EQ(kCGImageStatusComplete, CGImageSourceGetStatus(imageSource));
    ASSERT_EQ(kCGImageStatusUnknownType, CGImageSourceGetStatusAtIndex(imageSource, 0));

    CGImageRef imageRef = CGImageSourceCreateImageAtIndex(imageSource, 0, nullptr);
    ASSERT_NE_MSG(nullptr, imageRef, "FAILED: ImageIOTest::CGImageSourceCreateImageAtIndex returned nullptr");
    EXPECT_EQ(kCGImageStatusComplete, CGImageSourceGetStatusAtIndex(imageSource, 0));

    imageRef = CGImageSourceCreateImageAtIndex(imageSource, 1, nullptr);
    ASSERT_EQ_MSG(nullptr, imageRef, "FAILED: ImageIOTest::CGImageSourceCreateImageAtIndex should return nullptr");
    EXPECT_EQ(kCGImageStatusUnknownType, CGImageSourceGetStatusAtIndex(imageSource, 1));

    CFRelease(imageSource);
}
