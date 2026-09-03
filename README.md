# Omarchy Voxtype OSD

A compact, text-free dictation waveform for [Omarchy](https://omarchy.org/)
and [Voxtype](https://voxtype.io/).

The plugin runs inside Omarchy Shell and follows the active theme automatically:
background, popup border, accent color, recording color, spacing, scale, and
corner radius all come from Omarchy's shared design tokens.

## Experience

- A noise-gated live waveform grows from the centre while recording.
- Fast attack and soft release keep it responsive without looking nervous.
- The last audio shape morphs into a travelling accent pulse while Voxtype
  is transcribing.
- The waveform settles into a line and fades when the result is ready.
- No labels, transcript previews, notifications, or input-blocking surfaces.

## Requirements

- Omarchy Shell
- Voxtype 1.0 or newer
- `voxtype-audio-bridge` from the Voxtype package

## Install

Once the repository is published:

```bash
omarchy plugin add https://github.com/0x1ocean/omarchy-voxtype-osd --enable
```

Disable Voxtype's own OSD and notifications to avoid duplicate feedback:

```bash
voxtype config set osd.enabled false
voxtype config set output.notification.on_recording_start false
voxtype config set output.notification.on_recording_stop false
voxtype config set output.notification.on_transcription false
systemctl --user restart voxtype.service
```

## Local development

```bash
ln -s "$PWD" ~/.config/omarchy/plugins/io.github.0x1ocean.voxtype-osd
omarchy-shell shell rescanPlugins
omarchy plugin enable io.github.0x1ocean.voxtype-osd
```

Preview either state without recording audio:

```bash
omarchy-shell voxtype-osd preview recording
omarchy-shell voxtype-osd preview transcribing
omarchy-shell voxtype-osd hide
```

## License

MIT
