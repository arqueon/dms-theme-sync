#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
fake_bin=$(mktemp -d)
trap 'rm -rf -- "$fake_bin"' EXIT

cat >"$fake_bin/flatpak" <<'SH'
#!/usr/bin/env bash
if [[ $1 == list ]]; then
    printf '%s\n' org.example.Clean org.example.Legacy
elif [[ $1 == override && $2 == --user && $3 == --show ]]; then
    if [[ ${4:-} == org.example.Legacy ]]; then
        printf '%s\n' '[Environment]' 'GTK_THEME=Legacy-dark'
    else
        printf '%s\n' '[Environment]' 'ICON_THEME=Papirus'
    fi
fi
SH
chmod +x "$fake_bin/flatpak"

output=$(PATH="$fake_bin:$PATH" "$root/scripts/check-flatpak-overrides.sh")
grep -Fqx 'STATUS=issues' <<<"$output"
grep -Fqx 'COUNT=1' <<<"$output"
grep -Fqx $'APP=org.example.Legacy\tLegacy-dark' <<<"$output"

printf '%s\n' 'flatpak override diagnostic tests: ok'
