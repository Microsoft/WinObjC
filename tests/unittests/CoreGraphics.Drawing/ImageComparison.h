//******************************************************************************
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

#pragma once

#include <CoreGraphics/CGImage.h>
#include <Starboard/SmartTypes.h>
#include <cstdlib>

enum class ImageComparisonResult : unsigned int { Unknown = 0, Incomparable, Different, Same };

struct Pixel {
    // Value is slightly below threshold at which differences between two pixels are perceptible
    // Allows us to safely ignore minute differences which can pop up between OS versions
    static constexpr size_t sc_visualThreshold = 4;

    uint8_t r, g, b, a;
    bool operator==(const Pixel& o) const {
        return r == o.r && g == o.g && g == o.g && b == o.b && a == o.a;
    }
    bool operator!=(const Pixel& o) const {
        return !(*this == o);
    }
    bool near(const Pixel& o) const {
        return (std::abs(r - o.r) + std::abs(g - o.g) + std::abs(b - o.b) + std::abs(a - o.a)) < sc_visualThreshold;
    }
};

template <size_t FailureThreshold = 1>
struct PixelComparisonModeExact {
    static constexpr size_t Threshold = FailureThreshold;
    template <typename LP, typename RP>
    Pixel ComparePixels(const LP& background, const LP& bp, const RP& cp, size_t& npxchg);
};

template <size_t FailureThreshold = 1>
struct PixelComparisonModeMask {
    static constexpr size_t Threshold = FailureThreshold;
    template <typename LP, typename RP>
    Pixel ComparePixels(const LP& background, const LP& bp, const RP& cp, size_t& npxchg);
};

template <size_t FailureThreshold = 1>
struct PixelComparisonModeDifferenceLimen {
    static constexpr size_t Threshold = FailureThreshold;
    template <typename LP, typename RP>
    Pixel ComparePixels(const LP& background, const LP& bp, const RP& cp, size_t& npxchg);
};

struct ImageDelta {
    ImageComparisonResult result;
    size_t differences;
    woc::unique_cf<CGImageRef> deltaImage;

    ImageDelta(ImageComparisonResult result) : result(result), differences(0), deltaImage(nullptr) {
    }

    ImageDelta(ImageComparisonResult result, size_t differences, CGImageRef deltaImage)
        : result(result), differences(differences), deltaImage(CGImageRetain(deltaImage)) {
    }

    ImageDelta(ImageDelta&& other) : result(other.result), differences(other.differences), deltaImage(other.deltaImage.release()) {
    }
};

class ImageComparator {
public:
    virtual ImageDelta CompareImages(CGImageRef left, CGImageRef right) = 0;
};

template <typename PixelComparisonMode = PixelComparisonModeExact<1>>
class PixelByPixelImageComparator : public ImageComparator {
public:
    ImageDelta CompareImages(CGImageRef left, CGImageRef right) override;
};
