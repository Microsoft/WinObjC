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

#include "UITextField.h"
#include "UIColor.h"
#include "UIFont.h"
#include "UITextInputTraits.h"

static void MakeMutable(struct _PropertyMapper* prop, NIBWriter* writer, XIBObject* propObj, XIBObject* obj) {
    propObj->_className = "NSMutableString";
    obj->AddOutputMember(writer, prop->nibName, propObj);
}

static void WriteMinimumFontSize(struct _PropertyMapper* prop, NIBWriter* writer, XIBObject* propObj, XIBObject* obj) {
    obj->AddOutputMember(writer, "UIAdjustsFontSizeToFit", new XIBObjectBool(true));
    obj->AddOutputMember(writer, prop->nibName, propObj);
}

static void WriteLayoutWidth(struct _PropertyMapper* prop, NIBWriter* writer, XIBObject* propObj, XIBObject* obj) {
    obj->AddOutputMember(writer, "UIPreferredMaxLayoutWidth", new XIBObjectFloat(propObj->floatValue()));
}

static PropertyMapper propertyMappings[] = {
    {"IBUIHighlightedColor", "UIHighlightedColor", NULL},
    {"IBUIShadowColor", "UIShadowColor", NULL},
    {"IBUIBaselineAdjustment", "UIBaselineAdjustment", NULL},
    {"IBUIMinimumFontSize", "UIMinimumFontSize", WriteMinimumFontSize},
    {"IBUINumberOfLines", "UINumberOfLines", NULL},
    {"IBUITextAlignment", "UITextAlignment", NULL},
    {"IBUILineBreakMode", "UILineBreakMode", NULL},
    {"preferredMaxLayoutWidth", "UIPreferredMaxLayoutWidth", WriteLayoutWidth},
};
static const int numPropertyMappings = sizeof(propertyMappings) / sizeof(PropertyMapper);

UITextField::UITextField() {
    _shadowOffset.width = 0;
    _shadowOffset.height = -1;
    _text = NULL;
    _textColor = NULL;
    _placeholder = NULL;
    _borderStyle = 0;
    _font = NULL;
    _textInputTraits = NULL;
    _clearsOnBeginEditing = false;
    _clearButtonOffset.width = 0.0f;
    _clearButtonOffset.height = 0.0f;
}

void UITextField::InitFromXIB(XIBObject* obj) {
    UIControl::InitFromXIB(obj);

    _shadowOffset = obj->GetSize("IBUIShadowOffset", 0.0, 0.0f);
    _text = obj->GetString("IBUIText", NULL);
    _textColor = obj->FindMember("IBUITextColor");
    _placeholder = obj->GetString("IBUIPlaceholder", NULL);
    _borderStyle = obj->GetInt("IBUIBorderStyle", 0);
    _font = (UIFont*)obj->FindMember("IBUIFontDescription");
    if (!_font) {
        _font = (UIFont*)obj->FindMember("IBUIFont");
    }

    _clearsOnBeginEditing = obj->GetBool("IBUIClearsOnBeginEditing", false);
    if (_clearsOnBeginEditing) {
        _clearButtonOffset.width = 3.0f;
        _clearButtonOffset.height = 1.0f;
    }
    obj->_outputClassName = "UITextField";
}

void UITextField::InitFromStory(XIBObject* obj) {
    UIControl::InitFromStory(obj);

    _font = (UIFont*)obj->FindMemberAndHandle("fontDescription");
    _textInputTraits = (UITextInputTraits*)obj->FindMemberAndHandle("textInputTraits");
    // This is default if borderStyle isn't present
    _borderStyle = 0;
    const char* borderStyle = obj->getAttrAndHandle("borderStyle");

    if (borderStyle) {
        // BorderStyle does present, filling in corresponding value
        if (strcmp(borderStyle, "roundedRect") == 0) {
            _borderStyle = 3;
        } else if (strcmp(borderStyle, "bezel") == 0) {
            _borderStyle = 2;
        } else if (strcmp(borderStyle, "line") == 0) {
            _borderStyle = 1;
        } else {
            // Invalid border style, default to 0
            printf("Unknown textField border style %s\n", borderStyle);
        }
    }

    obj->_outputClassName = "UITextField";
}

void UITextField::ConvertStaticMappings(NIBWriter* writer, XIBObject* obj) {
    if (_shadowOffset.width != 0.0 || _shadowOffset.height != 0.0) {
        obj->AddSize(writer, "UIShadowOffset", _shadowOffset);
    }

    if (_text) {
        obj->AddString(writer, "UIText", _text);
    }

    if (_placeholder) {
        obj->AddString(writer, "UIPlaceholder", _placeholder);
    }

    if (_borderStyle != 0) {
        obj->AddInt(writer, "UIBorderStyle", _borderStyle);
    }

    if (_font) {
        AddOutputMember(writer, "UIFont", _font);
    }

    if (_textColor && !_textColor->isNil()) {
        obj->AddOutputMember(writer, "UITextColor", _textColor);
    } else {
        UIColor* color = new UIColor(4, 4, 0.0f, 0.0f, 0.0f, 1.0f, "whiteColor");
        obj->AddOutputMember(writer, "UITextColor", color->CreateObject(writer));
    }

    if (_textInputTraits) {
        _textInputTraits->ConvertStaticMappings(writer, this);
    }

    if (_clearsOnBeginEditing) {
        AddBool(writer, "UIClearsOnBeginEditing", _clearsOnBeginEditing);
    }

    if (_clearButtonOffset.width != 0.0f || _clearButtonOffset.height != 0.0f) {
        AddSize(writer, "UIClearButtonOffset", _clearButtonOffset);
    }

    AddOutputMember(writer, "UIMinimumScaleFactor", new XIBObjectFloat(1.0f));

    Map(writer, obj, propertyMappings, numPropertyMappings);
    UIControl::ConvertStaticMappings(writer, obj);
}
