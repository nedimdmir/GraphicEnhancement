
    // ---- VRAM-leak run: capture with NR, then fullscreen for a while (field log: +3 GB/min) ----
    Timer { interval: 150; running: true; repeat: true; onTriggered: graphicenhancement.logUi("uitest-tick", "") }
    Timer {
        interval: 1000; running: true; repeat: true
        property int ticks: 0
        onTriggered: {
            ++ticks
            if (ticks === 2) dialogs.open("capture")
            if (ticks === 6) {
                const f = graphicenhancement.captureFormats.find(x => x.label.indexOf("2560 x 1440 @ 60") === 0 && x.label.indexOf("NV12") > 0)
                if (f) graphicenhancement.captureFormatKey = f.id
                graphicenhancement.logUi("uitest", "UITEST_NOTE format=" + (f ? f.label : "not found"))
                graphicenhancement.nrEnabled = true
                graphicenhancement.fgEnabled = false
                graphicenhancement.startCaptureSession(); dialogs.close()
            }
            if (ticks === 40) { graphicenhancement.logUi("uitest", "UITEST_NOTE windowed phase done"); root.toggleFullscreen() }
            if (ticks === @END@) { root.toggleFullscreen(); graphicenhancement.logUi("uitest", "UITEST_DONE"); running = false }
        }
    }
