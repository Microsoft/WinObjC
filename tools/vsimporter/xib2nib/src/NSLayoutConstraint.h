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

#pragma once

#include "ObjectConverter.h"

enum {
    NSLayoutPriorityRequired = 1000,
    NSLayoutPriorityDefaultHigh = 750,
    NSLayoutPriorityDragThatCanResizeWindow = 510,
    NSLayoutPriorityWindowSizeStayPut = 500,
    NSLayoutPriorityDragThatCannotResizeWindow = 490,
    NSLayoutPriorityDefaultLow = 250,
    NSLayoutPriorityFittingSizeCompression = 50,
};

typedef float NSLayoutPriority;

typedef enum {
    NSLayoutAttributeLeft = 1,
    NSLayoutAttributeRight,
    NSLayoutAttributeTop,
    NSLayoutAttributeBottom,
    NSLayoutAttributeLeading,
    NSLayoutAttributeTrailing,
    NSLayoutAttributeWidth,
    NSLayoutAttributeHeight,
    NSLayoutAttributeCenterX,
    NSLayoutAttributeCenterY,
    NSLayoutAttributeBaseline,

    NSLayoutAttributeLastBaseline = NSLayoutAttributeBaseline,
    NSLayoutAttributeFirstBaseline,

    NSLayoutAttributeLeftMargin,
    NSLayoutAttributeRightMargin,
    NSLayoutAttributeTopMargin,
    NSLayoutAttributeBottomMargin,
    NSLayoutAttributeLeadingMargin,
    NSLayoutAttributeTrailingMargin,
    NSLayoutAttributeCenterXWithinMargins,
    NSLayoutAttributeCenterYWithinMargins,

    NSLayoutAttributeNotAnAttribute = 0
} NSLayoutAttribute;

typedef enum {
    NSLayoutRelationLessThanOrEqual = -1,
    NSLayoutRelationEqual = 0,
    NSLayoutRelationGreaterThanOrEqual = 1,
} NSLayoutRelation;

class NSLayoutConstraint : public ObjectConverterSwapper {
public:
    XIBObject* _firstItem;
    XIBObject* _secondItem;
    int _firstAttribute;
    int _secondAttribute;
    int _relation;
    double _multiplier;
    int _priority;
    double _constant;
    double _symbolicConstant;
    bool _hasSymbolicConstant;
    const char* _layoutIdentifier;
    bool _placeholder;
    bool _exportDefaultValues;

public:
    NSLayoutConstraint();

    virtual void InitFromXIB(XIBObject* obj);
    virtual void InitFromStory(XIBObject* obj);
    virtual void Awaken();
    virtual void ConvertStaticMappings(NIBWriter* writer, XIBObject* obj);
private:
    XIBObject* substituteItemUnsupported(NIBWriter* writer, XIBObject* item);
};
