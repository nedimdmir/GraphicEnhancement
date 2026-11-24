import QtQuick
Item {
    id: probe
    property string media: ""
    property string backend: "fsr3"
    property int stage: 0
    property double began: Date.now()
    property double phaseAt: 0
    function require(ok,why){if(!ok){console.log("QUEUE_UI_FAIL",why,graphicenhancement.diagnosticsReport());Qt.exit(3);throw new Error("QUEUE_UI_FAIL: "+why)}}
    function mark(name){console.log("QUEUE_UI_PHASE",JSON.stringify({name:name,backend:graphicenhancement.fgBackendName,at:Date.now(),position:graphicenhancement.position,nr:graphicenhancement.nrActive,sr:graphicenhancement.srActive,fg:graphicenhancement.fgActive,detail:graphicenhancement.runStatusDetail}));phaseAt=Date.now();++stage}
    Timer {
        interval: 200;running: true;repeat: true
        onTriggered: {
            require(Date.now()-probe.began<100000,"timeout");require(!graphicenhancement.failed,"engine failure")
            if(probe.stage===0){
                graphicenhancement.muted=true;graphicenhancement.lowLatency=false;graphicenhancement.colorEnabled=false;graphicenhancement.videoHdr=false
                graphicenhancement.nrEnabled=true;graphicenhancement.srEnabled=true;graphicenhancement.videoSrQuality=0;graphicenhancement.srTargetIndex=2
                while(graphicenhancement.nrLayers.length<2)require(graphicenhancement.duplicateNrLayer(graphicenhancement.nrLayers[0].index)>=0,"duplicate")
                for(let i=0;i<2;++i){require(graphicenhancement.setNrLayerParameter(graphicenhancement.nrLayers[i].index,"runtime",0),"runtime");require(graphicenhancement.setNrLayerParameter(graphicenhancement.nrLayers[i].index,"sizePolicy",0),"size");require(graphicenhancement.setNrLayerParameter(graphicenhancement.nrLayers[i].index,"temporal",0),"temporal")}
                graphicenhancement.fgBackendName="dlss";graphicenhancement.fgMultiplier=2;graphicenhancement.fgEnabled=true;graphicenhancement.openPath(probe.media);probe.mark("open");return
            }
            require(Date.now()-probe.phaseAt<18000,"phase did not settle")
            if(graphicenhancement.applying||!graphicenhancement.running||graphicenhancement.position<1||Date.now()-probe.phaseAt<2200||!graphicenhancement.nrActive||!graphicenhancement.srActive)return
            if(probe.stage===1){if(!graphicenhancement.fgActive)return;probe.mark("dlss2-active");graphicenhancement.fgBackendName=probe.backend;graphicenhancement.fgMultiplier=2;return}
            if(probe.stage===2){if(!graphicenhancement.fgActive||graphicenhancement.fgBackendName!==probe.backend)return;probe.mark(probe.backend+"-active");graphicenhancement.fgBackendName="dlss";graphicenhancement.fgMultiplier=3;return}
            if(probe.stage===3){if(!graphicenhancement.fgActive||graphicenhancement.fgBackendName!=="dlss"||graphicenhancement.fgMultiplier!==3||graphicenhancement.runStatusDetail.indexOf("3X")<0)return;probe.mark("dlss3-active");graphicenhancement.fgEnabled=false;return}
            if(probe.stage===4){if(graphicenhancement.fgActive)return;probe.mark("fg-off");graphicenhancement.fgEnabled=true;graphicenhancement.colorEnabled=true;return}
            if(probe.stage===5){if(!graphicenhancement.fgActive||!graphicenhancement.colorEnabled)return;probe.mark("color-active");graphicenhancement.colorEnabled=false;return}
            if(probe.stage===6){if(!graphicenhancement.fgActive||graphicenhancement.colorEnabled)return;probe.mark("color-off");require(graphicenhancement.setNrLayerParameter(graphicenhancement.nrLayers[0].index,"temporal",1),"temporal on");return}
            if(probe.stage===7){if(!graphicenhancement.fgActive||!graphicenhancement.nrLayers[0].temporal)return;probe.mark("temporal-active");require(graphicenhancement.setNrLayerParameter(graphicenhancement.nrLayers[0].index,"temporal",0),"temporal off");return}
            if(probe.stage===8){if(!graphicenhancement.fgActive||graphicenhancement.nrLayers[0].temporal)return;probe.mark("temporal-off");graphicenhancement.stopPlayback();return}
            if(probe.stage===9&&!graphicenhancement.running){console.log("QUEUE_UI_PASS",probe.backend);Qt.quit()}
        }
    }
    Timer {interval:200;running:true;repeat:true;onTriggered:if(probe.stage===9&&!graphicenhancement.running){console.log("QUEUE_UI_PASS",probe.backend);Qt.quit()}}
}
