// Private real-player fixture, loaded only by picture-rotation.py.
import QtQuick
import QtQuick.Window

Item {
    id: probe
    property string config: "{}"
    readonly property var cfg: JSON.parse(config)
    property var actions: []
    property int at: -1
    property int ticks: 0
    property int expected: 0
    property int expectedMetadata: 0
    function out(label, data) { console.log("ROTATION", label, JSON.stringify(data)) }
    function check(ok, why) { if (!ok) { out("FAIL", why); Qt.quit(); throw new Error(why) } }
    function find(item, name) {
        if (!item) return null
        if (item.objectName === name) return item
        for (const child of item.children || []) { const f = find(child, name); if (f) return f }
        return null
    }
    function button(cine) { return find(cine ? fullBar.contentItem : root.contentItem, cine ? "cine-rotate" : "pro-rotate") }
    function state() {
        const r = root.videoRect()
        return { page: root.page, fullscreen: root.fullscreen, rotation: graphicenhancement.previewRotation,
                 metadata: graphicenhancement.sourceRotation, aspect: graphicenhancement.previewAspect, film: root.filmAspect,
                 width: root.width, height: root.height, rect: r, paused: graphicenhancement.paused }
    }
    function verify() {
        check(graphicenhancement.previewRotation === expected, "rotation state " + JSON.stringify(state()))
        check(graphicenhancement.sourceRotation === expectedMetadata, "metadata was overwritten")
        check(Math.abs(graphicenhancement.previewAspect - (expected % 180 ? 1 / cfg.aspect : cfg.aspect)) < .001, "rotated aspect")
        if (root.page === "min" && !root.screenSized) {
            check(Math.abs(root.filmAspect - graphicenhancement.previewAspect) < .001, "cinema stale aspect")
            check(Math.abs(root.videoRect().height - root.height) <= 2, "cinema native viewport stale")
            check(root.height <= root.maxPictureHeight + 2, "portrait window runs off screen")
        }
        const r = root.videoRect()
        check(r.width > 0 && r.height > 0 && r.x >= -1 && r.y >= -1 && r.x + r.width <= root.width + 2 && r.y + r.height <= root.height + 2, "video overlaps controls")
        out("STATE", state())
    }
    function turn(cine) {
        const b = button(cine)
        check(b && b.enabled && b.visible, "rotation button unavailable")
        const owner = cine ? fullBar.contentItem : root.contentItem
        const p = b.mapToItem(owner, 0, 0)
        check(p.x >= 0 && p.x + b.width <= owner.width && p.y >= 0 && p.y + b.height <= owner.height, "rotation button clipped")
        // This fixture drives the production signal; QtQuick tests inject real
        // mouse events into the shared button separately.
        b.clicked()
        expected = (expected + 90) % 360
    }
    function add(fn) { actions.push(fn) }
    function setup() {
        expectedMetadata = cfg.metadata || 0
        if (cfg.recordDir) add(() => {
            check(graphicenhancement.setPreference("recordDir", cfg.recordDir), "record directory rejected")
            graphicenhancement.startRecording()
        })
        add(() => { verify(); turn(false) })
        add(() => { verify(); graphicenhancement.togglePlayPause() })
        add(() => { check(graphicenhancement.paused, "pause failed"); turn(false) })
        add(() => { verify(); graphicenhancement.seekTo(2) })
        add(() => { verify(); check(graphicenhancement.paused, "seek unpaused"); graphicenhancement.togglePlayPause() })
        add(() => { verify(); turn(false) })
        add(() => { verify(); turn(false) })
        add(() => { verify(); root.goPage("min") })
        for (let n = 0; n < 4; ++n) add(() => { verify(); turn(true) })
        add(() => { verify(); root.toggleFullscreen() })
        for (let n = 0; n < 4; ++n) add(() => { verify(); root.pointerActivity(); turn(true) })
        add(() => { verify(); root.toggleFullscreen() })
        add(() => { verify(); root.goPage("pro") })
        add(() => { verify(); root.toggleFullscreen() })
        add(() => { verify(); root.pointerActivity(); turn(true) })
        add(() => { verify(); root.toggleFullscreen() })
        add(() => { verify(); turn(false) })
        add(() => { verify(); turn(false) })
        add(() => { verify(); turn(false) })
        // All aspect choices must survive turns without the polling pass
        // resetting the user's offset or inverting metadata a second time.
        for (let mode = 0; mode < 7; ++mode) {
            add(() => {
                graphicenhancement.aspectMode = mode
                const base = graphicenhancement.previewAspect
                turn(false)
                check(Math.abs(graphicenhancement.previewAspect * base - 1) < .001, "aspect mode " + mode)
            })
            add(() => {
                check(graphicenhancement.previewRotation === 90, "aspect polling reset rotation")
                for (let n = 0; n < 3; ++n) turn(false)
            })
        }
        if (cfg.recordDir) {
            add(() => { check(graphicenhancement.recordingState.frames > 0 && !graphicenhancement.recordingState.failed, "recording failed during rotation"); graphicenhancement.stopRecording() })
            add(() => { check(!graphicenhancement.recordingState.finishing, "recording did not finish"); out("RECORDING", graphicenhancement.recordingState) })
        }
        add(() => { graphicenhancement.aspectMode = 0; verify(); turn(false); graphicenhancement.openPath(cfg.media) })
        add(() => { expected = 0; verify(); check(graphicenhancement.hasSource, "reopen failed"); out("PASS", state()); Qt.quit() })
    }
    Timer {
        interval: 100; repeat: true; running: true
        onTriggered: {
            ++probe.ticks
            if (probe.ticks > 1800) { probe.check(false, "fixture timeout"); return }
            if (probe.at < 0) {
                if (!graphicenhancement.hasSource || !graphicenhancement.sourceWidth || probe.ticks < 20) return
                graphicenhancement.nrEnabled = false; graphicenhancement.srEnabled = false; graphicenhancement.fgEnabled = false
                graphicenhancement.aspectMode = 0
                probe.setup(); probe.at = 0; probe.ticks = 0
            }
            if (probe.ticks % 12 !== 0) return
            if (probe.at < probe.actions.length) probe.actions[probe.at++]()
        }
    }
}
