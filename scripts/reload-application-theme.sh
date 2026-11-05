#!/usr/bin/env bash
set -u

# KDE's appearance KCMs notify running applications after changing shared
# configuration. Palette, font, and cursor changes are safe to request in a
# process that keeps its current QStyle. A QStyle transition is different:
# Dolphin and other applications may only rebuild part of a live window, so
# apply-theme.sh reports that boundary as restart-required instead of this
# helper promising an in-place style swap. Each message also carries the
# legacy argument required by the D-Bus signature.
exit_code=0
if command -v dbus-send >/dev/null 2>&1; then
    for change_type in 0 1 5; do
        if ! dbus-send --session --type=signal /KGlobalSettings \
            org.kde.KGlobalSettings.notifyChange \
            "int32:$change_type" int32:0; then
            exit_code=1
        fi
    done

    # KIconLoader divides icons into six public groups. KDE's Icons KCM
    # notifies every group after a theme change; doing the same here makes
    # existing views, toolbars, panels, dialogs, and small-icon consumers
    # reconsider their process-local icon caches.
    for group in 0 1 2 3 4 5; do
        if ! dbus-send --session --type=signal /KIconLoader \
            org.kde.KIconLoader.iconChanged "int32:$group"; then
            exit_code=1
        fi
    done
fi

# qt5ct and qt6ct watch their configuration directory via QFileSystemWatcher's
# directoryChanged signal (not fileChanged on qtXct.conf) and turn a change
# into a Qt ThemeChange event for already-running applications. Touch the
# config file for mtime consumers AND pulse a transient file in the directory
# so directoryChanged always fires even when qtXct.conf is a symlink into a
# dotfile manager outside ~/.config/qtXct.
config_home=${XDG_CONFIG_HOME:-${HOME:?}/.config}
for config in "$config_home/qt5ct/qt5ct.conf" "$config_home/qt6ct/qt6ct.conf"; do
    [[ -e $config ]] || continue
    config_dir=$(dirname "$config")
    pulse_file="$config_dir/.dms-reload-$$"
    if ! touch -- "$config" || ! : > "$pulse_file" || ! rm -f -- "$pulse_file"; then
        rm -f -- "$pulse_file" 2>/dev/null || true
        exit_code=1
    fi
done

# GTK 4.22+ re-parses ~/.config/gtk-4.0/gtk.css (@import url("dank-colors.css"))
# when org.gnome.desktop.a11y.interface reduced-motion toggles. Dux 2.1 pulses
# this inside its matugen worker; pulsing it here too covers manual apply and
# snapshot restore runs where matugen did not just exit.
if [[ -z ${DMS_THEME_RELOAD_TEST_LOG:-} ]] && command -v gsettings >/dev/null 2>&1; then
    current_rm=$(gsettings get org.gnome.desktop.a11y.interface reduced-motion 2>/dev/null || true)
    if [[ $current_rm == "'reduce'" || $current_rm == "'no-preference'" ]]; then
        flipped_rm="'reduce'"
        [[ $current_rm == "'reduce'" ]] && flipped_rm="'no-preference'"
        (
            gsettings set org.gnome.desktop.a11y.interface reduced-motion "$flipped_rm" >/dev/null 2>&1 || true
            sleep 0.1
            gsettings set org.gnome.desktop.a11y.interface reduced-motion "$current_rm" >/dev/null 2>&1 || true
        ) >/dev/null 2>&1 &
    fi
fi

exit "$exit_code"
