// Loaded only into a private test copy of Main.qml (production bridge).
// AMD field report 2026-10-22: SR cannot be turned off. Turns FSR SR on in list
// mode, then off, and logs what the interface and the engine report each time.
import QtQuick
Item {
    id: test
    property int step: 0
    property int ticks: 0
    property int mark: 0
    function state(tag) {
        console.log("SRTEST", tag, "srEnabled=" + graphicenhancement.srEnabled, "srActive=" + graphicenhancement.srActive,
                    "videoSrQuality=" + graphicenhancement.videoSrQuality, "status=" + graphicenhancement.statusText)
    }
    Connections {
        target: graphicenhancement
        function onNotice(message, error) { console.log("SRTEST notice", error, message) }
    }
    Timer {
        interval: 200; repeat: true; running: true
        onTriggered: {
            ++test.ticks
            if (test.ticks > 400) { console.log("SRTEST FAIL deadline"); Qt.quit(); return }
            if (test.step === 0) {
                if (!graphicenhancement.hasSource || test.ticks < 20) return
                graphicenhancement.nodeMode = 0
                graphicenhancement.nrEnabled = false
                graphicenhancement.fgEnabled = false
                graphicenhancement.videoSrQuality = 5
                graphicenhancement.srTargetIndex = 2
                graphicenhancement.srEnabled = true
                test.state("requested-on")
                test.mark = test.ticks; test.step = 1
            } else if (test.step === 1) {
                if (test.ticks - test.mark < 30) return
                test.state("after-on")
                graphicenhancement.srEnabled = false
                test.state("requested-off")
                test.mark = test.ticks; test.step = 2
            } else if (test.step === 2) {
                if (test.ticks - test.mark < 30) return
                test.state("after-off")
                console.log("SRTEST DONE")
                Qt.quit()
            }
        }
    }
}
