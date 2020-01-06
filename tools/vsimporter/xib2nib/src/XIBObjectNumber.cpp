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

#include "XIBObjectNumber.h"
#include "XIBObjectInt.h"
#include "XIBObjectDouble.h"

XIBObjectNumber::XIBObjectNumber(int num) {
    _className = "NSNumber";
    _keyName = "NS.intval";
    _val = new XIBObjectInt(num);
}

XIBObjectNumber::XIBObjectNumber(long long num) {
    _className = "NSNumber";
    _keyName = "NS.intval";
    _val = new XIBObjectInt(num);
}

XIBObjectNumber::XIBObjectNumber(bool val) {
    _className = "NSNumber";
    _keyName = "NS.intval";
    _val = new XIBObjectInt(val ? 1 : 0);
}

XIBObjectNumber::XIBObjectNumber(double val) {
    _className = "NSNumber";
    _keyName = "NS.dblval";
    _val = new XIBObjectDouble(val);
}

void XIBObjectNumber::EmitObject(NIBWriter* writer) {
    _outputClassName = "NSNumber";

    AddOutputMember(writer, _keyName, _val);
}


