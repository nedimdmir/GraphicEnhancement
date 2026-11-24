import QtQuick
Item {
    id: probe
    property string media: ""
    property string group: "pressure"
    property int stage: 0
    property double startedAt: Date.now()
    property double phaseAt: 0
    function require(ok,why){if(!ok){console.log("CACHE_UI_FAIL",why,graphicenhancement.diagnosticsReport());Qt.exit(3)}}
    Timer {
        interval: 200;running: true;repeat: true
        onTriggered: {
            require(Date.now()-probe.startedAt<90000,"timeout")
            require(!graphicenhancement.failed,"engine failure")
            if(probe.stage===0){
                graphicenhancement.muted=true;graphicenhancement.lowLatency=false
                graphicenhancement.nrEnabled=true;graphicenhancement.srEnabled=false;graphicenhancement.fgEnabled=false
                graphicenhancement.videoHdr=false;graphicenhancement.colorEnabled=false
                require(graphicenhancement.setNrLayerParameter(graphicenhancement.nrLayers[0].index,"temporal",0),"temporal")
                require(graphicenhancement.setNrLayerParameter(graphicenhancement.nrLayers[0].index,"sizePolicy",0),"size")
                graphicenhancement.openPath(probe.media);probe.stage=1;return
            }
            if(probe.stage===1){
                if(!graphicenhancement.running||graphicenhancement.applying||graphicenhancement.position<1||!graphicenhancement.nrActive)return
                graphicenhancement.nrEnabled=false;probe.phaseAt=Date.now();probe.stage=2;return
            }
            if(probe.stage===2){
                if(graphicenhancement.applying||graphicenhancement.nrActive||Date.now()-probe.phaseAt<(probe.group==="pressure"?24000:1500))return
                if(probe.group==="invalidate")require(graphicenhancement.setNrLayerParameter(graphicenhancement.nrLayers[0].index,"sizePolicy",2),"new size key")
                graphicenhancement.nrEnabled=true;probe.phaseAt=Date.now();probe.stage=3;return
            }
            if(probe.stage===3){
                if(graphicenhancement.applying||!graphicenhancement.nrActive||Date.now()-probe.phaseAt<1500)return
                console.log("CACHE_UI_RECOVERED",JSON.stringify({group:probe.group,position:graphicenhancement.position,details:graphicenhancement.diagnosticsReport()}))
                graphicenhancement.nrEnabled=false;probe.phaseAt=Date.now();probe.stage=4;return
            }
            if(probe.stage===4){
                if(graphicenhancement.applying||graphicenhancement.nrActive||Date.now()-probe.phaseAt<1500)return
                graphicenhancement.stopPlayback();probe.phaseAt=Date.now();probe.stage=5;return
            }
            if(probe.stage===5){
                if(graphicenhancement.running||Date.now()-probe.phaseAt<1000)return
                console.log("CACHE_UI_PASS",probe.group);Qt.quit()
            }
        }
    }
}
