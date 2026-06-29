# DMS Theme Sync

DMS Theme Sync is a daemon plugin for [Dank Material Shell](https://danklinux.com/docs/dankmaterialshell). It treats DMS as the source of truth and propagates its appearance settings to Linux applications without depending on a wallpaper manager.

It synchronizes:

- DMS regular and monospace font families, plus configurable UI, monospace and document sizes.
- DMS icon theme.
- DMS cursor theme **and cursor size**.
- A selectable GTK theme for DMS light and dark modes. Installed themes such as Matcha, Dracula, Breeze, adw-gtk3 and GTK2 themes using Murrine are supported by name.
- GTK2 (`~/.gtkrc-2.0`), GTK3 and GTK4 `settings.ini`.
- GNOME/GSettings and the desktop portal color-scheme hint.
- Qt5/Qt6 fonts, icons, style and the DMS-generated `DankMatugen.colors` palette.
- KDE fonts/icons/cursor through `kdeglobals` and `kcminputrc`.
- Fontconfig generic aliases (`sans-serif`, `serif`, `monospace`).
- XSettings for legacy GTK2/XWayland applications.
- XCursor defaults and `environment.d` for applications started after login.
- Automatic snapshots before changes, including affected files, GSettings and the user-systemd environment.

DMS itself remains responsible for generating dynamic GTK/Qt colors with Matugen. Keep DMS's **GTK**, **qt5ct** and **qt6ct** Matugen templates enabled. The plugin consumes the resulting `dank-colors.css` and `DankMatugen.colors`; it deliberately does not launch a second Matugen process, which avoids duplicate work and races during wallpaper changes.

The GTK propagation follows the same model as `nwg-look`: GSettings is applied directly for the running Wayland session, while GTK configuration files are exported for compatibility. `nwg-look` is useful for previewing installed themes but is not a runtime dependency.

## Qt policy

The plugin **always** writes the `qt5ct`/`qt6ct` configuration files (style, icons, fonts and the `DankMatugen.colors` palette). The Qt policy only controls the `QT_QPA_PLATFORMTHEME` environment variable, which selects whether Qt applications actually obey those files. Like DMS, the plugin treats that variable as user-owned:

- **Leave to my environment (default)**: the plugin does not touch `QT_QPA_PLATFORMTHEME`. Use this if you already set it (for example in `/etc/environment` or a `~/.config/environment.d/*.conf` file). This matches DMS, which never writes the variable either.
- **Plugin sets Follow GTK (`gtk3`)**: writes `QT_QPA_PLATFORMTHEME=gtk3`, so Qt applications follow the chosen GTK theme where the Qt GTK platform plugin is available.
- **Plugin sets DMS palette (`qt5ct/qt6ct`)**: writes `QT_QPA_PLATFORMTHEME=qt5ct`/`qt6ct`, so Qt applications use qt5ct/qt6ct with DMS's generated `DankMatugen.colors` palette.

When the plugin does write the variable, it goes to `~/.config/environment.d/90-dms-theme-sync.conf`. Environment changes apply reliably only to new sessions; existing applications need to be restarted and a logout/login may be required.

### Niri

`environment.d` is read by the systemd user session, not by the Niri `environment {}` block, so on Niri the plugin uses a dedicated KDL include instead. It writes the managed environment variables — cursor (`XCURSOR_*`/`HYPRCURSOR_*`) and, when you opt in, the Qt platform theme — to:

```text
~/.config/niri/dms-theme-sync.kdl
```

and references it once by appending `include "dms-theme-sync.kdl"` to the end of `~/.config/niri/environment.kdl`. The include is regenerated idempotently on every apply and the resulting config is checked with `niri validate`; if validation fails the appended line is rolled back. On Niri the plugin does not write its `environment.d` file. Any `QT_QPA_PLATFORMTHEME` you already set inline in `environment.kdl` is left untouched (with the Qt policy on its default, the plugin does not emit a Qt line at all).

## Installation

```bash
git clone https://github.com/arqueon/dms-theme-sync.git \
  ~/.config/DankMaterialShell/plugins/dmsThemeSync
dms restart
```

Enable **DMS Theme Sync** in DMS Settings → Plugins. Configure light/dark GTK themes and font sizes in the plugin settings. Font families, icons, cursor theme and cursor size are selected in the normal DMS Appearance settings.

All appearance choices in the plugin UI use detected dropdown menus; there are no free-form theme or font fields. Regular/monospace fonts, icons and cursors update the canonical DMS settings directly. Numeric sizes use bounded sliders.

For local development:

```bash
ln -s ~/Projects/dms-theme-sync \
  ~/.config/DankMaterialShell/plugins/dmsThemeSync
dms ipc call plugins reload dmsThemeSync
```

## IPC

```bash
dms ipc call dmsThemeSync apply
dms ipc call dmsThemeSync backup
dms ipc call dmsThemeSync restoreLatest
dms ipc call dmsThemeSync restore 20260628-182500
dms ipc call dmsThemeSync configure
dms ipc call dmsThemeSync status
```

`configure` opens the plugin's standalone DMS-styled configuration dialog. It provides the same detected dropdowns, sliders, apply, backup and restore actions without navigating through DMS Settings. It can be assigned directly to a compositor keybinding.

## Backups and restoration

Automatic backup is enabled by default. Before each application, the plugin snapshots every file it may change, relevant GNOME GSettings values, and cursor/Qt variables in the user-systemd environment. Retention is configurable from 1 to 30 snapshots; the default is 10.

Snapshots live in:

```text
~/.local/state/DankMaterialShell/plugins/dmsThemeSync/backups/
```

Restoring through the settings button or IPC disables automatic synchronization first, preventing the recovered configuration from being overwritten immediately. Files that did not exist when the snapshot was created are removed during restoration. Restart applications after restoring; Qt environment changes may require logging out and back in.

The helper is also usable directly:

```bash
scripts/theme-snapshot.sh list
scripts/theme-snapshot.sh backup --retention 10 --label manual
scripts/theme-snapshot.sh restore --snapshot latest
```

## Optional packages

The helper degrades gracefully when a toolkit is absent. Install the components you use:

- `gsettings`/`dconf` for GNOME settings and portal hints.
- `qt5ct` and `qt6ct` (or `qt6ct-kde`, depending on distribution) for Qt configuration.
- `xsettingsd` for legacy X11/XWayland clients.
- The selected GTK theme and its engine. For GTK2 themes based on Murrine, install the GTK2 Murrine engine.

GTK4/libadwaita does not fully honor arbitrary `GTK_THEME` widget themes. DMS's generated GTK4 CSS remains the color source; the plugin still synchronizes fonts, icons, cursor and dark/light preference.

## Safety and files changed

The helper performs key-level, idempotent updates. It does not replace complete GTK, Qt or KDE configuration files. Plugin-owned files are:

- `~/.config/fontconfig/conf.d/99-dms-theme-sync.conf`
- `~/.config/environment.d/90-dms-theme-sync.conf`

These files are included in snapshots, including their prior absence, so restoration removes them when appropriate.

Use the helper's `--dry-run` option during development to list intended writes. `--no-runtime` writes only into the selected HOME/XDG paths without calling GSettings, Fontconfig, XSettings or systemd; it is intended for isolated tests.

## License

MIT

## Publishing

After pushing the repository to `https://github.com/arqueon/dms-theme-sync`, copy `packaging/arqueon-dms-theme-sync.json` into the official registry's `plugins/` directory, run its validation commands, and submit the registry pull request. Add a screenshot URL to that entry when the settings-page screenshot is available.
