import QtQuick
Item {
 id:test
 property var config:({})
 property var appWindow:Window.window
 property int ticks:0
 property int phase:0
 property int readyTick:0
 property bool exportStarted:false
 property double pausePosition:0
 property int uiFrames:0
 function require(v,s){if(!v)throw new Error(s)}
 function preset(){const p=graphicenhancement.presets.find(p=>p.name==="FSR repair regression");require(p!==undefined,"saved list preset missing");require(graphicenhancement.applyPresetIndex(p.index),"apply preset refused")}
 function saved(){console.log("REPAIR_UI_SAVED",JSON.stringify({backend:graphicenhancement.fgBackendName,multiplier:graphicenhancement.fgMultiplier,enabled:graphicenhancement.fgEnabled,flow:graphicenhancement.flowQuality,content:graphicenhancement.contentRate}));require(graphicenhancement.fgBackendName==="fsr3"&&graphicenhancement.fgMultiplier===2&&graphicenhancement.fgEnabled,"FSR saved choice");require(graphicenhancement.flowQuality===2&&graphicenhancement.contentRate===2,"shared flow saved in list preset")}
 Connections {target:graphicenhancement;function onNotice(text,error){console.log("REPAIR_UI_NOTICE",text,error)}}
 Connections {target:test.appWindow;function onFrameSwapped(){++test.uiFrames}}
 Timer {interval:300;running:true;repeat:true;onTriggered:{try{
  ++test.ticks;test.require(test.ticks<800,"240s deadline phase="+test.phase)
  if(test.phase===0){
   if(test.ticks<10)return
   if(test.config.case==="seed-dlss"){
    graphicenhancement.nodeMode=0;graphicenhancement.nrEnabled=false;graphicenhancement.srEnabled=false
    graphicenhancement.fgBackendName="dlss";graphicenhancement.fgMultiplier=6;graphicenhancement.fgEnabled=true
    test.require(graphicenhancement.fgBackendName==="dlss"&&graphicenhancement.fgEnabled&&graphicenhancement.fgMultiplier===6,"seed live list DLSS 6X")
    graphicenhancement.nodeMode=1;graphicenhancement.fgBackendName="dlss";graphicenhancement.fgMultiplier=4;graphicenhancement.fgEnabled=false
    test.require(graphicenhancement.nodeMode===1&&graphicenhancement.fgBackendName==="dlss","seed inactive node DLSS choice")
    graphicenhancement.nodeMode=0;test.require(graphicenhancement.fgEnabled&&graphicenhancement.fgMultiplier===6,"seed mode roundtrip")
    console.log("REPAIR_UI_PASS");Qt.quit();return
   }
   if(["migration-before","migration","nvidia-keep","xess-keep"].includes(test.config.case)){
    console.log("REPAIR_UI_DEFAULT",test.config.case,graphicenhancement.fgBackendName,graphicenhancement.fgMultiplier,graphicenhancement.fgEnabled,graphicenhancement.nodeMode)
    const old=test.config.case==="migration-before"
    const nv=test.config.case==="nvidia-keep"
    const expected=old||nv?"dlss":test.config.case==="xess-keep"?"xess":"fsr3"
    test.require(graphicenhancement.nodeMode===0&&graphicenhancement.fgBackendName===expected,"restored list backend")
    test.require(graphicenhancement.fgMultiplier===(old?1:nv?6:2)&&graphicenhancement.fgEnabled===!old,"list multiplier and enabled state")
    graphicenhancement.nodeMode=1
    test.require(graphicenhancement.nodeMode===1&&graphicenhancement.fgBackendName===(old||nv?"dlss":"fsr3"),"inactive node backend restored")
    test.require(!graphicenhancement.fgEnabled,"disabled node stage must remain disabled")
    graphicenhancement.nodeMode=0
    test.require(graphicenhancement.fgBackendName===expected&&graphicenhancement.fgEnabled===!old,"list return preserves backend and switch")
    if(test.config.case==="migration"){
     graphicenhancement.fgBackendName="xess";test.require(graphicenhancement.fgBackendName==="xess"&&graphicenhancement.fgMultiplier===2,"manual XeSS choice remains available")
    }
    console.log(old?"REPAIR_UI_EXPECTED_OLD":"REPAIR_UI_PASS");Qt.quit();return
   }
   if(test.config.restore){
    test.saved();graphicenhancement.flowQuality=0;graphicenhancement.contentRate=0;graphicenhancement.fgEnabled=false
    test.preset();test.saved();console.log("REPAIR_UI_PASS");Qt.quit();return
   }
   if(test.config.case==="telemetry"){
    graphicenhancement.nodeMode=0;graphicenhancement.muted=true;graphicenhancement.reducedMotion=false
    graphicenhancement.nrEnabled=false;graphicenhancement.srEnabled=false;graphicenhancement.fgEnabled=false;graphicenhancement.videoHdr=false;graphicenhancement.colorEnabled=false
    if(!graphicenhancement.nrLayers.length)graphicenhancement.addEffect("nr")
    test.require(graphicenhancement.nrLayers.length===1,"single list NR layer")
    const n=graphicenhancement.nrLayers[0].index
    for(const p of [["runtime",3],["sizePolicy",0],["style",0],["total",1],["temporal",0],["antiFlicker",0],["correctionEnabled",0]])
     test.require(graphicenhancement.setNrLayerParameter(n,p[0],p[1]),"list NR parameter "+p[0])
    graphicenhancement.nrEnabled=true;graphicenhancement.displaySync=2
    graphicenhancement.openPath(test.config.media);test.phase=10;return
   }
   graphicenhancement.nodeMode=0;graphicenhancement.muted=true;graphicenhancement.nrEnabled=false;graphicenhancement.srEnabled=false;graphicenhancement.fgEnabled=false
   console.log("REPAIR_UI_CATALOG",JSON.stringify(graphicenhancement.fgBackendChoices),JSON.stringify(graphicenhancement.effectCatalog))
   const generic=graphicenhancement.effectCatalog.find(p=>p.id==="frame-generation")
   const dlss=graphicenhancement.fgBackendChoices.find(p=>p.id==="dlss")
   const fsr=graphicenhancement.fgBackendChoices.find(p=>p.id==="fsr3")
   test.require(generic!==undefined&&fsr!==undefined&&!fsr.disabled,"FSR component available")
   if(test.config.catalogOnly){
    test.require(dlss.disabled,"missing NVIDIA runtime is required to reproduce old generic-entry gate")
    if(!test.config.before)test.require(graphicenhancement.fgBackendName==="fsr3","missing DLSS provider defaults to FSR before adding")
    const added=graphicenhancement.addEffect("frame-generation")
    if(test.config.before){test.require(generic.disabled&&added<0,"old gate did not reproduce");console.log("REPAIR_UI_EXPECTED_OLD");Qt.quit();return}
    test.require(!generic.disabled&&added>=0,"generic FG entry must use any available provider")
   }else{
    // The fresh NVIDIA list already contains its disabled FG stage.
    // The missing-runtime package above exercises adding the absent stage.
    graphicenhancement.fgBackendName="dlss";graphicenhancement.fgMultiplier=6
   }
   graphicenhancement.fgBackendName="fsr3";graphicenhancement.fgMultiplier=2;graphicenhancement.fgEnabled=true
   graphicenhancement.flowQuality=2;graphicenhancement.contentRate=2;graphicenhancement.fgMotionSource=0
   test.saved();test.require(graphicenhancement.savePresetAs("FSR repair regression",21,false),"save list Chain+FG+Flow preset")
   graphicenhancement.flowQuality=0;graphicenhancement.contentRate=0;graphicenhancement.fgEnabled=false
   test.preset();test.saved()
   if(test.config.catalogOnly){console.log("REPAIR_UI_PASS");Qt.quit();return}
   graphicenhancement.displaySync=2;graphicenhancement.outputRateMode=0
   graphicenhancement.openPath(test.config.media);test.phase=1
  }else if(test.phase>=10){
   test.require(!graphicenhancement.failed,"telemetry lifecycle player failed")
   const dwell=test.ticks-test.readyTick
   if(test.phase===10){
    if(!graphicenhancement.running||!graphicenhancement.nrActive||graphicenhancement.position<2)return
    if(!test.readyTick)test.readyTick=test.ticks
    if(dwell<10)return
    test.pausePosition=graphicenhancement.position;graphicenhancement.togglePlayPause();test.phase=11;test.readyTick=test.ticks
   }else if(test.phase===11){
    if(dwell<6)return
    test.require(graphicenhancement.paused&&Math.abs(graphicenhancement.position-test.pausePosition)<0.2,"pause must retain media position")
    console.log("REPAIR_UI_TELEMETRY","paused",test.uiFrames,JSON.stringify(graphicenhancement.stageTimings))
    graphicenhancement.togglePlayPause();test.phase=12;test.readyTick=test.ticks
   }else if(test.phase===12){
    if(dwell<10)return
    test.require(!graphicenhancement.paused&&graphicenhancement.nrActive,"resume NR")
    test.appWindow.showFullScreen();test.phase=13;test.readyTick=test.ticks
   }else if(test.phase===13){
    if(dwell<10)return
    test.require(graphicenhancement.nrActive,"fullscreen NR")
    test.appWindow.showNormal();graphicenhancement.seekTo(12);test.phase=14;test.readyTick=test.ticks
   }else if(test.phase===14){
    if(dwell<10||graphicenhancement.position<12)return
    test.appWindow.page="node";test.require(graphicenhancement.nodeMode===1,"node page mode")
    const i=graphicenhancement.addEffect("nr");test.require(i>=0,"add node NR")
    for(const p of [["runtime",3],["sizePolicy",0],["temporal",0],["antiFlicker",0],["correctionEnabled",0]])
     test.require(graphicenhancement.setNrLayerParameter(i,p[0],p[1]),"node NR parameter "+p[0])
    const node=graphicenhancement.chain.find(p=>p.index===i)
    test.require(node!==undefined&&graphicenhancement.insertNodeAfter(node.id,0),"connect NR between input and output")
    test.phase=15;test.readyTick=test.ticks
   }else if(test.phase===15){
    if(dwell<12||!graphicenhancement.nrActive)return
    console.log("REPAIR_UI_TELEMETRY","node",JSON.stringify(graphicenhancement.nodeTimings),JSON.stringify(graphicenhancement.nodeConnections))
    graphicenhancement.nodeMode=0;test.appWindow.page="pro";test.phase=16;test.readyTick=test.ticks
   }else if(test.phase===16){
    if(dwell<10||!graphicenhancement.nrActive)return
    test.require(graphicenhancement.nrLayers.length===1&&graphicenhancement.nrLayers[0].runtime===3&&!graphicenhancement.fgEnabled&&!graphicenhancement.srEnabled,"list configuration survives mode roundtrip")
    graphicenhancement.reducedMotion=true;test.phase=17;test.readyTick=test.ticks
   }else if(test.phase===17){
    if(dwell<5)return
    test.require(graphicenhancement.reducedMotion&&graphicenhancement.nrActive,"reduced-motion switch preserves NR")
    graphicenhancement.stopPlayback();test.phase=18;test.readyTick=test.ticks
   }else if(test.phase===18){
    if(dwell<5)return
    test.require(!graphicenhancement.running,"stop must finish")
    console.log("REPAIR_UI_PASS");Qt.quit()
   }
  }else if(test.phase===1){
   test.require(!graphicenhancement.failed,"FSR preview failed "+graphicenhancement.runStatus)
   if(!graphicenhancement.running||graphicenhancement.position<2)return
   test.require(graphicenhancement.fgBackendName==="fsr3"&&graphicenhancement.fgEnabled,"live FSR selection rolled back")
   if(!test.readyTick)test.readyTick=test.ticks
   console.log("REPAIR_UI_SAMPLE",JSON.stringify({position:graphicenhancement.position,fps:graphicenhancement.submitFps,backend:graphicenhancement.fgBackendName,status:graphicenhancement.presentationStatus,detail:graphicenhancement.runStatusDetail}))
   if(test.ticks-test.readyTick<12)return
   test.appWindow.showFullScreen();test.phase=2;test.readyTick=test.ticks
  }else if(test.phase===2){
   test.require(!graphicenhancement.failed,"fullscreen preview failed")
   if(test.ticks-test.readyTick<12)return
   test.appWindow.showNormal();test.phase=3;test.readyTick=test.ticks
  }else if(test.phase===3){
   if(test.ticks-test.readyTick<8)return
   graphicenhancement.exportCompletionSound=false;graphicenhancement.exportHevc=false;graphicenhancement.exportRateControl=1
   graphicenhancement.addExportFiles([test.config.exportMedia]);test.phase=4
  }else if(test.phase===4){
   if(graphicenhancement.exportReadyCount<1)return
   graphicenhancement.startExport();test.require(graphicenhancement.exportRunning,"FSR GUI export rejected")
   test.exportStarted=true;test.phase=5
  }else if(test.phase===5){
   if(graphicenhancement.exportRunning)return
   test.require(graphicenhancement.exportItems.some(p=>p.state==="done"),"FSR GUI export failed "+JSON.stringify(graphicenhancement.exportItems))
   console.log("REPAIR_UI_EXPORT",JSON.stringify(graphicenhancement.exportItems));test.saved()
   console.log("REPAIR_UI_PASS");Qt.quit()
  }
 }catch(e){console.error("REPAIR_UI_FAIL",test.phase,e.message);Qt.exit(3)}}}
}
