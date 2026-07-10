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
    # Papirus reaches its folder icons through ~220 relative aliases per size.
    # GTK apps ask for `folder`; KDE apps ask for `inode-directory`. Carry only
    # the former and Thunar and Dolphin show two different folder colours.
    for alias_icon in inode-directory gtk-directory folder_open desktop; do
        [[ -L $OVERLAY/64x64/places/$alias_icon.svg ]] \
            || { printf 'Overlay is missing the %s alias\n' "$alias_icon" >&2; exit 1; }
        [[ $(readlink -f "$OVERLAY/64x64/places/$alias_icon.svg") == *"-red"* ]] \
            || { printf '%s does not resolve to the accent colour\n' "$alias_icon" >&2; exit 1; }
    done
    # HiDPI directories must carry Scale, or @2x lookups silently miss
    grep -Fqx "Scale=2" "$OVERLAY/index.theme" \
        || { printf 'Overlay index.theme lacks Scale for @2x dirs\n' >&2; exit 1; }
    [[ -z $(find "$OVERLAY" -xtype l -print -quit) ]] \
        || { printf 'Overlay contains broken symlinks\n' >&2; exit 1; }
    # The helper builds the overlay but never applies it: DMS owns the icon
    # theme, and writing the overlay name straight into gsettings would trip
    # DMS's own drift check and unmanage the theme.
    assert_line "$XDG_CONFIG_HOME/gtk-3.0/settings.ini" "gtk-icon-theme-name=Papirus-Dark"

    # turning it back off removes the generated theme
    run_folder --sync-folder-color false
    [[ ! -d $OVERLAY ]] || { printf 'Overlay survived the toggle being turned off\n' >&2; exit 1; }
    assert_line "$XDG_CONFIG_HOME/gtk-3.0/settings.ini" "gtk-icon-theme-name=Papirus-Dark"

    # --- Catppuccin: match the theme exactly, not approximately ---------------
    #
    # papirus-folders-catppuccin ships 4 flavours x 14 accents. When the GTK
    # theme is a Catppuccin the folders can come from the same palette, so the
    # flavour follows the colour mode and only the accent is matched by hue.
    if [[ -e $PAPIRUS/64x64/places/folder-cat-mocha-blue.svg ]]; then
        mkdir -p "$XDG_DATA_HOME/themes/Catppuccin-Yellow-Dark" \
                 "$XDG_DATA_HOME/themes/Catppuccin-Yellow-Light"

        cat_folder() { # $1=accent $2=mode $3=gtk theme -> folder-*.svg target
            printf '@define-color accent_bg_color %s;\n' "$1" \
                > "$XDG_CONFIG_HOME/gtk-4.0/dank-colors.css"
            rm -rf "$OVERLAY"
            "$ROOT/scripts/apply-theme.sh" --compositor generic --mode "$2" \
                --gtk-theme-dark "$3" --gtk-theme-light "$3" \
                --icon-theme Papirus-Dark --sync-folder-color true \
                --folder-base-theme Papirus-Dark --sync-kde false \
                --sync-xsettingsd false --backup-enabled false --no-runtime >/dev/null 2>&1
            basename "$(readlink "$OVERLAY/64x64/places/folder.svg")"
        }

        [[ $(cat_folder '#b6c4ff' dark Catppuccin-Yellow-Dark) == folder-cat-mocha-lavender.svg ]] \
            || { printf 'Catppuccin GTK theme did not map the accent to a mocha folder\n' >&2; exit 1; }
        [[ $(cat_folder '#b6c4ff' light Catppuccin-Yellow-Light) == folder-cat-latte-lavender.svg ]] \
            || { printf 'Light mode did not map the accent to a latte folder\n' >&2; exit 1; }

        # Catppuccin draws the paper inside the folder in the flavour's `text`
        # colour — a lavender at chroma ~16 — while rosewater sits at chroma 8.
        # Pick "most saturated fill" and folder-cat-mocha-rosewater reads as a
        # lavender, so a lavender accent would land on the pink folders.
        [[ $(cat_folder '#f2cdcd' dark Catppuccin-Yellow-Dark) == folder-cat-mocha-flamingo.svg ]] \
            || { printf 'Pastel accent did not map to its own folder (paper colour won)\n' >&2; exit 1; }

        # A non-Catppuccin GTK theme keeps the plain Papirus palette.
        [[ $(cat_folder '#e25252' dark Adwaita) == folder-red.svg ]] \
            || { printf 'Non-Catppuccin theme did not use the plain folder palette\n' >&2; exit 1; }

        # papirus-folders-catppuccin is an optional dependency: a Catppuccin GTK
        # theme on a machine that only has plain Papirus must fall back to the
        # nearest plain colour, not fail and not skip the overlay.
        NOCAT="$XDG_DATA_HOME/icons/Papirus-NoCat"
        mkdir -p "$NOCAT/64x64/places"
        cp -a "$PAPIRUS/64x64/places/." "$NOCAT/64x64/places/"
        rm -f "$NOCAT/64x64/places/"folder-cat-*
        cp "$PAPIRUS/index.theme" "$NOCAT/index.theme"
        printf '@define-color accent_bg_color #b6c4ff;\n' \
            > "$XDG_CONFIG_HOME/gtk-4.0/dank-colors.css"
        "$ROOT/scripts/apply-theme.sh" --compositor generic --mode dark \
            --gtk-theme-dark Catppuccin-Yellow-Dark --icon-theme Papirus-Dark \
            --sync-folder-color true --folder-base-theme Papirus-NoCat \
            --sync-kde false --sync-xsettingsd false --backup-enabled false \
            --no-runtime >/dev/null 2>&1
        [[ $(basename "$(readlink "$XDG_DATA_HOME/icons/Papirus-NoCat-DankFolders/64x64/places/folder.svg")") == folder-indigo.svg ]] \
            || { printf 'Catppuccin theme without the cat-* folders did not fall back to a plain colour\n' >&2; exit 1; }
        rm -rf "$NOCAT" "$XDG_DATA_HOME/icons/Papirus-NoCat-DankFolders"

        rm -rf "$OVERLAY"
        printf '@define-color accent_bg_color #e25252;\n' \
            > "$XDG_CONFIG_HOME/gtk-4.0/dank-colors.css"
    else
        printf 'catppuccin folders: skipped (papirus-folders-catppuccin not installed)\n'
    fi
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

# --- Flatpak overrides: opt-in, and never invoked when flatpak is absent ------
if command -v flatpak >/dev/null 2>&1; then
    flatpak_dry() {
        "$ROOT/scripts/apply-theme.sh" \
            --font "Archivo" --mono-font "Cascadia Mono" --document-font "Literata" \
            --font-size 11 --mono-size 12 --document-size 13 \
            --icon-theme "Papirus-Dark" --cursor-theme "Breeze" --cursor-size 32 \
            --mode light --gtk-theme-light auto --gtk-theme-dark auto \
            --qt-platform-theme qtct --qt-style Fusion --apply-matugen-colors true \
            --sync-kde false --sync-xsettingsd false \
            --backup-enabled false --backup-retention 10 --dry-run "$@" 2>&1
    }
    grep -q 'DRY-RUN: flatpak override' <<<"$(flatpak_dry --sync-flatpak true)" \
        || { printf 'Flatpak overrides not attempted with the toggle on\n' >&2; exit 1; }
    grep -q 'DRY-RUN: flatpak override' <<<"$(flatpak_dry --sync-flatpak false)" \
        && { printf 'Flatpak overrides attempted with the toggle off\n' >&2; exit 1; }
    # the icon theme name must reach the sandbox, or Flatpak apps keep the old one
    grep -q 'ICON_THEME=Papirus-Dark' <<<"$(flatpak_dry --sync-flatpak true)" \
        || { printf 'Icon theme missing from the flatpak override\n' >&2; exit 1; }
else
    printf 'flatpak overrides: skipped (flatpak not installed)\n'
fi

# --- Kvantum: rendered from the DMS palette, both files, no leftovers ---------
KV_COLORS="primary=#a1c9ff;on_surface=#f0f5ff;surface=#0e141c;surface_variant=#1f252d"
KV_COLORS="$KV_COLORS;surface_container_low=#1f252d;surface_container_highest=#2a323c"
KV_COLORS="$KV_COLORS;surface_bright=#2a323c;surface_dim=#0e141c;inverse_on_surface=#0e141c"
KV_COLORS="$KV_COLORS;inverse_primary=#00458a;primary_fixed_dim=#a1c9ff;tertiary_fixed_dim=#d6bee4"

run_kvantum() {
    "$ROOT/scripts/apply-theme.sh" \
        --font "Archivo" --mono-font "Cascadia Mono" --document-font "Literata" \
        --font-size 11 --mono-size 12 --document-size 13 \
        --icon-theme "Papirus-Dark" --cursor-theme "Breeze" --cursor-size 32 \
        --mode dark --gtk-theme-light auto --gtk-theme-dark auto \
        --qt-platform-theme qtct --apply-matugen-colors true \
        --sync-kde false --sync-xsettingsd false \
        --backup-enabled false --backup-retention 10 --no-runtime "$@" 2>&1
}

KV_DIR="$XDG_CONFIG_HOME/Kvantum/DankMatugen"

# off by default, and never rendered for a style other than kvantum
run_kvantum --qt-style Fusion --sync-kvantum true --kvantum-colors "$KV_COLORS" >/dev/null
[[ ! -d $KV_DIR ]] || { printf 'Kvantum theme rendered for a non-kvantum style\n' >&2; exit 1; }

if find /usr/lib /usr/lib64 -name 'libkvantum*.so' -print -quit 2>/dev/null | grep -q .; then
    out=$(run_kvantum --qt-style kvantum --sync-kvantum true --kvantum-colors "$KV_COLORS")
    [[ -f $KV_DIR/DankMatugen.kvconfig && -f $KV_DIR/DankMatugen.svg ]] \
        || { printf 'Kvantum theme files not rendered\n' >&2; exit 1; }
    # The .svg is where every widget is drawn; recolouring only the .kvconfig
    # leaves Kvantum drawing the template's colours.
    ! grep -q '{{colors' "$KV_DIR/DankMatugen.kvconfig" "$KV_DIR/DankMatugen.svg" \
        || { printf 'Unresolved colour placeholders left in the Kvantum theme\n' >&2; exit 1; }
    grep -q 'unresolved roles' <<<"$out" \
        && { printf 'Helper reported unresolved roles\n' >&2; exit 1; }
    assert_line "$XDG_CONFIG_HOME/Kvantum/kvantum.kvconfig" "theme=DankMatugen"
    python3 - "$KV_DIR/DankMatugen.svg" <<'PY' || { printf 'Rendered Kvantum SVG is not valid XML\n' >&2; exit 1; }
import sys, xml.dom.minidom
xml.dom.minidom.parse(sys.argv[1])
PY
    rm -rf "$XDG_CONFIG_HOME/Kvantum"
else
    printf 'kvantum: skipped (style plugin not installed)\n'
fi

# --- Qt platform theme: any plugin name Qt can load, and the style-is-inert note -
#
# qt5ct/qt6ct.conf is read by the qtXct platform theme and nobody else. Under
# gtk3 or kde the style we write is inert, and saying so is the whole point of
# the reconcile pass. Verified against qtdiag: PLATFORMTHEME=gtk3 reports
# "Styles requested: Fusion,windows".
# The compositor is forced generic: under Niri the KDL include replaces
# environment.d and deletes it, which is a different code path. Unsetting
# NIRI_SOCKET is not enough — detect_compositor also sniffs XDG_CURRENT_DESKTOP.
qt_note() { # $1=platform theme  $2=style  -> reconcile lines only
    env -u QT_QPA_PLATFORMTHEME -u QT_QPA_PLATFORMTHEME_QT6 \
        "$ROOT/scripts/apply-theme.sh" --compositor generic \
        --font Archivo --mono-font "Cascadia Mono" \
        --icon-theme Papirus-Dark --cursor-theme Breeze \
        --mode dark --sync-kde false --sync-xsettingsd false \
        --backup-enabled false --no-runtime \
        --qt-platform-theme "$1" --qt-style "$2" 2>&1 | grep '^reconcile:' || true
}

grep -q "style 'kvantum' in qt5ct/qt6ct.conf is ignored" <<<"$(qt_note gtk3 kvantum)" \
    || { printf 'No note that gtk3 ignores the Qt style\n' >&2; exit 1; }
grep -q "does not read qt5ct/qt6ct.conf" <<<"$(qt_note kde Breeze)" \
    || { printf 'No note that kde ignores the Qt style\n' >&2; exit 1; }
grep -q "no Qt platform theme is set" <<<"$(qt_note preserve kvantum)" \
    || { printf 'No note when nothing reads qt5ct/qt6ct.conf\n' >&2; exit 1; }
# qtct is the one combination where the style does arrive: stay quiet.
grep -q 'qt5ct/qt6ct.conf' <<<"$(qt_note qtct kvantum)" \
    && { printf 'Spurious note under the qtct platform theme\n' >&2; exit 1; }
# A style of "preserve" means we wrote none, so there is nothing to warn about.
grep -q 'is ignored' <<<"$(qt_note gtk3 preserve)" \
    && { printf 'Note about an ignored style when no style was written\n' >&2; exit 1; }

# Platform themes beyond gtk3/qtct used to fall through a closed case and be
# dropped without a word. They must reach environment.d verbatim.
rm -f "$XDG_CONFIG_HOME/environment.d/90-dms-theme-sync.conf"
qt_note xdgdesktopportal Fusion >/dev/null
assert_line "$XDG_CONFIG_HOME/environment.d/90-dms-theme-sync.conf" 'QT_QPA_PLATFORMTHEME=xdgdesktopportal'
assert_line "$XDG_CONFIG_HOME/environment.d/90-dms-theme-sync.conf" 'QT_QPA_PLATFORMTHEME_QT6=xdgdesktopportal'

# ...but the value lands in environment.d and in niri/Hyprland config, so a name
# that could break out of those files is rejected outright.
if "$ROOT/scripts/apply-theme.sh" --qt-platform-theme 'a b"c' --no-runtime >/dev/null 2>&1; then
    printf 'Accepted a Qt platform theme name with shell/KDL metacharacters\n' >&2
    exit 1
fi

# --- "auto": Kvantum when the machine has it, follow GTK when it does not -------
#
# Kvantum needs the qtXct platform theme to be read at all, so the two settings
# resolve together. DMS_THEME_SYNC_LIB_DIRS fakes both worlds regardless of what
# this machine has installed.
FAKE_KV="$TMP/with-kvantum"
NO_KV="$TMP/without-kvantum"
mkdir -p "$FAKE_KV" "$NO_KV"
: > "$FAKE_KV/libkvantum.so"

auto_env() { # $1=lib dirs -> "platformtheme|style"
    local envfile="$XDG_CONFIG_HOME/environment.d/90-dms-theme-sync.conf"
    rm -f "$envfile" "$XDG_CONFIG_HOME/qt6ct/qt6ct.conf"
    env -u QT_QPA_PLATFORMTHEME -u QT_QPA_PLATFORMTHEME_QT6 DMS_THEME_SYNC_LIB_DIRS="$1" \
        "$ROOT/scripts/apply-theme.sh" --compositor generic \
        --qt-platform-theme auto --qt-style auto \
        --sync-kvantum true --kvantum-colors "$KV_COLORS" \
        --sync-kde false --sync-xsettingsd false \
        --backup-enabled false --no-runtime >/dev/null 2>&1
    printf '%s|%s' \
        "$(sed -n 's/^QT_QPA_PLATFORMTHEME=//p' "$envfile" 2>/dev/null)" \
        "$(sed -n 's/^style=//p' "$XDG_CONFIG_HOME/qt6ct/qt6ct.conf" 2>/dev/null)"
}

[[ $(auto_env "$FAKE_KV") == 'qt5ct|kvantum' ]] \
    || { printf 'auto did not pick qtct+kvantum where Kvantum is installed\n' >&2; exit 1; }
[[ -d $XDG_CONFIG_HOME/Kvantum/DankMatugen ]] \
    || { printf 'auto picked kvantum but rendered no theme\n' >&2; exit 1; }
rm -rf "$XDG_CONFIG_HOME/Kvantum"

# No Kvantum: fall back to gtk3 and write no style at all, since under gtk3 a
# style in qt6ct.conf would never be read.
[[ $(auto_env "$NO_KV") == 'gtk3|' ]] \
    || { printf 'auto did not fall back to gtk3 with no style when Kvantum is absent\n' >&2; exit 1; }
[[ ! -d $XDG_CONFIG_HOME/Kvantum/DankMatugen ]] \
    || { printf 'Kvantum theme rendered without the style plugin installed\n' >&2; exit 1; }

# An explicit platform theme still wins over auto's preference: the style resolves
# against it, so under gtk3 "auto" writes nothing rather than something inert.
rm -f "$XDG_CONFIG_HOME/qt6ct/qt6ct.conf"
env -u QT_QPA_PLATFORMTHEME -u QT_QPA_PLATFORMTHEME_QT6 DMS_THEME_SYNC_LIB_DIRS="$FAKE_KV" \
    "$ROOT/scripts/apply-theme.sh" --compositor generic --qt-platform-theme gtk3 --qt-style auto \
    --sync-kde false --sync-xsettingsd false --backup-enabled false --no-runtime >/dev/null 2>&1
grep -q '^style=' "$XDG_CONFIG_HOME/qt6ct/qt6ct.conf" 2>/dev/null \
    && { printf 'auto wrote a Qt style under gtk3, where it is ignored\n' >&2; exit 1; }

# --- Niri: the platform theme reaches the KDL include, whatever its name -------
#
# write_niri_env_include used to re-derive the value from a closed gtk3|qtct case
# of its own, silently dropping anything else even after the rest of the script
# learned to carry it.
env -u QT_QPA_PLATFORMTHEME -u QT_QPA_PLATFORMTHEME_QT6 \
    "$ROOT/scripts/apply-theme.sh" --compositor niri --qt-platform-theme xdgdesktopportal \
    --qt-style preserve --sync-kde false --sync-xsettingsd false \
    --backup-enabled false --no-runtime >/dev/null 2>&1
grep -Fq 'QT_QPA_PLATFORMTHEME "xdgdesktopportal"' "$NIRI_DIR/dms-theme-sync.kdl" \
    || { printf 'Niri include dropped a platform theme outside gtk3/qtct\n' >&2; exit 1; }

printf 'helper tests: ok\n'
