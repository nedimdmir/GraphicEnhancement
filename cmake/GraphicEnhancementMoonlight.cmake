include_guard(GLOBAL)
# Moonlight / GameStream streaming core.
#
#   graphicenhancement_moonlight_common_c   moonlight-common-c (GPL-3.0) + its pinned ENet and nanors, built from
#                              the exact checkout named in scripts/moonlight/dependency-lock.json
#   graphicenhancement_moonlight_protocol   host HTTP(S) client, pairing, identity (Qt-free, OpenSSL + Winsock)
#
# Nothing is downloaded by the build: GRAPHICENHANCEMENT_MOONLIGHT_SOURCE_DIR must point at a checkout that passes
# scripts/moonlight/verify-moonlight-stage.py. Sunshine, the host, is never part of this build.
set(GRAPHICENHANCEMENT_MOONLIGHT_SOURCE_DIR "" CACHE PATH "Pinned moonlight-common-c checkout (with submodules)")
if(NOT EXISTS "${GRAPHICENHANCEMENT_MOONLIGHT_SOURCE_DIR}/src/Limelight.h")
  message(FATAL_ERROR "GRAPHICENHANCEMENT_ENABLE_MOONLIGHT needs GRAPHICENHANCEMENT_MOONLIGHT_SOURCE_DIR to be the pinned moonlight-common-c checkout")
endif()
find_package(Python3 REQUIRED COMPONENTS Interpreter)
execute_process(
  COMMAND "${Python3_EXECUTABLE}" "${CMAKE_CURRENT_SOURCE_DIR}/scripts/moonlight/verify-moonlight-stage.py"
          --source "${GRAPHICENHANCEMENT_MOONLIGHT_SOURCE_DIR}" --lock "${CMAKE_CURRENT_SOURCE_DIR}/scripts/moonlight/dependency-lock.json"
  RESULT_VARIABLE MOONLIGHT_VERIFY_RESULT OUTPUT_VARIABLE MOONLIGHT_VERIFY_OUTPUT ERROR_VARIABLE MOONLIGHT_VERIFY_ERROR)
if(NOT MOONLIGHT_VERIFY_RESULT EQUAL 0)
  message(FATAL_ERROR "moonlight-common-c verification failed: ${MOONLIGHT_VERIFY_OUTPUT} ${MOONLIGHT_VERIFY_ERROR}")
endif()
string(STRIP "${MOONLIGHT_VERIFY_OUTPUT}" MOONLIGHT_VERIFY_OUTPUT)
message(STATUS "${MOONLIGHT_VERIFY_OUTPUT}")

find_package(OpenSSL REQUIRED)

# ENet as shipped with moonlight-common-c (a fork with IPv6 and retransmission changes).
set(ENET_NO_INSTALL ON CACHE BOOL "" FORCE)
add_subdirectory("${GRAPHICENHANCEMENT_MOONLIGHT_SOURCE_DIR}/enet" "${CMAKE_CURRENT_BINARY_DIR}/moonlight-enet" EXCLUDE_FROM_ALL)

file(GLOB GRAPHICENHANCEMENT_MOONLIGHT_C_SOURCES "${GRAPHICENHANCEMENT_MOONLIGHT_SOURCE_DIR}/src/*.c")
list(APPEND GRAPHICENHANCEMENT_MOONLIGHT_C_SOURCES
  "${GRAPHICENHANCEMENT_MOONLIGHT_SOURCE_DIR}/nanors/rs.c"
  "${GRAPHICENHANCEMENT_MOONLIGHT_SOURCE_DIR}/nanors/deps/obl/oblas_common.c"
  "${GRAPHICENHANCEMENT_MOONLIGHT_SOURCE_DIR}/nanors/deps/obl/oblas_lite.c")
add_library(graphicenhancement_moonlight_common_c STATIC ${GRAPHICENHANCEMENT_MOONLIGHT_C_SOURCES})
set_target_properties(graphicenhancement_moonlight_common_c PROPERTIES C_STANDARD 11 C_EXTENSIONS OFF)
target_include_directories(graphicenhancement_moonlight_common_c SYSTEM PUBLIC "${GRAPHICENHANCEMENT_MOONLIGHT_SOURCE_DIR}/src")
target_include_directories(graphicenhancement_moonlight_common_c SYSTEM PRIVATE
  "${GRAPHICENHANCEMENT_MOONLIGHT_SOURCE_DIR}/nanors"
  "${GRAPHICENHANCEMENT_MOONLIGHT_SOURCE_DIR}/nanors/deps"
  "${GRAPHICENHANCEMENT_MOONLIGHT_SOURCE_DIR}/nanors/deps/obl")
target_compile_definitions(graphicenhancement_moonlight_common_c PRIVATE HAS_SOCKLEN_T NDEBUG)
target_compile_options(graphicenhancement_moonlight_common_c PRIVATE /W3 /wd4100 /wd4232 /wd5105)
target_link_libraries(graphicenhancement_moonlight_common_c PRIVATE enet OpenSSL::Crypto ws2_32 winmm)

add_library(graphicenhancement_moonlight_protocol STATIC
  "${GRAPHICENHANCEMENT_ROOT}/src/moonlight/Xml.cpp"
  "${GRAPHICENHANCEMENT_ROOT}/src/moonlight/Crypto.cpp"
  "${GRAPHICENHANCEMENT_ROOT}/src/moonlight/Http.cpp"
  "${GRAPHICENHANCEMENT_ROOT}/src/moonlight/Client.cpp"
  "${GRAPHICENHANCEMENT_ROOT}/src/moonlight/Pairing.cpp"
  "${GRAPHICENHANCEMENT_ROOT}/src/moonlight/IdentityStore.cpp"
  "${GRAPHICENHANCEMENT_ROOT}/src/moonlight/Discovery.cpp")
target_compile_features(graphicenhancement_moonlight_protocol PUBLIC cxx_std_20)
set_target_properties(graphicenhancement_moonlight_protocol PROPERTIES CXX_EXTENSIONS OFF)
target_compile_definitions(graphicenhancement_moonlight_protocol PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN)
target_include_directories(graphicenhancement_moonlight_protocol PUBLIC "${GRAPHICENHANCEMENT_ROOT}/include")
target_link_libraries(graphicenhancement_moonlight_protocol PUBLIC OpenSSL::SSL OpenSSL::Crypto PRIVATE ws2_32 crypt32 shell32 ole32 advapi32 user32 dnsapi)
