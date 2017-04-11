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

#import <CoreText/CTFrame.h>
#import <StubReturn.h>

#import "DWriteWrapper_CoreText.h"
#import "CoreTextInternal.h"
#import "CGContextInternal.h"
#import "CGPathInternal.h"

const CFStringRef kCTFrameProgressionAttributeName = CFSTR("kCTFrameProgressionAttributeName");
const CFStringRef kCTFramePathFillRuleAttributeName = CFSTR("kCTFramePathFillRuleAttributeName");
const CFStringRef kCTFramePathWidthAttributeName = CFSTR("kCTFramePathWidthAttributeName");
const CFStringRef kCTFrameClippingPathsAttributeName = CFSTR("kCTFrameClippingPathsAttributeName");
const CFStringRef kCTFramePathClippingPathAttributeName = CFSTR("kCTFramePathClippingPathAttributeName");

/**
 @Status Interoperable
*/
CFRange CTFrameGetStringRange(CTFrameRef frame) {
    RETURN_RESULT_IF_NULL(frame, CFRangeMake(0, 0));

    CFIndex count = 0;
    CFIndex len = CFArrayGetCount(frame->_lines);

    for (CFIndex index = 0; index < len; ++index) {
        _CTLine* line = static_cast<_CTLine*>(CFArrayGetValueAtIndex(frame->_lines, index));
        count += line->_strRange.length;
    }

    return CFRangeMake(0, count);
}

/**
 @Status Interoperable
*/
CFRange CTFrameGetVisibleStringRange(CTFrameRef frame) {
    RETURN_RESULT_IF_NULL(frame, CFRangeMake(0, 0));

    CFIndex count = 0;
    for (size_t index = 0; index < frame->_lineOrigins.size(); ++index) {
        if (frame->_lineOrigins[index].y < frame->_frameRect.size.height) {
            _CTLine* line = static_cast<_CTLine*>(CFArrayGetValueAtIndex(frame->_lines, index));
            count += line->_strRange.length;
        }
    }
    return CFRangeMake(0, count);
}

/**
 @Status Interoperable
*/
CGPathRef CTFrameGetPath(CTFrameRef frame) {
    RETURN_NULL_IF(!frame);
    return frame->_path;
}

/**
 @Status Stub
 @Notes
*/
CFDictionaryRef CTFrameGetFrameAttributes(CTFrameRef frame) {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Interoperable
*/
CFArrayRef CTFrameGetLines(CTFrameRef frame) {
    RETURN_NULL_IF(!frame);
    return frame->_lines;
}

/**
 @Status Interoperable
*/
void CTFrameGetLineOrigins(CTFrameRef frame, CFRange range, CGPoint origins[]) {
    RETURN_IF(!frame);
    _boundedCopy(range, frame->_lineOrigins.size(), frame->_lineOrigins.data(), origins);
}

/**
 @Status Interoperable
*/
void CTFrameDraw(CTFrameRef frame, CGContextRef ctx) {
    RETURN_IF(!ctx);
    RETURN_IF(!frame);

    std::vector<GlyphRunData> runs;

    for (size_t i = 0; i < frame->_lineOrigins.size() && (frame->_lineOrigins[i].y < frame->_frameRect.size.height); ++i) {
        _CTLine* line = static_cast<_CTLine*>(CFArrayGetValueAtIndex(frame->_lines, i));

        CGPoint relativePosition = frame->_lineOrigins[i];

        for (size_t j = 0; j < [line->_runs count]; ++j) {
            _CTRun* curRun = [line->_runs objectAtIndex:j];
            if (j > 0) {
                // Adjusts x position relative to the last run drawn
                relativePosition.x += curRun->_relativeXOffset;
            }
            runs.emplace_back(GlyphRunData{ &curRun->_dwriteGlyphRun, relativePosition, (CFDictionaryRef)curRun->_attributes.get() });
        }
    }

    if (!runs.empty()) {
        // Need to invert and translate coordinates so frame draws from top-left
        CGRect boundingRect = CGPathGetBoundingBox(frame->_path);
        CGContextTranslateCTM(ctx, 0, boundingRect.size.height);

        // Invert Text Matrix and CTM so glyphs are drawn in correct orientation and position
        CGAffineTransform textMatrix = CGContextGetTextMatrix(ctx);
        CGContextSetTextMatrix(ctx, CGAffineTransformMake(textMatrix.a, -textMatrix.b, textMatrix.c, -textMatrix.d, 0, 0));
        CGContextScaleCTM(ctx, 1.0f, -1.0f);

        _CGContextPushBeginDraw(ctx);
        auto popEnd = wil::ScopeExit([&]() {
            // Restore CTM and Text Matrix to values before we modified them
            CGContextSetTextMatrix(ctx, textMatrix);
            CGContextScaleCTM(ctx, 1.0f, -1.0f);
            CGContextTranslateCTM(ctx, 0, -boundingRect.size.height);
            _CGContextPopEndDraw(ctx);
        });

        _CGContextDrawGlyphRuns(ctx, runs.data(), runs.size());
    }
}

/**
 @Status Stub
 @Notes
*/
CFTypeID CTFrameGetTypeID() {
    UNIMPLEMENTED();
    return StubReturn();
}

// Convenience private function for NSString+UIKitAdditions
CGSize _CTFrameGetSize(CTFrameRef frame) {
    RETURN_RESULT_IF_NULL(frame, CGSize{});
    return frame->_frameRect.size;
}
