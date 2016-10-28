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

#import <StubReturn.h>
#import <Starboard.h>
#import <math.h>

#import "CGSurfaceInfoInternal.h" // TODO(DH) Evaluate the need for this header.

#import <CoreGraphics/CGContext.h>
#import <CoreGraphics/CGPath.h>
#import <CoreGraphics/CGLayer.h>
#import <CoreGraphics/CGAffineTransform.h>
#import <CoreGraphics/CGGradient.h>
#import "CGColorSpaceInternal.h"
#import "CGContextInternal.h"

#import <CFCppBase.h>

#include <COMIncludes.h>
#import <d2d1.h>
#import <d2d1_1.h>
#import <d2d1effects_2.h>
#import <wrl/client.h>
#include <COMIncludes_end.h>
#import <LoggingNative.h>

#import <list>
#import <vector>
#import <stack>
#import <algorithm>

using namespace Microsoft::WRL;

static inline D2D_RECT_F __CGRectToD2D_F(CGRect rect) {
    return {
        rect.origin.x, rect.origin.y, rect.origin.x + rect.size.width, rect.origin.y + rect.size.height,
    };
}

static inline D2D1_MATRIX_3X2_F __CGAffineTransformToD2D_F(CGAffineTransform transform) {
    return { transform.a, transform.b, transform.c, transform.d, transform.tx, transform.ty };
}

struct __CGContextDrawingState {
    // This is populated when the state is saved, and contains the D2D parameters that CG does not know.
    ComPtr<ID2D1DrawingStateBlock> d2dState{ nullptr };

    // Fills
    ComPtr<ID2D1Brush> fillBrush{ nullptr };

    // Strokes
    ComPtr<ID2D1Brush> strokeBrush{ nullptr };
    D2D1_STROKE_STYLE_PROPERTIES strokeProperties{
        D2D1_CAP_STYLE_FLAT,
        D2D1_CAP_STYLE_FLAT,
        D2D1_CAP_STYLE_FLAT,
        D2D1_LINE_JOIN_MITER,
        10.f, // Default from Reference Docs
        D2D1_DASH_STYLE_SOLID,
        0.f,
    };
    std::vector<CGFloat> dashes{};
    CGFloat lineWidth = 1.0f;

    // Computed from the above at draw time
    ComPtr<ID2D1StrokeStyle> strokeStyle{ nullptr };

    CGFloat flatness = 0.0f;

    // Image Drawing
    D2D1_INTERPOLATION_MODE bitmapInterpolationMode = D2D1_INTERPOLATION_MODE_NEAREST_NEIGHBOR;

    // Userspace Coordinate Transformation
    CGAffineTransform transform{ CGAffineTransformIdentity };
    CGAffineTransform textMatrix{ CGAffineTransformIdentity };

    // Alpha Blending
    CGFloat alpha = 1.0f;

    inline void ComputeStrokeStyle(ID2D1DeviceContext* deviceContext) {
        if (strokeStyle) {
            return;
        }

        if (std::fpclassify(lineWidth) == FP_ZERO) {
            // Set no stroke style.
            return;
        }

        ComPtr<ID2D1Factory> factory;
        deviceContext->GetFactory(&factory);

        std::vector<float> adjustedDashes(dashes.size());
        std::transform(dashes.cbegin(), dashes.cend(), adjustedDashes.begin(), [this](const CGFloat& f) -> float { return f / lineWidth; });
        FAIL_FAST_IF_FAILED(factory->CreateStrokeStyle(strokeProperties, adjustedDashes.data(), adjustedDashes.size(), &strokeStyle));
    }

    inline void ClearStrokeStyle() {
        strokeStyle.Reset();
    }
};

struct __CGContextImpl {
    ComPtr<ID2D1RenderTarget> renderTarget{ nullptr };

    // Calculated at creation time, this transform flips CG's drawing commands,
    // anchored in the bottom left, to D2D's top-left coordinate system.
    CGAffineTransform cgCompatibilityTransform{ CGAffineTransformIdentity };

    std::stack<__CGContextDrawingState> stateStack{};

    woc::unique_cf<CGMutablePathRef> currentPath{ nullptr };

    // TODO(DH) GH#1070 evaluate these defaults; they should be set by context creators.
    bool allowsAntialiasing = false;
    bool allowsFontSmoothing = false;
    bool allowsFontSubpixelPositioning = false;
    bool allowsFontSubpixelQuantization = false;

    __CGContextImpl() {
        // Set up a default/baseline state
        stateStack.emplace();
    }
};

struct __CGContext : CoreFoundation::CppBase<__CGContext, __CGContextImpl> {
    inline ComPtr<ID2D1RenderTarget>& RenderTarget() {
        return _impl.renderTarget;
    }

    inline std::stack<__CGContextDrawingState>& GStateStack() {
        return _impl.stateStack;
    }

    inline __CGContextDrawingState& CurrentGState() {
        return GStateStack().top();
    }

    inline bool HasPath() {
        return _impl.currentPath != nullptr;
    }

    inline CGMutablePathRef Path() {
        if (!_impl.currentPath) {
            _impl.currentPath.reset(CGPathCreateMutable());
        }
        return _impl.currentPath.get();
    }

    inline void SetPath(CGMutablePathRef path) {
        _impl.currentPath.reset(CGPathRetain(path));
    }

    inline void ClearPath() {
        _impl.currentPath.reset();
    }

    inline ComPtr<ID2D1Factory> Factory() {
        ComPtr<ID2D1Factory> factory;
        _impl.renderTarget->GetFactory(&factory);
        return factory;
    }
};

#define NOISY_RETURN_IF_NULL(param, ...)                                         \
    do {                                                                         \
        if (!context) {                                                          \
            TraceError(TAG, L"%hs: null " #param "!", __PRETTY_FUNCTION__); \
            return __VA_ARGS__;                                                  \
        }                                                                        \
    \
} while (0)

static const wchar_t* TAG = L"CGContext";

#pragma region Global State - CFRuntimeClass
/**
 @Status Interoperable
*/
CFTypeID CGContextGetTypeID() {
    return __CGContext::GetTypeID();
}
#pragma endregion

#pragma region Global State - Lifetime
static void __CGContextInitWithRenderTarget(CGContextRef context, ID2D1RenderTarget* renderTarget) {
    context->_impl.renderTarget = renderTarget;

    // Reference platform defaults:
    // * Fill  : fully transparent black
    // * Stroke: fully opaque black
    // If a context does not support alpha, the default fill looks like fully opaque black.
    CGContextSetRGBFillColor(context, 0, 0, 0, 0);
    CGContextSetRGBStrokeColor(context, 0, 0, 0, 1);
}

CGContextRef _CGContextCreateWithD2DRenderTarget(ID2D1RenderTarget* renderTarget) {
    FAIL_FAST_HR_IF_NULL(E_INVALIDARG, renderTarget);
    CGContextRef context = __CGContext::CreateInstance(kCFAllocatorDefault);
    __CGContextInitWithRenderTarget(context, renderTarget);
    return context;
}

/**
 @Status Interoperable
*/
CGContextRef CGContextRetain(CGContextRef context) {
    if (!context) {
        return nullptr;
    }

    CFRetain((CFTypeRef)context);
    return context;
}

/**
 @Status Interoperable
*/
void CGContextRelease(CGContextRef context) {
    if (!context) {
        return;
    }

    CFRelease((CFTypeRef)context);
}
#pragma endregion

#pragma region Global State - Graphics State Stack
/**
 @Status Interoperable
*/
void CGContextSaveGState(CGContextRef context) {
    NOISY_RETURN_IF_NULL(context);
    auto& oldState = context->CurrentGState();

    // This uses the drawing state's copy constructor.
    context->GStateStack().emplace(oldState);

    auto factory = context->Factory();
    ComPtr<ID2D1DrawingStateBlock> drawingState;
    FAIL_FAST_IF_FAILED(factory->CreateDrawingStateBlock(&drawingState));

    context->RenderTarget()->SaveDrawingState(drawingState.Get());
    oldState.d2dState = drawingState;
}

/**
 @Status Interoperable
*/
void CGContextRestoreGState(CGContextRef context) {
    NOISY_RETURN_IF_NULL(context);
    if (context->GStateStack().size() <= 1) {
        TraceError(TAG, L"Invalid attempt to pop last graphics state.");
        return;
    }

    context->GStateStack().pop();
    auto& newState = context->CurrentGState();
    context->RenderTarget()->RestoreDrawingState(newState.d2dState.Get());
    newState.d2dState = nullptr;
}
#pragma endregion

#pragma region Global State - Context Maintenance
/**
 @Status Stub
*/
void CGContextFlush(CGContextRef context) {
    NOISY_RETURN_IF_NULL(context);
    UNIMPLEMENTED();
}

/**
 @Status Stub
 @Notes
*/
void CGContextSynchronize(CGContextRef context) {
    NOISY_RETURN_IF_NULL(context);
    UNIMPLEMENTED();
}
#pragma endregion

#pragma region Global State - Transparency Layers
/**
 @Status Interoperable
*/
void CGContextBeginTransparencyLayer(CGContextRef context, CFDictionaryRef auxInfo) {
    NOISY_RETURN_IF_NULL(context);
    UNIMPLEMENTED();
}

/**
 @Status Interoperable
*/
void CGContextBeginTransparencyLayerWithRect(CGContextRef context, CGRect rect, CFDictionaryRef auxInfo) {
    NOISY_RETURN_IF_NULL(context);
    UNIMPLEMENTED();
}

/**
 @Status Interoperable
*/
void CGContextEndTransparencyLayer(CGContextRef context) {
    NOISY_RETURN_IF_NULL(context);
    UNIMPLEMENTED();
}
#pragma endregion

#pragma region Global State - Pagination
/**
 @Status Stub
 @Notes
*/
void CGContextBeginPage(CGContextRef context, const CGRect* mediaBox) {
    NOISY_RETURN_IF_NULL(context);
    UNIMPLEMENTED();
}

/**
 @Status Stub
 @Notes
*/
void CGContextEndPage(CGContextRef context) {
    NOISY_RETURN_IF_NULL(context);
    UNIMPLEMENTED();
}
#pragma endregion

#pragma region Global State - Device Coordinate Queries
/**
 @Status Stub
*/
CGRect CGContextConvertRectToDeviceSpace(CGContextRef context, CGRect rect) {
    NOISY_RETURN_IF_NULL(context, StubReturn());
    UNIMPLEMENTED();
    return rect;
}

/**
 @Status Stub
*/
CGRect CGContextConvertRectToUserSpace(CGContextRef context, CGRect rect) {
    NOISY_RETURN_IF_NULL(context, StubReturn());
    UNIMPLEMENTED();
    return rect;
}

/**
 @Status Stub
*/
CGPoint CGContextConvertPointToUserSpace(CGContextRef context, CGPoint point) {
    NOISY_RETURN_IF_NULL(context, StubReturn());
    UNIMPLEMENTED();
    return point;
}

/**
 @Status Stub
*/
CGSize CGContextConvertSizeToUserSpace(CGContextRef context, CGSize size) {
    NOISY_RETURN_IF_NULL(context, StubReturn());
    UNIMPLEMENTED();
    return size;
}

/**
 @Status Stub
*/
CGSize CGContextConvertSizeToDeviceSpace(CGContextRef context, CGSize size) {
    NOISY_RETURN_IF_NULL(context, StubReturn());
    UNIMPLEMENTED();
    return size;
}

/**
 @Status Stub
*/
CGPoint CGContextConvertPointToDeviceSpace(CGContextRef context, CGPoint point) {
    NOISY_RETURN_IF_NULL(context, StubReturn());
    UNIMPLEMENTED();
    return point;
}

/**
 @Status Stub
 @Notes
*/
CGAffineTransform CGContextGetUserSpaceToDeviceSpaceTransform(CGContextRef context) {
    NOISY_RETURN_IF_NULL(context, StubReturn());
    UNIMPLEMENTED();
    return StubReturn();
}
#pragma endregion

#pragma region Global State - CTM
/**
 @Status Interoperable
*/
CGAffineTransform CGContextGetCTM(CGContextRef context) {
    NOISY_RETURN_IF_NULL(context, StubReturn());
    auto& state = context->CurrentGState();
    return state.transform;
}

/**
 @Status Interoperable
*/
void CGContextTranslateCTM(CGContextRef context, CGFloat x, CGFloat y) {
    NOISY_RETURN_IF_NULL(context);
    CGContextConcatCTM(context, CGAffineTransformMakeTranslation(x, y));
}

/**
 @Status Interoperable
*/
void CGContextScaleCTM(CGContextRef context, CGFloat sx, CGFloat sy) {
    NOISY_RETURN_IF_NULL(context);
    CGContextConcatCTM(context, CGAffineTransformMakeScale(sx, sy));
}

/**
 @Status Interoperable
*/
void CGContextRotateCTM(CGContextRef context, CGFloat angle) {
    NOISY_RETURN_IF_NULL(context);
    CGContextConcatCTM(context, CGAffineTransformMakeRotation(angle));
}

/**
 @Status Interoperable
*/
void CGContextConcatCTM(CGContextRef context, CGAffineTransform t) {
    NOISY_RETURN_IF_NULL(context);
    auto& state = context->CurrentGState();
    state.transform = CGAffineTransformConcat(t, state.transform);
}

/**
 @Status Interoperable
*/
void CGContextSetCTM(CGContextRef context, CGAffineTransform transform) {
    NOISY_RETURN_IF_NULL(context);
    auto& state = context->CurrentGState();
    state.transform = transform;
}
#pragma endregion

#pragma region Global State - Path Manipulation
/**
 @Status Interoperable
*/
void CGContextBeginPath(CGContextRef context) {
    NOISY_RETURN_IF_NULL(context);

    // All subsequent path functions will create the new path as necessary.
    context->ClearPath();
}

/**
 @Status Interoperable
*/
void CGContextClosePath(CGContextRef context) {
    NOISY_RETURN_IF_NULL(context);

    CGPathCloseSubpath(context->Path());
}

/**
 @Status Interoperable
*/
void CGContextAddRect(CGContextRef context, CGRect rect) {
    NOISY_RETURN_IF_NULL(context);

    CGPathAddRect(context->Path(), &(context->CurrentGState().transform), rect);
}

/**
 @Status Interoperable
*/
void CGContextAddRects(CGContextRef context, const CGRect* rects, unsigned count) {
    NOISY_RETURN_IF_NULL(context);

    if (count == 0 || !rects) {
        return;
    }

    for (unsigned i = 0; i < count; i++) {
        CGContextAddRect(context, rects[i]);
    }
}

/**
 @Status Interoperable
*/
void CGContextAddLineToPoint(CGContextRef context, CGFloat x, CGFloat y) {
    NOISY_RETURN_IF_NULL(context);

    CGPathAddLineToPoint(context->Path(), &(context->CurrentGState().transform), x, y);
}

/**
 @Status Interoperable
*/
void CGContextAddCurveToPoint(CGContextRef context, CGFloat cp1x, CGFloat cp1y, CGFloat cp2x, CGFloat cp2y, CGFloat x, CGFloat y) {
    NOISY_RETURN_IF_NULL(context);

    CGPathAddCurveToPoint(context->Path(), &(context->CurrentGState().transform), cp1x, cp1y, cp2x, cp2y, x, y);
}

/**
 @Status Interoperable
*/
void CGContextAddQuadCurveToPoint(CGContextRef context, CGFloat cpx, CGFloat cpy, CGFloat x, CGFloat y) {
    NOISY_RETURN_IF_NULL(context);

    CGPathAddQuadCurveToPoint(context->Path(), &(context->CurrentGState().transform), cpx, cpy, x, y);
}

/**
 @Status Interoperable
*/
void CGContextMoveToPoint(CGContextRef context, CGFloat x, CGFloat y) {
    NOISY_RETURN_IF_NULL(context);

    CGPathMoveToPoint(context->Path(), &(context->CurrentGState().transform), x, y);
}

/**
 @Status Interoperable
*/
void CGContextAddArc(CGContextRef context, CGFloat x, CGFloat y, CGFloat radius, CGFloat startAngle, CGFloat endAngle, int clockwise) {
    NOISY_RETURN_IF_NULL(context);

    CGPathAddArc(context->Path(), &(context->CurrentGState().transform), x, y, radius, startAngle, endAngle, clockwise);
}

/**
 @Status Interoperable
*/
void CGContextAddArcToPoint(CGContextRef context, CGFloat x1, CGFloat y1, CGFloat x2, CGFloat y2, CGFloat radius) {
    NOISY_RETURN_IF_NULL(context);

    CGPathAddArcToPoint(context->Path(), &(context->CurrentGState().transform), x1, y1, x2, y2, radius);
}

/**
 @Status Interoperable
*/
void CGContextAddEllipseInRect(CGContextRef context, CGRect rect) {
    NOISY_RETURN_IF_NULL(context);

    CGPathAddEllipseInRect(context->Path(), &(context->CurrentGState().transform), rect);
}

/**
 @Status Interoperable
*/
void CGContextAddPath(CGContextRef context, CGPathRef path) {
    NOISY_RETURN_IF_NULL(context);
    if (!path) {
        return;
    }

    if (!context->HasPath()) {
        // If we don't curerntly have a path, take this one in as our own.
        woc::unique_cf<CGMutablePathRef> copiedPath{ CGPathCreateMutableCopy(path) };
        context->SetPath(copiedPath.get());
        return;
    }

    CGPathAddPath(context->Path(), &(context->CurrentGState().transform), path);
}

/**
 @Status Stub
*/
void CGContextReplacePathWithStrokedPath(CGContextRef context) {
    NOISY_RETURN_IF_NULL(context);

    if (!context->HasPath()) {
        return;
    }

    auto& state = context->CurrentGState();

// TODO GH#xxxx When CGPathCreateCopyByStrokingPath is no longer stubbed, remove the diagnostic suppression.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

    woc::unique_cf<CGPathRef> newPath{ CGPathCreateCopyByStrokingPath(context->Path(),
                                                                      &state.transform,
                                                                      state.lineWidth,
                                                                      (CGLineCap)state.strokeProperties.startCap,
                                                                      (CGLineJoin)state.strokeProperties.lineJoin,
                                                                      state.strokeProperties.miterLimit) };

#pragma clang diagnostic pop

    woc::unique_cf<CGMutablePathRef> newMutablePath{ CGPathCreateMutableCopy(newPath.get()) };
    context->SetPath(newMutablePath.get());
}

/**
 @Status Interoperable
*/
bool CGContextIsPathEmpty(CGContextRef context) {
    NOISY_RETURN_IF_NULL(context, StubReturn());

    return context->HasPath() && CGPathIsEmpty(context->Path());
}

/**
 @Status Interoperable
*/
CGRect CGContextGetPathBoundingBox(CGContextRef context) {
    NOISY_RETURN_IF_NULL(context, CGRectNull);

    if (!context->HasPath()) {
        return CGRectNull;
    }

    return CGPathGetBoundingBox(context->Path());
}

/**
 @Status Interoperable
*/
void CGContextAddLines(CGContextRef context, const CGPoint* points, unsigned count) {
    NOISY_RETURN_IF_NULL(context);

    if (!count || !points) {
        return;
    }

    CGPathAddLines(context->Path(), &(context->CurrentGState().transform), points, count);
}
#pragma endregion

#pragma region Global State - Path Queries
/**
 @Status Interoperable
 @Notes
*/
CGPathRef CGContextCopyPath(CGContextRef context) {
    NOISY_RETURN_IF_NULL(context, nullptr);

    if (!context->HasPath()) {
        return nullptr;
    }

    return CGPathCreateCopy(context->Path());
}

/**
 @Status Stub
 @Notes
*/
CGPoint CGContextGetPathCurrentPoint(CGContextRef context) {
    NOISY_RETURN_IF_NULL(context, CGPointZero);

    if (!context->HasPath()) {
        return CGPointZero;
    }

    return CGPathGetCurrentPoint(context->Path());
}

/**
 @Status Stub
 @Notes
*/
bool CGContextPathContainsPoint(CGContextRef context, CGPoint point, CGPathDrawingMode mode) {
    NOISY_RETURN_IF_NULL(context, false);

    if (!context->HasPath()) {
        return false;
    }

    return CGPathContainsPoint(context->Path(), &(context->CurrentGState().transform), point, (mode & kCGPathEOFill));
}
#pragma endregion

#pragma region Global State - Clipping and Masking
/// TODO(DH): GH#future Clipping and Masking
/**
 @Status Interoperable
*/
void CGContextClip(CGContextRef context) {
    NOISY_RETURN_IF_NULL(context);
    UNIMPLEMENTED();
}

/**
 @Status Interoperable
*/
void CGContextEOClip(CGContextRef context) {
    NOISY_RETURN_IF_NULL(context);
    UNIMPLEMENTED();
}

/**
 @Status Interoperable
*/
void CGContextClipToRect(CGContextRef context, CGRect rect) {
    NOISY_RETURN_IF_NULL(context);
    CGContextBeginPath(context);
    CGContextAddRect(context, rect);
    CGContextClip(context);
}

/**
 @Status Interoperable
*/
void CGContextClipToRects(CGContextRef context, const CGRect* rects, unsigned count) {
    NOISY_RETURN_IF_NULL(context);
    if (!rects || count == 0) {
        return;
    }

    CGContextBeginPath(context);
    CGContextAddRects(context, rects, count);
    CGContextClip(context);
}

/**
 @Status Caveat
 @Notes Limited bitmap format support
*/
void CGContextClipToMask(CGContextRef context, CGRect dest, CGImageRef image) {
    NOISY_RETURN_IF_NULL(context);
    UNIMPLEMENTED();
}

/**
 @Status Interoperable
*/
CGRect CGContextGetClipBoundingBox(CGContextRef context) {
    NOISY_RETURN_IF_NULL(context, StubReturn());
    UNIMPLEMENTED();
    return StubReturn();
}
#pragma endregion

#pragma region Drawing Parameters - Text
/**
 @Status Stub
*/
void CGContextSetCharacterSpacing(CGContextRef context, CGFloat spacing) {
    NOISY_RETURN_IF_NULL(context);
    UNIMPLEMENTED();
}

/**
 @Status Interoperable
*/
void CGContextSetTextDrawingMode(CGContextRef context, CGTextDrawingMode mode) {
    NOISY_RETURN_IF_NULL(context);
    UNIMPLEMENTED();
}

/**
 @Status Interoperable
*/
void CGContextSetFont(CGContextRef context, CGFontRef font) {
    NOISY_RETURN_IF_NULL(context);
    UNIMPLEMENTED();
}

/**
 @Status Interoperable
*/
void CGContextSelectFont(CGContextRef context, const char* name, CGFloat size, CGTextEncoding encoding) {
    NOISY_RETURN_IF_NULL(context);
    UNIMPLEMENTED();
}

/**
 @Status Interoperable
*/
void CGContextSetFontSize(CGContextRef context, CGFloat ptSize) {
    NOISY_RETURN_IF_NULL(context);
    UNIMPLEMENTED();
}

/**
 @Status Interoperable
*/
void CGContextSetTextMatrix(CGContextRef context, CGAffineTransform matrix) {
    NOISY_RETURN_IF_NULL(context);
    UNIMPLEMENTED();
}

/**
 @Status Interoperable
*/
CGAffineTransform CGContextGetTextMatrix(CGContextRef context) {
    NOISY_RETURN_IF_NULL(context, StubReturn());
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Interoperable
*/
void CGContextSetTextPosition(CGContextRef context, CGFloat x, CGFloat y) {
    NOISY_RETURN_IF_NULL(context);
    UNIMPLEMENTED();
}

/**
 @Status Interoperable
*/
CGPoint CGContextGetTextPosition(CGContextRef context) {
    NOISY_RETURN_IF_NULL(context, StubReturn());
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
*/
void CGContextSetAllowsFontSmoothing(CGContextRef context, bool allows) {
    NOISY_RETURN_IF_NULL(context);
    UNIMPLEMENTED();
}

/**
 @Status Stub
*/
void CGContextSetShouldSmoothFonts(CGContextRef context, bool shouldSmooth) {
    NOISY_RETURN_IF_NULL(context);
    UNIMPLEMENTED();
}

/**
 @Status Stub
*/
void CGContextSetAllowsFontSubpixelPositioning(CGContextRef context, bool allows) {
    NOISY_RETURN_IF_NULL(context);
    UNIMPLEMENTED();
}

/**
 @Status Stub
*/
void CGContextSetShouldSubpixelPositionFonts(CGContextRef context, bool subpixel) {
    NOISY_RETURN_IF_NULL(context);
    UNIMPLEMENTED();
}

/**
 @Status Stub
*/
void CGContextSetAllowsFontSubpixelQuantization(CGContextRef context, bool allows) {
    NOISY_RETURN_IF_NULL(context);
    UNIMPLEMENTED();
}

/**
 @Status Stub
*/
void CGContextSetShouldSubpixelQuantizeFonts(CGContextRef context, bool subpixel) {
    NOISY_RETURN_IF_NULL(context);
    UNIMPLEMENTED();
}
#pragma endregion

#pragma region Drawing Parameters - Generic
/**
 @Status Interoperable
*/
void CGContextSetBlendMode(CGContextRef context, CGBlendMode mode) {
    NOISY_RETURN_IF_NULL(context);
    UNIMPLEMENTED();
}

CGBlendMode CGContextGetBlendMode(CGContextRef context) {
    NOISY_RETURN_IF_NULL(context, StubReturn());
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
*/
void CGContextSetShouldAntialias(CGContextRef context, bool shouldAntialias) {
    NOISY_RETURN_IF_NULL(context);
    UNIMPLEMENTED();
}

/**
 @Status Stub
*/
void CGContextSetAllowsAntialiasing(CGContextRef context, bool allows) {
    NOISY_RETURN_IF_NULL(context);
    UNIMPLEMENTED();
}

/**
 @Status Interoperable
 @Notes CGContext defaults to low-quality linear interpolation.
*/
void CGContextSetInterpolationQuality(CGContextRef context, CGInterpolationQuality quality) {
    NOISY_RETURN_IF_NULL(context);
    static D2D1_INTERPOLATION_MODE d2dModes[] = {
        /* Default */ D2D1_INTERPOLATION_MODE_LINEAR,
        /* None    */ D2D1_INTERPOLATION_MODE_NEAREST_NEIGHBOR,
        /* Low     */ D2D1_INTERPOLATION_MODE_LINEAR,
        /* Medium  */ D2D1_INTERPOLATION_MODE_MULTI_SAMPLE_LINEAR,
        /* High    */ D2D1_INTERPOLATION_MODE_CUBIC,
    };

    quality = std::max(std::min(quality, kCGInterpolationHigh), kCGInterpolationDefault);

    auto& state = context->CurrentGState();
    state.bitmapInterpolationMode = d2dModes[quality];
}

/**
 @Status Interoperable
 @Notes Low-quality interpolation will be returned if the default interpolation is set.
*/
CGInterpolationQuality CGContextGetInterpolationQuality(CGContextRef context) {
    NOISY_RETURN_IF_NULL(context, StubReturn());

    auto& state = context->CurrentGState();
    switch (state.bitmapInterpolationMode) {
        case D2D1_INTERPOLATION_MODE_NEAREST_NEIGHBOR:
            return kCGInterpolationNone;
        case D2D1_INTERPOLATION_MODE_LINEAR:
            return kCGInterpolationLow;
        case D2D1_INTERPOLATION_MODE_MULTI_SAMPLE_LINEAR:
            return kCGInterpolationMedium;
        case D2D1_INTERPOLATION_MODE_ANISOTROPIC:
        case D2D1_INTERPOLATION_MODE_CUBIC:
        case D2D1_INTERPOLATION_MODE_HIGH_QUALITY_CUBIC:
            return kCGInterpolationHigh;
        default:
            return kCGInterpolationDefault;
    }
}

/**
 @Status Stub
*/
void CGContextSetRenderingIntent(CGContextRef context, CGColorRenderingIntent intent) {
    NOISY_RETURN_IF_NULL(context);
    UNIMPLEMENTED();
}

/**
 @Status Interoperable
*/
void CGContextSetAlpha(CGContextRef context, CGFloat alpha) {
    NOISY_RETURN_IF_NULL(context);
    context->CurrentGState().alpha = alpha;
}

/**
 @Status Stub
 @Notes
*/
void CGContextSetFlatness(CGContextRef context, CGFloat flatness) {
    NOISY_RETURN_IF_NULL(context);
    UNIMPLEMENTED();
}
#pragma endregion

#pragma region Drawing Parameters - Stroke Style
/**
 @Status Interoperable
*/
void CGContextSetLineDash(CGContextRef context, CGFloat phase, const CGFloat* lengths, unsigned count) {
    NOISY_RETURN_IF_NULL(context);
    auto& state = context->CurrentGState();
    state.ClearStrokeStyle();

    auto& dashes = state.dashes;

    if (count == 0 || !lengths) {
        state.strokeProperties.dashOffset = 0;
        state.strokeProperties.dashStyle = D2D1_DASH_STYLE_SOLID;
        dashes.clear();
    } else {
        state.strokeProperties.dashOffset = phase;
        state.strokeProperties.dashStyle = D2D1_DASH_STYLE_CUSTOM;
        dashes.assign(lengths, lengths + count);
    }
}

/**
 @Status Interoperable
*/
void CGContextSetMiterLimit(CGContextRef context, CGFloat limit) {
    NOISY_RETURN_IF_NULL(context);
    auto& state = context->CurrentGState();
    state.ClearStrokeStyle();
    state.strokeProperties.miterLimit = limit;
}

/**
 @Status Interoperable
*/
void CGContextSetLineJoin(CGContextRef context, CGLineJoin lineJoin) {
    NOISY_RETURN_IF_NULL(context);
    auto& state = context->CurrentGState();
    state.ClearStrokeStyle();
    state.strokeProperties.lineJoin = (D2D1_LINE_JOIN)lineJoin;
}

/**
 @Status Interoperable
*/
void CGContextSetLineCap(CGContextRef context, CGLineCap lineCap) {
    NOISY_RETURN_IF_NULL(context);
    auto& state = context->CurrentGState();
    state.ClearStrokeStyle();
    state.strokeProperties.startCap = (D2D1_CAP_STYLE)lineCap;
    state.strokeProperties.endCap = (D2D1_CAP_STYLE)lineCap;
    state.strokeProperties.dashCap = (D2D1_CAP_STYLE)lineCap;
}

/**
 @Status Interoperable
*/
void CGContextSetLineWidth(CGContextRef context, CGFloat width) {
    NOISY_RETURN_IF_NULL(context);
    auto& state = context->CurrentGState();
    state.ClearStrokeStyle();
    state.lineWidth = width;
}
#pragma endregion

#pragma region Drawing Parameters - Stroke Color
/**
 @Status Stub
 @Notes Since we are currently missing Color Space support, this will need to be implemented.
*/
void CGContextSetStrokeColor(CGContextRef context, const CGFloat* components) {
    NOISY_RETURN_IF_NULL(context);
    UNIMPLEMENTED();
}

/**
 @Status Caveat
 @Notes Interoperable only for RGB.
*/
void CGContextSetStrokeColorWithColor(CGContextRef context, CGColorRef color) {
    NOISY_RETURN_IF_NULL(context);
    const CGFloat* comp = CGColorGetComponents(color);
    CGContextSetRGBStrokeColor(context, comp[0], comp[1], comp[2], comp[3]);
}

/**
 @Status Stub
 @Notes Since we are currently missing Color Space support, this will need to be implemented.
*/
void CGContextSetStrokeColorSpace(CGContextRef context, CGColorSpaceRef colorSpace) {
    NOISY_RETURN_IF_NULL(context);
    UNIMPLEMENTED();
}

/**
 @Status Interoperable
*/
void CGContextSetGrayStrokeColor(CGContextRef context, CGFloat gray, CGFloat alpha) {
    NOISY_RETURN_IF_NULL(context);
    CGContextSetRGBStrokeColor(context, gray, gray, gray, alpha);
}

/**
 @Status Interoperable
*/
void CGContextSetRGBStrokeColor(CGContextRef context, CGFloat r, CGFloat g, CGFloat b, CGFloat a) {
    NOISY_RETURN_IF_NULL(context);
    ComPtr<ID2D1SolidColorBrush> brush;
    FAIL_FAST_IF_FAILED(context->RenderTarget()->CreateSolidColorBrush({ r, g, b, a }, &brush));
    FAIL_FAST_IF_FAILED(brush.As(&context->CurrentGState().strokeBrush));
}

/**
 @Status Caveat
 @Notes Manually converts CMYK to RGB, and does not involve the colorspace.
*/
void CGContextSetCMYKStrokeColor(CGContextRef context, CGFloat cyan, CGFloat magenta, CGFloat yellow, CGFloat black, CGFloat alpha) {
    NOISY_RETURN_IF_NULL(context);
    CGContextSetRGBStrokeColor(context,
                               (1.0f - cyan) * (1.0f - black),
                               (1.0f - magenta) * (1.0f - black),
                               (1.0f - yellow) * (1.0f - black),
                               alpha);
}
#pragma endregion

#pragma region Drawing Parameters - Shadows
/**
 @Status Interoperable
*/
void CGContextSetShadow(CGContextRef context, CGSize offset, CGFloat blur) {
    NOISY_RETURN_IF_NULL(context);
    UNIMPLEMENTED();
}

/**
 @Status Interoperable
*/
void CGContextSetShadowWithColor(CGContextRef context, CGSize offset, CGFloat blur, CGColorRef color) {
    NOISY_RETURN_IF_NULL(context);
    UNIMPLEMENTED();
}
#pragma endregion

#pragma region Drawing Parameters - Fill Color
/**
 @Status Stub
 @Notes Since we are currently missing Color Space support, this will need to be implemented.
*/
void CGContextSetFillColor(CGContextRef context, const CGFloat* components) {
    NOISY_RETURN_IF_NULL(context);
    UNIMPLEMENTED();
}

/**
 @Status Caveat
 @Notes Interoperable only for RGB.
*/
void CGContextSetFillColorWithColor(CGContextRef context, CGColorRef color) {
    NOISY_RETURN_IF_NULL(context);
    const CGFloat* comp = CGColorGetComponents(color);
    CGContextSetRGBFillColor(context, comp[0], comp[1], comp[2], comp[3]);
}

/**
 @Status Stub
 @Notes Since we are currently missing Color Space support, this will need to be implemented.
*/
void CGContextSetFillColorSpace(CGContextRef context, CGColorSpaceRef colorSpace) {
    NOISY_RETURN_IF_NULL(context);
    UNIMPLEMENTED();
}

/**
 @Status Interoperable
*/
void CGContextSetGrayFillColor(CGContextRef context, CGFloat gray, CGFloat alpha) {
    NOISY_RETURN_IF_NULL(context);
    CGContextSetRGBFillColor(context, gray, gray, gray, alpha);
}

/**
 @Status Interoperable
*/
void CGContextSetRGBFillColor(CGContextRef context, CGFloat r, CGFloat g, CGFloat b, CGFloat a) {
    NOISY_RETURN_IF_NULL(context);
    ComPtr<ID2D1SolidColorBrush> brush;
    FAIL_FAST_IF_FAILED(context->RenderTarget()->CreateSolidColorBrush({ r, g, b, a }, &brush));
    FAIL_FAST_IF_FAILED(brush.As(&context->CurrentGState().fillBrush));
}

/**
 @Status Caveat
 @Notes Manually converts CMYK to RGB, and does not involve the colorspace.
*/
void CGContextSetCMYKFillColor(CGContextRef context, CGFloat cyan, CGFloat magenta, CGFloat yellow, CGFloat black, CGFloat alpha) {
    NOISY_RETURN_IF_NULL(context);
    CGContextSetRGBFillColor(context,
                             (1.0f - cyan) * (1.0f - black),
                             (1.0f - magenta) * (1.0f - black),
                             (1.0f - yellow) * (1.0f - black),
                             alpha);
}
#pragma endregion

#pragma region Drawing Parameters - Stroke/Fill Patterns
/**
 @Status Stub
 @Notes
*/
void CGContextSetStrokePattern(CGContextRef context, CGPatternRef pattern, const CGFloat* components) {
    NOISY_RETURN_IF_NULL(context);
    UNIMPLEMENTED();
}

/**
 @Status Interoperable
*/
void CGContextSetFillPattern(CGContextRef context, CGPatternRef pattern, const CGFloat* components) {
    NOISY_RETURN_IF_NULL(context);
    UNIMPLEMENTED();
}

/**
 @Status Interoperable
*/
void CGContextSetPatternPhase(CGContextRef context, CGSize phase) {
    NOISY_RETURN_IF_NULL(context);
    UNIMPLEMENTED();
}
#pragma endregion

#pragma region Drawing Operations - Text
/**
 @Status Stub
*/
void CGContextShowText(CGContextRef context, const char* str, unsigned count) {
    NOISY_RETURN_IF_NULL(context);
    UNIMPLEMENTED();
}

/**
 @Status Interoperable
*/
void CGContextShowTextAtPoint(CGContextRef context, CGFloat x, CGFloat y, const char* str, size_t length) {
    NOISY_RETURN_IF_NULL(context);
    UNIMPLEMENTED();
}

/**
 @Status Interoperable
*/
void CGContextShowGlyphsAtPoint(CGContextRef context, CGFloat x, CGFloat y, const CGGlyph* glyphs, unsigned count) {
    NOISY_RETURN_IF_NULL(context);
    UNIMPLEMENTED();
}

/**
 @Status Interoperable
*/
void CGContextShowGlyphs(CGContextRef context, const CGGlyph* glyphs, unsigned count) {
    NOISY_RETURN_IF_NULL(context);
    UNIMPLEMENTED();
}

/**
 @Status Stub
 @Notes
*/
void CGContextShowGlyphsAtPositions(CGContextRef context, const CGGlyph* glyphs, const CGPoint* Lpositions, size_t count) {
    NOISY_RETURN_IF_NULL(context);
    UNIMPLEMENTED();
}

/**
 @Status Interoperable
*/
void CGContextShowGlyphsWithAdvances(CGContextRef context, const CGGlyph* glyphs, const CGSize* advances, size_t count) {
    NOISY_RETURN_IF_NULL(context);
    UNIMPLEMENTED();
}
#pragma endregion

#pragma region Drawing Operations - CGImage
/// TODO(DH): GH#1078 Image Drawing
/**
 @Status Interoperable
*/
void CGContextDrawImage(CGContextRef context, CGRect rect, CGImageRef image) {
    NOISY_RETURN_IF_NULL(context);
    if (!image) {
        TraceWarning(TAG, L"Img == nullptr!");
        return;
    }
    if (!context) {
        TraceWarning(TAG, L"CGContextDrawImage: context == nullptr!");
        return;
    }

    UNIMPLEMENTED();
}

void CGContextDrawImageRect(CGContextRef context, CGImageRef image, CGRect src, CGRect dst) {
    NOISY_RETURN_IF_NULL(context);
    UNIMPLEMENTED();
}

/**
 @Status Interoperable
*/
void CGContextDrawTiledImage(CGContextRef context, CGRect rect, CGImageRef image) {
    NOISY_RETURN_IF_NULL(context);
    UNIMPLEMENTED();
}
#pragma endregion

#pragma region Drawing Operations - Basic Shapes
/**
 @Status Interoperable
*/
void CGContextClearRect(CGContextRef context, CGRect rect) {
    NOISY_RETURN_IF_NULL(context);
    ComPtr<ID2D1RenderTarget> renderTarget = context->RenderTarget();
    renderTarget->PushAxisAlignedClip(__CGRectToD2D_F(rect), D2D1_ANTIALIAS_MODE_PER_PRIMITIVE);
    renderTarget->Clear(nullptr); // transparent black clear
    renderTarget->PopAxisAlignedClip();
}

template <typename Lambda> // Lambda takes the form void(*)(CGContextRef, ID2D1DeviceContext*)
static void __CGContextRenderToCommandList(CGContextRef context, ID2D1CommandList** outCommandList, Lambda&& drawLambda) {
    ComPtr<ID2D1RenderTarget> renderTarget = context->RenderTarget();
    ComPtr<ID2D1DeviceContext> deviceContext;
    FAIL_FAST_IF_FAILED(renderTarget.As(&deviceContext));

    // Cache the original target to restore it later.
    ComPtr<ID2D1Image> originalTarget;
    deviceContext->GetTarget(&originalTarget);

    ComPtr<ID2D1CommandList> commandList;
    FAIL_FAST_IF_FAILED(deviceContext->CreateCommandList(&commandList));

    deviceContext->BeginDraw();
    deviceContext->SetTarget(commandList.Get());

    std::forward<Lambda>(drawLambda)(context, deviceContext.Get());

    FAIL_FAST_IF_FAILED(deviceContext->EndDraw());
    FAIL_FAST_IF_FAILED(commandList->Close());

    deviceContext->SetTarget(originalTarget.Get());

    *outCommandList = commandList.Detach();
}

static void __CGContextRenderCommandList(CGContextRef context, ID2D1CommandList* commandList) {
    ComPtr<ID2D1RenderTarget> renderTarget = context->RenderTarget();
    auto& state = context->CurrentGState();

    ComPtr<ID2D1DeviceContext> deviceContext;
    FAIL_FAST_IF_FAILED(renderTarget.As(&deviceContext));

    D2D1_SIZE_F targetSize = renderTarget->GetSize();

    // CG is a lower-left origin system (LLO), but D2D is upper left (ULO).
    // We have to translate the render area back onscreen and flip it up to ULO.
    CGAffineTransform transform = CGAffineTransformMake(1.f, 0.f, 0.f, -1.f, 0.f, targetSize.height);
    transform = CGAffineTransformConcat(state.transform, transform);
    deviceContext->SetTransform(__CGAffineTransformToD2D_F(transform));

    deviceContext->BeginDraw();

    bool layer = false;
    if (state.alpha != 1.0f || false /* mask, clip, etc. */) {
        layer = true;
        renderTarget->PushLayer(
            D2D1::LayerParameters(D2D1::InfiniteRect(), nullptr, D2D1_ANTIALIAS_MODE_PER_PRIMITIVE, D2D1::IdentityMatrix(), state.alpha),
            nullptr);
    }

    deviceContext->DrawImage(commandList);

    if (layer) {
        renderTarget->PopLayer();
    }

    // TODO GH#1194: We will need to re-evaluate Direct2D's D2DERR_RECREATE when we move to HW acceleration.
    FAIL_FAST_IF_FAILED(deviceContext->EndDraw());

    deviceContext->SetTransform(D2D1::IdentityMatrix());
}

static void __CGContextDrawGeometry(CGContextRef context, ID2D1Geometry* geometry, CGPathDrawingMode drawMode) {
    ComPtr<ID2D1CommandList> commandList;
    __CGContextRenderToCommandList(context, &commandList, [geometry, drawMode](CGContextRef context, ID2D1DeviceContext* deviceContext) {
        auto& state = context->CurrentGState();
        if (drawMode & kCGPathFill) {
            if (drawMode & kCGPathEOFill) {
                // TODO(DH): GH#1077 Regenerate geometry in Even/Odd fill mode.
            }
            deviceContext->FillGeometry(geometry, state.fillBrush.Get());
        }

        if (drawMode & kCGPathStroke && std::fpclassify(state.lineWidth) != FP_ZERO) {
            // This only computes the stroke style if its parameters have changed since the last draw.
            state.ComputeStrokeStyle(deviceContext);

            deviceContext->DrawGeometry(geometry, state.strokeBrush.Get(), state.lineWidth, state.strokeStyle.Get());
        }
    });

    __CGContextRenderCommandList(context, commandList.Get());
}

/**
 @Status Interoperable
 @Notes The current path is cleared as a side effect of this function.
*/
void CGContextStrokeRect(CGContextRef context, CGRect rect) {
    NOISY_RETURN_IF_NULL(context);
    auto factory = context->Factory();

    ComPtr<ID2D1Geometry> geometry;
    ComPtr<ID2D1RectangleGeometry> rectGeometry;
    FAIL_FAST_IF_FAILED(factory->CreateRectangleGeometry(__CGRectToD2D_F(rect), &rectGeometry));
    FAIL_FAST_IF_FAILED(rectGeometry.As(&geometry));

    __CGContextDrawGeometry(context, geometry.Get(), kCGPathStroke);

    context->ClearPath();
}

/**
 @Status Interoperable
 @Notes The current path is cleared as a side effect of this function.
*/
void CGContextStrokeRectWithWidth(CGContextRef context, CGRect rect, CGFloat width) {
    NOISY_RETURN_IF_NULL(context);
    CGContextSaveGState(context);
    CGContextSetLineWidth(context, width);
    CGContextStrokeRect(context, rect);
    CGContextRestoreGState(context);
}

/**
 @Status Interoperable
 @Notes The current path is cleared as a side effect of this function.
*/
void CGContextFillRect(CGContextRef context, CGRect rect) {
    NOISY_RETURN_IF_NULL(context);
    auto factory = context->Factory();

    ComPtr<ID2D1Geometry> geometry;
    ComPtr<ID2D1RectangleGeometry> rectGeometry;
    FAIL_FAST_IF_FAILED(factory->CreateRectangleGeometry(__CGRectToD2D_F(rect), &rectGeometry));
    FAIL_FAST_IF_FAILED(rectGeometry.As(&geometry));

    __CGContextDrawGeometry(context, geometry.Get(), kCGPathFill);

    context->ClearPath();
}

/**
 @Status Interoperable
 @Notes The current path is cleared as a side effect of this function.
*/
void CGContextStrokeEllipseInRect(CGContextRef context, CGRect rect) {
    NOISY_RETURN_IF_NULL(context);
    auto factory = context->Factory();

    ComPtr<ID2D1Geometry> geometry;
    ComPtr<ID2D1EllipseGeometry> ellipseGeometry;
    FAIL_FAST_IF_FAILED(
        factory->CreateEllipseGeometry({ { CGRectGetMidX(rect), CGRectGetMidY(rect) }, rect.size.width / 2.f, rect.size.height / 2.f },
                                       &ellipseGeometry));
    FAIL_FAST_IF_FAILED(ellipseGeometry.As(&geometry));

    __CGContextDrawGeometry(context, geometry.Get(), kCGPathStroke);

    context->ClearPath();
}

/**
 @Status Interoperable
 @Notes The current path is cleared as a side effect of this function.
*/
void CGContextFillEllipseInRect(CGContextRef context, CGRect rect) {
    NOISY_RETURN_IF_NULL(context);
    auto factory = context->Factory();

    ComPtr<ID2D1Geometry> geometry;
    ComPtr<ID2D1EllipseGeometry> ellipseGeometry;
    FAIL_FAST_IF_FAILED(
        factory->CreateEllipseGeometry({ { CGRectGetMidX(rect), CGRectGetMidY(rect) }, rect.size.width / 2.f, rect.size.height / 2.f },
                                       &ellipseGeometry));
    FAIL_FAST_IF_FAILED(ellipseGeometry.As(&geometry));

    __CGContextDrawGeometry(context, geometry.Get(), kCGPathFill);

    context->ClearPath();
}

/**
 @Status Interoperable
 @Notes The current path is cleared as a side effect of this function.
*/
void CGContextStrokeLineSegments(CGContextRef context, const CGPoint* points, unsigned count) {
    NOISY_RETURN_IF_NULL(context);

    if (!points || count == 0 || count % 2 != 0) {
        // On the reference platform, an uneven number of points results in a sizeof(CGPoint) read
        // beyond the end of the point buffer. Here we see fit to make that illegal.
        return;
    }

    CGContextBeginPath(context);
    for (unsigned k = 0; k < count; k += 2) {
        CGContextMoveToPoint(context, points[k].x, points[k].y);
        CGContextAddLineToPoint(context, points[k + 1].x, points[k + 1].y);
    }
    CGContextStrokePath(context);
}

/**
 @Status Interoperable
 @Notes The current path is cleared as a side effect of this function.
*/
void CGContextFillRects(CGContextRef context, const CGRect* rects, size_t count) {
    NOISY_RETURN_IF_NULL(context);
    if (!rects || count == 0) {
        return;
    }

    for (size_t i = 0; i < count; ++i) {
        CGContextFillRect(context, rects[i]);
    }
}
#pragma endregion

#pragma region Drawing Operations - Paths
/**
 @Status Interoperable
 @Notes The current path is cleared as a side effect of this function.
*/
void CGContextDrawPath(CGContextRef context, CGPathDrawingMode mode) {
    NOISY_RETURN_IF_NULL(context);
    UNIMPLEMENTED();
    context->ClearPath();
}

/**
 @Status Interoperable
 @Notes The current path is cleared as a side effect of this function.
*/
void CGContextStrokePath(CGContextRef context) {
    NOISY_RETURN_IF_NULL(context);
    CGContextDrawPath(context, kCGPathStroke); // Clears path.
}

/**
 @Status Interoperable
 @Notes The current path is cleared as a side effect of this function.
*/
void CGContextFillPath(CGContextRef context) {
    NOISY_RETURN_IF_NULL(context);
    CGContextDrawPath(context, kCGPathFill); // Clears path.
}

/**
 @Status Interoperable
 @Notes The current path is cleared as a side effect of this function.
*/
void CGContextEOFillPath(CGContextRef context) {
    NOISY_RETURN_IF_NULL(context);
    CGContextDrawPath(context, kCGPathEOFill); // Clears path.
}
#pragma endregion

#pragma region Drawing Operations - Gradient + Shading
/**
 @Status Interoperable
*/
void CGContextDrawLinearGradient(
    CGContextRef context, CGGradientRef gradient, CGPoint startPoint, CGPoint endPoint, CGGradientDrawingOptions options) {
    NOISY_RETURN_IF_NULL(context);
    UNIMPLEMENTED();
}

/**
 @Status Interoperable
*/
void CGContextDrawRadialGradient(CGContextRef context,
                                 CGGradientRef gradient,
                                 CGPoint startCenter,
                                 CGFloat startRadius,
                                 CGPoint endCenter,
                                 CGFloat endRadius,
                                 CGGradientDrawingOptions options) {
    NOISY_RETURN_IF_NULL(context);
    UNIMPLEMENTED();
}

/**
 @Status Stub
*/
void CGContextDrawShading(CGContextRef context, CGShadingRef shading) {
    NOISY_RETURN_IF_NULL(context);
    UNIMPLEMENTED();
}
#pragma endregion

#pragma region Drawing Operations - CGLayer
/**
 @Status Stub
*/
void CGContextDrawLayerInRect(CGContextRef context, CGRect destRect, CGLayerRef layer) {
    NOISY_RETURN_IF_NULL(context);
    UNIMPLEMENTED();
}

/**
 @Status Stub
*/
void CGContextDrawLayerAtPoint(CGContextRef context, CGPoint destPoint, CGLayerRef layer) {
    NOISY_RETURN_IF_NULL(context);
    UNIMPLEMENTED();
}
#pragma endregion

#pragma region Drawing Operations - PDF
/**
 @Status Stub
 @Notes
*/
void CGContextDrawPDFPage(CGContextRef context, CGPDFPageRef page) {
    NOISY_RETURN_IF_NULL(context);
    UNIMPLEMENTED();
}
#pragma endregion

#pragma region Internal Functions - To Be Removed
// TODO(DH) GH#1077 remove all of these internal functions.
// TODO: functions below are not part of offical exports, but they are also exported
// to be used by other framework components, we should consider moving them to a shared library
void CGContextClearToColor(CGContextRef context, CGFloat r, CGFloat g, CGFloat b, CGFloat a) {
    NOISY_RETURN_IF_NULL(context);
    UNIMPLEMENTED();
}

bool CGContextIsDirty(CGContextRef context) {
    NOISY_RETURN_IF_NULL(context, StubReturn());
    return true;
}

void CGContextSetDirty(CGContextRef context, bool dirty) {
    NOISY_RETURN_IF_NULL(context);
    UNIMPLEMENTED();
}

void CGContextReleaseLock(CGContextRef context) {
    NOISY_RETURN_IF_NULL(context);
    UNIMPLEMENTED();
}

CGContextImpl* CGContextGetBacking(CGContextRef context) {
    NOISY_RETURN_IF_NULL(context, StubReturn());
    UNIMPLEMENTED();
    return nullptr;
}

bool CGContextIsPointInPath(CGContextRef context, bool eoFill, CGFloat x, CGFloat y) {
    NOISY_RETURN_IF_NULL(context, StubReturn());
    UNIMPLEMENTED();
    return StubReturn();
}

void CGContextDrawGlyphRun(CGContextRef context, const DWRITE_GLYPH_RUN* glyphRun) {
    NOISY_RETURN_IF_NULL(context);
    // TODO(DH) GH#1070 Merge in CGContextCairo.mm's Glyph Run code.
}
#pragma endregion

CGImageRef CGPNGImageCreateFromFile(NSString* path) {
    return new CGPNGDecoderImage([path UTF8String]);
}

CGImageRef CGPNGImageCreateFromData(NSData* data) {
    return new CGPNGDecoderImage(data);
}

CGImageRef CGJPEGImageCreateFromFile(NSString* path) {
    return new CGJPEGDecoderImage([path UTF8String]);
}

CGImageRef CGJPEGImageCreateFromData(NSData* data) {
    return new CGJPEGDecoderImage(data);
}

#pragma region CGBitmapContext
struct __CGBitmapContextImpl {
    woc::unique_cf<CGImageRef> image;
};

struct __CGBitmapContext : CoreFoundation::CppBase<__CGBitmapContext, __CGBitmapContextImpl, __CGContext> {};

/**
 @Status Caveat
 @Notes Limited bitmap formats available. Decode, shouldInterpolate, intent parameters
 and some byte orders ignored.
 */
CGContextRef CGBitmapContextCreate(void* data,
                                   size_t width,
                                   size_t height,
                                   size_t bitsPerComponent,
                                   size_t bytesPerRow,
                                   CGColorSpaceRef colorSpace,
                                   CGBitmapInfo bitmapInfo) {
    UNIMPLEMENTED();
    return nullptr;
}

/**
 @Status Interoperable
*/
CGColorSpaceRef CGBitmapContextGetColorSpace(CGContextRef context) {
    NOISY_RETURN_IF_NULL(context, StubReturn());
    UNIMPLEMENTED();
    return nullptr;
}

/**
 @Status Interoperable
*/
size_t CGBitmapContextGetWidth(CGContextRef context) {
    NOISY_RETURN_IF_NULL(context, StubReturn());
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Interoperable
*/
size_t CGBitmapContextGetHeight(CGContextRef context) {
    NOISY_RETURN_IF_NULL(context, StubReturn());
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Interoperable
*/
size_t CGBitmapContextGetBytesPerRow(CGContextRef context) {
    NOISY_RETURN_IF_NULL(context, StubReturn());
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Interoperable
*/
void* CGBitmapContextGetData(CGContextRef context) {
    NOISY_RETURN_IF_NULL(context, StubReturn());
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Caveat
 @Notes Has no copy-on-write semantics; bitmap returned is the source bitmap representing
        the CGContext
*/
CGImageRef CGBitmapContextCreateImage(CGContextRef context) {
    NOISY_RETURN_IF_NULL(context, StubReturn());
    UNIMPLEMENTED();
    return StubReturn();
}

CGImageRef CGBitmapContextGetImage(CGContextRef context) {
    NOISY_RETURN_IF_NULL(context, StubReturn());
    if (CFGetTypeID(context) != __CGBitmapContext::GetTypeID()) {
        TraceError(TAG, L"Image requested from non-bitmap CGContext.");
        return nullptr;
    }
    return ((__CGBitmapContext*)context)->Impl().image.get();
}

CGContextRef _CGBitmapContextCreateWithTexture(
    int width, int height, float scale, DisplayTexture* texture, DisplayTextureLocking* locking) {
    CGImageRef newImage = nullptr;
    __CGSurfaceInfo surfaceInfo = _CGSurfaceInfoInit(width, height, _ColorARGB);
    newImage = new CGGraphicBufferImage(surfaceInfo, texture, locking);

    ComPtr<ID2D1RenderTarget> renderTarget = newImage->Backing()->GetRenderTarget();
    renderTarget->SetDpi(96 * scale, 96 * scale);

    __CGBitmapContext* context = __CGBitmapContext::CreateInstance(kCFAllocatorDefault);
    __CGContextInitWithRenderTarget(context, renderTarget.Get());

    context->Impl().image.reset(newImage); // Consumes +1 reference.
    return context;
}

CGContextRef _CGBitmapContextCreateWithFormat(int width, int height, __CGSurfaceFormat fmt) {
    UNIMPLEMENTED();
    return StubReturn();
}
#pragma endregion
