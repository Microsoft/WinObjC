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
#include "XIBObjectTypes.h"
#include "NIBWriter.h"

XIBObjectDataWriter::XIBObjectDataWriter(const void* bin, int len) {
    _binVal = (void*)malloc(len);
    memcpy(_binVal, bin, len);
    _binLen = len;
}

bool XIBObjectDataWriter::NeedsSerialization() {
    return false;
}

void XIBObjectDataWriter::WriteData(NIBWriter* writer) {
    writer->WriteByte(NIBOBJ_DATA);
    writer->WriteInt(_binLen, 1);
    writer->WriteBytes(_binVal, _binLen);
}

XIBObjectString::XIBObjectString() {
    _strVal = NULL;
}

XIBObjectString::XIBObjectString(const char* str) {
    _strVal = str;
}

void XIBObjectString::InitFromStory(XIBObject* obj) {
    _strVal = strdup(obj->_node.text().as_string());
}

const char* XIBObjectString::stringValue() {
    return _strVal;
}

int XIBObjectString::intValue() {
    return atoi(_strVal);
}

bool XIBObjectString::EqualToString(const char* str) {
    if (strcmp(_strVal, str) == 0) {
        return true;
    }
    return false;
}

void XIBObjectString::EmitObject(NIBWriter* writer) {
    if (!_className)
        _className = "NSString";
    this->_outputClassName = _className;

    AddOutputMember(writer, "NS.bytes", new XIBObjectDataWriter(_strVal, _strVal ? strlen(_strVal) : 0));
}

static const char encode[] =
    "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    "abcdefghijklmnopqrstuvwxyz0123456789+/";
static const char decode[] =
    "|$$$}rstuvwxyz{$$$$$$$>?@ABCDEFGHIJKLMNOPQRSTUVW"
    "$$$$$$XYZ[\\]^_`abcdefghijklmnopq";

int lws_b64_decode_string(const char* in, char* out, int out_size) {
    int len;
    int i;
    int done = 0;
    unsigned char v;
    unsigned char quad[4];

    while (*in) {
        len = 0;
        for (i = 0; i < 4 && *in; i++) {
            v = 0;
            while (*in && !v) {
                v = *in++;
                v = (v < 43 || v > 122) ? 0 : decode[v - 43];
                if (v)
                    v = (v == '$') ? 0 : v - 61;
                if (*in) {
                    len++;
                    if (v)
                        quad[i] = v - 1;
                } else
                    quad[i] = 0;
            }
        }
        if (!len)
            continue;

        if (out_size < (done + len - 1))
            /* out buffer is too small */
            return -1;

        if (len >= 2)
            *out++ = quad[0] << 2 | quad[1] >> 4;
        if (len >= 3)
            *out++ = quad[1] << 4 | quad[2] >> 2;
        if (len >= 4)
            *out++ = ((quad[2] << 6) & 0xc0) | quad[3];

        done += len - 1;
    }

    if (done + 1 >= out_size)
        return -1;

    *out++ = '\0';

    return done;
}

XIBObjectData::XIBObjectData(const char* str) {
    _className = "NSData";
    _strVal = str;
    _binVal = (void*)malloc(strlen(str));
    _binLen = base64Decode(_binVal, strlen(str));
}

XIBObjectData::XIBObjectData(void* bin, int len) {
    _className = "NSData";
    _strVal = NULL;
    _binVal = (void*)malloc(len);
    memcpy(_binVal, bin, len);
    _binLen = len;
}

void XIBObjectData::EmitObject(NIBWriter* writer) {
    _outputClassName = _className;

    AddOutputMember(writer, "NS.bytes", new XIBObjectDataWriter(_binVal, _binLen));
}

int XIBObjectData::base64Decode(void* out, int outMaxLen) {
    return lws_b64_decode_string(_strVal, (char*)out, outMaxLen);
}

XIBObjectBool::XIBObjectBool(pugi::xml_node node) {
    _node = node;

    const char* str = NULL;

    str = getAttrib("value");
    if (!str) {
        str = node.child_value();
    }

    if (strcmp(str, "YES") == 0) {
        _val = true;
    } else if (strcmp(str, "NO") == 0) {
        _val = false;
    } else {
        assert(0);
    }
}

XIBObjectBool::XIBObjectBool(bool val) {
    _val = val;
}

bool XIBObjectBool::NeedsSerialization() {
    return false;
}

void XIBObjectBool::WriteData(NIBWriter* writer) {
    if (_val) {
        writer->WriteByte(NIBOBJ_TRUE);
    } else {
        writer->WriteByte(NIBOBJ_FALSE);
    }
}

int XIBObjectBool::intValue() {
    return (int)_val;
}

XIBObjectReal::XIBObjectReal(pugi::xml_node node) {
    _val = strtod(node.child_value(), NULL);
    _node = node;
}

XIBObjectReal::XIBObjectReal(double val) {
    _val = val;
};


bool XIBObjectReal::NeedsSerialization() {
    return false;
}

void XIBObjectReal::WriteData(NIBWriter* writer) {
    writer->WriteByte(NIBOBJ_DOUBLE);
    writer->WriteBytes(&_val, 8);
}

XIBArray::XIBArray(pugi::xml_node node) {
    ScanXIBNode(node);
}

XIBArray::XIBArray() {
    AddMember("EncodedWithXMLCoder", new XIBObjectBool(true));
}

XIBObject* XIBArray::ApplyVariation(XIBObject* variation) {
    // Variations act as a filter to include or exclude objects from an array based on a size class.
    // NOTE: We return a new ref, and leave the original intact. This has implications if somewhere
    //   in say, InitFromStoryboard, we change an array, or keep a ref to modify at some later point.
    //   Variations do not apply to <XIB3.
    if (variation) {
        XIBArray* ret = new XIBArray();
        ret->_parent = _parent;

        for (int i = 0; i < count(); i++) {
            bool exclude = false;
            auto obj = objectAtIndex(i);
            for (auto n = variation->_members.begin(); n != variation->_members.end(); n++) {
                auto excl = (*n)->_obj;
                if (strcmp(excl->ClassName(), "exclude") == 0) {
                    auto objRef = obj->getAttrib("id");
                    auto exclRef = excl->getAttrib("reference");
                    if (objRef && exclRef && !strcmp(objRef, exclRef)) {
                        exclude = true;
                        break;
                    }
                }
            }
            if (!exclude) {
                ret->AddMember(NULL, obj);
            }
        }

        for (auto n = variation->_members.begin(); n != variation->_members.end(); n++) {
            auto obj = (*n)->_obj;
            if (strcmp(obj->ClassName(), "include") == 0) {
                auto cObjRef = obj->getAttrib("reference");
                if (cObjRef) {
                    auto objRef = findReference(cObjRef);
                    if (objRef) {
                        ret->AddMember(NULL, objRef);
                    } else {
                        assert(0);
                    }
                }
            } else if (strcmp(obj->ClassName(), "exclude") == 0) {
                // Left blank intentionally
            } else {
                assert(0);
            }
        }

        return ret;
    }
    return this;
}

void XIBArray::InitFromStory(XIBObject* obj) {
    _className = "NSArray";
    _outputClassName = "NSArray";
    setSelfHandled();
}

void XIBArray::EmitObject(NIBWriter* writer) {
    if (!_className) {
        _className = "NSArray";
    }

    if ((_members.size() == 0 || _members[0]->_name == NULL || strcmp(_members[0]->_name, "EncodedWithXMLCoder") != 0) &&
        strcmp(_className, "NSObject") != 0) {
        XIBMember* newMember = new XIBMember();

        newMember->_name = "EncodedWithXMLCoder";
        newMember->_obj = new XIBObjectBool(true);

        _members.insert(_members.begin(), newMember);
    }
    this->_outputClassName = _className;
    // printf("NSArray\n");
    for (int i = 0; i < _members.size(); i++) {
        XIBMember* pMember = _members[i];

        if (pMember->_name == NULL) {
            AddOutputMember(writer, "UINibEncoderEmptyKey", pMember->_obj);
        } else if (strcmp(pMember->_name, "EncodedWithXMLCoder") == 0) {
            AddOutputMember(writer, "NSInlinedValue", pMember->_obj);
        } else {
            AddOutputMember(writer, pMember->_name, pMember->_obj);
        }
    }
}

XIBObject* XIBArray::objectAtIndex(int idx) {
    int curIdx = 0;
    for (memberList::iterator cur = _members.begin(); cur != _members.end(); cur++) {
        XIBMember* pMember = (*cur);

        if (pMember->_name == NULL) {
            if (curIdx == idx)
                return pMember->_obj;
            curIdx++;
        }
    }

    assert(0);
    return NULL;
}

int XIBArray::count() {
    int curIdx = 0;
    for (memberList::iterator cur = _members.begin(); cur != _members.end(); cur++) {
        XIBMember* pMember = (*cur);

        if (pMember->_name == NULL) {
            curIdx++;
        }
    }

    return curIdx;
}

XIBVariation::XIBVariation(pugi::xml_node node) {
    ScanXIBNode(node);
}

XIBVariation::XIBVariation() {
}

void XIBVariation::EmitObject(NIBWriter* writer) {
}

bool XIBVariation::NeedsSerialization() {
    return false;
}

void XIBAccessibilityArray::EmitObject(NIBWriter* writer) {
    //  Scan all UI objects
    for (memberList::iterator cur = writer->_allUIObjects->_members.begin(); cur != writer->_allUIObjects->_members.end(); cur++) {
        XIBMember* curMember = *cur;

        if (curMember->_obj->FindMember("IBUIAccessibilityConfiguration")) {
            XIBObject* accessibilityConfig = curMember->_obj->FindMember("IBUIAccessibilityConfiguration");
            accessibilityConfig->AddMember("UIAccessibileObject", curMember->_obj);
            AddMember(NULL, accessibilityConfig);
        }
    }
    XIBArray::EmitObject(writer);
}
