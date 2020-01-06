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

#include "UILayoutGuide.h"
#include "NSLayoutConstraint.h"
#include <assert.h>

UILayoutGuide::UILayoutGuide() {
    _systemConstraints = new XIBArray();
}

void UILayoutGuide::InitFromXIB(XIBObject* obj) {
    // Outdated code do nothing
}

void UILayoutGuide::InitFromStory(XIBObject* obj) {
    _owningView = obj->_parent;
    _outputClassName = "UILayoutGuide";

    const char* key = getAttrib("key");
    if (key && strcmp(key, "safeArea") == 0) {
        // handle today only safe area
        NSLayoutConstraint* systemConstraintLeft = new NSLayoutConstraint();
        systemConstraintLeft->_firstItem = this;
        systemConstraintLeft->_firstAttribute = NSLayoutAttributeLeft;
        systemConstraintLeft->_secondItem = _owningView;
        systemConstraintLeft->_secondAttribute = NSLayoutAttributeLeft;
        systemConstraintLeft->_layoutIdentifier = "UIViewSafeAreaLayoutGuide-left";
        systemConstraintLeft->_outputClassName = "NSLayoutConstraint";
        systemConstraintLeft->_ignoreUIObject = true;

        NSLayoutConstraint* systemConstraintTop = new NSLayoutConstraint();
        systemConstraintTop->_firstItem = this;
        systemConstraintTop->_firstAttribute = NSLayoutAttributeTop;
        systemConstraintTop->_secondItem = _owningView;
        systemConstraintTop->_secondAttribute = NSLayoutAttributeTop;
        systemConstraintTop->_layoutIdentifier = "UIViewSafeAreaLayoutGuide-top";
        systemConstraintTop->_outputClassName = "NSLayoutConstraint";
        systemConstraintTop->_ignoreUIObject = true;

        NSLayoutConstraint* systemConstraintRight = new NSLayoutConstraint();
        systemConstraintRight->_firstItem = _owningView;
        systemConstraintRight->_firstAttribute = NSLayoutAttributeRight;
        systemConstraintRight->_secondItem = this;
        systemConstraintRight->_secondAttribute = NSLayoutAttributeRight;
        systemConstraintRight->_layoutIdentifier = "UIViewSafeAreaLayoutGuide-right";
        systemConstraintRight->_outputClassName = "NSLayoutConstraint";
        systemConstraintRight->_ignoreUIObject = true;

        NSLayoutConstraint* systemConstraintBottom = new NSLayoutConstraint();
        systemConstraintBottom->_firstItem = _owningView;
        systemConstraintBottom->_firstAttribute = NSLayoutAttributeBottom;
        systemConstraintBottom->_secondItem = this;
        systemConstraintBottom->_secondAttribute = NSLayoutAttributeBottom;
        systemConstraintBottom->_layoutIdentifier = "UIViewSafeAreaLayoutGuide-bottom";
        systemConstraintBottom->_outputClassName = "NSLayoutConstraint";
        systemConstraintBottom->_ignoreUIObject = true;

        _systemConstraints->AddMember(NULL, systemConstraintTop);
        _systemConstraints->AddMember(NULL, systemConstraintLeft);
        _systemConstraints->AddMember(NULL, systemConstraintRight);
        _systemConstraints->AddMember(NULL, systemConstraintBottom);
    }
}

void UILayoutGuide::ConvertStaticMappings(NIBWriter* writer, XIBObject* obj) {
    obj->AddOutputMember(writer, "UILayoutGuideOwningView", _owningView);
    if (_systemConstraints->count()) {
        // its safeArea, don't know what to export other cases as Xcode doesn't support this yet as at v9.2
        obj->AddString(writer, "UILayoutGuideIdentifier", "UIViewSafeAreaLayoutGuide");
        obj->AddBool(writer, "UILayoutGuideOwningViewIsLocked", true);
        obj->AddOutputMember(writer, "UILayoutGuideSystemConstraints", _systemConstraints);
    }

    ObjectConverter::ConvertStaticMappings(writer, obj);
}
