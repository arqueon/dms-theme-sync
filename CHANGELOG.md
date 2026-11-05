# Change history

## 0.15.0 — 2026-11-05

- Achieve **live hot-reload of accent-colored folder icons (`*-DankFolders`)** in running KDE, Qt 5/6, and GTK 3/4 applications (`krusader`, `dolphin`, `thunar`, `nautilus`, etc.) on every wallpaper or Matugen accent change without restarting the application:
  - Maintain a hidden dot-prefixed alias symlink `~/.local/share/icons/.<overlay>-<color> -> <overlay>` (e.g. `.Papirus-Dark-DankFolders-green -> Papirus-Dark-DankFolders`) and write `icon_theme=.<overlay>-<color>` to `qt5ct.conf` and `qt6ct.conf` while keeping `kdeglobals`, GSettings, and Dux `SettingsData.iconTheme` pointed at `<overlay>`. Because the symlink starts with `.`, icon pickers (`KIconTheme::list()`, `discoveredIconThemes`) and Dux's `checkIconThemeDrift()` ignore it, while `QIcon::themeName()` changes whenever the folder accent color changes — clearing both Qt's `QIconLoader` cache and Krusader's private static `IconEngine` `QCache` (`s_cache`).
  - Include the active folder overlay signature (`<source>:<color>`) in the content hash for `~/.local/share/color-schemes/.dms-live/<scheme>-<sha8>.colors` so a folder-color change always rotates `color_scheme_path=` in `qt5ct.conf` / `qt6ct.conf` and triggers `QEvent::PaletteChange`.
  - Read the live primary accent directly from `--kvantum-colors` (`Theme.primary`) during runtime applies so folder and cursor accent selection never lags behind an asynchronous `gtk-4.0/dank-colors.css` write.
  - Update the GTK icon cache (`gtk-update-icon-cache`) on the generated overlay, pulse `org.gnome.desktop.interface icon-theme` in `scripts/reload-application-theme.sh` when a `*-DankFolders` overlay is active, and re-emit `KIconLoader.iconChanged` right before (`2.5s`) and right after (`3.2s`) `qt6ct`'s `3000 ms` `QTimer` window so `KIconLoader`'s process-local `imgDict` is empty at the exact moment `DolphinView` and `KrView` process `QEvent::PaletteChange`.
- Match Dux 2.1's `SettingsData.resolveIconTheme()` contract in `ThemeSyncService.qml` (`lightIconMode = iconThemePerMode && colorMode === "light"`), ensuring light-mode icon overlay reconciliation writes to `iconThemeLight` only when separate per-mode icon themes are enabled.

## 0.14.0 — 2026-11-04

- Achieve reliable **live Qt/KDE palette hot-reload** across running Qt 5/6 and KDE Frameworks applications (`dolphin`, `krusader`, `okular`, etc.) on every wallpaper or Matugen palette change without restarting the application:
  - Stage a content-hashed live copy of the active `.colors` file under `~/.local/share/color-schemes/.dms-live/<scheme>-<sha8>.colors` and point `qt5ct.conf` / `qt6ct.conf` `color_scheme_path=` at that path. `qt6ct-kde` loads the scheme through `KSharedConfig::openConfig(path)`, which caches parsed `KSharedConfig` instances per thread by canonical file path and never calls `reparseConfiguration()` when the same path is rewritten in place; changing the filename on content change forces a fresh read on every `ThemeChange` event while pruning older hashes for the same scheme stem.
  - Automatically unpin `ColorScheme=Dank*` from per-application KDE configs (`~/.config/*rc` such as `dolphinrc` and `okularrc`) while `syncKde` is enabled. When a KDE app has an explicit `ColorScheme=DankMatugen` entry in its own `*rc`, `KColorSchemeManager` activates that named scheme instead of following `System Default` (`kdeglobals`) and suffers from the same `KSharedConfig` path cache.
  - Pulse a transient file (`.dms-reload-$$`) inside `~/.config/qt5ct` and `~/.config/qt6ct` in `scripts/reload-application-theme.sh`. `qt5ct` and `qt6ct` register their config directory with `QFileSystemWatcher::addPath(dir)` and listen to `directoryChanged`, which `touch` on a symlinked `qtXct.conf` (e.g. managed by `lnk` or Stow) does not trigger.
  - Wait briefly in `scripts/apply-theme.sh` (`wait_for_dms_matugen_export`) when Dux's asynchronous `matugen` worker has not yet finished writing `dank-colors.css` and `DankMatugen*.colors`, and schedule a single automatic catch-up pass in `ThemeSyncService.qml` (accelerated via `Theme.matugenCompleted` on Dux 2.1) if the export finishes after the initial apply.
- Skip rebuilding the Papirus `*-DankFolders` symlink tree (~1,500 symlinks) when `X-DmsThemeSync-Signature` (`<base>:<color>`) in `index.theme`already matches and no broken symlinks exist, cutting no-op apply latency from ~2.7 s to ~0.2 s.
- Support **Dux Shell 2.1.0**:
  - Pulse `org.gnome.desktop.a11y.interface reduced-motion` in `scripts/reload-application-theme.sh` so running **GTK 4.22+** applications re-parse `~/.config/gtk-4.0/gtk.css` (`@import url("dank-colors.css");`) in hot during manual applies and snapshot restores, matching Dux 2.1's `matugen` worker.
  - Sanitize `~/.config/gtk-3.0/icon-theme.dms-backup` (introduced in Dux 2.1) by stripping any `-DankFolders` suffix so Dux 2.1's "System Default" icon restore always points to the underlying base theme rather than a deleted overlay.
  - Connect to `Theme.matugenCompleted(mode, result)` in `ThemeSyncService.qml` so any pending post-export retry runs as soon as Dux 2.1's `matugen` worker exits.
  - Mirror Dux 2.1's shell appearance controls in `ThemeSyncSettings.qml` when supported by the running shell (`Interface style`: Expressive vs Classic, `Interface density`, and `Section dividers` opacity) and expose `dms21`, `interfaceStyle`, `density`, `sectionDividerOpacity`, and `tooltipSurfaceColor` in IPC `status`.
- Add the **Terminal ANSI palette** selector (`SettingsData.terminalPalette`: *Tonal — distinct ANSI colors* vs *Vibrant — shift ANSI accents toward primary*) under *Dux appearance* so users can keep red/green/yellow/blue ANSI colors distinct in terminal applications (`kitty`, `herdr`, `alacritty`, `ghostty`, `foot`, `wezterm`).

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
