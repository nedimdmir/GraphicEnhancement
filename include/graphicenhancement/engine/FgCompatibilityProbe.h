#pragma once
#include <atomic>
#include <string>
#include <windows.h>
namespace graphicenhancement::pipeline { struct EnhanceGraphDesc; }
namespace graphicenhancement::gfx { class D3D12DeviceContext; }
namespace graphicenhancement::engine {
// Installed by the executable that implements --fg-compat-probe.
void setFgCompatibilityProbeExecutable(std::wstring path);
bool checkFgCompatibility(const pipeline::EnhanceGraphDesc&, const gfx::D3D12DeviceContext&, const std::atomic<bool>& cancel);
int runFgCompatibilityProbe(HANDLE mapping);
}
