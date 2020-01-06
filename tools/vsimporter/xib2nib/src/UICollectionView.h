#pragma once
#include "UIScrollView.h"

class UICollectionViewFlowLayout;

class UICollectionView : public UIScrollView {
private:
public:
    UICollectionViewFlowLayout *_collectionViewLayout;
    
    UICollectionView();
    virtual void InitFromXIB(XIBObject* obj);
    virtual void InitFromStory(XIBObject* obj);
    virtual void ConvertStaticMappings(NIBWriter* writer, XIBObject* obj);

    ObjectConverter* Clone();
};
