    // ---- monitoring overlay (RTSS / MSI Afterburner OSD) stress: every presenter path while the OSD draws ----
    // Run with RTSS running and something writing OSD text. Each step logs the run status; a lost device or a
    // crash ends the run early. Shots: windowed, fullscreen, each frame-generation backend, back to windowed.
    Timer { interval: 150; running: true; repeat: true; onTriggered: graphicenhancement.logUi("uitest-tick", "") }
    Timer {
        interval: 1000; running: true; repeat: true
        property int ticks: 0
        function note(what) { graphicenhancement.logUi("uitest", "UITEST_NOTE " + what + " status=" + graphicenhancement.runStatus + " fg=" + graphicenhancement.fgBackendName + "/" + graphicenhancement.fgEnabled) }
        onTriggered: {
            ++ticks
            if (ticks === 2) graphicenhancement.openUrl("@VIDEO@")
            if (ticks === 6) { note("plain"); graphicenhancement.logUi("uitest", "UITEST_SHOT plain") }
            if (ticks === 7) { graphicenhancement.nrEnabled = true; graphicenhancement.srEnabled = true }
            if (ticks === 11) { note("nr+sr"); graphicenhancement.logUi("uitest", "UITEST_SHOT nrsr") }
            if (ticks === 12) { graphicenhancement.fgBackendName = "dlss"; graphicenhancement.fgEnabled = true }
            if (ticks === 17) { note("fg dlss"); graphicenhancement.logUi("uitest", "UITEST_SHOT fg-dlss") }
            if (ticks === 18) root.toggleFullscreen()
            if (ticks === 23) { note("fullscreen dlss"); graphicenhancement.logUi("uitest", "UITEST_SHOT full-dlss") }
            if (ticks === 24) graphicenhancement.fgBackendName = "xess"
            if (ticks === 30) { note("fullscreen xess"); graphicenhancement.logUi("uitest", "UITEST_SHOT full-xess") }
            if (ticks === 31) graphicenhancement.fgBackendName = "fsr3"
            if (ticks === 37) { note("fullscreen fsr3"); graphicenhancement.logUi("uitest", "UITEST_SHOT full-fsr3") }
            if (ticks === 38) root.toggleFullscreen()
            if (ticks === 42) { note("windowed fsr3"); graphicenhancement.logUi("uitest", "UITEST_SHOT win-fsr3") }
            if (ticks === 43) { graphicenhancement.fgEnabled = false; root.goPage("pro") }
            if (ticks === 47) { note("pro page"); graphicenhancement.logUi("uitest", "UITEST_SHOT pro") }
            if (ticks === 48) root.goPage("home")
            if (ticks === 51) { note("home"); graphicenhancement.logUi("uitest", "UITEST_SHOT home") }
            if (ticks === 52) { graphicenhancement.logUi("uitest", "UITEST_DONE"); running = false }
        }
    }
