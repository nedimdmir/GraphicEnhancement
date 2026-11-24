
    // ---- 输出稳定器 from the node page's output card (node mode) ----------------------------
    Timer { interval: 150; running: true; repeat: true; onTriggered: graphicenhancement.logUi("uitest-tick", "") }
    Timer {
        interval: 2000; running: true; repeat: true
        property int phase: 0
        onTriggered: {
            phase += 1
            if (phase === 1) graphicenhancement.openUrl("@VIDEO@")
            if (phase === 2) root.goPage("node")
            if (phase === 3) graphicenhancement.nrHoldStrength = 0.8
            if (phase === 5) graphicenhancement.logUi("uitest", "UITEST_SHOT node-stabiliser")
            if (phase === 6) { graphicenhancement.logUi("uitest", "UITEST_NOTE nodeMode=" + graphicenhancement.nodeMode + " hold=" + graphicenhancement.nrHoldStrength); graphicenhancement.logUi("uitest", "UITEST_DONE"); running = false }
        }
    }
