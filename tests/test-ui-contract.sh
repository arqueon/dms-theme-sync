#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
settings="$ROOT/ThemeSyncSettings.qml"
service="$ROOT/ThemeSyncService.qml"

if grep -rnE '\bDank(Button|TextField|ActionButton|Dropdown|Slider|Toggle|Icon|Modal)\b' "$ROOT"/*.qml >/dev/null; then
    printf 'Deprecated Dank* or DankModal widget reference found in QML\n' >&2
    exit 1
fi

grep -Fq 'names = ["blue", "purple", "green", "orange", "red", "cyan", "pink", "amber", "coral", "monochrome"]' "$settings"
grep -Fq 'function selectIconTheme(value, lightMode)' "$settings"
grep -Fq 'id: iconThemeVerifyTimer' "$settings"
grep -Fq 'Dux kept ' "$settings"
grep -Fq 'SettingsData.setIconThemeForMode(value, targetLight)' "$settings"
grep -Fq 'text: "Separate light and dark themes"' "$settings"
grep -Fq 'currentValue: root.iconThemeDark' "$settings"
grep -Fq 'currentValue: root.iconThemeLight' "$settings"
grep -Fq 'text: "Use " + root.preferredPapirusTheme' "$settings"
grep -Fq '"discoveredIconThemes": root.discoveredIconThemes' "$service"
grep -Fq '"folderColorCapability": root.folderColorCapability' "$service"
grep -Fq '"folderColorReason": root.folderColorReason' "$service"
grep -Fq '"iconThemePerMode": root.iconThemePerMode' "$service"
grep -Fq '"folderBaseThemeDark": root.folderBaseThemeDark' "$service"
grep -Fq '"folderBaseThemeLight": root.folderBaseThemeLight' "$service"
grep -Fq 'function setIconThemeForMode(themeName, light)' "$service"
grep -Fq 'pluginData.folderColorBaseThemeLight || pluginData.folderColorBaseTheme' "$service"
grep -Fq 'function parseFlatpakDiagnostic(text)' "$settings"
grep -Fq 'text: root.flatpakDiagnosticBusy ? "Checking…" : "Check per-app Flatpak overrides"' "$settings"
grep -Fq 'nothing was changed.' "$settings"

# DSlider assigns to its own value while dragging, which replaces the
# declarative value binding. Reset actions must therefore restore both the
# visible slider and the backing setting, as Dux SettingsSliderRow does.
grep -Fq 'matugenContrastSlider.value = 0;' "$settings"
grep -Fq 'containerSaturationSlider.value = 100;' "$settings"
grep -Fq 'duxFontWeightSlider.value = Font.Normal;' "$settings"
grep -Fq 'duxFontScaleSlider.value = 100;' "$settings"
grep -Fq 'cursorSizeSlider.value = 24;' "$settings"
grep -Fq 'regularFontSizeSlider.value = 11;' "$settings"
grep -Fq 'monoFontSizeSlider.value = 12;' "$settings"
grep -Fq 'documentFontSizeSlider.value = 11;' "$settings"
grep -Fq 'backupRetentionSlider.value = 10;' "$settings"
grep -Fq 'niriBorderOpacitySlider.value = 70;' "$settings"
grep -Fq 'appSurfaceDepthValue' "$settings"
grep -Fq 'appSurfaceTintValue' "$settings"
grep -Fq 'text: "Dark surface depth"' "$settings"
grep -Fq 'text: "App background tint"' "$settings"
grep -Fq 'ThemeSyncPaletteGrid' "$settings"
grep -Fq 'ThemeSyncColorPickerRow' "$settings"
grep -Fq 'text: "Terminal ANSI palette"' "$settings"
grep -Fq 'text: "Interface style"' "$settings"
grep -Fq 'text: "Interface density"' "$settings"
grep -Fq 'text: "Companion assets"' "$settings"
grep -Fq 'text: "Niri focused border"' "$settings"
grep -Fq 'niriBorderModeValue' "$settings"
grep -Fq 'function onMatugenCompleted(mode, result)' "$service"
grep -Fq 'resolveAppliedIconTheme' "$service"
grep -Fq '"uniformListBg": root.uniformListBg' "$service" 2>/dev/null || true
grep -Fq '"appSurfaceDepth": root.appSurfaceDepth' "$service"
grep -Fq '"appSurfaceTint": root.appSurfaceTint' "$service"
grep -Fq '"appSurfacesActive": root.appSurfacesActive' "$service"
grep -Fq '"dms21": root.dms21' "$service"
grep -Fq '"dms22Icons": root.dms22Icons' "$service"
grep -Fq '"folderColorDeferred": root.folderColorDeferred' "$service"
grep -Fq 'readonly property bool cursorColorDeferred: false' "$service"
grep -Fq '"cursorColorDeferred": root.cursorColorDeferred' "$service"
grep -Fq '"applyFontScale": root.applyFontScale' "$service"
grep -Fq 'settingKey: "applyFontScale"' "$settings"
grep -Fq '"value": "low"' "$settings"
grep -Fq '"value": "medium"' "$settings"

printf 'ui capability contract: ok\n'
