import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Modules.Plugins
import qs.Services

PluginComponent {
    id: root

    property bool applying: false
    property bool pendingApply: false
    property bool manualRequest: false
    property string currentAction: "idle"
    property string appliedSignature: ""
    property string runningSignature: ""
    property bool ready: false
    property int lastExitCode: -1
    property string lastOutput: "Not applied yet"
    readonly property bool autoSync: pluginData.autoSync !== undefined ? pluginData.autoSync : true
    readonly property string regularFont: SettingsData.fontFamily || "sans-serif"
    readonly property string monoFont: SettingsData.monoFontFamily || "monospace"
    readonly property string documentFont: pluginData.documentFontFamily || regularFont
    readonly property int regularSize: Number(pluginData.regularFontSize || 11)
    readonly property int monoSize: Number(pluginData.monoFontSize || 12)
    readonly property int documentSize: Number(pluginData.documentFontSize || 11)
    readonly property string iconTheme: SettingsData.iconTheme || "System Default"
    readonly property bool iconThemePerMode: typeof SettingsData.iconThemePerMode !== "undefined" ? SettingsData.iconThemePerMode : false
    readonly property string iconThemeDark: typeof SettingsData.iconThemeDark !== "undefined" ? SettingsData.iconThemeDark : iconTheme
    readonly property string iconThemeLight: typeof SettingsData.iconThemeLight !== "undefined" ? SettingsData.iconThemeLight : iconTheme
    property var discoveredIconThemes: []
    readonly property string cursorTheme: (SettingsData.cursorSettings && SettingsData.cursorSettings.theme) || "System Default"
    readonly property int cursorSize: Number((SettingsData.cursorSettings && SettingsData.cursorSettings.size) || 24)
    readonly property string colorMode: Theme.isLightMode ? "light" : "dark"
    readonly property bool lightIconMode: colorMode === "light"
    readonly property string gtkThemeLight: pluginData.gtkThemeLight || "auto"
    readonly property string gtkThemeDark: pluginData.gtkThemeDark || "auto"
    readonly property string qtPlatformTheme: pluginData.qtPlatformTheme || "preserve"
    readonly property string qtStyle: pluginData.qtStyle || "Fusion"
    // "manual" keeps the two knobs above authoritative; every other mode hands
    // the helper a coherent route (native/Kvantum pair, generated Kvantum,
    // kcolorscheme, gtk3, auto).
    readonly property string qtSyncMode: pluginData.qtSyncMode || "manual"
    readonly property bool applyMatugenColors: pluginData.applyMatugenColors !== undefined ? pluginData.applyMatugenColors : true
    readonly property bool syncKde: pluginData.syncKde !== undefined ? pluginData.syncKde : true
    readonly property bool syncXsettingsd: pluginData.syncXsettingsd !== undefined ? pluginData.syncXsettingsd : true
    readonly property bool syncTerminalFonts: pluginData.syncTerminalFonts !== undefined ? pluginData.syncTerminalFonts : false
    // Folder recolouring only exists for Papirus, whose ~80 colour variants the
    // helper maps onto the Matugen accent. Any other icon theme: leave it alone.
    readonly property string overlaySuffix: "-DankFolders"
    // Once the overlay is applied it *is* SettingsData.iconTheme, so the base to
    // derive from has to be remembered rather than inferred.
    readonly property string savedFolderBaseTheme: lightIconMode ? (pluginData.folderColorBaseThemeLight || pluginData.folderColorBaseTheme || "") : (pluginData.folderColorBaseThemeDark || pluginData.folderColorBaseTheme || "")
    readonly property string folderBaseTheme: iconTheme.endsWith(overlaySuffix) ? (savedFolderBaseTheme || iconTheme.slice(0, -overlaySuffix.length)) : iconTheme
    readonly property string folderBaseThemeDark: iconThemeDark.endsWith(overlaySuffix) ? (pluginData.folderColorBaseThemeDark || iconThemeDark.slice(0, -overlaySuffix.length)) : iconThemeDark
    readonly property string folderBaseThemeLight: iconThemeLight.endsWith(overlaySuffix) ? (pluginData.folderColorBaseThemeLight || iconThemeLight.slice(0, -overlaySuffix.length)) : iconThemeLight
    readonly property bool iconThemeSupportsFolderColor: folderBaseTheme.indexOf("Papirus") === 0
    readonly property bool papirusInstalled: discoveredIconThemes.some(function(name) {
        return name.indexOf("Papirus") === 0;
    })
    readonly property string folderColorCapability: iconThemeSupportsFolderColor ? "ready" : "blocked"
    readonly property string folderColorReason: iconThemeSupportsFolderColor ? "Papirus selected" : (papirusInstalled ? "Papirus installed but DMS uses " + iconTheme : "Papirus not installed")
    readonly property bool syncFolderColorRequested: pluginData.syncFolderColor !== undefined ? pluginData.syncFolderColor : false
    readonly property bool syncFolderColor: syncFolderColorRequested && iconThemeSupportsFolderColor
    readonly property string folderOverlayTheme: folderBaseTheme + overlaySuffix
    // Cursor accent variants only exist for material-bibata-cursor's
    // Bibata-Material-* packs; the helper maps the Matugen accent onto the
    // nearest installed one. As with the folder overlay, once a variant is
    // applied it *is* SettingsData's cursor theme, so the theme to fall back
    // to has to be remembered rather than inferred.
    readonly property string materialCursorPrefix: "Bibata-Material-"
    readonly property string cursorBaseTheme: cursorTheme.indexOf(materialCursorPrefix) === 0 ? (pluginData.cursorColorBaseTheme || "System Default") : cursorTheme
    readonly property bool syncCursorColor: pluginData.syncCursorColor !== undefined ? pluginData.syncCursorColor : false
    // Reuses the exported dark primary_container for the focused border/focus
    // ring, through the plugin's own Niri include. Expressive palettes do not
    // guarantee a darker or muted result. The helper writes or removes the
    // block, and Niri reloads its configuration without a DMS setting change.
    readonly property bool dimNiriBorder: pluginData.dimNiriBorder !== undefined ? pluginData.dimNiriBorder : false
    readonly property bool syncFlatpak: pluginData.syncFlatpak !== undefined ? pluginData.syncFlatpak : false
    // Only the user's toggle. Whether Kvantum actually applies is the helper's
    // call: it resolves an "auto" style first, and gating here on
    // qtStyle === "kvantum" made auto skip the render — the style landed in
    // qt6ct.conf but the theme was never rendered or selected, so Qt painted
    // whatever kvantum.kvconfig last pointed at (Celestial, with bold text).
    readonly property bool syncKvantum: pluginData.syncKvantum !== undefined ? pluginData.syncKvantum : false
    // No file-manager exposes a toggle for the alternating list stripes; they
    // follow QPalette::AlternateBase, whose source depends on the Qt route. The
    // helper equalises it on every surface the plugin owns (derived .colors,
    // DankMatugen render, pair-theme shadow copy) and reports the rest.
    readonly property bool uniformListBg: pluginData.uniformListBg !== undefined ? pluginData.uniformListBg : false

    // The Kvantum templates want 12 Material roles. Theme exposes most of them
    // as properties; the rest live on currentThemeData, and the fallbacks below
    // mirror what DMS itself does in Theme.buildMatugenColorsFromTheme().
    function hex6(c) {
        const s = String(c);                 // QML colors serialise as #aarrggbb
        return s.length === 9 ? "#" + s.slice(3) : s;
    }
    readonly property string kvantumColors: {
        const td = Theme.currentThemeData || {};
        const pick = (...cs) => hex6(cs.find(c => c) || Theme.surface);
        const roles = {
            primary: Theme.primary,
            // surfaceText, not the onSurface alias: in the running shell that
            // alias can sit frozen at opaque black while surfaceText is correct
            // (seen live: onSurface=#000000, surfaceText=#f9dcd5). surfaceText
            // is what DMS paints its own bar text with, so it cannot drift.
            on_surface: pick(td.surfaceText, Theme.surfaceText),
            surface: Theme.surface,
            surface_variant: Theme.surfaceVariant,
            surface_container_low: Theme.surfaceContainerLow,
            surface_container_highest: Theme.surfaceContainerHighest,
            surface_bright: pick(td.surfaceBright, Theme.surfaceContainerHighest),
            surface_dim: pick(td.surfaceDim, Theme.background),
            inverse_on_surface: pick(td.inverseOnSurface, Theme.background),
            inverse_primary: pick(td.inversePrimary, Theme.primary),
            primary_fixed_dim: pick(td.primaryFixedDim, Theme.primary),
            tertiary_fixed_dim: pick(td.tertiaryFixedDim, Theme.tertiary, Theme.secondary)
        };
        return Object.keys(roles).map(k => k + "=" + hex6(roles[k])).join(";");
    }
    readonly property bool backupEnabled: pluginData.backupEnabled !== undefined ? pluginData.backupEnabled : true
    readonly property int backupRetention: Number(pluginData.backupRetention || 10)

    Process {
        running: true
        command: ["sh", "-c", "for base in \"$HOME/.icons\" \"$HOME/.local/share/icons\" /usr/local/share/icons /usr/share/icons; do [ -d \"$base\" ] || continue; for dir in \"$base\"/*; do [ -f \"$dir/index.theme\" ] || continue; grep -q '^Directories=' \"$dir/index.theme\" || continue; basename \"$dir\"; done; done | grep -vxE 'default|hicolor|locolor' | LC_ALL=C sort -fu"]

        stdout: StdioCollector {
            onStreamFinished: root.discoveredIconThemes = (text || "").split("\n").map(function(name) {
                return name.trim();
            }).filter(function(name) {
                return name !== "";
            })
        }
    }
    readonly property string configSignature: JSON.stringify([regularFont, monoFont, documentFont, regularSize, monoSize, documentSize, iconTheme, iconThemeDark, iconThemeLight, iconThemePerMode, cursorTheme, cursorSize, colorMode, gtkThemeLight, gtkThemeDark, qtPlatformTheme, qtStyle, qtSyncMode, applyMatugenColors, syncKde, syncXsettingsd, syncTerminalFonts, syncFolderColorRequested, syncCursorColor, dimNiriBorder, syncFlatpak, syncKvantum, uniformListBg, kvantumColors])

    // The helper only builds the overlay; it never decides the icon theme. DMS
    // does, through setIconTheme(), which is also what marks lastAppliedIconTheme.
    // Writing the overlay straight into gsettings would look like an outside
    // change to DMS's own checkIconThemeDrift() and get the theme unmanaged.
    function setIconThemeForMode(themeName, light) {
        if (typeof SettingsData.setIconThemeForMode === "function")
            SettingsData.setIconThemeForMode(themeName, light);
        else if (light === lightIconMode)
            SettingsData.setIconTheme(themeName);
    }

    function reconcileIconTheme(output) {
        if (syncFolderColorRequested) {
            if (!syncFolderColor)
                return;
            if (output.indexOf("folder-color: accent") === -1)
                return;
            if (SettingsData.iconTheme !== folderOverlayTheme) {
                if (pluginService)
                    pluginService.savePluginData(pluginId, lightIconMode ? "folderColorBaseThemeLight" : "folderColorBaseThemeDark", folderBaseTheme);
                setIconThemeForMode(folderOverlayTheme, lightIconMode);
            }
            return;
        }

        if (iconThemeDark.endsWith(overlaySuffix))
            setIconThemeForMode(folderBaseThemeDark, false);
        if (iconThemeLight.endsWith(overlaySuffix))
            setIconThemeForMode(folderBaseThemeLight, true);
        if (pluginService) {
            pluginService.savePluginData(pluginId, "folderColorBaseThemeDark", "");
            pluginService.savePluginData(pluginId, "folderColorBaseThemeLight", "");
            pluginService.savePluginData(pluginId, "folderColorBaseTheme", "");
        }
    }

    // Same contract for the cursor: the helper chooses a Bibata-Material-*
    // variant, DMS applies it through setCursorTheme() (which also updates
    // XResources and the compositor cursor). The saved base is cleared after a
    // restore so a variant the user later picks by hand is never overridden.
    function reconcileCursorTheme(output) {
        if (syncCursorColor) {
            const match = output.match(/cursor-color: accent #[0-9a-fA-F]{6} -> (\S+)/);
            if (!match)
                return;
            const variant = match[1];
            if (cursorTheme === variant)
                return;
            if (pluginService)
                pluginService.savePluginData(pluginId, "cursorColorBaseTheme", cursorBaseTheme);
            SettingsData.setCursorTheme(variant);
        } else if (cursorTheme.indexOf(materialCursorPrefix) === 0 && pluginData.cursorColorBaseTheme) {
            const base = pluginData.cursorColorBaseTheme;
            if (pluginService)
                pluginService.savePluginData(pluginId, "cursorColorBaseTheme", "");
            SettingsData.setCursorTheme(base);
        }
    }

    function helperPath() {
        return Paths.strip(Qt.resolvedUrl("scripts/apply-theme.sh").toString());
    }

    function snapshotHelperPath() {
        return Paths.strip(Qt.resolvedUrl("scripts/theme-snapshot.sh").toString());
    }

    function themeReloadHelperPath() {
        return Paths.strip(Qt.resolvedUrl("scripts/reload-application-theme.sh").toString());
    }

    property string xresourcesBackupCleanup: "Not run yet"
    property int xresourcesBackupCleanupExitCode: -1

    function pruneXresourcesBackups() {
        if (xresourcesCleanupProcess.running)
            return;
        xresourcesCleanupProcess.command = [Paths.strip(Qt.resolvedUrl("scripts/prune-xresources-backups.sh").toString()), "--keep", String(backupRetention)];
        xresourcesCleanupProcess.running = true;
    }

    // Cursor updates run asynchronously inside DMS. Periodic maintenance also
    // catches direct DMS changes and runs when autoSync or snapshots are off.
    Timer {
        interval: 5000
        running: true
        repeat: false
        onTriggered: root.pruneXresourcesBackups()
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: root.pruneXresourcesBackups()
    }

    Process {
        id: xresourcesCleanupProcess
        onExited: function(exitCode) {
            root.xresourcesBackupCleanupExitCode = exitCode;
            root.xresourcesBackupCleanup = ((xresourcesCleanupOutput.text || "") + (xresourcesCleanupError.text || "")).trim();
            if (exitCode !== 0)
                console.warn("Xresources backup cleanup:", root.xresourcesBackupCleanup);
        }
        stdout: StdioCollector { id: xresourcesCleanupOutput }
        stderr: StdioCollector { id: xresourcesCleanupError }
    }

    function buildCommand(dryRun) {
        const args = [helperPath(), "--font", regularFont, "--mono-font", monoFont, "--document-font", documentFont, "--font-size", String(regularSize), "--mono-size", String(monoSize), "--document-size", String(documentSize), "--icon-theme", iconTheme, "--cursor-theme", cursorTheme, "--cursor-size", String(cursorSize), "--mode", colorMode, "--gtk-theme-light", gtkThemeLight, "--gtk-theme-dark", gtkThemeDark, "--qt-platform-theme", qtPlatformTheme, "--qt-style", qtStyle, "--qt-sync-mode", qtSyncMode, "--compositor", CompositorService.compositor || "", "--apply-matugen-colors", applyMatugenColors ? "true" : "false", "--sync-kde", syncKde ? "true" : "false", "--sync-xsettingsd", syncXsettingsd ? "true" : "false", "--sync-terminal-fonts", syncTerminalFonts ? "true" : "false", "--sync-folder-color", syncFolderColor ? "true" : "false", "--folder-base-theme", folderBaseTheme, "--sync-cursor-color", syncCursorColor ? "true" : "false", "--dim-niri-border", dimNiriBorder ? "true" : "false", "--sync-flatpak", syncFlatpak ? "true" : "false", "--sync-kvantum", syncKvantum ? "true" : "false", "--uniform-list-bg", uniformListBg ? "true" : "false", "--kvantum-colors", kvantumColors, "--backup-enabled", backupEnabled ? "true" : "false", "--backup-retention", String(backupRetention)];
        if (dryRun)
            args.push("--dry-run");

        return args;
    }

    // DMS regenerates its Matugen templates (dank-colors.css, DankMatugen.colors)
    // for the dynamic theme and for stock themes — but not for custom/downloaded
    // ones: pick a registry theme and the bar goes red while GTK keeps painting
    // the previous palette, because the export never ran. Ask DMS to export
    // through its own machinery, exactly the call its stock-theme path makes.
    // No matugen loop: for custom themes Theme.* reads theme.json, not the
    // generated files, so the regeneration cannot re-trigger this.
    function maybeExportDmsColors() {
        if (Theme.currentTheme !== "custom")
            return ;

        if (!Theme.currentThemeData || typeof Theme.setDesiredTheme !== "function" || typeof Theme.buildMatugenColorsFromTheme !== "function")
            return ;

        const td = Theme.currentThemeData;
        const stockColors = Theme.buildMatugenColorsFromTheme(td, td);
        Theme.setDesiredTheme("hex", hex6(Theme.primary), Theme.isLightMode, SettingsData.iconTheme || "System Default", td.matugen_type || "scheme-tonal-spot", stockColors);
    }

    function requestApply(showResult) {
        if (!showResult && configSignature === appliedSignature)
            return ;

        maybeExportDmsColors();
        manualRequest = showResult;
        if (applying) {
            pendingApply = true;
            return ;
        }
        applyDebounce.restart();
    }

    function runApply() {
        if (applying) {
            pendingApply = true;
            return ;
        }
        applying = true;
        currentAction = "apply";
        runningSignature = configSignature;
        applyProcess.command = buildCommand(false);
        applyProcess.running = true;
    }

    // extra: for "backup", an optional name — a named snapshot is pinned and
    // retention never rotates it away. For "name", the new name for `snapshot`
    // (empty unpins, returning it to the rotation).
    function runSnapshotAction(action, snapshot, extra) {
        if (applying)
            return false;

        if (action === "restore") {
            if (pluginService && pluginService.savePluginData)
                pluginService.savePluginData(pluginId, "autoSync", false);

            applyProcess.command = [snapshotHelperPath(), "restore", "--snapshot", snapshot || "latest"];
        } else if (action === "name") {
            applyProcess.command = [snapshotHelperPath(), "name", "--snapshot", snapshot, "--name", extra || ""];
        } else {
            applyProcess.command = [snapshotHelperPath(), "backup", "--retention", String(backupRetention), "--label", "manual"];
            if (extra)
                applyProcess.command = applyProcess.command.concat(["--name", extra]);
        }
        currentAction = action;
        manualRequest = true;
        applying = true;
        applyProcess.running = true;
        return true;
    }

    function openConfiguration() {
        configDialog.openCentered();
    }

    pluginId: "dmsThemeSync"
    onConfigSignatureChanged: {
        if (autoSync && ready)
            requestApply(false);

    }
    onAutoSyncChanged: {
        if (autoSync)
            requestApply(false);

    }
    Component.onCompleted: {
        if (autoSync)
            startupTimer.start();

    }

    Timer {
        id: startupTimer

        interval: 4500
        repeat: false
        onTriggered: {
            root.ready = true;
            root.requestApply(false);
        }
    }

    Timer {
        id: applyDebounce

        interval: 700
        repeat: false
        onTriggered: root.runApply()
    }

    // KDE and Qt applications keep process-local appearance state. After a
    // successful apply (or restore), broadcast KDE's global and icon-group
    // notifications and nudge qt5ct/qt6ct's ThemeChange watchers. A short
    // delay lets SettingsData finish its writes.
    Timer {
        id: applicationThemeReloadTimer

        interval: 250
        repeat: false
        onTriggered: Quickshell.execDetached([root.themeReloadHelperPath()])
    }

    Process {
        id: applyProcess

        running: false
        onExited: function(exitCode) {
            root.lastExitCode = exitCode;
            const output = ((stdoutCollector.text || "") + (stderrCollector.text || "")).trim();
            const qtStyleRestartRequired = output.indexOf("QT_RESTART_REQUIRED:style:") !== -1;
            root.lastOutput = output || (exitCode === 0 ? "Theme synchronized" : "Theme synchronization failed");
            root.applying = false;
            if (exitCode === 0 && root.currentAction === "apply") {
                root.appliedSignature = root.runningSignature;
                root.reconcileIconTheme(output);
                root.reconcileCursorTheme(output);
                applicationThemeReloadTimer.restart();
            } else if (exitCode === 0 && root.currentAction === "restore") {
                applicationThemeReloadTimer.restart();
            }

            if (root.manualRequest) {
                if (exitCode === 0) {
                    if (root.currentAction === "backup")
                        ToastService.showInfo("DMS Theme Sync", "Backup created");
                    else if (root.currentAction === "restore")
                        ToastService.showInfo("DMS Theme Sync", "Backup restored; automatic sync disabled");
                    else if (qtStyleRestartRequired)
                        ToastService.showInfo("DMS Theme Sync", "Themes synchronized; restart open Qt applications to finish the widget-style change");
                    else
                        ToastService.showInfo("DMS Theme Sync", "Application themes synchronized");
                } else {
                    ToastService.showError("DMS Theme Sync", root.lastOutput);
                }
                root.manualRequest = false;
            }
            root.currentAction = "idle";
            if (root.pendingApply) {
                root.pendingApply = false;
                applyDebounce.restart();
            }
        }

        stdout: StdioCollector {
            id: stdoutCollector
        }

        stderr: StdioCollector {
            id: stderrCollector
        }

    }

    ThemeSyncDialog {
        id: configDialog

        parentWidget: root
    }

    // DMS re-creates every daemon plugin each time another one finishes
    // loading during the startup scan, and Quickshell 0.3.0 keeps the IPC
    // registration of the destroyed generations — the next call to a stale
    // entry segfaults the whole shell (DMS #1956). Registering only after the
    // scan has settled keeps the short-lived generations out of the registry.
    property bool ipcSettled: false

    Timer {
        interval: 8000
        running: true
        onTriggered: root.ipcSettled = true
    }

    IpcHandler {
        enabled: root.ipcSettled

        function apply() : string {
            root.requestApply(true);
            return root.applying ? "queued" : "scheduled";
        }

        function status() : string {
            return JSON.stringify({
                "applying": root.applying,
                "autoSync": root.autoSync,
                "backupEnabled": root.backupEnabled,
                "backupRetention": root.backupRetention,
                "xresourcesBackupCleanup": root.xresourcesBackupCleanup,
                "xresourcesBackupCleanupExitCode": root.xresourcesBackupCleanupExitCode,
                "currentAction": root.currentAction,
                "lastExitCode": root.lastExitCode,
                "mode": root.colorMode,
                "font": root.regularFont,
                "monoFont": root.monoFont,
                "iconTheme": root.iconTheme,
                "iconThemePerMode": root.iconThemePerMode,
                "iconThemeDark": root.iconThemeDark,
                "iconThemeLight": root.iconThemeLight,
                "discoveredIconThemes": root.discoveredIconThemes,
                "folderBaseTheme": root.folderBaseTheme,
                "folderBaseThemeDark": root.folderBaseThemeDark,
                "folderBaseThemeLight": root.folderBaseThemeLight,
                "folderColorCapability": root.folderColorCapability,
                "folderColorReason": root.folderColorReason,
                "cursorTheme": root.cursorTheme,
                "cursorSize": root.cursorSize,
                "dimNiriBorder": root.dimNiriBorder,
                "materialSpec": typeof SettingsData.matugenSpec !== "undefined" ? SettingsData.matugenSpec : null,
                "matugenScheme": SettingsData.matugenScheme,
                "matugenContrast": SettingsData.matugenContrast,
                "dmsTemplatesEnabled": typeof SettingsData.runDmsMatugenTemplates !== "undefined" ? SettingsData.runDmsMatugenTemplates : null,
                "gtkExportEnabled": typeof SettingsData.matugenTemplateGtk !== "undefined" ? SettingsData.matugenTemplateGtk : null,
                "kColorSchemeExportEnabled": typeof SettingsData.matugenTemplateKcolorscheme !== "undefined" ? SettingsData.matugenTemplateKcolorscheme : null,
                "niriExportEnabled": typeof SettingsData.matugenTemplateNiri !== "undefined" ? SettingsData.matugenTemplateNiri : null,
                "gtkTheme": root.colorMode === "light" ? root.gtkThemeLight : root.gtkThemeDark,
                "qtPlatformTheme": root.qtPlatformTheme,
                "qtSyncMode": root.qtSyncMode,
                "applyMatugenColors": root.applyMatugenColors,
                "uniformListBg": root.uniformListBg,
                "lastOutput": root.lastOutput
            }, null, 2);
        }

        function backup() : string {
            return root.runSnapshotAction("backup", "", "") ? "scheduled" : "busy";
        }

        // A named backup is pinned: retention neither counts nor deletes it.
        function backupNamed(name: string) : string {
            return root.runSnapshotAction("backup", "", name) ? "scheduled" : "busy";
        }

        // Pin (or rename) an existing snapshot; an empty name unpins it.
        function nameSnapshot(snapshot: string, name: string) : string {
            return root.runSnapshotAction("name", snapshot, name) ? "scheduled" : "busy";
        }

        function restoreLatest() : string {
            return root.runSnapshotAction("restore", "latest") ? "scheduled; automatic sync disabled" : "busy";
        }

        function restore(snapshot: string) : string {
            return root.runSnapshotAction("restore", snapshot) ? "scheduled; automatic sync disabled" : "busy";
        }

        function configure() : string {
            Qt.callLater(root.openConfiguration);
            return "scheduled";
        }

        target: "dmsThemeSync"
    }

}
