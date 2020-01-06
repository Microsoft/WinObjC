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

#include "UITextView.h"
#include "UIColor.h"
#include "UIFont.h"

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

UITextView::UITextView() {
    _font = NULL;
    _editable = false;
    _dataDetectorTypes = 0;
    _autoCorrectionType = 0;
    _returnKeyType = 0;
    _textAlignment = 0;
    _text = NULL;
    _textColor = NULL;
}

void UITextView::InitFromXIB(XIBObject* obj) {
    UIScrollView::InitFromXIB(obj);

    _shadowOffset = obj->GetSize("IBUIShadowOffset", 0, 0.0f);
    _text = obj->GetString("IBUIText", NULL);
    _textColor = obj->FindMember("IBUITextColor");
    _font = (UIFont*)obj->FindMember("IBUIFontDescription");
    _editable = obj->GetBool("IBUIEditable", true);
    _dataDetectorTypes = obj->GetInt("IBUIDataDetectorTypes", 0);
    if (!_font)
        _font = (UIFont*)obj->FindMember("IBUIFont");
    _textAlignment = 0;

    XIBObject* inputTraits = obj->FindMember("IBUITextInputTraits");
    if (inputTraits) {
        _autoCorrectionType = inputTraits->GetInt("IBUIAutocorrectionType", 0);
        _returnKeyType = inputTraits->GetInt("IBUIReturnKeyType", 0);
    }
    obj->_outputClassName = "UITextView";
}

void UITextView::InitFromStory(XIBObject* obj) {
    UIScrollView::InitFromStory(obj);

    //  Text must be done as an object because the string will not be initialized until
    //  InitFromStory is called on it
    XIBObject* textNode = (XIBObject*)obj->FindMemberAndHandle("text");
    if (textNode) {
        _text = strdup(textNode->_node.text().as_string());
    }
    _font = (UIFont*)obj->FindMemberAndHandle("fontDescription");

    obj->_outputClassName = "UITextView";
}

void UITextView::ConvertStaticMappings(NIBWriter* writer, XIBObject* obj) {
    if (_shadowOffset.width != 0.0 || _shadowOffset.height != 0.0)
        obj->AddSize(writer, "UIShadowOffset", _shadowOffset);
    if (_text)
        obj->AddString(writer, "UIText", _text);
    if (!_editable)
        AddBool(writer, "UIEditable", _editable);
    if (_dataDetectorTypes)
        AddInt(writer, "UIDataDetectorTypes", _dataDetectorTypes);
    if (_autoCorrectionType)
        AddInt(writer, "UIAutocorrectionType", _autoCorrectionType);
    if (_returnKeyType)
        AddInt(writer, "UIReturnKeyType", _returnKeyType);
    if (_textColor && !_textColor->isNil()) {
        obj->AddOutputMember(writer, "UITextColor", _textColor);
    } else {
        UIColor* color = new UIColor(4, 4, 0.0f, 0.0f, 0.0f, 1.0f, "whiteColor");
        obj->AddOutputMember(writer, "UITextColor", color->CreateObject(writer));
    }
    if (_font)
        obj->AddOutputMember(writer, "UIFont", _font);
    AddOutputMember(writer, "UIMinimumScaleFactor", new XIBObjectFloat(1.0f));

    CGSize size;
    size.width = getFrame().width;
    size.height = getFrame().height;
    AddSize(writer, "UIContentSize", size);

    AddInt(writer, "UITextAlignment", _textAlignment);

    if (!_subviews) {
        _subviews = new XIBArray();
        _subviews->_className = "NSMutableArray";
    }

    Map(writer, obj, propertyMappings, numPropertyMappings);
    UIScrollView::ConvertStaticMappings(writer, obj);
}
