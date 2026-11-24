
    // ---- a slider takes a typed value: double-click + type + Enter, then focus + Enter + type ----
    function uitestFind(item, name) {
        if (!item) return null
        if (item.objectName === name) return item
        const kids = item.children || []
        for (let k = 0; k < kids.length; ++k) { const f = uitestFind(kids[k], name); if (f) return f }
        return null
    }
    Timer { interval: 150; running: true; repeat: true; onTriggered: graphicenhancement.logUi("uitest-tick", "") }
    Timer {
        interval: 1000; running: true; repeat: true
        property int ticks: 0
        property var s: null
        onTriggered: {
            ++ticks
            if (ticks === 2) { graphicenhancement.volume = 0.8; root.goPage("set"); settingsPage.section = "audio" }
            if (ticks === 4) {
                s = uitestFind(root.contentItem, "settings-volume")
                if (!s) { graphicenhancement.logUi("uitest", "UITEST_FAIL no slider"); running = false; return }
                const p = s.mapToGlobal(s.trackWidth * 0.25, s.height / 2)
                graphicenhancement.logUi("uitest", "UITEST_DCLICK " + p.x + " " + p.y)
            }
            if (ticks === 5) {
                graphicenhancement.logUi("uitest", "UITEST_NOTE after double-click editing=" + s.editing + " volume=" + graphicenhancement.volume.toFixed(3))
                graphicenhancement.logUi("uitest", "UITEST_SHOT editor")
            }
            if (ticks === 6) graphicenhancement.logUi("uitest", "UITEST_KEY 51 1")   // 3 (replaces the selected text)
            if (ticks === 7) graphicenhancement.logUi("uitest", "UITEST_KEY 55 1")   // 7
            if (ticks === 8) graphicenhancement.logUi("uitest", "UITEST_KEY 13 1")   // Enter
            if (ticks === 9) {
                const ok1 = Math.abs(graphicenhancement.volume - 0.37) < 0.001 && !s.editing
                graphicenhancement.logUi("uitest", "UITEST_NOTE typed 37 -> volume=" + graphicenhancement.volume.toFixed(3) + " editing=" + s.editing + " ok=" + ok1)
                if (!ok1) { graphicenhancement.logUi("uitest", "UITEST_FAIL double-click path"); running = false; return }
                graphicenhancement.logUi("uitest", "UITEST_KEY 13 1")                 // Enter on the focused slider opens it again
            }
            if (ticks === 10) graphicenhancement.logUi("uitest", "UITEST_NOTE enter opens editing=" + s.editing)
            if (ticks === 11) graphicenhancement.logUi("uitest", "UITEST_KEY 49 1")  // 1
            if (ticks === 12) graphicenhancement.logUi("uitest", "UITEST_KEY 50 1")  // 2
            if (ticks === 13) graphicenhancement.logUi("uitest", "UITEST_KEY 48 1")  // 0 -> 120, clamped to 100
            if (ticks === 14) graphicenhancement.logUi("uitest", "UITEST_KEY 13 1")
            if (ticks === 15) {
                graphicenhancement.logUi("uitest", "UITEST_NOTE typed 120 -> volume=" + graphicenhancement.volume.toFixed(3))
                graphicenhancement.logUi("uitest", "UITEST_KEY 13 1")
            }
            if (ticks === 16) graphicenhancement.logUi("uitest", "UITEST_KEY 52 1")  // 4
            if (ticks === 17) graphicenhancement.logUi("uitest", "UITEST_KEY 27 1")  // Esc cancels
            if (ticks === 18) {
                const ok = Math.abs(graphicenhancement.volume - 1.0) < 0.001 && !s.editing
                graphicenhancement.logUi("uitest", "UITEST_NOTE after Esc volume=" + graphicenhancement.volume.toFixed(3) + " editing=" + s.editing)
                graphicenhancement.logUi("uitest", ok ? "UITEST_DONE" : "UITEST_FAIL clamp/escape")
                running = false
            }
        }
    }
