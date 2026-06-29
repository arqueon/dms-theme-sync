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
QT_PLATFORM_THEME="gtk3"
QT_STYLE="Fusion"
APPLY_MATUGEN_COLORS=true
SYNC_KDE=true
SYNC_XSETTINGSD=true
DRY_RUN=false
NO_RUNTIME=${DMS_THEME_SYNC_NO_RUNTIME:-false}

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
        --apply-matugen-colors) APPLY_MATUGEN_COLORS=${2:?}; shift 2 ;;
        --sync-kde) SYNC_KDE=${2:?}; shift 2 ;;
        --sync-xsettingsd) SYNC_XSETTINGSD=${2:?}; shift 2 ;;
        --dry-run) DRY_RUN=true; shift ;;
        --no-runtime) NO_RUNTIME=true; shift ;;
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
    update_ini "$qt_file" Appearance style "$QT_STYLE"
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
    printf '%s\n' \
        '<?xml version="1.0"?>' \
        '<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">' \
        '<fontconfig>' \
        '  <alias><family>sans-serif</family><prefer><family>'"$font_xml"'</family></prefer></alias>' \
        '  <alias><family>monospace</family><prefer><family>'"$mono_xml"'</family></prefer></alias>' \
        '  <alias><family>serif</family><prefer><family>'"$document_xml"'</family></prefer></alias>' \
        '</fontconfig>' > "$tmp"
    mv "$tmp" "$FONTCONFIG_FILE"
    if [[ $NO_RUNTIME != true ]] && command -v fc-cache >/dev/null 2>&1; then
        fc-cache -f >/dev/null 2>&1 || true
    fi
fi

if [[ -n $CURSOR_THEME ]]; then
    for cursor_default in "$HOME/.icons/default/index.theme" "$XDG_DATA_HOME/icons/default/index.theme"; do
        update_ini "$cursor_default" "Icon Theme" Inherits "$CURSOR_THEME"
    done
fi

ENV_DIR="$XDG_CONFIG_HOME/environment.d"
ENV_FILE="$ENV_DIR/90-dms-theme-sync.conf"
if $DRY_RUN; then
    log "DRY-RUN: write $ENV_FILE"
else
    mkdir -p "$ENV_DIR"
    tmp="$ENV_FILE.tmp.$$"
    {
        [[ -n $CURSOR_THEME ]] && printf 'XCURSOR_THEME=%s\nHYPRCURSOR_THEME=%s\n' "$CURSOR_THEME" "$CURSOR_THEME"
        printf 'XCURSOR_SIZE=%s\nHYPRCURSOR_SIZE=%s\n' "$CURSOR_SIZE" "$CURSOR_SIZE"
        case "$QT_PLATFORM_THEME" in
            gtk3) printf 'QT_QPA_PLATFORMTHEME=gtk3\nQT_QPA_PLATFORMTHEME_QT6=gtk3\n' ;;
            qtct) printf 'QT_QPA_PLATFORMTHEME=qt5ct\nQT_QPA_PLATFORMTHEME_QT6=qt6ct\n' ;;
        esac
    } > "$tmp"
    mv "$tmp" "$ENV_FILE"

    if [[ $NO_RUNTIME != true ]] && command -v systemctl >/dev/null 2>&1; then
        env_args=("XCURSOR_SIZE=$CURSOR_SIZE" "HYPRCURSOR_SIZE=$CURSOR_SIZE")
        [[ -n $CURSOR_THEME ]] && env_args+=("XCURSOR_THEME=$CURSOR_THEME" "HYPRCURSOR_THEME=$CURSOR_THEME")
        if [[ $QT_PLATFORM_THEME == gtk3 ]]; then
            env_args+=("QT_QPA_PLATFORMTHEME=gtk3" "QT_QPA_PLATFORMTHEME_QT6=gtk3")
        elif [[ $QT_PLATFORM_THEME == qtct ]]; then
            env_args+=("QT_QPA_PLATFORMTHEME=qt5ct" "QT_QPA_PLATFORMTHEME_QT6=qt6ct")
        fi
        systemctl --user set-environment "${env_args[@]}" >/dev/null 2>&1 || true
    fi
fi

log "Synchronized mode=$MODE gtk=${GTK_THEME:-preserved} qt=$QT_PLATFORM_THEME font='$FONT'/$FONT_SIZE mono='$MONO_FONT'/$MONO_SIZE icons=${ICON_THEME:-preserved} cursor=${CURSOR_THEME:-preserved}/$CURSOR_SIZE"
