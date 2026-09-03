import QtQuick
import qs.Commons
import "../lib/WaveformMath.js" as WaveformMath

Item {
  id: root

  property int barCount: 29
  property int barWidth: Style.space(3)
  property int barGap: Style.space(4)
  property int minBarHeight: Style.space(3)
  property int maxBarHeight: Style.space(26)
  property real baseLevel: 0.04
  property real phase: 0
  property real processingMix: 0
  property real finishProgress: 0
  property var levels: []
  property string displayState: "idle"
  property color waveColor: Color.accent

  implicitWidth: barCount * barWidth + (barCount - 1) * barGap
  implicitHeight: maxBarHeight

  function levelAt(index) {
    var recorded = WaveformMath.recordingLevel(index, barCount, levels, baseLevel)
    var processing = WaveformMath.processingLevel(index, barCount, phase)
    return WaveformMath.mixedLevel(
      recorded,
      processing,
      processingMix,
      displayState === "finishing" ? finishProgress : 0,
      baseLevel
    )
  }

  function heightAt(index) {
    return minBarHeight + (maxBarHeight - minBarHeight) * levelAt(index)
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
