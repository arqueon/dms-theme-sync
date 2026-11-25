# Zotero Dux Theme (`zotero-dux-theme`)

Download the latest `dux-theme@arqueon.org.xpi` release from
[`arqueon/zotero-dux-theme` releases](https://github.com/arqueon/zotero-dux-theme/releases)
(`GPL-3.0-or-later`). Prebuilt `.xpi` binaries are distributed there rather than
bundled inside `dms-theme-sync`.

## Install in Zotero 10

1. Download `dux-theme@arqueon.org.xpi` from the
   [GitHub releases page](https://github.com/arqueon/zotero-dux-theme/releases).
2. Open Zotero → **Tools → Add-ons** → gear icon → **Install Add-on From File…**
   and select the downloaded `.xpi`.

## Live reload behavior

- `scripts/reload-application-theme.sh` checks whether `dux-theme@arqueon.org*`
  is installed in a local Zotero profile (`~/.zotero/zotero/*/extensions/`,
  `~/.var/app/org.zotero.Zotero/.zotero/zotero/*/extensions/`, or
  `~/Zotero/extensions/`). Only when present does it send
  `POST http://127.0.0.1:23119/dux-theme/reload` (`-H 'Content-Type: application/json' -d '{}'`).
- As a fallback when DMS updates colors outside `dms-theme-sync`, the add-on
  also polls `IOUtils.stat()` every `1200 ms` on
  `~/.cache/DankMaterialShell/dms-colors.json` (fallback `~/.cache/dms/dms-colors.json`),
  `~/.config/dms/plugin_settings.json`, and `~/.cache/DankMaterialShell/dms-typography.json`.
