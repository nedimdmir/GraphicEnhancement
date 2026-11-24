import QtQuick

// Owned test loader: uses only the existing public QML bridge, no input hooks.
Item {
    id: probe
    property string media: ""
    property string group: "nr"
    property bool started: false
    property int cycle: 0
    property bool awaiting: false
    property double changeAt: 0
    property double startedAt: Date.now()
    property double settledAt: 0
    property bool targetOn: true
    property int targetLayers: 1
    property int targetPolicy: 0
    property int targetRuntime: 0
    function require(value, why) {
        if (!value) { console.log("CORE_UI_FAIL", why); Qt.exit(3) }
    }
    function change() {
        targetOn = group === "nr" ? cycle % 2 === 1 : cycle % 2 === 0
        if (group === "nr") graphicenhancement.nrEnabled = targetOn
        if (group === "sr") graphicenhancement.srEnabled = targetOn
        if (group === "fg") graphicenhancement.fgEnabled = targetOn
        if (group === "runtime") {
            targetRuntime = cycle % 2 ? 0 : 2
            require(graphicenhancement.setNrLayerParameter(graphicenhancement.nrLayers[0].index, "runtime", targetRuntime), "runtime request")
        }
        if (group === "sizes") {
            targetPolicy = [1, 3, 2][cycle % 3]
            require(graphicenhancement.setNrLayerParameter(graphicenhancement.nrLayers[0].index, "sizePolicy", targetPolicy), "size request")
        }
        if (group === "layers") {
            targetLayers = 1 + (cycle + 1) % 3
            for (let i=0; i<graphicenhancement.nrLayers.length; ++i)
                require(graphicenhancement.setEffectEnabled(graphicenhancement.nrLayers[i].index, i < targetLayers), "enable layer")
        }
        changeAt = Date.now(); awaiting = true
        console.log("CORE_UI_CHANGE", JSON.stringify({group:group, cycle:cycle, on:targetOn,
            layers:targetLayers, policy:targetPolicy, runtime:targetRuntime, position:graphicenhancement.position}))
    }
    function matches() {
        if (group === "nr") return graphicenhancement.nrActive === targetOn
        if (group === "sr") return graphicenhancement.nrActive && graphicenhancement.srActive === targetOn
        if (group === "fg") return graphicenhancement.nrActive && graphicenhancement.fgActive === targetOn
        if (group === "runtime") return graphicenhancement.nrActive && graphicenhancement.nrLayers[0].runtime === targetRuntime
        if (group === "sizes") return graphicenhancement.nrActive && graphicenhancement.nrLayers[0].sizePolicy === targetPolicy
        if (group === "layers") return graphicenhancement.nrActive && graphicenhancement.nrLayers.filter(x=>x.enabled).length === targetLayers
        return graphicenhancement.nrActive
    }
    Timer {
        interval: 200; running: true; repeat: true
        onTriggered: {
            require(!graphicenhancement.failed, "engine failure")
            require(Date.now()-probe.startedAt < 250000, "timeout")
            if (!probe.started) {
                probe.started = true
                graphicenhancement.muted = true; graphicenhancement.lowLatency = false
                graphicenhancement.nrEnabled = true; graphicenhancement.srEnabled = false; graphicenhancement.fgEnabled = false
                graphicenhancement.videoHdr = false; graphicenhancement.colorEnabled = false; graphicenhancement.videoSrQuality = 0
                graphicenhancement.srTargetIndex = 2; graphicenhancement.fgBackendName = "dlss"; graphicenhancement.fgMultiplier = 2
                // Selecting a multiplier intentionally enables FG in the
                // product bridge; reset it after configuring the saved level.
                graphicenhancement.fgEnabled = false
                while (graphicenhancement.nrLayers.length < (probe.group === "layers" ? 3 : 1))
                    require(graphicenhancement.duplicateNrLayer(graphicenhancement.nrLayers[0].index)>=0,"duplicate NR")
                for (let i=0;i<graphicenhancement.nrLayers.length;++i) {
                    require(graphicenhancement.setNrLayerParameter(graphicenhancement.nrLayers[i].index,"temporal",0),"temporal")
                    require(graphicenhancement.setNrLayerParameter(graphicenhancement.nrLayers[i].index,"sizePolicy",0),"initial size")
                    require(graphicenhancement.setEffectEnabled(graphicenhancement.nrLayers[i].index,i===0),"initial enable")
                }
                graphicenhancement.openPath(probe.media)
                console.log("CORE_UI_INITIAL",JSON.stringify({group:probe.group,fg:graphicenhancement.fgEnabled,
                    multiplier:graphicenhancement.fgMultiplier,sr:graphicenhancement.srEnabled,layers:graphicenhancement.nrLayers}))
                return
            }
            if (!graphicenhancement.running || graphicenhancement.applying || graphicenhancement.position <= 0) return
            if (probe.awaiting) {
                if (!probe.matches()) return
                console.log("CORE_UI_SETTLED", JSON.stringify({group:probe.group,cycle:probe.cycle,
                    observedBridgeMs:Date.now()-probe.changeAt, position:graphicenhancement.position, nr:graphicenhancement.nrActive,
                    sr:graphicenhancement.srActive,fg:graphicenhancement.fgActive,layers:graphicenhancement.nrLayers,detail:graphicenhancement.runStatusDetail}))
                probe.awaiting = false; probe.settledAt = Date.now(); ++probe.cycle
                if (probe.cycle>=20) {console.log("CORE_UI_PASS",probe.group);Qt.quit();return}
            }
            if (graphicenhancement.position>45) {graphicenhancement.seekTo(0);return}
            if (Date.now()-probe.settledAt<600) return
            probe.change()
        }
    }
}
