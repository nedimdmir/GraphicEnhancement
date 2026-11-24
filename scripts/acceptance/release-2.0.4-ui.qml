import QtQuick

Item {
    id: test
    property string media: ""
    property bool restore: false
    property int phase: 0
    property int ticks: 0
    property double startPosition: 0
    property var expected: ({})
    function require(ok,why) { if (!ok) throw new Error(why) }
    function values() {
        return {backend:graphicenhancement.fgBackendName,multiplier:graphicenhancement.fgMultiplier,
            vfgQuality:graphicenhancement.vfgQuality,motion:graphicenhancement.fgMotionSource,
            opticalFlow:graphicenhancement.opticalFlowChoice,amdHalf:graphicenhancement.amdFlowHalf,
            flowQuality:graphicenhancement.flowQuality,contentRate:graphicenhancement.contentRate,
            strict:graphicenhancement.fgStrict,lowQueue:graphicenhancement.fgLowQueue}
    }
    function check(want) {
        const got=values()
        for (const key in want) require(got[key]===want[key],key+" expected="+want[key]+" got="+got[key])
    }
    Timer {
        interval:250;running:true;repeat:true
        onTriggered: { try {
            ++test.ticks
            test.require(test.ticks<400,"100s UI deadline phase="+test.phase)
            test.require(!graphicenhancement.failed,"playback failed "+graphicenhancement.statusText)
            if (test.phase===0) {
                if(test.ticks<8)return
                test.require(graphicenhancement.setPreference("listInspectorWidth",480),"panel width preference")
                test.require(Number(graphicenhancement.preferences.listInspectorWidth)===480,"panel width not applied")
                test.require(!graphicenhancement.setPreference("listInspectorWidth",1),"invalid panel width accepted")
                test.require(graphicenhancement.preferences.gpuPriority===undefined||graphicenhancement.preferences.gpuPriority==="realtime","fresh profile default")
                test.require(graphicenhancement.gpuPriorityStatus.length>0,"GPU priority status missing")
                graphicenhancement.nodeMode=0;graphicenhancement.muted=true;graphicenhancement.nrEnabled=false;graphicenhancement.srEnabled=false;graphicenhancement.fgEnabled=false
                if(test.restore) {
                    const rows=graphicenhancement.fgPresets
                    test.require(rows.length===2&&rows[0].name==="204 persisted FG","FG preset did not survive restart")
                    test.require(graphicenhancement.applyFgPreset(rows[0].index),"restore apply failed")
                    test.check({backend:"dlss",multiplier:2,opticalFlow:0,amdHalf:true,flowQuality:0,contentRate:3,strict:true,lowQueue:true})
                    test.require(!graphicenhancement.applyFgPreset(rows[1].index),"rejected field incorrectly reported as a complete preset")
                    test.require(graphicenhancement.flowQuality===0,"rejected field replaced the last valid setting")
                    console.log("RELEASE_204_FG_REJECT_PASS")
                    test.require(graphicenhancement.deleteFgPreset(1)&&graphicenhancement.deleteFgPreset(0)&&graphicenhancement.fgPresets.length===0,"delete persisted preset")
                    console.log("RELEASE_204_UI_RESTORE_PASS",JSON.stringify(test.values()));Qt.quit();return
                }
                graphicenhancement.fgBackendName="dlss";graphicenhancement.fgMultiplier=2;graphicenhancement.vfgQuality=2
                graphicenhancement.fgMotionSource=1;graphicenhancement.setOpticalFlowChoice(0);graphicenhancement.amdFlowHalf=true;graphicenhancement.flowQuality=0;graphicenhancement.contentRate=3
                graphicenhancement.fgStrict=true;graphicenhancement.fgLowQueue=true
                test.expected=test.values()
                test.require(graphicenhancement.saveFgPreset("204 persisted FG",false),"FG save")
                test.require(!graphicenhancement.saveFgPreset("204 persisted FG",false),"duplicate save silently accepted")
                test.require(graphicenhancement.saveFgPreset("204 temporary",false),"second FG save")
                test.require(graphicenhancement.fgPresets.length===2,"saved FG count")
                graphicenhancement.fgEnabled=false;graphicenhancement.flowQuality=2;graphicenhancement.contentRate=0;graphicenhancement.amdFlowHalf=false;graphicenhancement.fgStrict=false;graphicenhancement.fgLowQueue=false
                test.require(graphicenhancement.applyFgPreset(0),"FG apply")
                test.check(test.expected)
                test.require(graphicenhancement.deleteFgPreset(1)&&graphicenhancement.fgPresets.length===1,"FG delete")
                console.log("RELEASE_204_FG_PRESET_PASS",JSON.stringify(test.values()))
                graphicenhancement.fgEnabled=false;graphicenhancement.openPath(test.media);test.phase=1
            } else if(test.phase===1) {
                if(!graphicenhancement.running||graphicenhancement.applying||graphicenhancement.position<.5)return
                test.startPosition=graphicenhancement.position
                graphicenhancement.setPreference("listInspectorWidth",540)
                graphicenhancement.page="min";graphicenhancement.page="pro"
                test.phase=2
            } else if(test.phase===2) {
                if(graphicenhancement.position<test.startPosition+1)return
                test.require(graphicenhancement.running,"width/page change stopped playback")
                test.require(Number(graphicenhancement.preferences.listInspectorWidth)===540,"panel width changed unexpectedly")
                test.require(graphicenhancement.gpuPriorityStatus.length>0,"GPU priority status missing during playback")
                console.log("RELEASE_204_UI_PASS",graphicenhancement.position,graphicenhancement.gpuPriorityStatus)
                graphicenhancement.stopPlayback();Qt.quit()
            }
        } catch(e) { console.error("RELEASE_204_UI_FAIL",e.message);Qt.quit() } }
    }
}
