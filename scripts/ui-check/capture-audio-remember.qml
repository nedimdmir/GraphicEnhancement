
    // ---- capture audio choice survives a restart (run twice with the same out dir) ---------
    // MODE=pick: choose the first WASAPI input and connect.  MODE=check: report the choice.
    Timer { interval: 150; running: true; repeat: true; onTriggered: graphicenhancement.logUi("uitest-tick", "") }
    Timer {
        interval: 1000; running: true; repeat: true
        property int ticks: 0
        onTriggered: {
            ++ticks
            if (ticks === 2) dialogs.open("capture")
            if (ticks === 5) {
                const inputs = graphicenhancement.captureAudioInputs
                graphicenhancement.logUi("uitest", "UITEST_NOTE choice=" + graphicenhancement.captureAudioChoice + " inputs=" + inputs.map(i => i.id + ":" + i.label).join(" | "))
                if ("@MODE@" === "pick") {
                    const w = inputs.find(i => i.label.indexOf("[WASAPI]") === 0)
                    if (w) graphicenhancement.captureAudioChoice = w.id
                    graphicenhancement.logUi("uitest", "UITEST_NOTE picked=" + graphicenhancement.captureAudioChoice)
                    graphicenhancement.startCaptureSession(); dialogs.close()
                }
            }
            if (ticks === 9) { graphicenhancement.logUi("uitest", "UITEST_DONE"); running = false }
        }
    }
