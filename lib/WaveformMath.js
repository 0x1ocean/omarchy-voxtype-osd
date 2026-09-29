function clamp(value, minimum, maximum) {
  return Math.max(minimum, Math.min(maximum, value))
}

function createHistory(barCount, baseline) {
  var history = []
  for (var i = 0; i < barCount; i++) history.push(baseline)
  return history
}

function frameEnergy(rms, peak, noiseFloor, baseline) {
  var raw = clamp(Number(rms) * 0.72 + Number(peak) * 0.28, 0, 1)
  var floorSpeed = raw < noiseFloor ? 0.12 : 0.006
  var nextFloor = noiseFloor + (raw - noiseFloor) * floorSpeed
  // Keep room noise below the gate, while letting normal speech use most of the bar height.
  var threshold = Math.min(0.30, nextFloor * 1.4 + 0.006)
  var gated = Math.max(0, (raw - threshold) / Math.max(0.12, 0.30 - threshold))
  var compressed = Math.pow(Math.min(1, gated), 0.8)

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

  var next = []
  for (var i = 1; i < history.length; i++) next.push(history[i])
  next.push(value)
  return next
}

function recordingLevel(index, barCount, history, baseline) {
  if (index < 0 || index >= barCount || !history || index >= history.length) return baseline
  return clamp(Number(history[index]) || 0, baseline, 1)
}

function processingWave(index, barCount, phase) {
  return (Math.sin(2 * Math.PI * (phase - index / barCount)) + 1) / 2
}

function processingLevel(index, barCount, phase, baseline) {
  return baseline + (1 - baseline) * (0.18 + processingWave(index, barCount, phase) * 0.36)
}

function processingOpacity(index, barCount, phase) {
  return 0.7 + processingWave(index, barCount, phase) * 0.3
}

function mixLevel(recorded, processing, progress) {
  var mix = clamp(progress, 0, 1)
  return recorded * (1 - mix) + processing * mix
}
