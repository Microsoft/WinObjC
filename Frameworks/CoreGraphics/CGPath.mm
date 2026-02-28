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
#import <WRLHelpers.h>
#include <COMIncludes_End.h>

#import <CFCppBase.h>
#import <CppUtils.h>

static const wchar_t* TAG = L"CGPath";

using namespace Microsoft::WRL;

class _CGPathCustomSink : public RuntimeClass<RuntimeClassFlags<RuntimeClassType::WinRtClassicComMix>, ID2D1GeometrySink> {
protected:
    InspectableClass(L"Windows.Bridge.Direct2D._CGPathCustomSink", TrustLevel::BaseTrust);

public:
    _CGPathCustomSink(_In_ ID2D1GeometrySink* sink)
        : m_geometrySink(sink),
          m_lastPoint{ 0, 0 },
          m_isFigureOpen(false),
          m_allowsFigureCalls(0),
          m_hasGeometryStarted(false),
          m_lastClose(D2D1_FIGURE_END_CLOSED),
          m_allowsFigureEndExceptFinal(0),
          m_delayedEndFigure(false) {
    }

    STDMETHOD_(void, SetFillMode)(D2D1_FILL_MODE fillMode) {
        m_geometrySink->SetFillMode(fillMode);
    }

    STDMETHOD_(void, SetSegmentFlags)(D2D1_PATH_SEGMENT vertexFlags) {
        m_geometrySink->SetSegmentFlags(vertexFlags);
    }

    STDMETHOD_(void, AddLines)(_In_reads_(pointsCount) CONST D2D1_POINT_2F* points, UINT32 pointsCount) {
        _delayedEndFigureCall();
        m_geometrySink->AddLines(points, pointsCount);
        m_lastPoint = points[pointsCount - 1];
    }

    STDMETHOD_(void, AddBeziers)(_In_reads_(beziersCount) CONST D2D1_BEZIER_SEGMENT* beziers, UINT32 beziersCount) {
        _delayedEndFigureCall();
        m_geometrySink->AddBeziers(beziers, beziersCount);
        m_lastPoint = beziers[beziersCount - 1].point3;
    }

    STDMETHOD_(void, AddLine)(D2D1_POINT_2F point) {
        _delayedEndFigureCall();
        m_geometrySink->AddLine(point);
        m_lastPoint = point;
    }

    STDMETHOD_(void, AddBezier)(_In_ CONST D2D1_BEZIER_SEGMENT* bezier) {
        _delayedEndFigureCall();
        m_geometrySink->AddBezier(bezier);
        m_lastPoint = bezier->point3;
    }

    STDMETHOD_(void, AddQuadraticBezier)(_In_ CONST D2D1_QUADRATIC_BEZIER_SEGMENT* bezier) {
        _delayedEndFigureCall();
        m_geometrySink->AddQuadraticBezier(bezier);
        m_lastPoint = bezier->point2;
    }

    STDMETHOD_(void, AddQuadraticBeziers)(_In_reads_(beziersCount) CONST D2D1_QUADRATIC_BEZIER_SEGMENT* beziers, UINT32 beziersCount) {
        _delayedEndFigureCall();
        m_geometrySink->AddQuadraticBeziers(beziers, beziersCount);
        m_lastPoint = beziers[beziersCount - 1].point2;
    }

    STDMETHOD_(void, AddArc)(_In_ CONST D2D1_ARC_SEGMENT* arc) {
        _delayedEndFigureCall();
        m_geometrySink->AddArc(arc);
        m_lastPoint = arc->point;
    }

    STDMETHOD_(void, _BeginFigure)(D2D1_POINT_2F startPoint, D2D1_FIGURE_BEGIN figureBegin) {
        _delayedEndFigureCall();
        _EndFigure(D2D1_FIGURE_END_OPEN);
        m_geometrySink->BeginFigure(startPoint, figureBegin);
        m_startPoint = startPoint;
        m_lastPoint = startPoint;

        m_isFigureOpen = true;
        m_hasGeometryStarted = true;
    }

    STDMETHOD_(void, BeginFigure)(D2D1_POINT_2F startPoint, D2D1_FIGURE_BEGIN figureBegin) {
        if (m_allowsFigureCalls > 0) {
            _BeginFigure(startPoint, figureBegin);
        }
    }

    // We are using an internal end figure call to force any simplify call to leave the figure open. Otherwise
    // Simplify will end and close the path causing an error state on further operations.
    STDMETHOD_(void, _EndFigure)(D2D1_FIGURE_END figureEnd) {
        if (m_isFigureOpen) {
            m_geometrySink->EndFigure(figureEnd);
            m_lastClose = figureEnd;
            m_isFigureOpen = false;
            if (figureEnd == D2D1_FIGURE_END_CLOSED) {
                m_lastPoint = m_startPoint;
            }
        }
    }

    // Only end the figure if we're requesting to actually close a figure, or if we have allowed the backing sink to dictate figure calls.
    STDMETHOD_(void, EndFigure)(D2D1_FIGURE_END figureEnd) {
        if (m_allowsFigureEndExceptFinal > 0 && figureEnd != D2D1_FIGURE_END_CLOSED) {
            m_delayedEndFigure = true;
            m_delayedEndFigureClosure = figureEnd;
        } else if (figureEnd == D2D1_FIGURE_END_CLOSED || m_allowsFigureCalls > 0) {
            _EndFigure(figureEnd);
        }
    }

    STDMETHOD(_Close)() {
        HRESULT hr = m_geometrySink->Close();
        m_geometrySink = nullptr;
        return hr;
    }

    // Close is left blank to prevent any Simplify call from closing and forcing us to re-open the current path.
    STDMETHOD(Close)() {
        return S_OK;
    };

    ID2D1GeometrySink* GetBackingSink() {
        return m_geometrySink.Get();
    }

    HRESULT SetAllowsFigureCalls(bool allows) {
        m_allowsFigureCalls += (allows ? 1 : -1);
        return m_allowsFigureCalls >= 0 ? S_OK : E_INVALIDARG;
    }

    bool IsFigureEndClosed() {
        return m_lastClose == D2D1_FIGURE_END_CLOSED;
    }

    bool IsSinkAvailable() {
        return m_geometrySink != nullptr;
    }

    bool IsFigureOpen() {
        return m_isFigureOpen;
    }

    bool IsGeometryStarted() {
        return m_hasGeometryStarted;
    }

    D2D1_POINT_2F GetCurrentPoint() {
        return m_lastPoint;
    }

    void SetCurrentPoint(D2D1_POINT_2F currentPoint) {
        m_lastPoint = currentPoint;
    }

    D2D1_POINT_2F GetStartingPoint() {
        return m_startPoint;
    }

    void SetStartingPoint(D2D1_POINT_2F startPoint) {
        m_startPoint = startPoint;
    }

    void SetBackingSink(ID2D1GeometrySink* sink) {
        m_geometrySink = sink;
    }

    HRESULT AllowAllExceptFinalEndFigure(bool allow) {
        m_allowsFigureEndExceptFinal += (allow ? 1 : -1);
        m_delayedEndFigure = false;
        return m_allowsFigureEndExceptFinal >= 0 ? S_OK : E_INVALIDARG;
    }

private:
    void _delayedEndFigureCall() {
        if (m_delayedEndFigure) {
            _EndFigure(m_delayedEndFigureClosure);
            m_delayedEndFigure = false;
        }
    }

    ComPtr<ID2D1GeometrySink> m_geometrySink;
    // The last point this geometry has moved to.
    D2D1_POINT_2F m_lastPoint;
    // The starting point this geometry will move to if it is closed.
    D2D1_POINT_2F m_startPoint;
    // Whether or not the figure is open and ready to receive new path information
    bool m_isFigureOpen;
    // Whether any geometry has been started. This can be inferred from other APIs, but those would require the geometry to be closed.
    bool m_hasGeometryStarted;
    // Greater than 0 if this geometry can end its own figures.
    int m_allowsFigureCalls;
    // Greater than 0 if this geometry will leave it's last EndFigure call ignored.
    int m_allowsFigureEndExceptFinal;
    // True when the next figure created should end the previous figure first.
    bool m_delayedEndFigure;
    // The figure closure type to end the last figure with.
    D2D1_FIGURE_END m_delayedEndFigureClosure;
    // The last figure closure type used.
    D2D1_FIGURE_END m_lastClose;
};

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
    ComPtr<_CGPathCustomSink> geometrySink;

    CGAffineTransform lastTransform;

    __CGPath() : lastTransform(CGAffineTransformIdentity) {
    }

    ID2D1PathGeometry* GetPathGeometry() const {
        return pathGeometry.Get();
    }

    ID2D1GeometrySink* GetGeometrySink() const {
        return geometrySink.Get();
    }

    bool IsLastFigureEndClosed() {
        return geometrySink->IsFigureEndClosed();
    }

    bool IsGeometryStarted() {
        return geometrySink && geometrySink->IsGeometryStarted();
    }

    HRESULT SetAllowsFigureCalls(bool allows) {
        return geometrySink->SetAllowsFigureCalls(allows);
    }

    CGPoint GetCurrentPoint() const {
        return _D2DPointToCGPoint(geometrySink->GetCurrentPoint());
    }

    // Only to be used by CGPathMoveToPoint to avoid copying a potentially closed geometry just to update the current point.
    void SetCurrentPoint(CGPoint point) {
        geometrySink->SetCurrentPoint(_CGPointToD2D_F(point));
    }

    CGPoint GetStartingPoint() const {
        return _D2DPointToCGPoint(geometrySink->GetStartingPoint());
    }

    void SetStartingPoint(CGPoint point) {
        geometrySink->SetStartingPoint(_CGPointToD2D_F(point));
    }

    void SetLastTransform(const CGAffineTransform* transform) {
        if (transform) {
            lastTransform = *transform;
        } else {
            lastTransform = CGAffineTransformIdentity;
        }
    }

    const CGAffineTransform* GetLastTransform() const {
        return &lastTransform;
    }

    HRESULT AllowAllExceptFinalEndFigure(bool allow) {
        RETURN_IF_FAILED(SetAllowsFigureCalls(allow));
        RETURN_IF_FAILED(geometrySink->AllowAllExceptFinalEndFigure(allow));
        return S_OK;
    }

    // A private helper function for re-opening a path geometry. CGPath does not
    // have a concept of an open and a closed path but D2D relies on it. A
    // path/sink cannot be read from while the path is open thus it must be
    // closed. However, a CGPath can be edited again after being read from so
    // we must open the path again. This cannot be done normally, so we must
    // create a new path with the old path information to edit.
    HRESULT PreparePathForEditing() {
        if (!IsGeometryStarted() && IsSinkAvailable() && !IsLastFigureEndClosed()) {
            RETURN_IF_FAILED(ClosePath());
        }
        if (!IsSinkAvailable()) {
            // Re-open this geometry.
            ComPtr<ID2D1Factory> factory;
            RETURN_IF_FAILED(_CGGetD2DFactory(&factory));

            // Create temp vars for new path/sink
            ComPtr<ID2D1PathGeometry> newPath;
            ComPtr<ID2D1GeometrySink> newBackingSink;

            // Open a new path that the contents of the old path will be streamed into. We cannot re-use the same path as it is now closed
            // and cannot be opened again. We use the newPath variable because the factory was returning the same pointer for some strange
            // reason so this will force it to do otherwise.
            RETURN_IF_FAILED(factory->CreatePathGeometry(&newPath));
            RETURN_IF_FAILED(newPath->Open(&newBackingSink));

            geometrySink->SetBackingSink(newBackingSink.Get());
            // Allow all calls except final endfigure
            RETURN_IF_FAILED(AllowAllExceptFinalEndFigure(true));
            RETURN_IF_FAILED(pathGeometry->Stream(geometrySink.Get()));
            RETURN_IF_FAILED(AllowAllExceptFinalEndFigure(false));
            geometrySink->SetFillMode(D2D1_FILL_MODE_WINDING);

            pathGeometry = newPath;
        }
        return S_OK;
    }

    bool IsSinkAvailable() {
        return geometrySink && geometrySink->IsSinkAvailable();
    }

    HRESULT ClosePath() {
        if (IsSinkAvailable()) {
            EndFigure(D2D1_FIGURE_END_OPEN);
            RETURN_IF_FAILED(geometrySink->_Close());
        }
        return S_OK;
    }

    bool IsFigureOpen() {
        return geometrySink && geometrySink->IsFigureOpen();
    }

    void BeginFigure() {
        if (IsSinkAvailable() && !geometrySink->IsFigureOpen()) {
            geometrySink->_BeginFigure(_CGPointToD2D_F(GetStartingPoint()), D2D1_FIGURE_BEGIN_FILLED);
        }
    }

    void EndFigure(D2D1_FIGURE_END figureStatus) {
        if (IsSinkAvailable() && geometrySink->IsFigureOpen()) {
            geometrySink->_EndFigure(figureStatus);
        }
    }

    HRESULT InitializeGeometries() {
        ComPtr<ID2D1Factory> factory;
        RETURN_IF_FAILED(_CGGetD2DFactory(&factory));

        RETURN_IF_FAILED(factory->CreatePathGeometry(&pathGeometry));
        ComPtr<ID2D1GeometrySink> newBackingSink;
        RETURN_IF_FAILED(pathGeometry->Open(&newBackingSink));
        newBackingSink->SetFillMode(D2D1_FILL_MODE_WINDING);

        geometrySink = Make<_CGPathCustomSink>(newBackingSink.Get());

        return S_OK;
    }

    HRESULT AddGeometryToPathWithTransformation(const ID2D1Geometry* geometry, const CGAffineTransform* transform) {
        RETURN_IF_FAILED(PreparePathForEditing());

        D2D1_MATRIX_3X2_F transformation = D2D1::IdentityMatrix();
        if (transform) {
            transformation = __CGAffineTransformToD2D_F(*transform);
        }
        RETURN_IF_FAILED(geometry->Simplify(D2D1_GEOMETRY_SIMPLIFICATION_OPTION_CUBICS_AND_LINES, &transformation, geometrySink.Get()));

        SetLastTransform(transform);
        return S_OK;
    }

    HRESULT WidenByStroking(
        CGPathRef path, CGFloat lineWidth, CGLineCap lineCap, CGLineJoin lineJoin, CGFloat miterLimit, const CGAffineTransform* transform) {
        RETURN_IF_FAILED(path->ClosePath());
        ComPtr<ID2D1StrokeStyle> newStrokeStyle = NULL;

        ComPtr<ID2D1Factory> factory;
        pathGeometry->GetFactory(&factory);

        ComPtr<ID2D1PathGeometry> newPath;
        ComPtr<ID2D1GeometrySink> newBackingSink;
        RETURN_IF_FAILED(factory->CreatePathGeometry(&newPath));
        RETURN_IF_FAILED(newPath->Open(&newBackingSink));
        geometrySink = Make<_CGPathCustomSink>(newBackingSink.Get());

        RETURN_IF_FAILED(factory->CreateStrokeStyle(D2D1::StrokeStyleProperties((D2D1_CAP_STYLE)lineCap,
                                                                                (D2D1_CAP_STYLE)lineCap,
                                                                                (D2D1_CAP_STYLE)lineCap,
                                                                                (D2D1_LINE_JOIN)lineJoin,
                                                                                lineJoin == kCGLineJoinMiter ? miterLimit : 0,
                                                                                D2D1_DASH_STYLE_SOLID,
                                                                                0),
                                                    nullptr,
                                                    0,
                                                    &newStrokeStyle));

        D2D1_MATRIX_3X2_F d2dTransform = D2D1::IdentityMatrix();
        if (transform) {
            d2dTransform = __CGAffineTransformToD2D_F(*transform);
        }

        RETURN_IF_FAILED(AllowAllExceptFinalEndFigure(true));
        RETURN_IF_FAILED(path->GetPathGeometry()->Widen(lineWidth, newStrokeStyle.Get(), d2dTransform, geometrySink.Get()));
        RETURN_IF_FAILED(AllowAllExceptFinalEndFigure(false));

        pathGeometry = newPath;

        return S_OK;
    }
};

HRESULT _CGPathGetGeometryWithFillMode(CGPathRef path, CGPathDrawingMode fillMode, ID2D1Geometry** pNewGeometry) {
    RETURN_HR_IF_NULL(E_POINTER, pNewGeometry);
    RETURN_HR_IF_NULL(E_POINTER, path);

    RETURN_IF_FAILED(path->ClosePath());
    if (fillMode == kCGPathEOFill || fillMode == kCGPathEOFillStroke) {
        ID2D1Geometry* geometry = path->GetPathGeometry();
        ComPtr<ID2D1Factory> factory;
        geometry->GetFactory(&factory);

        ComPtr<ID2D1GeometryGroup> geometryGroup;
        RETURN_IF_FAILED(factory->CreateGeometryGroup(D2D1_FILL_MODE_ALTERNATE, &geometry, 1, &geometryGroup));

        ComPtr<ID2D1Geometry> outGeometry;
        RETURN_IF_FAILED(geometryGroup.As(&outGeometry));

        *pNewGeometry = outGeometry.Detach();
    } else {
        path->pathGeometry.CopyTo(pNewGeometry);
    }
    return S_OK;
}

CFTypeID CGPathGetTypeID() {
    return __CGPath::GetTypeID();
}
namespace {
// A helper for determining the number of points per path element type
static inline size_t __CGPathGetExpectedPointCountForType(CGPathElementType type) {
    switch (type) {
        case kCGPathElementMoveToPoint:
        case kCGPathElementAddLineToPoint:
            return 1;
        case kCGPathElementAddQuadCurveToPoint:
            return 2;
        case kCGPathElementAddCurveToPoint:
            return 3;
        case kCGPathElementCloseSubpath:
            return 0;
        default:
            TraceError(TAG, L"Invalid CGPathElementType encountered.");
            return 0;
    }
}

// Create a mimic of CGPathElement that holds the points in a vector with a convenient copy constructor.
struct __CGPathElementVector {
    CGPathElementType type;
    std::vector<CGPoint> points;
    __CGPathElementVector(const CGPathElement& el)
        : type(el.type), points(el.points, el.points + __CGPathGetExpectedPointCountForType(el.type)) {
    }
};

// A struct to pass to the equality matching CGPathApply since only a single void* may be passed.
struct __CGPathElementMatch {
    std::vector<__CGPathElementVector> elements;
    bool equal = true;
    int positionToMatch = 0;
};
}

// A function to pass to CGPathApply to determine whether two paths are equal.
static void __CGPathApplyCheckEquality(void* pathMatchContext, const CGPathElement* element1) {
    __CGPathElementMatch* matchingContext = (__CGPathElementMatch*)pathMatchContext;

    // If the matching has already failed, simply return asap. There's no way to stop a CGPathApply early.
    if (!matchingContext->equal) {
        return;
    }
    int i = matchingContext->positionToMatch;
    __CGPathElementVector element2 = matchingContext->elements[i];
    if (element2.type != element1->type) {
        matchingContext->equal = false;
    } else if (element2.type != kCGPathElementCloseSubpath) {
        for (int i = 0; i < element2.points.size(); i++) {
            if (element1->points[i] != element2.points[i]) {
                matchingContext->equal = false;
                break;
            }
        }
    }

    matchingContext->positionToMatch++;
}

// A function to pass to CGPathApply to retrieve the individual path elements to check equality against.
static void _CGPathApplyGetElements(void* pathElements, const CGPathElement* element) {
    ((std::vector<__CGPathElementVector>*)pathElements)->emplace_back(*element);
}

static Boolean __CGPathEqual(CFTypeRef cf1, CFTypeRef cf2) {
    if (cf1 == cf2) {
        return true;
    }

    RETURN_FALSE_IF(!cf1);
    RETURN_FALSE_IF(!cf2);

    __CGPath* path1 = (__CGPath*)cf1;
    __CGPath* path2 = (__CGPath*)cf2;

    RETURN_FALSE_IF_FAILED(path1->ClosePath());
    RETURN_FALSE_IF_FAILED(path2->ClosePath());

    // Check the segment count of the path as they must be equal.
    UINT32 count1;
    UINT32 count2;
    RETURN_FALSE_IF_FAILED(path1->GetPathGeometry()->GetSegmentCount(&count1));
    RETURN_FALSE_IF_FAILED(path2->GetPathGeometry()->GetSegmentCount(&count2));
    if (count1 != count2) {
        return false;
    }

    std::vector<__CGPathElementVector> path1Elements;
    CGPathApply(path1, &path1Elements, _CGPathApplyGetElements);
    __CGPathElementMatch match;
    match.elements = path1Elements;
    CGPathApply(path2, &match, __CGPathApplyCheckEquality);

    return match.equal;
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
 @Status Interoperable
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

    FAIL_FAST_IF_FAILED(mutableRet->AllowAllExceptFinalEndFigure(true));
    FAIL_FAST_IF_FAILED(path->GetPathGeometry()->Stream(mutableRet->GetGeometrySink()));
    FAIL_FAST_IF_FAILED(mutableRet->AllowAllExceptFinalEndFigure(false));

    mutableRet->SetCurrentPoint(path->GetCurrentPoint());
    mutableRet->SetLastTransform(path->GetLastTransform());

    return mutableRet;
}

/**
 @Status Interoperable
*/
void CGPathAddLineToPoint(CGMutablePathRef path, const CGAffineTransform* transform, CGFloat x, CGFloat y) {
    RETURN_IF(!path || !path->IsGeometryStarted());

    FAIL_FAST_IF_FAILED(path->PreparePathForEditing());

    CGPoint pt = __CreateCGPointWithTransform(x, y, transform);

    path->BeginFigure();
    path->GetGeometrySink()->AddLine(_CGPointToD2D_F(pt));
    path->SetLastTransform(transform);
}

static inline CGPoint _getInvertedCurrentPointOfPath(CGPathRef path) {
    CGPoint point = path->GetCurrentPoint();
    if (!CGAffineTransformEqualToTransform(*path->GetLastTransform(), CGAffineTransformIdentity)) {
        point = CGPointApplyAffineTransform(point, CGAffineTransformInvert(*path->GetLastTransform()));
    }
    return point;
}

static HRESULT _createPathReadyForFigure(CGPathRef previousPath,
                                         CGPoint startPoint,
                                         ID2D1PathGeometry** pathGeometry,
                                         ID2D1GeometrySink** geometrySink) {
    ComPtr<ID2D1Factory> factory;
    RETURN_IF_FAILED(_CGGetD2DFactory(&factory));
    RETURN_IF_FAILED(factory->CreatePathGeometry(pathGeometry));
    RETURN_IF_FAILED((*pathGeometry)->Open(geometrySink));
    (*geometrySink)->SetFillMode(D2D1_FILL_MODE_WINDING);

    CGPoint invertedPoint = _getInvertedCurrentPointOfPath(previousPath);
    if (!CGPointEqualToPoint(invertedPoint, startPoint)) {
        (*geometrySink)->BeginFigure(_CGPointToD2D_F(invertedPoint), D2D1_FIGURE_BEGIN_FILLED);
        (*geometrySink)->AddLine(_CGPointToD2D_F(startPoint));
    } else {
        (*geometrySink)->BeginFigure(_CGPointToD2D_F(startPoint), D2D1_FIGURE_BEGIN_FILLED);
    }
    return S_OK;
}

static const CGFloat sc_zeroAngleThreshold = .00001;
// This function will return a normalized angle in radians between 0 and 2pi. This is to standardize
// the calculations for arcs since 0, 2pi, 4pi, etc... are all visually the same angle.
static CGFloat __normalizeAngle(CGFloat originalAngle) {
    CGFloat normalizedAngle = fmod(originalAngle, 2 * M_PI);
    if (abs(normalizedAngle) < sc_zeroAngleThreshold) {
        normalizedAngle = 0;
    }
    if (normalizedAngle == 0 && originalAngle != 0) {
        return 2 * M_PI;
    }
    return normalizedAngle;
}

/**
 @Status Interoperable
*/
void CGPathAddArcToPoint(
    CGMutablePathRef path, const CGAffineTransform* transform, CGFloat x1, CGFloat y1, CGFloat x2, CGFloat y2, CGFloat radius) {
    RETURN_IF(!path || !path->IsGeometryStarted());

    CGPoint invertedPoint = _getInvertedCurrentPointOfPath(path);

    // Get the distance to the vertex of the angle created by the tangent lines.
    CGFloat dx1 = x1 - invertedPoint.x;
    CGFloat dy1 = y1 - invertedPoint.y;

    CGFloat dx2 = x1 - x2;
    CGFloat dy2 = y1 - y2;

    // Normalize the angles of the tangent lines.
    CGFloat startAngle = __normalizeAngle(atan2(dy1, dx1));
    CGFloat endAngle = __normalizeAngle(atan2(dy2, dx2));

    // Calculate the angle of the bisector between the tangent line's angles.
    CGFloat bisector = (endAngle - startAngle) / 2;

    // tanLength is the distance to the point on the circle from the tangent line starting at the vertex point x1,y1.
    CGFloat tanLength = abs(radius / tan(bisector));

    // Calculate the tangent points on the circle from the tangent lines. These are the start and end points required by D2D.
    CGFloat tanPointAx = x1 - (tanLength * cos(startAngle));
    CGFloat tanPointAy = y1 - (tanLength * sin(startAngle));
    CGFloat tanPointBx = x1 - (tanLength * cos(endAngle));
    CGFloat tanPointBy = y1 - (tanLength * sin(endAngle));

    CGPoint endPoint = CGPointMake(tanPointBx, tanPointBy);
    const D2D1_POINT_2F endPointD2D = _CGPointToD2D_F(endPoint);

    // Determine the direction that the arc will be drawn in. This will always be the shorter angle which is why it's calculated based off
    // the startAngle + 180 degrees or PI radians.
    int sweepSign = 1;
    if (startAngle > endAngle) {
        sweepSign = -1;
    }
    D2D1_SWEEP_DIRECTION sweepDirection = { startAngle + (M_PI * sweepSign) < endAngle ? D2D1_SWEEP_DIRECTION_CLOCKWISE :
                                                                                         D2D1_SWEEP_DIRECTION_COUNTER_CLOCKWISE };
    // Set up the D2D arc segment.
    const D2D1_SIZE_F radiusD2D = { radius, radius };
    FLOAT rotationAngle = bisector * 2;
    D2D1_ARC_SIZE arcSize = D2D1_ARC_SIZE_SMALL;
    D2D1_ARC_SEGMENT arcSegment = D2D1::ArcSegment(endPointD2D, radiusD2D, rotationAngle, sweepDirection, arcSize);

    ComPtr<ID2D1PathGeometry> newPath;
    ComPtr<ID2D1GeometrySink> newSink;
    FAIL_FAST_IF_FAILED(_createPathReadyForFigure(path, CGPointMake(tanPointAx, tanPointAy), &newPath, &newSink));
    newSink->AddArc(arcSegment);
    newSink->EndFigure(D2D1_FIGURE_END_OPEN);
    FAIL_FAST_IF_FAILED(newSink->Close());

    FAIL_FAST_IF_FAILED(path->AddGeometryToPathWithTransformation(newPath.Get(), transform));

    if (transform) {
        endPoint = CGPointApplyAffineTransform(endPoint, *transform);
    }
}

static inline CGPoint _createCGPointOnAngle(CGFloat angle, CGFloat radius, int xOrigin, int yOrigin) {
    return CGPointMake(xOrigin + radius * cos(angle), yOrigin + radius * sin(angle));
}

/**
 @Status Interoperable
 @Notes All arcs from 0 to 2pi in either direction will result in a circle;
        the reference platform, by contrast, does not honor this behavior.
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

    // Normalize the angles to work with to values between 0 and 2*PI
    CGFloat normalizedStartAngle = __normalizeAngle(startAngle);
    CGFloat normalizedEndAngle = __normalizeAngle(endAngle);

    CGPoint startPoint = _createCGPointOnAngle(normalizedStartAngle, radius, x, y);
    CGPoint endPoint = _createCGPointOnAngle(normalizedEndAngle, radius, x, y);

    // Create the parameters for the AddArc method.
    const D2D1_POINT_2F endPointD2D = _CGPointToD2D_F(endPoint);
    const D2D1_SIZE_F radiusD2D = { radius, radius };
    D2D1_ARC_SIZE arcSize = D2D1_ARC_SIZE_SMALL;

    // D2D does not understand that the ending angle must be pointing in the proper direction, thus we must translate
    // what it means to have an ending angle to the proper small arc or large arc that D2D will use since a circle will
    // intersect that point regardless of which direction it is drawn in.
    CGFloat rawDifference = 0;
    if (clockwise) {
        rawDifference = normalizedStartAngle - normalizedEndAngle;
    } else {
        rawDifference = normalizedEndAngle - normalizedStartAngle;
    }
    CGFloat difference = rawDifference;
    if (difference < 0) {
        difference += 2 * M_PI;
    }
    if (difference > M_PI) {
        arcSize = D2D1_ARC_SIZE_LARGE;
    }

    rawDifference = abs(rawDifference);
    if (!clockwise) {
        rawDifference *= -1;
    }

    // The direction of the arc's sweep must be reversed since the coordinate systems for D2D and CoreGraphics are reversed.
    // CW in D2D is CCW in CoreGraphics.
    D2D1_SWEEP_DIRECTION sweepDirection = { clockwise ? D2D1_SWEEP_DIRECTION_COUNTER_CLOCKWISE : D2D1_SWEEP_DIRECTION_CLOCKWISE };

    ComPtr<ID2D1PathGeometry> newPath;
    ComPtr<ID2D1GeometrySink> newSink;
    if (!path->IsFigureOpen()) {
        CGPathMoveToPoint(path, transform, startPoint.x, startPoint.y);
    }
    FAIL_FAST_IF_FAILED(_createPathReadyForFigure(path, startPoint, &newPath, &newSink));

    // This will only happen when drawing a circle in the clockwise direction from 2pi to 0, a scenario
    // supported on the reference platform.
    if (abs(abs(rawDifference) - 2 * M_PI) < sc_zeroAngleThreshold) {
        CGFloat midPointAngle = normalizedStartAngle + rawDifference / 2;
        CGPoint midPoint = _createCGPointOnAngle(midPointAngle, radius, x, y);
        D2D1_ARC_SEGMENT arcSegment1 =
            D2D1::ArcSegment(_CGPointToD2D_F(midPoint), radiusD2D, rawDifference / 2, sweepDirection, D2D1_ARC_SIZE_SMALL);
        D2D1_ARC_SEGMENT arcSegment2 = D2D1::ArcSegment(endPointD2D, radiusD2D, rawDifference / 2, sweepDirection, D2D1_ARC_SIZE_SMALL);
        newSink->AddArc(arcSegment1);
        newSink->AddArc(arcSegment2);
    } else {
        D2D1_ARC_SEGMENT arcSegment = D2D1::ArcSegment(endPointD2D, radiusD2D, rawDifference, sweepDirection, arcSize);
        newSink->AddArc(arcSegment);
    }

    newSink->EndFigure(D2D1_FIGURE_END_OPEN);
    FAIL_FAST_IF_FAILED(newSink->Close());

    FAIL_FAST_IF_FAILED(path->AddGeometryToPathWithTransformation(newPath.Get(), transform));

    if (transform) {
        endPoint = CGPointApplyAffineTransform(endPoint, *transform);
    }
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
    path->BeginFigure();
}

/**
 @Status Interoperable
*/
void CGPathAddLines(CGMutablePathRef path, const CGAffineTransform* transform, const CGPoint* points, size_t count) {
    RETURN_IF(count == 0 || !points || !path);

    if (!path->IsFigureOpen()) {
        CGPathMoveToPoint(path, transform, points[0].x, points[0].y);
    }
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
    CGPoint newStart = toAdd->GetStartingPoint();
    //    CGPathMoveToPoint(path, transform, newStart.x, newStart.y);
    FAIL_FAST_IF_FAILED(path->AllowAllExceptFinalEndFigure(true));
    FAIL_FAST_IF_FAILED(path->AddGeometryToPathWithTransformation(toAdd->GetPathGeometry(), transform));
    FAIL_FAST_IF_FAILED(path->AllowAllExceptFinalEndFigure(false));
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

    FAIL_FAST_IF_FAILED(path->SetAllowsFigureCalls(true));
    FAIL_FAST_IF_FAILED(path->AddGeometryToPathWithTransformation(ellipseGeometry.Get(), transform));
    FAIL_FAST_IF_FAILED(path->SetAllowsFigureCalls(false));
}

/**
 @Status Interoperable
*/
void CGPathCloseSubpath(CGMutablePathRef path) {
    RETURN_IF(!path);
    path->PreparePathForEditing();
    path->EndFigure(D2D1_FIGURE_END_CLOSED);
}

namespace {
void __updateRectWithControlPoint(CGRect* rect, CGPoint point) {
    if (point.x < rect->origin.x) {
        rect->size.width += rect->origin.x - point.x;
        rect->origin.x = point.x;
    } else if (point.x > rect->origin.x + rect->size.width) {
        rect->size.width += point.x - rect->origin.x - rect->size.width;
    }
    if (point.y < rect->origin.y) {
        rect->size.height += rect->origin.y - point.y;
        rect->origin.y = point.y;
    } else if (point.y > rect->origin.y + rect->size.height) {
        rect->size.height += point.y - rect->origin.y - rect->size.height;
    }
}

void __CGPathApplyGetBoundingBoxWithControlPoints(void* rectangle, const CGPathElement* element) {
    CGRect* rect = static_cast<CGRect*>(rectangle);
    switch (element->type) {
        case kCGPathElementAddQuadCurveToPoint:
            __updateRectWithControlPoint(rect, element->points[0]);
            break;
        case kCGPathElementAddCurveToPoint:
            __updateRectWithControlPoint(rect, element->points[0]);
            __updateRectWithControlPoint(rect, element->points[1]);
            break;
        case kCGPathElementMoveToPoint:
        case kCGPathElementAddLineToPoint:
        default:
            break;
    }
}
}

/**
 @Status Interoperable
*/
CGRect CGPathGetBoundingBox(CGPathRef path) {
    if (path == NULL) {
        return CGRectNull;
    }

    if (FAILED(path->ClosePath())) {
        return CGRectNull;
    }
    CGRect boundingBoxWithControlPoints = CGPathGetPathBoundingBox(path);
    if (boundingBoxWithControlPoints == CGRectNull) {
        return CGRectNull;
    }
    CGPathApply(path, &boundingBoxWithControlPoints, __CGPathApplyGetBoundingBoxWithControlPoints);
    return boundingBoxWithControlPoints;
}

/**
 @Status Interoperable
*/
bool CGPathIsEmpty(CGPathRef path) {
    if (path == NULL) {
        return true;
    }

    return !path->IsGeometryStarted();
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
    RETURN_IF(!path || !path->IsGeometryStarted());

    CGPoint endPoint = CGPointMake(x, y);
    CGPoint controlPoint = CGPointMake(cpx, cpy);

    ComPtr<ID2D1PathGeometry> newPath;
    ComPtr<ID2D1GeometrySink> newSink;

    FAIL_FAST_IF_FAILED(_createPathReadyForFigure(path, _getInvertedCurrentPointOfPath(path), &newPath, &newSink));
    newSink->AddQuadraticBezier(D2D1::QuadraticBezierSegment(_CGPointToD2D_F(controlPoint), _CGPointToD2D_F(endPoint)));
    newSink->EndFigure(D2D1_FIGURE_END_OPEN);
    FAIL_FAST_IF_FAILED(newSink->Close());

    FAIL_FAST_IF_FAILED(path->AddGeometryToPathWithTransformation(newPath.Get(), transform));

    if (transform) {
        endPoint = CGPointApplyAffineTransform(endPoint, *transform);
    }
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
    RETURN_IF(!path || !path->IsGeometryStarted());

    CGPoint endPoint = CGPointMake(x, y);
    CGPoint controlPoint1 = CGPointMake(cp1x, cp1y);
    CGPoint controlPoint2 = CGPointMake(cp2x, cp2y);

    ComPtr<ID2D1PathGeometry> newPath;
    ComPtr<ID2D1GeometrySink> newSink;

    FAIL_FAST_IF_FAILED(_createPathReadyForFigure(path, _getInvertedCurrentPointOfPath(path), &newPath, &newSink));
    newSink->AddBezier(D2D1::BezierSegment(_CGPointToD2D_F(controlPoint1), _CGPointToD2D_F(controlPoint2), _CGPointToD2D_F(endPoint)));
    newSink->EndFigure(D2D1_FIGURE_END_OPEN);
    FAIL_FAST_IF_FAILED(newSink->Close());

    FAIL_FAST_IF_FAILED(path->AddGeometryToPathWithTransformation(newPath.Get(), transform));

    if (transform) {
        endPoint = CGPointApplyAffineTransform(endPoint, *transform);
    }
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
 @Status Interoperable
*/
CGRect CGPathGetPathBoundingBox(CGPathRef path) {
    if (path == NULL) {
        return CGRectNull;
    }

    if (FAILED(path->ClosePath())) {
        return CGRectNull;
    }

    D2D1_RECT_F bounds;
    if (FAILED(path->GetPathGeometry()->GetBounds(D2D1::IdentityMatrix(), &bounds))) {
        return CGRectNull;
    }

    return _D2DRectToCGRect(bounds);
}

/**
 @Status Interoperable
*/
void CGPathAddRects(CGMutablePathRef path, const CGAffineTransform* transform, const CGRect* rects, size_t count) {
    RETURN_IF(count == 0 || !rects || !path);

    for (int i = 0; i < count; i++) {
        CGPathAddRect(path, transform, rects[i]);
    }
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

    FAIL_FAST_IF_FAILED(path->SetAllowsFigureCalls(true));
    FAIL_FAST_IF_FAILED(path->AddGeometryToPathWithTransformation(rectangleGeometry.Get(), transform));
    FAIL_FAST_IF_FAILED(path->SetAllowsFigureCalls(false));
}

/**
 @Status Caveat
 @Notes Quadratic Bezier Curves are simplified into Cubic Bezier curves. Control point approximation for arcs differs from reference
 platform.
*/
void CGPathApply(CGPathRef path, void* info, CGPathApplierFunction function) {
    RETURN_IF(!path);
    FAIL_FAST_IF_FAILED(path->ClosePath());
    FAIL_FAST_IF_FAILED(_CGPathApplyInternal(path->GetPathGeometry(), info, function));
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
 @Status Caveat
 @Notes Creates a mutable copy. This API will approximate curves using straight line segments. This is simply a consequence
        of using the Widen API.
*/
CGPathRef CGPathCreateCopyByStrokingPath(
    CGPathRef path, const CGAffineTransform* transform, CGFloat lineWidth, CGLineCap lineCap, CGLineJoin lineJoin, CGFloat miterLimit) {
    RETURN_NULL_IF(!path);

    // Widenening with a width of 0 removes the path entirely, thus we need to return a regular copy here.
    if (lineWidth == 0) {
        return CGPathCreateCopy(path);
    }
    CGPathRef newPath = CGPathCreateMutable();
    FAIL_FAST_IF_FAILED(newPath->WidenByStroking(path, lineWidth, lineCap, lineJoin, miterLimit, transform));
    newPath->SetLastTransform(path->GetLastTransform());

    return newPath;
}

/**
 @Status Interoperable
 @Notes Creates a mutable copy
*/
CGPathRef CGPathCreateCopyByTransformingPath(CGPathRef path, const CGAffineTransform* transform) {
    return CGPathCreateMutableCopyByTransformingPath(path, transform);
}

/**
 @Status Interoperable
*/
CGMutablePathRef CGPathCreateMutableCopyByTransformingPath(CGPathRef path, const CGAffineTransform* transform) {
    RETURN_NULL_IF(!path);

    if (transform && !CGAffineTransformEqualToTransform(*transform, CGAffineTransformIdentity)) {
        CGMutablePathRef transformedPath = CGPathCreateMutable();
        FAIL_FAST_IF_FAILED(path->ClosePath());

        FAIL_FAST_IF_FAILED(transformedPath->AllowAllExceptFinalEndFigure(true));
        FAIL_FAST_IF_FAILED(transformedPath->AddGeometryToPathWithTransformation(path->GetPathGeometry(), transform));
        FAIL_FAST_IF_FAILED(transformedPath->AllowAllExceptFinalEndFigure(false));

        transformedPath->SetStartingPoint(path->GetStartingPoint());
        transformedPath->SetCurrentPoint(path->GetCurrentPoint());
        transformedPath->SetLastTransform(transform);
        return transformedPath;
    }
    return CGPathCreateMutableCopy(path);
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
 @Status Interoperable
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
