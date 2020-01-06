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

#include "NSLayoutConstraint.h"
#include "UIView.h"
#include "UILayoutGuide.h"

#include <assert.h>
#include <string>
#include <map>

std::map<std::string, NSLayoutAttribute> storyToLayout = { { "left", NSLayoutAttributeLeft },
                                                           { "right", NSLayoutAttributeRight },
                                                           { "top", NSLayoutAttributeTop },
                                                           { "bottom", NSLayoutAttributeBottom },
                                                           { "leading", NSLayoutAttributeLeading },
                                                           { "trailing", NSLayoutAttributeTrailing },
                                                           { "width", NSLayoutAttributeWidth },
                                                           { "height", NSLayoutAttributeHeight },
                                                           { "centerX", NSLayoutAttributeCenterX },
                                                           { "centerY", NSLayoutAttributeCenterY },
                                                           { "baseline", NSLayoutAttributeBaseline },
                                                           { "firstBaseline", NSLayoutAttributeFirstBaseline },
                                                           { "leftMargin", NSLayoutAttributeLeftMargin },
                                                           { "rightMargin", NSLayoutAttributeRightMargin },
                                                           { "topMargin", NSLayoutAttributeTopMargin },
                                                           { "bottomMargin", NSLayoutAttributeBottomMargin },
                                                           { "leadingMargin", NSLayoutAttributeLeadingMargin },
                                                           { "trailingMargin", NSLayoutAttributeTrailingMargin },
                                                           { "centerXWithinMargins", NSLayoutAttributeCenterXWithinMargins },
                                                           { "centerYWithinMargins", NSLayoutAttributeCenterYWithinMargins } };

static std::map<std::string, NSLayoutRelation> storyToRelation = {
    { "greaterThanOrEqual", NSLayoutRelationGreaterThanOrEqual },
    { "lessThanOrEqual", NSLayoutRelationLessThanOrEqual }};

NSLayoutConstraint::NSLayoutConstraint() {
    _firstItem = NULL;
    _secondItem = NULL;
    _firstAttribute = NSLayoutAttributeNotAnAttribute;
    _secondAttribute = NSLayoutAttributeNotAnAttribute;
    _relation = NSLayoutRelationEqual;
    _multiplier = 1.0;
    _priority = NSLayoutPriorityRequired;
    _constant = 0.0;
    _symbolicConstant = 0.0;
    _hasSymbolicConstant = false;
    _layoutIdentifier = NULL;
    _placeholder = false;
    _exportDefaultValues = false;
}

void NSLayoutConstraint::InitFromXIB(XIBObject* obj) {
    ObjectConverterSwapper::InitFromXIB(obj);

    _firstAttribute = (NSLayoutAttribute)obj->GetInt("firstAttribute", NSLayoutAttributeNotAnAttribute);
    _secondAttribute = (NSLayoutAttribute)obj->GetInt("secondAttribute", NSLayoutAttributeNotAnAttribute);

    _relation = (NSLayoutAttribute)obj->GetInt("relation", NSLayoutRelationEqual);

    _firstItem = obj->FindMember("firstItem");
    _secondItem = obj->FindMember("secondItem");

    if (obj->FindMember("multiplier")) {
        _multiplier = obj->FindMember("multiplier")->floatValue();
    }
    if (obj->FindMember("priority")) {
        _priority = obj->FindMember("priority")->intValue();
    }
    if (obj->FindMember("constant") && obj->FindMember("constant")->FindMember("value")) {
        if (strcmp(obj->FindMember("constant")->ClassName(), "IBLayoutConstant") == 0) {
            _constant = obj->FindMember("constant")->FindMember("value")->floatValue();
        } else {
            _hasSymbolicConstant = true;
            _symbolicConstant = obj->FindMember("constant")->FindMember("value")->floatValue(); // Hm.
        }
    }

    UIView* view = (UIView*)obj->FindMember("containingView");
    if (view) {
        view->_constraints->AddMember(NULL, this);
    }

    _outputClassName = "NSLayoutConstraint";
}

void NSLayoutConstraint::InitFromStory(XIBObject* obj) {
    ObjectConverterSwapper::InitFromStory(obj);

    const char* attr;
    if ((attr = obj->getAttrAndHandle("firstAttribute"))) {
        if (storyToLayout.find(attr) != storyToLayout.end()) {
            _firstAttribute = storyToLayout[attr];
        }
    }
    if ((attr = obj->getAttrAndHandle("secondAttribute"))) {
        if (storyToLayout.find(attr) != storyToLayout.end()) {
            _secondAttribute = storyToLayout[attr];
        }
    }

    if ((attr = obj->getAttrAndHandle("constant"))) {
        if (obj->getAttrAndHandle("symbolic") && strcmp(obj->getAttrAndHandle("symbolic"), "YES") == 0) {
            _hasSymbolicConstant = true;
            _symbolicConstant = strtod(attr, NULL);
        } else {
            _constant = strtod(attr, NULL);
        }
    }
    if ((attr = obj->getAttrAndHandle("priority"))) {
        _priority = std::stoi(attr, NULL);
    }

    if ((attr = obj->getAttrAndHandle("multiplier"))) {
        char *separator;
        _multiplier = strtod(attr, &separator);
        if (*separator == ':') {
            // it is multiplier in form of "100:200"
            double div = strtod(separator + 1, NULL);
            _multiplier /= div;
        }
    }

    if ((attr = getAttrAndHandle("secondItem"))) {
        _secondItem = findReference(attr);
        assert(_secondItem);
    }

    if ((attr = getAttrAndHandle("firstItem"))) {
        _firstItem = findReference(attr);
        assert(_firstItem);
    }

    if ((attr = obj->getAttrAndHandle("relation"))) {
        if (storyToRelation.find(attr) != storyToRelation.end()) {
            _relation = storyToRelation[attr];
        }
    }

    if ((attr = obj->getAttrAndHandle("placeholder"))) {
        _placeholder = strcmp(attr, "YES") == 0;
    }

    _outputClassName = "NSLayoutConstraint";
}

void NSLayoutConstraint::Awaken() {
    if (!_firstItem) {
        // Alludes to superview.
        _firstItem = dynamic_cast<UIView*>(_parent->_parent);
        assert(_firstItem);
    }
}

void NSLayoutConstraint::ConvertStaticMappings(NIBWriter* writer, XIBObject* obj) {
    AddInt(writer, "NSFirstAttribute", _firstAttribute);
    if (_secondAttribute)
        AddInt(writer, "NSSecondAttribute", _secondAttribute);

    if (_exportDefaultValues || _relation != NSLayoutRelationEqual)
        AddInt(writer, "NSRelation", _relation);

    if (_firstItem)
        AddOutputMember(writer, "NSFirstItem", substituteItemUnsupported(writer, _firstItem));
    if (_secondItem)
        AddOutputMember(writer, "NSSecondItem", substituteItemUnsupported(writer, _secondItem));

    if (_exportDefaultValues || _multiplier != 1.0f)
        AddOutputMember(writer, "NSMultiplier", new XIBObjectDouble(_multiplier));
    if (_exportDefaultValues || _priority != NSLayoutPriorityRequired)
        AddInt(writer, "NSPriority", _priority);

    if (_hasSymbolicConstant) {
        AddOutputMember(writer, "NSSymbolicConstant", new XIBObjectDouble(_symbolicConstant));
    } else {
        if (_exportDefaultValues || _constant != 0)
            AddOutputMember(writer, "NSConstant", new XIBObjectDouble(_constant));
    }

    if (_layoutIdentifier)
        AddString(writer, "NSLayoutIdentifier", _layoutIdentifier);

    ObjectConverterSwapper::ConvertStaticMappings(writer, obj);
}

XIBObject* NSLayoutConstraint::substituteItemUnsupported(NIBWriter* writer, XIBObject* item){
    if (writer->_minimumDeploymentTarget < DEPLOYMENT_TARGET_IOS11 && (strcmp(item->_outputClassName, "UILayoutGuide") == 0)) {
        writer->_wasLimitedByDeplymentTarget = true;
        // constraint to layout guide that is not supported, replace them to view
        UILayoutGuide *guide = (UILayoutGuide*)item;
        if (guide->_owningView)
            return guide->_owningView;
    }
    
    return item;
}
