#pragma once
#include <windows.h>

namespace graphicenhancement::ngx {
// Borrowed, process-pinned system NVAPI module. Never FreeLibrary this handle.
// No NvAPI_Initialize/Unload or architecture override is performed here.
HMODULE processNvapi();
}
