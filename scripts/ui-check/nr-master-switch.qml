    // ---- list-mode NR master switch: all layers off at once, back to what was on ----
    Timer { interval: 150; running: true; repeat: true; onTriggered: graphicenhancement.logUi("uitest-tick", "") }
    Timer {
        interval: 1000; running: true; repeat: true
        property int ticks: 0
        property string failure: ""
        function states() { return graphicenhancement.nrLayers.map(l => l.enabled ? 1 : 0).join("") }
        function expect(what, want) {
            const got = states()
            graphicenhancement.logUi("uitest", "UITEST_NOTE " + what + " layers=" + got + " any=" + graphicenhancement.nrAnyEnabled)
            if (got !== want && !failure) failure = what + " got " + got + " want " + want
        }
        onTriggered: {
            ++ticks
            if (ticks === 2) graphicenhancement.openUrl("@VIDEO@")
            if (ticks === 5) {
                root.goPage("pro")
                while (graphicenhancement.nrLayers.length < 3) graphicenhancement.addEffect("nr")
                const l = graphicenhancement.nrLayers
                graphicenhancement.setEffectEnabled(l[0].index, true); graphicenhancement.setEffectEnabled(l[1].index, false); graphicenhancement.setEffectEnabled(l[2].index, true)
                expect("start", "101")
            }
            if (ticks === 7) graphicenhancement.logUi("uitest", "UITEST_SHOT on")
            if (ticks === 8) { graphicenhancement.setAllNrEnabled(false); expect("master off", "000") }
            if (ticks === 10) graphicenhancement.logUi("uitest", "UITEST_SHOT off")
            if (ticks === 11) { graphicenhancement.setAllNrEnabled(true); expect("master on restores", "101") }
            if (ticks === 12) {
                graphicenhancement.setAllNrEnabled(false); graphicenhancement.setEffectEnabled(graphicenhancement.nrLayers[1].index, true)
                // A layer switched on by hand while the master was off: master shows on.
                expect("one by hand", "010")
                graphicenhancement.setAllNrEnabled(false); graphicenhancement.setAllNrEnabled(true); expect("restore after hand edit", "010")
            }
            if (ticks === 13) {
                graphicenhancement.setAllNrEnabled(false); graphicenhancement.addEffect("nr")
                graphicenhancement.setAllNrEnabled(true); expect("layer added while off: all on", "1111")
            }
            if (ticks === 14) { graphicenhancement.logUi("uitest", failure ? "UITEST_FAIL " + failure : "UITEST_DONE"); running = false }
        }
    }
