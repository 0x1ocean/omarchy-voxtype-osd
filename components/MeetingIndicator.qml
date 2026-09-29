import QtQuick
import qs.Commons

Item {
  id: root
  property string status: "starting"
  readonly property bool failed: status === "error" || status === "failed"
  implicitWidth: Style.space(17)
  implicitHeight: Style.space(18)
  opacity: status === "paused" ? 0.45 : 1

  Behavior on opacity { NumberAnimation { duration: 160 } }

  // Meeting health has no microphone level data: keep the status marker static.
  Rectangle {
    anchors.centerIn: parent
    width: Style.space(6)
    height: width
    radius: Style.cornerRadius > 0 ? width / 2 : 0
    color: root.failed ? Color.bar.active : Color.accent
  }
}
