import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui

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
    var next = []
    for (var i = 0; i <= Math.floor(barCount / 2); i++) next.push(0.04)
    levels = next
    smoothedEnergy = 0.04
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

  function updateStatus(raw) {
    try {
      var data = JSON.parse(String(raw || "{}").trim())
      showState(String(data.alt || data.class || "idle"))
    } catch (error) {
      console.warn("Voxtype OSD: invalid status payload", error)
    }
  }

  function updateAudio(raw) {
    if (daemonState !== "recording") return

    try {
      var data = JSON.parse(String(raw || "{}").trim())
      if (typeof data.peak !== "number" || typeof data.rms !== "number") return

      // The bridge emits about 100 frames per second. Sampling every third
      // frame gives the waveform a calmer, Superwhisper-like motion.
      audioSample++
      if (audioSample % 3 !== 0) return

      var raw = Math.min(1, Math.max(0, data.rms * 0.72 + data.peak * 0.28))

      // Voxtype 1.0 currently reports VAD=true even for quiet input, so learn
      // the floor directly from RMS/peak. It falls quickly when the room gets
      // quieter and rises very slowly, which prevents speech from becoming
      // the new baseline.
      var floorSpeed = raw < noiseFloor ? 0.12 : 0.006
      noiseFloor += (raw - noiseFloor) * floorSpeed

      var threshold = Math.min(0.30, noiseFloor * 1.65 + 0.008)
      var gated = Math.max(0, (raw - threshold) / Math.max(0.15, 0.55 - threshold))
      var compressed = Math.pow(Math.min(1, gated), 0.65)
      var target = 0.04 + compressed * 0.96

      // Fast attack makes the OSD feel immediate; the slower release keeps
      // the bars fluid instead of nervous between syllables.
      var smoothing = target > smoothedEnergy ? 0.55 : 0.21
      smoothedEnergy += (target - smoothedEnergy) * smoothing

      // The newest sample starts in the centre and its history travels
      // symmetrically towards both edges.
      var next = [smoothedEnergy]
      for (var i = 0; i < levels.length - 1; i++) next.push(levels[i])
      levels = next
    } catch (error) {
      // Status messages from the bridge intentionally contain no audio data.
    }
  }

  function recordingLevel(index) {
    var center = Math.floor(barCount / 2)
    var distance = Math.abs(index - center)
    if (distance < 0 || distance >= levels.length) return 0.04
    var level = Math.max(0.04, Math.min(1, Number(levels[distance]) || 0))
    var age = distance / Math.max(1, levels.length - 1)
    return 0.04 + (level - 0.04) * (1 - age * 0.38)
  }

  function processingLevel(index) {
    // One soft pulse crosses the surface, fully leaving the edge before the
    // next pass begins so the loop has no visible jump.
    var position = -4 + phase * (barCount + 8)
    var distance = index - position
    var pulse = Math.exp(-(distance * distance) / 9)
    return Math.min(1, 0.10 + pulse * 0.84)
  }

  function levelAt(index) {
    var recorded = recordingLevel(index)
    var processing = processingLevel(index)
    var level = recorded * (1 - processingMix) + processing * processingMix

    if (displayState === "finishing")
      level = level * (1 - finishProgress) + 0.04 * finishProgress

    return level
  }

  function heightAt(index) {
    return minBarHeight + (maxBarHeight - minBarHeight) * levelAt(index)
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

  Process {
    command: ["bash", "-c", "exec omarchy-voxtype-status"]
    running: true
    stdout: SplitParser {
      onRead: function(data) { root.updateStatus(data) }
    }
  }

  Process {
    command: ["/usr/bin/voxtype-audio-bridge"]
    running: true
    stdout: SplitParser {
      onRead: function(data) { root.updateAudio(data) }
    }
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

      Row {
        anchors.centerIn: parent
        spacing: root.barGap

        Repeater {
          model: root.barCount

          Rectangle {
            required property int index

            width: root.barWidth
            height: root.heightAt(index)
            anchors.verticalCenter: parent.verticalCenter
            radius: Style.cornerRadius > 0 ? width / 2 : 0
            color: root.waveColor

            Behavior on height {
              NumberAnimation {
                duration: root.displayState === "recording" ? 45 : 75
                easing.type: Easing.OutCubic
              }
            }

            Behavior on color {
              ColorAnimation { duration: 160 }
            }
          }
        }
      }
    }
  }
}
