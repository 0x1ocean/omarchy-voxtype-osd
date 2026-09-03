# Contributing

Issues and focused pull requests are welcome.

## Development

1. Install Voxtype and enable its state file.
2. Link the checkout into Omarchy Shell:

   ```bash
   ln -s "$PWD" ~/.config/omarchy/plugins/io.github.0x1ocean.voxtype-osd
   omarchy-shell shell rescanPlugins
   omarchy plugin enable io.github.0x1ocean.voxtype-osd
   ```

3. Run the tests:

   ```bash
   npm test
   omarchy plugin validate "$PWD"
   ```

4. Preview the visual states:

   ```bash
   omarchy-shell voxtype-osd preview recording
   omarchy-shell voxtype-osd preview transcribing
   omarchy-shell voxtype-osd hide
   ```

Keep the overlay text-free, click-through, theme-aware, and inexpensive while
hidden. Avoid hard-coded theme colors and edits under `/usr/share/omarchy`.
