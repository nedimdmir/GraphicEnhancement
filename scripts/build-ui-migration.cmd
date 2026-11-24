@echo off
rem Target-explicit build wrapper. Use scripts/build-ui-migration.ps1.
call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat" >nul 2>&1
if errorlevel 1 exit /b 4
set "ROOT=%~dp0.."
if "%GRAPHICENHANCEMENT_OUT%"=="" exit /b 3
if /I "%GRAPHICENHANCEMENT_UI_TARGET%"=="qml" (
  set "QML_SWITCH=ON"
) else (
  echo GRAPHICENHANCEMENT_UI_TARGET must be qml for the active UI migration 1>&2
  exit /b 7
)
set "OUT=%GRAPHICENHANCEMENT_OUT%"
if not "%GRAPHICENHANCEMENT_TMP%"=="" set "TEMP=%GRAPHICENHANCEMENT_TMP%"
if not "%GRAPHICENHANCEMENT_TMP%"=="" set "TMP=%GRAPHICENHANCEMENT_TMP%"
set "CMAKE=C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe"
if not exist "%OUT%\CMakeCache.txt" (
  "%CMAKE%" --preset x64-release -S "%ROOT%" -B "%OUT%" -DGRAPHICENHANCEMENT_BUILD_QML_UI=ON -DCMAKE_PREFIX_PATH="%GRAPHICENHANCEMENT_QT_DIR%;C:/graphicenhancement-deps/remoteplay-installed/x64-windows-static" -DGRAPHICENHANCEMENT_ENABLE_EXPERIMENTAL_DLSSNR=ON -DGRAPHICENHANCEMENT_DLSS_SDK_ROOT="%ROOT%\third_party_local\nvidia\DLSS_SDK_310.7.0" -DGRAPHICENHANCEMENT_NVOF_SDK_ROOT="%ROOT%\third_party_local\nvidia\Optical_Flow_SDK_5.0.7" -DGRAPHICENHANCEMENT_NVENC_HEADERS_ROOT="%ROOT%\third_party_local\nvidia\nv-codec-headers-13.0" -DGRAPHICENHANCEMENT_XESS_ROOT="%ROOT%\third_party_local\intel\xess-3.0.2" -DGRAPHICENHANCEMENT_FIDELITYFX_ROOT="%ROOT%\third_party_local\amd\FidelityFX-SDK\sdk" -DGRAPHICENHANCEMENT_FIDELITYFX2_ROOT="%ROOT%\third_party_local\amd\FidelityFX-SDK-2.3.0\Kits\FidelityFX" -DGRAPHICENHANCEMENT_FFMPEG_ROOT="C:\graphicenhancement-deps\ffmpeg-ps5-dav1d-installed" -DGRAPHICENHANCEMENT_CLIP_TOOLS_ROOT="C:\graphicenhancement-deps\tools-installed\x64-windows" -DGRAPHICENHANCEMENT_ENABLE_REMOTEPLAY=ON -DGRAPHICENHANCEMENT_RP_CHIAKI_VERIFY_DIR="C:/graphicenhancement-deps/chiaki-source" -DGRAPHICENHANCEMENT_RP_CHIAKI_SOURCE_DIR="%ROOT%\out\remoteplay\chiaki-msvc-stage" -DPROTOC="C:/graphicenhancement-deps/remoteplay-installed/x64-windows/tools/protobuf/protoc.exe" -DPKG_CONFIG_EXECUTABLE="C:/graphicenhancement-deps/vcpkg/downloads/tools/msys2/3e71d1f8e22ab23f/mingw64/bin/pkg-config.exe"
  if errorlevel 1 exit /b 5
) else (
  findstr /R /C:"^GRAPHICENHANCEMENT_BUILD_QML_UI:BOOL=%QML_SWITCH%$" "%OUT%\CMakeCache.txt" >nul
  if errorlevel 1 (
    echo Existing CMakeCache.txt does not match target %GRAPHICENHANCEMENT_UI_TARGET% 1>&2
    exit /b 8
  )
)
set "PRIMARY_TARGETS=graphicenhancement_qml_ui graphicenhancement_qml_data_tests graphicenhancement_qml_easing_tests graphicenhancement_qml_quick_tests"
rem The UI contract always builds all four targets. Do not forward arbitrary
rem command-line targets/options into a backend build from this UI wrapper.
"%CMAKE%" --build "%OUT%" --target %PRIMARY_TARGETS%
if errorlevel 1 exit /b 6
for %%T in (graphicenhancement_qml_ui graphicenhancement_qml_data_tests graphicenhancement_qml_easing_tests graphicenhancement_qml_quick_tests) do (
  if not exist "%OUT%\%%T.exe" exit /b 9
)
exit /b 0
