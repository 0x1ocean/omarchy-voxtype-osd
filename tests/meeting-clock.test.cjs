const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")
const test = require("node:test")
const vm = require("node:vm")

const source = fs.readFileSync(path.join(__dirname, "..", "lib", "MeetingClock.js"), "utf8")
const clock = {}
vm.createContext(clock)
vm.runInContext(source, clock)

test("meeting clock pauses and resumes without counting the pause", () => {
  let state = clock.transition(null, "recording", "meeting-1", 100000)
  assert.equal(clock.elapsedSeconds(state, 165000), 65)

  state = clock.transition(state, "paused", "meeting-1", 165000)
  assert.equal(clock.elapsedSeconds(state, 225000), 65)

  state = clock.transition(state, "recording", "meeting-1", 225000)
  assert.equal(clock.elapsedSeconds(state, 235000), 75)
})

test("meeting clock keeps its checkpoint across reloads", () => {
  const state = clock.transition(
    { id: "meeting-1", state: "paused", startedAtMs: 100000,
      pausedAtMs: 165000, pausedTotalMs: 0 },
    "paused", "meeting-1", 225000
  )
  assert.equal(clock.elapsedSeconds(state, 225000), 65)
  assert.equal(clock.transition(state, "idle", "", 225000).id, "")
})

test("new meeting resets the old time and formats long calls", () => {
  const old = clock.transition(null, "recording", "meeting-1", 100000)
  const next = clock.transition(old, "recording", "meeting-2", 225000)
  assert.equal(clock.elapsedSeconds(next, 225000), 0)
  assert.equal(clock.formatElapsed(75), "01:15")
  assert.equal(clock.formatElapsed(3675), "01:01:15")
})
