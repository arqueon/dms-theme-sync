#!/usr/bin/env bash
set -u

ACTION=${1:-}
[[ -n $ACTION ]] || { printf 'Usage: %s backup|restore|list [options]\n' "$0" >&2; exit 2; }
shift

XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-$HOME/.config}
XDG_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}
XDG_STATE_HOME=${XDG_STATE_HOME:-$HOME/.local/state}
BACKUP_ROOT=${DMS_THEME_SYNC_BACKUP_ROOT:-$XDG_STATE_HOME/DankMaterialShell/plugins/dmsThemeSync/backups}
NO_RUNTIME=${DMS_THEME_SYNC_NO_RUNTIME:-false}
RETENTION=10
SNAPSHOT=latest
LABEL=manual

while (( $# )); do
    case "$1" in
        --retention) RETENTION=${2:?}; shift 2 ;;
        --snapshot) SNAPSHOT=${2:?}; shift 2 ;;
        --label) LABEL=${2:?}; shift 2 ;;
        --no-runtime) NO_RUNTIME=true; shift ;;
        *) printf 'Unknown option: %s\n' "$1" >&2; exit 2 ;;
    esac
done

[[ $RETENTION =~ ^[0-9]+$ ]] || { printf 'Retention must be an integer\n' >&2; exit 2; }

TARGETS=(
    "$HOME/.gtkrc-2.0"
    "$XDG_CONFIG_HOME/gtk-3.0/settings.ini"
    "$XDG_CONFIG_HOME/gtk-3.0/gtk.css"
    "$XDG_CONFIG_HOME/gtk-4.0/settings.ini"
    "$XDG_CONFIG_HOME/gtk-4.0/gtk.css"
    "$XDG_CONFIG_HOME/qt5ct/qt5ct.conf"
    "$XDG_CONFIG_HOME/qt6ct/qt6ct.conf"
    "$XDG_CONFIG_HOME/kdeglobals"
    "$XDG_CONFIG_HOME/kcminputrc"
    "$XDG_CONFIG_HOME/xsettingsd/xsettingsd.conf"
    "$XDG_CONFIG_HOME/fontconfig/conf.d/99-dms-theme-sync.conf"
    "$HOME/.icons/default/index.theme"
    "$XDG_DATA_HOME/icons/default/index.theme"
    "$XDG_CONFIG_HOME/environment.d/90-dms-theme-sync.conf"
)

GSETTINGS=(
    "org.gnome.desktop.interface gtk-theme"
    "org.gnome.desktop.interface color-scheme"
    "org.gnome.desktop.interface icon-theme"
    "org.gnome.desktop.interface cursor-theme"
    "org.gnome.desktop.interface cursor-size"
    "org.gnome.desktop.interface font-name"
    "org.gnome.desktop.interface document-font-name"
    "org.gnome.desktop.interface monospace-font-name"
    "org.gnome.desktop.interface gtk-enable-animations"
    "org.gnome.desktop.wm.preferences titlebar-font"
)

ENV_KEYS=(XCURSOR_THEME HYPRCURSOR_THEME XCURSOR_SIZE HYPRCURSOR_SIZE QT_QPA_PLATFORMTHEME QT_QPA_PLATFORMTHEME_QT6)

snapshot_id() {
    date '+%Y%m%d-%H%M%S'
}

resolve_snapshot() {
    local requested=$1
    if [[ $requested == latest ]]; then
        find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d ! -name '*.tmp.*' -printf '%f\n' 2>/dev/null | LC_ALL=C sort -r | head -n 1
    else
        [[ $requested =~ ^[0-9]{8}-[0-9]{6}(-[0-9]+)?$ ]] || return 1
        printf '%s' "$requested"
    fi
}

backup_snapshot() {
    local id final tmp i path state schema key value env_dump env_key env_value
    id=$(snapshot_id)
    final="$BACKUP_ROOT/$id"
    [[ ! -e $final ]] || { id="$id-$$"; final="$BACKUP_ROOT/$id"; }
    tmp="$BACKUP_ROOT/.$id.tmp.$$"
    mkdir -p "$tmp/files" || return 1

    printf 'created=%s\nlabel=%s\n' "$(date --iso-8601=seconds)" "$LABEL" > "$tmp/metadata"
    : > "$tmp/manifest.tsv"
    for i in "${!TARGETS[@]}"; do
        path=${TARGETS[$i]}
        if [[ -e $path || -L $path ]]; then
            cp -a -- "$path" "$tmp/files/$i" || { rm -rf "$tmp"; return 1; }
            state=present
        else
            state=absent
        fi
        printf '%s\t%s\t%s\n' "$i" "$state" "$path" >> "$tmp/manifest.tsv"
    done

    : > "$tmp/gsettings.tsv"
    if [[ $NO_RUNTIME != true ]] && command -v gsettings >/dev/null 2>&1; then
        for entry in "${GSETTINGS[@]}"; do
            schema=${entry% *}
            key=${entry##* }
            value=$(gsettings get "$schema" "$key" 2>/dev/null) || continue
            printf '%s\t%s\t%s\n' "$schema" "$key" "$value" >> "$tmp/gsettings.tsv"
        done
    fi

    : > "$tmp/environment.tsv"
    if [[ $NO_RUNTIME != true ]] && command -v systemctl >/dev/null 2>&1; then
        env_dump=$(systemctl --user show-environment 2>/dev/null || true)
        for env_key in "${ENV_KEYS[@]}"; do
            env_value=$(printf '%s\n' "$env_dump" | sed -n "s/^$env_key=//p" | head -n 1)
            if printf '%s\n' "$env_dump" | grep -q "^$env_key="; then
                printf '%s\tset\t%s\n' "$env_key" "$env_value" >> "$tmp/environment.tsv"
            else
                printf '%s\tunset\t\n' "$env_key" >> "$tmp/environment.tsv"
            fi
        done
    fi

    mv "$tmp" "$final" || return 1

    if (( RETENTION > 0 )); then
        mapfile -t old_snapshots < <(find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d ! -name '*.tmp.*' -printf '%f\n' | LC_ALL=C sort -r | tail -n +$((RETENTION + 1)))
        for id in "${old_snapshots[@]}"; do
            [[ $id =~ ^[0-9]{8}-[0-9]{6}(-[0-9]+)?$ ]] && rm -rf -- "${BACKUP_ROOT:?}/$id"
        done
    fi

    printf 'BACKUP_CREATED:%s\n' "$(basename "$final")"
}

restore_snapshot() {
    local id dir index state recorded_path expected_path source schema key value env_key env_state env_value
    id=$(resolve_snapshot "$SNAPSHOT") || { printf 'Invalid snapshot id\n' >&2; return 2; }
    [[ -n $id ]] || { printf 'No backups available\n' >&2; return 1; }
    dir="$BACKUP_ROOT/$id"
    [[ -d $dir && -f $dir/manifest.tsv ]] || { printf 'Snapshot not found: %s\n' "$id" >&2; return 1; }

    while IFS=$'\t' read -r index state recorded_path; do
        [[ $index =~ ^[0-9]+$ && $index -lt ${#TARGETS[@]} ]] || { printf 'Invalid backup manifest index\n' >&2; return 1; }
        expected_path=${TARGETS[$index]}
        [[ $recorded_path == "$expected_path" ]] || { printf 'Backup path mismatch for index %s\n' "$index" >&2; return 1; }
        source="$dir/files/$index"
        if [[ $state == present ]]; then
            [[ -e $source || -L $source ]] || { printf 'Missing backup payload: %s\n' "$index" >&2; return 1; }
            mkdir -p "$(dirname "$expected_path")"
            rm -rf -- "$expected_path"
            cp -a -- "$source" "$expected_path" || return 1
        elif [[ $state == absent ]]; then
            rm -rf -- "$expected_path"
        else
            printf 'Invalid backup state: %s\n' "$state" >&2
            return 1
        fi
    done < "$dir/manifest.tsv"

    if [[ $NO_RUNTIME != true ]] && command -v gsettings >/dev/null 2>&1 && [[ -f $dir/gsettings.tsv ]]; then
        while IFS=$'\t' read -r schema key value; do
            [[ -n $schema && -n $key && -n $value ]] || continue
            gsettings writable "$schema" "$key" 2>/dev/null | grep -qx true || continue
            gsettings set "$schema" "$key" "$value" 2>/dev/null || true
        done < "$dir/gsettings.tsv"
    fi

    if [[ $NO_RUNTIME != true ]] && command -v systemctl >/dev/null 2>&1 && [[ -f $dir/environment.tsv ]]; then
        while IFS=$'\t' read -r env_key env_state env_value; do
            [[ $env_key =~ ^[A-Z0-9_]+$ ]] || continue
            if [[ $env_state == set ]]; then
                systemctl --user set-environment "$env_key=$env_value" >/dev/null 2>&1 || true
            elif [[ $env_state == unset ]]; then
                systemctl --user unset-environment "$env_key" >/dev/null 2>&1 || true
            fi
        done < "$dir/environment.tsv"
    fi

    if [[ $NO_RUNTIME != true ]]; then
        command -v fc-cache >/dev/null 2>&1 && fc-cache -f >/dev/null 2>&1 || true
        command -v xsettingsd >/dev/null 2>&1 && pkill -HUP -x xsettingsd 2>/dev/null || true
    fi

    printf 'BACKUP_RESTORED:%s\n' "$id"
}

case "$ACTION" in
    backup) backup_snapshot ;;
    restore) restore_snapshot ;;
    list)
        find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d ! -name '*.tmp.*' -printf '%f\n' 2>/dev/null | LC_ALL=C sort -r
        ;;
    *) printf 'Unknown action: %s\n' "$ACTION" >&2; exit 2 ;;
esac
