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

#import <CoreText/CTFramesetter.h>
#import <StubReturn.h>
#import <algorithm>
#import "CoreTextInternal.h"
#import "CGPathInternal.h"
#import <CFCppBase.h>
#import "DWriteWrapper_CoreText.h"

struct __CTFramesetter : CoreFoundation::CppBase<__CTFramesetter> {
    __CTFramesetter(CTTypesetterRef typesetter) : _typesetter(typesetter) {
    }

    inline CTTypesetterRef Typesetter() const {
        return _typesetter;
    }

private:
    woc::StrongCF<CTTypesetterRef> _typesetter;
};

/**
 @Status Interoperable
*/
CTFramesetterRef CTFramesetterCreateWithAttributedString(CFAttributedStringRef string) {
    auto typesetter = woc::MakeStrongCF<CTTypesetterRef>(CTTypesetterCreateWithAttributedString(string));
    return __CTFramesetter::CreateInstance(kCFAllocatorDefault, typesetter);
}

/**
 @Status Caveat
 @Notes frameAttributes parameter ignored
*/
CTFrameRef CTFramesetterCreateFrame(CTFramesetterRef framesetter, CFRange range, CGPathRef path, CFDictionaryRef frameAttributes) {
    RETURN_NULL_IF(!framesetter || !path);

    CGRect frameRect = CGPathGetBoundingBox(path);

    // Call _DWriteWrapper to get _CTLine object list that makes up this frame
    CFAttributedStringRef attributedString = _CTTypesetterGetAttributedString(framesetter->Typesetter());
    if (range.length == 0L) {
        range.length = CFAttributedStringGetLength(attributedString) - range.location;
    }

    woc::StrongCF<__CTFrame*> ret;
    ret = const_cast<__CTFrame*>(_DWriteGetFrame(attributedString, range, frameRect));
    ret->_path = path;
    ret->_frameRect.origin = frameRect.origin;

    // Trying to access attributes without any text will throw an error
    if (range.length <= 0L) {
        return static_cast<CTFrameRef>(ret.detach());
    }

    CTParagraphStyleRef settings = static_cast<CTParagraphStyleRef>(
        CFAttributedStringGetAttribute(attributedString, range.location, kCTParagraphStyleAttributeName, nullptr));

    if (settings == nullptr) {
        return static_cast<CTFrameRef>(ret.detach());
    }

    // DWrite only gives manual control of lineheight when it is constant through a frame
    // We need to shift each line by the difference in lineheight manually
    CGFloat lineHeightMultiple = 0.0f;
    if (CTParagraphStyleGetValueForSpecifier(settings,
                                             kCTParagraphStyleSpecifierLineHeightMultiple,
                                             sizeof(lineHeightMultiple),
                                             &lineHeightMultiple) &&
        lineHeightMultiple > 0) {
        // The actual ratio we need to change the line height by is lineHeightMultiple - 1
        lineHeightMultiple -= 1.0f;
        CGFloat totalShifted = 0.0f;
        CGFloat lastOriginY = frameRect.origin.y;
        for (size_t i = 0; i < ret->_lineOrigins.size(); ++i) {
            totalShifted += lineHeightMultiple * (ret->_lineOrigins[i].y - lastOriginY);
            lastOriginY = ret->_lineOrigins[i].y;
            ret->_lineOrigins[i].y += totalShifted;
        }

        // Adjust framesize to account for changes in lineheights
        ret->_frameRect.size.height += totalShifted;
    }

    // CoreText binds the origin of each line to the left for clipped lines no matter the writing direction / alignment
    // TODO 1121:: DWrite does not support line breaking by truncation, so we are using clipping, so need to adjust for truncation as well
    CTLineBreakMode lineBreakMode;
    if (CTParagraphStyleGetValueForSpecifier(settings, kCTParagraphStyleSpecifierLineBreakMode, sizeof(lineBreakMode), &lineBreakMode) &&
        (lineBreakMode == kCTLineBreakByClipping || lineBreakMode == kCTLineBreakByTruncatingHead ||
         lineBreakMode == kCTLineBreakByTruncatingTail || lineBreakMode == kCTLineBreakByTruncatingMiddle)) {
        for (size_t i = 0; i < ret->_lineOrigins.size(); ++i) {
            CTLineRef line = static_cast<CTLineRef>(CFArrayGetValueAtIndex(ret->_lines, i));
            if (line->_width > frameRect.size.width) {
                ret->_lineOrigins[i].x -= line->_relativeXOffset;
            }
        }
    }

    return static_cast<CTFrameRef>(ret.detach());
}

/**
 @Status Interoperable
*/
CTTypesetterRef CTFramesetterGetTypesetter(CTFramesetterRef framesetter) {
    RETURN_NULL_IF(!framesetter);
    return framesetter->Typesetter();
}

/**
 @Status Caveat
 @Notes frameAttributes parameter ignored
*/
CGSize CTFramesetterSuggestFrameSizeWithConstraints(
    CTFramesetterRef framesetter, CFRange stringRange, CFDictionaryRef frameAttributes, CGSize constraints, CFRange* fitRange) {
    RETURN_RESULT_IF_NULL(framesetter, CGSizeZero);
    return _DWriteGetFrameSize(_CTTypesetterGetAttributedString(framesetter->Typesetter()), stringRange, constraints, fitRange);
}

/**
 @Status Interoperable
*/
CFTypeID CTFramesetterGetTypeID() {
    return __CTFramesetter::GetTypeID();
}
