
    // ---- VRAM-leak run: capture with NR, then fullscreen for a while (field log: +3 GB/min) ----
    Timer { interval: 150; running: true; repeat: true; onTriggered: graphicenhancement.logUi("uitest-tick", "") }
    Timer {
        interval: 1000; running: true; repeat: true
        property int ticks: 0
        onTriggered: {
            ++ticks
            if (ticks === 2) { graphicenhancement.openUrl("@VIDEO@"); graphicenhancement.nrEnabled = true }
            if (ticks === 40) { graphicenhancement.logUi("uitest", "UITEST_NOTE windowed phase done"); root.toggleFullscreen() }
            if (ticks === @END@) { root.toggleFullscreen(); graphicenhancement.logUi("uitest", "UITEST_DONE"); running = false }
        }
    }
