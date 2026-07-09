#!/usr/bin/env bash
set -u

FONT="sans-serif"
MONO_FONT="monospace"
DOCUMENT_FONT=""
FONT_SIZE=11
MONO_SIZE=12
DOCUMENT_SIZE=11
ICON_THEME="System Default"
CURSOR_THEME="System Default"
CURSOR_SIZE=24
MODE="dark"
GTK_THEME_LIGHT="auto"
GTK_THEME_DARK="auto"
QT_PLATFORM_THEME="preserve"
QT_STYLE="Fusion"
COMPOSITOR=""
APPLY_MATUGEN_COLORS=true
SYNC_KDE=true
SYNC_XSETTINGSD=true
SYNC_TERMINAL_FONTS=false
SYNC_FOLDER_COLOR=false
FOLDER_BASE_THEME=""
SYNC_FLATPAK=false
SYNC_KVANTUM=false
KV_COLORS=""
DRY_RUN=false
NO_RUNTIME=${DMS_THEME_SYNC_NO_RUNTIME:-false}
BACKUP_ENABLED=true
BACKUP_RETENTION=10

while (( $# )); do
    case "$1" in
        --font) FONT=${2:?}; shift 2 ;;
        --mono-font) MONO_FONT=${2:?}; shift 2 ;;
        --document-font) DOCUMENT_FONT=${2-}; shift 2 ;;
        --font-size) FONT_SIZE=${2:?}; shift 2 ;;
        --mono-size) MONO_SIZE=${2:?}; shift 2 ;;
        --document-size) DOCUMENT_SIZE=${2:?}; shift 2 ;;
        --icon-theme) ICON_THEME=${2:?}; shift 2 ;;
        --cursor-theme) CURSOR_THEME=${2:?}; shift 2 ;;
        --cursor-size) CURSOR_SIZE=${2:?}; shift 2 ;;
        --mode) MODE=${2:?}; shift 2 ;;
        --gtk-theme-light) GTK_THEME_LIGHT=${2:?}; shift 2 ;;
        --gtk-theme-dark) GTK_THEME_DARK=${2:?}; shift 2 ;;
        --qt-platform-theme) QT_PLATFORM_THEME=${2:?}; shift 2 ;;
        --qt-style) QT_STYLE=${2:?}; shift 2 ;;
        --compositor) COMPOSITOR=${2-}; shift 2 ;;
        --apply-matugen-colors) APPLY_MATUGEN_COLORS=${2:?}; shift 2 ;;
        --sync-kde) SYNC_KDE=${2:?}; shift 2 ;;
        --sync-xsettingsd) SYNC_XSETTINGSD=${2:?}; shift 2 ;;
        --sync-terminal-fonts) SYNC_TERMINAL_FONTS=${2:?}; shift 2 ;;
        --sync-folder-color) SYNC_FOLDER_COLOR=${2:?}; shift 2 ;;
        --folder-base-theme) FOLDER_BASE_THEME=${2-}; shift 2 ;;
        --sync-flatpak) SYNC_FLATPAK=${2:?}; shift 2 ;;
        --sync-kvantum) SYNC_KVANTUM=${2:?}; shift 2 ;;
        --kvantum-colors) KV_COLORS=${2-}; shift 2 ;;
        --dry-run) DRY_RUN=true; shift ;;
        --no-runtime) NO_RUNTIME=true; shift ;;
        --backup-enabled) BACKUP_ENABLED=${2:?}; shift 2 ;;
        --backup-retention) BACKUP_RETENTION=${2:?}; shift 2 ;;
        *) printf 'Unknown option: %s\n' "$1" >&2; exit 2 ;;
    esac
done

DOCUMENT_FONT=${DOCUMENT_FONT:-$FONT}
XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-$HOME/.config}
XDG_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}

case "$MODE" in light|dark) ;; *) printf 'Invalid mode: %s\n' "$MODE" >&2; exit 2 ;; esac
case "$QT_PLATFORM_THEME" in gtk3|qtct|preserve) ;; *) printf 'Invalid Qt platform theme policy: %s\n' "$QT_PLATFORM_THEME" >&2; exit 2 ;; esac
[[ $FONT_SIZE =~ ^[0-9]+$ && $MONO_SIZE =~ ^[0-9]+$ && $DOCUMENT_SIZE =~ ^[0-9]+$ && $CURSOR_SIZE =~ ^[0-9]+$ ]] || {
    printf 'Font and cursor sizes must be integers\n' >&2
    exit 2
}
[[ $BACKUP_RETENTION =~ ^[0-9]+$ ]] || { printf 'Backup retention must be an integer\n' >&2; exit 2; }

log() { printf '%s\n' "$*"; }
run() {
    if $DRY_RUN; then
        printf 'DRY-RUN:'
        printf ' %q' "$@"
        printf '\n'
    else
        "$@"
    fi
}

theme_exists() {
    local name=$1 dir
    [[ -n $name ]] || return 1
    for dir in "$HOME/.themes" "$XDG_DATA_HOME/themes" /usr/local/share/themes /usr/share/themes; do
        [[ -d "$dir/$name" ]] && return 0
    done
    return 1
}

current_gtk_theme() {
    local file value
    for file in "$XDG_CONFIG_HOME/gtk-3.0/settings.ini" "$XDG_CONFIG_HOME/gtk-4.0/settings.ini"; do
        if [[ -f $file ]]; then
            value=$(sed -n 's/^[[:space:]]*gtk-theme-name[[:space:]]*=[[:space:]]*//p' "$file" | tail -n 1)
            [[ -n $value ]] && { printf '%s' "$value"; return; }
        fi
    done
    if command -v gsettings >/dev/null 2>&1; then
        gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null | sed "s/^'//;s/'$//"
    fi
}

resolve_gtk_theme() {
    local requested=$1 mode=$2 current candidate
    if [[ $requested == preserve ]]; then
        printf ''
        return
    fi
    if [[ $requested != auto ]]; then
        if theme_exists "$requested"; then
            printf '%s' "$requested"
        else
            log "GTK theme '$requested' is not installed; preserving the current theme" >&2
        fi
        return
    fi

    current=$(current_gtk_theme)
    [[ -n $current ]] || current=adw-gtk3
    if [[ $mode == dark ]]; then
        for candidate in \
            "${current/-light-/-dark-}" "${current%-light}-dark" "${current%-Light}-Dark" \
            "$current-dark" "$current-Dark" "$current" adw-gtk3-dark Breeze-Dark; do
            theme_exists "$candidate" && { printf '%s' "$candidate"; return; }
        done
    else
        for candidate in \
            "${current/-dark-/-light-}" "${current%-dark}" "${current%-Dark}" \
            "${current%-dark}-light" "$current" adw-gtk3 Breeze; do
            theme_exists "$candidate" && { printf '%s' "$candidate"; return; }
        done
    fi
    printf '%s' "$current"
}

GTK_REQUEST=$GTK_THEME_DARK
[[ $MODE == light ]] && GTK_REQUEST=$GTK_THEME_LIGHT
GTK_THEME=$(resolve_gtk_theme "$GTK_REQUEST" "$MODE")

if [[ $ICON_THEME == "System Default" ]]; then
    ICON_THEME=""
fi
if [[ $CURSOR_THEME == "System Default" ]]; then
    CURSOR_THEME=""
fi

# --- Folder accent overlay ---------------------------------------------------
#
# Papirus ships ~80 folder colours, and papirus-folders(1) switches between them
# by re-pointing folder*.svg symlinks. It cannot help us here: the Arch package
# installs the theme under /usr/share/icons, so the tool re-execs itself through
# sudo, and a shell plugin has no way to prompt for a password.
#
# Instead we generate a small overlay theme under $XDG_DATA_HOME that inherits
# the base theme and carries *only* the Places folder icons, each a symlink to
# the base theme's coloured variant. ~4 MB instead of a ~320 MB copy, no root,
# and pacman updates to the base theme are inherited for free because the
# symlinks point into it. Everything else (app icons, mimetypes) resolves
# through Inherits=.
#
# The colour itself is derived from the Matugen accent by HUE, not by nearest
# RGB: in dark mode Material You hands out a pastel tint (e.g. #a1c9ff), and a
# plain euclidean match against Papirus's saturated folders always lands on the
# washed-out entries.

OVERLAY_SUFFIX="-DankFolders"

icon_theme_dir() {
    local name=$1 d
    for d in "${XDG_DATA_HOME:-$HOME/.local/share}/icons" "$HOME/.icons" \
             /usr/local/share/icons /usr/share/icons; do
        [[ -d $d/$name ]] && { printf '%s' "$d/$name"; return 0; }
    done
    return 1
}

# hex -> "hue chroma" in CIE LCh. Pure awk so we keep the zero-dependency rule.
hue_chroma() {
    printf '%s' "${1#\#}" | awk '{
        r = strtonum("0x" substr($0,1,2)) / 255
        g = strtonum("0x" substr($0,3,2)) / 255
        b = strtonum("0x" substr($0,5,2)) / 255
        r = (r <= 0.04045) ? r/12.92 : ((r+0.055)/1.055)^2.4
        g = (g <= 0.04045) ? g/12.92 : ((g+0.055)/1.055)^2.4
        b = (b <= 0.04045) ? b/12.92 : ((b+0.055)/1.055)^2.4
        x = (0.4124*r + 0.3576*g + 0.1805*b) / 0.95047
        y = (0.2126*r + 0.7152*g + 0.0722*b)
        z = (0.0193*r + 0.1192*g + 0.9505*b) / 1.08883
        x = (x > 0.008856) ? x^(1/3) : 7.787*x + 16/116
        y = (y > 0.008856) ? y^(1/3) : 7.787*y + 16/116
        z = (z > 0.008856) ? z^(1/3) : 7.787*z + 16/116
        A = 500*(x-y); B = 200*(y-z)
        h = atan2(B, A) * 57.2957795; if (h < 0) h += 360
        printf "%.3f %.3f", h, sqrt(A*A + B*B)
    }'
}

# The perceived folder colour is the most chromatic fill in the SVG. Its
# position is not stable: in folder-red.svg it is the 3rd fill, in folder-yaru
# .svg the 2nd, and picking by index silently grabs a grey.
dominant_fill() {
    local svg=$1 best="" best_c=-1 hex c
    while read -r hex; do
        c=$(hue_chroma "$hex" | cut -d' ' -f2)
        awk -v a="$c" -v b="$best_c" 'BEGIN{exit !(a>b)}' && { best=$hex; best_c=$c; }
    done < <(grep -oE 'fill:#[0-9a-fA-F]{6}' "$svg" | sed 's/fill://' | sort -u)
    printf '%s' "$best"
}

# A colour is any X for which both folder-X.svg and folder-X-<variant>.svg
# exist. Splitting folder-*.svg on dashes would shred `cat-mocha-blue`.
#
# Papirus carries themed palettes (cat-*, nordic, yaru, breeze, adwaita) whose
# hues collide with the plain ones, so a pure hue match resolves ties at random
# — #a1c9ff lands on `nordic` as readily as on `blue`. Search the plain palette
# first and only fall back to the themed entries when nothing plain is close.
_folder_palette_match() {
    local places=$1 ah=$2 plain_only=$3 name hex h c d best="" bestd=999 bestc=-1
    for f in "$places"/folder-*.svg; do
        name=$(basename "$f" .svg); name=${name#folder-}
        [[ -e $places/folder-$name-documents.svg ]] || continue
        if [[ $plain_only == true ]]; then
            [[ $name == *-* ]] && continue
            case $name in nordic|yaru|breeze|adwaita|black|white) continue ;; esac
        fi
        hex=$(dominant_fill "$f"); [[ -n $hex ]] || continue
        read -r h c <<<"$(hue_chroma "$hex")"
        awk -v c="$c" 'BEGIN{exit !(c < 12)}' && continue
        d=$(awk -v a="$ah" -v b="$h" 'BEGIN{d=(b-a+180)%360-180; if(d<0)d=-d; print d}')
        # Hue decides; within 5 degrees prefer the more saturated folder, else an
        # amber accent lands on `paleorange` rather than `yellow`.
        if awk -v d="$d" -v bd="$bestd" -v c="$c" -v bc="$bestc" \
            'BEGIN{exit !(d < bd-5 || (d <= bd+5 && c > bc))}'; then
            best=$name; bestd=$d; bestc=$c
        fi
    done
    [[ -n $best ]] && printf '%s %s' "$best" "$bestd"
}

nearest_folder_color() {
    local places=$1 accent=$2 ah ac best d
    read -r ah ac <<<"$(hue_chroma "$accent")"
    awk -v c="$ac" 'BEGIN{exit !(c < 12)}' && { printf 'grey'; return 0; }
    read -r best d <<<"$(_folder_palette_match "$places" "$ah" true)"
    if [[ -n $best ]] && awk -v d="$d" 'BEGIN{exit !(d <= 30)}'; then
        printf '%s' "$best"; return 0
    fi
    read -r best d <<<"$(_folder_palette_match "$places" "$ah" false)"
    [[ -n $best ]] && printf '%s' "$best"
}

build_folder_overlay() {
    local base=$1 color=$2 out=$3 places size target name src
    rm -rf "$out"; mkdir -p "$out"
    local -a dirs=()
    while IFS= read -r places; do
        size=$(basename "$(dirname "$places")")
        local made=false
        for prefix in folder user; do
            for src in "$places/$prefix-$color"{-*,}.svg; do
                [[ -e $src ]] || continue
                name=$(basename "$src" .svg)
                if [[ $name == "$prefix-$color" ]]; then target=$prefix
                else target=${name/$prefix-$color-/$prefix-}; fi
                mkdir -p "$out/$size/places"
                ln -sfn "$src" "$out/$size/places/$target.svg"
                made=true
            done
        done
        # Papirus reaches the folder icons through ~220 aliases per size:
        # inode-directory.svg -> folder.svg, gtk-directory.svg -> folder.svg,
        # desktop.svg -> user-desktop.svg, and so on. They are *relative*
        # symlinks, so an alias we do not carry over resolves inside the base
        # theme and paints the base colour. That is how GTK apps (which ask for
        # `folder`) and KDE apps (which ask for `inode-directory`) end up with
        # two different folder colours on the same desktop.
        if $made; then
            local alias_src alias_name alias_target
            # No -L here: it would dereference the very symlinks we are looking for.
            while IFS= read -r alias_src; do
                alias_name=$(basename "$alias_src")
                alias_target=$(readlink "$alias_src")
                [[ $alias_target == */* ]] && continue          # not a sibling alias
                [[ -e $out/$size/places/$alias_target ]] || continue
                ln -sfn "$alias_target" "$out/$size/places/$alias_name"
            done < <(find "$places/" -maxdepth 1 -type l \
                        \( -lname 'folder*' -o -lname 'user*' \) 2>/dev/null)
        fi
        $made && dirs+=("$size/places")
    done < <(find -L "$base" -mindepth 2 -maxdepth 2 -type d -name places | sort)
    (( ${#dirs[@]} )) || { rm -rf "$out"; return 1; }

    {
        printf '[Icon Theme]\nName=%s\n' "${out##*/}"
        printf 'Comment=Folder accent overlay generated by dms-theme-sync\n'
        printf 'Inherits=%s,hicolor\n' "$(basename "$base")"
        printf 'Directories=%s\n\n' "$(IFS=,; printf '%s' "${dirs[*]}")"
        local d sz scale
        for d in "${dirs[@]}"; do
            sz=${d%%/*}; scale=1
            case "$sz" in *@*x) scale=${sz##*@}; scale=${scale%x}; sz=${sz%@*};; esac
            printf '[%s]\nSize=%s\nScale=%s\nContext=Places\nType=Fixed\n\n' "$d" "${sz%%x*}" "$scale"
        done
    } > "$out/index.theme"
}

icons_home="${XDG_DATA_HOME:-$HOME/.local/share}/icons"
# DMS owns the icon theme. Once the overlay is applied, SettingsData.iconTheme
# *is* the overlay, so the base to derive from must be remembered by the plugin
# and passed in; deriving it by stripping the suffix would break the moment the
# user renames anything.
folder_base=${FOLDER_BASE_THEME:-$ICON_THEME}
[[ $folder_base == *"$OVERLAY_SUFFIX" ]] && folder_base=${folder_base%"$OVERLAY_SUFFIX"}
overlay_dir="$icons_home/${folder_base}${OVERLAY_SUFFIX}"

# Sweep overlays left behind by a previous base theme. Without this, switching
# Papirus-Dark -> Tela strands `Papirus-Dark-DankFolders` in the theme picker.
if ! $DRY_RUN; then
    for stale in "$icons_home"/*"$OVERLAY_SUFFIX"; do
        [[ -d $stale && $stale != "$overlay_dir" ]] && rm -rf "$stale"
    done
fi

if [[ $SYNC_FOLDER_COLOR == true && -n $folder_base ]]; then
    base_dir=$(icon_theme_dir "$folder_base" || true)
    places_dir="$base_dir/64x64/places"
    accent=$(grep -m1 -oE '@define-color accent_bg_color #[0-9a-fA-F]{6}' \
        "${XDG_CONFIG_HOME:-$HOME/.config}/gtk-4.0/dank-colors.css" 2>/dev/null \
        | grep -oE '#[0-9a-fA-F]{6}' || true)

    if [[ -z $base_dir || ! -d $places_dir ]]; then
        log "folder-color: '$folder_base' has no Places icons; skipping"
    elif [[ -z $accent ]]; then
        log "folder-color: no Matugen accent found; skipping"
    else
        color=$(nearest_folder_color "$places_dir" "$accent" || true)
        if [[ -z $color ]]; then
            log "folder-color: no folder colour matches accent $accent; skipping"
        elif $DRY_RUN; then
            log "DRY-RUN: build overlay $overlay_dir (accent $accent -> $color)"
        elif build_folder_overlay "$base_dir" "$color" "$overlay_dir"; then
            # The overlay is a derived asset, not a decision. We build it and
            # name it; DMS decides whether it becomes the icon theme, so its own
            # drift check (checkIconThemeDrift) never sees a stranger in
            # gsettings and never falls back to "System Default".
            log "folder-color: accent $accent -> $color (overlay ${overlay_dir##*/})"
        else
            log "folder-color: overlay build failed; keeping $folder_base"
        fi
    fi
elif [[ $SYNC_FOLDER_COLOR != true && -d $overlay_dir ]] && ! $DRY_RUN; then
    rm -rf "$overlay_dir"   # toggle turned off: leave no orphan theme behind
fi

if [[ $BACKUP_ENABLED == true ]]; then
    if $DRY_RUN; then
        log "DRY-RUN: create pre-apply snapshot"
    else
        snapshot_args=(backup --retention "$BACKUP_RETENTION" --label pre-apply)
        [[ $NO_RUNTIME == true ]] && snapshot_args+=(--no-runtime)
        if ! snapshot_output=$("$(dirname "$0")/theme-snapshot.sh" "${snapshot_args[@]}"); then
            printf 'Failed to create pre-apply backup; synchronization aborted\n' >&2
            exit 1
        fi
        log "$snapshot_output"
    fi
fi

update_ini() {
    local file=$1 section=$2 key=$3 value=$4 dir tmp
    dir=$(dirname "$file")
    if $DRY_RUN; then
        log "DRY-RUN: set [$section] $key=$value in $file"
        return
    fi
    mkdir -p "$dir"
    tmp="$file.tmp.$$"
    awk -v section="$section" -v key="$key" -v value="$value" '
        BEGIN { in_section=0; section_seen=0; key_written=0 }
        $0 == "[" section "]" {
            in_section=1; section_seen=1; print; next
        }
        /^\[[^]]+\]$/ {
            if (in_section && !key_written) { print key "=" value; key_written=1 }
            in_section=0; print; next
        }
        in_section && index($0, key "=") == 1 {
            if (!key_written) { print key "=" value; key_written=1 }
            next
        }
        { print }
        END {
            if (!section_seen) { print "[" section "]"; print key "=" value }
            else if (in_section && !key_written) print key "=" value
        }
    ' "$file" 2>/dev/null > "$tmp" || {
        printf '[%s]\n%s=%s\n' "$section" "$key" "$value" > "$tmp"
    }
    mv "$tmp" "$file"
}

update_equals_key() {
    local file=$1 key=$2 value=$3 dir tmp
    dir=$(dirname "$file")
    if $DRY_RUN; then
        log "DRY-RUN: set $key=$value in $file"
        return
    fi
    mkdir -p "$dir"
    tmp="$file.tmp.$$"
    awk -v key="$key" -v value="$value" '
        BEGIN { written=0 }
        $0 ~ "^[[:space:]]*" key "[[:space:]]*=" {
            if (!written) { print key "=" value; written=1 }
            next
        }
        { print }
        END { if (!written) print key "=" value }
    ' "$file" 2>/dev/null > "$tmp" || printf '%s=%s\n' "$key" "$value" > "$tmp"
    mv "$tmp" "$file"
}

update_space_key() {
    local file=$1 key=$2 value=$3 dir tmp
    dir=$(dirname "$file")
    if $DRY_RUN; then
        log "DRY-RUN: set $key $value in $file"
        return
    fi
    mkdir -p "$dir"
    tmp="$file.tmp.$$"
    awk -v key="$key" -v value="$value" '
        BEGIN { written=0 }
        index($0, key " ") == 1 {
            if (!written) { print key " " value; written=1 }
            next
        }
        { print }
        END { if (!written) print key " " value }
    ' "$file" 2>/dev/null > "$tmp" || printf '%s %s\n' "$key" "$value" > "$tmp"
    mv "$tmp" "$file"
}

set_gsetting_string() {
    local schema=$1 key=$2 value=$3 escaped
    [[ -n $value ]] || return
    [[ $NO_RUNTIME == true ]] && return
    command -v gsettings >/dev/null 2>&1 || return
    gsettings writable "$schema" "$key" 2>/dev/null | grep -qx true || return
    escaped=${value//\'/\\\'}
    run gsettings set "$schema" "$key" "'$escaped'" || true
}

set_gsetting_int() {
    local schema=$1 key=$2 value=$3
    [[ $NO_RUNTIME == true ]] && return
    command -v gsettings >/dev/null 2>&1 || return
    gsettings writable "$schema" "$key" 2>/dev/null | grep -qx true || return
    run gsettings set "$schema" "$key" "$value" || true
}

set_gsetting_bool() {
    local schema=$1 key=$2 value=$3
    [[ $NO_RUNTIME == true ]] && return
    command -v gsettings >/dev/null 2>&1 || return
    gsettings writable "$schema" "$key" 2>/dev/null | grep -qx true || return
    run gsettings set "$schema" "$key" "$value" || true
}

for gtk_version in 3.0 4.0; do
    gtk_settings="$XDG_CONFIG_HOME/gtk-$gtk_version/settings.ini"
    [[ -n $GTK_THEME ]] && update_ini "$gtk_settings" Settings gtk-theme-name "$GTK_THEME"
    [[ -n $ICON_THEME ]] && update_ini "$gtk_settings" Settings gtk-icon-theme-name "$ICON_THEME"
    [[ -n $CURSOR_THEME ]] && update_ini "$gtk_settings" Settings gtk-cursor-theme-name "$CURSOR_THEME"
    update_ini "$gtk_settings" Settings gtk-cursor-theme-size "$CURSOR_SIZE"
    update_ini "$gtk_settings" Settings gtk-font-name "$FONT $FONT_SIZE"
    update_ini "$gtk_settings" Settings gtk-application-prefer-dark-theme "$([[ $MODE == dark ]] && printf true || printf false)"
done

ensure_matugen_css_import() {
    local gtk_dir=$1 colors_file css_file tmp backup
    colors_file="$gtk_dir/dank-colors.css"
    css_file="$gtk_dir/gtk.css"
    [[ -f $colors_file ]] || return
    if $DRY_RUN; then
        log "DRY-RUN: ensure Matugen import in $css_file"
        return
    fi
    mkdir -p "$gtk_dir"
    if [[ -f $css_file ]] && grep -Fq '@import url("dank-colors.css");' "$css_file"; then
        return
    fi

    tmp="$css_file.tmp.$$"
    backup="$css_file.dms-theme-sync-backup"
    if [[ -L $css_file ]]; then
        [[ -e $backup || -L $backup ]] || cp -a "$css_file" "$backup"
        printf '@import url("dank-colors.css");\n' > "$tmp"
    elif [[ -f $css_file ]] && grep -q 'Generated with Matugen' "$css_file"; then
        printf '@import url("dank-colors.css");\n' > "$tmp"
    elif [[ -s $css_file ]]; then
        printf '@import url("dank-colors.css");\n' > "$tmp"
        cat "$css_file" >> "$tmp"
    else
        printf '@import url("dank-colors.css");\n' > "$tmp"
    fi
    rm -f "$css_file"
    mv "$tmp" "$css_file"
}

if [[ $APPLY_MATUGEN_COLORS == true ]]; then
    ensure_matugen_css_import "$XDG_CONFIG_HOME/gtk-3.0"
    ensure_matugen_css_import "$XDG_CONFIG_HOME/gtk-4.0"
fi

GTK2_RC="$HOME/.gtkrc-2.0"
[[ -n $GTK_THEME ]] && update_equals_key "$GTK2_RC" gtk-theme-name "\"$GTK_THEME\""
[[ -n $ICON_THEME ]] && update_equals_key "$GTK2_RC" gtk-icon-theme-name "\"$ICON_THEME\""
[[ -n $CURSOR_THEME ]] && update_equals_key "$GTK2_RC" gtk-cursor-theme-name "\"$CURSOR_THEME\""
update_equals_key "$GTK2_RC" gtk-cursor-theme-size "$CURSOR_SIZE"
update_equals_key "$GTK2_RC" gtk-font-name "\"$FONT $FONT_SIZE\""

set_gsetting_string org.gnome.desktop.interface gtk-theme "$GTK_THEME"
set_gsetting_string org.gnome.desktop.interface icon-theme "$ICON_THEME"
set_gsetting_string org.gnome.desktop.interface cursor-theme "$CURSOR_THEME"
set_gsetting_int org.gnome.desktop.interface cursor-size "$CURSOR_SIZE"
set_gsetting_string org.gnome.desktop.interface font-name "$FONT $FONT_SIZE"
set_gsetting_string org.gnome.desktop.interface document-font-name "$DOCUMENT_FONT $DOCUMENT_SIZE"
set_gsetting_string org.gnome.desktop.interface monospace-font-name "$MONO_FONT $MONO_SIZE"
set_gsetting_string org.gnome.desktop.wm.preferences titlebar-font "$FONT Bold $FONT_SIZE"
set_gsetting_string org.gnome.desktop.interface color-scheme "$([[ $MODE == dark ]] && printf prefer-dark || printf prefer-light)"
set_gsetting_bool org.gnome.desktop.interface gtk-enable-animations true

for qt_version in 5 6; do
    qt_file="$XDG_CONFIG_HOME/qt${qt_version}ct/qt${qt_version}ct.conf"
    [[ $QT_STYLE != preserve ]] && update_ini "$qt_file" Appearance style "$QT_STYLE"
    [[ -n $ICON_THEME ]] && update_ini "$qt_file" Appearance icon_theme "$ICON_THEME"
    update_ini "$qt_file" Fonts general "\"$FONT,$FONT_SIZE,-1,5,400,0,0,0,0,0\""
    update_ini "$qt_file" Fonts fixed "\"$MONO_FONT,$MONO_SIZE,-1,5,400,0,0,0,0,0\""
    if [[ $APPLY_MATUGEN_COLORS == true && -f $XDG_DATA_HOME/color-schemes/DankMatugen.colors ]]; then
        update_ini "$qt_file" Appearance custom_palette true
        update_ini "$qt_file" Appearance color_scheme_path "$XDG_DATA_HOME/color-schemes/DankMatugen.colors"
    fi
done

if [[ $SYNC_KDE == true ]]; then
    KDEGLOBALS="$XDG_CONFIG_HOME/kdeglobals"
    update_ini "$KDEGLOBALS" General font "$FONT,$FONT_SIZE,-1,5,400,0,0,0,0,0"
    update_ini "$KDEGLOBALS" General fixed "$MONO_FONT,$MONO_SIZE,-1,5,400,0,0,0,0,0"
    update_ini "$KDEGLOBALS" General menuFont "$FONT,$FONT_SIZE,-1,5,400,0,0,0,0,0"
    update_ini "$KDEGLOBALS" General toolBarFont "$FONT,$FONT_SIZE,-1,5,400,0,0,0,0,0"
    update_ini "$KDEGLOBALS" General smallestReadableFont "$FONT,$FONT_SIZE,-1,5,400,0,0,0,0,0"
    [[ -n $ICON_THEME ]] && update_ini "$KDEGLOBALS" Icons Theme "$ICON_THEME"
    if [[ $APPLY_MATUGEN_COLORS == true && -f $XDG_DATA_HOME/color-schemes/DankMatugen.colors ]]; then
        update_ini "$KDEGLOBALS" General ColorScheme DankMatugen
    fi
    [[ -n $CURSOR_THEME ]] && update_ini "$XDG_CONFIG_HOME/kcminputrc" Mouse cursorTheme "$CURSOR_THEME"
    update_ini "$XDG_CONFIG_HOME/kcminputrc" Mouse cursorSize "$CURSOR_SIZE"
fi

if [[ $SYNC_XSETTINGSD == true ]]; then
    XSETTINGSD="$XDG_CONFIG_HOME/xsettingsd/xsettingsd.conf"
    [[ -n $GTK_THEME ]] && update_space_key "$XSETTINGSD" Net/ThemeName "\"$GTK_THEME\""
    [[ -n $ICON_THEME ]] && update_space_key "$XSETTINGSD" Net/IconThemeName "\"$ICON_THEME\""
    [[ -n $CURSOR_THEME ]] && update_space_key "$XSETTINGSD" Gtk/CursorThemeName "\"$CURSOR_THEME\""
    update_space_key "$XSETTINGSD" Gtk/CursorThemeSize "$CURSOR_SIZE"
    update_space_key "$XSETTINGSD" Gtk/FontName "\"$FONT $FONT_SIZE\""
    if ! $DRY_RUN && [[ $NO_RUNTIME != true ]] && command -v xsettingsd >/dev/null 2>&1; then
        pkill -HUP -x xsettingsd 2>/dev/null || true
    fi
fi

xml_escape() {
    printf '%s' "$1" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'"'"'/\&apos;/g'
}

FONTCONFIG_DIR="$XDG_CONFIG_HOME/fontconfig/conf.d"
FONTCONFIG_FILE="$FONTCONFIG_DIR/99-dms-theme-sync.conf"
if $DRY_RUN; then
    log "DRY-RUN: write $FONTCONFIG_FILE"
else
    mkdir -p "$FONTCONFIG_DIR"
    font_xml=$(xml_escape "$FONT")
    mono_xml=$(xml_escape "$MONO_FONT")
    document_xml=$(xml_escape "$DOCUMENT_FONT")
    tmp="$FONTCONFIG_FILE.tmp.$$"
    # /etc/fonts/conf.d/50-user.conf pulls in the whole of
    # $XDG_CONFIG_HOME/fontconfig, so this file is parsed at position ~50 —
    # BEFORE 60-latin.conf (which prefers Noto Sans Mono for monospace) and
    # 66-noto-sans.conf (Noto Sans for sans-serif). An <alias><prefer> from here
    # therefore never wins, whatever the 99- prefix suggests. A strong-bound
    # prepend does: later <prefer> families are inserted behind it.
    printf '%s\n' \
        '<?xml version="1.0"?>' \
        '<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">' \
        '<fontconfig>' \
        '  <match target="pattern"><test name="family"><string>sans-serif</string></test>' \
        '    <edit name="family" mode="prepend" binding="strong"><string>'"$font_xml"'</string></edit></match>' \
        '  <match target="pattern"><test name="family"><string>monospace</string></test>' \
        '    <edit name="family" mode="prepend" binding="strong"><string>'"$mono_xml"'</string></edit></match>' \
        '  <match target="pattern"><test name="family"><string>serif</string></test>' \
        '    <edit name="family" mode="prepend" binding="strong"><string>'"$document_xml"'</string></edit></match>' \
        '</fontconfig>' > "$tmp"
    mv "$tmp" "$FONTCONFIG_FILE"
    if [[ $NO_RUNTIME != true ]] && command -v fc-cache >/dev/null 2>&1; then
        fc-cache -f >/dev/null 2>&1 || true
    fi
fi

# --- Flatpak ------------------------------------------------------------------
#
# Sandboxed apps see none of the files written above. Dark/light already reaches
# them through the portal (org.freedesktop.appearance), but the theme names and
# the host's gtk.css do not: they need an explicit env override plus read-only
# access to the theme directories.
#
# This is also the only place where Electron apps can be reached in a sensible
# way. Native Electron mostly ignores the system theme, and the usual workaround
# — exporting GTK_THEME globally — would override settings.ini for *every* GTK
# app on the machine. Not worth it. Inside the Flatpak sandbox the same variable
# is scoped to the sandbox, so it is safe there and nowhere else.
#
# `flatpak override` is declarative, so re-running it is idempotent.
sync_flatpak_overrides() {
    command -v flatpak >/dev/null 2>&1 || return 0
    local -a args=(override --user)
    [[ -n $GTK_THEME ]]    && args+=("--env=GTK_THEME=$GTK_THEME")
    [[ -n $ICON_THEME ]]   && args+=("--env=ICON_THEME=$ICON_THEME")
    [[ -n $CURSOR_THEME ]] && args+=("--env=XCURSOR_THEME=$CURSOR_THEME" "--env=XCURSOR_SIZE=$CURSOR_SIZE")
    (( ${#args[@]} > 2 )) || return 0
    args+=(
        "--filesystem=xdg-config/gtk-3.0:ro"
        "--filesystem=xdg-config/gtk-4.0:ro"
        "--filesystem=xdg-data/themes:ro"
        "--filesystem=xdg-data/icons:ro"
        "--filesystem=~/.themes:ro"
        "--filesystem=~/.icons:ro"
    )
    if $DRY_RUN; then
        run flatpak "${args[@]}"      # `run` prints the command; do not swallow it
    else
        flatpak "${args[@]}" >/dev/null 2>&1 || log "flatpak: could not write user overrides"
    fi
}

if [[ $SYNC_FLATPAK == true ]] && { $DRY_RUN || [[ $NO_RUNTIME != true ]]; }; then
    sync_flatpak_overrides
fi

# --- Kvantum ------------------------------------------------------------------
#
# Kvantum draws Qt widgets from an SVG and takes its colours from its own theme
# (<name>.kvconfig + <name>.svg), not from the qt5ct/qt6ct palette. So selecting
# the kvantum style without giving it a theme does not add Material You to Qt —
# it removes it, swapping the DMS palette for whatever Kvantum was last set to.
#
# Render both files from the templates in assets/kvantum/ (vendored from
# InioX/matugen-themes, MIT) with the 12 Material roles DMS hands us, then point
# kvantum.kvconfig at the result. The SVG has to be recoloured too: it is where
# every widget shape lives, and it contains no hard-coded hex at all.
kvantum_style_plugin_installed() {
    find /usr/lib /usr/lib64 -name 'libkvantum*.so' -print -quit 2>/dev/null | grep -q .
}

sync_kvantum_theme() {
    local tpl_dir out_dir name=DankMatugen role hex
    tpl_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../assets/kvantum" 2>/dev/null && pwd)" || return 1
    [[ -f $tpl_dir/$name.kvconfig.in && -f $tpl_dir/$name.svg.in ]] || {
        log "kvantum: templates missing at assets/kvantum"; return 1; }
    [[ -n $KV_COLORS ]] || { log "kvantum: no colours supplied; skipping"; return 1; }

    out_dir="$XDG_CONFIG_HOME/Kvantum/$name"
    if $DRY_RUN; then log "DRY-RUN: render $out_dir/$name.{kvconfig,svg} and select it"; return 0; fi
    mkdir -p "$out_dir"

    local -a sed_args=()
    # KV_COLORS is "role=#hex;role=#hex;..." — no trailing separator, so the last
    # pair has no newline and plain `read` would silently drop it.
    while IFS='=' read -r role hex || [[ -n $role ]]; do
        [[ -n $role && $hex =~ ^#[0-9a-fA-F]{6}$ ]] || continue
        sed_args+=(-e "s|{{colors\.${role}\.default\.hex}}|${hex}|g")
    done < <(printf '%s' "$KV_COLORS" | tr ';' '\n')
    (( ${#sed_args[@]} )) || { log "kvantum: no usable colours; skipping"; return 1; }

    local f
    for f in kvconfig svg; do
        sed "${sed_args[@]}" "$tpl_dir/$name.$f.in" > "$out_dir/$name.$f.tmp.$$" || return 1
        mv "$out_dir/$name.$f.tmp.$$" "$out_dir/$name.$f"
    done

    # Any leftover placeholder means a role DMS did not give us: Kvantum would
    # render a literal "{{...}}" as an invalid colour and fall back to grey.
    local leftover
    leftover=$(grep -ohE '\{\{colors\.[a-z_]+' "$out_dir/$name.kvconfig" "$out_dir/$name.svg" | sort -u | head -3)
    [[ -n $leftover ]] && log "kvantum: unresolved roles: $(tr '\n' ' ' <<<"$leftover")"

    update_ini "$XDG_CONFIG_HOME/Kvantum/kvantum.kvconfig" General theme "$name"
    log "kvantum: theme '$name' rendered and selected"
}

if [[ $SYNC_KVANTUM == true && $QT_STYLE == kvantum ]]; then
    if $DRY_RUN || kvantum_style_plugin_installed; then
        sync_kvantum_theme || true
    fi
fi

# Terminal emulators read their own config, not GTK/Qt/gsettings/fontconfig, so
# the monospace font never reaches them through the toolkit sync above. When the
# user opts in, we generate one font include per terminal — each in that
# terminal's own config syntax — under a single stable directory. The plugin only
# writes these generated files; the user references each one from their terminal
# config once (see the header comment in every file). Terminals pick up the
# change on their next launch or config reload.
TERMINAL_DIR="$XDG_CONFIG_HOME/dms-theme-sync"

write_terminal_font_includes() {
    mkdir -p "$TERMINAL_DIR"
    local tmp

    # kitty: `font_family <name>` / `font_size <n>`, value is the rest of the line
    # (unquoted, spaces preserved). Referenced with `include <path>`.
    tmp="$TERMINAL_DIR/kitty.conf.tmp.$$"
    {
        printf '%s\n' '# ! AUTO-GENERATED BY dmsThemeSync — DO NOT EDIT !'
        printf '%s\n' '# ! Monospace font managed by the DMS Theme Sync plugin. !'
        printf '%s\n' "# Reference from kitty.conf:  include $TERMINAL_DIR/kitty.conf"
        printf 'font_family %s\n' "$MONO_FONT"
        printf 'font_size %s\n' "$MONO_SIZE"
    } > "$tmp"
    mv "$tmp" "$TERMINAL_DIR/kitty.conf"

    # ghostty: `key = value`, unquoted value keeps spaces. Referenced with
    # `config-file = <path>`.
    tmp="$TERMINAL_DIR/ghostty.conf.tmp.$$"
    {
        printf '%s\n' '# ! AUTO-GENERATED BY dmsThemeSync — DO NOT EDIT !'
        printf '%s\n' '# ! Monospace font managed by the DMS Theme Sync plugin. !'
        printf '%s\n' "# Reference from the ghostty config:  config-file = $TERMINAL_DIR/ghostty.conf"
        printf 'font-family = %s\n' "$MONO_FONT"
        printf 'font-size = %s\n' "$MONO_SIZE"
    } > "$tmp"
    mv "$tmp" "$TERMINAL_DIR/ghostty.conf"

    # alacritty: TOML. The family string needs backslash and double-quote escaped.
    # Referenced from alacritty.toml with `[general]` `import = ["<path>"]`.
    local mono_toml=$MONO_FONT
    mono_toml=${mono_toml//\\/\\\\}
    mono_toml=${mono_toml//\"/\\\"}
    tmp="$TERMINAL_DIR/alacritty.toml.tmp.$$"
    {
        printf '%s\n' '# ! AUTO-GENERATED BY dmsThemeSync — DO NOT EDIT !'
        printf '%s\n' '# ! Monospace font managed by the DMS Theme Sync plugin. !'
        printf '%s\n' "# Reference from alacritty.toml:  [general] import = [\"$TERMINAL_DIR/alacritty.toml\"]"
        printf '%s\n' '[font]'
        printf 'size = %s\n' "$MONO_SIZE"
        printf '%s\n' '[font.normal]'
        printf 'family = "%s"\n' "$mono_toml"
    } > "$tmp"
    mv "$tmp" "$TERMINAL_DIR/alacritty.toml"
}

if [[ $SYNC_TERMINAL_FONTS == true ]]; then
    if $DRY_RUN; then
        log "DRY-RUN: write terminal font includes in $TERMINAL_DIR (kitty.conf, alacritty.toml, ghostty.conf)"
    else
        write_terminal_font_includes
    fi
fi

if [[ -n $CURSOR_THEME ]]; then
    for cursor_default in "$HOME/.icons/default/index.theme" "$XDG_DATA_HOME/icons/default/index.theme"; do
        update_ini "$cursor_default" "Icon Theme" Inherits "$CURSOR_THEME"
    done
fi

ENV_DIR="$XDG_CONFIG_HOME/environment.d"
ENV_FILE="$ENV_DIR/90-dms-theme-sync.conf"
NIRI_DIR="$XDG_CONFIG_HOME/niri"
NIRI_INCLUDE="$NIRI_DIR/dms-theme-sync.kdl"
NIRI_ENV_KDL="$NIRI_DIR/environment.kdl"
NIRI_CONFIG_KDL="$NIRI_DIR/config.kdl"

HYPR_DIR="$XDG_CONFIG_HOME/hypr"
HYPR_INCLUDE="$HYPR_DIR/dms-theme-sync.conf"       # hyprlang (legacy)
HYPR_CONFIG="$HYPR_DIR/hyprland.conf"
HYPR_LUA_INCLUDE="$HYPR_DIR/dms-theme-sync.lua"    # Lua (Hyprland >=0.55)
HYPR_LUA_CONFIG="$HYPR_DIR/hyprland.lua"
LABWC_DIR="$XDG_CONFIG_HOME/labwc"
LABWC_ENV="$LABWC_DIR/environment"
LABWC_BEGIN='# >>> dmsThemeSync >>>'
LABWC_END='# <<< dmsThemeSync <<<'

# Resolve the Qt platform-theme values once; both are empty under "preserve".
QT_PLATFORM_QT5=""
QT_PLATFORM_QT6=""
case "$QT_PLATFORM_THEME" in
    gtk3) QT_PLATFORM_QT5=gtk3; QT_PLATFORM_QT6=gtk3 ;;
    qtct) QT_PLATFORM_QT5=qt5ct; QT_PLATFORM_QT6=qt6ct ;;
esac

# DMS passes --compositor (CompositorService.compositor). Fall back to sniffing
# the session env so the helper also works when invoked standalone or in tests.
detect_compositor() {
    [[ -n ${NIRI_SOCKET:-} ]] && { printf niri; return; }
    [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] && { printf hyprland; return; }
    [[ -n ${MANGO_INSTANCE_SIGNATURE:-} ]] && { printf mango; return; }
    [[ -n ${MIRACLESOCK:-} ]] && { printf miracle; return; }
    [[ -n ${LABWC_PID:-} ]] && { printf labwc; return; }
    [[ -n ${SWAYSOCK:-} ]] && { printf sway; return; }
    case "${XDG_CURRENT_DESKTOP:-}|${DESKTOP_SESSION:-}" in
        *[Nn]iri*) printf niri ;;
        *[Hh]ypr*) printf hyprland ;;
        *[Ll]abwc*) printf labwc ;;
        *[Ss]way*) printf sway ;;
        *) printf '' ;;
    esac
}

[[ -n $COMPOSITOR ]] || COMPOSITOR=$(detect_compositor)

# Universal baseline: environment.d is imported by sessions started through uwsm
# or systemd, which is how DMS launches every supported compositor except Niri.
write_environment_d() {
    mkdir -p "$ENV_DIR"
    local tmp="$ENV_FILE.tmp.$$"
    {
        [[ -n $CURSOR_THEME ]] && printf 'XCURSOR_THEME=%s\nHYPRCURSOR_THEME=%s\n' "$CURSOR_THEME" "$CURSOR_THEME"
        printf 'XCURSOR_SIZE=%s\nHYPRCURSOR_SIZE=%s\n' "$CURSOR_SIZE" "$CURSOR_SIZE"
        # QT_QPA_PLATFORMTHEME is only written when the user explicitly opts in.
        # With "preserve" (default) the plugin does not touch it, so a value set
        # by the user in /etc/environment or another environment.d file wins.
        [[ -n $QT_PLATFORM_QT5 ]] && printf 'QT_QPA_PLATFORMTHEME=%s\nQT_QPA_PLATFORMTHEME_QT6=%s\n' "$QT_PLATFORM_QT5" "$QT_PLATFORM_QT6"
    } > "$tmp"
    mv "$tmp" "$ENV_FILE"
}

# Hyprland reads env vars from its config, not environment.d. Mirror the Niri
# approach with a dedicated generated include sourced once from the main config.
# Hyprland 0.55 (May 2026) switched the config format from hyprlang to Lua, so we
# write whichever the user actually has — hyprland.conf (hyprlang) and/or
# hyprland.lua (Lua); a Lua-only setup never gets a hyprlang file and vice versa.
# We never create a main config that does not exist, so we can't inject a file
# format the user is not using. env applies to processes launched after parsing;
# the live session is also refreshed below via systemctl set-environment.
write_hyprland_env_include() {
    mkdir -p "$HYPR_DIR"

    # Legacy hyprlang: `env = KEY,VALUE`, sourced with `source = file` (relative).
    if [[ -f $HYPR_CONFIG ]]; then
        local tmp="$HYPR_INCLUDE.tmp.$$"
        {
            printf '%s\n' '# ! AUTO-GENERATED BY dmsThemeSync — DO NOT EDIT !'
            printf '%s\n' '# ! Cursor and Qt platform theme managed by the DMS Theme Sync plugin. !'
            if [[ -n $CURSOR_THEME ]]; then
                printf 'env = XCURSOR_THEME,%s\n' "$CURSOR_THEME"
                printf 'env = HYPRCURSOR_THEME,%s\n' "$CURSOR_THEME"
            fi
            printf 'env = XCURSOR_SIZE,%s\n' "$CURSOR_SIZE"
            printf 'env = HYPRCURSOR_SIZE,%s\n' "$CURSOR_SIZE"
            if [[ -n $QT_PLATFORM_QT5 ]]; then
                printf 'env = QT_QPA_PLATFORMTHEME,%s\n' "$QT_PLATFORM_QT5"
                printf 'env = QT_QPA_PLATFORMTHEME_QT6,%s\n' "$QT_PLATFORM_QT6"
            fi
        } > "$tmp"
        mv "$tmp" "$HYPR_INCLUDE"
        grep -q 'dms-theme-sync.conf' "$HYPR_CONFIG" \
            || printf '\nsource = dms-theme-sync.conf\n' >> "$HYPR_CONFIG"
    fi

    # Lua (Hyprland >=0.55): `hl.env("KEY", "VALUE")`, sourced with require() by
    # module name (no .lua suffix).
    if [[ -f $HYPR_LUA_CONFIG ]]; then
        local tmp="$HYPR_LUA_INCLUDE.tmp.$$"
        {
            printf '%s\n' '-- ! AUTO-GENERATED BY dmsThemeSync — DO NOT EDIT !'
            printf '%s\n' '-- ! Cursor and Qt platform theme managed by the DMS Theme Sync plugin. !'
            if [[ -n $CURSOR_THEME ]]; then
                printf 'hl.env("XCURSOR_THEME", "%s")\n' "$CURSOR_THEME"
                printf 'hl.env("HYPRCURSOR_THEME", "%s")\n' "$CURSOR_THEME"
            fi
            printf 'hl.env("XCURSOR_SIZE", "%s")\n' "$CURSOR_SIZE"
            printf 'hl.env("HYPRCURSOR_SIZE", "%s")\n' "$CURSOR_SIZE"
            if [[ -n $QT_PLATFORM_QT5 ]]; then
                printf 'hl.env("QT_QPA_PLATFORMTHEME", "%s")\n' "$QT_PLATFORM_QT5"
                printf 'hl.env("QT_QPA_PLATFORMTHEME_QT6", "%s")\n' "$QT_PLATFORM_QT6"
            fi
        } > "$tmp"
        mv "$tmp" "$HYPR_LUA_INCLUDE"
        grep -q 'require("dms-theme-sync")' "$HYPR_LUA_CONFIG" \
            || printf '\nrequire("dms-theme-sync")\n' >> "$HYPR_LUA_CONFIG"
    fi
}

# labwc reads ~/.config/labwc/environment (KEY=value) at startup. There is no
# include directive, so the plugin manages a single delimited block in place and
# leaves any user lines around it untouched.
write_labwc_env_block() {
    mkdir -p "$LABWC_DIR"
    local tmp="$LABWC_ENV.tmp.$$"
    if [[ -f $LABWC_ENV ]]; then
        awk -v b="$LABWC_BEGIN" -v e="$LABWC_END" '
            $0 == b { skip=1; next }
            $0 == e { skip=0; next }
            !skip { print }
        ' "$LABWC_ENV" > "$tmp"
    else
        : > "$tmp"
    fi
    {
        printf '%s\n' "$LABWC_BEGIN"
        printf '%s\n' '# AUTO-GENERATED by dmsThemeSync — change DMS settings, not this block.'
        if [[ -n $CURSOR_THEME ]]; then
            printf 'XCURSOR_THEME=%s\n' "$CURSOR_THEME"
            printf 'HYPRCURSOR_THEME=%s\n' "$CURSOR_THEME"
        fi
        printf 'XCURSOR_SIZE=%s\n' "$CURSOR_SIZE"
        printf 'HYPRCURSOR_SIZE=%s\n' "$CURSOR_SIZE"
        if [[ -n $QT_PLATFORM_QT5 ]]; then
            printf 'QT_QPA_PLATFORMTHEME=%s\n' "$QT_PLATFORM_QT5"
            printf 'QT_QPA_PLATFORMTHEME_QT6=%s\n' "$QT_PLATFORM_QT6"
        fi
        printf '%s\n' "$LABWC_END"
    } >> "$tmp"
    mv "$tmp" "$LABWC_ENV"
}

# Niri reads env vars from its environment {} block, not environment.d. On Niri
# we generate a dedicated include (cursor + Qt platform theme) and reference it
# once as a TOP-LEVEL include in config.kdl. Placement matters: it must come
# after the dms/*.kdl includes (so the synced theme overrides DMS-generated
# cursor/theme values) and before any user override includes (user*.kdl keeps
# the last word), so on fresh setups the line is inserted before the first
# `include "user..."` if present. If the line already exists anywhere in
# config.kdl, its position is respected and nothing is moved.
write_niri_env_include() {
    local qt5="" qt6=""
    case "$QT_PLATFORM_THEME" in
        gtk3) qt5=gtk3; qt6=gtk3 ;;
        qtct) qt5=qt5ct; qt6=qt6ct ;;
    esac

    local tmp="$NIRI_INCLUDE.tmp.$$"
    {
        printf '%s\n' '// ! AUTO-GENERATED BY dmsThemeSync — DO NOT EDIT !'
        printf '%s\n' '// ! Cursor and Qt platform theme managed by the DMS Theme Sync plugin. !'
        printf '%s\n' 'environment {'
        if [[ -n $CURSOR_THEME ]]; then
            printf '    XCURSOR_THEME "%s"\n' "$CURSOR_THEME"
            printf '    HYPRCURSOR_THEME "%s"\n' "$CURSOR_THEME"
        fi
        printf '    XCURSOR_SIZE "%s"\n' "$CURSOR_SIZE"
        printf '    HYPRCURSOR_SIZE "%s"\n' "$CURSOR_SIZE"
        if [[ -n $qt5 ]]; then
            printf '    QT_QPA_PLATFORMTHEME "%s"\n' "$qt5"
            printf '    QT_QPA_PLATFORMTHEME_QT6 "%s"\n' "$qt6"
        fi
        printf '%s\n' '}'
    } > "$tmp"
    mv "$tmp" "$NIRI_INCLUDE"

    [[ -f $NIRI_CONFIG_KDL ]] || return 0

    # All writes go through `cat > target` so symlinked configs (dotfile
    # managers like lnk) are written through, never replaced.
    local changed=false backup_env="" backup_cfg=""

    # Migration: versions <=0.3.0 appended the include to environment.kdl.
    # Remove it there so config.kdl is the single reference point.
    if [[ -f $NIRI_ENV_KDL ]] && grep -q '^include "dms-theme-sync.kdl"$' "$NIRI_ENV_KDL"; then
        backup_env=$(cat "$NIRI_ENV_KDL")
        grep -v '^include "dms-theme-sync.kdl"$' "$NIRI_ENV_KDL" > "$NIRI_ENV_KDL.tmp.$$" \
            && cat "$NIRI_ENV_KDL.tmp.$$" > "$NIRI_ENV_KDL"
        rm -f "$NIRI_ENV_KDL.tmp.$$"
        changed=true
    fi

    if ! grep -q 'dms-theme-sync.kdl' "$NIRI_CONFIG_KDL"; then
        backup_cfg=$(cat "$NIRI_CONFIG_KDL")
        if grep -q '^include "user' "$NIRI_CONFIG_KDL"; then
            awk '!done && /^include "user/ { print "include \"dms-theme-sync.kdl\""; done=1 } { print }' \
                "$NIRI_CONFIG_KDL" > "$NIRI_CONFIG_KDL.tmp.$$" \
                && cat "$NIRI_CONFIG_KDL.tmp.$$" > "$NIRI_CONFIG_KDL"
            rm -f "$NIRI_CONFIG_KDL.tmp.$$"
        else
            printf '\ninclude "dms-theme-sync.kdl"\n' >> "$NIRI_CONFIG_KDL"
        fi
        changed=true
    fi

    # Validate the combined result; on failure restore both files verbatim.
    if [[ $changed == true && $NO_RUNTIME != true ]] && command -v niri >/dev/null 2>&1 \
        && ! niri validate >/dev/null 2>&1; then
        [[ -n $backup_cfg ]] && printf '%s\n' "$backup_cfg" > "$NIRI_CONFIG_KDL"
        [[ -n $backup_env ]] && printf '%s\n' "$backup_env" > "$NIRI_ENV_KDL"
        log "WARN: niri validate failed; reverted include changes in config.kdl/environment.kdl"
    fi
}

if $DRY_RUN; then
    case "$COMPOSITOR" in
        niri)     log "DRY-RUN: write Niri include $NIRI_INCLUDE (+ top-level include in config.kdl), drop $ENV_FILE" ;;
        hyprland) log "DRY-RUN: write $ENV_FILE + Hyprland include (hyprlang and/or Lua, whichever main config exists)" ;;
        labwc)    log "DRY-RUN: write $ENV_FILE + labwc block in $LABWC_ENV" ;;
        *)        log "DRY-RUN: write $ENV_FILE (environment.d baseline)" ;;
    esac
elif [[ $COMPOSITOR == niri ]] && [[ -d $NIRI_DIR ]]; then
    # On Niri the include replaces environment.d for cursor/Qt. Drop the plugin's
    # environment.d file so there is a single source for Niri-launched apps.
    write_niri_env_include
    rm -f "$ENV_FILE" 2>/dev/null || true
else
    # Every other compositor: write the environment.d baseline, then add a native
    # include where the compositor has its own env mechanism (Hyprland, labwc).
    # Sway/Scroll/MangoWC/Miracle have no env-to-children directive and rely on
    # the baseline being imported by uwsm/systemd.
    write_environment_d
    case "$COMPOSITOR" in
        hyprland) write_hyprland_env_include ;;
        labwc)    write_labwc_env_block ;;
    esac
fi

# Update the running systemd user environment in all cases (current session).
if ! $DRY_RUN && [[ $NO_RUNTIME != true ]] && command -v systemctl >/dev/null 2>&1; then
    env_args=("XCURSOR_SIZE=$CURSOR_SIZE" "HYPRCURSOR_SIZE=$CURSOR_SIZE")
    [[ -n $CURSOR_THEME ]] && env_args+=("XCURSOR_THEME=$CURSOR_THEME" "HYPRCURSOR_THEME=$CURSOR_THEME")
    if [[ $QT_PLATFORM_THEME == gtk3 ]]; then
        env_args+=("QT_QPA_PLATFORMTHEME=gtk3" "QT_QPA_PLATFORMTHEME_QT6=gtk3")
    elif [[ $QT_PLATFORM_THEME == qtct ]]; then
        env_args+=("QT_QPA_PLATFORMTHEME=qt5ct" "QT_QPA_PLATFORMTHEME_QT6=qt6ct")
    fi
    systemctl --user set-environment "${env_args[@]}" >/dev/null 2>&1 || true
fi

# --- Reconcile ----------------------------------------------------------------
#
# Writing a file is not the same as the setting taking effect. Every surface
# here has at least one way to be silently overruled: gsettings can be rewritten
# by nwg-look or lxappearance, fontconfig's user directory is parsed *before*
# /etc/fonts/conf.d/60-latin.conf, GTK4 apps choke on symlinks left behind by
# uninstalled themes, and a theme name can point at a directory nobody
# installed. So after writing, read the system back and reconcile.
#
# Anything unambiguously broken is repaired. Anything that needs a human
# decision is reported with the exact file to look at, never silently changed.

RECONCILE_ISSUES=0
note() { RECONCILE_ISSUES=$((RECONCILE_ISSUES + 1)); log "reconcile: $*"; }

# 1. Dangling symlinks under the GTK config dirs. nwg-look points gtk.css and
#    gtk-dark.css at whatever theme was selected; uninstall the theme and the
#    link dangles. libadwaita then fails to load its assets.
prune_broken_links() {
    local d f
    for d in "${XDG_CONFIG_HOME:-$HOME/.config}"/gtk-{3,4}.0; do
        [[ -d $d ]] || continue
        while IFS= read -r -d '' f; do
            note "removed dangling symlink ${f#$HOME/} -> $(readlink "$f")"
            rm -f "$f"
        done < <(find "$d" -maxdepth 1 -xtype l -print0 2>/dev/null)
    done
}

# 2. gsettings is the source GTK3 actually consults on Wayland. If it disagrees
#    with what we just wrote, something else is writing it too: re-assert, then
#    check again and name the likely culprit if it still drifts.
verify_gsettings() {
    local key want got
    for pair in "gtk-theme:$GTK_THEME" "icon-theme:$ICON_THEME" "cursor-theme:$CURSOR_THEME"; do
        key=${pair%%:*}; want=${pair#*:}
        [[ -n $want ]] || continue
        got=$(gsettings get org.gnome.desktop.interface "$key" 2>/dev/null | tr -d "'")
        [[ $got == "$want" ]] && continue
        set_gsetting_string org.gnome.desktop.interface "$key" "$want"
        got=$(gsettings get org.gnome.desktop.interface "$key" 2>/dev/null | tr -d "'")
        [[ $got == "$want" ]] || note "gsettings $key stays '$got', expected '$want'"
    done
}

# 3. Our fontconfig file lives in $XDG_CONFIG_HOME/fontconfig/conf.d, which
#    50-user.conf pulls in at position ~50 — before 60-latin.conf. Strong-bound
#    prepends survive that, a plain <prefer> in the user's own fonts.conf does
#    not: it is parsed later still and wins. Check the outcome, not the file.
verify_fontconfig() {
    local generic want got user_conf="${XDG_CONFIG_HOME:-$HOME/.config}/fontconfig/fonts.conf"
    for pair in "monospace:$MONO_FONT" "sans-serif:$FONT" "serif:$DOCUMENT_FONT"; do
        generic=${pair%%:*}; want=${pair#*:}
        [[ -n $want ]] || continue
        got=$(fc-match "$generic" 2>/dev/null | cut -d'"' -f2)
        [[ $got == "$want" ]] && continue
        if [[ -f $user_conf ]] && grep -q "<family>$generic</family>" "$user_conf"; then
            note "fc-match $generic gives '$got', not '$want' — $user_conf overrides us; remove its <alias> for $generic"
        elif ! fc-list -q :family="$want"; then
            note "font '$want' is not installed; $generic falls back to '$got'"
        else
            note "fc-match $generic gives '$got', not '$want'"
        fi
    done
}

# 4. A theme name is just a string until something resolves it on disk. niri's
#    layout.kdl happily names a cursor nobody installed.
verify_theme_assets() {
    [[ -n $ICON_THEME ]] && ! icon_theme_dir "$ICON_THEME" >/dev/null \
        && note "icon theme '$ICON_THEME' is not installed"
    [[ -n $CURSOR_THEME ]] && ! icon_theme_dir "$CURSOR_THEME" >/dev/null \
        && note "cursor theme '$CURSOR_THEME' is not installed"
    [[ -n $GTK_THEME ]] && ! theme_exists "$GTK_THEME" \
        && note "GTK theme '$GTK_THEME' is not installed"
    # Picking the kvantum style writes style=kvantum into qt{5,6}ct.conf whether
    # or not Kvantum exists. Qt then silently falls back to Fusion.
    #
    # Test for the style plugin Qt actually loads. /usr/share/Kvantum proves
    # nothing: GTK themes such as celestial-gtk-theme ship Kvantum *themes*
    # there without Kvantum itself being installed.
    if [[ $QT_STYLE == kvantum ]] \
        && ! find /usr/lib /usr/lib64 -name 'libkvantum*.so' -print -quit 2>/dev/null | grep -q .; then
        note "Qt style is 'kvantum' but the Kvantum style plugin is missing; Qt falls back to Fusion"
    fi
    return 0
}

# 5. Other appearance tools do not coordinate with anyone. Their mere presence
#    means the next thing the user clicks can undo this run. Report, never touch.
detect_foreign_writers() {
    local cfg="${XDG_CONFIG_HOME:-$HOME/.config}" f
    [[ -e $cfg/nwg-look ]] && note "nwg-look config present ($cfg/nwg-look) — it rewrites gsettings and gtk4 symlinks behind us"
    [[ -e $cfg/lxappearance ]] && note "lxappearance config present — it rewrites gtk settings.ini behind us"
    # Only live scripts count: a commented-out line does nothing, and a *.bak
    # copy is never executed. Flagging either turns this check into noise.
    while IFS= read -r f; do
        [[ $f == *.bak* || $f == *~ ]] && continue
        grep -qE '^[[:space:]]*gsettings set org\.gnome\.desktop\.interface' "$f" \
            && note "$f sets the GTK theme behind us"
    done < <(find "$cfg/variety/scripts" -maxdepth 1 -type f 2>/dev/null)
    return 0
}

if ! $DRY_RUN; then
    # Filesystem-only checks: safe without a session, so they run in tests too.
    prune_broken_links
    verify_theme_assets
    detect_foreign_writers
    if [[ $NO_RUNTIME != true ]]; then
        command -v gsettings >/dev/null 2>&1 && verify_gsettings
        command -v fc-match  >/dev/null 2>&1 && verify_fontconfig
    fi
    (( RECONCILE_ISSUES == 0 )) && log "reconcile: clean" \
        || log "reconcile: $RECONCILE_ISSUES issue(s) above"
fi

log "Synchronized mode=$MODE gtk=${GTK_THEME:-preserved} qt=$QT_PLATFORM_THEME font='$FONT'/$FONT_SIZE mono='$MONO_FONT'/$MONO_SIZE icons=${ICON_THEME:-preserved} cursor=${CURSOR_THEME:-preserved}/$CURSOR_SIZE terminal-fonts=$SYNC_TERMINAL_FONTS"
