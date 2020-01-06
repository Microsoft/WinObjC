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

#ifndef __NIBWRITER_H
#define __NIBWRITER_H

#include <stdio.h>
#include "XIBObject.h"

#define NIBOBJ_INT8 0x00
#define NIBOBJ_INT16 0x01
#define NIBOBJ_INT32 0x02
#define NIBOBJ_INT64 0x03
#define NIBOBJ_FALSE 0x04
#define NIBOBJ_TRUE 0x05
#define NIBOBJ_FLOAT 0x06
#define NIBOBJ_DOUBLE 0x07
#define NIBOBJ_DATA 0x08
#define NIBOBJ_NULL 0x09
#define NIBOBJ_UID 0x0A

#define DEPLOYMENT_TARGET_IOS9 0x090000
#define DEPLOYMENT_TARGET_IOS11 0x0B0000
#define DEPLOYMENT_TARGET_RECENT DEPLOYMENT_TARGET_IOS11

class ProxiedObject {
public:
    XIBObject *_obj, *_proxyObj;
    const char* _name;
};

typedef std::vector<ProxiedObject*> proxyList;
class XIBDictionary;

class NIBWriter {
private:
    xibList _outputObjects;
    proxyList _proxies;
    FILE* fpOut;

public:
    uint32_t _minimumDeploymentTarget;
    bool _wasLimitedByDeplymentTarget;
    XIBObject* _allUIObjects;
    XIBObject* _connections;
    XIBObject* _baseObject;
    XIBObject* _topObjects;
    XIBObject* _accessibilityObjects;
    XIBObject* _visibleWindows;
    XIBObject* _keyValuePairs;

    XIBDictionary* _externalReferencesDictionary;

    NIBWriter(FILE* out);
    NIBWriter(FILE* out, XIBDictionary* externalRefsDict, XIBObject* base);

    void ExportObject(XIBObject* obj);
    void WriteObjects();
    XIBObject* AddOutputObject(XIBObject* pObj);
    void WriteData();

    void WriteInt(int val, int minlen);
    void WriteByte(int byte);
    void WriteBytes(void* bytes, int len);
    void AddOutletConnection(XIBObject* src, XIBObject* dst, char* propName);
    XIBObject* FindProxy(char* propName);
    XIBObject* AddProxy(char* propName);
    XIBObject* GetProxyFor(XIBObject* obj);
};

#endif
