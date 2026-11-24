// Loaded only into a private staging copy, never the user's running package.
import QtQuick
Item {
    id: test
    property string media: ""
    property int phase: 0
    property int ticks: 0
    property int total: 0
    property real beforePosition: 0
    function check(ok,why){if(!ok)throw new Error(why)}
    function next(n){phase=n;ticks=0;beforePosition=graphicenhancement.position}
    function active(){check(graphicenhancement.running&&graphicenhancement.fgActive&&graphicenhancement.fgBackendName==="vfg","VFG not active: "+graphicenhancement.statusText);check(graphicenhancement.position>beforePosition+1,"media clock stopped")}
    Timer {id: timer;interval: 250;repeat: true;running: test.media!==""
        onTriggered: {try {
            ++test.ticks;if(++test.total>280)throw new Error("70 second deadline phase "+test.phase)
            if(test.phase===0){
                if(test.ticks<8)return
                root.page="pro";graphicenhancement.muted=true;graphicenhancement.nrEnabled=false;graphicenhancement.srEnabled=false
                check(graphicenhancement.addEffect("vfg-fg")>=0,"VFG stage creation")
                graphicenhancement.vfgQuality=1;graphicenhancement.fgMultiplier=2;graphicenhancement.openPath(test.media);next(1)
            }else if(test.phase===1){
                if(!graphicenhancement.running||!graphicenhancement.fgActive||graphicenhancement.applying||graphicenhancement.position<1)return
                next(2)
            }else if(test.phase===2){
                if(test.ticks<24||graphicenhancement.applying)return
                active();console.log("FG_DISPLAY_CASE","2X",graphicenhancement.submitFps,graphicenhancement.runStatusDetail)
                graphicenhancement.outputRateMode=1;graphicenhancement.variableRefresh=true;next(3)
            }else if(test.phase===3){
                if(test.ticks<20||graphicenhancement.applying)return
                active();console.log("FG_DISPLAY_CASE","follow-display-VRR",graphicenhancement.presentationStatus)
                graphicenhancement.fgMultiplier=4;next(4)
            }else if(test.phase===4){
                if(test.ticks<20||graphicenhancement.applying)return
                active();check(graphicenhancement.fgMultiplier===4,"4X rollback")
                console.log("FG_DISPLAY_CASE","4X",graphicenhancement.submitFps,graphicenhancement.runStatusDetail)
                graphicenhancement.togglePlayPause();next(5)
            }else if(test.phase===5){
                if(test.ticks<4)return
                check(graphicenhancement.paused,"pause")
                graphicenhancement.togglePlayPause();next(6)
            }else if(test.phase===6){
                if(test.ticks<16||graphicenhancement.applying)return
                active();graphicenhancement.stopPlayback();next(7)
            }else if(test.phase===7){
                if(test.ticks<8)return
                check(!graphicenhancement.running,"close drains")
                graphicenhancement.fgMultiplier=2;graphicenhancement.openPath(test.media);next(8)
            }else if(test.phase===8){
                if(test.ticks<24||graphicenhancement.applying||!graphicenhancement.fgActive)return
                active();console.log("FG_DISPLAY_PASS",graphicenhancement.submitFps,graphicenhancement.runStatusDetail)
                timer.stop();Qt.quit()
            }
        }catch(e){console.error("FG_DISPLAY_FAIL",test.phase,e.message);timer.stop();Qt.quit()}}
    }
}
