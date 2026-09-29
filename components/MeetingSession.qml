import QtQuick
import Quickshell
import Quickshell.Io
import "../lib/MeetingClock.js" as MeetingClock

Item {
  id: root

  property var clock: MeetingClock.emptyClock()
  property string stoppingId: ""
  property int elapsedSeconds: 0
  property bool cacheReady: false
  property bool stateReady: false
  property string pendingState: "idle"
  property string pendingId: ""
  property string lookupId: ""
  property string lookupOutput: ""
  property int lookupAttempts: 0
  property bool exactStartKnown: false

  readonly property string state: cacheReady && stateReady ? clock.state : "idle"
  readonly property string id: cacheReady && stateReady ? clock.id : ""
  readonly property bool active: state === "recording" || state === "paused"
  readonly property bool stopping: active && stoppingId === id
  readonly property string elapsedText: MeetingClock.formatElapsed(elapsedSeconds)
  required property string runtimeDir
  readonly property string databasePath: {
    const xdg = Quickshell.env("XDG_DATA_HOME")
    const home = Quickshell.env("HOME")
    return (xdg && xdg.length > 0 ? xdg : home + "/.local/share") + "/voxtype/meetings/index.db"
  }

  function receiveState(nextState, nextId) {
    pendingState = nextState
    pendingId = nextId
    stateReady = true
    if (cacheReady) applyState()
  }

  function applyState() {
    // FileView loads are asynchronous: don't erase a checkpoint before live state arrives.
    if (!cacheReady || !stateReady) return
    const next = MeetingClock.transition(clock, pendingState, pendingId, Date.now())
    const changed = next.id !== clock.id || next.state !== clock.state
    const newMeeting = next.id !== clock.id
    clock = next
    updateElapsed()

    if (newMeeting) {
      exactStartKnown = false
      lookupAttempts = 0
      if (next.id) queryStart()
    }
    if (changed) clockCache.setText(JSON.stringify(clock) + "\n")
  }

  function updateElapsed() {
    elapsedSeconds = MeetingClock.elapsedSeconds(clock, Date.now())
  }

  function queryStart() {
    if (!active || exactStartKnown || lookupAttempts >= 5 || databaseQuery.running) return
    if (!/^[0-9a-f-]{36}$/.test(id)) return
    lookupId = id
    lookupOutput = ""
    lookupAttempts++
    databaseQuery.running = true
  }

  FileView {
    id: clockCache
    path: root.runtimeDir + "/voxwave-meeting-clock.json"
    printErrors: false
    atomicWrites: true

    onLoaded: {
      if (root.cacheReady) return
      try { root.clock = MeetingClock.normalizeClock(JSON.parse(text())) }
      catch (error) { root.clock = MeetingClock.emptyClock() }
      root.cacheReady = true
      root.applyState()
      if (root.active) root.queryStart()
    }
    onLoadFailed: {
      if (root.cacheReady) return
      root.cacheReady = true
      root.applyState()
    }
  }

  Process {
    id: databaseQuery
    command: ["sqlite3", "-readonly", root.databasePath,
      "SELECT started_at FROM meetings WHERE id = '" + root.lookupId + "' LIMIT 1;"]
    running: false
    stdout: SplitParser {
      onRead: function(line) { root.lookupOutput += line }
    }
    onExited: function(exitCode) {
      if (!root.lookupId) return
      const seconds = Number(root.lookupOutput.trim())
      if (exitCode === 0 && root.id === root.lookupId && Number.isFinite(seconds) && seconds > 0) {
        const updated = Object.assign({}, root.clock)
        updated.startedAtMs = seconds * 1000
        root.clock = updated
        root.exactStartKnown = true
        root.updateElapsed()
        clockCache.setText(JSON.stringify(root.clock) + "\n")
      }
      root.lookupId = ""
      root.lookupOutput = ""
    }
  }

  Timer {
    interval: 1000
    repeat: true
    running: root.state === "recording"
    onTriggered: root.updateElapsed()
  }

  Timer {
    interval: 2000
    repeat: true
    running: root.active && !root.exactStartKnown && root.lookupAttempts < 5
    onTriggered: root.queryStart()
  }
}
