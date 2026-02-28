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

#import <UIKit/UIKit.h>
#import <CoreImage/CoreImage.h>
#import <Starboard/SmartTypes.h>
#import "CALayerInternal.h"
#import "../UIKit/NullCompositor.h"
#import <CoreGraphics/CGImage.h>
#import <ImageIO/ImageIO.h>

#include <windows.h>

static NSString* getPathToFile(NSString* fileName) {
    static StrongId<NSString*> refPath = []() {
        char fullPath[_MAX_PATH];
        GetModuleFileNameA(NULL, fullPath, _MAX_PATH);
        return [@(fullPath) stringByDeletingLastPathComponent];
    }();
    return [refPath stringByAppendingPathComponent:fileName];
}

static CFMutableDataRef ObtainJPEGRepresentationFromCGImage(CGImageRef image) {
    CFMutableDataRef cfData = CFDataCreateMutable(NULL, 0);
    CFAutorelease(cfData);
    CGImageDestinationRef destination = CGImageDestinationCreateWithData(cfData, CFSTR("public.jpeg"), 1, NULL);
    CFAutorelease(destination);
    CGImageDestinationAddImage(destination, image, nullptr);
    if (!CGImageDestinationFinalize(destination)) {
        return nullptr;
    }
    return cfData;
}

TEST(CoreImage, CGImageFromRect) {
    SetCACompositor(new NullCompositor);
    CIContext* context = [CIContext contextWithOptions:nil];
    ASSERT_OBJCNE(nil, context);

    UIImage* photo = [UIImage imageNamed:getPathToFile(@"Photo2.jpg")];
    ASSERT_OBJCNE(nil, photo);

    CIImage* ciImage = [CIImage imageWithCGImage:photo.CGImage];
    ASSERT_OBJCNE(nil, ciImage);
    CGImageRef cgImage = [context createCGImage:ciImage fromRect:CGRectMake(300, 600, 200, 200)];
    ASSERT_NE(nullptr, cgImage);

    NSData* data = [NSData dataWithContentsOfFile:getPathToFile(@"CroppedPhoto2.jpg")];
    ASSERT_OBJCNE(nil, data);
    CIImage* croppedPhotoCIImage = [CIImage imageWithData:data];
    ASSERT_OBJCNE(nil, croppedPhotoCIImage);

    CGImageRef croppedPhoto = [context createCGImage:croppedPhotoCIImage fromRect:[croppedPhotoCIImage extent]];
    ASSERT_NE(nullptr, croppedPhoto);

    CFMutableDataRef originalImageCropped = ObtainJPEGRepresentationFromCGImage(cgImage);
    ASSERT_NE(nullptr, originalImageCropped);

    CFMutableDataRef croppedImage = ObtainJPEGRepresentationFromCGImage(croppedPhoto);
    ASSERT_NE(nullptr, croppedImage);

    ASSERT_TRUE(CFEqual(originalImageCropped, croppedImage));
}
