    // ---- colour 效果 group: texture / clarity / dehaze must change the picture (field report 2026-10-02) ----
    // Paused on one frame, so a screenshot difference can only come from the setting.
    Timer { interval: 150; running: true; repeat: true; onTriggered: graphicenhancement.logUi("uitest-tick", "") }
    Timer {
        interval: 1200; running: true; repeat: true
        property int ticks: 0
        readonly property var steps: [
            ["base", "", 0], ["clarity+", "clarity", 100], ["clarity-", "clarity", -100],
            ["texture+", "texture", 100], ["dehaze+", "dehaze", 100], ["dehaze-", "dehaze", -100], ["base2", "", 0]]
        onTriggered: {
            ++ticks
            if (ticks === 2) graphicenhancement.openUrl("@VIDEO@")
            if (ticks === 4) { root.goPage("pro"); graphicenhancement.colorEnabled = true }
            if (ticks === 5) { graphicenhancement.seekTo(12); if (!graphicenhancement.paused) graphicenhancement.togglePlayPause() }
            const k = ticks - 7
            if (k >= 0 && k < steps.length * 2) {
                const s = steps[Math.floor(k / 2)]
                if (k % 2 === 0) {
                    for (const n of ["clarity", "texture", "dehaze"]) graphicenhancement.setColourParameter(n, 0)
                    if (s[1]) graphicenhancement.setColourParameter(s[1], s[2])
                    graphicenhancement.logUi("uitest", "UITEST_NOTE " + s[0] + " paused=" + graphicenhancement.paused + " clarity=" + graphicenhancement.colourParameter("clarity"))
                } else graphicenhancement.logUi("uitest", "UITEST_SHOT " + s[0])
            }
            if (k === steps.length * 2 + 2) { graphicenhancement.logUi("uitest", "UITEST_DONE"); running = false }
        }
    }
