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
#import "D2DWrapper.h"

#include <COMIncludes.h>
#import <wrl/client.h>
#import <D2d1.h>
#include <COMIncludes_End.h>
#import <CFCPPBase.h>

static const wchar_t* TAG = L"CGPath";

inline CGPoint __CreateCGPointWithTransform(CGFloat x, CGFloat y, const CGAffineTransform* transform) {
    CGPoint pt{ x, y };
    if (transform) {
        pt = CGPointApplyAffineTransform(pt, *transform);
    }

    return pt;
}

using namespace std;
using namespace Microsoft::WRL;

struct __CGPathImpl {
    ComPtr<ID2D1PathGeometry> pathGeometry;
    ComPtr<ID2D1GeometrySink> geometrySink;

    bool isFigureClosed;
    CGPoint currentPoint{ 0, 0 };
    CGPoint startingPoint{ 0, 0 };

    __CGPathImpl() : isFigureClosed(true) {
    }
};

struct __CGPath : CoreFoundation::CppBase<__CGPath, __CGPathImpl> {
    // A private helper function for re-opening a path geometry. CGPath does not
    // have a concept of an open and a closed path but D2D relies on it. A
    // path/sink cannot be read from while the path is open thus it must be
    // closed. However, a CGPath can be edited again after being read from so
    // we must open the path again. This cannot be done normally, so we must
    // create a new path with the old path information to edit.
    void preparePathForEditing() {
        if (!_impl.geometrySink) {
            // Re-open this geometry.
            ComPtr<ID2D1Factory> factory = _GetD2DFactoryInstance();

            // Create temp vars for new path/sink
            ComPtr<ID2D1PathGeometry> newPath;
            ComPtr<ID2D1GeometrySink> newSink;

            // Open a new path that the contents of the old path will be streamed into. We cannot re-use the same path as it is now closed
            // and cannot be opened again. We use the newPath variable because the factory was returning the same pointer for some strange
            // reason so this will force it to do otherwise.
            FAIL_FAST_IF_FAILED(factory->CreatePathGeometry(&newPath));
            FAIL_FAST_IF_FAILED(newPath->Open(&newSink));
            FAIL_FAST_IF_FAILED(_impl.pathGeometry->Stream(newSink.Get()));

            _impl.pathGeometry = newPath;
            _impl.geometrySink = newSink;

            // Without a new figure being created, it's by default closed
            _impl.isFigureClosed = true;
        }
    }

    void closePath() {
        if (_impl.geometrySink) {
            endFigure(D2D1_FIGURE_END_OPEN);
            _impl.geometrySink->Close();
            _impl.geometrySink = nullptr;
        }
    }

    void beginFigure() {
        if (_impl.isFigureClosed) {
            _impl.geometrySink->BeginFigure(_CGPointToD2D_F(_impl.currentPoint), D2D1_FIGURE_BEGIN_FILLED);
            _impl.isFigureClosed = false;
        }
    }

    void endFigure(D2D1_FIGURE_END figureStatus) {
        if (!_impl.isFigureClosed) {
            _impl.geometrySink->EndFigure(figureStatus);
            _impl.isFigureClosed = true;
        }
    }

    void initializeGeometries() {
        ComPtr<ID2D1Factory> factory = _GetD2DFactoryInstance();

        FAIL_FAST_IF_FAILED(factory->CreatePathGeometry(&_impl.pathGeometry));
        FAIL_FAST_IF_FAILED(_impl.pathGeometry->Open(&_impl.geometrySink));
    }
};

CFTypeID CGPathGetTypeID() {
    return __CGPath::GetTypeID();
}

static Boolean __CGPathEqual(CFTypeRef cf1, CFTypeRef cf2) {
    __CGPath* path1 = (__CGPath*)cf1;
    __CGPath* path2 = (__CGPath*)cf2;

    path1->closePath();
    path2->closePath();

    // ID2D1 Geometries have no isEquals method. However, for two geometries to be equal they are both reported to contain the other.
    // Thus we must do two comparisons.

    D2D1_GEOMETRY_RELATION relation = D2D1_GEOMETRY_RELATION_UNKNOWN;
    if (SUCCEEDED(path1->_impl.pathGeometry->CompareWithGeometry(path2->_impl.pathGeometry.Get(), D2D1::IdentityMatrix(), &relation))) {
        // Does path 1 contain path 2?
        if (relation == D2D1_GEOMETRY_RELATION_IS_CONTAINED) {
            if (SUCCEEDED(
                    path2->_impl.pathGeometry->CompareWithGeometry(path1->_impl.pathGeometry.Get(), D2D1::IdentityMatrix(), &relation))) {
                // Return true if path 2 also contains path 1
                return (relation == D2D1_GEOMETRY_RELATION_IS_CONTAINED ? true : false);
            }
        }
    }
    return false;
}

/**
 @Status Interoperable
*/
CGMutablePathRef CGPathCreateMutable() {
    __CGPath* mutableRet = __CGPath::CreateInstance();

    mutableRet->initializeGeometries();

    return mutableRet;
}

/**
 @Status Caveat
 @Notes Creates a mutable copy
*/
CGPathRef CGPathCreateCopy(CGPathRef path) {
    if (path == NULL) {
        return NULL;
    }

    return CGPathCreateMutableCopy(path);
}

/**
@Status Interoperable
*/
CGMutablePathRef CGPathCreateMutableCopy(CGPathRef path) {
    if (path == NULL) {
        return NULL;
    }

    CGMutablePathRef mutableRet = CGPathCreateMutable();

    // In order to call stream and copy the contents of the original path into the
    // new copy we must close this path.
    // Otherwise the D2D calls will return that a bad state has been entered.
    path->closePath();

    FAIL_FAST_IF_FAILED(path->_impl.pathGeometry->Stream(mutableRet->_impl.geometrySink.Get()));

    mutableRet->_impl.currentPoint = path->_impl.currentPoint;
    mutableRet->_impl.startingPoint = path->_impl.startingPoint;

    return mutableRet;
}

/**
 @Status Interoperable
*/
void CGPathAddLineToPoint(CGMutablePathRef path, const CGAffineTransform* transform, CGFloat x, CGFloat y) {
    if (path == NULL) {
        return;
    }

    path->preparePathForEditing();

    CGPoint pt = __CreateCGPointWithTransform(x, y, transform);

    path->beginFigure();
    path->_impl.geometrySink->AddLine(_CGPointToD2D_F(pt));

    path->_impl.currentPoint = pt;
}

CGFloat _CGPathControlPointOffsetMultiplier(CGFloat angle) {
    // Constant used to approximate circles with bezier curves.
    // An n-piece cubic Bezier curve can approximate a circle,
    // when each inner control point is the distance 4/3 * tan(t/4)
    // from an outer control point on a unit circle, where t is 360/n degrees, and
    // n > 2
    return (4.0f / 3.0f) * tan(angle / 4.0f);
}

/**
 @Status Caveat
 @Notes transform property not supported
*/
void CGPathAddArcToPoint(
    CGMutablePathRef path, const CGAffineTransform* transform, CGFloat x1, CGFloat y1, CGFloat x2, CGFloat y2, CGFloat radius) {
    bool isEmpty = CGPathIsEmpty(path);

    if (isEmpty) {
        return;
    }

    CGPoint curPathPosition = CGPathGetCurrentPoint(path);
    // TODO: Deduplicate this code from CGContextImpl::CGContextAddArcToPoint and
    // CGContextCairo::CGContextAddArcToPoint
    double x0, y0;
    double dx0, dy0, dx2, dy2, xl0, xl2;
    double san, n0x, n0y, n2x, n2y, t;

    x0 = curPathPosition.x;
    y0 = curPathPosition.y;

    dx0 = x0 - x1;
    dy0 = y0 - y1;
    xl0 = sqrt(dx0 * dx0 + dy0 * dy0);
    if (xl0 == 0)
        return;

    dx2 = x2 - x1;
    dy2 = y2 - y1;
    xl2 = sqrt(dx2 * dx2 + dy2 * dy2);

    san = dx2 * dy0 - dx0 * dy2;
    if (san == 0) {
        CGPathAddLineToPoint(path, transform, x1, y1);
        return;
    }

    if (san < 0) {
        n0x = -dy0 / xl0;
        n0y = dx0 / xl0;
        n2x = dy2 / xl2;
        n2y = -dx2 / xl2;
    } else {
        n0x = dy0 / xl0;
        n0y = -dx0 / xl0;
        n2x = -dy2 / xl2;
        n2y = dx2 / xl2;
    }
    t = (dx2 * n2y - dx2 * n0y - dy2 * n2x + dy2 * n0x) / san;
    CGPathAddArc(path,
                 transform,
                 (CGFloat)(x1 + radius * (t * dx0 + n0x)),
                 (CGFloat)(y1 + radius * (t * dy0 + n0y)),
                 radius,
                 (CGFloat)atan2(-n0y, -n0x),
                 (CGFloat)atan2(-n2y, -n2x),
                 (san < 0));
}

// Internal function to break down Arcs into pieces smaller than pi/2.
void _CGPathAddArc(CGMutablePathRef path,
                   const CGAffineTransform* transform,
                   CGFloat x,
                   CGFloat y,
                   CGFloat radius,
                   CGFloat startAngle,
                   CGFloat endAngle,
                   bool clockwise) {
    // Get the difference between the start and end angle for this arc
    CGFloat delta = endAngle - startAngle;

    // If the difference is larger than pi/2 then this arc needs to be
    // broken down into more pieces
    // .00001f is used instead of epsilon here to avoid infinite loops with
    // values close to pi/2
    if ((fabs(delta) > M_PI_2) && (fabs((M_PI_2 - fabs(delta))) > 0.00001f)) {
        // Calculate the angle in the middle of the start & end angle.
        CGFloat midAngle = startAngle + (M_PI_2 * (delta < 0 ? -1.0f : 1.0f));

        // Call this function again now with the smaller arcs
        _CGPathAddArc(path, transform, x, y, radius, startAngle, midAngle, clockwise);
        _CGPathAddArc(path, transform, x, y, radius, midAngle, endAngle, clockwise);
        return;
    }

    // The start and end points for the arc, not yet adjusted with the center of
    // the arc
    CGPoint arcStartRelative = CGPointMake((cos(startAngle) * radius), (sin(startAngle) * radius));
    CGPoint arcEndRelative = CGPointMake((cos(endAngle) * radius), (sin(endAngle) * radius));

    // The start and end points of the arc, adjuste for the center.
    CGPoint arcStart = CGPointMake(arcStartRelative.x + x, arcStartRelative.y + y);
    CGPoint arcEnd = CGPointMake(arcEndRelative.x + x, arcEndRelative.y + y);

    // Use the angle size to determine the offset for control points
    CGFloat offsetMultiplier = _CGPathControlPointOffsetMultiplier(delta);

    // Create the curve with the control points properly offset
    CGPathAddCurveToPoint(path,
                          transform,
                          arcStart.x - (offsetMultiplier * arcStartRelative.y),
                          arcStart.y + (offsetMultiplier * arcStartRelative.x),
                          arcEnd.x + (offsetMultiplier * arcEndRelative.y),
                          arcEnd.y - (offsetMultiplier * arcEndRelative.x),
                          arcEnd.x,
                          arcEnd.y);
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
    if (path == NULL) {
        return;
    }

    // Normalize the start angle so it's between 0 and 2*pi
    startAngle = fmod(startAngle, 2.0f * M_PI);
    if (startAngle < 0.0f) {
        startAngle += 2.0f * M_PI;
    }

    // Normalize the end angle so it's between 0 and 2*pi
    endAngle = fmod(endAngle, 2.0f * M_PI);
    if (endAngle < 0.0f) {
        endAngle += 2.0f * M_PI;
    }

    // Calculate the starting point of the arc
    CGPoint arcStart = CGPointMake((cos(startAngle) * radius) + x, (sin(startAngle) * radius) + y);

    // Either draw a line to or move to the start of the arc
    if (!CGPathIsEmpty(path)) {
        CGPathAddLineToPoint(path, transform, arcStart.x, arcStart.y);
    } else {
        CGPathMoveToPoint(path, transform, arcStart.x, arcStart.y);
    }

    // Adjust the start/endangles to force the arc
    // to be pieced together clockwise or counter-clockwise
    if (clockwise && endAngle > startAngle) {
        startAngle += 2.0f * M_PI;
    } else if (!clockwise && startAngle > endAngle) {
        endAngle += 2.0f * M_PI;
    }

    // Call the internal function for breaking the arcs down into smaller segments
    _CGPathAddArc(path, transform, x, y, radius, startAngle, endAngle, clockwise);
}

/**
 @Status Interoperable
*/
void CGPathMoveToPoint(CGMutablePathRef path, const CGAffineTransform* transform, CGFloat x, CGFloat y) {
    // CGPathMoveToPoint does not update the geometry in any way. CGPaths do not consider these actions to be
    // segments of the path and are not considered on CGPathApply. Because of this we do not want to call
    // BeginFigure or anything else on the D2DPath because that would modify it's state in an invalid way.
    CGPoint pt = __CreateCGPointWithTransform(x, y, transform);

    path->_impl.startingPoint = pt;
    path->_impl.currentPoint = pt;

    path->endFigure(D2D1_FIGURE_END_OPEN);
}

/**
 @Status Interoperable
*/
void CGPathAddLines(CGMutablePathRef path, const CGAffineTransform* transform, const CGPoint* points, size_t count) {
    if (count == 0 || points == NULL || path == NULL) {
        return;
    }

    for (int i = 0; i < count; i++) {
        CGPathAddLineToPoint(path, transform, points[i].x, points[i].y);
    }
}

/**
 @Status Interoperable
*/
void CGPathAddRect(CGMutablePathRef path, const CGAffineTransform* transform, CGRect rect) {
    if (path == NULL) {
        return;
    }

    CGPathMoveToPoint(path, transform, CGRectGetMinX(rect), CGRectGetMinY(rect));

    CGPathAddLineToPoint(path, transform, CGRectGetMaxX(rect), CGRectGetMinY(rect));
    CGPathAddLineToPoint(path, transform, CGRectGetMaxX(rect), CGRectGetMaxY(rect));
    CGPathAddLineToPoint(path, transform, CGRectGetMinX(rect), CGRectGetMaxY(rect));
    CGPathCloseSubpath(path);
}

/**
 @Status Caveat
 @Notes Ignores Affine Transform
*/
void CGPathAddPath(CGMutablePathRef path, const CGAffineTransform* transform, CGPathRef toAdd) {
    if (path == NULL || toAdd == NULL) {
        return;
    }

    // Close the path we're adding and open the path we need to add to.
    toAdd->closePath();
    path->preparePathForEditing();
    FAIL_FAST_IF_FAILED(toAdd->_impl.pathGeometry->Stream(path->_impl.geometrySink.Get()));
}

/**
 @Status Interoperable
*/
void CGPathAddEllipseInRect(CGMutablePathRef path, const CGAffineTransform* transform, CGRect rect) {
    if (path == NULL) {
        return;
    }

    // Determine the control point offset multiplier to create 4 arcs
    CGFloat offsetMultiplier = _CGPathControlPointOffsetMultiplier(M_PI_2);

    CGFloat xControlPointOffset = offsetMultiplier * CGRectGetWidth(rect) / 2.0;
    CGFloat yControlPointOffset = offsetMultiplier * CGRectGetHeight(rect) / 2.0;

    CGFloat minX = CGRectGetMinX(rect);
    CGFloat midX = CGRectGetMidX(rect);
    CGFloat maxX = CGRectGetMaxX(rect);

    CGFloat minY = CGRectGetMinY(rect);
    CGFloat midY = CGRectGetMidY(rect);
    CGFloat maxY = CGRectGetMaxY(rect);

    // Move to the center of the ellipse
    CGPathMoveToPoint(path, transform, maxX, midY);

    // Add the 4 curves for the ellipse
    CGPathAddCurveToPoint(path, transform, maxX, midY + yControlPointOffset, midX + xControlPointOffset, maxY, midX, maxY);
    CGPathAddCurveToPoint(path, transform, midX - xControlPointOffset, maxY, minX, midY + yControlPointOffset, minX, midY);
    CGPathAddCurveToPoint(path, transform, minX, midY - yControlPointOffset, midX - xControlPointOffset, minY, midX, minY);
    CGPathAddCurveToPoint(path, transform, midX + xControlPointOffset, minY, maxX, midY - yControlPointOffset, maxX, midY);

    CGPathCloseSubpath(path);
}

/**
 @Status Interoperable
*/
void CGPathCloseSubpath(CGMutablePathRef path) {
    // Move the current point to the starting point since the line is closed.
    path->_impl.currentPoint = path->_impl.startingPoint;
    path->endFigure(D2D1_FIGURE_END_CLOSED);
}

/**
@Status Stub
@Notes
*/
CGRect CGPathGetBoundingBox(CGPathRef path) {
    if (path == NULL) {
        return CGRectMake(INFINITY, INFINITY, 0, 0);
    }

    D2D1_RECT_F bounds;

    path->closePath();

    FAIL_FAST_IF_FAILED(path->_impl.pathGeometry->GetBounds(D2D1::IdentityMatrix(), &bounds));

    return _D2DRectToCGRect(bounds);
}

/**
@Status Interoperable

*/
bool CGPathIsEmpty(CGPathRef path) {
    if (path == NULL) {
        return kCFBooleanTrue;
    }

    UINT32 count;

    path->closePath();

    path->_impl.pathGeometry->GetFigureCount(&count);
    return count == 0;
}

/**
 @Status Interoperable
*/
void CGPathRelease(CGPathRef path) {
    if (path == NULL) {
        return;
    }

    CFRelease(path);
}

/**
 @Status Interoperable
*/
CGPathRef CGPathRetain(CGPathRef path) {
    if (path == NULL) {
        return NULL;
    }

    CFRetain(path);

    return path;
}

/**
@Status Stub
@Notes
*/
void CGPathAddQuadCurveToPoint(CGMutablePathRef path, const CGAffineTransform* transform, CGFloat cpx, CGFloat cpy, CGFloat x, CGFloat y) {
    UNIMPLEMENTED();
}

/**
@Status Stub
@Notes
*/
void CGPathAddCurveToPoint(CGMutablePathRef path,
                           const CGAffineTransform* transform,
                           CGFloat cp1x,
                           CGFloat cp1y,
                           CGFloat cp2x,
                           CGFloat cp2y,
                           CGFloat x,
                           CGFloat y) {
    UNIMPLEMENTED();
}

/**
 @Status Interoperable
*/
CGPathRef CGPathCreateWithRect(CGRect rect, const CGAffineTransform* trans) {
    CGMutablePathRef ret = CGPathCreateMutable();
    CGPathAddRect(ret, trans, rect);

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
 @Status Stub
 @Notes
*/
void CGPathAddRoundedRect(
    CGMutablePathRef path, const CGAffineTransform* transform, CGRect rect, CGFloat cornerWidth, CGFloat cornerHeight) {
    UNIMPLEMENTED();
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
    if (transform) {
        point = CGPointApplyAffineTransform(point, *transform);
    }

    BOOL containsPoint = false;

    path->closePath();
    FAIL_FAST_IF_FAILED(path->_impl.pathGeometry.Get()->FillContainsPoint(_CGPointToD2D_F(point), D2D1::IdentityMatrix(), &containsPoint));

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
 @Status Stub
 @Notes
*/
CGPathRef CGPathCreateWithRoundedRect(CGRect rect, CGFloat cornerWidth, CGFloat cornerHeight, const CGAffineTransform* transform) {
    UNIMPLEMENTED();
    return StubReturn();
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
    return path->_impl.currentPoint;
}

/**
 @Status Stub
 @Notes
*/
bool CGPathIsRect(CGPathRef path, CGRect* rect) {
    UNIMPLEMENTED();
    return StubReturn();
}