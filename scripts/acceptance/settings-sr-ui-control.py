"""Audit immutable pre-task worktrees and this task's narrow source scope."""
from pathlib import Path
import hashlib
import json
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
BASE = Path('E:/项目/GraphicEnhancement')
TASK = 'settings-sr-ui-20261010'
start = json.loads((BASE/'archives'/TASK/'start.json').read_text(encoding='utf8'))

def git(*args, cwd=ROOT):
    return subprocess.check_output(['git', *args], cwd=cwd)

def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()

for name, row in start['worktrees'].items():
    path = Path(name)
    assert git('rev-parse', 'HEAD', cwd=path).decode().strip() == row['head'], name
    assert hashlib.sha256(git('status', '--porcelain=v1', '-z', cwd=path)).hexdigest() == row['statusSha256'], name
    for relative, digest in row['dirtyFiles'].items():
        file = path/relative
        assert (sha(file) if file.is_file() else None) == digest, str(file)
assert git('rev-parse', 'main').decode().strip() == start['main']
assert git('branch', '--show-current').decode().strip() == 'codex/'+TASK
allowed = {'docs/SETTINGS_SR_UI_REPORT_2026-10-10.md', 'qml/GraphicEnhancement/VSegment.qml', 'src/gfx/FsrSrBackend.cpp', 'include/graphicenhancement/ui/QmlPlayerBridge.h', 'qml/GraphicEnhancement/VButton.qml', 'include/graphicenhancement/gfx/PresentSink.h', 'qml/GraphicEnhancement/VMenu.qml', 'scripts/acceptance/settings-sr-ui-control.py', 'tests/integration/LivePresentationTests.cpp', 'CMakeLists.txt', 'src/gfx/PresentSink.cpp', 'src/engine/EngineController.cpp', 'tests/integration/SrQualityTests.cpp', 'docs/SETTINGS_SR_UI_PLAN_2026-10-10.md', 'src/engine/EnhancementSettings.cpp', 'qml/GraphicEnhancement/DialogHost.qml', 'tests/qml/quick/tst_slider_value.qml', 'qml/GraphicEnhancement/Main.qml', 'qml/GraphicEnhancement/NodePage.qml', 'include/graphicenhancement/engine/GraphDescription.h', 'tests/perf/PresentSinkLifecycleTests.cpp', 'tests/unit/GraphDescriptionTests.cpp', 'i18n/catalog.json', 'src/pipeline/EnhanceGraph.cpp', 'tests/qml/quick/tst_components.qml', 'include/graphicenhancement/gfx/FsrSrBackend.h', 'qml/GraphicEnhancement/VRow.qml', 'qml/GraphicEnhancement/ColorPage.qml', 'tests/integration/SettingsTransactionTests.cpp', 'include/graphicenhancement/engine/VideoPresenter.h', 'qml/GraphicEnhancement/SettingsPage.qml', 'include/graphicenhancement/engine/EnhancementSettings.h', 'AGENTS.md', 'src/engine/VideoPresenter.cpp', 'tests/qml/quick/tst_menu_layout.qml', 'scripts/acceptance/settings-sr-ui-build.py', 'qml/GraphicEnhancement/ChainControls.qml', 'docs/WORKLOG.md', 'qml/GraphicEnhancement/EnhancePage.qml', 'qml/GraphicEnhancement/VSliderValue.qml', 'include/graphicenhancement/pipeline/EnhanceGraph.h', 'src/ui/QmlPlayerBridge.cpp', 'scripts/acceptance/settings-sr-ui-gui-test.py', 'qml/GraphicEnhancement/VSelect.qml', 'scripts/acceptance/settings-sr-ui.qml', 'scripts/acceptance/settings-sr-ui-test.py'}
dirty = {p.decode('utf8') for p in git('ls-files', '-m', '-d', '--others', '--exclude-standard', '-z').split(b'\0') if p}
allowed.add('qml/GraphicEnhancement/ProPage.qml')
allowed.add('src/engine/VideoExportJob.cpp')
changed = {p.decode('utf8') for p in git('diff', '--name-only', start['base']).splitlines() if p}
assert (changed | dirty) <= allowed, (changed | dirty) - allowed
git('diff', '--check')
git('diff', '--cached', '--check')
label = sys.argv[1] if len(sys.argv) > 1 else 'audit'
assert re.fullmatch('[a-z0-9-]+', label)
report = {'baselineWorktreesUnchanged': len(start['worktrees']),
          'dirtyFilesUnchanged': sum(len(v['dirtyFiles']) for v in start['worktrees'].values()),
          'scopePass': True, 'changed': sorted(changed | dirty), 'mainHead': start['main'], 'base': start['base']}
(BASE/'reports'/TASK/(label+'.json')).write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf8')
print(json.dumps(report, ensure_ascii=False), flush=True)
