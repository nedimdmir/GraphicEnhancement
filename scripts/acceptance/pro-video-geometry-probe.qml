// Test-only driver loaded into a private copy of Main.qml by the companion script.
import QtQuick
Item {
    id: probe
    property var appWindow: Window.window
    property var cases: []
    property int index: -1
    property int ticks: 0
    property bool recorded: false
    property string media: ""
    function find(item, name) {
        if (!item) return null
        if (item.objectName === name) return item
        for (const child of (item.children || [])) {
            const hit = find(child, name)
            if (hit) return hit
        }
        return null
    }
    function rect(item) {
        const p = item.mapToItem(appWindow.contentItem, 0, 0)
        return { x: p.x, y: p.y, w: item.width, h: item.height }
    }
    function apply(c) {
        if (appWindow.fullscreen) appWindow.toggleFullscreen()
        appWindow.page = "pro"
        appWindow.width = c.width
        appWindow.height = c.height
        graphicenhancement.setPreference("language", c.language || "zh-CN")
        graphicenhancement.setPreference("listInspectorWidth", c.inspector || 376)
        graphicenhancement.contentRate = c.options ? 1 : 0
        graphicenhancement.displaySync = c.options ? 1 : 0
        graphicenhancement.outputCustomFps = 30
        graphicenhancement.outputRateMode = c.options ? 2 : 0
        graphicenhancement.playbackRate = c.options ? 0.5 : 1
        if (c.page === "min") appWindow.page = "min"
        if (c.fullscreen) appWindow.toggleFullscreen()
    }
    function record(c) {
        const content = appWindow.contentItem
        const host = find(content, "videoHost")
        const area = find(content, "videoArea")
        const bar = find(content, "pro-transport")
        const head = find(content, "pro-header")
        const options = find(content, "run-active-options")
        if (!host || !graphicenhancement.hasSource || graphicenhancement.failed) throw new Error("source/host unavailable")
        const row = { name: c.name, index: index, page: appWindow.page, qtDpr: Screen.devicePixelRatio,
            fullscreen: appWindow.fullscreen, window: {w: appWindow.width,h: appWindow.height},
            host: rect(host), options: graphicenhancement.runOptions, status: graphicenhancement.runStatus,
            submitFps: graphicenhancement.submitFps, applying: graphicenhancement.applying }
        if (appWindow.page === "pro" && !appWindow.fullscreen) {
            if (!area || !bar || !head) throw new Error("professional layout missing")
            row.area = rect(area); row.bar = rect(bar); row.header = rect(head)
            if (options) row.optionText = {rect: rect(options),text: options.text}
        }
        console.log("PRO_GEOMETRY " + JSON.stringify(row))
    }
    Timer {
        interval: 100; running: true; repeat: true
        onTriggered: {
            try {
                ++probe.ticks
                if (probe.index < 0) {
                    if (probe.ticks < 3) return
                    graphicenhancement.setPreference("reducedMotion", true)
                    graphicenhancement.nodeMode = 0; graphicenhancement.muted = true
                    graphicenhancement.nrEnabled = false; graphicenhancement.srEnabled = false
                    graphicenhancement.fgEnabled = false; graphicenhancement.videoHdr = false; graphicenhancement.colorEnabled = false
                    probe.index = 0; probe.apply(probe.cases[0])
                    // Open on the same callback as the page/size change, before a render.
                    graphicenhancement.openPath(probe.media)
                    probe.ticks = 0; return
                }
                if (probe.ticks > 180) throw new Error("timeout at " + probe.index)
                if (!probe.recorded) {
                    if (probe.ticks < 12 || !graphicenhancement.running || graphicenhancement.applying) return
                    probe.record(probe.cases[probe.index]); probe.recorded = true; probe.ticks = 0
                } else if (probe.ticks >= 5) {
                    ++probe.index
                    if (probe.index >= probe.cases.length) {
                        console.log("PRO_GEOMETRY_DONE")
                        graphicenhancement.stopPlayback(); Qt.quit(); return
                    }
                    probe.apply(probe.cases[probe.index]); probe.recorded = false; probe.ticks = 0
                }
            } catch(e) {
                console.error("PRO_GEOMETRY_FAIL " + e.message); Qt.exit(3)
            }
        }
    }
}
