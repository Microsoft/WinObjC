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

#include <CoreFoundation/CoreFoundation.h>
#include <CoreGraphics/CoreGraphics.h>

#include <string>

CGImageRef _CGImageCreateFromPNGFile(CFStringRef filename, bool shouldInterpolate = false);
CGImageRef _CGImageCreateFromJPEGFile(CFStringRef filename);
CFDataRef _CFDataCreatePNGFromCGImage(CGImageRef image);
bool _WriteCFDataToFile(CFDataRef data, CFStringRef filename);
CFDataRef _CFDataCreateFromCGImage(CGImageRef image);
CFStringRef _CFStringCreateAbsolutePath(CFStringRef relativePath);
CFStringRef _CFStringCreateWithStdString(const std::string& string);
