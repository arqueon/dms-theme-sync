import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Widgets

PluginSettings {
    id: root

    property var installedGtkThemes: ["auto", "preserve"]
    property var installedFonts: [SettingsData.fontFamily || "sans-serif"]
    property var installedMonoFonts: [SettingsData.monoFontFamily || "monospace"]
    property var installedIconThemes: [SettingsData.iconTheme || "System Default"]
    // Only Papirus ships the folder colour variants the accent sync needs.
    readonly property bool iconThemeSupportsFolderColor: (SettingsData.iconTheme || "").indexOf("Papirus") === 0

    // Visible section divider. The file used to mark its sections with `// ---`
    // comments, which organise the source and nothing else: in the UI the ~30
    // controls ran together as one flat list.
    component SectionHeader: StyledText {
        width: parent ? parent.width : 0
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.Bold
        color: Theme.primary
    }
    property var installedCursorThemes: [(SettingsData.cursorSettings && SettingsData.cursorSettings.theme) || "System Default"]
    property var snapshots: []

    // Plugin-owned values. Loaded from / saved to plugin data directly so the
    // controls reflect the stored choice even before option lists finish loading.
    property string gtkThemeLightValue: "auto"
    property string gtkThemeDarkValue: "auto"
    property string documentFontValue: ""
    property string selectedSnapshot: ""
    property int regularFontSizeValue: 11
    property int monoFontSizeValue: 12
    property int documentFontSizeValue: 11
    property int backupRetentionValue: 10

    // DMS color themes, mirrored from the live DMS API. These act on DMS directly,
    // exactly like the DMS Settings "Theme" tab.
    readonly property var dmsThemeOptions: {
        const opts = [{
            "label": "Dynamic (wallpaper)",
            "value": "dynamic"
        }];
        const names = (typeof Theme !== "undefined" && Theme.getAvailableThemes) ? Theme.getAvailableThemes() : [];
        for (let i = 0; i < names.length; i++) {
            const colors = Theme.getThemeColors(names[i]);
            opts.push({
                "label": (colors && colors.name) ? colors.name : names[i],
                "value": names[i]
            });
        }
        return opts;
    }
    readonly property var dmsThemeLabels: dmsThemeOptions.map(function(o) {
        return o.label;
    })
    readonly property var matugenSchemeOptions: (typeof Theme !== "undefined" && Theme.availableMatugenSchemes) ? Theme.availableMatugenSchemes : []
    readonly property var matugenSchemeLabels: matugenSchemeOptions.map(function(o) {
        return o.label;
    })
    readonly property var snapshotLabels: snapshots.map(function(id) {
        return root.formatSnapshot(id);
    })

    function labelForValue(options, value) {
        for (let i = 0; i < options.length; i++) {
            if (options[i].value === value)
                return options[i].label;
        }
        return value;
    }

    function valueForLabel(options, label) {
        for (let i = 0; i < options.length; i++) {
            if (options[i].label === label)
                return options[i].value;
        }
        return label;
    }

    function formatSnapshot(id) {
        const m = (id || "").match(/^(\d{4})(\d{2})(\d{2})-(\d{2})(\d{2})(\d{2})/);
        if (!m)
            return id;
        return m[1] + "-" + m[2] + "-" + m[3] + "  " + m[4] + ":" + m[5] + ":" + m[6];
    }

    function snapshotForLabel(label) {
        for (let i = 0; i < snapshots.length; i++) {
            if (root.formatSnapshot(snapshots[i]) === label)
                return snapshots[i];
        }
        return "";
    }

    function reloadPluginValues() {
        gtkThemeLightValue = String(root.loadValue("gtkThemeLight", "auto") || "auto");
        gtkThemeDarkValue = String(root.loadValue("gtkThemeDark", "auto") || "auto");
        documentFontValue = String(root.loadValue("documentFontFamily", "") || "");
        regularFontSizeValue = Number(root.loadValue("regularFontSize", 11)) || 11;
        monoFontSizeValue = Number(root.loadValue("monoFontSize", 12)) || 12;
        documentFontSizeValue = Number(root.loadValue("documentFontSize", 11)) || 11;
        backupRetentionValue = Number(root.loadValue("backupRetention", 10)) || 10;
    }

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
        const options = ["auto", "preserve"];
        const seen = ({
            "auto": true,
            "preserve": true
        });
        const names = (text || "").split("\n");
        for (let i = 0; i < names.length; i++) {
            const name = names[i].trim();
            if (name && !seen[name]) {
                options.push(name);
                seen[name] = true;
            }
        }
        installedGtkThemes = options;
    }

    function parseSnapshots(text) {
        const list = [];
        const lines = (text || "").split("\n");
        for (let i = 0; i < lines.length; i++) {
            const id = lines[i].trim();
            if (id)
                list.push(id);
        }
        snapshots = list;
        if (list.length > 0 && list.indexOf(selectedSnapshot) === -1)
            selectedSnapshot = list[0];
    }

    function refreshSnapshots() {
        snapshotListProcess.running = false;
        snapshotListProcess.running = true;
    }

    pluginId: "dmsThemeSync"
    // Load stored values once the component is ready. Process-driven option lists
    // are started declaratively below so they cannot be skipped if this throws.
    Component.onCompleted: reloadPluginValues()

    Connections {
        target: root.pluginService
        ignoreUnknownSignals: true

        function onPluginDataChanged(changedPluginId) {
            if (changedPluginId === root.pluginId)
                root.reloadPluginValues();
        }
    }

    Process {
        id: gtkThemesProcess

        running: true
        command: ["sh", "-c", "find \"$HOME/.themes\" \"$HOME/.local/share/themes\" /usr/local/share/themes /usr/share/themes -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sed 's#.*/##' | LC_ALL=C sort -fu"]

        stdout: StdioCollector {
            onStreamFinished: root.parseThemes(text)
        }

    }

    Process {
        id: fontsProcess

        running: true
        command: ["sh", "-c", "fc-list --format='%{family[0]}\\n' 2>/dev/null | LC_ALL=C sort -fu"]

        stdout: StdioCollector {
            onStreamFinished: root.installedFonts = root.parseSimpleList(text, SettingsData.fontFamily)
        }

    }

    Process {
        id: monoFontsProcess

        running: true
        command: ["sh", "-c", "fc-list :spacing=100 --format='%{family[0]}\\n' 2>/dev/null | LC_ALL=C sort -fu"]

        stdout: StdioCollector {
            onStreamFinished: root.installedMonoFonts = root.parseSimpleList(text, SettingsData.monoFontFamily)
        }

    }

    Process {
        id: iconsProcess

        running: true
        command: ["sh", "-c", "for base in \"$HOME/.icons\" \"$HOME/.local/share/icons\" /usr/local/share/icons /usr/share/icons; do [ -d \"$base\" ] || continue; for dir in \"$base\"/*; do [ -f \"$dir/index.theme\" ] || continue; grep -q '^Directories=' \"$dir/index.theme\" || continue; basename \"$dir\"; done; done | grep -vxE 'default|hicolor|locolor' | LC_ALL=C sort -fu"]

        stdout: StdioCollector {
            onStreamFinished: root.installedIconThemes = root.parseSimpleList(text, SettingsData.iconTheme)
        }

    }

    Process {
        id: cursorsProcess

        running: true
        command: ["sh", "-c", "for root in \"$HOME/.icons\" \"$HOME/.local/share/icons\" /usr/local/share/icons /usr/share/icons; do [ -d \"$root\" ] || continue; for dir in \"$root\"/*; do [ -d \"$dir/cursors\" ] && basename \"$dir\"; done; done | LC_ALL=C sort -fu"]

        stdout: StdioCollector {
            onStreamFinished: root.installedCursorThemes = root.parseSimpleList(text, SettingsData.cursorSettings && SettingsData.cursorSettings.theme)
        }

    }

    Process {
        id: snapshotListProcess

        running: true
        command: ["sh", "-c", "find \"${XDG_STATE_HOME:-$HOME/.local/state}/DankMaterialShell/plugins/dmsThemeSync/backups\" -mindepth 1 -maxdepth 1 -type d ! -name '*.tmp.*' -printf '%f\\n' 2>/dev/null | LC_ALL=C sort -r"]

        stdout: StdioCollector {
            onStreamFinished: root.parseSnapshots(text)
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
        text: "Every DMS appearance control is mirrored here, so the whole theme can be configured in one place. The color theme, light/dark mode, Matugen palette, fonts, icons and cursor write directly to DMS; the plugin then propagates them to GTK2/3/4, Qt5/6, KDE, XSettings, Fontconfig and desktop portals."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    SectionHeader {
        text: "DMS appearance"
    }

    Column {
        width: parent.width
        spacing: Theme.spacingS

        StyledText {
            text: "Color theme"
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.Medium
            color: Theme.surfaceText
        }

        StyledText {
            width: parent.width
            text: "DMS color theme. 'Dynamic (wallpaper)' derives the palette from the wallpaper with Matugen."
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            wrapMode: Text.WordWrap
        }

        DankDropdown {
            width: parent.width
            currentValue: root.labelForValue(root.dmsThemeOptions, Theme.currentThemeName)
            options: root.dmsThemeLabels
            onValueChanged: function(value) {
                const themeName = root.valueForLabel(root.dmsThemeOptions, value);
                if (themeName && themeName !== Theme.currentThemeName)
                    Theme.switchTheme(themeName);

            }
        }

    }

    DankToggle {
        width: parent.width
        text: "Light mode"
        description: "Use the light variant instead of dark. DMS stays the source of truth for the mode."
        checked: SessionData.isLightMode
        onToggled: function(isChecked) {
            if (isChecked === SessionData.isLightMode)
                return ;

            Theme.screenTransition();
            Theme.setLightMode(isChecked);
        }
    }

    Column {
        width: parent.width
        spacing: Theme.spacingS
        visible: typeof Theme !== "undefined" && Theme.matugenAvailable
        opacity: visible ? 1 : 0.4

        StyledText {
            text: "Matugen palette"
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.Medium
            color: Theme.surfaceText
        }

        StyledText {
            width: parent.width
            text: "Palette algorithm used for wallpaper-based colors"
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            wrapMode: Text.WordWrap
        }

        DankDropdown {
            width: parent.width
            currentValue: root.labelForValue(root.matugenSchemeOptions, SettingsData.matugenScheme)
            options: root.matugenSchemeLabels
            onValueChanged: function(value) {
                const scheme = root.valueForLabel(root.matugenSchemeOptions, value);
                if (scheme && scheme !== SettingsData.matugenScheme)
                    SettingsData.setMatugenScheme(scheme);

            }
        }

    }

    Column {
        width: parent.width
        spacing: Theme.spacingS
        visible: typeof Theme !== "undefined" && Theme.matugenAvailable
        opacity: visible ? 1 : 0.4

        Item {
            width: parent.width
            height: matugenContrastTitle.implicitHeight

            StyledText {
                id: matugenContrastTitle

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Matugen contrast"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            DankActionButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                iconName: "restart_alt"
                tooltipText: "Reset to default (0%)"
                onClicked: SettingsData.setMatugenContrast(0)
            }

        }

        StyledText {
            width: parent.width
            text: "Contrast of generated colors (-100 minimum, 0 standard, 100 maximum)"
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            wrapMode: Text.WordWrap
        }

        DankSlider {
            width: parent.width
            minimum: -100
            maximum: 100
            unit: "%"
            wheelEnabled: false
            value: Math.round((SettingsData.matugenContrast || 0) * 100)
            onSliderDragFinished: function(finalValue) {
                SettingsData.setMatugenContrast(finalValue / 100);
            }
        }

    }

    SectionHeader {
        text: "Fonts, icons and cursor"
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
            enableFuzzySearch: true
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
            enableFuzzySearch: true
            currentValue: SettingsData.monoFontFamily
            options: root.installedMonoFonts
            onValueChanged: function(value) {
                if (value && value !== SettingsData.monoFontFamily)
                    SettingsData.set("monoFontFamily", value);

            }
        }

    }

    Column {
        width: parent.width
        spacing: Theme.spacingS

        StyledText {
            text: "Document font"
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.Medium
            color: Theme.surfaceText
        }

        StyledText {
            width: parent.width
            text: "Choose an installed family or follow the regular DMS font"
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            wrapMode: Text.WordWrap
        }

        DankDropdown {
            width: parent.width
            enableFuzzySearch: true
            currentValue: root.documentFontValue === "" ? "Same as regular font" : root.documentFontValue
            options: ["Same as regular font"].concat(root.installedFonts)
            onValueChanged: function(value) {
                const resolved = (value === "Same as regular font") ? "" : value;
                if (resolved !== root.documentFontValue) {
                    root.documentFontValue = resolved;
                    root.saveValue("documentFontFamily", resolved);
                }
            }
        }

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
            enableFuzzySearch: true
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
            enableFuzzySearch: true
            currentValue: (SettingsData.cursorSettings && SettingsData.cursorSettings.theme) || "System Default"
            options: root.installedCursorThemes
            onValueChanged: function(value) {
                if (value && value !== SettingsData.cursorSettings.theme)
                    SettingsData.setCursorTheme(value);

            }
        }

    }

    Column {
        width: parent.width
        spacing: Theme.spacingS

        Item {
            width: parent.width
            height: cursorSizeTitle.implicitHeight

            StyledText {
                id: cursorSizeTitle

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Cursor size"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            DankActionButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                iconName: "restart_alt"
                tooltipText: "Reset to default (24 px)"
                onClicked: SettingsData.setCursorSize(24)
            }

        }

        StyledText {
            width: parent.width
            text: "Updates the canonical DMS cursor size"
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            wrapMode: Text.WordWrap
        }

        DankSlider {
            width: parent.width
            minimum: 12
            maximum: 64
            unit: " px"
            wheelEnabled: false
            value: (SettingsData.cursorSettings && SettingsData.cursorSettings.size) || 24
            onSliderDragFinished: function(finalValue) {
                SettingsData.setCursorSize(finalValue);
            }
        }

    }

    SectionHeader {
        text: "GTK theme"
    }

    Column {
        width: parent.width
        spacing: Theme.spacingS

        StyledText {
            text: "GTK theme — light mode"
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.Medium
            color: Theme.surfaceText
        }

        StyledText {
            width: parent.width
            text: "Installed GTK theme used when DMS is in light mode. 'auto' matches an installed variant; 'preserve' keeps the current theme."
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            wrapMode: Text.WordWrap
        }

        DankDropdown {
            width: parent.width
            enableFuzzySearch: true
            currentValue: root.gtkThemeLightValue
            options: root.installedGtkThemes
            onValueChanged: function(value) {
                if (value && value !== root.gtkThemeLightValue) {
                    root.gtkThemeLightValue = value;
                    root.saveValue("gtkThemeLight", value);
                }
            }
        }

    }

    Column {
        width: parent.width
        spacing: Theme.spacingS

        StyledText {
            text: "GTK theme — dark mode"
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.Medium
            color: Theme.surfaceText
        }

        StyledText {
            width: parent.width
            text: "Installed GTK theme used when DMS is in dark mode (Dracula, Matcha, Breeze, etc.)"
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            wrapMode: Text.WordWrap
        }

        DankDropdown {
            width: parent.width
            enableFuzzySearch: true
            currentValue: root.gtkThemeDarkValue
            options: root.installedGtkThemes
            onValueChanged: function(value) {
                if (value && value !== root.gtkThemeDarkValue) {
                    root.gtkThemeDarkValue = value;
                    root.saveValue("gtkThemeDark", value);
                }
            }
        }

    }

    // Not a Qt setting: it drives the GTK CSS import *and* the Qt palette, and
    // used to sit wedged between the two Qt dropdowns.
    ToggleSetting {
        settingKey: "applyMatugenColors"
        label: "Apply DMS Matugen colors"
        description: "Import DMS dynamic colors over the selected GTK theme and use DankMatugen.colors for Qt"
        defaultValue: true
    }

    SectionHeader {
        text: "Qt applications"
    }

    SelectionSetting {
        settingKey: "qtPlatformTheme"
        label: "Qt5/Qt6 platform theme"
        description: "qt5ct/qt6ct config files are always written. This only controls QT_QPA_PLATFORMTHEME. Keep 'Leave to my environment' if you already set it in /etc/environment or environment.d; otherwise let the plugin write it (needs logout/login)."
        options: [{
            "label": "Leave to my environment (recommended)",
            "value": "preserve"
        }, {
            "label": "Plugin sets Follow GTK (gtk3)",
            "value": "gtk3"
        }, {
            "label": "Plugin sets DMS palette (qt5ct/qt6ct)",
            "value": "qtct"
        }]
        defaultValue: "preserve"
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

    SectionHeader {
        text: "Font sizes"
    }

    Column {
        width: parent.width
        spacing: Theme.spacingS

        Item {
            width: parent.width
            height: regularSizeTitle.implicitHeight

            StyledText {
                id: regularSizeTitle

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Regular UI font size"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            DankActionButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                iconName: "restart_alt"
                tooltipText: "Reset to default (11 pt)"
                onClicked: {
                    root.regularFontSizeValue = 11;
                    root.saveValue("regularFontSize", 11);
                }
            }

        }

        StyledText {
            width: parent.width
            text: "GTK, GNOME, KDE and Qt interface text"
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            wrapMode: Text.WordWrap
        }

        DankSlider {
            width: parent.width
            minimum: 7
            maximum: 24
            unit: " pt"
            wheelEnabled: false
            value: root.regularFontSizeValue
            onSliderValueChanged: function(newValue) {
                root.regularFontSizeValue = newValue;
            }
            onSliderDragFinished: function(finalValue) {
                root.saveValue("regularFontSize", finalValue);
            }
        }

    }

    Column {
        width: parent.width
        spacing: Theme.spacingS

        Item {
            width: parent.width
            height: monoSizeTitle.implicitHeight

            StyledText {
                id: monoSizeTitle

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Monospace font size"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            DankActionButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                iconName: "restart_alt"
                tooltipText: "Reset to default (12 pt)"
                onClicked: {
                    root.monoFontSizeValue = 12;
                    root.saveValue("monoFontSize", 12);
                }
            }

        }

        StyledText {
            width: parent.width
            text: "Fixed-width text in GTK, GNOME, KDE and Qt"
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            wrapMode: Text.WordWrap
        }

        DankSlider {
            width: parent.width
            minimum: 7
            maximum: 24
            unit: " pt"
            wheelEnabled: false
            value: root.monoFontSizeValue
            onSliderValueChanged: function(newValue) {
                root.monoFontSizeValue = newValue;
            }
            onSliderDragFinished: function(finalValue) {
                root.saveValue("monoFontSize", finalValue);
            }
        }

    }

    Column {
        width: parent.width
        spacing: Theme.spacingS

        Item {
            width: parent.width
            height: documentSizeTitle.implicitHeight

            StyledText {
                id: documentSizeTitle

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Document font size"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            DankActionButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                iconName: "restart_alt"
                tooltipText: "Reset to default (11 pt)"
                onClicked: {
                    root.documentFontSizeValue = 11;
                    root.saveValue("documentFontSize", 11);
                }
            }

        }

        StyledText {
            width: parent.width
            text: "Document-oriented GNOME applications"
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            wrapMode: Text.WordWrap
        }

        DankSlider {
            width: parent.width
            minimum: 7
            maximum: 24
            unit: " pt"
            wheelEnabled: false
            value: root.documentFontSizeValue
            onSliderValueChanged: function(newValue) {
                root.documentFontSizeValue = newValue;
            }
            onSliderDragFinished: function(finalValue) {
                root.saveValue("documentFontSize", finalValue);
            }
        }

    }

    SectionHeader {
        text: "Propagation targets"
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

    ToggleSetting {
        settingKey: "syncTerminalFonts"
        label: "Synchronize terminal fonts"
        description: "Terminals read their own config, not GTK/Qt, so the monospace font never reaches them otherwise. When on, the plugin writes a font include per terminal in ~/.config/dms-theme-sync/ (kitty.conf, alacritty.toml, ghostty.conf) using the DMS monospace font and size. Opt-in: reference each file from your terminal config once — kitty: include ~/.config/dms-theme-sync/kitty.conf · ghostty: config-file = ~/.config/dms-theme-sync/ghostty.conf · alacritty: add it to [general] import. Each generated file also prints its exact reference line in its header."
        defaultValue: false
    }

    ToggleSetting {
        settingKey: "syncFolderColor"
        label: "Sync icon folder color (requires Papirus)"
        description: "Recolors the folder icons to follow the Material You accent. Only Papirus ships the ~80 folder color variants this needs, so the toggle does nothing with any other icon theme — yours is kept exactly as you set it. When on, the plugin generates a small overlay theme in ~/.local/share/icons that inherits Papirus and only overrides the folders (about 4 MB of symlinks, no root needed, and Papirus updates are inherited). The accent is matched by hue, not by nearest RGB, because Material You hands out pastel tints in dark mode."
        defaultValue: false
        enabled: root.iconThemeSupportsFolderColor
    }

    SectionHeader {
        text: "Synchronization and backups"
    }

    ToggleSetting {
        settingKey: "autoSync"
        label: "Auto-apply to applications"
        description: "Propagate DMS appearance changes (theme, light/dark, fonts, icons, cursor) to GTK, Qt and KDE apps automatically. When off, changes apply only with 'Apply now' below."
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "backupEnabled"
        label: "Back up before applying"
        description: "Snapshot the affected files, GSettings and runtime environment before every synchronization, so a previous state can be restored."
        defaultValue: true
    }

    Column {
        width: parent.width
        spacing: Theme.spacingS

        Item {
            width: parent.width
            height: retentionTitle.implicitHeight

            StyledText {
                id: retentionTitle

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Backups to retain"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            DankActionButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                iconName: "restart_alt"
                tooltipText: "Reset to default (10)"
                onClicked: {
                    root.backupRetentionValue = 10;
                    root.saveValue("backupRetention", 10);
                }
            }

        }

        StyledText {
            width: parent.width
            text: "Oldest snapshots are removed after a successful backup"
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            wrapMode: Text.WordWrap
        }

        DankSlider {
            width: parent.width
            minimum: 1
            maximum: 30
            unit: ""
            wheelEnabled: false
            value: root.backupRetentionValue
            onSliderValueChanged: function(newValue) {
                root.backupRetentionValue = newValue;
            }
            onSliderDragFinished: function(finalValue) {
                root.saveValue("backupRetention", finalValue);
            }
        }

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

            DankButton {
                text: "Apply now"
                iconName: "sync"
                onClicked: Quickshell.execDetached(["dms", "ipc", "call", "dmsThemeSync", "apply"])
            }

            StyledText {
                width: parent.width
                text: "Restore a backup"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            StyledText {
                width: parent.width
                text: root.snapshots.length > 0 ? "Pick a snapshot by date and restore it. Restoring disables auto-apply first so the recovered state is not immediately overwritten." : "No backups yet. Create one below or apply with backups enabled."
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                wrapMode: Text.WordWrap
            }

            Row {
                width: parent.width
                spacing: Theme.spacingM

                DankDropdown {
                    width: parent.width - restoreButton.width - refreshButton.width - Theme.spacingM * 2
                    enableFuzzySearch: true
                    emptyText: "No backups"
                    currentValue: root.selectedSnapshot ? root.formatSnapshot(root.selectedSnapshot) : ""
                    options: root.snapshotLabels
                    onValueChanged: function(value) {
                        root.selectedSnapshot = root.snapshotForLabel(value);
                    }
                }

                DankButton {
                    id: restoreButton

                    text: "Restore"
                    iconName: "restore"
                    enabled: root.selectedSnapshot !== ""
                    onClicked: Quickshell.execDetached(["dms", "ipc", "call", "dmsThemeSync", "restore", root.selectedSnapshot])
                }

                DankActionButton {
                    id: refreshButton

                    anchors.verticalCenter: parent.verticalCenter
                    iconName: "refresh"
                    tooltipText: "Refresh list"
                    onClicked: root.refreshSnapshots()
                }

            }

            DankButton {
                text: "Back up now"
                iconName: "backup"
                onClicked: Quickshell.execDetached(["dms", "ipc", "call", "dmsThemeSync", "backup"])
            }

            StyledText {
                width: parent.width
                text: "Backups are stored under ~/.local/state/DankMaterialShell/plugins/dmsThemeSync/backups.\nIPC: dms ipc call dmsThemeSync apply|backup|restoreLatest|status"
                font.pixelSize: Theme.fontSizeSmall
                font.family: "monospace"
                color: Theme.surfaceVariantText
                wrapMode: Text.WordWrap
            }

        }

    }

}
