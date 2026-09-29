const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")
const test = require("node:test")
const vm = require("node:vm")
const status = {}
vm.createContext(status)
vm.runInContext(fs.readFileSync(path.join(__dirname, "../lib/MeetingStatus.js"), "utf8"), status)

test("recording requires fresh recorder progress for the same meeting", () => {
  const data = { id: "meeting-1", state: "recording", updatedAtMs: 10000 }
  assert.equal(status.recorderHealth(data, "meeting-1", 12000), "recording")
  assert.equal(status.recorderHealth(data, "meeting-2", 12000), "unavailable")
  assert.equal(status.recorderHealth(data, "meeting-1", 15000), "unavailable")
  assert.equal(status.recorderHealth({ ...data, updatedAtMs: "bad" }, "meeting-1", 12000), "unavailable")
})

test("startup and pause wait for recorder confirmation; failures stay visible", () => {
  assert.equal(status.displayState("recording", false, "starting", 1000), "starting")
  assert.equal(status.displayState("recording", false, "recording", 20000), "recording")
  assert.equal(status.displayState("paused", false, "recording", 1000), "pausing")
  assert.equal(status.displayState("paused", false, "paused", 20000), "paused")
  assert.equal(status.displayState("recording", false, "unavailable", 9000), "error")
  assert.equal(status.displayState("recording", false, "error", 100), "error")
  assert.equal(status.displayState("recording", true, "finishing", 20000), "finishing")
})

test("completion waits for a clean recorder close and never hides an earlier failure", () => {
  assert.equal(status.completionState("finishing", false, 1000), "finishing")
  assert.equal(status.completionState("done", false, 1000), "finished")
  assert.equal(status.completionState("done", true, 1000), "failed")
  assert.equal(status.completionState("error", false, 1000), "failed")
  assert.equal(status.completionState("unavailable", false, 7000), "failed")
})
