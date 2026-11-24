"""Bounded CPU/GPU regression; no competing load or pressure driver."""
from pathlib import Path
import json
import os
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[2]
BASE=Path('E:/项目/GraphicEnhancement');TASK='nr-strength-protection-20261005'
BUILD=BASE/'build'/TASK
label=sys.argv[1];assert label.replace('-', '').isalnum()
LOG=BASE/'logs'/TASK/label;OUT=BASE/'tests'/TASK/label;TMP=BASE/'tmp'/TASK/label
for p in (LOG,OUT,TMP):p.mkdir(parents=True,exist_ok=False)
subprocess.run([sys.executable,'-B',str(ROOT/'scripts/acceptance/nr-protection-control.py'),'guard'],check=True)
candidate=BASE/'test-packages/field-fixes-20261005/GraphicEnhancement-2.0.3-field-20261005b-NVIDIA-win64-portable'
env=os.environ.copy();env.update(TEMP=str(TMP),TMP=str(TMP),PATH=str(candidate)+os.pathsep+env.get('PATH',''),
    GRAPHICENHANCEMENT_LOG_FILE=str(LOG/'device.log'),QML_DISABLE_DISK_CACHE='1')
tests=[('preset-library', 'graphicenhancement_preset_library_tests', []),
       ('preset-legacy','graphicenhancement_repair_preset_tests',['presets/legacy-presets.v1']),
       ('effect-chain','graphicenhancement_effect_chain_tests',[]),
       ('nr-tiers','graphicenhancement_nr_antiflicker_tests',[]),
       ('hdr-contract','graphicenhancement_hdr_color_tests',[]),
       ('legacy-shader','graphicenhancement_repair_shader_tests',[]),
       ('temporal','graphicenhancement_nr_temporal_gpu_tests',[]),
       ('correction','graphicenhancement_nr_correction_gpu_tests',[
           str(BASE/'tests'/TASK/'baseline/NrResidualComposite.dxil'),str(OUT/'shader')]),
       ('correction-fp16','graphicenhancement_nr_correction_gpu_tests',[
           str(BASE/'tests'/TASK/'baseline/NrResidualComposite.dxil'),str(OUT/'shader-fp16'),'--fp16'])]
if len(sys.argv)>2:tests=[t for t in tests if t[0] in sys.argv[2:]]
results=[]
for name,exe,args in tests:
    destination=LOG/(name+'.log')
    with destination.open('xb') as log:
        try:rc=subprocess.run([str(BUILD/(exe+'.exe')),*args],cwd=OUT,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=290).returncode
        except subprocess.TimeoutExpired:rc=124
    output=destination.read_text(encoding='utf-8',errors='replace')
    results.append({'name':name,'exit':rc,'log':str(destination)})
    print(name,rc,'\n'+'\n'.join(output.splitlines()[-5:]),flush=True)
(LOG/'results.json').write_text(json.dumps(results,ensure_ascii=False,indent=2),encoding='utf-8')
subprocess.run([sys.executable,'-B',str(ROOT/'scripts/acceptance/nr-protection-control.py'),'guard'],check=True)
raise SystemExit(0 if all(r['exit']==0 for r in results) else 1)
