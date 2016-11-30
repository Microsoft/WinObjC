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
//*****************************************************************************/
#pragma once

#import <CoreGraphics/CoreGraphics.h>

#ifdef __cplusplus

#pragma region CFRange
inline bool operator==(const CFRange& lhs, const CFRange& rhs) {
    return lhs.location == rhs.location && lhs.length == rhs.length;
}

template <typename T>
std::basic_ostream<T>& operator<<(std::basic_ostream<T>& os, const CFRange& range) {
    os << "{ location: " << range.location << ", length: " << range.length << " }";
    return os;
}

#pragma endregion

#pragma region CGPoint
inline bool operator==(const CGPoint& lhs, const CGPoint& rhs) {
    return lhs.x == rhs.x && lhs.y == rhs.y;
}

template <typename T>
std::basic_ostream<T>& operator<<(std::basic_ostream<T>& os, const CGPoint& point) {
    os << "{ x: " << point.x << ", y: " << point.y << " }";
    return os;
}

#pragma endregion

#pragma region CGSize
inline bool operator==(const CGSize& lhs, const CGSize& rhs) {
    return lhs.width == rhs.width && lhs.height == rhs.height;
}

template <typename T>
std::basic_ostream<T>& operator<<(std::basic_ostream<T>& os, const CGSize& size) {
    os << "{ width: " << size.width << ", height: " << size.height << " }";
    return os;
}

#pragma endregion

#pragma region CGRect
inline bool operator==(const CGRect& lhs, const CGRect& rhs) {
    return lhs.origin == rhs.origin && lhs.size == rhs.size;
}

template <typename T>
std::basic_ostream<T>& operator<<(std::basic_ostream<T>& os, const CGRect& rect) {
    os << "{ origin: " << rect.origin << ", size: " << rect.size << " }";
    return os;
}

#pragma endregion

#endif