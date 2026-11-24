
    // ---- split compare pauses frame generation, and says so ----
    Timer { interval: 150; running: true; repeat: true; onTriggered: graphicenhancement.logUi("uitest-tick", "") }
    Timer {
        interval: 1000; running: true; repeat: true
        property int ticks: 0
        onTriggered: {
            ++ticks
            if (ticks === 2) { graphicenhancement.openUrl("@VIDEO@"); graphicenhancement.fgBackendName = "xess"; graphicenhancement.fgEnabled = true }
            if (ticks === 8) graphicenhancement.logUi("uitest", "UITEST_NOTE before status=" + graphicenhancement.runStatus)
            if (ticks === 9) { graphicenhancement.compareMode = 2; root.goPage("pro") }
            if (ticks === 10) graphicenhancement.logUi("uitest", "UITEST_SHOT compare")
            if (ticks === 12) graphicenhancement.logUi("uitest", "UITEST_NOTE compare status=" + graphicenhancement.runStatus)
            if (ticks === 13) graphicenhancement.compareMode = 0
            if (ticks === 16) {
                graphicenhancement.logUi("uitest", "UITEST_NOTE after status=" + graphicenhancement.runStatus)
                graphicenhancement.logUi("uitest", "UITEST_DONE"); running = false
            }
        }
    }
