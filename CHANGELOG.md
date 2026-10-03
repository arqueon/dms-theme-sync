# Change history

## 0.12.6 — 2026-10-02

- Limit DMS cursor `.Xresources.backup<TIMESTAMP>` copies to the configured backup retention (default 10), independently of named snapshots. Clean at startup and every minute while the plugin runs, including with automatic theme sync disabled.
- Preserve the active resource file, symlinks, directories and manually named backups; expose cleanup results through IPC status.

## 0.12.5 — 2026-10-02

- Explain Niri border color substitution accurately: the existing `dimNiriBorder` setting uses DMS's exported dark `primary_container` highlight. Expressive palettes may remain vivid; no fixed dimming amount is guaranteed. The color-selection behavior is unchanged.
- Rename the border control to “Niri border: use DMS highlight color” and add context for Expressive and disabled Niri exports.
- Report Material specification, scheme, contrast and export flags through IPC `status`.
- Correct README template dependencies, distinguish Material specification from scheme, and document DMS 1.7 coverage and remaining integration work.

## 0.12.4

- Preserve the existing GTK animation accessibility preference during apply and restore.

## 0.12.3

- Add Standard/Expressive Material specification controls and match DMS's Expressive contrast range.
- Warn when relevant DMS color exports are disabled.

## 0.12.2

- Align the plugin's bar icon and controls with DMS theme and bar sizing.

## 0.12.1

- Expand backup coverage for managed theme and session configuration.

## 0.12.0

- Support separate light and dark icon themes and Papirus overlay bases.

Earlier changes remain available in the Git history.
