#pragma once
#include <windows.h>
#include <string>
namespace graphicenhancement::virtualcam {
HRESULT registerModule(const wchar_t* absoluteDllPath,bool x86,bool machine=false);
HRESULT unregisterModule(bool x86,bool machine=false);
std::wstring registeredModule(bool x86,bool machine=false);
}
