import QtQuick
Item {
    id: test
    property string media: ""
    property string shot: ""   // screenshot path from the runner; empty skips it
    property bool saved: false
    function find(name) {
        let hit=null
        const walk=item=>{if(hit)return;if(item.objectName===name){hit=item;return}for(const c of item.children)walk(c)}
        walk(test.parent.parent);return hit
    }
    Timer {
        interval:500;running:test.media.length>0;repeat:true
        property int step:0
        property int ticks:0
        property int total:0
        function next(n){step=n;ticks=0}
        function check(ok,label){if(!ok)throw new Error(label);graphicenhancement.logUi("sr-stage-test","PASS "+label)}
        function settled(){return ticks>=7&&graphicenhancement.running&&!graphicenhancement.applying}
        onTriggered:{try{
            ++ticks;if(++total>260)throw new Error("bounded SR stage test step="+step)
            if(step===0){
                if(ticks<4)return
                graphicenhancement.muted=true;graphicenhancement.nrEnabled=false;graphicenhancement.fgEnabled=false
                graphicenhancement.srEnabled=true;graphicenhancement.videoSrQuality=1;graphicenhancement.dualSrEnabled=false;graphicenhancement.srTargetIndex=3
                graphicenhancement.openPath(test.media);next(1);return
            }
            if(step===1){
                if(!settled())return
                check(graphicenhancement.srTargetIndex===3&&graphicenhancement.outputSummary==="7680x4320"&&graphicenhancement.srStageSummary==="","ordinary 8K remains an actual 8K output")
                check(!find("list-dual-sr-panel").visible,"second-pass settings start collapsed")
                find("list-sr-output").picked("3");next(11);return
            }
            if(step===11){
                if(!settled())return
                check(graphicenhancement.srOutput===3&&graphicenhancement.outputSummary==="3840x2160"&&graphicenhancement.srStageSummary==="1920x1080 → 7680x4320 → 3840x2160",
                      "supersample evaluates 8K and outputs the 4K shrink: "+graphicenhancement.srStageSummary)
                check(find("list-sr").summary.indexOf("8K→4K")>=0,"the card summary shows the supersample shrink: "+find("list-sr").summary)
                test.saved=false
                if(test.shot.length>0)test.parent.parent.grabToImage(r=>{r.saveToFile(test.shot.replace(/\.png$/,"-supersample.png"));test.saved=true})
                else test.saved=true
                next(115);return
            }
            if(step===115){
                if(!test.saved||ticks<3)return
                find("list-sr-output").picked("0");next(12);return
            }
            if(step===12){
                if(!settled())return
                check(graphicenhancement.outputSummary==="7680x4320"&&graphicenhancement.srStageSummary===""&&find("list-sr").summary.indexOf("→")<0,"no shrink returns to the ordinary 8K output")
                graphicenhancement.srTargetIndex=2;next(2);return
            }
            if(step===2){
                if(!settled())return
                find("list-dual-sr-toggle").toggled(true);next(3);return
            }
            if(step===3){
                if(!settled())return
                check(graphicenhancement.dualSrEnabled&&find("list-dual-sr-panel").visible,"Double SR control expands the second-pass settings")
                check(graphicenhancement.srTargetIndex===2&&graphicenhancement.srStageSummary==="1920x1080 → 3840x2160 → 1920x1080 → 3840x2160","first SR then reduce then second SR in the running plan")
                check(find("list-sr").summary.indexOf("4K→1080p→4K")>=0,"the card summary shows base 4K, then 1080p, then the second 4K: "+find("list-sr").summary)
                check(!find("list-sr-output").enabled,"the supersample shrink is unavailable while double SR is on")
                find("list-dual-sr-quality").picked("2");find("list-dual-sr-target").picked("1");next(4);return
            }
            if(step===4){
                if(!settled())return
                check(graphicenhancement.srTargetIndex===2&&graphicenhancement.videoSrQuality===1&&graphicenhancement.dualSrTargetIndex===1&&graphicenhancement.dualSrQuality===2,"second controls do not change base target or quality")
                check(graphicenhancement.outputSummary==="2560x1440","second target owns the final output")
                check(find("list-sr").summary.indexOf("4K→1080p→2K")>=0&&find("list-sr").summary.indexOf("低 / 标准 中")>=0,"the card summary follows the second target, family and tier: "+find("list-sr").summary)
                if(test.shot.length>0)test.parent.parent.grabToImage(r=>{r.saveToFile(test.shot);test.saved=true})
                else test.saved=true
                next(45);return
            }
            if(step===45){
                if(!test.saved||ticks<3)return
                find("list-dual-sr-toggle").toggled(false);next(5);return
            }
            if(step===5){
                if(!settled())return
                check(!find("list-dual-sr-panel").visible&&graphicenhancement.outputSummary==="3840x2160"&&graphicenhancement.srStageSummary==="","disable collapses controls and restores base-only output")
                // The reduction stays saved for turning double SR back on, but must not show.
                check(graphicenhancement.srPrescale===3&&find("list-sr").summary.indexOf("1080p")<0&&find("list-sr").summary.indexOf("/")<0,
                      "the card summary drops the kept reduction while double SR is off: "+find("list-sr").summary)
                graphicenhancement.nodeMode=1;check(graphicenhancement.addEffect("sr")>=0,"add base SR to an empty node graph");graphicenhancement.navigate("node")
                graphicenhancement.videoSrQuality=1;graphicenhancement.srTargetIndex=2;next(6);return
            }
            if(step===6){
                if(!settled())return
                check(find("node-dual-sr-toggle")&&find("node-sr-output")&&!find("node-dual-sr-panel").visible,"node editor has the same supersample and collapsed double SR controls")
                find("node-dual-sr-toggle").toggled(true);graphicenhancement.srPrescale=3;find("node-dual-sr-target").picked("3");next(7);return
            }
            if(step===7){
                if(!settled())return
                check(graphicenhancement.srTargetIndex===2&&graphicenhancement.dualSrTargetIndex===3&&graphicenhancement.outputSummary==="7680x4320","node second 8K target is independent and is not forced to 4K")
                check(graphicenhancement.srStageSummary==="1920x1080 → 3840x2160 → 1920x1080 → 7680x4320","node running sizes contain both SR operations")
                graphicenhancement.dualSrEnabled=false;graphicenhancement.nodeMode=0;graphicenhancement.navigate("pro")
                graphicenhancement.srTargetIndex=2;graphicenhancement.dualSrTargetIndex=2;graphicenhancement.dualSrEnabled=true
                graphicenhancement.nrEnabled=true;graphicenhancement.fgBackendName="vfg";graphicenhancement.fgMultiplier=2;graphicenhancement.fgEnabled=true
                next(8);return
            }
            if(step===8){
                if(ticks<24||!settled())return
                check(graphicenhancement.srActive&&graphicenhancement.nrActive&&graphicenhancement.fgActive&&graphicenhancement.fgBackendName==="vfg","bounded 4K two-pass SR with NR and VFG actually runs")
                check(graphicenhancement.outputSummary==="3840x2160"&&graphicenhancement.srStageSummary==="1920x1080 → 3840x2160 → 1920x1080 → 3840x2160","combined graph retains both SR operations and the requested 4K output")
                // Shrink first, then double SR off, then the 8K target: no step ever has an 8K final output with NR/VFG.
                graphicenhancement.srOutput=3;graphicenhancement.dualSrEnabled=false;graphicenhancement.srTargetIndex=3;next(9);return
            }
            if(step===9){
                if(ticks<24||!settled())return
                check(graphicenhancement.srActive&&graphicenhancement.nrActive&&graphicenhancement.fgActive&&graphicenhancement.outputSummary==="3840x2160"&&graphicenhancement.srStageSummary==="1920x1080 → 7680x4320 → 3840x2160",
                      "supersample 8K -> 4K with NR and VFG runs everything after SR at 4K")
                graphicenhancement.logUi("sr-stage-test","SR_STAGE_UI_PASS");console.log("SR_STAGE_UI_PASS");Qt.quit()
            }
        }catch(e){graphicenhancement.logUi("sr-stage-test","SR_STAGE_UI_FAIL "+e.message);console.log("SR_STAGE_UI_FAIL "+e.message);Qt.quit()}}
    }
}
