// Loaded only into a private test copy of Main.qml (production bridge).
// Drives a real recording: configure, start, act on schedule, stop, wait for
// the file, and print what the recorder reported. Config is JSON:
//   {dir, seconds, audio, fps, bitrate, hevc, effects:{...}, actions:[{at, do}]}
import QtQuick
import QtQuick.Window
Item {
    id: test
    property string config: "{}"
    property var cfg: JSON.parse(config)
    property int step: 0
    property int ticks: 0
    property int mark: 0
    property int done: 0
    property int rounds: 0
    function out(tag, value) { console.log("RECTEST", tag, typeof value === "string" ? value : JSON.stringify(value)) }
    function fail(why) { out("FAIL", why); Qt.quit() }
    function stateJson() {
        const s = graphicenhancement.recordingState || {}
        return { active: graphicenhancement.recording, frames: s.frames, dropped: s.dropped, seconds: s.seconds, files: s.files,
                 path: s.path, encoder: s.encoder, audio: s.audio, failed: s.failed, error: s.error, note: s.note, finishing: s.finishing }
    }
    function findControl(item, name) {
        if (item.objectName === name) return item
        for (const child of item.children || []) {
            const found = findControl(child, name)
            if (found) return found
        }
        return null
    }
    function control(name) { return findControl(test.Window.window.contentItem, name) }
    function clickRecord() {
        const mouse = control("pro-record-mouse")
        if (!mouse || !mouse.enabled) { fail("record control unavailable"); return false }
        // Invoke the production MouseArea signal. This checks the real handler
        // and timer, not native hit-testing or physical pointer coordinates.
        mouse.clicked(null)
        return true
    }
    function act(name) {
        out("ACTION", name)
        if (name === "colour-on") graphicenhancement.colorEnabled = true
        else if (name === "colour-off") graphicenhancement.colorEnabled = false
        else if (name === "nr-on") graphicenhancement.nrEnabled = true
        else if (name === "nr-off") graphicenhancement.nrEnabled = false
        else if (name === "sr-on") { graphicenhancement.srTargetIndex = 2; graphicenhancement.srEnabled = true }
        else if (name === "sr-off") graphicenhancement.srEnabled = false
        else if (name === "fg-on") { graphicenhancement.fgMultiplier = test.cfg.fgMultiplier || 2; graphicenhancement.fgEnabled = true }
        else if (name === "fg-off") graphicenhancement.fgEnabled = false
        else if (name === "pause" || name === "resume") graphicenhancement.togglePlayPause()
        else if (name === "seek") graphicenhancement.seekTo(2)
        else if (name === "stop-playback") graphicenhancement.stopPlayback()
    }
    Connections {
        target: graphicenhancement
        function onNotice(message, error) { console.log("RECTEST notice", error, message) }
    }
    Timer {
        interval: 100; repeat: true; running: true
        onTriggered: {
            ++test.ticks
            if (test.ticks > 2400) { test.fail("deadline"); return }
            if (test.step === 0) {
                if (!graphicenhancement.hasSource || test.ticks < 30 || !test.cfg.dir) return
                graphicenhancement.nodeMode = 0
                graphicenhancement.muted = !!test.cfg.muted
                const fx = test.cfg.effects || {}
                graphicenhancement.nrEnabled = !!fx.nr
                graphicenhancement.srEnabled = false
                if (test.cfg.fsr) graphicenhancement.videoSrQuality = 5
                graphicenhancement.colorEnabled = !!fx.colour
                if (fx.sr) { graphicenhancement.srTargetIndex = fx.srTarget || 2; graphicenhancement.srEnabled = true }
                if (fx.fg) { graphicenhancement.fgMultiplier = fx.fg; graphicenhancement.fgEnabled = true } else graphicenhancement.fgEnabled = false
                if (!test.cfg.noRecord) {
                    if (!test.cfg.expectFailure && !graphicenhancement.setPreference("recordDir", test.cfg.dir)) { test.fail("recordDir rejected"); return }
                    if (test.cfg.expectFailure && graphicenhancement.recordingDirectory !== test.cfg.dir) { test.fail("invalid-directory profile not loaded"); return }
                    graphicenhancement.setPreference("recordAudio", test.cfg.audio !== false)
                    graphicenhancement.setPreference("recordFps", test.cfg.fps || 0)
                    graphicenhancement.setPreference("recordBitrateMbps", test.cfg.bitrate || 0)
                    graphicenhancement.setPreference("recordHevc", !!test.cfg.hevc)
                }
                test.mark = test.ticks; test.step = 1
            } else if (test.step === 1) {
                // Let the effect settings apply before the file opens.
                if (test.ticks - test.mark < (test.cfg.settle || 30)) return
                if (test.cfg.noRecord) { test.mark = test.ticks; test.step = 5; return }
                if (test.cfg.useButton) {
                    if (!test.clickRecord()) return
                    if (test.control("pro-record-control").countdown !== 3) { test.fail("countdown did not start"); return }
                    test.mark = test.ticks; test.step = 6; return
                }
                graphicenhancement.startRecording()
                test.mark = test.ticks; test.step = 2
            } else if (test.step === 6) {
                if (test.ticks - test.mark < 12) return
                if (test.control("pro-record-control").countdown !== 2) { test.fail("countdown did not tick"); return }
                test.clickRecord()
                if (test.control("pro-record-control").countdown !== 0 || graphicenhancement.recording) { test.fail("countdown cancellation failed"); return }
                test.out("BUTTON_CANCELLED", test.stateJson())
                test.clickRecord()
                test.mark = test.ticks; test.step = 2
            } else if (test.step === 2) {
                const s = graphicenhancement.recordingState || {}
                if (!graphicenhancement.recording && test.cfg.expectFailure) { test.out("FINAL", test.stateJson()); Qt.quit(); return }
                if (!graphicenhancement.recording) { if (test.ticks - test.mark > 50) test.fail("not recording: " + JSON.stringify(test.stateJson())); return }
                if (!(s.frames > 0)) { if (test.ticks - test.mark > 100) test.fail("no frame reached the encoder"); return }
                test.out("STARTED", test.stateJson())
                test.mark = test.ticks; test.done = 0; test.step = 3
            } else if (test.step === 3) {
                const elapsed = (test.ticks - test.mark) / 10
                const actions = test.cfg.actions || []
                while (test.done < actions.length && elapsed >= actions[test.done].at) { test.act(actions[test.done].do); ++test.done }
                if (!graphicenhancement.recording && test.cfg.expectStop !== true) { test.fail("recording stopped early: " + JSON.stringify(test.stateJson())); return }
                if (elapsed < test.cfg.seconds && graphicenhancement.recording) return
                test.out("BEFORE_STOP", test.stateJson())
                if (graphicenhancement.recording) { if (test.cfg.useButton) test.clickRecord(); else graphicenhancement.stopRecording() }
                test.mark = test.ticks; test.step = 4
            } else if (test.step === 5) {
                const elapsed = (test.ticks - test.mark) / 10
                const actions = test.cfg.actions || []
                while (test.done < actions.length && elapsed >= actions[test.done].at) { test.act(actions[test.done].do); ++test.done }
                if (elapsed < test.cfg.seconds) return
                test.out("FINAL", test.stateJson()); Qt.quit()
            } else if (test.step === 4) {
                const s = graphicenhancement.recordingState || {}
                if (graphicenhancement.recording || s.finishing) { if (test.ticks - test.mark > 200) test.fail("file not finished"); return }
                test.out("FINAL", test.stateJson())
                if (++test.rounds < (test.cfg.repeats || 1)) { test.mark = test.ticks; test.step = 1; return }
                Qt.quit()
            }
        }
    }
}
