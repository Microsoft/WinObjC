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

#include <stdio.h>

#ifdef _WOC_APP
#if defined(_M_IX86)
#pragma comment(linker, "/INCLUDE:___refMTAThread")
#else
#pragma comment(linker, "/INCLUDE:__refMTAThread")
#endif

extern "C"
{
    int __cdecl WOCMain(::Platform::Array<::Platform::String^>^ args)
    {
        int main(int argc, char *argv[]);

        return main(0, NULL);
    }
}

#ifdef _M_ARM
 #pragma comment(linker, "/alternatename:?main@@YAHP$01$AAV?$Array@P$AAVString@Platform@@$00@Platform@@@Z=WOCMain")
#else
 #pragma comment(linker, "/alternatename:?main@@YAHP$01$AAV?$Array@P$AAVString@Platform@@$00@Platform@@@Z=_WOCMain")
#endif
#else // _WOC_APP
// We need to export something to ensure we link a viable PE
void __declspec(dllexport) EbrEnsureLinkage()
{

}
#endif // !_WOC_APP

