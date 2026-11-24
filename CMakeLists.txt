cmake_minimum_required(VERSION 3.24)

project(graphicenhancement VERSION 2.2.1 LANGUAGES C CXX)

# The Windows runtime needs the resource compiler; Linux does not have one.
if(WIN32)
  enable_language(RC)
endif()
# Moonlight/Xbox have C sources independently of the optional PS5 backend.
# Shown in the EXE's version resource and in the package name. CMake versions
# must be numeric, so the beta marker lives here instead.
set(GRAPHICENHANCEMENT_DISPLAY_VERSION "${PROJECT_VERSION}" CACHE STRING "Human-readable version string")
# The cache keeps the first value it ever saw, so a release that bumps
# project(VERSION) used to ship an EXE still stamped with the previous display
# string. Re-align it whenever the cached label does not start with the project
# version; an explicit matching label (e.g. "1.4.0beta") is still honoured.
if(NOT GRAPHICENHANCEMENT_DISPLAY_VERSION MATCHES "^${PROJECT_VERSION}")
  message(STATUS "GRAPHICENHANCEMENT_DISPLAY_VERSION ${GRAPHICENHANCEMENT_DISPLAY_VERSION} does not match project ${PROJECT_VERSION}; using ${PROJECT_VERSION}")
  set(GRAPHICENHANCEMENT_DISPLAY_VERSION "${PROJECT_VERSION}" CACHE STRING "Human-readable version string" FORCE)
endif()

# ---------------------------------------------------------------------------
# Linux: the OBS filter module only. Every target below is COM / D3D11 / D3D12
# / Win32 bound, so the portable part of the pipeline lives in linux/ instead
# of growing ifdefs through 100k lines of Windows code. See docs/OBS_FILTER.md.
# ---------------------------------------------------------------------------
if(NOT WIN32)
  add_subdirectory(linux/obs)
  return()
endif()
add_subdirectory(src/virtualcam)

# Decode the localized compiler output using the current console code page.
# CMake needs UTF-8 internally to write rules.ninja; the generator then emits
# the matching native prefix so Ninja records header dependencies.
if(MSVC AND CMAKE_GENERATOR MATCHES "Ninja")
  set(GRAPHICENHANCEMENT_INCLUDE_PROBE "${CMAKE_CURRENT_BINARY_DIR}/CMakeFiles/graphicenhancement-include-probe")
  file(WRITE "${GRAPHICENHANCEMENT_INCLUDE_PROBE}.h" "// Dependency parser probe\n")
  file(WRITE "${GRAPHICENHANCEMENT_INCLUDE_PROBE}.cpp" "#include \"graphicenhancement-include-probe.h\"\n")
  execute_process(COMMAND "${CMAKE_CXX_COMPILER}" /nologo /utf-8 /showIncludes /c /TP "${GRAPHICENHANCEMENT_INCLUDE_PROBE}.cpp" "/Fo${GRAPHICENHANCEMENT_INCLUDE_PROBE}.obj"
    OUTPUT_VARIABLE GRAPHICENHANCEMENT_INCLUDE_OUTPUT ERROR_VARIABLE GRAPHICENHANCEMENT_INCLUDE_OUTPUT
    RESULT_VARIABLE GRAPHICENHANCEMENT_INCLUDE_RESULT ENCODING AUTO)
  if(NOT GRAPHICENHANCEMENT_INCLUDE_RESULT EQUAL 0 OR NOT GRAPHICENHANCEMENT_INCLUDE_OUTPUT MATCHES "(^|[\r\n])([^\r\n]*: )[ ]*[A-Za-z]:[^\r\n]*graphicenhancement-include-probe.h")
    message(FATAL_ERROR "Unable to verify MSVC/Ninja header dependency prefix")
  endif()
  set(CMAKE_CL_SHOWINCLUDES_PREFIX "${CMAKE_MATCH_2}")
endif()

# ---------------------------------------------------------------------------
# GraphicEnhancement cache variables and feature switches (Playbook section 5.1).
# Machine-specific absolute paths are resolved by scripts/build.ps1 at
# configure time; CMakePresets.json stays free of local paths.
# ---------------------------------------------------------------------------
set(GRAPHICENHANCEMENT_DLSS_SDK_ROOT "" CACHE PATH "NVIDIA DLSS SDK root")
set(GRAPHICENHANCEMENT_NVOF_SDK_ROOT "" CACHE PATH "NVIDIA Optical Flow SDK root")
if(NOT GRAPHICENHANCEMENT_NVOF_SDK_ROOT)
  set(GRAPHICENHANCEMENT_NVOF_CANDIDATE "${CMAKE_CURRENT_SOURCE_DIR}/third_party_local/nvidia/Optical_Flow_SDK_5.0.7")
  if(EXISTS "${GRAPHICENHANCEMENT_NVOF_CANDIDATE}/NvOFInterface/nvOpticalFlowCommon.h")
    set(GRAPHICENHANCEMENT_NVOF_SDK_ROOT "${GRAPHICENHANCEMENT_NVOF_CANDIDATE}")
  endif()
endif()
set(GRAPHICENHANCEMENT_RUNTIME_ROOT "" CACHE PATH "Local NVIDIA runtime root")
set(GRAPHICENHANCEMENT_FFMPEG_ROOT "" CACHE PATH "vcpkg-installed x64-windows root with FFmpeg (player deps)")
option(GRAPHICENHANCEMENT_ENABLE_DEINTERLACE "Enable optional LGPL FFmpeg deinterlacing module" ON)
set(GRAPHICENHANCEMENT_CLIP_TOOLS_ROOT "" CACHE PATH "vcpkg-installed x64-windows root with openh264-enabled FFmpeg (clip tooling only)")

option(GRAPHICENHANCEMENT_ENABLE_EXPERIMENTAL_DLSSNR
  "Enable local-only experimental Feature 18 adapter" OFF)
option(GRAPHICENHANCEMENT_ENABLE_REMOTEPLAY "Build PS5 Remote Play with pinned Chiaki source" OFF)
option(GRAPHICENHANCEMENT_ENABLE_MOONLIGHT "Build the Moonlight / Sunshine streaming core (pinned moonlight-common-c)" OFF)
option(GRAPHICENHANCEMENT_ENABLE_XBOX "Build Xbox home streaming (unofficial; libdatachannel from the vcpkg tree)" OFF)
option(GRAPHICENHANCEMENT_ENABLE_DLSS_SR "Enable public DLSS SR backend" OFF)
option(GRAPHICENHANCEMENT_ENABLE_DLSS_FG "Enable public DLSSG backend" OFF)
option(GRAPHICENHANCEMENT_ENABLE_NVOF "Enable NVIDIA Optical Flow guidance" OFF)
option(GRAPHICENHANCEMENT_ENABLE_D3D12_DEBUG "Enable D3D12 debug layer" ON)
set(GRAPHICENHANCEMENT_FIDELITYFX_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/third_party_local/amd/FidelityFX-SDK/sdk" CACHE PATH "Local official FidelityFX SDK 1.1.4")
set(GRAPHICENHANCEMENT_XESS_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/third_party_local/intel/xess-3.0.2" CACHE PATH "Local Intel XeSS SDK 3.0.2")
set(GRAPHICENHANCEMENT_FIDELITYFX2_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/third_party_local/amd/FidelityFX-SDK-2.3.0/Kits/FidelityFX" CACHE PATH "Local AMD FidelityFX SDK 2.3.0 Kits/FidelityFX tree")

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")
include(GraphicEnhancementWarnings)
include(GraphicEnhancementShaders)

# NVIDIA's static NGX core shim (nvsdk_ngx_s*.lib) is built against the
# static CRT (MT/MTd); match it for the diagnostic tools that link it.
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")

# Moonlight targets come after the runtime setting: they link into the same
# executables as the rest of the engine, so they must use the static CRT too.
if(GRAPHICENHANCEMENT_ENABLE_MOONLIGHT)
  set(GRAPHICENHANCEMENT_ROOT "${CMAKE_CURRENT_SOURCE_DIR}")
  include(GraphicEnhancementMoonlight)
  graphicenhancement_apply_warnings(graphicenhancement_moonlight_protocol)
  add_executable(graphicenhancement_moonlight_protocol_tests tests/moonlight/ProtocolTests.cpp)
  target_compile_features(graphicenhancement_moonlight_protocol_tests PRIVATE cxx_std_20)
  target_compile_definitions(graphicenhancement_moonlight_protocol_tests PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN)
  target_link_libraries(graphicenhancement_moonlight_protocol_tests PRIVATE graphicenhancement_moonlight_protocol)
  graphicenhancement_apply_warnings(graphicenhancement_moonlight_protocol_tests)
  # The same fake host as a process, for the end-to-end UI check (scripts/moonlight/ui-demo.py).
  add_executable(graphicenhancement_moonlight_mockhost tests/moonlight/MockHostServer.cpp)
  target_compile_features(graphicenhancement_moonlight_mockhost PRIVATE cxx_std_20)
  target_compile_definitions(graphicenhancement_moonlight_mockhost PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN)
  target_include_directories(graphicenhancement_moonlight_mockhost PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/tests/moonlight)
  target_link_libraries(graphicenhancement_moonlight_mockhost PRIVATE graphicenhancement_moonlight_protocol)
endif()

# ---------------------------------------------------------------------------
# Targets grow phase by phase; only what actually compiles is declared.
# ---------------------------------------------------------------------------
add_library(graphicenhancement_base STATIC
  src/base/Log.cpp
  src/base/PrivateFrameTrace.cpp
  src/base/NgxResult.cpp
  src/base/FileIdentity.cpp
  src/base/InstanceWindow.cpp
  src/base/RuntimePaths.cpp
  src/base/ThunkHook.cpp
  # .cube parsing, the runtime LUT store and named colour looks: low level, no
  # D3D12, shared by the ingest pipeline and the settings/import paths.
  src/engine/ColorLut.cpp
  src/engine/ColorLookStore.cpp
)
graphicenhancement_apply_warnings(graphicenhancement_base)
target_compile_options(graphicenhancement_base PUBLIC /utf-8)
target_compile_features(graphicenhancement_base PUBLIC cxx_std_20)
target_compile_definitions(graphicenhancement_base PUBLIC
  UNICODE _UNICODE WIN32_LEAN_AND_MEAN NOMINMAX)
target_include_directories(graphicenhancement_base PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/include)
target_link_libraries(graphicenhancement_base PUBLIC bcrypt wintrust crypt32 version)

add_executable(graphicenhancement_logger_tests tests/unit/LoggerTests.cpp)
target_compile_features(graphicenhancement_logger_tests PRIVATE cxx_std_20)
target_link_libraries(graphicenhancement_logger_tests PRIVATE graphicenhancement_base)

add_executable(graphicenhancement_instance_recovery_tests tests/unit/InstanceRecoveryTests.cpp)
target_compile_features(graphicenhancement_instance_recovery_tests PRIVATE cxx_std_20)
target_link_libraries(graphicenhancement_instance_recovery_tests PRIVATE graphicenhancement_base user32)
graphicenhancement_apply_warnings(graphicenhancement_logger_tests)

add_executable(graphicenhancement_private_frame_trace_tests tests/unit/PrivateFrameTraceTests.cpp)
target_compile_features(graphicenhancement_private_frame_trace_tests PRIVATE cxx_std_20)
target_link_libraries(graphicenhancement_private_frame_trace_tests PRIVATE graphicenhancement_base)

# On-screen text reading for live translation (OCR passes, cleanup, line timing),
# with a scripted OCR engine: no GPU, no Windows OCR language needed.
add_executable(graphicenhancement_screen_text_tests tests/unit/ScreenTextTests.cpp src/engine/ScreenText.cpp)
target_compile_features(graphicenhancement_screen_text_tests PRIVATE cxx_std_20)
target_link_libraries(graphicenhancement_screen_text_tests PRIVATE graphicenhancement_base)

# When each on-screen line's translation is shown (src/ui/CaptionPresenter.h, no Qt).
add_executable(graphicenhancement_caption_presenter_tests tests/unit/CaptionPresenterTests.cpp)
target_compile_features(graphicenhancement_caption_presenter_tests PRIVATE cxx_std_20)

add_executable(graphicenhancement_export_timeline_tests tests/unit/ExportTimelineTests.cpp)
target_compile_features(graphicenhancement_export_timeline_tests PRIVATE cxx_std_20)
target_link_libraries(graphicenhancement_export_timeline_tests PRIVATE graphicenhancement_base)
graphicenhancement_apply_warnings(graphicenhancement_export_timeline_tests)

add_library(graphicenhancement_gfx STATIC
  src/gfx/GpuSchedulingPriority.cpp
  src/gfx/NvidiaVrrProfile.cpp
  src/gfx/D3D12DeviceContext.cpp
  src/gfx/CommandSlotRing.cpp
  src/gfx/PresentSink.cpp
  src/gfx/XessPresenter.cpp
  src/gfx/XessMfgUnlock.cpp
  src/gfx/XessPacing.cpp
  src/gfx/FsrFgPresenter.cpp
  src/gfx/AmfFrcBackend.cpp
  src/gfx/RifeDmlBackend.cpp
  src/gfx/AmfVideoSrBackend.cpp
  src/gfx/FsrSrBackend.cpp
)
graphicenhancement_apply_warnings(graphicenhancement_gfx)
target_compile_features(graphicenhancement_gfx PUBLIC cxx_std_20)
target_link_libraries(graphicenhancement_gfx PUBLIC graphicenhancement_base d3d12 dxgi dxguid)

# Isolated driver-profile policy/ABI tests: no NGX, media source or graphics device.
add_executable(graphicenhancement_vrr_profile_tests tests/unit/NvidiaVrrProfileTests.cpp src/gfx/NvidiaVrrProfile.cpp)
target_compile_features(graphicenhancement_vrr_profile_tests PRIVATE cxx_std_20)
target_include_directories(graphicenhancement_vrr_profile_tests PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/include)
target_compile_definitions(graphicenhancement_vrr_profile_tests PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN UNICODE _UNICODE)
graphicenhancement_apply_warnings(graphicenhancement_vrr_profile_tests)
if(EXISTS "${GRAPHICENHANCEMENT_XESS_ROOT}/inc/xess_fg/xefg_swapchain_d3d12.h")
  target_include_directories(graphicenhancement_gfx PRIVATE "${GRAPHICENHANCEMENT_XESS_ROOT}/inc")
  target_compile_definitions(graphicenhancement_gfx PRIVATE GRAPHICENHANCEMENT_HAS_XESS=1)
endif()
# AMD AMF SDK headers (MIT) for AMD FRC; the runtime comes with the AMD driver.
set(GRAPHICENHANCEMENT_AMF_SDK_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/third_party_local/amd/AMF-SDK-1.5.3" CACHE PATH "AMD AMF SDK (include/core, include/components)")
if(EXISTS "${GRAPHICENHANCEMENT_AMF_SDK_ROOT}/include/components/FRC.h")
  target_include_directories(graphicenhancement_gfx PRIVATE "${GRAPHICENHANCEMENT_AMF_SDK_ROOT}/include")
  target_compile_definitions(graphicenhancement_gfx PRIVATE GRAPHICENHANCEMENT_HAS_AMF=1)
  if(EXISTS "${GRAPHICENHANCEMENT_AMF_SDK_ROOT}/include/components/HQScaler.h")
    target_compile_definitions(graphicenhancement_gfx PRIVATE GRAPHICENHANCEMENT_HAS_AMF_HQ_SCALER=1)
  endif()
  target_link_libraries(graphicenhancement_gfx PRIVATE ole32)
else()
  message(STATUS "AMF SDK headers not found at ${GRAPHICENHANCEMENT_AMF_SDK_ROOT}; AMD FRC is unavailable in this build")
endif()
# RIFE frame generation: ONNX Runtime (MIT) and DirectML headers only; the
# runtime DLLs and models are loaded from runtime/rife at run time.
set(GRAPHICENHANCEMENT_ORT_DML_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/deps/ort-dml" CACHE PATH "ONNX Runtime DirectML NuGet (ort/build/native/include) and DirectML NuGet (dml/include)")
if(EXISTS "${GRAPHICENHANCEMENT_ORT_DML_ROOT}/ort/build/native/include/dml_provider_factory.h" AND EXISTS "${GRAPHICENHANCEMENT_ORT_DML_ROOT}/dml/include/DirectML.h")
  target_include_directories(graphicenhancement_gfx PRIVATE "${GRAPHICENHANCEMENT_ORT_DML_ROOT}/ort/build/native/include" "${GRAPHICENHANCEMENT_ORT_DML_ROOT}/dml/include")
  target_compile_definitions(graphicenhancement_gfx PRIVATE GRAPHICENHANCEMENT_HAS_RIFE_DML=1)
else()
  message(STATUS "ONNX Runtime DirectML headers not found at ${GRAPHICENHANCEMENT_ORT_DML_ROOT}; RIFE is unavailable in this build")
endif()
if(EXISTS "${GRAPHICENHANCEMENT_FIDELITYFX2_ROOT}/framegeneration/include/dx12/ffx_api_framegeneration_dx12.h")
  target_include_directories(graphicenhancement_gfx PRIVATE
    "${GRAPHICENHANCEMENT_FIDELITYFX2_ROOT}/api/include"
    "${GRAPHICENHANCEMENT_FIDELITYFX2_ROOT}/framegeneration/include"
    "${GRAPHICENHANCEMENT_FIDELITYFX2_ROOT}/upscalers/include")
  target_compile_definitions(graphicenhancement_gfx PRIVATE GRAPHICENHANCEMENT_HAS_FSR=1)
endif()
if(GRAPHICENHANCEMENT_ENABLE_D3D12_DEBUG)
  target_compile_definitions(graphicenhancement_gfx PUBLIC GRAPHICENHANCEMENT_D3D12_DEBUG=1)
endif()

# ---------------------------------------------------------------------------
# graphicenhancement_ngx: NGX core host + local experimental DLSSNR adapter.
# Compiled only with the explicit experimental switch; missing SDK paths are
# a configure-time failure, never a runtime surprise (Playbook 5.1/8.1).
# ---------------------------------------------------------------------------
if(GRAPHICENHANCEMENT_ENABLE_EXPERIMENTAL_DLSSNR)
  if(NOT GRAPHICENHANCEMENT_DLSS_SDK_ROOT OR NOT EXISTS "${GRAPHICENHANCEMENT_DLSS_SDK_ROOT}/include/nvsdk_ngx.h")
    message(FATAL_ERROR "GRAPHICENHANCEMENT_ENABLE_EXPERIMENTAL_DLSSNR requires GRAPHICENHANCEMENT_DLSS_SDK_ROOT pointing at NVIDIA DLSS SDK 310.7 (include/nvsdk_ngx.h missing)")
  endif()
add_library(graphicenhancement_ngx STATIC
  src/ngx/NgxCoreHost.cpp
  src/ngx/NgxCoreCache.cpp
  src/ngx/DlssNrRuntimeAdapter.cpp
  src/ngx/NvapiLifetime.cpp
  src/ngx/DlssSrBackend.cpp
    src/ngx/VideoSrBackend.cpp
    src/ngx/TrueHdrBackend.cpp
  src/ngx/AnrProvider.cpp
  src/ngx/DlssFgBackend.cpp
  src/ngx/FgCompatibilitySession.cpp
  src/ngx/compat/hde/hde64.c
  src/ngx/AdaMfgUnlock.cpp
  src/ngx/AmpereMfgUnlock.cpp
  src/ngx/MfgUnlockUtil.cpp
  src/ngx/NvapiArchSpoof.cpp
  src/ngx/DlssgTransfusion.cpp
)
  set_source_files_properties(src/ngx/compat/hde/hde64.c PROPERTIES LANGUAGE CXX)
  graphicenhancement_apply_warnings(graphicenhancement_ngx)
  target_compile_features(graphicenhancement_ngx PUBLIC cxx_std_20)
  target_link_libraries(graphicenhancement_ngx PUBLIC graphicenhancement_base graphicenhancement_gfx d3d11)
  target_include_directories(graphicenhancement_ngx PUBLIC
    "${GRAPHICENHANCEMENT_DLSS_SDK_ROOT}/include")
  # NVIDIA ships the static core shim as MT-Release; the _dbg variants match
  # the MDd debug runtime. Pick per configuration to avoid LNK2038.
  target_link_libraries(graphicenhancement_ngx PRIVATE
    "$<IF:$<CONFIG:Debug>,${GRAPHICENHANCEMENT_DLSS_SDK_ROOT}/lib/Windows_x86_64/x64/nvsdk_ngx_s_dbg.lib,${GRAPHICENHANCEMENT_DLSS_SDK_ROOT}/lib/Windows_x86_64/x64/nvsdk_ngx_s.lib>")
  target_compile_definitions(graphicenhancement_ngx PUBLIC
    GRAPHICENHANCEMENT_EXPERIMENTAL_LOCAL_DLSSNR=1 GRAPHICENHANCEMENT_HAS_NGX_CORE_CACHE=1 GRAPHICENHANCEMENT_HAS_PAUSED_NR_RESIDUAL_REUSE=1)

  # Diagnostic: exercises the Ada multi-frame unlock against the local DLSS-G
  # runtime image without involving NGX (works on any NVIDIA adapter).
  add_executable(graphicenhancement_dlssg_unlock_probe tools/dlssg_unlock_probe/main.cpp)
  target_compile_features(graphicenhancement_dlssg_unlock_probe PRIVATE cxx_std_20)
  target_compile_options(graphicenhancement_dlssg_unlock_probe PRIVATE /utf-8 /WX-)
  target_compile_definitions(graphicenhancement_dlssg_unlock_probe PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN UNICODE _UNICODE)
  target_link_libraries(graphicenhancement_dlssg_unlock_probe PRIVATE graphicenhancement_ngx)

  # Diagnostic: exercises the RTX 30 (sm_86) Ampere unlock against the local
  # DLSS-G runtime image without involving NGX (works on any NVIDIA adapter).
  add_executable(graphicenhancement_dlssg_ampere_probe tools/dlssg_ampere_probe/main.cpp)
  target_compile_features(graphicenhancement_dlssg_ampere_probe PRIVATE cxx_std_20)
  target_compile_options(graphicenhancement_dlssg_ampere_probe PRIVATE /utf-8 /WX-)
  target_compile_definitions(graphicenhancement_dlssg_ampere_probe PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN UNICODE _UNICODE)
  target_link_libraries(graphicenhancement_dlssg_ampere_probe PRIVATE graphicenhancement_ngx)
endif()

add_executable(graphicenhancement_runtime_probe
  tools/runtime_probe/main.cpp
)

# Dolby/DTS endpoint passthrough capability probe (diagnostic, never shipped).
add_executable(graphicenhancement_bitstream_probe tools/bitstream_audio_probe/main.cpp)
target_compile_features(graphicenhancement_bitstream_probe PRIVATE cxx_std_20)
target_compile_options(graphicenhancement_bitstream_probe PRIVATE /utf-8 /WX-)
target_compile_definitions(graphicenhancement_bitstream_probe PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN UNICODE _UNICODE)
target_link_libraries(graphicenhancement_bitstream_probe PRIVATE ole32)

# Isolated descriptor/Present diagnosis probe (user directive 2026-09-04 s3).
# No NGX/FFmpeg/NVOF/WASAPI. Uses PresentBlit shaders for cases F/G.
add_executable(graphicenhancement_descriptor_present_probe
  tools/descriptor_present_probe/main.cpp
)
graphicenhancement_apply_warnings(graphicenhancement_descriptor_present_probe)
target_compile_features(graphicenhancement_descriptor_present_probe PRIVATE cxx_std_20)
target_compile_definitions(graphicenhancement_descriptor_present_probe PRIVATE
  UNICODE _UNICODE WIN32_LEAN_AND_MEAN NOMINMAX
  GRAPHICENHANCEMENT_SHADER_DIR="${CMAKE_BINARY_DIR}/shaders")
target_link_libraries(graphicenhancement_descriptor_present_probe PRIVATE d3d12 dxgi)
add_dependencies(graphicenhancement_descriptor_present_probe graphicenhancement_shader_present_blit)

# Presentation scaler check (2026-11-18): drives PresentBlit offscreen and
# compares the fine path with a CPU model, the old bilinear blit and a
# Lanczos-3 reference, and times each blit. D3D12 only.
add_executable(graphicenhancement_present_scaling_tests tests/integration/PresentScalingGpuTests.cpp)
graphicenhancement_apply_warnings(graphicenhancement_present_scaling_tests)
target_compile_features(graphicenhancement_present_scaling_tests PRIVATE cxx_std_20)
target_compile_options(graphicenhancement_present_scaling_tests PRIVATE /utf-8)
target_compile_definitions(graphicenhancement_present_scaling_tests PRIVATE UNICODE _UNICODE WIN32_LEAN_AND_MEAN NOMINMAX)
target_link_libraries(graphicenhancement_present_scaling_tests PRIVATE d3d12 dxgi)
add_dependencies(graphicenhancement_present_scaling_tests graphicenhancement_shader_present_blit)
graphicenhancement_apply_warnings(graphicenhancement_runtime_probe)
target_compile_features(graphicenhancement_runtime_probe PRIVATE cxx_std_20)
target_compile_definitions(graphicenhancement_runtime_probe PRIVATE
  UNICODE _UNICODE WIN32_LEAN_AND_MEAN NOMINMAX)
target_link_libraries(graphicenhancement_runtime_probe PRIVATE graphicenhancement_gfx)

graphicenhancement_add_compute_shader(graphicenhancement_shader_parity_encode ParityEncode)
graphicenhancement_add_compute_shader(graphicenhancement_shader_parity_decode ParityDecode)
graphicenhancement_add_compute_shader(graphicenhancement_shader_rdna3_nr_decode Rdna3NrDecode)
graphicenhancement_add_compute_shader(graphicenhancement_shader_hdr_video_sr HdrVideoSrRestore)
graphicenhancement_add_compute_shader(graphicenhancement_shader_sr_resolve SrResolve)
graphicenhancement_add_compute_shader(graphicenhancement_shader_hdr_amd_nr_encode HdrAmdNrEncode)
graphicenhancement_add_compute_shader(graphicenhancement_shader_hdr_amd_nr_restore HdrAmdNrRestore)
if(GRAPHICENHANCEMENT_ENABLE_EXPERIMENTAL_DLSSNR)
  graphicenhancement_add_compute_shader(graphicenhancement_shader_test_pattern GenerateTestPattern)
  add_executable(graphicenhancement_nr_ampere_tests tests/integration/NrAmpereTests.cpp)
  target_compile_features(graphicenhancement_nr_ampere_tests PRIVATE cxx_std_20)
  target_compile_definitions(graphicenhancement_nr_ampere_tests PRIVATE UNICODE _UNICODE WIN32_LEAN_AND_MEAN NOMINMAX)
  target_link_libraries(graphicenhancement_nr_ampere_tests PRIVATE graphicenhancement_gfx graphicenhancement_ngx)
  add_executable(graphicenhancement_nvapi_lifetime_tests tests/integration/NvapiLifetimeTests.cpp)
  target_compile_features(graphicenhancement_nvapi_lifetime_tests PRIVATE cxx_std_20)
  target_compile_definitions(graphicenhancement_nvapi_lifetime_tests PRIVATE UNICODE _UNICODE WIN32_LEAN_AND_MEAN NOMINMAX)
  target_link_libraries(graphicenhancement_nvapi_lifetime_tests PRIVATE graphicenhancement_ngx)
  add_executable(graphicenhancement_nr_harness
    tools/nr_harness/main.cpp
    tools/nr_harness/frame_loop.cpp
    tools/nr_harness/harness_util.cpp
    tools/nr_harness/parity_compare.cpp
    tools/nr_harness/sr_test.cpp
  )
  graphicenhancement_apply_warnings(graphicenhancement_nr_harness)
  target_compile_features(graphicenhancement_nr_harness PRIVATE cxx_std_20)
  target_compile_definitions(graphicenhancement_nr_harness PRIVATE
    UNICODE _UNICODE WIN32_LEAN_AND_MEAN NOMINMAX
    GRAPHICENHANCEMENT_SHADER_DIR="${CMAKE_BINARY_DIR}/shaders")
  target_link_libraries(graphicenhancement_nr_harness PRIVATE graphicenhancement_gfx graphicenhancement_ngx graphicenhancement_parity)
  add_dependencies(graphicenhancement_nr_harness graphicenhancement_shader_test_pattern
    graphicenhancement_shader_parity_encode graphicenhancement_shader_parity_decode)

  # NR stacking probe: several Feature-18 handles on one snippet session.
  add_executable(graphicenhancement_nr_probe
    tools/nr_probe/main.cpp
    tools/nr_harness/harness_util.cpp
  )
  graphicenhancement_apply_warnings(graphicenhancement_nr_probe)
  target_compile_features(graphicenhancement_nr_probe PRIVATE cxx_std_20)
  target_compile_definitions(graphicenhancement_nr_probe PRIVATE
    UNICODE _UNICODE WIN32_LEAN_AND_MEAN NOMINMAX
    GRAPHICENHANCEMENT_SHADER_DIR="${CMAKE_BINARY_DIR}/shaders")
  target_link_libraries(graphicenhancement_nr_probe PRIVATE graphicenhancement_gfx graphicenhancement_ngx)

  # Phase 6: DLSSG truth harness + WASAPI audio probe.
  add_executable(graphicenhancement_fg_harness
    tools/fg_harness/main.cpp
    tools/fg_harness/fg_test.cpp
    tools/fg_harness/audio_test.cpp
    tools/nr_harness/harness_util.cpp
  )
  graphicenhancement_apply_warnings(graphicenhancement_fg_harness)
  target_compile_features(graphicenhancement_fg_harness PRIVATE cxx_std_20)
  target_compile_definitions(graphicenhancement_fg_harness PRIVATE
    UNICODE _UNICODE WIN32_LEAN_AND_MEAN NOMINMAX)
  target_link_libraries(graphicenhancement_fg_harness PRIVATE graphicenhancement_gfx graphicenhancement_ngx ole32 mmdevapi avrt)
endif()

# YUV→RGB shader is shared between the media pipeline and the harness.
graphicenhancement_add_compute_shader(graphicenhancement_shader_yuv_to_rgb YuvToLinearRgb)
graphicenhancement_add_compute_shader(graphicenhancement_shader_rgb_to_linear RgbToLinear)
graphicenhancement_add_compute_shader(graphicenhancement_shader_color_grade ColorGradePass)
# 纹理 / 清晰度 / 去朦胧: block statistics, blur, apply (ColorDetailPass).
graphicenhancement_add_compute_shader(graphicenhancement_shader_color_detail_reduce ColorDetailReduce)
graphicenhancement_add_compute_shader(graphicenhancement_shader_color_detail_blur ColorDetailBlur)
graphicenhancement_add_compute_shader(graphicenhancement_shader_color_detail_apply ColorDetailApply)
graphicenhancement_add_compute_shader(graphicenhancement_shader_yuy2_to_linear Yuy2ToLinear)
graphicenhancement_add_compute_shader(graphicenhancement_shader_packed_capture PackedCaptureToLinear)
add_dependencies(graphicenhancement_shader_rgb_to_linear graphicenhancement_shader_yuy2_to_linear)
# ScaleBlit: working frame -> swapchain backbuffer (Phase 6 present path).
graphicenhancement_add_compute_shader(graphicenhancement_shader_scale_blit ScaleBlit)
graphicenhancement_add_nis_shaders(graphicenhancement_shader_nis)
enable_testing()

add_subdirectory(tests/hdmi-bitstream)
add_subdirectory(tests/screenshot-alpha)
graphicenhancement_add_compute_shader(graphicenhancement_shader_effect_exclusion EffectExclusion)
# Live HUD Lock (ported from PushFPS, GPL-3.0-or-later): per-pixel HUD mask and compose.
graphicenhancement_add_compute_shader(graphicenhancement_shader_hud_lock_update HudLockUpdate)
graphicenhancement_add_compute_shader(graphicenhancement_shader_hud_lock_dynamic HudLockDynamic)
graphicenhancement_add_compute_shader(graphicenhancement_shader_hud_lock_fill HudLockFill)
graphicenhancement_add_compute_shader(graphicenhancement_shader_hud_lock_compose HudLockCompose)
graphicenhancement_add_compute_shader(graphicenhancement_shader_hud_protect_motion HudProtectMotion)
graphicenhancement_add_compute_shader(graphicenhancement_shader_hud_protect_detect HudProtectDetect)
graphicenhancement_add_compute_shader(graphicenhancement_shader_hud_protect_repair HudProtectRepair)
graphicenhancement_add_compute_shader(graphicenhancement_shader_hud_protect_flow HudProtectFlow)
graphicenhancement_add_compute_shader(graphicenhancement_shader_hud_protect_compose HudProtectCompose)
# Nv12Upload: byte buffer -> luma/chroma planes (copy-free upload path).
graphicenhancement_add_compute_shader(graphicenhancement_shader_nv12_upload Nv12Upload)
# PresentBlit: fullscreen-triangle pixel blit onto flip-model back buffers.
graphicenhancement_add_graphics_shader_pair(graphicenhancement_shader_present_blit PresentBlit)
graphicenhancement_add_graphics_shader_pair(graphicenhancement_shader_fullscreen_frame_stats FullscreenFrameStats)
graphicenhancement_add_compute_shader(graphicenhancement_shader_present_motion PresentMotion)
graphicenhancement_add_compute_shader(graphicenhancement_shader_hdr_coverage HdrCurveCoverage)
# NvofDensify: SHORT2 S10.5 raw flow -> workingExtent float2 + confidence.
graphicenhancement_add_compute_shader(graphicenhancement_shader_nvof_densify NvofDensify)
graphicenhancement_add_compute_shader(graphicenhancement_shader_nr_downsample NrDownsample)
graphicenhancement_add_compute_shader(graphicenhancement_shader_nr_residual NrResidualComposite)
graphicenhancement_add_compute_shader(graphicenhancement_shader_nr_temporal NrTemporal)
# Stage-5 output stabiliser (anti-flicker, default off).
graphicenhancement_add_compute_shader(graphicenhancement_shader_nr_hold NrHold)
# NR inference reuse (realtime preview only, default off).
graphicenhancement_add_compute_shader(graphicenhancement_shader_nr_reuse_compose NrReuseCompose)
graphicenhancement_add_compute_shader(graphicenhancement_shader_nr_reuse_warp NrReuseWarp)
graphicenhancement_add_compute_shader(graphicenhancement_shader_flow_adapt FlowAdapt)
graphicenhancement_add_compute_shader(graphicenhancement_shader_flow_refine FlowRefine)
graphicenhancement_add_compute_shader(graphicenhancement_shader_flow_fill FlowFill)
graphicenhancement_add_compute_shader(graphicenhancement_shader_flow_claim FlowClaim)
# VfgShotChange: per-pair shot-change test for VFG (replaces the SDK's automatic one).
graphicenhancement_add_compute_shader(graphicenhancement_shader_vfg_shot_change VfgShotChange)
# RIFE (RifeDmlBackend): colour <-> planar model tensors.
graphicenhancement_add_compute_shader(graphicenhancement_shader_rife_pack RifePack)
graphicenhancement_add_compute_shader(graphicenhancement_shader_rife_unpack RifeUnpack)
graphicenhancement_add_compute_shader(graphicenhancement_shader_rife_shot_change RifeShotChange)
graphicenhancement_add_compute_shader(graphicenhancement_shader_rgb_nv12 RgbToNv12)
graphicenhancement_add_compute_shader(graphicenhancement_shader_virtual_camera_nv12 VirtualCameraNv12)

# ---------------------------------------------------------------------------
# graphicenhancement_parity: RenoDX-equivalent codec reference (CPU golden + shaders later).
# The CPU reference has no D3D12 dependency, so it builds unconditionally.
# ---------------------------------------------------------------------------
add_library(graphicenhancement_parity STATIC
  src/parity/RenoDxParityCodec.cpp
)
graphicenhancement_apply_warnings(graphicenhancement_parity)
target_compile_features(graphicenhancement_parity PUBLIC cxx_std_20)
target_link_libraries(graphicenhancement_parity PUBLIC graphicenhancement_base)

add_executable(graphicenhancement_parity_tests
  tests/unit/ParityCpuReference.cpp
)
graphicenhancement_apply_warnings(graphicenhancement_parity_tests)
target_compile_features(graphicenhancement_parity_tests PRIVATE cxx_std_20)
target_compile_definitions(graphicenhancement_parity_tests PRIVATE
  UNICODE _UNICODE WIN32_LEAN_AND_MEAN NOMINMAX)
target_link_libraries(graphicenhancement_parity_tests PRIVATE graphicenhancement_parity)

add_executable(graphicenhancement_unified_tests
  tests/unit/UnifiedContractTests.cpp
)
graphicenhancement_apply_warnings(graphicenhancement_unified_tests)
target_compile_features(graphicenhancement_unified_tests PRIVATE cxx_std_20)
target_compile_definitions(graphicenhancement_unified_tests PRIVATE
  UNICODE _UNICODE WIN32_LEAN_AND_MEAN NOMINMAX)
target_include_directories(graphicenhancement_unified_tests PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/include)
target_link_libraries(graphicenhancement_unified_tests PRIVATE d3d12 graphicenhancement_gfx graphicenhancement_ngx)

# Guidance product library (Playbook R3/R4): providers produce the unified
# GuidanceFrame. First real member: ZeroGuidanceProvider (honest fallback).
# NvofGuidanceProvider moves in from player_probe during R3.2.
add_library(graphicenhancement_guidance STATIC
  src/guidance/ZeroGuidanceProvider.cpp
)
graphicenhancement_apply_warnings(graphicenhancement_guidance)
target_compile_options(graphicenhancement_guidance PRIVATE /WX-)
target_compile_features(graphicenhancement_guidance PRIVATE cxx_std_20)
target_compile_definitions(graphicenhancement_guidance PRIVATE
  UNICODE _UNICODE WIN32_LEAN_AND_MEAN NOMINMAX)
target_include_directories(graphicenhancement_guidance PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/include)
target_link_libraries(graphicenhancement_guidance PUBLIC graphicenhancement_pipeline graphicenhancement_gfx graphicenhancement_base d3d12 dxgi dxguid)

add_executable(graphicenhancement_guidance_tests
  tests/integration/GuidanceProviderTests.cpp
)
graphicenhancement_apply_warnings(graphicenhancement_guidance_tests)
target_compile_options(graphicenhancement_guidance_tests PRIVATE /WX-)
target_compile_features(graphicenhancement_guidance_tests PRIVATE cxx_std_20)
target_compile_definitions(graphicenhancement_guidance_tests PRIVATE
  UNICODE _UNICODE WIN32_LEAN_AND_MEAN NOMINMAX)
target_include_directories(graphicenhancement_guidance_tests PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/include)
target_link_libraries(graphicenhancement_guidance_tests PRIVATE graphicenhancement_guidance)

# Pipeline product library (Playbook R2/R3): data contracts + reset coordinator.
# Grows in R3 as the real GPU graph migrates out of the probes.
add_library(graphicenhancement_pipeline STATIC
  src/pipeline/ResetCoordinator.cpp
  src/pipeline/ColorGradeTables.cpp
  src/pipeline/ColorGradeInstance.cpp
  src/pipeline/ColorDetailPass.cpp
  src/pipeline/AntiAliasPass.cpp
  src/pipeline/SmaaLookupTables.cpp
  src/pipeline/NrInstance.cpp
  src/pipeline/AmdHipPreflight.cpp
  src/pipeline/LmxxfNrBackend.cpp
  src/pipeline/Rdna3NrBackend.cpp
  src/pipeline/VfgBackend.cpp
  src/pipeline/VfgAmpereCompat.cpp
  src/pipeline/VfxSrBackend.cpp
)
graphicenhancement_apply_warnings(graphicenhancement_pipeline)
# FFmpeg/NVOF headers are third-party: /WX stays off for this target.
target_compile_options(graphicenhancement_pipeline PRIVATE /WX-)
target_compile_features(graphicenhancement_pipeline PRIVATE cxx_std_20)
target_compile_definitions(graphicenhancement_pipeline PUBLIC
  UNICODE _UNICODE WIN32_LEAN_AND_MEAN NOMINMAX
  GRAPHICENHANCEMENT_SHADER_DIR="${CMAKE_BINARY_DIR}/shaders")
target_include_directories(graphicenhancement_pipeline PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/include)
set(GRAPHICENHANCEMENT_CUDA_DRIVER_INCLUDE_DIR "" CACHE PATH "External CUDA driver headers for native VFG (never vendored)")
if(EXISTS "${GRAPHICENHANCEMENT_CUDA_DRIVER_INCLUDE_DIR}/cuda.h")
  target_include_directories(graphicenhancement_pipeline PRIVATE "${GRAPHICENHANCEMENT_CUDA_DRIVER_INCLUDE_DIR}")
  target_compile_definitions(graphicenhancement_pipeline PRIVATE GRAPHICENHANCEMENT_HAVE_CUDA_DRIVER_HEADERS=1)
endif()
target_link_libraries(graphicenhancement_pipeline PUBLIC graphicenhancement_base graphicenhancement_gfx d3d12 dxgi dxguid d3dcompiler)
add_dependencies(graphicenhancement_pipeline graphicenhancement_shader_rdna3_nr_decode)

# Optional independent RX7000 network worker. All third-party source and runtime
# assets remain external; only our host and reproducible preparation script live here.
set(GRAPHICENHANCEMENT_RDNA3_NETWORK_SOURCE_DIR "" CACHE PATH "Prepared external RedDuke network source (MIT)")
if(EXISTS "${GRAPHICENHANCEMENT_RDNA3_NETWORK_SOURCE_DIR}/runtime/core/network.cpp")
  add_executable(graphicenhancement_amd_nr_worker src/pipeline/Rdna3NrWorker.cpp "${GRAPHICENHANCEMENT_RDNA3_NETWORK_SOURCE_DIR}/runtime/core/network.cpp")
  target_include_directories(graphicenhancement_amd_nr_worker PRIVATE include "${GRAPHICENHANCEMENT_RDNA3_NETWORK_SOURCE_DIR}")
  target_compile_features(graphicenhancement_amd_nr_worker PRIVATE cxx_std_20)
  target_compile_definitions(graphicenhancement_amd_nr_worker PRIVATE NOMINMAX UNICODE _UNICODE WIN32_LEAN_AND_MEAN)
  target_compile_options(graphicenhancement_amd_nr_worker PRIVATE /utf-8 /WX-)
  target_link_libraries(graphicenhancement_amd_nr_worker PRIVATE d3d12 dxgi dxguid version)
endif()
add_executable(graphicenhancement_amd_nr_test_worker src/pipeline/Rdna3NrWorker.cpp)
add_executable(graphicenhancement_rdna3_worker_diagnostics_tests tests/integration/Rdna3WorkerDiagnosticsTests.cpp)
target_include_directories(graphicenhancement_rdna3_worker_diagnostics_tests PRIVATE include)
target_compile_features(graphicenhancement_rdna3_worker_diagnostics_tests PRIVATE cxx_std_20)
target_compile_definitions(graphicenhancement_rdna3_worker_diagnostics_tests PRIVATE NOMINMAX UNICODE _UNICODE WIN32_LEAN_AND_MEAN)
add_executable(graphicenhancement_rdna3_hip_devices_tests tests/integration/Rdna3HipDevicesTests.cpp)
target_include_directories(graphicenhancement_rdna3_hip_devices_tests PRIVATE include)
target_compile_features(graphicenhancement_rdna3_hip_devices_tests PRIVATE cxx_std_20)
target_compile_definitions(graphicenhancement_rdna3_hip_devices_tests PRIVATE NOMINMAX UNICODE _UNICODE WIN32_LEAN_AND_MEAN)
target_link_libraries(graphicenhancement_rdna3_hip_devices_tests PRIVATE dxgi)
target_include_directories(graphicenhancement_amd_nr_test_worker PRIVATE include)
target_compile_features(graphicenhancement_amd_nr_test_worker PRIVATE cxx_std_20)
target_compile_definitions(graphicenhancement_amd_nr_test_worker PRIVATE NOMINMAX UNICODE _UNICODE WIN32_LEAN_AND_MEAN GRAPHICENHANCEMENT_RDNA3_CONTRACT_WORKER=1)
target_compile_options(graphicenhancement_amd_nr_test_worker PRIVATE /utf-8 /WX-)
target_link_libraries(graphicenhancement_amd_nr_test_worker PRIVATE d3d12 dxgi dxguid)
add_executable(graphicenhancement_rdna3_nr_contract_tests tests/integration/Rdna3NrContractTests.cpp)
target_include_directories(graphicenhancement_rdna3_nr_contract_tests PRIVATE include)
target_compile_features(graphicenhancement_rdna3_nr_contract_tests PRIVATE cxx_std_20)
target_compile_definitions(graphicenhancement_rdna3_nr_contract_tests PRIVATE NOMINMAX UNICODE _UNICODE WIN32_LEAN_AND_MEAN)
target_link_libraries(graphicenhancement_rdna3_nr_contract_tests PRIVATE graphicenhancement_pipeline graphicenhancement_parity)
add_dependencies(graphicenhancement_rdna3_nr_contract_tests graphicenhancement_shader_rdna3_nr_decode)
add_library(graphicenhancement_lmxxf_fake_runtime SHARED tests/unit/LmxxfNrFakeRuntime.cpp)
target_compile_features(graphicenhancement_lmxxf_fake_runtime PRIVATE cxx_std_20)
target_compile_definitions(graphicenhancement_lmxxf_fake_runtime PRIVATE LMXXF_NR_RUNTIME_EXPORTS NOMINMAX WIN32_LEAN_AND_MEAN)
target_link_libraries(graphicenhancement_lmxxf_fake_runtime PRIVATE d3d12 dxgi dxguid)
set_target_properties(graphicenhancement_lmxxf_fake_runtime PROPERTIES OUTPUT_NAME LmxxfNrRuntime RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lmxxf-test-runtime")
add_library(graphicenhancement_lmxxf_fake_original_runtime SHARED tests/unit/LmxxfNrFakeRuntime.cpp)
target_compile_features(graphicenhancement_lmxxf_fake_original_runtime PRIVATE cxx_std_20)
target_compile_definitions(graphicenhancement_lmxxf_fake_original_runtime PRIVATE LMXXF_NR_RUNTIME_EXPORTS NOMINMAX WIN32_LEAN_AND_MEAN GRAPHICENHANCEMENT_TEST_MODEL_MODE=1)
target_link_libraries(graphicenhancement_lmxxf_fake_original_runtime PRIVATE d3d12 dxgi dxguid)
set_target_properties(graphicenhancement_lmxxf_fake_original_runtime PROPERTIES OUTPUT_NAME LmxxfNrRuntime-Original RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lmxxf-test-runtime")
add_executable(graphicenhancement_lmxxf_nr_tests tests/unit/LmxxfNrTests.cpp)
target_compile_features(graphicenhancement_lmxxf_nr_tests PRIVATE cxx_std_20)
target_link_libraries(graphicenhancement_lmxxf_nr_tests PRIVATE graphicenhancement_pipeline)
add_dependencies(graphicenhancement_lmxxf_nr_tests graphicenhancement_lmxxf_fake_runtime graphicenhancement_lmxxf_fake_original_runtime)
# Issue 88: the AMD HIP self-test child, its class ladder and its result lines.
add_executable(graphicenhancement_amd_hip_preflight_tests tests/unit/AmdHipPreflightTests.cpp)
target_compile_features(graphicenhancement_amd_hip_preflight_tests PRIVATE cxx_std_20)
target_link_libraries(graphicenhancement_amd_hip_preflight_tests PRIVATE graphicenhancement_pipeline)
add_executable(graphicenhancement_lmxxf_runtime_metadata_tests tests/integration/LmxxfNrRuntimeMetadataTests.cpp)
target_compile_features(graphicenhancement_lmxxf_runtime_metadata_tests PRIVATE cxx_std_20)
target_link_libraries(graphicenhancement_lmxxf_runtime_metadata_tests PRIVATE graphicenhancement_pipeline)
add_dependencies(graphicenhancement_pipeline graphicenhancement_shader_color_grade graphicenhancement_shader_color_detail_reduce graphicenhancement_shader_color_detail_blur graphicenhancement_shader_color_detail_apply)
# Spatial anti-aliasing (#53): FXAA / SMAA / MLAA ported from SAOG0721/Magpie
# d687997 (sources and notices: THIRD_PARTY_NOTICES.md). Quality tiers of one
# source are separate .dxil variants.
graphicenhancement_add_compute_shader(graphicenhancement_shader_video_denoise VideoDenoise)
add_dependencies(graphicenhancement_pipeline graphicenhancement_shader_video_denoise)
graphicenhancement_add_compute_shader(graphicenhancement_shader_aa_luma AaLuma)
graphicenhancement_add_compute_shader_variant(graphicenhancement_shader_aa_fxaa3 AaFxaa AaFxaa3 FXAA_PRESET=3)
graphicenhancement_add_compute_shader_variant(graphicenhancement_shader_aa_fxaa4 AaFxaa AaFxaa4 FXAA_PRESET=4)
graphicenhancement_add_compute_shader_variant(graphicenhancement_shader_aa_fxaa5 AaFxaa AaFxaa5 FXAA_PRESET=5)
graphicenhancement_add_compute_shader(graphicenhancement_shader_aa_smaa_edges AaSmaaEdges)
graphicenhancement_add_compute_shader_variant(graphicenhancement_shader_aa_smaa_weights_low AaSmaaWeights AaSmaaWeightsLow SMAA_PRESET_LOW)
graphicenhancement_add_compute_shader_variant(graphicenhancement_shader_aa_smaa_weights_medium AaSmaaWeights AaSmaaWeightsMedium SMAA_PRESET_MEDIUM)
graphicenhancement_add_compute_shader_variant(graphicenhancement_shader_aa_smaa_weights_high AaSmaaWeights AaSmaaWeightsHigh SMAA_PRESET_HIGH)
graphicenhancement_add_compute_shader_variant(graphicenhancement_shader_aa_smaa_weights_ultra AaSmaaWeights AaSmaaWeightsUltra SMAA_PRESET_ULTRA)
graphicenhancement_add_compute_shader(graphicenhancement_shader_aa_smaa_blend AaSmaaBlend)
graphicenhancement_add_compute_shader(graphicenhancement_shader_aa_temporal AaTemporalResolve)
graphicenhancement_add_compute_shader(graphicenhancement_shader_aa_mlaa_edges AaMlaaEdges)
graphicenhancement_add_compute_shader(graphicenhancement_shader_aa_mlaa_counts AaMlaaCounts)
graphicenhancement_add_compute_shader(graphicenhancement_shader_aa_mlaa_blend AaMlaaBlend)
# DLAA in HDR: adds the input's out-of-BT.709 part back to the DLSS result.
graphicenhancement_add_compute_shader(graphicenhancement_shader_dlaa_hdr_restore DlaaHdrRestore)
add_dependencies(graphicenhancement_pipeline graphicenhancement_shader_aa_luma graphicenhancement_shader_aa_fxaa3 graphicenhancement_shader_aa_fxaa4 graphicenhancement_shader_aa_fxaa5
  graphicenhancement_shader_aa_smaa_edges graphicenhancement_shader_aa_smaa_weights_low graphicenhancement_shader_aa_smaa_weights_medium
  graphicenhancement_shader_aa_smaa_weights_high graphicenhancement_shader_aa_smaa_weights_ultra graphicenhancement_shader_aa_smaa_blend graphicenhancement_shader_aa_temporal
  graphicenhancement_shader_aa_mlaa_edges graphicenhancement_shader_aa_mlaa_counts graphicenhancement_shader_aa_mlaa_blend graphicenhancement_shader_dlaa_hdr_restore)

# Header-only PCM gain checks do not need audio hardware, Qt or GPU runtimes.
add_executable(graphicenhancement_audio_gain_tests tests/unit/AudioGainTests.cpp)
target_compile_features(graphicenhancement_audio_gain_tests PRIVATE cxx_std_20)
target_include_directories(graphicenhancement_audio_gain_tests PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/include)
graphicenhancement_apply_warnings(graphicenhancement_audio_gain_tests)

add_executable(graphicenhancement_pipeline_tests
  tests/unit/PipelineContractTests.cpp
)
graphicenhancement_apply_warnings(graphicenhancement_pipeline_tests)
target_compile_features(graphicenhancement_pipeline_tests PRIVATE cxx_std_20)
target_compile_definitions(graphicenhancement_pipeline_tests PRIVATE
  UNICODE _UNICODE WIN32_LEAN_AND_MEAN NOMINMAX)
target_include_directories(graphicenhancement_pipeline_tests PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/include)
target_link_libraries(graphicenhancement_pipeline_tests PRIVATE graphicenhancement_pipeline)
add_executable(graphicenhancement_vfg_gpu_tests tests/integration/VfgGpuTests.cpp)
target_compile_features(graphicenhancement_vfg_gpu_tests PRIVATE cxx_std_20)
target_link_libraries(graphicenhancement_vfg_gpu_tests PRIVATE graphicenhancement_pipeline)
add_executable(graphicenhancement_vfg_ampere_tests tests/unit/VfgAmpereTests.cpp)
target_compile_features(graphicenhancement_vfg_ampere_tests PRIVATE cxx_std_20)
target_compile_options(graphicenhancement_vfg_ampere_tests PRIVATE /utf-8)
target_link_libraries(graphicenhancement_vfg_ampere_tests PRIVATE graphicenhancement_pipeline)

add_executable(graphicenhancement_scene_tests
  tests/unit/SceneCadenceTests.cpp
  src/core/SceneCadenceAnalyzer.cpp
)
graphicenhancement_apply_warnings(graphicenhancement_scene_tests)
target_compile_features(graphicenhancement_scene_tests PRIVATE cxx_std_20)
target_compile_definitions(graphicenhancement_scene_tests PRIVATE
  UNICODE _UNICODE WIN32_LEAN_AND_MEAN NOMINMAX)
target_include_directories(graphicenhancement_scene_tests PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/include)

# Standalone scene analyzer tool (phase5 gate expects graphicenhancement_scene_analyzer.exe).
if(GRAPHICENHANCEMENT_FFMPEG_ROOT AND EXISTS "${GRAPHICENHANCEMENT_FFMPEG_ROOT}/include/libavformat/avformat.h")
  add_executable(graphicenhancement_scene_analyzer
    tools/scene_analyzer/main.cpp
    src/core/SceneCadenceAnalyzer.cpp
  )
  graphicenhancement_apply_warnings(graphicenhancement_scene_analyzer)
  target_compile_options(graphicenhancement_scene_analyzer PRIVATE /WX-)
  target_compile_features(graphicenhancement_scene_analyzer PRIVATE cxx_std_20)
  target_compile_definitions(graphicenhancement_scene_analyzer PRIVATE
    UNICODE _UNICODE WIN32_LEAN_AND_MEAN NOMINMAX)
  target_include_directories(graphicenhancement_scene_analyzer PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/include)
  target_link_libraries(graphicenhancement_scene_analyzer PRIVATE graphicenhancement_media graphicenhancement_base)
endif()

# NVOF probe tool (phase5 gate expects graphicenhancement_nvof_probe.exe).
set(GRAPHICENHANCEMENT_NVOF_SDK_ROOT "" CACHE PATH "NVIDIA Optical Flow SDK root")
if(GRAPHICENHANCEMENT_NVOF_SDK_ROOT AND EXISTS "${GRAPHICENHANCEMENT_NVOF_SDK_ROOT}/NvOFInterface/nvOpticalFlowCommon.h")
  # Reusable NVOF D3D12 session (Phase 6 motion guidance for DLSSG).
  add_library(graphicenhancement_nvof STATIC src/ngx/NvOfSession.cpp)
  graphicenhancement_apply_warnings(graphicenhancement_nvof)
  target_compile_features(graphicenhancement_nvof PUBLIC cxx_std_20)
  target_include_directories(graphicenhancement_nvof PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/include
    "${GRAPHICENHANCEMENT_NVOF_SDK_ROOT}/NvOFInterface"
    "${GRAPHICENHANCEMENT_NVOF_SDK_ROOT}/Common/NvOFBase")
  target_link_libraries(graphicenhancement_nvof PUBLIC graphicenhancement_base graphicenhancement_gfx)

  add_executable(graphicenhancement_nvof_probe tools/nvof_probe/main.cpp)

  # s9-A3: table-driven null-argument fault injection for NvOfSession.
  add_executable(graphicenhancement_nvof_fault_inject tools/nvof_fault_inject/main.cpp)
  graphicenhancement_apply_warnings(graphicenhancement_nvof_fault_inject)
  target_compile_options(graphicenhancement_nvof_fault_inject PRIVATE /WX-)
  target_compile_features(graphicenhancement_nvof_fault_inject PRIVATE cxx_std_20)
  target_compile_definitions(graphicenhancement_nvof_fault_inject PRIVATE
    UNICODE _UNICODE WIN32_LEAN_AND_MEAN NOMINMAX)
  target_link_libraries(graphicenhancement_nvof_fault_inject PRIVATE graphicenhancement_gfx graphicenhancement_nvof)
  graphicenhancement_apply_warnings(graphicenhancement_nvof_probe)
  target_compile_options(graphicenhancement_nvof_probe PRIVATE /WX-)
  target_compile_features(graphicenhancement_nvof_probe PRIVATE cxx_std_20)
  target_compile_definitions(graphicenhancement_nvof_probe PRIVATE
    UNICODE _UNICODE WIN32_LEAN_AND_MEAN NOMINMAX)
  target_include_directories(graphicenhancement_nvof_probe PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/include
    "${GRAPHICENHANCEMENT_NVOF_SDK_ROOT}/NvOFInterface"
    "${GRAPHICENHANCEMENT_NVOF_SDK_ROOT}/Common/NvOFBase")
  target_link_libraries(graphicenhancement_nvof_probe PRIVATE graphicenhancement_gfx graphicenhancement_base)
endif()

# Resolve FFmpeg before any consumer, including the shared enhancement graph.
if(GRAPHICENHANCEMENT_FFMPEG_ROOT AND EXISTS "${GRAPHICENHANCEMENT_FFMPEG_ROOT}/include/libavformat/avformat.h")
  list(APPEND CMAKE_MODULE_PATH "${GRAPHICENHANCEMENT_FFMPEG_ROOT}/share/ffmpeg")
  find_package(FFMPEG REQUIRED)
endif()

# EnhanceGraph (the real GPU chain) needs the NGX + NVOF backends; wire it
# into graphicenhancement_pipeline only when both exist so bare contract builds still work.
if(TARGET graphicenhancement_ngx AND TARGET graphicenhancement_nvof AND GRAPHICENHANCEMENT_FFMPEG_ROOT)
  target_sources(graphicenhancement_pipeline PRIVATE src/pipeline/EnhanceGraph.cpp src/pipeline/NisScaler.cpp src/pipeline/HudLock.cpp src/pipeline/HudProtect.cpp src/pipeline/NrTemporalPass.cpp src/pipeline/NrHoldPass.cpp src/pipeline/NrReusePass.cpp src/core/SceneCadenceAnalyzer.cpp)
  target_include_directories(graphicenhancement_pipeline PRIVATE ${FFMPEG_INCLUDE_DIRS})
  target_link_libraries(graphicenhancement_pipeline PRIVATE graphicenhancement_ngx graphicenhancement_nvof ${FFMPEG_LIBRARIES})
  add_dependencies(graphicenhancement_pipeline
    graphicenhancement_shader_yuv_to_rgb graphicenhancement_shader_rgb_to_linear graphicenhancement_shader_parity_encode
    graphicenhancement_shader_parity_decode graphicenhancement_shader_scale_blit graphicenhancement_shader_nis
    graphicenhancement_shader_hdr_amd_nr_encode graphicenhancement_shader_hdr_amd_nr_restore
    graphicenhancement_shader_nv12_upload graphicenhancement_shader_nvof_densify graphicenhancement_shader_packed_capture)
endif()

# ---------------------------------------------------------------------------
# graphicenhancement_media: FFmpeg demux/decode (Phase 3). Links only the Playbook 3.4
# dependency set from the pinned vcpkg install.
# ---------------------------------------------------------------------------
if(GRAPHICENHANCEMENT_FFMPEG_ROOT AND EXISTS "${GRAPHICENHANCEMENT_FFMPEG_ROOT}/include/libavformat/avformat.h")
  add_library(graphicenhancement_media STATIC
    src/media/FFmpegDemuxer.cpp
    src/media/DemuxSession.cpp
    src/media/FFmpegVideoDecoder.cpp
    src/media/FFmpegDeinterlacer.cpp
    src/media/FfmpegLog.cpp
  )
  graphicenhancement_apply_warnings(graphicenhancement_media)
  # FFmpeg headers are third-party; /WX stays off for this target
  # (Playbook 5.3: never let third-party headers block the build).
  target_compile_options(graphicenhancement_media PRIVATE /WX-)
  target_compile_features(graphicenhancement_media PUBLIC cxx_std_20)
  # d3d11: the HEVC hardware path decodes on a private D3D11VA device and shares
  # the surfaces with the D3D12 graph as NT handles.
  target_link_libraries(graphicenhancement_media PUBLIC graphicenhancement_base graphicenhancement_gfx d3d11 bcrypt winhttp)
  if(GRAPHICENHANCEMENT_ENABLE_DEINTERLACE)
    if(NOT EXISTS "${GRAPHICENHANCEMENT_FFMPEG_ROOT}/include/libavfilter/avfilter.h")
      message(FATAL_ERROR "Deinterlacing requires the filter prefix; run scripts/ffmpeg/build-deinterlace-module.py and set GRAPHICENHANCEMENT_FFMPEG_ROOT to its prefix (or explicitly disable GRAPHICENHANCEMENT_ENABLE_DEINTERLACE).")
    endif()
    target_compile_definitions(graphicenhancement_media PRIVATE GRAPHICENHANCEMENT_ENABLE_DEINTERLACE=1)
    # A reused build tree may retain FFMPEG_INCLUDE_DIRS from the pre-filter
    # prefix. Compile against the prefix whose filter headers we just checked.
    target_include_directories(graphicenhancement_media BEFORE PRIVATE "${GRAPHICENHANCEMENT_FFMPEG_ROOT}/include")
  endif()
  target_include_directories(graphicenhancement_media PUBLIC ${FFMPEG_INCLUDE_DIRS})
  target_link_directories(graphicenhancement_media PUBLIC ${FFMPEG_LIBRARY_DIRS})
  target_link_libraries(graphicenhancement_media PUBLIC ${FFMPEG_LIBRARIES})
  # libdovi (MIT): parses the RPU payload itself, including streams whose RPU sits
  # in the enhancement layer with no dovi_config record for FFmpeg to follow.
  option(GRAPHICENHANCEMENT_ENABLE_LIBDOVI "Parse Dolby Vision RPU carried in enhancement-layer streams" ON)
  set(GRAPHICENHANCEMENT_LIBDOVI_ROOT "" CACHE PATH "External libdovi prefix; binaries/SDK stay outside source Git")
  if(GRAPHICENHANCEMENT_ENABLE_LIBDOVI)
    find_path(GRAPHICENHANCEMENT_LIBDOVI_INCLUDE libdovi/rpu_parser.h HINTS "${GRAPHICENHANCEMENT_LIBDOVI_ROOT}/include")
    find_library(GRAPHICENHANCEMENT_LIBDOVI_LIBRARY NAMES dolby_vision.dll dovi libdovi HINTS "${GRAPHICENHANCEMENT_LIBDOVI_ROOT}/lib")
    find_file(GRAPHICENHANCEMENT_LIBDOVI_RUNTIME NAMES dolby_vision.dll dovi.dll libdovi.dll HINTS "${GRAPHICENHANCEMENT_LIBDOVI_ROOT}/bin")
    if(NOT GRAPHICENHANCEMENT_LIBDOVI_INCLUDE OR NOT GRAPHICENHANCEMENT_LIBDOVI_LIBRARY OR NOT GRAPHICENHANCEMENT_LIBDOVI_RUNTIME)
      message(FATAL_ERROR "libdovi enabled: provide GRAPHICENHANCEMENT_LIBDOVI_ROOT with matching include/lib/bin; see docs/PR_INTEGRATION_PLAN_2026-11-18.md. Explicitly disable GRAPHICENHANCEMENT_ENABLE_LIBDOVI only for a reduced developer build.")
    endif()
    add_library(graphicenhancement_libdovi INTERFACE)
    target_include_directories(graphicenhancement_libdovi INTERFACE "${GRAPHICENHANCEMENT_LIBDOVI_INCLUDE}")
    # Keep link.exe response files free of non-ANSI dependency paths.
    configure_file("${GRAPHICENHANCEMENT_LIBDOVI_LIBRARY}" "${CMAKE_CURRENT_BINARY_DIR}/graphicenhancement-libdovi.lib" COPYONLY)
    target_link_libraries(graphicenhancement_libdovi INTERFACE "${CMAKE_CURRENT_BINARY_DIR}/graphicenhancement-libdovi.lib")
    target_compile_definitions(graphicenhancement_libdovi INTERFACE GRAPHICENHANCEMENT_HAVE_LIBDOVI=1)
    target_link_libraries(graphicenhancement_media PUBLIC graphicenhancement_libdovi)
    message(STATUS "libdovi external runtime: ${GRAPHICENHANCEMENT_LIBDOVI_RUNTIME}")
  endif()

  add_executable(graphicenhancement_media_probe
    tools/media_probe/main.cpp
    tools/nr_harness/harness_util.cpp
  )
  graphicenhancement_apply_warnings(graphicenhancement_media_probe)
  target_compile_options(graphicenhancement_media_probe PRIVATE /WX-)
  target_compile_features(graphicenhancement_media_probe PRIVATE cxx_std_20)
  target_compile_definitions(graphicenhancement_media_probe PRIVATE
    UNICODE _UNICODE WIN32_LEAN_AND_MEAN NOMINMAX
    GRAPHICENHANCEMENT_SHADER_DIR="${CMAKE_BINARY_DIR}/shaders")
  target_link_libraries(graphicenhancement_media_probe PRIVATE graphicenhancement_media graphicenhancement_gfx graphicenhancement_ngx graphicenhancement_parity psapi)
  add_dependencies(graphicenhancement_media_probe graphicenhancement_shader_yuv_to_rgb)

  # graphicenhancement_sinks: product output sinks (Playbook R3). First member is the
  # WASAPI audio sink extracted verbatim from player_probe; D3D12PresentSink
  # currently lives in graphicenhancement_gfx and moves here when the migration completes.
  add_library(graphicenhancement_sinks STATIC
    src/sink/WasapiAudioSink.cpp
    src/sink/CaptureAudioSession.cpp
    src/sink/CaptureAudioDsp.cpp
    src/sink/BitstreamAudio.cpp
    src/sink/BitstreamAudioSink.cpp
    src/sink/HdmiBitstreamOutput.cpp
    src/sink/Iec61937Burst.cpp
    src/sink/ImageExportSink.cpp
    src/sink/NvencD3D12Encoder.cpp
    src/sink/NvencLiveEncoder.cpp
    src/sink/MfVideoEncoder.cpp
    src/sink/RecordingAudioTap.cpp
    src/sink/VideoEncoderFactory.cpp
  )
  graphicenhancement_apply_warnings(graphicenhancement_sinks)
  target_compile_options(graphicenhancement_sinks PRIVATE /WX-)
  target_compile_features(graphicenhancement_sinks PRIVATE cxx_std_20)
  target_compile_definitions(graphicenhancement_sinks PRIVATE
    UNICODE _UNICODE WIN32_LEAN_AND_MEAN NOMINMAX)
  set_source_files_properties(src/sink/HdmiBitstreamOutput.cpp PROPERTIES COMPILE_DEFINITIONS GRAPHICENHANCEMENT_HDMI_BITSTREAM_DIAGNOSTICS)
  target_include_directories(graphicenhancement_sinks PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/include)
  target_include_directories(graphicenhancement_sinks PRIVATE ${FFMPEG_INCLUDE_DIRS})
  set(GRAPHICENHANCEMENT_NVENC_HEADERS_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/third_party_local/nvidia/nv-codec-headers-13.0" CACHE PATH "NVENC 13.0 ABI headers (nv-codec-headers n13.0.19.0)")
  if(NOT EXISTS "${GRAPHICENHANCEMENT_NVENC_HEADERS_ROOT}/include/ffnvcodec/nvEncodeAPI.h")
    message(FATAL_ERROR "Stage nv-codec-headers n13.0.19.0 at GRAPHICENHANCEMENT_NVENC_HEADERS_ROOT; see THIRD_PARTY_NOTICES.md")
  endif()
  target_include_directories(graphicenhancement_sinks PRIVATE "${GRAPHICENHANCEMENT_NVENC_HEADERS_ROOT}/include")
  target_compile_definitions(graphicenhancement_sinks PRIVATE GRAPHICENHANCEMENT_SHADER_DIR="${CMAKE_BINARY_DIR}/shaders")
  add_dependencies(graphicenhancement_sinks graphicenhancement_shader_rgb_nv12)
  # graphicenhancement_media: AudioPipeline reads packets from the shared network demux session (#48).
  target_link_libraries(graphicenhancement_sinks PUBLIC graphicenhancement_base graphicenhancement_gfx graphicenhancement_media ole32 windowscodecs mmdevapi avrt mfplat mfuuid mf)
  add_subdirectory(third_party/soundtouch EXCLUDE_FROM_ALL)
  target_link_libraries(graphicenhancement_sinks PRIVATE ${FFMPEG_LIBRARIES} graphicenhancement_soundtouch)
  if(FFMPEG_INCLUDE_DIRS)
    target_include_directories(graphicenhancement_sinks PRIVATE ${FFMPEG_INCLUDE_DIRS})
  endif()

  # graphicenhancement_sources: product input sources (Playbook R3/R7). MediaFileSource
  # composes graphicenhancement_media; no second decode implementation exists.
  add_dependencies(graphicenhancement_pipeline graphicenhancement_shader_effect_exclusion graphicenhancement_shader_hud_lock_update graphicenhancement_shader_hud_lock_dynamic graphicenhancement_shader_hud_lock_fill graphicenhancement_shader_hud_lock_compose graphicenhancement_shader_hud_protect_motion graphicenhancement_shader_hud_protect_detect graphicenhancement_shader_hud_protect_repair graphicenhancement_shader_hud_protect_flow graphicenhancement_shader_hud_protect_compose graphicenhancement_shader_sr_resolve graphicenhancement_shader_nr_downsample graphicenhancement_shader_nr_residual graphicenhancement_shader_nr_temporal graphicenhancement_shader_nr_hold graphicenhancement_shader_nr_reuse_compose graphicenhancement_shader_nr_reuse_warp graphicenhancement_shader_flow_adapt graphicenhancement_shader_flow_refine graphicenhancement_shader_flow_fill graphicenhancement_shader_flow_claim graphicenhancement_shader_vfg_shot_change graphicenhancement_shader_rife_pack graphicenhancement_shader_rife_unpack graphicenhancement_shader_rife_shot_change)
  add_library(graphicenhancement_sources STATIC
    src/source/NativeCaptureSink.cpp
    src/source/MediaFileSource.cpp
    src/source/CaptureCardSource.cpp
    src/source/DeckLinkCapture.cpp
    src/source/DeckLinkDriver.cpp
    src/source/ElgatoHdrControl.cpp
    src/source/ScreenCaptureSource.cpp
    src/source/VirtualDesktop.cpp
    src/source/AverMediaAudioSwitch.cpp
    src/source/AverMediaVendorAudio.cpp
    src/source/AverMediaAudioCarrier.cpp
    src/source/CaptureCompressedDecoder.cpp
    src/source/WasapiAudioInput.cpp
    src/source/MagewellCapture.cpp
  )
  graphicenhancement_apply_warnings(graphicenhancement_sources)
  # Optional external DeckLink SDK. Generate the official COM ABI outside the
  # source tree; Desktop Video supplies the installed COM server at run time.
  set(GRAPHICENHANCEMENT_DECKLINK_SDK_DIR "" CACHE PATH "External DeckLink SDK Win IDL directory")
  if(GRAPHICENHANCEMENT_DECKLINK_SDK_DIR AND NOT EXISTS "${GRAPHICENHANCEMENT_DECKLINK_SDK_DIR}/DeckLinkAPI.idl")
    message(FATAL_ERROR "GRAPHICENHANCEMENT_DECKLINK_SDK_DIR must contain the external Win DeckLinkAPI.idl")
  endif()
  if(GRAPHICENHANCEMENT_DECKLINK_SDK_DIR AND EXISTS "${GRAPHICENHANCEMENT_DECKLINK_SDK_DIR}/DeckLinkAPI.idl")
    find_program(GRAPHICENHANCEMENT_MIDL_EXECUTABLE midl REQUIRED)
    set(GRAPHICENHANCEMENT_DECKLINK_GENERATED "${CMAKE_CURRENT_BINARY_DIR}/decklink-generated")
    file(MAKE_DIRECTORY "${GRAPHICENHANCEMENT_DECKLINK_GENERATED}")
    file(GLOB GRAPHICENHANCEMENT_DECKLINK_IDL_DEPENDS "${GRAPHICENHANCEMENT_DECKLINK_SDK_DIR}/*.idl")
    add_custom_command(OUTPUT "${GRAPHICENHANCEMENT_DECKLINK_GENERATED}/DeckLinkAPI_h.h"
      COMMAND "${GRAPHICENHANCEMENT_MIDL_EXECUTABLE}" /nologo /env x64 /I "${GRAPHICENHANCEMENT_DECKLINK_SDK_DIR}"
        /out "${GRAPHICENHANCEMENT_DECKLINK_GENERATED}" /h DeckLinkAPI_h.h
        /iid DeckLinkAPI_i.c /tlb DeckLinkAPI.tlb /client none /server none
        "${GRAPHICENHANCEMENT_DECKLINK_SDK_DIR}/DeckLinkAPI.idl"
      DEPENDS ${GRAPHICENHANCEMENT_DECKLINK_IDL_DEPENDS} VERBATIM)
    add_custom_target(graphicenhancement_decklink_abi DEPENDS "${GRAPHICENHANCEMENT_DECKLINK_GENERATED}/DeckLinkAPI_h.h")
    add_dependencies(graphicenhancement_sources graphicenhancement_decklink_abi)
    set_source_files_properties(src/source/DeckLinkDriver.cpp PROPERTIES
      COMPILE_DEFINITIONS GRAPHICENHANCEMENT_HAS_DECKLINK=1 INCLUDE_DIRECTORIES "${GRAPHICENHANCEMENT_DECKLINK_GENERATED}")
    message(STATUS "DeckLink native capture ABI: ${GRAPHICENHANCEMENT_DECKLINK_SDK_DIR}")
  else()
    set_source_files_properties(src/source/DeckLinkDriver.cpp PROPERTIES COMPILE_DEFINITIONS GRAPHICENHANCEMENT_HAS_DECKLINK=0)
    message(STATUS "DeckLink native capture: no SDK configured (DirectShow remains available)")
  endif()
  # Magewell Pro Capture low-latency video: compiled against the vendor SDK headers when
  # GRAPHICENHANCEMENT_MAGEWELL_SDK_DIR points at them (kept outside the source tree); LibMWCapture.dll is
  # loaded at run time. Without the headers the feature reports itself unavailable.
  set(GRAPHICENHANCEMENT_MAGEWELL_SDK_DIR "" CACHE PATH "MWCapture SDK root containing Include/LibMWCapture")
  if(GRAPHICENHANCEMENT_MAGEWELL_SDK_DIR AND EXISTS "${GRAPHICENHANCEMENT_MAGEWELL_SDK_DIR}/Include/LibMWCapture/MWCapture.h")
    set_source_files_properties(src/source/MagewellCapture.cpp PROPERTIES
      COMPILE_DEFINITIONS GRAPHICENHANCEMENT_HAS_MAGEWELL=1
      INCLUDE_DIRECTORIES "${GRAPHICENHANCEMENT_MAGEWELL_SDK_DIR}/Include;${GRAPHICENHANCEMENT_MAGEWELL_SDK_DIR}/Include/LibMWCapture")
    message(STATUS "Magewell SDK headers: ${GRAPHICENHANCEMENT_MAGEWELL_SDK_DIR}")
  endif()
  target_compile_options(graphicenhancement_sources PRIVATE /WX-)
  target_compile_features(graphicenhancement_sources PRIVATE cxx_std_20)
  target_link_libraries(graphicenhancement_sources PUBLIC graphicenhancement_sinks)
  target_compile_definitions(graphicenhancement_sources PRIVATE
    UNICODE _UNICODE WIN32_LEAN_AND_MEAN NOMINMAX)
  target_include_directories(graphicenhancement_sources PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/include)
  target_link_libraries(graphicenhancement_sources PUBLIC graphicenhancement_pipeline graphicenhancement_media graphicenhancement_base)
  target_link_libraries(graphicenhancement_sources PRIVATE ${FFMPEG_LIBRARIES} strmiids ole32 oleaut32 d3d12 dxgi cfgmgr32)
  # Matching FFmpeg imports and external libdovi propagate through graphicenhancement_media.
  target_link_libraries(graphicenhancement_sources PRIVATE d3d11 windowsapp dwmapi)

  if(GRAPHICENHANCEMENT_ENABLE_REMOTEPLAY)
    set(GRAPHICENHANCEMENT_ROOT "${CMAKE_CURRENT_SOURCE_DIR}")
    include(cmake/GraphicEnhancementRemotePlay.cmake)
    target_compile_definitions(graphicenhancement_sources PUBLIC GRAPHICENHANCEMENT_ENABLE_REMOTEPLAY=1)
    target_sources(graphicenhancement_sources PRIVATE src/source/RemotePlaySource.cpp src/source/RemotePlaySessionSource.cpp)
    target_link_libraries(graphicenhancement_sources PUBLIC graphicenhancement_remoteplay_chiaki)
  endif()

  if(GRAPHICENHANCEMENT_ENABLE_MOONLIGHT)
    find_package(Opus CONFIG REQUIRED)
    target_compile_definitions(graphicenhancement_sources PUBLIC GRAPHICENHANCEMENT_ENABLE_MOONLIGHT=1)
    target_sources(graphicenhancement_sources PRIVATE src/source/MoonlightSessionSource.cpp)
    target_link_libraries(graphicenhancement_sources PUBLIC graphicenhancement_moonlight_protocol graphicenhancement_moonlight_common_c PRIVATE Opus::opus)
  endif()

  if(GRAPHICENHANCEMENT_ENABLE_XBOX)
    set(GRAPHICENHANCEMENT_ROOT "${CMAKE_CURRENT_SOURCE_DIR}")
    include(GraphicEnhancementXbox)
    find_package(Opus CONFIG REQUIRED)
    target_compile_definitions(graphicenhancement_sources PUBLIC GRAPHICENHANCEMENT_ENABLE_XBOX=1)
    target_sources(graphicenhancement_sources PRIVATE src/source/XboxSessionSource.cpp)
    target_link_libraries(graphicenhancement_sources PUBLIC graphicenhancement_xbox_protocol PRIVATE Opus::opus)
  endif()

  add_executable(graphicenhancement_source_tests
    tests/integration/MediaFileSourceTests.cpp
  )
  graphicenhancement_apply_warnings(graphicenhancement_source_tests)
  target_compile_options(graphicenhancement_source_tests PRIVATE /WX-)
  target_compile_features(graphicenhancement_source_tests PRIVATE cxx_std_20)
  target_compile_definitions(graphicenhancement_source_tests PRIVATE
    UNICODE _UNICODE WIN32_LEAN_AND_MEAN NOMINMAX)
  target_include_directories(graphicenhancement_source_tests PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/include)
  target_link_libraries(graphicenhancement_source_tests PRIVATE graphicenhancement_sources)

  add_executable(graphicenhancement_capture_tests tests/integration/CaptureSourceTests.cpp)
  add_executable(graphicenhancement_network_interlace_tests tests/integration/NetworkInterlaceTests.cpp)
  target_compile_features(graphicenhancement_network_interlace_tests PRIVATE cxx_std_20)
  target_compile_definitions(graphicenhancement_network_interlace_tests PRIVATE UNICODE _UNICODE WIN32_LEAN_AND_MEAN NOMINMAX)
  target_link_libraries(graphicenhancement_network_interlace_tests PRIVATE graphicenhancement_engine)
  # #48: shared demux session, reconnect, buffering, damaged-data tolerance (tests/network).
  add_executable(graphicenhancement_network_buffer_tests tests/integration/NetworkBufferTests.cpp)
  target_compile_features(graphicenhancement_network_buffer_tests PRIVATE cxx_std_20)
  target_compile_definitions(graphicenhancement_network_buffer_tests PRIVATE UNICODE _UNICODE WIN32_LEAN_AND_MEAN NOMINMAX)
  target_link_libraries(graphicenhancement_network_buffer_tests PRIVATE graphicenhancement_engine)
  add_executable(graphicenhancement_decklink_tests tests/unit/DeckLinkCaptureTests.cpp)
  target_compile_features(graphicenhancement_decklink_tests PRIVATE cxx_std_20)
  target_compile_definitions(graphicenhancement_decklink_tests PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN)
  target_link_libraries(graphicenhancement_decklink_tests PRIVATE graphicenhancement_sources)
  add_executable(graphicenhancement_screen_capture_tests tests/integration/ScreenCaptureTests.cpp)
  target_compile_features(graphicenhancement_screen_capture_tests PRIVATE cxx_std_20)
  target_compile_definitions(graphicenhancement_screen_capture_tests PRIVATE UNICODE _UNICODE WIN32_LEAN_AND_MEAN NOMINMAX)
  target_link_libraries(graphicenhancement_screen_capture_tests PRIVATE graphicenhancement_engine dwmapi dxgi)
  add_executable(graphicenhancement_wasapi_input_tests tests/integration/WasapiInputTests.cpp)
  target_compile_features(graphicenhancement_wasapi_input_tests PRIVATE cxx_std_20)
  target_compile_definitions(graphicenhancement_wasapi_input_tests PRIVATE UNICODE _UNICODE WIN32_LEAN_AND_MEAN NOMINMAX)
  target_link_libraries(graphicenhancement_wasapi_input_tests PRIVATE graphicenhancement_sources)
  target_compile_features(graphicenhancement_capture_tests PRIVATE cxx_std_20)
  target_compile_definitions(graphicenhancement_capture_tests PRIVATE UNICODE _UNICODE WIN32_LEAN_AND_MEAN NOMINMAX)
  target_link_libraries(graphicenhancement_capture_tests PRIVATE graphicenhancement_sources)

  add_executable(graphicenhancement_live_timing_tests tests/unit/LivePresentationTimingTests.cpp)
  add_executable(graphicenhancement_control_paint_tests tests/integration/ControlPaintTests.cpp)
  target_compile_features(graphicenhancement_control_paint_tests PRIVATE cxx_std_20)
  target_compile_definitions(graphicenhancement_control_paint_tests PRIVATE UNICODE _UNICODE WIN32_LEAN_AND_MEAN NOMINMAX)
  target_include_directories(graphicenhancement_control_paint_tests PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/apps/graphicenhancement/ui)
  target_link_libraries(graphicenhancement_control_paint_tests PRIVATE graphicenhancement_base comctl32 gdiplus uxtheme gdi32 user32 ole32)
  target_compile_features(graphicenhancement_live_timing_tests PRIVATE cxx_std_20)
  target_compile_options(graphicenhancement_live_timing_tests PRIVATE /utf-8)
  target_include_directories(graphicenhancement_live_timing_tests PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/include)

  # Frame pacing repair and the adaptive multiplier (ported from PushFPS): header-only logic.
  add_executable(graphicenhancement_frame_pacing_repair_tests tests/unit/FramePacingRepairTests.cpp)
  target_compile_features(graphicenhancement_frame_pacing_repair_tests PRIVATE cxx_std_20)
  target_compile_options(graphicenhancement_frame_pacing_repair_tests PRIVATE /utf-8)
  target_include_directories(graphicenhancement_frame_pacing_repair_tests PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/include)
  add_executable(graphicenhancement_adaptive_fg_multiplier_tests tests/unit/AdaptiveFgMultiplierTests.cpp)
  target_compile_features(graphicenhancement_adaptive_fg_multiplier_tests PRIVATE cxx_std_20)
  target_compile_options(graphicenhancement_adaptive_fg_multiplier_tests PRIVATE /utf-8)
  target_compile_definitions(graphicenhancement_adaptive_fg_multiplier_tests PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN)
  target_include_directories(graphicenhancement_adaptive_fg_multiplier_tests PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/include)
  target_link_libraries(graphicenhancement_adaptive_fg_multiplier_tests PRIVATE graphicenhancement_base graphicenhancement_engine ${FFMPEG_LIBRARIES})
  # Live HUD Lock on a real D3D12 device (ported from PushFPS).
  add_executable(graphicenhancement_hud_lock_gpu_tests tests/integration/HudLockGpuTests.cpp)
  target_compile_features(graphicenhancement_hud_lock_gpu_tests PRIVATE cxx_std_20)
  target_compile_options(graphicenhancement_hud_lock_gpu_tests PRIVATE /utf-8)
  target_compile_definitions(graphicenhancement_hud_lock_gpu_tests PRIVATE UNICODE _UNICODE WIN32_LEAN_AND_MEAN NOMINMAX)
  target_link_libraries(graphicenhancement_hud_lock_gpu_tests PRIVATE graphicenhancement_pipeline d3d12 dxgi)
  add_dependencies(graphicenhancement_hud_lock_gpu_tests graphicenhancement_shader_hud_lock_update graphicenhancement_shader_hud_lock_compose)
  # NVENC recording tuning (two-pass, psycho-visual AQ; options from PushFPS).
  add_executable(graphicenhancement_nvenc_tuning_tests tests/integration/NvencTuningTests.cpp)
  target_compile_features(graphicenhancement_nvenc_tuning_tests PRIVATE cxx_std_20)
  target_compile_options(graphicenhancement_nvenc_tuning_tests PRIVATE /utf-8)
  target_compile_definitions(graphicenhancement_nvenc_tuning_tests PRIVATE UNICODE _UNICODE WIN32_LEAN_AND_MEAN NOMINMAX)
  target_link_libraries(graphicenhancement_nvenc_tuning_tests PRIVATE graphicenhancement_sinks graphicenhancement_base d3d12 dxgi)
  add_executable(graphicenhancement_repair_contract_tests tests/unit/RepairContractTests.cpp)
  add_executable(graphicenhancement_subtitle_loading_tests tests/integration/SubtitleLoadingTests.cpp)
  add_executable(graphicenhancement_subtitle_text_tests tests/integration/SubtitleTextTests.cpp)
  target_compile_features(graphicenhancement_subtitle_text_tests PRIVATE cxx_std_20)
  target_compile_options(graphicenhancement_subtitle_text_tests PRIVATE /utf-8)
  target_link_libraries(graphicenhancement_subtitle_text_tests PRIVATE graphicenhancement_engine)
  add_executable(graphicenhancement_screenshot_combination_tests tests/integration/ScreenshotCombinationTests.cpp)
  target_link_libraries(graphicenhancement_screenshot_combination_tests PRIVATE graphicenhancement_engine)
  target_compile_features(graphicenhancement_screenshot_combination_tests PRIVATE cxx_std_20)
  add_executable(graphicenhancement_bitmap_subtitle_tests tests/integration/BitmapSubtitleTests.cpp)
  add_executable(graphicenhancement_subtitle_format_tests tests/integration/SubtitleFormatTests.cpp)
  target_compile_features(graphicenhancement_subtitle_format_tests PRIVATE cxx_std_20)
  target_compile_options(graphicenhancement_subtitle_format_tests PRIVATE /utf-8)
  target_link_libraries(graphicenhancement_subtitle_format_tests PRIVATE graphicenhancement_engine)
  add_executable(graphicenhancement_webvtt_parse_tests tests/unit/WebVttParseTests.cpp)
  target_compile_features(graphicenhancement_webvtt_parse_tests PRIVATE cxx_std_20)
  target_link_libraries(graphicenhancement_webvtt_parse_tests PRIVATE graphicenhancement_engine)
  add_test(NAME graphicenhancement_webvtt_parse COMMAND graphicenhancement_webvtt_parse_tests)
  target_link_libraries(graphicenhancement_bitmap_subtitle_tests PRIVATE graphicenhancement_engine)
  target_compile_features(graphicenhancement_bitmap_subtitle_tests PRIVATE cxx_std_20)
  target_link_libraries(graphicenhancement_subtitle_loading_tests PRIVATE graphicenhancement_engine)
  target_compile_features(graphicenhancement_subtitle_loading_tests PRIVATE cxx_std_20)
  # graphicenhancement_engine is linked for the subtitle engine (SRT/ASS/VTT parsing +
  # indexed cue lookup); FFmpeg import libraries come from its public surface.
  target_link_libraries(graphicenhancement_repair_contract_tests PRIVATE graphicenhancement_base graphicenhancement_engine ${FFMPEG_LIBRARIES})
  # This suite keeps many EnhancementSettings copies and P5 RPU blobs alive at once;
  # the default 1 MiB stack overflowed after the 2.0.7 test/struct growth (verified: it
  # completes with a larger stack). Same remedy the other suites already use.
  target_link_options(graphicenhancement_repair_contract_tests PRIVATE /STACK:33554432)

  target_compile_features(graphicenhancement_repair_contract_tests PRIVATE cxx_std_20)
  target_compile_definitions(graphicenhancement_repair_contract_tests PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN)
  target_include_directories(graphicenhancement_repair_contract_tests PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/include)
  # main() holds hundreds of 8 KB EnhancementSettings copies; the 1 MB default stack overflowed partway (2.1.0).
  target_link_options(graphicenhancement_repair_contract_tests PRIVATE /STACK:33554432)

  add_executable(graphicenhancement_repair_parameter_tests tests/integration/RepairParameterTests.cpp)
  add_executable(graphicenhancement_image_dimension_tests tests/integration/ImageDimensionTests.cpp)
  add_executable(graphicenhancement_capture_color_probe tools/capture_color_probe/main.cpp)
  add_executable(graphicenhancement_capture_copy_bench tools/capture_copy_bench/main.cpp)
  target_compile_features(graphicenhancement_capture_copy_bench PRIVATE cxx_std_20)
  target_compile_options(graphicenhancement_capture_copy_bench PRIVATE /utf-8 /WX-)
  target_compile_definitions(graphicenhancement_capture_copy_bench PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN)
  target_link_libraries(graphicenhancement_capture_copy_bench PRIVATE graphicenhancement_engine)
  add_executable(graphicenhancement_decode_profile_probe tools/decode_profile_probe/main.cpp)
  target_compile_features(graphicenhancement_decode_profile_probe PRIVATE cxx_std_20)
  target_compile_options(graphicenhancement_decode_profile_probe PRIVATE /utf-8 /WX-)
  target_compile_definitions(graphicenhancement_decode_profile_probe PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN UNICODE _UNICODE)
  target_link_libraries(graphicenhancement_decode_profile_probe PRIVATE d3d12 dxgi dxguid)
  # Custom (Dolby Vision profile 5): runs the shipped YuvToLinearRgb.dxil over a
  # decoded frame with the player's own root constants and dumps the working
  # signal, so the profile-5 colour conversion can be diffed against an
  # independent reference decode instead of being taken on trust.
  add_executable(graphicenhancement_dovi_p5_probe tools/dovi_p5_probe/main.cpp)
  target_compile_features(graphicenhancement_dovi_p5_probe PRIVATE cxx_std_20)
  target_compile_options(graphicenhancement_dovi_p5_probe PRIVATE /utf-8 /WX-)
  target_compile_definitions(graphicenhancement_dovi_p5_probe PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN UNICODE _UNICODE
    GRAPHICENHANCEMENT_SHADER_DIR="${CMAKE_BINARY_DIR}/shaders")
  target_include_directories(graphicenhancement_dovi_p5_probe PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/include ${FFMPEG_INCLUDE_DIRS})
  target_link_libraries(graphicenhancement_dovi_p5_probe PRIVATE d3d12 dxgi dxguid ${FFMPEG_LIBRARIES})
  add_dependencies(graphicenhancement_dovi_p5_probe graphicenhancement_shader_yuv_to_rgb)
  add_executable(graphicenhancement_fsr_dispatch_tests tests/integration/FsrFgDispatchTests.cpp)
  target_compile_features(graphicenhancement_fsr_dispatch_tests PRIVATE cxx_std_20)
  target_link_libraries(graphicenhancement_fsr_dispatch_tests PRIVATE graphicenhancement_gfx d3d12 dxgi dxguid)
# Everything that touches media headers (NetworkInput, Dovi, the audio tests) needs these.
# Upstream relies on its own build environment exporting them; we add them globally.
include_directories(${FFMPEG_INCLUDE_DIRS})

  # The FSR probes include the FidelityFX SDK headers directly, so they cannot be built
  # without the local SDK tree (same guard as the FSR backend above). They are diagnostic
  # tools only; the player and the tests do not need them.
  if(EXISTS "${GRAPHICENHANCEMENT_FIDELITYFX2_ROOT}/api/include/ffx_api_loader.h")
    add_executable(graphicenhancement_fsr_probe tools/fsr_probe/main.cpp)
    target_compile_features(graphicenhancement_fsr_probe PRIVATE cxx_std_20)
    target_compile_options(graphicenhancement_fsr_probe PRIVATE /utf-8 /WX-)
    target_compile_definitions(graphicenhancement_fsr_probe PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN UNICODE _UNICODE)
    target_link_libraries(graphicenhancement_fsr_probe PRIVATE d3d12 dxgi dxguid)
    add_executable(graphicenhancement_fsr_upscale_probe tools/fsr_upscale_probe/main.cpp)
    target_compile_features(graphicenhancement_fsr_upscale_probe PRIVATE cxx_std_20)
    target_compile_options(graphicenhancement_fsr_upscale_probe PRIVATE /utf-8 /WX-)
    target_compile_definitions(graphicenhancement_fsr_upscale_probe PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN UNICODE _UNICODE)
    target_link_libraries(graphicenhancement_fsr_upscale_probe PRIVATE d3d12 dxgi dxguid)
  endif()
  add_executable(graphicenhancement_capture_color_tests tests/unit/CaptureColorContractTests.cpp)
  add_executable(graphicenhancement_capture_format_selection_tests tests/unit/CaptureFormatSelectionTests.cpp)
  target_compile_features(graphicenhancement_capture_format_selection_tests PRIVATE cxx_std_20)
  target_compile_options(graphicenhancement_capture_format_selection_tests PRIVATE /utf-8)
  target_include_directories(graphicenhancement_capture_format_selection_tests PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/include)
  target_compile_definitions(graphicenhancement_capture_format_selection_tests PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN)
  target_link_libraries(graphicenhancement_capture_format_selection_tests PRIVATE ole32 strmiids)
  add_executable(graphicenhancement_presentation_worker_tests tests/unit/LiveGpuSchedulerTests.cpp)
  add_executable(graphicenhancement_async_display_query_tests tests/unit/AsyncDisplayQueryTests.cpp)
  add_executable(graphicenhancement_tearing_detector_tests tests/unit/TearingDetectorTests.cpp)
  target_compile_features(graphicenhancement_tearing_detector_tests PRIVATE cxx_std_20)
  target_include_directories(graphicenhancement_tearing_detector_tests PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/include")
  target_compile_features(graphicenhancement_async_display_query_tests PRIVATE cxx_std_20)
  target_compile_definitions(graphicenhancement_async_display_query_tests PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN UNICODE _UNICODE)
  target_link_libraries(graphicenhancement_async_display_query_tests PRIVATE graphicenhancement_engine)
  target_compile_features(graphicenhancement_presentation_worker_tests PRIVATE cxx_std_20)
  target_compile_definitions(graphicenhancement_presentation_worker_tests PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN)
  target_include_directories(graphicenhancement_presentation_worker_tests PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/include)
  add_executable(graphicenhancement_realtime_preview_tests tests/unit/RealtimePreviewSchedulingTests.cpp)
  target_compile_features(graphicenhancement_realtime_preview_tests PRIVATE cxx_std_20)
  target_compile_definitions(graphicenhancement_realtime_preview_tests PRIVATE UNICODE _UNICODE WIN32_LEAN_AND_MEAN NOMINMAX)
  target_include_directories(graphicenhancement_realtime_preview_tests PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/include)
  # Its headers carry UTF-8 Chinese literals (CaptureBuffer.h, EnhancementSettings.h).
  target_compile_options(graphicenhancement_realtime_preview_tests PRIVATE /utf-8)
  add_executable(graphicenhancement_live_presentation_tests tests/integration/LivePresentationTests.cpp)
  # wmain holds many PlayerSnapshot locals; the default 1 MiB stack overflowed at entry.
  target_link_options(graphicenhancement_live_presentation_tests PRIVATE /STACK:8388608)
  add_executable(graphicenhancement_hdr_display_state_tests tests/unit/HdrDisplayStateTests.cpp)
  target_compile_features(graphicenhancement_hdr_display_state_tests PRIVATE cxx_std_20)
  target_compile_options(graphicenhancement_hdr_display_state_tests PRIVATE /utf-8)
  target_include_directories(graphicenhancement_hdr_display_state_tests PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/include)
  add_executable(graphicenhancement_nr_runtime_switch_tests tests/integration/NrRuntimeSwitchTests.cpp)
  target_compile_features(graphicenhancement_nr_runtime_switch_tests PRIVATE cxx_std_20)
  target_link_libraries(graphicenhancement_nr_runtime_switch_tests PRIVATE graphicenhancement_engine)

  add_executable(graphicenhancement_nr_model_settings_tests tests/unit/NrModelSettingsTests.cpp)
  target_compile_features(graphicenhancement_nr_model_settings_tests PRIVATE cxx_std_20)
  target_compile_options(graphicenhancement_nr_model_settings_tests PRIVATE /utf-8)
  target_link_libraries(graphicenhancement_nr_model_settings_tests PRIVATE graphicenhancement_engine)
  target_link_options(graphicenhancement_nr_model_settings_tests PRIVATE /STACK:33554432)
  if(GRAPHICENHANCEMENT_ENABLE_LIBDOVI)
    add_executable(graphicenhancement_libdovi_bridge_tests tests/unit/LibDoviBridgeTests.cpp)
    target_compile_features(graphicenhancement_libdovi_bridge_tests PRIVATE cxx_std_20)
    target_include_directories(graphicenhancement_libdovi_bridge_tests PRIVATE include ${FFMPEG_INCLUDE_DIRS})
    target_link_libraries(graphicenhancement_libdovi_bridge_tests PRIVATE graphicenhancement_libdovi ${FFMPEG_LIBRARIES})
  endif()
  add_executable(graphicenhancement_buffering_gate_tests tests/unit/BufferingGateTests.cpp)
  target_compile_features(graphicenhancement_buffering_gate_tests PRIVATE cxx_std_20)
  target_compile_options(graphicenhancement_buffering_gate_tests PRIVATE /utf-8)
  target_include_directories(graphicenhancement_buffering_gate_tests PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/include)
  add_executable(graphicenhancement_audio_timeline_tests tests/integration/AudioTimelineTests.cpp)
  target_include_directories(graphicenhancement_audio_timeline_tests PRIVATE ${FFMPEG_INCLUDE_DIRS})
  target_compile_features(graphicenhancement_audio_timeline_tests PRIVATE cxx_std_20)
  target_link_libraries(graphicenhancement_audio_timeline_tests PRIVATE graphicenhancement_sinks)
  add_executable(graphicenhancement_capture_audio_tests tests/integration/CaptureAudioTests.cpp)
  add_test(NAME graphicenhancement_capture_audio_hdmi_branch COMMAND graphicenhancement_capture_audio_tests --hdmi-branch)
  add_test(NAME graphicenhancement_capture_audio_bitstream_reservation COMMAND graphicenhancement_capture_audio_tests --bitstream-reservation)
  set_tests_properties(graphicenhancement_capture_audio_hdmi_branch graphicenhancement_capture_audio_bitstream_reservation PROPERTIES SKIP_RETURN_CODE 77)
  target_include_directories(graphicenhancement_capture_audio_tests PRIVATE ${FFMPEG_INCLUDE_DIRS})
  add_executable(graphicenhancement_avermedia_switch_tests tests/unit/AverMediaAudioSwitchTests.cpp)
  target_compile_features(graphicenhancement_avermedia_switch_tests PRIVATE cxx_std_20)
  target_compile_definitions(graphicenhancement_avermedia_switch_tests PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN UNICODE _UNICODE)
  target_link_libraries(graphicenhancement_avermedia_switch_tests PRIVATE graphicenhancement_sources)
  add_executable(graphicenhancement_avermedia_carrier_tests tests/unit/AverMediaCarrierTests.cpp)
  target_compile_features(graphicenhancement_avermedia_carrier_tests PRIVATE cxx_std_20)
  target_compile_options(graphicenhancement_avermedia_carrier_tests PRIVATE /utf-8)
  target_compile_definitions(graphicenhancement_avermedia_carrier_tests PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN UNICODE _UNICODE)
  target_include_directories(graphicenhancement_avermedia_carrier_tests PRIVATE ${FFMPEG_INCLUDE_DIRS})
  add_test(NAME graphicenhancement_avermedia_carrier COMMAND graphicenhancement_avermedia_carrier_tests)
  target_link_libraries(graphicenhancement_avermedia_carrier_tests PRIVATE graphicenhancement_sources ${FFMPEG_LIBRARIES})
  add_library(graphicenhancement_avermedia_fake_vendor SHARED tests/fixtures/FakeAverMediaVendor.cpp tests/fixtures/FakeAverMediaVendor.def)
  target_compile_features(graphicenhancement_avermedia_fake_vendor PRIVATE cxx_std_20)
  target_compile_options(graphicenhancement_avermedia_fake_vendor PRIVATE /utf-8)
  target_compile_definitions(graphicenhancement_avermedia_fake_vendor PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN UNICODE _UNICODE)
  target_include_directories(graphicenhancement_avermedia_fake_vendor PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/include)
  target_link_libraries(graphicenhancement_avermedia_fake_vendor PRIVATE ole32)
  add_library(graphicenhancement_avermedia_fake_missing SHARED tests/fixtures/FakeAverMediaVendor.cpp tests/fixtures/FakeAverMediaVendorMissing.def)
  target_compile_features(graphicenhancement_avermedia_fake_missing PRIVATE cxx_std_20)
  target_compile_options(graphicenhancement_avermedia_fake_missing PRIVATE /utf-8)
  target_compile_definitions(graphicenhancement_avermedia_fake_missing PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN UNICODE _UNICODE)
  target_include_directories(graphicenhancement_avermedia_fake_missing PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/include)
  target_link_libraries(graphicenhancement_avermedia_fake_missing PRIVATE ole32)
  add_executable(graphicenhancement_avermedia_vendor_tests tests/unit/AverMediaVendorAudioTests.cpp)
  target_compile_features(graphicenhancement_avermedia_vendor_tests PRIVATE cxx_std_20)
  target_compile_options(graphicenhancement_avermedia_vendor_tests PRIVATE /utf-8)
  target_compile_definitions(graphicenhancement_avermedia_vendor_tests PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN UNICODE _UNICODE)
  target_link_libraries(graphicenhancement_avermedia_vendor_tests PRIVATE graphicenhancement_sources)
  foreach(sdk_variant IN ITEMS Full NoGet NoSet)
    string(TOLOWER ${sdk_variant} sdk_variant_lower)
    set(sdk_target graphicenhancement_avermedia_fake_sdk_${sdk_variant_lower})
    add_library(${sdk_target} SHARED tests/fixtures/FakeAverMediaSdk.cpp tests/fixtures/FakeAverMediaSdk${sdk_variant}.def)
    target_compile_features(${sdk_target} PRIVATE cxx_std_20)
    target_compile_definitions(${sdk_target} PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN)
  endforeach()
  add_executable(graphicenhancement_avermedia_passthrough_tests tests/unit/AverMediaPassthroughTests.cpp)
  target_compile_features(graphicenhancement_avermedia_passthrough_tests PRIVATE cxx_std_20)
  target_compile_options(graphicenhancement_avermedia_passthrough_tests PRIVATE /utf-8)
  target_compile_definitions(graphicenhancement_avermedia_passthrough_tests PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN UNICODE _UNICODE)
  target_link_libraries(graphicenhancement_avermedia_passthrough_tests PRIVATE graphicenhancement_sources)
  add_executable(graphicenhancement_iec61937_probe_tests tests/unit/Iec61937ProbeTests.cpp)
  target_compile_features(graphicenhancement_iec61937_probe_tests PRIVATE cxx_std_20)
  target_compile_definitions(graphicenhancement_iec61937_probe_tests PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN UNICODE _UNICODE)
  target_link_libraries(graphicenhancement_iec61937_probe_tests PRIVATE graphicenhancement_sinks)
  if(GRAPHICENHANCEMENT_FFMPEG_ROOT AND EXISTS "${GRAPHICENHANCEMENT_FFMPEG_ROOT}/include/libavcodec/avcodec.h")
    add_executable(graphicenhancement_bitstream_audio_test tools/bitstream_audio_test/main.cpp)
    target_compile_features(graphicenhancement_bitstream_audio_test PRIVATE cxx_std_20)
    target_compile_options(graphicenhancement_bitstream_audio_test PRIVATE /utf-8 /WX-)
    target_compile_definitions(graphicenhancement_bitstream_audio_test PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN UNICODE _UNICODE)
    target_include_directories(graphicenhancement_bitstream_audio_test PRIVATE ${FFMPEG_INCLUDE_DIRS})
    target_link_libraries(graphicenhancement_bitstream_audio_test PRIVATE graphicenhancement_sinks graphicenhancement_base ${FFMPEG_LIBRARIES})
  endif()
  add_executable(graphicenhancement_audio_waveform_tests tests/integration/AudioWaveformTests.cpp)
  target_compile_features(graphicenhancement_audio_waveform_tests PRIVATE cxx_std_20)
  target_compile_definitions(graphicenhancement_audio_waveform_tests PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN)
  target_include_directories(graphicenhancement_audio_waveform_tests PRIVATE ${FFMPEG_INCLUDE_DIRS})
  target_link_libraries(graphicenhancement_audio_waveform_tests PRIVATE graphicenhancement_sinks ${FFMPEG_LIBRARIES})
  target_compile_features(graphicenhancement_capture_audio_tests PRIVATE cxx_std_20)
  target_include_directories(graphicenhancement_capture_audio_tests PRIVATE ${FFMPEG_INCLUDE_DIRS})
  target_link_libraries(graphicenhancement_capture_audio_tests PRIVATE graphicenhancement_sinks)
  target_compile_features(graphicenhancement_live_presentation_tests PRIVATE cxx_std_20)
  target_link_libraries(graphicenhancement_live_presentation_tests PRIVATE graphicenhancement_engine)
  add_executable(graphicenhancement_fg_admission_tests tests/integration/FgAdmissionTests.cpp)
  target_compile_features(graphicenhancement_fg_admission_tests PRIVATE cxx_std_20)
  target_compile_definitions(graphicenhancement_fg_admission_tests PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN)
  target_link_libraries(graphicenhancement_fg_admission_tests PRIVATE graphicenhancement_engine)
  target_compile_features(graphicenhancement_capture_color_tests PRIVATE cxx_std_20)
  target_link_libraries(graphicenhancement_capture_color_tests PRIVATE graphicenhancement_sources)
  add_executable(graphicenhancement_capture_startup_tests tests/unit/CaptureStartupTests.cpp)
  target_compile_features(graphicenhancement_capture_startup_tests PRIVATE cxx_std_20)
  target_compile_options(graphicenhancement_capture_startup_tests PRIVATE /utf-8)
  target_link_libraries(graphicenhancement_capture_startup_tests PRIVATE graphicenhancement_sources ole32)
  add_executable(graphicenhancement_capture_compressed_tests tests/unit/CaptureCompressedDecoderTests.cpp)
  target_compile_features(graphicenhancement_capture_compressed_tests PRIVATE cxx_std_20)
  target_compile_definitions(graphicenhancement_capture_compressed_tests PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN)
  target_include_directories(graphicenhancement_capture_compressed_tests PRIVATE ${FFMPEG_INCLUDE_DIRS})
  target_link_libraries(graphicenhancement_capture_compressed_tests PRIVATE graphicenhancement_sources graphicenhancement_gfx ${FFMPEG_LIBRARIES})
  add_executable(graphicenhancement_magewell_probe tools/magewell_probe/main.cpp)
  target_compile_features(graphicenhancement_magewell_probe PRIVATE cxx_std_20)
  target_compile_definitions(graphicenhancement_magewell_probe PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN UNICODE _UNICODE)
  target_link_libraries(graphicenhancement_magewell_probe PRIVATE graphicenhancement_sources)
  add_executable(graphicenhancement_magewell_frame_pump_tests tests/unit/MagewellFramePumpTests.cpp)
  target_compile_features(graphicenhancement_magewell_frame_pump_tests PRIVATE cxx_std_20)
  target_include_directories(graphicenhancement_magewell_frame_pump_tests PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/src/source)
  add_executable(graphicenhancement_stream_decode_bench tools/stream_decode_bench/main.cpp)
  target_compile_features(graphicenhancement_stream_decode_bench PRIVATE cxx_std_20)
  target_compile_definitions(graphicenhancement_stream_decode_bench PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN UNICODE _UNICODE)
  target_include_directories(graphicenhancement_stream_decode_bench PRIVATE ${FFMPEG_INCLUDE_DIRS})
  target_link_libraries(graphicenhancement_stream_decode_bench PRIVATE graphicenhancement_sources ${FFMPEG_LIBRARIES} d3d12 dxgi)
  add_executable(graphicenhancement_yuy2_color_tests tests/integration/Yuy2ColorTests.cpp)
  target_compile_features(graphicenhancement_yuy2_color_tests PRIVATE cxx_std_20)
  target_link_libraries(graphicenhancement_yuy2_color_tests PRIVATE graphicenhancement_engine)
  target_compile_features(graphicenhancement_capture_color_probe PRIVATE cxx_std_20)
  target_compile_definitions(graphicenhancement_capture_color_probe PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN)
  target_link_libraries(graphicenhancement_capture_color_probe PRIVATE graphicenhancement_engine)
  target_compile_features(graphicenhancement_image_dimension_tests PRIVATE cxx_std_20)
  target_include_directories(graphicenhancement_image_dimension_tests PRIVATE ${FFMPEG_INCLUDE_DIRS})
  target_compile_definitions(graphicenhancement_image_dimension_tests PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN GRAPHICENHANCEMENT_PROJECT_ROOT="${CMAKE_CURRENT_SOURCE_DIR}")
  target_link_libraries(graphicenhancement_image_dimension_tests PRIVATE graphicenhancement_engine)
  add_executable(graphicenhancement_preview_geometry_tests tests/integration/PreviewGeometryTests.cpp)
  add_executable(graphicenhancement_present_sink_lifecycle_tests tests/perf/PresentSinkLifecycleTests.cpp)
  target_compile_features(graphicenhancement_present_sink_lifecycle_tests PRIVATE cxx_std_20)
  target_compile_definitions(graphicenhancement_present_sink_lifecycle_tests PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN)
  target_link_libraries(graphicenhancement_present_sink_lifecycle_tests PRIVATE graphicenhancement_gfx user32)
  add_executable(graphicenhancement_settings_transaction_tests tests/integration/SettingsTransactionTests.cpp)
  target_compile_features(graphicenhancement_settings_transaction_tests PRIVATE cxx_std_20)
  target_link_libraries(graphicenhancement_settings_transaction_tests PRIVATE graphicenhancement_engine)
  add_executable(graphicenhancement_capture_cadence_fg_tests tests/integration/CaptureCadenceFgTests.cpp)
  target_compile_features(graphicenhancement_capture_cadence_fg_tests PRIVATE cxx_std_20)
  target_link_libraries(graphicenhancement_capture_cadence_fg_tests PRIVATE graphicenhancement_engine)
  add_executable(graphicenhancement_sr_quality_tests tests/integration/SrQualityTests.cpp)
  target_compile_features(graphicenhancement_sr_quality_tests PRIVATE cxx_std_20)
  target_link_libraries(graphicenhancement_sr_quality_tests PRIVATE graphicenhancement_engine)
  add_executable(graphicenhancement_experimental_backend_tests tests/integration/ExperimentalBackendTests.cpp)
  target_compile_features(graphicenhancement_experimental_backend_tests PRIVATE cxx_std_20)
  target_include_directories(graphicenhancement_experimental_backend_tests PRIVATE ${FFMPEG_INCLUDE_DIRS})
  target_compile_definitions(graphicenhancement_experimental_backend_tests PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN)
  target_link_libraries(graphicenhancement_experimental_backend_tests PRIVATE graphicenhancement_engine)
  target_compile_features(graphicenhancement_preview_geometry_tests PRIVATE cxx_std_20)
  target_include_directories(graphicenhancement_preview_geometry_tests PRIVATE ${FFMPEG_INCLUDE_DIRS})
  target_compile_definitions(graphicenhancement_preview_geometry_tests PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN)
  target_link_libraries(graphicenhancement_preview_geometry_tests PRIVATE graphicenhancement_engine)
  target_compile_features(graphicenhancement_repair_parameter_tests PRIVATE cxx_std_20)
  target_include_directories(graphicenhancement_repair_parameter_tests PRIVATE ${FFMPEG_INCLUDE_DIRS})
  target_compile_definitions(graphicenhancement_repair_parameter_tests PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN GRAPHICENHANCEMENT_PROJECT_ROOT="${CMAKE_CURRENT_SOURCE_DIR}")
  target_link_libraries(graphicenhancement_repair_parameter_tests PRIVATE graphicenhancement_pipeline graphicenhancement_sinks graphicenhancement_nvof)
  add_executable(graphicenhancement_repair_fg_tests tests/integration/RepairFgTests.cpp)
  add_executable(graphicenhancement_export_frame_pool_tests tests/integration/ExportFramePoolTests.cpp)
  add_executable(graphicenhancement_export_worker_failure_tests tests/integration/ExportWorkerFailureTests.cpp)
  add_executable(graphicenhancement_export_workflow_tests tests/integration/ExportWorkflowTests.cpp)
  # Diagnostic-only graph variant: an identity-copy C ABI provider is admitted
  # on the actual test adapter. Production graph and hardware policy are unchanged.
  set(GRAPHICENHANCEMENT_AMD_NR_TEST_GRAPH_SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/pipeline/EnhanceGraph.cpp" CACHE FILEPATH "Graph snapshot for AMD identity regression only")
  file(READ "${GRAPHICENHANCEMENT_AMD_NR_TEST_GRAPH_SOURCE}" _amd_nr_graph)
  # A pattern that stops matching must stop the build: the fixture then runs on
  # the real adapter, and every AMD case fails with "requires an AMD adapter".
  set(_amd_nr_open "ring_->queue(),context_.adapter().vendorId,instance->model.performance))return false;")
  string(FIND "${_amd_nr_graph}" "${_amd_nr_open}" _amd_nr_open_at)
  if(_amd_nr_open_at EQUAL -1)
    message(FATAL_ERROR "AMD NR identity fixture: the backend open call in EnhanceGraph.cpp changed; update this pattern")
  endif()
  string(REPLACE "${_amd_nr_open}"
    "ring_->queue(),0x1002 /* identity fixture only */,instance->model.performance))return false;" _amd_nr_graph "${_amd_nr_graph}")
  file(MAKE_DIRECTORY "${CMAKE_BINARY_DIR}/amd-nr-graph-test")
  file(WRITE "${CMAKE_BINARY_DIR}/amd-nr-graph-test/EnhanceGraph.cpp" "${_amd_nr_graph}")
  set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${GRAPHICENHANCEMENT_AMD_NR_TEST_GRAPH_SOURCE}")
  add_executable(graphicenhancement_amd_nr_graph_tests tests/integration/LmxxfNrGraphTests.cpp src/engine/EffectChain.cpp "${CMAKE_BINARY_DIR}/amd-nr-graph-test/EnhanceGraph.cpp")
  target_compile_features(graphicenhancement_amd_nr_graph_tests PRIVATE cxx_std_20)
  target_include_directories(graphicenhancement_amd_nr_graph_tests PRIVATE $<TARGET_PROPERTY:graphicenhancement_pipeline,INCLUDE_DIRECTORIES>)
  target_compile_definitions(graphicenhancement_amd_nr_graph_tests PRIVATE $<TARGET_PROPERTY:graphicenhancement_pipeline,COMPILE_DEFINITIONS>)
  target_compile_options(graphicenhancement_amd_nr_graph_tests PRIVATE /utf-8 /WX-)
  target_link_libraries(graphicenhancement_amd_nr_graph_tests PRIVATE graphicenhancement_pipeline graphicenhancement_sinks)
  add_dependencies(graphicenhancement_amd_nr_graph_tests graphicenhancement_lmxxf_fake_runtime graphicenhancement_lmxxf_fake_original_runtime)
  target_compile_features(graphicenhancement_export_workflow_tests PRIVATE cxx_std_20)
  target_compile_options(graphicenhancement_export_workflow_tests PRIVATE /utf-8)
  target_link_libraries(graphicenhancement_export_workflow_tests PRIVATE graphicenhancement_engine)
  add_executable(graphicenhancement_export_queue_tests tests/unit/ExportQueueTests.cpp)
  target_compile_features(graphicenhancement_export_queue_tests PRIVATE cxx_std_20)
  target_compile_options(graphicenhancement_export_queue_tests PRIVATE /utf-8)
  target_link_libraries(graphicenhancement_export_queue_tests PRIVATE graphicenhancement_engine)
  target_compile_features(graphicenhancement_export_worker_failure_tests PRIVATE cxx_std_20)
  target_link_libraries(graphicenhancement_export_worker_failure_tests PRIVATE graphicenhancement_engine)
  add_executable(graphicenhancement_fg_lifecycle_tests tests/integration/FgLifecycleTests.cpp)
  add_executable(graphicenhancement_fg_settings_tests tests/integration/FgSettingsTests.cpp)
  add_executable(graphicenhancement_fg_sustained_tests tests/integration/FgSustainedTests.cpp)
  target_compile_features(graphicenhancement_fg_sustained_tests PRIVATE cxx_std_20)
  target_link_libraries(graphicenhancement_fg_sustained_tests PRIVATE graphicenhancement_engine)
  add_executable(graphicenhancement_fg_presentation_tests tests/integration/FgPresentationTests.cpp)
  add_executable(graphicenhancement_amf_frc_tests tests/integration/AmfFrcTests.cpp)
  target_compile_features(graphicenhancement_amf_frc_tests PRIVATE cxx_std_20)
  target_include_directories(graphicenhancement_amf_frc_tests PRIVATE ${FFMPEG_INCLUDE_DIRS})
  target_link_libraries(graphicenhancement_amf_frc_tests PRIVATE graphicenhancement_engine)
  add_executable(graphicenhancement_fsr_switch_tests tests/integration/FsrFgSwitchTests.cpp)
  target_compile_features(graphicenhancement_fsr_switch_tests PRIVATE cxx_std_20)
  target_include_directories(graphicenhancement_fsr_switch_tests PRIVATE ${FFMPEG_INCLUDE_DIRS})
  target_link_libraries(graphicenhancement_fsr_switch_tests PRIVATE graphicenhancement_engine)
  target_compile_features(graphicenhancement_fg_presentation_tests PRIVATE cxx_std_20)
  target_compile_definitions(graphicenhancement_fg_presentation_tests PRIVATE GRAPHICENHANCEMENT_PROJECT_ROOT="${CMAKE_CURRENT_SOURCE_DIR}")
  target_link_libraries(graphicenhancement_fg_presentation_tests PRIVATE graphicenhancement_engine)
  add_executable(graphicenhancement_player_tracks_tests tests/integration/PlayerTracksTests.cpp)
  add_executable(graphicenhancement_scheduling_chain_tests tests/integration/SchedulingChainTests.cpp)
  add_executable(graphicenhancement_capture_latency_tests tests/integration/CaptureLatencyComparisonTests.cpp)
  target_compile_features(graphicenhancement_capture_latency_tests PRIVATE cxx_std_20)
  target_compile_options(graphicenhancement_capture_latency_tests PRIVATE /utf-8)
  target_link_libraries(graphicenhancement_capture_latency_tests PRIVATE graphicenhancement_engine)
  add_dependencies(graphicenhancement_capture_latency_tests graphicenhancement_shader_present_blit)
  add_executable(graphicenhancement_presentation_pacing_tests tests/integration/PresentationPacingTests.cpp)
  target_compile_features(graphicenhancement_presentation_pacing_tests PRIVATE cxx_std_20)
  target_compile_options(graphicenhancement_presentation_pacing_tests PRIVATE /utf-8)
  target_link_libraries(graphicenhancement_presentation_pacing_tests PRIVATE graphicenhancement_engine)
  target_compile_features(graphicenhancement_scheduling_chain_tests PRIVATE cxx_std_20)
  target_link_libraries(graphicenhancement_scheduling_chain_tests PRIVATE graphicenhancement_engine)
  target_compile_features(graphicenhancement_player_tracks_tests PRIVATE cxx_std_20)
  target_link_libraries(graphicenhancement_player_tracks_tests PRIVATE graphicenhancement_engine)
  add_executable(graphicenhancement_audio_track_output_tests tests/integration/AudioTrackOutputTests.cpp)
  add_executable(graphicenhancement_audio_playback_rate_tests tests/integration/AudioPlaybackRateTests.cpp)
  target_compile_features(graphicenhancement_audio_playback_rate_tests PRIVATE cxx_std_20)
  target_link_libraries(graphicenhancement_audio_playback_rate_tests PRIVATE graphicenhancement_sinks)
  target_compile_features(graphicenhancement_audio_track_output_tests PRIVATE cxx_std_20)
  target_link_libraries(graphicenhancement_audio_track_output_tests PRIVATE graphicenhancement_engine)
  target_compile_features(graphicenhancement_fg_settings_tests PRIVATE cxx_std_20)
  target_link_libraries(graphicenhancement_fg_settings_tests PRIVATE graphicenhancement_engine)
  target_compile_features(graphicenhancement_fg_lifecycle_tests PRIVATE cxx_std_20)
  target_compile_definitions(graphicenhancement_fg_lifecycle_tests PRIVATE GRAPHICENHANCEMENT_PROJECT_ROOT="${CMAKE_CURRENT_SOURCE_DIR}")
  target_link_libraries(graphicenhancement_fg_lifecycle_tests PRIVATE graphicenhancement_engine)
  target_compile_features(graphicenhancement_export_frame_pool_tests PRIVATE cxx_std_20)
  target_compile_definitions(graphicenhancement_export_frame_pool_tests PRIVATE GRAPHICENHANCEMENT_PROJECT_ROOT="${CMAKE_CURRENT_SOURCE_DIR}")
  target_link_libraries(graphicenhancement_export_frame_pool_tests PRIVATE graphicenhancement_engine)
  add_executable(graphicenhancement_motion_validation_tests tests/integration/MotionValidationTests.cpp)
  add_executable(graphicenhancement_depth_response_tests tests/integration/DepthResponseTests.cpp)
  add_executable(graphicenhancement_srfg_depth_tests tests/integration/SrFgDepthResponseTests.cpp)
  target_compile_features(graphicenhancement_srfg_depth_tests PRIVATE cxx_std_20)
  target_include_directories(graphicenhancement_srfg_depth_tests PRIVATE ${FFMPEG_INCLUDE_DIRS})
  target_compile_definitions(graphicenhancement_srfg_depth_tests PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN GRAPHICENHANCEMENT_PROJECT_ROOT="${CMAKE_CURRENT_SOURCE_DIR}")
  target_link_libraries(graphicenhancement_srfg_depth_tests PRIVATE graphicenhancement_engine)
  add_executable(graphicenhancement_fg_motion_boundary_tests tests/integration/FgMotionBoundaryTests.cpp)
  target_compile_features(graphicenhancement_fg_motion_boundary_tests PRIVATE cxx_std_20)
  target_include_directories(graphicenhancement_fg_motion_boundary_tests PRIVATE ${FFMPEG_INCLUDE_DIRS})
  target_compile_definitions(graphicenhancement_fg_motion_boundary_tests PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN GRAPHICENHANCEMENT_PROJECT_ROOT="${CMAKE_CURRENT_SOURCE_DIR}")
  target_link_libraries(graphicenhancement_fg_motion_boundary_tests PRIVATE graphicenhancement_engine)
  add_executable(graphicenhancement_fg_xess_boundary_tests tests/integration/FgXessBoundaryTests.cpp)
  target_compile_features(graphicenhancement_fg_xess_boundary_tests PRIVATE cxx_std_20)
  target_include_directories(graphicenhancement_fg_xess_boundary_tests PRIVATE ${FFMPEG_INCLUDE_DIRS})
  target_compile_definitions(graphicenhancement_fg_xess_boundary_tests PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN GRAPHICENHANCEMENT_PROJECT_ROOT="${CMAKE_CURRENT_SOURCE_DIR}")
  target_link_libraries(graphicenhancement_fg_xess_boundary_tests PRIVATE graphicenhancement_engine d3d11 dxgi)
  add_executable(graphicenhancement_xess_motion_contract_tests tests/integration/XessMotionContractTests.cpp)
  target_compile_features(graphicenhancement_xess_motion_contract_tests PRIVATE cxx_std_20)
  target_include_directories(graphicenhancement_xess_motion_contract_tests PRIVATE ${FFMPEG_INCLUDE_DIRS})
  target_compile_definitions(graphicenhancement_xess_motion_contract_tests PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN GRAPHICENHANCEMENT_PROJECT_ROOT="${CMAKE_CURRENT_SOURCE_DIR}")
  target_link_libraries(graphicenhancement_xess_motion_contract_tests PRIVATE graphicenhancement_engine)
  add_executable(graphicenhancement_xess_motion_quality_tests tests/integration/XessMotionQualityTests.cpp)
  target_compile_features(graphicenhancement_xess_motion_quality_tests PRIVATE cxx_std_20)
  target_include_directories(graphicenhancement_xess_motion_quality_tests PRIVATE ${FFMPEG_INCLUDE_DIRS})
  target_compile_definitions(graphicenhancement_xess_motion_quality_tests PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN GRAPHICENHANCEMENT_PROJECT_ROOT="${CMAKE_CURRENT_SOURCE_DIR}")
  target_link_libraries(graphicenhancement_xess_motion_quality_tests PRIVATE graphicenhancement_engine)
  # Qt 6.8.3 is staged under deps/ (the user allowed the latest Qt). The probe is
# opt-in so a normal product build never depends on Qt being present.
option(GRAPHICENHANCEMENT_BUILD_QT_PROBE "Build the Qt + D3D12 host probe" OFF)
option(GRAPHICENHANCEMENT_BUILD_QML_UI "Build the QML front end" OFF)
if(GRAPHICENHANCEMENT_BUILD_QT_PROBE OR GRAPHICENHANCEMENT_BUILD_QML_UI)
  find_package(Qt6 6.8 QUIET COMPONENTS Core Gui Qml Quick QuickControls2 Widgets Network)
endif()

# The QML bridge. It is engine code (no QML files), so it compiles into a
# separate small library rather than into graphicenhancement_engine: the product build must
# never depend on Qt being installed.
if(GRAPHICENHANCEMENT_BUILD_QML_UI AND Qt6_FOUND)
  # The 日落 palette's startup music (StartupMusic.h): Media Foundation's media engine.
  add_library(graphicenhancement_startup_music STATIC src/ui/StartupMusic.cpp include/graphicenhancement/ui/StartupMusic.h)
  set_target_properties(graphicenhancement_startup_music PROPERTIES AUTOMOC ON)
  target_compile_features(graphicenhancement_startup_music PUBLIC cxx_std_20)
  target_compile_options(graphicenhancement_startup_music PRIVATE /utf-8)
  target_include_directories(graphicenhancement_startup_music PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/include)
  target_link_libraries(graphicenhancement_startup_music PUBLIC graphicenhancement_base Qt6::Core PRIVATE ole32 oleaut32 mfplat mfuuid)
  add_executable(graphicenhancement_startup_music_tests tests/qml/StartupMusicTests.cpp)
  target_link_libraries(graphicenhancement_startup_music_tests PRIVATE graphicenhancement_startup_music)
  set(GRAPHICENHANCEMENT_UPDATE_PUBLIC_KEY "" CACHE STRING "Ed25519 release verification key as 64 lowercase hex digits")
  set(GRAPHICENHANCEMENT_UPDATE_TEST_PORT "" CACHE STRING "Local HTTP update fixture port (test builds only)")
  string(LENGTH "${GRAPHICENHANCEMENT_UPDATE_PUBLIC_KEY}" graphicenhancement_update_key_length)
  if(GRAPHICENHANCEMENT_UPDATE_PUBLIC_KEY AND
     (NOT graphicenhancement_update_key_length EQUAL 64 OR NOT GRAPHICENHANCEMENT_UPDATE_PUBLIC_KEY MATCHES "^[0-9a-f]+$"))
    message(FATAL_ERROR "GRAPHICENHANCEMENT_UPDATE_PUBLIC_KEY must be a 32-byte Ed25519 public key in lowercase hex")
  endif()
  find_package(OpenSSL 1.1.1 REQUIRED COMPONENTS Crypto)
  add_library(graphicenhancement_portable_manifest STATIC src/base/PortableUpdateManifest.cpp)
  target_compile_features(graphicenhancement_portable_manifest PUBLIC cxx_std_20)
  target_compile_definitions(graphicenhancement_portable_manifest PRIVATE GRAPHICENHANCEMENT_UPDATE_PUBLIC_KEY="${GRAPHICENHANCEMENT_UPDATE_PUBLIC_KEY}")
  if(GRAPHICENHANCEMENT_UPDATE_TEST_PORT)
    if(NOT GRAPHICENHANCEMENT_UPDATE_TEST_PORT MATCHES "^[1-9][0-9]*$" OR GRAPHICENHANCEMENT_UPDATE_TEST_PORT GREATER 65535
       OR NOT GRAPHICENHANCEMENT_DISPLAY_VERSION MATCHES "-.*test")
      message(FATAL_ERROR "The loopback update server requires a valid port and a test display version")
    endif()
    target_compile_definitions(graphicenhancement_portable_manifest PRIVATE GRAPHICENHANCEMENT_UPDATE_TEST_PORT=${GRAPHICENHANCEMENT_UPDATE_TEST_PORT})
  endif()
  if(GRAPHICENHANCEMENT_UPDATE_TEST_PORT)
    set(graphicenhancement_update_test_build true)
  else()
    set(graphicenhancement_update_test_build false)
  endif()
  file(GENERATE OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/portable-update-trust.json"
    CONTENT "{\"publicKey\":\"${GRAPHICENHANCEMENT_UPDATE_PUBLIC_KEY}\",\"testBuild\":${graphicenhancement_update_test_build}}\n")
  target_include_directories(graphicenhancement_portable_manifest PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}/include")
  target_link_libraries(graphicenhancement_portable_manifest PUBLIC Qt6::Core PRIVATE OpenSSL::Crypto ws2_32 crypt32)
  add_executable(graphicenhancement_portable_manifest_tests tests/unit/PortableUpdateManifestTests.cpp)
  target_link_libraries(graphicenhancement_portable_manifest_tests PRIVATE graphicenhancement_portable_manifest OpenSSL::Crypto)
  add_test(NAME graphicenhancement_portable_manifest COMMAND graphicenhancement_portable_manifest_tests)

  add_executable(graphicenhancement_portable_launcher WIN32 apps/graphicenhancement-portable/Launcher.cpp)
  target_compile_features(graphicenhancement_portable_launcher PRIVATE cxx_std_20)
  target_compile_options(graphicenhancement_portable_launcher PRIVATE /utf-8)
  target_compile_definitions(graphicenhancement_portable_launcher PRIVATE UNICODE _UNICODE NOMINMAX WIN32_LEAN_AND_MEAN)
  target_include_directories(graphicenhancement_portable_launcher PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/include")
  target_link_libraries(graphicenhancement_portable_launcher PRIVATE graphicenhancement_base shell32 user32)
  add_executable(graphicenhancement_update_worker apps/graphicenhancement-portable/UpdateWorker.cpp)
  target_compile_definitions(graphicenhancement_update_worker PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN)
  target_link_libraries(graphicenhancement_update_worker PRIVATE graphicenhancement_portable_manifest ole32 uuid)
  add_library(graphicenhancement_update_checker STATIC src/ui/UpdateChecker.cpp include/graphicenhancement/ui/UpdateChecker.h
    src/ui/PortableUpdate.cpp include/graphicenhancement/ui/PortableUpdate.h)
  set_target_properties(graphicenhancement_update_checker PROPERTIES AUTOMOC ON)
  target_compile_features(graphicenhancement_update_checker PUBLIC cxx_std_20)
  target_compile_options(graphicenhancement_update_checker PRIVATE /utf-8)
  target_include_directories(graphicenhancement_update_checker PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/include)
  target_link_libraries(graphicenhancement_update_checker PUBLIC Qt6::Core Qt6::Gui Qt6::Network graphicenhancement_portable_manifest)
  add_library(graphicenhancement_qml_bridge STATIC src/ui/QmlExportQueueModel.cpp include/graphicenhancement/ui/QmlExportQueueModel.h src/ui/QmlPlayerBridge.cpp src/ui/ThumbnailProvider.cpp
    src/ui/PlaylistModel.cpp include/graphicenhancement/ui/PlaylistModel.h
    src/ui/LiveTranslation.cpp src/ui/LiveTranslation.h
    src/ui/LiveSentences.cpp src/ui/LiveSentences.h
    src/ui/LiveAsr.cpp src/ui/LiveAsr.h
    src/ui/AsrAudioTap.cpp src/ui/AsrAudioTap.h
    src/ui/AsrModels.cpp src/ui/AsrModels.h
    src/ui/AsrWorker.cpp src/ui/AsrWorker.h
    src/ui/TranslationAssets.cpp src/ui/TranslationAssets.h
    src/ui/WinCaptionReader.cpp src/ui/WinCaptionReader.h
    include/graphicenhancement/ui/QmlPlayerBridge.h include/graphicenhancement/ui/ThumbnailProvider.h
    # Custom: the start-up format badge, same layered-window construction.
    src/media/FormatBadgeWindow.cpp
    # P4-c: the existing subtitle renderer, reused as-is (no second renderer).
    apps/graphicenhancement/ui/SubtitleOverlay.cpp)
  set_source_files_properties(apps/graphicenhancement/ui/SubtitleOverlay.cpp PROPERTIES COMPILE_OPTIONS /utf-8)
  # AUTOMOC: QmlPlayerBridge declares Q_OBJECT, so its meta-object has to be
  # generated. Without this the library links but every signal is unresolved.
  # Keep bridge domains explicit: no source glob or duplicate runtime state.
  target_sources(graphicenhancement_qml_bridge PRIVATE
    src/ui/NvidiaVrrProfileController.cpp
    include/graphicenhancement/ui/NvidiaVrrProfileController.h
    src/ui/bridge/Hardware.cpp
    src/ui/bridge/Status.cpp
    src/ui/bridge/FrameGeneration.cpp
    src/ui/bridge/Colour.cpp
    src/ui/bridge/Preferences.cpp
    src/ui/bridge/AnrDownload.cpp
    src/ui/bridge/Capture.cpp
    src/ui/bridge/VirtualCaptureAudioSetup.cpp
    src/ui/bridge/VirtualCaptureAudioSetup.h
    src/ui/bridge/RemotePlay.cpp
    src/ui/bridge/Export.cpp
    src/ui/bridge/Subtitles.cpp
    src/ui/bridge/Playback.cpp
    src/ui/bridge/Enhancement.cpp
    src/ui/bridge/Chain.cpp
    src/ui/bridge/Recording.cpp
    src/ui/bridge/VirtualCamera.cpp
    src/ui/bridge/View.cpp
    # Custom (Chrome bridge): local HTTP endpoint the browser extension posts to.
    src/ui/bridge/PlaybackServer.cpp
    include/graphicenhancement/ui/PlaybackServer.h
    src/ui/QmlPlayerBridge_p.h)
  set_target_properties(graphicenhancement_qml_bridge PROPERTIES AUTOMOC ON)
  # Interface language (UiLanguage.h): its own small library so the streaming models,
  # which are tested without the player, translate their messages too.
  add_library(graphicenhancement_ui_i18n STATIC src/ui/UiLanguage.cpp include/graphicenhancement/ui/UiLanguage.h)
  target_compile_features(graphicenhancement_ui_i18n PUBLIC cxx_std_20)
  target_compile_options(graphicenhancement_ui_i18n PRIVATE /utf-8)
  target_include_directories(graphicenhancement_ui_i18n PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/include)
  target_link_libraries(graphicenhancement_ui_i18n PUBLIC graphicenhancement_base Qt6::Core)
  target_link_libraries(graphicenhancement_qml_bridge PUBLIC graphicenhancement_ui_i18n graphicenhancement_update_checker)
  add_executable(graphicenhancement_playback_server_tests tests/unit/PlaybackServerTests.cpp src/ui/bridge/PlaybackServer.cpp include/graphicenhancement/ui/PlaybackServer.h)
  set_target_properties(graphicenhancement_playback_server_tests PROPERTIES AUTOMOC ON)
  target_compile_features(graphicenhancement_playback_server_tests PRIVATE cxx_std_20)
  target_link_libraries(graphicenhancement_playback_server_tests PRIVATE graphicenhancement_base Qt6::Core Qt6::Network)
  add_executable(graphicenhancement_ui_i18n_tests tests/unit/UiLanguageTests.cpp)
  target_compile_options(graphicenhancement_ui_i18n_tests PRIVATE /utf-8)
  target_link_libraries(graphicenhancement_ui_i18n_tests PRIVATE graphicenhancement_ui_i18n)
  qt_add_resources(graphicenhancement_ui_i18n_tests "graphicenhancement_i18n_tests" PREFIX "/i18n" BASE "${CMAKE_CURRENT_SOURCE_DIR}/i18n" FILES i18n/catalog.json)
  if(GRAPHICENHANCEMENT_ENABLE_MOONLIGHT)
    target_sources(graphicenhancement_qml_bridge PRIVATE src/ui/MoonlightInputCapture.cpp include/graphicenhancement/ui/MoonlightInputCapture.h)
    # The PC streaming model (hosts, pairing, apps, settings) is its own small library so it can be
    # tested against the mock host without the whole player.
    add_library(graphicenhancement_moonlight_model STATIC src/ui/MoonlightModel.cpp include/graphicenhancement/ui/MoonlightModel.h)
    set_target_properties(graphicenhancement_moonlight_model PROPERTIES AUTOMOC ON)
    target_compile_features(graphicenhancement_moonlight_model PUBLIC cxx_std_20)
    target_include_directories(graphicenhancement_moonlight_model PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/include ${FFMPEG_INCLUDE_DIRS})
    target_compile_definitions(graphicenhancement_moonlight_model PUBLIC GRAPHICENHANCEMENT_ENABLE_MOONLIGHT=1 PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN)
    target_link_libraries(graphicenhancement_moonlight_model PUBLIC graphicenhancement_moonlight_protocol graphicenhancement_base graphicenhancement_ui_i18n Qt6::Core Qt6::Gui)
    target_link_libraries(graphicenhancement_qml_bridge PUBLIC graphicenhancement_moonlight_model)
    if(GRAPHICENHANCEMENT_ENABLE_XBOX)
      add_library(graphicenhancement_xbox_model STATIC src/ui/XboxModel.cpp include/graphicenhancement/ui/XboxModel.h)
      set_target_properties(graphicenhancement_xbox_model PROPERTIES AUTOMOC ON)
      target_compile_features(graphicenhancement_xbox_model PUBLIC cxx_std_20)
      target_include_directories(graphicenhancement_xbox_model PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/include ${FFMPEG_INCLUDE_DIRS})
      target_compile_definitions(graphicenhancement_xbox_model PUBLIC GRAPHICENHANCEMENT_ENABLE_XBOX=1 PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN)
      target_link_libraries(graphicenhancement_xbox_model PUBLIC graphicenhancement_xbox_protocol graphicenhancement_base graphicenhancement_ui_i18n Qt6::Core Qt6::Gui)
      target_link_libraries(graphicenhancement_qml_bridge PUBLIC graphicenhancement_xbox_model)
    endif()

    add_executable(graphicenhancement_moonlight_model_tests tests/moonlight/ModelTests.cpp)
    target_compile_features(graphicenhancement_moonlight_model_tests PRIVATE cxx_std_20)
    target_compile_definitions(graphicenhancement_moonlight_model_tests PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN)
    target_include_directories(graphicenhancement_moonlight_model_tests PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/tests/moonlight)
    target_link_libraries(graphicenhancement_moonlight_model_tests PRIVATE graphicenhancement_moonlight_model)
  endif()
  target_compile_features(graphicenhancement_qml_bridge PRIVATE cxx_std_20)
  target_include_directories(graphicenhancement_qml_bridge PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/include ${CMAKE_CURRENT_SOURCE_DIR}/src ${FFMPEG_INCLUDE_DIRS}
    ${CMAKE_CURRENT_SOURCE_DIR}/apps/graphicenhancement/ui)
  # Widgets is needed only for QFileDialog: the native file picker is the one
  # piece of the old shell worth keeping, and its own dialog is what users
  # expect from a desktop app. No QWidget UI is created.
  target_link_libraries(graphicenhancement_qml_bridge PUBLIC graphicenhancement_engine Qt6::Core Qt6::Gui Qt6::Qml Qt6::Quick Qt6::QuickControls2 Qt6::Widgets Qt6::Network PRIVATE shell32 ole32 oleaut32 uiautomationcore iphlpapi ws2_32 ${FFMPEG_LIBRARIES})
  add_executable(graphicenhancement_playlist_tests tests/unit/PlaylistModelTests.cpp src/ui/PlaylistModel.cpp include/graphicenhancement/ui/PlaylistModel.h)
  set_target_properties(graphicenhancement_playlist_tests PROPERTIES AUTOMOC ON)
  target_compile_features(graphicenhancement_playlist_tests PRIVATE cxx_std_20)
  target_compile_options(graphicenhancement_playlist_tests PRIVATE /utf-8)
  target_include_directories(graphicenhancement_playlist_tests PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/include)
  target_link_libraries(graphicenhancement_playlist_tests PRIVATE Qt6::Core)
  find_package(Qt6 COMPONENTS Test)
  if(TARGET Qt6::Test)
    add_executable(graphicenhancement_live_translation_tests tests/integration/LiveTranslationTests.cpp)
    target_compile_features(graphicenhancement_live_translation_tests PRIVATE cxx_std_20)
    target_compile_options(graphicenhancement_live_translation_tests PRIVATE /utf-8)
    target_link_libraries(graphicenhancement_live_translation_tests PRIVATE graphicenhancement_qml_bridge Qt6::Test)
    add_executable(graphicenhancement_audio_volume_bridge_tests tests/integration/AudioVolumeBridgeTests.cpp)
    target_compile_features(graphicenhancement_audio_volume_bridge_tests PRIVATE cxx_std_20)
    target_compile_options(graphicenhancement_audio_volume_bridge_tests PRIVATE /utf-8)
    target_link_options(graphicenhancement_audio_volume_bridge_tests PRIVATE /STACK:8388608)
    target_link_libraries(graphicenhancement_audio_volume_bridge_tests PRIVATE graphicenhancement_qml_bridge Qt6::Test)
    add_executable(graphicenhancement_qml_rife_availability_tests tests/integration/QmlRifeAvailabilityTests.cpp)
    target_compile_features(graphicenhancement_qml_rife_availability_tests PRIVATE cxx_std_20)
    target_compile_options(graphicenhancement_qml_rife_availability_tests PRIVATE /utf-8)
    target_link_options(graphicenhancement_qml_rife_availability_tests PRIVATE /STACK:8388608)
    target_link_libraries(graphicenhancement_qml_rife_availability_tests PRIVATE graphicenhancement_qml_bridge Qt6::Test)
    add_executable(graphicenhancement_update_checker_tests tests/unit/UpdateCheckerTests.cpp)
    set_target_properties(graphicenhancement_update_checker_tests PROPERTIES AUTOMOC ON)
    target_compile_options(graphicenhancement_update_checker_tests PRIVATE /utf-8)
    target_link_libraries(graphicenhancement_update_checker_tests PRIVATE graphicenhancement_update_checker Qt6::Test)
    add_executable(graphicenhancement_playlist_window_tests tests/qml/PlaylistWindowTests.cpp)
    target_compile_features(graphicenhancement_playlist_window_tests PRIVATE cxx_std_20)
    target_compile_options(graphicenhancement_playlist_window_tests PRIVATE /utf-8)
    target_include_directories(graphicenhancement_playlist_window_tests PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/include)
    target_compile_definitions(graphicenhancement_playlist_window_tests PRIVATE GRAPHICENHANCEMENT_QML_DIR="${CMAKE_CURRENT_SOURCE_DIR}/qml")
    target_link_libraries(graphicenhancement_playlist_window_tests PRIVATE graphicenhancement_qml_bridge Qt6::Test)
  endif()
  # GRAPHICENHANCEMENT_DISPLAY_VERSION is the human-readable version the app reports; it is
  # the same value the resource file uses, so the UI cannot drift from it.
  target_compile_definitions(graphicenhancement_qml_bridge PRIVATE GRAPHICENHANCEMENT_DISPLAY_VERSION="${GRAPHICENHANCEMENT_DISPLAY_VERSION}")
  # libass (ISC) + FreeType/FriBidi/HarfBuzz, static, for full ASS/SSA effect
  # subtitles. Local prebuilt tree only (vcpkg x64-windows-static-md); never in
  # source Git. Without it ASS tracks fall back to the built-in styled renderer.
  set(GRAPHICENHANCEMENT_LIBASS_ROOT "" CACHE PATH "libass static install prefix (include/ass/ass.h, lib/ass.lib)")
  if(GRAPHICENHANCEMENT_LIBASS_ROOT AND EXISTS "${GRAPHICENHANCEMENT_LIBASS_ROOT}/include/ass/ass.h")
    target_sources(graphicenhancement_qml_bridge PRIVATE apps/graphicenhancement/ui/AssSubtitleRenderer.cpp apps/graphicenhancement/ui/AssSubtitleRenderer.h)
    set_source_files_properties(apps/graphicenhancement/ui/AssSubtitleRenderer.cpp PROPERTIES COMPILE_OPTIONS /utf-8)
    target_include_directories(graphicenhancement_qml_bridge PRIVATE "${GRAPHICENHANCEMENT_LIBASS_ROOT}/include")
    target_compile_definitions(graphicenhancement_qml_bridge PRIVATE GRAPHICENHANCEMENT_HAS_LIBASS=1)
    foreach(lib ass harfbuzz fribidi freetype libpng16 zs bz2 brotlidec brotlicommon)
      target_link_libraries(graphicenhancement_qml_bridge PRIVATE "${GRAPHICENHANCEMENT_LIBASS_ROOT}/lib/${lib}.lib")
    endforeach()
    target_link_libraries(graphicenhancement_qml_bridge PRIVATE gdi32 dwrite)
    message(STATUS "libass: ${GRAPHICENHANCEMENT_LIBASS_ROOT}")
  else()
    message(STATUS "libass: not configured; ASS effects use the built-in styled renderer")
  endif()

  # The QML module is deployed as plain files next to the executable rather
  # than compiled into a resource: the qmldir-based module keeps the .qml
  # editable in a build tree, which matters while the interface is still being
  # worked on. A packaged release can switch to compiling them in.
  # WIN32: a GUI subsystem binary. Without it a console window follows the app
  # around, which is not what a player should look like. Diagnostics still reach
  # the log file through the logger.
  add_executable(graphicenhancement_qml_ui WIN32 apps/graphicenhancement-qml/main.cpp apps/graphicenhancement-qml/ProfileInstance.cpp
    src/ui/QmlDataDirectory.cpp src/ui/QmlDiskCache.cpp)
  add_dependencies(graphicenhancement_qml_ui graphicenhancement_virtualcam_components)
  if(GRAPHICENHANCEMENT_UPDATE_PUBLIC_KEY)
    add_dependencies(graphicenhancement_qml_ui graphicenhancement_portable_launcher graphicenhancement_update_worker)
  endif()
  if(GRAPHICENHANCEMENT_UPDATE_TEST_PORT)
    target_compile_definitions(graphicenhancement_qml_ui PRIVATE GRAPHICENHANCEMENT_PORTABLE_UPDATE_TEST=1)
  endif()
  if(GRAPHICENHANCEMENT_ENABLE_LIBDOVI)
    add_custom_target(graphicenhancement_libdovi_runtime ALL
      COMMAND "${CMAKE_COMMAND}" -E copy_if_different "${GRAPHICENHANCEMENT_LIBDOVI_RUNTIME}" "$<TARGET_FILE_DIR:graphicenhancement_qml_ui>")
    add_dependencies(graphicenhancement_qml_ui graphicenhancement_libdovi_runtime)
  endif()
  # The QML copy is its own always-run step rather than a POST_BUILD of the link:
  # its two long E:/项目 paths on the link statement pushed that command past
  # CMake's response-file threshold, and link.exe reads response files in the
  # ANSI code page (the UTF-8 Qt library paths then fail to open).
  add_custom_target(graphicenhancement_qml_files ALL
    COMMAND ${CMAKE_COMMAND} -E copy_directory ${CMAKE_CURRENT_SOURCE_DIR}/qml ${CMAKE_CURRENT_BINARY_DIR}/qml
    COMMENT "Copying QML")
  add_dependencies(graphicenhancement_qml_ui graphicenhancement_qml_files)
  # Interface translations (设置 → 界面语言): one catalog, compiled in so a package
  # cannot ship without it. scripts/i18n/ builds it from the source strings.
  qt_add_resources(graphicenhancement_qml_ui "graphicenhancement_i18n" PREFIX "/i18n" BASE "${CMAKE_CURRENT_SOURCE_DIR}/i18n" FILES i18n/catalog.json)
  set(GRAPHICENHANCEMENT_VB_CABLE_PACKAGE "" CACHE FILEPATH "Original VB-Audio Pack46 ZIP to include for optional offline installation")
  if(GRAPHICENHANCEMENT_VB_CABLE_PACKAGE)
    file(SHA256 "${GRAPHICENHANCEMENT_VB_CABLE_PACKAGE}" graphicenhancement_vb_cable_sha256)
    if(NOT graphicenhancement_vb_cable_sha256 STREQUAL "bc44e8974191a5a2427d6c979e2dab08dbb09925f3f435dfa2f0ba3e45b6eb90")
      message(FATAL_ERROR "GRAPHICENHANCEMENT_VB_CABLE_PACKAGE must be the original VB-Audio Pack46 ZIP")
    endif()
    set_source_files_properties("${GRAPHICENHANCEMENT_VB_CABLE_PACKAGE}" PROPERTIES QT_RESOURCE_ALIAS "VBCABLE_Driver_Pack46.zip")
    qt_add_resources(graphicenhancement_qml_ui "graphicenhancement_optional_vb_cable" PREFIX "/optional-drivers"
      FILES "${GRAPHICENHANCEMENT_VB_CABLE_PACKAGE}" OPTIONS -no-compress)
  endif()
  target_compile_features(graphicenhancement_qml_ui PRIVATE cxx_std_20)
  # Every thread without an explicit size (UI, engine, export worker) reserves the
  # image default. The 32-node EffectChain is 45 KB and the bridge, preset and
  # engine frames hold several (2026-10-18: bridge constructor 400 KB,
  # EngineController::run 385 KB), so 1 MB no longer leaves a safe margin.
  # Reserve only: pages are committed as they are touched.
  target_link_options(graphicenhancement_qml_ui PRIVATE /STACK:8388608)
  # Qt6::CorePrivate only for QUnifiedTimer's slow mode behind --slow-animations.
  target_link_libraries(graphicenhancement_qml_ui PRIVATE graphicenhancement_qml_bridge graphicenhancement_engine graphicenhancement_startup_music Qt6::CorePrivate dbghelp ole32 rstrtmgr)

  add_executable(graphicenhancement_qml_data_tests tests/unit/QmlDataDirectoryTests.cpp src/ui/QmlDataDirectory.cpp)
  add_executable(graphicenhancement_capture_capability_tests tests/unit/CaptureCapabilityTests.cpp)
  add_executable(graphicenhancement_dshow_format_discovery_tests tests/unit/DirectShowFormatDiscoveryTests.cpp)
  target_compile_features(graphicenhancement_dshow_format_discovery_tests PRIVATE cxx_std_20)
  target_compile_definitions(graphicenhancement_dshow_format_discovery_tests PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN)
  target_compile_options(graphicenhancement_dshow_format_discovery_tests PRIVATE /utf-8)
  target_include_directories(graphicenhancement_dshow_format_discovery_tests PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/include)
  target_link_libraries(graphicenhancement_dshow_format_discovery_tests PRIVATE ole32 oleaut32 strmiids uuid)
  target_compile_features(graphicenhancement_capture_capability_tests PRIVATE cxx_std_20)
  target_compile_options(graphicenhancement_capture_capability_tests PRIVATE /utf-8)
  target_include_directories(graphicenhancement_capture_capability_tests PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/include)
  add_executable(graphicenhancement_subtitle_cache_tests tests/integration/SubtitleCacheTests.cpp)
  target_compile_features(graphicenhancement_subtitle_cache_tests PRIVATE cxx_std_20)
  target_compile_options(graphicenhancement_subtitle_cache_tests PRIVATE /utf-8)
  target_link_libraries(graphicenhancement_subtitle_cache_tests PRIVATE graphicenhancement_engine)
  target_compile_features(graphicenhancement_qml_data_tests PRIVATE cxx_std_20)
  target_include_directories(graphicenhancement_qml_data_tests PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/include)
  # The per-build QML disk cache folder (QmlDiskCache.h).
  add_executable(graphicenhancement_qml_cache_tests tests/unit/QmlDiskCacheTests.cpp src/ui/QmlDiskCache.cpp)
  target_compile_features(graphicenhancement_qml_cache_tests PRIVATE cxx_std_20)
  target_compile_options(graphicenhancement_qml_cache_tests PRIVATE /utf-8)
  target_include_directories(graphicenhancement_qml_cache_tests PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/include)
  target_link_libraries(graphicenhancement_qml_cache_tests PRIVATE Qt6::Core)

  # G0.6: Theme easing curves read back through QML against the design's CSS curves.
  # Loads qml/ from the source tree; runs offscreen with the Qt bin directory on PATH.
  add_executable(graphicenhancement_qml_easing_tests tests/qml/QmlEasingTests.cpp)
  target_compile_features(graphicenhancement_qml_easing_tests PRIVATE cxx_std_20)
  target_compile_definitions(graphicenhancement_qml_easing_tests PRIVATE GRAPHICENHANCEMENT_QML_DIR="${CMAKE_CURRENT_SOURCE_DIR}/qml")
  target_link_libraries(graphicenhancement_qml_easing_tests PRIVATE Qt6::Gui Qt6::Qml Qt6::Quick)

  # G1.6: component smoke tests (Qt Quick Test), tests/qml/quick/tst_*.qml.
  find_package(Qt6 COMPONENTS QuickTest)
  if(TARGET Qt6::QuickTest)
    add_executable(graphicenhancement_qml_quick_tests tests/qml/QuickSmokeTests.cpp)
    set_target_properties(graphicenhancement_qml_quick_tests PROPERTIES AUTOMOC ON)
    target_compile_features(graphicenhancement_qml_quick_tests PRIVATE cxx_std_20)
    target_compile_definitions(graphicenhancement_qml_quick_tests PRIVATE
      GRAPHICENHANCEMENT_QML_DIR="${CMAKE_CURRENT_SOURCE_DIR}/qml"
      QUICK_TEST_SOURCE_DIR="${CMAKE_CURRENT_SOURCE_DIR}/tests/qml/quick")
    target_link_libraries(graphicenhancement_qml_quick_tests PRIVATE Qt6::Qml Qt6::Quick Qt6::QuickTest)
  endif()
endif()

# Qt + D3D12 host probe (S3.0): answers whether Qt can host the native video
# swapchain window without costing present latency. Diagnostic only.
if(GRAPHICENHANCEMENT_BUILD_QT_PROBE AND Qt6_FOUND)
  add_executable(graphicenhancement_qt_probe tools/qt_probe/main.cpp)
  target_compile_features(graphicenhancement_qt_probe PRIVATE cxx_std_20)
  target_link_libraries(graphicenhancement_qt_probe PRIVATE graphicenhancement_engine Qt6::Core Qt6::Gui Qt6::Qml Qt6::Quick Qt6::QuickControls2)
endif()

add_executable(graphicenhancement_sr_reconstruction_tests tests/integration/SrReconstructionTests.cpp)
  target_compile_features(graphicenhancement_sr_reconstruction_tests PRIVATE cxx_std_20)
  target_include_directories(graphicenhancement_sr_reconstruction_tests PRIVATE ${FFMPEG_INCLUDE_DIRS})
  target_compile_definitions(graphicenhancement_sr_reconstruction_tests PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN GRAPHICENHANCEMENT_PROJECT_ROOT="${CMAKE_CURRENT_SOURCE_DIR}")
  target_link_libraries(graphicenhancement_sr_reconstruction_tests PRIVATE graphicenhancement_engine)
  target_compile_features(graphicenhancement_depth_response_tests PRIVATE cxx_std_20)
  target_include_directories(graphicenhancement_depth_response_tests PRIVATE ${FFMPEG_INCLUDE_DIRS})
  target_compile_definitions(graphicenhancement_depth_response_tests PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN GRAPHICENHANCEMENT_PROJECT_ROOT="${CMAKE_CURRENT_SOURCE_DIR}")
  target_link_libraries(graphicenhancement_depth_response_tests PRIVATE graphicenhancement_engine)
  add_executable(graphicenhancement_bidirectional_flow_tests tests/integration/BidirectionalFlowTests.cpp)
  target_compile_features(graphicenhancement_bidirectional_flow_tests PRIVATE cxx_std_20)
  target_link_libraries(graphicenhancement_bidirectional_flow_tests PRIVATE graphicenhancement_pipeline graphicenhancement_nvof)
  target_compile_features(graphicenhancement_motion_validation_tests PRIVATE cxx_std_20)
  target_link_libraries(graphicenhancement_motion_validation_tests PRIVATE graphicenhancement_pipeline)
  add_executable(graphicenhancement_repair_shader_tests tests/integration/RepairShaderTests.cpp)
  add_executable(graphicenhancement_nr_temporal_gpu_tests tests/integration/NrTemporalGpuTests.cpp)
  add_executable(graphicenhancement_nr_correction_gpu_tests tests/integration/NrCorrectionGpuTests.cpp)
  target_compile_features(graphicenhancement_nr_correction_gpu_tests PRIVATE cxx_std_20)
  target_compile_options(graphicenhancement_nr_correction_gpu_tests PRIVATE /utf-8)
  target_link_libraries(graphicenhancement_nr_correction_gpu_tests PRIVATE graphicenhancement_pipeline)
  # Stage-4 defect-audit assertions: GPU-free checks on the architecture-spoof
  # scope and the Ampere re-label policy (see docs/NR_FG_OPTIMIZATION_PLAN_2026-09-29.md).
  # Stage-6 anti-flicker tier assertions (GPU-free: enum narrowing, flat/list
  # agreement, validation, chain-node carry).
  add_executable(graphicenhancement_nr_antiflicker_tests tests/integration/NrAntiFlickerTests.cpp)
  target_compile_features(graphicenhancement_nr_antiflicker_tests PRIVATE cxx_std_20)
  target_link_libraries(graphicenhancement_nr_antiflicker_tests PRIVATE graphicenhancement_engine)
  # Stage-5 output-stabiliser acceptance (anti-flicker, default off).
  add_executable(graphicenhancement_nr_hold_gpu_tests tests/integration/NrHoldGpuTests.cpp)
  target_compile_features(graphicenhancement_nr_hold_gpu_tests PRIVATE cxx_std_20)
  target_link_libraries(graphicenhancement_nr_hold_gpu_tests PRIVATE graphicenhancement_pipeline)
  # NR inference reuse: frame selection, Auto controller and settings (GPU-free),
  # and the reuse pass on real D3D12 dispatches.
  add_executable(graphicenhancement_nr_reuse_tests tests/unit/NrReuseTests.cpp)
  target_compile_features(graphicenhancement_nr_reuse_tests PRIVATE cxx_std_20)
  target_link_libraries(graphicenhancement_nr_reuse_tests PRIVATE graphicenhancement_engine)
  add_executable(graphicenhancement_nr_reuse_gpu_tests tests/integration/NrReuseGpuTests.cpp)
  target_compile_features(graphicenhancement_nr_reuse_gpu_tests PRIVATE cxx_std_20)
  target_link_libraries(graphicenhancement_nr_reuse_gpu_tests PRIVATE graphicenhancement_pipeline)
  add_executable(graphicenhancement_nr_runtime_assertion_tests tests/integration/NrRuntimeAssertionTests.cpp)
  target_compile_features(graphicenhancement_nr_runtime_assertion_tests PRIVATE cxx_std_20)
  target_link_libraries(graphicenhancement_nr_runtime_assertion_tests PRIVATE graphicenhancement_pipeline)
  add_executable(graphicenhancement_nr_video_quality_probe tests/integration/NrVideoQualityProbe.cpp)
  target_compile_features(graphicenhancement_nr_video_quality_probe PRIVATE cxx_std_20)
  target_link_libraries(graphicenhancement_nr_video_quality_probe PRIVATE graphicenhancement_engine)
  # NR inference reuse against full inference on a real video (offline readbacks).
  add_executable(graphicenhancement_nr_reuse_quality_probe tests/integration/NrReuseQualityProbe.cpp)
  target_compile_features(graphicenhancement_nr_reuse_quality_probe PRIVATE cxx_std_20)
  target_link_libraries(graphicenhancement_nr_reuse_quality_probe PRIVATE graphicenhancement_engine)
  add_executable(graphicenhancement_nr_dynamic_size_experiment tests/perf/NrDynamicSizeExperiment.cpp)
  target_compile_features(graphicenhancement_nr_dynamic_size_experiment PRIVATE cxx_std_20)
  target_compile_options(graphicenhancement_nr_dynamic_size_experiment PRIVATE /utf-8)
  target_link_libraries(graphicenhancement_nr_dynamic_size_experiment PRIVATE graphicenhancement_ngx)

  add_executable(graphicenhancement_nr_model_preset_experiment tests/perf/NrModelPresetExperiment.cpp)
  target_compile_features(graphicenhancement_nr_model_preset_experiment PRIVATE cxx_std_20)
  target_compile_options(graphicenhancement_nr_model_preset_experiment PRIVATE /utf-8)
  target_link_libraries(graphicenhancement_nr_model_preset_experiment PRIVATE graphicenhancement_ngx)
  add_executable(graphicenhancement_nr_concurrent_create_experiment tests/perf/NrConcurrentCreateExperiment.cpp)
  target_compile_features(graphicenhancement_nr_concurrent_create_experiment PRIVATE cxx_std_20)
  target_compile_options(graphicenhancement_nr_concurrent_create_experiment PRIVATE /utf-8)
  target_link_libraries(graphicenhancement_nr_concurrent_create_experiment PRIVATE graphicenhancement_ngx)
  add_executable(graphicenhancement_nr_rebuild_benchmark tests/perf/NrRebuildBenchmark.cpp)
  target_compile_features(graphicenhancement_nr_rebuild_benchmark PRIVATE cxx_std_20)
  target_compile_options(graphicenhancement_nr_rebuild_benchmark PRIVATE /utf-8)
  target_link_libraries(graphicenhancement_nr_rebuild_benchmark PRIVATE graphicenhancement_engine)
  add_executable(graphicenhancement_nr_static_input_experiment tests/perf/NrStaticInputExperiment.cpp)
  target_compile_features(graphicenhancement_nr_static_input_experiment PRIVATE cxx_std_20)
  target_compile_options(graphicenhancement_nr_static_input_experiment PRIVATE /utf-8)
  target_link_libraries(graphicenhancement_nr_static_input_experiment PRIVATE graphicenhancement_engine bcrypt)
  add_executable(graphicenhancement_duplicate_gpu_experiment tests/perf/DuplicateGpuExperiment.cpp)
  target_compile_features(graphicenhancement_duplicate_gpu_experiment PRIVATE cxx_std_20)
  target_compile_options(graphicenhancement_duplicate_gpu_experiment PRIVATE /utf-8)
  target_link_libraries(graphicenhancement_duplicate_gpu_experiment PRIVATE graphicenhancement_engine d3dcompiler)
  add_executable(graphicenhancement_nr_paused_residual_experiment tests/perf/NrPausedResidualExperiment.cpp)
  target_compile_features(graphicenhancement_nr_paused_residual_experiment PRIVATE cxx_std_20)
  target_compile_options(graphicenhancement_nr_paused_residual_experiment PRIVATE /utf-8)
  target_link_libraries(graphicenhancement_nr_paused_residual_experiment PRIVATE graphicenhancement_engine bcrypt)
  add_executable(graphicenhancement_paused_present_experiment tests/perf/PausedPresentExperiment.cpp)
  target_compile_features(graphicenhancement_paused_present_experiment PRIVATE cxx_std_20)
  target_compile_options(graphicenhancement_paused_present_experiment PRIVATE /utf-8)
  target_link_libraries(graphicenhancement_paused_present_experiment PRIVATE graphicenhancement_engine)
  add_executable(graphicenhancement_nr_gpu_competition_load tests/perf/NrGpuCompetitionLoad.cpp)
  target_compile_features(graphicenhancement_nr_gpu_competition_load PRIVATE cxx_std_20)
  target_compile_options(graphicenhancement_nr_gpu_competition_load PRIVATE /utf-8)
  target_link_libraries(graphicenhancement_nr_gpu_competition_load PRIVATE graphicenhancement_engine)
  add_executable(graphicenhancement_nr_recent_cache_experiment tests/perf/NrRecentCacheExperiment.cpp)
  add_executable(graphicenhancement_nr_prewarm_experiment tests/perf/NrPrewarmExperiment.cpp)
  target_compile_features(graphicenhancement_nr_prewarm_experiment PRIVATE cxx_std_20)
  target_compile_options(graphicenhancement_nr_prewarm_experiment PRIVATE /utf-8)
  target_link_libraries(graphicenhancement_nr_prewarm_experiment PRIVATE graphicenhancement_engine)
  add_executable(graphicenhancement_ngx_compute_queue_experiment tests/perf/NgxComputeQueueExperiment.cpp)
  target_compile_features(graphicenhancement_ngx_compute_queue_experiment PRIVATE cxx_std_20)
  target_compile_options(graphicenhancement_ngx_compute_queue_experiment PRIVATE /utf-8)
  target_link_libraries(graphicenhancement_ngx_compute_queue_experiment PRIVATE graphicenhancement_engine)
  add_executable(graphicenhancement_nr_graph_queue_experiment tests/perf/NrGraphQueueExperiment.cpp)
  target_compile_features(graphicenhancement_nr_graph_queue_experiment PRIVATE cxx_std_20)
  target_compile_options(graphicenhancement_nr_graph_queue_experiment PRIVATE /utf-8)
  target_link_libraries(graphicenhancement_nr_graph_queue_experiment PRIVATE graphicenhancement_engine)
  add_executable(graphicenhancement_nr_mixed_resolution_experiment tests/perf/NrMixedResolutionExperiment.cpp)
  target_compile_features(graphicenhancement_nr_mixed_resolution_experiment PRIVATE cxx_std_20)
  target_compile_options(graphicenhancement_nr_mixed_resolution_experiment PRIVATE /utf-8)
  target_link_libraries(graphicenhancement_nr_mixed_resolution_experiment PRIVATE graphicenhancement_engine)
  add_executable(graphicenhancement_nr_auto_controller_tests tests/perf/AutoNrControllerTests.cpp)
  target_compile_features(graphicenhancement_nr_auto_controller_tests PRIVATE cxx_std_20)
  target_include_directories(graphicenhancement_nr_auto_controller_tests PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/include)
  add_executable(graphicenhancement_nr_auto_pool_experiment tests/perf/NrAutoPoolExperiment.cpp)
  target_compile_features(graphicenhancement_nr_auto_pool_experiment PRIVATE cxx_std_20)
  target_compile_options(graphicenhancement_nr_auto_pool_experiment PRIVATE /utf-8)
  target_link_libraries(graphicenhancement_nr_auto_pool_experiment PRIVATE graphicenhancement_engine)
  add_executable(graphicenhancement_nr_letterbox_experiment tests/perf/NrLetterboxExperiment.cpp)
  target_compile_features(graphicenhancement_nr_letterbox_experiment PRIVATE cxx_std_20)
  target_compile_options(graphicenhancement_nr_letterbox_experiment PRIVATE /utf-8)
  target_link_libraries(graphicenhancement_nr_letterbox_experiment PRIVATE graphicenhancement_engine)
  add_executable(graphicenhancement_nr_queue_migration_experiment tests/perf/NrQueueMigrationExperiment.cpp)
  target_compile_features(graphicenhancement_nr_queue_migration_experiment PRIVATE cxx_std_20)
  target_compile_options(graphicenhancement_nr_queue_migration_experiment PRIVATE /utf-8)
  target_link_libraries(graphicenhancement_nr_queue_migration_experiment PRIVATE graphicenhancement_engine)
  add_executable(graphicenhancement_nr_export_pipeline_experiment tests/perf/NrExportPipelineExperiment.cpp)
  target_compile_features(graphicenhancement_nr_export_pipeline_experiment PRIVATE cxx_std_20)
  target_compile_options(graphicenhancement_nr_export_pipeline_experiment PRIVATE /utf-8)
  target_link_libraries(graphicenhancement_nr_export_pipeline_experiment PRIVATE graphicenhancement_engine)
  target_compile_features(graphicenhancement_nr_recent_cache_experiment PRIVATE cxx_std_20)
  target_compile_options(graphicenhancement_nr_recent_cache_experiment PRIVATE /utf-8)
  target_link_libraries(graphicenhancement_nr_recent_cache_experiment PRIVATE graphicenhancement_engine bcrypt)
  add_executable(graphicenhancement_nr_core_cache_contract_tests tests/perf/NrCoreCacheContractTests.cpp)
  target_compile_features(graphicenhancement_nr_core_cache_contract_tests PRIVATE cxx_std_20)
  target_compile_options(graphicenhancement_nr_core_cache_contract_tests PRIVATE /utf-8)
  target_link_libraries(graphicenhancement_nr_core_cache_contract_tests PRIVATE graphicenhancement_engine)
  target_compile_features(graphicenhancement_nr_temporal_gpu_tests PRIVATE cxx_std_20)
  target_link_libraries(graphicenhancement_nr_temporal_gpu_tests PRIVATE graphicenhancement_pipeline)
  add_executable(graphicenhancement_gpu_timing_tests tests/integration/GpuTimingTests.cpp)
  target_compile_features(graphicenhancement_gpu_timing_tests PRIVATE cxx_std_20)
  target_link_libraries(graphicenhancement_gpu_timing_tests PRIVATE graphicenhancement_pipeline)
  target_compile_features(graphicenhancement_repair_shader_tests PRIVATE cxx_std_20)
  target_link_libraries(graphicenhancement_repair_shader_tests PRIVATE graphicenhancement_pipeline)
  target_include_directories(graphicenhancement_repair_fg_tests PRIVATE ${FFMPEG_INCLUDE_DIRS})
  target_compile_features(graphicenhancement_repair_fg_tests PRIVATE cxx_std_20)
  target_compile_definitions(graphicenhancement_repair_fg_tests PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN GRAPHICENHANCEMENT_PROJECT_ROOT="${CMAKE_CURRENT_SOURCE_DIR}")
  target_link_libraries(graphicenhancement_repair_fg_tests PRIVATE graphicenhancement_pipeline graphicenhancement_sinks graphicenhancement_nvof)

  # Headless quality-core runner (Playbook R3.3): the phase5 gate's quality
  add_library(graphicenhancement_engine STATIC src/engine/EngineController.cpp src/engine/EngineWatchdog.cpp src/engine/PreviewGpuSession.cpp src/engine/CaptureGraphPreparation.cpp src/engine/EngineControllerImage.cpp src/engine/PosterFrame.cpp src/engine/EffectChain.cpp src/engine/PresetLibrary.cpp src/ui/PlayerUiFacade.cpp src/engine/TiledImageProcessor.cpp src/engine/PresetStore.cpp src/engine/VideoPresenter.cpp src/engine/DisplayStateService.cpp src/engine/VideoExportJob.cpp src/engine/ExportStreams.cpp src/engine/ExportQueue.cpp src/engine/ExportJobManager.cpp src/engine/Subtitles.cpp src/engine/FgCompatibilityProbe.cpp src/engine/LiveRecorder.cpp src/engine/ReplayBuffer.cpp src/engine/MicrophoneCapture.cpp)
  target_sources(graphicenhancement_pipeline PRIVATE src/guidance/AmdOpticalFlow.cpp
    src/guidance/GpuDisOpticalFlow.cpp third_party/gpu-dis/src/gpu/native_strict_dis_provider.cpp)
  target_include_directories(graphicenhancement_pipeline PRIVATE third_party/gpu-dis/src/gpu)
  include(cmake/GraphicEnhancementGpuDis.cmake)
  graphicenhancement_add_compute_shader(graphicenhancement_shader_gpu_dis_luma GpuDisLuma)
  graphicenhancement_add_compute_shader(graphicenhancement_shader_gpu_dis_validate GpuDisValidate)
  add_dependencies(graphicenhancement_pipeline graphicenhancement_shader_gpu_dis graphicenhancement_shader_gpu_dis_luma graphicenhancement_shader_gpu_dis_validate)
  if(EXISTS "${GRAPHICENHANCEMENT_FIDELITYFX_ROOT}/bin/ffx_sdk/ffx_opticalflow_x64.lib")
    target_compile_definitions(graphicenhancement_pipeline PRIVATE GRAPHICENHANCEMENT_HAS_AMD_OF=1)
    target_include_directories(graphicenhancement_pipeline PRIVATE "${GRAPHICENHANCEMENT_FIDELITYFX_ROOT}/include")
    target_link_libraries(graphicenhancement_pipeline PRIVATE
      "${GRAPHICENHANCEMENT_FIDELITYFX_ROOT}/bin/ffx_sdk/ffx_opticalflow_x64.lib"
      "${GRAPHICENHANCEMENT_FIDELITYFX_ROOT}/bin/ffx_sdk/ffx_backend_dx12_x64.lib")
  endif()
  target_compile_features(graphicenhancement_engine PUBLIC cxx_std_20)
  target_sources(graphicenhancement_engine PRIVATE src/engine/VirtualCamera.cpp src/virtualcam/CameraRegistration.cpp)
  target_link_libraries(graphicenhancement_engine PUBLIC graphicenhancement_virtualcam_transport advapi32)
  # On-screen text for live translation: OCR reading logic (portable, ported from
  # VI Translator, MIT) and the Windows OCR reader of the presented picture.
  target_sources(graphicenhancement_engine PRIVATE src/engine/ScreenText.cpp src/engine/ScreenTextCapture.cpp)
  target_link_libraries(graphicenhancement_engine PRIVATE windowsapp)
  add_dependencies(graphicenhancement_engine graphicenhancement_shader_virtual_camera_nv12)
  target_compile_options(graphicenhancement_engine PRIVATE /utf-8)
  target_compile_definitions(graphicenhancement_engine PUBLIC GRAPHICENHANCEMENT_PROJECT_ROOT="${CMAKE_CURRENT_SOURCE_DIR}" GRAPHICENHANCEMENT_SHADER_DIR="${CMAKE_BINARY_DIR}/shaders")
  target_link_libraries(graphicenhancement_engine PUBLIC graphicenhancement_pipeline graphicenhancement_sources graphicenhancement_sinks graphicenhancement_ngx graphicenhancement_nvof)
  add_executable(graphicenhancement_vfg_export_probe tests/integration/VfgExportProbe.cpp)
  target_compile_features(graphicenhancement_vfg_export_probe PRIVATE cxx_std_20)
  target_compile_options(graphicenhancement_vfg_export_probe PRIVATE /utf-8)
  target_link_libraries(graphicenhancement_vfg_export_probe PRIVATE graphicenhancement_engine)
  add_executable(graphicenhancement_video_ai_export_probe tests/integration/VideoAiExportProbe.cpp)
  target_compile_features(graphicenhancement_video_ai_export_probe PRIVATE cxx_std_20)
  target_compile_options(graphicenhancement_video_ai_export_probe PRIVATE /utf-8)
  target_link_libraries(graphicenhancement_video_ai_export_probe PRIVATE graphicenhancement_engine)
  add_executable(graphicenhancement_preset_library_tests tests/unit/PresetLibraryTests.cpp src/engine/PresetLibrary.cpp src/engine/EffectChain.cpp)
target_link_options(graphicenhancement_preset_library_tests PRIVATE /STACK:33554432) # Preset apply recurses over 21 KB ChainConfiguration frames; the default 1 MB stack is too close to the edge.
add_executable(graphicenhancement_hdr_tuning_tests tests/unit/HdrOutputTuningTests.cpp src/engine/PresetLibrary.cpp src/engine/EffectChain.cpp)
target_compile_features(graphicenhancement_hdr_tuning_tests PRIVATE cxx_std_20)
target_include_directories(graphicenhancement_hdr_tuning_tests PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/include)
# graphicenhancement_base carries /utf-8 and NOMINMAX (PresetLibrary.cpp has Chinese literals and uses std::max).
target_link_libraries(graphicenhancement_hdr_tuning_tests PRIVATE graphicenhancement_base)
target_link_options(graphicenhancement_hdr_tuning_tests PRIVATE /STACK:33554432)
  target_compile_features(graphicenhancement_preset_library_tests PRIVATE cxx_std_20)
  target_include_directories(graphicenhancement_preset_library_tests PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/include)
  target_link_libraries(graphicenhancement_preset_library_tests PRIVATE graphicenhancement_base)
  add_executable(graphicenhancement_anr_settings_tests tests/unit/AnrSettingsTests.cpp src/engine/PresetLibrary.cpp src/engine/PresetStore.cpp src/engine/EffectChain.cpp)
  target_compile_features(graphicenhancement_anr_settings_tests PRIVATE cxx_std_20)
  target_link_libraries(graphicenhancement_anr_settings_tests PRIVATE graphicenhancement_base)
  target_compile_options(graphicenhancement_anr_settings_tests PRIVATE /utf-8)
  target_compile_definitions(graphicenhancement_anr_settings_tests PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN)
  add_executable(graphicenhancement_vfg_settings_tests tests/unit/VfgSettingsTests.cpp src/engine/PresetLibrary.cpp src/engine/PresetStore.cpp src/engine/EffectChain.cpp)
  target_compile_features(graphicenhancement_vfg_settings_tests PRIVATE cxx_std_20)
  target_compile_options(graphicenhancement_vfg_settings_tests PRIVATE /utf-8)
  target_compile_definitions(graphicenhancement_vfg_settings_tests PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN)
  target_include_directories(graphicenhancement_vfg_settings_tests PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/include)
  target_link_libraries(graphicenhancement_vfg_settings_tests PRIVATE graphicenhancement_base)
  add_executable(graphicenhancement_video_ai_settings_tests tests/unit/VideoAiSettingsTests.cpp src/engine/PresetLibrary.cpp src/engine/PresetStore.cpp src/engine/EffectChain.cpp)
  target_compile_features(graphicenhancement_video_ai_settings_tests PRIVATE cxx_std_20)
  target_compile_options(graphicenhancement_video_ai_settings_tests PRIVATE /utf-8)
  target_compile_definitions(graphicenhancement_video_ai_settings_tests PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN)
  target_include_directories(graphicenhancement_video_ai_settings_tests PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/include)
  target_link_libraries(graphicenhancement_video_ai_settings_tests PRIVATE graphicenhancement_base)
  target_link_options(graphicenhancement_video_ai_settings_tests PRIVATE /STACK:33554432)
  add_executable(graphicenhancement_effect_availability_tests tests/unit/EffectAvailabilityTests.cpp)
  target_compile_features(graphicenhancement_effect_availability_tests PRIVATE cxx_std_20)
  target_include_directories(graphicenhancement_effect_availability_tests PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/include)

  add_executable(graphicenhancement_effect_chain_tests tests/unit/EffectChainTests.cpp src/engine/EffectChain.cpp)
  target_compile_features(graphicenhancement_effect_chain_tests PRIVATE cxx_std_20)
  target_include_directories(graphicenhancement_effect_chain_tests PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/include)
  target_link_libraries(graphicenhancement_effect_chain_tests PRIVATE graphicenhancement_base)
  # Large independent settings/descriptor fixtures, like the preset contracts.
  target_link_options(graphicenhancement_effect_chain_tests PRIVATE /STACK:33554432)
  add_executable(graphicenhancement_nr_export_size_tests tests/integration/NrExportSizeTests.cpp)
  target_compile_features(graphicenhancement_nr_export_size_tests PRIVATE cxx_std_20)
  target_compile_options(graphicenhancement_nr_export_size_tests PRIVATE /utf-8)
  target_compile_definitions(graphicenhancement_nr_export_size_tests PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN UNICODE _UNICODE)
  target_link_options(graphicenhancement_nr_export_size_tests PRIVATE /STACK:33554432)
  target_link_libraries(graphicenhancement_nr_export_size_tests PRIVATE graphicenhancement_engine)

  add_executable(graphicenhancement_repair_preset_tests tests/unit/RepairPresetTests.cpp src/engine/PresetStore.cpp)
  # CPU bake of the colour grade: no GPU, no engine link - the tables the ingest
  # shader reads are pure maths and must be verifiable without a device.
  add_executable(graphicenhancement_color_grade_tests tests/unit/ColorGradeTableTests.cpp)
  target_compile_features(graphicenhancement_color_grade_tests PRIVATE cxx_std_20)
  target_compile_options(graphicenhancement_color_grade_tests PRIVATE /utf-8)
  target_compile_definitions(graphicenhancement_color_grade_tests PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN)
  target_include_directories(graphicenhancement_color_grade_tests PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/include)
  target_link_libraries(graphicenhancement_color_grade_tests PRIVATE graphicenhancement_pipeline)
  # GPU contract for the v4 colour chain: identity when off/neutral, exposure,
  # curve, saturation and hue, all through a real graph and its ingest pass.
  add_executable(graphicenhancement_color_grade_gpu_tests tests/integration/ColorGradeGpuTests.cpp src/engine/EffectChain.cpp)
  target_compile_features(graphicenhancement_color_grade_gpu_tests PRIVATE cxx_std_20)
  target_compile_options(graphicenhancement_color_grade_gpu_tests PRIVATE /utf-8 /WX-)
  target_compile_definitions(graphicenhancement_color_grade_gpu_tests PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN)
  target_include_directories(graphicenhancement_color_grade_gpu_tests PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/include ${FFMPEG_INCLUDE_DIRS})
  target_link_libraries(graphicenhancement_color_grade_gpu_tests PRIVATE graphicenhancement_pipeline graphicenhancement_sinks)
  # Byte-exact regression for the effect insertion slots (colour today, more
  # effects later): one frame per configuration through the real graph, printed
  # as SHA-256 so a build from before a change can be compared with one after it.
  add_executable(graphicenhancement_effect_slot_regression_tests tests/integration/EffectSlotRegressionTests.cpp)
  # GPU quality / HDR / temporal / slot / tiled / timing checks of the anti-aliasing effect (#53).
  add_executable(graphicenhancement_anti_alias_gpu_tests tests/integration/AntiAliasGpuTests.cpp)
  target_compile_features(graphicenhancement_anti_alias_gpu_tests PRIVATE cxx_std_20)
  target_compile_options(graphicenhancement_anti_alias_gpu_tests PRIVATE /utf-8)
  target_compile_definitions(graphicenhancement_anti_alias_gpu_tests PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN)
  target_link_libraries(graphicenhancement_anti_alias_gpu_tests PRIVATE graphicenhancement_engine)
  # Beauty node: face detector, passes and their tests.
  include(cmake/GraphicEnhancementBeauty.cmake)
  target_compile_features(graphicenhancement_effect_slot_regression_tests PRIVATE cxx_std_20)
  target_compile_options(graphicenhancement_effect_slot_regression_tests PRIVATE /utf-8)
  target_compile_definitions(graphicenhancement_effect_slot_regression_tests PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN)
  target_link_libraries(graphicenhancement_effect_slot_regression_tests PRIVATE graphicenhancement_engine)
  # Adobe .cube parsing + the runtime LUT store (CPU only).
  add_executable(graphicenhancement_color_lut_tests tests/unit/ColorLutTests.cpp src/engine/ColorLut.cpp)
  target_compile_features(graphicenhancement_color_lut_tests PRIVATE cxx_std_20)
  target_compile_options(graphicenhancement_color_lut_tests PRIVATE /utf-8)
  target_compile_definitions(graphicenhancement_color_lut_tests PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN)
  target_include_directories(graphicenhancement_color_lut_tests PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/include)
  target_link_libraries(graphicenhancement_color_lut_tests PRIVATE graphicenhancement_base bcrypt)
  # Named colour looks + .vpcolor export/import (CPU only).
  add_executable(graphicenhancement_color_look_tests tests/unit/ColorLookTests.cpp src/engine/ColorLookStore.cpp)
  target_compile_features(graphicenhancement_color_look_tests PRIVATE cxx_std_20)
  target_compile_options(graphicenhancement_color_look_tests PRIVATE /utf-8)
  target_compile_definitions(graphicenhancement_color_look_tests PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN)
  target_include_directories(graphicenhancement_color_look_tests PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/include)
  target_link_libraries(graphicenhancement_color_look_tests PRIVATE graphicenhancement_base)
  target_compile_features(graphicenhancement_repair_preset_tests PRIVATE cxx_std_20)
  target_compile_options(graphicenhancement_repair_preset_tests PRIVATE /utf-8)
  target_compile_definitions(graphicenhancement_repair_preset_tests PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN)
  target_include_directories(graphicenhancement_repair_preset_tests PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/include)
  add_executable(graphicenhancement_replay_buffer_tests tests/unit/ReplayBufferTests.cpp src/engine/ReplayBuffer.cpp src/sink/RecordingAudioTap.cpp)
  add_executable(graphicenhancement_virtualcam_gpu_tests tests/integration/VirtualCameraGpuTests.cpp)
  target_compile_features(graphicenhancement_virtualcam_gpu_tests PRIVATE cxx_std_20)
  target_compile_options(graphicenhancement_virtualcam_gpu_tests PRIVATE /utf-8)
  target_compile_definitions(graphicenhancement_virtualcam_gpu_tests PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN)
  target_link_libraries(graphicenhancement_virtualcam_gpu_tests PRIVATE graphicenhancement_engine)
  target_compile_features(graphicenhancement_replay_buffer_tests PRIVATE cxx_std_20)
  target_compile_options(graphicenhancement_replay_buffer_tests PRIVATE /utf-8)
  target_compile_definitions(graphicenhancement_replay_buffer_tests PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN)
  target_include_directories(graphicenhancement_replay_buffer_tests PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/include)
  add_executable(graphicenhancement_ui_contract_tests tests/unit/UiContractTests.cpp src/engine/PresetStore.cpp)
  target_compile_features(graphicenhancement_ui_contract_tests PRIVATE cxx_std_20)
  target_compile_options(graphicenhancement_ui_contract_tests PRIVATE /utf-8)
  target_compile_definitions(graphicenhancement_ui_contract_tests PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN)
  target_include_directories(graphicenhancement_ui_contract_tests PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/include)
  add_executable(graphicenhancement_popup_selector_tests tests/integration/PopupSelectorTests.cpp)
  add_executable(graphicenhancement_subtitle_panel_tests tests/integration/SubtitlePanelTests.cpp)
  add_executable(graphicenhancement_subtitle_overlay_tests tests/integration/SubtitleOverlayTests.cpp)
  target_compile_features(graphicenhancement_subtitle_overlay_tests PRIVATE cxx_std_20)
  target_compile_options(graphicenhancement_subtitle_overlay_tests PRIVATE /utf-8)
  target_compile_definitions(graphicenhancement_subtitle_overlay_tests PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN UNICODE _UNICODE)
  target_link_libraries(graphicenhancement_subtitle_overlay_tests PRIVATE graphicenhancement_engine gdiplus comctl32)
  target_compile_features(graphicenhancement_subtitle_panel_tests PRIVATE cxx_std_20)
  target_compile_options(graphicenhancement_subtitle_panel_tests PRIVATE /utf-8)
  target_compile_definitions(graphicenhancement_subtitle_panel_tests PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN UNICODE _UNICODE)
  target_link_libraries(graphicenhancement_subtitle_panel_tests PRIVATE graphicenhancement_base comctl32)
  target_compile_features(graphicenhancement_popup_selector_tests PRIVATE cxx_std_20)
  target_compile_options(graphicenhancement_popup_selector_tests PRIVATE /utf-8)
  target_compile_definitions(graphicenhancement_popup_selector_tests PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN UNICODE _UNICODE)
  target_link_libraries(graphicenhancement_popup_selector_tests PRIVATE graphicenhancement_base comctl32)
  add_dependencies(graphicenhancement_engine graphicenhancement_shader_hdr_video_sr graphicenhancement_shader_present_motion graphicenhancement_shader_present_blit graphicenhancement_shader_hdr_coverage graphicenhancement_shader_fullscreen_frame_stats)
  add_executable(graphicenhancement_hdr_color_tests tests/integration/HdrColorTests.cpp)
  add_executable(graphicenhancement_hdr_output_tuning_gpu_tests tests/integration/HdrOutputTuningGpuTests.cpp)
  target_compile_features(graphicenhancement_hdr_output_tuning_gpu_tests PRIVATE cxx_std_20)
  target_compile_definitions(graphicenhancement_hdr_output_tuning_gpu_tests PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN)
  target_link_libraries(graphicenhancement_hdr_output_tuning_gpu_tests PRIVATE graphicenhancement_engine)
  add_executable(graphicenhancement_cpu_yuv_upload_tests tests/integration/CpuYuvUploadTests.cpp)
  target_compile_features(graphicenhancement_cpu_yuv_upload_tests PRIVATE cxx_std_20)
  target_compile_definitions(graphicenhancement_cpu_yuv_upload_tests PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN)
  target_link_libraries(graphicenhancement_cpu_yuv_upload_tests PRIVATE graphicenhancement_engine)
  add_executable(graphicenhancement_multichannel_tests tests/integration/MultichannelTests.cpp)
  target_compile_features(graphicenhancement_multichannel_tests PRIVATE cxx_std_20)
  target_compile_definitions(graphicenhancement_multichannel_tests PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN)
  target_link_libraries(graphicenhancement_multichannel_tests PRIVATE graphicenhancement_engine)
  add_executable(graphicenhancement_hdr_enhancement_tests tests/integration/HdrEnhancementTests.cpp)
  add_executable(graphicenhancement_video_hdr_tests tests/integration/VideoHdrTests.cpp)
  target_compile_features(graphicenhancement_video_hdr_tests PRIVATE cxx_std_20)
  target_compile_definitions(graphicenhancement_video_hdr_tests PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN)
  target_link_libraries(graphicenhancement_video_hdr_tests PRIVATE graphicenhancement_engine)
  target_compile_features(graphicenhancement_hdr_enhancement_tests PRIVATE cxx_std_20)
  target_compile_definitions(graphicenhancement_hdr_enhancement_tests PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN)
  target_link_libraries(graphicenhancement_hdr_enhancement_tests PRIVATE graphicenhancement_engine)
  add_executable(graphicenhancement_source_fidelity_tests tests/integration/SourceFidelityTests.cpp)
  add_executable(graphicenhancement_file_safety_tests tests/integration/FileSafetyTests.cpp)
  target_compile_features(graphicenhancement_file_safety_tests PRIVATE cxx_std_20)
  target_compile_options(graphicenhancement_file_safety_tests PRIVATE /utf-8)
  target_compile_definitions(graphicenhancement_file_safety_tests PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN)
  target_link_libraries(graphicenhancement_file_safety_tests PRIVATE graphicenhancement_engine)
  target_compile_features(graphicenhancement_source_fidelity_tests PRIVATE cxx_std_20)
  target_compile_definitions(graphicenhancement_source_fidelity_tests PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN)
  target_link_libraries(graphicenhancement_source_fidelity_tests PRIVATE graphicenhancement_engine)
  add_executable(graphicenhancement_hw_import_image_tests tests/integration/HardwareImportImageTests.cpp)
  target_compile_features(graphicenhancement_hw_import_image_tests PRIVATE cxx_std_20)
  target_compile_definitions(graphicenhancement_hw_import_image_tests PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN)
  target_link_libraries(graphicenhancement_hw_import_image_tests PRIVATE graphicenhancement_engine)
  # Headless export harness: verifies the frame-timestamp policy (tail snap,
  # dropped-sample gap fill, hard refusal) without the GUI.
  add_executable(graphicenhancement_export_probe tools/export_probe/main.cpp)
  target_compile_features(graphicenhancement_export_probe PRIVATE cxx_std_20)
  target_compile_definitions(graphicenhancement_export_probe PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN)
  target_link_libraries(graphicenhancement_export_probe PRIVATE graphicenhancement_engine)
  target_compile_features(graphicenhancement_hdr_color_tests PRIVATE cxx_std_20)
  target_compile_definitions(graphicenhancement_hdr_color_tests PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN)
  target_link_libraries(graphicenhancement_hdr_color_tests PRIVATE graphicenhancement_engine)
  if(GRAPHICENHANCEMENT_ENABLE_REMOTEPLAY)
    add_executable(graphicenhancement_ps5_hw_image_tests tests/integration/Ps5HardwareImageTests.cpp)
    add_executable(graphicenhancement_ps5_quality_tests tests/integration/Ps5SourceQualityTests.cpp)
    target_compile_features(graphicenhancement_ps5_quality_tests PRIVATE cxx_std_20)
    target_compile_definitions(graphicenhancement_ps5_quality_tests PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN)
    target_link_libraries(graphicenhancement_ps5_quality_tests PRIVATE graphicenhancement_engine)
    target_compile_features(graphicenhancement_ps5_hw_image_tests PRIVATE cxx_std_20)
    target_compile_definitions(graphicenhancement_ps5_hw_image_tests PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN)
    target_link_libraries(graphicenhancement_ps5_hw_image_tests PRIVATE graphicenhancement_engine)
    find_package(SDL3 3.4.14 EXACT CONFIG REQUIRED)
    # P4-e: the QML front end forwards the PC controller to the PS5 the same way.
    # Only the SDL library file and headers: SDL3::SDL3's own system-library list
    # pushed the graphicenhancement_qml_ui link line over CMake's response-file threshold, and
    # link.exe reads response files in the ANSI code page, which breaks the UTF-8
    # Qt paths under E:/项目. Those system libraries come from #pragma comment in
    # the private QmlPlayerBridge_p.h instead.
    if(TARGET graphicenhancement_qml_bridge)
      target_sources(graphicenhancement_qml_bridge PRIVATE src/remoteplay/ControllerInput.cpp)
      target_link_libraries(graphicenhancement_qml_bridge PUBLIC $<TARGET_LINKER_FILE:SDL3::SDL3-static>)
      target_link_libraries(graphicenhancement_qml_bridge PRIVATE SDL3::Headers)
    endif()
    add_executable(graphicenhancement_remoteplay_source_tests tests/remoteplay/SourceTests.cpp)
    target_compile_features(graphicenhancement_remoteplay_source_tests PRIVATE cxx_std_20)
    target_compile_options(graphicenhancement_remoteplay_source_tests PRIVATE /utf-8)
    target_compile_definitions(graphicenhancement_remoteplay_source_tests PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN)
    target_include_directories(graphicenhancement_remoteplay_source_tests PRIVATE ${FFMPEG_INCLUDE_DIRS})
    target_link_libraries(graphicenhancement_remoteplay_source_tests PRIVATE graphicenhancement_sources graphicenhancement_gfx ${FFMPEG_LIBRARIES})
    add_executable(graphicenhancement_remoteplay_boundary_tests tests/remoteplay/ProductBoundaryTests.cpp src/remoteplay/ControllerInput.cpp)
    target_compile_features(graphicenhancement_remoteplay_boundary_tests PRIVATE cxx_std_20)
    target_link_libraries(graphicenhancement_remoteplay_boundary_tests PRIVATE graphicenhancement_sources SDL3::SDL3)
    add_executable(graphicenhancement_remoteplay_trigger_filter_tests tests/remoteplay/TriggerFilterTests.cpp)
    target_compile_features(graphicenhancement_remoteplay_trigger_filter_tests PRIVATE cxx_std_20)
    target_include_directories(graphicenhancement_remoteplay_trigger_filter_tests PRIVATE include)
    add_executable(graphicenhancement_remoteplay_profile_tests tests/remoteplay/ProfileStoreTests.cpp)
    target_compile_features(graphicenhancement_remoteplay_profile_tests PRIVATE cxx_std_20)
    target_compile_definitions(graphicenhancement_remoteplay_profile_tests PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN)
    target_link_libraries(graphicenhancement_remoteplay_profile_tests PRIVATE graphicenhancement_remoteplay_chiaki)
  endif()

  # matrix executes through the shared product libraries only.
  add_executable(graphicenhancement_quality_probe
    tools/quality_probe/main.cpp
    tools/nr_harness/harness_util.cpp
  )
  graphicenhancement_apply_warnings(graphicenhancement_quality_probe)
  target_compile_options(graphicenhancement_quality_probe PRIVATE /WX-)
  target_compile_features(graphicenhancement_quality_probe PRIVATE cxx_std_20)
  target_compile_definitions(graphicenhancement_quality_probe PRIVATE
    UNICODE _UNICODE WIN32_LEAN_AND_MEAN NOMINMAX
    GRAPHICENHANCEMENT_SHADER_DIR="${CMAKE_BINARY_DIR}/shaders")
  target_include_directories(graphicenhancement_quality_probe PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/include)
  target_link_libraries(graphicenhancement_quality_probe PRIVATE
    graphicenhancement_pipeline graphicenhancement_sources graphicenhancement_media graphicenhancement_ngx graphicenhancement_nvof graphicenhancement_sinks
    ${FFMPEG_LIBRARIES} psapi dxgi shell32)
  add_dependencies(graphicenhancement_quality_probe
    graphicenhancement_shader_yuv_to_rgb graphicenhancement_shader_parity_encode
    graphicenhancement_shader_parity_decode graphicenhancement_shader_scale_blit
    graphicenhancement_shader_nv12_upload graphicenhancement_shader_nvof_densify)

  # UI migration guard: per-frame output hashes for fixed stage configurations.
  add_executable(graphicenhancement_chain_hash_probe tools/chain_hash_probe/main.cpp)
  target_compile_features(graphicenhancement_chain_hash_probe PRIVATE cxx_std_20)
  target_compile_options(graphicenhancement_chain_hash_probe PRIVATE /WX-)
  target_compile_definitions(graphicenhancement_chain_hash_probe PRIVATE UNICODE _UNICODE WIN32_LEAN_AND_MEAN NOMINMAX)
  target_include_directories(graphicenhancement_chain_hash_probe PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/include)
  target_link_libraries(graphicenhancement_chain_hash_probe PRIVATE
    graphicenhancement_pipeline graphicenhancement_sources graphicenhancement_media graphicenhancement_ngx graphicenhancement_nvof graphicenhancement_sinks
    ${FFMPEG_LIBRARIES} dxgi shell32)
  add_dependencies(graphicenhancement_chain_hash_probe graphicenhancement_quality_probe)

  # Headless Remote Play probe: drives the product session stack with a saved
  # profile so codec/bitrate variants can be compared without the GUI.
  if(GRAPHICENHANCEMENT_ENABLE_REMOTEPLAY)
    add_executable(graphicenhancement_remoteplay_probe tools/remoteplay_probe/main.cpp)
    target_compile_features(graphicenhancement_remoteplay_probe PRIVATE cxx_std_20)
    target_compile_options(graphicenhancement_remoteplay_probe PRIVATE /WX-)
    target_compile_definitions(graphicenhancement_remoteplay_probe PRIVATE UNICODE _UNICODE WIN32_LEAN_AND_MEAN NOMINMAX)
    target_include_directories(graphicenhancement_remoteplay_probe PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/include)
    target_link_libraries(graphicenhancement_remoteplay_probe PRIVATE graphicenhancement_sources graphicenhancement_gfx ${FFMPEG_LIBRARIES})
  endif()

  # Phase 6 realtime engine probe: decode -> SR -> NR -> NVOF -> DLSSG -> present.
  if(GRAPHICENHANCEMENT_ENABLE_EXPERIMENTAL_DLSSNR AND EXISTS "${GRAPHICENHANCEMENT_NVOF_SDK_ROOT}/NvOFInterface/nvOpticalFlowCommon.h")
    add_executable(graphicenhancement_player_probe
      tools/player_probe/main.cpp
      tools/nr_harness/harness_util.cpp
    )
    graphicenhancement_apply_warnings(graphicenhancement_player_probe)
    target_compile_options(graphicenhancement_player_probe PRIVATE /WX-)
    target_compile_features(graphicenhancement_player_probe PRIVATE cxx_std_20)
    target_compile_definitions(graphicenhancement_player_probe PRIVATE
      UNICODE _UNICODE WIN32_LEAN_AND_MEAN NOMINMAX
      GRAPHICENHANCEMENT_SHADER_DIR="${CMAKE_BINARY_DIR}/shaders")
    target_link_libraries(graphicenhancement_player_probe PRIVATE
      graphicenhancement_media graphicenhancement_gfx graphicenhancement_ngx graphicenhancement_nvof graphicenhancement_parity graphicenhancement_sinks graphicenhancement_pipeline
      ${FFMPEG_LIBRARIES} psapi ole32 mmdevapi avrt)
    add_dependencies(graphicenhancement_player_probe
      graphicenhancement_shader_yuv_to_rgb graphicenhancement_shader_parity_encode
      graphicenhancement_shader_parity_decode graphicenhancement_shader_scale_blit graphicenhancement_shader_nv12_upload
      graphicenhancement_shader_present_blit graphicenhancement_shader_nvof_densify)
  endif()
endif()

# Clip generator: links the openh264-enabled toolchain FFmpeg ONLY.
if(GRAPHICENHANCEMENT_CLIP_TOOLS_ROOT AND EXISTS "${GRAPHICENHANCEMENT_CLIP_TOOLS_ROOT}/include/libavcodec/avcodec.h")
  add_executable(graphicenhancement_clip_gen tools/clip_generator/main.cpp)
  graphicenhancement_apply_warnings(graphicenhancement_clip_gen)
  target_compile_options(graphicenhancement_clip_gen PRIVATE /WX-)
  target_compile_features(graphicenhancement_clip_gen PRIVATE cxx_std_20)
  target_compile_definitions(graphicenhancement_clip_gen PRIVATE
    UNICODE _UNICODE WIN32_LEAN_AND_MEAN NOMINMAX)
  target_include_directories(graphicenhancement_clip_gen PRIVATE "${GRAPHICENHANCEMENT_CLIP_TOOLS_ROOT}/include")
  target_link_directories(graphicenhancement_clip_gen PRIVATE "${GRAPHICENHANCEMENT_CLIP_TOOLS_ROOT}/lib")
  target_link_libraries(graphicenhancement_clip_gen PRIVATE
    graphicenhancement_base
    "${GRAPHICENHANCEMENT_CLIP_TOOLS_ROOT}/lib/avcodec.lib"
    "${GRAPHICENHANCEMENT_CLIP_TOOLS_ROOT}/lib/avformat.lib"
    "${GRAPHICENHANCEMENT_CLIP_TOOLS_ROOT}/lib/avutil.lib")
endif()

# Layered child subtitle windows require a modern-Windows compatibility manifest.
if(TARGET graphicenhancement_qml_ui)
  set(GRAPHICENHANCEMENT_RESOURCE_FILENAME "graphicenhancement_qml_ui.exe")
  configure_file(apps/graphicenhancement/version.rc.in ${CMAKE_CURRENT_BINARY_DIR}/graphicenhancement-qml-version.rc @ONLY)
  target_sources(graphicenhancement_qml_ui PRIVATE ${CMAKE_CURRENT_BINARY_DIR}/graphicenhancement-qml-version.rc)
  set(GRAPHICENHANCEMENT_RESOURCE_FILENAME "GraphicEnhancement.exe")
  configure_file(apps/graphicenhancement/version.rc.in ${CMAKE_CURRENT_BINARY_DIR}/graphicenhancement-portable-version.rc @ONLY)
  target_sources(graphicenhancement_portable_launcher PRIVATE ${CMAKE_CURRENT_BINARY_DIR}/graphicenhancement-portable-version.rc)
  set(GRAPHICENHANCEMENT_RESOURCE_FILENAME "graphicenhancement_update_worker.exe")
  configure_file(apps/graphicenhancement/version.rc.in ${CMAKE_CURRENT_BINARY_DIR}/graphicenhancement-updater-version.rc @ONLY)
  target_sources(graphicenhancement_update_worker PRIVATE ${CMAKE_CURRENT_BINARY_DIR}/graphicenhancement-updater-version.rc)
endif()
configure_file(apps/graphicenhancement/resource.h ${CMAKE_CURRENT_BINARY_DIR}/graphicenhancement-resource.h COPYONLY)
configure_file(assets/graphicenhancement.ico ${CMAKE_CURRENT_BINARY_DIR}/graphicenhancement.ico COPYONLY)
if(TARGET graphicenhancement_qml_ui)
  set_source_files_properties(${CMAKE_CURRENT_BINARY_DIR}/graphicenhancement-qml-version.rc PROPERTIES
    OBJECT_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/assets/graphicenhancement.ico;${CMAKE_CURRENT_SOURCE_DIR}/apps/graphicenhancement/resource.h")
endif()
# P4-c: the QML front end hosts the same layered child subtitle window.
if(TARGET graphicenhancement_qml_ui)
  # Copied next to the link step and named relatively: a short link line keeps
  # link.exe off the (ANSI-decoded) response file.
  configure_file(apps/graphicenhancement/graphicenhancement.manifest ${CMAKE_CURRENT_BINARY_DIR}/graphicenhancement-qml.manifest COPYONLY)
  target_link_options(graphicenhancement_qml_ui PRIVATE "/MANIFESTINPUT:graphicenhancement-qml.manifest")
endif()
