import QtQuick
Item {
    id: probe
    property var appWindow: Window.window
    property var paths: []
    property int index: -1
    property int ticks: 0
    property bool recorded: false
    function openNext() {
        appWindow.page = "min"; appWindow.width = 720
        appWindow.x = 50; appWindow.y = 50
        graphicenhancement.openPath(paths[index]); ticks = 0; recorded = false
    }
    Timer {
        interval: 150; repeat: true; running: true
        onTriggered: {
            try {
                ++probe.ticks
                if (probe.index < 0) {
                    if (probe.ticks < 3) return
                    graphicenhancement.setPreference("reducedMotion", true)
                    graphicenhancement.muted = true; graphicenhancement.nrEnabled = false; graphicenhancement.srEnabled = false
                    graphicenhancement.fgEnabled = false; graphicenhancement.colorEnabled = false; graphicenhancement.videoHdr = false
                    probe.index = 0; probe.openNext(); return
                }
                if (graphicenhancement.failed || probe.ticks > 100) throw new Error("video failed or timed out")
                if (!probe.recorded && probe.ticks >= 14 && graphicenhancement.running && !graphicenhancement.applying) {
                    console.log("GUI_ROTATION " + JSON.stringify({index:probe.index,aspect:graphicenhancement.previewAspect}))
                    probe.recorded = true; probe.ticks = 0
                } else if (probe.recorded && probe.ticks > 8) {
                    ++probe.index
                    if (probe.index >= probe.paths.length) { console.log("GUI_ROTATION_DONE"); graphicenhancement.stopPlayback(); Qt.quit(); return }
                    probe.openNext()
                }
            } catch(e) { console.error("GUI_ROTATION_FAIL " + e.message); Qt.exit(3) }
        }
    }
}
