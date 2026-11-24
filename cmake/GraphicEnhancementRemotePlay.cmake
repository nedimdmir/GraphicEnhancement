include_guard(GLOBAL)
find_package(Threads REQUIRED)
add_library(graphicenhancement_remoteplay_core STATIC
    "${GRAPHICENHANCEMENT_ROOT}/src/remoteplay/Validation.cpp"
    "${GRAPHICENHANCEMENT_ROOT}/src/remoteplay/AnnexB.cpp"
    "${GRAPHICENHANCEMENT_ROOT}/src/remoteplay/Timeline.cpp"
    "${GRAPHICENHANCEMENT_ROOT}/src/remoteplay/VideoIngress.cpp"
    "${GRAPHICENHANCEMENT_ROOT}/src/remoteplay/SessionInbox.cpp")
target_include_directories(graphicenhancement_remoteplay_core PUBLIC "${GRAPHICENHANCEMENT_ROOT}/include")
target_compile_features(graphicenhancement_remoteplay_core PUBLIC cxx_std_20)
set_target_properties(graphicenhancement_remoteplay_core PROPERTIES CXX_EXTENSIONS OFF)
target_link_libraries(graphicenhancement_remoteplay_core PUBLIC Threads::Threads)
# Shared pinned native dependency for the product and probes. No stub fallback.
enable_language(C)
set(GRAPHICENHANCEMENT_RP_CHIAKI_SOURCE_DIR "" CACHE PATH "Patched chiaki-ng staging source tree")
set(GRAPHICENHANCEMENT_RP_CHIAKI_VERIFY_DIR "${GRAPHICENHANCEMENT_RP_CHIAKI_SOURCE_DIR}" CACHE PATH "Clean pinned chiaki-ng checkout used to verify provenance")
if(NOT EXISTS "${GRAPHICENHANCEMENT_RP_CHIAKI_SOURCE_DIR}/lib/include/chiaki/session.h")
    message(FATAL_ERROR "GRAPHICENHANCEMENT_RP_BUILD_NATIVE needs the pinned chiaki-ng source tree")
endif()
find_package(Python3 REQUIRED COMPONENTS Interpreter)
execute_process(
    COMMAND "${Python3_EXECUTABLE}" "${GRAPHICENHANCEMENT_ROOT}/scripts/remoteplay/verify-chiaki-stage.py"
        --stage "${GRAPHICENHANCEMENT_RP_CHIAKI_SOURCE_DIR}" --clean "${GRAPHICENHANCEMENT_RP_CHIAKI_VERIFY_DIR}"
    RESULT_VARIABLE CHIAKI_VERIFY_RESULT OUTPUT_VARIABLE CHIAKI_VERIFY_OUTPUT
    ERROR_VARIABLE CHIAKI_VERIFY_ERROR)
if(NOT CHIAKI_VERIFY_RESULT EQUAL 0)
    message(FATAL_ERROR "Chiaki source verification failed: ${CHIAKI_VERIFY_OUTPUT} ${CHIAKI_VERIFY_ERROR}")
endif()
# Target C++20 requirements remain explicit despite upstream defaults.
set(CHIAKI_ENABLE_GUI OFF CACHE BOOL "" FORCE)
set(CHIAKI_ENABLE_CLI OFF CACHE BOOL "" FORCE)
set(CHIAKI_ENABLE_TESTS OFF CACHE BOOL "" FORCE)
set(CHIAKI_ENABLE_ANDROID OFF CACHE BOOL "" FORCE)
set(CHIAKI_ENABLE_BOREALIS OFF CACHE BOOL "" FORCE)
set(CHIAKI_ENABLE_FFMPEG_DECODER OFF CACHE STRING "" FORCE)
set(CHIAKI_ENABLE_PI_DECODER OFF CACHE STRING "" FORCE)
set(CHIAKI_ENABLE_SETSU OFF CACHE STRING "" FORCE)
set(CHIAKI_ENABLE_STEAMDECK_NATIVE OFF CACHE STRING "" FORCE)
set(CHIAKI_ENABLE_STEAM_SHORTCUT OFF CACHE BOOL "" FORCE)
set(CHIAKI_ENABLE_SPEEX OFF CACHE STRING "" FORCE)
set(CHIAKI_ENABLE_RUDP OFF CACHE STRING "" FORCE)
set(CHIAKI_LIB_ENABLE_OPUS ON CACHE BOOL "" FORCE)
set(CHIAKI_LIB_ENABLE_MBEDTLS OFF CACHE BOOL "" FORCE)
set(CHIAKI_USE_SYSTEM_NANOPB OFF CACHE STRING "" FORCE)
set(CHIAKI_USE_SYSTEM_JERASURE OFF CACHE STRING "" FORCE)
set(CHIAKI_USE_SYSTEM_CURL OFF CACHE STRING "" FORCE)
# Disabling RUDP does NOT remove curl/json-c/libevent/miniupnpc in the pinned lib.
# Provision their REAL matching-toolchain dev libraries; never replace them with
# empty imported targets or remove FEC to force the native gate green.
add_subdirectory("${GRAPHICENHANCEMENT_RP_CHIAKI_SOURCE_DIR}" "${CMAKE_CURRENT_BINARY_DIR}/chiaki" EXCLUDE_FROM_ALL)
if(NOT TARGET chiaki-lib)
    message(FATAL_ERROR "Upstream chiaki-lib target was not created")
endif()
# vcpkg's static miniupnpc headers default to dllimport on Windows unless the
# caller opts into the static ABI. Without this definition the static library
# is found correctly but Chiaki emits unresolved __imp_* references.
target_compile_definitions(chiaki-lib PRIVATE MINIUPNP_STATICLIB)
add_library(graphicenhancement_remoteplay_chiaki STATIC
    "${GRAPHICENHANCEMENT_ROOT}/src/remoteplay/ChiakiBackend.cpp"
    "${GRAPHICENHANCEMENT_ROOT}/src/remoteplay/ChiakiRegistration.cpp"
    "${GRAPHICENHANCEMENT_ROOT}/src/remoteplay/ProfileStore.cpp"
    "${GRAPHICENHANCEMENT_ROOT}/src/remoteplay/Discovery.cpp")
target_compile_features(graphicenhancement_remoteplay_chiaki PUBLIC cxx_std_20)
target_compile_definitions(graphicenhancement_remoteplay_chiaki PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN)
target_link_libraries(graphicenhancement_remoteplay_chiaki PUBLIC graphicenhancement_remoteplay_core PRIVATE chiaki-lib crypt32 iphlpapi shell32 ole32 winhttp)

# Real sender + Takion encryption over loopback only; never contacts a console.
add_executable(graphicenhancement_remoteplay_feedback_wire_tests
    "${GRAPHICENHANCEMENT_ROOT}/tests/remoteplay/feedback-history/wire.c")
target_link_libraries(graphicenhancement_remoteplay_feedback_wire_tests PRIVATE chiaki-lib ws2_32)
enable_testing()
add_test(NAME remoteplay-feedback-wire COMMAND graphicenhancement_remoteplay_feedback_wire_tests)
set_tests_properties(remoteplay-feedback-wire PROPERTIES TIMEOUT 15)

# Exercise both real Takion socket-setup paths without contacting a console.
add_executable(graphicenhancement_remoteplay_udp_buffer_tests
    "${GRAPHICENHANCEMENT_ROOT}/tests/remoteplay/UdpReceiveBufferTests.c")
target_link_libraries(graphicenhancement_remoteplay_udp_buffer_tests PRIVATE chiaki-lib ws2_32)
add_test(NAME remoteplay-udp-buffer COMMAND graphicenhancement_remoteplay_udp_buffer_tests)
set_tests_properties(remoteplay-udp-buffer PROPERTIES TIMEOUT 15 LABELS "native-core")
