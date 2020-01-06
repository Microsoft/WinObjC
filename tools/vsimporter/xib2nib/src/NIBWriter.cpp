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

#include "NIBWriter.h"
#include "XIBObjectTypes.h"
#include "UIRuntimeOutletConnection.h"
#include "UIRuntimeEventConnection.h"
#include "UIProxyObject.h"
#include <assert.h>
#include <map>
#include "../WBITelemetry/WBITelemetry.h"

int curPlaceholder = 1;

void NIBWriter::WriteInt(int val, int minlen) {
    int len = 0;
    while (val >= 0x80 || len < minlen - 1) {
        int outByte = val & 0x7F;
        val >>= 7;
        fwrite(&outByte, 1, 1, fpOut);
        len++;
    }

    val |= 0x80;
    fwrite(&val, 1, 1, fpOut);
}

void NIBWriter::WriteByte(int byte) {
    fwrite(&byte, 1, 1, fpOut);
}

void NIBWriter::WriteBytes(void* bytes, int len) {
    fwrite(bytes, 1, len, fpOut);
}

XIBObject* NIBWriter::AddOutputObject(XIBObject* pObj) {
    if (!pObj->NeedsSerialization())
        return pObj;

    if (pObj->_parent != NULL && _baseObject != NULL) {
        bool found = false;

        XIBObject* curObj = pObj;
        while (curObj) {
            if (curObj == _baseObject) {
                found = true;
                break;
            }
            curObj = curObj->_parent;
        }

        if (!found) {
            pObj = GetProxyFor(pObj);
        }
    }
    for (size_t i = 0; i < _outputObjects.size(); i++) {
        if (_outputObjects[i] == pObj) {
            return pObj;
        }
    }

    _outputObjects.push_back(pObj);
    pObj->EmitObject(this);
    return pObj;
}

typedef struct {
    int _numHeaders;
    int _sizeDw;
    int _numObjects; //  2
    int _objectsOffset; //  3
    int _numKeyNames; //  4
    int _keyNamesOffset; //  5
    int _numItems; //  6
    int _itemsOffset; //  7
    int _numClassNames; //  8
    int _classNamesOffset; //  9
} NIBHeader;

class StringCombiner {
public:
    char** _stringTable;
    int _numStrings, _maxStrings;

    StringCombiner() {
        _numStrings = 0;
        _maxStrings = 32;
        _stringTable = (char**)malloc(sizeof(char*) * _maxStrings);
    }

    int AddString(const char* str) {
        for (int i = 0; i < _numStrings; i++) {
            if (strcmp(_stringTable[i], str) == 0) {
                return i;
            }
        }

        if (_numStrings + 1 > _maxStrings) {
            _maxStrings += 64;
            _stringTable = (char**)realloc(_stringTable, sizeof(char*) * _maxStrings);
        }

        _stringTable[_numStrings] = (char*)malloc(strlen(str) + 1);
        strcpy(_stringTable[_numStrings], str);

        int ret = _numStrings;
        _numStrings++;

        return ret;
    }
};

NIBWriter::NIBWriter(FILE* out) {
    _allUIObjects = NULL;
    _externalReferencesDictionary = NULL;
    _baseObject = NULL;
    _connections = NULL;
    _visibleWindows = NULL;
    _minimumDeploymentTarget = DEPLOYMENT_TARGET_RECENT;
    _wasLimitedByDeplymentTarget = false;
    fpOut = out;
}

NIBWriter::NIBWriter(FILE* out, XIBDictionary* externalReferences, XIBObject* base) {
    _allUIObjects = NULL;
    _externalReferencesDictionary = externalReferences;
    _baseObject = NULL;
    _connections = NULL;
    _visibleWindows = NULL;
    _minimumDeploymentTarget = DEPLOYMENT_TARGET_RECENT;
    _wasLimitedByDeplymentTarget = false;
    fpOut = out;

    curPlaceholder = 1;
    _baseObject = base;

    _allUIObjects = new XIBArray();
    _connections = new XIBArray();
    _topObjects = new XIBArray();
    _visibleWindows = new XIBArray();
    _keyValuePairs = new XIBArray();
    _accessibilityObjects = new XIBAccessibilityArray();
}

void NIBWriter::ExportObject(XIBObject* obj) {
    _topObjects->AddMember(NULL, obj);
    _allUIObjects->AddMember(NULL, obj);
}

void NIBWriter::WriteObjects() {
    XIBObject* nibRoot = new XIBArray();

    nibRoot->_className = "NSObject";
    nibRoot->_members.clear();
    nibRoot->AddMember("UINibTopLevelObjectsKey", _topObjects);
    nibRoot->AddMember("UINibObjectsKey", _allUIObjects);
    nibRoot->AddMember("UINibConnectionsKey", _connections);
    nibRoot->AddMember("UINibVisibleWindowsKey", _visibleWindows);
    nibRoot->AddMember("UINibAccessibilityConfigurationsKey", _accessibilityObjects);
    nibRoot->AddMember("UINibKeyValuePairsKey", _keyValuePairs);

    AddOutputObject(nibRoot);
    //  Sort connection records alphabetically using stable, uh, bubble sort
    for (;;) {
        bool didSwap = false;

        for (memberList::iterator cur = _connections->_outputMembers.begin(); cur != _connections->_outputMembers.end(); cur++) {
            if ((cur + 1) == _connections->_outputMembers.end())
                break;
            XIBMember* curMember = (*cur);
            XIBMember* nextMember = (*(cur + 1));

            if (strcmp(curMember->_name, "UINibEncoderEmptyKey") != 0)
                continue;

            //  Event connections first
            if (strcmp(curMember->_obj->_className, "UIRuntimeOutletConnection") == 0 &&
                strcmp(nextMember->_obj->_className, "UIRuntimeEventConnection") == 0) {
                *cur = nextMember;
                *(cur + 1) = curMember;
                didSwap = true;
                continue;
            }

            if (strcmp(curMember->_obj->_className, nextMember->_obj->_className) == 0) {
                const char *label1, *label2;

                if (strcmp(curMember->_obj->_className, "UIRuntimeEventConnection") == 0) {
                    UIRuntimeEventConnection* conn1 = (UIRuntimeEventConnection*)curMember->_obj;
                    UIRuntimeEventConnection* conn2 = (UIRuntimeEventConnection*)nextMember->_obj;

                    label1 = conn1->_label;
                    label2 = conn2->_label;
                } else {
                    UIRuntimeOutletConnection* conn1 = (UIRuntimeOutletConnection*)curMember->_obj;
                    UIRuntimeOutletConnection* conn2 = (UIRuntimeOutletConnection*)nextMember->_obj;

                    label1 = conn1->_label;
                    label2 = conn2->_label;
                }

                if (strcmp(label1, label2) > 0) {
                    *cur = nextMember;
                    *(cur + 1) = curMember;
                    didSwap = true;
                }
            }
        }

        if (!didSwap)
            break;
    }

    WriteData();
}

void NIBWriter::AddOutletConnection(XIBObject* src, XIBObject* dst, char* propName) {
    UIRuntimeOutletConnection* newConn = new UIRuntimeOutletConnection();

    newConn->_source = src;
    newConn->_destination = dst;
    newConn->_label = strdup(propName);

    _connections->AddMember(NULL, newConn);
}

XIBObject* NIBWriter::AddProxy(char* propName) {
    XIBObject* existingProxy = NIBWriter::FindProxy(propName);
    if (existingProxy)
        return existingProxy;

    UIProxyObject* newProxy = new UIProxyObject();
    newProxy->_identifier = strdup(propName);
    _allUIObjects->AddMember(NULL, newProxy);
    _topObjects->AddMember(NULL, newProxy);

    ProxiedObject* newProxiedObj = new ProxiedObject();
    newProxiedObj->_obj = NULL;
    newProxiedObj->_proxyObj = newProxy;
    newProxiedObj->_name = newProxy->_identifier;
    _proxies.push_back(newProxiedObj);

    return newProxy;
}

XIBObject* NIBWriter::FindProxy(char* propName) {
    for (proxyList::iterator cur = _proxies.begin(); cur != _proxies.end(); cur++) {
        ProxiedObject* curProxy = *cur;
        if (strcmp(curProxy->_name, propName) == 0) {
            return curProxy->_proxyObj;
        }
    }

    return NULL;
}

XIBObject* NIBWriter::GetProxyFor(XIBObject* obj) {
    //  Go through current proxies
    for (proxyList::iterator cur = _proxies.begin(); cur != _proxies.end(); cur++) {
        ProxiedObject* curObj = *cur;

        if (curObj->_obj == obj) {
            return curObj->_proxyObj;
        }
    }

    UIProxyObject* newProxy = new UIProxyObject();

    char szName[255];
    if (curPlaceholder == 2)
        curPlaceholder++;
    sprintf(szName, "UpstreamPlaceholder-%d", curPlaceholder++);
    newProxy->_identifier = strdup(szName);
    _allUIObjects->AddMember(NULL, newProxy);
    _topObjects->AddMember(NULL, newProxy);

    ProxiedObject* newProxiedObj = new ProxiedObject();
    newProxiedObj->_obj = obj;
    newProxiedObj->_proxyObj = newProxy;
    newProxiedObj->_name = newProxy->_identifier;
    _proxies.push_back(newProxiedObj);

    XIBObjectString* key = new XIBObjectString(strdup(szName));
    _externalReferencesDictionary->AddObjectForKey(key, obj);

    return newProxy;
}


void NIBWriter::WriteData() {
    fwrite("NIBArchive", 10, 1, fpOut);
    int headerPos = ftell(fpOut);

    NIBHeader header = { 0 };
    fwrite(&header, sizeof(header), 1, fpOut);

    //  Write out class names
    StringCombiner classNames;
    header._classNamesOffset = ftell(fpOut);

    for (int i = 0; i < _outputObjects.size(); i++) {
        XIBObject* pObject = _outputObjects[i];
        if (pObject->_outputClassName == NULL) {
            printf("Unable to find class mapping for required object <%s>\n", pObject->_node.name());
            TELEMETRY_EVENT_DATA(L"MissingClassMapping", pObject->_node.name());
            TELEMETRY_FLUSH();

            exit(-1);
        }
        pObject->_outputClassNameIdx = classNames.AddString(pObject->_outputClassName);
        pObject->_outputObjectIdx = i;
    }

    for (int i = 0; i < classNames._numStrings; i++) {
        char* pName = classNames._stringTable[i];
        int len = strlen(pName) + 1;
        WriteInt(len, 1);
        int tp = 0x80;
        fwrite(&tp, 1, 1, fpOut);
        fwrite(pName, 1, len, fpOut);

        header._numClassNames++;
    }

    //  Write out key names
    StringCombiner keyNames;
    header._keyNamesOffset = ftell(fpOut);
    for (int i = 0; i < _outputObjects.size(); i++) {
        XIBObject* pObject = _outputObjects[i];

        for (int j = 0; j < pObject->_outputMembers.size(); j++) {
            pObject->_outputMembers[j]->_outputNameIdx = keyNames.AddString(pObject->_outputMembers[j]->_name);
        }
    }

    for (int i = 0; i < keyNames._numStrings; i++) {
        char* pName = keyNames._stringTable[i];
        int len = strlen(pName);
        WriteInt(len, 1);
        fwrite(pName, 1, len, fpOut);

        header._numKeyNames++;
    }

    //  Write out items
    header._itemsOffset = ftell(fpOut);
    for (int i = 0; i < _outputObjects.size(); i++) {
        XIBObject* pObject = _outputObjects[i];

        pObject->_outputMembersIdx = header._numItems;

        for (int j = 0; j < pObject->_outputMembers.size(); j++) {
            XIBMember* cur = pObject->_outputMembers[j];

            //  Write out name index
            WriteInt(cur->_outputNameIdx, 1);
            /*(
            printf("%s\n", cur->_name);
            if ( strcmp(cur->_name, "UICenter") == 0 ) {
                printf("Hi\n");
            }
            */

            //  Write out item type + data
            cur->_obj->WriteData(this);
            header._numItems++;
        }
    }

    //  Write out objects
    header._objectsOffset = ftell(fpOut);
    for (int i = 0; i < _outputObjects.size(); i++) {
        XIBObject* pObject = _outputObjects[i];

        //  Write out class name index
        WriteInt(pObject->_outputClassNameIdx, 1);

        //  Item index
        WriteInt(pObject->_outputMembersIdx, 1);

        //  Item count
        WriteInt(pObject->_outputMembers.size(), 1);

        header._numObjects++;
    }

    header._numHeaders = 1;
    header._sizeDw = 9;

    fseek(fpOut, headerPos, SEEK_SET);
    fwrite(&header, sizeof(header), 1, fpOut);
}
