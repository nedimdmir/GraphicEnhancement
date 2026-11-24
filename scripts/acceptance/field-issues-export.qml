    Timer {
        interval: 500; running: true; repeat: true
        property int step: 0
        property int ticks: 0
        property int total: 0
        onTriggered: { try {
            ++ticks;++total;if(total>480)throw new Error("bounded export step="+step)
            if(step===0) {
                if(ticks<4)return
                root.page="pro";graphicenhancement.muted=true;graphicenhancement.nrEnabled=false;graphicenhancement.srEnabled=false;graphicenhancement.fgEnabled=false
                graphicenhancement.openPath("E:/项目/GraphicEnhancement/tests/nr-sfv2-lecram-20260930/media/gta6-native-4k30-silent-90s.mp4")
                step=1;ticks=0;return
            }
            if(step===1) {
                if(ticks<6||!graphicenhancement.running)return
                // Exclude the exact 4.000 endpoint: the export trim includes it.
                graphicenhancement.exportTrimStart=0;graphicenhancement.exportTrimEnd=3.98
                graphicenhancement.stopPlayback();step=2;ticks=0;return
            }
            if(step===2) {
                if(ticks<4||graphicenhancement.running)return
                graphicenhancement.nrEnabled=Qt.application.arguments.indexOf("--without-nr")<0
                graphicenhancement.srEnabled=true;graphicenhancement.srTargetIndex=3;graphicenhancement.exportSrTargetIndex=3;graphicenhancement.exportHevc=true
                graphicenhancement.exportRateControl=2;graphicenhancement.startExport();step=3;ticks=0;return
            }
            if(step===3) {
                if(ticks<4)return
                if(graphicenhancement.exportRunning)return
                if(graphicenhancement.exportEncoded!==120)throw new Error("encoded="+graphicenhancement.exportEncoded+" status="+graphicenhancement.exportStatus+" failures="+graphicenhancement.exportQueueFailure)
                running=false;graphicenhancement.logUi("export-repro","EXPORT_8K_120_PASS "+graphicenhancement.exportStatus);Qt.quit()
            }
        } catch(e) {running=false;graphicenhancement.cancelExport();graphicenhancement.logUi("export-repro","EXPORT_8K_FAIL "+e.message);Qt.quit()} }
    }
