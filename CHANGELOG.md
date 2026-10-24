# Change history

## 0.13.0 — 2026-10-22

- Support Dux Shell 2.0's third Material specification (`matugenSpec = "dms"`, the bold palette): the panel now offers Standard, Expressive and Bold, applies the 0..100 contrast range to both 2025 generators, and reports the value it reads instead of collapsing it to 2021.
- Mirror the new palette-source controls: source color mode, a read-only custom seed with a clear action, and smart mode (shown only when Dux's matugen reports smart support; turning it on switches off the time/location schedule, as Dux does). The scheme list follows Dux's own filter: Expressive and Bold only offer the 2025-capable schemes. Dux stays the generator; these write its settings and follow the result.
- Add Dux corner-style controls (Material scale / fixed radius, strength and fixed radius) without exporting shapes to GTK or Qt.
- Report Dux's Qt5ct/Qt6ct/Qt engine templates (`dmsQtTemplates`) and an active Qt engine (`qtengineActive`) through IPC `status` and the panel. Dux 2.0's qt5ct/qt6ct templates only write `colors/matugen.conf`, so they coexist with the palette the plugin sets.
- Hand the Qt palette to Dux only when its Qt engine is the active platform theme (it replaces qt5ct/qt6ct, so nobody else reads that palette): the plugin then stops rewriting it (and points a stale `DankUniform` back at Dux's scheme) while keeping style, fonts and icons. KDE colours stay with the plugin, because Dux re-applies its KColorScheme only on mode changes and `kdeglobals` would go stale between wallpapers. Uniform list backgrounds keep the plugin as owner in every case.
- Prefer Dux's per-mode KColorScheme (`DankMatugenDark`/`DankMatugenLight`) over the mode-agnostic file, so `kdeglobals` matches the scheme Dux applies.
- Follow Dux's font weight (OpenType 100-900) into Qt's legacy 0-99 scale (Qt's own mapping table: 400→50, 700→75) for Qt and KDE font strings. The document font still defaults to the regular font: Dux's `displayFontFamily` is a bundled headline face that GTK and Qt cannot resolve.
- Skip the legacy custom-theme re-export on 2.0: Dux already generates `dank-colors.css` from the theme's own colours, so forcing a second matugen run only raced the shell.
- Report radius, terminal opacity/palette and the extra palette fields through IPC `status`.
- Prefer `~/.local/state/dms` for snapshots, with the legacy `DankMaterialShell` path as fallback.
- Point `plugin.json` at the Dux schema URL and the `dependencies` field.
- Rename user-facing references from DMS to Dux (name, dialog, settings, docs). The plugin id `dmsThemeSync`, the `dms` CLI, `requires_dms` and the `~/.config/dms` paths stay unchanged so existing settings, IPC targets and installs keep working.

## 0.12.6 — 2026-10-02

- Limit DMS cursor `.Xresources.backup<TIMESTAMP>` copies to the configured backup retention (default 10), independently of named snapshots. Clean at startup and every minute while the plugin runs, including with automatic theme sync disabled.
- Preserve the active resource file, symlinks, directories and manually named backups; expose cleanup results through IPC status.

## 0.12.5 — 2026-10-02

- Explain Niri border color substitution accurately: the existing `dimNiriBorder` setting uses DMS's exported dark `primary_container` highlight. Expressive palettes may remain vivid; no fixed dimming amount is guaranteed. The color-selection behavior is unchanged.
- Rename the border control to “Niri border: use DMS highlight color” and add context for Expressive and disabled Niri exports.
- Report Material specification, scheme, contrast and export flags through IPC `status`.
- Correct README template dependencies, distinguish Material specification from scheme, and document DMS 1.7 coverage and remaining integration work.

## 0.12.4

- Preserve the existing GTK animation accessibility preference during apply and restore.

## 0.12.3

- Add Standard/Expressive Material specification controls and match DMS's Expressive contrast range.
- Warn when relevant DMS color exports are disabled.

## 0.12.2

- Align the plugin's bar icon and controls with DMS theme and bar sizing.

## 0.12.1

- Expand backup coverage for managed theme and session configuration.

## 0.12.0

- Support separate light and dark icon themes and Papirus overlay bases.

Earlier changes remain available in the Git history.
