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

#include "UITableView.h"
#include "UIColor.h"

static PropertyMapper propertyMappings[] = {
    {"IBUIShowsSelectionImmediatelyOnTouchBegin", "UIShowsSelectionImmediatelyOnTouchBegin", NULL},
};
static const int numPropertyMappings = sizeof(propertyMappings) / sizeof(PropertyMapper);

static void AddSize(NIBWriter* writer, XIBObject* obj, char* keyName, float width, float height) {
    struct {
        float width, height;
    } size;

    size.width = width;
    size.height = height;

    char* output = (char*)malloc(sizeof(size) + 1);
    output[0] = 6;
    memcpy(&output[1], &size, sizeof(size));

    obj->AddOutputMember(writer, keyName, new XIBObjectDataWriter(output, sizeof(size) + 1));
}

UITableView::UITableView() {
    _headerView = NULL;
    _footerView = NULL;
    _allowsSelectionDuringEditing = false;
    _separatorStyle = 0;
    _style = 0;
    _rowHeight = -1;
}

void UITableView::InitFromXIB(XIBObject* obj) {
    UIScrollView::InitFromXIB(obj);
    _allowsSelectionDuringEditing = obj->GetBool("IBUIAllowsSelectionDuringEditing", false);
    _style = obj->GetInt("IBUIStyle", 0);
    if (_style == 1) {
        _separatorStyle = 1;
        if (!_backgroundColor) {
            _backgroundColor = new UIColor("groupTableViewBackgroundColor");
        }
    }
    _separatorStyle = obj->GetInt("IBUISeparatorStyle", _separatorStyle);

    obj->_outputClassName = "UITableView";
}

void UITableView::InitFromStory(XIBObject* obj) {
    UIScrollView::InitFromStory(obj);

    _headerView = FindMemberAndHandle("tableHeaderView");
    if (_headerView) {
        _subviews->AddMember(NULL, _headerView);
    }
    _footerView = FindMemberAndHandle("tableFooterView");
    if (_footerView) {
        _subviews->AddMember(NULL, _footerView);
    }
    
    const char *attr;
    if ((attr = obj->getAttrAndHandle("rowHeight"))) {
        _rowHeight = strtof(attr, NULL);
    }

    obj->_outputClassName = "UITableView";
}

void UITableView::Awaken() {
    UIView::Awaken();
}

void UITableView::ConvertStaticMappings(NIBWriter* writer, XIBObject* obj) {
    UIScrollView::ConvertStaticMappings(writer, obj);
    Map(writer, obj, propertyMappings, numPropertyMappings);
    if (_allowsSelectionDuringEditing)
        AddBool(writer, "UIAllowsSelectionDuringEditing", _allowsSelectionDuringEditing);
    if (_separatorStyle)
        AddInt(writer, "UISeparatorStyle", _separatorStyle);
    if (_style)
        AddInt(writer, "UIStyle", _style);
    ::AddSize(writer, obj, "UIContentSize", 320, 40);
    if (_headerView)
        AddOutputMember(writer, "UITableHeaderView", _headerView);
    if (_footerView)
        AddOutputMember(writer, "UITableFooterView", _footerView);
    if (_rowHeight >= 0)
        AddOutputMember(writer, "UIRowHeight", new XIBObjectFloat(_rowHeight));
}
