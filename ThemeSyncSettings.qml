import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.Plugins
import qs.Services

PluginSettings {
    id: root

    property var installedGtkThemes: ["auto", "preserve"]
    property var installedFonts: [SettingsData.fontFamily || "sans-serif"]
    property var installedMonoFonts: [SettingsData.monoFontFamily || "monospace"]
    property var installedRegistryThemes: []
    property bool showSurfaceRoles: false
    // Dux 2.0 added a third Material specification, "dms": the 2025 palette with
    // a raised accent chroma. Probing for settings/properties introduced in 2.0
    // keeps the panel loadable on 1.5/1.6, where offering "dms" would write a
    // value the installed matugen rejects.
    readonly property bool dms20: typeof SettingsData.containerSaturation !== "undefined" || typeof Theme.selectedContainer !== "undefined"
    readonly property bool isDynamicTheme: Theme.currentThemeName === "dynamic" && Theme.currentThemeCategory !== "registry"
    readonly property bool specControlAvailable: typeof SettingsData.matugenSpec !== "undefined" && typeof SettingsData.setMatugenSpec === "function" && Theme.matugenAvailable
    readonly property string materialSpec: specControlAvailable ? (SettingsData.matugenSpec || "2021") : "2021"
    // 2025 and the 2.0 bold variant share the 0..100 contrast range; only the
    // 2021 generator accepts negative values.
    readonly property bool modernSpec: materialSpec !== "2021"
    readonly property var specOptions: {
        const opts = [{
            "label": "Standard (2021)",
            "value": "2021"
        }, {
            "label": "Expressive (2025)",
            "value": "2025"
        }];
        if (dms20)
            opts.push({
                "label": "Bold (Dux 2025)",
                "value": "dms"
            });
        return opts;
    }
    readonly property var specLabels: specOptions.map(function(o) {
        return o.label;
    })
    readonly property int specIndex: {
        for (let i = 0; i < specOptions.length; i++) {
            if (specOptions[i].value === materialSpec)
                return i;
        }
        return 0;
    }
    readonly property bool sourceModeAvailable: typeof SettingsData.matugenSourceMode !== "undefined" && typeof SettingsData.setMatugenSourceMode === "function" && typeof Theme !== "undefined" && Theme.availableSourceModes !== undefined && Theme.matugenAvailable
    readonly property var sourceModeOptions: sourceModeAvailable ? Theme.availableSourceModes : []
    readonly property var sourceModeLabels: sourceModeOptions.map(function(o) {
        return o.label;
    })
    readonly property string sourceModeLabel: {
        if (!sourceModeAvailable)
            return "";
        const mode = Theme.getSourceMode(SettingsData.matugenSourceMode);
        return mode ? mode.label : (SettingsData.matugenSourceMode || "");
    }
    readonly property bool seedColorAvailable: typeof SettingsData.matugenSeedColor !== "undefined" && typeof SettingsData.setMatugenSeedColor === "function"
    readonly property bool customSeed: seedColorAvailable && !!SettingsData.matugenSeedColor
    readonly property color defaultSeedColor: (typeof Theme !== "undefined" && !Theme.rawWallpaperPath) ? (Theme.materialWallpaperSeed || Theme.primary) : (typeof Theme !== "undefined" && typeof Theme.getMatugenColor === "function" ? Theme.getMatugenColor("source_color", Theme.primary) : Theme.primary)
    readonly property bool smartModeAvailable: typeof SettingsData.matugenSmartMode !== "undefined" && typeof SettingsData.setMatugenSmartMode === "function"
    readonly property bool matugenSmartCapable: smartModeAvailable && typeof Theme !== "undefined" && Theme.matugenAvailable && root.isDynamicTheme && (typeof DMSService === "undefined" || DMSService.matugenSmartSupported !== false)
    readonly property var autoScheduleModes: matugenSmartCapable ? ["manual", "time", "location", "wallpaper"] : ["manual", "time", "location"]
    readonly property var autoScheduleLabels: ["Manual", "Schedule", "Location", "Wallpaper"].slice(0, autoScheduleModes.length)
    readonly property string autoScheduleMode: {
        if (smartModeAvailable && SettingsData.matugenSmartMode)
            return "wallpaper";
        if (typeof SessionData === "undefined" || !SessionData.themeModeAutoEnabled)
            return "manual";
        return SessionData.themeModeAutoMode === "location" ? "location" : "time";
    }
    readonly property bool targetMonitorAvailable: typeof SettingsData.matugenTargetMonitor !== "undefined" && typeof SettingsData.setMatugenTargetMonitor === "function"
    readonly property bool generateAtStartupAvailable: typeof SettingsData.generateThemeAtStartup !== "undefined"
    readonly property bool terminalOpacityAvailable: typeof SettingsData.terminalOpacity !== "undefined"
    readonly property bool terminalsAlwaysDarkAvailable: typeof SettingsData.terminalsAlwaysDark !== "undefined"
    readonly property bool syncModeWithPortalAvailable: typeof SettingsData.syncModeWithPortal !== "undefined"
    readonly property bool terminalPaletteAvailable: typeof SettingsData.terminalPalette !== "undefined"
    // Dux exposes the wallpaper tint as an intensity ladder (Low/Medium/High
    // next to the untinted default) since 2.1; the plugin mirrors all four.
    readonly property var terminalPaletteOptions: [{
        "label": "Tonal — distinct ANSI colors (recommended)",
        "value": "default"
    }, {
        "label": "Soft — slight wallpaper tint (low)",
        "value": "low"
    }, {
        "label": "Medium — moderate wallpaper tint",
        "value": "medium"
    }, {
        "label": "Vibrant — shift ANSI accents toward primary",
        "value": "high"
    }]
    readonly property var terminalPaletteLabels: terminalPaletteOptions.map(function(o) {
        return o.label;
    })
    readonly property bool dms21: typeof SettingsData.interfaceStyle !== "undefined" || typeof SettingsData.density !== "undefined"
    // Dux 2.2 ships its own icon-folder and cursor-theme pipeline; while it is
    // present, the plugin's folder-color overlay and Bibata variant picking
    // defer to it automatically.
    readonly property bool dux22Icons: typeof SettingsData.iconFolderRecolor !== "undefined"
    readonly property bool interfaceStyleAvailable: typeof SettingsData.interfaceStyle !== "undefined"
    readonly property bool densityAvailable: typeof SettingsData.density !== "undefined"
    readonly property bool sectionDividerAvailable: typeof SettingsData.sectionDividerOpacity !== "undefined"
    readonly property var densityOptions: [{
        "label": "Spacious",
        "value": "spacious"
    }, {
        "label": "Comfortable",
        "value": "comfortable"
    }, {
        "label": "Compact",
        "value": "compact"
    }, {
        "label": "Dense",
        "value": "dense"
    }]
    readonly property var densityLabels: densityOptions.map(function(o) {
        return o.label;
    })
    readonly property bool radiusAvailable: typeof SettingsData.radiusMode !== "undefined" && typeof SettingsData.fixedRadius !== "undefined"
    readonly property bool fixedRadiusMode: radiusAvailable && SettingsData.radiusMode === "fixed"
    readonly property bool screenCornersAvailable: typeof SettingsData.screenCornersEnabled !== "undefined" && typeof SettingsData.screenCornerRadius !== "undefined"
    readonly property bool shellAccentAvailable: typeof SettingsData.containerSaturation !== "undefined" || typeof SettingsData.buttonColorMode !== "undefined" || typeof SettingsData.controlCenterTileColorMode !== "undefined"
    readonly property bool surfaceRolesAvailable: typeof SettingsData.hostSurfaceColor !== "undefined" && typeof SettingsData.cardSurfaceColor !== "undefined"
    readonly property bool duxFontWeightAvailable: typeof SettingsData.fontWeight !== "undefined"
    readonly property bool duxFontScaleAvailable: typeof SettingsData.fontScale !== "undefined"
    // Dux 2.0 can write qt5ct/qt6ct/qtengine colour files itself, on every palette
    // regeneration; the panel says which palette each side owns.
    readonly property bool dmsQtTemplates: typeof SettingsData.runDmsMatugenTemplates !== "undefined" && SettingsData.runDmsMatugenTemplates && (SettingsData.matugenTemplateQt5ct !== false || SettingsData.matugenTemplateQt6ct !== false || SettingsData.matugenTemplateQtengine !== false)
    readonly property bool dmsKdeTemplate: typeof SettingsData.runDmsMatugenTemplates !== "undefined" && SettingsData.runDmsMatugenTemplates && SettingsData.matugenTemplateKcolorscheme !== false
    // Mirrors ThemeSyncService: only an active Qt engine takes the Qt palette.
    readonly property bool deferQtColors: qtengineActive && !uniformToggle.value
    readonly property bool deferKdeColors: false
    readonly property bool qtengineActive: typeof SettingsData.qtengineActive !== "undefined" && SettingsData.qtengineActive
    readonly property bool hasDmsIconThemes: typeof SettingsData !== "undefined" && Array.isArray(SettingsData.availableIconThemes) && SettingsData.availableIconThemes.some(function(name) {
        return name && name !== "System Default";
    })
    property var fallbackIconThemes: [SettingsData.iconTheme || "System Default"]
    readonly property var installedIconThemes: root.mergeCurrentIntoList(hasDmsIconThemes ? SettingsData.availableIconThemes : fallbackIconThemes, SettingsData.iconTheme || "System Default")
    property string iconThemeValue: SettingsData.iconTheme || "System Default"
    property string requestedIconTheme: ""
    property bool requestedIconThemeLight: false
    property string iconThemeSelectionStatus: ""
    // Qt platform themes and widget styles, as reported by Qt itself. These used
    // to be hardcoded lists, which offered names this machine may not have and
    // hid the ones it does. The defaults below are the two synthetic entries plus
    // what Qt always builds in, so the dropdowns are usable if qtdiag is absent.
    property var availableQtPlatformThemes: ["preserve", "qtct"]
    property var availableQtStyles: ["preserve", "Fusion", "Windows"]
    // Only Papirus ships the folder colour variants the accent sync needs. Once
    // the overlay is applied, SettingsData.iconTheme is the overlay, so test the
    // base theme rather than the applied one.
    readonly property bool iconThemePerMode: typeof SettingsData.iconThemePerMode !== "undefined" ? SettingsData.iconThemePerMode : false
    readonly property string iconThemeDark: typeof SettingsData.iconThemeDark !== "undefined" ? SettingsData.iconThemeDark : (SettingsData.iconTheme || "System Default")
    readonly property string iconThemeLight: typeof SettingsData.iconThemeLight !== "undefined" ? SettingsData.iconThemeLight : (SettingsData.iconTheme || "System Default")
    readonly property bool pickedDuxIcons: dux22Icons && ((SettingsData.iconTheme || "") === "dux-icons" || (iconThemePerMode && (iconThemeDark === "dux-icons" || iconThemeLight === "dux-icons")))
    readonly property bool iconThemeSupportsFolderColor: (SettingsData.iconTheme || "").replace(/-DankFolders$/, "").indexOf("Papirus") === 0
    readonly property bool iconThemeDarkSupportsFolderColor: iconThemeDark.replace(/-DankFolders$/, "").indexOf("Papirus") === 0
    readonly property bool iconThemeLightSupportsFolderColor: iconThemeLight.replace(/-DankFolders$/, "").indexOf("Papirus") === 0
    readonly property var installedPapirusThemes: installedIconThemes.filter(function(name) {
        return name.indexOf("Papirus") === 0 && !name.endsWith("-DankFolders");
    })
    readonly property bool papirusInstalled: installedPapirusThemes.length > 0
    readonly property string preferredPapirusTheme: installedPapirusThemes.indexOf("Papirus-Dark") !== -1 ? "Papirus-Dark" : (installedPapirusThemes.indexOf("Papirus") !== -1 ? "Papirus" : (installedPapirusThemes[0] || ""))
    readonly property bool anyIconModeSupportsFolderColor: iconThemePerMode ? (iconThemeDarkSupportsFolderColor || iconThemeLightSupportsFolderColor) : iconThemeSupportsFolderColor
    readonly property string folderColorCapabilityReason: iconThemeSupportsFolderColor ? (iconThemePerMode ? "Ready in the current mode. Dark: " + iconThemeDark + "; light: " + iconThemeLight + "." : "ready") : (papirusInstalled ? "Papirus is installed, but the current " + (SessionData.isLightMode ? "light" : "dark") + " mode uses " + (SettingsData.iconTheme || "System Default") + "." : "Papirus is not installed.")
    readonly property bool hasDmsCursorThemes: typeof SettingsData !== "undefined" && Array.isArray(SettingsData.availableCursorThemes) && SettingsData.availableCursorThemes.some(function(name) {
        return name && name !== "System Default";
    })
    property var fallbackCursorThemes: [(SettingsData.cursorSettings && SettingsData.cursorSettings.theme) || "System Default"]
    readonly property var installedCursorThemes: root.mergeCurrentIntoList(hasDmsCursorThemes ? SettingsData.availableCursorThemes : fallbackCursorThemes, (SettingsData.cursorSettings && SettingsData.cursorSettings.theme) || "System Default")
    property string niriBorderModeValue: "off"
    property int niriBorderOpacityValue: 70
    property string niriBorderRoleValue: "secondary"
    property string niriBorderGradientToValue: "secondary"
    property string appSurfaceDepthValue: "dux"
    property string appSurfaceTintValue: "dux"
    // What the --probe-qt run found on this machine; drives the route
    // descriptions so the user picks between things that actually exist here.
    property string probeQt6ct: ""
    property string probeKvantum: ""
    property string probeGtk: ""
    property string probePair: ""
    property string probeNativePair: ""
    property string probeNativeMissing: ""
    property string qtSyncModeValue: "manual"
    property string qtPlatformThemeValue: "preserve"
    property string qtStyleValue: "Fusion"
    property var snapshots: []
    property var snapshotNames: ({
    })
    // Plugin-owned values. Loaded from / saved to plugin data directly so the
    // controls reflect the stored choice even before option lists finish loading.
    property string gtkThemeLightValue: "auto"
    property string gtkThemeDarkValue: "auto"
    property string documentFontValue: ""
    property string selectedSnapshot: ""
    property string snapshotActionStatus: ""
    property string flatpakDiagnosticStatus: "Not checked"
    property bool flatpakDiagnosticBusy: false
    property int regularFontSizeValue: 11
    property int monoFontSizeValue: 12
    property int documentFontSizeValue: 11
    property int backupRetentionValue: 10
    // Dux color themes, mirrored from the live Dux API. These act on Dux directly,
    // exactly like the Dux Settings "Theme" tab.
    readonly property var dmsThemeOptions: {
        const opts = [{
            "label": "Dynamic (Dux palette)",
            "value": "dynamic"
        }];
        // getAvailableThemes() can be empty while StockThemes is still being
        // initialised.  A function call does not expose that dependency to the
        // QML binding engine, so the expression would then stay empty for the
        // lifetime of this settings component.  These are the same stable
        // generic themes offered by Dux's native ThemeColorsTab.
        let names = (typeof Theme !== "undefined" && Theme.getAvailableThemes) ? Theme.getAvailableThemes() : [];
        if (!names || names.length === 0)
            names = ["blue", "purple", "green", "orange", "red", "cyan", "pink", "amber", "coral", "monochrome"];

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
    readonly property var qtSyncModeOptions: [{
        "label": "Manual — use the Qt applications options below",
        "value": "manual"
    }, {
        "label": "Automatic — visual fidelity with GTK",
        "value": "auto"
    }, {
        "label": "GTK–Qt twin theme (native Qt or Kvantum)",
        "value": "pair"
    }, {
        "label": "Kvantum rendered from the Dux palette",
        "value": "kvantum"
    }, {
        "label": "Dynamic wallpaper colors — Fusion (qt6ct-kde)",
        "value": "kcolorscheme"
    }, {
        "label": "Follow the GTK theme (gtk3)",
        "value": "gtk3"
    }]
    readonly property var qtPlatformThemeOptions: availableQtPlatformThemes.map(function(name) {
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
            "label": "Plugin sets Dux palette (qt5ct/qt6ct)",
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

        return {
            "label": name,
            "value": name
        };
    })
    readonly property var qtStyleOptions: availableQtStyles.map(function(name) {
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

        return {
            "label": name,
            "value": name
        };
    })
    // Same filter as Dux 2.0's own picker (MatugenPreviewService.schemeOptions):
    // the 2025 and Bold generators only take the spec2025 schemes, and
    // scheme-smart needs a matugen that reports smart support. Older shells
    // lack those fields, so the list stays whole there.
    readonly property var matugenSchemeOptions: {
        const all = (typeof Theme !== "undefined" && Theme.availableMatugenSchemes) ? Theme.availableMatugenSchemes : [];
        if (!root.dms20)
            return all;
        const smartSupported = typeof DMSService !== "undefined" && DMSService.matugenSmartSupported === true;
        return all.filter(function(o) {
            if (o.value === "scheme-smart" && !smartSupported)
                return false;
            return !root.modernSpec || o.spec2025 === true;
        });
    }
    readonly property var matugenSchemePreviewOptions: {
        if (typeof MatugenPreviewService !== "undefined" && MatugenPreviewService.schemeOptions && MatugenPreviewService.schemeOptions.length > 0)
            return MatugenPreviewService.schemeOptions;
        return matugenSchemeOptions;
    }
    readonly property var activeRegistryTheme: {
        const file = SettingsData.customThemeFile;
        if (Theme.currentThemeCategory !== "registry" || Theme.currentTheme !== "custom" || !file)
            return null;
        for (let i = 0; i < installedRegistryThemes.length; i++) {
            const t = installedRegistryThemes[i];
            if (file.endsWith((t.sourceDir || t.id) + "/theme.json"))
                return t;
        }
        return null;
    }
    readonly property var niriBorderModeOptions: [{
        "label": "Dux default (pure primary)",
        "value": "off"
    }, {
        "label": "Softened Dux primary (alpha)",
        "value": "soften"
    }, {
        "label": "Palette role (secondary / outline / container)",
        "value": "role"
    }, {
        "label": "Dynamic palette gradient (primary → role)",
        "value": "gradient"
    }]
    readonly property var niriBorderRoleOptions: [{
        "label": "Secondary",
        "value": "secondary",
        "color": Theme.secondary
    }, {
        "label": "Tertiary",
        "value": "tertiary",
        "color": Theme.tertiary
    }, {
        "label": "Outline",
        "value": "outline",
        "color": Theme.outline
    }, {
        "label": "Primary container",
        "value": "primary_container",
        "color": Theme.primaryContainer
    }, {
        "label": "Surface variant",
        "value": "surface_variant",
        "color": Theme.surfaceVariant
    }]
    readonly property var niriBorderGradientToOptions: [{
        "label": "Secondary",
        "value": "secondary",
        "color": Theme.secondary
    }, {
        "label": "Tertiary",
        "value": "tertiary",
        "color": Theme.tertiary
    }, {
        "label": "Primary container",
        "value": "primary_container",
        "color": Theme.primaryContainer
    }, {
        "label": "Outline",
        "value": "outline",
        "color": Theme.outline
    }]
    readonly property var appSurfaceDepthOptions: [{
        "label": "Dux default",
        "value": "dux"
    }, {
        "label": "Balanced (Adwaita / 2021)",
        "value": "balanced"
    }, {
        "label": "Charcoal (Breeze Dark)",
        "value": "charcoal"
    }, {
        "label": "Deep (OLED)",
        "value": "deep"
    }]
    readonly property var appSurfaceTintOptions: [{
        "label": "Dux default",
        "value": "dux",
        "color": Theme.surfaceContainer
    }, {
        "label": "Neutral (remove 2025 tint)",
        "value": "neutral",
        "color": "#88888c"
    }, {
        "label": "Subtle (soft accent wash)",
        "value": "subtle",
        "color": Theme.primaryContainer
    }, {
        "label": "Expressive (2025 style)",
        "value": "expressive",
        "color": Theme.primary
    }, {
        "label": "Secondary",
        "value": "secondary",
        "color": Theme.secondary
    }, {
        "label": "Tertiary",
        "value": "tertiary",
        "color": Theme.tertiary
    }]
    readonly property var shellButtonColorOptions: [{
        "label": "Primary",
        "value": "primary"
    }, {
        "label": "Primary Container",
        "value": "primaryContainer"
    }, {
        "label": "Secondary",
        "value": "secondary"
    }, {
        "label": "Surface Variant",
        "value": "surfaceVariant"
    }]
    readonly property var shellSurfaceColorOptions: [{
        "label": "Default",
        "value": "default"
    }, {
        "label": "Surface",
        "value": "s"
    }, {
        "label": "Surface Container",
        "value": "sc"
    }, {
        "label": "Surface High",
        "value": "sch"
    }, {
        "label": "Surface Highest",
        "value": "schh"
    }, {
        "label": "Inverse Surface",
        "value": "inverseSurface"
    }, {
        "label": "Primary Container",
        "value": "primaryContainer"
    }, {
        "label": "Secondary Container",
        "value": "secondaryContainer"
    }, {
        "label": "Tertiary Container",
        "value": "tertiaryContainer"
    }, {
        "label": "Custom",
        "value": "custom"
    }]
    readonly property var matugenSchemeLabels: matugenSchemeOptions.map(function(o) {
        return o.label;
    })
    readonly property var snapshotLabels: snapshots.map(function(id) {
        return root.formatSnapshot(id);
    })

    function mergeCurrentIntoList(list, currentValue) {
        const values = [];
        const seen = {};
        if (currentValue) {
            values.push(currentValue);
            seen[currentValue] = true;
        }
        if (Array.isArray(list)) {
            for (let i = 0; i < list.length; i++) {
                const v = list[i];
                if (v && !seen[v]) {
                    values.push(v);
                    seen[v] = true;
                }
            }
        }
        return values;
    }

    function iconThemeLabel(name) {
        return name === "dux-icons" ? "Dux Icons" : name;
    }

    function screenChoices() {
        const ids = [];
        const labels = [];
        const screens = Quickshell.screens || [];
        for (let i = 0; i < screens.length; i++) {
            const s = screens[i];
            if (!s || !s.name)
                continue;
            ids.push(s.name);
            labels.push(typeof SettingsData.getScreenDisplayName === "function" ? SettingsData.getScreenDisplayName(s) : s.name);
        }
        if (SettingsData.matugenTargetMonitor && ids.indexOf(SettingsData.matugenTargetMonitor) === -1) {
            ids.unshift(SettingsData.matugenTargetMonitor);
            labels.unshift(SettingsData.matugenTargetMonitor);
        }
        return {
            "ids": ids,
            "labels": labels
        };
    }

    function setAutoScheduleMode(mode) {
        if (mode === "wallpaper") {
            if (typeof SessionData !== "undefined" && SessionData.themeModeAutoEnabled && typeof SessionData.setThemeModeAutoEnabled === "function")
                SessionData.setThemeModeAutoEnabled(false);
            if (root.smartModeAvailable)
                SettingsData.setMatugenSmartMode(true);
            return;
        }
        if (mode === "time" || mode === "location") {
            if (root.smartModeAvailable && SettingsData.matugenSmartMode)
                SettingsData.setMatugenSmartMode(false);
            if (typeof SessionData !== "undefined") {
                if (typeof SessionData.setThemeModeAutoMode === "function")
                    SessionData.setThemeModeAutoMode(mode);
                if (typeof SessionData.setThemeModeAutoEnabled === "function")
                    SessionData.setThemeModeAutoEnabled(true);
            }
            return;
        }
        if (root.smartModeAvailable && SettingsData.matugenSmartMode)
            SettingsData.setMatugenSmartMode(false);
        if (typeof SessionData !== "undefined" && typeof SessionData.setThemeModeAutoEnabled === "function")
            SessionData.setThemeModeAutoEnabled(false);
    }

    function setNiriBorderMode(mode) {
        if (!mode || mode === root.niriBorderModeValue)
            return;
        root.niriBorderModeValue = mode;
        root.saveValue("niriBorderMode", mode);
        root.saveValue("dimNiriBorder", mode !== "off");
    }

    function colorMapFromOptions(opts) {
        const map = {};
        for (let i = 0; i < opts.length; i++) {
            if (opts[i].color !== undefined)
                map[opts[i].label] = opts[i].color;
            else if (typeof Theme.roleColor === "function")
                map[opts[i].label] = Theme.roleColor(opts[i].value);
        }
        return map;
    }

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
            else if (key === "native-pair")
                probeNativePair = value;
            else if (key === "native-missing")
                probeNativeMissing = value;
        }
    }

    function snapshotHelper() {
        return Paths.strip(Qt.resolvedUrl("scripts/theme-snapshot.sh").toString());
    }

    function flatpakDiagnosticHelper() {
        return Paths.strip(Qt.resolvedUrl("scripts/check-flatpak-overrides.sh").toString());
    }

    function parseFlatpakDiagnostic(text) {
        const lines = String(text || "").trim().split("\n");
        let status = "error";
        let count = 0;
        const apps = [];
        for (let i = 0; i < lines.length; i++) {
            if (lines[i].indexOf("STATUS=") === 0)
                status = lines[i].slice(7);
            else if (lines[i].indexOf("COUNT=") === 0)
                count = parseInt(lines[i].slice(6)) || 0;
            else if (lines[i].indexOf("APP=") === 0)
                apps.push(lines[i].slice(4).split("\t")[0]);
        }
        if (status === "clean")
            flatpakDiagnosticStatus = "No application-specific GTK_THEME overrides found.";
        else if (status === "unavailable")
            flatpakDiagnosticStatus = "Flatpak is not installed.";
        else if (status === "issues")
            flatpakDiagnosticStatus = count + " application-specific GTK_THEME override"
                + (count === 1 ? "" : "s") + ": " + apps.join(", ")
                + ". Review them in Flatseal or with flatpak override; nothing was changed.";
        else
            flatpakDiagnosticStatus = "The Flatpak override diagnostic could not complete.";
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
        qtPlatformThemeValue = String(root.loadValue("qtPlatformTheme", "preserve") || "preserve");
        qtStyleValue = String(root.loadValue("qtStyle", "Fusion") || "Fusion");
        documentFontValue = String(root.loadValue("documentFontFamily", "") || "");
        regularFontSizeValue = Number(root.loadValue("regularFontSize", 11)) || 11;
        monoFontSizeValue = Number(root.loadValue("monoFontSize", 12)) || 12;
        documentFontSizeValue = Number(root.loadValue("documentFontSize", 11)) || 11;
        backupRetentionValue = Number(root.loadValue("backupRetention", 10)) || 10;
        const legacyDim = root.loadValue("dimNiriBorder", false) === true;
        const savedBorderMode = String(root.loadValue("niriBorderMode", "") || "");
        niriBorderModeValue = (savedBorderMode === "off" || savedBorderMode === "soften" || savedBorderMode === "role" || savedBorderMode === "gradient") ? savedBorderMode : (legacyDim ? "soften" : "off");
        const savedOpacity = Number(root.loadValue("niriBorderOpacity", 70));
        niriBorderOpacityValue = (isFinite(savedOpacity) && savedOpacity >= 30 && savedOpacity <= 100) ? Math.round(savedOpacity) : 70;
        niriBorderRoleValue = String(root.loadValue("niriBorderRole", "secondary") || "secondary");
        niriBorderGradientToValue = String(root.loadValue("niriBorderGradientTo", "secondary") || "secondary");
        const savedSurfaceDepth = String(root.loadValue("appSurfaceDepth", "dux") || "dux");
        appSurfaceDepthValue = (savedSurfaceDepth === "balanced" || savedSurfaceDepth === "charcoal" || savedSurfaceDepth === "deep") ? savedSurfaceDepth : "dux";
        const savedSurfaceTint = String(root.loadValue("appSurfaceTint", "dux") || "dux");
        appSurfaceTintValue = (savedSurfaceTint === "neutral" || savedSurfaceTint === "subtle" || savedSurfaceTint === "expressive" || savedSurfaceTint === "secondary" || savedSurfaceTint === "tertiary") ? savedSurfaceTint : "dux";
    }

    function parseFonts(text) {
        const all = [];
        const mono = [];
        const seenAll = {};
        const seenMono = {};
        if (SettingsData.fontFamily) {
            all.push(SettingsData.fontFamily);
            seenAll[SettingsData.fontFamily] = true;
        }
        if (SettingsData.monoFontFamily) {
            mono.push(SettingsData.monoFontFamily);
            seenMono[SettingsData.monoFontFamily] = true;
        }
        const lines = (text || "").split("\n");
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i];
            const tab = line.indexOf("\t");
            if (tab === -1)
                continue;
            const spacing = line.slice(0, tab).trim();
            const family = line.slice(tab + 1).trim();
            if (!family)
                continue;
            if (!seenAll[family]) {
                all.push(family);
                seenAll[family] = true;
            }
            if ((spacing === "100" || spacing === "110") && !seenMono[family]) {
                mono.push(family);
                seenMono[family] = true;
            }
        }
        installedFonts = all;
        installedMonoFonts = mono;
    }

    function parseQtDiag(text) {
        let mode = "";
        let platText = "";
        let styleText = "";
        const lines = (text || "").split("\n");
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i].trim();
            if (line === "---PLATFORMS---") {
                mode = "platforms";
            } else if (line === "---STYLES---") {
                mode = "styles";
            } else if (line) {
                if (mode === "platforms")
                    platText += line + "\n";
                else if (mode === "styles")
                    styleText += line + "\n";
            }
        }
        availableQtPlatformThemes = parseQtPlatformThemes(platText);
        availableQtStyles = parseQtStyles(styleText);
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

    function selectIconTheme(value, lightMode) {
        const targetLight = lightMode === true;
        const canonical = targetLight ? iconThemeLight : iconThemeDark;
        if (!value || value === canonical)
            return ;

        requestedIconTheme = value;
        requestedIconThemeLight = targetLight;
        iconThemeValue = value;
        iconThemeSelectionStatus = "Applying " + value + "…";
        if (typeof SettingsData.setIconThemeForMode === "function")
            SettingsData.setIconThemeForMode(value, targetLight);
        else
            SettingsData.setIconTheme(value);
        iconThemeVerifyTimer.restart();
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
    // (plasma-integration) expects a running Plasma session, which a Dux desktop
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
    Component.onCompleted: {
        reloadPluginValues();
        if (typeof DMSService !== "undefined" && DMSService.dmsAvailable && typeof DMSService.listInstalledThemes === "function")
            DMSService.listInstalledThemes();
        if (typeof MatugenPreviewService !== "undefined" && typeof MatugenPreviewService.refresh === "function")
            MatugenPreviewService.refresh();
    }

    Connections {
        target: typeof MatugenPreviewService !== "undefined" ? MatugenPreviewService : null
        ignoreUnknownSignals: true

        function onKeyChanged() {
            if (typeof MatugenPreviewService !== "undefined" && typeof MatugenPreviewService.refresh === "function")
                MatugenPreviewService.refresh();
        }
    }

    Connections {
        target: typeof DMSService !== "undefined" ? DMSService : null
        ignoreUnknownSignals: true

        function onInstalledThemesReceived(themes) {
            root.installedRegistryThemes = Array.isArray(themes) ? themes : [];
        }
    }

    Timer {
        id: iconThemeVerifyTimer

        interval: 1200
        onTriggered: {
            const canonical = root.requestedIconThemeLight ? root.iconThemeLight : root.iconThemeDark;
            if (canonical === root.requestedIconTheme) {
                root.iconThemeValue = canonical;
                root.iconThemeSelectionStatus = "";
                return ;
            }
            root.iconThemeValue = canonical;
            root.iconThemeSelectionStatus = "Dux kept " + canonical + " instead of " + root.requestedIconTheme + ".";
            ToastService.showError("Icon theme was not changed", root.iconThemeSelectionStatus);
        }
    }

    Connections {
        function onIconThemeChanged() {
            root.iconThemeValue = SettingsData.iconTheme || "System Default";
        }

        target: SettingsData
    }

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
        command: ["sh", "-c", "fc-list --format='%{spacing}\t%{family[0]}\n' 2>/dev/null | LC_ALL=C sort -fu"]

        stdout: StdioCollector {
            onStreamFinished: root.parseFonts(text)
        }

    }

    Process {
        id: iconsProcess

        running: !root.hasDmsIconThemes
        command: ["sh", "-c", "for base in \"$HOME/.icons\" \"$HOME/.local/share/icons\" /usr/local/share/icons /usr/share/icons; do [ -d \"$base\" ] || continue; for dir in \"$base\"/*; do [ -f \"$dir/index.theme\" ] || continue; grep -q '^Directories=' \"$dir/index.theme\" || continue; basename \"$dir\"; done; done | grep -vxE 'default|hicolor|locolor' | LC_ALL=C sort -fu"]

        stdout: StdioCollector {
            onStreamFinished: root.fallbackIconThemes = root.parseSimpleList(text, SettingsData.iconTheme)
        }

    }

    Process {
        id: cursorsProcess

        running: !root.hasDmsCursorThemes
        command: ["sh", "-c", "for root in \"$HOME/.icons\" \"$HOME/.local/share/icons\" /usr/local/share/icons /usr/share/icons; do [ -d \"$root\" ] || continue; for dir in \"$root\"/*; do [ -d \"$dir/cursors\" ] && basename \"$dir\"; done; done | LC_ALL=C sort -fu"]

        stdout: StdioCollector {
            onStreamFinished: root.fallbackCursorThemes = root.parseSimpleList(text, SettingsData.cursorSettings && SettingsData.cursorSettings.theme)
        }

    }

    // Ask Qt once what it can load rather than spawning two separate qtdiag6 calls.
    Process {
        id: qtDiagProcess

        running: true
        command: ["sh", "-c", "out=\"\"; for q in \"$(command -v qtdiag6 2>/dev/null)\" /usr/lib/qt6/bin/qtdiag \"$(command -v qtdiag 2>/dev/null)\" /usr/lib/qt5/bin/qtdiag; do [ -x \"$q\" ] || continue; out=$(QT_QPA_PLATFORM=offscreen \"$q\" 2>/dev/null) && [ -n \"$out\" ] && break; done; echo '---PLATFORMS---'; printf '%s\n' \"$out\" | awk '/Platforms requested/{f=1;next} f&&/available/{sub(/.*: */,\"\");print;exit}' | tr ',' '\\n' | awk 'NF&&!seen[tolower($0)]++'; echo '---STYLES---'; printf '%s\n' \"$out\" | awk '/Styles requested/{f=1;next} f&&/available/{sub(/.*: */,\"\");print;exit}' | tr ',' '\\n' | awk 'NF&&!seen[tolower($0)]++'"]

        stdout: StdioCollector {
            onStreamFinished: root.parseQtDiag(text)
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

    Process {
        id: flatpakDiagnosticProcess

        running: false
        command: ["bash", root.flatpakDiagnosticHelper()]
        onRunningChanged: root.flatpakDiagnosticBusy = running

        stdout: StdioCollector {
            onStreamFinished: root.parseFlatpakDiagnostic(text)
        }

    }

    StyledText {
        width: parent.width
        text: "Dux Theme Sync"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "The controls below change Dux's theme, mode, palette, radii, fonts, icons and cursor. Theme Sync then carries the supported choices into GTK, Qt, KDE and other applications. Radii and layout stay in the shell; application themes keep their own geometry."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    SectionHeader {
        text: "Dux appearance"
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
            text: "Dux theme category and palette. 'Auto' derives dynamic Material colors from the wallpaper with Matugen."
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            wrapMode: Text.WordWrap
        }

        DButtonGroup {
            id: themeCategoryGroup

            readonly property int computedIndex: {
                if (Theme.currentThemeCategory === "registry")
                    return 3;
                if (Theme.currentThemeName === "dynamic")
                    return 1;
                if (Theme.currentThemeName === "custom")
                    return 2;
                return 0;
            }

            width: parent.width
            fillWidth: true
            arrowKeysSelect: false
            model: (typeof DMSService !== "undefined" && DMSService.dmsAvailable) ? ["Generic", "Auto", "Custom", "Registry"] : ["Generic", "Auto", "Custom"]
            currentIndex: computedIndex
            selectionMode: "single"
            onSelectionChanged: function(index, selected) {
                if (!selected || index === computedIndex)
                    return;
                if (index === 0)
                    Theme.switchThemeCategory("generic", "blue");
                else if (index === 1)
                    Theme.switchThemeCategory("dynamic", "dynamic");
                else if (index === 2)
                    Theme.switchThemeCategory("custom", "custom");
                else if (index === 3)
                    Theme.switchThemeCategory("registry", "");
            }
        }

        DDropdown {
            width: parent.width
            visible: Theme.currentThemeCategory !== "registry" && Theme.currentThemeName !== "dynamic" && Theme.currentThemeName !== "custom"
            currentValue: root.labelForValue(root.dmsThemeOptions, Theme.currentThemeName)
            options: root.dmsThemeLabels
            onValueChanged: function(value) {
                const themeName = root.valueForLabel(root.dmsThemeOptions, value);
                if (themeName && themeName !== Theme.currentThemeName)
                    Theme.switchTheme(themeName);
            }
        }

        Column {
            width: parent.width
            spacing: Theme.spacingS
            visible: Theme.currentThemeName === "custom" && Theme.currentThemeCategory !== "registry"

            StyledText {
                width: parent.width
                text: "Custom theme JSON path"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }

            Row {
                width: parent.width
                spacing: Theme.spacingS

                DTextField {
                    id: customThemePathField

                    width: parent.width - applyCustomThemeBtn.width - Theme.spacingS
                    placeholderText: "~/.config/dms/themes/my-theme/theme.json"
                    text: SettingsData.customThemeFile || ""
                    onAccepted: applyCustomThemeBtn.applyPath()
                }

                DButton {
                    id: applyCustomThemeBtn

                    function applyPath() {
                        const path = (customThemePathField.text || "").trim();
                        if (!path || path === SettingsData.customThemeFile)
                            return;
                        SettingsData.set("customThemeFile", path);
                        Theme.switchTheme("custom");
                    }

                    text: "Load"
                    iconName: "folder_open"
                    variant: "tonal"
                    anchors.verticalCenter: parent.verticalCenter
                    onClicked: applyPath()
                }
            }
        }

        Column {
            width: parent.width
            spacing: Theme.spacingS
            visible: Theme.currentThemeCategory === "registry"

            DDropdown {
                width: parent.width
                enableFuzzySearch: true
                emptyText: "No registry themes installed"
                currentValue: root.activeRegistryTheme ? (root.activeRegistryTheme.id || "") : ""
                options: root.installedRegistryThemes.map(function(t) {
                    return t.name || t.id;
                })
                optionValues: root.installedRegistryThemes.map(function(t) {
                    return t.id;
                })
                onValueChanged: function(themeId) {
                    for (let i = 0; i < root.installedRegistryThemes.length; i++) {
                        const t = root.installedRegistryThemes[i];
                        if (t.id === themeId) {
                            const nextFile = Quickshell.env("HOME") + "/.config/dms/themes/" + (t.sourceDir || t.id) + "/theme.json";
                            if (nextFile !== SettingsData.customThemeFile) {
                                SettingsData.set("customThemeFile", nextFile);
                                Theme.switchTheme("custom", true, true);
                            }
                            return;
                        }
                    }
                }
            }

            Column {
                id: registryVariantsBox

                readonly property var variants: root.activeRegistryTheme && root.activeRegistryTheme.hasVariants ? root.activeRegistryTheme.variants : null
                readonly property string themeId: root.activeRegistryTheme ? (root.activeRegistryTheme.id || "") : ""
                readonly property bool isMulti: !!(variants && variants.type === "multi")
                readonly property string modeKey: Theme.isLightMode ? "light" : "dark"
                readonly property var multiDefaults: (isMulti && variants && variants.defaults) ? (variants.defaults[modeKey] || variants.defaults.dark || {}) : {}
                readonly property var storedMulti: (isMulti && themeId && typeof SettingsData.getRegistryThemeMultiVariant === "function") ? SettingsData.getRegistryThemeMultiVariant(themeId, multiDefaults, modeKey) : multiDefaults
                readonly property var flavorList: {
                    if (!isMulti || !variants || !Array.isArray(variants.flavors))
                        return [];
                    return variants.flavors.filter(function(f) {
                        if (f.mode)
                            return f.mode === modeKey || f.mode === "both";
                        return !!f[modeKey];
                    });
                }
                readonly property string selectedFlavor: {
                    const sf = (storedMulti && storedMulti.flavor) || (multiDefaults && multiDefaults.flavor) || "";
                    for (let i = 0; i < flavorList.length; i++) {
                        if (flavorList[i].id === sf)
                            return sf;
                    }
                    return flavorList.length > 0 ? flavorList[0].id : sf;
                }
                readonly property string selectedAccent: (storedMulti && storedMulti.accent) || (multiDefaults && multiDefaults.accent) || ""
                readonly property string selectedVariant: (!isMulti && themeId && variants && typeof SettingsData.getRegistryThemeVariant === "function") ? SettingsData.getRegistryThemeVariant(themeId, variants["default"] || "") : ""

                width: parent.width
                spacing: Theme.spacingS
                visible: !!variants && ((isMulti && flavorList.length > 0) || (!isMulti && Array.isArray(variants.options) && variants.options.length > 0))

                DButtonGroup {
                    width: parent.width
                    visible: registryVariantsBox.isMulti && registryVariantsBox.flavorList.length > 1
                    fillWidth: true
                    arrowKeysSelect: false
                    model: registryVariantsBox.flavorList.map(function(f) {
                        return f.name;
                    })
                    currentIndex: {
                        for (let i = 0; i < registryVariantsBox.flavorList.length; i++) {
                            if (registryVariantsBox.flavorList[i].id === registryVariantsBox.selectedFlavor)
                                return i;
                        }
                        return 0;
                    }
                    selectionMode: "single"
                    onSelectionChanged: function(index, selected) {
                        if (!selected || index < 0 || index >= registryVariantsBox.flavorList.length)
                            return;
                        const nextFlavor = registryVariantsBox.flavorList[index].id;
                        if (nextFlavor && nextFlavor !== registryVariantsBox.selectedFlavor) {
                            Theme.screenTransition();
                            SettingsData.setRegistryThemeMultiVariant(registryVariantsBox.themeId, nextFlavor, registryVariantsBox.selectedAccent, registryVariantsBox.modeKey);
                        }
                    }
                }

                Flow {
                    width: parent.width
                    spacing: Theme.spacingS
                    visible: registryVariantsBox.isMulti && registryVariantsBox.variants && Array.isArray(registryVariantsBox.variants.accents) && registryVariantsBox.variants.accents.length > 0

                    Repeater {
                        model: (registryVariantsBox.variants && registryVariantsBox.variants.accents) || []

                        StyledRect {
                            required property var modelData
                            readonly property bool active: modelData.id === registryVariantsBox.selectedAccent

                            width: 30
                            height: 30
                            radius: 15
                            border.width: active ? 2 : 0
                            border.color: Theme.primary

                            DColorSwatch {
                                anchors.centerIn: parent
                                width: 24
                                height: 24
                                swatchColor: modelData.color || (modelData[registryVariantsBox.selectedFlavor] && modelData[registryVariantsBox.selectedFlavor].primary) || Theme.primary
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (!active) {
                                        Theme.screenTransition();
                                        SettingsData.setRegistryThemeMultiVariant(registryVariantsBox.themeId, registryVariantsBox.selectedFlavor, modelData.id, registryVariantsBox.modeKey);
                                    }
                                }
                            }
                        }
                    }
                }

                DDropdown {
                    width: parent.width
                    visible: !registryVariantsBox.isMulti && registryVariantsBox.variants && Array.isArray(registryVariantsBox.variants.options) && registryVariantsBox.variants.options.length > 0
                    currentValue: registryVariantsBox.selectedVariant
                    options: (registryVariantsBox.variants && registryVariantsBox.variants.options) ? registryVariantsBox.variants.options.map(function(v) {
                        return v.name;
                    }) : []
                    optionValues: (registryVariantsBox.variants && registryVariantsBox.variants.options) ? registryVariantsBox.variants.options.map(function(v) {
                        return v.id;
                    }) : []
                    onValueChanged: function(variantId) {
                        if (variantId && variantId !== registryVariantsBox.selectedVariant) {
                            Theme.screenTransition();
                            SettingsData.setRegistryThemeVariant(registryVariantsBox.themeId, variantId);
                        }
                    }
                }
            }
        }

    }

    DToggle {
        width: parent.width
        text: "Light mode"
        description: "Use the light variant instead of dark. Dux stays the source of truth for the mode."
        checked: SessionData.isLightMode
        onToggled: function(isChecked) {
            if (isChecked === SessionData.isLightMode)
                return;

            Theme.screenTransition();
            Theme.setLightMode(isChecked);
        }
    }

    Column {
        width: parent.width
        spacing: Theme.spacingS
        visible: typeof SessionData !== "undefined" && typeof SessionData.setThemeModeAutoEnabled === "function"

        StyledText {
            text: "Automatic mode control"
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.Medium
            color: Theme.surfaceText
        }

        StyledText {
            width: parent.width
            text: (root.autoScheduleMode === "time" || root.autoScheduleMode === "location") && SessionData.themeModeNextTransition ? "Next transition: " + SessionData.themeModeNextTransition : "Choose whether Dux switches light/dark manually, on a schedule, by location, or from the wallpaper."
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            wrapMode: Text.WordWrap
        }

        DButtonGroup {
            width: parent.width
            fillWidth: true
            arrowKeysSelect: false
            model: root.autoScheduleLabels
            currentIndex: Math.max(0, root.autoScheduleModes.indexOf(root.autoScheduleMode))
            selectionMode: "single"
            onSelectionChanged: function(index, selected) {
                if (!selected || index < 0 || index >= root.autoScheduleModes.length)
                    return;
                const next = root.autoScheduleModes[index];
                if (next !== root.autoScheduleMode)
                    root.setAutoScheduleMode(next);
            }
        }
    }

    Column {
        width: parent.width
        spacing: Theme.spacingS
        visible: root.specControlAvailable && root.isDynamicTheme

        StyledText {
            text: "Material palette"
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.Medium
            color: Theme.surfaceText
        }

        StyledText {
            width: parent.width
            text: root.dms20 ? "Standard is Material 2021, Expressive is Material 2025, and Bold raises the accent chroma on Dux's 2025 generator. This decides how Dux generates dynamic colors; Theme Sync follows the resulting palette and never re-generates it." : "Standard uses Material 2021; Expressive uses Material 2025. This selects how Dux generates dynamic colors. Theme Sync follows the resulting palette; it does not copy Dux layout, shapes or animations into applications."
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            wrapMode: Text.WordWrap
        }

        DButtonGroup {
            width: parent.width
            fillWidth: true
            arrowKeysSelect: false
            model: root.specLabels
            currentIndex: root.specIndex
            selectionMode: "single"
            onSelectionChanged: function(index, selected) {
                if (!selected || index < 0 || index >= root.specOptions.length)
                    return;
                const spec = root.specOptions[index].value;
                if (spec && spec !== SettingsData.matugenSpec)
                    SettingsData.setMatugenSpec(spec);
            }
        }
    }

    Column {
        width: parent.width
        spacing: Theme.spacingS
        visible: typeof Theme !== "undefined" && Theme.matugenAvailable && root.isDynamicTheme
        opacity: visible ? 1 : 0.4

        StyledText {
            text: "Matugen palette"
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.Medium
            color: Theme.surfaceText
        }

        StyledText {
            width: parent.width
            text: (typeof Theme.getMatugenScheme === "function" && Theme.getMatugenScheme(SettingsData.matugenScheme)) ? (Theme.getMatugenScheme(SettingsData.matugenScheme).description + " (" + SettingsData.matugenScheme + ")") : "Algorithm used to generate the dynamic palette."
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            wrapMode: Text.WordWrap
        }

        ThemeSyncPaletteGrid {
            width: parent.width
            options: root.matugenSchemePreviewOptions
            currentValue: SettingsData.matugenScheme
            ready: typeof MatugenPreviewService === "undefined" || MatugenPreviewService.ready
            onSelected: function(scheme) {
                if (scheme && scheme !== SettingsData.matugenScheme)
                    SettingsData.setMatugenScheme(scheme);
            }
        }

    }

    Column {
        width: parent.width
        spacing: Theme.spacingS
        visible: root.sourceModeAvailable && root.isDynamicTheme
        opacity: (root.customSeed || !Theme.rawWallpaperPath) ? 0.5 : 1

        StyledText {
            text: "Source color"
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.Medium
            color: Theme.surfaceText
        }

        StyledText {
            width: parent.width
            text: root.customSeed ? "Dux is deriving the palette from a custom derived color, so the wallpaper source is ignored until cleared." : (!Theme.rawWallpaperPath ? "No wallpaper image active (using Material wallpaper seed); set an image wallpaper to pick an extraction mode." : "Which wallpaper color the palette is built from. Dux owns the extraction; Theme Sync mirrors and updates the choice.")
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            wrapMode: Text.WordWrap
        }

        DDropdown {
            width: parent.width
            enabled: !root.customSeed && !!Theme.rawWallpaperPath
            currentValue: root.sourceModeLabel
            options: root.sourceModeLabels
            onValueChanged: function(value) {
                for (let i = 0; i < root.sourceModeOptions.length; i++) {
                    if (root.sourceModeOptions[i].label === value && root.sourceModeOptions[i].value !== SettingsData.matugenSourceMode) {
                        SettingsData.setMatugenSourceMode(root.sourceModeOptions[i].value);
                        return;
                    }
                }
            }
        }

    }

    ThemeSyncColorPickerRow {
        width: parent.width
        visible: root.seedColorAvailable && root.isDynamicTheme && typeof Theme !== "undefined" && Theme.matugenAvailable
        text: "Derived color"
        description: root.customSeed ? "Custom builds the palette from a color you pick instead of extracting from the wallpaper." : "Choose 'Custom' to pick any seed color in place of the wallpaper color."
        pickerTitle: "Derived seed color"
        options: [{
            "label": Theme.rawWallpaperPath ? "From wallpaper" : "Material",
            "value": "default",
            "previewColor": root.defaultSeedColor
        }, {
            "label": "Custom",
            "value": "custom"
        }]
        currentMode: root.customSeed ? "custom" : "default"
        customColor: root.customSeed ? SettingsData.matugenSeedColor : root.defaultSeedColor
        defaultColor: root.defaultSeedColor
        showReset: root.customSeed
        resetTooltip: "Use the wallpaper color again"
        onResetRequested: SettingsData.setMatugenSeedColor("")
        onModeSelected: function(mode) {
            if (mode !== "custom") {
                if (SettingsData.matugenSeedColor)
                    SettingsData.setMatugenSeedColor("");
                return;
            }
            if (!SettingsData.matugenSeedColor)
                SettingsData.setMatugenSeedColor(String(root.defaultSeedColor));
        }
        onCustomColorSelected: function(selectedColor) {
            const hex = typeof Theme.withAlpha === "function" ? String(Theme.withAlpha(selectedColor, 1)) : String(selectedColor);
            if (hex !== SettingsData.matugenSeedColor)
                SettingsData.setMatugenSeedColor(hex);
        }
    }

    Column {
        width: parent.width
        spacing: Theme.spacingS
        visible: typeof Theme !== "undefined" && Theme.matugenAvailable && root.isDynamicTheme
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

            DActionButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                iconName: "restart_alt"
                tooltipText: "Reset to default (0%)"
                onClicked: {
                    matugenContrastSlider.value = 0;
                    SettingsData.setMatugenContrast(0);
                }
            }

        }

        StyledText {
            width: parent.width
            text: root.modernSpec ? "Contrast of generated colors (0 standard to 100 maximum for Material 2025 and Bold)" : "Contrast of generated colors (-100 minimum, 0 standard, 100 maximum)"
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            wrapMode: Text.WordWrap
        }

        DSlider {
            id: matugenContrastSlider

            width: parent.width
            minimum: root.modernSpec ? 0 : -100
            maximum: 100
            unit: "%"
            wheelEnabled: false
            value: Math.round((SettingsData.matugenContrast || 0) * 100)
            onSliderDragFinished: function(finalValue) {
                const clamped = root.modernSpec ? Math.max(0, finalValue) : finalValue;
                if (Math.abs((clamped / 100) - (SettingsData.matugenContrast || 0)) > 0.001)
                    SettingsData.setMatugenContrast(clamped / 100);
                if (clamped !== finalValue)
                    matugenContrastSlider.value = clamped;
            }
        }

    }

    Column {
        readonly property var choices: root.screenChoices()

        width: parent.width
        spacing: Theme.spacingS
        visible: root.targetMonitorAvailable && root.isDynamicTheme && (choices.ids.length > 1 || !!SettingsData.matugenTargetMonitor)

        StyledText {
            text: "Matugen source display"
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.Medium
            color: Theme.surfaceText
        }

        StyledText {
            width: parent.width
            text: "Theme colors come from this display's wallpaper when separate per-display wallpapers are used."
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            wrapMode: Text.WordWrap
        }

        DDropdown {
            width: parent.width
            options: parent.choices.labels
            optionValues: parent.choices.ids
            currentValue: SettingsData.matugenTargetMonitor || (parent.choices.ids.length > 0 ? parent.choices.ids[0] : "")
            onValueChanged: function(screenId) {
                if (screenId && screenId !== SettingsData.matugenTargetMonitor)
                    SettingsData.setMatugenTargetMonitor(screenId);
            }
        }
    }

    DToggle {
        width: parent.width
        visible: root.generateAtStartupAvailable && typeof Theme !== "undefined" && Theme.matugenAvailable
        text: "Generate theme at startup"
        description: "Regenerate Matugen colors when Dux starts, even if nothing changed."
        checked: root.generateAtStartupAvailable ? SettingsData.generateThemeAtStartup : false
        onToggled: function(isChecked) {
            if (isChecked !== SettingsData.generateThemeAtStartup)
                SettingsData.set("generateThemeAtStartup", isChecked);
        }
    }

    Column {
        width: parent.width
        spacing: Theme.spacingS
        visible: root.terminalPaletteAvailable

        StyledText {
            text: "Terminal ANSI palette"
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.Medium
            color: Theme.surfaceText
        }

        StyledText {
            width: parent.width
            text: "Controls Dux's dank16 ANSI color generator for Kitty, Foot, Alacritty, Ghostty, WezTerm and other terminal templates. 'Tonal' keeps red, green, yellow, blue, magenta and cyan distinct for git diffs and syntax highlighting; 'Vibrant' shifts all ANSI accents toward the primary wallpaper color."
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            wrapMode: Text.WordWrap
        }

        DDropdown {
            width: parent.width
            currentValue: root.labelForValue(root.terminalPaletteOptions, SettingsData.terminalPalette || "default")
            options: root.terminalPaletteLabels
            onValueChanged: function(value) {
                const mode = root.valueForLabel(root.terminalPaletteOptions, value);
                if (mode && mode !== SettingsData.terminalPalette) {
                    if (typeof SettingsData.setTerminalPalette === "function")
                        SettingsData.setTerminalPalette(mode);
                    else
                        SettingsData.set("terminalPalette", mode);
                }
            }
        }

    }

    Column {
        width: parent.width
        spacing: Theme.spacingS
        visible: root.terminalOpacityAvailable && typeof Theme !== "undefined" && Theme.matugenAvailable

        Item {
            width: parent.width
            height: terminalOpacityTitle.implicitHeight

            StyledText {
                id: terminalOpacityTitle

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Terminal opacity"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            DActionButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                iconName: "restart_alt"
                tooltipText: "Reset to default (100%)"
                onClicked: {
                    terminalOpacitySlider.value = 100;
                    if (SettingsData.terminalOpacity !== 100)
                        SettingsData.set("terminalOpacity", 100);
                }
            }
        }

        DSlider {
            id: terminalOpacitySlider

            width: parent.width
            minimum: 10
            maximum: 100
            unit: "%"
            wheelEnabled: false
            value: root.terminalOpacityAvailable ? SettingsData.terminalOpacity : 100
            onSliderDragFinished: function(finalValue) {
                if (finalValue !== SettingsData.terminalOpacity)
                    SettingsData.set("terminalOpacity", finalValue);
            }
        }
    }

    DToggle {
        width: parent.width
        visible: root.terminalsAlwaysDarkAvailable
        text: "Terminals always dark"
        description: "Keep Dux's generated terminal templates in dark mode even when the desktop uses light mode."
        checked: root.terminalsAlwaysDarkAvailable ? SettingsData.terminalsAlwaysDark : false
        onToggled: function(isChecked) {
            if (isChecked !== SettingsData.terminalsAlwaysDark)
                SettingsData.set("terminalsAlwaysDark", isChecked);
        }
    }

    DToggle {
        width: parent.width
        visible: root.syncModeWithPortalAvailable
        text: "Sync mode with desktop portal"
        description: "Keep light and dark mode synchronized with the XDG desktop portal color-scheme."
        checked: root.syncModeWithPortalAvailable ? SettingsData.syncModeWithPortal : false
        onToggled: function(isChecked) {
            if (isChecked !== SettingsData.syncModeWithPortal)
                SettingsData.set("syncModeWithPortal", isChecked);
        }
    }

    SectionHeader {
        text: "Dux shapes & surfaces"
    }

    Column {
        width: parent.width
        spacing: Theme.spacingS
        visible: root.interfaceStyleAvailable

        StyledText {
            text: "Interface style"
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.Medium
            color: Theme.surfaceText
        }

        StyledText {
            width: parent.width
            text: "Dux 2.1 shell chrome style. 'Expressive' enables pill controls and press shape-morphing; 'Classic' uses standard rounded controls, stacked settings cards and defaults to a fixed corner radius."
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            wrapMode: Text.WordWrap
        }

        DDropdown {
            width: parent.width
            currentValue: SettingsData.interfaceStyle === "classic" ? "Classic" : "Expressive"
            options: ["Expressive", "Classic"]
            onValueChanged: function(value) {
                const style = value === "Classic" ? "classic" : "expressive";
                if (style !== SettingsData.interfaceStyle) {
                    if (typeof SettingsData.setInterfaceStyle === "function")
                        SettingsData.setInterfaceStyle(style);
                    else
                        SettingsData.set("interfaceStyle", style);
                }
            }
        }

    }

    Column {
        width: parent.width
        spacing: Theme.spacingS
        visible: root.densityAvailable

        StyledText {
            text: "Interface density"
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.Medium
            color: Theme.surfaceText
        }

        StyledText {
            width: parent.width
            text: "Spacing and control height inside Dux 2.1 panels and modals. Does not alter GTK or Qt application padding."
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            wrapMode: Text.WordWrap
        }

        DDropdown {
            width: parent.width
            currentValue: root.labelForValue(root.densityOptions, SettingsData.density || "comfortable")
            options: root.densityLabels
            onValueChanged: function(value) {
                const d = root.valueForLabel(root.densityOptions, value);
                if (d && d !== SettingsData.density) {
                    if (typeof SettingsData.setDensity === "function")
                        SettingsData.setDensity(d);
                    else
                        SettingsData.set("density", d);
                }
            }
        }

    }

    Column {
        width: parent.width
        spacing: Theme.spacingS
        visible: root.interfaceStyleAvailable && root.sectionDividerAvailable && SettingsData.interfaceStyle === "classic"

        StyledText {
            text: "Section dividers"
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.Medium
            color: Theme.surfaceText
        }

        DSlider {
            width: parent.width
            minimum: 0
            maximum: 40
            unit: "%"
            wheelEnabled: false
            value: Math.round((SettingsData.sectionDividerOpacity !== undefined ? SettingsData.sectionDividerOpacity : 0.12) * 100)
            onSliderDragFinished: function(finalValue) {
                const nextOpacity = finalValue / 100;
                if (typeof SettingsData.setSectionDividerOpacity === "function")
                    SettingsData.setSectionDividerOpacity(nextOpacity);
                else
                    SettingsData.set("sectionDividerOpacity", nextOpacity);
            }
        }

    }

    Column {
        width: parent.width
        spacing: Theme.spacingS
        visible: root.radiusAvailable

        StyledText {
            text: "Corner style"
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.Medium
            color: Theme.surfaceText
        }

        StyledText {
            width: parent.width
            text: "Dux 2.0 can scale Material shapes or pin one radius. These controls write the same settings as Dux Interface style; GTK and Qt keep their own theme radii, so nothing here is exported to applications."
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            wrapMode: Text.WordWrap
        }

        DDropdown {
            width: parent.width
            currentValue: root.fixedRadiusMode ? "Fixed radius" : "Material scale"
            options: ["Material scale", "Fixed radius"]
            onValueChanged: function(value) {
                const mode = value === "Fixed radius" ? "fixed" : "scale";
                if (mode !== SettingsData.radiusMode)
                    SettingsData.set("radiusMode", mode);

            }
        }

        Item {
            width: parent.width
            height: radiusStrengthTitle.implicitHeight
            visible: !root.fixedRadiusMode

            StyledText {
                id: radiusStrengthTitle

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Radius strength"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

        }

        DSlider {
            width: parent.width
            visible: !root.fixedRadiusMode
            minimum: 0
            maximum: 100
            unit: "%"
            wheelEnabled: false
            value: SettingsData.radiusStrength
            onSliderDragFinished: function(finalValue) {
                if (finalValue !== SettingsData.radiusStrength)
                    SettingsData.set("radiusStrength", finalValue);

            }
        }

        Item {
            width: parent.width
            height: fixedRadiusTitle.implicitHeight
            visible: root.fixedRadiusMode

            StyledText {
                id: fixedRadiusTitle

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Corner radius"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

        }

        DSlider {
            width: parent.width
            visible: root.fixedRadiusMode
            minimum: 0
            maximum: 32
            unit: "px"
            wheelEnabled: false
            value: SettingsData.fixedRadius
            onSliderDragFinished: function(finalValue) {
                if (finalValue !== SettingsData.fixedRadius)
                    SettingsData.set("fixedRadius", finalValue);

            }
        }

    }

    Column {
        width: parent.width
        spacing: Theme.spacingS
        visible: root.screenCornersAvailable

        DToggle {
            width: parent.width
            text: "Rounded screen corners"
            description: "Draw rounded corner masks at the outer edges of each display (Dux shell overlay; independent of window radii)."
            checked: !!SettingsData.screenCornersEnabled
            onToggled: function(isChecked) {
                if (isChecked !== SettingsData.screenCornersEnabled)
                    SettingsData.set("screenCornersEnabled", isChecked);
            }
        }

        StyledText {
            visible: !!SettingsData.screenCornersEnabled
            text: "Screen corner radius"
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
        }

        DSlider {
            width: parent.width
            visible: !!SettingsData.screenCornersEnabled
            minimum: 4
            maximum: 64
            unit: "px"
            wheelEnabled: false
            value: SettingsData.screenCornerRadius !== undefined ? SettingsData.screenCornerRadius : 16
            onSliderDragFinished: function(finalValue) {
                if (finalValue !== SettingsData.screenCornerRadius)
                    SettingsData.set("screenCornerRadius", finalValue);
            }
        }

        DToggle {
            width: parent.width
            visible: !!SettingsData.screenCornersEnabled && typeof SettingsData.screenCornersOverFullscreen !== "undefined"
            text: "Over fullscreen"
            description: "Keep the rounded screen-corner overlay above fullscreen windows."
            checked: !!SettingsData.screenCornersOverFullscreen
            onToggled: function(isChecked) {
                if (isChecked !== SettingsData.screenCornersOverFullscreen)
                    SettingsData.set("screenCornersOverFullscreen", isChecked);
            }
        }

    }

    Column {
        width: parent.width
        spacing: Theme.spacingS
        visible: typeof SettingsData.containerSaturation !== "undefined"

        Item {
            width: parent.width
            height: containerSaturationTitle.implicitHeight

            StyledText {
                id: containerSaturationTitle

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Container saturation"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            DActionButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                iconName: "restart_alt"
                tooltipText: "Reset to default (100%)"
                onClicked: {
                    containerSaturationSlider.value = 100;
                    SettingsData.set("containerSaturation", 100);
                }
            }

        }

        StyledText {
            width: parent.width
            text: "Strength of Dux's tinted container surfaces across cards, badges and highlights (0% neutral – 200% vivid)."
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            wrapMode: Text.WordWrap
        }

        DSlider {
            id: containerSaturationSlider

            width: parent.width
            minimum: 0
            maximum: 200
            step: 5
            unit: "%"
            wheelEnabled: false
            value: SettingsData.containerSaturation
            onSliderDragFinished: function(finalValue) {
                if (finalValue !== SettingsData.containerSaturation)
                    SettingsData.set("containerSaturation", finalValue);
            }
        }

    }

    Column {
        width: parent.width
        spacing: Theme.spacingS
        visible: typeof SettingsData.buttonColorMode !== "undefined"

        StyledText {
            text: "Button color"
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.Medium
            color: Theme.surfaceText
        }

        StyledText {
            width: parent.width
            text: "Palette role used for primary action buttons across Dux shell surfaces."
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            wrapMode: Text.WordWrap
        }

        DDropdown {
            width: parent.width
            currentValue: root.labelForValue(root.shellButtonColorOptions, SettingsData.buttonColorMode || "primary")
            options: root.shellButtonColorOptions.map(function(o) {
                return o.label;
            })
            optionColorMap: root.colorMapFromOptions(root.shellButtonColorOptions)
            onValueChanged: function(label) {
                const mode = root.valueForLabel(root.shellButtonColorOptions, label);
                if (mode && mode !== SettingsData.buttonColorMode)
                    SettingsData.set("buttonColorMode", mode);
            }
        }

    }

    Column {
        width: parent.width
        spacing: Theme.spacingS
        visible: typeof SettingsData.controlCenterTileColorMode !== "undefined"

        StyledText {
            text: "Control Center tile color"
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.Medium
            color: Theme.surfaceText
        }

        StyledText {
            width: parent.width
            text: "Palette role used for active tiles inside Dux Control Center."
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            wrapMode: Text.WordWrap
        }

        DDropdown {
            width: parent.width
            currentValue: root.labelForValue(root.shellButtonColorOptions, SettingsData.controlCenterTileColorMode || "primary")
            options: root.shellButtonColorOptions.map(function(o) {
                return o.label;
            })
            optionColorMap: root.colorMapFromOptions(root.shellButtonColorOptions)
            onValueChanged: function(label) {
                const mode = root.valueForLabel(root.shellButtonColorOptions, label);
                if (mode && mode !== SettingsData.controlCenterTileColorMode)
                    SettingsData.set("controlCenterTileColorMode", mode);
            }
        }

    }

    Column {
        width: parent.width
        spacing: Theme.spacingS
        visible: root.surfaceRolesAvailable

        DButton {
            variant: "tonal"
            iconName: root.showSurfaceRoles ? "expand_less" : "expand_more"
            text: root.showSurfaceRoles ? "Hide surface color roles" : "Customize surface color roles (5)"
            onClicked: root.showSurfaceRoles = !root.showSurfaceRoles
        }

        Column {
            width: parent.width
            spacing: Theme.spacingM
            visible: root.showSurfaceRoles

            ThemeSyncColorPickerRow {
                text: "Host surface"
                description: "Base background role for bars, panels and shell containers."
                options: root.shellSurfaceColorOptions
                currentMode: SettingsData.hostSurfaceColor || "default"
                customColor: Qt.color(SettingsData.hostSurfaceCustomColor || "#6750A4")
                defaultColor: typeof Theme.surfaceLadder !== "undefined" ? Theme.surfaceLadder.host : Theme.surface
                pickerTitle: "Host surface custom color"
                showReset: (SettingsData.hostSurfaceColor || "default") !== "default"
                onModeSelected: function(mode) {
                    SettingsData.set("hostSurfaceColor", mode);
                }
                onCustomColorSelected: function(c) {
                    SettingsData.set("hostSurfaceCustomColor", c.toString());
                }
                onResetRequested: function() {
                    SettingsData.set("hostSurfaceColor", "default");
                }
            }

            ThemeSyncColorPickerRow {
                text: "Card surface"
                description: "Elevated cards inside Dux settings and modal views."
                options: root.shellSurfaceColorOptions
                currentMode: SettingsData.cardSurfaceColor || "default"
                customColor: Qt.color(SettingsData.cardSurfaceCustomColor || "#6750A4")
                defaultColor: typeof Theme.surfaceLadder !== "undefined" ? Theme.surfaceLadder.card : Theme.surfaceContainer
                pickerTitle: "Card surface custom color"
                showReset: (SettingsData.cardSurfaceColor || "default") !== "default"
                onModeSelected: function(mode) {
                    SettingsData.set("cardSurfaceColor", mode);
                }
                onCustomColorSelected: function(c) {
                    SettingsData.set("cardSurfaceCustomColor", c.toString());
                }
                onResetRequested: function() {
                    SettingsData.set("cardSurfaceColor", "default");
                }
            }

            ThemeSyncColorPickerRow {
                text: "Chip surface"
                description: "Dropdown triggers, fields and secondary control fills."
                options: root.shellSurfaceColorOptions
                currentMode: SettingsData.chipSurfaceColor || "default"
                customColor: Qt.color(SettingsData.chipSurfaceCustomColor || "#6750A4")
                defaultColor: typeof Theme.surfaceLadder !== "undefined" ? Theme.surfaceLadder.chip : Theme.surfaceContainerHigh
                pickerTitle: "Chip surface custom color"
                showReset: (SettingsData.chipSurfaceColor || "default") !== "default"
                onModeSelected: function(mode) {
                    SettingsData.set("chipSurfaceColor", mode);
                }
                onCustomColorSelected: function(c) {
                    SettingsData.set("chipSurfaceCustomColor", c.toString());
                }
                onResetRequested: function() {
                    SettingsData.set("chipSurfaceColor", "default");
                }
            }

            ThemeSyncColorPickerRow {
                visible: typeof SettingsData.chipSurfaceNestedColor !== "undefined"
                text: "Nested chip surface"
                description: "Chips nested inside elevated surface cards."
                options: root.shellSurfaceColorOptions
                currentMode: SettingsData.chipSurfaceNestedColor || "default"
                customColor: Qt.color(SettingsData.chipSurfaceNestedCustomColor || "#6750A4")
                defaultColor: typeof Theme.surfaceLadder !== "undefined" && Theme.surfaceLadder.chipNested !== undefined ? Theme.surfaceLadder.chipNested : Theme.surfaceContainerHighest
                pickerTitle: "Nested chip custom color"
                showReset: (SettingsData.chipSurfaceNestedColor || "default") !== "default"
                onModeSelected: function(mode) {
                    SettingsData.set("chipSurfaceNestedColor", mode);
                }
                onCustomColorSelected: function(c) {
                    SettingsData.set("chipSurfaceNestedCustomColor", c.toString());
                }
                onResetRequested: function() {
                    SettingsData.set("chipSurfaceNestedColor", "default");
                }
            }

            ThemeSyncColorPickerRow {
                visible: typeof SettingsData.tooltipSurfaceColor !== "undefined"
                text: "Tooltip surface"
                description: "Floating tooltips and rich hover popups."
                options: root.shellSurfaceColorOptions
                currentMode: SettingsData.tooltipSurfaceColor || "default"
                customColor: Qt.color(SettingsData.tooltipSurfaceCustomColor || "#6750A4")
                defaultColor: Theme.inverseSurface
                pickerTitle: "Tooltip surface custom color"
                showReset: (SettingsData.tooltipSurfaceColor || "default") !== "default"
                onModeSelected: function(mode) {
                    SettingsData.set("tooltipSurfaceColor", mode);
                }
                onCustomColorSelected: function(c) {
                    SettingsData.set("tooltipSurfaceCustomColor", c.toString());
                }
                onResetRequested: function() {
                    SettingsData.set("tooltipSurfaceColor", "default");
                }
            }

        }

    }

    SectionHeader {
        text: "Fonts, icons and cursor"
    }

    StyledText {
        width: parent.width
        text: "Font weight comes from Dux and is converted to Qt's legacy scale for Qt and KDE applications; GTK keeps the family and size. Dux's UI font scale can also multiply the point sizes below when 'Scale app fonts with Dux's font scale' is enabled."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
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
            text: "Updates the canonical Dux regular font"
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            wrapMode: Text.WordWrap
        }

        DDropdown {
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
            text: "Updates the canonical Dux monospace font"
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            wrapMode: Text.WordWrap
        }

        DDropdown {
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
            text: "Choose an installed family or follow the regular Dux font"
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            wrapMode: Text.WordWrap
        }

        DDropdown {
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
        visible: root.duxFontWeightAvailable

        Item {
            width: parent.width
            height: duxFontWeightTitle.implicitHeight

            StyledText {
                id: duxFontWeightTitle

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Font weight"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            DActionButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                iconName: "restart_alt"
                tooltipText: "Reset to default (Regular / 400)"
                onClicked: {
                    duxFontWeightSlider.value = Font.Normal;
                    SettingsData.set("fontWeight", Font.Normal);
                }
            }

        }

        StyledText {
            width: parent.width
            text: "Dux font weight (100 Thin – 900 Black); also propagated to Qt and KDE font strings."
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            wrapMode: Text.WordWrap
        }

        DSlider {
            id: duxFontWeightSlider

            width: parent.width
            minimum: Font.Thin
            maximum: Font.Black
            step: 100
            showStops: true
            unit: ""
            wheelEnabled: false
            value: SettingsData.fontWeight
            onSliderDragFinished: function(finalValue) {
                if (finalValue !== SettingsData.fontWeight)
                    SettingsData.set("fontWeight", finalValue);
            }
        }

    }

    Column {
        width: parent.width
        spacing: Theme.spacingS
        visible: root.duxFontScaleAvailable

        Item {
            width: parent.width
            height: duxFontScaleTitle.implicitHeight

            StyledText {
                id: duxFontScaleTitle

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Dux UI font scale"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            DActionButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                iconName: "restart_alt"
                tooltipText: "Reset to default (100%)"
                onClicked: {
                    duxFontScaleSlider.value = 100;
                    SettingsData.set("fontScale", 1.0);
                }
            }

        }

        StyledText {
            width: parent.width
            text: "Dux shell typography scale (75–150%). Pair with 'Scale app fonts with Dux's font scale' below to mirror into GTK, Qt, KDE and terminals."
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            wrapMode: Text.WordWrap
        }

        DSlider {
            id: duxFontScaleSlider

            width: parent.width
            minimum: 75
            maximum: 150
            step: 5
            unit: "%"
            wheelEnabled: false
            value: Math.round((SettingsData.fontScale || 1.0) * 100)
            onSliderDragFinished: function(finalValue) {
                SettingsData.set("fontScale", finalValue / 100);
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
            text: root.iconThemePerMode ? "Updates Dux's separate light and dark icon themes" : "Updates the canonical Dux icon theme"
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            wrapMode: Text.WordWrap
        }

        DToggle {
            width: parent.width
            visible: typeof SettingsData.iconThemePerMode !== "undefined"
            text: "Separate light and dark themes"
            description: "Use a different icon theme for each appearance mode. Folder-color overlays are derived independently."
            checked: root.iconThemePerMode
            onToggled: function(isChecked) {
                if (typeof SettingsData.setIconThemePerMode === "function")
                    SettingsData.setIconThemePerMode(isChecked);
            }
        }

        DDropdown {
            width: parent.width
            visible: !root.iconThemePerMode
            enableFuzzySearch: true
            currentValue: root.iconThemeDark
            options: root.installedIconThemes.map(root.iconThemeLabel)
            optionValues: root.installedIconThemes
            onValueChanged: function(value) {
                root.selectIconTheme(value, false);
            }
        }

        StyledText {
            visible: root.iconThemePerMode
            text: "Dark mode icon theme"
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
        }

        DDropdown {
            width: parent.width
            visible: root.iconThemePerMode
            enableFuzzySearch: true
            currentValue: root.iconThemeDark
            options: root.installedIconThemes.map(root.iconThemeLabel)
            optionValues: root.installedIconThemes
            onValueChanged: function(value) {
                root.selectIconTheme(value, false);
            }
        }

        StyledText {
            visible: root.iconThemePerMode
            text: "Light mode icon theme"
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
        }

        DDropdown {
            width: parent.width
            visible: root.iconThemePerMode
            enableFuzzySearch: true
            currentValue: root.iconThemeLight
            options: root.installedIconThemes.map(root.iconThemeLabel)
            optionValues: root.installedIconThemes
            onValueChanged: function(value) {
                root.selectIconTheme(value, true);
            }
        }

        StyledText {
            width: parent.width
            visible: root.iconThemeSelectionStatus !== ""
            text: root.iconThemeSelectionStatus
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.error
            wrapMode: Text.WordWrap
        }

        DToggle {
            width: parent.width
            visible: root.dux22Icons && !root.pickedDuxIcons
            text: "Match folder colors to theme (Dux 2.2)"
            description: "Recolor the selected icon pack's folders natively through Dux 2.2's icon pipeline."
            checked: !!SettingsData.iconFolderRecolor
            onToggled: function(isChecked) {
                SettingsData.set("iconFolderRecolor", isChecked);
            }
        }

        Column {
            width: parent.width
            spacing: Theme.spacingS
            visible: root.pickedDuxIcons

            StyledText {
                text: "Dux Icons styling (Dux 2.2)"
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            StyledText {
                width: parent.width
                visible: typeof SettingsData.iconShape !== "undefined"
                text: "Icon shape"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }

            DDropdown {
                width: parent.width
                visible: typeof SettingsData.iconShape !== "undefined"
                options: ["Circle", "Squircle", "Rounded square", "Square", "Hexagon", "Cookie", "Clover"]
                optionValues: ["circle", "squircle", "rounded", "square", "hexagon", "cookie", "clover"]
                currentValue: SettingsData.iconShape || "squircle"
                onValueChanged: function(value) {
                    if (value && value !== SettingsData.iconShape)
                        SettingsData.set("iconShape", value);
                }
            }

            StyledText {
                width: parent.width
                visible: typeof SettingsData.iconAppStyle !== "undefined"
                text: "App icon style"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }

            DDropdown {
                width: parent.width
                visible: typeof SettingsData.iconAppStyle !== "undefined"
                options: ["Color", "Tinted", "Themed", "Monochrome"]
                optionValues: ["color", "tinted", "themed", "monochrome"]
                currentValue: SettingsData.iconAppStyle || "themed"
                onValueChanged: function(value) {
                    if (value && value !== SettingsData.iconAppStyle)
                        SettingsData.set("iconAppStyle", value);
                }
            }

            DToggle {
                width: parent.width
                visible: typeof SettingsData.iconGradient !== "undefined"
                text: "Shaded icons"
                description: "Fill each icon tile with a soft top-to-bottom gradient."
                checked: !!SettingsData.iconGradient
                onToggled: function(isChecked) {
                    if (isChecked !== SettingsData.iconGradient)
                        SettingsData.set("iconGradient", isChecked);
                }
            }

            StyledText {
                width: parent.width
                visible: typeof SettingsData.iconTileColor !== "undefined" && SettingsData.iconAppStyle !== "color"
                text: "Tile color"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }

            DDropdown {
                width: parent.width
                visible: typeof SettingsData.iconTileColor !== "undefined" && SettingsData.iconAppStyle !== "color"
                options: ["Theme", "App color", "Edge Match", "Ring"]
                optionValues: ["theme", "app", "edge", "ring"]
                currentValue: SettingsData.iconTileColor || "edge"
                onValueChanged: function(value) {
                    if (value && value !== SettingsData.iconTileColor)
                        SettingsData.set("iconTileColor", value);
                }
            }

            StyledText {
                width: parent.width
                visible: typeof SettingsData.iconFileStyle !== "undefined"
                text: "Files & folders"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }

            DDropdown {
                width: parent.width
                visible: typeof SettingsData.iconFileStyle !== "undefined"
                options: ["Standard", "Color"]
                optionValues: ["standard", "color"]
                currentValue: SettingsData.iconFileStyle || "color"
                onValueChanged: function(value) {
                    if (value && value !== SettingsData.iconFileStyle)
                        SettingsData.set("iconFileStyle", value);
                }
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
            text: "Updates the canonical Dux cursor theme"
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            wrapMode: Text.WordWrap
        }

        DDropdown {
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

            DActionButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                iconName: "restart_alt"
                tooltipText: "Reset to default (24 px)"
                onClicked: {
                    cursorSizeSlider.value = 24;
                    SettingsData.setCursorSize(24);
                }
            }

        }

        StyledText {
            width: parent.width
            text: "Updates the canonical Dux cursor size"
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            wrapMode: Text.WordWrap
        }

        DSlider {
            id: cursorSizeSlider

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
            text: "Installed GTK theme used when Dux is in light mode. 'auto' matches an installed variant; 'preserve' keeps the current theme."
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            wrapMode: Text.WordWrap
        }

        DDropdown {
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
            text: "Installed GTK theme used when Dux is in dark mode (Dracula, Matcha, Breeze, etc.)"
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            wrapMode: Text.WordWrap
        }

        DDropdown {
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
        id: matugenColorsToggle
        settingKey: "applyMatugenColors"
        label: "Apply Dux Matugen colors"
        description: "Import Dux dynamic colors over the selected GTK theme and expose DankMatugen.colors to compatible Qt routes. A fixed same-author Kvantum pair such as Matcha keeps its own colors by design."
        defaultValue: true
    }

    Column {
        width: parent.width
        spacing: Theme.spacingS
        visible: matugenColorsToggle.value && typeof SettingsData.runDmsMatugenTemplates !== "undefined"
            && (!SettingsData.runDmsMatugenTemplates || SettingsData.matugenTemplateGtk === false || SettingsData.matugenTemplateKcolorscheme === false)

        StyledText {
            width: parent.width
            text: "A Dux color export used here is disabled. Existing files can retain an older palette. Theme Sync leaves your template choices unchanged until you enable them below (or in Dux Wallpaper & colors → App theming)."
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.warning !== undefined ? Theme.warning : Theme.surfaceVariantText
            wrapMode: Text.WordWrap
        }

        Flow {
            width: parent.width
            spacing: Theme.spacingS

            DButton {
                visible: !SettingsData.runDmsMatugenTemplates
                variant: "tonal"
                buttonHeight: 32
                iconName: "play_arrow"
                text: "Enable Run DMS templates"
                onClicked: SettingsData.set("runDmsMatugenTemplates", true)
            }

            DButton {
                visible: SettingsData.matugenTemplateGtk === false
                variant: "tonal"
                buttonHeight: 32
                iconName: "palette"
                text: "Enable GTK template"
                onClicked: SettingsData.set("matugenTemplateGtk", true)
            }

            DButton {
                visible: SettingsData.matugenTemplateKcolorscheme === false
                variant: "tonal"
                buttonHeight: 32
                iconName: "color_lens"
                text: "Enable KDE ColorScheme template"
                onClicked: SettingsData.set("matugenTemplateKcolorscheme", true)
            }
        }

    }

    Column {
        width: parent.width
        spacing: Theme.spacingS
        enabled: matugenColorsToggle.value
        opacity: enabled ? 1 : 0.45

        StyledText {
            text: "Dark surface depth"
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.Medium
            color: Theme.surfaceText
        }

        StyledText {
            width: parent.width
            text: "Adjust dark-mode application backgrounds across GTK 3/4, Flatpak, Qt 5/6, KDE, and Kvantum. Fixes very dark Tone 4–12 surfaces in Expressive/Bold (2025/Dux) and flattens KDE's Tone 4 surfaces into a clear View < Window/Header < Button/Card hierarchy without affecting Light mode."
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            wrapMode: Text.WordWrap
        }

        DDropdown {
            width: parent.width
            currentValue: root.labelForValue(root.appSurfaceDepthOptions, root.appSurfaceDepthValue)
            options: root.appSurfaceDepthOptions.map(function(o) {
                return o.label;
            })
            onValueChanged: function(label) {
                const depth = root.valueForLabel(root.appSurfaceDepthOptions, label);
                if (depth && depth !== root.appSurfaceDepthValue) {
                    root.appSurfaceDepthValue = depth;
                    root.saveValue("appSurfaceDepth", depth);
                }
            }
        }

        StyledText {
            text: "App background tint"
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.Medium
            color: Theme.surfaceText
        }

        StyledText {
            width: parent.width
            text: "Control chroma and tint source for application surfaces in both dark and light modes (for example, give Bold/2021 an Expressive 2025 wash, neutralize 2025's tint, or tint using Secondary/Tertiary) while keeping Material palette and text contrast intact."
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            wrapMode: Text.WordWrap
        }

        DDropdown {
            width: parent.width
            currentValue: root.labelForValue(root.appSurfaceTintOptions, root.appSurfaceTintValue)
            options: root.appSurfaceTintOptions.map(function(o) {
                return o.label;
            })
            optionColorMap: root.colorMapFromOptions(root.appSurfaceTintOptions)
            onValueChanged: function(label) {
                const tint = root.valueForLabel(root.appSurfaceTintOptions, label);
                if (tint && tint !== root.appSurfaceTintValue) {
                    root.appSurfaceTintValue = tint;
                    root.saveValue("appSurfaceTint", tint);
                }
            }
        }

        StyledText {
            width: parent.width
            visible: root.appSurfaceDepthValue !== "dux" || root.appSurfaceTintValue !== "dux"
            text: "Active: " + root.labelForValue(root.appSurfaceDepthOptions, root.appSurfaceDepthValue) + " · " + root.labelForValue(root.appSurfaceTintOptions, root.appSurfaceTintValue) + ". Applies via ~/.config/gtk-{3,4}.0/dms-theme-sync-surfaces.css, derived KDE/Qt schemes, and Kvantum without modifying Dux Shell."
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            wrapMode: Text.WordWrap
        }

    }

    ToggleSetting {
        id: uniformToggle

        settingKey: "uniformListBg"
        label: "Uniform list backgrounds"
        description: "Remove the alternating row colors in file lists (Dolphin details view and friends) on every surface the plugin manages"
        defaultValue: false
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
            parts.push(root.probeQt6ct === "kde" ? "qt6ct-kde ✓ (reads the Dux palette directly)" : "stock qt6ct (cannot read the Dux .colors palette — qt6ct-kde fixes that)");
            parts.push(root.probeKvantum === "yes" ? "Kvantum ✓" : "Kvantum not installed");
            if (root.probeNativePair && root.probeNativePair !== "none")
                parts.push("native Qt pair for " + root.probeGtk + ": " + root.probeNativePair);
            else if (root.probeNativeMissing && root.probeNativeMissing !== "none")
                parts.push("native Qt pair for " + root.probeGtk + " is incomplete (missing " + root.probeNativeMissing + ")");
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

    StyledText {
        width: parent.width
        visible: root.dmsQtTemplates
        text: root.deferQtColors ? "Dux's Qt engine is the active Qt platform theme, so it paints Qt apps with Dux's palette. Theme Sync leaves the Qt palette alone and keeps widget style, fonts, icons and the KDE colour scheme in sync." : "Dux's Qt templates are on. They write their own colors/matugen.conf and do not touch the palette Theme Sync points Qt and KDE at, so both can stay enabled: Theme Sync keeps those palettes in step with Dux on every wallpaper change."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    StyledText {
        width: parent.width
        visible: root.qtengineActive
        text: "Dux's Qt engine is active on this session. Theme Sync's qt5ct/qt6ct routes do not feed it: keep Dux's Qt engine template enabled for it, or switch platform themes deliberately."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    // Not a SelectionSetting: that component puts the trigger in a fixed
    // 200 px column next to the label, and these option labels are sentences.
    // The full-width pattern below (own title + description, compact dropdown
    // stretched to the row) is the same one the GTK theme selectors use, and
    // the popup inherits the trigger's width, so the options finally fit.
    Column {
        width: parent.width
        spacing: Theme.spacingS

        StyledText {
            text: "Synchronization route"
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.Medium
            color: Theme.surfaceText
        }

        StyledText {
            width: parent.width
            text: "Choose the objective for Qt. 'Automatic' prioritizes visual fidelity with GTK, re-evaluated on every apply: native Breeze → a same-author Kvantum pair such as Matcha → Kvantum rendered from Dux → Fusion with the Dux palette → follow GTK. Select 'Dynamic wallpaper colors — Fusion' when wallpaper colors matter more than preserving Matcha's fixed Qt design. Every route except 'Manual' overrides the platform theme and widget style below. Changing that widget style is a process boundary: configuration is applied immediately, but open Qt applications may need a restart to rebuild the whole window."
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            wrapMode: Text.WordWrap
        }

        DDropdown {
            width: parent.width
            currentValue: root.labelForValue(root.qtSyncModeOptions, root.qtSyncModeValue)
            options: root.qtSyncModeOptions.map(function(o) {
                return o.label;
            })
            onValueChanged: function(label) {
                const value = root.valueForLabel(root.qtSyncModeOptions, label);
                if (value && value !== root.qtSyncModeValue) {
                    root.qtSyncModeValue = value;
                    root.saveValue("qtSyncMode", value);
                }
            }
        }

    }

    SectionHeader {
        text: "Qt applications"
    }

    StyledText {
        width: parent.width
        visible: root.qtSyncModeValue !== "manual"
        text: "The synchronization route above is not 'Manual', so it decides the platform theme and widget style — the two options below are written but then overridden on every apply. Palette, fonts and icons can refresh in place; a different widget style is completed on the next application start."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.warning !== undefined ? Theme.warning : Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    Column {
        width: parent.width
        spacing: Theme.spacingS

        StyledText {
            text: "Qt5/Qt6 platform theme"
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.Medium
            color: Theme.surfaceText
        }

        StyledText {
            width: parent.width
            text: {
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
                return "Only platform themes this machine has and that make sense on a Dux desktop are listed (sandbox aliases and Plasma's are filtered out). Controls QT_QPA_PLATFORMTHEME. " + where + ". Apps started after the next apply pick it up; already-running ones need a restart. Keep 'Leave to my environment' if you already set the variable yourself. Only 'Dux palette' reads qt5ct/qt6ct.conf — under gtk3 the widget style below is ignored.";
            }
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            wrapMode: Text.WordWrap
        }

        DDropdown {
            width: parent.width
            currentValue: root.labelForValue(root.qtPlatformThemeOptions, root.qtPlatformThemeValue)
            options: root.qtPlatformThemeOptions.map(function(o) {
                return o.label;
            })
            onValueChanged: function(label) {
                const value = root.valueForLabel(root.qtPlatformThemeOptions, label);
                if (value && value !== root.qtPlatformThemeValue) {
                    root.qtPlatformThemeValue = value;
                    root.saveValue("qtPlatformTheme", value);
                }
            }
        }

    }

    Column {
        width: parent.width
        spacing: Theme.spacingS

        StyledText {
            text: "Qt widget style"
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.Medium
            color: Theme.surfaceText
        }

        StyledText {
            width: parent.width
            text: "Styles Qt can actually load here, as reported by qtdiag. Written to qt5ct.conf and qt6ct.conf, which only the qt5ct/qt6ct platform theme reads. 'Auto' picks Kvantum when it is installed and the platform theme reads those files, and otherwise writes no style at all. Changing this value updates configuration now but requires restarting open Qt applications for a complete, consistent result."
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            wrapMode: Text.WordWrap
        }

        DDropdown {
            width: parent.width
            currentValue: root.labelForValue(root.qtStyleOptions, root.qtStyleValue)
            options: root.qtStyleOptions.map(function(o) {
                return o.label;
            })
            onValueChanged: function(label) {
                const value = root.valueForLabel(root.qtStyleOptions, label);
                if (value && value !== root.qtStyleValue) {
                    root.qtStyleValue = value;
                    root.saveValue("qtStyle", value);
                }
            }
        }

    }

    SectionHeader {
        text: "Font sizes"
    }

    ToggleSetting {
        settingKey: "applyFontScale"
        label: "Scale app fonts with Dux's font scale"
        description: "Dux's UI scale (Settings → Appearance → Fonts) normally only resizes the shell. With this on, the plugin multiplies the three sizes below by that scale before applying them to GTK, Qt, KDE and terminals, rounded to whole points. Off (default) keeps the sliders as absolute point sizes."
        defaultValue: false
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

            DActionButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                iconName: "restart_alt"
                tooltipText: "Reset to default (11 pt)"
                onClicked: {
                    regularFontSizeSlider.value = 11;
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

        DSlider {
            id: regularFontSizeSlider

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

            DActionButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                iconName: "restart_alt"
                tooltipText: "Reset to default (12 pt)"
                onClicked: {
                    monoFontSizeSlider.value = 12;
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

        DSlider {
            id: monoFontSizeSlider

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

            DActionButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                iconName: "restart_alt"
                tooltipText: "Reset to default (11 pt)"
                onClicked: {
                    documentFontSizeSlider.value = 11;
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

        DSlider {
            id: documentFontSizeSlider

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
        description: "Terminals read their own config, not GTK/Qt, so the monospace font never reaches them otherwise. When on, the plugin writes a font include per terminal in ~/.config/dms-theme-sync/ (kitty.conf, alacritty.toml, ghostty.conf) using the Dux monospace font and size. Opt-in: reference each file from your terminal config once — kitty: include ~/.config/dms-theme-sync/kitty.conf · ghostty: config-file = ~/.config/dms-theme-sync/ghostty.conf · alacritty: add it to [general] import. Each generated file also prints its exact reference line in its header."
        defaultValue: false
    }

    ToggleSetting {
        settingKey: "syncKvantum"
        label: "Generate a Kvantum theme from the Dux palette"
        description: "Kvantum draws Qt widgets from an SVG and takes its colours from its own theme, not from the qt5ct/qt6ct palette — so selecting the kvantum style without giving it a theme does not add Material You to Qt, it removes it. When on, the plugin renders ~/.config/Kvantum/DankMatugen/ from the Dux colours (both the .kvconfig and the recoloured .svg) and selects it. Only has an effect when the Qt widget style is 'kvantum'. In the 'Automatic' synchronization route this toggle also gates the Dux-palette-Kvantum step; a native Qt pair or paired Kvantum theme always wins over the render, because pairing means both halves come from one design."
        defaultValue: false
    }

    ToggleSetting {
        settingKey: "syncFlatpak"
        label: "Synchronize Flatpak applications"
        description: "Sandboxed apps do not see every host theme file. Dark/light reaches them through the desktop portal. When on, the plugin exposes GTK 3 configuration and only the GTK 4 CSS color files—not GTK 4 settings.ini—plus theme directories, icons and the cursor. It removes the old GTK_THEME override: forcing that debugging variable can make GTK 4/libadwaita applications render with GTK 3 metrics, causing missing padding and overlapping controls."
        defaultValue: false
    }

    Column {
        width: parent.width
        spacing: Theme.spacingS

        StyledText {
            width: parent.width
            text: root.flatpakDiagnosticStatus
            font.pixelSize: Theme.fontSizeSmall
            color: root.flatpakDiagnosticStatus.indexOf("override") !== -1
                && root.flatpakDiagnosticStatus.indexOf("No application") !== 0
                ? Theme.warning : Theme.surfaceVariantText
            wrapMode: Text.WordWrap
        }

        DButton {
            text: root.flatpakDiagnosticBusy ? "Checking…" : "Check per-app Flatpak overrides"
            iconName: "manage_search"
            enabled: !root.flatpakDiagnosticBusy
            onClicked: {
                root.flatpakDiagnosticStatus = "Checking without changing Flatpak state…";
                flatpakDiagnosticProcess.running = true;
            }
        }

    }

    ToggleSetting {
        settingKey: "syncFolderColor"
        label: "Sync icon folder color (requires Papirus)"
        description: "Recolors the folder icons to follow the Material You accent. Only Papirus ships the ~80 folder color variants this needs, so the toggle does nothing with any other icon theme — yours is kept exactly as you set it. When on, the plugin generates a small overlay theme in ~/.local/share/icons that inherits Papirus and only overrides the folders (about 4 MB of symlinks, no root needed, and Papirus updates are inherited). The accent is matched by hue, not by nearest RGB, because Material You hands out pastel tints in dark mode."
        defaultValue: false
        enabled: root.anyIconModeSupportsFolderColor && !root.dux22Icons
    }

    StyledText {
        width: parent.width
        visible: root.dux22Icons
        text: "Dux 2.2+ now manages icon folders natively (Settings → Appearance → Dux Icons). This overlay defers to it automatically and any previously generated overlay is reverted on the next apply; prefer Dux's own recolor."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.warning
        wrapMode: Text.WordWrap
    }

    Column {
        width: parent.width
        spacing: Theme.spacingS
        visible: !root.iconThemeSupportsFolderColor

        StyledText {
            width: parent.width
            text: root.folderColorCapabilityReason
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            wrapMode: Text.WordWrap
        }

        DButton {
            visible: root.papirusInstalled
            text: "Use " + root.preferredPapirusTheme
            iconName: "folder"
            onClicked: root.selectIconTheme(root.preferredPapirusTheme, SessionData.isLightMode)
        }

    }

    ToggleSetting {
        settingKey: "syncCursorColor"
        label: "Sync cursor color (requires Bibata-Material-* cursors)"
        description: "Selects the installed Bibata-Material-* cursor variant nearest to the Material You accent on every apply, matched by hue like the folder color. The variants are built once with material-bibata-cursor (28 accents, installed to ~/.icons); the plugin never builds cursors itself, it only chooses among the ones present and hands the choice to Dux's own cursor setting. A neutral accent picks a neutral variant (Grey, Slate, Cloud…). Turning this off returns the cursor to the theme you had before."
        defaultValue: false
    }

    Column {
        width: parent.width
        spacing: Theme.spacingS

        StyledText {
            text: "Niri focused border"
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.Medium
            color: Theme.surfaceText
        }

        StyledText {
            width: parent.width
            text: "Controls how dms-theme-sync styles Niri's focused border and focus ring inside dms-theme-sync.kdl (Niri only). 'Softened Dux primary' adds translucent alpha; 'Palette role' picks a secondary/outline/container role from the live palette; 'Dynamic palette gradient' blends primary to a second role at 45°. Width, inactive and urgent colors remain unchanged. Keeps legacy dimNiriBorder synchronized when enabled."
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            wrapMode: Text.WordWrap
        }

        DDropdown {
            width: parent.width
            currentValue: root.labelForValue(root.niriBorderModeOptions, root.niriBorderModeValue)
            options: root.niriBorderModeOptions.map(function(o) {
                return o.label;
            })
            onValueChanged: function(label) {
                const mode = root.valueForLabel(root.niriBorderModeOptions, label);
                if (mode)
                    root.setNiriBorderMode(mode);
            }
        }

        Item {
            width: parent.width
            height: niriBorderOpacityTitle.implicitHeight
            visible: root.niriBorderModeValue !== "off"

            StyledText {
                id: niriBorderOpacityTitle

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Border opacity"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            DActionButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                iconName: "restart_alt"
                tooltipText: "Reset to default (70%)"
                onClicked: {
                    niriBorderOpacitySlider.value = 70;
                    root.niriBorderOpacityValue = 70;
                    root.saveValue("niriBorderOpacity", 70);
                }
            }

        }

        DSlider {
            id: niriBorderOpacitySlider

            width: parent.width
            visible: root.niriBorderModeValue !== "off"
            minimum: 30
            maximum: 100
            step: 5
            unit: "%"
            wheelEnabled: false
            value: root.niriBorderOpacityValue
            onSliderValueChanged: function(newValue) {
                root.niriBorderOpacityValue = newValue;
            }
            onSliderDragFinished: function(finalValue) {
                root.saveValue("niriBorderOpacity", finalValue);
            }
        }

        StyledText {
            visible: root.niriBorderModeValue === "role"
            text: "Palette role"
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
        }

        DDropdown {
            width: parent.width
            visible: root.niriBorderModeValue === "role"
            currentValue: root.labelForValue(root.niriBorderRoleOptions, root.niriBorderRoleValue)
            options: root.niriBorderRoleOptions.map(function(o) {
                return o.label;
            })
            optionColorMap: root.colorMapFromOptions(root.niriBorderRoleOptions)
            onValueChanged: function(label) {
                const role = root.valueForLabel(root.niriBorderRoleOptions, label);
                if (role && role !== root.niriBorderRoleValue) {
                    root.niriBorderRoleValue = role;
                    root.saveValue("niriBorderRole", role);
                }
            }
        }

        StyledText {
            visible: root.niriBorderModeValue === "gradient"
            text: "Gradient second color (from primary)"
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
        }

        DDropdown {
            width: parent.width
            visible: root.niriBorderModeValue === "gradient"
            currentValue: root.labelForValue(root.niriBorderGradientToOptions, root.niriBorderGradientToValue)
            options: root.niriBorderGradientToOptions.map(function(o) {
                return o.label;
            })
            optionColorMap: root.colorMapFromOptions(root.niriBorderGradientToOptions)
            onValueChanged: function(label) {
                const role = root.valueForLabel(root.niriBorderGradientToOptions, label);
                if (role && role !== root.niriBorderGradientToValue) {
                    root.niriBorderGradientToValue = role;
                    root.saveValue("niriBorderGradientTo", role);
                }
            }
        }

        Column {
            width: parent.width
            spacing: Theme.spacingS
            visible: root.niriBorderModeValue !== "off" && CompositorService.compositor === "niri"
                && typeof SettingsData.runDmsMatugenTemplates !== "undefined"
                && (!SettingsData.runDmsMatugenTemplates || SettingsData.matugenTemplateNiri === false)

            StyledText {
                width: parent.width
                text: "The Dux Niri color export is disabled. The border can reuse an older highlight or skip the override if no palette exists. Enable Run DMS templates and Niri below (or in Dux Wallpaper & colors → App theming) to follow new colors."
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.warning !== undefined ? Theme.warning : Theme.surfaceVariantText
                wrapMode: Text.WordWrap
            }

            Flow {
                width: parent.width
                spacing: Theme.spacingS

                DButton {
                    visible: !SettingsData.runDmsMatugenTemplates
                    variant: "tonal"
                    buttonHeight: 32
                    iconName: "play_arrow"
                    text: "Enable Run DMS templates"
                    onClicked: SettingsData.set("runDmsMatugenTemplates", true)
                }

                DButton {
                    visible: SettingsData.matugenTemplateNiri === false
                    variant: "tonal"
                    buttonHeight: 32
                    iconName: "border_color"
                    text: "Enable Niri template"
                    onClicked: SettingsData.set("matugenTemplateNiri", true)
                }
            }

        }

    }

    SectionHeader {
        text: "Companion assets"
    }

    StyledText {
        width: parent.width
        text: "Optional companion integrations shipped in assets/:\n• Zotero 10 (assets/zotero/dux-theme@arqueon.org.xpi — github.com/arqueon/zotero-dux-theme): synchronizes Dux Matugen colors, light/dark mode, uniformListBg, reader page themes, and typography in hot; notified by reload-application-theme.sh via 127.0.0.1:23119/dux-theme/reload.\n• Strata (assets/strata/strata-theme.toml — github.com/arqueon/strata-extras): Matugen template generating ~/.config/strata/themes/matugen.toml; Strata watches its themes folder and reloads automatically on its own."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    SectionHeader {
        text: "Synchronization and backups"
    }

    ToggleSetting {
        settingKey: "autoSync"
        label: "Auto-apply to applications"
        description: "Propagate Dux appearance changes (theme, light/dark, fonts, icons, cursor) to GTK, Qt and KDE apps automatically. When off, changes apply only with 'Apply now' below."
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "backupEnabled"
        label: "Back up before applying"
        description: "Before changing theme state, snapshot managed files, compositor includes, the Kvantum selection and generated theme, color schemes, Flatpak overrides, GSettings and the runtime environment. A paired Kvantum theme shadow may also be changed; that dynamically named directory is not included in snapshots. If the snapshot fails, synchronization is aborted."
        defaultValue: true
    }

    StyledText {
        width: parent.width
        text: "Each successful apply reports the snapshot ID and an exact restore command. Restoring returns the captured files and settings, then disables automatic synchronization so the recovered state is not overwritten immediately."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
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

            DActionButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                iconName: "restart_alt"
                tooltipText: "Reset to default (10)"
                onClicked: {
                    backupRetentionSlider.value = 10;
                    root.backupRetentionValue = 10;
                    root.saveValue("backupRetention", 10);
                }
            }

        }

        StyledText {
            width: parent.width
            text: "Keeps this many unnamed snapshots and, separately, the newest Dux .Xresources.backup files. Named snapshots stay pinned. Cursor-file copies are cleaned at plugin startup and every minute, even when automatic theme sync or snapshots are off. To preserve one outside rotation, rename it with a nonnumeric suffix."
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            wrapMode: Text.WordWrap
        }

        DSlider {
            id: backupRetentionSlider

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

            DButton {
                text: "Apply now"
                iconName: "sync"
                onClicked: {
                    root.snapshotActionStatus = "Apply scheduled. With backups enabled, no theme file changes until the pre-apply snapshot succeeds.";
                    Quickshell.execDetached(["dms", "ipc", "call", "dmsThemeSync", "apply"]);
                }
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

                DDropdown {
                    width: parent.width - restoreButton.width - refreshButton.width - Theme.spacingM * 2
                    enableFuzzySearch: true
                    emptyText: "No backups"
                    currentValue: root.selectedSnapshot ? root.formatSnapshot(root.selectedSnapshot) : ""
                    options: root.snapshotLabels
                    onValueChanged: function(value) {
                        root.selectedSnapshot = root.snapshotForLabel(value);
                    }
                }

                DButton {
                    id: restoreButton

                    text: "Restore"
                    iconName: "restore"
                    enabled: root.selectedSnapshot !== ""
                    onClicked: {
                        root.snapshotActionStatus = "Restore scheduled for " + root.selectedSnapshot + ". Automatic synchronization will be disabled.";
                        Quickshell.execDetached(["dms", "ipc", "call", "dmsThemeSync", "restore", root.selectedSnapshot]);
                    }
                }

                DActionButton {
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

            DTextField {
                id: snapshotNameField

                width: parent.width
                placeholderText: "Snapshot name, e.g. \"known good — before experiments\""
            }

            Row {
                width: parent.width
                spacing: Theme.spacingM

                DButton {
                    id: pinButton

                    text: snapshotNameField.text ? "Pin selected" : "Unpin selected"
                    iconName: "push_pin"
                    enabled: root.selectedSnapshot !== "" && !snapshotActionProcess.running
                    onClicked: {
                        root.snapshotActionStatus = snapshotNameField.text ? "Pinning selected snapshot…" : "Unpinning selected snapshot…";
                        snapshotActionProcess.command = ["bash", root.snapshotHelper(), "name", "--snapshot", root.selectedSnapshot, "--name", snapshotNameField.text];
                        snapshotActionProcess.running = true;
                    }
                }

                DButton {
                    id: backupNowButton

                    text: snapshotNameField.text ? "Back up now (pinned)" : "Back up now"
                    iconName: "backup"
                    enabled: !snapshotActionProcess.running
                    onClicked: {
                        root.snapshotActionStatus = "Creating snapshot before any further changes…";
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
                onExited: function(exitCode) {
                    const output = ((snapshotActionStdout.text || "") + (snapshotActionStderr.text || "")).trim();
                    if (exitCode === 0) {
                        if (output.indexOf("BACKUP_CREATED:") === 0) {
                            const id = output.substring("BACKUP_CREATED:".length).split("\n")[0];
                            root.snapshotActionStatus = "Backup created: " + id + ". Restore it with: dms ipc call dmsThemeSync restore " + id;
                        } else if (output.indexOf("SNAPSHOT_NAMED:") === 0) {
                            root.snapshotActionStatus = "Snapshot name updated. Named snapshots marked 📌 are excluded from rotation.";
                        } else {
                            root.snapshotActionStatus = output || "Snapshot action completed.";
                        }
                    } else {
                        root.snapshotActionStatus = "Snapshot action failed: " + (output || "unknown error");
                    }
                    root.refreshSnapshots();
                }

                stdout: StdioCollector {
                    id: snapshotActionStdout
                }

                stderr: StdioCollector {
                    id: snapshotActionStderr
                }

            }

            StyledText {
                width: parent.width
                visible: root.snapshotActionStatus !== ""
                text: root.snapshotActionStatus
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceText
                wrapMode: Text.WordWrap
            }

            StyledText {
                width: parent.width
                text: "Stored under ~/.local/state/dms/plugins/dmsThemeSync/backups (older Dux: ~/.local/state/DankMaterialShell, kept as a symlink).\nList: scripts/theme-snapshot.sh list\nRestore selected: dms ipc call dmsThemeSync restore " + (root.selectedSnapshot || "SNAPSHOT_ID") + "\nRestore latest: dms ipc call dmsThemeSync restoreLatest"
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
