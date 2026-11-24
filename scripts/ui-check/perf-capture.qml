
    // ---- performance run: capture 2560x1440 60 NV12, NR (1080p layer), NVIDIA flow, XeSS 2X ----
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
                graphicenhancement.fgBackendName = "@FG@"
                graphicenhancement.fgEnabled = @FGON@
                graphicenhancement.startCaptureSession(); dialogs.close()
            }
            if (ticks === 66) { graphicenhancement.logUi("uitest", "UITEST_DONE"); running = false }
        }
    }
