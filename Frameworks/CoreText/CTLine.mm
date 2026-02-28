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

#import <CoreText/CTLine.h>
#import <StubReturn.h>
#import "CoreTextInternal.h"
#import "CGContextInternal.h"
#import "DWriteWrapper_CoreText.h"
#import <CoreText/CTTypesetter.h>
#import <CoreFoundation/CFString.h>

#import <memory>
#import <algorithm>
#import <numeric>
#import <cwchar>
#import <vector>

// Adds the characters and attributes of a given attributed string to the end of the receiver.
static inline void __CFAttributedStringAppendAttributedString(CFMutableAttributedStringRef attrString, CFAttributedStringRef appendString) {
    CFRange replaceRange = { CFAttributedStringGetLength(attrString), 0 };
    CFAttributedStringReplaceAttributedString(attrString, replaceRange, appendString);
}

// Inserts the characters and attribute of the given string into the receiver at the given index.
static inline void __CFAttributedStringInsertAttributedStringOneAttribute(CFMutableAttributedStringRef attrString,
                                                                          CFIndex index,
                                                                          CFStringRef string,
                                                                          CFDictionaryRef attribs) {
    CFRange replaceRange = { index, 0 };

    CFAttributedStringReplaceString(attrString, replaceRange, string);
    CFAttributedStringSetAttributes(attrString, { index, CFStringGetLength(string) }, attribs, true);
}

// Adds the characters and attribute of a given string to the end of the receiver.
static inline void __CFAttributedStringAppendAttributedStringOneAttribute(CFMutableAttributedStringRef attrString,
                                                                          CFStringRef string,
                                                                          CFDictionaryRef attribs) {
    __CFAttributedStringInsertAttributedStringOneAttribute(attrString, CFAttributedStringGetLength(attrString), string, attribs);
}

static CFStringRef __CTCreateReversedString(CFStringRef string) {
    RETURN_RESULT_IF_NULL(string, nullptr);

    CFIndex length = CFStringGetLength(string);
    RETURN_RESULT_IF((length < 2), CFStringCreateCopy(kCFAllocatorDefault, string));

    CFIndex usedBufLen;
    CFStringGetBytes(string, CFRangeMake(0, length), kCFStringEncodingUTF16, 0, false, nullptr, length, &usedBufLen);

    CFIndex bufLen = (usedBufLen / sizeof(UniChar));
    std::unique_ptr<UniChar[]> characters(new UniChar[bufLen + 1]);
    characters[bufLen] = L'\0';

    CFStringGetBytes(
        string, CFRangeMake(0, length), kCFStringEncodingUTF16, 0, false, reinterpret_cast<UInt8*>(characters.get()), usedBufLen, nullptr);

    wchar_t* result = _wcsrev(reinterpret_cast<wchar_t*>(characters.get()));
    if (result == nullptr) {
        return nullptr;
    }

    return CFStringCreateWithCharactersNoCopy(kCFAllocatorDefault, characters.release(), bufLen, nullptr);
}

CTLineRef _CTLineCreate() {
    return __CTLine::CreateInstance(kCFAllocatorDefault);
}

static CFMutableAttributedStringRef __CTLineGetTruncatedStringFromSourceLine(CTLineRef sourceLine,
                                                                             CTLineTruncationType truncationType,
                                                                             double widthToExtract) {
    CFArrayRef glyphRuns = CTLineGetGlyphRuns(sourceLine);
    CFIndex numberOfRuns = CFArrayGetCount(glyphRuns);
    double extractedWidth = 0;
    bool done = false;

    CFMutableAttributedStringRef ret = CFAttributedStringCreateMutable(kCFAllocatorDefault, 0);

    for (int i = 0; i < numberOfRuns; ++i) {
        int runIndex;
        if (truncationType == kCTLineTruncationStart) {
            runIndex = numberOfRuns - i - 1;
        } else if (truncationType == kCTLineTruncationEnd) {
            runIndex = i;
        }

        CTRunRef run = static_cast<CTRunRef>(CFArrayGetValueAtIndex(glyphRuns, runIndex));
        auto runString = woc::MakeStrongCF<CFMutableStringRef>(CFStringCreateMutable(kCFAllocatorDefault, 0));

        int numberOfGlyphs = run->_dwriteGlyphRun.glyphCount;
        for (int j = 0; j < numberOfGlyphs; ++j) {
            int glyphIndex;
            if (truncationType == kCTLineTruncationStart) {
                glyphIndex = numberOfGlyphs - j - 1;
            } else if (truncationType == kCTLineTruncationEnd) {
                glyphIndex = j;
            }

            if (extractedWidth + run->_dwriteGlyphRun.glyphAdvances[glyphIndex] > widthToExtract) {
                done = true;
                break;
            }

            extractedWidth += run->_dwriteGlyphRun.glyphAdvances[glyphIndex];
            char glyph = CFStringGetCharacterAtIndex(run->_stringFragment, glyphIndex);
            CFStringAppendFormat(runString, nullptr, CFSTR("%c"), glyph);
        }

        CFDictionaryRef attribs = CTRunGetAttributes(run);

        if (truncationType == kCTLineTruncationStart) {
            auto reverse = woc::MakeStrongCF<CFStringRef>(__CTCreateReversedString(runString));
            __CFAttributedStringInsertAttributedStringOneAttribute(ret, 0, reverse, attribs);
        } else if (truncationType == kCTLineTruncationEnd) {
            __CFAttributedStringAppendAttributedStringOneAttribute(ret, runString, attribs);
        }
        if (done) {
            break;
        }
    }

    CFAutorelease(ret);
    return ret;
}

/**
 @Status Interoperable
*/
CTLineRef CTLineCreateWithAttributedString(CFAttributedStringRef string) {
    RETURN_NULL_IF(!string);
    return _DWriteCreateLine(string);
}

/**
 @Status Interoperable
*/
CTLineRef CTLineCreateTruncatedLine(CTLineRef sourceLine, double width, CTLineTruncationType truncationType, CTLineRef truncationToken) {
    RETURN_NULL_IF(!sourceLine);

    // get the truncationToken width, use it to calculate the exact width that should be extracted from the sourceLine.
    CGFloat truncationTokenWidth;
    if (truncationToken == nullptr) {
        truncationTokenWidth = 0.0f;
    } else {
        truncationTokenWidth = truncationToken->_width;
    }

    RETURN_NULL_IF(width <= 0 || truncationTokenWidth > width);

    CGFloat sourceLineWidth = sourceLine->_width;
    if (width >= sourceLineWidth || sourceLineWidth == truncationTokenWidth) {
        // return a copy of sourceLine
        return __CTLine::CreateInstance(kCFAllocatorDefault, *sourceLine);
    }

    // widthToExtract is the width that will be extracted from the sourceLine and merged with truncationToken finally
    double widthToExtract;
    if (truncationToken == nullptr) {
        widthToExtract = width;
    } else {
        widthToExtract = width - truncationTokenWidth;
    }

    // get an CFMutableAttributedString string from truncationToken by looping across its runs and extracting the run attribuets.
    auto stringFromToken = woc::MakeStrongCF<CFMutableAttributedStringRef>(CFAttributedStringCreateMutable(kCFAllocatorDefault, 0));
    CFArrayRef tokenRuns = CTLineGetGlyphRuns(truncationToken);
    if (tokenRuns != nullptr) {
        CFIndex numberOfRuns = CFArrayGetCount(tokenRuns);
        for (int i = 0; i < numberOfRuns; ++i) {
            CTRunRef run = static_cast<CTRunRef>(CFArrayGetValueAtIndex(tokenRuns, i));
            CFDictionaryRef attribs = CTRunGetAttributes(run);
            __CFAttributedStringAppendAttributedStringOneAttribute(stringFromToken, run->_stringFragment, attribs);
        }
    }

    CFMutableAttributedStringRef finalString = nullptr;
    CFMutableAttributedStringRef truncatedStringFromLeft = nullptr;
    CFMutableAttributedStringRef truncatedStringFromRight = nullptr;

    switch (truncationType) {
        case kCTLineTruncationStart:
            truncatedStringFromRight = __CTLineGetTruncatedStringFromSourceLine(sourceLine, kCTLineTruncationStart, widthToExtract);
            __CFAttributedStringAppendAttributedString(stringFromToken, truncatedStringFromRight);
            finalString = stringFromToken;

            break;
        case kCTLineTruncationMiddle:
            widthToExtract = widthToExtract / 2;
            truncatedStringFromLeft = __CTLineGetTruncatedStringFromSourceLine(sourceLine, kCTLineTruncationEnd, widthToExtract);
            truncatedStringFromRight = __CTLineGetTruncatedStringFromSourceLine(sourceLine, kCTLineTruncationStart, widthToExtract);
            __CFAttributedStringAppendAttributedString(truncatedStringFromLeft, stringFromToken);
            __CFAttributedStringAppendAttributedString(truncatedStringFromLeft, truncatedStringFromRight);
            finalString = truncatedStringFromLeft;

            break;
        case kCTLineTruncationEnd:
            truncatedStringFromLeft = __CTLineGetTruncatedStringFromSourceLine(sourceLine, kCTLineTruncationEnd, widthToExtract);
            __CFAttributedStringAppendAttributedString(truncatedStringFromLeft, stringFromToken);
            finalString = truncatedStringFromLeft;

            break;
        default:
            return nullptr;
    }
    return CTLineCreateWithAttributedString(static_cast<CFAttributedStringRef>(finalString));
}

/**
 @Status NotInPlan
 @Notes This would be hard to get right for justfication factors (0, 1).
*/

CTLineRef CTLineCreateJustifiedLine(CTLineRef line, CGFloat justificationFactor, double justificationWidth) {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Interoperable
*/
void CTLineDraw(CTLineRef line, CGContextRef ctx) {
    RETURN_IF(!line || !ctx);

    std::vector<GlyphRunData> runs;

    // Translate by the inverse of the relativeXOffset to draw at the text position
    CGPoint relativePosition = { -line->_relativeXOffset, 0 };
    CFIndex count = CFArrayGetCount(line->_runs);
    for (CFIndex i = 0; i < count; ++i) {
        __CTRun* curRun = static_cast<__CTRun*>(const_cast<void*>(CFArrayGetValueAtIndex(line->_runs, i)));
        // Adjusts x position relative to the last run drawn
        relativePosition.x += curRun->_relativeXOffset;
        runs.emplace_back(GlyphRunData{ &curRun->_dwriteGlyphRun, relativePosition, curRun->_attributes });
    }

    if (!runs.empty()) {
        _CGContextPushBeginDraw(ctx);
        auto popEnd = wil::ScopeExit([ctx]() { _CGContextPopEndDraw(ctx); });
        _CGContextDrawGlyphRuns(ctx, runs.data(), runs.size());
    }
}

/**
 @Status Interoperable
*/
CFIndex CTLineGetGlyphCount(CTLineRef line) {
    RETURN_RESULT_IF_NULL(line, 0);
    return line->_glyphCount;
}

/**
 @Status Interoperable
*/
CFArrayRef CTLineGetGlyphRuns(CTLineRef line) {
    RETURN_NULL_IF(!line);
    return line->_runs;
}

/**
 @Status Interoperable
*/
CFRange CTLineGetStringRange(CTLineRef line) {
    RETURN_RESULT_IF_NULL(line, CFRangeMake(0, 0));
    return line->_strRange;
}

/**
 @Status Caveat
 @Notes Returns 0.0
*/
double CTLineGetPenOffsetForFlush(CTLineRef line, CGFloat flushFactor, double flushWidth) {
    UNIMPLEMENTED();
    return 0.0;
}

/**
 @Status Interoperable
*/
CGRect CTLineGetImageBounds(CTLineRef line, CGContextRef context) {
    RETURN_RESULT_IF((!line || !context), CGRectNull);

    CGFloat ascent, descent;
    double width = CTLineGetTypographicBounds(line, &ascent, &descent, nullptr);
    return { CGContextGetTextPosition(context), { width, ascent - descent } };
}

double __CTLine::GetTypographicBounds(CGFloat* ascent, CGFloat* descent, CGFloat* leading) const {
    RETURN_RESULT_IF((CFArrayGetCount(_runs) == 0), 0);

    // Created with impossible values -FLT_MAX which signify they need to be populated
    if ((_ascent == -FLT_MAX || _descent == -FLT_MAX || _leading == -FLT_MAX) && (ascent || descent || leading)) {
        CFIndex count = CFArrayGetCount(_runs);
        for (CFIndex i = 0; i < count; ++i) {
            CTRunRef run = static_cast<CTRunRef>(CFArrayGetValueAtIndex(_runs, i));
            CGFloat newAscent, newDescent, newLeading;
            CTRunGetTypographicBounds(run, { 0, 0 }, &newAscent, &newDescent, &newLeading);
            _ascent = std::max(_ascent, newAscent);
            _descent = std::max(_descent, newDescent);
            _leading = std::max(_leading, newLeading);
        }
    }

    if (ascent) {
        *ascent = _ascent;
    }
    if (descent) {
        *descent = _descent;
    }
    if (leading) {
        *leading = _leading;
    }

    return _width;
}

/**
 @Status Interoperable
*/
double CTLineGetTypographicBounds(CTLineRef line, CGFloat* ascent, CGFloat* descent, CGFloat* leading) {
    RETURN_RESULT_IF((!line), 0);
    return line->GetTypographicBounds(ascent, descent, leading);
}

/**
 @Status Stub
 @Notes
*/
double CTLineGetTrailingWhitespaceWidth(CTLineRef line) {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Interoperable
*/
CFIndex CTLineGetStringIndexForPosition(CTLineRef line, CGPoint position) {
    RETURN_RESULT_IF((!line || line->_glyphCount == 0), kCFNotFound);

    CGFloat curPos = 0;
    CFIndex count = CFArrayGetCount(line->_runs);
    for (CFIndex i = 0; i < count; ++i) {
        CTRunRef run = static_cast<CTRunRef>(CFArrayGetValueAtIndex(line->_runs, i));
        curPos += run->_relativeXOffset;
        CGFloat runPos = curPos;
        for (int i = 0; i < run->_dwriteGlyphRun.glyphCount; i++) {
            if (_GlyphRunIsRTL(run->_dwriteGlyphRun)) {
                if (runPos <= position.x) {
                    return run->_stringIndices[i];
                }

                runPos -= run->_dwriteGlyphRun.glyphAdvances[i];
            } else {
                runPos += run->_dwriteGlyphRun.glyphAdvances[i];
                if (runPos >= position.x) {
                    return run->_stringIndices[i];
                }
            }
        }
    }

    return line->_strRange.location + line->_strRange.length;
}

/**
 @Status Interoperable
*/
CGFloat CTLineGetOffsetForStringIndex(CTLineRef line, CFIndex charIndex, CGFloat* secondaryOffset) {
    CGFloat ret = 0.0;
    if (line && charIndex >= 0) {
        if (charIndex > line->_strRange.location + line->_strRange.length) {
            ret = line->_width;
        } else {
            CFIndex count = CFArrayGetCount(line->_runs);
            for (CFIndex i = 0; i < count; ++i) {
                CTRunRef run = static_cast<CTRunRef>(CFArrayGetValueAtIndex(line->_runs, i));
                if (run->_range.location + run->_range.length >= charIndex && run->_stringIndices.size() > 0) {
                    int index = std::upper_bound(run->_stringIndices.begin(), run->_stringIndices.end(), charIndex) -
                                run->_stringIndices.begin() - 1;

                    if (index >= 0) {
                        if (_GlyphRunIsRTL(run->_dwriteGlyphRun)) {
                            ret += std::accumulate(run->_dwriteGlyphRun.glyphAdvances,
                                                   run->_dwriteGlyphRun.glyphAdvances + index,
                                                   run->_relativeXOffset,
                                                   std::minus<CGFloat>());
                        } else {
                            ret += std::accumulate(run->_dwriteGlyphRun.glyphAdvances,
                                                   run->_dwriteGlyphRun.glyphAdvances + index,
                                                   run->_relativeXOffset);
                        }
                    }

                    break;
                }

                ret += run->_relativeXOffset;
            }
        }
    }

    if (secondaryOffset) {
        *secondaryOffset = ret;
    }
    return ret;
}

/**
 @Status NotInPlan
 @Notes This API is mostly un-documented and appears to be very low usage.
*/

CGRect CTLineGetBoundsWithOptions(CTLineRef line, CTLineBoundsOptions options) {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
 @Status Interoperable
*/
CFTypeID CTLineGetTypeID() {
    return __CTLine::GetTypeID();
}
