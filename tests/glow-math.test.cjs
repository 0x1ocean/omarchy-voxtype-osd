const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")
const test = require("node:test")
const vm = require("node:vm")

const source = fs.readFileSync(path.join(__dirname, "..", "lib", "GlowMath.js"), "utf8")
const math = {}
vm.createContext(math)
vm.runInContext(source, math)

test("falloff is full at the corner and gone at the tip", () => {
  assert.equal(math.falloff(0), 1)
  assert.equal(math.falloff(1), 0)
  assert.ok(math.falloff(0.5) > 0.2 && math.falloff(0.5) < 0.23)
  assert.equal(math.falloff(-1), 1)
  assert.equal(math.falloff(2), 0)
})

test("approach is frame-rate independent", () => {
  let a = 0
  for (let i = 0; i < 60; i++) a = math.approach(a, 1, 0.1, 1 / 60)
  let b = 0
  for (let i = 0; i < 30; i++) b = math.approach(b, 1, 0.1, 1 / 30)
  assert.ok(Math.abs(a - b) < 1e-9)
})

test("voice rises faster than it falls", () => {
  const up = math.followVoice(0, 1, 1 / 60)
  const down = 1 - math.followVoice(1, 0, 1 / 60)
  assert.ok(up > down)
  assert.equal(math.followVoice(0.5, NaN, 1 / 60) < 0.5, true)
})

test("wave contour hugs the bottom and tapers to the tip", () => {
  const pts = math.waveContour(400, 30, 1000, 0, { points: 20 })
  assert.equal(pts.length, 21)
  assert.equal(pts[0].x, 0)
  assert.equal(pts[20].x, 400)
  assert.equal(pts[20].y, 1000)
  assert.ok(pts.every(p => p.y <= 1000))
  assert.ok(1000 - pts[0].y > 1000 - pts[15].y)
})

test("wave crest moves away from the corner as phase grows", () => {
  const crest = phase => {
    const pts = math.waveContour(2000, 40, 1000, phase, { points: 400, amplitude: 1 })
    // first local maximum of height after the corner region
    let best = 0
    for (let i = 5; i < 200; i++) if (1000 - pts[i].y > 1000 - pts[best].y || best === 0) best = i
    return pts[best].x
  }
  assert.ok(crest(0.1) > crest(0))
})
