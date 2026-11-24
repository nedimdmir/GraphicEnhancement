// List mode: the chain in pipeline order.
//
// Reordering is deliberately NOT offered here. The user's reason was concrete:
// beginners break the chain by dragging it. Only adding layers and toggling them
// is allowed; node mode (NodePage) is where free arrangement lives.
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root
    spacing: 6

    function addEffect(type) {
        const index = graphicenhancement.addEffect(type)
        if (index >= 0) selected = index
    }

    property int selected: -1
    onSelectedChanged: graphicenhancement.selectedNrLayer = selected

    Repeater {
        model: graphicenhancement.chain
        delegate: ChainNodeCard {
            Layout.fillWidth: true
            required property var modelData
            node: modelData
            selected: root.selected === modelData.index
            onToggleRequested: enabled => graphicenhancement.setEffectEnabled(modelData.index, enabled)
            onRemoveRequested: graphicenhancement.removeEffect(modelData.index)
            onSelectRequested: root.selected = modelData.index
        }
    }

    // A refused edit explains itself here rather than in a modal.
    Text {
        Layout.fillWidth: true
        Layout.topMargin: 6
        visible: !graphicenhancement.chainValid
        text: graphicenhancement.chainError
        color: Theme.err
        wrapMode: Text.WordWrap
        font.family: Theme.fontUi
        font.pixelSize: Theme.fsSmall
    }
}
