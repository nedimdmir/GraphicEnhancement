import QtQuick
Item {
    id: test
    property string media: ""
    property int ticks: 0
    Timer {
        interval: 100; repeat: true; running: true
        onTriggered: {
            ++test.ticks
            if (test.ticks===40) graphicenhancement.togglePlayPause()
            if (test.ticks===60) graphicenhancement.seekTo(2)
            if (test.ticks===80) graphicenhancement.togglePlayPause()
            if (test.ticks===110) graphicenhancement.openPath(test.media)
            if (test.ticks===150) { console.log("ROTATION_BASELINE_DONE"); Qt.quit() }
        }
    }
}
