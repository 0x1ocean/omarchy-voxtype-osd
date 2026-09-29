function meetingState(raw) {
  var lines = String(raw || "").split("\n")
  var state = lines[0].trim()
  if (state === "idle") return { state: "idle", id: "" }
  var id = String(lines[1] || "").trim()
  if ((state === "recording" || state === "paused")
      && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id))
    return { state: state, id: id }
  // The daemon truncates before writing. A partial read is not an idle event.
  return null
}
