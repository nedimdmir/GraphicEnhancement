
    // ---- click the picture: pause/resume a file; arrows seek 5 s; double click = fullscreen ----
    Timer { interval: 150; running: true; repeat: true; onTriggered: graphicenhancement.logUi("uitest-tick", "") }
    Timer {
        interval: 1000; running: true; repeat: true
        property int ticks: 0
        property real pos: 0
        function center() { return root.contentItem.mapToGlobal(videoHost.x + videoHost.width / 2, videoHost.y + videoHost.height / 2) }
        onTriggered: {
            ++ticks
            if (ticks === 2) graphicenhancement.openUrl("@VIDEO@")
            if (ticks === 6) { const c = center(); graphicenhancement.logUi("uitest", "UITEST_NOTE playing=" + !graphicenhancement.paused); graphicenhancement.logUi("uitest", "UITEST_CLICK " + c.x + " " + c.y) }
            if (ticks === 8) { graphicenhancement.logUi("uitest", "UITEST_NOTE after click playing=" + !graphicenhancement.paused); const c = center(); graphicenhancement.logUi("uitest", "UITEST_CLICK " + c.x + " " + c.y) }
            if (ticks === 10) { graphicenhancement.logUi("uitest", "UITEST_NOTE after 2nd click playing=" + !graphicenhancement.paused); pos = graphicenhancement.position; graphicenhancement.logUi("uitest", "UITEST_KEY 39 1") }
            if (ticks === 11) { graphicenhancement.logUi("uitest", "UITEST_NOTE right arrow moved " + (graphicenhancement.position - pos).toFixed(2) + " s"); const c = center(); graphicenhancement.logUi("uitest", "UITEST_DCLICK " + c.x + " " + c.y) }
            if (ticks === 13) {
                graphicenhancement.logUi("uitest", "UITEST_NOTE after double click fullscreen=" + root.fullscreen + " playing=" + !graphicenhancement.paused)
                const ok = root.fullscreen && !graphicenhancement.paused
                root.toggleFullscreen()
                graphicenhancement.logUi("uitest", ok ? "UITEST_DONE" : "UITEST_FAIL")
                running = false
            }
        }
    }
