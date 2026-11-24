
    // ---- pro list stage timings show every NR layer when two or more run ----
    Timer { interval: 150; running: true; repeat: true; onTriggered: graphicenhancement.logUi("uitest-tick", "") }
    Timer {
        interval: 1000; running: true; repeat: true
        property int ticks: 0
        onTriggered: {
            ++ticks
            if (ticks === 2) { graphicenhancement.openUrl("@VIDEO@"); graphicenhancement.nrEnabled = true }
            if (ticks === 8) graphicenhancement.logUi("uitest", "UITEST_NOTE one layer: " + graphicenhancement.stageTimings.map(r => r.label + "=" + r.ms.toFixed(2)).join(", "))
            if (ticks === 9) { const i = graphicenhancement.addEffect("nr"); graphicenhancement.setEffectEnabled(i, true); graphicenhancement.logUi("uitest", "UITEST_NOTE addEffect nr -> " + i + " enabled=" + graphicenhancement.nrLayers.map(l => l.enabled).join(",")) }
            if (ticks === 16) {
                const rows = graphicenhancement.stageTimings
                graphicenhancement.logUi("uitest", "UITEST_NOTE two layers: " + rows.map(r => r.label + "=" + r.ms.toFixed(2)).join(", "))
                root.goPage("pro")
            }
            if (ticks === 18) graphicenhancement.logUi("uitest", "UITEST_SHOT pro")
            if (ticks === 19) {
                const labels = graphicenhancement.stageTimings.map(r => r.label)
                const ok = labels.indexOf("NR 第1层") >= 0 && labels.indexOf("NR 第2层") >= 0
                graphicenhancement.logUi("uitest", ok ? "UITEST_DONE" : "UITEST_FAIL " + labels.join(","))
                running = false
            }
        }
    }
