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
    readonly property string qtPlatformTheme: pluginData.qtPlatformTheme || "gtk3"
    readonly property string qtStyle: pluginData.qtStyle || "Fusion"
    readonly property bool applyMatugenColors: pluginData.applyMatugenColors !== undefined ? pluginData.applyMatugenColors : true
    readonly property bool syncKde: pluginData.syncKde !== undefined ? pluginData.syncKde : true
    readonly property bool syncXsettingsd: pluginData.syncXsettingsd !== undefined ? pluginData.syncXsettingsd : true
    readonly property string configSignature: JSON.stringify([regularFont, monoFont, documentFont, regularSize, monoSize, documentSize, iconTheme, cursorTheme, cursorSize, colorMode, gtkThemeLight, gtkThemeDark, qtPlatformTheme, qtStyle, applyMatugenColors, syncKde, syncXsettingsd])

    function helperPath() {
        return Paths.strip(Qt.resolvedUrl("scripts/apply-theme.sh").toString());
    }

    function buildCommand(dryRun) {
        const args = [helperPath(), "--font", regularFont, "--mono-font", monoFont, "--document-font", documentFont, "--font-size", String(regularSize), "--mono-size", String(monoSize), "--document-size", String(documentSize), "--icon-theme", iconTheme, "--cursor-theme", cursorTheme, "--cursor-size", String(cursorSize), "--mode", colorMode, "--gtk-theme-light", gtkThemeLight, "--gtk-theme-dark", gtkThemeDark, "--qt-platform-theme", qtPlatformTheme, "--qt-style", qtStyle, "--apply-matugen-colors", applyMatugenColors ? "true" : "false", "--sync-kde", syncKde ? "true" : "false", "--sync-xsettingsd", syncXsettingsd ? "true" : "false"];
        if (dryRun)
            args.push("--dry-run");

        return args;
    }

    function requestApply(showResult) {
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
        applyProcess.command = buildCommand(false);
        applyProcess.running = true;
    }

    pluginId: "dmsThemeSync"
    onConfigSignatureChanged: {
        if (autoSync)
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

        interval: 1200
        repeat: false
        onTriggered: root.requestApply(false)
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
            if (root.manualRequest) {
                if (exitCode === 0)
                    ToastService.showInfo("DMS Theme Sync", "Application themes synchronized");
                else
                    ToastService.showError("DMS Theme Sync", root.lastOutput);
                root.manualRequest = false;
            }
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

    IpcHandler {
        function apply() : string {
            root.requestApply(true);
            return root.applying ? "queued" : "scheduled";
        }

        function status() : string {
            return JSON.stringify({
                "applying": root.applying,
                "autoSync": root.autoSync,
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

        target: "dmsThemeSync"
    }

}
