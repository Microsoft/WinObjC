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

#import <Starboard/SmartTypes.h>
#import <TestFramework.h>
#import <UIKit/UIImage.h>

static NSString* getPathToFile(NSString* fileName) {
    static StrongId<NSString*> refPath = []() {
        char fullPath[_MAX_PATH];
        GetModuleFileNameA(NULL, fullPath, _MAX_PATH);
        return [@(fullPath) stringByDeletingLastPathComponent];
    }();
    return [refPath stringByAppendingPathComponent:fileName];
}

template <typename VerifierLambda> // Takes the form void(*)(UIImage*,UIImage*)
static void testRepresentationOfCroppedImage(NSString* source1, NSString* source2, CGRect cropRegion, VerifierLambda&& verify) {
    UIImage* photo = [UIImage imageNamed:source1];
    ASSERT_OBJCNE(nil, photo);

    // crop it
    woc::unique_cf<CGImageRef> imageRef{ CGImageCreateWithImageInRect([photo CGImage], cropRegion) };
    ASSERT_NE(nullptr, imageRef);

    photo = [UIImage imageWithCGImage:imageRef.get()];
    ASSERT_OBJCNE(nil, photo);

    UIImage* croppedRef = [UIImage imageNamed:source2];
    ASSERT_OBJCNE(nil, croppedRef);

    verify(photo, croppedRef);
}

TEST(UIImage, JPEGRepresentation) {
    CGFloat quality = 1;
    auto verifier = [&quality](UIImage* source, UIImage* testImage) {
        NSData* OrgCroppedData = UIImageJPEGRepresentation(source, quality);
        ASSERT_OBJCNE(nil, OrgCroppedData);

        NSData* croppedData = UIImageJPEGRepresentation(testImage, quality);
        ASSERT_OBJCNE(nil, croppedData);

        ASSERT_OBJCEQ(croppedData, OrgCroppedData);
    };
    NSString* source1 = getPathToFile(@"data/Photo2.jpg");
    NSString* source2 = getPathToFile(@"data/CroppedPhoto2.jpg");
    CGRect region = CGRectMake(300, 600, 200, 200);

    testRepresentationOfCroppedImage(source1, source2, region, verifier);

    quality = 0.5;
    testRepresentationOfCroppedImage(source1, source2, region, verifier);
}

TEST(UIImage, PNGRepresentation) {
    auto verifier = [](UIImage* source, UIImage* testImage) {
        NSData* OrgCroppedData = UIImagePNGRepresentation(source);
        ASSERT_OBJCNE(nil, OrgCroppedData);

        NSData* croppedData = UIImagePNGRepresentation(testImage);
        ASSERT_OBJCNE(nil, croppedData);
        ASSERT_OBJCEQ(croppedData, OrgCroppedData);
    };
    testRepresentationOfCroppedImage(getPathToFile(@"data/png1.png"),
                                     getPathToFile(@"data/CroppedPhoto1.png"),
                                     CGRectMake(200, 200, 800, 600),
                                     verifier);
}
