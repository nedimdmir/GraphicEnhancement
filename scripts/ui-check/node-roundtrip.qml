
    // ---- node page after leaving and re-entering the scene (VPage.home) --------------------
    Timer { interval: 150; running: true; repeat: true; onTriggered: graphicenhancement.logUi("uitest-tick", "") }
    Timer {
        interval: 2500; running: true; repeat: true
        property int phase: 0
        onTriggered: {
            phase += 1
            if (phase === 1) root.goPage("node")
            if (phase === 2) graphicenhancement.logUi("uitest", "UITEST_SHOT node-first")
            if (phase === 3) root.goPage("min")
            if (phase === 4) root.goPage("node")
            if (phase === 5) graphicenhancement.logUi("uitest", "UITEST_SHOT node-again")
            if (phase === 6) root.goPage("pro")
            if (phase === 7) graphicenhancement.logUi("uitest", "UITEST_SHOT pro-again")
            if (phase === 8) { graphicenhancement.logUi("uitest", "UITEST_DONE"); running = false }
        }
    }
