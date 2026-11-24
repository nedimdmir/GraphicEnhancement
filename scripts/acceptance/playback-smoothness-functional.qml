import QtQuick
import QtQuick.Controls
import GraphicEnhancement
Item {
    id: test
    property var appWindow: Window.window
    property string media: ""
    property string mode: ""
    property int phase: 0
    property int waited: 0
    property int rateIndex: 0
    property var rates: [1.3,1.8,.25,4,1]
    property double started: 0
    property double position: 0
    property bool subtitleSeen: false
    property var barWindow: null
    property var actualRateMenu: null
    property var actualRateDialog: null
    function require(ok,message) {
        if(ok)return
        console.error("PLAYBACK_FUNCTION_FAIL",phase,message,graphicenhancement.statusText)
        timer.stop(); Qt.quit(); throw new Error(message)
    }
    function find(item,name,depth) {
        if(!item)return null
        depth=depth || 0
        if(depth>20)return null
        if(item.objectName===name)return item
        const children=item.data || item.contentData || item.children || []
        for(let k=0;k<children.length;++k){const found=find(children[k],name,depth+1);if(found)return found}
        if(item.contentItem)return find(item.contentItem,name,depth+1)
        return null
    }
    PlaybackRateDialog { id: rateDialog; objectName: "acceptance-rate" }
    Connections {
        target: graphicenhancement
        function onSubtitleTextChanged() { console.log("PLAYBACK_SUBTITLE",JSON.stringify(graphicenhancement.subtitleText)) }
        function onNotice(text,error) { console.log("PLAYBACK_FUNCTION_NOTICE",text,error) }
    }
    Timer {
        id: timer
        interval: 200; running: true; repeat: true
        onTriggered: {
            ++test.waited
            if(test.waited>600){test.require(false,"120-second deadline");return}
            if(!test.media.length)return
            test.require(!graphicenhancement.failed,"source failed")
            if(test.phase===0){
                graphicenhancement.nrEnabled=false;graphicenhancement.srEnabled=false;graphicenhancement.fgEnabled=false
                graphicenhancement.openPath(test.media);test.phase=1;return
            }
            if(test.phase===1){
                if(!graphicenhancement.running||graphicenhancement.position<.3||graphicenhancement.applying)return
                test.require(graphicenhancement.effectCapabilities.nr4.available===false,"NVIDIA must keep AMD NR unavailable")
                test.require(graphicenhancement.effectCapabilities.fsr4.available===false,"NVIDIA must keep FSR4 FG unavailable")
                test.phase=2;return
            }
            if(test.phase===2){
                if(!graphicenhancement.subtitleText.includes("It is over, Sauron."))return
                test.subtitleSeen=true;graphicenhancement.togglePlayPause();graphicenhancement.seekTo(9.5);test.phase=3;return
            }
            if(test.phase===3){
                if(Math.abs(graphicenhancement.position-9.5)>.2||!graphicenhancement.paused)return
                if(graphicenhancement.subtitleText!=="I am Zaladane,\nHigh Priestess of\nthe Sun God, Garokk.")return
                console.log("PLAYBACK_SUBTITLE_THREE_LINES_PASS",JSON.stringify(graphicenhancement.subtitleText))
                test.started=Date.now();test.phase=4;return
            }
            if(test.phase===4){
                // Leave the true native overlay visible long enough to inspect.
                if(Date.now()-test.started<4500)return
                graphicenhancement.seekTo(0);graphicenhancement.togglePlayPause();test.phase=5;return
            }
            if(test.phase===5){
                if(graphicenhancement.paused||graphicenhancement.applying||graphicenhancement.position>1.0)return
                rateDialog.open();const input=test.find(rateDialog.contentItem,"acceptance-rate-input")
                test.require(!!input,"custom dialog field missing")
                input.text=String(test.rates[test.rateIndex]);rateDialog.applyRate()
                test.require(Math.abs(graphicenhancement.playbackRate-test.rates[test.rateIndex])<.000001,"rate was refused")
                test.phase=6;test.started=Date.now();return
            }
            if(test.phase===6){
                if(Date.now()-test.started<1200)return
                test.position=graphicenhancement.position;test.started=Date.now();test.phase=7;return
            }
            if(test.phase===7){
                if(Date.now()-test.started<1800)return
                const measured=(graphicenhancement.position-test.position)/((Date.now()-test.started)/1000)
                test.require(Math.abs(measured-test.rates[test.rateIndex])<Math.max(.18,test.rates[test.rateIndex]*.18),"media PTS speed mismatch")
                console.log("PLAYBACK_RATE_REAL_PASS",test.rates[test.rateIndex],measured,test.appWindow.page)
                ++test.rateIndex
                if(test.rateIndex<test.rates.length){graphicenhancement.seekTo(0);test.phase=5;return}
                const before=graphicenhancement.playbackRate
                rateDialog.open();const input=test.find(rateDialog.contentItem,"acceptance-rate-input")
                input.text="4.01";rateDialog.applyRate()
                test.require(rateDialog.opened&&graphicenhancement.playbackRate===before&&rateDialog.errorText.length>0,"invalid value must keep dialog and actual speed")
                rateDialog.close();rateDialog.open();input.text="1.8";rateDialog.close()
                test.require(graphicenhancement.playbackRate===before,"cancel changed actual speed")
                graphicenhancement.playbackRate=NaN;test.require(graphicenhancement.playbackRate===before,"NaN accepted")
                test.appWindow.page="min";test.appWindow.toggleFullscreen();test.phase=8;return
            }
            if(test.phase===8){
                if(!test.appWindow.fullscreen)return
                rateDialog.open();const input=test.find(rateDialog.contentItem,"acceptance-rate-input")
                input.text="1.8";rateDialog.applyRate()
                test.require(graphicenhancement.playbackRate===1.8,"fullscreen custom rate refused")
                test.appWindow.toggleFullscreen();test.phase=9;test.started=Date.now();return
            }
            if(test.phase===9){
                if(test.appWindow.fullscreen||Date.now()-test.started<1000)return
                test.barWindow=test.find(test.appWindow,"fullscreenBar")
                test.require(!!test.barWindow,"actual floating cinema window missing")
                const button=test.find(test.barWindow,"cine-playback-rate")
                test.require(!!button,"actual cinema rate button missing")
                test.actualRateMenu=test.find(button,"cine-playback-rate-menu")
                test.actualRateDialog=test.find(button,"cine-playback-rate-custom")
                test.require(!!test.actualRateMenu&&!!test.actualRateDialog,"actual cinema popups missing")
                test.actualRateMenu.openAt(button,"up");test.phase=10;test.started=Date.now();return
            }
            if(test.phase===10){
                if(Date.now()-test.started<800)return
                test.require(test.barWindow.menuOpen,"rate menu omitted from floating-window mask")
                test.require(test.barWindow.hitRect.height===test.barWindow.height,"menu mask cuts off speed options")
                test.require(test.actualRateMenu.y+test.actualRateMenu.height<=test.barWindow.menuRoom-15,"rate menu overlaps playback pill")
                console.log("PLAYBACK_CINEMA_MENU_MASK_PASS",test.barWindow.hitRect.height,test.actualRateMenu.y,test.actualRateMenu.height)
                test.actualRateMenu.close();test.actualRateDialog.open();test.phase=11;test.started=Date.now();return
            }
            if(test.phase===11){
                if(Date.now()-test.started<800)return
                const popupWindow=test.actualRateDialog.contentItem.Window.window
                const field=test.find(test.actualRateDialog.contentItem,"cine-playback-rate-custom-input")
                test.require(popupWindow!==test.barWindow && !(popupWindow.flags & Qt.WindowDoesNotAcceptFocus),"floating custom entry cannot accept keyboard focus")
                test.require(field.activeFocus,"custom input has no active focus")
                field.text="1.3";test.actualRateDialog.applyRate()
                test.require(graphicenhancement.playbackRate===1.3,"actual cinema control did not apply custom rate")
                console.log("PLAYBACK_CINEMA_MASK_FOCUS_PASS",test.barWindow.hitRect.height,test.actualRateMenu.y,test.actualRateMenu.height)
                console.log("PLAYBACK_FUNCTION_PASS",test.rates.length,"comma+threeLines+invalid+cancel+fullscreen+vendor-gray")
                Qt.quit()
            }
        }
    }
}
