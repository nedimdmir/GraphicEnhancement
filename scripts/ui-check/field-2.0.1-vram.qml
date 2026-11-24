    // Real product capture/NR/FG/fullscreen check. No driver settings are changed.
    Timer { interval: 150; running: true; repeat: true; onTriggered: graphicenhancement.logUi("uitest-tick", "") }
    Timer {
        interval: 1000; running: true; repeat: true
        property int ticks: 0
        onTriggered: {
            ++ticks
            if (ticks === 2) {
                graphicenhancement.logUi("uitest", "UITEST_NOTE screens=" + Qt.application.screens.map(s => s.name + ":" + s.width + "x" + s.height).join(","))
                dialogs.open("capture")
            }
            if (ticks === 6) {
                const f = graphicenhancement.captureFormats.find(x => x.label.indexOf("3840 x 2160 @ 60") === 0 && x.label.indexOf("NV12") > 0)
                       || graphicenhancement.captureFormats.find(x => x.label.indexOf("2560 x 1440 @ 60") === 0 && x.label.indexOf("NV12") > 0)
                if (!f) { graphicenhancement.logUi("uitest", "UITEST_FAIL no 4K/1440p60 NV12 capture format"); running = false; return }
                graphicenhancement.captureFormatKey = f.id
                graphicenhancement.logUi("uitest", "UITEST_NOTE format=" + f.label)
                graphicenhancement.nrEnabled = true
                graphicenhancement.fgEnabled = false
                if (!graphicenhancement.startCaptureSession()) { graphicenhancement.logUi("uitest", "UITEST_FAIL capture start rejected"); running = false; return }
                dialogs.close()
            }
            if (ticks === 40) { graphicenhancement.logUi("uitest", "UITEST_NOTE fullscreen NR on FG off"); root.toggleFullscreen() }
            if (ticks === 130) { graphicenhancement.logUi("uitest", "UITEST_NOTE fullscreen NR on FG on"); graphicenhancement.fgEnabled = true }
            if (ticks === 230) { graphicenhancement.logUi("uitest", "UITEST_NOTE fullscreen off"); root.toggleFullscreen() }
            if (ticks === 260) { graphicenhancement.logUi("uitest", "UITEST_DONE"); running = false; root.close() }
        }
    }
