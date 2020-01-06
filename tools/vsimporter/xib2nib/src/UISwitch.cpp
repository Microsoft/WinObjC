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

#include "UISwitch.h"
#include <assert.h>

UISwitch::UISwitch() {
    _on = false;
}

void UISwitch::InitFromXIB(XIBObject* obj) {
    UIControl::InitFromXIB(obj);

    _outputClassName = "UISwitch";
}

void UISwitch::InitFromStory(XIBObject* obj) {
    UIControl::InitFromStory(obj);

    const char* attr;
    if ((attr = obj->getAttrAndHandle("on"))) {
        if (strcmp(attr, "YES") == 0)
            _on = true;
    }

    _outputClassName = "UISwitch";
}

void UISwitch::ConvertStaticMappings(NIBWriter* writer, XIBObject* obj) {
    if (_on)
        AddBool(writer, "UISwitchOn", _on);
    
    if (_enabled)
        AddBool(writer, "UISwitchEnabled", _enabled);
    else
        AddBool(writer, "UIDisabled", true);
    
    if (_selected)
        AddBool(writer, "UISelected", _selected);

    if (_highlighted)
        AddBool(writer, "UIHighlighted", _selected);

    UIControl::ConvertStaticMappings(writer, obj);
}

