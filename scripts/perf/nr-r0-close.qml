import QtQuick
Item {
    id: probe
    property var appWindow: Window.window
    property string media: ""
    property string action: ""
    property int phase: 0
    property double phaseAt: 0
    property double started: Date.now()
    function require(ok, why) { if (!ok) { console.log("CLOSE_UI_FAIL", why); Qt.exit(3); throw new Error(why) } }
    Timer {
        interval: 100; running: true; repeat: true
        onTriggered: {
            const now = Date.now()
            probe.require(now-probe.started < 55000, "timeout")
            if (!probe.media) return
            if (probe.phase === 0) {
                graphicenhancement.muted = true; graphicenhancement.lowLatency = false
                graphicenhancement.videoHdr = false; graphicenhancement.colorEnabled = false
                graphicenhancement.nrEnabled = true; graphicenhancement.srEnabled = false; graphicenhancement.fgEnabled = false
                probe.require(graphicenhancement.duplicateNrLayer(graphicenhancement.nrLayers[0].index) >= 0, "duplicate")
                for (let layer of graphicenhancement.nrLayers) {
                    probe.require(graphicenhancement.setNrLayerParameter(layer.index,"runtime",0), "runtime")
                    probe.require(graphicenhancement.setNrLayerParameter(layer.index,"sizePolicy",0), "1080 cap")
                    probe.require(graphicenhancement.setNrLayerParameter(layer.index,"temporal",0), "temporal")
                }
                graphicenhancement.videoSrQuality = 0; graphicenhancement.srTargetIndex = 2; graphicenhancement.srEnabled = true
                graphicenhancement.fgBackendName = "dlss"; graphicenhancement.fgMultiplier = 2; graphicenhancement.fgEnabled = true
                graphicenhancement.openPath(probe.media); probe.phase = 1; return
            }
            probe.require(!graphicenhancement.failed, "engine failure")
            if (probe.phase === 1) {
                if (!graphicenhancement.nrActive || !graphicenhancement.srActive || !graphicenhancement.fgActive || graphicenhancement.position < 2) return
                if (probe.action === "fsr3" || probe.action === "xess" || probe.action === "vfg") graphicenhancement.fgBackendName = probe.action
                else if (probe.action === "nr-runtime") probe.require(graphicenhancement.setNrLayerParameter(graphicenhancement.nrLayers[0].index,"runtime",2), "SF-v2 switch")
                else if (probe.action === "nr-size") probe.require(graphicenhancement.setNrLayerParameter(graphicenhancement.nrLayers[0].index,"sizePolicy",3), "size switch")
                else if (probe.action === "nr-layer") probe.require(graphicenhancement.duplicateNrLayer(graphicenhancement.nrLayers[0].index) >= 0, "third layer")
                else if (probe.action === "stop") graphicenhancement.stopPlayback()
                else probe.require(false,"unknown action")
                probe.phaseAt = now; probe.phase = 2; return
            }
            if (probe.phase === 2 && now-probe.phaseAt >= 200) {
                console.log("CLOSE_UI_QUIT", probe.action, "applying="+graphicenhancement.applying, graphicenhancement.runStatusDetail)
                console.log("CLOSE_UI_PASS"); Qt.quit(); probe.phase = 3
            }
        }
    }
}
