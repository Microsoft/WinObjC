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

#pragma once
#include "XIBObjectTypes.h"

typedef struct _PropertyMapper {
    char* xibName;
    char* nibName;
    void (*ConvertProperty)(struct _PropertyMapper* prop, NIBWriter* writer, XIBObject* propObj, XIBObject* obj);
} PropertyMapper;

class ObjectConverter : public XIBObject {
public:
    XIBArray* _connections;
    XIBArray* _userDefinedAttributes;
    XIBArray* _variations;

    ObjectConverter() {
        _connections = NULL;
        _userDefinedAttributes = NULL;
    };
    virtual void InitFromXIB(XIBObject* obj);
    virtual void InitFromStory(XIBObject* obj);
    virtual void ConvertStaticMappings(NIBWriter* writer, XIBObject* obj);

    void Map(NIBWriter* writer, XIBObject* obj, PropertyMapper* properties, int numProperties);
    virtual ObjectConverter* Clone();

    static XIBObject* ConverterForObject(const char* className, pugi::xml_node node);
    static XIBObject* ConverterForStoryObject(const char* className, pugi::xml_node node);
};

class ObjectConverterSwapper : public ObjectConverter {
public:
    virtual void InitFromXIB(XIBObject* obj);
    virtual void InitFromStory(XIBObject* obj);
    virtual void ConvertStaticMappings(NIBWriter* writer, XIBObject* obj);
};

void ConvertOffset(struct _PropertyMapper* prop, NIBWriter* writer, XIBObject* propObj, XIBObject* obj);
