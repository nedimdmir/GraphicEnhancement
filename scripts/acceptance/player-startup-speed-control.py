"""Guard this field repair against an immutable, external source baseline."""
import hashlib
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASELINE = Path('E:/项目/GraphicEnhancement/archives/player-startup-speed-20261003/scope-baseline.json')
ALLOWED = {'qml/GraphicEnhancement/CineBar.qml', 'scripts/acceptance/player-startup-speed-control.py', 'include/graphicenhancement/sink/WasapiAudioSink.h', 'scripts/acceptance/player-startup-speed-build.py', 'include/graphicenhancement/ui/QmlPlayerBridge.h', 'src/ui/QmlPlayerBridge.cpp', 'qml/GraphicEnhancement/PlaybackRateButton.qml', 'include/graphicenhancement/engine/EngineController.h', 'src/sink/WasapiAudioSink.cpp', 'tests/qml/quick/tst_components.qml', 'THIRD_PARTY_NOTICES.md', 'CMakeLists.txt', 'scripts/package-qml-release.py', 'docs/RELEASE_NOTES_2.0.1.md', 'src/engine/EngineController.cpp', 'src/ui/PlayerUiFacade.cpp', 'tests/integration/AudioPlaybackRateTests.cpp', 'qml/GraphicEnhancement/qmldir', 'apps/graphicenhancement-qml/main.cpp', 'qml/GraphicEnhancement/SettingsPage.qml', 'i18n/catalog.json', 'scripts/acceptance/player-startup-speed-tests.py', 'docs/WORKLOG.md', 'docs/PLAYER_STARTUP_SPEED_PLAN_2026-10-03.md', 'qml/GraphicEnhancement/ProPage.qml', 'docs/CURRENT_STATUS.md'}

baseline = json.loads(BASELINE.read_text(encoding='utf8'))
ALLOWED.update({
    'src/xbox/WebRtcSession.cpp', 'include/graphicenhancement/xbox/WebRtcSession.h',
    'include/graphicenhancement/xbox/Protocol.h', 'src/source/XboxSessionSource.cpp',
    'include/graphicenhancement/source/XboxSessionSource.h',
    'src/source/CaptureCardSource.cpp', 'include/graphicenhancement/source/CaptureTiming.h',
    'include/graphicenhancement/engine/LivePresentationTiming.h', 'tests/unit/LivePresentationTimingTests.cpp',
    'tests/xbox/XboxTests.cpp', 'tests/qml/quick/tst_playback_rate.qml',
})
tracked = subprocess.check_output(['git', 'ls-files', '-z'], cwd=ROOT).decode().split('\0')
new = subprocess.check_output(['git', 'ls-files', '--others', '--exclude-standard', '-z'], cwd=ROOT).decode().split('\0')
current = {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest()
           for p in tracked + new if p and (ROOT / p).is_file()}
changed = {p for p in current.keys() | baseline['files'].keys()
           if current.get(p) != baseline['files'].get(p)}
unexpected = {p for p in changed - ALLOWED if not p.startswith('third_party/soundtouch/')}
print('FIELD SCOPE', 'FAIL' if unexpected else 'PASS', len(changed), 'changed files')
if unexpected:
    print('\n'.join(sorted(unexpected)))
raise SystemExit(bool(unexpected))
