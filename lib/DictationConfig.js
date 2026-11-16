// How dictation is shown: "glow" lights up the focused window's frame,
// "pill" shows the compact waveform pill, "both" shows both.
var indicator = "glow"

// Logical sizes are scaled by Omarchy's Style.space() in the view components.
var barCount = 3
var barIntervalMs = 50
var processingCycleMs = 575
var animationTickMs = 16

var pillWidth = 72
var pillHeight = 36
var barWidth = 4
var barGap = 6
var minBarHeight = 3
var maxBarHeight = 24

var enterMs = 110
var transitionMs = 200
var exitMs = 140
var barEaseMs = 45
