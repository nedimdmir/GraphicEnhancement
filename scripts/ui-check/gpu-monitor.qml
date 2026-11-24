    // ---- GPU usage orb measures one adapter, chosen in settings (default: high-performance) ----
    Timer { interval: 150; running: true; repeat: true; onTriggered: graphicenhancement.logUi("uitest-tick", "") }
    Timer {
        interval: 1000; running: true; repeat: true
        property int ticks: 0
        property var choices: []
        onTriggered: {
            ++ticks
            if (ticks === 1) {
                choices = graphicenhancement.gpuMonitorChoices
                graphicenhancement.logUi("uitest", "UITEST_NOTE choices " + choices.map(c => (c.id || "auto") + "=" + c.label).join(" | ") + " monitor=" + graphicenhancement.gpuMonitorName)
                graphicenhancement.openUrl("@VIDEO@")
            }
            if (ticks >= 5 && ticks <= 9) graphicenhancement.logUi("uitest", "UITEST_NOTE auto gpu=" + graphicenhancement.gpuUtilization.toFixed(1) + " known=" + graphicenhancement.gpuUtilizationKnown)
            if (ticks === 10) {
                const other = choices.length > 2 ? choices[2].id : (choices.length > 1 ? choices[1].id : "")
                graphicenhancement.logUi("uitest", "UITEST_NOTE switch to " + other + " ok=" + graphicenhancement.setPreference("monitorGpu", other) + " monitor=" + graphicenhancement.gpuMonitorName)
            }
            if (ticks >= 13 && ticks <= 16) graphicenhancement.logUi("uitest", "UITEST_NOTE chosen gpu=" + graphicenhancement.gpuUtilization.toFixed(1))
            if (ticks === 17) {
                const bad = graphicenhancement.setPreference("monitorGpu", "dead:beef:00000000")
                graphicenhancement.setPreference("monitorGpu", "")
                root.goPage("set")
                graphicenhancement.logUi("uitest", "UITEST_NOTE unknown id accepted=" + bad + " back to auto monitor=" + graphicenhancement.gpuMonitorName)
            }
            if (ticks === 19) graphicenhancement.logUi("uitest", "UITEST_SHOT settings")
            if (ticks === 20) { graphicenhancement.logUi("uitest", "UITEST_DONE"); running = false }
        }
    }
