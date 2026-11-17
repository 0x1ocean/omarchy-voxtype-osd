import QtQuick
import Quickshell
import Quickshell.Wayland
import "components"
import "lib/DictationConfig.js" as DictationConfig

Item {
  id: root

  readonly property bool meetingVisible: meeting.active || meetingPresentation.presented
  readonly property bool showPill: DictationConfig.indicator !== "glow"
  readonly property bool showGlow: DictationConfig.indicator !== "pill"
  readonly property string runtimeDir: (Quickshell.env("XDG_RUNTIME_DIR")
    || "/run/user/" + Quickshell.env("UID")) + "/voxtype"

  DictationSession { id: dictation }
  MeetingSession { id: meeting; runtimeDir: root.runtimeDir }
  MeetingRecorder {
    id: recorder
    runtimeDir: root.runtimeDir
    meetingId: meeting.id || meetingPresentation.lastMeetingId
    monitoring: meeting.active || meetingPresentation.presented
  }
  DictationPreview {
    id: preview
    dictation: dictation
    onMeetingPreviewCleared: meetingPresentation.reset()
  }

  MeetingPresentation {
    id: meetingPresentation
    meetingState: preview.meetingState || meeting.state
    meetingId: preview.meetingState ? preview.meetingId : meeting.id
    recorderHealth: preview.meetingState ? preview.meetingHealth : recorder.health
    recorderHadError: preview.meetingState ? preview.meetingHealth === "error" : recorder.hadError
    stopping: preview.meetingState ? preview.meetingStopping : meeting.stopping
    elapsedText: preview.meetingState ? "01:23" : meeting.elapsedText
  }

  VoxtypeBridge {
    runtimeDir: root.runtimeDir
    onStateReceived: function(state) { preview.receiveLiveState(state) }
    onMeetingStateReceived: function(state, id) { meeting.receiveState(state, id) }
    onMeetingStoppingReceived: function(id) { meeting.stoppingId = id }
    onAudioFrame: function(peak, rms) {
      if (!preview.dictationOverride) dictation.updateAudio(peak, rms)
    }
  }

  WindowGlow {
    session: dictation
    enabled: root.showGlow
  }

  PanelWindow {
    visible: (root.showPill && dictation.panelMapped) || root.meetingVisible
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"

    WlrLayershell.namespace: "omarchy-voxtype-osd"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    // The overlay is visual only and never steals clicks from applications.
    mask: Region {}

    DictationPill {
      visible: root.showPill && dictation.panelMapped
      session: dictation
      meetingVisible: root.meetingVisible
    }

    MeetingPill {
      presentation: meetingPresentation
    }
  }
}
