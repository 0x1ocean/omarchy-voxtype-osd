import QtQuick
import "../lib/DictationConfig.js" as DictationConfig
import "../lib/WaveformMath.js" as WaveformMath

Item {
  id: root

  property string daemonState: "idle"
  property string displayState: "idle"
  property bool panelMapped: false
  property real reveal: 0
  property real phase: 0
  property real processingMix: 0
  property real finishProgress: 0
  property var levels: []
  property real pendingPeak: 0
  property real pendingRmsSum: 0
  property int pendingFrames: 0
  property real lastBarAtMs: 0
  property real lastAudioAtMs: 0
  property real smoothedEnergy: 0.04
  property real noiseFloor: 0.04

  readonly property real baseLevel: 0.04
  readonly property int barCount: DictationConfig.barCount
  readonly property int barIntervalMs: DictationConfig.barIntervalMs
  readonly property int processingCycleMs: DictationConfig.processingCycleMs

  function resetLevels() {
    levels = WaveformMath.createHistory(barCount, baseLevel)
    smoothedEnergy = baseLevel
    noiseFloor = baseLevel
    pendingPeak = 0
    pendingRmsSum = 0
    pendingFrames = 0
    lastBarAtMs = 0
    lastAudioAtMs = Date.now()
  }

  function finishSurface() {
    panelMapped = false
    displayState = "idle"
    reveal = 0
    finishProgress = 0
    processingMix = 0
    resetLevels()
  }

  function showState(next) {
    if (next !== "recording" && next !== "transcribing") next = "idle"
    if (next === daemonState) return

    var previous = daemonState
    daemonState = next

    if (next === "recording" || next === "transcribing") {
      enterAnimation.stop()
      cancelAnimation.stop()
      finishAnimation.stop()
      finishProgress = 0

      if (next === "recording" && previous !== "recording") resetLevels()
      if (next === "transcribing" && previous !== "transcribing") phase = 0

      displayState = next
      processingMix = next === "transcribing" ? 1 : 0

      if (!panelMapped) {
        reveal = 0
        panelMapped = true
        enterAnimation.restart()
      } else {
        reveal = 1
      }
      return
    }

    enterAnimation.stop()
    if (previous === "transcribing" && panelMapped) {
      displayState = "finishing"
      reveal = 1
      finishProgress = 0
      finishAnimation.restart()
    } else if (panelMapped) {
      cancelAnimation.restart()
    } else {
      finishSurface()
    }
  }

  function updateAudio(peak, rms) {
    if (daemonState !== "recording") return
    if (!Number.isFinite(peak) || !Number.isFinite(rms)) return
    lastAudioAtMs = Date.now()

    // Aggregate bridge frames, then advance the strip at a steady visual pace.
    pendingPeak = Math.max(pendingPeak, peak)
    pendingRmsSum += rms
    pendingFrames++
    const now = Date.now()
    if (lastBarAtMs === 0) lastBarAtMs = now
    if (now - lastBarAtMs < barIntervalMs) return

    var aggregatedPeak = pendingPeak
    var aggregatedRms = pendingRmsSum / pendingFrames
    pendingPeak = 0
    pendingRmsSum = 0
    pendingFrames = 0
    lastBarAtMs = now
    appendAudio(aggregatedPeak, aggregatedRms)
  }

  function appendAudio(peak, rms) {
    var frame = WaveformMath.frameEnergy(rms, peak, noiseFloor, baseLevel)
    noiseFloor = frame.noiseFloor
    smoothedEnergy = WaveformMath.smoothEnergy(smoothedEnergy, frame.target)
    levels = WaveformMath.pushHistory(levels, smoothedEnergy)
  }

  function previewAudio(peak, rms) {
    if (daemonState !== "recording") return
    lastAudioAtMs = Date.now()
    appendAudio(peak, rms)
  }

  Component.onCompleted: resetLevels()

  Timer {
    interval: 100
    running: root.daemonState === "recording"
    repeat: true
    onTriggered: {
      if (Date.now() - root.lastAudioAtMs > 250) {
        root.pendingPeak = 0
        root.pendingRmsSum = 0
        root.pendingFrames = 0
        root.lastBarAtMs = 0
        root.appendAudio(0, 0)
      }
    }
  }

  NumberAnimation {
    id: enterAnimation
    target: root
    property: "reveal"
    from: 0
    to: 1
    duration: DictationConfig.enterMs
    easing.type: Easing.OutCubic
  }

  NumberAnimation {
    id: cancelAnimation
    target: root
    property: "reveal"
    from: root.reveal
    to: 0
    duration: DictationConfig.exitMs
    easing.type: Easing.OutCubic
    onFinished: root.finishSurface()
  }

  NumberAnimation {
    id: finishAnimation
    target: root
    property: "finishProgress"
    from: 0
    to: 1
    duration: DictationConfig.exitMs
    easing.type: Easing.InOutCubic
    onFinished: root.finishSurface()
  }

  Behavior on processingMix {
    NumberAnimation { duration: DictationConfig.transitionMs; easing.type: Easing.InOutCubic }
  }

  Timer {
    interval: DictationConfig.animationTickMs
    running: root.panelMapped && (root.displayState === "transcribing" || root.displayState === "finishing")
    repeat: true
    onTriggered: root.phase = (root.phase + interval / root.processingCycleMs) % 1
  }
}
