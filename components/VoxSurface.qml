import QtQuick
import qs.Commons
import qs.Ui

BorderSurface {
  color: Color.popups.background
  borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, Math.max(1, Style.space(2)))
  radius: Style.cornerRadius
}
