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

#include "UISegmentedControl.h"
#include "UIColor.h"
#include "UISegment.h"

UISegmentedControl::UISegmentedControl() {
    _segments = NULL;
    _momentary = false;
    _springLoaded = false;
    _tintColor = NULL;
    _segmentControlStyle = 0;
    _selectedSegmentIndex = -1;
}

void UISegmentedControl::InitFromXIB(XIBObject* obj) {
    UIControl::InitFromXIB(obj);
    // removed outdated code
}

void UISegmentedControl::InitFromStory(XIBObject* obj) {
    UIControl::InitFromStory(obj);

    _tintColor = (UIColor*)FindMemberAndHandle("tintColor");
    _segments = (XIBArray*)obj->FindMemberClass("segments");
    if (_segments) {
        // add them to subviews also set proper index
        for (int idx = 0; idx < _segments->count(); idx++) {
            UISegment *segment = (UISegment*)_segments->objectAtIndex(idx);
            segment->_position = idx;
            
            _subviews->AddMember(NULL, segment);
        }
    }

    const char* attr;
    if ((attr = obj->getAttrAndHandle("momentary"))) {
        if (strcmp(attr, "YES") == 0)
            _momentary = true;
    }

    if ((attr = obj->getAttrAndHandle("springLoaded"))) {
        if (strcmp(attr, "YES") == 0)
            _springLoaded = true;
    }
    
    if ((attr = obj->getAttrAndHandle("selectedSegmentIndex"))) {
        _selectedSegmentIndex = std::stoi(attr, NULL);
    }

    obj->_outputClassName = "UISegmentedControl";
}

void UISegmentedControl::ConvertStaticMappings(NIBWriter* writer, XIBObject* obj) {
    UIControl::ConvertStaticMappings(writer, obj);
    if (_segments)
        AddOutputMember(writer, "UISegments", _segments);
    if (_momentary)
        AddBool(writer, "UIMomentary", _momentary);
    if (_springLoaded)
        AddBool(writer, "UISpringLoaded", _springLoaded);
    if (_tintColor)
        AddOutputMember(writer, "UISegmentedControlTintColor", _tintColor);
    if (_selectedSegmentIndex != -1)
        AddInt(writer, "UISelectedSegmentIndex", _selectedSegmentIndex);
}
