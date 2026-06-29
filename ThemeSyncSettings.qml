import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Widgets

PluginSettings {
    id: root

    property var installedGtkThemes: [{
        "label": "Auto-detect matching variant",
        "value": "auto"
    }, {
        "label": "Keep current theme",
        "value": "preserve"
    }]
    property var installedFonts: [SettingsData.fontFamily || "sans-serif"]
    property var installedMonoFonts: [SettingsData.monoFontFamily || "monospace"]
    property var installedIconThemes: [SettingsData.iconTheme || "System Default"]
    property var installedCursorThemes: [(SettingsData.cursorSettings && SettingsData.cursorSettings.theme) || "System Default"]
    readonly property var documentFontOptions: [{
        "label": "Same as regular font",
        "value": ""
    }].concat(installedFonts.map(function(name) {
        return {
            "label": name,
            "value": name
        };
    }))

    function parseSimpleList(text, currentValue) {
        const values = [];
        const seen = ({
        });
        if (currentValue) {
            values.push(currentValue);
            seen[currentValue] = true;
        }
        const lines = (text || "").split("\n");
        for (let i = 0; i < lines.length; i++) {
            const value = lines[i].trim();
            if (value && !seen[value]) {
                values.push(value);
                seen[value] = true;
            }
        }
        return values;
    }

    function parseThemes(text) {
        const options = [{
            "label": "Auto-detect matching variant",
            "value": "auto"
        }, {
            "label": "Keep current theme",
            "value": "preserve"
        }];
        const seen = ({
            "auto": true,
            "preserve": true
        });
        const names = (text || "").split("\n");
        for (let i = 0; i < names.length; i++) {
            const name = names[i].trim();
            if (name && !seen[name]) {
                options.push({
                    "label": name,
                    "value": name
                });
                seen[name] = true;
            }
        }
        installedGtkThemes = options;
    }

    pluginId: "dmsThemeSync"
    Component.onCompleted: {
        gtkThemesProcess.running = true;
        fontsProcess.running = true;
        monoFontsProcess.running = true;
        iconsProcess.running = true;
        cursorsProcess.running = true;
    }

    Process {
        id: gtkThemesProcess

        command: ["sh", "-c", "find \"$HOME/.themes\" \"$HOME/.local/share/themes\" /usr/local/share/themes /usr/share/themes -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sed 's#.*/##' | LC_ALL=C sort -fu"]

        stdout: StdioCollector {
            onStreamFinished: root.parseThemes(text)
        }

    }

    Process {
        id: fontsProcess

        command: ["sh", "-c", "fc-list --format='%{family[0]}\\n' 2>/dev/null | LC_ALL=C sort -fu"]

        stdout: StdioCollector {
            onStreamFinished: root.installedFonts = root.parseSimpleList(text, SettingsData.fontFamily)
        }

    }

    Process {
        id: monoFontsProcess

        command: ["sh", "-c", "fc-list :spacing=100 --format='%{family[0]}\\n' 2>/dev/null | LC_ALL=C sort -fu"]

        stdout: StdioCollector {
            onStreamFinished: root.installedMonoFonts = root.parseSimpleList(text, SettingsData.monoFontFamily)
        }

    }

    Process {
        id: iconsProcess

        command: ["sh", "-c", "for root in \"$HOME/.icons\" \"$HOME/.local/share/icons\" /usr/local/share/icons /usr/share/icons; do [ -d \"$root\" ] || continue; for dir in \"$root\"/*; do [ -f \"$dir/index.theme\" ] && basename \"$dir\"; done; done | LC_ALL=C sort -fu"]

        stdout: StdioCollector {
            onStreamFinished: root.installedIconThemes = root.parseSimpleList(text, SettingsData.iconTheme)
        }

    }

    Process {
        id: cursorsProcess

        command: ["sh", "-c", "for root in \"$HOME/.icons\" \"$HOME/.local/share/icons\" /usr/local/share/icons /usr/share/icons; do [ -d \"$root\" ] || continue; for dir in \"$root\"/*; do [ -d \"$dir/cursors\" ] && basename \"$dir\"; done; done | LC_ALL=C sort -fu"]

        stdout: StdioCollector {
            onStreamFinished: root.installedCursorThemes = root.parseSimpleList(text, SettingsData.cursorSettings && SettingsData.cursorSettings.theme)
        }

    }

    StyledText {
        width: parent.width
        text: "DMS Theme Sync"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "DMS remains the source of truth for font families, icons, cursor, light/dark mode and Matugen colors. This plugin propagates them to GTK2/3/4, Qt5/6, KDE, XSettings, Fontconfig and desktop portals."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    ToggleSetting {
        settingKey: "autoSync"
        label: "Synchronize automatically"
        description: "Apply after DMS appearance settings or light/dark mode change"
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "backupEnabled"
        label: "Back up before applying"
        description: "Create a restorable snapshot of files, GSettings and runtime environment before every synchronization"
        defaultValue: true
    }

    SliderSetting {
        settingKey: "backupRetention"
        label: "Backups to retain"
        description: "Oldest snapshots are removed after a successful backup"
        minimum: 1
        maximum: 30
        unit: ""
        defaultValue: 10
    }

    Column {
        width: parent.width
        spacing: Theme.spacingS

        StyledText {
            text: "Regular font"
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.Medium
            color: Theme.surfaceText
        }

        StyledText {
            width: parent.width
            text: "Updates the canonical DMS regular font"
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            wrapMode: Text.WordWrap
        }

        DankDropdown {
            width: parent.width
            currentValue: SettingsData.fontFamily
            options: root.installedFonts
            onValueChanged: function(value) {
                if (value && value !== SettingsData.fontFamily)
                    SettingsData.set("fontFamily", value);

            }
        }

    }

    Column {
        width: parent.width
        spacing: Theme.spacingS

        StyledText {
            text: "Monospace font"
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.Medium
            color: Theme.surfaceText
        }

        StyledText {
            width: parent.width
            text: "Updates the canonical DMS monospace font"
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            wrapMode: Text.WordWrap
        }

        DankDropdown {
            width: parent.width
            currentValue: SettingsData.monoFontFamily
            options: root.installedMonoFonts
            onValueChanged: function(value) {
                if (value && value !== SettingsData.monoFontFamily)
                    SettingsData.set("monoFontFamily", value);

            }
        }

    }

    SelectionSetting {
        settingKey: "documentFontFamily"
        label: "Document font"
        description: "Choose an installed family or follow the regular DMS font"
        options: root.documentFontOptions
        defaultValue: ""
    }

    Column {
        width: parent.width
        spacing: Theme.spacingS

        StyledText {
            text: "Icon theme"
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.Medium
            color: Theme.surfaceText
        }

        StyledText {
            width: parent.width
            text: "Updates the canonical DMS icon theme"
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            wrapMode: Text.WordWrap
        }

        DankDropdown {
            width: parent.width
            currentValue: SettingsData.iconTheme
            options: root.installedIconThemes
            onValueChanged: function(value) {
                if (value && value !== SettingsData.iconTheme)
                    SettingsData.setIconTheme(value);

            }
        }

    }

    Column {
        width: parent.width
        spacing: Theme.spacingS

        StyledText {
            text: "Cursor theme"
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.Medium
            color: Theme.surfaceText
        }

        StyledText {
            width: parent.width
            text: "Updates the canonical DMS cursor theme"
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            wrapMode: Text.WordWrap
        }

        DankDropdown {
            width: parent.width
            currentValue: (SettingsData.cursorSettings && SettingsData.cursorSettings.theme) || "System Default"
            options: root.installedCursorThemes
            onValueChanged: function(value) {
                if (value && value !== SettingsData.cursorSettings.theme)
                    SettingsData.setCursorTheme(value);

            }
        }

    }

    SelectionSetting {
        settingKey: "gtkThemeLight"
        label: "GTK theme — light mode"
        description: "Installed GTK theme used when DMS is in light mode"
        options: root.installedGtkThemes
        defaultValue: "auto"
    }

    SelectionSetting {
        settingKey: "gtkThemeDark"
        label: "GTK theme — dark mode"
        description: "Installed GTK theme used when DMS is in dark mode (Dracula, Matcha, Breeze, etc.)"
        options: root.installedGtkThemes
        defaultValue: "auto"
    }

    SelectionSetting {
        settingKey: "qtPlatformTheme"
        label: "Qt5/Qt6 theme source"
        description: "Follow GTK, use qt5ct/qt6ct with DMS Matugen colors, or preserve the current environment"
        options: [{
            "label": "Follow GTK (gtk3)",
            "value": "gtk3"
        }, {
            "label": "DMS palette (qt5ct/qt6ct)",
            "value": "qtct"
        }, {
            "label": "Preserve environment",
            "value": "preserve"
        }]
        defaultValue: "gtk3"
    }

    ToggleSetting {
        settingKey: "applyMatugenColors"
        label: "Apply DMS Matugen colors"
        description: "Import DMS dynamic colors over the selected GTK theme and use DankMatugen.colors for Qt"
        defaultValue: true
    }

    SelectionSetting {
        settingKey: "qtStyle"
        label: "Qt widget style"
        description: "Fallback style written to qt5ct and qt6ct"
        options: ["Fusion", "Breeze", "kvantum", "Windows", {
            "label": "Preserve current style",
            "value": "preserve"
        }]
        defaultValue: "Fusion"
    }

    SliderSetting {
        settingKey: "regularFontSize"
        label: "Regular UI font size"
        description: "GTK, GNOME, KDE and Qt interface text"
        minimum: 7
        maximum: 24
        unit: " pt"
        defaultValue: 11
    }

    SliderSetting {
        settingKey: "monoFontSize"
        label: "Monospace font size"
        description: "Fixed-width text in GTK, GNOME, KDE and Qt"
        minimum: 7
        maximum: 24
        unit: " pt"
        defaultValue: 12
    }

    SliderSetting {
        settingKey: "documentFontSize"
        label: "Document font size"
        description: "Document-oriented GNOME applications"
        minimum: 7
        maximum: 24
        unit: " pt"
        defaultValue: 11
    }

    ToggleSetting {
        settingKey: "syncKde"
        label: "Synchronize KDE configuration"
        description: "Update kdeglobals and kcminputrc for KDE/Qt applications"
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "syncXsettingsd"
        label: "Synchronize XSettings"
        description: "Update xsettingsd for GTK2 and XWayland applications when installed"
        defaultValue: true
    }

    StyledRect {
        width: parent.width
        height: actionColumn.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh

        Column {
            id: actionColumn

            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            StyledText {
                width: parent.width
                text: "Cursor theme and size, icon theme, and regular/monospace font families are read directly from DMS Appearance settings."
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                wrapMode: Text.WordWrap
            }

            DankButton {
                text: "Apply now"
                iconName: "sync"
                onClicked: Quickshell.execDetached(["dms", "ipc", "call", "dmsThemeSync", "apply"])
            }

            Row {
                spacing: Theme.spacingM

                DankButton {
                    text: "Back up now"
                    iconName: "backup"
                    onClicked: Quickshell.execDetached(["dms", "ipc", "call", "dmsThemeSync", "backup"])
                }

                DankButton {
                    text: "Restore latest"
                    iconName: "restore"
                    onClicked: Quickshell.execDetached(["dms", "ipc", "call", "dmsThemeSync", "restoreLatest"])
                }

            }

            StyledText {
                width: parent.width
                text: "Restoring disables automatic synchronization first. Backups are stored under ~/.local/state/DankMaterialShell/plugins/dmsThemeSync/backups."
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                wrapMode: Text.WordWrap
            }

            StyledText {
                width: parent.width
                text: "IPC: dms ipc call dmsThemeSync apply|backup|restoreLatest\nStatus: dms ipc call dmsThemeSync status"
                font.pixelSize: Theme.fontSizeSmall
                font.family: "monospace"
                color: Theme.surfaceVariantText
                wrapMode: Text.WordWrap
            }

        }

    }

}
