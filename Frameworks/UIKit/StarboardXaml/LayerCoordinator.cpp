//******************************************************************************
//
// Copyright (c) Microsoft Corporation. All rights reserved.
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

#include "LayerCoordinator.h"
#include "LayerProxy.h"

#include <ErrorHandling.h>

#include <algorithm>
#include <functional>
#include <map>

using namespace Platform;
using namespace UIKit::Xaml::Private::CoreAnimation;
using namespace Windows::Foundation;
using namespace Windows::Storage::Streams;
using namespace Windows::UI::Xaml;
using namespace Windows::UI::Xaml::Controls;
using namespace Windows::UI::Xaml::Media;
using namespace Windows::UI::Xaml::Media::Animation;
using namespace Windows::UI::Xaml::Media::Imaging;

static const wchar_t* TAG = L"LayerCoordinator";

static const bool DEBUG_ALL = false;
static const bool DEBUG_POSITION = DEBUG_ALL || false;
static const bool DEBUG_ANCHORPOINT = DEBUG_ALL || false;
static const bool DEBUG_SIZE = DEBUG_ALL || false;
static const bool DEBUG_GRAVITY = DEBUG_ALL || false;

namespace CoreAnimation {

// Provides support for setting, animating and retrieving values.
using ApplyAnimationFunction = void (*)(FrameworkElement^ target, Storyboard^ storyboard, DoubleAnimation^ properties, Object^ fromValue, Object^ toValue);
using ApplyTransformFunction = void (*)(FrameworkElement^ target, Object^ toValue);
using GetCurrentValueFunction = Object^ (*)(FrameworkElement^ target);

struct AnimatableProperty {
public:
    ApplyAnimationFunction AnimateValue;
    ApplyTransformFunction SetValue;
    GetCurrentValueFunction GetValue;

    AnimatableProperty(const ApplyAnimationFunction& animate, const ApplyTransformFunction& set, const GetCurrentValueFunction& get) {
        AnimateValue = animate;
        SetValue = set;
        GetValue = get;
    };

    AnimatableProperty() {
    }
};

std::map<std::string, AnimatableProperty> s_animatableProperties = {
    { "position.x",
      AnimatableProperty{
          ApplyAnimationFunction{[](FrameworkElement^ target, Storyboard^ storyboard, DoubleAnimation^ properties, Object^ from, Object^ to) {
              // Animate the PositionTransform
              LayerCoordinator::AddAnimation(
                  LayerCoordinator::GetPositionXTransformPath(),
                  target,
                  storyboard,
                  properties,
                  from,
                  to);
          }},
          ApplyTransformFunction{[](FrameworkElement^ target, Object^ toValue) {
              auto positionX = static_cast<double>(toValue);

              // Store PositionX
              LayerCoordinator::SetPositionX(target, static_cast<float>(positionX));

              // Update the PositionTransform
              LayerCoordinator::GetPositionTransform(target)->X = positionX;
          }},
          GetCurrentValueFunction{[](FrameworkElement^ target) -> Object^ {
              return LayerCoordinator::GetPositionTransform(target)->X;
          }}} },
    { "position.y",
      AnimatableProperty{
          ApplyAnimationFunction{[](FrameworkElement^ target, Storyboard^ storyboard, DoubleAnimation^ properties, Object^ from, Object^ to) {
              // Animate the PositionTransform
              LayerCoordinator::AddAnimation(
                  LayerCoordinator::GetPositionYTransformPath(),
                  target,
                  storyboard,
                  properties,
                  from,
                  to);
          }},
          ApplyTransformFunction{[](FrameworkElement^ target, Object^ toValue) {
              auto positionY = static_cast<double>(toValue);

              // Store PositionY
              LayerCoordinator::SetPositionY(target, static_cast<float>(positionY));

              // Update the PositionTransform
              LayerCoordinator::GetPositionTransform(target)->Y = positionY;
          }},
          GetCurrentValueFunction{[](FrameworkElement^ target) -> Object^ {
              return LayerCoordinator::GetPositionTransform(target)->Y;
          }}} },
    { "position",
      AnimatableProperty{
          ApplyAnimationFunction{[](FrameworkElement^ target, Storyboard^ storyboard, DoubleAnimation^ properties, Object^ from, Object^ to) {
              s_animatableProperties["position.x"].AnimateValue(target,
                                                            storyboard,
                                                            properties,
                                                            from ? (Object^)((Point)from).X : nullptr,
                                                            (double)((Point)to).X);
              s_animatableProperties["position.y"].AnimateValue(target,
                                                            storyboard,
                                                            properties,
                                                            from ? (Object^)((Point)from).Y : nullptr,
                                                            (double)((Point)to).Y);
          }},
          ApplyTransformFunction{[](FrameworkElement^ target, Object^ toValue) {
              s_animatableProperties["position.x"].SetValue(target, (double)((Point)toValue).X);
              s_animatableProperties["position.y"].SetValue(target, (double)((Point)toValue).Y);
          }},
          GetCurrentValueFunction{[](FrameworkElement^ target) -> Object^ {
              // Unbox x and y values as doubles, before casting them to floats
              return Point((float)(double)LayerCoordinator::GetValue(target, "position.x"),
                           (float)(double)LayerCoordinator::GetValue(target, "position.y"));
          }}} },
    { "origin.x",
      AnimatableProperty{
          ApplyAnimationFunction{[](FrameworkElement^ target, Storyboard^ storyboard, DoubleAnimation^ properties, Object^ from, Object^ to) {
              // Zero out negative and null values
              auto fromValue = from ? std::max<double>(0.0, static_cast<double>(from)) : 0.0;
              auto toValue = to ? std::max<double>(0.0, static_cast<double>(to)) : 0.0;

              LayerCoordinator::AddAnimation(
                  LayerCoordinator::GetOriginXTransformPath(),
                  target,
                  storyboard,
                  properties,
                  from ? static_cast<Object^>(-fromValue) : nullptr,
                  -toValue);

              // Animate the Clip transform
              if (target->Clip) {
                  LayerCoordinator::AddAnimation(
                      "(UIElement.Clip).(Transform).(TranslateTransform.X)",
                      target,
                      storyboard,
                      properties,
                      from ? static_cast<Object^>(fromValue) : nullptr,
                      toValue);
              }
          }},
          ApplyTransformFunction{[](FrameworkElement^ target, Object^ toValue) {
              auto targetValue = static_cast<double>(toValue);

              // Store the new OriginX value
              LayerCoordinator::SetOriginX(target, static_cast<float>(targetValue));

              // Update the OriginTransform
              LayerCoordinator::GetOriginTransform(target)->X = -targetValue;

              // Update the Clip transform
              if (target->Clip) {
                  ((TranslateTransform^)target->Clip->Transform)->X = targetValue;
              }
          }},
          GetCurrentValueFunction{[](FrameworkElement^ target) -> Object^ {
              return -(LayerCoordinator::GetOriginTransform(target)->X);
          }}} },
    { "origin.y",
      AnimatableProperty{
          ApplyAnimationFunction{[](FrameworkElement^ target, Storyboard^ storyboard, DoubleAnimation^ properties, Object^ from, Object^ to) {
              // Zero out negative and null values
              auto fromValue = from ? std::max<double>(0.0, static_cast<double>(from)) : 0.0;
              auto toValue = to ? std::max<double>(0.0, static_cast<double>(to)) : 0.0;

              LayerCoordinator::AddAnimation(
                  LayerCoordinator::GetOriginYTransformPath(),
                  target,
                  storyboard,
                  properties,
                  from ? static_cast<Object^>(-fromValue) : nullptr,
                  -toValue);

              // Animate the Clip transform
              if (target->Clip) {
                  LayerCoordinator::AddAnimation(
                      "(UIElement.Clip).(Transform).(TranslateTransform.Y)",
                      target,
                      storyboard,
                      properties,
                      from ? static_cast<Object^>(fromValue) : nullptr,
                      toValue);
              }
          }},
          ApplyTransformFunction{[](FrameworkElement^ target, Object^ toValue) {
              auto targetValue = static_cast<double>(toValue);

              // Store the new OriginY value
              LayerCoordinator::SetOriginY(target, static_cast<float>(targetValue));

              // Update the OriginTransform
              LayerCoordinator::GetOriginTransform(target)->Y = -targetValue;

              // Update the Clip transform
              if (target->Clip) {
                  ((TranslateTransform^)target->Clip->Transform)->Y = targetValue;
              }
          }},
          GetCurrentValueFunction{[](FrameworkElement^ target) -> Object^ {
              return -(LayerCoordinator::GetOriginTransform(target)->Y);
          }}} },
    { "origin",
      AnimatableProperty{
          ApplyAnimationFunction{[](FrameworkElement^ target, Storyboard^ storyboard, DoubleAnimation^ properties, Object^ from, Object^ to) {
              s_animatableProperties["origin.x"].AnimateValue(target,
                                                          storyboard,
                                                          properties,
                                                          (from != nullptr) ? (Object^)((Point)from).X : nullptr,
                                                          (double)((Point)to).X);
              s_animatableProperties["origin.y"].AnimateValue(target,
                                                          storyboard,
                                                          properties,
                                                          (from != nullptr) ? (Object^)((Point)from).Y : nullptr,
                                                          (double)((Point)to).Y);
          }},
          ApplyTransformFunction{[](FrameworkElement^ target, Object^ toValue) {
              s_animatableProperties["origin.x"].SetValue(target, (double)((Point)toValue).X);
              s_animatableProperties["origin.y"].SetValue(target, (double)((Point)toValue).Y);
          }},
          GetCurrentValueFunction{[](FrameworkElement^ target) -> Object^ {
              // Unbox x and y values as doubles, before casting them to floats
              return Point((float)(double)LayerCoordinator::GetValue(target, "origin.x"),
                           (float)(double)LayerCoordinator::GetValue(target, "origin.y"));
          }}} },
    { "anchorPoint.x",
      AnimatableProperty{
          ApplyAnimationFunction{[](FrameworkElement^ target, Storyboard^ storyboard, DoubleAnimation^ properties, Object^ from, Object^ to) {
              // Zero out negative and null values
              auto fromValue = from ? std::max<double>(0.0, static_cast<double>(from)) : 0.0;
              auto toValue = to ? std::max<double>(0.0, static_cast<double>(to)) : 0.0;

              // Calculate values to animate on the AnchorPoint transform
              fromValue = -target->Width * fromValue;
              toValue = -target->Width * toValue;
              LayerCoordinator::AddAnimation(
                  LayerCoordinator::GetAnchorXTransformPath(),
                  target,
                  storyboard,
                  properties,
                  from ? static_cast<Object^>(fromValue) : nullptr,
                  toValue);
          }},
          ApplyTransformFunction{[](FrameworkElement^ target, Object^ toValue) {
              // Store the new anchorPointX value
              auto anchorPointX = static_cast<double>(toValue);
              LayerCoordinator::SetAnchorPointX(target, static_cast<float>(anchorPointX));

              // Calculate and update the AnchorPoint transform
              double destX = -target->Width * anchorPointX;
              LayerCoordinator::GetAnchorTransform(target)->X = destX;
          }},
          GetCurrentValueFunction{[](FrameworkElement^ target) -> Object^ {
              return static_cast<double>(LayerCoordinator::GetAnchorPointX(target));
          }}} },
    { "anchorPoint.y",
      AnimatableProperty{
          ApplyAnimationFunction{[](FrameworkElement^ target, Storyboard^ storyboard, DoubleAnimation^ properties, Object^ from, Object^ to) {
              // Zero out negative and null values
              auto fromValue = from ? std::max<double>(0.0, static_cast<double>(from)) : 0.0;
              auto toValue = to ? std::max<double>(0.0, static_cast<double>(to)) : 0.0;

              // Calculate values to animate on the AnchorPoint transform
              fromValue = -target->Height * fromValue;
              toValue = -target->Height * toValue;
              LayerCoordinator::AddAnimation(
                  LayerCoordinator::GetAnchorYTransformPath(),
                  target,
                  storyboard,
                  properties,
                  from ? static_cast<Object^>(fromValue) : nullptr,
                  toValue);
          }},
          ApplyTransformFunction{[](FrameworkElement^ target, Object^ toValue) {
              // Store the new anchorPointY value
              auto anchorPointY = static_cast<double>(toValue);
              LayerCoordinator::SetAnchorPointY(target, static_cast<float>(anchorPointY));

              // Calculate and update the AnchorPoint transform
              double destY = -target->Height * anchorPointY;
              LayerCoordinator::GetAnchorTransform(target)->Y = destY;
          }},
          GetCurrentValueFunction{[](FrameworkElement^ target) -> Object^ {
              return static_cast<double>(LayerCoordinator::GetAnchorPointY(target));
          }}} },
    { "anchorPoint",
      AnimatableProperty{
          ApplyAnimationFunction{[](FrameworkElement^ target, Storyboard^ storyboard, DoubleAnimation^ properties, Object^ from, Object^ to) {
              s_animatableProperties["anchorPoint.x"].AnimateValue(target,
                                                               storyboard,
                                                               properties,
                                                               (from != nullptr) ? (Object^)((Point)from).X : nullptr,
                                                               (double)((Point)to).X);
              s_animatableProperties["anchorPoint.y"].AnimateValue(target,
                                                               storyboard,
                                                               properties,
                                                               (from != nullptr) ? (Object^)((Point)from).Y : nullptr,
                                                               (double)((Point)to).Y);
          }},
          ApplyTransformFunction{[](FrameworkElement^ target, Object^ toValue) {
              LayerCoordinator::SetValue(target, "anchorPoint.x", static_cast<double>(static_cast<Point>(toValue).X));
              LayerCoordinator::SetValue(target, "anchorPoint.y", static_cast<double>(static_cast<Point>(toValue).Y));
          }},
          GetCurrentValueFunction{[](FrameworkElement^ target) -> Object^ {
              // Unbox x and y values as doubles, before casting them to floats
              return Point(static_cast<float>(static_cast<double>(LayerCoordinator::GetValue(target, "anchorPoint.x"))),
                           static_cast<float>(static_cast<double>(LayerCoordinator::GetValue(target, "anchorPoint.y"))));
          }}} },
    { "size.width",
      AnimatableProperty{
          ApplyAnimationFunction{[](FrameworkElement^ target, Storyboard^ storyboard, DoubleAnimation^ properties, Object^ from, Object^ to) {
              // Zero out negative and null values
              auto fromValue = from ? std::max<double>(0.0, static_cast<double>(from)) : 0.0;
              auto toValue = to ? std::max<double>(0.0, static_cast<double>(to)) : 0.0;

              // Calculate values to animate on the AnchorPoint transform
              // TODO: SHOULD WE JUST ANIMATE THEM DIRECTLY RATHER THAN DUPLICATING THIS LOGIC, OR PULL OUT TO SHARED LOCATION?
              float anchorPointX = LayerCoordinator::GetAnchorPointX(target);
              fromValue = ((-fromValue) * anchorPointX);
              toValue = ((-toValue) * anchorPointX);
              LayerCoordinator::AddAnimation(
                  LayerCoordinator::GetAnchorXTransformPath(),
                  target,
                  storyboard,
                  properties,
                  from ? static_cast<Object^>(fromValue) : nullptr,
                  toValue);

              // Animate the VisualWidth property to the new value
              LayerCoordinator::AddAnimation("(LayerCoordinator.VisualWidth)", target, storyboard, properties, from, to, true);
          }},
          ApplyTransformFunction{[](FrameworkElement^ target, Object^ toValue) {
              // Update our width
              auto toWidth = std::max<double>(0.0, static_cast<double>(toValue));

              // Override any default MinWidth set on the Xaml element (for example, TextBox's default width/height are set in generic.xaml)
              target->MinWidth = toWidth;

              // Set the new width
              target->Width = toWidth;

              // Update the AnchorPoint transform
              double destX = -(toWidth) * LayerCoordinator::GetAnchorPointX(target);
              LayerCoordinator::GetAnchorTransform(target)->X = destX;

              auto anchorX = LayerCoordinator::GetAnchorTransform(target)->X;
              auto anchorY = LayerCoordinator::GetAnchorTransform(target)->Y;

              // Update the VisualWidth property
              LayerCoordinator::SetVisualWidth(target, toWidth);

              // Update the Clip rect if necessary
              if (target->Clip) {
                  Rect clipRect = target->Clip->Rect;
                  clipRect.Width = static_cast<float>(toWidth);
                  target->Clip->Rect = clipRect;
              }
          }},
          GetCurrentValueFunction{[](FrameworkElement^ target) -> Object^ {
              return LayerCoordinator::GetVisualWidth(target);
          }}} },
    { "size.height",
      AnimatableProperty{
          ApplyAnimationFunction{[](FrameworkElement^ target, Storyboard^ storyboard, DoubleAnimation^ properties, Object^ from, Object^ to) {
              // Zero out negative and null values
              auto fromValue = from ? std::max<double>(0.0, static_cast<double>(from)) : 0.0;
              auto toValue = to ? std::max<double>(0.0, static_cast<double>(to)) : 0.0;

              // Calculate values to animate on the AnchorPoint transform
              // TODO: SHOULD WE JUST ANIMATE THEM DIRECTLY RATHER THAN DUPLICATING THIS LOGIC, OR PULL OUT TO SHARED LOCATION?
              float anchorPointY = LayerCoordinator::GetAnchorPointY(target);
              fromValue = (-(fromValue) * anchorPointY);
              toValue = (-(toValue) * anchorPointY);
              LayerCoordinator::AddAnimation(
                  LayerCoordinator::GetAnchorYTransformPath(),
                  target,
                  storyboard,
                  properties,
                  from ? static_cast<Object^>(fromValue) : nullptr,
                  toValue);

              // Animate the VisualHeight property to the new value
              LayerCoordinator::AddAnimation("(LayerCoordinator.VisualHeight)", target, storyboard, properties, from, to, true);
          }},
          ApplyTransformFunction{[](FrameworkElement^ target, Object^ toValue) {
              // Update our height
              auto toHeight = std::max<double>(0.0, static_cast<double>(toValue));

              // Override any default MinHeight set on the Xaml element (for example, TextBox's default width/height are set in generic.xaml)
              target->MinHeight = toHeight;

              // Set the new height
              target->Height = toHeight;

              // Update the AnchorPoint transform
              double destY = -(toHeight) * LayerCoordinator::GetAnchorPointY(target);
              LayerCoordinator::GetAnchorTransform(target)->Y = destY;

              // Update the VisualHeight property
              LayerCoordinator::SetVisualHeight(target, toHeight);

              // Update the Clip rect if necessary
              if (target->Clip) {
                  Rect clipRect = target->Clip->Rect;
                  clipRect.Height = static_cast<float>(toHeight);
                  target->Clip->Rect = clipRect;
              }
          }},
          GetCurrentValueFunction{[](FrameworkElement^ target) -> Object^ {
              return LayerCoordinator::GetVisualHeight(target);
          }}} },
    { "size",
      AnimatableProperty{
          ApplyAnimationFunction{[](FrameworkElement^ target, Storyboard^ storyboard, DoubleAnimation^ properties, Object^ from, Object^ to) {
              s_animatableProperties["size.width"].AnimateValue(target,
                                                            storyboard,
                                                            properties,
                                                            (from != nullptr) ? (Object^)((Size)from).Width : nullptr,
                                                            (double)((Size)to).Width);
              s_animatableProperties["size.height"].AnimateValue(target,
                                                             storyboard,
                                                             properties,
                                                             (from != nullptr) ? (Object^)((Size)from).Height : nullptr,
                                                             (double)((Size)to).Height);
          }},
          ApplyTransformFunction{[](FrameworkElement^ target, Object^ toValue) {
              s_animatableProperties["size.width"].SetValue(target, (double)((Size)toValue).Width);
              s_animatableProperties["size.height"].SetValue(target, (double)((Size)toValue).Height);
          }},
          GetCurrentValueFunction{[](FrameworkElement^ target) -> Object^ {
              // Unbox width and height values as doubles, before casting them to floats
              return Size((float)(double)LayerCoordinator::GetValue(target, "size.width"),
                          (float)(double)LayerCoordinator::GetValue(target, "size.height"));
          }}} },
    { "transform.rotation",
      AnimatableProperty{
          ApplyAnimationFunction{[](FrameworkElement^ target, Storyboard^ storyboard, DoubleAnimation^ properties, Object^ from, Object^ to) {
              LayerCoordinator::AddAnimation(
                  LayerCoordinator::GetRotationTransformPath(),
                  target,
                  storyboard,
                  properties,
                  from,
                  to);
          }},
          ApplyTransformFunction{[](FrameworkElement^ target, Object^ toValue) {
              LayerCoordinator::GetRotationTransform(target)->Angle = static_cast<double>(toValue);
          }},
          GetCurrentValueFunction{[](FrameworkElement^ target) -> Object^ {
              return LayerCoordinator::GetRotationTransform(target)->Angle;
          }}} },
    { "transform.scale.x",
      AnimatableProperty{
          ApplyAnimationFunction{[](FrameworkElement^ target, Storyboard^ storyboard, DoubleAnimation^ properties, Object^ from, Object^ to) {
              LayerCoordinator::AddAnimation(
                  LayerCoordinator::GetScaleXTransformPath(),
                  target,
                  storyboard,
                  properties,
                  from,
                  to);
          }},
          ApplyTransformFunction{[](FrameworkElement^ target, Object^ toValue) {
              LayerCoordinator::GetScaleTransform(target)->ScaleX = static_cast<double>(toValue);
          }},
          GetCurrentValueFunction{[](FrameworkElement^ target) -> Object^ {
              return LayerCoordinator::GetScaleTransform(target)->ScaleX;
          }}} },
    { "transform.scale.y",
      AnimatableProperty{
          ApplyAnimationFunction{[](FrameworkElement^ target, Storyboard^ storyboard, DoubleAnimation^ properties, Object^ from, Object^ to) {
              LayerCoordinator::AddAnimation(
                  LayerCoordinator::GetScaleYTransformPath(),
                  target,
                  storyboard,
                  properties,
                  from,
                  to);
          }},
          ApplyTransformFunction{[](FrameworkElement^ target, Object^ toValue) {
              LayerCoordinator::GetScaleTransform(target)->ScaleY = static_cast<double>(toValue);
          }},
          GetCurrentValueFunction{[](FrameworkElement^ target) -> Object^ {
              return LayerCoordinator::GetScaleTransform(target)->ScaleY;
          }}} },
    { "transform.translation.x",
      AnimatableProperty{
          ApplyAnimationFunction{[](FrameworkElement^ target, Storyboard^ storyboard, DoubleAnimation^ properties, Object^ from, Object^ to) {
              LayerCoordinator::AddAnimation(
                  LayerCoordinator::GetTranslationXTransformPath(),
                  target,
                  storyboard,
                  properties,
                  from,
                  to);
          }},
          ApplyTransformFunction{[](FrameworkElement^ target, Object^ toValue) {
              LayerCoordinator::GetTranslationTransform(target)->X = static_cast<double>(toValue);
          }},
          GetCurrentValueFunction{[](FrameworkElement^ target) -> Object^ {
              return LayerCoordinator::GetTranslationTransform(target)->X;
          }}} },
    { "transform.translation.y",
      AnimatableProperty{
          ApplyAnimationFunction{[](FrameworkElement^ target, Storyboard^ storyboard, DoubleAnimation^ properties, Object^ from, Object^ to) {
              LayerCoordinator::AddAnimation(
                  LayerCoordinator::GetTranslationYTransformPath(),
                  target,
                  storyboard,
                  properties,
                  from,
                  to);
          }},
          ApplyTransformFunction{[](FrameworkElement^ target, Object^ toValue) {
              LayerCoordinator::GetTranslationTransform(target)->Y = static_cast<double>(toValue);
          }},
          GetCurrentValueFunction{[](FrameworkElement^ target) -> Object^ {
              return LayerCoordinator::GetTranslationTransform(target)->Y;
          }}} },
    { "opacity",
      AnimatableProperty{
          ApplyAnimationFunction{[](FrameworkElement^ target, Storyboard^ storyboard, DoubleAnimation^ properties, Object^ from, Object^ to) {
              LayerCoordinator::AddAnimation("(UIElement.Opacity)", target, storyboard, properties, from, to);
          }},
          ApplyTransformFunction{[](FrameworkElement^ target, Object^ toValue) {
              target->Opacity = static_cast<double>(toValue);
          }},
          GetCurrentValueFunction{[](FrameworkElement^ target) -> Object^ { 
              return target->Opacity; 
          }}} },
    { "gravity",
      AnimatableProperty{
          ApplyAnimationFunction{}, // No animation supported
          ApplyTransformFunction{[](FrameworkElement^ target, Object^ toValue) {
              LayerCoordinator::SetContentGravity(target, static_cast<ContentGravity>(static_cast<int>(toValue)));
          }},
          GetCurrentValueFunction{[](FrameworkElement^ target) -> Object^ { 
              return static_cast<int>(LayerCoordinator::GetContentGravity(target));
          }}} },
    { "masksToBounds",
      AnimatableProperty{
          ApplyAnimationFunction{}, // No animation supported
          ApplyTransformFunction{[](FrameworkElement^ target, Object^ toValue) {
              bool masksToBounds = static_cast<bool>(toValue);
              if (masksToBounds) {
                  // Set up our Clip geometry based on the visual/transformed width/height of the target
                  // TODO: Why can't we just use Width/Height here??
                  //       It seems like we probably can??
                  auto clipGeometry = ref new RectangleGeometry();
                  clipGeometry->Rect = Rect(
                      0, 
                      0, 
                      static_cast<float>(LayerCoordinator::GetVisualWidth(target)), 
                      static_cast<float>(LayerCoordinator::GetVisualHeight(target)));

                  // Set up its origin transform
                  auto clipOriginTransform = ref new TranslateTransform();
                  clipOriginTransform->X = LayerCoordinator::GetOriginX(target);
                  clipOriginTransform->Y = LayerCoordinator::GetOriginY(target);
                  clipGeometry->Transform = clipOriginTransform;

                  target->Clip = clipGeometry;
              } else {
                  // Clear out the Clip geometry
                  target->Clip = nullptr;
              }
          }},
          GetCurrentValueFunction{[](FrameworkElement^ target) -> Object^ {
              return target->Clip != nullptr; 
          }}} },
};

// CALayer property management plumbing
bool LayerCoordinator::s_dependencyPropertiesRegistered = false;
DependencyProperty^ LayerCoordinator::s_anchorPointProperty = nullptr;
DependencyProperty^ LayerCoordinator::s_originProperty = nullptr;
DependencyProperty^ LayerCoordinator::s_positionProperty = nullptr;
DependencyProperty^ LayerCoordinator::s_visualWidthProperty = nullptr;
DependencyProperty^ LayerCoordinator::s_visualHeightProperty = nullptr;
DependencyProperty^ LayerCoordinator::s_contentGravityProperty = nullptr;
DependencyProperty^ LayerCoordinator::s_contentCenterProperty = nullptr;
DependencyProperty^ LayerCoordinator::s_contentSizeProperty = nullptr;
DependencyProperty^ LayerCoordinator::s_contentScaleProperty = nullptr;

void LayerCoordinator::InitializeFrameworkElement(FrameworkElement^ element) {
    // No-op if already registered
    _RegisterDependencyProperties();

    // Make sure this FrameworkElement is hit-testable by default
    element->IsHitTestVisible = true;

    ////////////////////////////////////////////////////////////////
    // Set up all necessary RenderTransforms for CALayer support.
    // The order of transforms is critical.
    ////////////////////////////////////////////////////////////////

    // Grab Width/Height
    // These likely won't be set yet, but if not, we'll use 0 until the layer is resized
    auto width = element->Width;
    if (std::isnan(width)) {
        width = 0.0;
        element->Width = width;
    }

    auto height = element->Height;
    if (std::isnan(height)) {
        height = 0.0;
        element->Height = height;
    }

    // The anchor value modifies how the rest of the transforms are applied to this layer
    // Ideally we'd just set UIElement::RenderTransformOrigin, but that doesn't apply to TranslateTransforms
    auto sizeAnchorTransform = ref new TranslateTransform(); // anchorpoint
    sizeAnchorTransform->X = -width * GetAnchorPointX(element);
    sizeAnchorTransform->Y = -height * GetAnchorPointY(element);

    // Set up the origin transform
    auto originTransform = ref new TranslateTransform(); // origin
    originTransform->X = -GetOriginX(element);
    originTransform->Y = -GetOriginY(element);

    // Nested transform group for rotation, scale and translation transforms
    auto contentTransform = ref new TransformGroup();
    contentTransform->Children->Append(ref new RotateTransform()); // transform.rotation
    contentTransform->Children->Append(ref new ScaleTransform()); // transform.scale
    contentTransform->Children->Append(ref new TranslateTransform()); // transform.translation

    // Positioning transform
    auto positionTransform = ref new TranslateTransform(); // position
    positionTransform->X = GetPositionX(element);
    positionTransform->Y = GetPositionY(element);

    auto layerTransforms = ref new TransformGroup();
    layerTransforms->Children->Append(sizeAnchorTransform);
    layerTransforms->Children->Append(originTransform);
    layerTransforms->Children->Append(contentTransform);
    layerTransforms->Children->Append(positionTransform);
    element->RenderTransform = layerTransforms;

    SetVisualWidth(element, width);
    SetVisualHeight(element, height);
}

// CALayer property managment support
void LayerCoordinator::SetValue(FrameworkElement^ element, const char* propertyName, Object^ value) {
    s_animatableProperties[propertyName].SetValue(element, value);
}

Object^ LayerCoordinator::GetValue(FrameworkElement^ element, const char* propertyName) {
    return s_animatableProperties[propertyName].GetValue(element);
}

void LayerCoordinator::AnimateValue(
    FrameworkElement^ target,
    Storyboard^ storyboard,
    DoubleAnimation^ timeline,
    const char* propertyName,
    Object^ fromValue,
    Object^ toValue) {
    s_animatableProperties[propertyName].AnimateValue(target, storyboard, timeline, fromValue, toValue);
}

// CALayer content support
void LayerCoordinator::SetContent(FrameworkElement^ element, ImageSource^ source, float width, float height, float scale) {
    // Get content
    bool createIfPossible = (source != nullptr); // Only create the Image if we have a valid source to set
    Image^ contentImage = _GetContentImage(element, createIfPossible);
    if (!contentImage) {
        return;
    }

    // Apply content source
    contentImage->Source = source;

    // Store content size with the scale factor applied
    if (scale <= 0.0) {
        scale = 1.0f;
    }
    _SetContentSize(element, Size(width / scale, height / scale));

    // Store the content scale
    _SetContentScale(element, scale);

    // Refresh any content center settings
    _ApplyContentCenter(element, _GetContentCenter(element));

    // Refresh any content gravity settings
    _ApplyContentGravity(element, GetContentGravity(element));
}

Image^ LayerCoordinator::_GetContentImage(FrameworkElement^ element, bool createIfPossible) {
    // First check if the element implements ILayer
    Image^ contentImage;
    ILayer^ layerElement = dynamic_cast<ILayer^>(element);
    if (layerElement) {
        // Accessing the LayerContent will create it on-demand, so only do so if necessary
        if (layerElement->HasLayerContent || createIfPossible) {
            contentImage = layerElement->LayerContent;
        }
    } else {
        // Not an ILayer, so default to grabbing the xamlElement's LayerContentProperty (if it exists)
        contentImage = dynamic_cast<Image^>(element->GetValue(Layer::LayerContentProperty));
    }

    if (!contentImage && createIfPossible) {
        UNIMPLEMENTED_WITH_MSG(
            "Layer Content not supported on this Xaml element: [%ws].",
            element->GetType()->FullName->Data());
    }

    return contentImage;
}

void LayerCoordinator::SetContentCenter(FrameworkElement^ element, Windows::Foundation::Rect rect) {
    element->SetValue(s_contentCenterProperty, rect);
    _ApplyContentCenter(element, rect);
}

Rect LayerCoordinator::_GetContentCenter(FrameworkElement^ element) {
    return static_cast<Rect>(element->GetValue(s_contentCenterProperty));
}

void LayerCoordinator::_ApplyContentCenter(FrameworkElement^ element, Rect contentCenter) {
    // Nothing to do if we don't have any content
    Image^ image = _GetContentImage(element);
    if (!image || !image->Source ) {
        return;
    }

    ContentGravity gravity = GetContentGravity(element);
    Size contentSize = _GetContentSize(element);
    if (contentCenter.Equals(Rect(0, 0, 1.0, 1.0))) {
        image->NineGrid = Thickness(0, 0, 0, 0);
    } else {
        // When creating the NineGrid, we need to take the scaled image dimensions into account
        const double contentScale = _GetContentScale(element);
        const double imageWidth = contentSize.Width * contentScale;
        const double imageHeight = contentSize.Height * contentScale;

        int left = static_cast<int>(contentCenter.X * imageWidth);
        int top = static_cast<int>(contentCenter.Y * imageHeight);
        int right = (static_cast<int>(imageWidth) - (left + (static_cast<int>(contentCenter.Width * imageWidth))));
        int bottom = (static_cast<int>(imageHeight) - (top + (static_cast<int>(contentCenter.Height * imageHeight))));

        // Remove edge cases that contentsCenter supports but NineGrid does not. 1/3 for top 1/3 for bottom 1/3 for
        // the center etc..
        left = std::max<int>(0, left);
        top = std::max<int>(0, top);
        right = std::max<int>(0, right);
        bottom = std::max<int>(0, bottom);

        // Cap the left/right to the maximum width
        int maxWidth = static_cast<int>(imageWidth / 3);
        left = std::min<int>(left, maxWidth);
        right = std::min<int>(right, maxWidth);

        // Cap the top/bottom to the maximum height
        int maxHeight = static_cast<int>(imageHeight / 3);
        top = std::min<int>(top, maxHeight);
        bottom = std::min<int>(bottom, maxHeight);

        // Set the image's NineGrid to accomodate
        image->NineGrid = Thickness(left, top, right, bottom);
    }
}

void LayerCoordinator::_RegisterDependencyProperties() {
    if (!s_dependencyPropertiesRegistered) {

        // AnchorPoint always starts at Point(0.5, 0.5)
        s_anchorPointProperty = DependencyProperty::RegisterAttached(
            "AnchorPoint",
            Point::typeid,
            FrameworkElement::typeid,
            ref new PropertyMetadata(Point(0.5, 0.5), nullptr));

        s_originProperty = DependencyProperty::RegisterAttached(
            "Origin",
            Point::typeid,
            FrameworkElement::typeid,
            ref new PropertyMetadata(Point(0.0, 0.0), nullptr));

        s_positionProperty = DependencyProperty::RegisterAttached(
            "Position",
            Point::typeid,
            FrameworkElement::typeid,
            ref new PropertyMetadata(Point(0.0, 0.0), nullptr));

        s_visualWidthProperty = DependencyProperty::RegisterAttached(
            "VisualWidth",
            double::typeid,
            FrameworkElement::typeid,
            ref new PropertyMetadata(0.0,
            ref new PropertyChangedCallback(&LayerCoordinator::_VisualWidthChangedCallback)));

        s_visualHeightProperty = DependencyProperty::RegisterAttached(
            "VisualHeight",
            double::typeid,
            FrameworkElement::typeid,
            ref new PropertyMetadata(0.0,
            ref new PropertyChangedCallback(&LayerCoordinator::_VisualHeightChangedCallback)));

        // Store as an int (rather than as a ContentGravity enum value) so we can read the values in the VS debugger at runtime
        s_contentGravityProperty = DependencyProperty::RegisterAttached(
            "ContentGravity",
            int::typeid,
            FrameworkElement::typeid,
            ref new PropertyMetadata(static_cast<Object^>(static_cast<int>(ContentGravity::Resize)), nullptr));

        s_contentCenterProperty = DependencyProperty::RegisterAttached(
            "ContentCenter",
            Windows::Foundation::Rect::typeid,
            FrameworkElement::typeid,
            ref new PropertyMetadata(Windows::Foundation::Rect(0, 0, 1.0, 1.0), nullptr));

        // The size of the layer content, divided by the scale factor of the content
        s_contentSizeProperty = DependencyProperty::RegisterAttached(
            "ContentSize",
            Windows::Foundation::Size::typeid,
            FrameworkElement::typeid,
            ref new PropertyMetadata(Windows::Foundation::Size(0, 0), nullptr));

        s_contentScaleProperty = DependencyProperty::RegisterAttached(
            "ContentScale",
            double::typeid,
            FrameworkElement::typeid,
            ref new PropertyMetadata(0.0, nullptr));

        s_dependencyPropertiesRegistered = true;
    }
}

// AnchorPoint
float LayerCoordinator::GetAnchorPointX(FrameworkElement^ element) {
    return static_cast<Point>(element->GetValue(s_anchorPointProperty)).X;
}

void LayerCoordinator::SetAnchorPointX(FrameworkElement^ element, float value) {
    if (DEBUG_ANCHORPOINT) {
        TraceVerbose(TAG, L"SetAnchorPointX [%ws:%f]", element->GetType()->FullName->Data(), value);
    }

    auto point = static_cast<Point>(element->GetValue(s_anchorPointProperty));
    point.X = value;
    element->SetValue(s_anchorPointProperty, point);
}

float LayerCoordinator::GetAnchorPointY(FrameworkElement^ element) {
    return static_cast<Point>(element->GetValue(s_anchorPointProperty)).Y;
}

void LayerCoordinator::SetAnchorPointY(FrameworkElement^ element, float value) {
    if (DEBUG_ANCHORPOINT) {
        TraceVerbose(TAG, L"SetAnchorPointY [%ws:%f]", element->GetType()->FullName->Data(), value);
    }

    auto point = static_cast<Point>(element->GetValue(s_anchorPointProperty));
    point.Y = value;
    element->SetValue(s_anchorPointProperty, point);
}

TranslateTransform^ LayerCoordinator::GetAnchorTransform(FrameworkElement^ element) {
    return safe_cast<TranslateTransform^>(safe_cast<TransformGroup^>(element->RenderTransform)->Children->GetAt(0));
}

String^ LayerCoordinator::GetAnchorXTransformPath() {
    static String^ path = L"(UIElement.RenderTransform).(TransformGroup.Children)[0].(TranslateTransform.X)";
    return path;
}

String^ LayerCoordinator::GetAnchorYTransformPath() {
    static String^ path = L"(UIElement.RenderTransform).(TransformGroup.Children)[0].(TranslateTransform.Y)";
    return path;
}

// Origin
float LayerCoordinator::GetOriginX(FrameworkElement^ element) {
    return static_cast<Point>(element->GetValue(s_originProperty)).X;
}

void LayerCoordinator::SetOriginX(FrameworkElement^ element, float value) {
    auto point = static_cast<Point>(element->GetValue(s_originProperty));
    point.X = value;
    element->SetValue(s_originProperty, point);
}

float LayerCoordinator::GetOriginY(FrameworkElement^ element) {
    return static_cast<Point>(element->GetValue(s_originProperty)).Y;
}

void LayerCoordinator::SetOriginY(FrameworkElement^ element, float value) {
    auto point = static_cast<Point>(element->GetValue(s_originProperty));
    point.Y = value;
    element->SetValue(s_originProperty, point);
}

TranslateTransform^ LayerCoordinator::GetOriginTransform(FrameworkElement^ element) {
    return safe_cast<TranslateTransform^>(safe_cast<TransformGroup^>(element->RenderTransform)->Children->GetAt(1));
}

String^ LayerCoordinator::GetOriginXTransformPath() {
    static String^ path = L"(UIElement.RenderTransform).(TransformGroup.Children)[1].(TranslateTransform.X)";
    return path;
}

String^ LayerCoordinator::GetOriginYTransformPath() {
    static String^ path = L"(UIElement.RenderTransform).(TransformGroup.Children)[1].(TranslateTransform.Y)";
    return path;
}

// Position
float LayerCoordinator::GetPositionX(FrameworkElement^ element) {
    return static_cast<Point>(element->GetValue(s_positionProperty)).X;
}

void LayerCoordinator::SetPositionX(FrameworkElement^ element, float value) {
    if (DEBUG_POSITION) {
        TraceVerbose(TAG, L"SetPositionX [%ws:%f]", element->GetType()->FullName->Data(), value);
    }

    auto point = static_cast<Point>(element->GetValue(s_positionProperty));
    point.X = value;
    element->SetValue(s_positionProperty, point);
}

float LayerCoordinator::GetPositionY(FrameworkElement^ element) {
    return static_cast<Point>(element->GetValue(s_positionProperty)).Y;
}

void LayerCoordinator::SetPositionY(FrameworkElement^ element, float value) {
    if (DEBUG_POSITION) {
        TraceVerbose(TAG, L"SetPositionY [%ws:%f]", element->GetType()->FullName->Data(), value);
    }

    auto point = static_cast<Point>(element->GetValue(s_positionProperty));
    point.Y = value;
    element->SetValue(s_positionProperty, point);
}

TranslateTransform^ LayerCoordinator::GetPositionTransform(FrameworkElement^ element) {
    return safe_cast<TranslateTransform^>(safe_cast<TransformGroup^>(element->RenderTransform)->Children->GetAt(3));
}

String^ LayerCoordinator::GetPositionXTransformPath() {
    static String^ path = L"(UIElement.RenderTransform).(TransformGroup.Children)[3].(TranslateTransform.X)";
    return path;
}

String^ LayerCoordinator::GetPositionYTransformPath() {
    static String^ path = L"(UIElement.RenderTransform).(TransformGroup.Children)[3].(TranslateTransform.Y)";
    return path;
}

// Rotation
RotateTransform^ LayerCoordinator::GetRotationTransform(FrameworkElement^ element) {
    return safe_cast<RotateTransform^>(
        safe_cast<TransformGroup^>(
            safe_cast<TransformGroup^>(element->RenderTransform)->Children->GetAt(2))->Children->GetAt(0));
}

String^ LayerCoordinator::GetRotationTransformPath() {
    static String^ path = L"(UIElement.RenderTransform).(TransformGroup.Children)[2].(TransformGroup.Children)[0].(RotateTransform.Angle)";
    return path;
}

// Scale
ScaleTransform^ LayerCoordinator::GetScaleTransform(FrameworkElement^ element) {
    return safe_cast<ScaleTransform^>(
        safe_cast<TransformGroup^>(
            safe_cast<TransformGroup^>(element->RenderTransform)->Children->GetAt(2))->Children->GetAt(1));
}

String^ LayerCoordinator::GetScaleXTransformPath() {
    static String^ path = L"(UIElement.RenderTransform).(TransformGroup.Children)[2].(TransformGroup.Children)[1].(ScaleTransform.ScaleX)";
    return path;
}

String^ LayerCoordinator::GetScaleYTransformPath() {
    static String^ path = L"(UIElement.RenderTransform).(TransformGroup.Children)[2].(TransformGroup.Children)[1].(ScaleTransform.ScaleY)";
    return path;
}

// Translation
TranslateTransform^ LayerCoordinator::GetTranslationTransform(FrameworkElement^ element) {
    return safe_cast<TranslateTransform^>(
        safe_cast<TransformGroup^>(
            safe_cast<TransformGroup^>(element->RenderTransform)->Children->GetAt(2))->Children->GetAt(2));
}

String^ LayerCoordinator::GetTranslationXTransformPath() {
    static String^ path = L"(UIElement.RenderTransform).(TransformGroup.Children)[2].(TransformGroup.Children)[2].(TranslateTransform.X)";
    return path;
}

String^ LayerCoordinator::GetTranslationYTransformPath() {
    static String^ path = L"(UIElement.RenderTransform).(TransformGroup.Children)[2].(TransformGroup.Children)[2].(TranslateTransform.Y)";
    return path;
}

// VisualWidth
double LayerCoordinator::GetVisualWidth(FrameworkElement^ element) {
    return static_cast<double>(element->GetValue(s_visualWidthProperty));
}

void LayerCoordinator::SetVisualWidth(FrameworkElement^ element, double value) {
    element->SetValue(s_visualWidthProperty, value);
}

// VisualHeight
double LayerCoordinator::GetVisualHeight(FrameworkElement^ element) {
    return static_cast<double>(element->GetValue(s_visualHeightProperty));
}

void LayerCoordinator::SetVisualHeight(FrameworkElement^ element, double value) {
    element->SetValue(s_visualHeightProperty, value);
}

void LayerCoordinator::_VisualWidthChangedCallback(DependencyObject^ sender, DependencyPropertyChangedEventArgs^ args) {
    auto element = safe_cast<FrameworkElement^>(sender);

    // Update the element's width accordingly
    element->Width = safe_cast<double>(args->NewValue);

    // Refresh any content gravity settings
    _ApplyContentGravity(element, GetContentGravity(element));
}

void LayerCoordinator::_VisualHeightChangedCallback(DependencyObject^ sender, DependencyPropertyChangedEventArgs^ args) {
    auto element = safe_cast<FrameworkElement^>(sender);

    // Update the element's height accordingly
    element->Height = safe_cast<double>(args->NewValue);

    // Refresh any content gravity settings
    _ApplyContentGravity(element, GetContentGravity(element));
}

// ContentGravity
ContentGravity LayerCoordinator::GetContentGravity(FrameworkElement^ element) {
    // We store as an int (rather than as a ContentGravity enum value) so we can read the values in the VS debugger at runtime
    return static_cast<ContentGravity>(static_cast<int>(element->GetValue(s_contentGravityProperty)));
}

void LayerCoordinator::SetContentGravity(FrameworkElement^ element, ContentGravity value) {
    // We store as an int (rather than as a ContentGravity enum value) so we can read the values in the VS debugger at runtime
    element->SetValue(s_contentGravityProperty, ref new Platform::Box<int>(static_cast<int>(value)));
    _ApplyContentGravity(element, value);
}

void LayerCoordinator::_ApplyContentGravity(FrameworkElement^ element, ContentGravity gravity) {

    // Grab the content and containing element sizes
    const Size contentSize = _GetContentSize(element);
    const double elementWidth = element->Width;
    const double elementHeight = element->Height;

    // Apply gravity mapping
    HorizontalAlignment horizontalAlignment;
    VerticalAlignment verticalAlignment;
    double finalContentWidth = 0.0;
    double finalContentHeight = 0.0;
    double contentLeft = 0.0;
    double contentTop = 0.0;
    switch (gravity) {
    case ContentGravity::Center:
        // Determine horizontal/vertical alignment
        horizontalAlignment = HorizontalAlignment::Center;
        verticalAlignment = VerticalAlignment::Center;

        // ContentGravity::Center does not resize the content
        finalContentWidth = contentSize.Width;
        finalContentHeight = contentSize.Height;

        // Vertically and horizontally center the content within its containing layer.
        contentLeft = (elementWidth / 2) - (contentSize.Width / 2);
        contentTop = (elementHeight / 2) - (contentSize.Height / 2);
        break;

    case ContentGravity::Top:
        // Determine horizontal/vertical alignment
        horizontalAlignment = HorizontalAlignment::Center;
        verticalAlignment = VerticalAlignment::Top;

        // ContentGravity::Top does not resize the content
        finalContentWidth = contentSize.Width;
        finalContentHeight = contentSize.Height;

        // Bottom-align and horizontally-center the content within its containing layer.
        // Note: This is counter-intuitive; Top/Bottom gravity is swapped for CALayer.
        contentLeft = (elementWidth / 2) - (contentSize.Width / 2);
        contentTop = (elementHeight - contentSize.Height);
        break;

    case ContentGravity::Bottom:
        // Determine horizontal/vertical alignment
        horizontalAlignment = HorizontalAlignment::Center;
        verticalAlignment = VerticalAlignment::Bottom;

        // ContentGravity::Bottom does not resize the content
        finalContentWidth = contentSize.Width;
        finalContentHeight = contentSize.Height;

        // Top-align and horizontally-center the content within its containing layer.
        // Note: This is counter-intuitive; Top/Bottom gravity is swapped for CALayer.
        contentLeft = (elementWidth / 2) - (contentSize.Width / 2);
        contentTop = 0;
        break;

    case ContentGravity::Left:
        // Determine horizontal/vertical alignment
        horizontalAlignment = HorizontalAlignment::Left;
        verticalAlignment = VerticalAlignment::Center;

        // ContentGravity::Left does not resize the content
        finalContentWidth = contentSize.Width;
        finalContentHeight = contentSize.Height;

        // Left-align and vertically-center the content within its containing layer.
        contentLeft = 0;
        contentTop = (elementHeight / 2) - (contentSize.Height / 2);
        break;

    case ContentGravity::Right:
        // Determine horizontal/vertical alignment
        horizontalAlignment = HorizontalAlignment::Right;
        verticalAlignment = VerticalAlignment::Center;

        // ContentGravity::Right does not resize the content
        finalContentWidth = contentSize.Width;
        finalContentHeight = contentSize.Height;

        // Right-align and vertically-center the content within its containing layer.
        contentLeft = (elementWidth - contentSize.Width);
        contentTop = (elementHeight / 2) - (contentSize.Height / 2);
        break;

    case ContentGravity::TopLeft:
        // Determine horizontal/vertical alignment
        horizontalAlignment = HorizontalAlignment::Left;
        verticalAlignment = VerticalAlignment::Top;

        // ContentGravity::TopLeft does not resize the content
        finalContentWidth = contentSize.Width;
        finalContentHeight = contentSize.Height;

        // Left and *bottom* align the content within its containing layer.
        // Note: This is counter-intuitive; Top/Bottom gravity is swapped for CALayer.
        contentLeft = 0;
        contentTop = (elementHeight - contentSize.Height);
        break;

    case ContentGravity::TopRight:
        // Determine horizontal/vertical alignment
        horizontalAlignment = HorizontalAlignment::Right;
        verticalAlignment = VerticalAlignment::Top;

        // ContentGravity::TopRight does not resize the content
        finalContentWidth = contentSize.Width;
        finalContentHeight = contentSize.Height;

        // Right and *bottom* align the content within its containing layer.
        // Note: This is counter-intuitive; Top/Bottom gravity is swapped for CALayer.
        contentLeft = (elementWidth - contentSize.Width);
        contentTop = (elementHeight - contentSize.Height);
        break;

    case ContentGravity::BottomLeft:
        // Determine horizontal/vertical alignment
        horizontalAlignment = HorizontalAlignment::Left;
        verticalAlignment = VerticalAlignment::Bottom;

        // ContentGravity::BottomLeft does not resize the content
        finalContentWidth = contentSize.Width;
        finalContentHeight = contentSize.Height;

        // Left and *top* align the content within its containing layer.
        // Note: This is counter-intuitive; Top/Bottom gravity is swapped for CALayer.
        contentLeft = 0;
        contentTop = 0;
        break;

    case ContentGravity::BottomRight:
        // Determine horizontal/vertical alignment
        horizontalAlignment = HorizontalAlignment::Right;
        verticalAlignment = VerticalAlignment::Bottom;

        // ContentGravity::BottomRight does not resize the content
        finalContentWidth = contentSize.Width;
        finalContentHeight = contentSize.Height;

        // Right and *top* align the content within its containing layer.
        // Note: This is counter-intuitive; Top/Bottom gravity is swapped for CALayer.
        contentLeft = (elementWidth - contentSize.Width);
        contentTop = 0;
        break;

    case ContentGravity::Resize:
        // Determine horizontal/vertical alignment
        horizontalAlignment = HorizontalAlignment::Left;
        verticalAlignment = VerticalAlignment::Top;

        // Resize content to that of its containing layer
        finalContentWidth = elementWidth;
        finalContentHeight = elementHeight;

        // Completely fill/align the content within its containing layer.
        contentLeft = 0;
        contentTop = 0;
        break;

    case ContentGravity::ResizeAspect:
        {
            // Determine horizontal/vertical alignment
            horizontalAlignment = HorizontalAlignment::Center;
            verticalAlignment = VerticalAlignment::Center;

            // Resize the content to fit within its containing layer, while retaining its
            // aspect ratio.
            const double widthAspect = elementWidth / contentSize.Width;
            const double heightAspect = elementHeight / contentSize.Height;
            const double minAspect = std::min<double>(widthAspect, heightAspect);
            finalContentWidth = (contentSize.Width * static_cast<float>(minAspect));
            finalContentHeight = (contentSize.Height * static_cast<float>(minAspect));

            // Vertically and horizontally center the content within its containing layer
            contentLeft = (elementWidth / 2) - (finalContentWidth / 2);
            contentTop = (elementHeight / 2) - (finalContentHeight / 2);
            break;
        }

    case ContentGravity::ResizeAspectFill: 
        {
            // Determine horizontal/vertical alignment
            horizontalAlignment = HorizontalAlignment::Center;
            verticalAlignment = VerticalAlignment::Center;

            // Resize the content to fill its containing layer, while retaining its
            // aspect ratio.
            const double widthAspect = elementWidth / contentSize.Width;
            const double heightAspect = elementHeight / contentSize.Height;
            const double maxAspect = std::max<double>(widthAspect, heightAspect);
            finalContentWidth = contentSize.Width * static_cast<float>(maxAspect);
            finalContentHeight = contentSize.Height * static_cast<float>(maxAspect);

            // Vertically and horizontally center the content within its containing layer
            contentLeft = (elementWidth / 2) - (finalContentWidth / 2);
            contentTop = (elementHeight / 2) - (finalContentHeight / 2);
            break; 
        }
    }

    if (DEBUG_GRAVITY) {
        TraceVerbose(
            TAG,
            L"Applying content gravity (%ws); elementSize=%fx%f; contentSize=%fx%f; contentLeft=%f; contentTop=%f",
            gravity.ToString()->Data(),
            elementWidth,
            elementHeight,
            finalContentWidth,
            finalContentHeight,
            contentLeft,
            contentTop);
    }

    // Do we have content?
    Image^ image = _GetContentImage(element);
    if (image) {
        // Set the image's size
        image->Width = finalContentWidth;
        image->Height = finalContentHeight;

        // Using Fill since we calculate the aspect/size ourselves
        image->Stretch = Stretch::Fill;

        // We currently have to position via Canvas top/left, rather than a Grid, to prevent
        // clipping of the image (Canvas doesn't clip its children, but Grid does).
        // So log a warning if the image isn't in a Canvas.
        if (image->Parent && !dynamic_cast<Canvas^>(image->Parent)) {
            auto parent = image->Parent;
            auto type = parent->GetType();
            auto name = type->FullName;
            auto data = name->Data();

            TraceWarning(
                TAG,
                L"Positioning of layer content only works within Canvas elements, but this image is within a %ws.",
                image->Parent->GetType()->FullName->Data());
        }

        // Position the image within its parent
        image->SetValue(Canvas::LeftProperty, contentLeft);
        image->SetValue(Canvas::TopProperty, contentTop);
    }

    // If we don't have content, apply the gravity alignment directly to the target FrameworkElement,
    // otherwise apply it to the content image
    FrameworkElement^ gravityElement = image ? image : element;
    gravityElement->HorizontalAlignment = horizontalAlignment;
    gravityElement->VerticalAlignment = verticalAlignment;
}

// ContentSize
Size LayerCoordinator::_GetContentSize(FrameworkElement^ element) {
    return static_cast<Size>(element->GetValue(s_contentSizeProperty));
}

void LayerCoordinator::_SetContentSize(Windows::UI::Xaml::FrameworkElement^ element, Size value) {
    element->SetValue(s_contentSizeProperty, value);
}

// ContentScale
void LayerCoordinator::_SetContentScale(Windows::UI::Xaml::FrameworkElement^ element, double value) {
    element->SetValue(s_contentScaleProperty, value);
}

double LayerCoordinator::_GetContentScale(FrameworkElement^ element) {
    return static_cast<double>(element->GetValue(s_contentScaleProperty));
}

void LayerCoordinator::AddAnimation(Platform::String^ propertyName,
                                   FrameworkElement^ target,
                                   Media::Animation::Storyboard^ storyboard,
                                   Media::Animation::DoubleAnimation^ copyProperties,
                                   Platform::Object^ fromValue,
                                   Platform::Object^ toValue,
                                   bool dependent) {
    DoubleAnimation^ posxAnim = ref new DoubleAnimation();
    if (toValue) {
        posxAnim->To = static_cast<double>(toValue);
    }

    if (fromValue) {
        posxAnim->From = static_cast<double>(fromValue);
    }

    posxAnim->Duration = copyProperties->Duration;
    posxAnim->RepeatBehavior = copyProperties->RepeatBehavior;
    posxAnim->AutoReverse = copyProperties->AutoReverse;
    posxAnim->EasingFunction = copyProperties->EasingFunction;
    posxAnim->EnableDependentAnimation = dependent;
    posxAnim->FillBehavior = copyProperties->FillBehavior;
    posxAnim->BeginTime = copyProperties->BeginTime;
    storyboard->Children->Append(posxAnim);

    Storyboard::SetTarget(posxAnim, target);
    Storyboard::SetTargetProperty(posxAnim, propertyName);
}

} /* namespace CoreAnimation */

// clang-format on
