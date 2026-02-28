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

#import <StubReturn.h>
#import <CoreImage/CIContext.h>

#import <Starboard.h>
#import "CIImageInternal.h"

NSString* const kCIContextOutputColorSpace = @"kCIContextOutputColorSpace";
NSString* const kCIContextWorkingColorSpace = @"kCIContextWorkingColorSpace";
NSString* const kCIContextUseSoftwareRenderer = @"kCIContextUseSoftwareRenderer";
NSString* const kCIContextPriorityRequestLow = @"kCIContextPriorityRequestLow";
NSString* const kCIContextWorkingFormat = @"kCIContextWorkingFormat";

@implementation CIContext {
    CGContextRef _cgContext;
    CGRect _rect;
}

/**
 @Status Interoperable
*/
- (instancetype)init {
    if (self = [super init]) {
        _cgContext = nullptr;
        _rect = CGRectInfinite;
    }
    return self;
}

/**
 @Status Stub
 @Notes
*/
+ (CIContext*)contextWithCGContext:(CGContextRef)ctx options:(NSDictionary*)dict {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
+ (CIContext*)contextWithEAGLContext:(EAGLContext*)eaglContext {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
+ (CIContext*)contextWithEAGLContext:(EAGLContext*)eaglContext options:(NSDictionary*)options {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Caveat
 @Notes parameter dict is ignored.
*/
+ (CIContext*)contextWithOptions:(NSDictionary*)dict {
    return [[CIContext alloc] init];
}

/**
 @Status Stub
 @Notes
*/
+ (CIContext*)contextWithMTLDevice:(id<MTLDevice>)device {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
+ (CIContext*)contextWithMTLDevice:(id<MTLDevice>)device options:(NSDictionary*)options {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Caveat
 @Notes The options on CIContext are ignored.
*/
- (CGImageRef)createCGImage:(CIImage*)im fromRect:(CGRect)r {
    return static_cast<CGImageRef>([im _CGImageFromRect:r]);
}

/**
 @Status Stub
 @Notes
*/
- (CGImageRef)createCGImage:(CIImage*)im fromRect:(CGRect)r format:(CIFormat)f colorSpace:(CGColorSpaceRef)cs {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
- (void)drawImage:(CIImage*)im atPoint:(CGPoint)p fromRect:(CGRect)src {
    UNIMPLEMENTED();
}

/**
 @Status Stub
 @Notes
*/
- (void)drawImage:(CIImage*)im inRect:(CGRect)dest fromRect:(CGRect)src {
    UNIMPLEMENTED();
}

/**
 @Status Stub
 @Notes
*/
- (void)render:(CIImage*)im toBitmap:(void*)data rowBytes:(ptrdiff_t)rb bounds:(CGRect)r format:(CIFormat)f colorSpace:(CGColorSpaceRef)cs {
    UNIMPLEMENTED();
}

/**
 @Status Stub
 @Notes
*/
- (void)render:(CIImage*)image toCVPixelBuffer:(CVPixelBufferRef)buffer {
    UNIMPLEMENTED();
}

/**
 @Status Stub
 @Notes
*/
- (void)render:(CIImage*)image toCVPixelBuffer:(CVPixelBufferRef)buffer bounds:(CGRect)r colorSpace:(CGColorSpaceRef)cs {
    UNIMPLEMENTED();
}

/**
 @Status Stub
 @Notes
*/
- (void)render:(CIImage*)image
     toMTLTexture:(id<MTLTexture>)texture
    commandBuffer:(id<MTLCommandBuffer>)commandBuffer
           bounds:(CGRect)bounds
       colorSpace:(CGColorSpaceRef)colorSpace {
    UNIMPLEMENTED();
}

/**
 @Status Stub
 @Notes
*/
- (CGSize)inputImageMaximumSize {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
- (CGSize)outputImageMaximumSize {
    UNIMPLEMENTED();
    return StubReturn();
}

@end
