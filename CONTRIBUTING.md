# Contributing

Issues and focused pull requests are welcome.

## Development

1. Install Voxtype and enable its state file.
2. Link the checkout into Omarchy Shell:

   ```bash
   ln -s "$PWD" ~/.config/omarchy/plugins/io.github.0x1ocean.voxtype-osd
   omarchy plugin enable io.github.0x1ocean.voxtype-osd
   omarchy restart shell
   ```

3. Run the tests and manifest validation:

   ```bash
   npm run check
   ```

4. Preview the visual states:

   ```bash
   omarchy-shell voxtype-osd preview recording
   omarchy-shell voxtype-osd preview transcribing
   omarchy-shell voxtype-osd preview meeting
   omarchy-shell voxtype-osd preview paused
   omarchy-shell voxtype-osd preview meeting-starting
   omarchy-shell voxtype-osd preview meeting-finishing
   omarchy-shell voxtype-osd preview meeting-done
   omarchy-shell voxtype-osd preview meeting-error
   omarchy-shell voxtype-osd hide
   ```

   `preview recording` feeds a repeating sample signal into the waveform, so
   its right-to-left movement can be checked without microphone input. Let it
   run for a few seconds, then use `preview transcribing` to inspect the three
   bars changing to a processing pulse.

   Tune the scroll cadence, processing cycle, and pill dimensions in
   `lib/DictationConfig.js`. Both live audio and the preview use its cadence.

`DictationOsd.qml` composes the panel. Keep Voxtype reads in `VoxtypeBridge`,
state and time in the session components, meeting feedback in `MeetingPresentation`,
appearance in the pill components,
and pure calculations in `lib/`. Meeting labels use English by default. Keep
the overlay click-through, theme-aware, and inexpensive while hidden. Avoid
hard-coded theme colors and edits under `/usr/share/omarchy`.

`npm run test:qml` exercises lifecycle transitions in Qt 6's `qmltestrunner`
and FileView/process integration in a separate, headless Quickshell instance.
It needs QtTest, qmltestrunner, and Quickshell installed. The runner creates
disposable clock checkpoints and never starts Voxtype or accesses audio devices.
`npm run check` includes these tests; CI runs the portable JS/Python tests.

Apply state changes only after related QML bindings settle. Do not interpret
partial meeting-state writes as completion, erase clock checkpoints before the
first live state arrives, or leave status/audio streams stopped after an exit.

Meeting recorder tests use isolated runtime/data directories and fake audio
processes; they never access the microphone. They require `inotify-tools` and
`flock`. Keep health decisions in `MeetingStatus.js` and recorder progress in
the companion script. A successful process launch alone must never produce
`Recording` or `Done`. Preview `meeting-done` after `meeting` or `meeting-finishing`
to inspect completion; after `meeting-error` it correctly shows `Check audio`.

The meeting note exporter uses Python 3.11+ and the standard library.
`npm test` also runs its Python tests against temporary databases and notes.
Export only completed transcripts; preserve note edits and retry failed writes.

After changing QML in a symlinked checkout, run `omarchy restart shell` if the
plugin watcher does not reload it. Check `journalctl --user` for QML warnings.
