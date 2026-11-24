// Disposable staging loader using the actual bridge, engine and export worker.
import QtQuick
Item {
    id: test
    property var appWindow: Window.window
    property string media: ""
    property string shortMedia: ""
    property string evidence: ""
    property string phase: "run"
    property int step: 0
    property int ticks: 0
    property int waited: 0
    property int current: 0
    property real beforePosition: 0
    property var cases: [{m:2,q:1},{m:3,q:1},{m:4,q:1},{m:5,q:1},{m:6,q:1},{m:7,q:1},{m:8,q:1},{m:8,q:0},{m:8,q:2}]
    function check(ok,why){if(!ok){console.error("VFG_UI_FAIL",phase,step,why);timer.stop();Qt.quit();throw new Error(why)}}
    function next(n){step=n;waited=0}
    function find(item,name){if(item.objectName===name)return item;for(const child of item.children||[]){const r=find(child,name);if(r)return r}return null}
    function findNodePage(item){if(typeof item.selectId==="function")return item;for(const child of item.children||[]){const r=findNodePage(child);if(r)return r}return null}
    function findProPage(item){if(typeof item.overlayContains==="function"&&typeof item.tab==="string")return item;for(const child of item.children||[]){const r=findProPage(child);if(r)return r}return null}
    function preset(name){return graphicenhancement.presets.findIndex(x=>x.name===name)}
    function startCase(){const c=cases[current];beforePosition=graphicenhancement.position;graphicenhancement.fgMultiplier=c.m;graphicenhancement.vfgQuality=c.q;next(2)}
    Connections {target: graphicenhancement;function onNotice(message,error){console.log("VFG_NOTICE",message,error)}}
    Timer {id: timer;interval: 200;running: true;repeat: true
        onTriggered: {try {
            if(++test.ticks>1150)test.check(false,"230-second deadline");++test.waited
            if(!test.media.length)return
            const rtss=test.find(test.appWindow.contentItem,"overlay-restart-confirm")
            if(rtss&&rtss.shown){rtss.close();rtss.rejected();console.log("VFG_UI_RTSS_DEFER")}
            if(test.step===0){
                if(test.waited<10)return
                test.check(graphicenhancement.fgBackendChoices.some(x=>x.id==="vfg"),"VFG backend menu")
                if(test.phase==="restore"){
                    test.check(graphicenhancement.nodeMode===0&&graphicenhancement.fgBackendName==="vfg"&&graphicenhancement.fgMultiplier===8&&graphicenhancement.vfgQuality===1,"list restart preserves 8X Medium")
                    test.check(test.preset("VFG List 8 Medium")>=0&&test.preset("VFG Node 8 High")>=0,"preset restart")
                    graphicenhancement.nodeMode=1;test.check(graphicenhancement.fgBackendName==="vfg"&&graphicenhancement.fgMultiplier===8&&graphicenhancement.vfgQuality===2,"node restart preserves independent 8X High")
                    test.check(graphicenhancement.applyPresetIndex(test.preset("VFG Node 8 High")),"node VFG preset applies")
                    graphicenhancement.nodeMode=0;test.check(graphicenhancement.vfgQuality===1,"switch back restores list Medium")
                    console.log("VFG_UI_RESTORE_PASS");timer.stop();Qt.quit();return
                }
                graphicenhancement.muted=true;graphicenhancement.nrEnabled=false;graphicenhancement.srEnabled=false
                test.appWindow.page="pro"
                const professional=test.findProPage(test.appWindow.contentItem)
                if(professional)professional.tab="fg"
                if(test.phase==="missing"){
                    graphicenhancement.openPath(test.media);test.next(20);return
                }
                test.check(graphicenhancement.addEffect("vfg-fg")>=0,"add VFG list stage")
                const factor=test.find(test.appWindow.contentItem,"list-vfg-multiplier")
                const quality=test.find(test.appWindow.contentItem,"list-vfg-quality")
                test.check(factor&&quality,"list controls created")
                test.check(factor.options.map(x=>x.id).join(",")==="2,3,4,5,6,7,8","all seven multiplier controls")
                for(let q=0;q<3;++q){quality.picked(String(q));test.check(graphicenhancement.vfgQuality===q,"quality control commits "+q)}
                for(let m=2;m<=8;++m){factor.picked(String(m));test.check(graphicenhancement.fgMultiplier===m,"multiplier control commits "+m)}
                graphicenhancement.vfgQuality=1;graphicenhancement.fgMultiplier=2;graphicenhancement.openPath(test.media);test.next(1)
            }else if(test.step===1){
                if(!graphicenhancement.running||!graphicenhancement.hasSource||graphicenhancement.applying)return
                test.startCase()
            }else if(test.step===2){
                if(test.waited<12||graphicenhancement.applying)return
                const c=test.cases[test.current]
                test.check(graphicenhancement.running&&graphicenhancement.fgActive&&graphicenhancement.fgBackendName==="vfg","VFG inactive "+graphicenhancement.statusText)
                test.check(graphicenhancement.fgMultiplier===c.m&&graphicenhancement.vfgQuality===c.q,"hot settings rollback")
                test.check(graphicenhancement.position>test.beforePosition+0.3,"playback clock stopped")
                test.check(graphicenhancement.runStatusDetail.indexOf("NVIDIA VFG")>=0,"actual running backend label")
                console.log("VFG_UI_CASE",c.m,c.q,"submitFps",graphicenhancement.submitFps,"detail",graphicenhancement.runStatusDetail)
                if(++test.current<test.cases.length){test.startCase();return}
                graphicenhancement.vfgQuality=1;test.next(3)
            }else if(test.step===3){
                if(test.waited<8||graphicenhancement.applying)return
                test.check(graphicenhancement.savePresetAs("VFG List 8 Medium",15,false),"save list VFG preset")
                test.next(12)
                test.appWindow.contentItem.grabToImage(r=>{test.check(r.saveToFile(test.evidence+"/vfg-list.png"),"list screenshot");graphicenhancement.fgBackendName="dlss";graphicenhancement.fgMultiplier=6;test.next(15)})
            }else if(test.step===15){
                if(test.waited<12||graphicenhancement.applying)return
                if(graphicenhancement.runStatusDetail.indexOf("DLSS")<0||graphicenhancement.runStatusDetail.indexOf("6X")<0){if(test.waited<100)return;test.check(false,"DLSS 6X actual running label")}
                test.check(graphicenhancement.fgActive&&graphicenhancement.fgBackendName==="dlss"&&graphicenhancement.fgMultiplier===6,"legacy DLSS 6X works after VFG 8X")
                console.log("VFG_UI_DLSS6_PASS",graphicenhancement.runStatusDetail)
                graphicenhancement.fgBackendName="vfg";graphicenhancement.fgMultiplier=8;test.next(16)
            }else if(test.step===16){
                if(test.waited<12||graphicenhancement.applying)return
                if(graphicenhancement.runStatusDetail.indexOf("NVIDIA VFG")<0||graphicenhancement.runStatusDetail.indexOf("8X")<0){if(test.waited<100)return;test.check(false,"VFG 8X actual running label after DLSS")}
                test.check(graphicenhancement.fgActive&&graphicenhancement.fgBackendName==="vfg"&&graphicenhancement.fgMultiplier===8,"VFG 8X restores after DLSS 6X")
                graphicenhancement.togglePlayPause();test.next(4)
            }else if(test.step===4){
                if(!graphicenhancement.paused)return
                graphicenhancement.seekTo(2);test.appWindow.width=1160;test.appWindow.height=740;test.next(5)
            }else if(test.step===5){
                if(test.waited<10)return
                test.check(graphicenhancement.paused&&graphicenhancement.position>=1.9,"paused seek")
                graphicenhancement.togglePlayPause();test.next(6)
            }else if(test.step===6){
                if(test.waited<10||graphicenhancement.applying)return
                test.check(graphicenhancement.running&&!graphicenhancement.paused&&graphicenhancement.position>2.5,"resume after seek/resize")
                graphicenhancement.nodeMode=1;test.appWindow.page="node";test.check(graphicenhancement.addEffect("vfg-fg")>=0,"add VFG node")
                graphicenhancement.fgMultiplier=8;graphicenhancement.vfgQuality=2;test.next(7)
            }else if(test.step===7){
                if(test.waited<10||graphicenhancement.applying)return
                test.check(graphicenhancement.chainValid&&graphicenhancement.fgActive&&graphicenhancement.vfgQuality===2,"node VFG running")
                test.check(graphicenhancement.effectCatalog.some(x=>x.id==="vfg-fg"),"node add menu includes VFG")
                const page=test.findNodePage(test.appWindow.contentItem),fg=graphicenhancement.chain.find(x=>x.type==="frame-generation")
                if(page&&fg)page.selectId(fg.id)
                test.check(graphicenhancement.savePresetAs("VFG Node 8 High",15,true),"save node VFG preset")
                test.next(12)
                test.appWindow.contentItem.grabToImage(r=>{test.check(r.saveToFile(test.evidence+"/vfg-node.png"),"node screenshot");graphicenhancement.stopPlayback();test.next(8)})
            }else if(test.step===8){
                if(test.waited<8||graphicenhancement.hasSource)return
                graphicenhancement.nodeMode=0;test.appWindow.page="pro"
                test.check(graphicenhancement.fgMultiplier===8&&graphicenhancement.vfgQuality===1,"list state survives node High")
                graphicenhancement.vfgQuality=2
                graphicenhancement.addExportFiles([test.shortMedia]);graphicenhancement.exportCompletionSound=false;graphicenhancement.exportHevc=true;graphicenhancement.exportSrTargetIndex=-1;graphicenhancement.exportRateControl=1;graphicenhancement.exportBitrateMbps=18
                test.next(9)
            }else if(test.step===9){
                if(graphicenhancement.exportReadyCount!==1)return
                graphicenhancement.startExport();test.check(graphicenhancement.exportRunning,"VFG worker started")
                graphicenhancement.vfgQuality=0;graphicenhancement.fgMultiplier=2;test.next(10)
            }else if(test.step===10){
                if(graphicenhancement.exportRunning)return
                test.check(graphicenhancement.exportItems.filter(x=>x.state==="done").length===1,"native VFG worker export")
                graphicenhancement.fgMultiplier=8;graphicenhancement.vfgQuality=1;test.next(11)
            }else if(test.step===11){
                if(test.waited<10)return
                console.log("VFG_UI_PASS");timer.stop();Qt.quit()
            }else if(test.step===20){
                if(test.waited<20||graphicenhancement.applying||!graphicenhancement.running)return
                console.log("VFG_UI_MISSING_STATE",JSON.stringify({active:graphicenhancement.fgActive,enabled:graphicenhancement.fgEnabled,position:graphicenhancement.position,backend:graphicenhancement.fgBackendName,multiplier:graphicenhancement.fgMultiplier,quality:graphicenhancement.vfgQuality,warning:graphicenhancement.backendWarning}))
                test.check(!graphicenhancement.fgActive&&!graphicenhancement.fgEnabled&&graphicenhancement.position>0.4,"missing runtime keeps base playback")
                test.check(graphicenhancement.backendWarning.indexOf("VFG")>=0,"missing runtime reports exact failed backend")
                console.log("VFG_UI_MISSING_PASS",graphicenhancement.backendWarning);timer.stop();Qt.quit()
            }
        }catch(e){console.error("VFG_UI_FAIL",e.message);timer.stop();Qt.quit()}}
    }
}
