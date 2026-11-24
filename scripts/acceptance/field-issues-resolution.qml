    Timer {
        interval: 500; running: true; repeat: true
        property int step: 0
        property int ticks: 0
        property int total: 0
        property double began: 0
        property double before: 0
        function check(ok,label) { if(!ok)throw new Error(label) }
        function next(n) { step=n;ticks=0 }
        onTriggered: { try {
            ++ticks;++total;if(total>440)throw new Error("bounded step="+step)
            if(step===0) {
                if(ticks<4)return
                root.page="pro";graphicenhancement.muted=true;graphicenhancement.nrEnabled=true;graphicenhancement.srEnabled=true;graphicenhancement.fgEnabled=false
                graphicenhancement.srTargetIndex=4
                graphicenhancement.openPath("E:/项目/GraphicEnhancement/tests/field-issues-20260930/media/gta6-1080p30-45s.mp4")
                next(1);return
            }
            if(step===1||step===3||step===5) {
                if(ticks<6||graphicenhancement.applying||!graphicenhancement.running)return
                check(graphicenhancement.srActive&&graphicenhancement.nrActive,"NR+SR active "+graphicenhancement.statusText)
                before=graphicenhancement.position;began=Date.now()
                graphicenhancement.logUi("resolution-test","RESOLUTION_BEGIN "+graphicenhancement.srTargetLabel+" "+graphicenhancement.outputSummary)
                next(step+1);return
            }
            if(step===2||step===4||step===6) {
                if(Date.now()-began<30000)return
                check(graphicenhancement.running&&graphicenhancement.srActive&&graphicenhancement.nrActive&&graphicenhancement.position>before+20,"30s high resolution playback "+graphicenhancement.srTargetLabel+" "+graphicenhancement.statusText)
                graphicenhancement.logUi("resolution-test","RESOLUTION_30S_PASS "+graphicenhancement.srTargetLabel+" "+graphicenhancement.outputSummary)
                if(step===6){graphicenhancement.logUi("resolution-test","RESOLUTION_UI_PASS");Qt.quit();return}
                graphicenhancement.seekTo(0);graphicenhancement.srTargetIndex=step===2?5:6;next(step+1);return
            }
        } catch(e) {graphicenhancement.logUi("resolution-test","RESOLUTION_UI_FAIL "+e.message);Qt.quit()} }
    }
