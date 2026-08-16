#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
settings="$ROOT/ThemeSyncSettings.qml"
service="$ROOT/ThemeSyncService.qml"

grep -Fq 'names = ["blue", "purple", "green", "orange", "red", "cyan", "pink", "amber", "coral", "monochrome"]' "$settings"
grep -Fq 'function selectIconTheme(value)' "$settings"
grep -Fq 'id: iconThemeVerifyTimer' "$settings"
grep -Fq 'DMS kept ' "$settings"
grep -Fq 'text: "Use " + root.preferredPapirusTheme' "$settings"
grep -Fq '"discoveredIconThemes": root.discoveredIconThemes' "$service"
grep -Fq '"folderColorCapability": root.folderColorCapability' "$service"
grep -Fq '"folderColorReason": root.folderColorReason' "$service"
grep -Fq 'function parseFlatpakDiagnostic(text)' "$settings"
grep -Fq 'text: root.flatpakDiagnosticBusy ? "Checking…" : "Check per-app Flatpak overrides"' "$settings"
grep -Fq 'nothing was changed.' "$settings"

# DankSlider assigns to its own value while dragging, which replaces the
# declarative value binding. Reset actions must therefore restore both the
# visible slider and the backing setting, as DMS SettingsSliderRow does.
grep -Fq 'matugenContrastSlider.value = 0;' "$settings"
grep -Fq 'cursorSizeSlider.value = 24;' "$settings"
grep -Fq 'regularFontSizeSlider.value = 11;' "$settings"
grep -Fq 'monoFontSizeSlider.value = 12;' "$settings"
grep -Fq 'documentFontSizeSlider.value = 11;' "$settings"
grep -Fq 'backupRetentionSlider.value = 10;' "$settings"

printf 'ui capability contract: ok\n'
