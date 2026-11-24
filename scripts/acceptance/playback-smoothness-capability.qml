import QtQuick
Item {
    id: test
    property string media: ""
    property string mode: "capability"
    property bool available: graphicenhancement.effectCapabilities.vfg.available
    property int phase: 0
    property int ticks: 0
    property double started: 0
    function require(ok,why) {
        if(ok)return
        console.error("PLAYBACK_CAPABILITY_FAIL",why)
        timer.stop();Qt.quit();throw new Error(why)
    }
    Timer {
        id: timer;interval:200;running:true;repeat:true
        onTriggered: {
            ++test.ticks;test.require(test.ticks<150,"30-second deadline")
            if(test.phase===0){
                graphicenhancement.nrEnabled=false;graphicenhancement.srEnabled=false;graphicenhancement.fgEnabled=false
                test.require(test.available,"VFG must initially be present on the test GPU")
                console.log("PLAYBACK_CAPABILITY_READY");test.started=Date.now();test.phase=1;return
            }
            if(test.phase===1){
                if(Date.now()-test.started<400)return
                graphicenhancement.lowLatency=!graphicenhancement.lowLatency
                console.log("PLAYBACK_CAPABILITY_ACTION_READ",graphicenhancement.effectCapabilities.vfg.available,test.available)
                test.require(!graphicenhancement.effectCapabilities.vfg.available,"missing component not found by action validation")
                test.started=Date.now();test.phase=2;return
            }
            if(test.phase===2){
                if(test.available){test.require(Date.now()-test.started<6000,"QML binding stayed enabled after missing component");return}
                const choice=graphicenhancement.fgBackendChoices.filter(c=>c.id==="vfg")[0]
                test.require(choice.disabled,"missing VFG menu not gray")
                console.log("PLAYBACK_CAPABILITY_MISSING_PASS");test.started=Date.now();test.phase=3;return
            }
            if(test.phase===3){
                if(!test.available){test.require(Date.now()-test.started<6000,"QML binding never saw restored component");return}
                const choice=graphicenhancement.fgBackendChoices.filter(c=>c.id==="vfg")[0]
                test.require(!choice.disabled,"restored VFG menu stays gray")
                console.log("PLAYBACK_CAPABILITY_PASS");Qt.quit()
            }
        }
    }
}
