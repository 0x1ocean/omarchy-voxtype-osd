# Changelog

All notable changes to VoxWave are documented here.

## 0.4.0 — 2026-11-16

- Add the window glow indicator, now the default: the focused window's frame
  lights up from the bottom corners with a voice-driven wave, a transcribing
  runner, and a completion flash. Choose `glow`, `pill` or `both` with
  `indicator` in `lib/DictationConfig.js`.
- Follow focus through Quickshell's Hyprland IPC instead of spawning hyprctl,
  and render the blurred glow from a half-resolution bottom strip.
- Read daemon state from `voxtype status --follow`.

## 0.3.0 — 2026-09-29

- Refresh the release description and add a close-up screenshot of the real
  dictation indicator, including a root preview for the Omarchy marketplace.

- Separate meeting lifecycle from presentation and reconcile settled input snapshots.
- Preserve meeting clock checkpoints regardless of file-load order.
- Retry interrupted status/audio streams and settle stale dictation levels.
- Ignore partial meeting-state writes and cancel overlapping entrance/exit motion.
- Recover stalled audio processes and bound recorder shutdown time.
- Skip malformed transcripts without blocking other note exports.
- Add headless QML lifecycle and Quickshell I/O regression checks.

- Automatically export completed meetings to Markdown notes with timestamps and
  speakers, retry pending exports, and preserve user edits across reruns.

- Use a static accent marker for meeting status; remove simulated audio motion.
- Confirm meeting recording from a companion-recorder heartbeat and FFmpeg progress.
- Surface recorder crashes, stalled audio, and incomplete endings without a false Done.
- Keep the companion recorder and its service in the repository, with isolated lifecycle tests.

- Use the theme accent for dictation bars in both recording and processing.
- Give recording bars a wider height range and tune voice sensitivity while
  keeping the adaptive background-noise gate. Feed preview audio through the
  same level calculation as live recording.
- Use the same three bars for recording and processing, with a compact surface
  and a gentle staggered pulse during transcription.
- Scroll recorded audio from right to left.
- Advance the three recording bars every 50 ms and aggregate audio frames
  within each interval; run the processing pulse on a 575 ms cycle.
- Add a compact English meeting indicator with a pause-aware timer.
- Add restrained entrance and completion motion for the meeting indicator.
- Keep Omarchy's themed border while calming the entrance and processing motion.
- Keep the meeting timer aligned as status labels change.
- Restore meeting time after an Omarchy Shell restart.
- Separate Voxtype integration, state, timing, and presentation into components.
- Keep dictation dimensions and motion timing in one configuration module.
- Isolate development preview controls from the live panel composition.
- Keep live Voxtype status from interrupting a development preview, then
  restore the live state when the preview is hidden.
- Add shared surface styling and a single development check command.

## 0.2.0 — 2026-09-03

- Add a centred, mirrored live recording waveform.
- Add adaptive noise-floor gating and fast-attack/slow-release motion.
- Morph recording into a travelling theme-accent pulse while transcribing.
- Add a compact completion animation with no text or notification.
- Follow Omarchy surface, border, spacing, scale, and corner-radius tokens.
- Add unit tests and GitHub Actions.

## 0.1.0 — 2026-09-03

- Initial working Omarchy Shell plugin.
