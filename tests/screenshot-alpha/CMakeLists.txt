cmake_minimum_required(VERSION 3.24)

# Also runnable without the player's optional Qt/FFmpeg/NGX SDK dependencies.
if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
  project(GraphicEnhancementScreenshotAlphaTests LANGUAGES CXX)
  set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
  set(GRAPHICENHANCEMENT_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../..")
  add_library(graphicenhancement_screenshot_test_support STATIC
    ${GRAPHICENHANCEMENT_ROOT}/src/base/Log.cpp
    ${GRAPHICENHANCEMENT_ROOT}/src/base/NgxResult.cpp
    ${GRAPHICENHANCEMENT_ROOT}/src/gfx/D3D12DeviceContext.cpp
    ${GRAPHICENHANCEMENT_ROOT}/src/gfx/CommandSlotRing.cpp)
  target_include_directories(graphicenhancement_screenshot_test_support PUBLIC ${GRAPHICENHANCEMENT_ROOT}/include)
  target_compile_features(graphicenhancement_screenshot_test_support PUBLIC cxx_std_20)
  target_compile_definitions(graphicenhancement_screenshot_test_support PUBLIC UNICODE _UNICODE NOMINMAX WIN32_LEAN_AND_MEAN)
  target_compile_options(graphicenhancement_screenshot_test_support PUBLIC /utf-8)
  target_link_libraries(graphicenhancement_screenshot_test_support PUBLIC d3d12 dxgi dxguid ole32 oleaut32 windowscodecs advapi32 psapi version)
  enable_testing()
  include(${GRAPHICENHANCEMENT_ROOT}/cmake/GraphicEnhancementShaders.cmake)
  graphicenhancement_find_dxc(DXC_EXE)
  set(SCALE_BLIT_SHADER "${CMAKE_CURRENT_BINARY_DIR}/ScaleBlit.dxil")
  file(GLOB SHADER_INCLUDES "${GRAPHICENHANCEMENT_ROOT}/shaders/*.hlsli")
  add_custom_command(OUTPUT "${SCALE_BLIT_SHADER}"
    COMMAND "${DXC_EXE}" -T cs_6_0 -E main -O3 -Fo "${SCALE_BLIT_SHADER}" "${GRAPHICENHANCEMENT_ROOT}/shaders/ScaleBlit.hlsl"
    DEPENDS "${GRAPHICENHANCEMENT_ROOT}/shaders/ScaleBlit.hlsl" ${SHADER_INCLUDES} VERBATIM)
  add_custom_target(graphicenhancement_shader_scale_blit DEPENDS "${SCALE_BLIT_SHADER}")
else()
  set(GRAPHICENHANCEMENT_ROOT "${PROJECT_SOURCE_DIR}")
  set(SCALE_BLIT_SHADER "${CMAKE_BINARY_DIR}/shaders/ScaleBlit.dxil")
endif()

add_executable(graphicenhancement_screenshot_alpha_tests
  ScreenshotAlphaTests.cpp ${GRAPHICENHANCEMENT_ROOT}/src/sink/ImageExportSink.cpp)
target_compile_features(graphicenhancement_screenshot_alpha_tests PRIVATE cxx_std_20)
target_compile_options(graphicenhancement_screenshot_alpha_tests PRIVATE /W4 /utf-8)
target_compile_definitions(graphicenhancement_screenshot_alpha_tests PRIVATE GRAPHICENHANCEMENT_TEST_SCALE_BLIT="${SCALE_BLIT_SHADER}")
add_dependencies(graphicenhancement_screenshot_alpha_tests graphicenhancement_shader_scale_blit)
if(TARGET graphicenhancement_screenshot_test_support)
  target_link_libraries(graphicenhancement_screenshot_alpha_tests PRIVATE graphicenhancement_screenshot_test_support)
else()
  target_link_libraries(graphicenhancement_screenshot_alpha_tests PRIVATE graphicenhancement_gfx ole32 oleaut32 windowscodecs)
endif()
add_test(NAME screenshot_alpha COMMAND graphicenhancement_screenshot_alpha_tests "${CMAKE_CURRENT_BINARY_DIR}/results")
set_tests_properties(screenshot_alpha PROPERTIES TIMEOUT 120)
