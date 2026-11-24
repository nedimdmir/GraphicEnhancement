import QtQuick
Item {
 id:probe
 property var config:({})
 property var appWindow:Window.window
 property int ticks:0
 property int uiFrames:0
 property double ready:0
 function require(v,s){if(!v)throw new Error(s)}
 Connections {target:graphicenhancement;function onNotice(text,error){console.log("REGRESSION_NOTICE",text,error)}}
 Connections {target:probe.appWindow;function onFrameSwapped(){++probe.uiFrames}}
 Timer {interval:1000;running:true;repeat:true;onTriggered:{try{
  ++probe.ticks;probe.require(probe.ticks<125,"125s deadline")
  if(probe.ticks===3){
   probe.appWindow.width=1280;probe.appWindow.height=800;graphicenhancement.nodeMode=0;graphicenhancement.muted=true;graphicenhancement.reducedMotion=probe.config.reducedMotion===true
   graphicenhancement.displaySync=probe.config.display===0?0:2
   graphicenhancement.nrEnabled=false;graphicenhancement.srEnabled=false;graphicenhancement.fgEnabled=false;graphicenhancement.videoHdr=false;graphicenhancement.colorEnabled=false;graphicenhancement.lowLatency=false
   if(!graphicenhancement.nrLayers.length)graphicenhancement.addEffect("nr")
   probe.require(graphicenhancement.nrLayers.length===1,"one NR layer")
   const n=graphicenhancement.nrLayers[0].index
   for(const p of [["runtime",3],["sizePolicy",0],["style",0],["total",1],["temporal",0],["antiFlicker",0]])
    probe.require(graphicenhancement.setNrLayerParameter(n,p[0],p[1]),p[0])
   if(probe.config.modern)probe.require(graphicenhancement.setNrLayerParameter(n,"correctionEnabled",0),"correction off")
   graphicenhancement.nrEnabled=true
   console.log("REGRESSION_CONFIG",JSON.stringify({layers:graphicenhancement.nrLayers,nr:graphicenhancement.nrEnabled,sr:graphicenhancement.srEnabled,fg:graphicenhancement.fgEnabled,lowLatency:graphicenhancement.lowLatency,reducedMotion:graphicenhancement.reducedMotion}))
   graphicenhancement.openPath(probe.config.media)
  }
  probe.require(!graphicenhancement.failed,"engine failed")
  if(!probe.ready&&graphicenhancement.running&&graphicenhancement.position>0&&graphicenhancement.nrActive)probe.ready=Date.now()
  console.log("REGRESSION_SAMPLE",JSON.stringify({tick:probe.ticks,uiFrames:probe.uiFrames,active:probe.appWindow.active,ready:probe.ready>0,position:graphicenhancement.position,fps:graphicenhancement.submitFps,nr:graphicenhancement.nrActive,stages:graphicenhancement.stageTimings,total:graphicenhancement.chainTotalMs,detail:graphicenhancement.runStatusDetail}))
  if(probe.ready&&Date.now()-probe.ready>=probe.config.seconds*1000){console.log("REGRESSION_PASS");Qt.quit()}
 }catch(e){console.error("REGRESSION_FAIL",e.message);Qt.exit(3)}}}
}
