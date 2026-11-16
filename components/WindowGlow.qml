// Window glow: while you dictate, the focused window's frame lights up from
// both bottom corners. The bottom light moves as a soft wave that follows
// your voice; the bottom centre stays clear so the input line isn't covered.
//
//   listening, silent -> thin calm glow tucked into the corners, slow breath
//   speaking          -> waves rise, speed up and reach inwards with your voice
//   transcribing      -> waves settle, hue shifts, a light runs along the bottom
//   finished          -> a short flash along the whole bottom edge
//   cancelled         -> fades out
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Commons
import "../lib/GlowMath.js" as GlowMath

Scope {
  id: glow

  required property var session
  property bool enabled: true

  readonly property bool recording: session.daemonState === "recording"
  readonly property bool transcribing: session.daemonState === "transcribing"
  readonly property bool active: enabled && (recording || transcribing)

  // --- Presence ---------------------------------------------------------------
  // 0 = hidden, 1 = fully risen. Settles a little while transcribing.
  property real level: active ? (transcribing ? 0.8 : 1) : 0
  Behavior on level { NumberAnimation { duration: glow.level < 0.05 ? 520 : 420; easing.type: Easing.OutCubic } }

  // Finish flash, played when a transcription ends.
  property real flash: 0
  Connections {
    target: glow.session
    function onDisplayStateChanged() {
      if (glow.enabled && glow.session.displayState === "finishing") flashAnimation.restart()
    }
  }
  SequentialAnimation {
    id: flashAnimation
    NumberAnimation { target: glow; property: "flash"; from: 0; to: 1; duration: 140; easing.type: Easing.OutCubic }
    NumberAnimation { target: glow; property: "flash"; to: 0; duration: 650; easing.type: Easing.InOutSine }
  }

  readonly property bool busy: level > 0.005 || flash > 0.01

  // --- One clock for every animated value --------------------------------
  property real voice: 0          // smoothed voice energy, 0..1
  property real clock: 0          // seconds since the glow appeared
  property real wave: 0           // accumulated wave phase
  property real thinkMix: 0       // 0 = listening colours, 1 = transcribing colours

  FrameAnimation {
    running: glow.busy
    onTriggered: {
      const dt = Math.min(frameTime, 0.1)
      // session.smoothedEnergy is already noise-gated; 0.04 is its resting floor.
      const heard = glow.recording ? (glow.session.smoothedEnergy - 0.04) / 0.96 : 0
      glow.voice = GlowMath.followVoice(glow.voice, heard * 1.25, dt)
      glow.thinkMix = GlowMath.approach(glow.thinkMix, glow.transcribing ? 1 : 0, 0.06, dt)
      glow.clock += dt
      glow.wave += dt * (glow.transcribing ? 0.15 : 0.35 + 1.4 * glow.voice)
    }
  }
  onBusyChanged: if (!busy) { voice = 0; clock = 0; thinkMix = 0 }

  readonly property real breath: 1 + 0.06 * Math.sin(clock * 6.283185 / 3.2)
  readonly property real energy: Math.min(1.4, level * (0.22 * breath + 1.15 * voice))

  // --- Colours -------------------------------------------------------------
  readonly property color base: Color.accent
  readonly property color think: hueShift(base, 0.14, 0.08)
  readonly property color c: Qt.tint(base, tone(think, thinkMix))
  readonly property color depth: Qt.tint(hueShift(base, 0.07, 0.06), tone(think, thinkMix))
  function tone(col, alpha) { return Qt.rgba(col.r, col.g, col.b, alpha) }
  function hueShift(col, dh, dl) {
    return Qt.hsla((col.hslHue + dh + 1) % 1, col.hslSaturation, Math.min(1, col.hslLightness + dl), 1)
  }

  // --- Focused window ------------------------------------------------------
  readonly property var ipc: Hyprland.activeToplevel ? Hyprland.activeToplevel.lastIpcObject : null
  readonly property var win: ipc && ipc.at && ipc.size
    ? { x: ipc.at[0], y: ipc.at[1], w: ipc.size[0], h: ipc.size[1] } : null
  readonly property var screen: {
    const name = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
    return Quickshell.screens.find(s => s.name === name) || Quickshell.screens[0]
  }

  onActiveChanged: if (active) Hyprland.refreshToplevels()
  Connections {
    target: Hyprland
    enabled: glow.active
    function onRawEvent(event) {
      if (["activewindowv2", "movewindowv2", "changefloatingmode", "fullscreen", "workspacev2"].includes(event.name))
        Hyprland.refreshToplevels()
    }
  }
  // Hyprland sends no event for an interactive resize; a slow refresh covers it.
  Timer { interval: 400; repeat: true; running: glow.active; onTriggered: Hyprland.refreshToplevels() }

  // --- Overlay -------------------------------------------------------------
  PanelWindow {
    screen: glow.screen
    visible: glow.busy && glow.win !== null
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omarchy-voxtype-glow"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    mask: Region {}

    Item {
      id: area
      x: glow.win ? glow.win.x - glow.screen.x : 0
      y: glow.win ? glow.win.y - glow.screen.y : 0
      width: glow.win ? glow.win.w : 0
      height: glow.win ? glow.win.h : 0
      clip: true
      Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
      Behavior on y { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
      Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
      Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

      // Reach along the bottom (fraction of width), up the sides, and depth.
      readonly property real reachB: Math.min(0.49, 0.13 + 0.30 * glow.energy)
      readonly property real reachS: height * (0.07 + 0.16 * glow.energy)
      readonly property real thick: 6 + 22 * glow.energy

      // Glow layer: only the bottom strip, blurred at half resolution.
      Item {
        id: strip
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: Math.max(area.reachS, area.thick * 2) + 48
        opacity: Math.min(1, glow.level * (0.65 + glow.voice * 0.6))
        layer.enabled: true
        layer.textureSize: Qt.size(Math.max(1, width / 2), Math.max(1, height / 2))
        layer.effect: MultiEffect { blurEnabled: true; blur: 1.0; blurMax: 32; blurMultiplier: 0.4 }

        Repeater {
          model: 2   // 0 = left corner, 1 = right corner (mirrored)
          Item {
            required property int index
            anchors.fill: parent
            transform: Scale { origin.x: strip.width / 2; xScale: index ? -1 : 1 }

            WaveBand { length: strip.width * area.reachB * 1.1; depth: area.thick * 1.1; col: glow.c; alpha: 0.82; offset: index * 1.3 }
            WaveBand { length: strip.width * area.reachB * 0.75; depth: area.thick * 1.5; col: glow.depth; alpha: 0.35; offset: 2.1 + index * 1.3; speed: 0.7; wavelength: 320 }
            SideBand { length: area.reachS * (1 + 0.05 * Math.sin(glow.wave * 0.7 + index)); depth: area.thick * 0.7 }
          }
        }

        // Transcribing: a light running back and forth along the bottom.
        Rectangle {
          property real p: 0.5 + 0.42 * Math.sin(glow.clock * 6.283185 / 1.8)
          width: Math.max(80, strip.width * 0.2)
          height: 12
          radius: 6
          x: strip.width * p - width / 2
          y: strip.height - height
          opacity: glow.thinkMix
          gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.5; color: glow.think }
            GradientStop { position: 1.0; color: "transparent" }
          }
        }
      }

      // Lit rim on the frame itself (thin, no extra layer).
      Repeater {
        model: 2
        Item {
          required property int index
          anchors.fill: parent
          opacity: Math.min(1, glow.level * (0.6 + glow.voice))
          transform: Scale { origin.x: area.width / 2; xScale: index ? -1 : 1 }

          Rectangle {
            anchors { left: parent.left; bottom: parent.bottom }
            width: 2; height: area.reachS * 1.3
            gradient: RimFade { col: glow.c; reversed: true }
          }
          Rectangle {
            anchors { left: parent.left; bottom: parent.bottom }
            width: area.width * area.reachB; height: 2
            gradient: RimFade { col: glow.c; orientation: Gradient.Horizontal }
          }
        }
      }

      // Finish flash along the whole bottom edge.
      Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 8
        visible: glow.flash > 0.01
        opacity: glow.flash
        layer.enabled: visible
        layer.effect: MultiEffect { blurEnabled: true; blur: 0.9; blurMax: 40; brightness: 0.15 }
        gradient: Gradient {
          orientation: Gradient.Horizontal
          GradientStop { position: 0.0; color: glow.tone(glow.base, 0.6) }
          GradientStop { position: 0.5; color: Qt.lighter(glow.base, 1.35) }
          GradientStop { position: 1.0; color: glow.tone(glow.base, 0.6) }
        }
      }
    }
  }

  // --- Building blocks (left-corner geometry; the right side is mirrored) -----

  // Eased fade from `col` at the start to transparent at the end.
  component Fade: LinearGradient {
    property color col: "white"
    property real alpha: 1
    GradientStop { position: 0.0;  color: glow.tone(col, alpha * GlowMath.falloff(0.0)) }
    GradientStop { position: 0.22; color: glow.tone(col, alpha * GlowMath.falloff(0.22)) }
    GradientStop { position: 0.5;  color: glow.tone(col, alpha * GlowMath.falloff(0.5)) }
    GradientStop { position: 0.8;  color: glow.tone(col, alpha * GlowMath.falloff(0.8)) }
    GradientStop { position: 1.0;  color: "transparent" }
  }

  component RimFade: Gradient {
    property color col: "white"
    property bool reversed: false
    GradientStop { position: reversed ? 1.0 : 0.0;   color: glow.tone(col, GlowMath.falloff(0.0)) }
    GradientStop { position: reversed ? 0.78 : 0.22; color: glow.tone(col, GlowMath.falloff(0.22)) }
    GradientStop { position: 0.5;                    color: glow.tone(col, GlowMath.falloff(0.5)) }
    GradientStop { position: reversed ? 0.2 : 0.8;   color: glow.tone(col, GlowMath.falloff(0.8)) }
    GradientStop { position: reversed ? 0.0 : 1.0;   color: "transparent" }
  }

  // Bottom band whose top edge is a wave running from the corner inwards.
  component WaveBand: Shape {
    id: band
    property real length: 100
    property real depth: 20
    property color col: "white"
    property real alpha: 1
    property real offset: 0
    property real speed: 1
    property real wavelength: 230
    readonly property real amplitude: glow.transcribing ? 0.08 : 0.10 + 0.50 * Math.min(1, glow.voice * 1.2)
    anchors.fill: parent
    preferredRendererType: Shape.GeometryRenderer

    ShapePath {
      strokeWidth: -1
      fillGradient: Fade { x1: 0; y1: band.height; x2: band.length; y2: band.height; col: band.col; alpha: band.alpha }
      PathPolyline {
        path: {
          const top = GlowMath.waveContour(band.length, band.depth, band.height, glow.wave * band.speed,
            { wavelength: band.wavelength, amplitude: band.amplitude, offset: band.offset })
          const pts = [Qt.point(0, band.height), Qt.point(band.length, band.height)]
          for (let i = top.length - 1; i >= 0; i--) pts.push(Qt.point(top[i].x, top[i].y))
          return pts
        }
      }
    }
  }

  // Side band: thick at the corner, curving smoothly to nothing up the edge.
  component SideBand: Shape {
    id: side
    property real length: 100
    property real depth: 20
    anchors.fill: parent
    preferredRendererType: Shape.GeometryRenderer

    ShapePath {
      strokeWidth: -1
      fillGradient: Fade { x1: 0; y1: side.height; x2: 0; y2: side.height - side.length; col: glow.c; alpha: 0.85 }
      startX: 0; startY: side.height
      PathLine { x: 0; y: side.height - side.length }
      PathQuad { x: side.depth; y: side.height; controlX: side.depth * 0.9; controlY: side.height - side.length * 0.18 }
      PathLine { x: 0; y: side.height }
    }
  }
}
