function emptyClock() {
  return { id: "", state: "idle", startedAtMs: 0, pausedAtMs: 0, pausedTotalMs: 0 }
}

function normalizeClock(value) {
  if (!value || typeof value !== "object") return emptyClock()
  if (typeof value.id !== "string" || !value.id) return emptyClock()
  if (value.state !== "recording" && value.state !== "paused") return emptyClock()

  return {
    id: value.id,
    state: value.state,
    startedAtMs: Math.max(0, Number(value.startedAtMs) || 0),
    pausedAtMs: Math.max(0, Number(value.pausedAtMs) || 0),
    pausedTotalMs: Math.max(0, Number(value.pausedTotalMs) || 0)
  }
}

function transition(clock, state, id, nowMs) {
  if ((state !== "recording" && state !== "paused") || !id) return emptyClock()

  var previous = normalizeClock(clock)
  if (previous.id !== id) {
    return {
      id: id,
      state: state,
      startedAtMs: nowMs,
      pausedAtMs: state === "paused" ? nowMs : 0,
      pausedTotalMs: 0
    }
  }
  if (previous.state === state) return previous

  if (state === "paused") {
    previous.pausedAtMs = nowMs
  } else {
    previous.pausedTotalMs += Math.max(0, nowMs - previous.pausedAtMs)
    previous.pausedAtMs = 0
  }
  previous.state = state
  return previous
}

function elapsedSeconds(clock, nowMs) {
  var current = normalizeClock(clock)
  if (!current.id || current.startedAtMs <= 0) return 0
  var endMs = current.state === "paused" ? current.pausedAtMs : nowMs
  return Math.max(0, Math.floor((endMs - current.startedAtMs - current.pausedTotalMs) / 1000))
}

function formatElapsed(seconds) {
  var total = Math.max(0, Math.floor(Number(seconds) || 0))
  var hours = Math.floor(total / 3600)
  var minutes = Math.floor((total % 3600) / 60)
  var secs = total % 60
  function pad(value) { return value < 10 ? "0" + value : String(value) }
  return hours > 0 ? pad(hours) + ":" + pad(minutes) + ":" + pad(secs)
    : pad(minutes) + ":" + pad(secs)
}
