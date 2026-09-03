import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "components"
import "lib/WaveformMath.js" as WaveformMath

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
  property int audioSample: 0
  property real smoothedEnergy: 0.04
  property real noiseFloor: 0.04

  readonly property real baseLevel: 0.04
  readonly property int barCount: 29
  readonly property int barWidth: Style.space(3)
  readonly property int barGap: Style.space(4)
  readonly property int cardWidth: Style.space(270)
  readonly property int cardHeight: Style.space(48)
  readonly property int minBarHeight: Style.space(3)
  readonly property int maxBarHeight: Style.space(26)
  readonly property bool active: daemonState === "recording" || daemonState === "transcribing"
  readonly property color waveColor: displayState === "recording" ? Color.bar.active : Color.accent

  function resetLevels() {
    levels = WaveformMath.createHistory(barCount, baseLevel)
    smoothedEnergy = baseLevel
    audioSample = 0
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

    // The bridge emits about 100 frames per second. Sampling every third
    // frame gives the waveform a calmer, Superwhisper-like motion.
    audioSample++
    if (audioSample % 3 !== 0) return

    var frame = WaveformMath.frameEnergy(rms, peak, noiseFloor, baseLevel)
    noiseFloor = frame.noiseFloor
    smoothedEnergy = WaveformMath.smoothEnergy(smoothedEnergy, frame.target)
    levels = WaveformMath.pushHistory(levels, smoothedEnergy)
  }

  Component.onCompleted: resetLevels()

  NumberAnimation {
    id: enterAnimation
    target: root
    property: "reveal"
    from: 0
    to: 1
    duration: 95
    easing.type: Easing.OutCubic
  }

  NumberAnimation {
    id: cancelAnimation
    target: root
    property: "reveal"
    from: root.reveal
    to: 0
    duration: 150
    easing.type: Easing.OutCubic
    onFinished: root.finishSurface()
  }

  NumberAnimation {
    id: finishAnimation
    target: root
    property: "finishProgress"
    from: 0
    to: 1
    duration: 160
    easing.type: Easing.InOutCubic
    onFinished: root.finishSurface()
  }

  Behavior on processingMix {
    NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
  }

  VoxtypeBridge {
    onStateReceived: function(state) { root.showState(state) }
    onAudioFrame: function(peak, rms) { root.updateAudio(peak, rms) }
  }

  Timer {
    interval: 16
    running: root.panelMapped && (root.displayState === "transcribing" || root.displayState === "finishing")
    repeat: true
    onTriggered: root.phase = (root.phase + 0.0145) % 1
  }

  // Handy for development and screenshots:
  //   omarchy-shell voxtype-osd preview recording
  //   omarchy-shell voxtype-osd preview transcribing
  //   omarchy-shell voxtype-osd hide
  IpcHandler {
    target: "voxtype-osd"

    function preview(state: string): string {
      root.showState(state)
      return "ok"
    }

    function hide(): string {
      root.showState("idle")
      return "ok"
    }

    function state(): string {
      return root.daemonState
    }
  }

  PanelWindow {
    id: panel
    visible: root.panelMapped
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"

    WlrLayershell.namespace: "omarchy-voxtype-osd"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    // The overlay is visual only and never steals clicks from applications.
    mask: Region {}

    BorderSurface {
      id: card
      width: root.cardWidth
      height: root.cardHeight
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: Style.space(67)
      color: Color.popups.background
      borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, Math.max(1, Style.space(2)))
      radius: Style.cornerRadius
      opacity: root.reveal * (1 - root.finishProgress)
      scale: 0.97 + root.reveal * 0.03 - root.finishProgress * 0.015

      Waveform {
        anchors.centerIn: parent
        width: implicitWidth
        height: implicitHeight
        barCount: root.barCount
        barWidth: root.barWidth
        barGap: root.barGap
        minBarHeight: root.minBarHeight
        maxBarHeight: root.maxBarHeight
        baseLevel: root.baseLevel
        phase: root.phase
        processingMix: root.processingMix
        finishProgress: root.finishProgress
        levels: root.levels
        displayState: root.displayState
        waveColor: root.waveColor
      }
    }
  }
}
