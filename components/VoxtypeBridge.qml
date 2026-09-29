import QtQuick
import Quickshell
import Quickshell.Io
import "../lib/VoxtypeProtocol.js" as VoxtypeProtocol

Item {
  id: root

  signal stateReceived(string state)
  signal meetingStateReceived(string state, string id)
  signal meetingStoppingReceived(string id)
  signal audioFrame(real peak, real rms)

  required property string runtimeDir

  function updateStatus(raw) {
    try {
      var data = JSON.parse(String(raw || "{}").trim())
      root.stateReceived(String(data.alt || data.class || "idle"))
    } catch (error) {
      console.warn("VoxWave: invalid Voxtype status payload", error)
    }
  }

  function updateAudio(raw) {
    try {
      var data = JSON.parse(String(raw || "{}").trim())
      if (typeof data.peak !== "number" || typeof data.rms !== "number") return
      root.audioFrame(data.peak, data.rms)
    } catch (error) {
      // Connection status messages intentionally contain no audio frame.
    }
  }

  RestartingStream {
    command: ["omarchy-voxtype-status"]
    onLineReceived: function(data) { root.updateStatus(data) }
    onDisconnected: root.stateReceived("idle")
  }

  RestartingStream {
    command: ["voxtype-audio-bridge"]
    onLineReceived: function(data) { root.updateAudio(data) }
    onDisconnected: root.audioFrame(0, 0)
  }

  FileView {
    id: meetingFile
    path: root.runtimeDir + "/meeting_state"
    watchChanges: true
    printErrors: false

    onLoaded: {
      const snapshot = VoxtypeProtocol.meetingState(text())
      if (snapshot) {
        meetingRetry.stop()
        root.meetingStateReceived(snapshot.state, snapshot.id)
      } else meetingRetry.restart()
    }
    onLoadFailed: root.meetingStateReceived("idle", "")
    onFileChanged: reload()
  }

  Timer {
    id: meetingRetry
    interval: 100
    onTriggered: meetingFile.reload()
  }

  FileView {
    path: root.runtimeDir + "/meeting-hotkey-stopping"
    watchChanges: true
    printErrors: false

    onLoaded: root.meetingStoppingReceived(String(text() || "").trim())
    onLoadFailed: root.meetingStoppingReceived("")
    onFileChanged: reload()
  }
}
