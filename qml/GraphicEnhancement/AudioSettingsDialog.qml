// audio dialog: source/settings logic is owned by this component.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

DialogLayer {
    key: "audio"
    glyph: "music"
    title: qsTr("音频设置")
    dialogWidth: 560
    actions: [{ label: qsTr("完成"), primary: true }]
    onActionTriggered: dialogHost.close()

    DialogSection { text: qsTr("音轨") }
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 6
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
                implicitHeight: 52
                radius: 12
                color: Theme.card2
                border.width: 1
                border.color: graphicenhancement.selectedAudioTrack === modelData.index ? Theme.accent : Theme.stroke
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 12
                    // .trk .bars: the playing track's bars move (M39).
                    VEqBars {
                        objectName: "audio-track-bars-" + modelData.index
                        active: graphicenhancement.selectedAudioTrack === modelData.index && graphicenhancement.running && !graphicenhancement.paused
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
                    VIcon {
                        visible: graphicenhancement.selectedAudioTrack === modelData.index
                        name: "check"
                        color: Theme.accent
                    }
                }
                HoverHandler { cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: graphicenhancement.selectedAudioTrack = modelData.index }
            }
        }
    }
    DialogSection { text: qsTr("输出") }
    DialogGroup {
        VRow {
            label: qsTr("音量")
            value: Math.round(graphicenhancement.volume * 100) + "%"
            VSlider {
                implicitWidth: 170
                from: 0; to: graphicenhancement.maximumVolume; value: graphicenhancement.volume; inputScale: 100
                defaultValue: 1
                onMoved: graphicenhancement.volume = value
            }
        }
        VRow {
            label: qsTr("静音")
            VSwitch {
                checked: graphicenhancement.muted
                onToggled: checked => graphicenhancement.muted = checked
            }
        }
    }
    DialogGroup {
        visible: graphicenhancement.sourceKind === "capture"
        VRow {
            label: qsTr("本机音频监听")
            hint: qsTr("关闭后仍可录制和保存回放；本机不播放采集声音")
            VSwitch {
                objectName: "audio-capture-monitor"
                checked: graphicenhancement.preferences.captureAudioMonitor !== false
                onToggled: v => graphicenhancement.setPreference("captureAudioMonitor", v)
            }
        }
        VRow {
            label: qsTr("HDMI 码流直通")
            hint: qsTr("将采集的 AC-3 / DTS 送到功放。直通期间会独占所选输出设备，其他程序无法在该设备播放声音。")
            VSwitch {
                objectName: "audio-hdmi-passthrough"
                checked: graphicenhancement.preferences.captureHdmiPassthrough === true
                onToggled: v => graphicenhancement.setPreference("captureHdmiPassthrough", v)
            }
        }
    }
    DialogSection { text: qsTr("音画同步") }
    DialogGroup {
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
            label: qsTr("手动偏移")
            hint: qsTr("负值 = 声音提前")
            value: graphicenhancement.audioOffsetMs + " ms"
            VSlider {
                implicitWidth: 170
                center: true
                from: -250; to: 250; value: graphicenhancement.audioOffsetMs; enabledControl: graphicenhancement.audioSyncMode === 1
                onMoved: graphicenhancement.audioOffsetMs = Math.round(value / 10) * 10
            }
        }
        VRow {
            label: qsTr("当前偏差")
            hint: qsTr("软件内测得的音画偏差，不是扬声器实测；只在采集卡 / PS5 实时输入时有")
            value: graphicenhancement.audioSkewKnown ? (graphicenhancement.audioSkewMs >= 0 ? "+" : "") + graphicenhancement.audioSkewMs.toFixed(0) + " ms" : qsTr("未测")
        }
    }
    DialogSection { text: qsTr("输出设备") }
    DialogGroup {
        VRow {
            label: qsTr("输出设备")
            hint: graphicenhancement.audioOutputStatus
            VSelect {
                objectName: "audio-device"
                implicitWidth: 240
                readonly property string chosen: graphicenhancement.preferences.audioDevice || ""
                value: { const d = graphicenhancement.audioDevices.find(x => x.id === chosen); return d ? d.label : qsTr("跟随系统默认") }
                options: graphicenhancement.audioDevices
                onPicked: id => graphicenhancement.setPreference("audioDevice", id)
            }
        }
        VRow {
            label: qsTr("立体声下混")
            hint: qsTr("多声道片源混成双声道再输出（耳机）；关闭时按设备声道布局映射")
            VSwitch {
                objectName: "audio-stereo"
                checked: graphicenhancement.preferences.audioForceStereo === true
                onToggled: checked => graphicenhancement.setPreference("audioForceStereo", checked)
            }
        }
    }
    // The list is read when the dialog opens: devices come and go.
    Connections {
        target: dialogHost
        function onDialogChanged() { if (dialogHost.dialog === "audio") graphicenhancement.refreshAudioDevices() }
    }
}
