import QtQuick
import qs.Commons

VoxSurface {
  id: root

  required property var presentation

  visible: presentation.presented
  opacity: presentation.reveal
  width: Style.space(224)
  height: Style.space(40)
  anchors.horizontalCenter: parent.horizontalCenter
  anchors.bottom: parent.bottom
  anchors.bottomMargin: Style.space(67)

  Row {
    anchors.centerIn: parent
    height: parent.height
    spacing: Style.space(9)

    MeetingIndicator {
      width: implicitWidth
      height: implicitHeight
      anchors.verticalCenter: parent.verticalCenter
      status: root.presentation.displayState
    }

    Text {
      width: Style.space(90)
      height: parent.height
      verticalAlignment: Text.AlignVCenter
      text: root.presentation.statusText
      color: Color.popups.text
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
      font.weight: Font.Medium
    }

    Text {
      width: Style.space(72)
      height: parent.height
      verticalAlignment: Text.AlignVCenter
      text: root.presentation.shownElapsedText
      color: Color.popups.text
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
      font.weight: Font.Medium
      horizontalAlignment: Text.AlignRight
      opacity: 0.72
    }
  }
}
