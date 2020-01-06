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

typedef enum {
    UIReturnKeyTypeDefault = 0,
    UIReturnKeyTypeGo,
    UIReturnKeyTypeGoogle,
    UIReturnKeyTypeJoin,
    UIReturnKeyTypeNext,
    UIReturnKeyTypeRoute,
    UIReturnKeyTypeSearch,
    UIReturnKeyTypeSend,
    UIReturnKeyTypeYahoo,
    UIReturnKeyTypeDone,
    UIReturnKeyTypeEmergencyCall,
    UIReturnKeyTypeContinue
} UIReturnKeyType;

typedef enum {
    UIAutocapitalizationTypeNone = 0,
    UIAutocapitalizationTypeWords,
    UIAutocapitalizationTypeSentences,
    UIAutocapitalizationTypeAllCharacters,
} UIAutocapitalizationType;

typedef enum {
    UIKeyboardTypeDefault = 0,
    UIKeyboardTypeAlphabet,
    UIKeyboardTypeNumbersAndPunctuation,
    UIKeyboardTypeURL,
    UIKeyboardTypeNumberPad,
    UIKeyboardTypePhonePad,
    UIKeyboardTypeNamePhonePad,
    UIKeyboardTypeEmailAddress,
    UIKeyboardTypeDecimalPad,
    UIKeyboardTypeTwitter,
    UIKeyboardTypeWebSearch,
    UIKeyboardTypeASCIICapableNumberPad
} UIKeyboardType;

typedef enum {
    UIKeyboardAppearanceDefault = 0,
    UIKeyboardAppearanceAlert,
    UIKeyboardAppearanceLight
} UIKeyboardAppearance;

class UITextInputTraits : public ObjectConverter {
public:
    int _returnKeyType;
    const char *_textContentType;
    int _autocapitalizationType;
    int _autocorrectionType;
    int _smartDashesType;
    int _smartInsertDeleteType;
    int _smartQuotesType;
    int _spellCheckingType;
    int _keyboardType;
    int _keyboardAppearance;
    bool _secureTextEntry;
    
    UITextInputTraits();
    virtual void InitFromXIB(XIBObject* obj);
    virtual void InitFromStory(XIBObject* obj);
    virtual void ConvertStaticMappings(NIBWriter* writer, XIBObject* obj);
};
