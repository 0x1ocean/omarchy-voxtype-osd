function recorderHealth(data, meetingId, nowMs) {
  if (!data || !meetingId || data.id !== meetingId) return "unavailable"
  var age = nowMs - Number(data.updatedAtMs)
  if (!Number.isFinite(age) || age < -1000 || age > 4000) return "unavailable"
  return ["starting", "recording", "paused", "finishing", "done", "error"].indexOf(data.state) >= 0
    ? data.state : "unavailable"
}

function displayState(meetingState, stopping, health, waitingMs) {
  if (health === "error") return "error"
  if (stopping) return health === "unavailable" && waitingMs >= 8000 ? "error" : "finishing"
  if (meetingState === "recording" && health === "recording") return "recording"
  if (meetingState === "paused" && health === "paused") return "paused"
  if (waitingMs >= 8000) return "error"
  return meetingState === "paused" ? "pausing" : "starting"
}

function completionState(health, hadError, waitingMs) {
  if (health === "error" || hadError) return "failed"
  if (health === "done") return "finished"
  return waitingMs >= 6000 ? "failed" : "finishing"
}

function label(state) {
  var labels = { starting: "Starting", recording: "Recording", pausing: "Pausing",
    paused: "Paused", finishing: "Finishing", finished: "Done",
    error: "Audio error", failed: "Check audio" }
  return labels[state] || "Starting"
}
