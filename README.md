# DMS Theme Sync

**Cross-toolkit theme synchronization for [Dank Material Shell](https://danklinux.com/docs/dankmaterialshell).** DMS Theme Sync treats DMS as the single source of truth for appearance and propagates it to GTK, Qt, KDE and X11/XWayland applications — no wallpaper manager required.

It runs as a background **daemon**, adds an optional **bar widget**, and ships a standalone **configuration dialog**.

## Highlights

- **One place for everything.** The plugin UI mirrors every DMS appearance control — color theme, light/dark mode, Matugen palette & contrast, fonts, icons, cursor and cursor size — next to its own options, so you never jump between DMS Settings and the plugin.
- **Cross-toolkit.** GTK2/3/4, GNOME/GSettings, Qt5/6, KDE, Fontconfig, XSettings and XCursor.
- **Matugen-aware.** Reuses DMS's native Matugen output; never runs a second Matugen pass.
- **Safe by default.** Every apply takes a restorable snapshot first.
- **Detected dropdowns only.** No free-form theme/font fields; numeric sizes use sliders with reset buttons.

## What it propagates

| Area | Targets |
| --- | --- |
| **GTK** | `~/.gtkrc-2.0`, GTK3/GTK4 `settings.ini`, safe Matugen color import |
| **GNOME** | GSettings (theme, icons, cursor + size, fonts) and the portal color-scheme hint |
| **Qt5/Qt6** | `qt5ct`/`qt6ct` style, icons, fonts and the `DankMatugen.colors` palette |
| **KDE** | `kdeglobals`, `kcminputrc` |
| **Fontconfig** | `sans-serif`, `serif`, `monospace` aliases |
| **X11** | XSettings and XCursor defaults |
| **Session env** | `environment.d` — or a Niri KDL include (see [Niri](#niri)) |

> [!IMPORTANT]
> DMS generates the dynamic colors. Keep DMS's **GTK**, **qt5ct** and **qt6ct** Matugen templates enabled. The plugin consumes the resulting `dank-colors.css` and `DankMatugen.colors` and deliberately does **not** launch a second Matugen process — avoiding duplicate work and races during wallpaper changes.

## Install

```bash
git clone https://github.com/arqueon/dms-theme-sync.git \
  ~/.config/DankMaterialShell/plugins/dmsThemeSync
dms restart
```

Enable **DMS Theme Sync** in *DMS Settings → Plugins*. Add the **bar widget** from *DMS Settings → Bar → Add Widget* for quick access.

For local development:

```bash
ln -s ~/Projects/dms-theme-sync \
  ~/.config/DankMaterialShell/plugins/dmsThemeSync
dms ipc call plugins reload dmsThemeSync
```

## Configure

Open the dialog any of these ways:

- **Bar widget** — **left click** opens the dialog, **right click** applies immediately.
- **Keybind / IPC** — `dms ipc call dmsThemeSync configure`.
- **DMS Settings → Plugins → DMS Theme Sync.**

Controls that mirror DMS (color theme, light/dark, Matugen, fonts, icons, cursor) write the **canonical DMS settings** directly. Plugin-specific options — per-mode **GTK theme**, **font sizes**, **Qt policy** and **backups** — are stored by the plugin. All choices use detected dropdowns and bounded sliders; sliders have a reset-to-default button.

### IPC

```bash
dms ipc call dmsThemeSync apply
dms ipc call dmsThemeSync backup
dms ipc call dmsThemeSync restoreLatest
dms ipc call dmsThemeSync restore 20260628-182500
dms ipc call dmsThemeSync configure
dms ipc call dmsThemeSync status      # pretty-printed JSON
```

## Qt policy

The plugin **always** writes the `qt5ct`/`qt6ct` files (style, icons, fonts, `DankMatugen.colors`). The Qt policy only controls the **`QT_QPA_PLATFORMTHEME`** variable, which decides whether Qt apps actually obey those files.

- **Leave to my environment** *(default)* — the plugin does not touch the variable. Use this if you set it yourself (e.g. `/etc/environment`, `environment.d`, or your compositor config). This matches DMS, which never writes it either.
- **Plugin sets Follow GTK (`gtk3`)** — Qt apps follow the chosen GTK theme.
- **Plugin sets DMS palette (`qt5ct`/`qt6ct`)** — Qt apps use the `DankMatugen.colors` palette.

> [!NOTE]
> Environment changes only apply to **new** sessions: restart the apps and, usually, log out and back in.

### Niri

`environment.d` is read by the systemd session, **not** by Niri's `environment {}` block. On **Niri** the plugin instead writes the managed variables — cursor (`XCURSOR_*`/`HYPRCURSOR_*`) and, when you opt in, the Qt platform theme — to a generated include:

```text
~/.config/niri/dms-theme-sync.kdl
```

referenced once by an `include "dms-theme-sync.kdl"` line appended to the end of `~/.config/niri/environment.kdl`. The include is regenerated idempotently and the result is checked with `niri validate`; a failing change is rolled back. The plugin's `environment.d` file is **not** used on Niri, and any `QT_QPA_PLATFORMTHEME` you set inline in `environment.kdl` is left untouched.

## Backups & restore

Enabled by default. Before each apply, the plugin snapshots every file it may change, the relevant GSettings values, and the cursor/Qt session environment. Retention: **1–30** snapshots (default **10**).

```text
~/.local/state/DankMaterialShell/plugins/dmsThemeSync/backups/
```

Restore from the dialog's **backup-by-date** selector or via IPC. Restoring **disables auto-apply first** so the recovered state is not immediately overwritten; files that were absent when the snapshot was taken are removed.

```bash
scripts/theme-snapshot.sh list
scripts/theme-snapshot.sh backup --retention 10 --label manual
scripts/theme-snapshot.sh restore --snapshot latest
```

## Files the plugin owns

The helper makes **key-level, idempotent** edits; it never replaces whole GTK/Qt/KDE files. Files it creates:

- `~/.config/fontconfig/conf.d/99-dms-theme-sync.conf`
- `~/.config/environment.d/90-dms-theme-sync.conf` — non-Niri sessions
- `~/.config/niri/dms-theme-sync.kdl` — Niri sessions (plus one `include` line in `environment.kdl`)

The fontconfig and `environment.d` files are captured in snapshots (including their prior absence), so restore can remove them. The Niri include is regenerated on each apply and left in place to avoid a dangling `include`.

> [!TIP]
> `--dry-run` lists intended writes; `--no-runtime` writes only into the target HOME/XDG paths without calling GSettings, Fontconfig, XSettings, systemd or niri — intended for isolated tests.

## Optional packages

Everything degrades gracefully when a toolkit is missing. Install what you use:

- `gsettings`/`dconf` — GNOME settings and portal hints
- `qt5ct` and `qt6ct` (or `qt6ct-kde`) — Qt configuration
- `xsettingsd` — legacy X11/XWayland clients
- the selected GTK theme and its engine (e.g. the **Murrine** engine for GTK2 themes)

> [!NOTE]
> GTK4/libadwaita does not honor arbitrary `GTK_THEME` widget themes. DMS's generated GTK4 CSS stays the color source; the plugin still syncs fonts, icons, cursor and dark/light preference.

## Publishing

Push to `https://github.com/arqueon/dms-theme-sync`, copy `packaging/arqueon-dms-theme-sync.json` into the official registry's `plugins/` directory, run its validation commands, and open the pull request. Add a screenshot URL to that entry once the settings-page screenshot is available.

## License

[GPL-3.0-or-later](LICENSE)
