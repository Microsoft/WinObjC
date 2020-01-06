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

#include "UIScrollView.h"

static void InvertBool(struct _PropertyMapper* prop, NIBWriter* writer, XIBObject* propObj, XIBObject* obj) {
    XIBObjectBool* value = (XIBObjectBool*)propObj;

    bool newVal = value->intValue() == 0;

    obj->AddOutputMember(writer, prop->nibName, new XIBObjectBool(newVal));
}

static PropertyMapper propertyMappings[] = {
    {"IBUIScrollEnabled", "UIScrollDisabled", InvertBool},
    {"IBUIDelaysContentTouches", "UIDelaysContentTouches", NULL},
    {"IBUIDelaysContentTouches", "UIDelaysContentTouches", NULL},
    {"IBUIPagingEnabled", "UIPagingEnabled", NULL},
    {"IBUIShowsHorizontalScrollIndicator", "UIShowsHorizontalScrollIndicator", NULL},
    {"IBUIShowsVerticalScrollIndicator", "UIShowsVerticalScrollIndicator", NULL},
};
static const int numPropertyMappings = sizeof(propertyMappings) / sizeof(PropertyMapper);

UIScrollView::UIScrollView() {
    _bouncesZoom = true;
    _bounceEnabled = true;
    _canCancelContentTouches = true;
}

void UIScrollView::InitFromXIB(XIBObject* obj) {
    UIView::InitFromXIB(obj);

    obj->_outputClassName = "UIScrollView";
    _bouncesZoom = obj->GetBool("IBUIBouncesZoom", true);
    _bounceEnabled = obj->GetBool("IBUIBounces", true);
    _canCancelContentTouches = obj->GetBool("IBUICanCancelContentTouches", true);
}

void UIScrollView::InitFromStory(XIBObject* obj) {
    UIView::InitFromStory(obj);

    if (obj->getAttrib("bouncesZoom")) {
        if (strcmp(obj->getAttrAndHandle("bouncesZoom"), "NO") == 0) {
            _bouncesZoom = false;
        }
    }

    obj->_outputClassName = "UIScrollView";
}

void UIScrollView::ConvertStaticMappings(NIBWriter* writer, XIBObject* obj) {
    Map(writer, obj, propertyMappings, numPropertyMappings);
    UIView::ConvertStaticMappings(writer, obj);
    if (_bouncesZoom)
        obj->AddBool(writer, "UIBouncesZoom", _bouncesZoom);
    if (!_bounceEnabled)
        obj->AddBool(writer, "UIBounceEnabled", _bounceEnabled);
    if (!_canCancelContentTouches)
        obj->AddBool(writer, "UICanCancelContentTouches", _canCancelContentTouches);
}

ObjectConverter* UIScrollView::Clone() {
    return new UIScrollView();
}
