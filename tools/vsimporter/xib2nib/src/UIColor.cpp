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

#include "UIColor.h"
#include <assert.h>

UIColor::UIColor() {
    _colorSpace = 0;
    _componentCount = 0;
    _r = 0;
    _g = 0;
    _b = 0;
    _a = 0;
    _systemName = NULL;
    _colorSpaceOut = colorSpaceFull;
}

UIColor::UIColor(int colorSpace, int componentCount, float r, float g, float b, float a, char* systemName) {
    _colorSpace = colorSpace;
    _componentCount = componentCount;
    _r = r;
    _g = g;
    _b = b;
    _a = a;
    _systemName = systemName;
    _colorSpaceOut = colorSpaceFull;
}

UIColor::UIColor(char* systemName) {
    _systemName = systemName;
    _colorSpaceOut = colorSpaceName;
}

void UIColor::InitFromXIB(XIBObject* obj) {
    ObjectConverter::InitFromXIB(obj);

    _outputClassName = "UIColor";
    int colorSpace = obj->GetInt("NSColorSpace", 0);
    _r = 0.0f;
    _g = 0.0f;
    _b = 0.0f;
    _a = 1.0f;

    if (obj->FindMember("NSWhite") != NULL || obj->FindMember("NSRGB") != NULL) {
        if (obj->FindMember("NSWhite") != NULL) {
            XIBObjectData* colorData = (XIBObjectData*)obj->FindMember("NSWhite");

            char szColorString[255];
            int len = colorData->base64Decode(szColorString, sizeof(szColorString) - 1);
            szColorString[len] = 0;

            sscanf(szColorString, "%f %f", &_r, &_a);
            _g = _r;
            _b = _r;
        } else {
            XIBObjectData* colorData = (XIBObjectData*)obj->FindMember("NSRGB");

            char szColorString[255];
            int len = colorData->base64Decode(szColorString, sizeof(szColorString) - 1);
            szColorString[len] = 0;

            sscanf(szColorString, "%f %f %f %f", &_r, &_g, &_b, &_a);
        }

        _componentCount = 4;
        _colorSpace = 4;
    }
    _colorSpaceOut = colorSpaceRGB;

    _systemName = obj->GetString("IBUIColorCocoaTouchKeyPath", NULL);
}

void UIColor::InitFromStory(XIBObject* obj) {
    ObjectConverter::InitFromStory(obj);

    if (getAttrib("cocoaTouchSystemColor")) {
        const char* sysColor = getAttrib("cocoaTouchSystemColor");
        bool isHandled = true;

        if (strcmp(sysColor, "lightTextColor") == 0) {
            _colorSpaceOut = colorSpaceWhite;
            _systemName = sysColor;
            _white = 1.0f;
            _a = 0.6f;
        } else if (strcmp(sysColor, "darkTextColor") == 0) {
            _colorSpaceOut = colorSpaceWhite;
            _systemName = sysColor;
            _white = 0.6f;
            _a = 0.6f;
        } else if (strcmp(sysColor, "groupTableViewBackgroundColor") == 0) {
            _colorSpaceOut = colorSpaceWhite;
            _systemName = sysColor;
            _white = 1.0f;
            _a = 0.6f;
        } else if (strcmp(sysColor, "tableCellGroupedBackgroundColor") == 0) {
            _colorSpaceOut = colorSpaceWhite;
            _systemName = sysColor;
            _white = 1.0f;
            _a = 0.6f;
        } else {
            isHandled = false;
        }

        if (isHandled) {
            getAttrAndHandle("cocoaTouchSystemColor");
        }

    } else if (getAttrib("colorSpace")) {
        const char* space = getAttrib("colorSpace");

        bool spaceIsHandled = true;

        if (strcmp(space, "custom") == 0) {
            space = getAttrAndHandle("customColorSpace");
        }

        if (strcmp(space, "calibratedWhite") == 0) {
            _colorSpaceOut = colorSpaceWhite;
            _white = strtof(getAttrAndHandle("white"), NULL);
            _a = strtof(getAttrAndHandle("alpha"), NULL);
        } else if (strcmp(space, "calibratedRGB") == 0 || strcmp(space, "deviceRGB") == 0 || strcmp(space, "adobeRGB1998") == 0 ||
                   strcmp(space, "sRGB") == 0) {
            _colorSpaceOut = colorSpaceRGB;
            _a = strtof(getAttrAndHandle("alpha"), NULL);
            _r = strtof(getAttrAndHandle("red"), NULL);
            _g = strtof(getAttrAndHandle("green"), NULL);
            _b = strtof(getAttrAndHandle("blue"), NULL);
        } else {
            spaceIsHandled = false;
        }

        if (spaceIsHandled) {
            getAttrAndHandle("colorSpace");
        }
    }

    _outputClassName = "UIColor";
}

void UIColor::ConvertStaticMappings(NIBWriter* writer, XIBObject* obj) {
    if (!_outputClassName)
        obj->_outputClassName = "UIColor";
    if (!_isStory) {
        switch (_colorSpaceOut) {
            case colorSpaceRGB:
            case colorSpaceFull:
                if (_r == _g && _r == _b) {
                    obj->AddOutputMember(writer, "UIWhite", new XIBObjectFloat(_r));
                }

                obj->AddOutputMember(writer, "UIRed", new XIBObjectFloat(_r));
                obj->AddOutputMember(writer, "UIGreen", new XIBObjectFloat(_g));
                obj->AddOutputMember(writer, "UIBlue", new XIBObjectFloat(_b));
                obj->AddOutputMember(writer, "UIAlpha", new XIBObjectFloat(_a));
                break;

            default:
                break;
        }

        if (_systemName) {
            obj->AddString(writer, "UISystemColorName", _systemName);
            obj->AddString(writer, "UIPatternSelector", _systemName);
        }
    } else {
        switch (_colorSpaceOut) {
            case colorSpaceWhite: {
                obj->AddOutputMember(writer, "UIWhite", new XIBObjectFloat(_white));
                obj->AddOutputMember(writer, "UIAlpha", new XIBObjectFloat(_a));
                char buf[128];
                if (_a != 1)
                    snprintf(buf, 128, "%.3f %.3f", _white, _a);
                else
                    snprintf(buf, 128, "%.3f", _white);
                obj->AddString(writer, "NSWhite", strdup(buf));
                obj->AddInt(writer, "NSColorSpace", 4);
                obj->AddInt(writer, "UIColorComponentCount", 2);
                break;
            }

            case colorSpaceRGB:
            case colorSpaceFull: {
                obj->AddOutputMember(writer, "UIAlpha", new XIBObjectFloat(_a));
                obj->AddOutputMember(writer, "UIRed", new XIBObjectFloat(_r));
                obj->AddOutputMember(writer, "UIGreen", new XIBObjectFloat(_g));
                obj->AddOutputMember(writer, "UIBlue", new XIBObjectFloat(_b));
                char buf[128];
                if (_a != 1)
                    snprintf(buf, 128, "%.3f %.3f %.3f %.3f", _r, _g, _b, _a);
                else
                    snprintf(buf, 128, "%.3f %.3f %.3f", _r, _g, _b);
                obj->AddString(writer, "NSRGB", strdup(buf));
                obj->AddInt(writer, "NSColorSpace", 2);
                obj->AddInt(writer, "UIColorComponentCount", 4);
                break;
            }
        }

        if (_systemName) {
            obj->AddString(writer, "UISystemColorName", _systemName);
        }
    }
}

XIBObject* UIColor::CreateObject(NIBWriter* writer) {
    XIBObject* ret = new XIBObject();

    ret->_needsConversion = false;
    ret->_outputClassName = "UIColor";
    ret->_className = "IBUIColor";
    ConvertStaticMappings(writer, ret);

    return ret;
}

ObjectConverter* UIColor::Clone() {
    return new UIColor();
}
