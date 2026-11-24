import QtQuick

// Isolated test-only loader; never distributed with the product.
Item {
    id: probe
    property var appWindow: Window.window
    property var config: ({})
    property string media: ""
    property int seconds: 50
    property int ticks: 0
    property double readyAt: 0
    property double previous: 0
    property var intervals: []
    property bool configured: false
    property bool expectSr: false
    property bool expectFg: false
    property int expectNr: 1
    property var expectedPolicies: []

    function require(value, why) {
        if (!value) { console.log("NR_PERF_FAIL", why); Qt.exit(3); throw new Error(why) }
    }
    Connections {
        target: graphicenhancement
        function onNotice(text, error) { console.log("NR_PERF_NOTICE", text, error) }
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
            if (!probe.configured) {
                probe.appWindow.width = 1280; probe.appWindow.height = 800
                graphicenhancement.muted = true; graphicenhancement.lowLatency = false
                graphicenhancement.nrEnabled = true; graphicenhancement.srEnabled = false; graphicenhancement.fgEnabled = false
                graphicenhancement.videoHdr = false; graphicenhancement.colorEnabled = false
                probe.expectNr = probe.config.layers || 1
                const policies = probe.config.policies || [1]
                probe.expectedPolicies = policies
                while (graphicenhancement.nrLayers.length < probe.expectNr)
                    probe.require(graphicenhancement.duplicateNrLayer(graphicenhancement.nrLayers[0].index) >= 0, "duplicate layer")
                for (let i = 0; i < probe.expectNr; ++i) {
                    const idx = graphicenhancement.nrLayers[i].index
                    probe.require(graphicenhancement.setNrLayerParameter(idx, "sizePolicy", policies[Math.min(i, policies.length-1)]), "size policy")
                    probe.require(graphicenhancement.setNrLayerParameter(idx, "runtime", 0), "Lecram runtime")
                    probe.require(graphicenhancement.setNrLayerParameter(idx, "temporal", probe.config.temporal ? 1 : 0), "temporal")
                }
                probe.expectSr = Boolean(probe.config.sr)
                if (probe.expectSr) {
                    graphicenhancement.videoSrQuality = 0 // actual DLSS SR, not RTX Video SR
                    graphicenhancement.srTargetIndex = 2; graphicenhancement.srEnabled = true
                }
                probe.expectFg = Boolean(probe.config.fg)
                if (probe.expectFg) {
                    graphicenhancement.fgBackendName = "dlss"; graphicenhancement.fgMultiplier = probe.config.multiplier || 2; graphicenhancement.fgEnabled = true
                }
                console.log("NR_PERF_CONFIG", JSON.stringify({config:probe.config, layers:graphicenhancement.nrLayers,
                    sr:graphicenhancement.srEnabled, srQuality:graphicenhancement.videoSrQuality, srTarget:graphicenhancement.srTargetIndex,
                    fg:graphicenhancement.fgEnabled, multiplier:graphicenhancement.fgMultiplier, backend:graphicenhancement.fgBackendName}))
                graphicenhancement.openPath(probe.media)
                probe.configured = true
            }
            probe.require(!graphicenhancement.failed, "engine failure")
            if (!probe.readyAt && graphicenhancement.running && graphicenhancement.position > 0 && graphicenhancement.nrActive &&
                graphicenhancement.srActive === probe.expectSr && graphicenhancement.fgActive === probe.expectFg) {
                probe.readyAt = Date.now()
                console.log("NR_PERF_READY", probe.readyAt)
            }
            const a = probe.intervals.sort((a,b) => a-b)
            const p = value => a.length ? a[Math.min(a.length-1,Math.floor(a.length*value))] : 0
            console.log("NR_PERF_SAMPLE", JSON.stringify({tick:probe.ticks, ready:probe.readyAt > 0,
                active:probe.appWindow.active, width:probe.appWindow.width, height:probe.appWindow.height,
                position:graphicenhancement.position, fps:graphicenhancement.submitFps, nr:graphicenhancement.nrActive, sr:graphicenhancement.srActive,
                fg:graphicenhancement.fgActive, uiTimerP50Ms:p(.5), uiTimerP95Ms:p(.95), uiTimerMaxMs:p(1),
                uiTimerSamples:a.length, detail:graphicenhancement.runStatusDetail}))
            probe.intervals = []
            if (probe.readyAt && Date.now() - probe.readyAt >= probe.seconds * 1000) {
                probe.require(graphicenhancement.nrLayers.length === probe.expectNr, "layer count changed")
                console.log("NR_PERF_PASS"); Qt.quit()
            }
            if (probe.ticks >= 250) { console.log("NR_PERF_FAIL", "timeout"); Qt.exit(4) }
        }
    }
}
