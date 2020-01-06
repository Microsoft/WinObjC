//******************************************************************************
//
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

#pragma once
#include "UIView.h"
#include <map>

class UIColor;
class UIFont;

// line break mode used in both UILabel and UIButton (possible other places as well)
typedef enum {
    UILineBreakModeWordWrap = 0,
    UILineBreakModeCharacterWrap,
    UILineBreakModeClip,
    UILineBreakModeHeadTruncation,
    UILineBreakModeTailTruncation,
    UILineBreakModeMiddleTruncation
} UILineBreakMode;


// helper map initialized in UILabel.cpp
extern std::map<std::string, UILineBreakMode> storyToUILineBreakMode;

class UILabel : public UIView {
private:
    CGSize _shadowOffset;
    const char* _text;
    UIColor *_textColor, *_highlightedColor;
    UIFont* _font;
    int _textAlignment;
    int _numberOfLines;
    bool _adjustsFontSizeToFit;
    float _minimumFontSize;
    float _minimumScaleFactor;
    int _baselineAdjustment;
    int _lineBreakMode;

public:
    UILabel();

    virtual void InitFromXIB(XIBObject* obj);
    virtual void InitFromStory(XIBObject* obj);
    virtual void ConvertStaticMappings(NIBWriter* writer, XIBObject* obj);
    ObjectConverter* Clone();
};
