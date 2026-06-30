# DMS Theme Sync

**Cross-toolkit theme synchronization for [Dank Material Shell](https://danklinux.com/docs/dankmaterialshell).** DMS Theme Sync treats DMS as the single source of truth for appearance and propagates it to GTK, Qt, KDE and X11/XWayland applications — no wallpaper manager required.

It runs as a background **daemon**, adds an optional **bar widget**, and ships a standalone **configuration dialog**.

<img width="809" height="930" alt="1782710026434229332" src="https://github.com/user-attachments/assets/14829950-5538-4334-8222-ec9ca35233c2" />

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
| **Session env** | `environment.d` + live systemd user env — or a Niri KDL include (see [Compositors](#compositors)) |

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

### Compositors

Only the **session-environment** variables — cursor (`XCURSOR_*`/`HYPRCURSOR_*`) and, when you opt in, the Qt platform theme — depend on the compositor. Everything else (GTK, Qt, KDE, Fontconfig, GSettings, XSettings) is compositor-agnostic and applies identically everywhere.

The plugin detects the running compositor (via DMS's `CompositorService`) and always refreshes the **live** systemd user environment (`systemctl --user set-environment`) so apps launched after an apply pick up the new values immediately. The persistent env is written per compositor:

- **Niri** — `environment.d` is read by the systemd session, **not** by Niri's `environment {}` block, so on Niri the plugin writes a generated KDL include:

  ```text
  ~/.config/niri/dms-theme-sync.kdl
  ```

  referenced once by an `include "dms-theme-sync.kdl"` line appended to `~/.config/niri/environment.kdl` — or to `config.kdl` if your config is not split into includes. The include is regenerated idempotently and checked with `niri validate`; a failing change is rolled back. The `environment.d` file is **not** used on Niri, and any `QT_QPA_PLATFORMTHEME` you set inline in `environment.kdl` is left untouched.

- **Hyprland** — a generated include `source`d once from your main config, written in whichever format you actually use (Hyprland 0.55 switched from hyprlang to Lua, both still supported):
  - `~/.config/hypr/dms-theme-sync.conf` (`env = …`) sourced from `hyprland.conf`, **and/or**
  - `~/.config/hypr/dms-theme-sync.lua` (`hl.env(…)`) `require()`d from `hyprland.lua`.

  The plugin only writes the format whose main config exists and never creates a main config, so a Lua-only setup never gets a hyprlang file and vice-versa.

- **labwc** — a delimited block (your other lines untouched) in labwc's native env file:

  ```text
  ~/.config/labwc/environment
  ```

- **Sway, Scroll, MangoWC, Miracle WM and any other Wayland compositor** — these have no directive to export env to child apps, so the plugin relies on the universal baseline:

  ```text
  ~/.config/environment.d/90-dms-theme-sync.conf
  ```

  imported automatically by sessions started through **[uwsm](https://github.com/Vladimir-csp/uwsm)** (the launcher DMS recommends) or any systemd user session. The baseline is **also** written on Hyprland and labwc, so they are covered whether or not the compositor reads its native env file.

> [!NOTE]
> Compositor env files only apply at startup. Newly launched apps pick up changes; existing apps and `exec-once`/autostart entries that ran before the include is parsed need a relog. The live-session refresh still updates already-running DMS on each apply. If you start a compositor **without** uwsm/systemd and without one of the native configs above, you fall into the "reduced features" case in the [DMS compositor guide](https://danklinux.com/docs/dankmaterialshell/compositors).

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
- `~/.config/environment.d/90-dms-theme-sync.conf` — every compositor except Niri
- `~/.config/niri/dms-theme-sync.kdl` — Niri only (plus one `include` line in `environment.kdl`)
- `~/.config/hypr/dms-theme-sync.conf` / `dms-theme-sync.lua` — Hyprland only (plus one `source`/`require` line in your main config)
- `~/.config/labwc/environment` — labwc only (a delimited `dmsThemeSync` block; surrounding lines untouched)

The fontconfig, `environment.d`, Hyprland include and labwc env files are captured in snapshots (including their prior absence), so restore can revert or remove them. The Niri include is regenerated on each apply and left in place to avoid a dangling `include`.

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

## Availability

Source: <https://github.com/arqueon/dms-theme-sync>. Submitted to the [DMS plugin registry](https://danklinux.com/plugins); once listed it can also be browsed from *DMS Settings → Plugins*.

## License

[GPL-3.0-or-later](LICENSE)
