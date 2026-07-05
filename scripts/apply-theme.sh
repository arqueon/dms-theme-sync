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

log "Synchronized mode=$MODE gtk=${GTK_THEME:-preserved} qt=$QT_PLATFORM_THEME font='$FONT'/$FONT_SIZE mono='$MONO_FONT'/$MONO_SIZE icons=${ICON_THEME:-preserved} cursor=${CURSOR_THEME:-preserved}/$CURSOR_SIZE"
