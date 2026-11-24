// Loaded only into a task-owned staging copy of Main.qml by the test runner.
// Drives the production bridge/model/worker; never changes installed user data.
import QtQuick
Item {
    id: test
    property string outputDirectory: ""
    property string evidenceDirectory: ""
    property var appWindow: Window.window
    property int step: 0
    property int ticks: 0
    property var ids: []
    property string media: "E:/项目/GraphicEnhancement/tests/export-page-20261002/media/"
    function find(item,name){if(item.objectName===name)return item;for(const child of item.children||[]){const hit=find(child,name);if(hit)return hit}return null}
    function require(ok,why){if(!ok){console.error("EXPORT_UI_FAIL",step,why);timer.stop();Qt.quit();throw new Error(why)}}
    function done(){console.log("EXPORT_UI_PASS: production model, per-file trim, cancel/retry, frozen batch, mixed failure, sound enabled/disabled, image batch success/failure/cancel");timer.stop();Qt.quit()}
    Timer {
        id: timer
        interval: 200; repeat: true; running: true
        onTriggered: {
            if(++test.ticks>600){test.require(false,"120-second deadline");return}
            if(!test.outputDirectory.length)return
            const model=graphicenhancement.exportQueueModel
            if(test.step===0){
                if(test.ticks<5)return
                let files=[];for(let i=0;i<20;++i)files.push(test.media+"tracks.mp4")
                graphicenhancement.addExportFiles(files)
                test.require(model.count===20&&!graphicenhancement.exportRunning,"add-only contract")
                test.require(model.moveItem(model.get(19).itemId,0),"production model move")
                test.require(model.removeItem(model.get(3).itemId),"production model remove")
                model.clearWaiting();test.require(model.count===0,"production model clear")
                graphicenhancement.addExportFiles([test.media+"tracks.mp4",test.media+"font-ass.mkv",test.media+"tracks.mkv"])
                for(let j=0;j<3;++j)test.ids.push(model.get(j).itemId)
                graphicenhancement.exportContainer=1;graphicenhancement.exportSrTargetIndex=0
                graphicenhancement.exportCompletionSound=true
                graphicenhancement.previewExportItem(test.ids[0]);test.step=1
            }else if(test.step===1){
                if(!graphicenhancement.hasSource||graphicenhancement.duration<=0)return
                graphicenhancement.exportTrimStart=0.5;graphicenhancement.exportTrimEnd=1.5
                test.require(Math.abs(graphicenhancement.exportTrimStart-0.5)<0.01,"set first trim")
                graphicenhancement.previewExportItem(test.ids[1]);test.step=2
            }else if(test.step===2){
                if(!graphicenhancement.hasSource||graphicenhancement.duration<=0)return
                test.require(graphicenhancement.exportTrimStart===0&&graphicenhancement.exportTrimEnd===0,"trim leaked to second item")
                graphicenhancement.previewExportItem(test.ids[0])
                test.require(Math.abs(graphicenhancement.exportTrimStart-0.5)<0.01&&Math.abs(graphicenhancement.exportTrimEnd-1.5)<0.01,"trim not restored")
                model.moveItem(test.ids[2],0)
                graphicenhancement.startExport();graphicenhancement.cancelExport()
                test.require(graphicenhancement.exportReadyCount===3,"cancel lost waiting files")
                test.step=3
            }else if(test.step===3){
                if(graphicenhancement.exportRunning)return
                graphicenhancement.startExport()
                test.require(graphicenhancement.exportRunning,"restart after cancel")
                graphicenhancement.addExportFiles([test.media+"tracks.mp4"])
                graphicenhancement.previewExportItem(test.ids[1]);test.step=4
            }else if(test.step===4){
                if(graphicenhancement.exportRunning)return
                test.require(graphicenhancement.exportItems.filter(i=>i.state==="done").length===3,"first batch did not finish all members")
                test.require(graphicenhancement.exportReadyCount===1,"late item joined active batch")
                test.step=7
                test.appWindow.contentItem.grabToImage(result=>{
                    result.saveToFile(test.evidenceDirectory+"/production-export.png")
                    graphicenhancement.addExportFiles([test.media+"broken.mkv"])
                    graphicenhancement.startExport();test.step=5
                })
            }else if(test.step===5){
                if(graphicenhancement.exportRunning)return
                test.require(graphicenhancement.exportQueueFailures===1,"mixed batch failure missing")
                test.require(graphicenhancement.exportItems.some(i=>i.state==="failed"&&i.note.length>0),"specific failure reason missing")
                model.clearWaiting();graphicenhancement.exportCompletionSound=false
                graphicenhancement.addExportFiles([test.media+"tracks.mp4"]);graphicenhancement.startExport();test.step=6
            }else if(test.step===6){
                if(graphicenhancement.exportRunning)return
                test.require(graphicenhancement.exportItems.every(i=>i.state==="done"),"muted batch failed")
                test.require(!graphicenhancement.exportCompletionSound,"sound preference reverted")
                graphicenhancement.exportCompletionSound=true
                test.require(graphicenhancement.startImageBatch([test.media+"frame-a.png",test.media+"frame-b.png"],test.evidenceDirectory+"/images"),"image batch start refused")
                test.step=8
            }else if(test.step===8){
                if(graphicenhancement.imageBatchActive)return
                test.require(graphicenhancement.imageBatchDone===2&&graphicenhancement.imageBatchFailures===0,"image batch success missing")
                test.require(graphicenhancement.startImageBatch([test.media+"frame-a.png",test.media+"frame-b.png"],test.evidenceDirectory+"/images"),"image conflict test refused")
                test.step=9
            }else if(test.step===9){
                if(graphicenhancement.imageBatchActive)return
                test.require(graphicenhancement.imageBatchDone===0&&graphicenhancement.imageBatchFailures===2,"existing image outputs were overwritten")
                test.require(graphicenhancement.startImageBatch([test.media+"frame-a.png"],test.evidenceDirectory+"/cancel-images"),"image cancel test refused")
                graphicenhancement.cancelImageBatch()
                test.require(!graphicenhancement.imageBatchActive,"image cancellation failed")
                graphicenhancement.exportCompletionSound=false
                test.done()
            }
        }
    }
}
