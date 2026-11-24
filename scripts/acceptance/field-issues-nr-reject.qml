    Timer {
        interval: 250; running: true; repeat: true
        property int step: 0
        property int ticks: 0
        property int total: 0
        property double positionBefore: 0
        function check(value,label) { if(!value)throw new Error(label) }
        onTriggered: { try {
            ++ticks;++total;if(total>240)throw new Error("bounded step="+step)
            if(step===0) {
                if(ticks<8)return
                root.page="pro";graphicenhancement.muted=true
                graphicenhancement.srEnabled=false;graphicenhancement.fgEnabled=false;graphicenhancement.nrEnabled=true
                check(graphicenhancement.nrLayers[0].runtime===0,"initial Lecram")
                graphicenhancement.openPath("E:/项目/GraphicEnhancement/tests/nr-sfv2-lecram-20260930/media/gta6-native-4k30-silent-90s.mp4")
                step=1;ticks=0;return
            }
            if(step===1) {
                if(ticks<20||!graphicenhancement.running||graphicenhancement.applying)return
                check(graphicenhancement.nrActive,"Lecram active")
                positionBefore=graphicenhancement.position
                check(graphicenhancement.setNrLayerParameter(graphicenhancement.nrLayers[0].index,"runtime",2),"enqueue SF-v2 request")
                step=2;ticks=0;return
            }
            if(step===2) {
                if(ticks<24||graphicenhancement.applying)return
                check(graphicenhancement.running&&graphicenhancement.nrActive&&graphicenhancement.position>positionBefore+0.5,"working Lecram playback restored")
                check(graphicenhancement.nrLayers.every(n=>n.runtime===0),"selector restored to actual Lecram")
                graphicenhancement.logUi("nr-reject-test","NR_UI_REJECT_PASS");Qt.quit()
            }
        } catch(e) {graphicenhancement.logUi("nr-reject-test","NR_UI_REJECT_FAIL "+e.message);Qt.quit()} }
    }
