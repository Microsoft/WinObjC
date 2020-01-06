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

#include "UITextInputTraits.h"
#include <assert.h>
#include <map>

static std::map<std::string, UIReturnKeyType> storyToReturnType = {
    { "go", UIReturnKeyTypeGo },
    { "google", UIReturnKeyTypeGoogle },
    { "join", UIReturnKeyTypeJoin },
    { "next", UIReturnKeyTypeNext },
    { "route", UIReturnKeyTypeRoute },
    { "search", UIReturnKeyTypeSearch },
    { "send", UIReturnKeyTypeSend },
    { "yahoo", UIReturnKeyTypeYahoo },
    { "done", UIReturnKeyTypeDone },
    { "emergencyCall", UIReturnKeyTypeEmergencyCall },
    { "continue", UIReturnKeyTypeContinue }
};

static std::map<std::string, UIAutocapitalizationType> storyToAutocapitalizationType = {
    { "words", UIAutocapitalizationTypeWords },
    { "sentences", UIAutocapitalizationTypeSentences },
    { "allCharacters", UIAutocapitalizationTypeAllCharacters }
};

typedef enum {
    GenericBooleanOptionDefault = 0,
    GenericBooleanOptionNo = 1,
    GenericBooleanOptionYes = 2
} GenericBooleanOption;

static std::map<std::string, GenericBooleanOption> storyToGenericBooleanOption = {
    { "no", GenericBooleanOptionNo },
    { "yes", GenericBooleanOptionYes },
    // just in case also capitalized
    { "NO", GenericBooleanOptionNo },
    { "YES", GenericBooleanOptionYes },
};

static std::map<std::string, UIKeyboardAppearance> storyToKeyboardAppearance = {
    { "alert", UIKeyboardAppearanceAlert },
    { "light", UIKeyboardAppearanceLight }
};

static std::map<std::string, UIKeyboardType> storyToKeyboardType = {
    { "alphabet", UIKeyboardTypeAlphabet },
    { "numbersAndPunctuation", UIKeyboardTypeNumbersAndPunctuation },
    { "URL", UIKeyboardTypeURL },
    { "numberPad", UIKeyboardTypeNumberPad },
    { "phonePad", UIKeyboardTypePhonePad },
    { "namePhonePad", UIKeyboardTypeNamePhonePad },
    { "emailAddress", UIKeyboardTypeEmailAddress },
    { "decimalPad", UIKeyboardTypeDecimalPad },
    { "twitter", UIKeyboardTypeTwitter },
    { "webSearch", UIKeyboardTypeWebSearch },
    { "ASCIICapableNumberPad", UIKeyboardTypeASCIICapableNumberPad }
};


UITextInputTraits::UITextInputTraits() {
    _returnKeyType = UIReturnKeyTypeDefault;
    _textContentType = NULL;
    _autocapitalizationType = UIAutocapitalizationTypeNone;
    _autocorrectionType = GenericBooleanOptionDefault;
    _smartDashesType = GenericBooleanOptionDefault;
    _smartInsertDeleteType = GenericBooleanOptionDefault;
    _smartQuotesType = GenericBooleanOptionDefault;
    _spellCheckingType = GenericBooleanOptionDefault;
    _keyboardType = UIKeyboardTypeDefault;
    _keyboardAppearance = UIKeyboardAppearanceDefault;
    _secureTextEntry = false;
}

void UITextInputTraits::InitFromXIB(XIBObject* obj) {
    // Outdated code do nothing
}

void UITextInputTraits::InitFromStory(XIBObject* obj) {
    const char *attr;
    if ((attr = obj->getAttrAndHandle("returnKeyType"))) {
        if (storyToReturnType.find(attr) != storyToReturnType.end()) {
            _returnKeyType = storyToReturnType[attr];
        }
    }
    
    if ((attr = obj->getAttrAndHandle("autocapitalizationType"))) {
        if (storyToAutocapitalizationType.find(attr) != storyToAutocapitalizationType.end()) {
            _autocapitalizationType = storyToAutocapitalizationType[attr];
        }
    }
    
    if ((attr = obj->getAttrAndHandle("autocorrectionType"))) {
        if (storyToGenericBooleanOption.find(attr) != storyToGenericBooleanOption.end()) {
            _autocorrectionType = storyToGenericBooleanOption[attr];
        }
    }

    if ((attr = obj->getAttrAndHandle("smartDashesType"))) {
        if (storyToGenericBooleanOption.find(attr) != storyToGenericBooleanOption.end()) {
            _smartDashesType = storyToGenericBooleanOption[attr];
        }
    }

    if ((attr = obj->getAttrAndHandle("smartInsertDeleteType"))) {
        if (storyToGenericBooleanOption.find(attr) != storyToGenericBooleanOption.end()) {
            _smartInsertDeleteType = storyToGenericBooleanOption[attr];
        }
    }

    if ((attr = obj->getAttrAndHandle("smartQuotesType"))) {
        if (storyToGenericBooleanOption.find(attr) != storyToGenericBooleanOption.end()) {
            _smartQuotesType = storyToGenericBooleanOption[attr];
        }
    }

    if ((attr = obj->getAttrAndHandle("spellCheckingType"))) {
        if (storyToGenericBooleanOption.find(attr) != storyToGenericBooleanOption.end()) {
            _spellCheckingType = storyToGenericBooleanOption[attr];
        }
    }

    if ((attr = obj->getAttrAndHandle("keyboardType"))) {
        if (storyToKeyboardType.find(attr) != storyToKeyboardType.end()) {
            _keyboardType = storyToKeyboardType[attr];
        }
    }

    if ((attr = obj->getAttrAndHandle("keyboardAppearance"))) {
        if (storyToKeyboardAppearance.find(attr) != storyToKeyboardAppearance.end()) {
            _keyboardAppearance = storyToKeyboardAppearance[attr];
        }
    }

    if ((attr = obj->getAttrAndHandle("secureTextEntry"))) {
        if (strcmp(attr, "YES") == 0) {
            _secureTextEntry = true;
        }
    }
    
    _textContentType = obj->getAttrAndHandle("textContentType");
}

void UITextInputTraits::ConvertStaticMappings(NIBWriter* writer, XIBObject* obj) {
    if (_returnKeyType != UIReturnKeyTypeDefault)
        obj->AddInt(writer, "UIReturnKeyType", _returnKeyType);
    
    if (_autocapitalizationType != UIAutocapitalizationTypeNone)
        obj->AddInt(writer, "UIAutocapitalizationType", _autocapitalizationType);
    
    if (_autocorrectionType != GenericBooleanOptionDefault)
        obj->AddInt(writer, "UIAutocorrectionType", _autocorrectionType);
    
    if (_smartDashesType != GenericBooleanOptionDefault)
        obj->AddInt(writer, "UITextSmartDashesType", _smartDashesType);
    
    if (_smartInsertDeleteType != GenericBooleanOptionDefault)
        obj->AddInt(writer, "UITextSmartInsertDeleteType", _smartInsertDeleteType);
    
    if (_smartQuotesType != GenericBooleanOptionDefault)
        obj->AddInt(writer, "UITextSmartQuotesType", _smartQuotesType);

    // TODO: seems as spellCheckingType is not get out for iOS nib
    // if (_spellCheckingType != GenericBooleanOptionDefault)
    //    obj->AddInt(writer, "UI????Type", _spellCheckingType);

    if (_keyboardType != UIKeyboardTypeDefault)
        obj->AddInt(writer, "UIKeyboardType", _keyboardType);

    if (_keyboardAppearance != UIKeyboardAppearanceDefault)
        obj->AddInt(writer, "UIKeyboardAppearance", _keyboardAppearance);

    if (_secureTextEntry)
        obj->AddBool(writer, "UISecureTextEntry", _secureTextEntry);
    
    if (_textContentType)
        obj->AddString(writer, "UITextContentType", _textContentType);
}
