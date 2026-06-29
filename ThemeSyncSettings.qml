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
    Component.onCompleted: gtkThemesProcess.running = true

    Process {
        id: gtkThemesProcess

        command: ["sh", "-c", "find \"$HOME/.themes\" \"$HOME/.local/share/themes\" /usr/local/share/themes /usr/share/themes -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sed 's#.*/##' | LC_ALL=C sort -fu"]

        stdout: StdioCollector {
            onStreamFinished: root.parseThemes(text)
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

    StringSetting {
        settingKey: "qtStyle"
        label: "Qt widget style"
        description: "Fallback style written to qt5ct and qt6ct (for example Fusion, Breeze or kvantum)"
        placeholder: "Fusion"
        defaultValue: "Fusion"
    }

    StringSetting {
        settingKey: "documentFontFamily"
        label: "Document font"
        description: "Empty uses the regular DMS font family"
        placeholder: "Same as DMS regular font"
        defaultValue: ""
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

            StyledText {
                width: parent.width
                text: "IPC: dms ipc call dmsThemeSync apply\nStatus: dms ipc call dmsThemeSync status"
                font.pixelSize: Theme.fontSizeSmall
                font.family: "monospace"
                color: Theme.surfaceVariantText
                wrapMode: Text.WordWrap
            }

        }

    }

}
