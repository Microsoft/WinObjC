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

#include "UISegment.h"
#include "UICustomResource.h"
#include <string>

UISegment::UISegment() {
    _outputClassName = "UISegment";
    _title = NULL;
    _image = NULL;
    _enabled = true;
    _position = 0;
}

void UISegment::InitFromXIB(XIBObject* obj) {
    UIView::InitFromXIB(obj);

    obj->_outputClassName = "UISegment";
}

void UISegment::InitFromStory(XIBObject* obj) {
    UIView::InitFromStory(obj);

    _title = obj->getAttrAndHandle("title");
    _image = obj->getAttrAndHandle("image");
    const char* attr;
    if ((attr = obj->getAttrAndHandle("enabled"))) {
        if (strcmp(attr, "NO") == 0)
            _enabled = false;
    }

    PopulateSizeFromStoryboard("contentOffset", _contentOffset);
    
    obj->_outputClassName = "UISegment";
}

void UISegment::ConvertStaticMappings(NIBWriter* writer, XIBObject* obj) {
    UIView::ConvertStaticMappings(writer, obj);
    if (_image) {
        // add placeholder
        UICustomResource *placeholder = new UICustomResource();
        placeholder->_imageName = strdup(_image);
        AddOutputMember(writer, "UISegmentInfo", placeholder);
    } else if (_title) {
        AddString(writer, "UISegmentInfo", _title);
    }
    
    if (!_enabled)
        AddBool(writer, "UIUserInteractionDisabled", _enabled);
    
    if (_position)
        AddInt(writer, "UISegmentPosition", _position);

    if (_contentOffset.IsValid())
        AddSize(writer, "UISegmentContentOffset", _contentOffset);
}
