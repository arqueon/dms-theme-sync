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

# qt5ct and qt6ct watch their configuration files and turn a change into a Qt
# ThemeChange event for already-running applications. That event covers the
# platform theme's palette, fonts, style hints, and icons. Touch only existing
# files: this preserves dot-manager symlinks and never invents a configuration
# for a toolkit the user does not have.
config_home=${XDG_CONFIG_HOME:-${HOME:?}/.config}
for config in "$config_home/qt5ct/qt5ct.conf" "$config_home/qt6ct/qt6ct.conf"; do
    [[ -e $config ]] || continue
    if ! touch -- "$config"; then
        exit_code=1
    fi
done

exit "$exit_code"
