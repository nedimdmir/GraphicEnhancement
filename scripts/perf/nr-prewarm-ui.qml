import QtQuick
Item {
    id: probe
    property string media: ""
    property string group: "nr"
    property bool referenceBuild: false
    property int stage: 0
    property double startedAt: Date.now()
    property double openedAt: 0
    function require(ok,why){if(!ok){console.log("PREWARM_UI_FAIL",why,graphicenhancement.diagnosticsReport());Qt.exit(3)}}
    Timer {
        interval: 100;repeat: true;running: true
        onTriggered: {
            const elapsed=Date.now()-probe.startedAt
            require(elapsed<90000,"timeout");require(!graphicenhancement.failed,"engine failure")
            if(probe.stage===0){
                graphicenhancement.muted=true;graphicenhancement.lowLatency=false;graphicenhancement.videoHdr=false;graphicenhancement.colorEnabled=false;graphicenhancement.fgEnabled=false
                graphicenhancement.nrEnabled=probe.group!=="alloff"&&probe.group!=="sr"
                graphicenhancement.srEnabled=probe.group==="srnr"||probe.group==="sr"
                graphicenhancement.videoSrQuality=0;graphicenhancement.srTargetIndex=2
                require(graphicenhancement.setNrLayerParameter(graphicenhancement.nrLayers[0].index,"temporal",0),"temporal")
                require(graphicenhancement.setNrLayerParameter(graphicenhancement.nrLayers[0].index,"sizePolicy",0),"size")
                console.log("PREWARM_UI_CONFIG",JSON.stringify({group:probe.group,at:Date.now(),nr:graphicenhancement.nrEnabled,sr:graphicenhancement.srEnabled}));probe.stage=1;return
            }
            if(probe.stage===1){
                if(probe.group==="quit"&&elapsed>=2300){console.log("PREWARM_UI_QUIT_DURING");Qt.quit();return}
                if(probe.group==="alloff"&&elapsed>=6500){console.log("PREWARM_UI_ALL_OFF_PASS");Qt.quit();return}
                if(probe.group==="disable"&&elapsed>=2500){require(graphicenhancement.setPreference("prewarmEnhancement",false),"disable prewarm");probe.stage=2;return}
                const openAt=probe.group==="during"?2300:8000
                if(elapsed<openAt)return
                if(probe.group==="mismatch")require(graphicenhancement.setNrLayerParameter(graphicenhancement.nrLayers[0].index,"sizePolicy",2),"size key change")
                probe.openedAt=Date.now();console.log("PREWARM_UI_OPEN",probe.openedAt);graphicenhancement.openPath(probe.media);probe.stage=3;return
            }
            if(probe.stage===2){
                if(elapsed<8000)return
                probe.openedAt=Date.now();console.log("PREWARM_UI_OPEN",probe.openedAt);graphicenhancement.openPath(probe.media);probe.stage=3;return
            }
            if(probe.stage===3){
                if(!graphicenhancement.running||graphicenhancement.applying||graphicenhancement.position<1.5)return
                require(graphicenhancement.nrActive===(probe.group!=="sr"),"NR active")
                require(graphicenhancement.srActive===(probe.group==="srnr"||probe.group==="sr"),"SR active")
                console.log("PREWARM_UI_PASS",JSON.stringify({group:probe.group,observedOpenMs:Date.now()-probe.openedAt,
                    nr:graphicenhancement.nrActive,sr:graphicenhancement.srActive,position:graphicenhancement.position,details:graphicenhancement.diagnosticsReport()}));Qt.quit()
            }
        }
    }
}
