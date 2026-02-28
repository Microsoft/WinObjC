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
#include <string>

enum class DrawingTestMode : int { Generate, Compare };

class DrawingTestConfigImpl {
public:
    virtual DrawingTestMode GetMode() = 0;
    virtual std::string GetOutputPath() = 0;
    virtual std::string GetComparisonPath() = 0;
    virtual std::string GetResourcePath(const std::string& resource) = 0;
};

class DrawingTestConfig {
public:
    static DrawingTestConfigImpl* Get();
};
