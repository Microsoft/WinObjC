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

#include <assert.h>
#include "UIStoryboardSegue.h"
#include "UIViewController.h"

UIStoryboardSegue::UIStoryboardSegue() {
    _destination = NULL;
    _type = segueRelationship;
    _identifier = NULL;
    _actionName = NULL;
}

void UIStoryboardSegue::InitFromXIB(XIBObject* obj) {
    ObjectConverter::InitFromXIB(obj);
}

void UIStoryboardSegue::InitFromStory(XIBObject* obj) {
    ObjectConverter::InitFromStory(obj);
    _destination = getAttrAndHandle("destination");
    if (_destination) {
        // IMPORTANT: Commenting out the next few lines because it this blocks segue handling when NIB filenames are prefixed with
        // "UIViewController-".
        //            This prefix is prepended generated under the IBTool (compatibility purposes) but it's not required by
        //            WinObjC-generated usage.
    }

    _identifier = getAttrAndHandle("identifier");

    const char* pKind = getAttrib("kind");
    if (pKind) {
        bool isHandled = true;
        if (strcmp(pKind, "modal") == 0) {
            _type = segueModal;
            _outputClassName = "UIStoryboardModalSegueTemplate";
        } else if (strcmp(pKind, "push") == 0) {
            _type = seguePush;
            _outputClassName = "UIStoryboardPushSegueTemplate";
        } else if (strcmp(pKind, "relationship") == 0) {
            _type = segueRelationship;
        } else if (strcmp(pKind, "show") == 0) {
            _type = segueShow;
            _outputClassName = "UIStoryboardShowSegueTemplate";
            _actionName = "showViewController:sender:";
        } else if (strcmp(pKind, "showDetail") == 0) {
            _type = segueShowDetails;
            _outputClassName = "UIStoryboardShowSegueTemplate";
            _actionName = "showDetailViewController:sender:";
        } else if (strcmp(pKind, "presentation") == 0) {
            _type = seguePresentModally;
            _outputClassName = "UIStoryboardPresentationSegueTemplate";
        } else if (strcmp(pKind, "popoverPresentation") == 0) {
            _type = seguePresentAsPopover;
            _outputClassName = "UIStoryboardPopoverPresentationSegueTemplate";
        } else if (strcmp(pKind, "custom") == 0) {
            _type = segueCustom;
            _outputClassName = "UIStoryboardSegueTemplate";
        } else if (strcmp(pKind, "replace") == 0) {
            _type = segueCustom;
            _outputClassName = "UIStoryboardPushSegueTemplate";
        } else {
            _type = segueUnsupported;
            isHandled = false;
        }

        if (isHandled) {
            getAttrAndHandle("kind");
        }
    }
}

void UIStoryboardSegue::ConvertStaticMappings(NIBWriter* writer, XIBObject* obj) {
    ObjectConverter::ConvertStaticMappings(writer, obj);
    AddString(writer, "UIIdentifier", _identifier);

    // find story view controller by id and try to use it storyboardIdentifier if set as destination
    XIBObject* controller = XIBObject::findReference(_destination);
    UIViewController* uiViewController = dynamic_cast<UIViewController*>(controller);
    if (uiViewController && uiViewController->_storyboardIdentifier)
        AddString(writer, "UIDestinationViewControllerIdentifier", uiViewController->_storyboardIdentifier);
    else

        AddString(writer, "UIDestinationViewControllerIdentifier", _destination);
    if (_actionName != NULL)
        AddString(writer, "UIActionName", _actionName);
}
