    // Inject only into a disposable staged Main.qml, never the product source.
    Timer {
        interval: 250; running: true; repeat: true
        property int step: 0
        property int ticks: 0
        property int total: 0
        property int current: 0
        property double beforePosition: 0
        property bool restore: Qt.application.arguments.indexOf("--fg-restore") >= 0
        property var cases: [
            {backend:"fsr3", multiplier:2}, {backend:"xess", multiplier:4},
            {backend:"xess", multiplier:2}, {backend:"xess", multiplier:3},
            {backend:"xess", multiplier:4}, {backend:"dlss", multiplier:4},
            {backend:"fsr3", multiplier:2}
        ]
        function check(value, label) { if (!value) throw new Error(label) }
        function next(value) { step = value; ticks = 0 }
        function preset(name) {
            for (var i=0;i<graphicenhancement.presets.length;++i)
                if (graphicenhancement.presets[i].name === name) return i
            return -1
        }
        function startCase() {
            var c=cases[current]
            beforePosition=graphicenhancement.position
            graphicenhancement.fgBackendName=c.backend
            graphicenhancement.fgEnabled=true
            graphicenhancement.fgMultiplier=c.multiplier
            next(2)
        }
        onTriggered: { try {
            ++ticks; ++total
            if (total>680) throw new Error("bounded step="+step+" ticks="+ticks)
            if (step===0) {
                if (ticks<8) return
                check(graphicenhancement.fgBackendChoices.length===4, "four independent backend choices")
                if (restore) {
                    check(graphicenhancement.nodeMode===0 && graphicenhancement.fgBackendName==="fsr3", "list session restored")
                    check(preset("FG List FSR31")>=0 && preset("FG Node FSR31")>=0 && preset("FG Node FSR4")>=0, "preset library restored")
                    graphicenhancement.nodeMode=1
                    check(graphicenhancement.applyPresetIndex(preset("FG Node FSR4")), "FSR4 node preset applies")
                    check(graphicenhancement.fgBackendName==="fsr4" && graphicenhancement.fgMaxMultiplier===2, "FSR4 restored without DLSS label")
                    check(graphicenhancement.applyPresetIndex(preset("FG Node FSR31")), "FSR3 node preset applies")
                    check(graphicenhancement.fgBackendName==="fsr3", "independent FSR3 restored")
                    graphicenhancement.nodeMode=0
                    check(graphicenhancement.fgBackendName==="fsr3", "list configuration survives node choices")
                    console.log("FG_UI_RESTORE_PASS"); Qt.quit(); return
                }
                graphicenhancement.muted=true; graphicenhancement.nrEnabled=false; graphicenhancement.srEnabled=false
                root.page="pro"
                graphicenhancement.openPath("E:/项目/GraphicEnhancement/tests/nr-fg-opt-20260929/media/gta6-4k30-silent-180s.mp4")
                next(1); return
            }
            if (step===1) {
                if (!graphicenhancement.running || !graphicenhancement.hasSource || graphicenhancement.applying) return
                startCase(); return
            }
            if (step===2) {
                if (ticks<20 || graphicenhancement.applying) return
                var c=cases[current]
                check(graphicenhancement.running && graphicenhancement.fgActive, "FG inactive "+c.backend+" "+graphicenhancement.statusText)
                check(graphicenhancement.fgBackendName===c.backend && graphicenhancement.fgMultiplier===c.multiplier, "backend/multiplier not applied")
                check(graphicenhancement.position>beforePosition+0.5, "source position stopped "+c.backend)
                if (c.backend==="fsr3") {
                    check(graphicenhancement.fgProviderText.indexOf("3.1.")>=0, "actual FSR3 provider absent")
                    check(graphicenhancement.runStatusDetail.indexOf("FSR 3.1")>=0 && graphicenhancement.runStatusDetail.indexOf("DLSS")<0, "FSR status mislabeled")
                    check(graphicenhancement.fgMultiplierChoices.length===1 && graphicenhancement.fgMaxMultiplier===2, "FSR2X ceiling")
                    var old=graphicenhancement.fgMultiplier
                    graphicenhancement.fgMultiplier=4
                    check(graphicenhancement.fgMultiplier===old, "illegal FSR4X mutated settings")
                }
                if (c.backend==="xess") check(graphicenhancement.fgMaxMultiplier===4 && graphicenhancement.fgMultiplierChoices.length===3, "XeSS 4X option disappeared")
                console.log("FG_UI_CASE backend="+c.backend+" multiplier="+c.multiplier+" fps="+graphicenhancement.submitFps.toFixed(1)+" position="+graphicenhancement.position.toFixed(2)+" provider="+graphicenhancement.fgProviderText)
                ++current
                if (current<cases.length) { startCase(); return }
                check(graphicenhancement.savePresetAs("FG List FSR31",15,false), "save list FSR3 preset")
                beforePosition=graphicenhancement.position; graphicenhancement.fgBackendName="fsr4"
                next(3); return
            }
            if (step===3) {
                if (ticks<20 || graphicenhancement.applying) return
                check(graphicenhancement.running && graphicenhancement.fgActive && graphicenhancement.fgBackendName==="fsr3", "unsupported FSR4 did not restore FSR3 backend="+graphicenhancement.fgBackendName+" active="+graphicenhancement.fgActive+" running="+graphicenhancement.running)
                check(graphicenhancement.backendWarning.indexOf("FSR 4")>=0, "FSR4 failure not explained")
                check(graphicenhancement.position>beforePosition+0.5, "FSR4 rejection stopped playback")
                console.log("FG_UI_FSR4_ROLLBACK warning="+graphicenhancement.backendWarning)
                graphicenhancement.togglePlayPause(); next(4); return
            }
            if (step===4) {
                if (!graphicenhancement.paused) return
                graphicenhancement.seekTo(40); root.width=1160; root.height=740
                next(5); return
            }
            if (step===5) {
                if (ticks<12) return
                check(graphicenhancement.paused && graphicenhancement.position>=39, "paused seek not complete")
                graphicenhancement.togglePlayPause(); next(6); return
            }
            if (step===6) {
                if (ticks<16 || graphicenhancement.applying) return
                check(graphicenhancement.running && !graphicenhancement.paused && graphicenhancement.fgActive && graphicenhancement.position>40.5, "pause/seek/resize/resume failed")
                graphicenhancement.nodeMode=1; root.page="node"
                next(7); return
            }
            if (step===7) {
                if (ticks<12 || graphicenhancement.applying) return
                check(graphicenhancement.effectCatalog.some(function(o){return o.id==="fsr3-fg"}) &&
                      graphicenhancement.effectCatalog.some(function(o){return o.id==="fsr4-fg"}), "FSR node add menu absent")
                check(graphicenhancement.addEffect("fsr3-fg")>=0, "add FSR3 node failed")
                next(8); return
            }
            if (step===8) {
                if (ticks<20 || graphicenhancement.applying) return
                check(graphicenhancement.fgActive && graphicenhancement.fgBackendName==="fsr3" && graphicenhancement.chainValid, "node FSR3 not active")
                check(graphicenhancement.chain.some(function(o){return o.type==="frame-generation" && o.label.indexOf("FSR 3.1")>=0}), "node mislabeled")
                check(graphicenhancement.savePresetAs("FG Node FSR31",15,true), "save node FSR3 preset")
                graphicenhancement.stopPlayback(); next(9); return
            }
            if (step===9) {
                if (ticks<16 || graphicenhancement.hasSource) return
                graphicenhancement.fgBackendName="fsr4"
                check(graphicenhancement.fgBackendName==="fsr4", "idle FSR4 selection failed")
                check(graphicenhancement.savePresetAs("FG Node FSR4",15,true), "save FSR4 node preset failed")
                check(graphicenhancement.applyPresetIndex(preset("FG Node FSR31")), "restore FSR3 node preset")
                graphicenhancement.nodeMode=0; root.page="pro"
                check(graphicenhancement.fgBackendName==="fsr3", "list state was overwritten by node FSR4")
                next(10); return
            }
            if (step===10) {
                if (ticks<8) return
                console.log("FG_UI_PASS"); Qt.quit()
            }
        } catch(e) { console.warn("FG_UI_FAIL "+e.message); Qt.quit() } }
    }
