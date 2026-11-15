# Zotero Dux Theme (`zotero-dux-theme`)

Bundled copy of `dux-theme@arqueon.org.xpi` from
[`arqueon/zotero-dux-theme`](https://github.com/arqueon/zotero-dux-theme)
(`GPL-3.0-or-later`).

## Install in Zotero 10

1. Open Zotero → **Tools → Add-ons** → gear icon → **Install Add-on From File…**.
2. Select `dux-theme@arqueon.org.xpi` (or download newer builds from the
   [GitHub releases](https://github.com/arqueon/zotero-dux-theme/releases)).

## Live reload behavior

- `scripts/reload-application-theme.sh` sends `POST http://127.0.0.1:23119/dux-theme/reload`
  with `-H 'Content-Type: application/json' -d '{}'` on every apply/restore so
  running Zotero windows and built-in PDF/EPUB/snapshot readers update
  immediately.
- As a fallback when DMS updates colors outside `dms-theme-sync`, the plugin
  also polls `IOUtils.stat()` every `1200 ms` on
  `~/.cache/DankMaterialShell/dms-colors.json` (fallback `~/.cache/dms/dms-colors.json`),
  `~/.config/dms/plugin_settings.json`, and `~/.cache/DankMaterialShell/dms-typography.json`.
