
    // ---- capture card: pause stops processing, play resumes ----
    Timer { interval: 150; running: true; repeat: true; onTriggered: graphicenhancement.logUi("uitest-tick", "") }
    Timer {
        interval: 1000; running: true; repeat: true
        property int ticks: 0
        onTriggered: {
            ++ticks
            if (ticks === 2) dialogs.open("capture")
            if (ticks === 4) { graphicenhancement.nrEnabled = true; graphicenhancement.startCaptureSession(); dialogs.close() }
            if (ticks === 10) { graphicenhancement.logUi("uitest", "UITEST_NOTE pause"); graphicenhancement.togglePlayPause() }
            if (ticks === 12) graphicenhancement.logUi("uitest", "UITEST_SHOT paused")
            if (ticks === 16) { graphicenhancement.logUi("uitest", "UITEST_NOTE resume paused=" + graphicenhancement.paused); graphicenhancement.togglePlayPause() }
            if (ticks === 21) { graphicenhancement.logUi("uitest", "UITEST_NOTE end paused=" + graphicenhancement.paused); graphicenhancement.logUi("uitest", "UITEST_DONE"); running = false }
        }
    }
