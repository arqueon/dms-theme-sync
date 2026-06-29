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
    readonly property string cursorTheme: (SettingsData.cursorSettings && SettingsData.cursorSettings.theme) || "System Default"
    readonly property int cursorSize: Number((SettingsData.cursorSettings && SettingsData.cursorSettings.size) || 24)
    readonly property string colorMode: Theme.isLightMode ? "light" : "dark"
    readonly property string gtkThemeLight: pluginData.gtkThemeLight || "auto"
    readonly property string gtkThemeDark: pluginData.gtkThemeDark || "auto"
    readonly property string qtPlatformTheme: pluginData.qtPlatformTheme || "preserve"
    readonly property string qtStyle: pluginData.qtStyle || "Fusion"
    readonly property bool applyMatugenColors: pluginData.applyMatugenColors !== undefined ? pluginData.applyMatugenColors : true
    readonly property bool syncKde: pluginData.syncKde !== undefined ? pluginData.syncKde : true
    readonly property bool syncXsettingsd: pluginData.syncXsettingsd !== undefined ? pluginData.syncXsettingsd : true
    readonly property bool backupEnabled: pluginData.backupEnabled !== undefined ? pluginData.backupEnabled : true
    readonly property int backupRetention: Number(pluginData.backupRetention || 10)
    readonly property string configSignature: JSON.stringify([regularFont, monoFont, documentFont, regularSize, monoSize, documentSize, iconTheme, cursorTheme, cursorSize, colorMode, gtkThemeLight, gtkThemeDark, qtPlatformTheme, qtStyle, applyMatugenColors, syncKde, syncXsettingsd])

    function helperPath() {
        return Paths.strip(Qt.resolvedUrl("scripts/apply-theme.sh").toString());
    }

    function snapshotHelperPath() {
        return Paths.strip(Qt.resolvedUrl("scripts/theme-snapshot.sh").toString());
    }

    function buildCommand(dryRun) {
        const args = [helperPath(), "--font", regularFont, "--mono-font", monoFont, "--document-font", documentFont, "--font-size", String(regularSize), "--mono-size", String(monoSize), "--document-size", String(documentSize), "--icon-theme", iconTheme, "--cursor-theme", cursorTheme, "--cursor-size", String(cursorSize), "--mode", colorMode, "--gtk-theme-light", gtkThemeLight, "--gtk-theme-dark", gtkThemeDark, "--qt-platform-theme", qtPlatformTheme, "--qt-style", qtStyle, "--apply-matugen-colors", applyMatugenColors ? "true" : "false", "--sync-kde", syncKde ? "true" : "false", "--sync-xsettingsd", syncXsettingsd ? "true" : "false", "--backup-enabled", backupEnabled ? "true" : "false", "--backup-retention", String(backupRetention)];
        if (dryRun)
            args.push("--dry-run");

        return args;
    }

    function requestApply(showResult) {
        if (!showResult && configSignature === appliedSignature)
            return ;

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

    function runSnapshotAction(action, snapshot) {
        if (applying)
            return false;

        if (action === "restore") {
            if (pluginService && pluginService.savePluginData)
                pluginService.savePluginData(pluginId, "autoSync", false);

            applyProcess.command = [snapshotHelperPath(), "restore", "--snapshot", snapshot || "latest"];
        } else {
            applyProcess.command = [snapshotHelperPath(), "backup", "--retention", String(backupRetention), "--label", "manual"];
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

    Process {
        id: applyProcess

        running: false
        onExited: function(exitCode) {
            root.lastExitCode = exitCode;
            const output = ((stdoutCollector.text || "") + (stderrCollector.text || "")).trim();
            root.lastOutput = output || (exitCode === 0 ? "Theme synchronized" : "Theme synchronization failed");
            root.applying = false;
            if (exitCode === 0 && root.currentAction === "apply")
                root.appliedSignature = root.runningSignature;

            if (root.manualRequest) {
                if (exitCode === 0) {
                    if (root.currentAction === "backup")
                        ToastService.showInfo("DMS Theme Sync", "Backup created");
                    else if (root.currentAction === "restore")
                        ToastService.showInfo("DMS Theme Sync", "Backup restored; automatic sync disabled");
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

    IpcHandler {
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
                "currentAction": root.currentAction,
                "lastExitCode": root.lastExitCode,
                "mode": root.colorMode,
                "font": root.regularFont,
                "monoFont": root.monoFont,
                "iconTheme": root.iconTheme,
                "cursorTheme": root.cursorTheme,
                "cursorSize": root.cursorSize,
                "gtkTheme": root.colorMode === "light" ? root.gtkThemeLight : root.gtkThemeDark,
                "qtPlatformTheme": root.qtPlatformTheme,
                "applyMatugenColors": root.applyMatugenColors,
                "lastOutput": root.lastOutput
            });
        }

        function backup() : string {
            return root.runSnapshotAction("backup", "") ? "scheduled" : "busy";
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
