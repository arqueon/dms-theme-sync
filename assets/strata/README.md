# Strata Matugen theme

Vendored from [`arqueon/strata-extras`](https://github.com/arqueon/strata-extras)
(`themes/matugen/strata-theme.toml`, MIT) for the
[Strata](https://github.com/lgse/strata) GTK 4 file manager.

## Setup

1. Copy (or link) `strata-theme.toml` to `~/.config/matugen/templates/strata-theme.toml`.
2. Add the Matugen output entry to `~/.config/matugen/config.toml`:

   ```toml
   [templates.strata]
   input_path = '~/.config/matugen/templates/strata-theme.toml'
   output_path = '~/.config/strata/themes/matugen.toml'
   ```

3. Run Matugen (or change wallpaper in Dux Shell) once, then choose **Matugen**
   in **Strata → Settings → Appearance**.

Strata watches `~/.config/strata/themes/` directly and repaints open windows on
its own whenever `matugen.toml` changes, so `apply-theme.sh` does not touch
Strata.
