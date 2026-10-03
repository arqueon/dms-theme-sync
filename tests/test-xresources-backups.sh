#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf -- "$TMP"' EXIT
dir="$TMP/home with spaces"
mkdir -p "$dir/.Xresources.backup1999999999" "$dir/nested"
printf 'current resource\n' > "$dir/.Xresources"
printf 'named copy\n' > "$dir/.Xresources.backup-manual"
printf 'short suffix\n' > "$dir/.Xresources.backup123"
printf 'other suffix\n' > "$dir/.Xresources.backup1786777663.old"
printf 'malformed name\n' > "$dir/"$'.Xresources.backup\n.Xresources.backup1786777664'
printf 'nested copy\n' > "$dir/nested/.Xresources.backup1000000000"
printf 'target\n' > "$TMP/target"
ln -s "$TMP/target" "$dir/.Xresources.backup1999999998"
for stamp in 1786777661 1786777662 1786777663 1786777664; do
    printf '%s\n' "$stamp" > "$dir/.Xresources.backup$stamp"
done
# A newer mtime on the oldest name must not change which backups survive.
touch -d '2030-01-01' "$dir/.Xresources.backup1786777661"
helper="$ROOT/scripts/prune-xresources-backups.sh"
out=$("$helper" --directory "$dir" --keep 2 --dry-run)
[[ $out == *'would-remove=2 kept=2 limit=2' ]]
[[ -f $dir/.Xresources.backup1786777661 ]]
for invalid in 0 -1 31 2.5 garbage 02; do
    if "$helper" --directory "$dir" --keep "$invalid" >/dev/null 2>&1; then
        printf 'Invalid retention accepted: %s\n' "$invalid" >&2; exit 1
    fi
done
[[ -f $dir/.Xresources.backup1786777661 ]]
out=$("$helper" --directory "$dir" --keep 2)
[[ $out == *'removed=2 kept=2 limit=2' ]]
[[ ! -e $dir/.Xresources.backup1786777661 && ! -e $dir/.Xresources.backup1786777662 ]]
[[ -f $dir/.Xresources.backup1786777663 && -f $dir/.Xresources.backup1786777664 ]]
[[ -L $dir/.Xresources.backup1999999998 && $(cat "$TMP/target") == target ]]
[[ -d $dir/.Xresources.backup1999999999 ]]
[[ $(cat "$dir/.Xresources") == 'current resource' ]]
[[ -f $dir/.Xresources.backup-manual && -f $dir/.Xresources.backup123 ]]
[[ -f $dir/.Xresources.backup1786777663.old && -f $dir/nested/.Xresources.backup1000000000 ]]
[[ -f "$dir/"$'.Xresources.backup\n.Xresources.backup1786777664' ]]
out=$("$helper" --directory "$dir" --keep 2)
[[ $out == *'removed=0 kept=2 limit=2' ]]
# A later DMS cursor change is rotated on the next maintenance pass.
printf 'new\n' > "$dir/.Xresources.backup1786777665"
"$helper" --directory "$dir" --keep 2 >/dev/null
[[ ! -e $dir/.Xresources.backup1786777663 && -f $dir/.Xresources.backup1786777665 ]]
mkdir "$TMP/empty"
[[ $("$helper" --directory "$TMP/empty") == *'removed=0 kept=0 limit=10' ]]
printf 'xresources backup retention tests: ok\n'
