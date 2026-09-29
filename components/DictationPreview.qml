import QtQuick
import Quickshell.Io

Item {
  id: root

  required property var dictation
  signal meetingPreviewCleared()
  property string meetingState: ""
  property string meetingHealth: "recording"
  property bool meetingStopping: false
  property int meetingSerial: 0
  readonly property string meetingId: "preview-" + meetingSerial
  property string liveState: "idle"
  property bool dictationOverride: false
  property bool recording: false
  property int frame: 0
  readonly property var audioSamples: [
    [0.02, 0.01], [0.03, 0.02], [0.08, 0.04], [0.18, 0.06],
    [0.25, 0.10], [0.40, 0.14], [0.28, 0.11], [0.09, 0.04],
    [0.03, 0.02], [0.12, 0.05], [0.24, 0.09], [0.50, 0.20],
    [0.35, 0.14], [0.18, 0.07], [0.05, 0.025], [0.02, 0.01],
    [0.03, 0.02], [0.16, 0.06], [0.38, 0.13], [0.27, 0.10],
    [0.08, 0.03], [0.03, 0.02], [0.02, 0.01], [0.02, 0.01]
  ]

  function receiveLiveState(state) {
    liveState = state
    if (!dictationOverride) dictation.showState(state)
  }

  Timer {
    interval: root.dictation.barIntervalMs
    repeat: true
    running: root.recording && root.dictation.daemonState === "recording"
    onTriggered: {
      const sample = root.audioSamples[root.frame % root.audioSamples.length]
      root.dictation.previewAudio(sample[0], sample[1])
      root.frame++
    }
  }

  // Preview states without recording:
  //   omarchy-shell voxtype-osd preview recording|transcribing|meeting|paused
  //   omarchy-shell voxtype-osd hide
  IpcHandler {
    target: "voxtype-osd"

    function preview(state: string): string {
      if (["meeting", "paused", "meeting-starting", "meeting-finishing", "meeting-error", "meeting-done"].indexOf(state) >= 0) {
        if ((root.meetingState === "" || root.meetingState === "idle") && state !== "meeting-done")
          root.meetingSerial++
        root.meetingHealth = state === "meeting-error" ? "error"
          : state === "meeting-starting" ? "starting"
          : state === "meeting-finishing" ? "finishing"
          : state === "meeting-done" ? "done"
          : state === "paused" ? "paused" : "recording"
        root.meetingStopping = state === "meeting-finishing"
        root.meetingState = state === "meeting-done" ? "idle"
          : state === "paused" ? "paused" : "recording"
      } else {
        root.dictationOverride = true
        root.recording = state === "recording"
        root.frame = 0
        root.dictation.showState(state)
      }
      return "ok"
    }

    function hide(): string {
      root.recording = false
      root.dictationOverride = false
      root.dictation.showState(root.liveState)
      if (root.meetingState !== "") {
        root.meetingState = ""
        root.meetingPreviewCleared()
      }
      return "ok"
    }

    function state(): string {
      return root.dictation.daemonState
    }
  }
}
