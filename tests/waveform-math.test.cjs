const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")
const test = require("node:test")
const vm = require("node:vm")

const source = fs.readFileSync(
  path.join(__dirname, "..", "lib", "WaveformMath.js"),
  "utf8"
)
const math = {}
vm.createContext(math)
vm.runInContext(source, math)

test("creates one half of a mirrored history", () => {
  const history = math.createHistory(29, 0.04)
  assert.equal(history.length, 15)
  assert.ok(history.every(value => value === 0.04))
})

test("pushes the newest sample without growing history", () => {
  const history = math.pushHistory([0.1, 0.2, 0.3], 0.9)
  assert.deepEqual(Array.from(history), [0.9, 0.1, 0.2])
})

test("keeps quiet input close to the baseline", () => {
  const frame = math.frameEnergy(0.02, 0.03, 0.04, 0.04)
  assert.ok(frame.target >= 0.04)
  assert.ok(frame.target < 0.08)
})

test("maps clear speech to a visibly stronger target", () => {
  const quiet = math.frameEnergy(0.02, 0.03, 0.04, 0.04)
  const speech = math.frameEnergy(0.3, 0.65, 0.04, 0.04)
  assert.ok(speech.target > quiet.target + 0.5)
})

test("uses a faster attack than release", () => {
  const attackDelta = math.smoothEnergy(0.1, 0.9) - 0.1
  const releaseDelta = 0.9 - math.smoothEnergy(0.9, 0.1)
  assert.ok(attackDelta > releaseDelta)
})

test("mirrors recording levels around the centre", () => {
  const history = [0.9, 0.7, 0.5, 0.3]
  assert.equal(
    math.recordingLevel(13, 29, history, 0.04),
    math.recordingLevel(15, 29, history, 0.04)
  )
  assert.equal(math.recordingLevel(14, 29, history, 0.04), 0.9)
})

test("moves the processing pulse across the waveform", () => {
  const early = Array.from({ length: 29 }, (_, index) =>
    math.processingLevel(index, 29, 0.25)
  )
  const late = Array.from({ length: 29 }, (_, index) =>
    math.processingLevel(index, 29, 0.75)
  )

  assert.ok(early.indexOf(Math.max(...early)) < late.indexOf(Math.max(...late)))
})

test("mix and finish reach exact endpoints", () => {
  assert.equal(math.mixedLevel(0.8, 0.2, 0, 0, 0.04), 0.8)
  assert.equal(math.mixedLevel(0.8, 0.2, 1, 0, 0.04), 0.2)
  assert.equal(math.mixedLevel(0.8, 0.2, 1, 1, 0.04), 0.04)
})
