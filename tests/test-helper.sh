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
grep -Fq '<family>Cascadia Mono</family>' "$XDG_CONFIG_HOME/fontconfig/conf.d/99-dms-theme-sync.conf"

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

printf 'helper tests: ok\n'
