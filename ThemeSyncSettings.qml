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
    // Qt platform themes and widget styles, as reported by Qt itself. These used
    // to be hardcoded lists, which offered names this machine may not have and
    // hid the ones it does. The defaults below are the two synthetic entries plus
    // what Qt always builds in, so the dropdowns are usable if qtdiag is absent.
    property var availableQtPlatformThemes: ["preserve", "qtct"]
    property var availableQtStyles: ["preserve", "Fusion", "Windows"]
    // Only Papirus ships the folder colour variants the accent sync needs. Once
    // the overlay is applied, SettingsData.iconTheme is the overlay, so test the
    // base theme rather than the applied one.
    readonly property bool iconThemeSupportsFolderColor: (SettingsData.iconTheme || "").replace(/-DankFolders$/, "").indexOf("Papirus") === 0
    property var installedCursorThemes: [(SettingsData.cursorSettings && SettingsData.cursorSettings.theme) || "System Default"]
    // What the --probe-qt run found on this machine; drives the route
    // descriptions so the user picks between things that actually exist here.
    property string probeQt6ct: ""
    property string probeKvantum: ""
    property string probeGtk: ""
    property string probePair: ""
    property string qtSyncModeValue: "manual"
    property var snapshots: []
    property var snapshotNames: ({
    })
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

    function applyHelper() {
        return Paths.strip(Qt.resolvedUrl("scripts/apply-theme.sh").toString());
    }

    // --probe-qt output is "key=value" lines; unknown keys are ignored so the
    // helper can grow the probe without breaking older UIs.
    function parseQtProbe(text) {
        const lines = (text || "").split("\n");
        for (let i = 0; i < lines.length; i++) {
            const idx = lines[i].indexOf("=");
            if (idx < 1)
                continue;

            const key = lines[i].slice(0, idx).trim();
            const value = lines[i].slice(idx + 1).trim();
            if (key === "qt6ct")
                probeQt6ct = value;
            else if (key === "kvantum")
                probeKvantum = value;
            else if (key === "gtk")
                probeGtk = value;
            else if (key === "pair")
                probePair = value;
        }
    }

    function snapshotHelper() {
        return Paths.strip(Qt.resolvedUrl("scripts/theme-snapshot.sh").toString());
    }

    function formatSnapshot(id) {
        const m = (id || "").match(/^(\d{4})(\d{2})(\d{2})-(\d{2})(\d{2})(\d{2})/);
        const date = m ? m[1] + "-" + m[2] + "-" + m[3] + "  " + m[4] + ":" + m[5] + ":" + m[6] : id;
        const name = snapshotNames[id];
        return name ? "📌 " + name + " — " + date : date;
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
        qtSyncModeValue = String(root.loadValue("qtSyncMode", "manual") || "manual");
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

    // Not every key Qt reports is a choice worth offering. qt5ct/qt6ct collapse
    // into the single "qtct" entry (the plugin writes a different name per Qt
    // version; picking one alone leaves the other toolkit unthemed). snap and
    // flatpak are libqxdgdesktopportal registering the same plugin under names
    // meant for apps inside those sandboxes — three entries, one plugin. And kde
    // (plasma-integration) expects a running Plasma session, which a DMS desktop
    // by definition is not; anyone exporting it by hand still gets the reconcile
    // note, but the dropdown does not offer a switch that is never right here.
    function parseQtPlatformThemes(text) {
        const options = ["auto", "preserve", "qtct"];
        const seen = ({
            "auto": true,
            "preserve": true,
            "qtct": true,
            "qt5ct": true,
            "qt6ct": true,
            "snap": true,
            "flatpak": true,
            "kde": true
        });
        const names = (text || "").split("\n");
        for (let i = 0; i < names.length; i++) {
            const name = names[i].trim();
            if (name && !seen[name]) {
                options.push(name);
                seen[name] = true;
            }
        }
        return options;
    }

    // qt5ct-style/qt6ct-style are proxy styles: they read the very config file
    // we are writing, so offering them as the style would be circular.
    function parseQtStyles(text) {
        const options = ["auto", "preserve"];
        const seen = ({
            "auto": true,
            "preserve": true,
            "qt5ct-style": true,
            "qt6ct-style": true
        });
        const names = (text || "").split("\n");
        for (let i = 0; i < names.length; i++) {
            const name = names[i].trim();
            if (name && !seen[name]) {
                options.push(name);
                seen[name] = true;
            }
        }
        return options.length > 2 ? options : ["auto", "preserve", "Fusion", "Windows"];
    }

    // list prints "id<TAB>name"; the name column is empty for unnamed snapshots.
    // A named snapshot is pinned — retention neither counts nor deletes it.
    function parseSnapshots(text) {
        const list = [];
        const names = ({
        });
        const lines = (text || "").split("\n");
        for (let i = 0; i < lines.length; i++) {
            const parts = lines[i].split("\t");
            const id = (parts[0] || "").trim();
            if (!id)
                continue;

            list.push(id);
            if (parts.length > 1 && parts[1].trim())
                names[id] = parts[1].trim();

        }
        snapshots = list;
        snapshotNames = names;
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
        function onPluginDataChanged(changedPluginId) {
            if (changedPluginId === root.pluginId)
                root.reloadPluginValues();

        }

        target: root.pluginService
        ignoreUnknownSignals: true
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

    // Ask Qt what it can load rather than guessing. `qtdiag` prints two
    // "available" lines — platform themes under "Platforms requested", styles
    // under "Styles requested" — so both greps are anchored to their section.
    // Offscreen keeps it from needing a display. If qtdiag is absent (qt6-tools
    // not installed) the collector gets nothing and the defaults stand.
    Process {
        id: qtPlatformThemesProcess

        running: true
        command: ["sh", "-c", "q=$(command -v qtdiag6 || command -v qtdiag) || exit 0; QT_QPA_PLATFORM=offscreen \"$q\" 2>/dev/null | awk '/Platforms requested/{f=1;next} f&&/available/{sub(/.*: */,\"\");print;exit}' | tr ',' '\\n'"]

        stdout: StdioCollector {
            onStreamFinished: root.availableQtPlatformThemes = root.parseQtPlatformThemes(text)
        }

    }

    Process {
        id: qtStylesProcess

        running: true
        command: ["sh", "-c", "q=$(command -v qtdiag6 || command -v qtdiag) || exit 0; QT_QPA_PLATFORM=offscreen \"$q\" 2>/dev/null | awk '/Styles requested/{f=1;next} f&&/available/{sub(/.*: */,\"\");print;exit}' | tr ',' '\\n'"]

        stdout: StdioCollector {
            onStreamFinished: root.availableQtStyles = root.parseQtStyles(text)
        }

    }

    // Ask the helper, not a re-implementation: --probe-qt answers with the same
    // detection functions the apply run will use (qt6ct flavour, Kvantum
    // presence, the Kvantum pair for the current GTK theme), so what this UI
    // promises and what the helper does cannot drift apart.
    Process {
        id: qtProbeProcess

        running: true
        command: ["bash", root.applyHelper(), "--probe-qt", "--mode", (typeof Theme !== "undefined" && Theme.isLightMode) ? "light" : "dark", "--gtk-theme-light", root.gtkThemeLightValue || "auto", "--gtk-theme-dark", root.gtkThemeDarkValue || "auto"]

        stdout: StdioCollector {
            onStreamFinished: root.parseQtProbe(text)
        }

    }

    // The helper's `list`, not a private find: only the helper prints the
    // id<TAB>name pairs the pinned markers come from, and only it knows to
    // ignore directories that are not snapshots.
    Process {
        id: snapshotListProcess

        running: true
        command: ["bash", root.snapshotHelper(), "list"]

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
        text: "GTK ↔ Qt synchronization"
    }

    StyledText {
        width: parent.width
        // The probe fills in after a moment; until then say nothing rather than
        // something wrong.
        text: {
            if (!root.probeQt6ct)
                return "Probing what this machine can do…";

            const parts = [];
            parts.push(root.probeQt6ct === "kde" ? "qt6ct-kde ✓ (reads the DMS palette directly)" : "stock qt6ct (cannot read the DMS .colors palette — qt6ct-kde fixes that)");
            parts.push(root.probeKvantum === "yes" ? "Kvantum ✓" : "Kvantum not installed");
            if (root.probePair && root.probePair !== "none")
                parts.push("Kvantum pair for " + root.probeGtk + ": " + root.probePair);
            else if (root.probeKvantum === "yes")
                parts.push("no Kvantum pair for " + root.probeGtk);
            return "Detected: " + parts.join(" · ");
        }
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    SelectionSetting {
        settingKey: "qtSyncMode"
        label: "Synchronization route"
        description: "How Qt applications are made to match GTK. 'Automatic' picks the best route this machine supports, re-evaluated on every apply: a Kvantum theme paired with the GTK theme (same author, both halves one design) → Kvantum rendered from the DMS palette (needs the toggle below) → the DMS palette through qt6ct-kde (KColorScheme) → Qt follows the GTK theme (gtk3). Every route except 'Manual' overrides the platform theme and widget style in the Qt applications section — pick 'Manual' to drive those two by hand, exactly as before this option existed."
        options: [{
            "label": "Manual — use the Qt applications options below",
            "value": "manual"
        }, {
            "label": "Automatic — best available route",
            "value": "auto"
        }, {
            "label": "Kvantum theme paired with the GTK theme",
            "value": "pair"
        }, {
            "label": "Kvantum rendered from the DMS palette",
            "value": "kvantum"
        }, {
            "label": "DMS palette via qt6ct-kde (KColorScheme)",
            "value": "kcolorscheme"
        }, {
            "label": "Follow the GTK theme (gtk3)",
            "value": "gtk3"
        }]
        defaultValue: "manual"
    }

    SectionHeader {
        text: "Qt applications"
    }

    StyledText {
        width: parent.width
        visible: root.qtSyncModeValue !== "manual"
        text: "The synchronization route above is not 'Manual', so it decides the platform theme and widget style — the two options below are written but then overridden on every apply."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.warning !== undefined ? Theme.warning : Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    SelectionSetting {
        settingKey: "qtPlatformTheme"
        label: "Qt5/Qt6 platform theme"
        description: {
            // Where QT_QPA_PLATFORMTHEME actually lands depends on the compositor:
            // on Niri the plugin writes a KDL include and environment.d is NOT
            // used, so naming only environment.d here was wrong on the very
            // machines this runs on.
            const c = (typeof CompositorService !== "undefined" && CompositorService.compositor) || "";
            let where;
            if (c === "niri")
                where = "On niri it is written to ~/.config/niri/dms-theme-sync.kdl (included from config.kdl); environment.d is not used";
            else if (c === "hyprland")
                where = "On Hyprland it is written to environment.d plus a Hyprland include";
            else
                where = "It is written to environment.d (systemd user session)";
            return "Only platform themes this machine has and that make sense on a DMS desktop are listed (sandbox aliases and Plasma's are filtered out). Controls QT_QPA_PLATFORMTHEME. " + where + ". Apps started after the next apply pick it up; already-running ones need a restart. Keep 'Leave to my environment' if you already set the variable yourself. Only 'DMS palette' reads qt5ct/qt6ct.conf — under gtk3 the widget style below is ignored.";
        }
        options: root.availableQtPlatformThemes.map(function(name) {
            if (name === "auto")
                return {
                "label": "Auto (Kvantum if installed, else follow GTK)",
                "value": "auto"
            };

            if (name === "preserve")
                return {
                "label": "Leave to my environment (recommended)",
                "value": "preserve"
            };

            if (name === "qtct")
                return {
                "label": "Plugin sets DMS palette (qt5ct/qt6ct)",
                "value": "qtct"
            };

            if (name === "gtk3")
                return {
                "label": "Plugin sets Follow GTK (gtk3)",
                "value": "gtk3"
            };

            if (name === "xdgdesktopportal")
                return {
                "label": "Portal only: dark/light + accent, no style (xdgdesktopportal)",
                "value": "xdgdesktopportal"
            };

            return name;
        })
        defaultValue: "preserve"
    }

    SelectionSetting {
        settingKey: "qtStyle"
        label: "Qt widget style"
        description: "Styles Qt can actually load here, as reported by qtdiag. Written to qt5ct.conf and qt6ct.conf, which only the qt5ct/qt6ct platform theme reads. 'Auto' picks Kvantum when it is installed and the platform theme reads those files, and otherwise writes no style at all."
        options: root.availableQtStyles.map(function(name) {
            if (name === "auto")
                return {
                "label": "Auto (Kvantum if installed and readable)",
                "value": "auto"
            };

            if (name === "preserve")
                return {
                "label": "Preserve current style",
                "value": "preserve"
            };

            return name;
        })
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
        settingKey: "syncKvantum"
        label: "Generate a Kvantum theme from the DMS palette"
        description: "Kvantum draws Qt widgets from an SVG and takes its colours from its own theme, not from the qt5ct/qt6ct palette — so selecting the kvantum style without giving it a theme does not add Material You to Qt, it removes it. When on, the plugin renders ~/.config/Kvantum/DankMatugen/ from the DMS colours (both the .kvconfig and the recoloured .svg) and selects it. Only has an effect when the Qt widget style is 'kvantum'. In the 'Automatic' synchronization route this toggle also gates the DMS-palette-Kvantum step; a paired Kvantum theme always wins over the render, because pairing means both halves come from one design."
        defaultValue: false
    }

    ToggleSetting {
        settingKey: "syncFlatpak"
        label: "Synchronize Flatpak applications"
        description: "Sandboxed apps never see the files written above. Dark/light already reaches them through the portal, but the theme names and the host's gtk.css do not. When on, the plugin sets GTK_THEME, ICON_THEME and XCURSOR_THEME as user-wide flatpak overrides and grants read-only access to the theme directories. This is also the only sane way to reach Electron apps: exporting GTK_THEME globally would override settings.ini for every GTK app on the machine, while inside the sandbox the variable is scoped to the sandbox."
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
                text: root.snapshots.length > 0 ? "Pick a snapshot and restore it. Restoring disables auto-apply first so the recovered state is not immediately overwritten. Unnamed snapshots rotate away when the retention limit is reached — give a name (📌) to any configuration you cannot afford to lose." : "No backups yet. Create one below or apply with backups enabled."
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

            StyledText {
                width: parent.width
                text: "Name & pin"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            StyledText {
                width: parent.width
                text: "A named snapshot (📌) is pinned: retention never rotates it away. Type a name, then either pin the snapshot selected above or take a new named backup. Pinning with the field empty unpins the selected one."
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                wrapMode: Text.WordWrap
            }

            DankTextField {
                id: snapshotNameField

                width: parent.width
                placeholderText: "Snapshot name, e.g. \"known good — before experiments\""
            }

            Row {
                width: parent.width
                spacing: Theme.spacingM

                DankButton {
                    id: pinButton

                    text: snapshotNameField.text ? "Pin selected" : "Unpin selected"
                    iconName: "push_pin"
                    enabled: root.selectedSnapshot !== "" && !snapshotActionProcess.running
                    onClicked: {
                        snapshotActionProcess.command = ["bash", root.snapshotHelper(), "name", "--snapshot", root.selectedSnapshot, "--name", snapshotNameField.text];
                        snapshotActionProcess.running = true;
                    }
                }

                DankButton {
                    id: backupNowButton

                    text: snapshotNameField.text ? "Back up now (pinned)" : "Back up now"
                    iconName: "backup"
                    enabled: !snapshotActionProcess.running
                    onClicked: {
                        let cmd = ["bash", root.snapshotHelper(), "backup", "--retention", String(root.backupRetentionValue), "--label", "manual"];
                        if (snapshotNameField.text)
                            cmd = cmd.concat(["--name", snapshotNameField.text]);

                        snapshotActionProcess.command = cmd;
                        snapshotActionProcess.running = true;
                    }
                }

            }

            // Straight to the script, not through the daemon's IPC: the daemon
            // serialises snapshot actions behind its apply gate and answers
            // "busy" — which a button click has no way to show — and its IPC
            // registration does not survive plugin reloads. Naming is a one-line
            // metadata write; running it here keeps the click always effective
            // and lets the list refresh the moment it finishes.
            Process {
                id: snapshotActionProcess

                running: false
                onExited: root.refreshSnapshots()
            }

            StyledText {
                width: parent.width
                text: "Backups are stored under ~/.local/state/DankMaterialShell/plugins/dmsThemeSync/backups.\nIPC: dms ipc call dmsThemeSync apply|backup|backupNamed <name>|nameSnapshot <id> <name>|restoreLatest|status"
                font.pixelSize: Theme.fontSizeSmall
                font.family: "monospace"
                color: Theme.surfaceVariantText
                wrapMode: Text.WordWrap
            }

        }

    }

    // Visible section divider. The file used to mark its sections with `// ---`
    // comments, which organise the source and nothing else: in the UI the ~30
    // controls ran together as one flat list.
    component SectionHeader: StyledText {
        width: parent ? parent.width : 0
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.Bold
        color: Theme.primary
    }

}
