const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const test = require('node:test')
const vm = require('node:vm')
const protocol = {}
vm.createContext(protocol)
vm.runInContext(fs.readFileSync(path.join(__dirname, '../lib/VoxtypeProtocol.js'), 'utf8'), protocol)
const id = '11111111-1111-1111-1111-111111111111'

test('partial meeting writes never become false completion events', () => {
  for (const raw of ['', 'recording', 'recording\n1111', 'paused\n', 'unknown\n' + id])
    assert.equal(protocol.meetingState(raw), null)
  assert.equal(protocol.meetingState(`recording\n${id}\n`).id, id)
  assert.equal(protocol.meetingState(`paused\n${id}`).state, 'paused')
  assert.equal(protocol.meetingState('idle').state, 'idle')
})
