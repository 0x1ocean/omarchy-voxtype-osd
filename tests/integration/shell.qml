import QtQuick
import Quickshell
import "../../components"

Item {
  id: root
  property int streamLines: 0
  property bool lateApplied: false
  property bool checked: false
  property bool failed: false

  function verify(condition, message) {
    if (!condition) {
      failed = true
      console.error("FAIL: " + message)
      Qt.quit()
    }
  }

  MeetingSession {
    id: early
    runtimeDir: Quickshell.env("VOXWAVE_TEST_RUNTIME") + "/early"
    Component.onCompleted: receiveState("paused", "test-meeting")
  }
  MeetingSession {
    id: late
    runtimeDir: Quickshell.env("VOXWAVE_TEST_RUNTIME") + "/late"
  }
  RestartingStream {
    command: ["sh", "-c", "printf 'ready\\n'"]
    onLineReceived: function(line) {
      root.verify(line === "ready", "stream output is preserved")
      root.streamLines++
    }
  }

  Timer {
    interval: 50
    repeat: true
    running: true
    onTriggered: {
      if (root.failed) return
      if (late.cacheReady && !root.lateApplied) {
        root.verify(!late.active, "cached state is hidden until live state arrives")
        late.receiveState("paused", "test-meeting")
        root.lateApplied = true
      }
      if (early.cacheReady && root.lateApplied && !root.checked) {
        root.verify(early.elapsedSeconds === 60, "live state before cache retains paused time")
        root.verify(late.elapsedSeconds === 60, "cache before live state retains paused time")
        root.verify(late.clock.startedAtMs === 100000 && late.clock.pausedTotalMs === 5000,
          "checkpoint survives asynchronous initialization")
        root.checked = true
      }
      if (!root.failed && root.checked && root.streamLines >= 2) {
        console.log("PASS: SessionIO (3 scenarios)")
        Qt.quit()
      }
    }
  }
  Timer {
    interval: 8000
    running: true
    onTriggered: root.verify(false, "integration test timed out")
  }
}
