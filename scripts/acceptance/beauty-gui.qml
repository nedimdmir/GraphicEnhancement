// Loaded into a private copy of Main.qml by beauty-gui.py: drives the real bridge,
// the list page's 美颜 group and the engine while a clip with a face plays.
import QtQuick
import QtQuick.Window
Item {
    id: test
    property string media: ""
    property string shotPath: ""
    property int step: 0
    property int ticks: 0
    property int layerIndex: -1
    property int nodeA: -1
    property int nodeB: -1
    property int waitFaces: 0
    property real beginPosition: 0
    function require(ok, message) {
        if (!ok) throw new Error(message)
        console.log("BEAUTY_UI_CHECK", message)
    }
    function chainTypes() { return graphicenhancement.chain.map(n => n.type) }
    function window() { return test.Window.window.contentItem }
    function find(item, name) {
        if (!item) return null
        if (item.objectName === name) return item
        for (let i = 0; i < item.children.length; ++i) { const r = find(item.children[i], name); if (r) return r }
        return null
    }
    // Scroll the inspector so `item` sits at its top.
    function reveal(item) {
        let flick = item.parent
        while (flick && flick.contentY === undefined) flick = flick.parent
        if (!flick) return
        const y = item.mapToItem(flick.contentItem, 0, 0).y - 4
        flick.contentY = Math.max(0, Math.min(y, Math.max(0, flick.contentHeight - flick.height)))
    }
    Timer {
        interval: 400; repeat: true; running: true
        onTriggered: { try {
            if (++test.ticks > 150) throw new Error("deadline step=" + test.step)
            if (test.step === 0) {
                if (test.ticks < 4) return
                test.require(graphicenhancement.beautyLayers.length === 0 && !graphicenhancement.beautyAnyEnabled, "a fresh profile has no beauty layer")
                const ids = graphicenhancement.effectCatalog.map(e => e.id)
                test.require(ids.indexOf("beauty") >= 0 && ids.indexOf("aa") >= 0, "the catalog offers beauty next to anti-aliasing")
                const stage = test.find(test.window(), "list-beauty-stage")
                test.require(stage && stage.visible && !stage.enabledSwitch, "the 美颜 group sits on the 画质 tab, without a switch while empty")
                graphicenhancement.volume = 0
                graphicenhancement.openPath(test.media)
                test.step = 1; return
            }
            test.require(!graphicenhancement.failed, "player has no error")
            if (test.step === 1) {
                if (!graphicenhancement.running || graphicenhancement.position < 0.5 || graphicenhancement.applying) return
                test.beginPosition = graphicenhancement.position
                graphicenhancement.logUi("beauty-gui", "BEGIN beauty edits")
                // Open the group, as a user does to reach its add button.
                test.find(test.window(), "list-beauty-stage").open = true
                test.step = 11; return
            }
            if (test.step === 11) {
                // The group's dashed add button, as a click sends it.
                const add = test.find(test.window(), "list-beauty-add")
                test.require(add && add.visible && !add.full, "the add button is offered")
                add.add()
                test.step = 2; return
            }
            if (graphicenhancement.applying) return
            if (test.step === 2) {
                test.require(graphicenhancement.beautyLayers.length === 1, "the add button creates one layer")
                const l = graphicenhancement.beautyLayers[0]
                test.layerIndex = l.index
                test.require(!l.enabled && !l.restore && !l.smooth, "a new layer arrives switched off with both sub-functions off")
                const types = test.chainTypes()
                const hdr = types.indexOf("video-hdr")
                test.require(hdr < 0 || types.indexOf("beauty") < hdr, "the layer sits in front of RTX Video HDR")
                test.require(test.find(test.window(), "beauty-card-1") !== null, "the layer card exists")
                test.require(graphicenhancement.applyBeautyPreset(test.layerIndex, "restoreNatural"), "preset: original restore + natural smoothing")
                test.step = 3; return
            }
            if (test.step === 3) {
                const l = graphicenhancement.beautyParamsAt(test.layerIndex)
                test.require(l.enabled && l.restore && l.smooth && Math.abs(l.smoothAmount - 0.6) < 1e-6 && l.radius === 5 &&
                             Math.abs(l.restoreStrength - 1) < 1e-6, "the preset switches the layer and both sub-functions on")
                test.require(graphicenhancement.chain.find(n => n.type === "beauty").enabled, "the chip shows the layer on")
                test.step = 4; return
            }
            if (test.step === 4) {
                // The shared tracker reports the face within a few detections.
                if (graphicenhancement.beautyStatus.indexOf("检测到") !== 0) {
                    if (++test.waitFaces < 30) return
                    throw new Error("no face reported: '" + graphicenhancement.beautyStatus + "'")
                }
                test.require(true, "status: " + graphicenhancement.beautyStatus)
                const rows = graphicenhancement.stageTimings.filter(r => r.label === "美颜" || r.label === "人脸识别")
                console.log("BEAUTY_UI_INFO timing", JSON.stringify(rows.map(r => ({label: r.label, ms: r.ms, measured: r.measured}))))
                graphicenhancement.logUi("beauty-gui", "BEGIN live beauty values")
                test.require(graphicenhancement.setBeautyParameterAt(test.layerIndex, "smoothAmount", 0.8) &&
                             Math.abs(graphicenhancement.beautyParamsAt(test.layerIndex).smoothAmount - 0.8) < 1e-6, "the smoothing amount is live")
                test.require(graphicenhancement.setBeautyParameterAt(test.layerIndex, "restoreStrength", 0.5), "the restore strength is live")
                test.require(graphicenhancement.setBeautyParameterAt(test.layerIndex, "scope", 1) && graphicenhancement.beautyParamsAt(test.layerIndex).scope === 1, "all-skin scope")
                test.require(graphicenhancement.setBeautyParameterAt(test.layerIndex, "scope", 0), "back to faces")
                test.require(!graphicenhancement.setBeautyParameterAt(test.layerIndex, "radius", 13), "an out-of-range radius is refused")
                test.require(!graphicenhancement.setBeautyParameterAt(test.layerIndex, "satMin", 0.9), "a saturation floor above the ceiling is refused")
                test.require(graphicenhancement.setBeautyDetection("quality", 2) && graphicenhancement.beautyDetection.quality === 2, "the detection level is live")
                test.require(graphicenhancement.setBeautyDetection("stability", 0.3) && Math.abs(graphicenhancement.beautyDetection.stability - 0.3) < 1e-6,
                             "the tracking stability is live")
                test.step = 5; return
            }
            if (test.step === 5) {
                graphicenhancement.logUi("beauty-gui", "END live beauty values")
                test.require(graphicenhancement.beautyStatus.length > 0, "the status stays: " + graphicenhancement.beautyStatus)
                test.require(graphicenhancement.setBeautyParameterAt(test.layerIndex, "showMask", 1), "mask view on")
                test.step = 6; return
            }
            if (test.step === 6) {
                test.require(graphicenhancement.setBeautyParameterAt(test.layerIndex, "showMask", 0), "mask view off")
                const copy = graphicenhancement.duplicateBeautyLayer(test.layerIndex)
                test.require(copy === test.layerIndex + 1 && graphicenhancement.beautyLayers.length === 2, "copy as a new layer right behind it")
                test.require(graphicenhancement.setBeautyParameterAt(copy, "restoreStrength", 0.25), "the copy edits its own values")
                test.require(graphicenhancement.moveBeautyLayer(copy, -1), "move the copy up")
                test.require(Math.abs(graphicenhancement.beautyLayers[0].restoreStrength - 0.25) < 1e-6 &&
                             Math.abs(graphicenhancement.beautyLayers[1].restoreStrength - 0.5) < 1e-6, "the layers traded places")
                test.require(!graphicenhancement.moveBeautyLayer(graphicenhancement.beautyLayers[0].index, -1), "the first layer cannot move up")
                test.step = 7; return
            }
            if (test.step === 7) {
                test.require(graphicenhancement.setBeautyParameterAt(graphicenhancement.beautyLayers[1].index, "enabled", 0), "switch layer 2 off")
                test.require(graphicenhancement.setAllBeautyEnabled(false) && !graphicenhancement.beautyAnyEnabled, "the group switch turns every layer off")
                test.step = 8; return
            }
            if (test.step === 8) {
                test.require(graphicenhancement.setAllBeautyEnabled(true), "group switch on again")
                test.require(graphicenhancement.beautyLayers[0].enabled && !graphicenhancement.beautyLayers[1].enabled, "on again brings back only the layer that was on")
                test.require(graphicenhancement.resetBeautyLayer(graphicenhancement.beautyLayers[1].index) && !graphicenhancement.beautyLayers[1].restore &&
                             !graphicenhancement.beautyLayers[1].smooth, "reset turns the sub-functions off")
                test.require(graphicenhancement.removeEffect(graphicenhancement.beautyLayers[1].index) && graphicenhancement.beautyLayers.length === 1, "remove the second layer")
                test.step = 9; return
            }
            if (test.step === 9) {
                const stage = test.find(test.window(), "list-beauty-stage")
                const card = test.find(test.window(), "beauty-card-1")
                test.require(stage && card, "the group and its layer card")
                stage.open = true; card.open = true
                test.step = 91; return
            }
            if (test.step === 91) {
                test.reveal(test.find(test.window(), "list-beauty-stage"))
                test.step = 92; return
            }
            if (test.step === 92) {
                // grabToImage renders on a later frame: change nothing until it is saved.
                if (test.shotPath.length > 0)
                    test.window().grabToImage(r => r.saveToFile(test.shotPath))
                test.step = 93; return
            }
            if (test.step === 93) {
                graphicenhancement.nodeMode = 1
                test.step = 10; return
            }
            if (test.step === 10) {
                test.nodeA = graphicenhancement.addEffect("beauty")
                test.require(test.nodeA >= 0 && !graphicenhancement.beautyParamsAt(test.nodeA).enabled, "a node-mode beauty node arrives switched off")
                test.require(graphicenhancement.applyBeautyPreset(test.nodeA, "natural") && graphicenhancement.beautyParamsAt(test.nodeA).enabled &&
                             graphicenhancement.beautyParamsAt(test.nodeA).smooth && !graphicenhancement.beautyParamsAt(test.nodeA).restore, "the node takes a preset")
                test.require(graphicenhancement.duplicateBeautyLayer(test.nodeA) < 0, "node mode copies through the node menu instead")
                // An anti-aliasing node switched off at its defaults has no settings instance either.
                test.nodeB = graphicenhancement.addEffect("aa")
                test.require(test.nodeB >= 0 && graphicenhancement.setEffectEnabled(test.nodeB, false) && !graphicenhancement.antiAliasParamsAt(test.nodeB).enabled,
                             "a node-mode anti-aliasing node switches off at its defaults")
                test.step = 12; return
            }
            if (test.step === 12) {
                test.require(graphicenhancement.removeEffect(Math.max(test.nodeA, test.nodeB)) && graphicenhancement.removeEffect(Math.min(test.nodeA, test.nodeB)),
                             "remove the nodes")
                graphicenhancement.nodeMode = 0
                test.step = 13; return
            }
            test.require(graphicenhancement.nodeMode === 0 && graphicenhancement.beautyLayers.length === 1 && graphicenhancement.beautyLayers[0].enabled,
                         "list mode keeps its own beauty layer")
            test.require(graphicenhancement.position > test.beginPosition + 2, "media time advances through the edits")
            graphicenhancement.logUi("beauty-gui", "END beauty edits")
            console.log("BEAUTY_UI_PASS")
            Qt.quit()
        } catch(e) { console.log("BEAUTY_UI_FAIL", String(e)); Qt.quit() } }
    }
}
