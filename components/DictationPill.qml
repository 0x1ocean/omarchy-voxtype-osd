import QtQuick
import qs.Commons
import "../lib/DictationConfig.js" as DictationConfig

VoxSurface {
  id: root

  required property var session
  property bool meetingVisible: false

  width: Style.space(DictationConfig.pillWidth)
  height: Style.space(DictationConfig.pillHeight)
  anchors.horizontalCenter: parent.horizontalCenter
  anchors.bottom: parent.bottom
  anchors.bottomMargin: Style.space(meetingVisible ? 123 : 67)
  visible: session.panelMapped
  opacity: session.reveal * (1 - session.finishProgress)

  Waveform {
    anchors.centerIn: parent
    width: implicitWidth
    height: implicitHeight
    barCount: root.session.barCount
    baseLevel: root.session.baseLevel
    phase: root.session.phase
    processingMix: root.session.processingMix
    levels: root.session.levels
    displayState: root.session.displayState
  }
}
