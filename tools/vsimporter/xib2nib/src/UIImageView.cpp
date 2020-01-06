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

#include "UIImageView.h"
#include "UICustomResource.h"

static PropertyMapper propertyMappings[] = {
    {"IBUIImage", "UIImage", NULL}
};
static const int numPropertyMappings = sizeof(propertyMappings) / sizeof(PropertyMapper);

UIImageView::UIImageView() {
    _image = NULL;
}

void UIImageView::InitFromXIB(XIBObject* obj) {
    UIView::InitFromXIB(obj);

    obj->_outputClassName = "UIImageView";
}

void UIImageView::InitFromStory(XIBObject* obj) {
    UIView::InitFromStory(obj);

    _image = NULL;
    const char* imageName = getAttrAndHandle("image");
    if (imageName) {
        UICustomResource* image = new UICustomResource();
        image->_imageName = imageName;
        _image = image;
    }

    obj->_outputClassName = "UIImageView";
}

void UIImageView::ConvertStaticMappings(NIBWriter* writer, XIBObject* obj) {
    Map(writer, obj, propertyMappings, numPropertyMappings);
    UIView::ConvertStaticMappings(writer, obj);
    if (_image)
        AddOutputMember(writer, "UIImage", _image);
}
