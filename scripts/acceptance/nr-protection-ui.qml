// Loaded only into the task's candidate copy while exercising the real bridge.
import QtQuick
import GraphicEnhancement
Item {
    id: test
    property string media: ""
    property string evidence: ""
    property bool resume: false
    property bool multi: false
    property bool visual: false
    property bool styleFollowup: false
    property var appWindow: Window.window
    property int step: 0
    property int ticks: 0
    property int entered: 0
    property int savedIndex: -1
    width: appWindow ? appWindow.width : 1280
    height: appWindow ? appWindow.height : 720
    function find(item,name){
        if(item.objectName===name)return item
        for(const child of item.children||[]){const hit=find(child,name);if(hit)return hit}
        return null
    }
    function require(ok,why){
        if(!ok){console.error("NR_CONTROLS_UI_FAIL",step,why);timer.stop();Qt.quit();throw new Error(why)}
    }
    function next(n){step=n;entered=ticks}
    function elapsed(n){return ticks-entered>=n}
    function edit(key,value){require(graphicenhancement.setNrLayerParameter(graphicenhancement.nrLayers[0].index,key,value),"edit rejected: "+key)}
    function capture(label){
        console.log("NR_CONTROLS_STATE",label,JSON.stringify(graphicenhancement.nrLayers),JSON.stringify(graphicenhancement.stageTimings),graphicenhancement.statusText)
        graphicenhancement.logUi("nr-controls-test",label+" "+JSON.stringify(graphicenhancement.nrLayers))
        graphicenhancement.takeScreenshot()
    }
    NrLayerEditor {
        id: controls
        anchors.right: parent.right;anchors.top: parent.top;anchors.margins: 10
        width: 360;listControls: false
        layerData: graphicenhancement.nrLayers.length ? graphicenhancement.nrLayers[0] : ({index:0,runtime:0,intensity:1,tone:1,structure:1,skin:-1,style:0,autoMask:0,uiCorrection:0,total:1,darken:1,brighten:1,color:1,luminance:1,temporal:false,antiFlicker:2,sizePolicy:0})
        layerCount: graphicenhancement.nrLayers.length
        onEdited: (index,key,amount) => test.require(graphicenhancement.setNrLayerParameter(index,key,amount),"control rejected: "+key)
    }
    Connections {
        target: graphicenhancement
        function onNotice(message,error){console.log("NR_CONTROLS_NOTICE",message,error)}
    }
    Timer {
        id: timer;interval: 100;repeat: true;running: true
        onTriggered: {
            if(++test.ticks>2400){test.require(false,"240s deadline");return}
            if(!test.media.length||test.ticks<12)return
            if(test.multi){
                if(test.step===0){
                    graphicenhancement.nodeMode=0;graphicenhancement.nrEnabled=true;graphicenhancement.srEnabled=false;graphicenhancement.fgEnabled=false
                    if(test.styleFollowup){test.edit("runtime",3);test.edit("style",1)}
                    test.edit("total",5);test.edit("correctionEnabled",1)
                    test.require(graphicenhancement.duplicateNrLayer(graphicenhancement.nrLayers[0].index)>=0,"two-layer creation failed")
                    const second=graphicenhancement.nrLayers[1].index
                    if(test.styleFollowup)test.require(graphicenhancement.setNrLayerParameter(second,"style",2),"second style rejected")
                    test.require(graphicenhancement.setNrLayerParameter(second,"correctionAuto",0),"second manual mode rejected")
                    test.require(graphicenhancement.setNrLayerParameter(second,"temporalStability",.5),"second stability rejected")
                    test.require(graphicenhancement.setProtectionRegion(.1,.1,.3,.3,0),"stack protection region rejected")
                    graphicenhancement.protectionEnabled=true
                    test.require(graphicenhancement.setPreference("screenshotDir",test.evidence+"/screenshots"),"multi screenshot directory rejected")
                    graphicenhancement.openPath(test.media);test.next(1)
                }else if(test.step===1){
                    test.require(!graphicenhancement.failed,"two-layer preview failed: "+graphicenhancement.statusText)
                    if(!graphicenhancement.nrActive||graphicenhancement.position<.8)return
                    if(!graphicenhancement.paused)graphicenhancement.togglePlayPause()
                    test.next(2)
                }else if(test.step===2){
                    if(!test.elapsed(20))return
                    test.require(graphicenhancement.nrLayers.length===2&&graphicenhancement.nrActive&&!graphicenhancement.failed,"two-layer graph not active")
                    test.capture("two-controlled-layers-with-protection")
                    console.log("NR_CONTROLS_MULTI_PASS")
                    timer.stop();Qt.quit()
                }
                return
            }
            if(test.resume){
                if(test.step===0){
                    test.require(graphicenhancement.nodeMode===0&&graphicenhancement.nrLayers.length===1,"list session not restored")
                    const n=graphicenhancement.nrLayers[0]
                    test.require(n.total===5&&n.correctionEnabled&&!n.correctionAuto&&Math.abs(n.hueProtection-.4)<1e-5&&Math.abs(n.chromaProtection-.3)<1e-5,"manual session values not restored")
                    if(test.styleFollowup)test.require(n.style===2&&n.runtime===3&&Math.abs(n.neutralProtection-.6)<1e-5&&Math.abs(n.colorRetention-.35)<1e-5&&Math.abs(n.luminanceRetention-.2)<1e-5&&Math.abs(n.shadowProtection-.5)<1e-5&&Math.abs(n.correctionAmount-.7)<1e-5,"extended list session lost parameters")
                    graphicenhancement.nodeMode=1;test.next(1)
                }else if(test.step===1){
                    if(!test.elapsed(8))return
                    const n=graphicenhancement.nrLayers[0]
                    test.require(n&&n.total===5&&n.correctionEnabled&&!n.correctionAuto&&Math.abs(n.hueProtection-.42)<1e-5,"node session values not restored")
                    if(test.styleFollowup)test.require(Math.abs(n.neutralProtection-.43)<1e-5&&Math.abs(n.colorRetention-.52)<1e-5&&Math.abs(n.luminanceRetention-.31)<1e-5&&Math.abs(n.shadowProtection-.64)<1e-5&&Math.abs(n.correctionAmount-.62)<1e-5,"extended node session lost parameters")
                    graphicenhancement.nodeMode=0
                    console.log("NR_CONTROLS_RESTORE_PASS")
                    timer.stop();Qt.quit()
                }
                return
            }
            if(test.step===0){
                graphicenhancement.nodeMode=0;graphicenhancement.nrEnabled=true;graphicenhancement.srEnabled=false;graphicenhancement.fgEnabled=false
                if(!graphicenhancement.nrLayers.length)graphicenhancement.addEffect("nr")
                test.require(graphicenhancement.nrLayers.length===1,"expected isolated default NR layer")
                if(test.styleFollowup){test.edit("runtime",3);test.edit("style",2)}
                test.require(!graphicenhancement.nrLayers[0].correctionEnabled,"new profile correction must default off")
                test.require(graphicenhancement.setPreference("screenshotDir",test.evidence+"/screenshots"),"task screenshot directory rejected")
                const residual=test.find(controls,"nr-residual-group"),group=test.find(controls,"nr-correction-group")
                test.require(residual&&group,"new shared NR groups missing")
                residual.expanded=true;group.expanded=true
                test.require(test.find(controls,"nr-total").to===5,"strength slider ceiling is not five")
                test.find(controls,"nr-total").moved(5)
                test.require(graphicenhancement.nrLayers[0].total===5,"slider five did not reach settings")
                graphicenhancement.openPath(test.media);test.next(1)
            }else if(test.step===1){
                test.require(!graphicenhancement.failed,"real preview failed: "+graphicenhancement.statusText)
                if(!graphicenhancement.nrActive||graphicenhancement.position<.8)return
                if(!graphicenhancement.paused)graphicenhancement.togglePlayPause()
                test.next(2)
            }else if(test.step===2){
                if(!test.elapsed(20)||!graphicenhancement.paused)return
                test.capture("raw-five")
                test.find(controls,"nr-correctionEnabled").toggled(true)
                test.require(graphicenhancement.nrLayers[0].correctionEnabled&&graphicenhancement.nrLayers[0].correctionAuto,"auto switch not applied")
                test.next(3)
            }else if(test.step===3){
                if(!test.elapsed(45))return
                test.require(!graphicenhancement.failed&&graphicenhancement.nrActive,"controlled paused preview failed")
                test.capture("auto-five")
                if(test.styleFollowup)test.find(controls,"nr-correctionAmount").moved(.7)
                test.find(controls,"nr-correctionAuto").picked("0")
                if(test.styleFollowup){
                    test.find(controls,"nr-use-auto-defaults").clicked()
                    test.require(Math.abs(graphicenhancement.nrLayers[0].colorRetention-.665)<1e-5&&Math.abs(graphicenhancement.nrLayers[0].luminanceRetention-.14)<1e-5,"style-specific automatic values not copied")
                }
                test.find(controls,"nr-hueProtection").moved(.4)
                test.find(controls,"nr-chromaProtection").moved(.3)
                test.find(controls,"nr-highlightProtection").moved(.9)
                test.find(controls,"nr-localCompression").moved(.7)
                test.find(controls,"nr-temporalStability").moved(.8)
                if(test.styleFollowup){
                    test.find(controls,"nr-neutralProtection").moved(.6)
                    test.find(controls,"nr-colorRetention").moved(.35)
                    test.find(controls,"nr-luminanceRetention").moved(.2)
                    test.find(controls,"nr-shadowProtection").moved(.5)
                }
                test.next(4)
            }else if(test.step===4){
                if(!test.elapsed(30))return
                const n=graphicenhancement.nrLayers[0]
                test.require(!n.correctionAuto&&n.total===5&&Math.abs(n.hueProtection-.4)<1e-5,"manual slider values not applied")
                test.capture("manual-five")
                test.require(graphicenhancement.savePresetAs("NR correction manual five",1,false),"production preset save failed")
                const saved=graphicenhancement.presetChoices.find(p=>p.label==="NR correction manual five")
                test.savedIndex=saved ? Number(saved.id) : -1
                test.require(test.savedIndex>=0,"saved preset missing from choices")
                test.find(controls,"nr-correctionEnabled").toggled(false)
                test.require(graphicenhancement.nrLayers[0].total===5&&!graphicenhancement.nrLayers[0].correctionEnabled&&Math.abs(graphicenhancement.nrLayers[0].hueProtection-.4)<1e-5,"off must preserve gain/manual values")
                test.next(5)
            }else if(test.step===5){
                if(!test.elapsed(30))return
                test.capture("raw-five-restored")
                if(test.visual){console.log("NR_CONTROLS_VISUAL_PASS");timer.stop();Qt.quit();return}
                const index=graphicenhancement.nrLayers[0].index
                test.require(graphicenhancement.resetNrLayer(index),"NR reset failed")
                test.require(graphicenhancement.nrLayers[0].total===1&&!graphicenhancement.nrLayers[0].correctionEnabled,"NR reset defaults wrong")
                test.require(graphicenhancement.applyPresetIndex(test.savedIndex),"NR preset apply failed")
                test.require(graphicenhancement.nrLayers[0].total===5&&graphicenhancement.nrLayers[0].correctionEnabled&&!graphicenhancement.nrLayers[0].correctionAuto,"preset did not restore mode and gain")
                if(test.styleFollowup)test.require(Math.abs(graphicenhancement.nrLayers[0].colorRetention-.35)<1e-5&&Math.abs(graphicenhancement.nrLayers[0].correctionAmount-.7)<1e-5,"extended preset did not restore values")
                const duplicate=graphicenhancement.duplicateNrLayer(graphicenhancement.nrLayers[0].index)
                test.require(duplicate>=0&&graphicenhancement.nrLayers.length===2&&Math.abs(graphicenhancement.nrLayers[1].hueProtection-.4)<1e-5&&graphicenhancement.nrLayers[1].total===5,"duplicate lost correction values")
                if(test.styleFollowup)test.require(Math.abs(graphicenhancement.nrLayers[1].colorRetention-.35)<1e-5,"duplicate lost source-color value")
                test.require(graphicenhancement.removeEffect(duplicate),"duplicate cleanup failed")
                graphicenhancement.nodeMode=1
                if(!graphicenhancement.nrLayers.length)graphicenhancement.addEffect("nr")
                test.edit("total",5);test.edit("correctionEnabled",1);test.edit("correctionAuto",0);test.edit("hueProtection",.42)
                if(test.styleFollowup){test.edit("neutralProtection",.43);test.edit("colorRetention",.52);test.edit("luminanceRetention",.31);test.edit("shadowProtection",.64);test.edit("correctionAmount",.62)}
                test.require(graphicenhancement.nrLayers[0].total===5&&Math.abs(graphicenhancement.nrLayers[0].hueProtection-.42)<1e-5,"node parameter editing failed")
                graphicenhancement.nodeMode=0;test.next(6)
            }else if(test.step===6){
                if(!test.elapsed(25))return
                graphicenhancement.exportCompletionSound=false;graphicenhancement.exportSrTargetIndex=2;graphicenhancement.exportHevc=true
                graphicenhancement.exportRateControl=1;graphicenhancement.exportBitrateMbps=12
                graphicenhancement.addExportFiles([test.media]);test.next(7)
            }else if(test.step===7){
                if(graphicenhancement.exportReadyCount!==1)return
                graphicenhancement.startExport();test.require(graphicenhancement.exportRunning,"real NR export not started");test.next(8)
            }else if(test.step===8){
                if(graphicenhancement.exportRunning)return
                test.require(graphicenhancement.exportItems.some(i=>i.state==="done"),"real NR export failed")
                graphicenhancement.stopPlayback()
                console.log("NR_CONTROLS_UI_PASS",JSON.stringify(graphicenhancement.nrLayers),JSON.stringify(graphicenhancement.exportItems))
                timer.stop();Qt.quit()
            }
        }
    }
}
