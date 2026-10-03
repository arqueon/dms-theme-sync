#!/usr/bin/env bash
set -euo pipefail

# DMS updateXResources() creates these before a cursor change. They are
# separate from Theme Sync's named/pinned snapshots. Never follow symlinks.
target_dir=${HOME:?}
keep=10
dry_run=false
while (( $# )); do
    case "$1" in
        --directory) target_dir=${2:?}; shift 2 ;;
        --keep) keep=${2:?}; shift 2 ;;
        --dry-run) dry_run=true; shift ;;
        *) printf 'Unknown option: %s\n' "$1" >&2; exit 2 ;;
    esac
done
[[ $keep =~ ^([1-9]|[12][0-9]|30)$ ]] || {
    printf 'Retention must be an integer from 1 to 30\n' >&2; exit 2;
}
[[ -d $target_dir ]] || { printf 'Backup directory does not exist\n' >&2; exit 1; }

# Only exact epoch-suffixed regular files directly in the chosen directory.
# Sort by the timestamp in the name: copies can have misleading mtimes.
timestamps=$(find "$target_dir" -regextype posix-extended -mindepth 1 -maxdepth 1 -type f \
    -regex '.*/\.Xresources\.backup[0-9]{10,}' -printf '%f\n' \
    | sed -nE 's/^\.Xresources\.backup([0-9]{10,})$/\1/p' | LC_ALL=C sort -rn)
pruned=0
retained=0
while IFS= read -r stamp; do
    [[ -n $stamp ]] || continue
    file="$target_dir/.Xresources.backup$stamp"
    [[ -f $file && ! -L $file ]] || continue
    if (( retained < keep )); then
        retained=$((retained + 1))
    else
        if ! $dry_run; then
            rm -- "$file"
        fi
        pruned=$((pruned + 1))
    fi
done <<< "$timestamps"
if $dry_run; then
    printf 'xresources-backups: would-remove=%s kept=%s limit=%s\n' "$pruned" "$retained" "$keep"
else
    printf 'xresources-backups: removed=%s kept=%s limit=%s\n' "$pruned" "$retained" "$keep"
fi
