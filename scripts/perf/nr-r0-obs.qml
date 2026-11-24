import QtQuick
Item {
    id: probe
    property var appWindow: Window.window
    property string commandFile: ""
    property int sequence: -1
    property bool configured: false
    Timer { id: exitResize; interval: 50; onTriggered: { console.log("OBS_UI_PASS"); Qt.quit() } }
    function require(ok, why) { if (!ok) { console.log("OBS_UI_FAIL", why); Qt.exit(3) } }
    Timer {
        interval: 500; running: true; repeat: true
        onTriggered: {
            if (!probe.commandFile) return
            const request = new XMLHttpRequest()
            request.open("GET", probe.commandFile, false); request.send()
            const c = JSON.parse(request.responseText)
            if (!probe.configured) {
                probe.appWindow.title = c.title
                graphicenhancement.muted = true; graphicenhancement.lowLatency = false
                graphicenhancement.srEnabled = false; graphicenhancement.fgEnabled = false
                graphicenhancement.colorEnabled = false; graphicenhancement.videoHdr = false
                graphicenhancement.nrEnabled = true
                const index = graphicenhancement.nrLayers[0].index
                probe.require(graphicenhancement.setNrLayerParameter(index, "runtime", 0), "runtime")
                probe.require(graphicenhancement.setNrLayerParameter(index, "sizePolicy", 1), "native NR")
                probe.require(graphicenhancement.setNrLayerParameter(index, "temporal", 0), "temporal")
                graphicenhancement.openPath(c.media)
                probe.configured = true
            }
            probe.require(!graphicenhancement.failed, "engine failed")
            if (probe.sequence !== c.sequence) {
                probe.sequence = c.sequence
                if (c.action === "pause" && !graphicenhancement.paused) graphicenhancement.togglePlayPause()
                if (c.action === "resume" && graphicenhancement.paused) graphicenhancement.togglePlayPause()
                if (c.action === "resize") { probe.appWindow.width = 1000; probe.appWindow.height = 700 }
                if (c.action === "fullscreen" && !probe.appWindow.fullscreen) probe.appWindow.toggleFullscreen()
                if (c.action === "windowed" && probe.appWindow.fullscreen) probe.appWindow.toggleFullscreen()
                if (c.action === "exit-resize") { probe.appWindow.width = 1100; probe.appWindow.height = 750; exitResize.start() }
                if (c.action === "quit") { console.log("OBS_UI_PASS"); Qt.quit() }
                console.log("OBS_UI_ACTION", c.action, probe.sequence)
            }
            console.log("OBS_UI_SAMPLE", JSON.stringify({position:graphicenhancement.position, paused:graphicenhancement.paused,
                nr:graphicenhancement.nrActive, failed:graphicenhancement.failed, fullscreen:probe.appWindow.fullscreen,
                width:probe.appWindow.width, height:probe.appWindow.height}))
        }
    }
}
