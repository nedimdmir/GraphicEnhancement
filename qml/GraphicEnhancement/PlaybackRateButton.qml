import QtQuick
import QtQuick.Controls

Rectangle {
    id: control
    implicitWidth: 44
    implicitHeight: 28
    radius: 8
    visible: graphicenhancement.hasSource && !graphicenhancement.isCapture && graphicenhancement.duration > 0
    enabled: graphicenhancement.running
    property real menuBottomLimit: -1
    readonly property bool menuOpen: rateMenu.visible || customRate.visible
    color: hover.hovered ? Qt.rgba(1, 1, 1, 0.10) : "transparent"
    readonly property string rateLabel: Number(graphicenhancement.playbackRate || 1).toFixed(2).replace(/\.?0+$/, "") + "×"
    Text {
        anchors.centerIn: parent
        text: control.rateLabel
        color: Theme.t1
        font.family: Theme.fontMono
        font.pixelSize: 12
    }
    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: rateMenu.openAt(control, "up") }
    ToolTip.visible: hover.hovered && !control.menuOpen
    ToolTip.text: qsTr("播放速度")
    VMenu {
        id: rateMenu
        objectName: control.objectName + "-menu"
        aboveLimit: control.menuBottomLimit
        title: qsTr("播放速度")
        items: [1, 1.5, 2, 3].map(r => ({ label: r + "×", rate: r, checked: Number(graphicenhancement.playbackRate || 1) === r }))
            .concat([{ label: qsTr("自定义…"), custom: true, checked: [1,1.5,2,3].indexOf(Number(graphicenhancement.playbackRate)) < 0 }])
        onPicked: (i, o) => {
            if (o.custom) customRate.open()
            else graphicenhancement.playbackRate = o.rate
        }
    }
    PlaybackRateDialog { id: customRate; objectName: control.objectName + "-custom" }
}
