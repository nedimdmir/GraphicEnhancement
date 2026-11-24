@echo off
chcp 65001 >nul
setlocal
set "EXE=%~1"
if not defined EXE set "EXE=%~dp0..\..eyra_qml_ui.exe"
if not exist "%EXE%" (
  echo Usage: install-protocol.cmd "full path to graphicenhancement_qml_ui.exe"
  exit /b 1
)
for %%I in ("%EXE%") do set "EXE=%%~fI"
reg add "HKCU\Software\Classes\graphicenhancement" /ve /d "URL:GraphicEnhancement Protocol" /f >nul
reg add "HKCU\Software\Classes\graphicenhancement" /v "URL Protocol" /d "" /f >nul
reg add "HKCU\Software\Classes\graphicenhancement\shell\open\command" /ve /d "\"%EXE%\" \"%%1\"" /f >nul
if errorlevel 1 (
  echo [错误] 注册 graphicenhancement:// 协议失败
  pause
  exit /b 1
)
echo 已注册 graphicenhancement:// 协议：%EXE%
pause
