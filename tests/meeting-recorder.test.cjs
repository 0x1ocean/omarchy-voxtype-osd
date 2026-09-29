const assert = require("node:assert/strict")
const fs = require("node:fs/promises")
const os = require("node:os")
const path = require("node:path")
const { spawn } = require("node:child_process")
const test = require("node:test")
const delay = ms => new Promise(resolve => setTimeout(resolve, ms))

async function recorderFixture(t, initialState = "idle") {
  const dir = await fs.mkdtemp(path.join(os.tmpdir(), "voxwave-recorder-test-"))
  const bin = path.join(dir, "bin")
  const runtime = path.join(dir, "runtime/voxtype")
  const audio = path.join(dir, "data/voxtype/meeting-audio")
  await fs.mkdir(bin, { recursive: true })
  await fs.mkdir(runtime, { recursive: true })
  if (initialState !== "idle") {
    await fs.writeFile(path.join(runtime, "meeting_state"), `${initialState}\n11111111-1111-1111-1111-111111111111\n`)
  }
  await fs.writeFile(path.join(bin, "pactl"), "#!/bin/sh\nprintf 'test-device\\n'\n", { mode: 0o755 })
  await fs.writeFile(path.join(bin, "ffmpeg"), `#!/usr/bin/env node
const fs = require('node:fs')
const args = process.argv.slice(2)
const progress = args[args.indexOf('-progress') + 1]
const output = args[args.length - 1]
let time = 0
fs.writeFileSync(output, 'test recording')
setInterval(() => {
  if (fs.existsSync(process.env.TEST_RECORDER_FAULT + '/crash')) process.exit(1)
  if (fs.existsSync(process.env.TEST_RECORDER_FAULT + '/stall')) return
  time += 100000
  fs.appendFileSync(progress, 'out_time_us=' + time + '\\nprogress=continue\\n')
}, 100)
process.on('SIGTERM', () => {
  if (!fs.existsSync(process.env.TEST_RECORDER_FAULT + '/hang-on-stop')) process.exit(0)
})
`, { mode: 0o755 })
  const child = spawn("bash", [path.join(__dirname, "../scripts/voxtype-meeting-audio")], {
    detached: true,
    env: { ...process.env, PATH: `${bin}:${process.env.PATH}`, TEST_RECORDER_FAULT: dir,
      XDG_RUNTIME_DIR: path.join(dir, "runtime"), XDG_DATA_HOME: path.join(dir, "data") },
    stdio: ["ignore", "pipe", "pipe"]
  })
  let logs = ""
  child.stdout.on("data", data => { logs += data })
  child.stderr.on("data", data => { logs += data })
  t.after(async () => {
    try { process.kill(-child.pid, "SIGTERM") } catch {}
    for (let i = 0; i < 20 && child.exitCode === null; i++) await delay(50)
    try { process.kill(-child.pid, "SIGKILL") } catch {}
    await fs.rm(dir, { recursive: true, force: true })
  })
  async function waitFor(state, predicate = () => true, timeout = 5000) {
    const deadline = Date.now() + timeout
    let data
    while (Date.now() < deadline) {
      try { data = JSON.parse(await fs.readFile(path.join(runtime, "meeting-audio/status.json"), "utf8")) } catch {}
      if (data?.state === state && predicate(data)) return data
      await delay(50)
    }
    assert.fail(`Expected ${state}; got ${JSON.stringify(data)}\n${logs}`)
  }
  async function state(value, id = "11111111-1111-1111-1111-111111111111") {
    await fs.writeFile(path.join(runtime, "next-state"), `${value}\n${id}\n`)
    await fs.rename(path.join(runtime, "next-state"), path.join(runtime, "meeting_state"))
  }
  await waitFor(initialState)
  return { dir, runtime, audio, state, waitFor }
}

test("recorder confirms progress, splits paused calls, and closes before completion", async t => {
  const r = await recorderFixture(t)
  await r.state("recording")
  await r.waitFor("recording")
  await r.state("paused")
  await r.waitFor("paused")
  assert.equal((await fs.readdir(r.audio)).length, 1)
  await r.state("recording")
  await r.waitFor("recording")
  assert.equal((await fs.readdir(r.audio)).length, 2)
  await fs.writeFile(path.join(r.runtime, "meeting_stop"), "")
  await r.waitFor("finishing")
  await r.state("idle")
  const done = await r.waitFor("done")
  assert.equal(done.hadError, false)
})

test("a crashed recorder retries but retains the failure for the final result", async t => {
  const r = await recorderFixture(t)
  await fs.writeFile(path.join(r.dir, "crash"), "")
  await r.state("recording")
  await r.waitFor("error")
  await fs.unlink(path.join(r.dir, "crash"))
  await r.waitFor("recording", data => data.hadError)
  await r.state("idle")
  await r.waitFor("error", data => data.hadError)
})

test("an alive process without advancing audio is reported as an error", async t => {
  const r = await recorderFixture(t)
  await fs.writeFile(path.join(r.dir, "stall"), "")
  await r.state("recording")
  await r.waitFor("starting")
  await r.waitFor("error", data => data.hadError, 11000)
  await fs.unlink(path.join(r.dir, "stall"))
  await r.waitFor("recording", data => data.hadError && data.hasAudio)
  assert.equal((await fs.readdir(r.audio)).length, 2)
})

test("a recorder ignoring termination cannot block stop forever or report success", async t => {
  const r = await recorderFixture(t)
  await fs.writeFile(path.join(r.dir, "hang-on-stop"), "")
  await r.state("recording")
  await r.waitFor("recording")
  await r.state("idle")
  await r.waitFor("error", data => data.hadError, 6000)
})

test("joining an already recording meeting preserves the possible gap in its outcome", async t => {
  const r = await recorderFixture(t, "recording")
  await r.waitFor("recording", data => data.hadError && data.hasAudio)
  await r.state("idle")
  await r.waitFor("error", data => data.hadError)
})
