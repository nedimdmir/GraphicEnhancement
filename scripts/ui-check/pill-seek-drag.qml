
    // ---- dragging the 极简 pill's seek rail seeks and does not move the window ----
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
        property real wx: 0
        property real wy: 0
        onTriggered: {
            ++ticks
            if (ticks === 2) graphicenhancement.openUrl("@VIDEO@")
            if (ticks === 6) { graphicenhancement.togglePlayPause(); graphicenhancement.logUi("uitest", "UITEST_SHOT before") }
            if (ticks === 7) {
                const seek = uitestFind(fullBar.contentItem, "cine-seek")
                if (!seek) { graphicenhancement.logUi("uitest", "UITEST_FAIL no seek rail"); running = false; return }
                const a = seek.mapToGlobal(seek.width * 0.2, seek.height / 2)
                const b = seek.mapToGlobal(seek.width * 0.6, seek.height / 2)
                wx = root.x; wy = root.y
                graphicenhancement.logUi("uitest", "UITEST_NOTE window " + wx + "," + wy + " progress " + graphicenhancement.progress.toFixed(3))
                graphicenhancement.logUi("uitest", "UITEST_DRAG " + a.x + " " + a.y + " " + b.x + " " + (b.y + 6))
            }
            if (ticks === 10) {
                const moved = Math.abs(root.x - wx) + Math.abs(root.y - wy)
                graphicenhancement.logUi("uitest", "UITEST_NOTE after drag window " + root.x + "," + root.y + " progress " + graphicenhancement.progress.toFixed(3))
                graphicenhancement.logUi("uitest", "UITEST_SHOT after")
                const ok = moved < 2 && graphicenhancement.progress > 0.5 && graphicenhancement.progress < 0.7
                graphicenhancement.logUi("uitest", ok ? "UITEST_DONE" : "UITEST_FAIL moved=" + moved + " progress=" + graphicenhancement.progress.toFixed(3))
                running = false
            }
        }
    }
