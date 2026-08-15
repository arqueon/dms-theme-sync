#!/usr/bin/env bash
# Report per-application GTK_THEME overrides without changing Flatpak state.
set -euo pipefail

if ! command -v flatpak >/dev/null 2>&1; then
    printf '%s\n' 'STATUS=unavailable' 'COUNT=0'
    exit 0
fi

mapfile -t apps < <(flatpak list --app --columns=application 2>/dev/null \
    | sed '/^[[:space:]]*$/d' | LC_ALL=C sort -u) || {
    printf '%s\n' 'STATUS=error' 'COUNT=0'
    exit 0
}

issues=()
for app_id in "${apps[@]}"; do
    shown=$(flatpak override --user --show "$app_id" 2>/dev/null || true)
    value=$(awk -F= '$1 == "GTK_THEME" { sub(/^[^=]*=/, ""); print; exit }' <<<"$shown")
    if [[ -n $value ]]; then
        value=${value//$'\t'/ }
        value=${value//$'\n'/ }
        issues+=("$app_id"$'\t'"$value")
    fi
done

if ((${#issues[@]} == 0)); then
    printf '%s\n' 'STATUS=clean' 'COUNT=0'
    exit 0
fi

printf '%s\n' 'STATUS=issues' "COUNT=${#issues[@]}"
printf 'APP=%s\n' "${issues[@]}"
