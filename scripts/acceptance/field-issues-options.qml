    Timer {
        interval: 250; running: true; repeat: true
        property int step: 0
        property int ticks: 0
        property int total: 0
        property bool restore: Qt.application.arguments.indexOf("--options-restore") >= 0
        function check(ok, label) { if(!ok) throw new Error(label) }
        function next(n) { step=n; ticks=0 }
        function preset(name) { for(var i=0;i<graphicenhancement.presets.length;++i)if(graphicenhancement.presets[i].name===name)return i;return -1 }
        onTriggered: { try {
            ++ticks;++total;if(total>650)throw new Error("bounded step="+step)
            if(step===0) {
                if(ticks<8)return
                if(restore) {
                    check(graphicenhancement.hdrOutputMode===1&&graphicenhancement.srTargetIndex===5&&graphicenhancement.srMotionSource===0&&graphicenhancement.nrMotionSource===0&&graphicenhancement.fgMotionSource===0,"saved common choices restored")
                    check(graphicenhancement.aspectMode===6,"saved preview ratio restored")
                    graphicenhancement.nodeMode=1
                    check(graphicenhancement.hdrOutputMode===1&&graphicenhancement.srTargetIndex===5&&graphicenhancement.nrMotionSource===0,"node session common choices")
                    running=false;console.log("OPTIONS_UI_RESTORE_PASS");Qt.quit();return
                }
                root.page="pro";graphicenhancement.muted=true;graphicenhancement.nrEnabled=false;graphicenhancement.srEnabled=false;graphicenhancement.fgEnabled=false
                check(graphicenhancement.hdrOutputMode===0,"fresh HDR10 default")
                graphicenhancement.fgBackendName="xess";check(graphicenhancement.fgMotionSource===0,"XeSS fresh zero motion")
                graphicenhancement.fgBackendName="dlss";check(graphicenhancement.fgMotionSource===1,"DLSS preserves prior flow default")
                graphicenhancement.openPath("E:/项目/GraphicEnhancement/tests/field-issues-20260930/media/gta6-1080p30-45s.mp4")
                next(1);return
            }
            if(ticks<16||graphicenhancement.applying||!graphicenhancement.running)return
            if(step>=1&&step<=7) {
                graphicenhancement.aspectMode=step-1
                check(graphicenhancement.aspectMode===step-1,"geometry selection")
                if(step===5)check(Math.abs(graphicenhancement.previewAspect-16/9)<.001,"forced 16:9")
                if(step===6)check(Math.abs(graphicenhancement.previewAspect-4/3)<.001,"forced 4:3")
                if(step===7)check(Math.abs(graphicenhancement.previewAspect-21/9)<.001,"forced 21:9")
                if(step<7){next(step+1);return}
                graphicenhancement.aspectMode=0;graphicenhancement.seekTo(0);graphicenhancement.srTargetIndex=2;graphicenhancement.srMotionSource=0;graphicenhancement.srEnabled=true;next(8);return
            }
            if(step===8) {
                check(graphicenhancement.srActive&&graphicenhancement.srMotionSource===0,"SR zero motion initializes")
                graphicenhancement.videoSrQuality=5;next(14);return
            }
            if(step===14) {
                check(graphicenhancement.srActive&&graphicenhancement.videoSrQuality===5&&graphicenhancement.srMotionSource===0,"FSR SR zero motion initializes")
                graphicenhancement.srMotionSource=1;next(15);return
            }
            if(step===15) {
                check(graphicenhancement.srActive&&graphicenhancement.srMotionSource===1,"FSR SR flow initializes")
                graphicenhancement.srMotionSource=0;next(16);return
            }
            if(step===16) {
                check(graphicenhancement.srActive&&graphicenhancement.srMotionSource===0,"FSR SR returns to zero")
                graphicenhancement.seekTo(0);graphicenhancement.videoSrQuality=0;graphicenhancement.nrMotionSource=0;graphicenhancement.nrEnabled=true;next(9);return
            }
            if(step===9) {
                check(graphicenhancement.nrActive&&graphicenhancement.nrMotionSource===0&&graphicenhancement.srActive,"NR zero motion initializes")
                graphicenhancement.fgBackendName="xess";graphicenhancement.fgMultiplier=4;graphicenhancement.fgEnabled=true;next(10);return
            }
            if(step===10) {
                check(graphicenhancement.fgActive&&graphicenhancement.fgMotionSource===0,"XeSS zero motion 4X active "+graphicenhancement.statusText)
                graphicenhancement.fgMotionSource=1;next(11);return
            }
            if(step===11) {
                check(graphicenhancement.fgActive&&graphicenhancement.fgMotionSource===1,"XeSS external flow active")
                graphicenhancement.fgEnabled=false;graphicenhancement.srEnabled=false;graphicenhancement.nrEnabled=false;next(12);return
            }
            if(step===12) {
                graphicenhancement.hdrOutputMode=1;graphicenhancement.srTargetIndex=5;graphicenhancement.fgMotionSource=0;graphicenhancement.srMotionSource=0;graphicenhancement.nrMotionSource=0
                check(graphicenhancement.savePresetAs("Field Rendering Choices",15,false),"save list common choices")
                graphicenhancement.hdrOutputMode=0;graphicenhancement.srTargetIndex=2;graphicenhancement.srMotionSource=1
                check(graphicenhancement.applyPresetIndex(preset("Field Rendering Choices")),"apply list common choices")
                check(graphicenhancement.hdrOutputMode===1&&graphicenhancement.srTargetIndex===5&&graphicenhancement.srMotionSource===0,"list common choices restored")
                graphicenhancement.nodeMode=1;root.page="node";next(13);return
            }
            if(step===13) {
                check(graphicenhancement.hdrOutputMode===1&&graphicenhancement.srTargetIndex===5&&graphicenhancement.nrMotionSource===0,"node common choices")
                check(graphicenhancement.savePresetAs("Field Node Rendering Choices",15,true),"save node common choices")
                graphicenhancement.nodeMode=0;graphicenhancement.aspectMode=6;running=false;console.log("OPTIONS_UI_PASS");Qt.quit()
            }
        } catch(e) {running=false;console.log("OPTIONS_UI_FAIL "+e.message);Qt.quit()} }
    }
