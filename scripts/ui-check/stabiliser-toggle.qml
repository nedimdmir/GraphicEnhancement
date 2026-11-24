    // ---- output stabiliser on then off: the picture must keep moving (field report 2026-10-02) ----
    Timer { interval: 150; running: true; repeat: true; onTriggered: graphicenhancement.logUi("uitest-tick", "") }
    Timer {
        interval: 1000; running: true; repeat: true
        property int ticks: 0
        property string failure: ""
        property real lastPos: -1
        function note(what) {
            graphicenhancement.logUi("uitest", "UITEST_NOTE " + what + " pos=" + graphicenhancement.position.toFixed(2) + " fps=" + graphicenhancement.displayFps.toFixed(1)
                        + " hold=" + graphicenhancement.nrHoldStrength)
        }
        function moving(what) {
            note(what)
            if (lastPos >= 0 && graphicenhancement.position - lastPos < 0.5 && !failure) failure = what + ": position stuck at " + graphicenhancement.position.toFixed(2)
            lastPos = graphicenhancement.position
        }
        onTriggered: {
            ++ticks
            if (ticks === 2) graphicenhancement.openUrl("@VIDEO@")
            if (ticks === 4) { root.goPage("pro"); if (@NR@) { if (graphicenhancement.nrLayers.length === 0) graphicenhancement.addEffect("nr"); graphicenhancement.setAllNrEnabled(true) } @EXTRA@ }
            if (ticks === 6) moving("before")
            if (ticks === 7) { @ON@; note("on") }
            if (ticks === 9) { note("stabiliser on"); graphicenhancement.logUi("uitest", "UITEST_SHOT on-9") }
            if (ticks === 10) { note("stabiliser on 2"); graphicenhancement.logUi("uitest", "UITEST_SHOT on-10") }
            if (ticks === 11) { @OFF@; note("off") }
            if (ticks >= 13 && ticks <= 22) { moving("stabiliser off " + ticks); graphicenhancement.logUi("uitest", "UITEST_SHOT off-" + ticks) }
            if (ticks === 23) { graphicenhancement.logUi("uitest", failure ? "UITEST_FAIL " + failure : "UITEST_DONE"); running = false }
        }
    }
