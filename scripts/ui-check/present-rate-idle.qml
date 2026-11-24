
    // ---- UI present rate: idle 极简 (12 s), then a paused video (12 s) ----------------------
    Timer { interval: 150; running: true; repeat: true; onTriggered: graphicenhancement.logUi("uitest-tick", "") }
    Timer {
        interval: 250; running: true; repeat: true
        property int ticks: 0
        onTriggered: {
            ++ticks
            if (ticks === 2) graphicenhancement.logUi("uitest", "UITEST_NOTE phase idle")
            if (ticks === 50) graphicenhancement.openUrl("@VIDEO@")
            if (ticks === 58) { graphicenhancement.togglePlayPause(); graphicenhancement.logUi("uitest", "UITEST_NOTE phase paused") }
            if (ticks === 110) { graphicenhancement.logUi("uitest", "UITEST_DONE"); running = false }
        }
    }
