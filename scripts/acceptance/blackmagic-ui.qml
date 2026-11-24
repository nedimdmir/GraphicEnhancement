import QtQuick
Item {
    id: test
    property var dialogHost: null
    property var appWindow: Window.window
    property string evidence: ""
    property string phase: "capture"
    property string rememberedKey: ""
    property int step: 0
    property int ticks: 0
    property int began: 0
    property bool grabbed: false
    property string selected: ""
    function require(ok,why) { if(!ok) throw new Error(why) }
    function find(item,name) {
        if(item.objectName===name)return item
        for(const child of item.children||[]){const hit=find(child,name);if(hit)return hit}
        return null
    }
    function grab(name) {
        grabbed=false
        appWindow.contentItem.grabToImage(result=>{
            if(!result.saveToFile(test.evidence+"/"+name+".png"))console.log("BLACKMAGIC_UI_FAIL screenshot save")
            test.grabbed=true
        })
    }
    Timer {
        interval:250;running:true;repeat:true
        onTriggered: { try {
            ++test.ticks
            test.require(test.ticks<400,"100s deadline step="+test.step)
            test.require(!graphicenhancement.failed,"source failed: "+graphicenhancement.statusText)
            if(test.step===0) {
                if(test.ticks<8)return
                test.require(test.dialogHost!==null,"production DialogHost missing")
                graphicenhancement.nrEnabled=false;graphicenhancement.srEnabled=false;graphicenhancement.fgEnabled=false;graphicenhancement.muted=true
                test.dialogHost.open("capture");test.step=1
            } else if(test.step===1) {
                if(graphicenhancement.captureQueryBusy||!graphicenhancement.captureFormats.length)return
                const device=graphicenhancement.captureDevices.find(x=>x.label==="KUHAIMI 27P")
                test.require(device!==undefined,"explicit local USB fixture unavailable")
                if(graphicenhancement.captureDeviceId!==device.id){graphicenhancement.captureDeviceId=device.id;return}
                test.require(!graphicenhancement.captureBlackmagicDevice,"ordinary USB card misidentified as Blackmagic")
                const props=test.find(test.appWindow.contentItem,"capture-driver-properties")
                const input=test.find(test.appWindow.contentItem,"capture-driver-input")
                test.require(props!==null&&props.enabled,"driver properties unavailable while idle")
                test.require(input!==null&&!input.visible,"Blackmagic-only input control shown on ordinary USB")
                if(test.phase==="properties") {
                    // This fixture has no input crossbar/property page. Exercise
                    // real COM graph creation without displaying a modal window.
                    const before=graphicenhancement.captureFormatKey
                    test.require(!graphicenhancement.openCaptureDriverSettings(true),"ordinary USB unexpectedly exposed an input crossbar")
                    test.require(!graphicenhancement.captureQueryBusy&&props.enabled&&graphicenhancement.captureFormatKey===before,"failed property page left query busy or changed format")
                    console.log("BLACKMAGIC_UI_PROPERTIES_PASS",graphicenhancement.captureStatus)
                    Qt.quit();return
                }
                if(test.phase==="restore") {
                    test.require(graphicenhancement.captureFormatKey===test.rememberedKey,"legacy VideoInfo2 format did not migrate: "+graphicenhancement.captureFormatKey)
                    console.log("BLACKMAGIC_UI_RESTORE_PASS",graphicenhancement.captureFormatKey)
                    Qt.quit();return
                }
                const format=graphicenhancement.captureFormats.find(x=>x.id.includes(":scan=")&&x.label.startsWith("1920 x 1080 @ 60.00")&&x.label.includes("YUY2"))
                test.require(format!==undefined,"explicit 1080p60 YUY2 VideoInfo2 unavailable")
                graphicenhancement.captureFormatKey=format.id;test.selected=format.id
                graphicenhancement.captureAudioChoice=-1;graphicenhancement.captureRequestedFps=0
                test.grab("capture-idle");test.step=2
            } else if(test.step===2) {
                if(!test.grabbed||graphicenhancement.applying)return
                test.require(graphicenhancement.startCaptureSession(),"GUI source connect rejected")
                // Opening must not create a competing driver filter either.
                test.require(!graphicenhancement.openCaptureDriverSettings(false),"driver settings opened during source opening")
                test.step=3
            } else if(test.step===3) {
                if(!graphicenhancement.running||graphicenhancement.captureFps<20)return
                test.require(graphicenhancement.captureSignalLevel==="ok"&&graphicenhancement.captureSignalText==="正在收帧","callback status makes incorrect signal claim")
                test.require(!test.find(test.appWindow.contentItem,"capture-driver-properties").enabled,"driver properties enabled during capture")
                test.require(!graphicenhancement.openCaptureDriverSettings(false),"driver settings opened during live capture")
                test.require(!graphicenhancement.nrEnabled&&!graphicenhancement.srEnabled&&!graphicenhancement.fgEnabled,"basic capture silently enabled enhancement")
                test.began=test.ticks;test.step=4
            } else if(test.step===4) {
                if(test.ticks-test.began<24)return
                test.require(graphicenhancement.captureFps>50&&graphicenhancement.captureFps<70,"local 60fps capture callback out of range: "+graphicenhancement.captureFps)
                console.log("BLACKMAGIC_UI_LIVE",graphicenhancement.captureFps,graphicenhancement.sourceSummary,test.selected)
                test.grab("capture-live")
                graphicenhancement.takeScreenshot();test.step=5
            } else if(test.step===5) {
                if(!test.grabbed||!graphicenhancement.lastScreenshot.length)return
                test.find(test.appWindow.contentItem,"capture-dialog").actionTriggered("断开")
                test.step=6
            } else if(test.step===6) {
                if(graphicenhancement.running||graphicenhancement.captureSignalLevel!=="idle")return
                test.require(test.find(test.appWindow.contentItem,"capture-driver-properties").enabled,"driver properties did not recover after disconnect")
                test.require(graphicenhancement.captureFormatKey===test.selected,"disconnect lost selected format")
                console.log("BLACKMAGIC_UI_PASS",test.selected,graphicenhancement.lastScreenshot)
                Qt.quit()
            }
        } catch(e) {console.log("BLACKMAGIC_UI_FAIL",String(e));Qt.quit()} }
    }
}
