import QtQuick
import qs.Commons
import "../lib/DictationConfig.js" as DictationConfig
import "../lib/WaveformMath.js" as WaveformMath

Item {
  id: root

  property int barCount: DictationConfig.barCount
  property int barWidth: Style.space(DictationConfig.barWidth)
  property int barGap: Style.space(DictationConfig.barGap)
  property int minBarHeight: Style.space(DictationConfig.minBarHeight)
  property int maxBarHeight: Style.space(DictationConfig.maxBarHeight)
  property real baseLevel: 0.04
  property real phase: 0
  property real processingMix: 0
  property var levels: []
  property string displayState: "idle"
  property color waveColor: Color.accent

  implicitWidth: barCount * barWidth + (barCount - 1) * barGap
  implicitHeight: maxBarHeight

  function levelAt(index) {
    var recorded = WaveformMath.recordingLevel(index, barCount, levels, baseLevel)
    var processing = WaveformMath.processingLevel(index, barCount, phase, baseLevel)
    return WaveformMath.mixLevel(recorded, processing, processingMix)
  }

  function opacityAt(index) {
    var mix = Math.max(0, Math.min(1, processingMix))
    var processing = WaveformMath.processingOpacity(index, barCount, phase)
    return 1 + (processing - 1) * mix
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
        opacity: root.opacityAt(index)

        Behavior on height {
          enabled: root.displayState === "recording"
          NumberAnimation {
            duration: DictationConfig.barEaseMs
            easing.type: Easing.OutCubic
          }
        }
      }
    }
  }
}
