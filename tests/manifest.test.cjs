const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")
const test = require("node:test")

const root = path.join(__dirname, "..")
const manifest = JSON.parse(fs.readFileSync(path.join(root, "manifest.json"), "utf8"))

test("manifest exposes a persistent panel entry point", () => {
  assert.equal(manifest.schemaVersion, 1)
  assert.equal(manifest.id, "io.github.0x1ocean.voxtype-osd")
  assert.ok(manifest.kinds.includes("panel"))
  assert.equal(manifest.keepLoaded, true)
  assert.ok(fs.existsSync(path.join(root, manifest.entryPoints.panel)))
})

test("manifest version matches package metadata", () => {
  const pkg = JSON.parse(fs.readFileSync(path.join(root, "package.json"), "utf8"))
  assert.equal(manifest.version, pkg.version)
})
