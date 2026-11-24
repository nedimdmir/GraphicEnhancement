import QtQuick
Item {
    id: test
    property string config: "{}"
    readonly property var cfg: JSON.parse(config)
    property int phase: 0
    property int ticks: 0
    property int total: 0
    function check(ok,why){if(!ok)throw new Error(why)}
    function next(n){phase=n;ticks=0}
    function sample(mark){console.log("CAPTURE_FG_"+mark,JSON.stringify({caseName:cfg.name,half:cfg.half,format:graphicenhancement.captureFormatLabel,source:graphicenhancement.sourceSummary,fgActive:graphicenhancement.fgActive,backend:graphicenhancement.fgBackendName,submitFps:graphicenhancement.submitFps,inputFps:graphicenhancement.captureFps,dropped:graphicenhancement.captureDropped,status:graphicenhancement.runStatusDetail}))}
    Timer {id: timer;interval:250;repeat:true;running:test.config!=="{}"
        onTriggered:{try{
            ++test.ticks;if(++test.total>480)throw new Error("120 second deadline phase "+test.phase)
            if(test.phase===0){
                if(test.ticks<8)return
                root.page="pro";graphicenhancement.muted=true;graphicenhancement.nrEnabled=false;graphicenhancement.srEnabled=false;graphicenhancement.refreshCaptureDevices();next(1)
            }else if(test.phase===1){
                if(graphicenhancement.captureQueryBusy||test.ticks<4)return
                const device=graphicenhancement.captureDevices.find(x=>x.label.indexOf("KUHAIMI G50")>=0)
                check(!!device,"KUHAIMI G50 not present")
                graphicenhancement.captureDeviceId=device.id;next(2)
            }else if(test.phase===2){
                if(graphicenhancement.captureQueryBusy||test.ticks<4)return
                const format=graphicenhancement.captureFormats.find(x=>x.width===2560&&x.height===1440&&Math.abs(x.fps-60)<0.01&&x.pixel==="NV12"&&!x.interlaced&&!x.disabled)
                check(!!format,"exact 2560x1440p60 NV12 not advertised")
                graphicenhancement.captureFormatKey=format.id;graphicenhancement.captureAudioChoice=-1;graphicenhancement.captureBufferMode=0
                graphicenhancement.contentRate=test.cfg.half?5:0;graphicenhancement.outputRateMode=0;graphicenhancement.variableRefresh=false;graphicenhancement.displaySync=2
                check(graphicenhancement.addEffect("vfg-fg")>=0,"VFG stage")
                graphicenhancement.vfgQuality=1;graphicenhancement.fgMultiplier=2
                check(graphicenhancement.startCaptureSession(),"capture open refused: "+graphicenhancement.captureStatus)
                next(3)
            }else if(test.phase===3){
                if(!graphicenhancement.running||!graphicenhancement.fgActive||graphicenhancement.applying||test.ticks<24)return
                check(graphicenhancement.captureFormatLabel.indexOf("NV12")>=0,"selection changed pixel format")
                sample("BEGIN");next(4)
            }else if(test.phase===4){
                check(graphicenhancement.running&&graphicenhancement.fgActive,"capture or VFG stopped: "+graphicenhancement.statusText)
                if(test.ticks%4===0)sample("SAMPLE")
                if(test.ticks<test.cfg.seconds*4)return
                sample("END");graphicenhancement.takeScreenshot();next(5)
            }else if(test.phase===5){
                if(test.ticks<8)return
                graphicenhancement.stopPlayback();next(6)
            }else if(test.phase===6){
                if(test.ticks<8)return
                check(!graphicenhancement.running,"capture did not stop")
                console.log("CAPTURE_FG_PASS",test.cfg.name);timer.stop();Qt.quit()
            }
        }catch(e){console.error("CAPTURE_FG_FAIL",test.cfg.name,test.phase,e.message);graphicenhancement.stopPlayback();timer.stop();Qt.quit()}}
    }
}
