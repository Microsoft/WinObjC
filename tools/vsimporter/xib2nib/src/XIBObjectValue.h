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
#include "XIBObject.h"
#include <iostream>
#include <string>
#include <sstream>

#define NSPointNSValueType 1
#define NSSizeNSValueType  2
#define NSRectNSValueType  3
#define NSRangeNSValueType 4

template <typename TData>
class XIBObjectValue : public XIBObject {
    TData _data;
public:
    explicit XIBObjectValue(TData &v ) : _data(v) {
        _outputClassName = "NSValue";
    }

    void EmitObject(NIBWriter* writer) {
        EmitObject(writer, _data);
    }

private:

    const char *to_str(const UIPoint &point) {
        std::stringstream ss;
        ss << "{" <<  point.x << ", " <<point.y << "}";
        std::string str = ss.str();
        char *v = new char[str.length()+1];
        strcpy(v, str.c_str());
        return v;
    }

    const char *to_str(const CGSize &size) {
        std::stringstream ss;
        ss << "{" << size.width << size.height << "}";
        std::string str = ss.str();
        char *v = new char[str.length()+1];
        strcpy(v, str.c_str());
        return v;
    }

    const char *to_str(const UIRect &rect) {
        std::stringstream ss;
        ss << "{{" << rect.x << ", " << rect.y << "}, {" << rect.width << ", " <<  rect.height << "}}";
        std::string str = ss.str();
        char *v = new char[str.length()+1];
        strcpy(v, str.c_str());
        return v;
    }

    void EmitObject(NIBWriter* writer, const CGSize &size) {
        AddInt(writer, "NS.special", NSSizeNSValueType);
        AddString(writer, "NS.sizeval", to_str(size));
    }

    void EmitObject(NIBWriter* writer, const UIPoint &point) {
        AddInt(writer, "NS.special", NSPointNSValueType);
        AddString(writer, "NS.pointval", to_str(point));
    }

    void EmitObject(NIBWriter* writer, const UIRect &rect) {
        AddInt(writer, "NS.special", NSRectNSValueType);
        AddString(writer, "NS.rectval", to_str(rect));
    }

    void EmitObject(NIBWriter* writer, const NSRange &range) {
        AddInt(writer, "NS.special", NSRangeNSValueType);
        AddInt(writer, "NS.rangeval.length", range.length);
        AddInt(writer, "NS.rangeval.location", range.location);
    }
};

