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

#include "Starboard.h"
#include <StubReturn.h>

#include <UIKit/UIGraphics.h>
#include <UIKit/UIImage.h>

#include "CGImageInternal.h"
#include "CGContextInternal.h"
#include <CoreGraphics/CGGeometry.h>

#include <Foundation/NSString.h>
#include <Foundation/NSMutableDictionary.h>
#include <Foundation/NSBundle.h>

#include "UIImageCachedObject.h"
#include "CALayerInternal.h"
#include "StarboardXaml/DisplayProperties.h"

#include "windows.h"
#include "COMIncludes.h"
#include "Wincodec.h"
#include "COMIncludes_End.h"

#import <MobileCoreServices/UTType.h>
#import <ImageIO/CGImageDestination.h>

#include "LoggingNative.h"
#include <math.h>

@interface UIImage ()
- (CGRect)_imageStretch;
@end

static const wchar_t* TAG = L"UIImage";

CFMutableDictionaryRef g_imageCache;
pthread_mutex_t imageCacheLock = PTHREAD_MUTEX_INITIALIZER;

/**
 @Status Interoperable
*/
void UIImageSetLayerContents(CALayer* layer, UIImage* image) {
    CGImageRef cgImage = (CGImageRef)[image CGImage];
    CGImageRef curImage = (CGImageRef)[layer contents];

    if (cgImage != curImage) {
        [layer setContents:(id)cgImage];
    }
    if ([layer contentsScale] != [image scale]) {
        [layer setContentsScale:[image scale]];
    }
    if ([layer contentsOrientation] != [image imageOrientation]) {
        [layer setContentsOrientation:[image imageOrientation]];
    }

    // Working around #1965; only call '_imageStretch' if 'image' is non-nil
    CGRect stretch = (image ? [image _imageStretch] : CGRectZero);
    if (!CGRectEqualToRect([layer contentsCenter], stretch)) {
        [layer setContentsCenter:stretch];
    }
}

@implementation UIImage {
    CGImageRef m_pImage;
    id _cacheName;
    idretain _cacheImage;
    CGRect _imageStretch;
    UIEdgeInsets _imageInsets;
    float _scale;
    UIImageOrientation _orientation;
    bool _isFromCache;
    uint8_t* out;
    uint8_t** row_pointers;
}

/**
 @Status Stub
*/
+ (BOOL)supportsSecureCoding {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
*/
- (instancetype)initWithCoder:(NSCoder*)decoder {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
*/
- (void)encodeWithCoder:(NSCoder*)encoder {
    UNIMPLEMENTED();
}

+ (UIImageCachedObject*)cacheImage:(UIImage*)image withName:(NSString*)name {
    //  Cache the image
    UIImageCachedObject* obj = [UIImageCachedObject new];
    obj->_scale = image->_scale;
    obj->_imageStretch = image->_imageStretch;
    obj->m_pImage = image->m_pImage;
    CGImageRetain(obj->m_pImage);
    obj->_cacheName = [name copy];
    pthread_mutex_lock(&imageCacheLock);
    [(id)g_imageCache setObject:(id)obj forKey:obj->_cacheName];
    pthread_mutex_unlock(&imageCacheLock);

    return [obj autorelease];
}

static inline CGImageRef getImage(UIImage* uiImage) {
    RETURN_NULL_IF(!uiImage);
    return uiImage->m_pImage;
}

/**
 @Status Interoperable
*/
+ (UIImage*)imageNamed:(NSString*)pathAddr {
    return [self applicationImageNamed:pathAddr];
}

+ (UIImage*)applicationImageNamed:(NSString*)pathAddr {
    UIImage* found = [[UIImage alloc] initWithContentsOfFile:pathAddr];

    if (found == nil) {
        NSData* loadPackagedImage(NSString * name);
        NSData* fileData = loadPackagedImage(pathAddr);
        float scale = 1.f;
        if (strstr([pathAddr UTF8String], "@2x") != NULL)
            scale = 2.0f;
        if (fileData) {
            found = [[UIImage alloc] initWithData:fileData scale:scale];
            if (found) {
                found->_cacheImage = [UIImage cacheImage:found withName:pathAddr];
            }
        }
    }

    return [found autorelease];
}

/**
 @Status Interoperable
*/
+ (UIImage*)imageWithData:(NSData*)data {
    return [[[self alloc] initWithData:data] autorelease];
}

/**
 @Status Interoperable
*/
+ (UIImage*)imageWithData:(NSData*)data scale:(float)scale {
    return [[[self alloc] initWithData:data scale:scale] autorelease];
}

/**
 @Status Caveat
 @Notes Ignores the UIImageRenderingMode passed in and will always be treated as
 the orginal ignoring the template.
*/
- (UIImage*)imageWithRenderingMode:(UIImageRenderingMode)renderingMode {
    return [[[UIImage alloc] _initWithCopyOfImage:self WithRenderingMode:renderingMode] autorelease];
}

/**
 @Status Interoperable
*/
+ (UIImage*)imageWithContentsOfFile:(id)pathAddr {
    return [[[self alloc] initWithContentsOfFile:pathAddr] autorelease];
}

/**
 @Status Interoperable
*/
+ (id)imageWithCGImage:(CGImageRef)image {
    return [[[self alloc] initWithCGImage:image] autorelease];
}

/**
 @Status Interoperable
*/
+ (id)imageWithCGImage:(CGImageRef)image scale:(float)scaleFactor orientation:(UIImageOrientation)orientation {
    return [[[self alloc] initWithCGImage:image scale:scaleFactor orientation:orientation] autorelease];
}

- (instancetype)init {
    if (self = [super init]) {
        _scale = 1.0f;
        _imageStretch.origin.x = 0.0f;
        _imageStretch.origin.y = 0.0f;
        _imageStretch.size.width = 1.0f;
        _imageStretch.size.height = 1.0f;
    }
    return self;
}

/**
 @Status Interoperable
*/
- (instancetype)initWithCGImage:(CGImageRef)image {
    if (!image) {
        [self release];
        return nil;
    }

    if (self = [self init]) {
        m_pImage = image;
        CGImageRetain(image);
    }
    return self;
}

/**
 @Status Interoperable
*/
- (instancetype)initWithCGImage:(CGImageRef)image scale:(float)scale orientation:(UIImageOrientation)orientation {
    if (self = [self initWithCGImage:image]) {
        _scale = scale;
        _orientation = orientation;
    }

    return self;
}

- (instancetype)_initWithCopyOfImage:(UIImage*)imageToCopy WithRenderingMode:(UIImageRenderingMode)renderingMode {
    if (!imageToCopy) {
        [self release];
        return nil;
    }

    if (self = [self initWithCGImage:getImage(imageToCopy)]) {
        _scale = imageToCopy->_scale;
        _orientation = imageToCopy->_orientation;
        _imageInsets = imageToCopy->_imageInsets;
        _imageStretch = imageToCopy->_imageStretch;
        _renderingMode = renderingMode;
    }
    return self;
}

/**
 @Status Interoperable
*/
- (instancetype)initWithContentsOfFile:(NSString*)pathAddr {
    if (!pathAddr) {
        [self release];
        return nil;
    }

    if (self = [self init]) {
        NSBundle* bundle = [NSBundle mainBundle];

        const char* path = (char*)[pathAddr UTF8String];
        bool found = false;
        char* pathStr = NULL;

        if (strlen(path) == 0) {
            TraceVerbose(TAG, L"UIImage: path is blank");
            [self release];
            return nil;
        }

        if (strrchr(path, '.') != NULL && DisplayProperties::ScreenScale() > 1.5f) {
            size_t newStrSize = strlen(path) + 10;
            char* newStr = (char*)malloc(newStrSize);
            const char* pathEnd = strrchr(path, '.');
            memcpy(newStr, path, pathEnd - path);
            newStr[pathEnd - path] = 0;
            strcat_s(newStr, newStrSize, "@2x");
            strcat_s(newStr, newStrSize, pathEnd);

            pathStr = _strdup(newStr);

            if (EbrAccess(pathStr, 0) == -1) {
                id pathFind =
                    [bundle pathForResource:[NSString stringWithUTF8String:newStr] ofType:nil inDirectory:nil forLocalization:@"English"];

                if (pathFind != nil) {
                    path = (char*)[pathFind UTF8String];
                    if (pathStr) {
                        free(pathStr);
                    }
                    pathStr = _strdup(path);
                    found = true;
                }
            } else {
                found = true;
            }
            free(newStr);
        }

        if (!found) {
            if (pathStr) {
                free(pathStr);
            }
            pathStr = _strdup(path);

            if (EbrAccess(pathStr, 0) == -1) {
                NSString* pathFind = [bundle pathForResource:pathAddr ofType:nil inDirectory:nil forLocalization:@"English"];

                if (pathFind != nil) {
                    path = [pathFind UTF8String];
                    if (pathStr) {
                        free(pathStr);
                    }
                    pathStr = _strdup(path);
                }
            }
        }
        if (!found && DisplayProperties::ScreenScale() > 1.5f) {
            NSString* _2x = [pathAddr stringByAppendingString:@"@2x"];

            NSString* pathFind = [bundle pathForResource:_2x ofType:@"png" inDirectory:nil forLocalization:@"English"];

            if (pathFind != nil) {
                path = [pathFind UTF8String];
                if (pathStr) {
                    free(pathStr);
                }
                pathStr = _strdup(path);
                found = true;
            } else {
                pathFind = [bundle pathForResource:pathAddr ofType:@"png" inDirectory:nil forLocalization:@"English"];

                if (pathFind != nil) {
                    path = [pathFind UTF8String];
                    if (pathStr) {
                        free(pathStr);
                    }
                    pathStr = _strdup(path);
                    found = true;
                }
            }
        }

        pthread_mutex_lock(&imageCacheLock);
        //  Check if it's already loaded
        if (!g_imageCache) {
            g_imageCache = CFDictionaryCreateMutable(NULL, 10, &kCFTypeDictionaryKeyCallBacks, NULL);
        }

        const UIImageCachedObject* cachedImage =
            reinterpret_cast<const UIImageCachedObject*>(CFDictionaryGetValue(g_imageCache, [NSString stringWithUTF8String:pathStr]));

        if (cachedImage) {
            if (pathStr) {
                free(pathStr);
            }
            m_pImage = cachedImage->m_pImage;
            _cacheImage = cachedImage;
            CGImageRetain(m_pImage);
            _scale = cachedImage->_scale;
            _imageStretch = cachedImage->_imageStretch;
            _isFromCache = true;
            pthread_mutex_unlock(&imageCacheLock);
            return self;
        }
        pthread_mutex_unlock(&imageCacheLock);

        NSData* inData = [NSData dataWithContentsOfFile:[NSString stringWithUTF8String:pathStr]];
        if (!inData) {
            [self release];
            return nil;
        }

        m_pImage = _CGImageGetImageFromData((void*)[inData bytes], [inData length]);

        if (!m_pImage) {
            [self release];
            return nil;
        }

        if (strstr(pathStr, "@2x") != NULL) {
            _scale = 2.0f;
        }

        _imageStretch.origin.x = 0.0f;
        _imageStretch.origin.y = 0.0f;
        _imageStretch.size.width = 1.0f;
        _imageStretch.size.height = 1.0f;

        //  Cache the image
        _cacheImage = [UIImage cacheImage:self withName:[NSString stringWithUTF8String:pathStr]];

        if (pathStr) {
            free(pathStr);
        }
    }
    return self;
}

/**
 @Status Interoperable
*/
- (instancetype)initWithData:(NSData*)data {
    return [self initWithData:data scale:1.0];
}

/**
 @Status Interoperable
*/
- (instancetype)initWithData:(NSData*)data scale:(float)scale {
    if (!data) {
        [self release];
        return nil;
    }

    if (self = [self init]) {
        _scale = scale;

        if ([data length] == 0) {
            [self release];
            return nil;
        }

        m_pImage = _CGImageGetImageFromData((void*)[data bytes], [data length]);
        if (!m_pImage) {
            [self release];
            return nil;
        }
    }
    return self;
}

- (void)draw1PartImageInRect:(CGRect)pos {
    TraceVerbose(TAG, L"UIImage::draw1PartImageInRect");

    CGContextRef cur = UIGraphicsGetCurrentContext();

    CGRect srcRect;

    srcRect.origin.x = 0;
    srcRect.origin.y = float(CGImageGetWidth(getImage(self)));
    srcRect.size.width = pos.size.width;
    srcRect.size.height = -pos.size.height;

    _CGContextDrawImageRect(cur, getImage(self), srcRect, pos);
}

/**
 @Status Interoperable
*/
- (void)drawAtPoint:(CGPoint)point {
    [self drawAtPoint:point blendMode:kCGBlendModeNormal alpha:1.0f];
}

/**
 @Status Interoperable
*/
- (void)drawAtPoint:(CGPoint)point blendMode:(CGBlendMode)mode alpha:(float)alpha {
    CGContextRef cur = UIGraphicsGetCurrentContext();
    RETURN_IF(!cur);

    CGImageRef img = getImage(self);
    RETURN_IF(!img);

    CGContextSaveGState(cur);
    _CGContextPushBeginDraw(cur);

    auto popEnd = wil::ScopeExit([cur]() {
        _CGContextPopEndDraw(cur);
        CGContextRestoreGState(cur);
    });

    CGContextSetBlendMode(cur, mode);
    CGContextSetAlpha(cur, alpha);

    float img_height = CGImageGetHeight(img);
    float img_width = CGImageGetWidth(img);

    CGRect pos;
    pos.origin = point;
    pos.size.height = (img_height / _scale);
    pos.size.width = (img_width / _scale);

    // |1  0 0| is the transformation matrix for flipping a rect about its Y midpoint m. (m = (y + h/2))
    // |0 -1 0|
    // |0 2m 1|
    CGContextConcatCTM(cur, CGAffineTransformMake(1, 0, 0, -1, 0, 2 * (pos.origin.y + (pos.size.height / 2))));

    CGContextDrawImage(cur, pos, img);
}

/**
 @Status Interoperable
*/
- (void)drawAsPatternInRect:(CGRect)pos {
    [self drawAtPoint:pos.origin];
}

static inline void drawPatches(CGContextRef context, UIImage* img, CGRect* dst) {
    // Note: Subdivides image into 1-9 patches which are drawn individually and
    // the number of
    // subdivisions depends on what insets have been set.

    // Note: Since source image has a TL origin (UIKit) and destination image has
    // BL origin (QuartzCore) by default and there may be a
    // custom transform applied to the GFX context, we need to at the very least
    // ensure images are sampledFrom and writtenTo the right
    // location for each pixel.
    // Thus, the patch rects are constructed according to their default origin and
    // the sign of the rect height indicates the sampling Y
    // direction
    // relative to its the origin. Any custom transforms applied to the GFX
    // context are handled in the underlying draw function.

    RETURN_IF(!img);

    CGImageRef cgImg = getImage(img);
    RETURN_IF(!cgImg);

    const float srcHeight = static_cast<float>(CGImageGetHeight(cgImg));
    const float srcWidth = static_cast<float>(CGImageGetWidth(cgImg));
    const float srcTopCap = img->_imageInsets.top * img->_scale;
    const float srcBotCap = img->_imageInsets.bottom * img->_scale;
    const float srcLeftCap = img->_imageInsets.left * img->_scale;
    const float srcRightCap = img->_imageInsets.right * img->_scale;

    const float dstHeight = dst->size.height;
    const float dstWidth = dst->size.width;
    const float dstX = dst->origin.x;
    const float dstY = dst->origin.y;
    const float dstTopCap = img->_imageInsets.top;
    const float dstBotCap = img->_imageInsets.bottom;
    const float dstLeftCap = img->_imageInsets.left;
    const float dstRightCap = img->_imageInsets.right;

    // |1  0 0| is the transformation matrix for flipping a rect about its Y midpoint m. (m = (y + h/2))
    // |0 -1 0|
    // |0 2m 1|
    CGContextConcatCTM(context, CGAffineTransformMake(1, 0, 0, -1, 0, 2 * (dstY + (dstHeight / 2))));

    // Center strip
    if (dstHeight - dstTopCap - dstBotCap > 0) {
        if (dstLeftCap) {
            // MidHeightLeft
            _CGContextDrawImageRect(context,
                                    cgImg,
                                    CGRectMake(0, srcHeight - srcBotCap, srcLeftCap, -(srcHeight - srcTopCap - srcBotCap)),
                                    CGRectMake(dstX, (dstY + dstBotCap), dstLeftCap, (dstHeight - dstTopCap - dstBotCap)));
        }

        if (dstWidth - dstLeftCap - dstRightCap > 0) {
            // MidHeightMidWidth
            _CGContextDrawImageRect(context,
                                    cgImg,
                                    CGRectMake(srcLeftCap,
                                               srcHeight - srcBotCap,
                                               (srcWidth - srcLeftCap - srcRightCap),
                                               -(srcHeight - srcTopCap - srcBotCap)),
                                    CGRectMake((dstX + dstLeftCap),
                                               (dstY + dstBotCap),
                                               (dstWidth - dstLeftCap - dstRightCap),
                                               (dstHeight - dstTopCap - dstBotCap)));
        } else {
            UNIMPLEMENTED_WITH_MSG(
                "Patched draws only supported when sum of "
                "dstLeftCap and dstRightCap is less than the "
                "width of the UI element.");
        }

        if (dstRightCap) {
            // MidHeightRight
            _CGContextDrawImageRect(
                context,
                cgImg,
                CGRectMake((srcWidth - srcRightCap), srcHeight - srcBotCap, srcRightCap, -(srcHeight - srcTopCap - srcBotCap)),
                CGRectMake((dstX + dstWidth - dstRightCap), (dstY + dstBotCap), dstRightCap, (dstHeight - dstTopCap - dstBotCap)));
        }
    } else {
        UNIMPLEMENTED_WITH_MSG(
            "Patched draws only supported when sum of dstTopCap "
            "and dstBotCap is less than the height of the UI "
            "element.");
    }

    if (dstTopCap) {
        if (dstLeftCap) {
            // TL corner
            _CGContextDrawImageRect(context,
                                    cgImg,
                                    CGRectMake(0, srcTopCap, srcLeftCap, -srcTopCap),
                                    CGRectMake(dstX, (dstY + dstHeight - dstTopCap), dstLeftCap, dstTopCap));
        }

        if (dstWidth - dstLeftCap - dstRightCap > 0) {
            // TCenter
            _CGContextDrawImageRect(context,
                                    cgImg,
                                    CGRectMake(srcLeftCap, srcTopCap, (srcWidth - srcLeftCap - srcRightCap), -srcTopCap),
                                    CGRectMake((dstX + dstLeftCap),
                                               (dstY + dstHeight - dstTopCap),
                                               (dstWidth - dstLeftCap - dstRightCap),
                                               dstTopCap));
        }

        if (dstRightCap) {
            // TR corner
            _CGContextDrawImageRect(context,
                                    cgImg,
                                    CGRectMake((srcWidth - srcRightCap), srcTopCap, srcRightCap, -srcTopCap),
                                    CGRectMake((dstX + dstWidth - dstRightCap), (dstY + dstHeight - dstTopCap), dstRightCap, dstTopCap));
        }
    }

    if (dstBotCap) {
        if (dstLeftCap) {
            // BL Corner
            _CGContextDrawImageRect(context,
                                    cgImg,
                                    CGRectMake(0, srcHeight, srcLeftCap, -srcBotCap),
                                    CGRectMake(dstX, dstY, dstLeftCap, dstBotCap));
        }

        if (dstWidth - dstLeftCap - dstRightCap > 0) {
            // bottomMidWidth
            _CGContextDrawImageRect(context,
                                    cgImg,
                                    CGRectMake(srcLeftCap, srcHeight, (srcWidth - srcLeftCap - srcRightCap), -srcBotCap),
                                    CGRectMake((dstX + dstLeftCap), dstY, (dstWidth - dstLeftCap - dstRightCap), dstBotCap));
        }

        if (dstRightCap) {
            _CGContextDrawImageRect(context,
                                    cgImg,
                                    CGRectMake((srcWidth - srcRightCap), srcHeight, srcRightCap, -srcBotCap),
                                    CGRectMake((dstX + dstWidth - dstRightCap), dstY, dstRightCap, dstBotCap));
        }
    }
}

/**
 @Status Interoperable
*/
- (UIEdgeInsets)capInsets {
    return _imageInsets;
}

/**
 @Status Interoperable
*/
- (void)drawInRect:(CGRect)pos {
    [self drawInRect:pos blendMode:kCGBlendModeNormal alpha:1.0f];
}

/**
 @Status Interoperable
*/
- (void)drawInRect:(CGRect)pos blendMode:(CGBlendMode)mode alpha:(float)alpha {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGImageRef img = getImage(self);

    if (img == NULL) {
        TraceWarning(TAG, L"m_pImage = NULL!");
        return;
    }

    if (_scale == 0.0f) {
        TraceWarning(TAG, L"Scale should be non-zero!");
        return;
    }

    CGContextSaveGState(ctx);
    _CGContextPushBeginDraw(ctx);

    auto popEnd = wil::ScopeExit([ctx]() {
        _CGContextPopEndDraw(ctx);
        CGContextRestoreGState(ctx);
    });

    CGContextSetBlendMode(ctx, mode);
    CGContextSetAlpha(ctx, alpha);

    // Draw image and divide into patches if necessary
    drawPatches(ctx, self, &pos);
}

- (void)setOrientation:(UIImageOrientation)orientation {
    _orientation = orientation;
}

/**
 @Status Interoperable
*/
- (CGSize)size {
    CGSize size;
    CGImageRef image = getImage(self);

    if (image) {
        size.width = float(CGImageGetWidth(image));
        size.height = float(CGImageGetHeight(image));

        if (_scale > 0.0f) {
            size.width /= _scale;
            size.height /= _scale;
        }
    } else {
        size.width = 0;
        size.height = 0;
    }

    return size;
}

/**
 @Status Interoperable
*/
- (CGRect)_imageStretch {
    return _imageStretch;
}

- (CGImageRef)imageRef {
    return getImage(self);
}

/**
 @Status Interoperable
*/
- (CGImageRef)CGImage {
    return getImage(self);
}

/**
 @Status Interoperable
*/
- (UIImageOrientation)imageOrientation {
    return _orientation;
}

/**
 @Status Interoperable
*/
- (int)leftCapWidth {
    return (int)_imageInsets.left;
}

/**
 @Status Interoperable
*/
- (int)topCapHeight {
    return (int)_imageInsets.top;
}

/**
 @Status Interoperable
*/
- (UIImage*)stretchableImageWithLeftCapWidth:(int)leftCap topCapHeight:(int)topCap {
    UIImage* ret = [UIImage imageWithCGImage:getImage(self) scale:_scale orientation:_orientation];
    ret->_imageInsets.left = float(leftCap);
    ret->_imageInsets.top = float(topCap);

    CGSize imgSize = [self size];
    if (leftCap != 0) {
        ret->_imageStretch.origin.x = leftCap / imgSize.width;
        ret->_imageStretch.size.width = 1.0f / imgSize.width;
        if (leftCap < imgSize.width) {
            // As per UIImage documentation, left/top caps create cap insets with a
            // center section of 1x1 logical pixels
            ret->_imageInsets.right = imgSize.width - (ret->_imageInsets.left + 1);
        }
    }
    if (topCap != 0) {
        ret->_imageStretch.origin.y = topCap / imgSize.height;
        ret->_imageStretch.size.height = 1.0f / imgSize.height;
        if (topCap < imgSize.height) {
            ret->_imageInsets.bottom = imgSize.height - (ret->_imageInsets.top + 1);
        }
    }

    return ret;
}

/**
 @Status Interoperable
*/
- (UIImage*)resizableImageWithCapInsets:(UIEdgeInsets)insets {
    UIImage* ret = [UIImage imageWithCGImage:getImage(self) scale:_scale orientation:_orientation];
    ret->_imageInsets.left = 0;
    ret->_imageInsets.top = 0;

    CGSize imgSize = [self size];

    ret->_imageStretch.origin.x = insets.left / imgSize.width;
    ret->_imageStretch.origin.y = insets.top / imgSize.width;
    ret->_imageStretch.size.width = (imgSize.width - (insets.left + insets.right + 1)) / imgSize.width;
    ret->_imageStretch.size.height = (imgSize.height - (insets.top + insets.bottom + 1)) / imgSize.height;
    ret->_imageInsets = insets;

    return ret;
}

/**
 @Status Caveat
 @Notes resizeMode not supported
*/
- (UIImage*)resizableImageWithCapInsets:(UIEdgeInsets)insets resizingMode:(unsigned)resizeMode {
    UIImage* ret = [UIImage imageWithCGImage:getImage(self) scale:_scale orientation:_orientation];

    ret->_imageInsets.left = 0;
    ret->_imageInsets.top = 0;

    CGSize imgSize = [self size];

    ret->_imageStretch.origin.x = insets.left / imgSize.width;
    ret->_imageStretch.origin.y = insets.top / imgSize.width;
    ret->_imageStretch.size.width = (imgSize.width - (insets.left + insets.right + 1)) / imgSize.width;
    ret->_imageStretch.size.height = (imgSize.height - (insets.top + insets.bottom + 1)) / imgSize.height;

    ret->_imageInsets = insets;

    return ret;
}

/**
 @Status Interoperable
*/
- (void)dealloc {
    if (m_pImage) {
        CGImageRelease(m_pImage);
    }

    [super dealloc];
}

/**
 @Status Interoperable
*/
- (float)scale {
    return _scale;
}

- (void)_setScale:(float)scale {
    _scale = scale;
}

- (instancetype)copyWithZone:(NSZone*)zone {
    return [self retain];
}

/**
 @Status Stub
*/
- (NSArray*)images {
    UNIMPLEMENTED();
    return nil;
}

/**
 @Status Stub
*/
- (UIImage*)imageFlippedForRightToLeftLayoutDirection {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
*/
- (UIImage*)imageWithAlignmentRectInsets:(UIEdgeInsets)alignmentInsets {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
*/
+ (UIImage*)animatedImageNamed:(NSString*)name duration:(NSTimeInterval)duration {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
*/
+ (UIImage*)animatedImageWithImages:(NSArray*)images duration:(NSTimeInterval)duration {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
*/
+ (UIImage*)animatedResizableImageNamed:(NSString*)name capInsets:(UIEdgeInsets)capInsets duration:(NSTimeInterval)duration {
    UNIMPLEMENTED();
    return StubReturn();
}

static NSData* _ObtainImageRepresentation(UIImage* img, CFStringRef type, NSDictionary* properties) {
    RETURN_NULL_IF(!img);
    CFMutableDataRef cfData = CFDataCreateMutable(nullptr, 0);
    CFAutorelease(cfData);
    CGImageDestinationRef destination = CGImageDestinationCreateWithData(cfData, type, 1, nullptr);
    CFAutorelease(destination);
    CGImageDestinationAddImage(destination, getImage(img), static_cast<CFDictionaryRef>(properties));
    if (!CGImageDestinationFinalize(destination)) {
        return nil;
    }
    return static_cast<NSData*>(cfData);
}

/**
 @Status Interoperable
*/
NSData* UIImagePNGRepresentation(UIImage* img) {
    RETURN_NULL_IF(!img);
    return _ObtainImageRepresentation(img, kUTTypePNG, nil);
}

/**
 @Status Interoperable
*/
NSData* UIImageJPEGRepresentation(UIImage* img, CGFloat quality) {
    RETURN_NULL_IF(!img);
    NSDictionary* properties = [NSDictionary dictionaryWithObjectsAndKeys:@(quality), kCGImageDestinationLossyCompressionQuality, nil];
    return _ObtainImageRepresentation(img, kUTTypeJPEG, properties);
}

/**
 @Status Stub
*/
+ (UIImage*)animatedResizableImageNamed:(NSString*)name
                              capInsets:(UIEdgeInsets)capInsets
                           resizingMode:(UIImageResizingMode)resizingMode
                               duration:(NSTimeInterval)duration {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
*/
+ (UIImage*)imageNamed:(NSString*)name inBundle:(NSBundle*)bundle compatibleWithTraitCollection:(UITraitCollection*)traitCollection {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
*/
+ (UIImage*)imageWithCIImage:(CIImage*)ciImage scale:(CGFloat)scale orientation:(UIImageOrientation)orientation {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
*/
+ (UIImage*)imageWithCIImage:(CIImage*)ciImage {
    UNIMPLEMENTED();
    return StubReturn();
}

@end
