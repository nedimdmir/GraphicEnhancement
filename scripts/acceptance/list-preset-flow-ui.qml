import QtQuick
Item {
    id: test
    property string media: ""
    property string evidence: ""
    property bool restore: false
    property var appWindow: Window.window
    property int phase: 0
    property int ticks: 0
    property double startPosition: 0
    property var savedDialog: null
    property var dialogHost: null
    property bool captured: false
    function require(ok,why) { if (!ok) throw new Error(why) }
    function find(item,name) {
        if(item.objectName===name)return item
        for(const child of item.children||[]){const hit=find(child,name);if(hit)return hit}
        return null
    }
    function scroll(item) {
        if(typeof item.contentY==="number" && item.contentHeight>item.height)return item
        for(const child of item.children||[]){const hit=scroll(child);if(hit)return hit}
        return null
    }
    function flow() { return [graphicenhancement.opticalFlowChoice,graphicenhancement.flowQuality,graphicenhancement.amdFlowHalf,graphicenhancement.contentRate] }
    function checkFlow(want) { require(JSON.stringify(flow())===JSON.stringify(want),"flow expected="+JSON.stringify(want)+" got="+JSON.stringify(flow())) }
    function preset(name) { const row=graphicenhancement.presets.find(p=>p.name===name);require(row!==undefined,"missing preset "+name);return row }
    function configure(quality,half,cadence) { require(graphicenhancement.setOpticalFlowChoice(0),"NVOF selection");graphicenhancement.flowQuality=quality;graphicenhancement.amdFlowHalf=half;graphicenhancement.contentRate=cadence }
    Timer {
        interval:250;running:true;repeat:true
        onTriggered: { try {
            ++test.ticks
            test.require(test.ticks<400,"100s deadline phase="+test.phase)
            test.require(!graphicenhancement.failed,"playback failed "+graphicenhancement.statusText)
            if(test.phase===0) {
                if(test.ticks<8)return
                test.require(!test.find(test.appWindow.contentItem,"list-fg-presets"),"standalone FG card remains")
                test.require(graphicenhancement.fgPresets===undefined&&typeof graphicenhancement.saveFgPreset==="undefined","standalone FG API remains")
                if(test.restore) {
                    test.checkFlow([0,0,true,5])
                    test.require(graphicenhancement.defaultPresetIndex===test.preset("204 shared flow").index,"default preset index lost")
                    test.configure(2,false,0)
                    test.require(graphicenhancement.applyPresetIndex(test.preset("204 shared flow").index),"restart unified apply")
                    test.checkFlow([0,0,true,5])
                    console.log("LIST_PRESET_FLOW_RESTORE_PASS",JSON.stringify(test.flow()));Qt.quit();return
                }
                graphicenhancement.nodeMode=0;graphicenhancement.muted=true;graphicenhancement.nrEnabled=false;graphicenhancement.srEnabled=false;graphicenhancement.fgEnabled=false
                test.configure(0,true,5);test.checkFlow([0,0,true,5])
                test.require(test.dialogHost!==null,"production dialog host missing")
                test.dialogHost.open("save");test.phase=1
            } else if(test.phase===1) {
                const dialog=test.find(test.appWindow.contentItem,"preset-save-dialog")
                if(!dialog)return
                test.savedDialog=dialog
                const part=dialog.parts.find(p=>p.id==="flow")
                test.require(part&&part.meaningful&&part.summary.indexOf("NVIDIA NVOF")>=0&&part.summary.indexOf("60→30")>=0,"shared flow summary missing current values")
                test.require(test.find(dialog,"preset-part-flow")!==null,"shared flow checkbox missing")
                test.find(dialog,"preset-name").text="204 shared flow"
                for(const part of dialog.parts)test.find(dialog,"preset-part-"+part.id).toggled(part.id==="flow")
                const scroller=test.scroll(dialog)
                if(scroller)scroller.contentY=scroller.contentHeight-scroller.height
                test.phase=11
            } else if(test.phase===11) {
                test.require(test.find(test.savedDialog,"preset-part-flow").checked &&
                    !test.find(test.savedDialog,"preset-part-chain").checked,"production checkbox did not reflect choices")
                test.appWindow.contentItem.grabToImage(result=>{test.require(result.saveToFile(test.evidence+"/screenshots/unified-flow-save.png"),"save-dialog screenshot");test.captured=true})
                test.phase=2
            } else if(test.phase===2) {
                if(!test.captured)return
                test.savedDialog.actionTriggered("保存预设")
                const row=test.preset("204 shared flow")
                test.require(row.contents===16&&!row.nodeMode,"dialog saved incorrect mask or kind")
                test.require(graphicenhancement.exportPreset(row.index,test.evidence+"/shared-flow.v10"),"preset export")
                test.require(graphicenhancement.importPreset(test.evidence+"/shared-flow.v10"),"preset import")
                test.configure(2,false,0)
                test.require(graphicenhancement.applyPresetIndex(row.index),"unified flow-only preset apply")
                test.checkFlow([0,0,true,5])
                test.require(!graphicenhancement.fgEnabled&&!graphicenhancement.nrEnabled&&!graphicenhancement.srEnabled,"flow-only changed effects")
                test.require(graphicenhancement.savePresetAs("204 chain without flow",1,false),"save unselected shared flow")
                test.configure(2,false,3)
                test.require(graphicenhancement.applyPresetIndex(test.preset("204 chain without flow").index),"chain-only preset apply")
                test.checkFlow([0,2,false,3])
                graphicenhancement.nodeMode=1;test.configure(1,true,2)
                test.require(graphicenhancement.savePresetAs("204 node flow",16,true),"node flow save")
                test.configure(2,false,4)
                test.require(graphicenhancement.applyPresetIndex(test.preset("204 node flow").index),"node flow apply")
                test.checkFlow([0,1,true,2])
                graphicenhancement.nodeMode=0
                test.require(graphicenhancement.setDefaultPreset(row.index),"set shared flow startup default")
                test.require(graphicenhancement.applyPresetIndex(row.index),"list flow after mode switch")
                test.checkFlow([0,0,true,5])
                console.log("LIST_PRESET_FLOW_SCOPE_PASS",JSON.stringify(graphicenhancement.presets))
                // Source cadence is allowed to differ; applying the preset must keep playback progressing.
                test.configure(0,true,0);graphicenhancement.openPath(test.media);test.phase=3
            } else if(test.phase===3) {
                if(!graphicenhancement.running||graphicenhancement.applying||graphicenhancement.position<.5)return
                test.startPosition=graphicenhancement.position
                test.require(graphicenhancement.applyPresetIndex(test.preset("204 shared flow").index),"flow preset during playback")
                test.checkFlow([0,0,true,5]);test.phase=4
            } else if(test.phase===4) {
                if(graphicenhancement.applying||graphicenhancement.position<test.startPosition+1)return
                test.require(graphicenhancement.running,"preset stalled playback")
                console.log("LIST_PRESET_FLOW_UI_PASS",graphicenhancement.position,JSON.stringify(test.flow()))
                graphicenhancement.stopPlayback();Qt.quit()
            }
        } catch(e) { console.error("LIST_PRESET_FLOW_UI_FAIL",e.message);Qt.quit() } }
    }
}
