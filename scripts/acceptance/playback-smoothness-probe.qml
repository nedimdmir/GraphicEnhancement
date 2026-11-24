import QtQuick
Item {
    id: probe
    property var appWindow: Window.window
    property string media: ""
    property string mode: "plain"
    property int limit: 220
    property int ticks: 0
    property double previous: 0
    property var intervals: []
    property double started: Date.now()
    property int notifications: 0
    Connections {
        target: graphicenhancement
        ignoreUnknownSignals: true
        function onFgChoicesChanged() { ++probe.notifications }
        function onNotice(text, error) { console.log("SMOOTH_NOTICE", text, error) }
    }
    Timer {
        interval: 16; running: true; repeat: true
        onTriggered: {
            const now = Date.now()
            if (probe.previous) probe.intervals.push(now - probe.previous)
            probe.previous = now
        }
    }
    Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: {
            ++probe.ticks
            if (probe.ticks === 1) {
                probe.appWindow.width = 1280; probe.appWindow.height = 800
                graphicenhancement.muted = true
                graphicenhancement.nrEnabled = false; graphicenhancement.srEnabled = false; graphicenhancement.fgEnabled = false
                if (probe.mode === "heavy") {
                    graphicenhancement.nrEnabled = true; graphicenhancement.srEnabled = true
                    graphicenhancement.videoSrQuality = 4; graphicenhancement.srTargetIndex = 2
                    graphicenhancement.fgBackendName = "dlss"; graphicenhancement.fgMultiplier = 2; graphicenhancement.fgEnabled = true
                }
                if (probe.mode === "dlss6" || probe.mode === "vfg4") {
                    graphicenhancement.fgBackendName = probe.mode === "dlss6" ? "dlss" : "vfg"
                    graphicenhancement.fgMultiplier = probe.mode === "dlss6" ? 6 : 4
                    graphicenhancement.vfgQuality = 1; graphicenhancement.fgEnabled = true
                }
                graphicenhancement.openPath(probe.media)
            }
            const a = probe.intervals.sort((a,b) => a-b)
            const percentile = p => a.length ? a[Math.min(a.length-1,Math.floor(a.length*p))] : 0
            console.log("SMOOTH_SAMPLE", JSON.stringify({seconds:(Date.now()-probe.started)/1000,
                active:probe.appWindow.active, visibility:probe.appWindow.visibility,
                p50:percentile(.5), p95:percentile(.95), max:percentile(1), count:a.length,
                fgNotifications:probe.notifications, running:graphicenhancement.running, position:graphicenhancement.position,
                fps:graphicenhancement.submitFps, detail:graphicenhancement.runStatusDetail,
                nr:graphicenhancement.nrActive,sr:graphicenhancement.srActive,fg:graphicenhancement.fgActive,failed:graphicenhancement.failed}))
            probe.intervals=[]; probe.notifications=0
            if (probe.ticks === 6 && graphicenhancement.effectCapabilities !== undefined) {
                const begin=Date.now(); let available=0
                for(let k=0;k<100;++k) available += graphicenhancement.effectCapabilities.nr0.available ? 1 : 0
                console.log("SMOOTH_GETTER_100", Date.now()-begin, available)
            }
            if (probe.ticks >= probe.limit) Qt.quit()
        }
    }
}
