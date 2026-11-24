cmake_minimum_required(VERSION 3.24)
if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
  project(graphicenhancement_hdmi_bitstream_tests LANGUAGES CXX)
  enable_testing()
endif()

set(graphicenhancement_root "../..")
add_executable(graphicenhancement_hdmi_bitstream_tests
  ${graphicenhancement_root}/tests/unit/HdmiBitstreamTests.cpp
  ${graphicenhancement_root}/src/sink/HdmiBitstreamOutput.cpp
  ${graphicenhancement_root}/src/sink/Iec61937Burst.cpp)
target_compile_features(graphicenhancement_hdmi_bitstream_tests PRIVATE cxx_std_20)
target_compile_definitions(graphicenhancement_hdmi_bitstream_tests PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN)
target_include_directories(graphicenhancement_hdmi_bitstream_tests PRIVATE ${graphicenhancement_root}/include)
target_link_libraries(graphicenhancement_hdmi_bitstream_tests PRIVATE ole32 mmdevapi avrt)
foreach(case IN ITEMS ac3 dts underrun endpoint format-change missing-device)
  add_test(NAME graphicenhancement_hdmi_bitstream_${case} COMMAND graphicenhancement_hdmi_bitstream_tests ${case})
endforeach()
