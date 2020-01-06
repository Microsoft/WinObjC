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
#include "UIScrollView.h"

class UIFont;

class UITextView : public UIScrollView {
private:
    CGSize _shadowOffset;
    const char* _text;
    XIBObject* _textColor;
    UIFont* _font;
    int _textAlignment;
    bool _editable;
    int _dataDetectorTypes;
    int _autoCorrectionType;
    int _returnKeyType;
    int _lineBreakMode;

public:
    UITextView();
    virtual void InitFromXIB(XIBObject* obj);
    virtual void ConvertStaticMappings(NIBWriter* writer, XIBObject* obj);
    virtual void InitFromStory(XIBObject* obj);
};
