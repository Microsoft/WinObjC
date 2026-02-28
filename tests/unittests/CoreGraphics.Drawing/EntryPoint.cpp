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

#include <windows.h>
#include <TestFramework.h>
#include <memory>

#include <CoreFoundation/CoreFoundation.h>

#include "DrawingTestConfig.h"

template <size_t N>
static int strconstprefix(const char* left, const char (&right)[N]) {
    // The null terminator would fail a prefix match; don't count it.
    return strncmp(left, right, N - 1);
}

static std::string __ModuleDirectory() {
    static std::string modulePath = GetCurrentTestDirectory();
    return modulePath;
}

static std::string __OutputDirectory() {
    std::string toReturn;
    toReturn.resize(_MAX_PATH, '\0');
    _getcwd(&toReturn[0], _MAX_PATH);
    return toReturn;
}

class CommandLineDrawingTestConfigImpl : public DrawingTestConfigImpl {
private:
    DrawingTestMode _mode;
    std::string _outputPath;
    std::string _comparisonPath;

public:
    CommandLineDrawingTestConfigImpl(int argc, char** argv)
        : _mode(DrawingTestMode::Compare), _outputPath(__OutputDirectory()), _comparisonPath(__ModuleDirectory() + "/data/reference") {
        for (int i = 1; i < argc; ++i) {
            char* arg = argv[i];
            if (!arg) {
                break;
            }

            if (strcmp(arg, "--generate") == 0) {
                _mode = DrawingTestMode::Generate;
            } else if (strconstprefix(arg, "--out=") == 0) {
                _outputPath = std::move(std::string(arg + 6));
            } else if (strconstprefix(arg, "--compare=") == 0) {
                _comparisonPath = std::move(std::string(arg + 10));
            }
        }
    }

    virtual DrawingTestMode GetMode() override {
        return _mode;
    }

    virtual std::string GetOutputPath() override {
        return _outputPath;
    }

    virtual std::string GetComparisonPath() override {
        return _comparisonPath;
    }

    virtual std::string GetResourcePath(const std::string& resource) override {
        // Using / as a path separator is valid on both Windows and OS X.
        return __ModuleDirectory() + "/data/" + resource;
    }
};

std::shared_ptr<DrawingTestConfigImpl> _configImpl;
/* static */ DrawingTestConfigImpl* DrawingTestConfig::Get() {
    return _configImpl.get();
}

int main(int argc, char** argv) {
    testing::InitGoogleTest(&argc, argv);

    _configImpl = std::move(std::make_shared<CommandLineDrawingTestConfigImpl>(argc, argv));

    auto result = RUN_ALL_TESTS();
    return result;
}
