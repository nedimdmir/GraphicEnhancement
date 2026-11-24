import QtQuick
Item {
 id: test
 property string media: ""
 property int step: 0
 property int ticks: 0
 Timer { interval: 500; running: true; repeat: true; onTriggered: { try {
  if(!test.media.length)return
  if(++test.ticks>240)throw new Error("120s fallback deadline")
  if(test.step===0&&test.ticks>4){
   graphicenhancement.muted=true;graphicenhancement.nrEnabled=false;graphicenhancement.srEnabled=false;graphicenhancement.videoHdr=false;graphicenhancement.colorEnabled=false
   graphicenhancement.nodeMode=0;graphicenhancement.addEffect("vfg-fg");graphicenhancement.fgMultiplier=4;graphicenhancement.vfgQuality=1
   graphicenhancement.openPath(test.media);test.step=1
  }
  if(test.step===1&&!graphicenhancement.applying&&graphicenhancement.running&&graphicenhancement.position>2&&graphicenhancement.backendWarning.length){
   console.log("VFG_FAILURE_STATE",JSON.stringify({failed:graphicenhancement.failed,position:graphicenhancement.position,warning:graphicenhancement.backendWarning,backend:graphicenhancement.fgBackendName,enabled:graphicenhancement.fgEnabled,active:graphicenhancement.fgActive,multiplier:graphicenhancement.fgMultiplier}))
   // fgEnabled is the saved chain node request, not the active backend. The
   // engine recovery log separately verifies applied multiplier=1.
   if(graphicenhancement.failed||graphicenhancement.fgActive)throw new Error("failed SDK frame remained active")
   console.log("VFG_FAILURE_PASS",JSON.stringify({position:graphicenhancement.position,warning:graphicenhancement.backendWarning,backend:graphicenhancement.fgBackendName,enabled:graphicenhancement.fgEnabled,active:graphicenhancement.fgActive}))
   Qt.quit()
  }
 } catch(e){console.error("VFG_FAILURE_FAIL",e.message);Qt.exit(3)} } }
}
