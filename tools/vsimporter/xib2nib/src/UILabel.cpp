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

#include "UILabel.h"
#include "UIColor.h"
#include "UIFont.h"
#include <assert.h>

static void MakeMutable(struct _PropertyMapper* prop, NIBWriter* writer, XIBObject* propObj, XIBObject* obj) {
    propObj->_className = "NSMutableString";
    obj->AddOutputMember(writer, prop->nibName, propObj);
}

static void WriteLayoutWidth(struct _PropertyMapper* prop, NIBWriter* writer, XIBObject* propObj, XIBObject* obj) {
    obj->AddOutputMember(writer, "UIPreferredMaxLayoutWidth", new XIBObjectFloat(propObj->floatValue()));
}

static PropertyMapper propertyMappings[] = {
    {"IBUIShadowColor", "UIShadowColor",  NULL}, {"IBUILineBreakMode", "UILineBreakMode", NULL},
    {"preferredMaxLayoutWidth", "UIPreferredMaxLayoutWidth", WriteLayoutWidth},
};
static const int numPropertyMappings = sizeof(propertyMappings) / sizeof(PropertyMapper);

std::map<std::string, UILineBreakMode> storyToUILineBreakMode = {
    { "wordWrap", UILineBreakModeWordWrap },
    { "characterWrap", UILineBreakModeCharacterWrap },
    { "clip", UILineBreakModeClip },
    { "headTruncation", UILineBreakModeHeadTruncation },
    { "tailTruncation", UILineBreakModeTailTruncation },
    { "middleTruncation", UILineBreakModeMiddleTruncation },
};


UILabel::UILabel() {
    _text = NULL;
    _textAlignment = 0;
    _highlightedColor = NULL;
    _textColor = NULL;
    _numberOfLines = 1;
    _baselineAdjustment = 0;
    _minimumFontSize = -1.0f;
    _minimumScaleFactor = -1.0f;
    _font = NULL;

    // default line break mode is tailTrucation
    _lineBreakMode = UILineBreakModeTailTruncation;
}

void UILabel::InitFromXIB(XIBObject* obj) {
    UIView::InitFromXIB(obj);

    _shadowOffset = obj->GetSize("IBUIShadowOffset", 0, -1.0f);
    _text = obj->GetString("IBUIText", NULL);
    _textColor = (UIColor*)obj->FindMember("IBUITextColor");
    if (_textColor && _textColor->isNil())
        _textColor = NULL;
    _highlightedColor = (UIColor*)obj->FindMember("IBUIHighlightedColor");
    if (_highlightedColor && _highlightedColor->isNil())
        _highlightedColor = NULL;

    _baselineAdjustment = obj->GetInt("IBUIBaselineAdjustment", 0);

    _textAlignment = obj->GetInt("IBUITextAlignment", 0);
    _numberOfLines = obj->GetInt("IBUINumberOfLines", 1);

    // default line break mode is tailTruncation
    _lineBreakMode = obj->GetInt("IBUILineBreakMode", 4);
    _font = (UIFont*)obj->FindMember("IBUIFontDescription");
    if (!_font)
        _font = (UIFont*)obj->FindMember("IBUIFont");

    if (FindMember("IBUIMinimumFontSize")) {
        _minimumFontSize = FindMember("IBUIMinimumFontSize")->floatValue();
    } else if (FindMember("IBUIMinimumScaleFactor")) {
        _minimumScaleFactor = FindMember("IBUIMinimumScaleFactor")->floatValue();
    }

    obj->_outputClassName = "UILabel";
}

void UILabel::InitFromStory(XIBObject* obj) {
    UIView::InitFromStory(obj);

    memset(&_shadowOffset, 0, sizeof(_shadowOffset));
    _shadowOffset.height = -1.0f;
    _text = getAttrAndHandle("text");
    _textColor = (UIColor*)obj->FindMemberAndHandle("textColor");
    _font = (UIFont*)obj->FindMemberAndHandle("fontDescription");

    if (getAttrib("numberOfLines")) {
        _numberOfLines = atoi(getAttrAndHandle("numberOfLines"));
    }

    const char* lineBreakModeAttributeString = "lineBreakMode";
    const char* lineBreakModeAttributeValue = getAttrib(lineBreakModeAttributeString);
    if (lineBreakModeAttributeValue) {
        if (storyToUILineBreakMode.find(lineBreakModeAttributeValue) != storyToUILineBreakMode.end()) {
            _lineBreakMode = storyToUILineBreakMode[lineBreakModeAttributeValue];
        } else {
            printf("invalid linebreak value %s, using default (tailTruncation) \n", lineBreakModeAttributeValue);
        }
    }

    const char* textAlignmentAttributeString = "textAlignment";
    const char* textAlignmentAttributeValue = getAttrAndHandle(textAlignmentAttributeString);
    if (textAlignmentAttributeValue) {
        if (strcmp(textAlignmentAttributeValue, "left") == 0) {
            _textAlignment = 0;
            getAttrAndHandle(textAlignmentAttributeString);

        } else if (strcmp(textAlignmentAttributeValue, "center") == 0) {
            _textAlignment = 1;
            getAttrAndHandle(textAlignmentAttributeString);

        } else if (strcmp(textAlignmentAttributeValue, "right") == 0) {
            _textAlignment = 2;
            getAttrAndHandle(textAlignmentAttributeString);
        } else {
            printf("UILabel: invalid textAligment value %s, using default (left)\n", textAlignmentAttributeValue);
        }
    }

    if (getAttrib("minimumScaleFactor")) {
        _minimumScaleFactor = strtod(getAttrAndHandle("minimumScaleFactor"), NULL);
    } else if (getAttrib("minimumFontSize")) {
        _minimumFontSize = strtod(getAttrAndHandle("minimumFontSize"), NULL);
    }

    obj->_outputClassName = "UILabel";
}

void UILabel::ConvertStaticMappings(NIBWriter* writer, XIBObject* obj) {
    if (_shadowOffset.width != 0.0 || _shadowOffset.height != 0.0) {
        obj->AddSize(writer, "UIShadowOffset", _shadowOffset);
    }

    if (_text) {
        obj->AddString(writer, "UIText", _text);
    }

    if (_textColor) {
        obj->AddOutputMember(writer, "UITextColor", _textColor);
    } else {
        UIColor* color = new UIColor(4, 4, 0.0f, 0.0f, 0.0f, 1.0f, "whiteColor");
        obj->AddOutputMember(writer, "UITextColor", color->CreateObject(writer));
    }

    if (_highlightedColor) {
        obj->AddOutputMember(writer, "UIHighlightedColor", _highlightedColor);
    }

    if (_textAlignment != 0) {
        AddInt(writer, "UITextAlignment", _textAlignment);
    }

    if (_numberOfLines != 1) {
        AddInt(writer, "UINumberOfLines", _numberOfLines);
    }

    if (_lineBreakMode != UILineBreakModeTailTruncation) {
        AddInt(writer, "UILineBreakMode", _lineBreakMode);
    }

    if (_baselineAdjustment != 0) {
        AddInt(writer, "UIBaselineAdjustment", _baselineAdjustment);
    }

    if (_minimumFontSize != -1.0f) {
        AddBool(writer, "UIAdjustsFontSizeToFit", true);
        AddOutputMember(writer, "UIMinimumFontSize", new XIBObjectFloat(_minimumFontSize));
    } else if (_minimumScaleFactor != -1.0f) {
        AddBool(writer, "UIAdjustsFontSizeToFit", true);
        AddOutputMember(writer, "UIMinimumScaleFactor", new XIBObjectFloat(_minimumScaleFactor));
    } else {
        AddBool(writer, "UIAdjustsFontSizeToFit", false);
    }

    if (_font) {
        AddOutputMember(writer, "UIFont", _font);
    }

    Map(writer, obj, propertyMappings, numPropertyMappings);
    UIView::ConvertStaticMappings(writer, obj);
}

ObjectConverter* UILabel::Clone() {
    return new UILabel();
}
