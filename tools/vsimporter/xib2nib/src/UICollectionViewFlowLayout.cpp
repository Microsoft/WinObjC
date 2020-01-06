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

#include "UICollectionViewFlowLayout.h"
#include <map>

typedef enum {
    UISectionInsetReferenceContent = 0,
    UISectionInsetReferenceSafeArea,
    UISectionInsetReferenceLayoutMargins
} UISectionInsetReference;

static std::map<std::string, UISectionInsetReference> storyToInsetReference = {
    { "safeArea", UISectionInsetReferenceSafeArea },
    { "layoutMargins", UISectionInsetReferenceLayoutMargins }
};

typedef enum {
    UIScrollDirectionVertical = 0,
    UIScrollDirectionHorizontal,
} UIScrollDirection;

static std::map<std::string, UIScrollDirection> storyToScrollDirrection = {
    { "vertical", UIScrollDirectionVertical },
    { "horizontal", UIScrollDirectionHorizontal }
};


UICollectionViewFlowLayout::UICollectionViewFlowLayout() {
    _scrollDirection = UIScrollDirectionVertical;
    _minimumLineSpacing = -1;
    _minimumInteritemSpacing = -1;
    _customClass = NULL;
    _customModule = NULL;
    _sectionInsetReference = UISectionInsetReferenceContent;
}

void UICollectionViewFlowLayout::InitFromXIB(XIBObject* obj) {
    // Outdated code do nothing
}

void UICollectionViewFlowLayout::InitFromStory(XIBObject* obj) {
    obj->PopulateSizeFromStoryboard("itemSize", _itemSize);
    obj->PopulateSizeFromStoryboard("headerReferenceSize", _headerReferenceSize);
    obj->PopulateSizeFromStoryboard("footerReferenceSize", _footerReferenceSize);
    obj->PopulateInsetsFromStoryboard("sectionInset", _sectionInset);

    _customClass = obj->getAttrAndHandle("customClass");
    if (_customClass) {
        const char* module = obj->getAttrAndHandle("customModule");;
        if (module) {
            // its swift, mange class name with module
            char buf[128]; // should be big enough
            snprintf(buf, 128, "_TtC%zu%s%zu%s", strlen(module), module, strlen(_customClass), _customClass);
            _customClass = strdup(buf);
        }
    }

    const char* attr;
    if ((attr = obj->getAttrAndHandle("minimumLineSpacing"))) {
        _minimumLineSpacing = strtof(attr, NULL);
    }

    if ((attr = obj->getAttrAndHandle("minimumInteritemSpacing"))) {
        _minimumInteritemSpacing = strtof(attr, NULL);
    }

    if ((attr = obj->getAttrAndHandle("sectionInsetReference"))) {
        if (storyToInsetReference.find(attr) != storyToInsetReference.end()) {
            _sectionInsetReference = storyToInsetReference[attr];
        }
    }

    if ((attr = obj->getAttrAndHandle("scrollDirection"))) {
        if (storyToScrollDirrection.find(attr) != storyToScrollDirrection.end()) {
            _scrollDirection = storyToScrollDirrection[attr];
        }
    }
}

void UICollectionViewFlowLayout::ConvertStaticMappings(NIBWriter* writer, XIBObject* obj) {
    _outputClassName = "UICollectionViewFlowLayout";

    if (_itemSize.IsValid())
        obj->AddData(writer, "UIItemSize", _itemSize);
    
    if (_headerReferenceSize.IsValid())
        obj->AddData(writer, "UIHeaderReferenceSize", _headerReferenceSize);

    if (_footerReferenceSize.IsValid())
        obj->AddData(writer, "UIFooterReferenceSize", _footerReferenceSize);

    if (_sectionInset.IsValid())
        obj->AddData(writer, "UISectionInset", _sectionInset);
    
    if (_customClass) {
        obj->AddString(writer, "UIClassName", _customClass);
        obj->AddString(writer, "UIOriginalClassName", "UICollectionViewLayout");
    }

    if (_minimumLineSpacing >= 0)
        AddOutputMember(writer, "UILineSpacing", new XIBObjectFloat(_minimumLineSpacing));

    if (_minimumInteritemSpacing >= 0)
        AddOutputMember(writer, "UIInteritemSpacing", new XIBObjectFloat(_minimumInteritemSpacing));
    
    if (_scrollDirection != UIScrollDirectionVertical)
        AddInt(writer, "UIScrollDirection", _scrollDirection);
    
    if (_sectionInsetReference != UISectionInsetReferenceContent)
        AddInt(writer, "UISectionInsetReference", _sectionInsetReference);
    
    ObjectConverter::ConvertStaticMappings(writer, obj);
}
