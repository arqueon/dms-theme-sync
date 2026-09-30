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
assert_line "$XDG_CONFIG_HOME/qt5ct/qt5ct.conf" 'general="Archivo,11,-1,5,50,0,0,0,0,0"'
assert_line "$XDG_CONFIG_HOME/qt6ct/qt6ct.conf" 'fixed="Cascadia Mono,12,-1,5,50,0,0,0,0,0"'
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

# An application-theme reload must broadcast KDE's palette, font, and cursor
# changes, invalidate every public KIconLoader group (not only MainToolbar),
# and wake qt5ct/qt6ct's watchers for non-KDE Qt applications. Style changes
# are a restart boundary: broadcasting one produced partial live windows in
# Dolphin, so the apply helper reports them instead.
# Stub D-Bus so the contract is deterministic.
RELOAD_BIN="$TMP/reload-bin"
RELOAD_LOG="$TMP/icon-reload.log"
mkdir -p "$RELOAD_BIN"
cat > "$RELOAD_BIN/dbus-send" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${DMS_THEME_RELOAD_TEST_LOG:?}"
EOF
chmod +x "$RELOAD_BIN/dbus-send"

qt5_config="$XDG_CONFIG_HOME/qt5ct/qt5ct.conf"
qt6_config="$XDG_CONFIG_HOME/qt6ct/qt6ct.conf"
qt6_target="$TMP/managed-qt6ct.conf"
mv "$qt6_config" "$qt6_target"
ln -s "$qt6_target" "$qt6_config"
touch -d @1000000000 "$qt5_config" "$qt6_target"

PATH="$RELOAD_BIN:$PATH" DMS_THEME_RELOAD_TEST_LOG="$RELOAD_LOG" \
    "$ROOT/scripts/reload-application-theme.sh"

mapfile -t reload_calls < "$RELOAD_LOG"
[[ ${#reload_calls[@]} -eq 9 ]] \
    || { printf 'Expected 9 KDE theme notifications, got %s\n' "${#reload_calls[@]}" >&2; exit 1; }
for change_type in 0 1 5; do
    grep -Fqx -- "--session --type=signal /KGlobalSettings org.kde.KGlobalSettings.notifyChange int32:$change_type int32:0" "$RELOAD_LOG" \
        || { printf 'Missing KGlobalSettings change type %s notification\n' "$change_type" >&2; exit 1; }
done
! grep -Fq 'org.kde.KGlobalSettings.notifyChange int32:2 ' "$RELOAD_LOG" \
    || { printf 'StyleChanged must not be broadcast as a safe live reload\n' >&2; exit 1; }
for group in 0 1 2 3 4 5; do
    grep -Fqx -- "--session --type=signal /KIconLoader org.kde.KIconLoader.iconChanged int32:$group" "$RELOAD_LOG" \
        || { printf 'Missing KIconLoader group %s notification\n' "$group" >&2; exit 1; }
done
[[ -L $qt6_config ]] || { printf 'Qt watcher pulse replaced a managed symlink\n' >&2; exit 1; }
[[ $(stat -c %Y "$qt5_config") -gt 1000000000 ]] \
    || { printf 'qt5ct watcher was not notified\n' >&2; exit 1; }
[[ $(stat -c %Y "$qt6_target") -gt 1000000000 ]] \
    || { printf 'qt6ct watcher was not notified through its symlink\n' >&2; exit 1; }
rm "$qt6_config"
mv "$qt6_target" "$qt6_config"

# A real QStyle transition is recorded for the service/UI, while a palette
# refresh under an unchanged style stays quiet.
sed -i 's/^style=Fusion$/style=kvantum/' "$qt5_config" "$qt6_config"
qt_style_change_output=$("$ROOT/scripts/apply-theme.sh" \
    --font "Archivo" --mono-font "Cascadia Mono" --document-font "Literata" \
    --font-size 11 --mono-size 12 --document-size 13 \
    --icon-theme "Papirus-Dark" --cursor-theme "Breeze" --cursor-size 32 \
    --mode light --gtk-theme-light auto --gtk-theme-dark auto \
    --qt-platform-theme qtct --qt-style Fusion \
    --apply-matugen-colors true \
    --backup-enabled false --backup-retention 10 \
    --sync-kde true --sync-xsettingsd true --no-runtime)
grep -Fq 'QT_RESTART_REQUIRED:style:qt5:kvantum->Fusion,qt6:kvantum->Fusion' \
    <<<"$qt_style_change_output" \
    || { printf 'Qt style transition did not request a restart\n' >&2; exit 1; }
qt_palette_only_output=$("$ROOT/scripts/apply-theme.sh" \
    --font "Archivo" --mono-font "Cascadia Mono" --document-font "Literata" \
    --font-size 11 --mono-size 12 --document-size 13 \
    --icon-theme "Papirus-Dark" --cursor-theme "Breeze" --cursor-size 32 \
    --mode light --gtk-theme-light auto --gtk-theme-dark auto \
    --qt-platform-theme qtct --qt-style Fusion \
    --apply-matugen-colors true \
    --backup-enabled false --backup-retention 10 \
    --sync-kde true --sync-xsettingsd true --no-runtime)
! grep -Fq 'QT_RESTART_REQUIRED:style:' <<<"$qt_palette_only_output" \
    || { printf 'Unchanged Qt style requested a restart\n' >&2; exit 1; }

# Dotfile managers place symlinks at the paths the helper updates. Exercise the
# three structured writers plus generated GTK CSS and session files, using the
# relative link shape produced by GNU Stow/lnk.
DOTFILES="$HOME/dotfiles"
mkdir -p "$DOTFILES/gtk-3.0" "$DOTFILES/gtk-4.0" "$DOTFILES/environment.d"
mv "$XDG_CONFIG_HOME/gtk-3.0/settings.ini" "$DOTFILES/gtk-3.0/settings.ini"
ln -s ../../dotfiles/gtk-3.0/settings.ini "$XDG_CONFIG_HOME/gtk-3.0/settings.ini"
mv "$HOME/.gtkrc-2.0" "$DOTFILES/gtkrc-2.0"
ln -s dotfiles/gtkrc-2.0 "$HOME/.gtkrc-2.0"
mv "$XDG_CONFIG_HOME/xsettingsd/xsettingsd.conf" "$DOTFILES/xsettingsd.conf"
ln -s ../../dotfiles/xsettingsd.conf "$XDG_CONFIG_HOME/xsettingsd/xsettingsd.conf"
printf 'button { padding: 2px; }\n' > "$DOTFILES/gtk-4.0/gtk.css"
rm -f "$XDG_CONFIG_HOME/gtk-4.0/gtk.css"
ln -s ../../dotfiles/gtk-4.0/gtk.css "$XDG_CONFIG_HOME/gtk-4.0/gtk.css"
# DMS itself links GTK3's watched stylesheet directly to the generated Matugen
# palette. Theme Sync must refresh that file without replacing its contents
# with an import of itself.
rm -f "$XDG_CONFIG_HOME/gtk-3.0/gtk.css"
ln -s dank-colors.css "$XDG_CONFIG_HOME/gtk-3.0/gtk.css"
mv "$XDG_CONFIG_HOME/environment.d/90-dms-theme-sync.conf" \
    "$DOTFILES/environment.d/90-dms-theme-sync.conf"
ln -s ../../dotfiles/environment.d/90-dms-theme-sync.conf \
    "$XDG_CONFIG_HOME/environment.d/90-dms-theme-sync.conf"

"$ROOT/scripts/apply-theme.sh" \
    --font "Archivo" --mono-font "Cascadia Mono" --document-font "Literata" \
    --font-size 11 --mono-size 12 --document-size 13 \
    --icon-theme "Papirus-Dark" --cursor-theme "Breeze" --cursor-size 32 \
    --mode light --gtk-theme-light auto --gtk-theme-dark auto \
    --qt-platform-theme qtct --qt-style Fusion \
    --apply-matugen-colors true \
    --backup-enabled false --backup-retention 10 \
    --sync-kde true --sync-xsettingsd true --no-runtime >/dev/null

for managed_link in \
    "$XDG_CONFIG_HOME/gtk-3.0/settings.ini" \
    "$XDG_CONFIG_HOME/gtk-3.0/gtk.css" \
    "$HOME/.gtkrc-2.0" \
    "$XDG_CONFIG_HOME/xsettingsd/xsettingsd.conf" \
    "$XDG_CONFIG_HOME/gtk-4.0/gtk.css" \
    "$XDG_CONFIG_HOME/environment.d/90-dms-theme-sync.conf"; do
    [[ -L $managed_link ]] \
        || { printf 'Managed symlink was replaced: %s\n' "$managed_link" >&2; exit 1; }
done
assert_line "$DOTFILES/gtk-3.0/settings.ini" "gtk-font-name=Archivo 11"
grep -Fq 'Generated with Matugen' "$XDG_CONFIG_HOME/gtk-3.0/dank-colors.css" \
    || { printf 'GTK3 Matugen palette was overwritten through gtk.css symlink\n' >&2; exit 1; }
! grep -Fqx '@import url("dank-colors.css");' "$XDG_CONFIG_HOME/gtk-3.0/dank-colors.css" \
    || { printf 'GTK3 Matugen palette imports itself\n' >&2; exit 1; }
assert_line "$DOTFILES/gtkrc-2.0" 'gtk-theme-name="Matcha-light-sea"'
assert_line "$DOTFILES/xsettingsd.conf" 'Net/IconThemeName "Papirus-Dark"'
assert_line "$DOTFILES/gtk-4.0/gtk.css" '@import url("dank-colors.css");'
assert_line "$DOTFILES/environment.d/90-dms-theme-sync.conf" 'QT_QPA_PLATFORMTHEME=qt5ct'

printf 'before-symlink-restore\n' >> "$DOTFILES/gtk-3.0/settings.ini"
symlink_backup=$("$ROOT/scripts/theme-snapshot.sh" backup --retention 10 --label symlinks --no-runtime)
symlink_snapshot=${symlink_backup#BACKUP_CREATED:}
awk -F '\t' -v p="$XDG_CONFIG_HOME/gtk-3.0/settings.ini" \
    '$3 == p && $4 == "present" { found=1 } END { exit !found }' \
    "$HOME/.local/state/DankMaterialShell/plugins/dmsThemeSync/backups/$symlink_snapshot/manifest.tsv" \
    || { printf 'Symlink target was not recorded in snapshot manifest\n' >&2; exit 1; }
printf 'mutated-after-symlink-backup\n' > "$DOTFILES/gtk-3.0/settings.ini"
"$ROOT/scripts/theme-snapshot.sh" restore --snapshot "$symlink_snapshot" --no-runtime >/dev/null
[[ -L $XDG_CONFIG_HOME/gtk-3.0/settings.ini ]] \
    || { printf 'Snapshot restore replaced a managed symlink\n' >&2; exit 1; }
grep -Fq 'before-symlink-restore' "$DOTFILES/gtk-3.0/settings.ini" \
    || { printf 'Snapshot restore did not recover the symlink target content\n' >&2; exit 1; }

# Restore regular files so the snapshot tests below continue to exercise their
# original scope. Snapshotting arbitrary external dotfile repositories is not
# part of this helper's backup contract.
rm -f "$XDG_CONFIG_HOME/gtk-3.0/settings.ini" "$HOME/.gtkrc-2.0" \
    "$XDG_CONFIG_HOME/gtk-3.0/gtk.css" \
    "$XDG_CONFIG_HOME/xsettingsd/xsettingsd.conf" \
    "$XDG_CONFIG_HOME/gtk-4.0/gtk.css" \
    "$XDG_CONFIG_HOME/environment.d/90-dms-theme-sync.conf"
mv "$DOTFILES/gtk-3.0/settings.ini" "$XDG_CONFIG_HOME/gtk-3.0/settings.ini"
mv "$DOTFILES/gtkrc-2.0" "$HOME/.gtkrc-2.0"
mv "$DOTFILES/xsettingsd.conf" "$XDG_CONFIG_HOME/xsettingsd/xsettingsd.conf"
mv "$DOTFILES/gtk-4.0/gtk.css" "$XDG_CONFIG_HOME/gtk-4.0/gtk.css"
printf '@import url("dank-colors.css");\n' > "$XDG_CONFIG_HOME/gtk-3.0/gtk.css"
mv "$DOTFILES/environment.d/90-dms-theme-sync.conf" \
    "$XDG_CONFIG_HOME/environment.d/90-dms-theme-sync.conf"

printf 'pre-backup-marker\n' >> "$XDG_CONFIG_HOME/gtk-3.0/settings.ini"
rm -f "$XDG_CONFIG_HOME/environment.d/90-dms-theme-sync.conf"
FLATPAK_OVERRIDE="$XDG_DATA_HOME/flatpak/overrides/global"
mkdir -p "$(dirname "$FLATPAK_OVERRIDE")"
printf '[Environment]\nGTK_THEME=legacy-theme\n' > "$FLATPAK_OVERRIDE"
mkdir -p "$XDG_CONFIG_HOME/hypr" "$XDG_CONFIG_HOME/niri" "$XDG_CONFIG_HOME/Kvantum"
printf 'before-source\n' > "$XDG_CONFIG_HOME/hypr/hyprland.conf"
printf 'before-include\n' > "$XDG_CONFIG_HOME/niri/config.kdl"
printf '[General]\ntheme=Before\n' > "$XDG_CONFIG_HOME/Kvantum/kvantum.kvconfig"
backup_output=$("$ROOT/scripts/theme-snapshot.sh" backup --retention 3 --label test --no-runtime)
snapshot=${backup_output#BACKUP_CREATED:}
printf 'mutated\n' > "$XDG_CONFIG_HOME/gtk-3.0/settings.ini"
printf 'created-after-backup\n' > "$XDG_CONFIG_HOME/environment.d/90-dms-theme-sync.conf"
printf '[Environment]\nGTK_THEME=mutated-theme\n' > "$FLATPAK_OVERRIDE"
printf 'after-source\n' > "$XDG_CONFIG_HOME/hypr/hyprland.conf"
printf 'after-include\n' > "$XDG_CONFIG_HOME/niri/config.kdl"
printf '[General]\ntheme=After\n' > "$XDG_CONFIG_HOME/Kvantum/kvantum.kvconfig"

"$ROOT/scripts/theme-snapshot.sh" restore --snapshot "$snapshot" --no-runtime >/dev/null
grep -Fq 'pre-backup-marker' "$XDG_CONFIG_HOME/gtk-3.0/settings.ini"
grep -Fq 'GTK_THEME=legacy-theme' "$FLATPAK_OVERRIDE" \
    || { printf 'Restore did not recover the Flatpak override\n' >&2; exit 1; }
grep -Fqx 'before-source' "$XDG_CONFIG_HOME/hypr/hyprland.conf"
grep -Fqx 'before-include' "$XDG_CONFIG_HOME/niri/config.kdl"
grep -Fqx 'theme=Before' "$XDG_CONFIG_HOME/Kvantum/kvantum.kvconfig"
[[ ! -e $XDG_CONFIG_HOME/environment.d/90-dms-theme-sync.conf ]] || {
    printf 'Restore did not remove a file that was absent in the snapshot\n' >&2
    exit 1
}
# list prints "id<TAB>name"; the name column is empty when unnamed.
"$ROOT/scripts/theme-snapshot.sh" list | cut -f1 | grep -Fqx "$snapshot"

# --- Named snapshots are pinned: retention neither counts nor deletes them ----
snap_named=$("$ROOT/scripts/theme-snapshot.sh" backup --retention 2 --no-runtime --name "keep me" )
snap_named=${snap_named#BACKUP_CREATED:}
for _ in 1 2 3; do
    sleep 1.1
    "$ROOT/scripts/theme-snapshot.sh" backup --retention 2 --no-runtime >/dev/null
done
"$ROOT/scripts/theme-snapshot.sh" list | grep -Fq "$snap_named	keep me" \
    || { printf 'Named snapshot was rotated away by retention\n' >&2; exit 1; }
[[ $("$ROOT/scripts/theme-snapshot.sh" list | awk -F'\t' '$2==""' | wc -l) -eq 2 ]] \
    || { printf 'Unnamed snapshots did not rotate to the retention limit\n' >&2; exit 1; }

# Pinning an existing snapshot exempts it; unpinning returns it to the rotation.
oldest_unnamed=$("$ROOT/scripts/theme-snapshot.sh" list | awk -F'\t' '$2==""' | tail -1 | cut -f1)
"$ROOT/scripts/theme-snapshot.sh" name --snapshot "$oldest_unnamed" --name "pinned later" >/dev/null
sleep 1.1
"$ROOT/scripts/theme-snapshot.sh" backup --retention 1 --no-runtime >/dev/null
"$ROOT/scripts/theme-snapshot.sh" list | cut -f1 | grep -Fqx "$oldest_unnamed" \
    || { printf 'Snapshot pinned after creation was still rotated away\n' >&2; exit 1; }
"$ROOT/scripts/theme-snapshot.sh" name --snapshot "$oldest_unnamed" --name "" >/dev/null
sleep 1.1
"$ROOT/scripts/theme-snapshot.sh" backup --retention 1 --no-runtime >/dev/null
"$ROOT/scripts/theme-snapshot.sh" list | cut -f1 | grep -Fqx "$oldest_unnamed" \
    && { printf 'Unpinned snapshot survived the rotation\n' >&2; exit 1; }

# A stray directory in the backup root must neither be listed nor eat slots.
mkdir -p "$HOME/.local/state/DankMaterialShell/plugins/dmsThemeSync/backups/stray-dir"
"$ROOT/scripts/theme-snapshot.sh" list | cut -f1 | grep -q '^stray-dir$' \
    && { printf 'Non-snapshot directory listed as a snapshot\n' >&2; exit 1; }

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
        --compositor niri "$@" >/dev/null
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

# --- Niri focused-border dimming: opt-in, follows dms/colors.kdl --------------
mkdir -p "$NIRI_DIR/dms"
cat > "$NIRI_DIR/dms/colors.kdl" <<'EOF'
layout {
    focus-ring {
        active-color   "#9ee600"
        inactive-color "#a6ab99"
    }

    border {
        active-color   "#9ee600"
        inactive-color "#a6ab99"
    }
}

recent-windows {
    highlight {
        active-color   "#6d9f00"
        urgent-color   "#ffc3bb"
    }
}
EOF

# default off: the include carries no colour override
run_niri
grep -q 'active-color' "$NIRI_DIR/dms-theme-sync.kdl" \
    && { printf 'Border override written without opt-in\n' >&2; exit 1; }

# on: border and focus-ring take the darker container tone — and nothing else.
# The inactive/urgent colours must stay DMS's, so they never appear here.
run_niri --dim-niri-border true
[[ $(grep -c 'active-color "#6d9f00"' "$NIRI_DIR/dms-theme-sync.kdl") -eq 2 ]] \
    || { printf 'Border override missing or incomplete:\n%s\n' "$(cat "$NIRI_DIR/dms-theme-sync.kdl")" >&2; exit 1; }
grep -Eq 'inactive-color|urgent-color' "$NIRI_DIR/dms-theme-sync.kdl" \
    && { printf 'Border override leaked beyond the active colours\n' >&2; exit 1; }

# off again: the next apply drops the block and DMS colours return
run_niri
grep -q 'layout' "$NIRI_DIR/dms-theme-sync.kdl" \
    && { printf 'Border override survived the toggle being turned off\n' >&2; exit 1; }

# generated palette missing or unparseable: honest skip, include still written
mv "$NIRI_DIR/dms/colors.kdl" "$NIRI_DIR/dms/colors.kdl.away"
dim_out=$("$ROOT/scripts/apply-theme.sh" \
    --font "Archivo" --mono-font "Cascadia Mono" --document-font "Literata" \
    --font-size 11 --mono-size 12 --document-size 13 \
    --icon-theme "Papirus-Dark" --cursor-theme "Breeze" --cursor-size 32 \
    --mode light --gtk-theme-light auto --gtk-theme-dark auto \
    --qt-platform-theme qtct --qt-style Fusion \
    --apply-matugen-colors true \
    --backup-enabled false --backup-retention 10 \
    --sync-kde true --sync-xsettingsd true --no-runtime \
    --compositor niri --dim-niri-border true 2>&1)
printf '%s\n' "$dim_out" | grep -q 'niri-border: no primary_container tone' \
    || { printf 'Missing palette not reported:\n%s\n' "$dim_out" >&2; exit 1; }
grep -q 'active-color' "$NIRI_DIR/dms-theme-sync.kdl" \
    && { printf 'Border override written from a missing palette\n' >&2; exit 1; }
mv "$NIRI_DIR/dms/colors.kdl.away" "$NIRI_DIR/dms/colors.kdl"

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

# --- GTK <-> Qt routes: detection, pairing, and the vanilla-qt6ct diagnostic ---

# Controlled detection environments. The qt6ct discriminator is the
# libKF6ColorScheme NEEDED string in libqt6ct-common: only the -kde build
# carries it, so a file with (or without) that string is a faithful stand-in.
KVLIB="$TMP/kvlib"; mkdir -p "$KVLIB"; : > "$KVLIB/libkvantum-fake.so"
NOKVLIB="$TMP/nokvlib"; mkdir -p "$NOKVLIB"
QT6KDE="$TMP/qt6kde"; mkdir -p "$QT6KDE"
printf 'libKF6ColorScheme.so.6' > "$QT6KDE/libqt6ct-common.so.0.11"
QT6VAN="$TMP/qt6van"; mkdir -p "$QT6VAN"
printf 'no kde here' > "$QT6VAN/libqt6ct-common.so.0.11"
QT5STYLES="$TMP/qt5styles"; mkdir -p "$QT5STYLES"; : > "$QT5STYLES/breeze5.so"
QT6STYLES="$TMP/qt6styles"; mkdir -p "$QT6STYLES"; : > "$QT6STYLES/breeze6.so"
NOQT5STYLES="$TMP/noqt5styles"; mkdir -p "$NOQT5STYLES"
NOQTSTYLES="$TMP/noqtstyles"; mkdir -p "$NOQTSTYLES"

# A same-author pair: WhiteSur GTK (both modes) and WhiteSur Kvantum halves.
mkdir -p "$XDG_DATA_HOME/themes/WhiteSur-Dark" "$XDG_DATA_HOME/themes/WhiteSur" \
    "$XDG_CONFIG_HOME/Kvantum/WhiteSurDark" "$XDG_CONFIG_HOME/Kvantum/WhiteSur"
: > "$XDG_CONFIG_HOME/Kvantum/WhiteSurDark/WhiteSurDark.kvconfig"
: > "$XDG_CONFIG_HOME/Kvantum/WhiteSur/WhiteSur.kvconfig"

# --compositor sway: the Niri block above created ~/.config/niri, and without
# an explicit compositor the helper would sniff the real session (niri) and
# route the env vars into the KDL include instead of environment.d.
run_route() {
    "$ROOT/scripts/apply-theme.sh" \
        --font "Archivo" --mono-font "Cascadia Mono" \
        --font-size 11 --mono-size 12 --document-size 13 \
        --icon-theme "Papirus-Dark" --cursor-theme "Breeze" --cursor-size 32 \
        --gtk-theme-light auto --gtk-theme-dark auto \
        --apply-matugen-colors true \
        --backup-enabled false --backup-retention 10 \
        --sync-kde true --sync-xsettingsd true --no-runtime \
        --compositor sway "$@"
}

# auto + Kvantum + pair installed: qtct platform, kvantum style, pair selected
DMS_THEME_SYNC_LIB_DIRS="$KVLIB" DMS_THEME_SYNC_QT6CT_DIRS="$QT6VAN" \
    run_route --mode dark --gtk-theme-dark WhiteSur-Dark --qt-sync-mode auto >/dev/null
assert_line "$XDG_CONFIG_HOME/Kvantum/kvantum.kvconfig" "theme=WhiteSurDark"
assert_line "$XDG_CONFIG_HOME/qt6ct/qt6ct.conf" "style=kvantum"
assert_line "$XDG_CONFIG_HOME/environment.d/90-dms-theme-sync.conf" "QT_QPA_PLATFORMTHEME=qt5ct"

# light mode picks the light half of the same pair
DMS_THEME_SYNC_LIB_DIRS="$KVLIB" DMS_THEME_SYNC_QT6CT_DIRS="$QT6VAN" \
    run_route --mode light --gtk-theme-light WhiteSur --qt-sync-mode auto >/dev/null
assert_line "$XDG_CONFIG_HOME/Kvantum/kvantum.kvconfig" "theme=WhiteSur"

# Matcha encodes the variant order differently on each side:
# GTK Matcha-dark-sea / Matcha-sea, Kvantum Matcha-sea-dark / Matcha-sea.
# Keep this audited pair explicit so token scoring cannot regress silently.
mkdir -p "$XDG_DATA_HOME/themes/Matcha-dark-sea" "$XDG_DATA_HOME/themes/Matcha-sea" \
    "$XDG_CONFIG_HOME/Kvantum/Matcha-sea-dark" "$XDG_CONFIG_HOME/Kvantum/Matcha-sea"
: > "$XDG_CONFIG_HOME/Kvantum/Matcha-sea-dark/Matcha-sea-dark.kvconfig"
: > "$XDG_CONFIG_HOME/Kvantum/Matcha-sea/Matcha-sea.kvconfig"
DMS_THEME_SYNC_LIB_DIRS="$KVLIB" DMS_THEME_SYNC_QT6CT_DIRS="$QT6VAN" \
    run_route --mode dark --gtk-theme-dark Matcha-dark-sea --qt-sync-mode auto >/dev/null
assert_line "$XDG_CONFIG_HOME/Kvantum/kvantum.kvconfig" "theme=Matcha-sea-dark"
DMS_THEME_SYNC_LIB_DIRS="$KVLIB" DMS_THEME_SYNC_QT6CT_DIRS="$QT6VAN" \
    run_route --mode light --gtk-theme-light Matcha-sea --qt-sync-mode auto >/dev/null
assert_line "$XDG_CONFIG_HOME/Kvantum/kvantum.kvconfig" "theme=Matcha-sea"
# Keep the GTK fixtures for the later no-pair case, but remove the installed
# Kvantum halves so that case is genuinely isolated.
rm -rf "$XDG_CONFIG_HOME/Kvantum/Matcha-sea-dark" \
    "$XDG_CONFIG_HOME/Kvantum/Matcha-sea"

# Breeze is a native Qt style pair, not a Kvantum theme. Automatic mode should
# use it only when both the Qt5 and Qt6 style plugins are installed, so neither
# generation silently falls back to Fusion.
mkdir -p "$XDG_DATA_HOME/themes/Breeze-Dark" "$XDG_DATA_HOME/themes/Breeze"
DMS_THEME_SYNC_LIB_DIRS="$KVLIB" DMS_THEME_SYNC_QT6CT_DIRS="$QT6KDE" \
DMS_THEME_SYNC_QT5_STYLE_DIRS="$QT5STYLES" DMS_THEME_SYNC_QT6_STYLE_DIRS="$QT6STYLES" \
    run_route --mode dark --gtk-theme-dark Breeze-Dark --qt-sync-mode auto >/dev/null
assert_line "$XDG_CONFIG_HOME/qt5ct/qt5ct.conf" "style=Breeze"
assert_line "$XDG_CONFIG_HOME/qt6ct/qt6ct.conf" "style=Breeze"

breeze_probe=$(DMS_THEME_SYNC_LIB_DIRS="$KVLIB" DMS_THEME_SYNC_QT6CT_DIRS="$QT6KDE" \
    DMS_THEME_SYNC_QT5_STYLE_DIRS="$QT5STYLES" DMS_THEME_SYNC_QT6_STYLE_DIRS="$QT6STYLES" \
    run_route --mode dark --gtk-theme-dark Breeze-Dark --qt-sync-mode auto --probe-qt)
grep -Fxq 'native-pair=Breeze' <<<"$breeze_probe" \
    || { printf 'Breeze native pair missing from probe:\n%s\n' "$breeze_probe" >&2; exit 1; }
grep -Fxq 'route=native' <<<"$breeze_probe" \
    || { printf 'Breeze native route not selected:\n%s\n' "$breeze_probe" >&2; exit 1; }

# A partial pair is not safe: Qt6 Breeze without breeze5 would strand Qt5 apps.
breeze_probe=$(DMS_THEME_SYNC_LIB_DIRS="$KVLIB" DMS_THEME_SYNC_QT6CT_DIRS="$QT6KDE" \
    DMS_THEME_SYNC_QT5_STYLE_DIRS="$NOQT5STYLES" DMS_THEME_SYNC_QT6_STYLE_DIRS="$QT6STYLES" \
    run_route --mode dark --gtk-theme-dark Breeze-Dark --qt-sync-mode auto --probe-qt)
grep -Fxq 'native-pair=none' <<<"$breeze_probe" \
    || { printf 'Partial Breeze pair was accepted:\n%s\n' "$breeze_probe" >&2; exit 1; }
grep -Fxq 'native-missing=qt5' <<<"$breeze_probe" \
    || { printf 'Missing breeze5 was not diagnosed:\n%s\n' "$breeze_probe" >&2; exit 1; }
grep -Fxq 'route=native' <<<"$breeze_probe" \
    && { printf 'Partial Breeze pair selected the native route:\n%s\n' "$breeze_probe" >&2; exit 1; }

# auto without Kvantum but with qt6ct-kde: the KColorScheme route (qtct + Fusion)
DMS_THEME_SYNC_LIB_DIRS="$NOKVLIB" DMS_THEME_SYNC_QT6CT_DIRS="$QT6KDE" \
DMS_THEME_SYNC_QT5_STYLE_DIRS="$NOQTSTYLES" DMS_THEME_SYNC_QT6_STYLE_DIRS="$NOQTSTYLES" \
    run_route --mode dark --gtk-theme-dark auto --qt-sync-mode auto >/dev/null
assert_line "$XDG_CONFIG_HOME/qt6ct/qt6ct.conf" "style=Fusion"
assert_line "$XDG_CONFIG_HOME/environment.d/90-dms-theme-sync.conf" "QT_QPA_PLATFORMTHEME=qt5ct"

# auto with neither: Qt follows GTK
DMS_THEME_SYNC_LIB_DIRS="$NOKVLIB" DMS_THEME_SYNC_QT6CT_DIRS="$QT6VAN" \
DMS_THEME_SYNC_QT5_STYLE_DIRS="$NOQTSTYLES" DMS_THEME_SYNC_QT6_STYLE_DIRS="$NOQTSTYLES" \
    run_route --mode dark --gtk-theme-dark auto --qt-sync-mode auto >/dev/null
assert_line "$XDG_CONFIG_HOME/environment.d/90-dms-theme-sync.conf" "QT_QPA_PLATFORMTHEME=gtk3"

# explicit pair mode with no matching Kvantum theme: falls back to the
# DankMatugen render, and says so
mkdir -p "$XDG_DATA_HOME/themes/NoPair-Dark"
kv_roles="primary=#112233;on_surface=#e0e0e0;surface=#101010;surface_variant=#202020"
kv_roles+=";surface_container_low=#151515;surface_container_highest=#252525"
kv_roles+=";surface_bright=#303030;surface_dim=#0a0a0a;inverse_on_surface=#101010"
kv_roles+=";inverse_primary=#334455;primary_fixed_dim=#223344;tertiary_fixed_dim=#445566"
route_out=$(DMS_THEME_SYNC_LIB_DIRS="$KVLIB" DMS_THEME_SYNC_QT6CT_DIRS="$QT6VAN" \
    run_route --mode dark --gtk-theme-dark NoPair-Dark --qt-sync-mode pair \
    --sync-kvantum true --kvantum-colors "$kv_roles")
grep -q 'no Kvantum theme pairs' <<<"$route_out" \
    || { printf 'Pair fallback not reported:\n%s\n' "$route_out" >&2; exit 1; }
assert_line "$XDG_CONFIG_HOME/Kvantum/kvantum.kvconfig" "theme=DankMatugen"

# stock qt6ct + .colors palette + non-kvantum style: the silent no-op is named
route_out=$(DMS_THEME_SYNC_LIB_DIRS="$NOKVLIB" DMS_THEME_SYNC_QT6CT_DIRS="$QT6VAN" \
    run_route --mode dark --gtk-theme-dark auto --qt-platform-theme qtct --qt-style Fusion)
grep -q 'install qt6ct-kde' <<<"$route_out" \
    || { printf 'Vanilla qt6ct diagnostic missing:\n%s\n' "$route_out" >&2; exit 1; }

# with qt6ct-kde present the same run stays quiet about it
route_out=$(DMS_THEME_SYNC_LIB_DIRS="$NOKVLIB" DMS_THEME_SYNC_QT6CT_DIRS="$QT6KDE" \
    run_route --mode dark --gtk-theme-dark auto --qt-platform-theme qtct --qt-style Fusion)
grep -q 'cannot parse DankMatugen.colors' <<<"$route_out" \
    && { printf 'Diagnostic fired with qt6ct-kde installed\n' >&2; exit 1; }

# --probe-qt answers without touching anything
probe_before=$(find "$HOME" -type f -exec sha256sum {} + | LC_ALL=C sort)
probe_out=$(DMS_THEME_SYNC_LIB_DIRS="$KVLIB" DMS_THEME_SYNC_QT6CT_DIRS="$QT6KDE" \
    run_route --mode dark --gtk-theme-dark WhiteSur-Dark --qt-sync-mode auto --probe-qt)
probe_after=$(find "$HOME" -type f -exec sha256sum {} + | LC_ALL=C sort)
[[ $probe_before == "$probe_after" ]] || { printf 'Probe wrote to disk\n' >&2; exit 1; }
grep -Fxq 'qt6ct=kde' <<<"$probe_out" || { printf 'Probe qt6ct wrong:\n%s\n' "$probe_out" >&2; exit 1; }
grep -Fxq 'kvantum=yes' <<<"$probe_out" || { printf 'Probe kvantum wrong\n' >&2; exit 1; }
grep -Fxq 'pair=WhiteSurDark' <<<"$probe_out" || { printf 'Probe pair wrong:\n%s\n' "$probe_out" >&2; exit 1; }
grep -Fxq 'route=pair' <<<"$probe_out" || { printf 'Probe route wrong:\n%s\n' "$probe_out" >&2; exit 1; }

# Catppuccin: the accent token refines the pick within the mode's flavour
mkdir -p "$XDG_DATA_HOME/themes/Catppuccin-Flamingo-Dark" \
    "$XDG_CONFIG_HOME/Kvantum/catppuccin-mocha-blue" \
    "$XDG_CONFIG_HOME/Kvantum/catppuccin-mocha-flamingo" \
    "$XDG_CONFIG_HOME/Kvantum/catppuccin-latte-flamingo"
for t in catppuccin-mocha-blue catppuccin-mocha-flamingo catppuccin-latte-flamingo; do
    : > "$XDG_CONFIG_HOME/Kvantum/$t/$t.kvconfig"
done
probe_out=$(DMS_THEME_SYNC_LIB_DIRS="$KVLIB" DMS_THEME_SYNC_QT6CT_DIRS="$QT6VAN" \
    run_route --mode dark --gtk-theme-dark Catppuccin-Flamingo-Dark --qt-sync-mode auto --probe-qt)
grep -Fxq 'pair=catppuccin-mocha-flamingo' <<<"$probe_out" \
    || { printf 'Catppuccin accent pairing wrong:\n%s\n' "$probe_out" >&2; exit 1; }

# The blocks below assume a pristine Kvantum state (their first assertion is
# that nothing has been rendered), so drop everything this block created.
rm -rf "$XDG_CONFIG_HOME/Kvantum"

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
        local folder_mode=${TEST_FOLDER_MODE:-dark}
        "$ROOT/scripts/apply-theme.sh" \
            --font "Archivo" --mono-font "Cascadia Mono" --document-font "Literata" \
            --font-size 11 --mono-size 12 --document-size 13 \
            --icon-theme "Papirus-Dark" --cursor-theme "Breeze" --cursor-size 32 \
            --mode "$folder_mode" --gtk-theme-light auto --gtk-theme-dark auto \
            --qt-platform-theme qtct --qt-style Fusion \
            --apply-matugen-colors true --sync-kde false --sync-xsettingsd false \
            --backup-enabled false --backup-retention 10 --no-runtime "$@"
    }

    run_folder --sync-folder-color false >/dev/null
    [[ ! -d $OVERLAY ]] || { printf 'Overlay built while the toggle was off\n' >&2; exit 1; }
    assert_line "$XDG_CONFIG_HOME/gtk-3.0/settings.ini" "gtk-icon-theme-name=Papirus-Dark"

    folder_first_output=$(run_folder --sync-folder-color true)
    grep -Fqx "ICON_THEME_RELOAD_REQUIRED:Papirus-Dark-DankFolders" <<<"$folder_first_output" \
        || { printf 'First overlay build did not request an icon reload\n' >&2; exit 1; }
    [[ -d $OVERLAY ]] || { printf 'Overlay not built with the toggle on\n' >&2; exit 1; }
    # a red accent must resolve to the `red` folders, not to a themed near-hue
    [[ $(readlink "$OVERLAY/64x64/places/folder.svg") == *"/folder-red.svg" ]] \
        || { printf 'Accent did not map to the red folder set\n' >&2; exit 1; }
    grep -Fqx "Inherits=Papirus-Dark,hicolor" "$OVERLAY/index.theme" \
        || { printf 'Overlay does not inherit from the base theme\n' >&2; exit 1; }
    grep -Fqx "X-DmsThemeSync-Signature=Papirus-Dark:red" "$OVERLAY/index.theme" \
        || { printf 'Overlay signature does not describe its source and colour\n' >&2; exit 1; }
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

    # Rebuilding the same derived theme must stay quiet: the D-Bus reload is
    # reserved for semantic changes, not every automatic synchronization.
    folder_repeat_output=$(run_folder --sync-folder-color true)
    ! grep -Fq "ICON_THEME_RELOAD_REQUIRED:" <<<"$folder_repeat_output" \
        || { printf 'Unchanged overlay requested a redundant icon reload\n' >&2; exit 1; }

    # The theme name remains stable across a mode flip, but its inheritance
    # changes. That exact transition used to leave Dolphin's toolbar pixmaps
    # cached until the application was restarted.
    if [[ -d ${PAPIRUS%-Dark}/64x64/places ]]; then
        folder_light_output=$(TEST_FOLDER_MODE=light run_folder --sync-folder-color true)
        grep -Fqx "Inherits=Papirus,hicolor" "$OVERLAY/index.theme" \
            || { printf 'Light mode did not derive the overlay from Papirus\n' >&2; exit 1; }
        grep -Fq "ICON_THEME_RELOAD_REQUIRED:" <<<"$folder_light_output" \
            || { printf 'Dark-to-light overlay change did not request an icon reload\n' >&2; exit 1; }

        folder_dark_output=$(run_folder --sync-folder-color true)
        grep -Fqx "Inherits=Papirus-Dark,hicolor" "$OVERLAY/index.theme" \
            || { printf 'Dark mode did not restore the Papirus-Dark inheritance\n' >&2; exit 1; }
        grep -Fq "ICON_THEME_RELOAD_REQUIRED:" <<<"$folder_dark_output" \
            || { printf 'Light-to-dark overlay change did not request an icon reload\n' >&2; exit 1; }
    fi

    # turning it back off removes the generated theme
    folder_remove_output=$(run_folder --sync-folder-color false)
    [[ ! -d $OVERLAY ]] || { printf 'Overlay survived the toggle being turned off\n' >&2; exit 1; }
    grep -Fq "ICON_THEME_RELOAD_REQUIRED:" <<<"$folder_remove_output" \
        || { printf 'Removing the active overlay did not request an icon reload\n' >&2; exit 1; }
    assert_line "$XDG_CONFIG_HOME/gtk-3.0/settings.ini" "gtk-icon-theme-name=Papirus-Dark"

    # --- Dark mode derives the overlay from the base's dark variant -----------
    #
    # folderColorBaseTheme remembers a light base ("Papirus"); in dark mode the
    # overlay must keep that name — the QML side recomputes it — but inherit
    # Papirus-Dark, or every monochrome action icon renders #444444 against a
    # near-black palette.
    if [[ -d ${PAPIRUS%-Dark}/64x64/places ]]; then
        OVERLAY_LIGHTBASE="$XDG_DATA_HOME/icons/Papirus-DankFolders"
        run_folder --sync-folder-color true --folder-base-theme Papirus >/dev/null
        [[ -d $OVERLAY_LIGHTBASE ]] \
            || { printf 'Overlay not named after the configured base\n' >&2; exit 1; }
        grep -Fqx "Inherits=Papirus-Dark,hicolor" "$OVERLAY_LIGHTBASE/index.theme" \
            || { printf 'Dark mode did not derive the overlay from Papirus-Dark\n' >&2; exit 1; }
        run_folder --sync-folder-color false --folder-base-theme Papirus >/dev/null
        [[ ! -d $OVERLAY_LIGHTBASE ]] \
            || { printf 'Light-base overlay survived the toggle being turned off\n' >&2; exit 1; }
    fi

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

# --- Cursor accent: nearest installed Bibata-Material-* variant by hue --------
#
# The helper only reports a choice; DMS applies it. So the whole contract here
# is the log line: which variant, and the exact skip reasons.
#
# $HOME is sandboxed but /usr/share/icons is not, and on a machine with the
# Bibata-Material-* packs installed system-wide every assertion below would
# see them. Restrict the icon search to the sandboxed directories.
export DMS_THEME_SYNC_ICON_DIRS="$XDG_DATA_HOME/icons $HOME/.icons"
mkdir -p "$XDG_CONFIG_HOME/gtk-4.0"
printf '@define-color accent_bg_color #e01b24;\n' > "$XDG_CONFIG_HOME/gtk-4.0/dank-colors.css"

run_cursor() {
    "$ROOT/scripts/apply-theme.sh" \
        --font "Archivo" --mono-font "Cascadia Mono" --document-font "Literata" \
        --font-size 11 --mono-size 12 --document-size 13 \
        --icon-theme "Papirus-Dark" --cursor-theme "Breeze" --cursor-size 32 \
        --mode dark --gtk-theme-light auto --gtk-theme-dark auto \
        --qt-platform-theme qtct --qt-style Fusion \
        --apply-matugen-colors true --sync-kde false --sync-xsettingsd false \
        --backup-enabled false --backup-retention 10 --no-runtime "$@"
}

# no variants installed: report it, choose nothing
cursor_out=$(run_cursor --sync-cursor-color true)
grep -Fq 'cursor-color: no recognized Bibata-Material-* cursor variants installed' <<<"$cursor_out" \
    || { printf 'Missing cursor variants were not diagnosed:\n%s\n' "$cursor_out" >&2; exit 1; }

# a variant outside the palette table must never be chosen
mkdir -p "$XDG_DATA_HOME/icons/Bibata-Material-Unknown/cursors"
cursor_out=$(run_cursor --sync-cursor-color true)
grep -Fq 'cursor-color: no recognized Bibata-Material-* cursor variants installed' <<<"$cursor_out" \
    || { printf 'Unrecognized cursor variant was accepted:\n%s\n' "$cursor_out" >&2; exit 1; }

# a red accent lands on Salmon, not on teal Mint and not on neutral Grey;
# an icon theme without a cursors/ directory is not a cursor theme
mkdir -p "$XDG_DATA_HOME/icons/Bibata-Material-Salmon/cursors" \
         "$XDG_DATA_HOME/icons/Bibata-Material-Mint/cursors" \
         "$XDG_DATA_HOME/icons/Bibata-Material-Grey/cursors" \
         "$XDG_DATA_HOME/icons/Bibata-Material-Teal"
cursor_out=$(run_cursor --sync-cursor-color true)
grep -Fq 'cursor-color: accent #e01b24 -> Bibata-Material-Salmon' <<<"$cursor_out" \
    || { printf 'Red accent did not choose Salmon:\n%s\n' "$cursor_out" >&2; exit 1; }

# a neutral accent picks a neutral variant instead of the nearest hue
printf '@define-color accent_bg_color #7a7a7a;\n' > "$XDG_CONFIG_HOME/gtk-4.0/dank-colors.css"
cursor_out=$(run_cursor --sync-cursor-color true)
grep -Fq 'cursor-color: accent #7a7a7a -> Bibata-Material-Grey' <<<"$cursor_out" \
    || { printf 'Neutral accent did not choose Grey:\n%s\n' "$cursor_out" >&2; exit 1; }

# toggle off: the helper stays silent so the QML side restores the saved base
cursor_out=$(run_cursor --sync-cursor-color false)
! grep -Fq 'cursor-color:' <<<"$cursor_out" \
    || { printf 'Cursor choice reported with the toggle off:\n%s\n' "$cursor_out" >&2; exit 1; }
rm -rf "$XDG_DATA_HOME/icons/Bibata-Material-"{Salmon,Mint,Grey,Teal,Unknown}
unset DMS_THEME_SYNC_ICON_DIRS

# --- Reconcile: dangling GTK symlinks are preserved, live foreign writers named
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
[[ -L $XDG_CONFIG_HOME/gtk-4.0/gtk-dark.css ]] \
    || { printf 'Dangling gtk-dark.css symlink was removed\n' >&2; exit 1; }
grep -q 'dangling symlink.*preserved for its owner to repair' <<<"$reconcile_out" \
    || { printf 'Preserved dangling symlink was not reported\n' >&2; exit 1; }
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
    grep -q -- '--unset-env=GTK_THEME' <<<"$(flatpak_dry --sync-flatpak true)" \
        || { printf 'Legacy GTK_THEME is not cleared from the flatpak override\n' >&2; exit 1; }
    grep -q -- '--env=GTK_THEME=' <<<"$(flatpak_dry --sync-flatpak true)" \
        && { printf 'GTK_THEME is still forced inside flatpak sandboxes\n' >&2; exit 1; }
    grep -q -- '--nofilesystem=xdg-config/gtk-4.0' <<<"$(flatpak_dry --sync-flatpak true)" \
        || { printf 'The broad GTK4 configuration grant is not removed\n' >&2; exit 1; }
    grep -q -- '--filesystem=xdg-config/gtk-4.0/gtk.css:ro' <<<"$(flatpak_dry --sync-flatpak true)" \
        || { printf 'GTK4 CSS is not exposed to the flatpak sandbox\n' >&2; exit 1; }
    grep -q -- '--filesystem=xdg-config/gtk-4.0:ro' <<<"$(flatpak_dry --sync-flatpak true)" \
        && { printf 'GTK4 settings.ini is still broadly exposed to flatpak sandboxes\n' >&2; exit 1; }

    # With the toggle off, migrate only an override that matches the old
    # plugin signature. A fake flatpak keeps this test isolated from the real
    # user installation while exercising the detection branch.
    fake_bin="$TMP/fake-flatpak-bin"
    mkdir -p "$fake_bin"
    # shellcheck disable=SC2016
    printf '%s\n' \
        '#!/bin/sh' \
        'if [ "$1" = override ] && [ "$2" = --user ] && [ "$3" = --show ]; then' \
        '  printf "[Context]\\nfilesystems=xdg-config/gtk-3.0:ro;xdg-config/gtk-4.0:ro;\\n\\n[Environment]\\nGTK_THEME=adw-gtk3-dark\\nICON_THEME=Papirus-Dark\\n"' \
        'fi' > "$fake_bin/flatpak"
    chmod +x "$fake_bin/flatpak"
    legacy_out=$(PATH="$fake_bin:$PATH" flatpak_dry --sync-flatpak false)
    grep -q -- '--unset-env=GTK_THEME' <<<"$legacy_out" \
        || { printf 'Legacy plugin-owned GTK_THEME was not migrated with the toggle off\n' >&2; exit 1; }
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

# --- Uniform list backgrounds: derived scheme, render, pair shadow, kdeglobals -
#
# The stripes in Dolphin's details view come from QPalette::AlternateBase, whose
# source depends on the route. The toggle must equalise every surface the plugin
# owns and clean all of it up when turned off.
SCHEMES="$XDG_DATA_HOME/color-schemes"
printf '[General]\nColorScheme=DankMatugen\nName=Dank Shell (matugen)\n\n[Colors:View]\nBackgroundAlternate=10,20,30\nBackgroundNormal=1,2,3\nForegroundNormal=200,200,200\n\n[Colors:Window]\nBackgroundNormal=5,6,7\n' \
    > "$SCHEMES/DankMatugen.colors"

run_uniform() {
    "$ROOT/scripts/apply-theme.sh" --compositor generic \
        --font Archivo --mono-font "Cascadia Mono" \
        --icon-theme Papirus-Dark --cursor-theme Breeze \
        --mode dark --qt-platform-theme qtct --apply-matugen-colors true \
        --sync-xsettingsd false --backup-enabled false --no-runtime "$@" 2>&1
}

# off (default): no derived scheme, qt6ct points at DMS's own file
run_uniform --sync-kde true --qt-style Fusion >/dev/null
[[ ! -e $SCHEMES/DankUniform.colors ]] \
    || { printf 'Derived scheme written while the toggle was off\n' >&2; exit 1; }
assert_line "$XDG_CONFIG_HOME/qt6ct/qt6ct.conf" "color_scheme_path=$SCHEMES/DankMatugen.colors"
# ...but kdeglobals still gets the fresh [Colors:*] copy (the staleness fix)
assert_line "$XDG_CONFIG_HOME/kdeglobals" "BackgroundAlternate=10,20,30"
assert_line "$XDG_CONFIG_HOME/kdeglobals" 'ColorScheme=DankMatugen'

# on: derived scheme with the View alternate equalised, everything points at it
run_uniform --sync-kde true --qt-style Fusion --uniform-list-bg true >/dev/null
[[ -f $SCHEMES/DankUniform.colors ]] \
    || { printf 'Derived uniform scheme not written\n' >&2; exit 1; }
grep -A2 '\[Colors:View\]' "$SCHEMES/DankUniform.colors" | grep -Fqx 'BackgroundAlternate=1,2,3' \
    || { printf 'Derived scheme did not equalise the View alternate\n' >&2; exit 1; }
grep -Fqx 'ColorScheme=DankUniform' "$SCHEMES/DankUniform.colors" \
    || { printf 'Derived scheme kept the original ColorScheme name\n' >&2; exit 1; }
assert_line "$XDG_CONFIG_HOME/qt6ct/qt6ct.conf" "color_scheme_path=$SCHEMES/DankUniform.colors"
assert_line "$XDG_CONFIG_HOME/kdeglobals" 'ColorScheme=DankUniform'
assert_line "$XDG_CONFIG_HOME/kdeglobals" "BackgroundAlternate=1,2,3"
# untouched sections still arrive verbatim
assert_line "$XDG_CONFIG_HOME/kdeglobals" "BackgroundNormal=5,6,7"

# DMS's own scheme files are equalised too: KColorSchemeManager pins a scheme
# per app (dolphinrc ColorScheme=DankMatugen) and pinned apps read these files
# directly — every new view (tab, split pane) captures the alternate from them.
grep -A2 '\[Colors:View\]' "$SCHEMES/DankMatugen.colors" | grep -Fqx 'BackgroundAlternate=1,2,3' \
    || { printf 'DMS scheme file kept its striped View alternate\n' >&2; exit 1; }
# a regeneration behind our back (any DankMatugen* variant) is re-patched
printf '[General]\nColorScheme=DankMatugenDark\nName=Dank Dark\n\n[Colors:View]\nBackgroundAlternate=40,50,60\nBackgroundNormal=4,5,6\n' \
    > "$SCHEMES/DankMatugenDark.colors"
run_uniform --sync-kde true --qt-style Fusion --uniform-list-bg true >/dev/null
grep -A2 '\[Colors:View\]' "$SCHEMES/DankMatugenDark.colors" | grep -Fqx 'BackgroundAlternate=4,5,6' \
    || { printf 'Regenerated DMS scheme variant was not re-equalised\n' >&2; exit 1; }
rm -f "$SCHEMES/DankMatugenDark.colors"

# kdeglobals refresh is a section replace, not an append: run twice, one copy
count=$(grep -c '^\[Colors:View\]' "$XDG_CONFIG_HOME/kdeglobals")
[[ $count -eq 1 ]] || { printf 'kdeglobals holds %s copies of [Colors:View]\n' "$count" >&2; exit 1; }

# the DankMatugen render gets a transparent alternate in the output, not in the
# template: the template ships transparent_dolphin_view=true, under which an
# alternate equal to base still stripes against the window colour.
if find /usr/lib /usr/lib64 -name 'libkvantum*.so' -print -quit 2>/dev/null | grep -q .; then
    run_uniform --sync-kde false --qt-style kvantum --sync-kvantum true \
        --kvantum-colors "$KV_COLORS" --uniform-list-bg true >/dev/null
    kv_alt=$(sed -n 's/^alt\.base\.color=//p' "$XDG_CONFIG_HOME/Kvantum/DankMatugen/DankMatugen.kvconfig" | head -1)
    [[ $kv_alt == '#00000000' ]] \
        || { printf 'Rendered kvconfig alternate not transparent (alt=%s)\n' "$kv_alt" >&2; exit 1; }
    grep -q 'alt.base.color={{' "$ROOT/assets/kvantum/DankMatugen.kvconfig.in" \
        || { printf 'Template was modified instead of the render\n' >&2; exit 1; }
    rm -rf "$XDG_CONFIG_HOME/Kvantum"
fi

# pair theme: a marked shadow copy is built from the system theme and swept off.
# The fake system root cannot be under /usr in a test, so exercise the
# user-copy rule instead: an unmarked user copy is never touched and reconcile
# names it when it stripes.
mkdir -p "$XDG_DATA_HOME/themes/WhiteSur-Dark" "$XDG_CONFIG_HOME/Kvantum/WhiteSurDark"
printf '[GeneralColors]\nbase.color=#101010\nalt.base.color=#202020\n' \
    > "$XDG_CONFIG_HOME/Kvantum/WhiteSurDark/WhiteSurDark.kvconfig"
pair_out=$(DMS_THEME_SYNC_LIB_DIRS="$KVLIB" run_uniform --sync-kde false \
    --gtk-theme-dark WhiteSur-Dark --qt-sync-mode pair --uniform-list-bg true)
grep -q "your own copy of Kvantum theme 'WhiteSurDark'" <<<"$pair_out" \
    || { printf 'Unmarked user pair copy not reported:\n%s\n' "$pair_out" >&2; exit 1; }
grep -Fqx 'alt.base.color=#202020' "$XDG_CONFIG_HOME/Kvantum/WhiteSurDark/WhiteSurDark.kvconfig" \
    || { printf 'User-owned pair copy was modified\n' >&2; exit 1; }
# a marked dir is ours: swept when the toggle goes off
mkdir -p "$XDG_CONFIG_HOME/Kvantum/FakeShadow"
printf 'source=/usr/share/Kvantum/FakeShadow\n' > "$XDG_CONFIG_HOME/Kvantum/FakeShadow/.dms-theme-sync-uniform"
run_uniform --sync-kde false --qt-style Fusion >/dev/null
[[ ! -d $XDG_CONFIG_HOME/Kvantum/FakeShadow ]] \
    || { printf 'Marked shadow survived the toggle being off\n' >&2; exit 1; }
[[ -d $XDG_CONFIG_HOME/Kvantum/WhiteSurDark ]] \
    || { printf 'User-owned Kvantum copy was swept\n' >&2; exit 1; }
rm -rf "$XDG_CONFIG_HOME/Kvantum"

# off again: the derived scheme is removed and the pointers return to DMS's file
run_uniform --sync-kde true --qt-style Fusion >/dev/null
[[ ! -e $SCHEMES/DankUniform.colors ]] \
    || { printf 'Derived scheme survived the toggle being turned off\n' >&2; exit 1; }
assert_line "$XDG_CONFIG_HOME/qt6ct/qt6ct.conf" "color_scheme_path=$SCHEMES/DankMatugen.colors"
assert_line "$XDG_CONFIG_HOME/kdeglobals" 'ColorScheme=DankMatugen'

# reconcile names a stale kdeglobals copy (another writer rewrote it behind us)
sed -i 's/^BackgroundNormal=1,2,3/BackgroundNormal=9,9,9/' "$XDG_CONFIG_HOME/kdeglobals"
stale_out=$(run_uniform --sync-kde false --qt-style Fusion)
grep -q 'stale palette' <<<"$stale_out" \
    && { printf 'Stale note fired with sync-kde off\n' >&2; exit 1; }
stale_out=$(run_uniform --sync-kde true --qt-style Fusion)
grep -q 'stale palette' <<<"$stale_out" \
    && { printf 'Stale note fired although the refresh just ran\n' >&2; exit 1; }
assert_line "$XDG_CONFIG_HOME/kdeglobals" "BackgroundNormal=1,2,3"

# restore the minimal scheme the earlier blocks expect
printf '[ColorEffects:Disabled]\nColor=0,0,0\n' > "$SCHEMES/DankMatugen.colors"

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

# --- GTK export drift: reconcile says when dank-colors.css is not the live theme
#
# GTK follows what DMS exported; Qt/Kvantum follow the live theme. DMS skips the
# export for custom/downloaded themes, so a registry theme can leave GTK painting
# the previous palette. The daemon re-exports, and reconcile is the safety net.
printf '@define-color accent_bg_color #c7b3f3;\n' > "$XDG_CONFIG_HOME/gtk-4.0/dank-colors.css"
drift_out=$(env -u NIRI_SOCKET "$ROOT/scripts/apply-theme.sh" --compositor generic \
    --qt-platform-theme qtct --qt-style preserve --sync-kvantum false \
    --kvantum-colors "primary=#ac3232;on_surface=#e6d4d8" \
    --sync-kde false --sync-xsettingsd false --backup-enabled false --no-runtime 2>&1)
grep -q "is not the live theme" <<<"$drift_out" \
    || { printf 'No drift note when the GTK export disagrees with the live theme\n' >&2; exit 1; }
printf '@define-color accent_bg_color #AC3232;\n' > "$XDG_CONFIG_HOME/gtk-4.0/dank-colors.css"
drift_out=$(env -u NIRI_SOCKET "$ROOT/scripts/apply-theme.sh" --compositor generic \
    --qt-platform-theme qtct --qt-style preserve --sync-kvantum false \
    --kvantum-colors "primary=#ac3232;on_surface=#e6d4d8" \
    --sync-kde false --sync-xsettingsd false --backup-enabled false --no-runtime 2>&1)
grep -q "is not the live theme" <<<"$drift_out" \
    && { printf 'Drift note fired although the accents match (case)\n' >&2; exit 1; }
printf '/* Generated with Matugen */\n@define-color accent_color #123456;\n' \
    > "$XDG_CONFIG_HOME/gtk-4.0/dank-colors.css"

# --- Live session env: the same resolved values as the persistent writers ------
#
# The systemctl block used to re-derive the platform theme from a closed
# gtk3|qtct case, so any other name reached the niri include and environment.d
# but not the live session. Runtime commands are stubbed (pkill included — a
# real one would kill the user's xsettingsd) and systemctl captures its args.
STUBS="$TMP/stubs"
mkdir -p "$STUBS"
for cmd in gsettings fc-cache fc-match xsettingsd niri pkill pgrep dconf; do
    printf '#!/bin/sh\nexit 0\n' > "$STUBS/$cmd"; chmod +x "$STUBS/$cmd"
done
printf '#!/bin/sh\necho "$@" >> "%s/systemctl.log"\nexit 0\n' "$TMP" > "$STUBS/systemctl"
chmod +x "$STUBS/systemctl"

live_env() { # $1=platform theme -> captured systemctl args
    rm -f "$TMP/systemctl.log"
    env -u QT_QPA_PLATFORMTHEME -u QT_QPA_PLATFORMTHEME_QT6 PATH="$STUBS:$PATH" \
        "$ROOT/scripts/apply-theme.sh" --compositor generic \
        --qt-platform-theme "$1" --qt-style preserve \
        --sync-kde false --sync-xsettingsd false --backup-enabled false >/dev/null 2>&1
    cat "$TMP/systemctl.log" 2>/dev/null
}

grep -q 'QT_QPA_PLATFORMTHEME=xdgdesktopportal' <<<"$(live_env xdgdesktopportal)" \
    || { printf 'Live session env did not receive a platform theme outside gtk3/qtct\n' >&2; exit 1; }
grep -q 'QT_QPA_PLATFORMTHEME=qt5ct' <<<"$(live_env qtct)" \
    || { printf 'Live session env did not receive qt5ct under qtct\n' >&2; exit 1; }
# preserve means hands off: no QT variable set (and none unset — a value the
# user exported themselves must survive).
grep -q 'QT_QPA_PLATFORMTHEME' <<<"$(live_env preserve)" \
    && { printf 'Live session env was touched under preserve\n' >&2; exit 1; }

printf 'helper tests: ok\n'
