import QtQuick
import "../lib/MeetingStatus.js" as MeetingStatus

// Reconcile one settled input snapshot, independent of QML binding update order.
Item {
  id: root
  property string meetingState: "idle"
  property string meetingId: ""
  property string recorderHealth: "unavailable"
  property bool recorderHadError: false
  property bool stopping: false
  property string elapsedText: "00:00"

  property string lastMeetingId: ""
  property string previousState: "idle"
  property bool previousStopping: false
  property string displayState: "idle"
  property string shownElapsedText: "00:00"
  property bool hadAudioError: false
  property bool presented: false
  property real reveal: 0
  property real changedAtMs: 0
  readonly property string statusText: MeetingStatus.label(displayState)

  function scheduleSync() { Qt.callLater(root.sync) }

  function reset() {
    completeTimer.stop()
    hideTimer.stop()
    lastMeetingId = ""
    previousState = "idle"
    previousStopping = false
    displayState = "idle"
    hadAudioError = false
    presented = false
    reveal = 0
  }

  function sync() {
    const active = meetingState === "recording" || meetingState === "paused"
    const now = Date.now()
    if (active && !meetingId) return
    const newMeeting = active && meetingId !== lastMeetingId
    if (newMeeting || meetingState !== previousState || stopping !== previousStopping)
      changedAtMs = now
    previousState = meetingState
    previousStopping = stopping

    if (active) {
      completeTimer.stop()
      hideTimer.stop()
      if (newMeeting) {
        hadAudioError = false
        shownElapsedText = elapsedText
      }
      lastMeetingId = meetingId
      presented = true
      reveal = 1
      if (!stopping) shownElapsedText = elapsedText
      displayState = MeetingStatus.displayState(meetingState, stopping,
        recorderHealth, now - changedAtMs)
      if (displayState === "error" || recorderHadError) hadAudioError = true
    } else if (presented && displayState !== "finished" && displayState !== "failed") {
      displayState = MeetingStatus.completionState(recorderHealth,
        hadAudioError || recorderHadError, now - changedAtMs)
      if (displayState === "finished" || displayState === "failed") completeTimer.restart()
    }
  }

  onMeetingStateChanged: scheduleSync()
  onMeetingIdChanged: scheduleSync()
  onStoppingChanged: scheduleSync()
  onRecorderHealthChanged: scheduleSync()
  onRecorderHadErrorChanged: scheduleSync()
  onElapsedTextChanged: scheduleSync()
  Component.onCompleted: scheduleSync()

  Behavior on reveal { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

  Timer {
    interval: 250
    running: root.presented
    repeat: true
    onTriggered: root.sync()
  }
  Timer {
    id: completeTimer
    interval: root.displayState === "failed" ? 5000 : 900
    onTriggered: { root.reveal = 0; hideTimer.restart() }
  }
  Timer {
    id: hideTimer
    interval: 140
    onTriggered: root.presented = false
  }
}
