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
#include "UIColor.h"

typedef enum {
    UIViewAutoresizingNone = 0,
    UIViewAutoresizingFlexibleLeftMargin = 1 << 0,
    UIViewAutoresizingFlexibleWidth = 1 << 1,
    UIViewAutoresizingFlexibleRightMargin = 1 << 2,
    UIViewAutoresizingFlexibleTopMargin = 1 << 3,
    UIViewAutoresizingFlexibleHeight = 1 << 4,
    UIViewAutoresizingFlexibleBottomMargin = 1 << 5
} UIViewAutoresizing;

typedef enum {
    UIViewContentModeScaleToFill,
    UIViewContentModeScaleAspectFit,
    UIViewContentModeScaleAspectFill,
    UIViewContentModeRedraw,
    UIViewContentModeCenter,
    UIViewContentModeTop,
    UIViewContentModeBottom,
    UIViewContentModeLeft,
    UIViewContentModeRight,
    UIViewContentModeTopLeft,
    UIViewContentModeTopRight,
    UIViewContentModeBottomLeft,
    UIViewContentModeBottomRight,
} UIViewContentMode;

class UIView : public ObjectConverterSwapper {
public:
    XIBArray* _subviews;
    XIBArray* _constraints;
    XIBArray* _layoutGuides;
    UIColor* _backgroundColor;
    UIRect _bounds;
    UIRect _contentStretch;
    UIPoint _center;
    bool _autoresizeSubviews;
    bool _hidden;
    bool _translatesAutoresizeToConstraints;
    int _autoresizingMask;
    int _contentMode;
    bool _opaque;
    bool _enabled;
    bool _multipleTouchEnabled;
    bool _clipsToBounds;
    bool _userInteractionDisabled;
    bool _clearsContextBeforeDrawing;
    int _tag;
    int _horizontalHuggingPriority;
    int _verticalHuggingPriority;
    int _horizontalCompressionResistancePriority;
    int _verticalCompressionResistancePriority;

public:
    UIView();

    virtual void InitFromXIB(XIBObject* obj);
    virtual void InitFromStory(XIBObject* obj);
    virtual void ConvertStaticMappings(NIBWriter* writer, XIBObject* obj);

    UIRect getFrame();
    void setFrame(UIRect frame);
};
