include_guard(GLOBAL)
# Xbox home streaming (unofficial): sign-in, the streaming session API and a native WebRTC session.
#
#   graphicenhancement_xbox_protocol   WinHTTP + nlohmann-json for the services, libdatachannel (MPL-2.0) for WebRTC.
#
# libdatachannel, libjuice, usrsctp, libsrtp and plog come from the vcpkg tree on CMAKE_PREFIX_PATH
# (x64-windows-static, the same OpenSSL as the rest of the build). Nothing is downloaded here.
find_package(LibDataChannel CONFIG REQUIRED)
find_package(nlohmann_json CONFIG REQUIRED)

add_library(graphicenhancement_xbox_protocol STATIC
  "${GRAPHICENHANCEMENT_ROOT}/src/xbox/Https.cpp"
  "${GRAPHICENHANCEMENT_ROOT}/src/xbox/Account.cpp"
  "${GRAPHICENHANCEMENT_ROOT}/src/xbox/StreamApi.cpp"
  "${GRAPHICENHANCEMENT_ROOT}/src/xbox/WebRtcSession.cpp")
target_compile_features(graphicenhancement_xbox_protocol PUBLIC cxx_std_20)
set_target_properties(graphicenhancement_xbox_protocol PROPERTIES CXX_EXTENSIONS OFF)
target_compile_definitions(graphicenhancement_xbox_protocol PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN)
target_include_directories(graphicenhancement_xbox_protocol PUBLIC "${GRAPHICENHANCEMENT_ROOT}/include")
target_link_libraries(graphicenhancement_xbox_protocol
  PUBLIC LibDataChannel::LibDataChannel nlohmann_json::nlohmann_json graphicenhancement_base
  PRIVATE winhttp crypt32 shell32 ole32 ws2_32)
graphicenhancement_apply_warnings(graphicenhancement_xbox_protocol)

add_executable(graphicenhancement_xbox_tests "${GRAPHICENHANCEMENT_ROOT}/tests/xbox/XboxTests.cpp")
target_compile_features(graphicenhancement_xbox_tests PRIVATE cxx_std_20)
target_compile_definitions(graphicenhancement_xbox_tests PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN)
target_link_libraries(graphicenhancement_xbox_tests PRIVATE graphicenhancement_xbox_protocol)
graphicenhancement_apply_warnings(graphicenhancement_xbox_tests)
