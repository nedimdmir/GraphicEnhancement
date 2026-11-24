
    // ---- screen DPI change with a video open (run with GRAPHICENHANCEMENT_TEST_DPI_FLIP=8000) ----------
    // Field report 2026-10-01: moving the window to a second monitor with a video open
    // crashed in QQuickItem::childItems. The app must survive both DPI changes.
    Timer { interval: 150; running: true; repeat: true; onTriggered: graphicenhancement.logUi("uitest-tick", "") }
    Timer {
        interval: 250; running: true; repeat: true
        property int ticks: 0
        onTriggered: {
            ++ticks
            if (ticks === 6) graphicenhancement.openUrl("@VIDEO@")
            if (ticks === 14) root.goPage("pro")
            if (ticks === 40) graphicenhancement.logUi("uitest", "UITEST_SHOT after-dpi-150")
            if (ticks === 56) { graphicenhancement.logUi("uitest", "UITEST_NOTE running=" + graphicenhancement.running + " page=" + root.page); graphicenhancement.logUi("uitest", "UITEST_DONE"); running = false }
        }
    }
