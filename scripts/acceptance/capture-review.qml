// Loaded only into a private staging copy, never the user's running package.
// claude-capture-review-20261026: one capture-card round with the user's own
// capture setup and effect chain (copied read-only into a private profile).
//   1 resume the remembered capture source; anti-aliasing and the colour grade on
//   2 60 s steady state with every effect on (the user keeps playing)
//   3 信号 card: Windows HDR / VRR / refresh, then 刷新显示器状态
//   4 banner: pause the game; anti-aliasing screenshots on a still picture
//     (NR on: off / after NR / off again / node order = before NR; NR off: off / on)
//   5 everything back on, banner: carry on playing; quit
import QtQuick
Item {
    id: test
    anchors.fill: parent
    z: 1000
    property string shotDir: ""
    property int phase: 0
    property int ticks: 0
    property int shotIndex: 0
    property var notices: []
    property string banner: ""
    property var steps: [
        {name: "nr-aa-off", nr: true, aa: false, node: 0},
        {name: "nr-aa-after", nr: true, aa: true, node: 0},
        {name: "nr-aa-off-repeat", nr: true, aa: false, node: 0},
        {name: "nr-aa-before-node", nr: true, aa: true, node: 1},
        {name: "nonr-aa-off", nr: false, aa: false, node: 0},
        {name: "nonr-aa-on", nr: false, aa: true, node: 0}
    ]
    function check(ok, why) { if (!ok) throw new Error(why) }
    function log(text) { graphicenhancement.logUi("capture-review", text); console.log("CR", text) }
    function state() {
        return "running=" + graphicenhancement.running + " applying=" + graphicenhancement.applying + " nr=" + graphicenhancement.nrEnabled + " aa=" + graphicenhancement.antiAliasEnabled
            + " color=" + graphicenhancement.colorEnabled + " fg=" + graphicenhancement.fgEnabled + " node=" + graphicenhancement.nodeMode + " source=" + graphicenhancement.sourceSummary
            + " submitFps=" + graphicenhancement.submitFps.toFixed(2) + " hdr=" + graphicenhancement.displayHdr + " vrr=" + graphicenhancement.vrrState + "/" + graphicenhancement.vrrSummary
            + " refreshHz=" + graphicenhancement.displayRefreshHz.toFixed(1) + " checking=" + graphicenhancement.displayChecking
    }
    function next(p, why) { phase = p; ticks = 0; log("phase=" + p + " " + why + " | " + state()) }
    Connections { target: graphicenhancement; function onNotice(text, error) { test.notices.push(text); console.log("CR notice", error, text) } }
    Rectangle {
        visible: test.banner.length > 0
        anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter; anchors.topMargin: 40
        width: bannerText.implicitWidth + 60; height: 64; radius: 12
        color: "#E0202020"; border.color: "#FFD54F"; border.width: 2
        Text { id: bannerText; anchors.centerIn: parent; text: test.banner; color: "#FFD54F"; font.pixelSize: 26; font.bold: true }
    }
    Timer {
        interval: 250; repeat: true; running: test.shotDir.length > 0
        onTriggered: { try {
            ++test.ticks
            if (test.phase === 0) {
                if (test.ticks < 8) return
                test.next(1, "resume capture"); graphicenhancement.resumeCaptureSession()
            } else if (test.phase === 1) {
                if (!graphicenhancement.running || graphicenhancement.applying || graphicenhancement.submitFps < 1) { check(test.ticks < 160, "capture did not start within 40 s"); return }
                if (test.ticks < 12) return
                if (!graphicenhancement.antiAliasEnabled) graphicenhancement.antiAliasEnabled = true
                if (!graphicenhancement.colorEnabled) graphicenhancement.colorEnabled = true
                test.next(2, "all effects on")
            } else if (test.phase === 2) {
                if (test.ticks === 20) test.log("steady-start | " + test.state())
                if (test.ticks < 20 + 240) return   // 5 s settle, then 60 s steady
                test.log("steady-end | " + test.state())
                test.notices = []
                test.next(3, "display card")
                check(graphicenhancement.displayHdr >= 0 && graphicenhancement.displayRefreshHz > 0, "信号 card has Windows HDR and the refresh rate")
                graphicenhancement.recheckDisplay()
                check(graphicenhancement.displayChecking, "刷新显示器状态 shows the spinner at once")
            } else if (test.phase === 3) {
                if (test.ticks < 24) return
                const answered = test.notices.filter(t => t.indexOf("已刷新显示器状态") === 0)
                check(answered.length === 1 && !graphicenhancement.displayChecking, "refresh notice: " + JSON.stringify(test.notices))
                test.log("display-refreshed | " + answered[0] + " | " + test.state())
                test.banner = "请暂停游戏（约 40 秒，画面静止即可）"
                test.next(4, "banner: pause the game")
            } else if (test.phase === 4) {
                if (test.ticks < 40) return       // 10 s to pause
                test.shotIndex = 0
                test.next(5, "screenshots")
            } else if (test.phase === 5) {
                const step = test.steps[test.shotIndex]
                if (test.ticks === 1) {
                    if (graphicenhancement.nodeMode !== step.node) graphicenhancement.nodeMode = step.node
                    if (graphicenhancement.nrEnabled !== step.nr) graphicenhancement.nrEnabled = step.nr
                    if (graphicenhancement.antiAliasEnabled !== step.aa) graphicenhancement.antiAliasEnabled = step.aa
                    test.log("shot-config " + step.name + " | " + test.state())
                    return
                }
                if (graphicenhancement.applying || !graphicenhancement.running) { check(test.ticks < 80, "configuration " + step.name + " did not apply"); return }
                if (test.ticks < 14) return       // settle the NR history on the still picture
                if (test.ticks === 14) { graphicenhancement.takeScreenshot(); return }
                if (test.ticks < 22) return
                test.log("shot " + step.name + " file=" + graphicenhancement.lastScreenshot + " | " + test.state())
                if (++test.shotIndex < test.steps.length) { test.ticks = 0; return }
                test.banner = "截图完成，可以继续游戏"
                graphicenhancement.nodeMode = 0; graphicenhancement.nrEnabled = true; graphicenhancement.antiAliasEnabled = true
                test.next(6, "restore every effect")
            } else if (test.phase === 6) {
                if (test.ticks < 24 || graphicenhancement.applying) return
                test.log("done | " + test.state())
                console.log("CR_PASS"); Qt.quit()
            }
        } catch (e) { console.error("CR_FAIL", test.phase, e.message); test.log("FAIL phase=" + test.phase + " " + e.message); Qt.quit() } }
    }
}
