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

#include "UIViewController.h"
#include "UIStoryboardSegue.h"
#include "UINavigationItem.h"
#include "UITabBarItem.h"
#include <assert.h>

static PropertyMapper propertyMappings[] = {
    {"IBUINibName", "UINibName", NULL},
    {"IBUIResizesToFullScreen", "UIResizesToFullScreen", NULL},
    {"IBUITitle", "UITitle", NULL},
};

static const int numPropertyMappings = sizeof(propertyMappings) / sizeof(PropertyMapper);
viewControllerList UIViewController::_viewControllerNames;

UIViewController::UIViewController() {
    _childViewControllers = new XIBArray();
    _viewControllers = new XIBArray();
    _parentViewController = NULL;
    _view = NULL;
    _navigationItem = NULL;
    _tabBarItem = NULL;
    _resizesToFullSize = true;
    _storyboardIdentifier = NULL;
}

void UIViewController::InitFromXIB(XIBObject* obj) {
    ObjectConverterSwapper::InitFromXIB(obj);
    _view = (UIView*)obj->FindMember("IBUIView");
    _tabBarItem = (UITabBarItem*)obj->FindMember("IBUITabBarItem");
    _navigationItem = (UINavigationItem*)obj->FindMember("IBUINavigationItem");
    _resizesToFullSize = obj->GetBool("IBUIAutoresizesArchivedViewToFullSize", true);

    XIBArray* viewControllers = (XIBArray*)obj->FindMember("IBUIViewControllers");
    if (viewControllers) {
        for (int i = 0; i < viewControllers->count(); i++) {
            XIBObject* curObj = viewControllers->objectAtIndex(i);
            ((UIViewController*)curObj)->_parentViewController = this;
            _childViewControllers->AddMember(NULL, curObj);
            _viewControllers->AddMember(NULL, curObj);
        }
    }

    _outputClassName = "UIViewController";
}

void UIViewController::InitFromStory(XIBObject* obj) {
    ObjectConverterSwapper::InitFromStory(obj);
    _view = (UIView*)obj->FindMemberAndHandle("view");

    _viewControllerNames.push_back(_id);

    if (getAttrib("storyboardIdentifier")) {
        _storyboardIdentifier = getAttrAndHandle("storyboardIdentifier");
    }

    if (_connections) {
        for (int i = 0; i < _connections->count(); i++) {
            XIBObject* curObj = _connections->objectAtIndex(i);
            if (strcmp(curObj->_className, "segue") == 0) {
                const char* pDest = curObj->getAttrAndHandle("destination");
                const char* pKind = curObj->getAttrAndHandle("kind");

                XIBObject* newController = findReference(pDest);

                if (newController && strcmp(pKind, "relationship") == 0) {
                    ((UIViewController*)newController)->_parentViewController = this;
                    _childViewControllers->AddMember(NULL, newController);
                    _viewControllers->AddMember(NULL, newController);
                }
            }
        }
    }

    _tabBarItem = (UITabBarItem*)FindMemberAndHandle("tabBarItem");
    _navigationItem = (UINavigationItem*)obj->FindMemberAndHandle("navigationItem");

    _outputClassName = "UIViewController";
}

void UIViewController::Awaken() {
}

void ScanForSegues(XIBArray* out, XIBObject* obj) {
    for (memberList::iterator cur = obj->_members.begin(); cur != obj->_members.end(); cur++) {
        XIBMember* curMember = *cur;

        if (curMember->_obj->_className && strcmp(curMember->_obj->_className, "segue") == 0) {
            UIStoryboardSegue* curSegue = (UIStoryboardSegue*)curMember->_obj;

            if (curSegue->_type != segueUnsupported) {
                curSegue->_parent = out;
                out->AddMember(NULL, curMember->_obj);
            }
        }

        ScanForSegues(out, curMember->_obj);
    }
}

void UIViewController::ConvertStaticMappings(NIBWriter* writer, XIBObject* obj) {
    Map(writer, obj, propertyMappings, numPropertyMappings);

    XIBArray* segueTemplates = new XIBArray();

    if (_storyboardIdentifier)
        AddString(writer, "UIStoryboardIdentifier", _storyboardIdentifier);
    if (_tabBarItem)
        AddOutputMember(writer, "UITabBarItem", _tabBarItem);
    if (_navigationItem)
        AddOutputMember(writer, "UINavigationItem", _navigationItem);
    if (!_resizesToFullSize)
        AddBool(writer, "UIAutoresizesArchivedViewToFullSize", _resizesToFullSize);
    if (_view) {
        if (!_isStory) {
            AddOutputMember(writer, "UIView", _view);
        } else {
            ScanForSegues(segueTemplates, this);

            // This would cause a crash if we're not really a storyboard (i.e. input file has extension .storyboard)
            // Currently we set both XIB3 and Storyboard with _isStory == true when calling XIBObject::ScanStoryObjects()
            // which may trickle down into this control. IsStoryBoardConversion() returns true if we're really a .storyboard input file
            if (IsStoryboardConversion()) {
                XIBDictionary* externalObjects = new XIBDictionary();

                char szNibName[255];
                sprintf(szNibName, "%s-view-%s", _id, _view->_id);
                AddString(writer, "UINibName", szNibName);

                char szOutputName[255];
                sprintf(szOutputName, "%s.nib", szNibName);
                printf("Writing %s\n", GetOutputFilename(szOutputName).c_str());
                FILE* fpOut = fopen(GetOutputFilename(szOutputName).c_str(), "wb");

                NIBWriter* viewWriter = new NIBWriter(fpOut, externalObjects, _view);
                viewWriter->ExportObject(_view);

                XIBObject* ownerProxy = viewWriter->AddProxy("IBFilesOwner");
                XIBObject* firstResponderProxy = viewWriter->AddProxy("IBFirstResponder");

                //  Add view connection
                viewWriter->AddOutletConnection(ownerProxy, _view, "view");

                viewWriter->WriteObjects();
                fclose(fpOut);

                if (externalObjects->_members.size() > 1) {
                    AddOutputMember(writer, "UIExternalObjectsTableForViewLoading", externalObjects);
                }
            }
        }
    }
    if (_parentViewController) {
        AddOutputMember(writer, "UIParentViewController", _parentViewController);
    }
    if (_isStory) {
        XIBObject* storyboard = writer->AddProxy("UIStoryboardPlaceholder");
        writer->AddOutletConnection(this, storyboard, "storyboard");

        if (segueTemplates->count() > 0) {
            AddOutputMember(writer, "UIStoryboardSegueTemplates", segueTemplates);

            for (int i = 0; i < segueTemplates->count(); i++) {
                UIStoryboardSegue* curSegue = (UIStoryboardSegue*)segueTemplates->objectAtIndex(i);

                writer->AddOutletConnection(curSegue, this, "viewController");
                writer->_allUIObjects->AddMember(NULL, curSegue);
            }
        }
    }
    if (_childViewControllers->count() > 0) {
        AddOutputMember(writer, "UIChildViewControllers", _childViewControllers);
    }
    if (_viewControllers->count() > 0) {
        AddOutputMember(writer, "UIViewControllers", _viewControllers);
    }

    ObjectConverterSwapper::ConvertStaticMappings(writer, obj);
}
