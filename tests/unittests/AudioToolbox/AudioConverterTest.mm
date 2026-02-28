//******************************************************************************
//
// Copyright (c) 2017 Intel Corporation. All rights reserved.
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

#include <TestFramework.h>
#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <StubReturn.h>
#import <NSBundleInternal.h>
#import <NSLogging.h>

static const wchar_t* TAG = L"AudioConverterTest";

#import <AudioToolbox/AudioConverterInternal.h>


TEST(AudioToolbox, AudioConverterTest) {
    AudioStreamBasicDescription inFormat;
    inFormat.mSampleRate = 44100;
    inFormat.mFormatID = kAudioFormatLinearPCM;
    inFormat.mFormatFlags = (kAudioFormatFlagIsPacked | kAudioFormatFlagIsSignedInteger);
    inFormat.mBytesPerPacket = 4;
    inFormat.mFramesPerPacket = 1;
    inFormat.mBytesPerFrame = 4;
    inFormat.mChannelsPerFrame = 2;
    inFormat.mBitsPerChannel = 16;
    inFormat.mReserved = 0;

    AudioStreamBasicDescription outFormat;
    outFormat.mSampleRate = 44100;
    outFormat.mFormatID = kAudioFormatLinearPCM;
    outFormat.mFormatFlags = (kAudioFormatFlagIsPacked | kAudioFormatFlagIsFloat);
    outFormat.mBytesPerPacket = 8;
    outFormat.mFramesPerPacket = 1;
    outFormat.mBytesPerFrame = 8;
    outFormat.mChannelsPerFrame = 2;
    outFormat.mBitsPerChannel = 32;
    outFormat.mReserved = 0;

    AudioConverterRef converter;
    OSStatus err = noErr;
    err = AudioConverterNew(&inFormat, &outFormat, &converter);
    ASSERT_EQ(err, 0);

    DWORD flag = MF_MEDIATYPE_EQUAL_FORMAT_USER_DATA;
    DWORD streamID = 0;
    ComPtr<IMFTransform> mediaTransform = [(__bridge AudioConverter*)converter getTransform];

    ComPtr<IMFMediaType> expectedInMediaType = nullptr;
    _setMFProperties(&inFormat, &expectedInMediaType);
    ComPtr<IMFMediaType> resInMediaType = nullptr;
    mediaTransform->GetInputCurrentType(streamID, &resInMediaType);
    HRESULT hr = resInMediaType->IsEqual(expectedInMediaType.Get(), &flag);
    HRESULT hrExpected = S_OK;
    ASSERT_EQ(hr, hrExpected);

    ComPtr<IMFMediaType> expectedOutMediaType = nullptr;
    _setMFProperties(&outFormat, &expectedOutMediaType);
    ComPtr<IMFMediaType> resOutMediaType = nullptr;
    mediaTransform->GetOutputCurrentType(streamID, &resOutMediaType);
    hr = resOutMediaType->IsEqual(expectedOutMediaType.Get(), &flag);
    ASSERT_EQ(hr, hrExpected);

    err = AudioConverterDispose(converter);
    ASSERT_EQ(err, 0);
}