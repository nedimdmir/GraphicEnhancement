// Loaded into a private copy of Main.qml by aa-53-gui.py: drives the real bridge
// and engine through the anti-aliasing card (#53) while a clip plays.
import QtQuick
import QtQuick.Window
Item {
    id: test
    property string media: ""
    property string shotPath: ""
    property int step: 0
    property int ticks: 0
    property int nodeA: -1
    property int nodeB: -1
    property real beginPosition: 0
    function require(ok, message) {
        if (!ok) throw new Error(message)
        console.log("AA_UI_CHECK", message)
    }
    function chainTypes() { return graphicenhancement.chain.map(n => n.type) }
    function find(item, name) {
        if (!item) return null
        if (item.objectName === name) return item
        for (let i = 0; i < item.children.length; ++i) { const r = find(item.children[i], name); if (r) return r }
        return null
    }
    Timer {
        interval: 400; repeat: true; running: true
        onTriggered: { try {
            if (++test.ticks > 120) throw new Error("deadline step=" + test.step)
            const p = graphicenhancement.antiAliasParams
            if (test.step === 0) {
                if (test.ticks < 4) return
                test.require(!graphicenhancement.antiAliasEnabled && p.present === false, "a fresh profile has no anti-aliasing node")
                const ids = graphicenhancement.effectCatalog.map(e => e.id)
                test.require(ids.indexOf("aa") >= 0 && ids.indexOf("beauty") >= 0, "catalog offers anti-aliasing and beauty")
                graphicenhancement.volume = 0
                graphicenhancement.openPath(test.media)
                test.step = 1; return
            }
            test.require(!graphicenhancement.failed, "player has no error")
            if (test.step === 1) {
                if (!graphicenhancement.running || graphicenhancement.position < 0.5 || graphicenhancement.applying) return
                test.beginPosition = graphicenhancement.position
                graphicenhancement.logUi("aa-53-gui", "BEGIN anti-alias edits")
                graphicenhancement.antiAliasEnabled = true
                test.step = 2; return
            }
            if (graphicenhancement.applying) return
            if (test.step === 2) {
                test.require(graphicenhancement.antiAliasEnabled && p.present && p.method === 1 && p.quality === 2, "the switch creates SMAA high")
                const types = test.chainTypes()
                test.require(types.indexOf("aa") >= 0 && types.indexOf("aa") < types.indexOf("sr") &&
                             types.lastIndexOf("color") < types.indexOf("aa"), "the list chain holds it after the grades and in front of SR")
                const card = test.find(test.Window.window.contentItem, "list-anti-alias")
                const sr = test.find(test.Window.window.contentItem, "list-sr")
                test.require(card && sr && card.visible && card.mapToItem(null, 0, 0).y < sr.mapToItem(null, 0, 0).y,
                             "the card sits above 超分辨率 on the 画质 tab")
                test.require(String(p.summary).indexOf("SMAA") === 0, "the card summary names the method")
                test.step = 3; return
            }
            if (test.step === 3) {
                test.require(graphicenhancement.setAntiAliasParameter("method", 2) && graphicenhancement.antiAliasParams.method === 2 && graphicenhancement.antiAliasParams.quality === 0,
                             "MLAA has no tiers")
                test.require(graphicenhancement.setAntiAliasParameter("mlaaThreshold", 0.15) && Math.abs(graphicenhancement.antiAliasParams.mlaaThreshold - 0.15) < 1e-6,
                             "the MLAA threshold is live")
                test.require(!graphicenhancement.setAntiAliasParameter("temporal", 1), "temporal accumulation is refused for MLAA")
                test.require(!graphicenhancement.setAntiAliasParameter("mlaaThreshold", 0.9), "an out-of-range threshold is refused")
                test.step = 4; return
            }
            if (test.step === 4) {
                test.require(graphicenhancement.setAntiAliasParameter("method", 1) && graphicenhancement.antiAliasParams.quality === 2, "back to SMAA starts at high")
                test.require(graphicenhancement.setAntiAliasParameter("temporal", 2) && Math.abs(graphicenhancement.antiAliasParams.historyWeight - 0.75) < 1e-6,
                             "4x uses its own history default")
                test.require(graphicenhancement.setAntiAliasParameter("temporal", 1) && Math.abs(graphicenhancement.antiAliasParams.historyWeight - 0.5) < 1e-6,
                             "T2x uses its own history default")
                test.require(graphicenhancement.setAntiAliasParameter("historyWeight", 0.6) && graphicenhancement.setAntiAliasParameter("temporal", 2) &&
                             Math.abs(graphicenhancement.antiAliasParams.historyWeight - 0.6) < 1e-6, "a tuned history weight survives a mode change")
                test.require(graphicenhancement.setAntiAliasParameter("temporal", 0), "temporal accumulation off")
                test.step = 5; return
            }
            if (test.step === 5) {
                // Expand the card (SMAA with the experimental temporal rows) for the screenshot.
                test.require(graphicenhancement.setAntiAliasParameter("temporal", 1), "temporal rows for the screenshot")
                test.find(test.Window.window.contentItem, "list-anti-alias").open = true
                test.step = 51; return
            }
            if (test.step === 51) {
                test.require(String(graphicenhancement.antiAliasParams.summary).indexOf("T2x") > 0, "the summary names the experimental mode")
                // grabToImage renders on a later frame: change nothing until it is saved.
                if (test.shotPath.length > 0)
                    test.Window.window.contentItem.grabToImage(r => r.saveToFile(test.shotPath))
                test.step = 52; return
            }
            if (test.step === 52) {
                test.require(graphicenhancement.setAntiAliasParameter("temporal", 0), "temporal accumulation off again")
                test.step = 6; return
            }
            if (test.step === 6) {
                graphicenhancement.antiAliasEnabled = false
                test.require(!graphicenhancement.antiAliasEnabled && graphicenhancement.antiAliasParams.present, "switching off keeps the node and its values")
                test.require(graphicenhancement.chain.find(n => n.type === "aa").enabled === false, "the chip shows it switched off")
                graphicenhancement.nodeMode = 1
                test.step = 7; return
            }
            if (test.step === 7) {
                test.nodeA = graphicenhancement.addEffect("aa")
                test.require(test.nodeA >= 0 && graphicenhancement.antiAliasParamsAt(test.nodeA).enabled, "a node-mode anti-aliasing node starts switched on")
                test.require(graphicenhancement.setAntiAliasParameterAt(test.nodeA, "method", 0) && graphicenhancement.antiAliasParamsAt(test.nodeA).quality === 1,
                             "the node edits its own instance")
                test.nodeB = graphicenhancement.addEffect("aa")
                test.require(test.nodeB >= 0, "a second instance is allowed")
                test.require(graphicenhancement.addEffect("aa") < 0, "a third instance is refused")
                test.step = 8; return
            }
            if (test.step === 8) {
                test.require(graphicenhancement.removeEffect(Math.max(test.nodeA, test.nodeB)) && graphicenhancement.removeEffect(Math.min(test.nodeA, test.nodeB)),
                             "the node instances are removed again")
                graphicenhancement.nodeMode = 0
                test.step = 9; return
            }
            test.require(graphicenhancement.nodeMode === 0 && graphicenhancement.antiAliasParams.present && !graphicenhancement.antiAliasEnabled, "list mode keeps its own configuration")
            test.require(graphicenhancement.position > test.beginPosition + 2, "media time advances through the edits")
            graphicenhancement.logUi("aa-53-gui", "END anti-alias edits")
            console.log("AA_UI_PASS")
            Qt.quit()
        } catch(e) { console.log("AA_UI_FAIL", String(e)); Qt.quit() } }
    }
}
