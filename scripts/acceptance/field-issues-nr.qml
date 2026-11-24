    Timer {
        interval: 250; running: true; repeat: true
        property int step: 0
        property int ticks: 0
        property int total: 0
        property double beforePosition: 0
        property bool restore: Qt.application.arguments.indexOf("--nr-restore") >= 0
        function check(value,label) { if(!value) throw new Error(label) }
        function next(value) { step=value; ticks=0 }
        function preset(name) { for(var i=0;i<graphicenhancement.presets.length;++i)if(graphicenhancement.presets[i].name===name)return i;return -1 }
        function choose(id) {
            beforePosition=graphicenhancement.position
            check(graphicenhancement.setNrLayerParameter(graphicenhancement.nrLayers[0].index,"runtime",id),"select runtime "+id)
            check(graphicenhancement.nrLayers.every(n=>n.runtime===id),"whole chain runtime "+id)
        }
        onTriggered: { try {
            ++ticks;++total;if(total>520)throw new Error("bounded step="+step)
            if(step===0) {
                if(ticks<8)return
                if(restore) {
                    check(graphicenhancement.nodeMode===0&&graphicenhancement.nrLayers.every(n=>n.runtime===2),"list SF-v2 restored")
                    graphicenhancement.nodeMode=1
                    check(graphicenhancement.nrLayers.every(n=>n.runtime===2),"node SF-v2 restored")
                    check(graphicenhancement.applyPresetIndex(preset("NR Node Lecram")),"restore Lecram preset")
                    check(graphicenhancement.nrLayers.every(n=>n.runtime===0),"manual Lecram preserved")
                    console.log("NR_UI_RESTORE_PASS");Qt.quit();return
                }
                root.page="pro";graphicenhancement.muted=true;graphicenhancement.srEnabled=false;graphicenhancement.fgEnabled=false
                graphicenhancement.nrEnabled=true
                check(graphicenhancement.nrLayers[0].runtime===0,"5070 fresh Lecram default")
                graphicenhancement.openPath("E:/项目/GraphicEnhancement/tests/nr-sfv2-lecram-20260930/media/gta6-native-4k30-silent-90s.mp4")
                next(1);return
            }
            if(step===1) {
                if(ticks<20||!graphicenhancement.running||graphicenhancement.applying)return
                check(graphicenhancement.nrActive,"Lecram NR active "+graphicenhancement.statusText)
                check(graphicenhancement.duplicateNrLayer(graphicenhancement.nrLayers[0].index)>=0,"second NR layer")
                choose(2);next(2);return
            }
            if(step===2) {
                if(ticks<20||graphicenhancement.applying)return
                check(graphicenhancement.running&&graphicenhancement.nrActive&&graphicenhancement.position>beforePosition+0.5,"SF-v2 playback")
                check(graphicenhancement.nrLayers.length===2&&graphicenhancement.nrLayers.every(n=>n.runtime===2),"two NRs SF-v2")
                console.log("NR_UI_SF_ACTIVE position="+graphicenhancement.position)
                check(graphicenhancement.savePresetAs("NR List SF-v2",15,false),"save list SF-v2")
                choose(0);next(3);return
            }
            if(step===3) {
                if(ticks<20||graphicenhancement.applying)return
                check(graphicenhancement.running&&graphicenhancement.nrActive&&graphicenhancement.position>beforePosition+0.5,"Lecram hot switch")
                check(!graphicenhancement.setNrLayerParameter(graphicenhancement.nrLayers[0].index,"runtime",1),"retired option rejected")
                graphicenhancement.togglePlayPause();next(4);return
            }
            if(step===4) {
                if(!graphicenhancement.paused)return
                graphicenhancement.seekTo(20);root.width=1140;root.height=720;next(5);return
            }
            if(step===5) {
                if(ticks<12)return
                graphicenhancement.togglePlayPause();next(6);return
            }
            if(step===6) {
                if(ticks<16||graphicenhancement.applying)return
                check(graphicenhancement.running&&!graphicenhancement.paused&&graphicenhancement.nrActive&&graphicenhancement.position>20.5,"NR pause seek resize resume")
                graphicenhancement.nodeMode=1;root.page="node";next(7);return
            }
            if(step===7) {
                if(ticks<10||graphicenhancement.applying)return
                check(graphicenhancement.addEffect("nr")>=0,"add NR node")
                choose(0);next(8);return
            }
            if(step===8) {
                if(ticks<16||graphicenhancement.applying)return
                check(graphicenhancement.nrActive&&graphicenhancement.chainValid,"node Lecram active")
                check(graphicenhancement.savePresetAs("NR Node Lecram",15,true),"save node Lecram")
                choose(2);next(9);return
            }
            if(step===9) {
                if(ticks<16||graphicenhancement.applying)return
                check(graphicenhancement.nrActive&&graphicenhancement.running&&graphicenhancement.position>beforePosition+0.5,"node SF-v2 active")
                graphicenhancement.nodeMode=0;root.page="pro"
                check(graphicenhancement.applyPresetIndex(preset("NR List SF-v2")),"list SF-v2 preset")
                next(10);return
            }
            if(step===10) {
                if(ticks<16||graphicenhancement.applying)return
                check(graphicenhancement.nrActive&&graphicenhancement.nrLayers.every(n=>n.runtime===2),"final list SF-v2")
                console.log("NR_UI_PASS");Qt.quit()
            }
        } catch(e) {console.warn("NR_UI_FAIL "+e.message);Qt.quit()} }
    }
