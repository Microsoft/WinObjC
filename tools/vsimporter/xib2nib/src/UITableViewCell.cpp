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

#include "UITableViewCell.h"
#include <map>


static std::map<std::string, UISelectionStyle> storyToSelectionStyle = {
    { "none", UISelectionStyleNone },
    { "blue", UISelectionStyleBlue },
    { "gray", UISelectionStyleGray },
    { "default", UISelectionStyleDefault }};

static std::map<std::string, UIAccessoryType> storyToAccessoryType = {
    { "disclosureIndicator", UIAccessoryTypeDisclosureIndicator },
    { "disclosureButton", UIAccessoryTypeDetailDisclosureButton },
    { "checkmark", UIAccessoryTypeCheckmark },
    { "detailButton", UIAccessoryTypeDetailButton }};

static std::map<std::string, UITableViewCellStyle> storyToCellStyle = {
    { "IBUITableViewCellStyleDefault", UITableViewCellStyleBasic },
    { "IBUITableViewCellStyleValue1", UITableViewCellStyleRightDetails },
    { "IBUITableViewCellStyleValue2", UITableViewCellStyleLeftDetails },
    { "IBUITableViewCellStyleSubtitle", UITableViewCellStyleSubtitle }};

UITableViewCell::UITableViewCell() {
    _indentationLevel = 0;
    _indentationWidth = 0.0f;
    _selectionStyle = UISelectionStyleDefault;
    _accessoryType = UIAccessoryTypeNone;
    _editingAccessoryType = UIAccessoryTypeNone;
    _cellStyle = UITableViewCellStyleCustom;
    _reuseIdentifier = NULL;
    _detailTextLabel = NULL;
    _imageView = NULL;
    _textLabel = NULL;
    _focusStyleCustom = false;
}

void UITableViewCell::InitFromXIB(XIBObject* obj) {
    UIView::InitFromXIB(obj);

    obj->_outputClassName = "UITableViewCell";

    _reuseIdentifier = obj->GetString("IBUIReuseIdentifier", NULL);
    _contentView = (UIView*)obj->FindMember("IBUIContentView");
    _imageView = (UIView*)new XIBObjectNil();
    _textLabel = (UIView*)new XIBObjectNil();
    _detailTextLabel = (UIView*)new XIBObjectNil();
    _selectionStyle = obj->GetInt("IBUISelectionStyle", 0);
    _indentationLevel = obj->GetInt("IBUIIndentationLevel", 0);
    if (obj->FindMember("IBUIIndentationWidth"))
        _indentationWidth = obj->FindMember("IBUIIndentationWidth")->floatValue();
}

void UITableViewCell::InitFromStory(XIBObject* obj) {
    UIView::InitFromStory(obj);

    obj->_outputClassName = "UITableViewCell";

    const char* attr;
    if ((attr = obj->getAttrAndHandle("style"))) {
        if (storyToCellStyle.find(attr) != storyToCellStyle.end()) {
            _cellStyle = storyToCellStyle[attr];
        }
    }

    if ((attr = obj->getAttrAndHandle("selectionStyle"))) {
        if (storyToSelectionStyle.find(attr) != storyToSelectionStyle.end()) {
            _selectionStyle = storyToSelectionStyle[attr];
        }
    }

    if ((attr = obj->getAttrAndHandle("editingAccessoryType"))) {
        if (storyToAccessoryType.find(attr) != storyToAccessoryType.end()) {
            _editingAccessoryType = storyToAccessoryType[attr];
        }
    }

    if ((attr = obj->getAttrAndHandle("accessoryType"))) {
        if (storyToAccessoryType.find(attr) != storyToAccessoryType.end()) {
            _accessoryType = storyToAccessoryType[attr];
        }
    }

    if ((attr = obj->getAttrAndHandle("indentationWidth"))) {
        _indentationWidth = strtof(attr, NULL);
    }

    if ((attr = obj->getAttrAndHandle("focusStyle"))) {
        if (strcmp(attr, "custom") == 0)
            _focusStyleCustom = true;
    }

    _reuseIdentifier = obj->getAttrAndHandle("reuseIdentifier");
    _contentView = (UIView*)obj->FindMemberAndHandle("contentView");
    if (_contentView)
        _subviews->AddMember(NULL, _contentView);
}

void UITableViewCell::Awaken() {
    UIView::Awaken();
    if (_contentView) {
        _contentView->_clipsToBounds = false;
        _contentView->_backgroundColor = NULL;
        _contentView->_contentMode = 0;
        _contentView->_multipleTouchEnabled = false;
    }
}

void UITableViewCell::ConvertStaticMappings(NIBWriter* writer, XIBObject* obj) {
    writer->_allUIObjects->AddMember(NULL, this);
    if (_contentView) {
        _contentView->setFrame(getFrame());
        _contentView->_opaque = true;
        int count = _contentView->_subviews->count();
        for (int i = 0; i < count; i++) {
            UIView* curObj = (UIView*)_contentView->_subviews->objectAtIndex(i);
            // curObj->_bounds.height  = _contentView->_bounds.height;
            writer->_allUIObjects->AddMember(NULL, curObj);
        }
        _contentView->_ignoreUIObject = true;
    }

    UIView::ConvertStaticMappings(writer, obj);

    if (_indentationLevel)
        obj->AddInt(writer, "UIIndentationLevel", _indentationLevel);
    if (_indentationWidth != 0.0f)
        obj->AddOutputMember(writer, "UIIndentationWidth", new XIBObjectFloat(_indentationWidth));
    if (_reuseIdentifier)
        obj->AddString(writer, "UIReuseIdentifier", _reuseIdentifier);
    if (_contentView) {
        _contentView->_outputClassName = "UITableViewCellContentView";
        obj->AddOutputMember(writer, "UIContentView", _contentView);
    }
    if (_imageView)
        obj->AddOutputMember(writer, "UIImageView", _imageView);
    if (_textLabel)
        obj->AddOutputMember(writer, "UITextLabel", _textLabel);
    if (_detailTextLabel)
        obj->AddOutputMember(writer, "UIDetailTextLabel", _detailTextLabel);

    if (_accessoryType != UIAccessoryTypeNone)
        obj->AddInt(writer, "UIAccessoryType", _accessoryType);
    if (_editingAccessoryType != UIAccessoryTypeNone)
        obj->AddInt(writer, "UIEditingAccessoryType", _editingAccessoryType);
    if (_cellStyle != UITableViewCellStyleCustom)
        obj->AddInt(writer, "UITableViewCellStyle", _cellStyle);
    if (_focusStyleCustom)
        obj->AddInt(writer, "UIFocusStyle", 1);

    obj->AddBool(writer, "UITableCellBackgroundColorSet", true);
    obj->AddInt(writer, "UISelectionStyle", _selectionStyle);
}

ObjectConverter* UITableViewCell::Clone() {
    return new UITableViewCell();
}
