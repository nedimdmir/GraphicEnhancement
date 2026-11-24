import QtQuick
Item {
    id: test
    property string phase: "edit"
    property int step: 0
    property int ticks: 0
    property int nrIndex: -1
    property real beginPosition: 0
    function require(ok, message) {
        if (!ok) throw new Error(message)
        console.log("INACTIVE_UI_CHECK", message)
    }
    function closed() {
        require(!graphicenhancement.nrEnabled && !graphicenhancement.srEnabled && !graphicenhancement.fgEnabled && !graphicenhancement.colorEnabled && !graphicenhancement.videoHdr, "effects stay disabled")
    }
    function values() {
        const nr = graphicenhancement.nrLayers[0]
        require(nr.style === 2 && nr.sizePolicy === 3 && nr.temporal, "disabled NR values retained")
        require(graphicenhancement.videoSrQuality === 4 && graphicenhancement.srTargetIndex === 1, "disabled SR values retained")
        require(graphicenhancement.vfgQuality === 2 && graphicenhancement.videoHdrParams.peakNits === 800, "disabled VFG and Video HDR values retained")
        require(Math.abs(graphicenhancement.colorExposure - .4) < .001, "disabled colour value retained")
        require(graphicenhancement.nrHoldStrength === 0 && Math.abs(graphicenhancement.nrHoldTolerance - .12) < .001, "disabled stabiliser tolerance retained")
    }
    Timer {
        interval: 500; repeat: true; running: true
        onTriggered: { try {
            if (++test.ticks > 100) throw new Error("deadline step=" + test.step)
            if (test.step === 0) {
                if (test.ticks < 4) return
                test.closed()
                if (test.phase === "invalid") {
                    test.require(graphicenhancement.nrHoldStrength === 0 && Math.abs(graphicenhancement.nrHoldTolerance - .02) < .001, "invalid stabiliser preferences keep defaults")
                    console.log("INACTIVE_UI_PASS invalid"); Qt.quit(); return
                }
                test.require(graphicenhancement.nrLayers.length > 0, "real list NR instance exists")
                test.nrIndex = graphicenhancement.nrLayers[0].index
                if (test.phase === "restore") { test.values(); test.require(!graphicenhancement.running, "restoring private settings does not auto-play"); console.log("INACTIVE_UI_PASS restore"); Qt.quit(); return }
                test.require(graphicenhancement.nrHoldStrength === 0 && Math.abs(graphicenhancement.nrHoldTolerance - .02) < .001, "old profile keeps stabiliser disabled by default")
                graphicenhancement.volume = 0
                graphicenhancement.openPath("E:/Ai/知识/小七姐/GTAVI_An_Extended_Look_4K_Native.mp4")
                test.step = 1; return
            }
            test.require(!graphicenhancement.failed, "real player has no error")
            if (test.step === 1) {
                if (!graphicenhancement.running || graphicenhancement.position < 1 || graphicenhancement.applying) return
                test.beginPosition = graphicenhancement.position
                graphicenhancement.logUi("inactive-effects-test", "BEGIN inactive UI edits")
                test.step = 2; return
            }
            test.closed()
            if (test.step === 2) test.require(graphicenhancement.setNrLayerParameter(test.nrIndex, "style", 2), "edit disabled NR style")
            else if (test.step === 3) test.require(graphicenhancement.setNrLayerParameter(test.nrIndex, "sizePolicy", 3), "edit disabled NR resolution")
            else if (test.step === 4) test.require(graphicenhancement.setNrLayerParameter(test.nrIndex, "temporal", 1), "edit disabled NR history option")
            else if (test.step === 5) graphicenhancement.videoSrQuality = 4
            else if (test.step === 6) graphicenhancement.srTargetIndex = 1
            else if (test.step === 7) graphicenhancement.vfgQuality = 2
            else if (test.step === 8) test.require(graphicenhancement.setVideoHdrParameter("peakNits", 800), "edit disabled Video HDR")
            else if (test.step === 9) graphicenhancement.colorExposure = .4
            else if (test.step === 10) graphicenhancement.nrHoldTolerance = .12
            else {
                if (graphicenhancement.applying) return
                test.values()
                test.require(graphicenhancement.position > test.beginPosition + 3, "actual media time advances throughout GUI edits")
                graphicenhancement.logUi("inactive-effects-test", "END inactive UI edits")
                console.log("INACTIVE_UI_PASS edit")
                Qt.quit(); return
            }
            ++test.step
        } catch(e) { console.log("INACTIVE_UI_FAIL", String(e)); Qt.quit() } }
    }
}
