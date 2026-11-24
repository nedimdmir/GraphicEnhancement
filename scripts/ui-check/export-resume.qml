    // ---- export continues after a GPU reset (field report 2026-10-02: 8K NR export lost to a TDR) ----
    // Run with GRAPHICENHANCEMENT_TEST_EXPORT_REMOVE_DEVICE_AT=<frame> so the first worker loses its D3D12 device.
    Connections { target: graphicenhancement; function onNotice(text, isError) { graphicenhancement.logUi("uitest-notice", (isError ? "ERR " : "") + text) } }
    Timer { interval: 150; running: true; repeat: true; onTriggered: graphicenhancement.logUi("uitest-tick", "") }
    Timer {
        interval: 1000; running: true; repeat: true
        property int ticks: 0
        property int finishedAt: 0
        onTriggered: {
            ++ticks
            if (ticks === 2) { graphicenhancement.openUrl("@VIDEO@") }
            if (ticks === 4) { root.goPage("pro"); if (@NR@) { if (graphicenhancement.nrLayers.length === 0) graphicenhancement.addEffect("nr"); graphicenhancement.setAllNrEnabled(true) } }
            if (ticks === 6) { root.goPage("exp"); graphicenhancement.addExportFiles(["@VIDEO@"]) }
            if (ticks === 8) { graphicenhancement.logUi("uitest", "UITEST_NOTE start target=" + graphicenhancement.exportTarget); graphicenhancement.startExport() }
            if (ticks > 8 && ticks % 2 === 0)
                graphicenhancement.logUi("uitest", "UITEST_NOTE running=" + graphicenhancement.exportRunning + " progress=" + graphicenhancement.exportProgress.toFixed(3) + " status=" + graphicenhancement.exportStatus)
            if (ticks > 12 && !graphicenhancement.exportRunning && !finishedAt) {
                finishedAt = ticks
                graphicenhancement.logUi("uitest", "UITEST_NOTE finished status=" + graphicenhancement.exportStatus + " items=" + JSON.stringify(graphicenhancement.exportItems.map(i => i.state + ":" + i.note)))
            }
            if (finishedAt && ticks === finishedAt + 2) { graphicenhancement.logUi("uitest", "UITEST_DONE"); running = false }
            if (ticks === 250) { graphicenhancement.logUi("uitest", "UITEST_FAIL export did not finish"); running = false }
        }
    }
