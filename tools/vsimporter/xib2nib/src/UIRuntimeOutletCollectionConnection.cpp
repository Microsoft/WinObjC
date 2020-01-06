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

#include "UIRuntimeOutletCollectionConnection.h"
#include <assert.h>

UIRuntimeOutletCollectionConnection::UIRuntimeOutletCollectionConnection() {
    _outputClassName = "UIRuntimeOutletCollectionConnection";
    _className = "UIRuntimeOutletCollectionConnection";
    _collectionClassName = NULL;
    _destinations = NULL;
    _addsToExisting = false;
}

void UIRuntimeOutletCollectionConnection::InitFromXIB(XIBObject* obj) {
    ObjectConverter::InitFromXIB(obj);

    _outputClassName = "UIRuntimeOutletCollectionConnection";
    _label = obj->GetString("label", NULL);
    _source = obj->FindMember("source");
    XIBObject* destObj = obj->FindMember("destination");
    if (destObj) {
        _destinations = new XIBArray();
        _destinations->_className = "NSMutableArray";
        _destinations->AddMember(NULL, destObj);
    }

    _collectionClassName = obj->GetString("cachedDesigntimeCollectionClassName", NULL);
    _addsToExisting = obj->GetBool("addsContentToExistingCollection", false);
}

void UIRuntimeOutletCollectionConnection::InitFromStory(XIBObject* obj) {
    ObjectConverter::InitFromStory(obj);

    _outputClassName = "UIRuntimeOutletCollectionConnection";

    _collectionClassName = "NSArray";
    _addsToExisting = true;

    //  Find the destination we're to plug into
    const char* destId = getAttrAndHandle("destination");
    _label = getAttrAndHandle("property");
    _source = _parent->_parent;

    ObjectConverter* destObj = (ObjectConverter*)findReference(destId);
    if (destObj) {
        _destinations = new XIBArray();
        _destinations->_className = "NSMutableArray";
        _destinations->AddMember(NULL, destObj);
    }

    //  Check if the destination property is part of our heirarchy
    XIBObject* curObj = this;
    while (curObj) {
        if (curObj == destObj) {
            destObj = (ObjectConverter*)_source;
            break;
        }
        curObj = curObj->_parent;
    }
    if (!destObj->_connectedObjects)
        destObj->_connectedObjects = new XIBArray();

    destObj->_connectedObjects->AddMember(NULL, this);
}

void UIRuntimeOutletCollectionConnection::ConvertStaticMappings(NIBWriter* writer, XIBObject* obj) {
    ObjectConverter::ConvertStaticMappings(writer, obj);
    AddString(writer, "UILabel", _label);
    AddOutputMember(writer, "UISource", _source);
    AddOutputMember(writer, "UIDestination", _destinations);
    AddString(writer, "runtimeCollectionClassName", _collectionClassName);
    AddBool(writer, "addsContentToExistingCollection", _addsToExisting);
}

void UIRuntimeOutletCollectionConnection::addDestinations(XIBArray *objs) {
    if (!objs || objs->count() == 0)
        return;
    if (!_destinations) {
        _destinations = new XIBArray();
        _destinations->_className = "NSMutableArray";
    }

    for (int i = 0; i < objs->count(); i++)
        _destinations->AddMember(NULL, objs->objectAtIndex(i));
}
