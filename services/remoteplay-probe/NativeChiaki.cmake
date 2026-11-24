add_executable(graphicenhancement_remoteplay_native_probe "${CMAKE_CURRENT_LIST_DIR}/native_main.cpp")
target_compile_features(graphicenhancement_remoteplay_native_probe PRIVATE cxx_std_20)
target_compile_definitions(graphicenhancement_remoteplay_native_probe PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN)
target_link_libraries(graphicenhancement_remoteplay_native_probe PRIVATE graphicenhancement_remoteplay_chiaki chiaki-lib)
add_test(NAME rp.native_core_initialization COMMAND graphicenhancement_remoteplay_native_probe)
set_tests_properties(rp.native_core_initialization PROPERTIES TIMEOUT 30 LABELS "native-core;not-ps5")

# Optional source regressions link the production adapter and real FFmpeg.
set(GRAPHICENHANCEMENT_RP_FFMPEG_ROOT "" CACHE PATH "Existing GraphicEnhancement FFmpeg installation")
if(GRAPHICENHANCEMENT_RP_FFMPEG_ROOT)
    add_executable(graphicenhancement_remoteplay_source_tests
        "${GRAPHICENHANCEMENT_ROOT}/tests/remoteplay/SourceTests.cpp"
        "${GRAPHICENHANCEMENT_ROOT}/src/source/RemotePlaySource.cpp"
        "${GRAPHICENHANCEMENT_ROOT}/src/base/Log.cpp")
    target_compile_features(graphicenhancement_remoteplay_source_tests PRIVATE cxx_std_20)
    target_compile_definitions(graphicenhancement_remoteplay_source_tests PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN)
    target_include_directories(graphicenhancement_remoteplay_source_tests SYSTEM PRIVATE "${GRAPHICENHANCEMENT_RP_FFMPEG_ROOT}/include")
    target_link_libraries(graphicenhancement_remoteplay_source_tests PRIVATE graphicenhancement_remoteplay_chiaki d3d12
        "${GRAPHICENHANCEMENT_RP_FFMPEG_ROOT}/lib/avcodec.lib"
        "${GRAPHICENHANCEMENT_RP_FFMPEG_ROOT}/lib/avutil.lib"
        "${GRAPHICENHANCEMENT_RP_FFMPEG_ROOT}/lib/avformat.lib")
endif()

add_executable(graphicenhancement_remoteplay_profile_tests "${GRAPHICENHANCEMENT_ROOT}/tests/remoteplay/ProfileStoreTests.cpp")
target_compile_features(graphicenhancement_remoteplay_profile_tests PRIVATE cxx_std_20)
target_compile_definitions(graphicenhancement_remoteplay_profile_tests PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN)
target_link_libraries(graphicenhancement_remoteplay_profile_tests PRIVATE graphicenhancement_remoteplay_chiaki)
add_test(NAME rp.dpapi_profile COMMAND graphicenhancement_remoteplay_profile_tests)
set_tests_properties(rp.dpapi_profile PROPERTIES TIMEOUT 30)
