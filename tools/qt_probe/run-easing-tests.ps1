# Runs graphicenhancement_qml_easing_tests (G0.6) with the Qt runtime on PATH for this process only.
param([string]$Build = 'E:\项目\GraphicEnhancement\build\qt-probe-20260926',
      [string]$Qt = 'E:\项目\GraphicEnhancement\deps\qt\6.8.3\msvc2022_64',
      [string]$Out = '')
$env:PATH = "$Qt\bin;$env:PATH"
$env:TEMP = 'E:\项目\GraphicEnhancement\tmp\ui-qml-migration-20260925'; $env:TMP = $env:TEMP
$text = & (Join-Path $Build 'graphicenhancement_qml_easing_tests.exe') 2>&1 | Out-String
$code = $LASTEXITCODE
$text.TrimEnd()
if ($Out) { $text | Set-Content -LiteralPath $Out -Encoding utf8 }
"exit=$code"
exit $code
