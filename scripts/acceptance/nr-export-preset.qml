import QtQuick
Item {
    id: test
    property string media: ""
    property string output: ""
    property int phase: 0
    property int ticks: 0
    property int total: 0
    function check(ok,why){if(!ok)throw new Error(why)}
    function next(n){phase=n;ticks=0}
    Timer {id:timer;interval:250;repeat:true;running:test.media!==""
        onTriggered:{try{
            ++test.ticks;if(++test.total>520)throw new Error("130 second timeout")
            if(test.phase===0){
                if(test.ticks<8)return
                root.page="pro";graphicenhancement.muted=true;graphicenhancement.nodeMode=0;graphicenhancement.srEnabled=false;graphicenhancement.fgEnabled=false;graphicenhancement.nrEnabled=true
                const index=graphicenhancement.nrLayers[0].index
                check(graphicenhancement.setNrLayerParameter(index,"runtime",2),"SF runtime")
                check(graphicenhancement.setNrLayerParameter(index,"sizePercent",37),"manual 37%")
                check(graphicenhancement.savePresetAs("NR export percent 37",15,false),"save manual preset")
                const preset=graphicenhancement.presets.findIndex(x=>x.name==="NR export percent 37");check(preset>=0,"saved preset listed")
                check(graphicenhancement.selectExportPreset(preset),"choose independent export preset")
                check(graphicenhancement.setNrLayerParameter(index,"sizePercent",100),"different current slider")
                graphicenhancement.nrEnabled=false
                graphicenhancement.exportCompletionSound=false;graphicenhancement.exportHevc=true;graphicenhancement.exportSrTargetIndex=-1;graphicenhancement.exportRateControl=1;graphicenhancement.exportBitrateMbps=24
                graphicenhancement.enqueueExportFile(test.media,test.output);next(1)
            }else if(test.phase===1){
                if(graphicenhancement.exportReadyCount!==1)return
                graphicenhancement.startExport();check(graphicenhancement.exportRunning,"worker did not start")
                check(graphicenhancement.setNrLayerParameter(graphicenhancement.nrLayers[0].index,"sizePercent",25),"edit current preview after freeze")
                next(2)
            }else if(test.phase===2){
                if(graphicenhancement.exportRunning)return
                check(graphicenhancement.exportItems.filter(x=>x.state==="done").length===1,"export failed: "+graphicenhancement.exportStatus)
                check(graphicenhancement.nrLayers[0].sizePercent===25&&!graphicenhancement.nrEnabled,"export changed current preview settings")
                console.log("NR_EXPORT_PRESET_PASS",graphicenhancement.exportPresetName,graphicenhancement.exportStatus);timer.stop();Qt.quit()
            }
        }catch(e){console.error("NR_EXPORT_PRESET_FAIL",test.phase,e.message);graphicenhancement.cancelExport();timer.stop();Qt.quit()}}
    }
}
