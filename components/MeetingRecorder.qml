import QtQuick
import Quickshell
import Quickshell.Io
import "../lib/MeetingStatus.js" as MeetingStatus

Item {
  id: root
  property string meetingId: ""
  property bool monitoring: false
  property var data: ({})
  property real nowMs: Date.now()
  readonly property string health: MeetingStatus.recorderHealth(data, meetingId, nowMs)
  readonly property bool hadError: !!data && data.id === meetingId && data.hadError === true
  required property string runtimeDir

  FileView {
    id: statusFile
    path: root.runtimeDir + "/meeting-audio/status.json"
    watchChanges: true
    printErrors: false
    onLoaded: {
      try { root.data = JSON.parse(text()) }
      catch (error) { root.data = ({}) }
      root.nowMs = Date.now()
    }
    onLoadFailed: root.data = ({})
    onFileChanged: reload()
  }

  Timer {
    interval: 1000
    running: root.monitoring
    repeat: true
    onTriggered: { root.nowMs = Date.now(); statusFile.reload() }
  }
}
