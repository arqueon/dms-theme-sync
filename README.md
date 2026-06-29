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

DMS itself remains responsible for generating dynamic GTK/Qt colors with Matugen. Keep DMS's **GTK**, **qt5ct** and **qt6ct** Matugen templates enabled. The plugin consumes the resulting `dank-colors.css` and `DankMatugen.colors`; it deliberately does not launch a second Matugen process, which avoids duplicate work and races during wallpaper changes.

The GTK propagation follows the same model as `nwg-look`: GSettings is applied directly for the running Wayland session, while GTK configuration files are exported for compatibility. `nwg-look` is useful for previewing installed themes but is not a runtime dependency.

## Qt policy

The plugin offers three modes:

- **Follow GTK (`gtk3`)**: writes `QT_QPA_PLATFORMTHEME=gtk3`, so Qt applications use the chosen GTK theme where the Qt GTK platform plugin is available.
- **DMS palette (`qt5ct/qt6ct`)**: uses qt5ct and qt6ct with DMS's generated `DankMatugen.colors` palette.
- **Preserve environment**: updates Qt config files but does not select a platform-theme environment variable.

Environment changes apply reliably to new sessions. Existing applications generally need to be restarted; a logout/login may be required after changing the Qt policy.

## Installation

```bash
git clone https://github.com/arqueon/dms-theme-sync.git \
  ~/.config/DankMaterialShell/plugins/dmsThemeSync
dms restart
```

Enable **DMS Theme Sync** in DMS Settings → Plugins. Configure light/dark GTK themes and font sizes in the plugin settings. Font families, icons, cursor theme and cursor size are selected in the normal DMS Appearance settings.

For local development:

```bash
ln -s ~/Projects/dms-theme-sync \
  ~/.config/DankMaterialShell/plugins/dmsThemeSync
dms ipc call plugins reload dmsThemeSync
```

## IPC

```bash
dms ipc call dmsThemeSync apply
dms ipc call dmsThemeSync status
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

Use the helper's `--dry-run` option during development to list intended writes. `--no-runtime` writes only into the selected HOME/XDG paths without calling GSettings, Fontconfig, XSettings or systemd; it is intended for isolated tests.

## License

MIT

## Publishing

After pushing the repository to `https://github.com/arqueon/dms-theme-sync`, copy `packaging/arqueon-dms-theme-sync.json` into the official registry's `plugins/` directory, run its validation commands, and submit the registry pull request. Add a screenshot URL to that entry when the settings-page screenshot is available.
