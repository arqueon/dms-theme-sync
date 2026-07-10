# DMS Theme Sync

**Cross-toolkit theme synchronization for [Dank Material Shell](https://danklinux.com/docs/dankmaterialshell).** DMS Theme Sync treats DMS as the single source of truth for appearance and propagates it to GTK, Qt, KDE, Flatpak and X11/XWayland applications — no wallpaper manager required.

It runs as a background **daemon**, adds an optional **bar widget**, and ships a standalone **configuration dialog**.

## Scope

Theming on Linux is not a solved problem, and it is not one problem either. It is a dozen configuration systems that were never introduced to each other, each with its own file, its own precedence rules, and its own way of failing silently. Nobody owns the result, so the result is whatever the last tool you clicked happened to write.

**The ambition of this plugin is to make one decision — DMS's — reach every toolkit on the machine, and to keep it reaching them.** Not by fighting the other tools, but by writing every surface correctly, reading the system back afterwards, and saying plainly what it could not fix.

Some of what that means in practice, all of it found on real systems:

- **A file being written is not a setting taking effect.** `$XDG_CONFIG_HOME/fontconfig/conf.d` is pulled in by `50-user.conf` at position ~50, *before* `60-latin.conf`. A `<alias><prefer>` written there never wins, whatever the `99-` prefix suggests. This plugin's own fontconfig file was inert for months until it was verified rather than assumed.
- **Every generic family has a second owner.** `66-noto-sans.conf` claims `sans-serif`, `60-latin.conf` claims `monospace`. Only a strong-bound prepend survives them.
- **GTK3 reads gsettings, and gsettings has other writers.** `nwg-look` and `lxappearance` rewrite it behind your back; a wallpaper script can too. The theme name in `settings.ini` and the one in `gsettings` disagree far more often than anyone notices.
- **GTK4/libadwaita ignores your theme entirely.** It honours only `~/.config/gtk-4.0/gtk.css` colour overrides and the portal's colour-scheme. Every "GTK4 theme" is decoration. Gradience was archived in 2024 for exactly this reason.
- **Dead symlinks accumulate.** `nwg-look` points `gtk.css` and `gtk-dark.css` at the theme you selected; uninstall it and libadwaita trips over the dangling link on every launch, quietly.
- **Sandboxes see none of it.** Flatpak apps get dark/light from the portal and nothing else — not the theme name, not your `gtk.css` — unless someone sets an override.
- **A theme name is a string until something resolves it.** A compositor config can happily name a cursor theme nobody installed, and a Qt style (`kvantum`) that has no plugin behind it, and both fail by falling back rather than complaining.

So the plugin writes, then **reconciles**: it prunes dangling links, re-asserts gsettings, checks that `fc-match` really returns the font it asked for, verifies that every named theme exists on disk, and names the tools that are going to fight it. Anything unambiguous it repairs; anything that needs a human it reports with the file to look at, and touches nothing.

What it will not do is take ownership away from DMS or from you. If DMS decides the icon theme, the plugin asks DMS to change it — through DMS's own API, so DMS's drift detection recognises its own value. If your compositor config sets the cursor, that is your file. The goal is not a plugin that wins every write; it is a desktop where there is only one writer worth listening to.

Linux theming will not be fixed by this plugin. It can, within reach, stop being a surprise.

<img width="809" height="930" alt="1782710026434229332" src="https://github.com/user-attachments/assets/14829950-5538-4334-8222-ec9ca35233c2" />

## Highlights

- **One place for everything.** The plugin UI mirrors every DMS appearance control — color theme, light/dark mode, Matugen palette & contrast, fonts, icons, cursor and cursor size — next to its own options, so you never jump between DMS Settings and the plugin.
- **Cross-toolkit.** GTK2/3/4, GNOME/GSettings, Qt5/6, Kvantum, KDE, Flatpak, Fontconfig, XSettings and XCursor.
- **It checks its own work.** After every apply it reads the system back: prunes dangling GTK symlinks, re-asserts gsettings, confirms `fc-match` really returns the font it asked for, and names the themes and tools that will fight it.
- **Matugen-aware.** Reuses DMS's native Matugen output; never runs a second Matugen pass. Optionally renders a Kvantum theme and recolours Papirus folders from the same palette.
- **DMS decides, the plugin propagates.** It changes DMS settings only through DMS's own API, never behind its back.
- **Safe by default.** Every apply takes a restorable snapshot first.
- **Detected dropdowns only.** No free-form theme/font fields; numeric sizes use sliders with reset buttons.

## What it propagates

| Area | Targets |
| --- | --- |
| **GTK** | `~/.gtkrc-2.0`, GTK3/GTK4 `settings.ini`, safe Matugen color import |
| **GNOME** | GSettings (theme, icons, cursor + size, fonts) and the portal color-scheme hint |
| **Qt5/Qt6** | `qt5ct`/`qt6ct` style, icons, fonts and the `DankMatugen.colors` palette |
| **Kvantum** | opt-in: renders `DankMatugen.{kvconfig,svg}` from the DMS palette and selects it (see [Kvantum](#kvantum)) |
| **KDE** | `kdeglobals`, `kcminputrc` |
| **Fontconfig** | `sans-serif`, `serif`, `monospace` aliases |
| **X11** | XSettings and XCursor defaults |
| **Flatpak** | opt-in `flatpak override --user`: `GTK_THEME`, `ICON_THEME`, `XCURSOR_THEME` + read-only theme dirs |
| **Icons** | opt-in folder accent: a generated overlay theme whose folders follow the Matugen accent (Papirus; the full Catppuccin set when the GTK theme is one) |
| **Terminals** | opt-in font includes for kitty, Alacritty and Ghostty (see [Terminal fonts](#terminal-fonts)) |
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

### The Qt platform theme decides whether any of this is read

`qt5ct.conf` and `qt6ct.conf` are read by the **qtXct platform theme** and by nothing else. Under `gtk3`, `kde` or no platform theme at all, Qt never opens those files, so the widget style you picked is inert. `qtdiag` shows it plainly — with `QT_QPA_PLATFORMTHEME=gtk3` it reports `Styles requested: Fusion,windows`, not the configured style. Reconcile now says so instead of letting you hunt for a theme that was never loaded:

```text
reconcile: Qt platform theme is 'gtk3': Qt apps follow the GTK theme, and style 'kvantum' in qt5ct/qt6ct.conf is ignored
```

Under `gtk3` the *colours* still arrive — Qt applications follow the GTK theme, which carries the Matugen palette — so only the style is reported lost. With no platform theme set, neither reaches Qt.

Both dropdowns are populated from what this machine can actually load, as reported by `qtdiag`, and then pruned of entries that read as choices but are not. `qt5ct`/`qt6ct` collapse into the single **DMS palette** entry, because the plugin writes a different name per Qt version. `snap` and `flatpak` are dropped: `libqxdgdesktopportal.so` registers all three keys, so they are the portal plugin under names meant for apps inside those sandboxes — not looks. `kde` (plasma-integration) is dropped because it expects a running Plasma session, which a DMS desktop is not; export it by hand and reconcile will still tell you the style is inert. What remains — `gtk3`, the portal, the DMS palette — is each a genuinely different behaviour. If `qtdiag` is missing, the lists fall back to the names Qt always builds in.

Set both to **Auto** to let the machine decide. Kvantum only means anything where `qt5ct.conf`/`qt6ct.conf` is read, so the two resolve together:

| | Platform theme | Style |
|---|---|---|
| Kvantum installed | `qtct` | `kvantum`, with the theme rendered from the DMS palette |
| Kvantum absent | `gtk3` | none written — Qt apps follow the GTK theme |

Pinning the platform theme by hand still wins: with `gtk3` selected, an **Auto** style writes nothing rather than something inert.

### Kvantum

Choosing the `kvantum` style writes `style=kvantum` into `qt5ct.conf` and `qt6ct.conf` regardless of whether Kvantum is installed. Qt then falls back to Fusion **without saying anything**, which is precisely the class of silent failure this plugin exists to remove. Reconcile therefore checks for the style plugin Qt actually loads (`libkvantum*.so`) and reports when it is missing. `/usr/share/Kvantum` is not evidence: GTK themes such as `celestial-gtk-theme` ship Kvantum *themes* there without Kvantum itself.

When the **Generate a Kvantum theme from the DMS palette** toggle is on and the Qt style is `kvantum`, the plugin renders the theme itself. What follows is why that is a real feature and not a two-line write.

`qt5ct`/`qt6ct` gives Qt applications the DMS palette, which is where almost all of the visible consistency comes from. Kvantum adds SVG-drawn widget *shapes* on top, and it takes its colours from its own theme — a `<name>.kvconfig` plus a `<name>.svg` — not from the qtXct palette. So selecting `kvantum` today swaps one source of colour for another and drops out of the Matugen palette entirely.

So the plugin renders the theme on every apply: `~/.config/Kvantum/DankMatugen/DankMatugen.kvconfig` and `DankMatugen.svg`, then points `~/.config/Kvantum/kvantum.kvconfig` at it. **Both** files are recoloured — the `.svg` is where every widget is drawn, and the upstream template contains no hard-coded hex at all, so recolouring only the config would leave Kvantum painting the template's colours.

The templates live in `assets/kvantum/`, vendored verbatim from [InioX/matugen-themes](https://github.com/InioX/matugen-themes) (MIT, see the `NOTICE` there) so an apply never depends on the network. They ask for twelve Material roles; DMS's `Theme` singleton exposes most of them and the rest are derived exactly the way DMS derives them in `buildMatugenColorsFromTheme()`. A role the plugin cannot resolve is **reported**, never written as a literal `{{colors.…}}` — Kvantum would read that as an invalid colour and quietly paint grey.

### Folder accent

The folder overlay picks the Papirus folder set whose hue is nearest the Matugen accent. Papirus also carries themed palettes (`nordic`, `yaru`, `cat-*`) whose hues collide with the plain ones, so the plain palette is searched first and the themed entries are a fallback — otherwise `#a1c9ff` lands on `nordic` as readily as on `blue`.

When the GTK theme is a **Catppuccin** and [`papirus-folders-catppuccin`](https://github.com/catppuccin/papirus-folders) is installed, the folders come from the same palette as the theme rather than from a near-hue approximation. That set is 4 flavours × 14 accents; the flavour follows the colour mode — `mocha` in dark, `latte` in light, the way Catppuccin pairs them — and only the accent is matched by hue. `frappe` and `macchiato` are reachable by naming the base theme directly.

Matching those needed a fix worth naming. Catppuccin draws the sheet of paper inside the folder in the flavour's `text` colour, a lavender at chroma ~16, and the pastel accents sit *below* that — `rosewater` is chroma 8, `flamingo` 13.9. "Most saturated fill wins" therefore reads `folder-cat-mocha-rosewater` as a lavender, and a lavender accent would land on the pink folders. The paper is the one fill every variant of a flavour shares, so it is found by intersecting them and excluded, rather than by hardcoding a hex per flavour.

### Compositors

Only the **session-environment** variables — cursor (`XCURSOR_*`/`HYPRCURSOR_*`) and, when you opt in, the Qt platform theme — depend on the compositor. Everything else (GTK, Qt, KDE, Fontconfig, GSettings, XSettings) is compositor-agnostic and applies identically everywhere.

The plugin detects the running compositor (via DMS's `CompositorService`) and always refreshes the **live** systemd user environment (`systemctl --user set-environment`) so apps launched after an apply pick up the new values immediately. The persistent env is written per compositor:

- **Niri** — `environment.d` is read by the systemd session, **not** by Niri's `environment {}` block, so on Niri the plugin writes a generated KDL include:

  ```text
  ~/.config/niri/dms-theme-sync.kdl
  ```

  referenced once by a top-level `include "dms-theme-sync.kdl"` line in `~/.config/niri/config.kdl`. On fresh setups the line is inserted **before** the first `include "user..."` line if you have one, so it overrides the DMS-generated `dms/*.kdl` values (cursor, Qt platform theme) while your own override files keep the last word; if the line already exists, its position is respected. Setups migrated from older plugin versions (<=0.3.0) get the stray include removed from `environment.kdl` automatically. Every change is checked with `niri validate` and rolled back verbatim on failure. The `environment.d` file is **not** used on Niri, and any `QT_QPA_PLATFORMTHEME` you set inline in `environment.kdl` is left untouched.

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

## Terminal fonts

Terminal emulators read **their own** config, not GTK/Qt/GSettings/Fontconfig, so the DMS monospace font never reaches them through the toolkit sync — a terminal with no `font_family` of its own falls back to the generic `monospace`, which fontconfig may resolve to something other than your DMS choice.

This is **opt-in** (off by default) so it never rewrites a terminal config you did not ask it to. Enable **Synchronize terminal fonts** in the plugin settings. The plugin then writes one font include per terminal — each in that terminal's **own syntax** — using the DMS monospace family and size, into a single stable directory:

```text
~/.config/dms-theme-sync/kitty.conf      # font_family / font_size
~/.config/dms-theme-sync/alacritty.toml  # [font] size + [font.normal] family
~/.config/dms-theme-sync/ghostty.conf    # font-family = / font-size =
```

The plugin only **generates** these files; you reference each one from your terminal config **once** (the exact line is printed in every file's header):

- **kitty** — in `~/.config/kitty/kitty.conf`:
  ```conf
  include ~/.config/dms-theme-sync/kitty.conf
  ```
- **Ghostty** — in your Ghostty config:
  ```conf
  config-file = ~/.config/dms-theme-sync/ghostty.conf
  ```
- **Alacritty** — in `~/.config/alacritty/alacritty.toml`:
  ```toml
  [general]
  import = ["~/.config/dms-theme-sync/alacritty.toml"]
  ```

Place the reference where it should win: kitty and Ghostty let a later line override an earlier one, so put it **after** any `font_family`/`font-family` you keep, or remove yours and let the include own it. Changes apply on the terminal's next launch or config reload (e.g. kitty `ctrl+shift+F5`, or `kill -SIGUSR1 $(pidof kitty)`).

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
- `~/.local/share/icons/<base>-DankFolders/` — only while the folder-accent toggle is on; deleted when it is turned off, and stale overlays from a previous base theme are swept on every run
- `~/.config/environment.d/90-dms-theme-sync.conf` — every compositor except Niri
- `~/.config/niri/dms-theme-sync.kdl` — Niri only (plus one top-level `include` line in `config.kdl`)
- `~/.config/hypr/dms-theme-sync.conf` / `dms-theme-sync.lua` — Hyprland only (plus one `source`/`require` line in your main config)
- `~/.config/labwc/environment` — labwc only (a delimited `dmsThemeSync` block; surrounding lines untouched)
- `~/.config/dms-theme-sync/{kitty.conf,alacritty.toml,ghostty.conf}` — only when **Synchronize terminal fonts** is on; referenced from your terminal configs, never injected into them

The fontconfig, `environment.d`, Hyprland include, labwc env and terminal font files are captured in snapshots (including their prior absence), so restore can revert or remove them. The Niri include is regenerated on each apply and left in place to avoid a dangling `include`.

> [!TIP]
> `--dry-run` lists intended writes; `--no-runtime` writes only into the target HOME/XDG paths without calling GSettings, Fontconfig, XSettings, systemd or niri — intended for isolated tests.

## Optional packages

Everything degrades gracefully when a toolkit is missing. Install what you use:

- `gsettings`/`dconf` — GNOME settings and portal hints
- `qt5ct` and `qt6ct` (or `qt6ct-kde`) — Qt configuration
- `qt6-tools` — provides `qtdiag`, which is how the Qt platform-theme and style dropdowns are populated; without it they fall back to the names Qt always builds in
- `xsettingsd` — legacy X11/XWayland clients
- `kvantum` — only if you want SVG-drawn Qt widgets; `qt6ct` with the DMS palette already gives colour consistency
- `papirus-icon-theme` — the folder accent overlay; it is the only theme shipping ~80 folder colours in one package
- `papirus-folders-catppuccin` — extra: lets a Catppuccin GTK theme use the matching Catppuccin folders instead of the nearest plain colour. Without it, plain Papirus is used and nothing breaks
- the selected GTK theme and its engine (e.g. the **Murrine** engine for GTK2 themes)

> [!NOTE]
> GTK4/libadwaita does not honor arbitrary `GTK_THEME` widget themes. DMS's generated GTK4 CSS stays the color source; the plugin still syncs fonts, icons, cursor and dark/light preference.

## Availability

Source: <https://github.com/arqueon/dms-theme-sync>. Submitted to the [DMS plugin registry](https://danklinux.com/plugins); once listed it can also be browsed from *DMS Settings → Plugins*.

## License

[GPL-3.0-or-later](LICENSE)
