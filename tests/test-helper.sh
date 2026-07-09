#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

export HOME="$TMP/home"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
mkdir -p "$XDG_CONFIG_HOME/gtk-3.0" "$XDG_DATA_HOME/themes/Matcha-dark-sea" \
    "$XDG_DATA_HOME/themes/Matcha-light-sea" "$XDG_DATA_HOME/color-schemes"

printf '[Settings]\ngtk-theme-name=Matcha-dark-sea\ncustom-key=keep-me\n' \
    > "$XDG_CONFIG_HOME/gtk-3.0/settings.ini"
printf '[ColorEffects:Disabled]\nColor=0,0,0\n' \
    > "$XDG_DATA_HOME/color-schemes/DankMatugen.colors"
printf '/* Generated with Matugen */\n@define-color accent_color #123456;\n' \
    > "$XDG_CONFIG_HOME/gtk-3.0/dank-colors.css"
mkdir -p "$XDG_CONFIG_HOME/gtk-4.0"
cp "$XDG_CONFIG_HOME/gtk-3.0/dank-colors.css" "$XDG_CONFIG_HOME/gtk-4.0/dank-colors.css"

"$ROOT/scripts/apply-theme.sh" \
    --font "Archivo" --mono-font "Cascadia Mono" --document-font "Literata" \
    --font-size 11 --mono-size 12 --document-size 13 \
    --icon-theme "Papirus-Dark" --cursor-theme "Breeze" --cursor-size 32 \
    --mode light --gtk-theme-light auto --gtk-theme-dark auto \
    --qt-platform-theme qtct --qt-style Fusion \
    --apply-matugen-colors true \
    --backup-enabled false --backup-retention 10 \
    --sync-kde true --sync-xsettingsd true --no-runtime >/dev/null

assert_line() {
    local file=$1 line=$2
    grep -Fqx "$line" "$file" || {
        printf 'Missing %q in %s\n' "$line" "$file" >&2
        exit 1
    }
}

assert_line "$XDG_CONFIG_HOME/gtk-3.0/settings.ini" "gtk-theme-name=Matcha-light-sea"
assert_line "$XDG_CONFIG_HOME/gtk-3.0/settings.ini" "gtk-font-name=Archivo 11"
assert_line "$XDG_CONFIG_HOME/gtk-3.0/settings.ini" "custom-key=keep-me"
assert_line "$XDG_CONFIG_HOME/gtk-4.0/settings.ini" "gtk-cursor-theme-size=32"
assert_line "$XDG_CONFIG_HOME/gtk-3.0/gtk.css" '@import url("dank-colors.css");'
assert_line "$XDG_CONFIG_HOME/gtk-4.0/gtk.css" '@import url("dank-colors.css");'
assert_line "$HOME/.gtkrc-2.0" 'gtk-theme-name="Matcha-light-sea"'
assert_line "$XDG_CONFIG_HOME/qt5ct/qt5ct.conf" 'general="Archivo,11,-1,5,400,0,0,0,0,0"'
assert_line "$XDG_CONFIG_HOME/qt6ct/qt6ct.conf" 'fixed="Cascadia Mono,12,-1,5,400,0,0,0,0,0"'
assert_line "$XDG_CONFIG_HOME/kdeglobals" 'Theme=Papirus-Dark'
assert_line "$XDG_CONFIG_HOME/kcminputrc" 'cursorSize=32'
assert_line "$XDG_CONFIG_HOME/environment.d/90-dms-theme-sync.conf" 'QT_QPA_PLATFORMTHEME=qt5ct'
assert_line "$XDG_CONFIG_HOME/environment.d/90-dms-theme-sync.conf" 'QT_QPA_PLATFORMTHEME_QT6=qt6ct'
# The generic-family rules must be strong-bound prepends, not <alias><prefer>:
# 50-user.conf loads this file at position ~50, before 60-latin.conf, so a
# <prefer> here is silently overridden by Noto Sans Mono / Noto Sans.
fc_conf="$XDG_CONFIG_HOME/fontconfig/conf.d/99-dms-theme-sync.conf"
grep -Fq '<string>Cascadia Mono</string>' "$fc_conf"
grep -Fq 'mode="prepend" binding="strong"' "$fc_conf"
! grep -Fq '<prefer>' "$fc_conf"

before=$(find "$HOME" -type f -exec sha256sum {} + | LC_ALL=C sort)
"$ROOT/scripts/apply-theme.sh" \
    --font "Archivo" --mono-font "Cascadia Mono" --document-font "Literata" \
    --font-size 11 --mono-size 12 --document-size 13 \
    --icon-theme "Papirus-Dark" --cursor-theme "Breeze" --cursor-size 32 \
    --mode light --gtk-theme-light auto --gtk-theme-dark auto \
    --qt-platform-theme qtct --qt-style Fusion \
    --apply-matugen-colors true \
    --backup-enabled false --backup-retention 10 \
    --sync-kde true --sync-xsettingsd true --no-runtime >/dev/null
after=$(find "$HOME" -type f -exec sha256sum {} + | LC_ALL=C sort)
[[ $before == "$after" ]] || { printf 'Second run was not idempotent\n' >&2; exit 1; }

printf 'pre-backup-marker\n' >> "$XDG_CONFIG_HOME/gtk-3.0/settings.ini"
rm -f "$XDG_CONFIG_HOME/environment.d/90-dms-theme-sync.conf"
backup_output=$("$ROOT/scripts/theme-snapshot.sh" backup --retention 3 --label test --no-runtime)
snapshot=${backup_output#BACKUP_CREATED:}
printf 'mutated\n' > "$XDG_CONFIG_HOME/gtk-3.0/settings.ini"
printf 'created-after-backup\n' > "$XDG_CONFIG_HOME/environment.d/90-dms-theme-sync.conf"

"$ROOT/scripts/theme-snapshot.sh" restore --snapshot "$snapshot" --no-runtime >/dev/null
grep -Fq 'pre-backup-marker' "$XDG_CONFIG_HOME/gtk-3.0/settings.ini"
[[ ! -e $XDG_CONFIG_HOME/environment.d/90-dms-theme-sync.conf ]] || {
    printf 'Restore did not remove a file that was absent in the snapshot\n' >&2
    exit 1
}
"$ROOT/scripts/theme-snapshot.sh" list | grep -Fqx "$snapshot"

# --- Niri: top-level include in config.kdl, migration from environment.kdl ---
NIRI_DIR="$XDG_CONFIG_HOME/niri"
mkdir -p "$NIRI_DIR"
printf 'include "input.kdl"\ninclude "dms/colors.kdl"\ninclude "user-common.kdl"\ninclude "user.kdl"\n' \
    > "$NIRI_DIR/config.kdl"
# legacy layout (<=0.3.0): include appended to environment.kdl
printf 'environment {\n    FOO "bar"\n}\n\ninclude "dms-theme-sync.kdl"\n' > "$NIRI_DIR/environment.kdl"

run_niri() {
    "$ROOT/scripts/apply-theme.sh" \
        --font "Archivo" --mono-font "Cascadia Mono" --document-font "Literata" \
        --font-size 11 --mono-size 12 --document-size 13 \
        --icon-theme "Papirus-Dark" --cursor-theme "Breeze" --cursor-size 32 \
        --mode light --gtk-theme-light auto --gtk-theme-dark auto \
        --qt-platform-theme qtct --qt-style Fusion \
        --apply-matugen-colors true \
        --backup-enabled false --backup-retention 10 \
        --sync-kde true --sync-xsettingsd true --no-runtime \
        --compositor niri >/dev/null
}
run_niri

[[ -f $NIRI_DIR/dms-theme-sync.kdl ]] || { printf 'Niri include file not generated\n' >&2; exit 1; }
grep -Fqx 'include "dms-theme-sync.kdl"' "$NIRI_DIR/config.kdl" \
    || { printf 'Include line missing from config.kdl\n' >&2; exit 1; }
# inserted before the first user include, after dms/ includes
expected=$(printf 'include "input.kdl"\ninclude "dms/colors.kdl"\ninclude "dms-theme-sync.kdl"\ninclude "user-common.kdl"\ninclude "user.kdl"\n')
[[ $(cat "$NIRI_DIR/config.kdl") == "$expected" ]] \
    || { printf 'Include not placed before user includes:\n%s\n' "$(cat "$NIRI_DIR/config.kdl")" >&2; exit 1; }
grep -q 'dms-theme-sync.kdl' "$NIRI_DIR/environment.kdl" \
    && { printf 'Legacy include not migrated out of environment.kdl\n' >&2; exit 1; }
grep -Fqx '    FOO "bar"' "$NIRI_DIR/environment.kdl" \
    || { printf 'environment.kdl content damaged by migration\n' >&2; exit 1; }
[[ ! -e $XDG_CONFIG_HOME/environment.d/90-dms-theme-sync.conf ]] \
    || { printf 'environment.d baseline should be dropped on Niri\n' >&2; exit 1; }

# idempotent second run: config.kdl untouched, position respected
before_niri=$(cat "$NIRI_DIR/config.kdl")
run_niri
[[ $(cat "$NIRI_DIR/config.kdl") == "$before_niri" ]] \
    || { printf 'Second Niri run moved or duplicated the include\n' >&2; exit 1; }

# config.kdl written through symlinks (dotfile managers), never replaced
repo_dir="$TMP/lnk-repo"; mkdir -p "$repo_dir"
mv "$NIRI_DIR/config.kdl" "$repo_dir/config.kdl"
sed -i '/dms-theme-sync/d' "$repo_dir/config.kdl"
ln -s "$repo_dir/config.kdl" "$NIRI_DIR/config.kdl"
run_niri
[[ -L $NIRI_DIR/config.kdl ]] || { printf 'Symlinked config.kdl was replaced by a regular file\n' >&2; exit 1; }
grep -Fqx 'include "dms-theme-sync.kdl"' "$repo_dir/config.kdl" \
    || { printf 'Include not written through the symlink\n' >&2; exit 1; }

# --- Terminal font includes: off by default, generated only when opted in ---
TERMINAL_DIR="$XDG_CONFIG_HOME/dms-theme-sync"

run_terminal() {
    "$ROOT/scripts/apply-theme.sh" \
        --font "Archivo" --mono-font "Cascadia Mono" --document-font "Literata" \
        --font-size 11 --mono-size 12 --document-size 13 \
        --icon-theme "Papirus-Dark" --cursor-theme "Breeze" --cursor-size 32 \
        --mode light --gtk-theme-light auto --gtk-theme-dark auto \
        --qt-platform-theme qtct --qt-style Fusion \
        --apply-matugen-colors true \
        --backup-enabled false --backup-retention 10 \
        --sync-kde true --sync-xsettingsd true --no-runtime "$@" >/dev/null
}

# default (flag absent): nothing written
run_terminal
[[ ! -e $TERMINAL_DIR ]] || { printf 'Terminal includes written without opt-in\n' >&2; exit 1; }
# explicit false: still nothing
run_terminal --sync-terminal-fonts false
[[ ! -e $TERMINAL_DIR ]] || { printf 'Terminal includes written with --sync-terminal-fonts false\n' >&2; exit 1; }

# opt-in: three files, each in its terminal's own syntax
run_terminal --sync-terminal-fonts true
assert_line "$TERMINAL_DIR/kitty.conf" "font_family Cascadia Mono"
assert_line "$TERMINAL_DIR/kitty.conf" "font_size 12"
assert_line "$TERMINAL_DIR/ghostty.conf" "font-family = Cascadia Mono"
assert_line "$TERMINAL_DIR/ghostty.conf" "font-size = 12"
assert_line "$TERMINAL_DIR/alacritty.toml" 'family = "Cascadia Mono"'
assert_line "$TERMINAL_DIR/alacritty.toml" "size = 12"

# idempotent second run with the flag on
before_term=$(find "$TERMINAL_DIR" -type f -exec sha256sum {} + | LC_ALL=C sort)
run_terminal --sync-terminal-fonts true
after_term=$(find "$TERMINAL_DIR" -type f -exec sha256sum {} + | LC_ALL=C sort)
[[ $before_term == "$after_term" ]] || { printf 'Terminal include run was not idempotent\n' >&2; exit 1; }

# terminal includes are captured in snapshots and restore can remove them
BACKUP_ROOT="$HOME/.local/state/DankMaterialShell/plugins/dmsThemeSync/backups"
term_backup=$("$ROOT/scripts/theme-snapshot.sh" backup --retention 3 --label term --no-runtime)
term_snapshot=${term_backup#BACKUP_CREATED:}
grep -Fq "$TERMINAL_DIR/kitty.conf" "$BACKUP_ROOT/$term_snapshot/manifest.tsv" \
    || { printf 'Terminal include not recorded in snapshot manifest\n' >&2; exit 1; }
rm -rf "$TERMINAL_DIR"
"$ROOT/scripts/theme-snapshot.sh" restore --snapshot "$term_snapshot" --no-runtime >/dev/null
assert_line "$TERMINAL_DIR/kitty.conf" "font_family Cascadia Mono"

# --- Folder accent overlay: off by default, built only when opted in ---------
# Needs a real Papirus install to read folder colours from; skip where absent.
PAPIRUS=""
for d in /usr/share/icons /usr/local/share/icons; do
    [[ -d $d/Papirus-Dark/64x64/places ]] && { PAPIRUS="$d/Papirus-Dark"; break; }
done

if [[ -n $PAPIRUS ]]; then
    OVERLAY="$XDG_DATA_HOME/icons/Papirus-Dark-DankFolders"
    printf '@define-color accent_bg_color #e25252;\n' \
        > "$XDG_CONFIG_HOME/gtk-4.0/dank-colors.css"

    run_folder() {
        "$ROOT/scripts/apply-theme.sh" \
            --font "Archivo" --mono-font "Cascadia Mono" --document-font "Literata" \
            --font-size 11 --mono-size 12 --document-size 13 \
            --icon-theme "Papirus-Dark" --cursor-theme "Breeze" --cursor-size 32 \
            --mode dark --gtk-theme-light auto --gtk-theme-dark auto \
            --qt-platform-theme qtct --qt-style Fusion \
            --apply-matugen-colors true --sync-kde false --sync-xsettingsd false \
            --backup-enabled false --backup-retention 10 --no-runtime "$@" >/dev/null
    }

    run_folder --sync-folder-color false
    [[ ! -d $OVERLAY ]] || { printf 'Overlay built while the toggle was off\n' >&2; exit 1; }
    assert_line "$XDG_CONFIG_HOME/gtk-3.0/settings.ini" "gtk-icon-theme-name=Papirus-Dark"

    run_folder --sync-folder-color true
    [[ -d $OVERLAY ]] || { printf 'Overlay not built with the toggle on\n' >&2; exit 1; }
    # a red accent must resolve to the `red` folders, not to a themed near-hue
    [[ $(readlink "$OVERLAY/64x64/places/folder.svg") == *"/folder-red.svg" ]] \
        || { printf 'Accent did not map to the red folder set\n' >&2; exit 1; }
    grep -Fqx "Inherits=Papirus-Dark,hicolor" "$OVERLAY/index.theme" \
        || { printf 'Overlay does not inherit from the base theme\n' >&2; exit 1; }
    # HiDPI directories must carry Scale, or @2x lookups silently miss
    grep -Fqx "Scale=2" "$OVERLAY/index.theme" \
        || { printf 'Overlay index.theme lacks Scale for @2x dirs\n' >&2; exit 1; }
    [[ -z $(find "$OVERLAY" -xtype l -print -quit) ]] \
        || { printf 'Overlay contains broken symlinks\n' >&2; exit 1; }
    # the overlay, not the base theme, becomes the applied icon theme
    assert_line "$XDG_CONFIG_HOME/gtk-3.0/settings.ini" \
        "gtk-icon-theme-name=Papirus-Dark-DankFolders"

    # turning it back off removes the generated theme and restores the base name
    run_folder --sync-folder-color false
    [[ ! -d $OVERLAY ]] || { printf 'Overlay survived the toggle being turned off\n' >&2; exit 1; }
    assert_line "$XDG_CONFIG_HOME/gtk-3.0/settings.ini" "gtk-icon-theme-name=Papirus-Dark"
else
    printf 'folder overlay: skipped (no Papirus-Dark installed)\n'
fi

# --- Reconcile: dangling GTK symlinks are pruned, live foreign writers named --
# nwg-look points gtk.css / gtk-dark.css at the selected theme; uninstall it and
# libadwaita trips over the dead link on every launch.
ln -sfn "$TMP/does-not-exist/gtk-dark.css" "$XDG_CONFIG_HOME/gtk-4.0/gtk-dark.css"
mkdir -p "$XDG_CONFIG_HOME/variety/scripts"
printf '#!/bin/sh\n# gsettings set org.gnome.desktop.interface gtk-theme "X"\n' \
    > "$XDG_CONFIG_HOME/variety/scripts/set_wallpaper"
printf '#!/bin/sh\ngsettings set org.gnome.desktop.interface gtk-theme "X"\n' \
    > "$XDG_CONFIG_HOME/variety/scripts/set_wallpaper.bak-1"

run_reconcile() {
    "$ROOT/scripts/apply-theme.sh" \
        --font "Archivo" --mono-font "Cascadia Mono" --document-font "Literata" \
        --font-size 11 --mono-size 12 --document-size 13 \
        --icon-theme "Papirus-Dark" --cursor-theme "Breeze" --cursor-size 32 \
        --mode light --gtk-theme-light auto --gtk-theme-dark auto \
        --qt-platform-theme qtct --qt-style Fusion --apply-matugen-colors true \
        --sync-kde false --sync-xsettingsd false \
        --backup-enabled false --backup-retention 10 --no-runtime 2>&1
}

reconcile_out=$(run_reconcile)
[[ ! -e $XDG_CONFIG_HOME/gtk-4.0/gtk-dark.css ]] \
    || { printf 'Dangling gtk-dark.css symlink was not pruned\n' >&2; exit 1; }
grep -q 'removed dangling symlink' <<<"$reconcile_out" \
    || { printf 'Prune was not reported\n' >&2; exit 1; }
# a commented-out line and a *.bak copy are not live writers
grep -q 'sets the GTK theme behind us' <<<"$reconcile_out" \
    && { printf 'Commented-out / backup script reported as a live writer\n' >&2; exit 1; }

printf '#!/bin/sh\ngsettings set org.gnome.desktop.interface gtk-theme "X"\n' \
    > "$XDG_CONFIG_HOME/variety/scripts/set_wallpaper"
grep -q 'sets the GTK theme behind us' <<<"$(run_reconcile)" \
    || { printf 'Live foreign writer not detected\n' >&2; exit 1; }
rm -rf "$XDG_CONFIG_HOME/variety"

printf 'helper tests: ok\n'
