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

#include "DrawingTest.h"
#include "DrawingTestConfig.h"

#include <CoreFoundation/CoreFoundation.h>
#include <ImageIO/ImageIO.h>

#include <Starboard/SmartTypes.h>
#include <memory>

static CGImageRef __CGImageCreateFromPNGFile(CFStringRef filename) {
    woc::unique_cf<CGDataProviderRef> dataProvider{ CGDataProviderCreateWithFilename(
        CFStringGetCStringPtr(filename, kCFStringEncodingUTF8)) };
    if (!dataProvider) {
        return nullptr;
    }

    woc::unique_cf<CGImageRef> image{ CGImageCreateWithPNGDataProvider(dataProvider.get(), nullptr, FALSE, kCGRenderingIntentDefault) };
    return image.release();
}

static CFDataRef __CFDataCreatePNGFromCGImage(CGImageRef image) {
    // Estimate the image data size to be as large as its raw pixel buffer.
    // This will never be hit; but if it does, CFData will grow intelligently regardless.
    size_t sizeEstimate = CGImageGetHeight(image) * CGImageGetBytesPerRow(image);
    woc::unique_cf<CFMutableDataRef> imageData{ CFDataCreateMutable(nullptr, sizeEstimate) };
    if (!imageData) {
        return nullptr;
    }

    woc::unique_cf<CGImageDestinationRef> imageDest{ CGImageDestinationCreateWithData(imageData.get(), CFSTR("public.png"), 1, nullptr) };
    if (!imageDest) {
        return nullptr;
    }

    CGImageDestinationAddImage(imageDest.get(), image, nullptr);
    CGImageDestinationFinalize(imageDest.get());

    return imageData.release();
}

static bool __WriteCFDataToFile(CFDataRef data, CFStringRef filename) {
    std::unique_ptr<char[]> owningFilenamePtr;

    char* rawFilename = const_cast<char*>(CFStringGetCStringPtr(filename, kCFStringEncodingUTF8));
    size_t len = 0;

    if (!rawFilename) {
        CFRange filenameRange{ 0, CFStringGetLength(filename) };
        CFIndex requiredBufferLength = 0;
        CFStringGetBytes(filename, filenameRange, kCFStringEncodingUTF8, 0, FALSE, nullptr, 0, &requiredBufferLength);
        owningFilenamePtr.reset(new char[requiredBufferLength]);
        rawFilename = owningFilenamePtr.get();
        CFStringGetBytes(
            filename, filenameRange, kCFStringEncodingUTF8, 0, FALSE, (UInt8*)rawFilename, requiredBufferLength, &requiredBufferLength);
        len = requiredBufferLength;
    } else {
        len = strlen(rawFilename);
    }

    woc::unique_cf<CFURLRef> url{ CFURLCreateFromFileSystemRepresentation(nullptr, (UInt8*)rawFilename, len, FALSE) };
    if (!url) {
        return false;
    }

    return CFURLWriteDataAndPropertiesToResource(url.get(), data, nullptr, nullptr);
}

static const CGSize g_defaultCanvasSize{ 512.f, 256.f };

woc::unique_cf<CGColorSpaceRef> testing::DrawTest::s_deviceColorSpace;

void testing::DrawTest::SetUpTestCase() {
    s_deviceColorSpace.reset(CGColorSpaceCreateDeviceRGB());
}

void testing::DrawTest::TearDownTestCase() {
    s_deviceColorSpace.release();
}

CGSize testing::DrawTest::CanvasSize() {
    return g_defaultCanvasSize;
}

void testing::DrawTest::SetUp() {
    CGSize size = CanvasSize();

    _context.reset(CGBitmapContextCreate(
        nullptr, size.width, size.height, 8, size.width * 4, s_deviceColorSpace.get(), kCGImageAlphaPremultipliedFirst));
    ASSERT_NE(nullptr, _context);

    _bounds = { CGPointZero, size };

    SetUpContext();
}

CFStringRef testing::DrawTest::CreateAdditionalTestDescription() {
    return nullptr;
}

CFStringRef testing::DrawTest::CreateOutputFilename() {
    const ::testing::TestInfo* const test_info = ::testing::UnitTest::GetInstance()->current_test_info();
    woc::unique_cf<CFStringRef> additionalDesc{ CreateAdditionalTestDescription() };
    woc::unique_cf<CFStringRef> filename{ CFStringCreateWithFormat(nullptr,
                                                                   nullptr,
                                                                   CFSTR("TestImage.%s.%s%s%@.png"),
                                                                   test_info->test_case_name(),
                                                                   test_info->name(),
                                                                   (additionalDesc ? "." : ""),
                                                                   (additionalDesc ? additionalDesc.get() : CFSTR(""))) };
    return filename.release();
}

struct pixel {};
struct bgraPixel : pixel {
    bgraPixel(uint8_t b, uint8_t g, uint8_t r, uint8_t a) : b(b), g(g), r(r), a(a) {
    }
    uint8_t b, g, r, a;
};

struct rgbaPixel : pixel {
    rgbaPixel(uint8_t r, uint8_t g, uint8_t b, uint8_t a) : r(r), g(g), b(b), a(a) {
    }
    uint8_t r, g, b, a;
};

template <typename T, typename U>
typename std::enable_if<std::is_base_of<pixel, T>::value && std::is_base_of<pixel, U>::value, bool>::type operator==(const T& t,
                                                                                                                     const U& u) {
    return t.r == u.r && t.g == u.g && t.b == u.b && t.a == u.a;
}

template <typename T, typename U>
typename std::enable_if<std::is_base_of<pixel, T>::value && std::is_base_of<pixel, U>::value, bool>::type operator!=(const T& t,
                                                                                                                     const U& u) {
    return !(t == u);
}

CGImageRef _CreateGreenlineImage(rgbaPixel background, CGImageRef baseline, CGImageRef comparand, int& npxchg) {
    CGDataProviderRef baselineProvider{ CGImageGetDataProvider(baseline) };
    woc::unique_cf<CFDataRef> baselineData{ CGDataProviderCopyData(baselineProvider) };

    CGDataProviderRef comparandProvider{ CGImageGetDataProvider(comparand) };
    woc::unique_cf<CFDataRef> comparandData{ CGDataProviderCopyData(comparandProvider) };

    CFIndex baselineLength = CFDataGetLength(baselineData.get());
    if (baselineLength != CFDataGetLength(comparandData.get())) {
        npxchg = CFDataGetLength(comparandData.get());
        return nullptr;
    }

    woc::unique_iw<uint8_t> greenlineBuffer{ static_cast<uint8_t*>(IwCalloc(baselineLength, 1)) };

    const bgraPixel* baselinePixels{ reinterpret_cast<const bgraPixel*>(CFDataGetBytePtr(baselineData.get())) };
    const rgbaPixel* comparandPixels{ reinterpret_cast<const rgbaPixel*>(CFDataGetBytePtr(comparandData.get())) };
    rgbaPixel* greenlinePixels{ reinterpret_cast<rgbaPixel*>(greenlineBuffer.get()) };

    npxchg = 0;
    for (off_t i = 0; i < baselineLength / sizeof(rgbaPixel); ++i) {
        auto& bp = baselinePixels[i];
        auto& cp = comparandPixels[i];
        auto& gp = greenlinePixels[i];
        if (bp != cp) {
            ++npxchg;
            if (cp == background) {
                // Pixel is in EXPECTED but not ACTUAL
                gp.r = gp.a = 255;
            } else if (bp == background) {
                // Pixel is in ACTUAL but not EXPECTED
                gp.g = gp.a = 255;
            } else {
                // Pixel is in BOTH but DIFFERENT
                gp.r = gp.g = gp.a = 255;
            }
        } else {
            gp.r = gp.g = gp.b = 0;
            gp.a = 255;
        }
    }

    woc::unique_cf<CFDataRef> greenlineData{
        CFDataCreateWithBytesNoCopy(nullptr, greenlineBuffer.release(), baselineLength, kCFAllocatorDefault)
    };
    woc::unique_cf<CGDataProviderRef> greenlineProvider{ CGDataProviderCreateWithCFData(greenlineData.get()) };

    auto bi1 = CGImageGetBitmapInfo(comparand);
    auto bi2 = CGImageGetBitmapInfo(baseline);
    fprintf(stderr, "comparand %x baseline %x\n", bi1, bi2);

    return CGImageCreate(CGImageGetWidth(baseline),
                         CGImageGetHeight(baseline),
                         8,
                         32,
                         CGImageGetWidth(baseline) * 4,
                         CGImageGetColorSpace(baseline),
                         CGImageGetBitmapInfo(baseline),
                         greenlineProvider.get(),
                         nullptr,
                         FALSE,
                         kCGRenderingIntentDefault);
}

void testing::DrawTest::TearDown() {
    CGContextRef context = GetDrawingContext();

    woc::unique_cf<CGImageRef> image{ CGBitmapContextCreateImage(context) };
    ASSERT_NE(nullptr, image);

    woc::unique_cf<CFStringRef> originalFilename{ CreateOutputFilename() };

    woc::unique_cf<CFMutableStringRef> filename{ CFStringCreateMutableCopy(nullptr, 0, originalFilename.get()) };

    CFStringFindAndReplace(filename.get(), CFSTR("DISABLED_"), CFSTR(""), CFRange{ 0, CFStringGetLength(filename.get()) }, 0);
    CFStringFindAndReplace(filename.get(), CFSTR("/"), CFSTR("_"), CFRange{ 0, CFStringGetLength(filename.get()) }, 0);

    auto drawingConfig = DrawingTestConfig::Get();

    if (drawingConfig->GetMode() == DrawingTestMode::Compare) {
        woc::unique_cf<CFStringRef> referenceFilename{
            CFStringCreateWithFormat(nullptr, nullptr, CFSTR("%s/%@"), drawingConfig->GetComparisonPath().c_str(), filename.get())
        };
        woc::unique_cf<CGImageRef> referenceImage{ __CGImageCreateFromPNGFile(referenceFilename.get()) };
        ASSERT_NE(nullptr, referenceImage);

        int npxchg = 0;

        woc::unique_cf<CGImageRef> greenlines{
            _CreateGreenlineImage(rgbaPixel{ 255, 255, 255, 255 }, referenceImage.get(), image.get(), npxchg)
        };

        if (npxchg > 0) {
            woc::unique_cf<CFDataRef> actualImageData{ __CFDataCreatePNGFromCGImage(image.get()) };
            woc::unique_cf<CFDataRef> deltaImageData{ __CFDataCreatePNGFromCGImage(greenlines.get()) };

            ADD_FAILURE();
#ifdef WINOBJC
            RecordProperty("expectedImage",
                           [[[NSData dataWithContentsOfFile:(NSString*)referenceFilename.get()] base64Encoding] UTF8String]);
            RecordProperty("actualImage", [[static_cast<NSData*>(actualImageData.get()) base64Encoding] UTF8String]);
            RecordProperty("deltaImage", [[static_cast<NSData*>(deltaImageData.get()) base64Encoding] UTF8String]);
#endif
        }
    } else if (drawingConfig->GetMode() == DrawingTestMode::Generate) {
        woc::unique_cf<CFDataRef> actualImageData{ __CFDataCreatePNGFromCGImage(image.get()) };
        ASSERT_NE(nullptr, actualImageData);

        woc::unique_cf<CFStringRef> outputPath{
            CFStringCreateWithFormat(nullptr, nullptr, CFSTR("%s/%@"), drawingConfig->GetOutputPath().c_str(), filename.get())
        };
        ASSERT_NE(nullptr, outputPath);

        ASSERT_TRUE(__WriteCFDataToFile(actualImageData.get(), outputPath.get()));
    }
}

void testing::DrawTest::SetUpContext() {
    // The default context is fine as-is.
}

void testing::DrawTest::TestBody() {
    // Nothing.
}

CGContextRef testing::DrawTest::GetDrawingContext() {
    return _context.get();
}

void testing::DrawTest::SetDrawingBounds(CGRect bounds) {
    _bounds = bounds;
}

CGRect testing::DrawTest::GetDrawingBounds() {
    return _bounds;
}

void WhiteBackgroundTest::SetUpContext() {
    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();

    CGContextSaveGState(context);
    CGContextSetRGBFillColor(context, 1.0, 1.0, 1.0, 1.0);
    CGContextFillRect(context, bounds);
    CGContextRestoreGState(context);

    CGContextSetRGBStrokeColor(context, 0.0, 0.0, 0.0, 1.0);
}

CGSize UIKitMimicTest::CanvasSize() {
    CGSize parent = WhiteBackgroundTest::CanvasSize();
    return { parent.width * 2., parent.height * 2. };
}

void UIKitMimicTest::SetUpContext() {
    WhiteBackgroundTest::SetUpContext();

    CGContextRef context = GetDrawingContext();
    CGRect bounds = GetDrawingBounds();

    CGContextScaleCTM(context, 1.0, -1.0);
    CGContextTranslateCTM(context, 0, -bounds.size.height);
    CGContextScaleCTM(context, 2.0, 2.0);
    bounds = CGRectApplyAffineTransform(bounds, CGAffineTransformMakeScale(.5, .5));

    SetDrawingBounds(bounds);
}
