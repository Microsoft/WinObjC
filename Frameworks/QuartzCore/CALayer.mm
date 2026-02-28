//******************************************************************************
//
// Copyright (c) 2016 Intel Corporation. All rights reserved.
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
#import <math.h>
#import "CoreGraphics/CGContext.h"
#import "CGContextInternal.h"
#import "CGImageInternal.h"
#import "CGIWICBitmap.h"
#import <CoreGraphics/D2DWrapper.h>

#import "Foundation/NSMutableArray.h"
#import "Foundation/NSMutableDictionary.h"
#import "Foundation/NSNumber.h"
#import "Foundation/NSValue.h"
#import "Foundation/NSNull.h"

#import <UIKit/UIApplication.h>
#import "CGColorInternal.h"
#import "UIKit/NSValue+UIKitAdditions.h"

#import "QuartzCore/CALayer.h"
#import "QuartzCore/CATransaction.h"
#import "QuartzCore/CAEAGLLayer.h"
#import "CAEAGLLayerInternal.h"

#import "CACompositor.h"
#import "CAAnimationInternal.h"
#import "CABasicAnimationInternal.h"
#import "CATransactionInternal.h"
#import "Quaternion.h"

#import "LoggingNative.h"
#import "NSLogging.h"
#import "CALayerInternal.h"
#import "CppWinRTHelpers.h"

#import <objc/objc-arc.h>

#include <COMIncludes.h>
#import <WRLHelpers.h>
#import <ErrorHandling.h>
#import <wrl/client.h>
#import <wrl/implements.h>
#import <winrt/Windows.Foundation.h>
#import <winrt/Windows.UI.Xaml.h>
#import <winrt/Windows.UI.Xaml.Controls.h>
#import <winrt/Windows.UI.Xaml.Media.h>
#import <Windows.UI.Xaml.h>
#include <COMIncludes_End.h>

using namespace winrt::Windows::UI::Xaml;

static const wchar_t* TAG = L"CALayer";

static const bool DEBUG_ALL = false;
static const bool DEBUG_VERBOSE = DEBUG_ALL || false;
static const bool DEBUG_DRAWING = DEBUG_VERBOSE || false;

static const int c_windowsDPI = 96;

NSString* const kCAOnOrderIn = @"kCAOnOrderIn";
NSString* const kCAOnOrderOut = @"kCAOnOrderOut";
NSString* const kCATransition = @"kCATransition";
NSString* const kCAGravityCenter = @"kCAGravityCenter";
NSString* const kCAGravityTop = @"kCAGravityTop";
NSString* const kCAGravityBottom = @"kCAGravityBottom";
NSString* const kCAGravityLeft = @"kCAGravityLeft";
NSString* const kCAGravityRight = @"kCAGravityRight";
NSString* const kCAGravityTopLeft = @"kCAGravityTopLeft";
NSString* const kCAGravityTopRight = @"kCAGravityTopRight";
NSString* const kCAGravityBottomLeft = @"kCAGravityBottomLeft";
NSString* const kCAGravityBottomRight = @"kCAGravityBottomRight";
NSString* const kCAGravityResize = @"kCAGravityResize";
NSString* const kCAGravityResizeAspect = @"kCAGravityResizeAspect";
NSString* const kCAGravityResizeAspectFill = @"kCAGravityResizeAspectFill";
NSString* const kCAFilterLinear = @"kCAFilterLinear";
NSString* const kCAFilterNearest = @"kCAFilterNearest";
NSString* const kCAFilterTrilinear = @"kCAFilterTrilinear";

// The number of rendering attempts a CALayer will make when
// its backing device disappears.
static const unsigned int _kCALayerRenderAttempts = 3;

@interface CALayer () {
@public
    CAPrivateInfo* priv;
}
@end

// FIXME(DH): Compatibility shim to avoid rewriting parts of CA for libobjc2.
// VSO 6149838
static BOOL object_isMethodFromClass(id object, SEL selector, const char* className) {
    return class_getMethodImplementation(objc_getClass(className), selector) ==
           class_getMethodImplementation(object_getClass(object), selector);
}

@interface NSValue (CATransform3D)
// This is defined in Foundation/NSValue.mm
- (NSValue*)initWithCATransform3D:(CATransform3D)val;
@end

NSString* _opacityAction = @"opacity";
NSString* _positionAction = @"position";
NSString* _boundsAction = @"bounds";
NSString* _transformAction = @"transform";
NSString* _orderInAction = @"onOrderIn";
NSString* _orderOutAction = @"orderOut";

enum Gravity {
    kGravityResize = 0,
    kGravityCenter = 1,
    kGravityTop = 2,
    kGravityResizeAspect = 3,
    kGravityTopLeft = 4,
    kGravityBottomLeft = 5,
    kGravityLeft = 6,
    kGravityAspectFill = 7,
    kGravityBottom = 8,
    kGravityTopRight = 9,
    kGravityRight = 10,
    kGravityBottomRight = 11
};

CACompositorInterface* _globalCompositor;

template <class T>
class NodeList {
public:
    T** items;
    int count;
    int max;
    int curPos;

    NodeList() {
        items = NULL;
        count = 0;
        max = 0;
        curPos = 0;
    }

    ~NodeList() {
        if (items) {
            free(items);
        }
    }

    inline void AddNode(T* item) {
        if (count + 1 > max) {
            max += 64;
            items = (T**)realloc(items, max * sizeof(T*));
        }
        items[count++] = item;
    }
};

static void GetNeededLayouts(CAPrivateInfo* state, NodeList<CAPrivateInfo>* list) {
    CAPrivateInfo* cur = state;
    if (cur->needsLayout) {
        list->AddNode(cur);
    }

    cur = cur->lastChild;
    while (cur) {
        GetNeededLayouts(cur, list);
        cur = cur->prevSibling;
    }
}

void DoLayerLayouts(CALayer* window) {
    NodeList<CAPrivateInfo> list;
    for (;;) {
        GetNeededLayouts(window->priv, &list);

        if (list.curPos == list.count) {
            break;
        }
        while (list.curPos < list.count) {
            list.items[list.curPos]->needsLayout = FALSE;
            list.items[list.curPos]->didLayout = TRUE;
            [list.items[list.curPos]->self layoutSublayers];
            list.curPos++;
        }
    }

    for (int i = 0; i < list.count; i++) {
        list.items[i]->didLayout = FALSE;
    }
}

static void GetNeededDisplays(CAPrivateInfo* state, NodeList<CAPrivateInfo>* list) {
    CAPrivateInfo* cur = state;
    if (cur->needsDisplay) {
        list->AddNode(cur);
    }

    cur = cur->lastChild;
    while (cur) {
        GetNeededDisplays(cur, list);
        cur = cur->prevSibling;
    }
}

static void DoDisplayList(CALayer* layer) {
    NodeList<CAPrivateInfo> list;
    GetNeededDisplays(layer->priv, &list);

    while (list.curPos < list.count) {
        CAPrivateInfo* cur = list.items[list.curPos];

        if (cur->delegate) {
            if (DEBUG_VERBOSE) {
                TraceVerbose(TAG, L"Getting new texture for %hs", object_getClassName(cur->delegate));
            }
        }

        std::shared_ptr<IDisplayTexture> newTexture = [cur->self _getDisplayTexture];
        cur->needsDisplay = FALSE;

        // Set the new (or null) display texture on the layer proxy backing this layer
        [CATransaction _currentLayerTransaction]->SetLayerTexture(cur->_layerProxy, newTexture, cur->contentsSize, cur->contentsScale);

        [cur->self _displayChanged];

        list.curPos++;
    }
}

CAPrivateInfo::CAPrivateInfo(CALayer* self, const FrameworkElement& xamlElement) : _xamlElement(nullptr), _sublayerXamlElement(nullptr) {
    memset(this, 0, sizeof(CAPrivateInfo));
    setSelf(self);

    memset(&bounds, 0, sizeof(bounds));
    memset(&position, 0, sizeof(position));

    anchorPoint.x = 0.5f;
    anchorPoint.y = 0.5f;

    _animations = nil;

    contentsRect.origin.x = 0.0f;
    contentsRect.origin.y = 0.0f;
    contentsRect.size.width = 1.0f;
    contentsRect.size.height = 1.0f;

    contentsCenter.origin.x = 0.0f;
    contentsCenter.origin.y = 0.0f;
    contentsCenter.size.width = 1.0f;
    contentsCenter.size.height = 1.0f;

    contentsScale = 1.0f;

    superlayer = nil;
    opacity = 1.0f;
    hidden = FALSE;
    gravity = kGravityResize;
    contents = nullptr;
    ownsContents = FALSE;
    savedContext = NULL;
    isOpaque = FALSE;
    delegate = nil;
    needsDisplay = TRUE;
    needsUpdate = FALSE;
    backgroundColor.r = 0.0f;
    backgroundColor.g = 0.0f;
    backgroundColor.b = 0.0f;
    backgroundColor.a = 0.0f;
    _backgroundColor = nullptr;
    transform = CATransform3DMakeTranslation(0, 0, 0);
    masksToBounds = FALSE;
    isRootLayer = FALSE;
    needsDisplayOnBoundsChange = FALSE;
    _name = nil;

    // Create our backing layer proxy
    _layerProxy = GetCACompositor()->CreateLayerProxy(objcwinrt::to_insp(xamlElement));

    // Query for our backing XAML node.
    // ILayerProxy will have created one if the xamlElement passed into the previous CreateLayerProxy call was nullptr.
    Microsoft::WRL::ComPtr<IInspectable> inspectable(_layerProxy->GetXamlElement());
    _xamlElement = objcwinrt::from_insp<FrameworkElement>(inspectable);
}

CAPrivateInfo::~CAPrivateInfo() {
    _undefinedKeys = nil;
    _actions = nil;
    CGColorRelease(_backgroundColor);
    _name = nil;
    if (_animations) {
        [_animations release];
    }
    if (contents) {
        CGImageRelease(contents);
    }
    if (savedContext) {
        CGContextRelease(savedContext);
    }
}

CGContextRef CreateLayerContentsBitmapContext32(int width, int height, float scale) {
    if ([NSThread isMainThread]) {
        std::shared_ptr<IDisplayTexture> texture = GetCACompositor()->CreateDisplayTexture(width, height);

        Microsoft::WRL::ComPtr<IWICBitmap> customWICBtmap =
            Microsoft::WRL::Make<CGIWICBitmap>(texture, GUID_WICPixelFormat32bppPBGRA, height, width);
        // We want to convert it to GUID_WICPixelFormat32bppPBGRA for D2D Render Target compatibility.
        woc::unique_cf<CGImageRef> image(_CGImageCreateWithWICBitmap(customWICBtmap.Get()));

        Microsoft::WRL::ComPtr<ID2D1Factory> factory;
        RETURN_NULL_IF_FAILED(_CGGetD2DFactory(&factory));

        Microsoft::WRL::ComPtr<ID2D1RenderTarget> renderTarget;
        RETURN_NULL_IF_FAILED(factory->CreateWicBitmapRenderTarget(customWICBtmap.Get(), D2D1::RenderTargetProperties(), &renderTarget));
        renderTarget->SetDpi(c_windowsDPI * scale, c_windowsDPI * scale);

        CGContextRef context = _CGBitmapContextCreateWithRenderTarget(renderTarget.Get(), image.get(), GUID_WICPixelFormat32bppPBGRA);
        CGContextIwEnableEnhancedErrorHandling(context);
        return context;
    }

    return nullptr;
}

@implementation CALayer

/**
 @Status Interoperable
*/
- (instancetype)init {
    return [self _initWithXamlElement:nullptr];
}

/**
 Microsoft Extension
 All CALayers are ultimately backed by a Xaml FrameworkElement.  Passing nil here will
 result in the default Xaml FrameworkElement type being used.
*/
- (instancetype)_initWithXamlElement:(const FrameworkElement&)xamlElement {
    assert(!priv);
    priv = new CAPrivateInfo(self, xamlElement);
    return self;
}

/**
 Microsoft Extension
 Retrieves the XAML FrameworkElement backing this CALayer.
*/
- (FrameworkElement)_xamlElement {
    return priv->_xamlElement;
}

- (CAPrivateInfo*)_priv {
    return priv;
}

- (bool)_isVisibleOrHitable {
    if (priv->hidden || priv->opacity <= 0.01f) {
        return NO;
    }
    return YES;
}

/**
 @Status Interoperable
*/
- (void)setNeedsDisplay {
    priv->needsDisplay = TRUE;
    [self _displayChanged];
}

/**
 @Status Interoperable
*/
- (void)displayIfNeeded {
    if (priv->needsDisplay) {
        priv->needsDisplay = FALSE;
        [self display];
    }
}

/**
 @Status Caveat
 @Notes transform properties not supported
*/
- (void)renderInContext:(CGContextRef)ctx {
    // if calayer is hidden or opacity is 0 do not render it.
    if (![self _isVisibleOrHitable]) {
        return;
    }

    [self layoutIfNeeded];

    CGContextSaveGState(ctx);
    _CGContextPushBeginDraw(ctx);

    auto popEnd = wil::ScopeExit([ctx]() {
        _CGContextPopEndDraw(ctx);
        CGContextRestoreGState(ctx);
    });

    CGContextTranslateCTM(ctx, priv->position.x, priv->position.y);
    CGContextTranslateCTM(ctx, -priv->bounds.size.width * priv->anchorPoint.x, -priv->bounds.size.height * priv->anchorPoint.y);
    CGRect destRect;

    destRect.origin.x = 0;
    destRect.origin.y = 0;
    destRect.size.width = priv->bounds.size.width;
    destRect.size.height = priv->bounds.size.height;

    if (priv->masksToBounds) {
        CGContextClipToRect(ctx, destRect);
    }
    if (priv->contents == NULL) {
        if ([priv->delegate respondsToSelector:@selector(displayLayer:)]) {
            [priv->delegate displayLayer:self];
        }
    }

    if (priv->contents == NULL) {
        if (priv->_backgroundColor != nullptr) {
            CGContextSetFillColorWithColor(ctx, priv->_backgroundColor);
            CGContextFillRect(ctx, destRect);
        }
        [self drawInContext:ctx];
        if (![priv->delegate respondsToSelector:@selector(displayLayer:)]) {
            [priv->delegate drawLayer:self inContext:ctx];
        }
    } else {
        // If the layer has cached contents, blit them directly.

        // Since the layer was rendered in Quartz referential (ULO) AND the current context
        // is assumed to be Quartz referential (ULO), BUT the layer's cached contents
        // were captured in a CGImage (CGImage referential, LLO), we have to flip
        // the context again before we render it.

        // |1  0 0| is the transformation matrix for flipping a rect anchored at 0,0 about its Y midpoint.
        // |0 -1 0|
        // |0  h 1|
        CGContextSaveGState(ctx);
        CGContextConcatCTM(ctx, CGAffineTransformMake(1, 0, 0, -1, 0, destRect.size.height));
        CGContextDrawImage(ctx, destRect, priv->contents);
        CGContextRestoreGState(ctx);
    }

    //  Draw sublayers
    LLTREE_FOREACH(curLayer, priv) {
        [curLayer->self renderInContext:ctx];
    }
}

/**
 @Status Interoperable
*/
- (void)drawInContext:(CGContextRef)ctx {
}

/**
 @Status Interoperable
*/
- (void)display {
    if (DEBUG_VERBOSE) {
        TraceVerbose(TAG,
                     L"Displaying for 0x%p (%hs, %hs)",
                     priv->delegate,
                     object_getClassName(self),
                     priv->delegate ? object_getClassName(priv->delegate) : "nil");
    }

    if (priv->savedContext != NULL) {
        CGContextRelease(priv->savedContext);
        priv->savedContext = NULL;
    }

    if (priv->contents == NULL || priv->ownsContents || [self isKindOfClass:[CAShapeLayer class]]) {
        if (priv->contents) {
            if (priv->ownsContents) {
                if (DEBUG_VERBOSE) {
                    TraceVerbose(TAG, L"Freeing 0x%x with refcount %d", priv->contents, CFGetRetainCount((CFTypeRef)priv->contents));
                }
                CGImageRelease(priv->contents);
            }
            priv->contents = NULL;
        }

        // Update content size, even in case of the early out below.
        int widthInPoints = ceilf(priv->bounds.size.width);
        int heightInPoints = ceilf(priv->bounds.size.height);

        int width = (int)(widthInPoints * priv->contentsScale);
        int height = (int)(heightInPoints * priv->contentsScale);

        if (width <= 0 || height <= 0) {
            TraceVerbose(TAG, L"Not drawing due to invalid layer dimensions; width=%d, height=%d", width, height);
            return;
        }

        priv->contentsSize.width = (float)width;
        priv->contentsSize.height = (float)height;

        // nothing to do?
        bool hasDrawingMethod = false;
        if (priv->delegate != nil && (!object_isMethodFromClass(priv->delegate, @selector(drawRect:), "UIView") ||
                                      !object_isMethodFromClass(priv->delegate, @selector(drawLayer:inContext:), "UIView") ||
                                      [priv->delegate respondsToSelector:@selector(displayLayer:)])) {
            hasDrawingMethod = true;
        }

        if (!object_isMethodFromClass(self, @selector(drawInContext:), "CALayer")) {
            hasDrawingMethod = true;
        }

        if (!hasDrawingMethod) {
            if (DEBUG_DRAWING) {
                TraceVerbose(TAG, L"Not drawing because no drawing callback was found for this layer.");
            }
            return;
        }

        unsigned int tries = 0;
        do {
            // Create the contents
            woc::StrongCF<CGContextRef> drawContext{ woc::MakeStrongCF(
                CreateLayerContentsBitmapContext32(width, height, priv->contentsScale)) };
            _CGContextPushBeginDraw(drawContext);

            if (priv->_backgroundColor != nullptr && CGColorGetPattern(priv->_backgroundColor) != nullptr) {
                CGContextSaveGState(drawContext);
                CGContextSetFillColorWithColor(drawContext, priv->_backgroundColor);

                CGRect wholeRect = CGRectMake(0, 0, width, height);
                CGContextFillRect(drawContext, wholeRect);
                CGContextRestoreGState(drawContext);
            }

            // UIKit and CALayer consumers expect the origin to be in the top left.
            // CoreGraphics defaults to the bottom left, so we must flip and translate the canvas.
            CGContextTranslateCTM(drawContext, 0, heightInPoints);
            CGContextScaleCTM(drawContext, 1.0f, -1.0f);
            CGContextTranslateCTM(drawContext, -priv->bounds.origin.x, -priv->bounds.origin.y);

            _CGContextSetShadowProjectionTransform(drawContext, CGAffineTransformMakeScale(1.0, -1.0));

            [self drawInContext:drawContext];

            if (priv->delegate != 0) {
                if ([priv->delegate respondsToSelector:@selector(displayLayer:)]) {
                    [priv->delegate displayLayer:self];
                } else {
                    [priv->delegate drawLayer:self inContext:drawContext];
                }
            }

            _CGContextPopEndDraw(drawContext);

            woc::StrongCF<CFErrorRef> renderError;
            if (CGContextIwGetError(drawContext, &renderError)) {
                switch (CFErrorGetCode(renderError)) {
                    case kCGContextErrorDeviceReset:
                        NSTraceInfo(TAG, @"Hardware device disappeared when rendering %@; retrying.", self);
                        ++tries;
                        continue;
                    default: {
                        FAIL_FAST_MSG("Failed to render <%hs %p>: %hs",
                                      object_getClassName(self),
                                      self,
                                      [[static_cast<NSError*>(renderError.get()) debugDescription] UTF8String]);
                        break;
                    }
                }
            }

            CGImageRef target = _CGBitmapContextGetImage(drawContext);
            priv->ownsContents = TRUE;
            priv->savedContext = CGContextRetain(drawContext);
            priv->contents = CGImageRetain(target);
            break;
        } while (tries < _kCALayerRenderAttempts);

        if (!priv->contents) {
            NSTraceError(TAG, @"Failed to render layer %@", self);
        }
    } else if (priv->contents) {
        priv->contentsSize.width = float(CGImageGetWidth(priv->contents));
        priv->contentsSize.height = float(CGImageGetHeight(priv->contents));
    }
}

static void doRecursiveAction(CALayer* layer, NSString* actionName) {
    //  Notify all subviews
    LLTREE_FOREACH(obj, layer->priv) {
        doRecursiveAction(obj->self, actionName);
    }

    id<CAAction> action = [layer actionForKey:actionName];
    if (action != nil) {
        [action runActionForKey:actionName object:layer arguments:nil];
    }

    /* Note: This can causes unnecessary redraws - should be refactored such that the contents are only released
    when the layer is determined to have been removed from the drawing tree after an entire update cycle */
    if (actionName == (NSString*)_orderOutAction) {
        [layer _releaseContents:FALSE];

        if (layer->priv->savedContext) {
            CGContextRelease(layer->priv->savedContext);
            layer->priv->savedContext = NULL;
        }
    }
}

/**
 @Status Interoperable
*/
- (void)addSublayer:(CALayer*)subLayerAddr {
    if (subLayerAddr == self) {
        FAIL_FAST_MSG("Cannot addSublayer:self!");
    }

    [self _setShouldLayout];
    [subLayerAddr _setShouldLayout];

    [subLayerAddr retain];
    [subLayerAddr removeFromSuperlayer];
    [subLayerAddr autorelease];

    //  If our layer is visible, order all subviews in
    bool isVisible = false;

    CALayer* curLayer = self;
    while (curLayer != nil) {
        if (curLayer->priv->isRootLayer) {
            isVisible = true;
            break;
        }

        curLayer = curLayer->priv->superlayer;
    }

    if (isVisible) {
        //  Order in subviews
        doRecursiveAction(subLayerAddr, _orderInAction);
    }

    priv->addChildAfter(subLayerAddr, nil);
    [subLayerAddr retain];

    CALayer* sublayer = (CALayer*)subLayerAddr;
    sublayer->priv->superlayer = self;

    [CATransaction _addSublayerToLayer:self sublayer:sublayer];
}

/**
 @Status Interoperable
*/
- (void)insertSublayer:(CALayer*)layer above:(CALayer*)aboveLayer {
    int curLayerPos = priv->indexOfChild(aboveLayer);
    if (curLayerPos == 0x7fffffff) {
        assert(0);
    }

    [self insertSublayer:layer atIndex:curLayerPos + 1];
}

/**
 @Status Interoperable
*/
- (void)insertSublayer:(CALayer*)layer below:(CALayer*)belowLayer {
    int curLayerPos = priv->indexOfChild(belowLayer);
    if (curLayerPos == 0x7fffffff) {
        assert(0);
    }

    [self insertSublayer:layer atIndex:curLayerPos];
}

/**
 @Status Interoperable
*/
- (void)insertSublayer:(CALayer*)subLayerAddr atIndex:(unsigned)index {
    if (subLayerAddr == self) {
        assert(0);
    }

    [self _setShouldLayout];
    [subLayerAddr _setShouldLayout];

    //  If our layer is visible, order all subviews in
    bool isVisible = false;

    CALayer* curLayer = self;

    while (curLayer != nil) {
        if (curLayer->priv->isRootLayer) {
            isVisible = true;
            break;
        }

        curLayer = curLayer->priv->superlayer;
    }

    if (isVisible) {
        //  Order in subviews
        doRecursiveAction(subLayerAddr, _orderInAction);
    }

    CALayer* insertBefore = nil;

    if (index < (unsigned)priv->childCount) {
        insertBefore = priv->childAtIndex(index)->self;
    } else {
        if (index > (unsigned)priv->childCount) {
            if (DEBUG_VERBOSE) {
                TraceVerbose(TAG, L"Adding sublayer at index %d, count=%d!", index, priv->childCount);
            }

            index = priv->childCount;
        }
    }

    priv->insertChildAtIndex(subLayerAddr, index);
    [subLayerAddr retain];

    CALayer* sublayer = (CALayer*)subLayerAddr;
    sublayer->priv->superlayer = self;

    if (insertBefore != nil) {
        [CATransaction _addSublayerToLayer:self sublayer:sublayer before:insertBefore];
    } else {
        [CATransaction _addSublayerToLayer:self sublayer:sublayer];
    }
}

/**
 @Status Interoperable
*/
- (void)replaceSublayer:(CALayer*)oldLayer with:(CALayer*)newLayer {
    // according to the docs, if oldLayer is not found the behaviour is undefined.
    int index = priv->indexOfChild(oldLayer);
    if (index == NSNotFound) {
        return;
    }

    [self _setShouldLayout];
    [newLayer _setShouldLayout];

    [oldLayer retain];
    [newLayer retain];

    priv->replaceChild(oldLayer, newLayer);

    [CATransaction _replaceInLayer:self sublayer:oldLayer withSublayer:newLayer];

    [oldLayer release];
    [newLayer release];
}

- (void)exchangeSublayer:(CALayer*)layer1 withLayer:(CALayer*)layer2 {
    [layer1 retain];
    [layer2 retain];

    int index1 = priv->indexOfChild(layer1);
    int index2 = priv->indexOfChild(layer2);

    priv->exchangeChild(layer1, layer2);

    //  Special case: adjacent views
    if (index2 == index1 + 1) {
        [CATransaction _moveLayer:layer1 beforeLayer:nil afterLayer:layer2];
    } else if (index1 == index2 + 1) {
        [CATransaction _moveLayer:layer2 beforeLayer:nil afterLayer:layer1];
    } else {
        int dist = index1 - index2;

        dist = dist < 0 ? -dist : dist;

        if (dist > 1) {
            if (index1 > 0) {
                CALayer* node1Before = priv->childAtIndex(index1 - 1)->self;
                [CATransaction _moveLayer:layer2 beforeLayer:nil afterLayer:node1Before];
            } else {
                CALayer* node1After = priv->childAtIndex(index1 + 1)->self;
                [CATransaction _moveLayer:layer2 beforeLayer:node1After afterLayer:nil];
            }

            if (index2 > 0) {
                CALayer* node2Before = priv->childAtIndex(index2 - 1)->self;
                [CATransaction _moveLayer:layer1 beforeLayer:nil afterLayer:node2Before];
            } else {
                CALayer* node2After = priv->childAtIndex(index2 + 1)->self;
                [CATransaction _moveLayer:layer1 beforeLayer:node2After afterLayer:nil];
            }
        } else {
            assert(0);
        }
    }
}

- (void)bringSublayerToFront:(CALayer*)sublayer {
    if (sublayer == self) {
        assert(0);
    }

    if (priv->lastChild->self == sublayer) {
        return;
    }

    CALayer* insertAfter = priv->lastChild->self;
    priv->removeChild(sublayer);
    priv->addChildAfter(sublayer, nil);

    [CATransaction _moveLayer:sublayer beforeLayer:nil afterLayer:insertAfter];
}

- (void)sendSublayerToBack:(CALayer*)sublayer {
    if (sublayer == self) {
        assert(0);
    }

    CALayer* insertBefore = priv->firstChild->self;
    priv->removeChild(sublayer);
    priv->addChildBefore(sublayer, nil);

    [CATransaction _moveLayer:sublayer beforeLayer:insertBefore afterLayer:nil];
}

/**
 @Status Interoperable
*/
- (void)removeFromSuperlayer {
    if (priv->superlayer == 0) {
        return;
    }

    //  If our layer is visible, order all subviews out
    bool isVisible = false;

    CALayer* curLayer = self;
    CALayer* superLayer = (CALayer*)priv->superlayer;
    CALayer* nextSuper = curLayer->priv->superlayer;
    priv->superlayer = 0;

    while (curLayer != nil) {
        if (curLayer->priv->isRootLayer) {
            isVisible = true;
            break;
        }

        curLayer = nextSuper;

        if (curLayer) {
            nextSuper = curLayer->priv->superlayer;
        }
    }

    if (isVisible) {
        //  Order out subviews
        doRecursiveAction(self, _orderOutAction);
    }

    [CATransaction _removeLayer:self];

    superLayer->priv->removeChild(self);

    [superLayer setNeedsLayout];
    [self release];
}

- (BOOL)hidden {
    return priv->hidden;
}

/**
 @Status Interoperable
*/
- (CGRect)frame {
    CGRect ret;

    if (priv->_frameIsCached) {
        return priv->_cachedFrame;
    }

    //  Get transformed bounding box
    CGAffineTransform curTransform, translate, invTranslate;
    curTransform = [self affineTransform];

    translate = CGAffineTransformMakeTranslation(-priv->position.x, -priv->position.y);
    translate = CGAffineTransformConcat(translate, curTransform);
    invTranslate = CGAffineTransformMakeTranslation(priv->position.x, priv->position.y);
    translate = CGAffineTransformConcat(translate, invTranslate);

    ret.origin.x = priv->position.x - priv->bounds.size.width * priv->anchorPoint.x;
    ret.origin.y = priv->position.y - priv->bounds.size.height * priv->anchorPoint.y;
    ret.size = priv->bounds.size;

    ret = CGRectApplyAffineTransform(ret, translate);
    if (DEBUG_VERBOSE) {
        TraceVerbose(TAG,
                     L"%hs: frame(%d, %d, %d, %d)",
                     object_getClassName(self),
                     (int)ret.origin.x,
                     (int)ret.origin.y,
                     (int)ret.size.width,
                     (int)ret.size.height);
    }

    memcpy(&priv->_cachedFrame, &ret, sizeof(CGRect));
    priv->_frameIsCached = TRUE;

    return ret;
}

/**
 @Status Interoperable
*/
- (void)setFrame:(CGRect)frame {
    if (DEBUG_VERBOSE) {
        char szOut[512];
        sprintf_s(szOut,
                  sizeof(szOut),
                  "%s: setFrame(%f, %f, %f, %f)\n",
                  object_getClassName(self),
                  frame.origin.x,
                  frame.origin.y,
                  frame.size.width,
                  frame.size.height);
        TraceVerbose(TAG, L"%hs", szOut);
    }
    priv->_frameIsCached = FALSE;

    if (memcmp(&frame, &CGRectNull, sizeof(CGRect)) == 0) {
        [self setPosition:frame.origin];

        CGRect curBounds;
        curBounds = [self bounds];
        curBounds.size = frame.size;

        [self setBounds:curBounds];

        return;
    }

    //  Get transformed bounding box
    CGAffineTransform curTransform, translate, invTranslate;
    curTransform = [self affineTransform];

    CGPoint position;

    position.x = frame.origin.x + frame.size.width * priv->anchorPoint.x;
    position.y = frame.origin.y + frame.size.height * priv->anchorPoint.y;

    //  Get transformed bounding box
    translate = CGAffineTransformMakeTranslation(-position.x, -position.y);
    translate = CGAffineTransformConcat(translate, curTransform);
    invTranslate = CGAffineTransformMakeTranslation(position.x, position.y);
    translate = CGAffineTransformConcat(translate, invTranslate);

    translate = CGAffineTransformInvert(translate);
    frame = CGRectApplyAffineTransform(frame, translate);

    CGSize outSize;
    outSize.width = frame.size.width;
    outSize.height = frame.size.height;

    position.x = frame.origin.x + frame.size.width * priv->anchorPoint.x;
    position.y = frame.origin.y + frame.size.height * priv->anchorPoint.y;

    [self setPosition:position];

    CGRect outBounds = [self bounds];
    outBounds.size = outSize;
    [self setBounds:outBounds];
}

/**
 @Status Interoperable
*/
+ (CALayer*)layer {
    return [[self new] autorelease];
}

/**
 @Status Interoperable
*/
- (CGRect)bounds {
    return priv->bounds;
}

/**
 @Status Interoperable
*/
- (CALayer*)superlayer {
    return priv->superlayer;
}

/**
 @Status Interoperable
*/
- (CGPoint)position {
    return priv->position;
}

/**
 @Status Interoperable
*/
- (CGPoint)anchorPoint {
    return priv->anchorPoint;
}

/**
 @Status Interoperable
*/
- (void)setPosition:(CGPoint)pos {
    if (priv->position.x == pos.x && priv->position.y == pos.y) {
        return;
    }

    id<CAAction> action = [self actionForKey:(id)_positionAction];

    priv->position.x = pos.x;
    priv->position.y = pos.y;
    priv->_frameIsCached = FALSE;

    NSValue* newPosValue = [[NSValue alloc] initWithCGPoint:priv->position];
    [CATransaction _setPropertyForLayer:self name:@"position" value:newPosValue];
    [newPosValue release];

    if (action != nil) {
        [action runActionForKey:(id)_positionAction object:self arguments:nil];
    }
}

/**
 @Status Interoperable
*/
- (void)setBounds:(CGRect)bounds {
    CGRect zero = { 0 };
    if (*((DWORD*)&bounds.size.width) == 0xCCCCCCCC) {
        assert(0);
    }

    if (bounds.origin.x != bounds.origin.x || bounds.origin.y != bounds.origin.y || bounds.size.width != bounds.size.width ||
        bounds.size.height != bounds.size.height) {
        TraceWarning(TAG,
                     L"**** Warning: Bad bounds on CALayer - %f, %f, %f, %f *****",
                     bounds.origin.x,
                     bounds.origin.y,
                     bounds.size.width,
                     bounds.size.height);
        return;
    }

    id<CAAction> action = nil;
    if (priv->bounds.size.width != bounds.size.width || priv->bounds.size.height != bounds.size.height ||
        priv->bounds.origin.x != bounds.origin.x || priv->bounds.origin.y != bounds.origin.y) {
        action = [self actionForKey:_boundsAction];
    }

    if (priv->bounds.size.width != bounds.size.width || priv->bounds.size.height != bounds.size.height) {
        priv->bounds.size = bounds.size;

        if (priv->superlayer != 0 && priv->needsDisplayOnBoundsChange) {
            [self setNeedsDisplay];
        }
        [self _setShouldLayout];
        [priv->superlayer _setShouldLayout];

        NSValue* newSizeValue = [[NSValue alloc] initWithCGSize:priv->bounds.size];
        [CATransaction _setPropertyForLayer:self name:@"bounds.size" value:newSizeValue];
        [newSizeValue release];
        priv->_frameIsCached = FALSE;
    }

    if (priv->bounds.origin.x != bounds.origin.x || priv->bounds.origin.y != bounds.origin.y) {
        priv->bounds.origin = bounds.origin;

        NSValue* newOriginValue = [[NSValue alloc] initWithCGPoint:priv->bounds.origin];
        [CATransaction _setPropertyForLayer:self name:@"bounds.origin" value:newOriginValue];
        [newOriginValue release];
    }

    [action runActionForKey:(id)_boundsAction object:self arguments:nil];
}

- (void)_setOrigin:(CGPoint)origin {
    if (origin.x != origin.x || origin.y != origin.y) {
        TraceWarning(TAG, L"**** Warning: Bad origin on CALayer - %f, %f *****", origin.x, origin.y);
        FAIL_FAST();
    }

    priv->bounds.origin = origin;
    [self setNeedsLayout];
}

/**
 @Status Interoperable
*/
- (void)setAnchorPoint:(CGPoint)point {
    priv->anchorPoint = point;
    priv->_frameIsCached = FALSE;

    NSValue* newAnchorValue = [[NSValue alloc] initWithCGPoint:priv->anchorPoint];
    [CATransaction _setPropertyForLayer:self name:@"anchorPoint" value:newAnchorValue];
    [newAnchorValue release];
}

- (CGRect)contentsRect {
    return priv->contentsRect;
}

- (void)setContentsRect:(CGRect)rect {
    memcpy(&priv->contentsRect, &rect, sizeof(CGRect));

    NSValue* newRect = [[NSValue alloc] initWithCGRect:priv->contentsRect];
    [CATransaction _setPropertyForLayer:self name:@"contentsRect" value:newRect];
    [newRect release];
}

/**
 @Status Interoperable
*/
- (CGRect)contentsCenter {
    return priv->contentsCenter;
}

/**
 @Status Interoperable
*/
- (void)setContentsCenter:(CGRect)rect {
    memcpy(&priv->contentsCenter, &rect, sizeof(CGRect));

    NSValue* newRect = [[NSValue alloc] initWithCGRect:priv->contentsCenter];
    [CATransaction _setPropertyForLayer:self name:@"contentsCenter" value:newRect];
    [newRect release];
}

/**
 @Status Interoperable
*/
- (void)setContentsGravity:(NSString*)gravity {
    if ([gravity isEqual:kCAGravityCenter]) {
        priv->gravity = kGravityCenter;
    } else if ([gravity isEqual:kCAGravityResize]) {
        priv->gravity = kGravityResize;
    } else if ([gravity isEqual:kCAGravityTop]) {
        priv->gravity = kGravityTop;
    } else if ([gravity isEqual:kCAGravityResizeAspect]) {
        priv->gravity = kGravityResizeAspect;
    } else if ([gravity isEqual:kCAGravityTopLeft]) {
        priv->gravity = kGravityTopLeft;
    } else if ([gravity isEqual:kCAGravityTopRight]) {
        priv->gravity = kGravityTopRight;
    } else if ([gravity isEqual:kCAGravityBottomLeft]) {
        priv->gravity = kGravityBottomLeft;
    } else if ([gravity isEqual:kCAGravityLeft]) {
        priv->gravity = kGravityLeft;
    } else if ([gravity isEqual:kCAGravityResizeAspectFill]) {
        priv->gravity = kGravityAspectFill;
    } else if ([gravity isEqual:kCAGravityBottom]) {
        priv->gravity = kGravityBottom;
    } else if ([gravity isEqual:kCAGravityRight]) {
        priv->gravity = kGravityRight;
    } else if ([gravity isEqual:kCAGravityBottomRight]) {
        priv->gravity = kGravityBottomRight;
    } else {
        assert(0);
    }

    NSNumber* newGravity = [[NSNumber alloc] initWithInt:priv->gravity];
    [CATransaction _setPropertyForLayer:self name:@"gravity" value:newGravity];
    [newGravity release];
}

/**
 @Status Interoperable
*/
- (NSString*)contentsGravity {
    if (priv->gravity == kGravityCenter) {
        return kCAGravityCenter;
    } else if (priv->gravity == kGravityResize) {
        return kCAGravityResize;
    } else if (priv->gravity == kGravityTop) {
        return kCAGravityTop;
    } else if (priv->gravity == kGravityResizeAspect) {
        return kCAGravityResizeAspect;
    } else if (priv->gravity == kGravityTopLeft) {
        return kCAGravityTopLeft;
    } else if (priv->gravity == kGravityTopRight) {
        return kCAGravityTopRight;
    } else if (priv->gravity == kGravityBottomLeft) {
        return kCAGravityBottomLeft;
    } else if (priv->gravity == kGravityLeft) {
        return kCAGravityLeft;
    } else if (priv->gravity == kGravityAspectFill) {
        return kCAGravityResizeAspectFill;
    } else if (priv->gravity == kGravityBottom) {
        return kCAGravityBottom;
    } else if (priv->gravity == kGravityRight) {
        return kCAGravityRight;
    } else if (priv->gravity == kGravityBottomRight) {
        return kCAGravityBottomRight;
    } else {
        assert(0);
    }
    return nil;
}

/**
 @Status Interoperable
*/
- (void)setHidden:(BOOL)hidden {
    if (priv->hidden == hidden) {
        return;
    }

    priv->hidden = hidden;

    NSNumber* newHidden = [[NSNumber alloc] initWithInt:priv->hidden];
    [CATransaction _setPropertyForLayer:self name:@"hidden" value:newHidden];
    [newHidden release];
}

/**
 @Status Interoperable
*/
- (BOOL)isHidden {
    return priv->hidden;
}

/**
 @Status Interoperable
*/
- (void)setDelegate:(id)delegateAddr {
    priv->delegate = delegateAddr;

    if ([delegateAddr respondsToSelector:@selector(drawRect:)]) {
        if (!object_isMethodFromClass(priv->delegate, @selector(drawRect:), "UIView") &&
            ![priv->delegate isKindOfClass:[CAEAGLLayer class]]) {
            priv->contentsScale = GetCACompositor()->GetScreenScale();
        }
    }
}

/**
 @Status Interoperable
*/
- (id)delegate {
    return priv->delegate;
}

/**
 @Status Interoperable
*/
- (void)setContents:(id)pImg {
    CGImageRef oldContents = priv->contents;

    if (pImg != NULL) {
        priv->contents = static_cast<CGImageRef>(pImg);
        CGImageRetain(static_cast<CGImageRef>(pImg));
        priv->ownsContents = FALSE;

        priv->contentsSize.width = float(CGImageGetWidth(priv->contents));
        priv->contentsSize.height = float(CGImageGetHeight(priv->contents));
    } else {
        priv->contents = NULL;
        priv->ownsContents = FALSE;
    }

    if (oldContents) {
        CGImageRelease(oldContents);
    }
    if (priv->savedContext) {
        CGContextRelease(priv->savedContext);
        priv->savedContext = NULL;
    }

    [self setNeedsDisplay];
}

/**
 @Status Interoperable
*/
- (id)contents {
    if (!priv->ownsContents) {
        return (id)priv->contents;
    }

    return nil;
}

- (UIImageOrientation)contentsOrientation {
    return priv->contentsOrientation;
}

- (void)setContentsOrientation:(UIImageOrientation)orientation {
    priv->contentsOrientation = orientation;
    NSNumber* newOrientation = [[NSNumber alloc] initWithInt:priv->contentsOrientation];
    [CATransaction _setPropertyForLayer:self name:@"contentsOrientation" value:newOrientation];
    [newOrientation release];
}

- (void)_releaseContents:(BOOL)immediately {
    if (priv->ownsContents) {
        if (priv->contents) {
            CGImageRelease(priv->contents);
            priv->contents = NULL;
        }
        if (priv->savedContext) {
            CGContextRelease(priv->savedContext);
            priv->savedContext = NULL;
        }
    }

    // Clear out the display texture for this layer
    [CATransaction _currentLayerTransaction]->SetLayerTexture(priv->_layerProxy, nullptr, CGSizeMake(0, 0), 0.0f);
    [self setNeedsDisplay];
}

- (BOOL)isOpaque {
    return priv->isOpaque;
}

/**
 @Status Interoperable
*/
- (BOOL)opaque {
    return priv->isOpaque;
}

/**
 @Status Interoperable
*/
- (void)setOpaque:(BOOL)isOpaque {
    priv->isOpaque = isOpaque;
}

/**
 @Status Stub
*/
- (void)setZPosition:(float)pos {
    UNIMPLEMENTED();
}

/**
 @Status Stub
*/
- (float)zPosition {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
*/
- (void)setAnchorPointZ:(float)pos {
    UNIMPLEMENTED();
}

/**
 @Status Stub
*/
- (float)anchorPointZ {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Interoperable
*/
- (void)setMasksToBounds:(BOOL)mask {
    priv->masksToBounds = mask;

    NSNumber* newMask = [[NSNumber alloc] initWithInt:priv->masksToBounds];
    [CATransaction _setPropertyForLayer:self name:@"masksToBounds" value:newMask];
    [newMask release];
}

/**
 @Status Interoperable
*/
- (BOOL)masksToBounds {
    return priv->masksToBounds;
}

/**
 @Status Interoperable
 @Notes For CABasicAnimation when all three animation properties are nil, our behavior (i.e. no animation)
        remains consistent with what happens on Mac, but varies from Apple Documentation.
*/
- (void)addAnimation:(CAAnimation*)anim forKey:(NSString*)key {
    if (priv->_animations == nil) {
        priv->_animations = [NSMutableDictionary new];
    }

    if (key == nil) {
        static int curId = 0;
        char szName[255];
        sprintf_s(szName, sizeof(szName), "Undefined_%d", curId);
        curId++;
        key = [NSString stringWithCString:szName];
    }

    CAAnimation* curAnim = [priv->_animations objectForKey:key];
    if (curAnim == anim) {
        return;
    }

    if (curAnim != nil) {
        [curAnim _removeAnimationsFromLayer];
    }

    CAAnimation* animCopy = [anim copy];
    animCopy->_keyName = [key copy];
    [priv->_animations setObject:(id)animCopy forKey:(id)animCopy->_keyName];

    [CATransaction _addAnimationToLayer:self animation:animCopy forKey:key];
    [animCopy release];
}

- (void)_removeAnimation:(CAAnimation*)animation {
    CAAnimation* objForKey = [priv->_animations objectForKey:animation->_keyName];
    [priv->_animations removeObjectForKey:animation->_keyName];
}

/**
 @Status Interoperable
*/
- (CAAnimation*)animationForKey:(NSString*)key {
    if (priv->_animations == nil) {
        priv->_animations = [NSMutableDictionary new];
    }

    if (key == nil) {
        key = @"";
    }

    return [priv->_animations objectForKey:key];
}

/**
 @Status Interoperable
*/
- (NSArray*)animationKeys {
    if (priv->_animations == nil) {
        priv->_animations = [NSMutableDictionary new];
    }

    return [priv->_animations allKeys];
}

/**
 @Status Interoperable
*/
- (void)removeAllAnimations {
    if (priv->_animations) {
        int count = CFDictionaryGetCount((CFDictionaryRef)priv->_animations);
        id* vals = (id*)malloc(sizeof(id) * count);
        CFDictionaryGetKeysAndValues((CFDictionaryRef)priv->_animations, NULL, (const void**)vals);
        for (int i = 0; i < count; i++) {
            [vals[i] _removeAnimationsFromLayer];
        }
        free(vals);

        [priv->_animations removeAllObjects];
    }
}

/**
 @Status Interoperable
*/
- (void)removeAnimationForKey:(NSString*)key {
    CAAnimation* anim = [priv->_animations objectForKey:key];

    if (anim != nil) {
        [anim _removeAnimationsFromLayer];
    }
    [priv->_animations removeObjectForKey:key];
}

/**
 @Status Interoperable
*/
- (void)setAffineTransform:(CGAffineTransform)transform {
    CATransform3D newTransform;

    newTransform = CATransform3DMakeTranslation(0, 0, 0);
    newTransform.m[0][0] = transform.a;
    newTransform.m[0][1] = transform.b;
    newTransform.m[1][0] = transform.c;
    newTransform.m[1][1] = transform.d;
    newTransform.m[3][0] = transform.tx;
    newTransform.m[3][1] = transform.ty;

    [self setTransform:newTransform];
}

/**
 @Status Interoperable
*/
- (CGAffineTransform)affineTransform {
    return CGAffineTransformMake(priv->transform.m[0][0],
                                 priv->transform.m[0][1],
                                 priv->transform.m[1][0],
                                 priv->transform.m[1][1],
                                 priv->transform.m[3][0],
                                 priv->transform.m[3][1]);
}

/**
 @Status Interoperable
*/
- (void)setTransform:(CATransform3D)transform {
    if (memcmp(priv->transform.m, transform.m, sizeof(transform.m)) == 0) {
        return;
    }

    id<CAAction> action = [self actionForKey:_transformAction];

    memcpy(priv->transform.m, transform.m, sizeof(transform.m));
    priv->_frameIsCached = FALSE;

    [action runActionForKey:(id)_transformAction object:self arguments:nil];

    NSValue* transformValue = [[NSValue alloc] initWithCATransform3D:priv->transform];
    [CATransaction _setPropertyForLayer:self name:@"transform" value:transformValue];
    [transformValue release];
}

/**
 @Status Interoperable
*/
- (CATransform3D)transform {
    return priv->transform;
}

/**
 @Status Stub
*/
- (void)setSublayerTransform:(CATransform3D)transform {
    UNIMPLEMENTED();
}

/**
 @Status Stub
*/
- (CATransform3D)sublayerTransform {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Interoperable
*/
- (void)setBackgroundColor:(CGColorRef)color {
    if (color != nullptr) {
        const CGFloat* colorComp = CGColorGetComponents(color);
        priv->backgroundColor = { colorComp[0], colorComp[1], colorComp[2], colorComp[3] };
    } else {
        priv->backgroundColor.Clear();
    }

    CGColorRef old = priv->_backgroundColor;
    priv->_backgroundColor = CGColorRetain(color);
    CGColorRelease(old);

    // The CATransaction is now synchronous and in this scenario, the backgroundColor
    // is updated almost immediately.By setting the priv->background first,
    // we can ensure both states are kept in sync which is useful when performing
    // automated testing.
    [CATransaction _setPropertyForLayer:self name:@"backgroundColor" value:static_cast<NSObject*>(color)];

    [self setNeedsDisplay];
}

/**
 @Status Interoperable
*/
- (CGColorRef)backgroundColor {
    return priv->_backgroundColor;
}

/**
 @Status Interoperable
*/
- (void)setBorderColor:(CGColorRef)color {
    // Set the border color via CATransaction

    [CATransaction _setPropertyForLayer:self name:@"borderColor" value:static_cast<NSObject*>(color)];
    [self setNeedsDisplay];
}

/**
 @Status Interoperable
*/
- (CGColorRef)borderColor {
    // Grab the current border color directly off of the layer proxy
    return static_cast<CGColorRef>(priv->_layerProxy->GetPropertyValue("borderColor"));
}

/**
 @Status Interoperable
*/
- (void)setBorderWidth:(float)width {
    // Set the border width via CATransaction
    [CATransaction _setPropertyForLayer:self name:@"borderWidth" value:[NSNumber numberWithFloat:width]];
    [self setNeedsDisplay];
}

/**
 @Status Interoperable
*/
- (float)borderWidth {
    // Grab the current border width directly off of the layer proxy
    return [(NSNumber*)priv->_layerProxy->GetPropertyValue("borderWidth") floatValue];
}

/**
 @Status NotInPlan
 @Notes Rounded corners with clipped children are not currently achievable in Xaml.
*/
- (void)setCornerRadius:(float)radius {
    UNIMPLEMENTED_WITH_MSG("Rounded corners with clipped children are not achievable in Xaml.");
}

/**
 @Status NotInPlan
 @Notes Rounded corners with clipped children are not currently achievable in Xaml.
*/
- (float)cornerRadius {
    UNIMPLEMENTED_WITH_MSG("Rounded corners with clipped children are not achievable in Xaml.");
    return StubReturn();
}

/**
 @Status Interoperable
*/
- (void)setContentsScale:(float)scale {
    priv->contentsScale = scale;

    NSNumber* newScale = [[NSNumber alloc] initWithFloat:priv->contentsScale];
    [CATransaction _setPropertyForLayer:self name:@"contentsScale" value:newScale];
    [newScale release];
}

/**
 @Status Stub
*/
- (void)setShadowOffset:(CGSize)size {
    UNIMPLEMENTED();
}

/**
 @Status Stub
*/
- (CGSize)shadowOffset {
    UNIMPLEMENTED();
    CGSize ret;
    ret.width = 0.0f;
    ret.height = -3.0f;
    return ret;
}

/**
 @Status Stub
*/
- (void)setShadowOpacity:(float)opacity {
    UNIMPLEMENTED();
}

/**
 @Status Stub
*/
- (float)shadowOpacity {
    UNIMPLEMENTED();
    return 0.0f;
}

/**
 @Status Stub
*/
- (void)setShadowColor:(CGColorRef)color {
    UNIMPLEMENTED();
}

/**
 @Status Stub
*/
- (CGColorRef)shadowColor {
    UNIMPLEMENTED();
    return CGColorGetConstantColor(kCGColorBlack);
}

/**
 @Status Stub
*/
- (void)setShadowRadius:(float)radius {
    UNIMPLEMENTED();
}

/**
 @Status Stub
*/
- (float)shadowRadius {
    UNIMPLEMENTED();
    return 3.0f;
}

/**
 @Status Interoperable
*/
- (BOOL)shouldRasterize {
    return priv->_shouldRasterize;
}

/**
   @Status Interoperable
*/
- (void)setShouldRasterize:(BOOL)shouldRasterize {
    priv->_shouldRasterize = shouldRasterize;
    priv->_layerProxy->SetShouldRasterize(shouldRasterize);
}

/**
 @Status Interoperable
*/
- (float)contentsScale {
    return priv->contentsScale;
}

/**
 @Status Interoperable
*/
- (void)setOpacity:(float)value {
    if (priv->opacity == value) {
        return;
    }

    id<CAAction> action = [self actionForKey:_opacityAction];

    priv->opacity = value;

    if (action != nil) {
        [action runActionForKey:(id)_opacityAction object:self arguments:nil];
    }

    NSNumber* newOpacity = [[NSNumber alloc] initWithFloat:priv->opacity];
    [CATransaction _setPropertyForLayer:self name:@"opacity" value:newOpacity];
    [newOpacity release];
}

/**
 @Status Interoperable
*/
- (float)opacity {
    return priv->opacity;
}

/**
 @Status Interoperable
*/
- (void)setName:(NSString*)name {
    priv->_name.attach([name copy]);
}

/**
 @Status Interoperable
*/
- (NSString*)name {
    return static_cast<NSString*>(priv->_name);
}

/**
 @Status Stub
*/
- (void)setSublayers:(NSArray*)sublayers {
    UNIMPLEMENTED();
}

/**
 @Status Interoperable
*/
- (NSArray*)sublayers {
    return priv->subnodesArray();
}

/**
 @Status Interoperable
*/
- (id<CAAction>)actionForKey:(NSString*)key {
    id<CAAction> ret = nil;

    if ([priv->delegate respondsToSelector:@selector(actionForLayer:forKey:)]) {
        ret = [priv->delegate actionForLayer:self forKey:key];
    }

    if (ret == nil) {
        ret = (id<CAAction>)[priv->_actions objectForKey:key];
    }

    if (ret == nil) {
        ret = (id<CAAction>)[[self class] defaultActionForKey:key];
    }

    if (ret == nil) {
        //  Implicit animation
        bool shouldAnimate = false;

        if (key == _positionAction) {
            shouldAnimate = true;
        } else if (key == _boundsAction) {
            shouldAnimate = true;
        } else if (key == _transformAction) {
            shouldAnimate = true;
        } else if (key == _opacityAction) {
            shouldAnimate = true;
        }

        if (priv->superlayer == nil) {
            shouldAnimate = false;
        }

        if (shouldAnimate) {
            ret = [CATransaction _implicitAnimationForKey:key];
            if (ret != nil) {
                NSObject* value = reinterpret_cast<NSObject*>(priv->_layerProxy->GetPropertyValue([key UTF8String]));
                [static_cast<CABasicAnimation*>(ret) setFromValue:value];
            }
        }
    }

    // The documentation says that we must convert from NSNull to nil here
    if ([static_cast<NSObject*>(ret) isKindOfClass:[NSNull class]]) {
        return nil;
    }

    return ret;
}

/**
 @Status Interoperable
 @Notes Intended override point for subclasses.
*/
+ (id<CAAction>)defaultActionForKey:(NSString*)key {
    return nil;
}

- (std::shared_ptr<IDisplayTexture>)_getDisplayTexture {
    //  Update if needed
    [self displayIfNeeded];

    //  Create and return a texture if we have contents
    if (priv->contents) {
        return GetCACompositor()->GetDisplayTextureForCGImage(priv->contents);
    }

    return nullptr;
}

/**
 @Status Stub
*/
- (CALayer*)presentationLayer {
    UNIMPLEMENTED();
    return nil;
}

/**
 @Status Stub
*/
- (instancetype)initWithLayer:(CALayer*)layerToCopy {
    UNIMPLEMENTED();
    return self;
}

/**
 @Status Interoperable
*/
- (void)setNeedsDisplayOnBoundsChange:(BOOL)needsDisplayOnBoundsChange {
    priv->needsDisplayOnBoundsChange = needsDisplayOnBoundsChange;
}

/**
 @Status Interoperable
*/
- (BOOL)needsDisplayOnBoundsChange {
    return priv->needsDisplayOnBoundsChange;
}

/**
 @Status Interoperable
*/
- (CALayer*)hitTest:(CGPoint)point {
    if (![self _isVisibleOrHitable]) {
        return nil;
    }

    //  Convert point to our locality
    CAPoint3D pt;
    pt.x = point.x;
    pt.y = point.y;
    pt.z = 0.0f;

    CATransform3D curTransform;
    curTransform = CATransform3DMakeTranslation(0, 0, 0);

    curTransform = CATransform3DTranslate(curTransform,
                                          -(priv->position.x - priv->bounds.size.width * priv->anchorPoint.x),
                                          -(priv->position.y - priv->bounds.size.height * priv->anchorPoint.y),
                                          0.0f);
    curTransform = CATransform3DConcat(curTransform, priv->transform);
    CATransform3DTransformPoints(curTransform, &pt, 1);

    point.x = pt.x;
    point.y = pt.y;

    //  Check sublayers
    LLTREE_FOREACH_REVERSE(curSublayer, priv) {
        CALayer* ret = [curSublayer->self hitTest:point];

        if (ret != nil) {
            return ret;
        }
    }

    if (point.x >= priv->bounds.origin.x && point.y >= priv->bounds.origin.y && point.x < priv->bounds.origin.x + priv->bounds.size.width &&
        point.y < priv->bounds.origin.x + priv->bounds.size.height) {
        return self;
    }

    return nil;
}

/**
 @Status Interoperable
*/
- (BOOL)containsPoint:(CGPoint)point {
    if (point.x >= priv->bounds.origin.x && point.y >= priv->bounds.origin.y && point.x < priv->bounds.origin.x + priv->bounds.size.width &&
        point.y < priv->bounds.origin.x + priv->bounds.size.height) {
        return TRUE;
    }

    return FALSE;
}

- (void)dealloc {
    if (DEBUG_VERBOSE) {
        TraceVerbose(TAG,
                     L"CALayer dealloc: (%hs - 0x%p, %hs - 0x%p).",
                     object_getClassName(self),
                     self,
                     priv->delegate ? object_getClassName(priv->delegate) : "nil",
                     priv->delegate);
    }

    [self removeAllAnimations];
    [self removeFromSuperlayer];
    while (priv->firstChild) {
        [priv->firstChild->self removeFromSuperlayer];
    }

    delete priv;
    priv = NULL;
    [super dealloc];
}

/**
 @Status Interoperable
 @Public No
*/
- (id)valueForUndefinedKey:(NSString*)keyPath {
    return [priv->_undefinedKeys valueForKey:keyPath];
}

/**
 @Status Interoperable
 @Public No
*/
- (id)valueForKeyPath:(NSString*)keyPath {
    char* pPath = (char*)[keyPath UTF8String];
    if (strcmp(pPath, "position.x") == 0) {
        return [NSNumber numberWithFloat:priv->position.x];
    } else if (strcmp(pPath, "position.y") == 0) {
        return [NSNumber numberWithFloat:priv->position.y];
    } else if (strcmp(pPath, "transform.rotation.z") == 0 || strcmp(pPath, "transform.rotation") == 0) {
        CATransform3D curTransform = [self transform];
        Quaternion qval;
        qval.CreateFromMatrix(reinterpret_cast<float*>(&curTransform));
        return [NSNumber numberWithFloat:(float)-qval.roll() * 180.0f / M_PI];
    } else if (strcmp(pPath, "transform.rotation.x") == 0 || strcmp(pPath, "transform.rotation.y") == 0) {
        if (DEBUG_VERBOSE) {
            TraceVerbose(TAG, L"Should get rotation");
        }
        return [NSNumber numberWithFloat:0.0f];
    } else if (strcmp(pPath, "transform.scale") == 0) {
        CATransform3D curTransform = [self transform];
        float scale[3];
        CATransform3DGetScale(curTransform, scale);
        return [NSNumber numberWithFloat:(scale[0] + scale[1] + scale[2]) / 3.0f];
    } else if (strcmp(pPath, "transform.scale.x") == 0) {
        CATransform3D curTransform = [self transform];
        float scale[3];
        CATransform3DGetScale(curTransform, scale);
        return [NSNumber numberWithFloat:scale[0]];
    } else if (strcmp(pPath, "transform.scale.y") == 0) {
        CATransform3D curTransform = [self transform];
        float scale[3];
        CATransform3DGetScale(curTransform, scale);
        return [NSNumber numberWithFloat:scale[1]];
    } else if (strcmp(pPath, "transform.scale.z") == 0) {
        CATransform3D curTransform = [self transform];
        float scale[3];
        CATransform3DGetScale(curTransform, scale);
        return [NSNumber numberWithFloat:scale[2]];
    } else if (strcmp(pPath, "transform.translation") == 0) {
        CATransform3D curTransform = [self transform];
        float translation[3];
        CATransform3DGetPosition(curTransform, translation);
        return [NSValue valueWithCGSize:CGSizeMake(translation[0] - priv->position.x, translation[1] - priv->position.y)];
    } else if (strcmp(pPath, "transform.translation.x") == 0) {
        CATransform3D curTransform = [self transform];
        float translation[3];
        CATransform3DGetPosition(curTransform, translation);
        return [NSNumber numberWithFloat:translation[0]];
    } else if (strcmp(pPath, "transform.translation.y") == 0) {
        CATransform3D curTransform = [self transform];
        float translation[3];
        CATransform3DGetPosition(curTransform, translation);
        return [NSNumber numberWithFloat:translation[1]];
    } else if (strcmp(pPath, "transform.translation.z") == 0) {
        CATransform3D curTransform = [self transform];
        float translation[3];
        CATransform3DGetPosition(curTransform, translation);
        return [NSNumber numberWithFloat:translation[2]];
    } else if (strcmp(pPath, "bounds.origin") == 0) {
        CGRect bounds = [self bounds];
        return [NSValue valueWithCGPoint:bounds.origin];
    } else if (strcmp(pPath, "bounds.size") == 0) {
        CGRect bounds = [self bounds];
        return [NSValue valueWithCGSize:bounds.size];
    } else if (strcmp(pPath, "bounds.size.width") == 0) {
        CGRect bounds = [self bounds];
        return [NSNumber numberWithFloat:bounds.size.width];
    } else if (strcmp(pPath, "bounds.size.height") == 0) {
        CGRect bounds = [self bounds];
        return [NSNumber numberWithFloat:bounds.size.height];
    } else if (strcmp(pPath, "bounds.origin.x") == 0) {
        CGRect bounds = [self bounds];
        return [NSNumber numberWithFloat:bounds.origin.x];
    } else if (strcmp(pPath, "bounds.origin.y") == 0) {
        CGRect bounds = [self bounds];
        return [NSNumber numberWithFloat:bounds.origin.y];
    }

    return [super valueForKeyPath:keyPath];
}

/**
 @Status Interoperable
 @Public No
*/
- (void)setValue:(id)value forUndefinedKey:(NSString*)key {
    if (priv->_undefinedKeys == nil) {
        priv->_undefinedKeys.attach([NSMutableDictionary new]);
    }
    [priv->_undefinedKeys setObject:value forKey:key];
}

/**
 @Status Interoperable
 @Public No
*/
- (void)setValue:(id)value forKeyPath:(NSString*)keyPath {
    if ([keyPath isEqual:@"transform.scale"]) {
        CATransform3D curTransform;
        float scale = [value floatValue];

        curTransform = [self transform];

        curTransform.m11 = scale;
        curTransform.m22 = scale;
        curTransform.m33 = 1.0f;
        curTransform.m44 = 1.0f;

        [self setTransform:curTransform];
    } else {
        [super setValue:value forKeyPath:keyPath];
    }
}

/**
 @Status Stub
*/
- (void)setMask:(CALayer*)mask {
    UNIMPLEMENTED();
}

/**
 @Status Stub
*/
- (CALayer*)mask {
    UNIMPLEMENTED();
    TraceWarning(TAG, L"mask not supported");
    return nil;
}

/**
 @Status Stub
*/
- (void)setShadowPath:(CGPathRef)path {
    UNIMPLEMENTED();
    TraceWarning(TAG, L"setShadowPath not supported");
}

/**
 @Status Stub
*/
- (CGPathRef)shadowPath {
    UNIMPLEMENTED();
    return nullptr;
}

/**
 @Status Interoperable
*/
- (NSArray*)actions {
    return static_cast<NSArray*>(priv->_actions);
}

/**
 @Status Interoperable
*/
- (void)setActions:(NSArray*)actions {
    priv->_actions.attach([actions copy]);
}

/**
 @Status Interoperable
*/
- (CGPoint)convertPoint:(CGPoint)point toLayer:(CALayer*)toLayer {
    return [CALayer convertPoint:point fromLayer:self toLayer:toLayer];
}

/**
 @Status Interoperable
*/
- (CGRect)convertRect:(CGRect)rect toLayer:(CALayer*)toLayer {
    return [CALayer convertRect:rect fromLayer:self toLayer:toLayer];
}

/**
 @Status Interoperable
*/
- (CGPoint)convertPoint:(CGPoint)point fromLayer:(CALayer*)fromLayer {
    return [CALayer convertPoint:point fromLayer:fromLayer toLayer:self];
}

/**
 @Status Interoperable
*/
- (CGRect)convertRect:(CGRect)rect fromLayer:(CALayer*)fromLayer {
    return [CALayer convertRect:rect fromLayer:fromLayer toLayer:self];
}

/**
 @Status Interoperable
*/
- (void)layoutIfNeeded {
    CALayer* curLayer = self;

    while (curLayer != nil) {
        if (curLayer->priv->superlayer == nil || ((CALayer*)curLayer->priv->superlayer)->priv->needsLayout == FALSE) {
            DoLayerLayouts(curLayer);
            return;
        }

        curLayer = curLayer->priv->superlayer;
    }
}

// Finds the topmost superlayer for the specified layer
static CALayer* _findSuperLayerForLayer(CALayer* layer) {
    CALayer* superLayer = layer;
    while (superLayer->priv->superlayer) {
        superLayer = superLayer->priv->superlayer;
    }

    return superLayer;
}

// Kicks off an update to the layer's layout and display hierarchy if needed
- (void)_displayChanged {
    // Find the topmost superlayer
    CALayer* superLayer = _findSuperLayerForLayer(self);

    // Kick off a display update if necessary
    if (!superLayer->priv->_displayPending) {
        superLayer->priv->_displayPending = true;

        if (DEBUG_VERBOSE) {
            TraceVerbose(TAG,
                         L"Posting _displayChanged work for (%hs - 0x%p, %hs - 0x%p) on superlayer (%hs - 0x%p, %hs - 0x%p).",
                         object_getClassName(self),
                         self,
                         priv->delegate ? object_getClassName(priv->delegate) : "nil",
                         priv->delegate,
                         object_getClassName(superLayer),
                         superLayer,
                         superLayer->priv->delegate ? object_getClassName(superLayer->priv->delegate) : "nil",
                         superLayer->priv->delegate);
        }

        //////////////////////////////////////////////////////////////////////////////////////////////
        // TODO: Switch to ARC
        // We don't want to do display updates on an object that's currently deallocating.
        // In order to ensure that we're not mid-deallocation during the display update,
        // we create a weak reference here, and then *immediately* acquire a strong reference to it.
        // If that succeeds, we're guaranteed to not dealloc until after the block executes.

        // Store a weak reference - this will fail if we're already deallocating
        id weakSuperLayer = nil;
        objc_storeWeak(&weakSuperLayer, superLayer);

        // Grab a strong reference that we can pass into the block - this will fail if we're already deallocating
        auto strongSuperLayer = reinterpret_cast<CALayer*>(objc_loadWeakRetained(&weakSuperLayer));

        // We need to make sure the retain we just performed above is released *after* we construct the block
        auto releaseSuperLayer = wil::ScopeExit([&strongSuperLayer]() { objc_release(strongSuperLayer); });

        // The weak reference is no longer needed, so clean up after ourselves
        objc_destroyWeak(&weakSuperLayer);

        // Grab a raw pointer (so it's not block-retained) - for logging purposes (if needed)
        void* rawSuperLayerForLog = reinterpret_cast<void*>(superLayer);

        dispatch_async(dispatch_get_main_queue(), ^{
            // If we have a valid non-dealloc'd object, run its display update pass
            if (strongSuperLayer) {
                // Only run the update pass for this superLayer if it's a 'root layer' - aka a UIWindow layer,
                // or if we're running as a framework - aka for middleware scenarios - where the layer won't have
                // a 'root' superlayer.
                if (strongSuperLayer->priv->isRootLayer || GetCACompositor()->IsRunningAsFramework()) {
                    strongSuperLayer->priv->_displayPending = false;

                    if (DEBUG_VERBOSE) {
                        TraceVerbose(TAG,
                                     L"Performing _displayChanged work for superlayer (%hs - 0x%p, %hs - 0x%p).",
                                     object_getClassName(strongSuperLayer),
                                     strongSuperLayer,
                                     strongSuperLayer->priv->delegate ? object_getClassName(strongSuperLayer->priv->delegate) : "nil",
                                     strongSuperLayer->priv->delegate);
                    }

                    // Recalculate layouts
                    DoLayerLayouts(strongSuperLayer);

                    // Redisplay anything necessary
                    DoDisplayList(strongSuperLayer);
                }
            } else if (DEBUG_VERBOSE) {
                TraceVerbose(TAG, L"Skipping _displayChanged work for currently-dealloc'd object (0x%p).", rawSuperLayerForLog);
            }

            // Always commit and process all queued CATransactions
            [CATransaction _commitAndProcessRootQueue];
        });
    }
}

/**
 @Status Interoperable
*/
- (void)setNeedsLayout {
    priv->needsLayout = TRUE;
    [self _displayChanged];
}

- (void)_setShouldLayout {
    //  Ensure that we don't repeatedly call layoutSubviews if view sizes start arguing
    if (priv->didLayout) {
        return;
    }
    [self setNeedsLayout];
}

/**
 @Status Interoperable
*/
- (void)layoutSublayers {
    if ([priv->delegate respondsToSelector:@selector(layoutSublayersOfLayer:)]) {
        [priv->delegate layoutSublayersOfLayer:self];
    }
}

- (std::shared_ptr<ILayerProxy>)_layerProxy {
    return priv->_layerProxy;
}

- (int)_pixelWidth {
    return (int)priv->bounds.size.width * priv->contentsScale;
}

- (int)_pixelHeight {
    return (int)priv->bounds.size.height * priv->contentsScale;
}

- (void)_setRootLayer:(BOOL)isRootLayer {
    priv->isRootLayer = isRootLayer;
}

// Queries for, caches, and returns our backing XAML node's sublayer element.
- (FrameworkElement)_getSublayerXamlElement {
    if (!priv->_sublayerXamlElement) {
        Microsoft::WRL::ComPtr<IInspectable> inspectable(priv->_layerProxy->GetSublayerXamlElement());
        priv->_sublayerXamlElement = objcwinrt::from_insp<FrameworkElement>(inspectable);
    }

    return priv->_sublayerXamlElement;
}

// CAUTION: This is debug-only/temporary code; don't use it anywhere else!
void GetLayerTransform(CALayer* layer, CGAffineTransform* outTransform) {
    static const int c_maxDepth = 32;

    //  Work backwards to its root layer
    CALayer* layerList[c_maxDepth];
    int layerListLen = 0;

    CALayer* curLayer = (CALayer*)layer;

    while (curLayer != nil) {
        assert(layerListLen < c_maxDepth);
        layerList[layerListLen++] = curLayer;

        curLayer = (CALayer*)curLayer->priv->superlayer;
    }

    //  Build transform
    CGPoint origin;

    *outTransform = CGAffineTransformMakeTranslation(0.0f, 0.0f);

    origin.x = 0;
    origin.y = 0;

    for (int i = layerListLen - 1; i >= 0; i--) {
        curLayer = layerList[i];

        *outTransform =
            CGAffineTransformTranslate(*outTransform, curLayer->priv->position.x - origin.x, curLayer->priv->position.y - origin.y);

        CGAffineTransform transform;

        transform.a = curLayer->priv->transform.m[0][0];
        transform.b = curLayer->priv->transform.m[0][1];
        transform.c = curLayer->priv->transform.m[1][0];
        transform.d = curLayer->priv->transform.m[1][1];
        transform.tx = curLayer->priv->transform.m[3][0];
        transform.ty = curLayer->priv->transform.m[3][1];

        *outTransform = CGAffineTransformConcat(transform, *outTransform);
        *outTransform = CGAffineTransformTranslate(*outTransform, -curLayer->priv->bounds.origin.x, -curLayer->priv->bounds.origin.y);

        //  Calculate new center point
        origin.x = curLayer->priv->bounds.size.width * curLayer->priv->anchorPoint.x;
        origin.y = curLayer->priv->bounds.size.height * curLayer->priv->anchorPoint.y;
    }
}

// CAUTION: This is debug-only/temporary code; don't use it anywhere else!
CGPoint _legacyConvertPoint(CGPoint point, CALayer* fromLayer, CALayer* toLayer) {
    //  Convert the point to center-based position
    point.x -= fromLayer->priv->bounds.size.width * fromLayer->priv->anchorPoint.x;
    point.y -= fromLayer->priv->bounds.size.height * fromLayer->priv->anchorPoint.y;

    //  Convert to world-view
    CGAffineTransform fromTransform;
    GetLayerTransform(fromLayer, &fromTransform);
    point = CGPointApplyAffineTransform(point, fromTransform);

    CGAffineTransform toTransform;
    GetLayerTransform(toLayer, &toTransform);
    toTransform = CGAffineTransformInvert(toTransform);
    point = CGPointApplyAffineTransform(point, toTransform);

    //  Convert the point from center-based position
    point.x += toLayer->priv->bounds.size.width * toLayer->priv->anchorPoint.x;
    point.y += toLayer->priv->bounds.size.height * toLayer->priv->anchorPoint.y;

    return point;
}

// CAUTION: This is debug-only/temporary code and won't work in most scenarios; don't use it anywhere else!
bool _floatAlmostEqual(float a, float b) {
    // Just look at two trailing decimals for our touch point
    a = std::floor(a * 100) / 100;
    b = std::floor(b * 100) / 100;
    return (fabs(a - b) <= FLT_EPSILON);
}

/**
 @Status Interoperable
*/
+ (CGPoint)convertPoint:(CGPoint)point fromLayer:(CALayer*)fromLayer toLayer:(CALayer*)toLayer {
    if (!fromLayer && !toLayer) {
        if (DEBUG_VERBOSE) {
            TraceVerbose(TAG, L"convertPoint cannot convert points for two nil layers.");
        }

        return point;
    }

    UIElement fromLayerElement = nullptr;
    UIElement toLayerElement = nullptr;

    if (fromLayer) {
        // Get the backing sublayer xaml UIElement for fromLayer
        // We use the sublayer element to support proper point conversion within a scrolled view.
        fromLayerElement = [fromLayer _getSublayerXamlElement];
    } else if (GetCACompositor()->IsRunningAsFramework()) {
        // In framework mode we don't own the topmost layer
        fromLayerElement = Window::Current().Content();
    } else {
        // Get the topmost layer for the current layer hierarchy
        fromLayer = _findSuperLayerForLayer(toLayer);
        fromLayerElement = [fromLayer _getSublayerXamlElement];
    }

    if (toLayer) {
        toLayerElement = [toLayer _getSublayerXamlElement];
    } else if (GetCACompositor()->IsRunningAsFramework()) {
        toLayerElement = Window::Current().Content();
    } else {
        toLayer = _findSuperLayerForLayer(fromLayer);
        toLayerElement = [toLayer _getSublayerXamlElement];
    }

    // set up transform from xaml elment in fromLayer to xaml element in toLayer
    Media::GeneralTransform transform = fromLayerElement.TransformToVisual(toLayerElement);

    // transform the points in fromLayer to point in toLayer
    winrt::Windows::Foundation::Point pointInFromLayer{ point.x, point.y };
    winrt::Windows::Foundation::Point pointInToLayer = transform.TransformPoint(pointInFromLayer);
    CGPoint ret = { pointInToLayer.X, pointInToLayer.Y };

    if (DEBUG_VERBOSE && fromLayer && toLayer) {
        // How does our new convertPoint logic compare to the legacy logic?
        CGPoint legacyPoint = _legacyConvertPoint(point, fromLayer, toLayer);
        if (!_floatAlmostEqual(ret.x, legacyPoint.x) || !_floatAlmostEqual(ret.y, legacyPoint.y)) {
            TraceWarning(TAG,
                         L"convertPoint: The legacy point {%f, %f} did not match the new point {%f, %f}!",
                         legacyPoint.x,
                         legacyPoint.y,
                         ret.x,
                         ret.y);
        }

        TraceVerbose(
            TAG, L"convertPoint:{%f, %f} to:{%f, %f}, legacyPoint={%f, %f}", point.x, point.y, ret.x, ret.y, legacyPoint.x, legacyPoint.y);
    }

    return ret;
}

+ (CGRect)convertRect:(CGRect)pos fromLayer:(CALayer*)fromLayer toLayer:(CALayer*)toLayer {
    if (!fromLayer && !toLayer) {
        if (DEBUG_VERBOSE) {
            TraceVerbose(TAG, L"convertRect cannot convert rects for two nil layers.");
        }

        return pos;
    }

    UIElement fromLayerElement = nullptr;
    UIElement toLayerElement = nullptr;

    if (fromLayer) {
        // Get the backing sublayer xaml UIElement for fromLayer
        // We use the sublayer element to support proper point conversion within a scrolled view.
        fromLayerElement = [fromLayer _getSublayerXamlElement];
    } else if (GetCACompositor()->IsRunningAsFramework()) {
        // In framework mode we don't own the topmost layer
        fromLayerElement = Window::Current().Content();
    } else {
        // Get the topmost layer for the current layer hierarchy
        fromLayer = _findSuperLayerForLayer(toLayer);
        fromLayerElement = [fromLayer _getSublayerXamlElement];
    }

    if (toLayer) {
        toLayerElement = [toLayer _getSublayerXamlElement];
    } else if (GetCACompositor()->IsRunningAsFramework()) {
        toLayerElement = Window::Current().Content();
    } else {
        toLayer = _findSuperLayerForLayer(fromLayer);
        toLayerElement = [toLayer _getSublayerXamlElement];
    }

    // set up transform from xaml elment in fromLayer to xaml element in toLayer
    Media::GeneralTransform transform = fromLayerElement.TransformToVisual(toLayerElement);

    // transform the rect in fromLayer to rect in toLayer
    winrt::Windows::Foundation::Rect rectInFromLayer =
        RectHelper::FromCoordinatesAndDimensions(pos.origin.x, pos.origin.y, pos.size.width, pos.size.height);
    winrt::Windows::Foundation::Rect rectInToLayer = transform.TransformBounds(rectInFromLayer);

    CGRect ret = { rectInToLayer.X, rectInToLayer.Y, rectInToLayer.Width, rectInToLayer.Height };

    if (DEBUG_VERBOSE) {
        TraceVerbose(TAG,
                     L"convertRect: {origin:{%f, %f} size:{%f, %f}} to {origin:{%f, %f} size:{%f, %f}}",
                     pos.origin.x,
                     pos.origin.y,
                     pos.size.width,
                     pos.size.height,
                     ret.origin.x,
                     ret.origin.y,
                     ret.size.width,
                     ret.size.height);
    }

    return ret;
}

- (NSObject*)_presentationValueForKey:(NSString*)key {
    return reinterpret_cast<NSObject*>(priv->_layerProxy->GetPropertyValue([key UTF8String]));
}

////////////////////////////////////////////////////////////////////
// TODO: This is a hack only here for UIWindow
// We should find it a better home (just setting its backing Canvas.Z-Index property directly should be sufficient)
- (void)_setZIndex:(int)zIndex {
    NSNumber* newZIndex = [[NSNumber alloc] initWithInt:zIndex];
    [CATransaction _setPropertyForLayer:self name:@"zIndex" value:newZIndex];
    [newZIndex release];
}

/**
 @Status Stub
 @Notes
*/
- (BOOL)needsDisplay {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
+ (BOOL)needsDisplayForKey:(NSString*)key {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
- (void)setNeedsDisplayInRect:(CGRect)theRect {
    UNIMPLEMENTED();
}

/**
 @Status Stub
 @Notes
*/
- (CFTimeInterval)convertTime:(CFTimeInterval)timeInterval fromLayer:(CALayer*)layer {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Interoperable
*/
- (BOOL)needsLayout {
    return priv->needsLayout;
}

/**
 @Status Stub
 @Notes
*/
- (instancetype)initWithCoder:(NSCoder*)decoder {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
- (void)encodeWithCoder:(NSCoder*)encoder {
    UNIMPLEMENTED();
}

/**
 @Status Stub
 @Notes
*/
- (id)modelLayer {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
- (BOOL)contentsAreFlipped {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
- (CGSize)preferredFrameSize {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
- (CFTimeInterval)convertTime:(CFTimeInterval)timeInterval toLayer:(CALayer*)layer {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
- (void)scrollPoint:(CGPoint)thePoint {
    UNIMPLEMENTED();
}

/**
 @Status Stub
 @Notes
*/
- (void)scrollRectToVisible:(CGRect)theRect {
    UNIMPLEMENTED();
}

/**
 @Status Stub
 @Notes
*/
- (BOOL)shouldArchiveValueForKey:(NSString*)key {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
+ (id)defaultValueForKey:(NSString*)key {
    UNIMPLEMENTED();
    return StubReturn();
}

@end

void SetCACompositor(CACompositorInterface* compositorInterface) {
    _globalCompositor = compositorInterface;
}

CACompositorInterface* GetCACompositor() {
    return _globalCompositor;
}
