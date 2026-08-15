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

printf 'ui capability contract: ok\n'
