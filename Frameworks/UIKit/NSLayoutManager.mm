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

#include <StubReturn.h>
#include "Starboard.h"

#include <UIKit/NSLayoutManager.h>
#include <UIKit/NSLayoutManagerDelegate.h>
#include <UIKit/NSTextContainer.h>
#include <UIKit/UIGraphics.h>

#include "CoreTextInternal.h"
#include "CGContextInternal.h"

#include <vector>
#include <functional>

@implementation NSLayoutManager {
    NSMutableArray* _textContainers;
    StrongId<NSTextStorage> _textStorage;
    NSMutableArray* _ctLines;
    std::vector<CGPoint> _lineOrigins;
    CGSize _totalSize;
    BOOL _needsLayout;
    woc::unique_cf<CTFrameRef> _frame;
}

// Private helper:
// Given a CTLineRef, returns the index of the character in the original string, that maps to the last visible glyph in the line
static CFIndex __CTLineGetStringIndexOfLastVisibleGlyph(CTLineRef line) {
    CFArrayRef runs = CTLineGetGlyphRuns(line);

    CFIndex ret = -1;
    for (CFIndex i = CFArrayGetCount(runs) - 1; i >= 0; --i) {
        CTRunRef run = static_cast<CTRunRef>(CFArrayGetValueAtIndex(runs, i));
        CFIndex glyphCount = CTRunGetGlyphCount(run);

        // Open question: Can runs ever be non-monotonic with respect to the original string?
        // If not, can do an early return here
        if (glyphCount > 0) {
            const CFIndex* stringIndices = CTRunGetStringIndicesPtr(run);

            // Glyphs within a run can be non-monotonic with respect to the original string
            // Find the greatest index within the run's string indices
            const CFIndex* maxIndexInRun = std::max_element(stringIndices, stringIndices + glyphCount);

            if (*maxIndexInRun > ret) {
                ret = *maxIndexInRun;
            }
        }
    }

    return ret;
}

// Private helper for getting the width and height of a line in DIPs
static inline CGSize __CTLineGetBounds(CTLineRef line) {
    CGFloat ascent, descent, leading;
    return { CTLineGetTypographicBounds(line, &ascent, &descent, &leading), ascent + descent + leading };
}

- (void)__layoutAllText {
    [_ctLines removeAllObjects];
    _lineOrigins.clear();
    _totalSize.width = 0;
    _totalSize.height = 0;

    woc::unique_cf<CTFramesetterRef> framesetter{ CTFramesetterCreateWithAttributedString(
        static_cast<CFAttributedStringRef>(_textStorage.get())) };

    // Creates frame containing all of the text, which allows us to measure the line heights for measuring rectangles and breaks the text
    // into CTLineRefs for hard line breaks (e.g. '\n') which allows the assumption that once we run out of glyphs in a line to draw we must
    // perform a line break
    if (!_frame) {
        woc::unique_cf<CGPathRef> path{ CGPathCreateWithRect(CGRectMake(0, 0, FLT_MAX, FLT_MAX), nullptr) };
        _frame.reset(CTFramesetterCreateFrame(framesetter.get(), {}, path.get(), nullptr));
    }

    NSTextContainer* container = (NSTextContainer*)_textContainers[0];
    const CGSize containerSize = container.size;
    CGPoint origin{ 0, 0 };

    for (id lineRef in static_cast<NSArray*>(CTFrameGetLines(_frame.get()))) {
        CTLineRef line = static_cast<CTLineRef>(lineRef);

        // Maximum height of lines on current horizontal, needed to get next yPos
        const CGFloat lineHeight = __CTLineGetBounds(line).height;

        const CFRange lineRange = CTLineGetStringRange(line);
        const CFIndex lineEnd = lineRange.location + lineRange.length; // String index of last glyph in line

        const CFIndex indexOfLastVisibleChar = __CTLineGetStringIndexOfLastVisibleGlyph(line); // Alternate termination point

        CGRect proposedRect{}; // Proposes a drawing rectangle to [NSTextContainer lineFragmentRectForProposedRect]
        proposedRect.size.width = containerSize.width;
        proposedRect.size.height = lineHeight;

        CGRect frameDrawRect{}; // Drawing rectangle actually used in CTFramesetterCreateFrame to layout the text
        frameDrawRect.size.height = lineHeight;

        double drawnWidth = 0.0; // Width of line already drawn, saves us from having to redraw line twice

        CFIndex stringIndex = lineRange.location; // String index of first glyph in line to be drawn
        while (stringIndex < lineEnd) {
            if (origin.y > containerSize.height) {
                // Added as much text as can fit in the frame, can end here
                return;
            }

            if (stringIndex > indexOfLastVisibleChar) {
                // Ended up without any visible glyphs to draw, caused by a line of only whitespace
                origin = { 0.0f, origin.y + lineHeight };
                break;
            }

            CGRect remainingRect{};
            proposedRect.origin = origin;
            const CGRect rect = [container lineFragmentRectForProposedRect:proposedRect
                                                                   atIndex:stringIndex
                                                          writingDirection:NSWritingDirectionLeftToRight
                                                             remainingRect:&remainingRect];

            // Approximate how many characters can fit to keep from re-rendering large amounts of text
            const CFIndex lastIndex = std::min(CTLineGetStringIndexForPosition(line, { drawnWidth + rect.size.width, 0.0f }) + 1, lineEnd);

            if (lastIndex == stringIndex) {
                // Unable to fit any text in the current rect, continue to next
                if (remainingRect.size.width > 0.0f && stringIndex < lineEnd) {
                    origin = { remainingRect.origin.x, origin.y };
                } else {
                    origin = { 0.0f, origin.y + lineHeight };
                }

                continue;
            }

            frameDrawRect.size.width = rect.size.width;
            woc::unique_cf<CGPathRef> path{ CGPathCreateWithRect(frameDrawRect, nullptr) };
            woc::unique_cf<CTFrameRef> frame{
                CTFramesetterCreateFrame(framesetter.get(), { stringIndex, lastIndex - stringIndex }, path.get(), nullptr)
            };

            // Create line to fit as much text as possible in given rect
            CTLineRef fitLine = static_cast<CTLineRef>(CFArrayGetValueAtIndex(CTFrameGetLines(frame.get()), 0));

            const CFIndex fitLength = CTLineGetStringRange(fitLine).length;
            if (fitLength == 0L) {
                // Failed to fit any text in the current rect, continue to next
                if (remainingRect.size.width > 0.0f && stringIndex < lineEnd) {
                    origin = { remainingRect.origin.x, origin.y };
                } else {
                    origin = { 0.0f, origin.y + lineHeight };
                }

                continue;
            }
            stringIndex += fitLength;

            // Save line and origin for when it is drawn
            [_ctLines addObject:(id)fitLine];
            _lineOrigins.emplace_back(CGPoint{ rect.origin.x, rect.origin.y + lineHeight });

            const double fitWidth = CTLineGetTypographicBounds(fitLine, nullptr, nullptr, nullptr);
            drawnWidth += fitWidth;

            if (remainingRect.size.width > 0 && stringIndex < lineEnd) {
                origin = { remainingRect.origin.x, origin.y };
            } else {
                origin = { 0.0f, origin.y + lineHeight };
                _totalSize.width = std::max(_totalSize.width, static_cast<CGFloat>(rect.origin.x + fitWidth));
                if (stringIndex > indexOfLastVisibleChar) {
                    // Ended up with whitespace at end of the line, break to next line
                    break;
                }
            }
        }
    }

    _totalSize.height = origin.y;
}

- (void)layoutIfNeeded {
    if (_needsLayout) {
        _needsLayout = FALSE;
        [self __layoutAllText];
    }
}

/**
 @Status Interoperable
*/

- (instancetype)init {
    _textContainers = [NSMutableArray new];
    _ctLines = [NSMutableArray new];
    _needsLayout = TRUE;
    return self;
}

/**
 @Status Interoperable
*/

- (void)addTextContainer:(NSTextContainer*)container {
    [_textContainers addObject:container];
    container.layoutManager = self;
    _needsLayout = TRUE;
}

/**
 @Status Interoperable
*/

- (void)setTextStorage:(NSTextStorage*)storage {
    _textStorage = storage;
    [_textStorage addLayoutManager:self];
}

/**
 @Status Interoperable
*/

- (NSTextStorage*)textStorage {
    return _textStorage;
}

/**
 @Status Stub
*/

- (void)drawBackgroundForGlyphRange:(NSRange)range atPoint:(CGPoint)position {
    UNIMPLEMENTED();
}

/**
 @Status Caveat

 @Notes range parameter is not supported
*/

- (void)drawGlyphsForGlyphRange:(NSRange)range atPoint:(CGPoint)position {
    [self layoutIfNeeded];

    CGContextRef curCtx = UIGraphicsGetCurrentContext();
    CGContextSaveGState(curCtx);
    CGContextSetTextMatrix(curCtx, CGAffineTransformMakeScale(1.0f, -1.0f));

    _CGContextPushBeginDraw(curCtx);
    auto popEnd = wil::ScopeExit([curCtx]() { _CGContextPopEndDraw(curCtx); });

    int count = [_ctLines count];
    for (int curLine = 0; curLine < count; curLine++) {
        CTLineRef line = (CTLineRef)_ctLines[curLine];
        CGContextSaveGState(curCtx);
        CGContextSetTextPosition(curCtx, _lineOrigins[curLine].x, _lineOrigins[curLine].y);
        CTLineDraw(line, curCtx);
        CGContextRestoreGState(curCtx);
    }
    CGContextRestoreGState(curCtx);
}

/**
 @Status Caveat

 @Notes Text container parameter is not supported
*/

- (CGRect)usedRectForTextContainer:(NSTextContainer*)tc {
    [self layoutIfNeeded];

    CGRect ret;

    ret.origin.x = 0;
    ret.origin.y = 0;
    ret.size = _totalSize;
    return ret;
}

static NSRange NSRangeFromCFRange(CFRange range) {
    NSRange ret;

    ret.location = range.location;
    ret.length = range.length;

    return ret;
}

- (CGRect)_rectForLine:(NSUInteger)lineIdx {
    CGPoint origin = _lineOrigins[lineIdx];
    CGRect ret;

    ret.origin = _lineOrigins[lineIdx];

    CGFloat ascent, descent, leading;

    ret.size.width = _totalSize.width;

    CTLineGetTypographicBounds((CTLineRef)_ctLines[lineIdx], &ascent, &descent, &leading);
    ret.size.height = ascent + descent + leading;

    return ret;
}

/**
 @Status Caveat

 @Notes There is currently no distinction between character ranges and glyph ranges.
*/

- (NSRange)characterRangeForGlyphRange:(NSRange)range actualGlyphRange:(NSRange*)actualRange {
    [self layoutIfNeeded];

    /*** Caveat: Character ranges and glyph ranges are the same ***/
    if (actualRange) {
        *actualRange = range;
    }
    return range;
}

/**
 @Status Caveat

 @Notes There is currently no distinction between character ranges and glyph ranges.
*/

- (NSRange)glyphRangeForCharacterRange:(NSRange)range actualCharacterRange:(NSRange*)actualRange {
    [self layoutIfNeeded];

    /*** Caveat: Character ranges and glyph ranges are the same ***/
    if (actualRange) {
        *actualRange = range;
    }
    return range;
}

/**
 @Status Caveat

 @Notes Only one text container is supported - this method returns text container zero, effectiveRange is not supported, effectiveRange
 parameter not supported.
*/

- (NSTextContainer*)textContainerForGlyphAtIndex:(NSUInteger)glyphIndex effectiveRange:(NSRange*)effectiveRange {
    [self layoutIfNeeded];

    /*** Caveat: We can only handle one text container ***/
    NSTextContainer* ret = [_textContainers objectAtIndex:0];

    if (effectiveRange) {
        UNIMPLEMENTED_WITH_MSG("effectiveRange parameter not supported.");
    }

    return ret;
}

/**
 @Status Caveat

 @Notes The text container parameter is ignored.
*/

- (CGRect)boundingRectForGlyphRange:(NSRange)range inTextContainer:(NSTextContainer*)tc {
    [self layoutIfNeeded];

    CGRect ret = CGRectNull;
    int count = [_ctLines count];

    for (int curLineIdx = 0; curLineIdx < count; curLineIdx++) {
        CTLineRef curLine = (CTLineRef)_ctLines[curLineIdx];

        NSRange lineRange = NSRangeFromCFRange(CTLineGetStringRange(curLine));

        if (NSIntersectionRange(lineRange, range).length > 0) {
            CFArrayRef runs = CTLineGetGlyphRuns(curLine);
            int runCount = CFArrayGetCount(runs);

            for (int curRunIdx = 0; curRunIdx < runCount; curRunIdx++) {
                CTRunRef curRun = (CTRunRef)CFArrayGetValueAtIndex(runs, curRunIdx);

                CFRange runRange = CTRunGetStringRange(curRun);
                NSRange intersection = NSIntersectionRange(NSRangeFromCFRange(runRange), range);
                if (intersection.length > 0) {
                    CGRect lineRect = [self _rectForLine:curLineIdx];

                    NSRange runIntersection;

                    runIntersection.location = intersection.location - runRange.location;
                    runIntersection.length = intersection.length;

                    CGPoint firstLetterPosition, lastLetterPosition;

                    CFRange pos;

                    pos.location = runIntersection.location;
                    pos.length = 1;
                    CTRunGetPositions(curRun, pos, &firstLetterPosition);

                    pos.location = runIntersection.location + runIntersection.length - 1;
                    pos.length = 1;
                    CTRunGetPositions(curRun, pos, &lastLetterPosition);

                    CGSize lastLetterAdvance;
                    CTRunGetAdvances(curRun, pos, &lastLetterAdvance);

                    //  Construct a rectangle and union it with our current rectangle
                    CGRect runRect;
                    runRect.origin.x = lineRect.origin.x + firstLetterPosition.x;
                    runRect.origin.y = lineRect.origin.y;
                    runRect.size.width = (lastLetterPosition.x + lastLetterAdvance.width) - firstLetterPosition.x;
                    runRect.size.height = lineRect.size.height;

                    ret = CGRectUnion(ret, runRect);
                }
            }
        }
    }

    if (CGRectIsNull(ret)) {
        ret = CGRectMake(0, 0, 0, 0);
    }

    return ret;
}

/**
 @Status Caveat

 @Notes fraction is always returned as 0.0
*/

- (NSUInteger)glyphIndexForPoint:(CGPoint)pt inTextContainer:(NSTextContainer*)container fractionOfDistanceThroughGlyph:(CGFloat*)fraction {
    /*** Caveat: Fraction is not returned ***/

    [self layoutIfNeeded];

    int lineCount = [_ctLines count];

    if (lineCount == 0)
        return 0;
    int ret = 0;

    //  Find the closest line
    int closestLine = 0;
    float closestDistance = FLT_MAX;
    CGRect lineRect = CGRectMake(0, 0, 0, 0);

    for (int curLineIdx = 0; curLineIdx < lineCount; curLineIdx++) {
        CGRect rect = [self _rectForLine:curLineIdx];

        if (CGRectContainsPoint(rect, pt)) {
            closestLine = curLineIdx;
            lineRect = rect;
            break;
        }

        float dist1 = fabs(rect.origin.y - pt.y);
        if (dist1 < closestDistance) {
            closestLine = curLineIdx;
            closestDistance = dist1;
            lineRect = rect;
        }
        float dist2 = fabs(rect.origin.y + rect.size.height - pt.y);
        if (dist2 < closestDistance) {
            closestLine = curLineIdx;
            closestDistance = dist2;
            lineRect = rect;
        }
    }

    //  Find the closest glyph within this run
    closestDistance = FLT_MAX;
    CFArrayRef runs = CTLineGetGlyphRuns((CTLineRef)_ctLines[closestLine]);
    int runCount = CFArrayGetCount(runs);
    bool stop = false;

    for (int curRunIdx = 0; curRunIdx < runCount && !stop; curRunIdx++) {
        CTRunRef curRun = (CTRunRef)CFArrayGetValueAtIndex(runs, curRunIdx);

        CFRange runRange = CTRunGetStringRange(curRun);
        CGPoint* glyphPositions = (CGPoint*)malloc(sizeof(CGPoint) * runRange.length);
        CGSize* glyphSizes = (CGSize*)malloc(sizeof(CGSize) * runRange.length);

        CFRange indexes;
        indexes.location = 0;
        indexes.length = runRange.length;

        CTRunGetPositions(curRun, indexes, glyphPositions);
        CTRunGetAdvances(curRun, indexes, glyphSizes);

        for (int curCharIdx = 0; curCharIdx < indexes.length; curCharIdx++) {
            //  Construct a rectangle for this glyph
            CGRect glyphRect;
            glyphRect.origin.x = lineRect.origin.x + glyphPositions[curCharIdx].x;
            glyphRect.origin.y = lineRect.origin.y;
            glyphRect.size.width = glyphSizes[curCharIdx].width;
            glyphRect.size.height = lineRect.size.height;

            if (CGRectContainsPoint(glyphRect, pt)) {
                ret = runRange.location + curCharIdx;
                stop = true;
                break;
            }

            float dist1 = fabs(glyphRect.origin.x - pt.x);
            if (dist1 < closestDistance) {
                ret = runRange.location + curCharIdx;
                closestDistance = dist1;
            }
            float dist2 = fabs(glyphRect.origin.x + glyphRect.size.width - pt.x);
            if (dist2 < closestDistance) {
                ret = runRange.location + curCharIdx;
                closestDistance = dist2;
            }
        }

        free(glyphPositions);
        free(glyphSizes);
    }

    return ret;
}

/**
 @Status Interoperable
*/

- (CGRect)lineFragmentRectForGlyphAtIndex:(NSUInteger)idx effectiveRange:(NSRange*)outGlyphRange {
    [self layoutIfNeeded];

    int count = [_ctLines count];

    for (int curLineIdx = 0; curLineIdx < count; curLineIdx++) {
        CTLineRef curLine = (CTLineRef)_ctLines[curLineIdx];

        CFRange lineRange = CTLineGetStringRange(curLine);

        if (lineRange.location <= idx && lineRange.location + lineRange.length > idx) {
            CGRect ret = [self _rectForLine:curLineIdx];

            if (outGlyphRange) {
                outGlyphRange->location = lineRange.location;
                outGlyphRange->length = lineRange.length;
            }

            return ret;
        }
    }

    CGRect ret = { 0 };
    return ret;
}

/**
 @Status Interoperable
*/

- (CGPoint)locationForGlyphAtIndex:(NSUInteger)idx {
    [self layoutIfNeeded];

    int count = [_ctLines count];

    for (int curLineIdx = 0; curLineIdx < count; curLineIdx++) {
        CTLineRef curLine = (CTLineRef)_ctLines[curLineIdx];

        CFRange lineRange = CTLineGetStringRange(curLine);

        if (lineRange.location <= idx && lineRange.location + lineRange.length > idx) {
            CFArrayRef runs = CTLineGetGlyphRuns(curLine);
            int runCount = CFArrayGetCount(runs);

            for (int curRunIdx = 0; curRunIdx < runCount; curRunIdx++) {
                CTRunRef curRun = (CTRunRef)CFArrayGetValueAtIndex(runs, curRunIdx);

                CFRange runRange = CTRunGetStringRange(curRun);
                if (runRange.location <= idx && runRange.location + runRange.length > idx) {
                    CGPoint ret;

                    CFRange pos;
                    pos.location = idx - runRange.location;
                    pos.length = 1;

                    CTRunGetPositions(curRun, pos, &ret);

                    return ret;
                }
            }
        }
    }

    CGPoint ret;

    ret.x = 0;
    ret.y = 0;
    return ret;
}

/**
 @Status Caveat

 @Notes This call always invalidates the entire text range
*/

- (void)invalidateDisplayForCharacterRange:(NSRange)range {
    _needsLayout = TRUE;
    [_delegate layoutManagerDidInvalidateLayout:self];
}

/**
 @Status Interoperable
*/

- (void)textContainerChangedGeometry:(NSTextContainer*)container {
    NSRange range;

    range.location = 0;
    range.length = [_textStorage length];

    [self invalidateDisplayForCharacterRange:range];
}

/**
 @Status Caveat

 @Notes This call always invalidates the entire text range
*/

- (void)processEditingForTextStorage:(NSTextStorage*)textStorage
                              edited:(NSTextStorageEditActions)actions
                               range:(NSRange)editRange
                      changeInLength:(NSInteger)deltaLen
                    invalidatedRange:(NSRange)invalidRange {
    _frame.reset(nullptr);
    [self invalidateDisplayForCharacterRange:invalidRange];
}

/**
 @Status Interoperable
*/
- (void)dealloc {
    [_textContainers release];
    [_ctLines release];
    [super dealloc];
}

/**
 @Status Stub
 @Notes
*/
- (void)insertTextContainer:(NSTextContainer*)container atIndex:(NSUInteger)index {
    UNIMPLEMENTED();
}

/**
 @Status Stub
 @Notes
*/
- (void)removeTextContainerAtIndex:(NSUInteger)index {
    UNIMPLEMENTED();
}

/**
 @Status Stub
 @Notes
*/
- (void)setTextContainer:(NSTextContainer*)container forGlyphRange:(NSRange)glyphRange {
    UNIMPLEMENTED();
}

/**
 @Status Stub
 @Notes
*/
- (void)invalidateDisplayForGlyphRange:(NSRange)glyphRange {
    UNIMPLEMENTED();
}

/**
 @Status Stub
 @Notes
*/
- (void)invalidateGlyphsForCharacterRange:(NSRange)charRange
                           changeInLength:(NSInteger)delta
                     actualCharacterRange:(NSRangePointer)actualCharRange {
    UNIMPLEMENTED();
}

/**
 @Status Stub
 @Notes
*/
- (void)invalidateLayoutForCharacterRange:(NSRange)charRange actualCharacterRange:(NSRangePointer)actualCharRange {
    UNIMPLEMENTED();
}

/**
 @Status Stub
 @Notes
*/
- (void)ensureGlyphsForCharacterRange:(NSRange)charRange {
    UNIMPLEMENTED();
}

/**
 @Status Stub
 @Notes
*/
- (void)ensureGlyphsForGlyphRange:(NSRange)glyphRange {
    UNIMPLEMENTED();
}

/**
 @Status Stub
 @Notes
*/
- (void)ensureLayoutForBoundingRect:(CGRect)bounds inTextContainer:(NSTextContainer*)container {
    UNIMPLEMENTED();
}

/**
 @Status Stub
 @Notes
*/
- (void)ensureLayoutForCharacterRange:(NSRange)charRange {
    UNIMPLEMENTED();
}

/**
 @Status Stub
 @Notes
*/
- (void)ensureLayoutForGlyphRange:(NSRange)glyphRange {
    UNIMPLEMENTED();
}

/**
 @Status Stub
 @Notes
*/
- (void)ensureLayoutForTextContainer:(NSTextContainer*)container {
    UNIMPLEMENTED();
}

/**
 @Status Stub
 @Notes
*/
- (void)setGlyphs:(const CGGlyph*)glyphs
          properties:(const NSGlyphProperty*)props
    characterIndexes:(const NSUInteger*)charIndexes
                font:(UIFont*)aFont
       forGlyphRange:(NSRange)glyphRange {
    UNIMPLEMENTED();
}

/**
 @Status Stub
 @Notes
*/
- (NSUInteger)characterIndexForGlyphAtIndex:(NSUInteger)glyphIndex {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
- (NSUInteger)getGlyphsInRange:(NSRange)glyphRange
                        glyphs:(CGGlyph*)glyphBuffer
                    properties:(NSGlyphProperty*)props
              characterIndexes:(NSUInteger*)charIndexBuffer
                    bidiLevels:(unsigned char*)bidiLevelBuffer {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
- (CGGlyph)glyphAtIndex:(NSUInteger)glyphIndex {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
- (CGGlyph)glyphAtIndex:(NSUInteger)glyphIndex isValidIndex:(BOOL*)isValidIndex {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
- (NSUInteger)glyphIndexForCharacterAtIndex:(NSUInteger)charIndex {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
- (BOOL)isValidGlyphIndex:(NSUInteger)glyphIndex {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
- (NSGlyphProperty)propertyForGlyphAtIndex:(NSUInteger)glyphIndex {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
- (void)setAttachmentSize:(CGSize)attachmentSize forGlyphRange:(NSRange)glyphRange {
    UNIMPLEMENTED();
}

/**
 @Status Stub
 @Notes
*/
- (void)setDrawsOutsideLineFragment:(BOOL)flag forGlyphAtIndex:(NSUInteger)glyphIndex {
    UNIMPLEMENTED();
}

/**
 @Status Stub
 @Notes
*/
- (void)setExtraLineFragmentRect:(CGRect)fragmentRect usedRect:(CGRect)usedRect textContainer:(NSTextContainer*)container {
    UNIMPLEMENTED();
}

/**
 @Status Stub
 @Notes
*/
- (void)setLineFragmentRect:(CGRect)fragmentRect forGlyphRange:(NSRange)glyphRange usedRect:(CGRect)usedRect {
    UNIMPLEMENTED();
}

/**
 @Status Stub
 @Notes
*/
- (void)setLocation:(CGPoint)location forStartOfGlyphRange:(NSRange)glyphRange {
    UNIMPLEMENTED();
}

/**
 @Status Stub
 @Notes
*/
- (void)setNotShownAttribute:(BOOL)flag forGlyphAtIndex:(NSUInteger)glyphIndex {
    UNIMPLEMENTED();
}

/**
 @Status Stub
 @Notes
*/
- (CGSize)attachmentSizeForGlyphAtIndex:(NSUInteger)glyphIndex {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
- (BOOL)drawsOutsideLineFragmentForGlyphAtIndex:(NSUInteger)glyphIndex {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
- (NSUInteger)firstUnlaidCharacterIndex {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
- (NSUInteger)firstUnlaidGlyphIndex {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
- (void)getFirstUnlaidCharacterIndex:(NSUInteger*)charIndex glyphIndex:(NSUInteger*)glyphIndex {
    UNIMPLEMENTED();
}

/**
 @Status Stub
 @Notes
*/
- (BOOL)notShownAttributeForGlyphAtIndex:(NSUInteger)glyphIndex {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
- (NSRange)truncatedGlyphRangeInLineFragmentForGlyphAtIndex:(NSUInteger)glyphIndex {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
- (NSUInteger)characterIndexForPoint:(CGPoint)point
                             inTextContainer:(NSTextContainer*)container
    fractionOfDistanceBetweenInsertionPoints:(CGFloat*)partialFraction {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
- (void)enumerateEnclosingRectsForGlyphRange:(NSRange)glyphRange
                    withinSelectedGlyphRange:(NSRange)selectedRange
                             inTextContainer:(NSTextContainer*)textContainer
                                  usingBlock:(void (^)(CGRect, BOOL*))block {
    UNIMPLEMENTED();
}

/**
 @Status Stub
 @Notes
*/
- (void)enumerateLineFragmentsForGlyphRange:(NSRange)glyphRange
                                 usingBlock:(void (^)(CGRect, CGRect, NSTextContainer*, NSRange, BOOL*))block {
    UNIMPLEMENTED();
}

/**
 @Status Stub
 @Notes
*/
- (CGFloat)fractionOfDistanceThroughGlyphForPoint:(CGPoint)point inTextContainer:(NSTextContainer*)container {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
- (NSUInteger)getLineFragmentInsertionPointsForCharacterAtIndex:(NSUInteger)charIndex
                                             alternatePositions:(BOOL)aFlag
                                                 inDisplayOrder:(BOOL)dFlag
                                                      positions:(CGFloat*)positions
                                               characterIndexes:(NSUInteger*)charIndexes {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
- (NSUInteger)glyphIndexForPoint:(CGPoint)point inTextContainer:(NSTextContainer*)container {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
- (NSRange)glyphRangeForBoundingRect:(CGRect)bounds inTextContainer:(NSTextContainer*)container {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
- (NSRange)glyphRangeForBoundingRectWithoutAdditionalLayout:(CGRect)bounds inTextContainer:(NSTextContainer*)container {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
- (NSRange)glyphRangeForTextContainer:(NSTextContainer*)container {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
- (NSRange)rangeOfNominallySpacedGlyphsContainingIndex:(NSUInteger)glyphIndex {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Stub
 @Notes
*/
- (void)drawStrikethroughForGlyphRange:(NSRange)glyphRange
                     strikethroughType:(NSUnderlineStyle)strikethroughVal
                        baselineOffset:(CGFloat)baselineOffset
                      lineFragmentRect:(CGRect)lineRect
                lineFragmentGlyphRange:(NSRange)lineGlyphRange
                       containerOrigin:(CGPoint)containerOrigin {
    UNIMPLEMENTED();
}

/**
 @Status Stub
 @Notes
*/
- (void)drawUnderlineForGlyphRange:(NSRange)glyphRange
                     underlineType:(NSUnderlineStyle)underlineVal
                    baselineOffset:(CGFloat)baselineOffset
                  lineFragmentRect:(CGRect)lineRect
            lineFragmentGlyphRange:(NSRange)lineGlyphRange
                   containerOrigin:(CGPoint)containerOrigin {
    UNIMPLEMENTED();
}

/**
 @Status Stub
 @Notes
*/
- (void)fillBackgroundRectArray:(const CGRect*)rectArray
                          count:(NSUInteger)rectCount
              forCharacterRange:(NSRange)charRange
                          color:(UIColor*)color {
    UNIMPLEMENTED();
}

/**
 @Status Stub
 @Notes
*/
- (void)showCGGlyphs:(const CGGlyph*)glyphs
           positions:(const CGPoint*)positions
               count:(NSUInteger)glyphCount
                font:(UIFont*)font
              matrix:(CGAffineTransform)textMatrix
          attributes:(NSDictionary*)attributes
           inContext:(CGContextRef)graphicsContext {
    UNIMPLEMENTED();
}

/**
 @Status Stub
 @Notes
*/
- (void)strikethroughGlyphRange:(NSRange)glyphRange
              strikethroughType:(NSUnderlineStyle)strikethroughVal
               lineFragmentRect:(CGRect)lineRect
         lineFragmentGlyphRange:(NSRange)lineGlyphRange
                containerOrigin:(CGPoint)containerOrigin {
    UNIMPLEMENTED();
}

/**
 @Status Stub
 @Notes
*/
- (void)underlineGlyphRange:(NSRange)glyphRange
              underlineType:(NSUnderlineStyle)underlineVal
           lineFragmentRect:(CGRect)lineRect
     lineFragmentGlyphRange:(NSRange)lineGlyphRange
            containerOrigin:(CGPoint)containerOrigin {
    UNIMPLEMENTED();
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
- (CGRect)lineFragmentUsedRectForGlyphAtIndex:(NSUInteger)glyphIndex effectiveRange:(NSRangePointer)effectiveGlyphRange {
    UNIMPLEMENTED();
    return StubReturn();
}

@end
