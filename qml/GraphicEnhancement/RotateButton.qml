import QtQuick

VButton {
    icon: true
    ghost: true
    iconName: "rotatecw"
    implicitWidth: 28
    implicitHeight: 28
    enabled: graphicenhancement.hasSource
    Accessible.role: Accessible.Button
    Accessible.name: tip
    tip: qsTr("顺时针旋转 90°（已旋转 %1°）").arg(graphicenhancement.previewRotation)
    onClicked: graphicenhancement.rotatePictureClockwise()
}
