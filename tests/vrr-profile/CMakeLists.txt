cmake_minimum_required(VERSION 3.24)
project(GraphicEnhancementVrrProfileChecks LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
enable_testing()
find_package(Qt6 6.8 REQUIRED COMPONENTS Core Gui Qml Quick QuickControls2 QuickTest Test)
get_filename_component(GRAPHICENHANCEMENT_ROOT "../.." ABSOLUTE)

function(vrr_check_target target)
  target_include_directories(${target} PRIVATE "${GRAPHICENHANCEMENT_ROOT}/include")
  target_compile_definitions(${target} PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN UNICODE _UNICODE)
  if(MSVC)
    target_compile_options(${target} PRIVATE /utf-8 /W4 /WX /permissive- /Zc:__cplusplus /Zc:preprocessor)
  endif()
endfunction()

# Compiles the real system-driver adapter, but its default test entry point
# executes policy assertions only. CI never uses the optional --inspect mode.
add_executable(vrr_policy_tests ../unit/NvidiaVrrProfileTests.cpp "${GRAPHICENHANCEMENT_ROOT}/src/gfx/NvidiaVrrProfile.cpp")
set_target_properties(vrr_policy_tests PROPERTIES AUTOMOC OFF)
vrr_check_target(vrr_policy_tests)
add_test(NAME vrr_policy COMMAND vrr_policy_tests)

# Link-time fakes replace only the three driver entry points. This exercises
# the production controller's JSON, locking and async state without a GPU or
# access to the runner's real driver profiles.
add_executable(vrr_controller_tests ControllerTests.cpp LogStub.cpp
  "${GRAPHICENHANCEMENT_ROOT}/src/ui/NvidiaVrrProfileController.cpp"
  "${GRAPHICENHANCEMENT_ROOT}/include/graphicenhancement/ui/NvidiaVrrProfileController.h")
vrr_check_target(vrr_controller_tests)
target_link_libraries(vrr_controller_tests PRIVATE Qt6::Core Qt6::Test)
add_test(NAME vrr_controller COMMAND vrr_controller_tests)

add_executable(vrr_qml_tests QuickTests.cpp LogStub.cpp "${GRAPHICENHANCEMENT_ROOT}/src/ui/UiLanguage.cpp")
vrr_check_target(vrr_qml_tests)
target_compile_definitions(vrr_qml_tests PRIVATE GRAPHICENHANCEMENT_VRR_SOURCE_ROOT="${GRAPHICENHANCEMENT_ROOT}")
target_link_libraries(vrr_qml_tests PRIVATE Qt6::Core Qt6::Gui Qt6::Qml Qt6::Quick Qt6::QuickControls2 Qt6::QuickTest)
qt_add_resources(vrr_qml_tests "vrr_test_i18n" PREFIX "/i18n" BASE "${GRAPHICENHANCEMENT_ROOT}/i18n"
  FILES "${GRAPHICENHANCEMENT_ROOT}/i18n/catalog.json")
foreach(language IN ITEMS zh-CN zh-TW en ja)
  add_test(NAME vrr_qml_${language} COMMAND vrr_qml_tests -input "${GRAPHICENHANCEMENT_ROOT}/tests/qml/quick/tst_vrr_profile.qml")
  set_tests_properties(vrr_qml_${language} PROPERTIES
    ENVIRONMENT "QT_QPA_PLATFORM=offscreen;QT_QUICK_BACKEND=software;QML_DISABLE_DISK_CACHE=1;GRAPHICENHANCEMENT_TEST_UI_LANGUAGE=${language}"
    TIMEOUT 120)
endforeach()
set_tests_properties(vrr_policy vrr_controller PROPERTIES TIMEOUT 120)
