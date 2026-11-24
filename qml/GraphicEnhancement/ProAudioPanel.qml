// Professional-view audioCol controls; settings remain in the shared bridge.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import QtQuick.Effects

ColumnLayout {
    id: audioCol
    Layout.fillWidth: true
    spacing: 6
    VGroup {
        VRow {
            label: qsTr("音量")
            value: Math.round(graphicenhancement.volume * 100) + "%"
            VSlider {
                implicitWidth: 150
                from: 0; to: graphicenhancement.maximumVolume; value: graphicenhancement.volume; inputScale: 100
                defaultValue: 1
                onMoved: value => graphicenhancement.volume = value
            }
        }
        VRow {
            label: qsTr("静音")
            VSwitch {
                checked: graphicenhancement.muted
                onToggled: checked => graphicenhancement.muted = checked
            }
        }
        VRow {
            visible: graphicenhancement.sourceKind === "capture"
            label: qsTr("本机音频监听")
            hint: qsTr("关闭后仍可录制和保存回放；本机不播放采集声音")
            VSwitch {
                objectName: "pro-capture-audio-monitor"
                checked: graphicenhancement.preferences.captureAudioMonitor !== false
                onToggled: v => graphicenhancement.setPreference("captureAudioMonitor", v)
            }
        }
        VRow {
            label: qsTr("声音同步")
            hint: graphicenhancement.audioSyncMode === 0 ? (graphicenhancement.audioSyncLive ? qsTr("软件估算补偿 ") + graphicenhancement.audioCompensationMs.toFixed(0) + " ms" : qsTr("自动估算 · 采集卡 / PS5 实时输入时生效"))
                  : graphicenhancement.audioSyncMode === 1 ? qsTr("手动偏移 · 实时输入时生效") : qsTr("关闭补偿")
            VSeg {
                options: [{ id: "0", label: qsTr("自动估算") }, { id: "1", label: qsTr("手动") }, { id: "2", label: qsTr("关闭", "off") }]
                current: String(graphicenhancement.audioSyncMode)
                onPicked: id => graphicenhancement.audioSyncMode = Number(id)
            }
        }
        VRow {
            label: qsTr("音频偏移")
            hint: qsTr("正值延后音频")
            value: graphicenhancement.audioOffsetMs + " ms"
            VSlider {
                implicitWidth: 150
                center: true
                from: -250; to: 250; value: graphicenhancement.audioOffsetMs; enabledControl: graphicenhancement.audioSyncMode === 1
                onMoved: value => graphicenhancement.audioOffsetMs = Math.round(value)
            }
        }
    }
    VEyebrow { text: qsTr("音轨") }
    Text {
        visible: graphicenhancement.audioTracks.length === 0
        text: qsTr("当前源没有可选音轨。")
        color: Theme.t3
        font.family: Theme.fontUi
        font.pixelSize: Theme.fsSmall
    }
    Repeater {
        model: graphicenhancement.audioTracks
        delegate: Rectangle {
            required property var modelData
            Layout.fillWidth: true
            implicitHeight: 44
            radius: 12
            color: Theme.card2
            border.width: 1
            border.color: graphicenhancement.selectedAudioTrack === modelData.index ? Theme.accent : Theme.stroke
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 12
                VEqBars {
                    active: graphicenhancement.selectedAudioTrack === modelData.index && graphicenhancement.running && !graphicenhancement.paused
                    opacity: graphicenhancement.selectedAudioTrack === modelData.index ? 1 : 0.6
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        text: modelData.label
                        color: Theme.t1
                        font.family: Theme.fontUi
                        font.pixelSize: Theme.fsBody
                    }
                    Text {
                        text: modelData.channels > 0 ? modelData.channels + qsTr(" 声道") : ""
                        color: Theme.t3
                        font.family: Theme.fontUi
                        font.pixelSize: 11
                    }
                }
            }
            HoverHandler { cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: graphicenhancement.selectedAudioTrack = modelData.index }
        }
    }
}
