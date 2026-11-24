# GraphicEnhancement OBS filter module.
#
# OBS owns capture, decode, encode and composition; this module adds only the
# per-frame GPU enhancement chain, which is why it works on Linux without any
# of the Windows-only backends (NGX/DLSS, Media Foundation, WGC, WASAPI).

find_package(libobs REQUIRED)

add_library(graphicenhancement_obs_plugin MODULE
  graphicenhancement-filter.c
)
set_target_properties(graphicenhancement_obs_plugin PROPERTIES
  PREFIX ""
  OUTPUT_NAME "graphicenhancement-filter"
)
target_compile_features(graphicenhancement_obs_plugin PRIVATE c_std_11)
target_link_libraries(graphicenhancement_obs_plugin PRIVATE OBS::libobs)

install(TARGETS graphicenhancement_obs_plugin
  LIBRARY DESTINATION lib/obs-plugins)
install(FILES graphicenhancement.effect
  DESTINATION share/obs/obs-plugins/graphicenhancement-filter)
install(DIRECTORY locale/
  DESTINATION share/obs/obs-plugins/graphicenhancement-filter/locale)

include(CTest)
if(BUILD_TESTING)
  add_executable(graphicenhancement_cube_tests ../../tests/obs-filter/cube-tests.c)
  target_link_libraries(graphicenhancement_cube_tests PRIVATE m)
  add_test(NAME obs_cube_parser COMMAND graphicenhancement_cube_tests "${CMAKE_CURRENT_BINARY_DIR}/test.cube")
  set_tests_properties(obs_cube_parser PROPERTIES TIMEOUT 30)
endif()
