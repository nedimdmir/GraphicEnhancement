    Timer { interval: 150; running: true; repeat: true; onTriggered: graphicenhancement.logUi("uitest-tick", "") }
    Timer {
        interval: 250; running: true; repeat: true
        property int phase: 0
        property int ticks: 0
        property int total: 0
        property int choice: 0
        property real beforePosition: 0
        property var choices: [0, 2, 3, 0]
        property bool restore: Qt.application.arguments.indexOf("--nr-restore") >= 0
        function check(ok, message) { if (!ok) throw new Error(message) }
        function next(p) { phase=p; ticks=0 }
        function preset(name) { for (var i=0;i<graphicenhancement.presets.length;++i) if(graphicenhancement.presets[i].name===name)return i;return -1 }
        function choose(id) {
            beforePosition=graphicenhancement.position
            check(graphicenhancement.setNrLayerParameter(graphicenhancement.nrLayers[0].index,"runtime",id),"select NR "+id)
            check(graphicenhancement.nrLayers.every(n=>n.runtime===id),"all layers select NR "+id)
        }
        function findItem(item, name) {
            if (item.objectName===name) return item
            const children=item.children || []
            for(var i=0;i<children.length;++i){const found=findItem(children[i],name);if(found)return found}
            return null
        }
        onTriggered: { try {
            ++ticks; ++total
            if(total>980||ticks>180)throw new Error("bounded wait phase="+phase)
            if(phase===0){
                if(ticks<8)return
                if(restore){
                    check(graphicenhancement.nrLayers.every(n=>n.runtime===3),"list original restores after restart")
                    graphicenhancement.nodeMode=1
                    check(graphicenhancement.nrLayers.every(n=>n.runtime===3),"node original restores after restart")
                    check(graphicenhancement.applyPresetIndex(preset("2.0.2 original node")),"original node preset loads")
                    check(graphicenhancement.nrLayers.every(n=>n.runtime===3),"original node preset retains variant")
                    graphicenhancement.nodeMode=0
                    check(graphicenhancement.applyPresetIndex(preset("2.0.2 original list")),"original list preset loads")
                    check(graphicenhancement.nrLayers.every(n=>n.runtime===3),"original list preset retains variant")
                    graphicenhancement.logUi("uitest","UITEST_DONE original NR persistence");running=false;root.close();return
                }
                check(graphicenhancement.nrLayers[0].runtime===0,"RTX 50 fresh Lecram default unchanged")
                root.goPage("pro");graphicenhancement.muted=true;graphicenhancement.srEnabled=false;graphicenhancement.fgEnabled=false;graphicenhancement.nrEnabled=true
                graphicenhancement.openUrl("@VIDEO@");next(1);return
            }
            if(phase===1){
                if(ticks<16||!graphicenhancement.running||graphicenhancement.applying)return
                check(graphicenhancement.nrActive,"initial NR evaluates")
                const selector=findItem(root.contentItem,"nr-runtime")
                check(selector&&selector.options.length===3,"three options exposed in NR editor")
                check(selector.options.map(x=>x.id).join(",")==="0,2,3","persistent NR IDs exposed")
                check(!graphicenhancement.setNrLayerParameter(graphicenhancement.nrLayers[0].index,"runtime",1),"retired ID rejected by UI")
                check(!graphicenhancement.setNrLayerParameter(graphicenhancement.nrLayers[0].index,"runtime",4),"invalid ID rejected")
                check(graphicenhancement.duplicateNrLayer(graphicenhancement.nrLayers[0].index)>=0,"add second NR layer")
                choice=0;choose(choices[choice]);next(2);return
            }
            if(phase===2||phase===4){
                if(ticks<16||graphicenhancement.applying)return
                check(graphicenhancement.running&&graphicenhancement.nrActive&&graphicenhancement.position>beforePosition+0.5,"NR playback advances "+choices[choice])
                check(graphicenhancement.nrLayers.every(n=>n.runtime===choices[choice]),"active variant retained")
                graphicenhancement.logUi("uitest","NR_VARIANT_PASS mode="+graphicenhancement.nodeMode+" id="+choices[choice]+" position="+graphicenhancement.position)
                if(++choice<choices.length){choose(choices[choice]);ticks=0;return}
                choose(3)
                if(phase===2){
                    check(graphicenhancement.savePresetAs("2.0.2 original list",15,false),"save original list preset")
                    graphicenhancement.nodeMode=1;root.goPage("node");next(3);return
                }
                check(graphicenhancement.savePresetAs("2.0.2 original node",15,true),"save original node preset")
                graphicenhancement.nodeMode=0;root.goPage("pro");next(5);return
            }
            if(phase===3){
                if(ticks<12||graphicenhancement.applying)return
                if(!graphicenhancement.nrLayers.length)check(graphicenhancement.addEffect("nr")>=0,"add node NR")
                choice=0;choose(choices[choice]);next(4);return
            }
            if(phase===5){
                if(ticks<16||graphicenhancement.applying)return
                check(graphicenhancement.nrActive&&graphicenhancement.nrLayers.every(n=>n.runtime===3),"list original resumes after node mode")
                graphicenhancement.logUi("uitest","UITEST_SHOT original-nr")
                graphicenhancement.logUi("uitest","UITEST_DONE all NR variants");running=false;root.close()
            }
        } catch(e) {graphicenhancement.logUi("uitest","UITEST_FAIL "+e.message);running=false;root.close()} }
    }
