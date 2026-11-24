import QtQuick
Item {
    id: test
    property string caseName: "hdr"
    property var appWindow: Window.window
    property int ticks: 0
    property int phase: 0
    function require(ok, text) { if (!ok) throw new Error(text) }
    function find(item, name) {
        if (item.objectName === name) return item
        for (const child of item.children || []) { const found = find(child, name); if (found) return found }
        return null
    }
    function findPro(item) {
        if (typeof item.tab === "string" && item.tab === "quality") return item
        for (const child of item.children || []) { const found = findPro(child); if (found) return found }
        return null
    }
    function findSettings(item) {
        if (typeof item.section === "string" && item.sectionColumns !== undefined) return item
        for (const child of item.children || []) { const found = findSettings(child); if (found) return found }
        return null
    }
    function preset(name) {
        const entry = graphicenhancement.presets.find(p => p.name === name)
        require(entry !== undefined, "saved preset missing: " + name)
        require(graphicenhancement.applyPresetIndex(entry.index), "preset apply refused: " + name)
    }
    function listValues() {
        require(graphicenhancement.nodeMode === 0, "list mode")
        require(graphicenhancement.hdrTuningPreset === "darkAndBright", "list HDR baseline " + graphicenhancement.hdrTuningPreset)
        require(graphicenhancement.hdrCurve && graphicenhancement.hdrMetadataEnabled, "list HDR toggles")
        require(graphicenhancement.hdrCurveStrength === 140 && graphicenhancement.hdrDisplayPeakNits === 1600, "list HDR dials")
        require(graphicenhancement.contentRate === 2 && graphicenhancement.opticalFlowChoice === 1 && graphicenhancement.flowQuality === 2, "list Flow")
        require(graphicenhancement.nrLayers.length === 1 && graphicenhancement.nrLayers[0].style === 2 && graphicenhancement.nrLayers[0].total === 5 && graphicenhancement.nrLayers[0].correctionEnabled, "list NR5 style2 correction")
    }
    function nodeValues() {
        require(graphicenhancement.nodeMode === 1 && graphicenhancement.hdrTuningPreset === "darkRoom", "node HDR baseline")
        require(graphicenhancement.hdrCurveStrength === 75 && graphicenhancement.hdrDisplayPeakNits === 1000, "node HDR dials")
    }
    function first() {
        require(!graphicenhancement.hdrCurve && !graphicenhancement.hdrMetadataEnabled, "new HDR defaults must be off")
        graphicenhancement.nrEnabled = false; graphicenhancement.srEnabled = false; graphicenhancement.fgEnabled = false; graphicenhancement.muted = true
        for (const id of ["standard", "darkLift", "highlightGuard", "darkAndBright", "brightRoom", "darkRoom", "punch"]) {
            require(graphicenhancement.applyHdrTuningPreset(id) && graphicenhancement.hdrTuningPreset === id, "HDR preset " + id)
            graphicenhancement.hdrCurveStrength = 150; graphicenhancement.hdrDisplayPeakNits = 1400
            require(graphicenhancement.hdrTuningPreset === id, "dials must preserve HDR baseline " + id)
        }
        const old = JSON.stringify(graphicenhancement.hdrCurveParams)
        require(!graphicenhancement.setHdrCurveParameter("midGrayNits", NaN), "reject NaN")
        require(!graphicenhancement.setHdrCurveParameter("peakCapNits", 50000), "reject oversized value")
        require(!graphicenhancement.setHdrMetadataParameter("maxCllNits", Infinity), "reject infinite metadata")
        require(JSON.stringify(graphicenhancement.hdrCurveParams) === old, "invalid input must preserve settings")
        require(graphicenhancement.setHdrCurveParameter("midGrayNits", 333) && graphicenhancement.hdrTuningPreset === "custom", "manual HDR controls")
        require(graphicenhancement.applyHdrTuningPreset("darkAndBright"), "list HDR preset")
        graphicenhancement.hdrCurveStrength = 140; graphicenhancement.hdrDisplayPeakNits = 1600
        if (!graphicenhancement.nrLayers.length) graphicenhancement.addEffect("nr")
        const index = graphicenhancement.nrLayers[0].index
        require(graphicenhancement.setNrLayerParameter(index, "runtime", 3), "NVIDIA original NR")
        require(graphicenhancement.setNrLayerParameter(index, "style", 2), "style2")
        require(graphicenhancement.setNrLayerParameter(index, "total", 5), "NR5")
        require(graphicenhancement.setNrLayerParameter(index, "correctionEnabled", 1), "automatic correction")
        require(graphicenhancement.setOpticalFlowChoice(1), "AMD flow")
        graphicenhancement.flowQuality = 2; graphicenhancement.contentRate = 2
        listValues()
        require(graphicenhancement.savePresetAs("PR19 list HDR NR5 Flow", 17, false), "list Chain+Flow preset save")
        require(graphicenhancement.savePresetAs("PR19 chain HDR only", 1, false), "chain-only preset save")
        graphicenhancement.nodeMode = 1
        require(graphicenhancement.applyHdrTuningPreset("darkRoom"), "node HDR preset")
        graphicenhancement.hdrCurveStrength = 75; graphicenhancement.hdrDisplayPeakNits = 1000
        nodeValues()
        require(graphicenhancement.savePresetAs("PR19 node HDR", 17, true), "node preset save")
        graphicenhancement.nodeMode = 0; listValues()
        console.log("PR_UI_FIRST_PASS", JSON.stringify(graphicenhancement.hdrDisplayInfo), JSON.stringify(graphicenhancement.presets.filter(p => !p.builtin)))
    }
    function restore() {
        listValues()
        graphicenhancement.nodeMode = 1; nodeValues()
        require(graphicenhancement.applyHdrTuningPreset("standard"), "clear node HDR")
        graphicenhancement.hdrCurveStrength = 100; graphicenhancement.hdrDisplayPeakNits = 0
        preset("PR19 node HDR"); nodeValues()
        graphicenhancement.nodeMode = 0; listValues()
        require(graphicenhancement.applyHdrTuningPreset("standard"), "clear list HDR")
        graphicenhancement.hdrCurveStrength = 100; graphicenhancement.hdrDisplayPeakNits = 0; graphicenhancement.contentRate = 3
        preset("PR19 chain HDR only")
        require(graphicenhancement.hdrCurveStrength === 140 && graphicenhancement.hdrTuningPreset === "darkAndBright", "Chain preset HDR restore")
        require(graphicenhancement.contentRate === 3, "Chain-only preset must preserve cadence")
        preset("PR19 list HDR NR5 Flow"); listValues()
        console.log("PR_UI_RESTORE_PASS", JSON.stringify(graphicenhancement.hdrCurveParams), JSON.stringify(graphicenhancement.nrLayers))
    }
    Timer {
        interval: 250; running: true; repeat: true
        onTriggered: {
            try {
                ++test.ticks; test.require(test.ticks < 160, "40s GUI deadline")
                if (test.phase === 0 && test.ticks >= 12) {
                    test.appWindow.width = 1280; test.appWindow.height = 800; test.appWindow.page = "pro"
                    test.phase = 1
                } else if (test.phase === 1 && test.ticks >= 20) {
                    const pro = test.findPro(test.appWindow.contentItem)
                    test.require(pro !== null, "real ProPage missing"); pro.tab = "display"; test.phase = 2
                } else if (test.phase === 2 && test.ticks >= 26) {
                    const curve = test.find(test.appWindow.contentItem, "list-hdr-curve")
                    const metadata = test.find(test.appWindow.contentItem, "list-hdr-metadata")
                    test.require(curve !== null && metadata !== null, "real HDR accordions missing")
                    curve.open = true; metadata.open = true
                    test.require(test.find(test.appWindow.contentItem, "list-hdrcurve-strength") !== null, "HDR strength slider missing")
                    if (test.caseName === "hdr") test.first(); else test.restore()
                    test.phase = 3
                } else if (test.phase === 3 && test.ticks >= 32) {
                    test.appWindow.page = "set"; test.phase = 4
                } else if (test.phase === 4 && test.ticks >= 36) {
                    const settings = test.findSettings(test.appWindow.contentItem)
                    test.require(settings !== null, "real SettingsPage missing"); settings.section = "play"; test.phase = 5
                } else if (test.phase === 5 && test.ticks >= 42) {
                    const strength = test.find(test.appWindow.contentItem, "hdrcurve-strength")
                    const meta = test.find(test.appWindow.contentItem, "hdrmeta-enabled")
                    test.require(strength !== null && strength.value === 140, "SettingsPage HDR strength binding")
                    test.require(meta !== null && meta.checked, "SettingsPage metadata binding")
                    console.log("PR_UI_SETTINGS_PASS"); test.phase = 6
                } else if (test.phase === 6 && test.ticks >= 48) Qt.quit()
            } catch (e) { console.error("PR_UI_FAIL", test.phase, e.message); Qt.quit() }
        }
    }
}
