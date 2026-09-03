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
  property var levels: []
  property int audioSample: 0

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
    for (var i = 0; i < barCount; i++) next.push(0.06)
    levels = next
  }

  function showState(next) {
    if (next !== "recording" && next !== "transcribing") next = "idle"

    var wasActive = root.active
    daemonState = next

    if (next === "recording" || next === "transcribing") {
      hideTimer.stop()
      if (next === "recording" && displayState !== "recording") resetLevels()
      displayState = next
      panelMapped = true
      reveal = 1
      return
    }

    if (wasActive || panelMapped) {
      reveal = 0
      hideTimer.restart()
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

      var energy = Math.min(1, Math.max(0.06, data.rms * 6 + data.peak * 0.85))
      var next = levels.slice(1)
      next.push(energy)
      levels = next
    } catch (error) {
      // Status messages from the bridge intentionally contain no audio data.
    }
  }

  function levelAt(index) {
    if (displayState === "transcribing") {
      var center = (barCount - 1) / 2
      var distance = Math.abs(index - center) / Math.max(1, center)
      var envelope = 0.30 + 0.70 * (1 - Math.pow(distance, 1.7))
      var travellingWave = 0.5 + 0.5 * Math.sin(phase - index * 0.52)
      return 0.12 + envelope * travellingWave * 0.78
    }

    if (index < 0 || index >= levels.length) return 0.06
    return Math.max(0.06, Math.min(1, Number(levels[index]) || 0))
  }

  function heightAt(index) {
    return minBarHeight + (maxBarHeight - minBarHeight) * levelAt(index)
  }

  Component.onCompleted: resetLevels()

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
    interval: 40
    running: root.panelMapped
    repeat: true
    onTriggered: root.phase = (root.phase + 0.19) % (Math.PI * 2)
  }

  Timer {
    id: hideTimer
    interval: 180
    onTriggered: {
      root.panelMapped = false
      root.displayState = "idle"
      root.resetLevels()
    }
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
      color: Util.alpha(Color.popups.background, 0.97)
      borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, Math.max(1, Style.space(2)))
      radius: Style.cornerRadius
      opacity: root.reveal
      scale: 0.98 + root.reveal * 0.02

      Behavior on opacity {
        NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
      }

      Behavior on scale {
        NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
      }

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
                duration: root.displayState === "recording" ? 70 : 110
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
