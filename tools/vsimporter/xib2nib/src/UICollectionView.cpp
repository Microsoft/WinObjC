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

#include "UICollectionView.h"
#include "UICollectionViewFlowLayout.h"

UICollectionView::UICollectionView() {
    _collectionViewLayout = NULL;
}

void UICollectionView::InitFromXIB(XIBObject* obj) {
    UIScrollView::InitFromXIB(obj);

    obj->_outputClassName = "UICollectionView";
}

void UICollectionView::InitFromStory(XIBObject* obj) {
    UIScrollView::InitFromStory(obj);

    _collectionViewLayout = (UICollectionViewFlowLayout*)obj->FindMember("collectionViewLayout");
    obj->_outputClassName = "UICollectionView";
}

void UICollectionView::ConvertStaticMappings(NIBWriter* writer, XIBObject* obj) {
    writer->_allUIObjects->AddMember(NULL, this);
    
    if (_collectionViewLayout)
        AddOutputMember(writer , "UICollectionLayout", _collectionViewLayout);
        
    UIScrollView::ConvertStaticMappings(writer, obj);
}

ObjectConverter* UICollectionView::Clone() {
    return new UICollectionView();
}
