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

#include "UIControl.h"

UIControl::UIControl() {
    _contentVerticalAlignment = UIControlContentVerticalAlignmentTop;
    _contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    _enabled = true;
    _selected = false;
    _highlighted = false;
}

void UIControl::InitFromXIB(XIBObject* obj) {
    UIView::InitFromXIB(obj);

    _contentVerticalAlignment = GetInt("IBUIContentVerticalAlignment", 1);
    _contentHorizontalAlignment = GetInt("IBUIContentHorizontalAlignment", 1);

    _outputClassName = "UIControl";
}

void UIControl::InitFromStory(XIBObject* obj) {
    UIView::InitFromStory(obj);

    const char* horizontalAlign = getAttrAndHandle("contentHorizontalAlignment");
    if (horizontalAlign) {
        if (strcmp(horizontalAlign, "center") == 0) {
            _contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
        } else if (strcmp(horizontalAlign, "left") == 0) {
            _contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        } else if (strcmp(horizontalAlign, "right") == 0) {
            _contentHorizontalAlignment = UIControlContentHorizontalAlignmentRight;
        } else if (strcmp(horizontalAlign, "fill") == 0) {
            _contentHorizontalAlignment = UIControlContentHorizontalAlignmentFill;
        } else {
            printf("Unknown contentHorizontalAlignment value: %s\n", horizontalAlign);
        }
    }

    const char* verticalAlign = getAttrAndHandle("contentVerticalAlignment");
    if (verticalAlign) {
        if (strcmp(verticalAlign, "center") == 0) {
            _contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
        } else if (strcmp(verticalAlign, "top") == 0) {
            _contentVerticalAlignment = UIControlContentVerticalAlignmentTop;
        } else if (strcmp(verticalAlign, "bottom") == 0) {
            _contentVerticalAlignment = UIControlContentVerticalAlignmentBottom;
        } else if (strcmp(verticalAlign, "fill") == 0) {
            _contentVerticalAlignment = UIControlContentVerticalAlignmentFill;
        } else {
            printf("Unknown contentVerticalAlignment value: %s\n", verticalAlign);
        }
    }

    const char* attr;
    if ((attr = obj->getAttrAndHandle("enabled"))) {
        if (strcmp(attr, "NO") == 0)
            _enabled = false;
    }

    if ((attr = obj->getAttrAndHandle("selected"))) {
        if (strcmp(attr, "YES") == 0)
            _selected = true;
    }

    if ((attr = obj->getAttrAndHandle("highlighted"))) {
        if (strcmp(attr, "YES") == 0)
            _highlighted = true;
    }

    _outputClassName = "UIControl";
}

void UIControl::ConvertStaticMappings(NIBWriter* writer, XIBObject* obj) {
    UIView::ConvertStaticMappings(writer, obj);

    if (_contentVerticalAlignment != UIControlContentVerticalAlignmentTop)
        AddInt(writer, "UIContentVerticalAlignment", _contentVerticalAlignment);
    if (_contentHorizontalAlignment != UIControlContentHorizontalAlignmentLeft)
        AddInt(writer, "UIContentHorizontalAlignment", _contentHorizontalAlignment);
}
