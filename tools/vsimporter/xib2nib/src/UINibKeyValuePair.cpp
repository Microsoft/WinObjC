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

#include <assert.h>
#include "UIProxyObject.h"
#include "UINibKeyValuePair.h"
#include "XIBObjectValue.h"
#include "XIBObject.h"

UINibKeyValuePair::UINibKeyValuePair() {
}

void UINibKeyValuePair::InitFromXIB(XIBObject* obj) {
    ObjectConverter::InitFromXIB(obj);
    // not interested much in outdated xcode
}

void UINibKeyValuePair::InitFromStory(XIBObject* obj) {
    ObjectConverter::InitFromStory(obj);

    _className = "UINibKeyValuePair";
    _outputClassName = "UINibKeyValuePair";

    _keyPath = getAttrAndHandle("keyPath");
    const char* type = getAttrAndHandle("type");
    _source = _parent->_parent;
    if (!type ) {
        assert(0); // shall not happen
    } else if (strcmp(type , "boolean") == 0) {
        const char* str = getAttrAndHandle("value");
        _value = new XIBObjectNumber(strcmp(str, "YES") == 0);
    } else if (strcmp(type , "string") == 0) {
        const char* str = getAttrAndHandle("value");
        _value =  new XIBObjectString(str);
    } else if (strcmp(type , "number") == 0) {
        XIBObject *obj = FindMemberAndHandle("value");
        const char *str = obj->getAttrAndHandle("value");
        if (strcmp(obj->_node.name(), "integer") == 0) {
            _value = new XIBObjectNumber(strtoll(str, NULL, 0));
        } else if (strcmp(obj->_node.name(), "real") == 0) {
            _value = new XIBObjectNumber(strtod(str, NULL));
        } else if (strcmp(obj->_node.name(), "float") == 0) {
            _value = new XIBObjectNumber(strtof(str, NULL));
        } else if (strcmp(obj->_node.name(), "double") == 0) {
            _value = new XIBObjectNumber(strtod(str, NULL));
        } else {
            assert(0); // shall not happen
        }
    } else if (strcmp(type , "point") == 0) {
        XIBObject *obj= FindMemberAndHandle("value");
        if (obj) {
            UIPoint pt;
            pt.x = static_cast<float>(strtod(obj->getAttrAndHandle("x"), NULL));
            pt.y = static_cast<float>(strtod(obj->getAttrAndHandle("y"), NULL));
            _value = new XIBObjectValue<UIPoint>(pt);
        }
    } else if (strcmp(type , "size") == 0) {
        XIBObject *obj= FindMemberAndHandle("value");
        if (obj) {
            CGSize size;
            size.width = static_cast<float>(strtod(obj->getAttrAndHandle("width"), NULL));
            size.height = static_cast<float>(strtod(obj->getAttrAndHandle("height"), NULL));
            _value = new XIBObjectValue<CGSize>(size);
        }
    } else if (strcmp(type , "rect") == 0) {
        XIBObject *obj= FindMemberAndHandle("value");
        if (obj) {
            UIRect rect;
            rect.x = static_cast<float>(strtod(obj->getAttrAndHandle("x"), NULL));
            rect.y = static_cast<float>(strtod(obj->getAttrAndHandle("y"), NULL));
            rect.width = static_cast<float>(strtod(obj->getAttrAndHandle("width"), NULL));
            rect.height = static_cast<float>(strtod(obj->getAttrAndHandle("height"), NULL));
            _value = new XIBObjectValue<UIRect>(rect);
        }
    } else if (strcmp(type , "range") == 0) {
        XIBObject *obj= FindMemberAndHandle("value");
        if (obj) {
            NSRange range = {0};
            range.location = strtoll(obj->getAttrAndHandle("location"), NULL, 0);
            range.length = strtoll(obj->getAttrAndHandle("length"), NULL, 0);
            _value = new XIBObjectValue<NSRange>(range);
        }
    } else if (strcmp(type , "color") == 0) {
        _value = FindMemberAndHandle("value");
    } else if (strcmp(type , "image") == 0) {
        const char* str = getAttrAndHandle("value");
        _value =  new XIBObjectString(str);
    } else if (strcmp(type , "nil") == 0) {
        _value =  new XIBObjectNil();
    }
}

void UINibKeyValuePair::ConvertStaticMappings(NIBWriter* writer, XIBObject* obj) {
    AddOutputMember(writer, "UIObject", _source);
    AddString(writer, "UIKeyPath", _keyPath);
    AddOutputMember(writer, "UIValue", _value);
    ObjectConverter::ConvertStaticMappings(writer, obj);
}
