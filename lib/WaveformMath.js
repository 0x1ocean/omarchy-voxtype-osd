function clamp(value, minimum, maximum) {
  return Math.max(minimum, Math.min(maximum, value))
}

function createHistory(barCount, baseline) {
  var history = []
  var length = Math.floor(barCount / 2) + 1
  for (var i = 0; i < length; i++) history.push(baseline)
  return history
}

function frameEnergy(rms, peak, noiseFloor, baseline) {
  var raw = clamp(Number(rms) * 0.72 + Number(peak) * 0.28, 0, 1)
  var floorSpeed = raw < noiseFloor ? 0.12 : 0.006
  var nextFloor = noiseFloor + (raw - noiseFloor) * floorSpeed
  var threshold = Math.min(0.30, nextFloor * 1.65 + 0.008)
  var gated = Math.max(0, (raw - threshold) / Math.max(0.15, 0.55 - threshold))
  var compressed = Math.pow(Math.min(1, gated), 0.65)

  return {
    noiseFloor: nextFloor,
    target: baseline + compressed * (1 - baseline)
  }
}

function smoothEnergy(current, target) {
  var smoothing = target > current ? 0.55 : 0.21
  return current + (target - current) * smoothing
}

function pushHistory(history, value) {
  if (!history || history.length === 0) return [value]

  var next = [value]
  for (var i = 0; i < history.length - 1; i++) next.push(history[i])
  return next
}

function recordingLevel(index, barCount, history, baseline) {
  var centre = Math.floor(barCount / 2)
  var distance = Math.abs(index - centre)
  if (!history || distance >= history.length) return baseline

  var level = clamp(Number(history[distance]) || 0, baseline, 1)
  var age = distance / Math.max(1, history.length - 1)
  return baseline + (level - baseline) * (1 - age * 0.38)
}

function processingLevel(index, barCount, phase) {
  var position = -4 + phase * (barCount + 8)
  var distance = index - position
  var pulse = Math.exp(-(distance * distance) / 9)
  return Math.min(1, 0.10 + pulse * 0.84)
}

function mixedLevel(recorded, processing, processingMix, finishProgress, baseline) {
  var mix = clamp(processingMix, 0, 1)
  var finish = clamp(finishProgress, 0, 1)
  var level = recorded * (1 - mix) + processing * mix
  return level * (1 - finish) + baseline * finish
}
