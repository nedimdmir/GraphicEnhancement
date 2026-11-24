import QtQuick
Item {
 id: probe
 property var config: ({})
 property var appWindow: Window.window
 property int ticks: 0
 property int state: 0
 property double ready: 0
 property int uiFrames: 0
 function require(ok, why) { if (!ok) throw new Error(why) }
 Connections { target: graphicenhancement; function onNotice(text,error) { console.log("VFG_DIAG_NOTICE",text,error) } }
 Connections { target: probe.appWindow; function onFrameSwapped() { ++probe.uiFrames } }
 Timer { interval: 500; running: true; repeat: true; onTriggered: { try {
  if (!probe.config.media) return
  ++probe.ticks; probe.require(probe.ticks<260,"130s deadline")
  if (probe.state===0 && probe.ticks>=5) {
   probe.appWindow.page="pro"; probe.appWindow.width=1280; probe.appWindow.height=800
   graphicenhancement.nodeMode=0; graphicenhancement.muted=true; graphicenhancement.reducedMotion=false
   graphicenhancement.nrEnabled=false; graphicenhancement.srEnabled=false; graphicenhancement.fgEnabled=false
   graphicenhancement.videoHdr=false; graphicenhancement.colorEnabled=false; graphicenhancement.lowLatency=false
   graphicenhancement.displaySync=probe.config.display; graphicenhancement.outputRateMode=0
   graphicenhancement.nrMotionSource=probe.config.flow?1:0
   if (!graphicenhancement.nrLayers.length) graphicenhancement.addEffect("nr")
   probe.require(graphicenhancement.nrLayers.length===1,"one NR layer")
   const n=graphicenhancement.nrLayers[0].index
   for (const p of [["runtime",3],["sizePolicy",0],["style",0],["total",1],["temporal",0],["antiFlicker",0],["correctionEnabled",0]])
    probe.require(graphicenhancement.setNrLayerParameter(n,p[0],p[1]),p[0])
   graphicenhancement.nrEnabled=probe.config.nr
   probe.require(graphicenhancement.addEffect("vfg-fg")>=0,"add VFG")
   graphicenhancement.fgMultiplier=probe.config.multiplier; graphicenhancement.vfgQuality=probe.config.quality
   graphicenhancement.fgStrict=probe.config.strict
   console.log("VFG_DIAG_CONFIG",JSON.stringify({config:probe.config,layers:graphicenhancement.nrLayers,chain:graphicenhancement.chain,strict:graphicenhancement.fgStrict,nrMotion:graphicenhancement.nrMotionSource,cap:graphicenhancement.outputRateMode,backend:graphicenhancement.fgBackendName,quality:graphicenhancement.vfgQuality,multiplier:graphicenhancement.fgMultiplier}))
   graphicenhancement.openPath(probe.config.media); probe.state=1
  }
  probe.require(!graphicenhancement.failed,"engine failed")
  if (probe.state===1 && graphicenhancement.running && graphicenhancement.fgActive && graphicenhancement.position>0 && !graphicenhancement.applying) {
   probe.ready=Date.now(); probe.state=2
  }
  if (probe.ticks%2===0) console.log("VFG_DIAG_SAMPLE",JSON.stringify({wall:Date.now(),seconds:probe.ready?(Date.now()-probe.ready)/1000:-1,position:graphicenhancement.position,ready:probe.state===2,active:probe.appWindow.active,uiFrames:probe.uiFrames,fps:graphicenhancement.submitFps,ratio:graphicenhancement.outputRateRatio,total:graphicenhancement.chainTotalMs,totalKnown:graphicenhancement.chainTotalMsKnown,budget:graphicenhancement.stageBudgetMs,stages:graphicenhancement.stageTimings,status:graphicenhancement.runStatus,detail:graphicenhancement.runStatusDetail,nr:graphicenhancement.nrActive,fg:graphicenhancement.fgActive,backend:graphicenhancement.fgBackendName,multiplier:graphicenhancement.fgMultiplier,quality:graphicenhancement.vfgQuality,skipped:graphicenhancement.skippedFrames,queued:graphicenhancement.queuedFrames,gpu:graphicenhancement.gpuUtilization,gpuKnown:graphicenhancement.gpuUtilizationKnown,strict:graphicenhancement.fgStrict,cap:graphicenhancement.outputRateMode}))
  if (probe.state===2 && Date.now()-probe.ready>=(probe.config.seconds+5)*1000) {
   probe.require(graphicenhancement.fgActive && graphicenhancement.fgBackendName==="vfg","VFG stayed active")
   probe.require(graphicenhancement.fgMultiplier===probe.config.multiplier && graphicenhancement.vfgQuality===probe.config.quality,"requested settings retained")
   console.log("VFG_DIAG_PASS"); Qt.quit()
  }
 } catch(e) { console.error("VFG_DIAG_FAIL",e.message); Qt.exit(3) } } }
}
