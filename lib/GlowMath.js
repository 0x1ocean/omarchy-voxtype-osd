// Pure math for the window glow. Kept free of QML so it can be unit-tested.

function clamp(value, minimum, maximum) {
  return Math.max(minimum, Math.min(maximum, value))
}

// Eased falloff used by every glow gradient: 1 at the corner, 0 at the tip.
function falloff(position) {
  return Math.pow(1 - clamp(position, 0, 1), 2.2)
}

// Frame-rate independent approach of `current` towards `target`.
// `rate` is the fraction covered per 1/60 s.
function approach(current, target, rate, dt) {
  var k = 1 - Math.pow(1 - rate, Math.max(0, dt) * 60)
  return current + (target - current) * k
}

// Voice energy from an audio level (already noise-gated, 0..1), with a
// fast attack and a slow release so the glow glides instead of jumping.
function followVoice(current, level, dt) {
  var target = clamp(Number(level) || 0, 0, 1)
  return approach(current, target, target > current ? 0.18 : 0.04, dt)
}

// Top edge of a bottom wave band as a list of {x, y} points, starting at the
// corner (x = 0) and ending at the tip (x = length). `height` is the band
// thickness at the corner, `bottom` the y of the window's bottom edge.
// The crest moves away from the corner as `phase` grows.
function waveContour(length, height, bottom, phase, options) {
  var opts = options || {}
  var points = opts.points || 24
  var wavelength = opts.wavelength || 230
  var amplitude = opts.amplitude === undefined ? 0.3 : opts.amplitude
  var offset = opts.offset || 0
  var span = Math.max(1, length)
  var contour = []

  for (var i = 0; i <= points; i++) {
    var u = i / points
    var x = span * u
    var taper = Math.pow(1 - u, 1.8)
    var a = 6.283185 * (x / wavelength - phase) + offset
    var wave = 0.8 * Math.sin(a) + 0.2 * Math.sin(0.5 * a + 1.1)
    var h = height * taper * (1 + amplitude * wave) + (1 - u)
    contour.push({ x: x, y: bottom - Math.max(0, h) })
  }
  return contour
}
