import QtQuick
import Quickshell.Io

Item {
  id: root

  signal stateReceived(string state)
  signal audioFrame(real peak, real rms)

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

  Process {
    command: ["bash", "-c", "exec omarchy-voxtype-status"]
    running: true
    stdout: SplitParser {
      onRead: function(data) { root.updateStatus(data) }
    }
  }

  Process {
    command: ["bash", "-c", "exec voxtype-audio-bridge"]
    running: true
    stdout: SplitParser {
      onRead: function(data) { root.updateAudio(data) }
    }
  }
}
