import QtQuick
Item {
    id: probe
    property var appWindow: Window.window
    property string media: ""
    property string group: "nr"
    property int stage: 0
    property double started: Date.now()
    property double phaseAt: 0
    property double pausedPosition: 0
    property int pausedNr: 0
    property int edits: 0
    property int editedNr: 0
    property bool expectedFg: group === "dlss" || group === "xess" || group === "fsr3" || group === "vfg"
    property double resumePosition: 0
    function require(ok, why) {if(!ok){console.log("PAUSED_UI_FAIL",why,graphicenhancement.diagnosticsReport());Qt.exit(3)}}
    function nrCount() {
        const report=graphicenhancement.diagnosticsReport()
        const found=/NR[^\r\n]*?(\d+)\s*\/\s*NVOF\s*(\d+)/.exec(report)
        require(found!==null,"NR counter unavailable");return found?Number(found[1]):-1
    }
    Connections {target: graphicenhancement;function onNotice(text,error){console.log("PAUSED_UI_NOTICE",text,error)}}
    Timer {
        interval: 500;running: true;repeat: true
        onTriggered: {
            const now=Date.now();probe.require(now-probe.started<220000,"timeout")
            probe.require(!graphicenhancement.failed,"engine failed")
            if(probe.stage===0){
                probe.appWindow.width=1280;probe.appWindow.height=800
                graphicenhancement.muted=true;graphicenhancement.lowLatency=false
                graphicenhancement.srEnabled=false;graphicenhancement.fgEnabled=false;graphicenhancement.videoHdr=false;graphicenhancement.colorEnabled=false
                graphicenhancement.nrEnabled=true
                const idx=graphicenhancement.nrLayers[0].index
                probe.require(graphicenhancement.setNrLayerParameter(idx,"sizePolicy",1),"native NR")
                probe.require(graphicenhancement.setNrLayerParameter(idx,"temporal",probe.group==="temporal"?1:0),"temporal")
                if(probe.group==="srnr"){graphicenhancement.videoSrQuality=0;graphicenhancement.srTargetIndex=2;graphicenhancement.srEnabled=true}
                if(probe.expectedFg){graphicenhancement.fgBackendName=probe.group;graphicenhancement.fgMultiplier=2;graphicenhancement.fgEnabled=true}
                console.log("PAUSED_UI_CONFIG",JSON.stringify({group:probe.group,layers:graphicenhancement.nrLayers,sr:graphicenhancement.srEnabled,fg:graphicenhancement.fgEnabled}))
                graphicenhancement.openPath(probe.media);probe.stage=1;return
            }
            if(probe.stage===1){
                if(!graphicenhancement.running||graphicenhancement.position<5||!graphicenhancement.nrActive||graphicenhancement.applying||graphicenhancement.fgActive!==probe.expectedFg)return
                graphicenhancement.togglePlayPause();probe.phaseAt=now;probe.stage=2;return
            }
            if(probe.stage===2){
                if(!graphicenhancement.paused||now-probe.phaseAt<1500)return
                probe.pausedPosition=graphicenhancement.position;probe.pausedNr=probe.nrCount();probe.phaseAt=now;probe.stage=3
                console.log("PAUSED_UI_IDLE_BEGIN",JSON.stringify({nr:probe.pausedNr,position:probe.pausedPosition,at:now}));return
            }
            if(probe.stage===3){
                probe.require(graphicenhancement.paused&&!graphicenhancement.applying,"idle transport")
                probe.require(probe.nrCount()===probe.pausedNr,"NR evaluated while idle")
                probe.require(Math.abs(graphicenhancement.position-probe.pausedPosition)<.1,"position drift while paused")
                if(now-probe.phaseAt<30000)return
                console.log("PAUSED_UI_IDLE_PASS",JSON.stringify({nr:probe.nrCount(),durationMs:now-probe.phaseAt,position:graphicenhancement.position}));probe.stage=4;return
            }
            if(probe.stage===4){
                if(graphicenhancement.applying||now-probe.phaseAt<700)return
                if(probe.edits===20){probe.editedNr=probe.nrCount();console.log("PAUSED_UI_EDITS_PASS",JSON.stringify({nrBefore:probe.pausedNr,nrAfter:probe.editedNr,requests:probe.edits}));probe.resumePosition=graphicenhancement.position;graphicenhancement.togglePlayPause();probe.stage=5;return}
                const idx=graphicenhancement.nrLayers[0].index
                if(probe.edits===10)probe.require(graphicenhancement.setNrLayerParameter(idx,"intensity",.8),"model invalidation")
                probe.require(graphicenhancement.setNrLayerParameter(idx,"total",(probe.edits%10)*.2),"residual edit")
                console.log("PAUSED_UI_EDIT",JSON.stringify({request:probe.edits,nrBefore:probe.nrCount(),modelChanged:probe.edits===10}));++probe.edits;probe.phaseAt=now;return
            }
            if(probe.stage===5){
                if(graphicenhancement.paused||graphicenhancement.position<probe.resumePosition+2)return
                probe.require(probe.nrCount()>probe.editedNr,"resume did not evaluate NR")
                console.log("PAUSED_UI_RESUME_PASS",JSON.stringify({nr:probe.nrCount(),position:graphicenhancement.position}));graphicenhancement.togglePlayPause();probe.phaseAt=now;probe.stage=6;return
            }
            if(probe.stage===6){if(!graphicenhancement.paused||now-probe.phaseAt<1000)return;graphicenhancement.seekTo(2);probe.phaseAt=now;probe.stage=7;return}
            if(probe.stage===7){
                if(graphicenhancement.applying||now-probe.phaseAt<1500)return
                probe.require(graphicenhancement.paused&&Math.abs(graphicenhancement.position-2)<.2,"paused seek")
                console.log("PAUSED_UI_SEEK_PASS",JSON.stringify({nr:probe.nrCount(),position:graphicenhancement.position}));console.log("PAUSED_UI_PASS");Qt.quit()
            }
        }
    }
}
