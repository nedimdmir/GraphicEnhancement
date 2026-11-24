// capture dialog: source/settings logic is owned by this component.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

DialogLayer {
    required property var legacyPicker
    signal guideRequested()
    id: captureDialog
    property bool onboardingActive: false
    instantTransition: onboardingActive
    objectName: "capture-dialog"
    key: "capture"
    glyph: "video"
    title: qsTr("采集卡")
    sub: qsTr("连接设备后，先关闭增强确认基础画面，再按需开启")
    dialogWidth: 660
    foot: qsTr("关闭其他占用同一采集卡的软件")
    actions: [
        { label: captureDialog.live ? qsTr("断开") : qsTr("取消") },
        { label: qsTr("连接并开始"), primary: true, icon: "play" }
    ]
    onActionTriggered: label => {
        if (onboardingActive) return
        if (label === qsTr("断开")) { graphicenhancement.stopPlayback(); return }
        if (label !== qsTr("连接并开始")) { dialogHost.close(); return }
        if (graphicenhancement.startCaptureSession()) dialogHost.close()
    }
    Connections {
        target: dialogHost
        function onDialogChanged() {
            if (dialogHost.dialog !== "capture" || captureDialog.onboardingActive) return
            graphicenhancement.refreshCaptureDevices()
            // The PS5 手柄控制 host list is the PS5 dialog's saved pairings.
            if (graphicenhancement.ps5Control.available === true) graphicenhancement.ps5Load()
        }
    }
    function onboardingTarget(key) {
        const rows = {
            "device": videoDeviceRow,
            "resolution": resolutionRow,
            "capture-rate": captureRateRow,
            "format": pixelFormatRow,
            "input-color": inputColorRow
        }
        return key === "connect" ? { item: primaryAction }
                                 : { item: rows[key], viewport: bodyViewport }
    }
    function labelOf(list, id, fallback) { const f = list.find(x => String(x.id) === String(id)); return f ? f.label : fallback }
    readonly property bool live: graphicenhancement.captureSignalLevel !== "idle"
    readonly property var pc: graphicenhancement.ps5Control
    readonly property bool pcOn: pc.available === true && pc.enabled === true
    readonly property string pcTag: {
        switch (pc.state) {
        case "starting": return qsTr("连接中")
        case "connected": return qsTr("已连接")
        case "recovering": return qsTr("重连中")
        case "pin": return qsTr("需要 PIN")
        case "failed": return qsTr("已停止")
        case "nopair": return qsTr("未配对")
        default: return qsTr("未连接")
        }
    }
    readonly property string pcStatus: {
        switch (pc.state) {
        case "starting": return qsTr("正在连接 PS5…")
        case "connected": return pc.keepaliveFps >= 0 ? qsTr("PS5 手柄控制已连接 · 保活画面 %1 fps（收到即丢弃）").arg(pc.keepaliveFps) : qsTr("PS5 手柄控制已连接")
        case "pin": return qsTr("PS5 要求输入登录 PIN")
        case "recovering": case "failed": case "nopair": return pc.message || ""
        default: return qsTr("采集卡连上后自动连接 PS5")
        }
    }

    VButton {
        objectName: "capture-guide-open"
        Layout.alignment: Qt.AlignLeft
        Layout.bottomMargin: 4
        text: qsTr("如何选择采集格式？")
        onClicked: captureDialog.guideRequested()
    }

    // dialogs.js .cap-prev: the picture and a signal line under it. The
    // picture is the session's own poster still when the engine made one;
    // there is no periodic frame grab here, because that would sit on the
    // live capture path. The status line is live.
    Rectangle {
        objectName: "capture-preview"
        Layout.fillWidth: true
        Layout.topMargin: 4
        implicitHeight: 180 + 34
        radius: 10
        color: Theme.videoBlack
        border.width: 1
        border.color: Theme.stroke
        clip: true
        Image {
            id: capturePoster
            objectName: "capture-preview-image"
            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
            anchors.margins: 1
            height: 180
            fillMode: Image.PreserveAspectCrop
            source: captureDialog.live ? graphicenhancement.capturePreviewUrl : ""
            visible: status === Image.Ready
        }
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 90 - height / 2
            spacing: 8
            visible: !capturePoster.visible
            VIcon { anchors.horizontalCenter: parent.horizontalCenter; name: "video"; size: 22; color: Theme.t3 }
            Text {
                text: captureDialog.live ? qsTr("画面在主窗口播放") : qsTr("连接后在主窗口显示画面")
                color: Theme.t3
                font.family: Theme.fontUi
                font.pixelSize: 12
            }
        }
        RowLayout {
            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
            height: 34
            anchors.leftMargin: 10; anchors.rightMargin: 10
            spacing: 8
            VTag {
                objectName: "capture-signal"
                text: graphicenhancement.captureSignalText
                kind: graphicenhancement.captureSignalLevel === "ok" ? "ok" : graphicenhancement.captureSignalLevel === "warn" ? "warn" : ""
            }
            Text {
                Layout.fillWidth: true
                text: captureDialog.live
                      ? graphicenhancement.sourceSummary.replace("x", "×") + " · " + graphicenhancement.captureFps.toFixed(2) + " fps"
                        + (graphicenhancement.sourceFormatText.split(" · ").length > 2 ? " · " + graphicenhancement.sourceFormatText.split(" · ")[1] : "")
                      : (graphicenhancement.captureFormatLabel.length ? graphicenhancement.captureFormatLabel : qsTr("选择设备和格式后连接"))
                color: Theme.t2
                font.family: Theme.fontMono
                font.pixelSize: 11
                elide: Text.ElideRight
            }
        }
    }

    DialogSection { text: qsTr("设备") }
    DialogGroup {
        VRow {
            id: videoDeviceRow
            label: qsTr("视频输入设备")
            hint: graphicenhancement.captureQueryBusy ? qsTr("正在查询…当前播放继续") : (graphicenhancement.captureDevices.length === 0 ? qsTr("未检测到采集设备") : "")
            RowLayout {
                spacing: 6
                VSelect {
                    objectName: "capture-device"
                    implicitWidth: 220
                    value: graphicenhancement.captureDeviceLabel
                    options: graphicenhancement.captureDevices
                    onPicked: id => graphicenhancement.captureDeviceId = id
                }
                // M38: the refresh icon becomes a spinner while the query runs.
                Item {
                    implicitWidth: Theme.ctlHeight; implicitHeight: Theme.ctlHeight
                    VButton {
                        objectName: "capture-refresh"
                        anchors.fill: parent
                        visible: !graphicenhancement.captureQueryBusy
                        icon: true; ghost: true; iconName: "refresh"; tip: qsTr("刷新设备")
                        onClicked: graphicenhancement.refreshCaptureDevices()
                    }
                    VSpinner { anchors.centerIn: parent; visible: graphicenhancement.captureQueryBusy }
                }
            }
        }
        VRow {
            objectName: "capture-legacy-entry"
            label: qsTr("旧版格式选择")
            hint: qsTr("直接查看完整格式列表，包含被常用帧率筛选隐藏的模式")
            VButton {
                objectName: "capture-legacy-open"
                text: qsTr("打开旧版格式列表")
                enabled: !graphicenhancement.captureQueryBusy && graphicenhancement.captureDeviceId.length > 0
                onClicked: legacyPicker.open()
            }
        }
        VRow {
            id: resolutionRow
            label: qsTr("分辨率")
            hint: qsTr("先选择分辨率，再选择该分辨率支持的帧率和像素格式")
            VSelect {
                objectName: "capture-resolution"
                enabled: !graphicenhancement.captureQueryBusy
                opacity: enabled ? 1 : 0.5
                implicitWidth: 180
                value: captureDialog.labelOf(graphicenhancement.captureResolutionOptions, graphicenhancement.captureResolutionId, graphicenhancement.captureResolutionOptions.length ? qsTr("请选择分辨率") : "—")
                options: graphicenhancement.captureResolutionOptions
                onPicked: id => graphicenhancement.captureResolutionId = id
            }
        }
        VRow {
            label: qsTr("自定义分辨率")
            hint: qsTr("仅接受驱动尺寸范围与步进支持的值；连接时核对实际格式")
            RowLayout {
                spacing: 6
                enabled: !graphicenhancement.captureQueryBusy && graphicenhancement.captureDeviceId.length > 0
                DialogTextField { id: customCaptureResolution; objectName: "capture-custom-resolution"; implicitWidth: 140; text: "1920x1080" }
                VButton { text: qsTr("检查并选择"); onClicked: graphicenhancement.captureResolutionId = customCaptureResolution.text }
            }
        }
        VRow {
            id: captureRateRow
            label: qsTr("帧率")
            hint: qsTr("列出离散帧率及驱动范围内的候选；设备帧率填 0 时沿用此选择，连接时验证实际值")
            VSelect {
                objectName: "capture-frame-rate"
                enabled: !graphicenhancement.captureQueryBusy && graphicenhancement.captureResolutionId.length > 0
                opacity: enabled ? 1 : 0.5
                implicitWidth: 280
                value: captureDialog.labelOf(graphicenhancement.captureFrameRateOptions, graphicenhancement.captureFrameRateId, graphicenhancement.captureFrameRateOptions.length ? qsTr("请选择帧率") : "—")
                options: graphicenhancement.captureFrameRateOptions
                onPicked: id => graphicenhancement.captureFrameRateId = id
            }
        }
        VRow {
            // Some cards list every rate from 1 to 120 fps (logs(18)). The frame-rate menu
            // shows the common rates the card offers; this lists the rest too.
            objectName: "capture-all-rates-row"
            visible: graphicenhancement.captureHiddenFrameRates > 0
            label: qsTr("显示全部可用帧率")
            hint: qsTr("默认只列常用帧率：24、25、30、50、60、100、120、144、165、240（含 59.94 这类非整数帧率）。这张卡另外上报了 %1 个帧率").arg(graphicenhancement.captureHiddenFrameRates)
            VSwitch {
                objectName: "capture-all-rates"
                enabled: !graphicenhancement.captureQueryBusy
                opacity: enabled ? 1 : 0.35
                checked: graphicenhancement.preferences.captureShowAllFrameRates === true
                onToggled: checked => graphicenhancement.setPreference("captureShowAllFrameRates", checked)
            }
        }
        VRow {
            id: pixelFormatRow
            label: qsTr("像素格式")
            // Never search graphicenhancement.captureFormats here: a card can list 15000+ (logs(18)).
            hint: graphicenhancement.captureFormatCostHint ? qsTr("该格式比低延迟格式多一道处理环节，高分辨率/高帧率下建议优先低延迟格式") : qsTr("只列出当前分辨率和帧率下的像素格式")
            VSelect {
                objectName: "capture-format"
                enabled: !graphicenhancement.captureQueryBusy && graphicenhancement.captureResolutionId.length > 0 && graphicenhancement.captureFrameRateId.length > 0
                opacity: enabled ? 1 : 0.5
                implicitWidth: 220
                value: captureDialog.labelOf(graphicenhancement.capturePixelOptions, graphicenhancement.capturePixelId, graphicenhancement.captureResolutionId.length ? qsTr("请选择像素格式") : qsTr("请先选择分辨率"))
                options: graphicenhancement.capturePixelOptions
                onPicked: id => graphicenhancement.capturePixelId = id
            }
        }
        VRow {
            objectName: "capture-driver-settings-row"
            visible: graphicenhancement.captureDeviceId.length > 0
            label: qsTr("驱动设置")
            hint: captureDialog.live ? qsTr("先断开采集，再配置驱动")
                  : graphicenhancement.captureBlackmagicDevice
                    ? (graphicenhancement.preferences.blackmagicNativeCapture === true
                       ? qsTr("请在设备列表选择对应的 HDMI/SDI 输入口；Driver 保留驱动当前输入。支持自动检测的卡建议选择自动，信号未锁定时会明确提示。")
                       : qsTr("Blackmagic 两个条目可能属于同一张卡。DirectShow 黑屏可尝试下方原生采集开关；手动格式须匹配实际信号。"))
                    : qsTr("配置驱动公开的输入与视频属性；其他采集应用占用设备时请先关闭")
            RowLayout {
                spacing: 6
                VButton {
                    objectName: "capture-driver-properties"
                    text: qsTr("设备属性"); ghost: true
                    enabled: !graphicenhancement.captureQueryBusy && !captureDialog.live && !graphicenhancement.liveOpeningText.length
                    onClicked: graphicenhancement.openCaptureDriverSettings(false)
                }
                VButton {
                    objectName: "capture-driver-input"
                    visible: graphicenhancement.captureBlackmagicDevice
                    text: qsTr("输入选择"); ghost: true
                    enabled: !graphicenhancement.captureQueryBusy && !captureDialog.live && !graphicenhancement.liveOpeningText.length
                    onClicked: graphicenhancement.openCaptureDriverSettings(true)
                }
            }
        }
        VRow {
            objectName: "capture-blackmagic-native-row"
            label: qsTr("Blackmagic 原生采集")
            hint: qsTr("默认关闭。开启使用 DeckLink 原生接口，关闭使用 DirectShow。需安装 Desktop Video 驱动；切换后重新选择设备和格式并连接，不写入驱动永久配置。")
            VSwitch {
                objectName: "capture-blackmagic-native"
                enabled: !graphicenhancement.captureQueryBusy && (graphicenhancement.captureBlackmagicDevice || graphicenhancement.preferences.blackmagicNativeCapture === true)
                opacity: enabled ? 1 : 0.35
                checked: graphicenhancement.preferences.blackmagicNativeCapture === true
                onToggled: checked => graphicenhancement.setPreference("blackmagicNativeCapture", checked)
            }
        }
        VRow {
            objectName: "capture-magewell-row"
            label: qsTr("美乐威低延迟模式")
            hint: !graphicenhancement.captureMagewellDevice
                  ? qsTr("仅美乐威 Pro Capture（PCIe 内置卡）可用；USB Capture 系列不支持")
                  : (graphicenhancement.captureMagewellStatus.length > 0 ? graphicenhancement.captureMagewellStatus + " · " : "")
                    + qsTr("画面未收齐即可开始传输。持续丢帧时按原格式切回普通采集。重新连接后生效。")
            VSwitch {
                objectName: "capture-magewell"
                enabled: graphicenhancement.captureMagewellDevice
                opacity: enabled ? 1 : 0.35
                checked: graphicenhancement.captureMagewellDevice && graphicenhancement.preferences.magewellLowLatency === true
                onToggled: checked => graphicenhancement.setPreference("magewellLowLatency", checked)
            }
        }
        VRow {
            label: qsTr("设备帧率 FPS")
            hint: qsTr("0 = 沿用所选格式；设备返回其他帧率会报错，不在软件中偷偷丢帧")
            DialogTextField {
                objectName: "capture-fps"
                implicitWidth: 100
                text: String(graphicenhancement.captureRequestedFps)
                onEdited: text => graphicenhancement.captureRequestedFps = Number(text)
                // Take a valid rate as it is typed. Only a canonical number ("59.94", not
                // "59.") so the field's binding never rewrites what is still being typed.
                onTyped: text => {
                    const n = Number(text.trim())
                    if (text.trim().length > 0 && String(n) === text.trim() && (n === 0 || (n >= 1 && n <= 1000)))
                        graphicenhancement.captureRequestedFps = n
                }
            }
        }
    }
    DialogSection { text: qsTr("音频") }
    DialogGroup {
        VRow {
            label: qsTr("音频输入")
            hint: qsTr("录制采集卡声音需选择输入；本机监听可独立关闭")
            VSelect {
                objectName: "capture-audio"
                implicitWidth: 260
                value: captureDialog.labelOf(graphicenhancement.captureAudioInputs, graphicenhancement.captureAudioChoice, qsTr("不采集音频"))
                options: graphicenhancement.captureAudioInputs
                onPicked: id => graphicenhancement.captureAudioChoice = Number(id)
            }
        }
        VRow {
            label: qsTr("本机音频监听")
            hint: qsTr("关闭后仍可录制和保存回放；本机不播放采集声音")
            VSwitch {
                objectName: "capture-audio-monitor"
                checked: graphicenhancement.preferences.captureAudioMonitor !== false
                onToggled: v => graphicenhancement.setPreference("captureAudioMonitor", v)
            }
        }
        VRow {
            label: qsTr("GraphicEnhancement 虚拟扬声器")
            hint: graphicenhancement.captureVirtualAudioBusy ? qsTr("正在处理 VB-CABLE 安装器…")
                : graphicenhancement.captureVirtualAudioInstalled ? qsTr("已检测到 VB-CABLE · 用于转接 Windows 侦听")
                : qsTr("可选 · 采集卡直采无声时使用")
            RowLayout {
                spacing: 6
                VButton {
                    objectName: "capture-virtual-audio-setup"
                    text: graphicenhancement.captureVirtualAudioInstalled ? qsTr("已安装") : qsTr("安装…")
                    ghost: true
                    enabled: !graphicenhancement.captureVirtualAudioBusy && !graphicenhancement.captureVirtualAudioInstalled
                    onClicked: virtualAudioGuide.showFor(1)
                }
                VButton {
                    objectName: "capture-virtual-audio-instructions"
                    text: qsTr("使用说明")
                    ghost: true
                    enabled: !graphicenhancement.captureVirtualAudioBusy
                    onClicked: virtualAudioGuide.showFor(0)
                }
                VButton {
                    objectName: "capture-virtual-audio-remove"
                    visible: graphicenhancement.captureVirtualAudioInstalled
                    text: qsTr("卸载…")
                    ghost: true
                    enabled: !graphicenhancement.captureVirtualAudioBusy
                    onClicked: virtualAudioGuide.showFor(2)
                }
            }
        }
        VRow {
            label: qsTr("Dolby / DTS 位流")
            VSeg {
                objectName: "capture-audio-ingress"
                options: [{ id: "0", label: qsTr("自动") }, { id: "1", label: qsTr("强制 PCM") }, { id: "2", label: qsTr("位流优先") }]
                current: String(graphicenhancement.captureAudioIngress)
                onPicked: id => graphicenhancement.captureAudioIngress = Number(id)
            }
        }
    }
    VConfirm {
        id: virtualAudioGuide
        parent: captureDialog.dialogHost
        objectName: "capture-virtual-audio-confirm"
        cardWidth: 510
        property int operation: 0
        property bool disconnectRequested: false
        readonly property bool removalBlocked: shown && operation === 2 && graphicenhancement.captureVirtualAudioRemovalBlocked
        function showFor(value) {
            operation = value
            disconnectRequested = false
            open()
        }
        title: operation === 2 ? qsTr("卸载 GraphicEnhancement 虚拟扬声器")
            : operation === 1 ? qsTr("安装 GraphicEnhancement 虚拟扬声器") : qsTr("GraphicEnhancement 虚拟扬声器使用说明")
        text: operation === 2
            ? qsTr("先在 Windows 中关闭采集卡的“侦听此设备”，或把目标改回原设备。确认后打开 VB-Audio 安装器，选择 Remove Driver 并按提示重启。其他使用 VB-CABLE 的软件也会失去这条音频通路。")
            : qsTr("此功能使用 VB-Audio 的 VB-CABLE（捐赠软件），可从内置安装包离线安装。首次安装需管理员确认，完成后按提示重启。\n\n1. 在 Windows“录制”里打开采集卡音频的属性，勾选“侦听此设备”，播放目标选 CABLE Input。如果已改名，请选择改后的名称。")
        acceptText: operation === 2 ? qsTr("确认卸载") : operation === 1 ? qsTr("确认安装") : qsTr("完成")
        acceptEnabled: !graphicenhancement.captureVirtualAudioBusy && !removalBlocked
        onAccepted: { if (operation !== 0) graphicenhancement.setupCaptureVirtualAudio(operation === 2) }
        Connections {
            target: captureDialog.dialogHost
            function onDialogChanged() { if (!captureDialog.shown) virtualAudioGuide.close() }
        }
        RowLayout {
            Layout.fillWidth: true
            VButton {
                objectName: "capture-virtual-audio-windows-listen"
                text: qsTr("打开 Windows 录制设置")
                ghost: true
                onClicked: graphicenhancement.openCaptureWindowsListen()
            }
            VButton {
                text: qsTr("VB-Audio 官网")
                ghost: true
                onClicked: graphicenhancement.openCaptureVirtualAudioVendor()
            }
        }
        RowLayout {
            visible: virtualAudioGuide.removalBlocked
            Layout.fillWidth: true
            Text {
                Layout.fillWidth: true
                text: qsTr("请先断开采集并等待连接结束")
                color: Theme.t2
                font.family: Theme.fontUi
                font.pixelSize: Theme.fsBody
                wrapMode: Text.WordWrap
            }
            VButton {
                objectName: "capture-virtual-audio-disconnect"
                visible: captureDialog.live
                text: qsTr("断开采集")
                ghost: true
                enabled: !virtualAudioGuide.disconnectRequested
                onClicked: {
                    virtualAudioGuide.disconnectRequested = true
                    graphicenhancement.stopPlayback()
                }
            }
        }
        Text {
            objectName: "capture-virtual-audio-follow-up"
            visible: virtualAudioGuide.operation !== 2
            Layout.fillWidth: true
            text: qsTr("2. 回到 GraphicEnhancement，在“音频输入”选“GraphicEnhancement 虚拟扬声器”，再连接采集。音频输出选真实耳机或音箱，即可使用音画同步。\n\n可选改名：在 Windows 声音的“播放”页打开 CABLE Input 的属性，在“常规”里改成“GraphicEnhancement 采集音频”。")
            color: Theme.t2
            font.family: Theme.fontUi
            font.pixelSize: Theme.fsBody
            wrapMode: Text.WordWrap
            lineHeight: 1.3
        }
    }
    // PS5 手柄控制: the capture card stays the picture and the sound; PS5 Remote
    // Play only carries the pad (also from a handheld this picture is re-streamed to).
    DialogSection { visible: captureDialog.pc.available === true; text: qsTr("PS5 手柄控制") }
    DialogGroup {
        visible: captureDialog.pc.available === true
        VRow {
            label: qsTr("用远程游玩控制 PS5")
            hint: qsTr("画面和声音来自采集卡，手柄经 PS5 远程游玩发给主机。把处理后的画面再串流给掌机或别的电脑时，用那边的手柄玩 PS5")
            VSwitch {
                objectName: "capture-ps5-control"
                checked: captureDialog.pcOn
                onToggled: checked => graphicenhancement.ps5ControlSet("enabled", checked)
            }
        }
        VRow {
            visible: captureDialog.pcOn
            label: qsTr("PS5 主机")
            hint: graphicenhancement.ps5Profiles.length === 0 ? qsTr("还没有配对的 PS5，先在「PS5 串流」里配对一次") : qsTr("和「PS5 串流」共用配对")
            RowLayout {
                spacing: 6
                VSelect {
                    objectName: "capture-ps5-host"
                    visible: graphicenhancement.ps5Profiles.length > 0
                    implicitWidth: 170
                    value: { const p = graphicenhancement.ps5Profiles.find(x => x.id === graphicenhancement.ps5.profile); return p ? p.label : qsTr("请选择") }
                    options: graphicenhancement.ps5Profiles
                    onPicked: id => graphicenhancement.ps5SelectProfile(id)
                }
                VTag {
                    objectName: "capture-ps5-state"
                    Layout.alignment: Qt.AlignVCenter
                    text: captureDialog.pcTag
                    kind: captureDialog.pc.state === "connected" ? "ok"
                        : captureDialog.pc.state === "failed" || captureDialog.pc.state === "nopair" || captureDialog.pc.state === "pin" ? "warn" : ""
                }
                VButton {
                    objectName: "capture-ps5-restart"
                    visible: captureDialog.pc.state === "failed"
                    text: qsTr("重连"); ghost: true
                    onClicked: graphicenhancement.ps5ControlRestart()
                }
                VButton {
                    objectName: "capture-ps5-pair"
                    text: graphicenhancement.ps5Profiles.length === 0 ? qsTr("去配对") : qsTr("配对…")
                    ghost: true
                    onClicked: dialogHost.open("ps5")
                }
            }
        }
        VRow {
            visible: captureDialog.pcOn && captureDialog.pc.state === "pin"
            label: qsTr("登录 PIN")
            hint: qsTr("PS5 提示时填写，不是 8 位配对码")
            RowLayout {
                spacing: 6
                DialogTextField { id: controlPin; objectName: "capture-ps5-pin"; implicitWidth: 120 }
                VButton { text: qsTr("提交"); ghost: true; onClicked: { graphicenhancement.ps5SendLoginPin(controlPin.text); controlPin.text = "" } }
            }
        }
        VRow {
            visible: captureDialog.pcOn
            label: qsTr("后台也转发手柄")
            hint: qsTr("再串流时建议打开：GraphicEnhancement 不在前台也继续转发。打开后在这台电脑上用别的程序时，手柄也会操作 PS5")
            VSwitch {
                objectName: "capture-ps5-background"
                checked: captureDialog.pc.background === true
                onToggled: checked => graphicenhancement.ps5ControlSet("background", checked)
            }
        }
        VRow {
            visible: captureDialog.pcOn
            label: qsTr("手柄")
            hint: qsTr("谁按键就用谁：本机手柄、串流软件建的虚拟手柄都可以")
            Text {
                objectName: "capture-ps5-pad"
                text: (captureDialog.pc.pad || "").length > 0
                      ? captureDialog.pc.pad + " · " + (captureDialog.pc.gyro === true ? qsTr("有陀螺仪") : qsTr("无陀螺仪"))
                      : captureDialog.pc.state === "off" || captureDialog.pc.state === "nopair" ? "—" : qsTr("未检测到手柄")
                color: Theme.t1
                font.family: Theme.fontUi
                font.pixelSize: Theme.fsSmall
                elide: Text.ElideRight
                width: Math.min(implicitWidth, 260)
            }
        }
    }
    DialogNote {
        objectName: "capture-ps5-note"
        visible: captureDialog.pcOn
        text: (captureDialog.pcStatus.length > 0 ? captureDialog.pcStatus + "\n" : "")
              + qsTr("PS5 仍会发一路 720p 30fps、约 5 Mbps 的保活画面，本机收到即丢弃；PS5 同一时间只允许一个远程游玩连接。再串流时记得选择上面的「音频输入」。")
    }
    DialogSection { text: qsTr("格式与画面") }
    DialogGroup {
        VRow {
            id: inputColorRow
            visible: graphicenhancement.captureMjpegSelected !== true
            label: qsTr("输入色彩（SDR / HDR）")
            hint: qsTr("不确定就选「自动」。采集 HDR：采集格式选 P010，这里选「HDR · PQ」（游戏机、显卡的 HDR10 都是 PQ）。「HDR · HLG」用于广播信号。「SDR · 709」是普通画面。变更需重连")
            VSeg {
                objectName: "capture-color-space"
                options: [{ id: "0", label: qsTr("自动") }, { id: "1", label: "HDR · PQ" }, { id: "2", label: "HDR · HLG" }, { id: "3", label: "SDR · 709" }]
                current: String(graphicenhancement.captureColorSpace)
                onPicked: id => graphicenhancement.captureColorSpace = Number(id)
            }
        }
        DialogNote {
            visible: graphicenhancement.captureMjpegSelected === true
            text: qsTr("MJPEG 采集的输入色彩跟随码流，可在下方单独调整色彩范围。")
        }
        VRow {
            label: qsTr("输入范围")
            hint: qsTr("Limited = 16–235，Full = 0–255。画面发灰选「有限」，暗部全黑、亮部过曝选「完全」")
            VSeg {
                objectName: "capture-color-range"
                options: [{ id: "0", label: qsTr("自动") }, { id: "1", label: qsTr("有限 · Limited") }, { id: "2", label: qsTr("完全 · Full") }]
                current: String(graphicenhancement.captureColorRange)
                onPicked: id => graphicenhancement.captureColorRange = Number(id)
            }
        }
        VRow {
            label: qsTr("设备缓冲")
            hint: qsTr("自动：1080p 及以下 2 帧，更高 3 帧；最小 1 帧延迟最低但可能丢帧")
            VSeg {
                objectName: "capture-buffer-mode"
                options: [{ id: "0", label: qsTr("自动") }, { id: "1", label: qsTr("最小") }, { id: "2", label: qsTr("驱动默认") }]
                current: String(graphicenhancement.captureBufferMode)
                onPicked: id => graphicenhancement.captureBufferMode = Number(id)
            }
        }
        VRow {
            label: qsTr("转为 SDR 显示")
            hint: qsTr("收到 HDR 也按 SDR 预览，立即生效")
            VSwitch {
                objectName: "capture-force-sdr"
                checked: graphicenhancement.captureForceSdr
                onToggled: checked => graphicenhancement.captureForceSdr = checked
            }
        }
        VRow {
            label: qsTr("画面上下翻转")
            hint: qsTr("采集画面倒置时开启，立即生效")
            VSwitch {
                objectName: "capture-flip-vertical"
                checked: graphicenhancement.captureFlipVertical
                onToggled: checked => graphicenhancement.captureFlipVertical = checked
            }
        }
    }
    DialogNote { visible: graphicenhancement.captureStatus.length > 0; text: graphicenhancement.captureStatus }
}
