"""Bounded field regressions in an isolated, current-runtime staging directory."""
import json, os, shutil, subprocess, sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
BASE=Path('E:/项目/GraphicEnhancement'); TASK='field-upgrade-20261003'
BUILD=BASE/'build'/TASK; TESTS=BASE/'tests'/TASK; APP=TESTS/'app'
QT=Path('C:/graphicenhancement-deps/qt-graphicenhancement/6.8.3/msvc2022_64')
subprocess.run([sys.executable,'-B',str(ROOT/'scripts/acceptance/field-upgrade-control.py')],check=True)
label=sys.argv[1]
if not label.replace('-','').isalnum():raise ValueError('label')
out=TESTS/label;out.mkdir(parents=True,exist_ok=False)
tmp=BASE/'tmp'/TASK/label;tmp.mkdir(parents=True,exist_ok=False)
if not APP.exists():shutil.copytree(BASE/'releases/2.0.2/GraphicEnhancement-2.0.2-win64-portable',APP)
for name in ('graphicenhancement_qml_ui','graphicenhancement_qml_quick_tests','graphicenhancement_capture_audio_tests','graphicenhancement_xbox_tests','graphicenhancement_lmxxf_nr_tests','graphicenhancement_export_probe','graphicenhancement_ui_i18n_tests','graphicenhancement_preset_library_tests'):
    shutil.copy2(BUILD/(name+'.exe'),APP/(name+'.exe'))
shutil.copytree(BUILD/'lmxxf-test-runtime',APP/'lmxxf-test-runtime',dirs_exist_ok=True)
shutil.copytree(ROOT/'qml',APP/'qml',dirs_exist_ok=True)
shutil.copytree(ROOT/'tests/qml/quick',APP/'qml-tests',dirs_exist_ok=True)
for name in ('Qt6Test.dll','Qt6QuickTest.dll'):shutil.copy2(QT/'bin'/name,APP/name)
env=os.environ.copy();env.update(TEMP=str(tmp),TMP=str(tmp),
    QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software',QT_QUICK_CONTROLS_STYLE='Basic',
    QML_DISABLE_DISK_CACHE='1',QT_FORCE_STDERR_LOGGING='1',
    QT_QPA_PLATFORM_PLUGIN_PATH=str(QT/'plugins/platforms'),
    PATH=str(QT/'bin')+os.pathsep+str(APP)+os.pathsep+env['PATH'])
results=[]
cases=[('qml-software',['.\\graphicenhancement_qml_quick_tests.exe']),
       ('xbox-loopback',['.\\graphicenhancement_xbox_tests.exe']),
       ('xbox-float-output',['.\\graphicenhancement_capture_audio_tests.exe','--xbox-float-rtp']),
       ('amd-abi-copy',['.\\graphicenhancement_lmxxf_nr_tests.exe']),
       ('ui-i18n',['.\\graphicenhancement_ui_i18n_tests.exe']),
       ('nr-preset-persistence',['.\\graphicenhancement_preset_library_tests.exe'])]
if len(sys.argv)>2:cases=[case for case in cases if case[0] in sys.argv[2:]]
if not cases:raise ValueError('No matching tests')
for name,args in cases:
    with (out/(name+'.log')).open('xb') as log:
        try:code=subprocess.run(args,executable=str(APP/Path(args[0]).name),cwd=APP,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=290).returncode
        except subprocess.TimeoutExpired:code=124
    results.append({'test':name,'exit':code});print(results[-1],flush=True)
(out/'summary.json').write_text(json.dumps(results,indent=2),encoding='utf8')
raise SystemExit(any(r['exit'] for r in results))
