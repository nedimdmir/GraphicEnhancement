import QtQuick
Item {
    id: probe
    property string media: ""
    property string expectedSaved: "normal"
    property bool started: false
    property int cycle: 0
    property bool awaiting: false
    property double changedAt: 0
    property double startedAt: Date.now()
    property string target: "normal"
    function require(ok, why) { if (!ok) { console.log("PRIORITY_UI_FAIL",why); Qt.exit(3) } }
    Timer {
        interval: 200; repeat: true; running: true
        onTriggered: {
            require(Date.now()-probe.startedAt<100000,"timeout")
            require(!graphicenhancement.failed,"engine failure")
            if (!probe.started) {
                probe.started=true
                require((graphicenhancement.preferences.gpuPriority||"normal")===probe.expectedSaved,"saved preference")
                require(!graphicenhancement.setPreference("gpuPriority","invalid"),"reject invalid priority")
                graphicenhancement.muted=true;graphicenhancement.lowLatency=false
                graphicenhancement.nrEnabled=true;graphicenhancement.srEnabled=false;graphicenhancement.fgEnabled=false
                graphicenhancement.videoHdr=false;graphicenhancement.colorEnabled=false
                require(graphicenhancement.setNrLayerParameter(graphicenhancement.nrLayers[0].index,"temporal",0),"temporal")
                require(graphicenhancement.setNrLayerParameter(graphicenhancement.nrLayers[0].index,"sizePolicy",0),"size")
                graphicenhancement.openPath(probe.media)
                return
            }
            if (!graphicenhancement.running||graphicenhancement.applying||graphicenhancement.position<=0) return
            require(graphicenhancement.nrActive,"NR remains active")
            if (probe.awaiting) {
                if (Date.now()-probe.changedAt<1000) return
                require((graphicenhancement.preferences.gpuPriority||"normal")===probe.target,"accepted preference")
                console.log("PRIORITY_UI_EFFECTIVE",JSON.stringify({cycle:probe.cycle,target:probe.target,
                    status:graphicenhancement.gpuPriorityStatus,position:graphicenhancement.position,paused:graphicenhancement.paused,nr:graphicenhancement.nrActive}))
                probe.awaiting=false;++probe.cycle
                if (probe.cycle===20) { console.log("PRIORITY_UI_PASS",graphicenhancement.gpuPriorityStatus);Qt.quit();return }
                probe.changedAt=Date.now();return
            }
            if (Date.now()-probe.changedAt<400) return
            if (probe.cycle===9&&!graphicenhancement.paused)graphicenhancement.togglePlayPause()
            if (probe.cycle===14&&graphicenhancement.paused)graphicenhancement.togglePlayPause()
            probe.target=probe.cycle===19?"realtime":["normal","high","realtime"][probe.cycle%3]
            require(graphicenhancement.setPreference("gpuPriority",probe.target),"set priority")
            probe.changedAt=Date.now();probe.awaiting=true
            console.log("PRIORITY_UI_REQUEST",JSON.stringify({cycle:probe.cycle,target:probe.target}))
        }
    }
}
