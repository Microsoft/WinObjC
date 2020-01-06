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

#include "UIBarButtonItem.h"
#include "UIStoryboardSegue.h"
#include "UIRuntimeEventConnection.h"
#include <assert.h>

UIBarButtonItem::UIBarButtonItem() {
    _systemItem = -1;
    _style = 0;
    _customView = NULL;
    _width = -1.0f;
    _title = NULL;
}

void UIBarButtonItem::InitFromXIB(XIBObject* obj) {
    ObjectConverterSwapper::InitFromXIB(obj);

    _systemItem = obj->GetInt("IBUISystemItemIdentifier", -1);
    _style = obj->GetInt("IBUIStyle", 0);
    _title = obj->GetString("IBUITitle", NULL);
    obj->_outputClassName = "UIBarButtonItem";
}

void UIBarButtonItem::InitFromStory(XIBObject* obj) {
    ObjectConverterSwapper::InitFromStory(obj);

    _title = obj->getAttrAndHandle("title");
    _customView = (UIView*)obj->FindMemberAndHandle("customView");
    const char* pStyle = obj->getAttrAndHandle("style");
    if (pStyle) {
        if (strcmp(pStyle, "plain") == 0) {
            _style = 0;
        } else {
            assert(0);
        }
    } else
        _style = 1;
    if (getAttrib("width")) {
        _width = strtod(getAttrAndHandle("width"), NULL);
    }
    if (getAttrib("systemItem")) {
        const char* sysItem = getAttrib("systemItem");
        bool isHandled = true;

        if (strcmp(sysItem, "flexibleSpace") == 0) {
            _systemItem = (int)UIBarButtonSystemItemFlexibleSpace;
        } else if (strcmp(sysItem, "fixedSpace") == 0) {
            _systemItem = (int)UIBarButtonSystemItemFixedSpace;
        } else if (strcmp(sysItem, "compose") == 0) {
            _systemItem = (int)UIBarButtonSystemItemCompose;
        } else if (strcmp(sysItem, "camera") == 0) {
            _systemItem = (int)UIBarButtonSystemItemCamera;
        } else if (strcmp(sysItem, "add") == 0) {
            _systemItem = (int)UIBarButtonSystemItemAdd;
        } else if (strcmp(sysItem, "done") == 0) {
            _systemItem = (int)UIBarButtonSystemItemDone;
        } else {
            isHandled = false;
            printf("Unknown UIBarButton item type %s\n", sysItem);
        }

        if (isHandled) {
            getAttrAndHandle("systemItem");
        }
    }

    obj->_outputClassName = "UIBarButtonItem";
}

void UIBarButtonItem::ConvertStaticMappings(NIBWriter* writer, XIBObject* obj) {
    AddOutputMember(writer, "UIEnabled", new XIBObjectBool(true));
    if (_systemItem != -1) {
        AddInt(writer, "UISystemItem", _systemItem);
        AddBool(writer, "UIIsSystemItem", true);
    }
    if (_title)
        AddString(writer, "UITitle", _title);
    if (!_customView) {
        if (_style)
            AddInt(writer, "UIStyle", _style);
        if (_width != -1.0f) {
            AddOutputMember(writer, "UIWidth", new XIBObjectFloat(_width));
        }
    }
    if (_customView) {
        AddOutputMember(writer, "UICustomView", _customView);
    }

    ObjectConverterSwapper::ConvertStaticMappings(writer, obj);
}
