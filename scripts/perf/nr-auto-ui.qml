import QtQuick
Item {
    id: probe
    property string media: ""
    property string mode: "lifecycle"
    property int stage: 0
    property double began: Date.now()
    property double phaseAt: Date.now()
    property double pausePosition: 0
    function require(ok, why) {
        if (!ok) { console.log("AUTO_UI_FAIL", why, graphicenhancement.diagnosticsReport()); Qt.exit(3); throw new Error(why) }
    }
    function mark(name) {
        console.log("AUTO_UI_PHASE", JSON.stringify({name:name, at:Date.now(), position:graphicenhancement.position,
            nr:graphicenhancement.nrActive, sr:graphicenhancement.srActive, auto:graphicenhancement.nrAutoActive, percent:graphicenhancement.nrAutoPercent,
            status:graphicenhancement.nrAutoStatus, layers:graphicenhancement.nrLayers, detail:graphicenhancement.runStatusDetail}))
        phaseAt = Date.now(); ++stage
    }
    NrLayerEditor { id: firstEditor; visible:false; layerData:graphicenhancement.nrLayers[0]; layerCount:graphicenhancement.nrLayers.length }
    NrLayerEditor { id: secondEditor; visible:false; layerData:graphicenhancement.nrLayers.length>1?graphicenhancement.nrLayers[1]:graphicenhancement.nrLayers[0]; layerCount:graphicenhancement.nrLayers.length }
    Timer {
        interval:200; running:true; repeat:true
        onTriggered: {
            probe.require(Date.now()-probe.began<180000,"timeout")
            probe.require(!graphicenhancement.failed,"engine failure")
            if (probe.stage===0) {
                if(probe.mode==="persist") {
                    probe.require(graphicenhancement.nrLayers.length===2&&graphicenhancement.nrLayers[0].sizePolicy===6,"saved Auto lost")
                } else {
                    graphicenhancement.muted=true; graphicenhancement.lowLatency=false; graphicenhancement.videoHdr=false; graphicenhancement.colorEnabled=false
                    graphicenhancement.fgEnabled=false; graphicenhancement.srEnabled=false; graphicenhancement.nrEnabled=true
                    probe.require(graphicenhancement.setOpticalFlowChoice(0),"NVIDIA flow")
                    while(graphicenhancement.nrLayers.length<2)probe.require(graphicenhancement.duplicateNrLayer(graphicenhancement.nrLayers[0].index)>=0,"duplicate")
                    for(let i=0;i<2;++i) {
                        probe.require(graphicenhancement.setNrLayerParameter(graphicenhancement.nrLayers[i].index,"runtime",0),"runtime")
                        probe.require(graphicenhancement.setNrLayerParameter(graphicenhancement.nrLayers[i].index,"temporal",0),"temporal")
                        probe.require(graphicenhancement.setNrLayerParameter(graphicenhancement.nrLayers[i].index,"sizePolicy",0),"fixed size")
                    }
                    probe.require(graphicenhancement.nrAutoSelectionReason(graphicenhancement.nrLayers[0].index)==="","first layer admission")
                    probe.require(!firstEditor.sizeChoices.find(o=>o.id==="6").disabled,"first layer choice")
                    probe.require(secondEditor.sizeChoices.find(o=>o.id==="6").disabled,"second layer must be gray")
                    probe.require(!graphicenhancement.setNrLayerParameter(graphicenhancement.nrLayers[1].index,"sizePolicy",6),"second Auto refused")
                    probe.require(graphicenhancement.setNrLayerParameter(graphicenhancement.nrLayers[0].index,"sizePolicy",6),"select actual Auto")
                }
                graphicenhancement.openPath(probe.media); probe.mark("open"); return
            }
            if(probe.stage===1) {
                if(!graphicenhancement.running||graphicenhancement.applying||!graphicenhancement.nrActive||graphicenhancement.position<3)return
                if(probe.mode==="refuse") {
                    probe.require(!graphicenhancement.nrAutoActive&&graphicenhancement.nrAutoStatus.length>0,"pool refusal must preserve NR with fallback")
                    probe.mark("pool-refused-fixed-nr"); console.log("AUTO_UI_PASS",probe.mode); Qt.quit(); return
                }
                if(!graphicenhancement.nrAutoActive||graphicenhancement.nrAutoPercent>70)return
                probe.require(graphicenhancement.nrAutoStatus.indexOf("70%")>=0||graphicenhancement.nrAutoPercent<70,"actual percent status")
                probe.mark("auto-downshift")
                if(probe.mode==="persist") { console.log("AUTO_UI_PASS",probe.mode); Qt.quit(); return }
                graphicenhancement.togglePlayPause(); return
            }
            if(probe.stage===2) {
                if(!graphicenhancement.paused||Date.now()-probe.phaseAt<600)return
                probe.pausePosition=graphicenhancement.position; probe.mark("paused"); return
            }
            if(probe.stage===3) {
                if(Date.now()-probe.phaseAt<1200)return
                probe.require(graphicenhancement.paused&&Math.abs(graphicenhancement.position-probe.pausePosition)<0.08,"paused position")
                graphicenhancement.seekTo(12); probe.mark("seek-paused"); return
            }
            if(probe.stage===4) {
                if(Date.now()-probe.phaseAt<1000||graphicenhancement.applying||Math.abs(graphicenhancement.position-12)>0.3)return
                probe.require(graphicenhancement.paused&&graphicenhancement.nrAutoActive,"pause seek kept Auto")
                graphicenhancement.playbackRate=0.5; graphicenhancement.togglePlayPause(); probe.mark("resume-half-speed"); return
            }
            if(probe.stage===5) {
                if(graphicenhancement.applying||graphicenhancement.paused||!graphicenhancement.nrActive||graphicenhancement.nrAutoPercent!==100)return
                probe.mark("auto-upshift")
                probe.require(graphicenhancement.setNrLayerParameter(graphicenhancement.nrLayers[0].index,"intensity",0.7),"model uniform")
                probe.mark("model-edit"); return
            }
            if(probe.stage===7) {
                if(Date.now()-probe.phaseAt<2000||graphicenhancement.applying)return
                probe.require(graphicenhancement.nrAutoActive&&Math.abs(graphicenhancement.nrLayers[0].intensity-0.7)<0.000001,"uniform retained")
                probe.require(graphicenhancement.setNrLayerParameter(graphicenhancement.nrLayers[0].index,"sizePolicy",0),"Auto off")
                probe.mark("select-fixed"); return
            }
            if(probe.stage===8) {
                if(graphicenhancement.applying||graphicenhancement.nrAutoActive||!graphicenhancement.nrActive)return
                probe.mark("fixed-active")
                probe.require(graphicenhancement.setNrLayerParameter(graphicenhancement.nrLayers[0].index,"sizePolicy",6),"Auto reenable")
                return
            }
            if(probe.stage===9) {
                if(graphicenhancement.applying||!graphicenhancement.nrAutoActive||!graphicenhancement.nrActive)return
                probe.mark("auto-reenabled"); graphicenhancement.colorEnabled=true; return
            }
            if(probe.stage===10) {
                if(graphicenhancement.applying||graphicenhancement.nrAutoActive||!graphicenhancement.nrActive||!graphicenhancement.colorEnabled)return
                probe.require(graphicenhancement.nrLayers[0].sizePolicy===6&&graphicenhancement.nrAutoStatus.length>0,"unsupported saved Auto fallback")
                probe.require(firstEditor.sizeChoices.find(o=>o.id==="6").disabled,"color gray choice")
                probe.mark("color-fixed-fallback"); graphicenhancement.colorEnabled=false; return
            }
            if(probe.stage===11) {
                if(graphicenhancement.applying||!graphicenhancement.nrAutoActive||!graphicenhancement.nrActive)return
                probe.mark("color-off-auto-restored")
                probe.require(graphicenhancement.setNrLayerParameter(graphicenhancement.nrLayers[0].index,"temporal",1),"temporal on"); return
            }
            if(probe.stage===12) {
                if(graphicenhancement.applying||graphicenhancement.nrAutoActive||!graphicenhancement.nrActive||!graphicenhancement.nrLayers[0].temporal)return
                probe.require(firstEditor.sizeChoices.find(o=>o.id==="6").disabled,"temporal gray choice")
                probe.mark("temporal-fixed-fallback")
                probe.require(graphicenhancement.setNrLayerParameter(graphicenhancement.nrLayers[0].index,"temporal",0),"temporal off"); return
            }
            if(probe.stage===13) {
                if(graphicenhancement.applying||!graphicenhancement.nrAutoActive||!graphicenhancement.nrActive)return
                probe.mark("temporal-off-auto-restored"); graphicenhancement.playbackRate=1
                console.log("AUTO_UI_PASS",probe.mode); Qt.quit()
            }
        }
    }
}
