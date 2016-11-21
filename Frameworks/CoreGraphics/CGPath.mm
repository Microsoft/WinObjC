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

#import <CoreGraphics/CGBitmapContext.h>
#import <CoreGraphics/CoreGraphics.h>
#import <Starboard.h>
#import <StubReturn.h>
#import <algorithm>
#import <vector>

#import <CoreFoundation/CoreFoundation.h>
#import <CFRuntime.h>
#import <CoreGraphics/D2DWrapper.h>
#import "CGPathInternal.h"

#include <COMIncludes.h>
#import <wrl/client.h>
#include <COMIncludes_End.h>

#import <CFCPPBase.h>

static const wchar_t* TAG = L"CGPath";

static inline CGPoint __CreateCGPointWithTransform(CGFloat x, CGFloat y, const CGAffineTransform* transform) {
    CGPoint pt{ x, y };
    if (transform) {
        pt = CGPointApplyAffineTransform(pt, *transform);
    }

    return pt;
}

using namespace std;
using namespace Microsoft::WRL;

struct __CGPath : CoreFoundation::CppBase<__CGPath> {
    ComPtr<ID2D1PathGeometry> pathGeometry;
    ComPtr<ID2D1GeometrySink> geometrySink;

    bool figureClosed;
    CGPoint currentPoint{ 0, 0 };
    CGPoint startingPoint{ 0, 0 };
    CGAffineTransform lastTransform;

    __CGPath() : figureClosed(true), lastTransform(CGAffineTransformIdentity) {
    }

    ComPtr<ID2D1PathGeometry> GetPathGeometry() {
        return pathGeometry;
    }

    ComPtr<ID2D1GeometrySink> GetGeometrySink() {
        return geometrySink;
    }

    CGPoint GetCurrentPoint() {
        return currentPoint;
    }

    CGPoint GetStartingPoint() {
        return startingPoint;
    }

    void SetCurrentPoint(CGPoint newPoint) {
        currentPoint = newPoint;
    }

    void SetStartingPoint(CGPoint newPoint) {
        startingPoint = newPoint;
    }

    void SetLastTransform(const CGAffineTransform* transform) {
        if (transform) {
            lastTransform = *transform;
        } else {
            lastTransform = CGAffineTransformIdentity;
        }
    }

    const CGAffineTransform* GetLastTransform() {
        return &lastTransform;
    }

    // A private helper function for re-opening a path geometry. CGPath does not
    // have a concept of an open and a closed path but D2D relies on it. A
    // path/sink cannot be read from while the path is open thus it must be
    // closed. However, a CGPath can be edited again after being read from so
    // we must open the path again. This cannot be done normally, so we must
    // create a new path with the old path information to edit.
    HRESULT PreparePathForEditing() {
        if (!geometrySink) {
            // Re-open this geometry.
            ComPtr<ID2D1Factory> factory;
            RETURN_IF_FAILED(_CGGetD2DFactory(&factory));

            // Create temp vars for new path/sink
            ComPtr<ID2D1PathGeometry> newPath;
            ComPtr<ID2D1GeometrySink> newSink;

            // Open a new path that the contents of the old path will be streamed into. We cannot re-use the same path as it is now closed
            // and cannot be opened again. We use the newPath variable because the factory was returning the same pointer for some strange
            // reason so this will force it to do otherwise.
            RETURN_IF_FAILED(factory->CreatePathGeometry(&newPath));
            RETURN_IF_FAILED(newPath->Open(&newSink));
            RETURN_IF_FAILED(pathGeometry->Stream(newSink.Get()));

            pathGeometry = newPath;
            geometrySink = newSink;

            // Without a new figure being created, it's by default closed
            figureClosed = true;
        }
        return S_OK;
    }

    HRESULT ClosePath() {
        if (geometrySink) {
            EndFigure(D2D1_FIGURE_END_OPEN);
            RETURN_IF_FAILED(geometrySink->Close());
            geometrySink = nullptr;
        }
        return S_OK;
    }

    void BeginFigure() {
        if (figureClosed) {
            geometrySink->BeginFigure(_CGPointToD2D_F(currentPoint), D2D1_FIGURE_BEGIN_FILLED);
            figureClosed = false;
        }
    }

    void EndFigure(D2D1_FIGURE_END figureStatus) {
        if (!figureClosed) {
            geometrySink->EndFigure(figureStatus);
            figureClosed = true;
        }
    }

    HRESULT InitializeGeometries() {
        ComPtr<ID2D1Factory> factory;
        RETURN_IF_FAILED(_CGGetD2DFactory(&factory));

        RETURN_IF_FAILED(factory->CreatePathGeometry(&pathGeometry));
        RETURN_IF_FAILED(pathGeometry->Open(&geometrySink));

        return S_OK;
    }

    HRESULT SimplifyGeometryToPathWithTransformation(ComPtr<ID2D1Geometry> geometry, const CGAffineTransform* transform) {
        RETURN_IF_FAILED(ClosePath());
        RETURN_IF_FAILED(PreparePathForEditing());

        D2D1_MATRIX_3X2_F transformation = D2D1::IdentityMatrix();
        if (transform) {
            transformation = __CGAffineTransformToD2D_F(*transform);
        }
        RETURN_IF_FAILED(
            geometry->Simplify(D2D1_GEOMETRY_SIMPLIFICATION_OPTION_CUBICS_AND_LINES, &transformation, GetGeometrySink().Get()));
        return S_OK;
    }
};

HRESULT _CGPathGetGeometry(CGPathRef path, ID2D1Geometry** pGeometry) {
    RETURN_HR_IF_NULL(E_POINTER, pGeometry);
    RETURN_HR_IF_NULL(E_POINTER, path);
    RETURN_IF_FAILED(path->ClosePath());
    path->GetPathGeometry().CopyTo(pGeometry);
    return S_OK;
}

CFTypeID CGPathGetTypeID() {
    return __CGPath::GetTypeID();
}

static Boolean __CGPathEqual(CFTypeRef cf1, CFTypeRef cf2) {
    if (!cf1 && !cf2) {
        return true;
    }
    RETURN_FALSE_IF(!cf1);
    RETURN_FALSE_IF(!cf2);

    __CGPath* path1 = (__CGPath*)cf1;
    __CGPath* path2 = (__CGPath*)cf2;

    RETURN_FALSE_IF_FAILED(path1->ClosePath());
    RETURN_FALSE_IF_FAILED(path2->ClosePath());

    // ID2D1 Geometries have no isEquals method. However, for two geometries to be equal they are both reported to contain the other.
    // Thus we must do two comparisons.
    D2D1_GEOMETRY_RELATION relation = D2D1_GEOMETRY_RELATION_UNKNOWN;
    RETURN_FALSE_IF_FAILED(
        path1->GetPathGeometry()->CompareWithGeometry(path2->GetPathGeometry().Get(), D2D1::IdentityMatrix(), &relation));

    // Does path 1 contain path 2?
    if (relation == D2D1_GEOMETRY_RELATION_IS_CONTAINED) {
        RETURN_FALSE_IF_FAILED(
            path2->GetPathGeometry()->CompareWithGeometry(path1->GetPathGeometry().Get(), D2D1::IdentityMatrix(), &relation));

        // Return true if path 2 also contains path 1
        return (relation == D2D1_GEOMETRY_RELATION_IS_CONTAINED ? true : false);
    }

    return false;
}

/**
 @Status Interoperable
*/
CGMutablePathRef CGPathCreateMutable() {
    __CGPath* mutableRet = __CGPath::CreateInstance();

    FAIL_FAST_IF_FAILED(mutableRet->InitializeGeometries());

    return mutableRet;
}

/**
 @Status Caveat
 @Notes Creates a mutable copy
*/
CGPathRef CGPathCreateCopy(CGPathRef path) {
    RETURN_NULL_IF(!path);

    return CGPathCreateMutableCopy(path);
}

/**
@Status Interoperable
*/
CGMutablePathRef CGPathCreateMutableCopy(CGPathRef path) {
    RETURN_NULL_IF(!path);

    CGMutablePathRef mutableRet = CGPathCreateMutable();

    // In order to call stream and copy the contents of the original path into the
    // new copy we must close this path.
    // Otherwise the D2D calls will return that a bad state has been entered.
    FAIL_FAST_IF_FAILED(path->ClosePath());

    FAIL_FAST_IF_FAILED(path->GetPathGeometry()->Stream(mutableRet->GetGeometrySink().Get()));

    mutableRet->SetCurrentPoint(path->GetCurrentPoint());
    mutableRet->SetStartingPoint(path->GetStartingPoint());
    mutableRet->SetLastTransform(path->GetLastTransform());

    return mutableRet;
}

/**
 @Status Interoperable
*/
void CGPathAddLineToPoint(CGMutablePathRef path, const CGAffineTransform* transform, CGFloat x, CGFloat y) {
    RETURN_IF(!path);

    FAIL_FAST_IF_FAILED(path->PreparePathForEditing());

    CGPoint pt = __CreateCGPointWithTransform(x, y, transform);

    path->BeginFigure();
    path->GetGeometrySink()->AddLine(_CGPointToD2D_F(pt));
    path->SetLastTransform(transform);

    path->SetCurrentPoint(pt);
}

static inline bool _affineTransformEquals(const CGAffineTransform original, const CGAffineTransform compare) {
    return (original.a != compare.a) && (original.b == compare.b) && (original.c == compare.c) && (original.d == compare.d) &&
           (original.tx == compare.tx) && (original.ty == compare.ty);
}

static inline CGPoint _getInvertedCurrentPointOfPath(CGPathRef path) {
    CGPoint point = path->GetCurrentPoint();
    if (!_affineTransformEquals(*path->GetLastTransform(), CGAffineTransformIdentity)) {
        point = CGPointApplyAffineTransform(point, CGAffineTransformInvert(*path->GetLastTransform()));
    }
    return point;
}

static HRESULT _createPathReadyForFigure(CGPathRef previousPath,
                                         ID2D1PathGeometry** pathGeometry,
                                         ID2D1GeometrySink** geometrySink,
                                         CGPoint startPoint) {
    ComPtr<ID2D1Factory> factory;
    RETURN_IF_FAILED(_CGGetD2DFactory(&factory));
    RETURN_IF_FAILED(factory->CreatePathGeometry(pathGeometry));
    RETURN_IF_FAILED((*pathGeometry)->Open(geometrySink));

    CGPoint invertedPoint = _getInvertedCurrentPointOfPath(previousPath);
    if (!CGPointEqualToPoint(invertedPoint, startPoint)) {
        (*geometrySink)->BeginFigure(_CGPointToD2D_F(invertedPoint), D2D1_FIGURE_BEGIN_FILLED);
        (*geometrySink)->AddLine(_CGPointToD2D_F(startPoint));
    } else {
        (*geometrySink)->BeginFigure(_CGPointToD2D_F(startPoint), D2D1_FIGURE_BEGIN_FILLED);
    }
    return S_OK;
}

/**
 @Status Interoperable
*/
void CGPathAddArcToPoint(
    CGMutablePathRef path, const CGAffineTransform* transform, CGFloat x1, CGFloat y1, CGFloat x2, CGFloat y2, CGFloat radius) {
    RETURN_IF(!path);

    CGPoint invertedPoint = _getInvertedCurrentPointOfPath(path);

    CGFloat dx1 = x1 - invertedPoint.x;
    CGFloat dy1 = y1 - invertedPoint.y;

    CGFloat dx2 = x1 - x2;
    CGFloat dy2 = y1 - y2;

    // Normalize the angles we're working with.
    CGFloat startAngle = fmod(atan2(dy1, dx1), 2 * M_PI);
    CGFloat endAngle = fmod(atan2(dy2, dx2), 2 * M_PI);
    if (startAngle < 0) {
        startAngle += M_PI * 2;
    }
    if (endAngle < 0) {
        endAngle += M_PI * 2;
    }

    CGFloat bisector = (endAngle - startAngle) / 2;

    // tanLength is the distance to the point on the circle from the tangent line.
    CGFloat tanLength = abs(radius / tan(bisector));

    CGFloat tanPointAx = x1 - (tanLength * cos(startAngle));
    CGFloat tanPointAy = y1 - (tanLength * sin(startAngle));
    CGFloat tanPointBx = x1 - (tanLength * cos(endAngle));
    CGFloat tanPointBy = y1 - (tanLength * sin(endAngle));

    CGPoint endPoint = CGPointMake(tanPointBx, tanPointBy);
    const D2D1_POINT_2F endPointD2D = _CGPointToD2D_F(endPoint);

    int sweepSign = 1;
    if (startAngle > endAngle) {
        sweepSign = -1;
    }
    D2D1_SWEEP_DIRECTION sweepDirection = { startAngle + (M_PI * sweepSign) < endAngle ? D2D1_SWEEP_DIRECTION_CLOCKWISE :
                                                                                         D2D1_SWEEP_DIRECTION_COUNTER_CLOCKWISE };

    const D2D1_SIZE_F radiusD2D = { radius, radius };
    FLOAT rotationAngle = bisector * 2;
    D2D1_ARC_SIZE arcSize = D2D1_ARC_SIZE_SMALL;
    D2D1_ARC_SEGMENT arcSegment = D2D1::ArcSegment(endPointD2D, radiusD2D, rotationAngle, sweepDirection, arcSize);

    ComPtr<ID2D1PathGeometry> newPath;
    ComPtr<ID2D1GeometrySink> newSink;
    FAIL_FAST_IF_FAILED(_createPathReadyForFigure(path, &newPath, &newSink, CGPointMake(tanPointAx, tanPointAy)));
    newSink->AddArc(arcSegment);
    newSink->EndFigure(D2D1_FIGURE_END_OPEN);
    FAIL_FAST_IF_FAILED(newSink->Close());

    FAIL_FAST_IF_FAILED(path->SimplifyGeometryToPathWithTransformation(newPath, transform));

    if (transform) {
        endPoint = CGPointApplyAffineTransform(endPoint, *transform);
    }
    path->SetLastTransform(transform);
    path->SetCurrentPoint(endPoint);
}

/**
 @Status Interoperable
*/
void CGPathAddArc(CGMutablePathRef path,
                  const CGAffineTransform* transform,
                  CGFloat x,
                  CGFloat y,
                  CGFloat radius,
                  CGFloat startAngle,
                  CGFloat endAngle,
                  bool clockwise) {
    RETURN_IF(!path);

    CGPoint startPoint = CGPointMake(x + radius * cos(startAngle), y + radius * sin(startAngle));
    CGPoint endPoint = CGPointMake(x + radius * cos(endAngle), y + radius * sin(endAngle));

    // Create the parameters for the AddArc method.
    const D2D1_POINT_2F endPointD2D = _CGPointToD2D_F(endPoint);
    const D2D1_SIZE_F radiusD2D = { radius, radius };
    CGFloat rotationAngle = abs(startAngle - endAngle);
    D2D1_ARC_SIZE arcSize = D2D1_ARC_SIZE_SMALL;
    CGFloat expectedAngle = (clockwise ? startAngle + rotationAngle : startAngle - rotationAngle);

    // D2D does not understand that the ending angle must be pointing in the proper direction, thus we must translate
    // what it means to have an ending angle to the proper small arc or large arc that D2D will use since a circle will
    // intersect that point regardless of which direction it is drawn in.
    if (expectedAngle == endAngle) {
        arcSize = D2D1_ARC_SIZE_LARGE;
    } else {
        rotationAngle = (2 * M_PI) - rotationAngle;
    }
    D2D1_SWEEP_DIRECTION sweepDirection = { clockwise ? D2D1_SWEEP_DIRECTION_COUNTER_CLOCKWISE : D2D1_SWEEP_DIRECTION_CLOCKWISE };
    D2D1_ARC_SEGMENT arcSegment = D2D1::ArcSegment(endPointD2D, radiusD2D, rotationAngle, sweepDirection, arcSize);

    ComPtr<ID2D1PathGeometry> newPath;
    ComPtr<ID2D1GeometrySink> newSink;
    FAIL_FAST_IF_FAILED(_createPathReadyForFigure(path, &newPath, &newSink, startPoint));

    newSink->AddArc(arcSegment);
    newSink->EndFigure(D2D1_FIGURE_END_OPEN);
    FAIL_FAST_IF_FAILED(newSink->Close());

    FAIL_FAST_IF_FAILED(path->SimplifyGeometryToPathWithTransformation(newPath, transform));

    if (transform) {
        endPoint = CGPointApplyAffineTransform(endPoint, *transform);
    }
    path->SetLastTransform(transform);
    path->SetCurrentPoint(endPoint);
}

/**
 @Status Interoperable
*/
void CGPathMoveToPoint(CGMutablePathRef path, const CGAffineTransform* transform, CGFloat x, CGFloat y) {
    RETURN_IF(!path);

    // CGPaths do not consider these actions to be segments of the path and are not considered on CGPathApply, thus we should simply end the
    // current figure and move the location of this path to the new point.
    path->EndFigure(D2D1_FIGURE_END_OPEN);

    CGPoint pt = __CreateCGPointWithTransform(x, y, transform);
    path->SetStartingPoint(pt);
    path->SetCurrentPoint(pt);
    path->SetLastTransform(transform);
}

/**
 @Status Interoperable
*/
void CGPathAddLines(CGMutablePathRef path, const CGAffineTransform* transform, const CGPoint* points, size_t count) {
    RETURN_IF(count == 0 || !points || !path);

    for (int i = 0; i < count; i++) {
        CGPathAddLineToPoint(path, transform, points[i].x, points[i].y);
    }
}

/**
 @Status Interoperable
*/
void CGPathAddRect(CGMutablePathRef path, const CGAffineTransform* transform, CGRect rect) {
    RETURN_IF(!path);

    CGPathMoveToPoint(path, transform, CGRectGetMinX(rect), CGRectGetMinY(rect));

    CGPathAddLineToPoint(path, transform, CGRectGetMaxX(rect), CGRectGetMinY(rect));
    CGPathAddLineToPoint(path, transform, CGRectGetMaxX(rect), CGRectGetMaxY(rect));
    CGPathAddLineToPoint(path, transform, CGRectGetMinX(rect), CGRectGetMaxY(rect));
    CGPathCloseSubpath(path);
    path->SetLastTransform(transform);
}

/**
 @Status Interoperable
*/
void CGPathAddPath(CGMutablePathRef path, const CGAffineTransform* transform, CGPathRef toAdd) {
    RETURN_IF(!path || !toAdd);

    // Close the path being added.
    FAIL_FAST_IF_FAILED(toAdd->ClosePath());
    FAIL_FAST_IF_FAILED(path->SimplifyGeometryToPathWithTransformation(toAdd->GetPathGeometry(), transform));

    CGPoint currentPoint = toAdd->GetCurrentPoint();
    CGPoint startingPoint = toAdd->GetStartingPoint();
    if (transform) {
        currentPoint = CGPointApplyAffineTransform(currentPoint, *transform);
        startingPoint = CGPointApplyAffineTransform(startingPoint, *transform);
    }
    path->SetStartingPoint(startingPoint);
    path->SetCurrentPoint(currentPoint);
    path->SetLastTransform(transform);
}

/**
 @Status Interoperable
*/
void CGPathAddEllipseInRect(CGMutablePathRef path, const CGAffineTransform* transform, CGRect rect) {
    RETURN_IF(!path);

    CGFloat radiusX = rect.size.width / 2.0;
    CGFloat radiusY = rect.size.height / 2.0;
    CGPoint center = CGPointMake(rect.origin.x + radiusX, rect.origin.y + radiusY);

    D2D1_ELLIPSE ellipse = D2D1::Ellipse(_CGPointToD2D_F(center), radiusX, radiusY);
    ComPtr<ID2D1Factory> factory;
    FAIL_FAST_IF_FAILED(_CGGetD2DFactory(&factory));
    ComPtr<ID2D1EllipseGeometry> ellipseGeometry;

    FAIL_FAST_IF_FAILED(factory->CreateEllipseGeometry(&ellipse, &ellipseGeometry));

    FAIL_FAST_IF_FAILED(path->SimplifyGeometryToPathWithTransformation(ellipseGeometry, transform));
    path->SetLastTransform(transform);
}

/**
 @Status Interoperable
*/
void CGPathCloseSubpath(CGMutablePathRef path) {
    RETURN_IF(!path);

    // Move the current point to the starting point since the line is closed.
    if (!CGPointEqualToPoint(path->GetStartingPoint(), path->GetCurrentPoint())) {
        CGPathAddLineToPoint(path, nullptr, path->GetStartingPoint().x, path->GetStartingPoint().y);
    }

    // Due to issues with streaming one geometry into another, the starting point of the D2D figure gets lost.
    // Thus we draw our own closing line and declare the figure has ended.
    path->EndFigure(D2D1_FIGURE_END_OPEN);
}

/**
@Status Interoperable
*/
CGRect CGPathGetBoundingBox(CGPathRef path) {
    if (path == NULL) {
        return CGRectNull;
    }

    D2D1_RECT_F bounds;

    if (FAILED(path->ClosePath())) {
        return CGRectNull;
    }

    if (FAILED(path->GetPathGeometry()->GetBounds(D2D1::IdentityMatrix(), &bounds))) {
        return CGRectNull;
    }

    return _D2DRectToCGRect(bounds);
}

/**
@Status Interoperable

*/
bool CGPathIsEmpty(CGPathRef path) {
    if (path == NULL) {
        return true;
    }

    UINT32 count;

    RETURN_FALSE_IF_FAILED(path->ClosePath());

    RETURN_FALSE_IF_FAILED(path->GetPathGeometry()->GetFigureCount(&count));
    return count == 0;
}

/**
 @Status Interoperable
*/
void CGPathRelease(CGPathRef path) {
    RETURN_IF(!path);
    CFRelease(path);
}

/**
 @Status Interoperable
*/
CGPathRef CGPathRetain(CGPathRef path) {
    RETURN_NULL_IF(!path);

    CFRetain(path);

    return path;
}

/**
@Status Interoperable
*/
void CGPathAddQuadCurveToPoint(CGMutablePathRef path, const CGAffineTransform* transform, CGFloat cpx, CGFloat cpy, CGFloat x, CGFloat y) {
    RETURN_IF(!path);

    CGPoint endPoint = CGPointMake(x, y);
    CGPoint controlPoint = CGPointMake(cpx, cpy);

    ComPtr<ID2D1PathGeometry> newPath;
    ComPtr<ID2D1GeometrySink> newSink;

    FAIL_FAST_IF_FAILED(_createPathReadyForFigure(path, &newPath, &newSink, _getInvertedCurrentPointOfPath(path)));
    newSink->AddQuadraticBezier(D2D1::QuadraticBezierSegment(_CGPointToD2D_F(controlPoint), _CGPointToD2D_F(endPoint)));
    newSink->EndFigure(D2D1_FIGURE_END_OPEN);
    FAIL_FAST_IF_FAILED(newSink->Close());

    FAIL_FAST_IF_FAILED(path->SimplifyGeometryToPathWithTransformation(newPath, transform));

    if (transform) {
        endPoint = CGPointApplyAffineTransform(endPoint, *transform);
    }
    path->SetCurrentPoint(endPoint);
    path->SetLastTransform(transform);
}

/**
@Status Interoperable
*/
void CGPathAddCurveToPoint(CGMutablePathRef path,
                           const CGAffineTransform* transform,
                           CGFloat cp1x,
                           CGFloat cp1y,
                           CGFloat cp2x,
                           CGFloat cp2y,
                           CGFloat x,
                           CGFloat y) {
    RETURN_IF(!path);

    CGPoint endPoint = CGPointMake(x, y);
    CGPoint controlPoint1 = CGPointMake(cp1x, cp1y);
    CGPoint controlPoint2 = CGPointMake(cp2x, cp2y);

    ComPtr<ID2D1PathGeometry> newPath;
    ComPtr<ID2D1GeometrySink> newSink;

    FAIL_FAST_IF_FAILED(_createPathReadyForFigure(path, &newPath, &newSink, _getInvertedCurrentPointOfPath(path)));
    newSink->AddBezier(D2D1::BezierSegment(_CGPointToD2D_F(controlPoint1), _CGPointToD2D_F(controlPoint2), _CGPointToD2D_F(endPoint)));
    newSink->EndFigure(D2D1_FIGURE_END_OPEN);
    FAIL_FAST_IF_FAILED(newSink->Close());

    FAIL_FAST_IF_FAILED(path->SimplifyGeometryToPathWithTransformation(newPath, transform));

    if (transform) {
        endPoint = CGPointApplyAffineTransform(endPoint, *transform);
    }
    path->SetCurrentPoint(endPoint);
    path->SetLastTransform(transform);
}

/**
 @Status Interoperable
*/
CGPathRef CGPathCreateWithRect(CGRect rect, const CGAffineTransform* transform) {
    CGMutablePathRef ret = CGPathCreateMutable();
    CGPathAddRect(ret, transform, rect);

    return (CGPathRef)ret;
}

/**
 @Status Interoperable
*/
CGPathRef CGPathCreateWithEllipseInRect(CGRect rect, const CGAffineTransform* transform) {
    CGMutablePathRef ret = CGPathCreateMutable();
    CGPathAddEllipseInRect(ret, transform, rect);

    return (CGPathRef)ret;
}

/**
 @Status Stub
*/
CGRect CGPathGetPathBoundingBox(CGPathRef self) {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
void CGPathAddRects(CGMutablePathRef path, const CGAffineTransform* transform, const CGRect* rects, size_t count) {
    UNIMPLEMENTED();
}

/**
 @Status Stub
 @Notes
*/
void CGPathAddRelativeArc(
    CGMutablePathRef path, const CGAffineTransform* transform, CGFloat x, CGFloat y, CGFloat radius, CGFloat startAngle, CGFloat delta) {
    UNIMPLEMENTED();
}

/**
 @Status Interoperable
 @Notes
*/
void CGPathAddRoundedRect(
    CGMutablePathRef path, const CGAffineTransform* transform, CGRect rect, CGFloat cornerWidth, CGFloat cornerHeight) {
    RETURN_IF(!path);

    D2D1_RECT_F rectangle = __CGRectToD2D_F(rect);
    D2D1_ROUNDED_RECT roundedRectangle = { rectangle, cornerWidth, cornerHeight };

    ComPtr<ID2D1Factory> factory;
    FAIL_FAST_IF_FAILED(_CGGetD2DFactory(&factory));
    ComPtr<ID2D1RoundedRectangleGeometry> rectangleGeometry;

    FAIL_FAST_IF_FAILED(factory->CreateRoundedRectangleGeometry(&roundedRectangle, &rectangleGeometry));

    FAIL_FAST_IF_FAILED(path->SimplifyGeometryToPathWithTransformation(rectangleGeometry, transform));
    path->SetLastTransform(transform);
}

int _CGPathPointCountForElementType(CGPathElementType type) {
    int pointCount = 0;

    switch (type) {
        case kCGPathElementMoveToPoint:
        case kCGPathElementAddLineToPoint:
            pointCount = 1;
            break;
        case kCGPathElementAddQuadCurveToPoint:
            pointCount = 2;
            break;
        case kCGPathElementAddCurveToPoint:
            pointCount = 3;
            break;
        case kCGPathElementCloseSubpath:
            pointCount = 0;
            break;
    }
    return pointCount;
}

/**
 @Status Stub
*/
void CGPathApply(CGPathRef path, void* info, CGPathApplierFunction function) {
    UNIMPLEMENTED();
}

/**
 @Status Caveat
 @Notes eoFill ignored. Default fill pattern for ID2D1 Geometry is used.
*/
bool CGPathContainsPoint(CGPathRef path, const CGAffineTransform* transform, CGPoint point, bool eoFill) {
    RETURN_FALSE_IF(!path);

    if (transform) {
        point = CGPointApplyAffineTransform(point, *transform);
    }

    BOOL containsPoint = FALSE;

    RETURN_FALSE_IF_FAILED(path->ClosePath());
    RETURN_FALSE_IF_FAILED(path->GetPathGeometry()->FillContainsPoint(_CGPointToD2D_F(point), D2D1::IdentityMatrix(), &containsPoint));

    return (containsPoint ? true : false);
}

/**
 @Status Stub
 @Notes
*/
CGPathRef CGPathCreateCopyByDashingPath(
    CGPathRef path, const CGAffineTransform* transform, CGFloat phase, const CGFloat* lengths, size_t count) {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
CGPathRef CGPathCreateCopyByStrokingPath(
    CGPathRef path, const CGAffineTransform* transform, CGFloat lineWidth, CGLineCap lineCap, CGLineJoin lineJoin, CGFloat miterLimit) {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
CGPathRef CGPathCreateCopyByTransformingPath(CGPathRef path, const CGAffineTransform* transform) {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
CGMutablePathRef CGPathCreateMutableCopyByTransformingPath(CGPathRef path, const CGAffineTransform* transform) {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Interoperable
 @Notes
*/
CGPathRef CGPathCreateWithRoundedRect(CGRect rect, CGFloat cornerWidth, CGFloat cornerHeight, const CGAffineTransform* transform) {
    CGMutablePathRef ret = CGPathCreateMutable();
    CGPathAddRoundedRect(ret, transform, rect, cornerWidth, cornerHeight);
    return (CGPathRef)ret;
}

/**
 @Status Stub
*/
bool CGPathEqualToPath(CGPathRef path1, CGPathRef path2) {
    return __CGPathEqual(path1, path2);
}

/**
 @Status Interoperable
*/
CGPoint CGPathGetCurrentPoint(CGPathRef path) {
    if (!path) {
        return CGPointZero;
    }
    return path->GetCurrentPoint();
}

/**
 @Status Stub
 @Notes
*/
bool CGPathIsRect(CGPathRef path, CGRect* rect) {
    UNIMPLEMENTED();
    return StubReturn();
}
