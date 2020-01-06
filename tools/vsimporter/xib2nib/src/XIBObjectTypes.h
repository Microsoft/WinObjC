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

#ifndef __XIBOBJECTTYPES_H
#define __XIBOBJECTTYPES_H

#include "XIBObject.h"
#include "XIBObjectFloat.h"
#include "XIBObjectDouble.h"
#include "XIBObjectInt.h"
#include "XIBObjectNumber.h"
#include "XIBDictionary.h"
#include "XIBObjectNil.h"

class XIBObjectString : public XIBObject {
public:
    const char* _strVal;
    XIBObjectString(const char* str);
    XIBObjectString();
    const char* stringValue();
    int intValue();
    bool EqualToString(const char* str);
    ;
    void EmitObject(NIBWriter* writer);
    void InitFromStory(XIBObject* obj);
};

class XIBObjectData : public XIBObject {
public:
    const char* _strVal;
    void* _binVal;
    int _binLen;

    XIBObjectData(const char* str);
    XIBObjectData(void* bin, int len);
    void EmitObject(NIBWriter* writer);
    int base64Decode(void* out, int outMaxLen);
};

class XIBObjectBool : public XIBObject {
public:
    bool _val;
    XIBObjectBool(pugi::xml_node node);
    XIBObjectBool(bool val);
    bool NeedsSerialization();
    void WriteData(NIBWriter* writer);
    int intValue();
};

class XIBObjectReal : public XIBObject {
private:
    double _val;
public:
    XIBObjectReal(pugi::xml_node node);
    XIBObjectReal(double val);
    virtual bool NeedsSerialization();
    void WriteData(NIBWriter* writer);
};

class XIBArray : public XIBObject {
public:
    XIBArray(pugi::xml_node node);
    XIBArray();

    virtual XIBObject* ApplyVariation(XIBObject* variation);

    virtual void InitFromStory(XIBObject* obj);
    void EmitObject(NIBWriter* writer);
    XIBObject* objectAtIndex(int idx);
    int count();
};

class XIBVariation : public XIBArray {
public:
    XIBVariation(pugi::xml_node node);
    XIBVariation();

    bool NeedsSerialization();
    void EmitObject(NIBWriter* writer);
};

class XIBAccessibilityArray : public XIBArray {
    void EmitObject(NIBWriter* writer);
};

// Distinguish between XIB3 format and Storyboard since we write out intermediate NIB files in the storyboard code path
// These methods are used only when dealing with storyboard (.storyboard) files
bool IsStoryboardConversion();
std::string GetOutputFilename(const char* filename);
#endif