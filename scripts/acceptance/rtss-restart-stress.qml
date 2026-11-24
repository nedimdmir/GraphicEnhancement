import QtQuick
Item {
    id: test
    property var appWindow: Window.window
    property string media: ""
    property string evidence: ""
    property int index: -1
    property int ticks: 0
    property int waited: 0
    property int settling: 0
    property double before: 0
    property bool captured: false
    property int transportPhase: 0
    property int transportTicks: 0
    property var cases: [
        {name:"plain",nr:false,sr:false,fg:"",m:2,q:1},
        {name:"nr-parameters",nr:true,sr:false,fg:"",m:2,q:1},
        {name:"nr-rtx-highest-4k",nr:true,sr:true,fg:"",m:2,q:1},
        {name:"nr-rtx-dlss2",nr:true,sr:true,fg:"dlss",m:2,q:1},
        {name:"dlss6",nr:false,sr:false,fg:"dlss",m:6,q:1},
        {name:"xess4",nr:false,sr:false,fg:"xess",m:4,q:1},
        {name:"fsr3-2",nr:false,sr:false,fg:"fsr3",m:2,q:1},
        {name:"vfg2-low",nr:false,sr:false,fg:"vfg",m:2,q:0},
        {name:"vfg4-medium",nr:false,sr:false,fg:"vfg",m:4,q:1},
        {name:"vfg8-high",nr:false,sr:false,fg:"vfg",m:8,q:2},
        {name:"nr-resize-pause-seek",nr:true,sr:false,fg:"",m:2,q:1}
    ]
    function require(ok, message) {
        if (ok) return
        timer.stop()
        console.error("RTSS_STRESS_FAIL", index, message, graphicenhancement.statusText, graphicenhancement.backendWarning)
        Qt.quit()
        throw new Error(message)
    }
    function next() {
        ++index; waited=0; settling=0; captured=false; transportPhase=0; transportTicks=0
        if (index === cases.length) {
            console.log("RTSS_STRESS_PASS", cases.length, "version="+graphicenhancement.version)
            Qt.quit(); return
        }
        const c=cases[index]
        graphicenhancement.fgEnabled=false
        graphicenhancement.nrEnabled=c.nr; graphicenhancement.srEnabled=c.sr
        graphicenhancement.nrIntensity=0.45; graphicenhancement.nrTone=0.2; graphicenhancement.nrStructure=0.3; graphicenhancement.nrSkin=0.25
        graphicenhancement.videoSrQuality=4; graphicenhancement.srTargetIndex=2
        if (c.fg.length) {
            graphicenhancement.fgBackendName=c.fg; graphicenhancement.fgMultiplier=c.m; graphicenhancement.vfgQuality=c.q
            graphicenhancement.fgEnabled=true
        }
        before=graphicenhancement.position
        console.log("RTSS_STRESS_REQUEST", c.name)
    }
    Connections {
        target: graphicenhancement
        function onOverlayRestartSuggested() { test.require(false,"live server was detected before launch; another restart is invalid") }
        function onNotice(message,error) { console.log("RTSS_STRESS_NOTICE",message,error) }
    }
    Timer {
        id: timer
        interval: 200; repeat: true; running: true
        onTriggered: {
            if (++test.ticks > 1150) { test.require(false,"230-second deadline"); return }
            if (!test.media.length) return
            test.require(vySoftwareUi && graphicenhancement.overlayCompatActive && graphicenhancement.rivaTunerRunning(),"real RTSS compatibility missing")
            test.require(test.appWindow.color.a === 1,"transparent software background")
            test.require(!graphicenhancement.failed,"source/GPU failure")
            if (test.index === -1) {
                if (test.ticks === 5) {
                    test.appWindow.page="pro"; test.appWindow.requestActivate()
                    graphicenhancement.muted=true; graphicenhancement.nrEnabled=false; graphicenhancement.srEnabled=false; graphicenhancement.fgEnabled=false
                    graphicenhancement.openPath(test.media)
                }
                if (graphicenhancement.running && graphicenhancement.hasSource && !graphicenhancement.applying) test.next()
                return
            }
            const c=test.cases[test.index]
            ++test.waited
            if (test.waited > 140) { test.require(false,"backend transition deadline"); return }
            if (graphicenhancement.applying || test.waited < 22 || !graphicenhancement.running) return
            if (graphicenhancement.nrActive !== c.nr || graphicenhancement.srActive !== c.sr || graphicenhancement.fgActive !== !!c.fg.length) return
            if (c.fg.length && (graphicenhancement.fgBackendName !== c.fg || graphicenhancement.fgMultiplier !== c.m)) return
            if (c.name === "nr-resize-pause-seek") {
                // Wait for real state acknowledgements, including a cold NR
                // initialization; transport/window changes are asynchronous.
                if (test.transportPhase === 0) {
                    test.appWindow.width=1100; test.appWindow.height=680
                    graphicenhancement.togglePlayPause(); test.transportPhase=1; return
                }
                if (test.transportPhase === 1) {
                    if (!graphicenhancement.paused) return
                    graphicenhancement.seekTo(2); test.transportPhase=2; return
                }
                if (test.transportPhase === 2) {
                    test.require(graphicenhancement.paused,"pause was lost while seeking")
                    if (Math.abs(graphicenhancement.position-2)>=0.6) return
                    console.log("RTSS_STRESS_SEEK",graphicenhancement.position)
                    graphicenhancement.togglePlayPause(); test.before=2
                    test.appWindow.page="min"; test.appWindow.toggleFullscreen()
                    test.transportPhase=3; return
                }
                if (test.transportPhase === 3) {
                    if (!test.appWindow.fullscreen) return
                    if (++test.transportTicks<10) return
                    console.log("RTSS_STRESS_FULLSCREEN",test.appWindow.fullscreen)
                    test.appWindow.toggleFullscreen(); test.appWindow.page="pro"
                    test.transportPhase=4; return
                }
                if (test.transportPhase === 4) {
                    if (test.appWindow.fullscreen) return
                    console.log("RTSS_STRESS_WINDOW_RESTORED",!test.appWindow.fullscreen)
                    test.transportPhase=5
                }
            }
            if (graphicenhancement.paused) return
            if (graphicenhancement.position < test.before+0.5) return
            if (!test.captured) {
                test.captured=true
                const state={name:c.name,position:graphicenhancement.position,detail:graphicenhancement.runStatusDetail,
                    nr:graphicenhancement.nrActive,sr:graphicenhancement.srActive,fg:graphicenhancement.fgActive,backend:graphicenhancement.fgBackendName,
                    multiplier:graphicenhancement.fgMultiplier,quality:graphicenhancement.vfgQuality,submitFps:graphicenhancement.submitFps,
                    intensity:graphicenhancement.nrIntensity,tone:graphicenhancement.nrTone,structure:graphicenhancement.nrStructure,skin:graphicenhancement.nrSkin}
                console.log("RTSS_STRESS_CASE",JSON.stringify(state))
                test.appWindow.contentItem.grabToImage(result=>{
                    test.require(result.saveToFile(test.evidence+"/"+c.name+"-ui.png"),"UI screenshot failed")
                })
                return
            }
            if (++test.settling>8) test.next()
        }
    }
}
