    // ---- export: closes playback at start, VBR 8 Mbps default, ETA holds while paused ----
    function uitestFind(item, name) {
        if (!item) return null
        if (item.objectName === name) return item
        const kids = item.children || []
        for (let k = 0; k < kids.length; ++k) { const f = uitestFind(kids[k], name); if (f) return f }
        return null
    }
    Connections { target: graphicenhancement; function onNotice(text, isError) { graphicenhancement.logUi("uitest-notice", (isError ? "ERR " : "") + text) } }
    Timer { interval: 150; running: true; repeat: true; onTriggered: graphicenhancement.logUi("uitest-tick", "") }
    Timer {
        interval: 1000; running: true; repeat: true
        property int ticks: 0
        property string failure: ""
        property real etaPaused: 0
        function fail(why) { if (!failure) failure = why }
        function eta() { const n = uitestFind(root.contentItem, "export-eta"); return n ? n.text : "(none)" }
        onTriggered: {
            ++ticks
            if (ticks === 2) {
                graphicenhancement.logUi("uitest", "UITEST_NOTE default rate=" + graphicenhancement.exportRateControl + " bitrate=" + graphicenhancement.exportBitrateMbps)
                if (graphicenhancement.exportRateControl !== 1 || graphicenhancement.exportBitrateMbps !== 8) fail("default not VBR 8")
                graphicenhancement.openUrl("@VIDEO@")
            }
            if (ticks === 5) {
                root.goPage("exp")

                graphicenhancement.addExportFiles(["@VIDEO@"])
            }
            if (ticks === 8) { graphicenhancement.logUi("uitest", "UITEST_NOTE before start hasSource=" + graphicenhancement.hasSource + " ready=" + graphicenhancement.exportReadyCount + " target=" + graphicenhancement.exportTarget + " items=" + JSON.stringify(graphicenhancement.exportItems.map(i => i.state + ":" + i.note))); graphicenhancement.startExport() }
            if (ticks === 10) {
                graphicenhancement.logUi("uitest", "UITEST_NOTE after start hasSource=" + graphicenhancement.hasSource + " running=" + graphicenhancement.exportRunning)
                if (graphicenhancement.hasSource) fail("playback still open after export start")
            }
            if (ticks === 16) { graphicenhancement.logUi("uitest", "UITEST_NOTE running eta=" + graphicenhancement.exportEtaSeconds.toFixed(1) + " text=" + eta()); graphicenhancement.pauseExport(true) }
            if (ticks === 18) { etaPaused = graphicenhancement.exportEtaSeconds; graphicenhancement.logUi("uitest", "UITEST_NOTE paused eta=" + etaPaused.toFixed(1) + " text=" + eta()); graphicenhancement.logUi("uitest", "UITEST_SHOT paused") }
            if (ticks === 24) {
                const later = graphicenhancement.exportEtaSeconds
                graphicenhancement.logUi("uitest", "UITEST_NOTE paused 6s later eta=" + later.toFixed(1) + " paused=" + graphicenhancement.exportPaused)
                if (Math.abs(later - etaPaused) > 1.0) fail("eta moved while paused " + etaPaused.toFixed(1) + " -> " + later.toFixed(1))
                if (eta().indexOf("已暂停") < 0) fail("paused text missing: " + eta())
                graphicenhancement.pauseExport(false)
            }
            if (ticks === 28) { graphicenhancement.logUi("uitest", "UITEST_NOTE resumed eta=" + graphicenhancement.exportEtaSeconds.toFixed(1) + " text=" + eta()); graphicenhancement.cancelExport() }
            if (ticks === 32) { graphicenhancement.logUi("uitest", failure ? "UITEST_FAIL " + failure : "UITEST_DONE"); running = false }
        }
    }
