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

test("creates a full left-to-right recording history", () => {
  const history = math.createHistory(3, 0.04)
  assert.equal(history.length, 3)
  assert.ok(history.every(value => value === 0.04))
})

test("pushes the newest sample to the right without growing history", () => {
  const history = math.pushHistory([0.1, 0.2, 0.3], 0.9)
  assert.deepEqual(Array.from(history), [0.2, 0.3, 0.9])
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

test("separates background noise, ordinary speech, and louder speech", () => {
  const noise = math.frameEnergy(0.025, 0.04, 0.04, 0.04)
  const ordinary = math.frameEnergy(0.1, 0.25, 0.04, 0.04)
  const loud = math.frameEnergy(0.2, 0.5, 0.04, 0.04)

  assert.ok(noise.target < 0.08)
  assert.ok(ordinary.target > noise.target + 0.3)
  assert.ok(loud.target > ordinary.target + 0.4)
})

test("uses a faster attack than release", () => {
  const attackDelta = math.smoothEnergy(0.1, 0.9) - 0.1
  const releaseDelta = 0.9 - math.smoothEnergy(0.9, 0.1)
  assert.ok(attackDelta > releaseDelta)
})

test("moves a recorded peak from right to left as new samples arrive", () => {
  let history = [0.04, 0.04, 0.9]
  assert.equal(math.recordingLevel(2, 3, history, 0.04), 0.9)
  history = math.pushHistory(history, 0.2)
  assert.equal(math.recordingLevel(1, 3, history, 0.04), 0.9)
  history = math.pushHistory(history, 0.3)
  assert.equal(math.recordingLevel(0, 3, history, 0.04), 0.9)
})

test("processing animates the same three bars with staggered heights", () => {
  const levels = Array.from({ length: 3 }, (_, index) =>
    math.processingLevel(index, 3, 0, 0.04)
  )

  assert.equal(levels.length, 3)
  assert.ok(levels.every(value => value > 0.04 && value < 0.6))
  assert.ok(new Set(levels).size === 3)
  assert.notEqual(math.processingLevel(0, 3, 0, 0.04), math.processingLevel(0, 3, 0.25, 0.04))
  assert.ok(Array.from({ length: 3 }, (_, index) =>
    math.processingOpacity(index, 3, 0)).every(value => value >= 0.7 && value <= 1))
})

test("transition moves from recording heights to processing heights", () => {
  assert.equal(math.mixLevel(0.8, 0.3, 0), 0.8)
  assert.equal(math.mixLevel(0.8, 0.3, 1), 0.3)
})
