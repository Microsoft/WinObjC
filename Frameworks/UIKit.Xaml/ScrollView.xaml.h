﻿//******************************************************************************
//
// Copyright (c) Microsoft. All rights reserved.
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

// clang-format does not like C++/CX
// clang-format off
#pragma once

#include "ScrollView.g.h"
#include "Layer.xaml.h"
#include "ObjCXamlControls.h"

namespace UIKit {
namespace Xaml {

[Windows::Foundation::Metadata::WebHostHidden]
public ref class ScrollView sealed : public Private::CoreAnimation::ILayer
{
public:
    ScrollView();

    // Accessor for our Layer content; we create one on demand
    virtual property Windows::UI::Xaml::Controls::Image^ LayerContent {
        Windows::UI::Xaml::Controls::Image^ get();
    }

    // Accessor to check for exising Layer content
    virtual property bool HasLayerContent {
        bool get();
    }

    // Accessor for our SublayerCanvas
    virtual property Windows::UI::Xaml::Controls::Canvas^ SublayerCanvas {
        Windows::UI::Xaml::Controls::Canvas^ get();
    }

    // Accessor for the LayerProperty that manages the BorderBrush of this label
    virtual Private::CoreAnimation::LayerProperty^ GetBorderBrushProperty();

    // Accessor for the LayerProperty that manages the BorderThickness of this label
    virtual Private::CoreAnimation::LayerProperty^ GetBorderThicknessProperty();

internal:
    property Windows::UI::Xaml::Controls::ScrollViewer^ scrollViewer{
        Windows::UI::Xaml::Controls::ScrollViewer^ get();
    }

};

} /* Xaml*/
} /* UIKit*/

// clang-format on