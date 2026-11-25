import QtQuick
import qs.Common
import qs.DCommon.Widgets
import qs.Services

Column {
    id: root

    property string text: ""
    property string description: ""
    property var options: []
    property string currentMode: "default"
    property color customColor: Theme.primary
    property color defaultColor: Theme.primary
    property string pickerTitle: ""
    property bool showReset: false
    property string resetTooltip: "Reset to default"
    readonly property real swatchSize: Theme.iconSize + Theme.spacingXS

    signal modeSelected(string mode)
    signal customColorSelected(color selectedColor)
    signal resetRequested

    readonly property var optionColorMap: {
        const map = {};
        for (let i = 0; i < options.length; i++) {
            const opt = options[i];
            if (opt.previewColor !== undefined) {
                map[opt.label] = opt.previewColor;
                continue;
            }
            if (opt.value === "custom") {
                map[opt.label] = root.customColor;
            } else if (opt.value === "default") {
                map[opt.label] = root.defaultColor;
            } else if (opt.value === "none") {
                map[opt.label] = "transparent";
            } else if (typeof Theme.roleColor === "function") {
                map[opt.label] = Theme.roleColor(opt.value);
            }
        }
        return map;
    }

    function labelFor(value) {
        for (let i = 0; i < options.length; i++) {
            if (options[i].value === value)
                return options[i].label;
        }
        return options.length > 0 ? options[0].label : "";
    }

    function valueFor(label) {
        for (let i = 0; i < options.length; i++) {
            if (options[i].label === label)
                return options[i].value;
        }
        return options.length > 0 ? options[0].value : "default";
    }

    function openPicker() {
        if (typeof PopoutService === "undefined" || !PopoutService.colorPickerModal)
            return;
        PopoutService.colorPickerModal.selectedColor = root.customColor;
        PopoutService.colorPickerModal.pickerTitle = root.pickerTitle || root.text;
        PopoutService.colorPickerModal.onColorSelectedCallback = function(selectedColor) {
            root.customColorSelected(selectedColor);
            root.modeSelected("custom");
        };
        PopoutService.colorPickerModal.show(true);
    }

    width: parent ? parent.width : 0
    spacing: Theme.spacingS
    opacity: enabled ? 1 : 0.45

    Item {
        width: parent.width
        height: Math.max(titleLabel.implicitHeight, resetButton.visible ? resetButton.height : 0)

        StyledText {
            id: titleLabel

            anchors.left: parent.left
            anchors.right: resetButton.visible ? resetButton.left : parent.right
            anchors.rightMargin: resetButton.visible ? Theme.spacingS : 0
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.Medium
            color: Theme.surfaceText
        }

        DActionButton {
            id: resetButton

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: root.showReset
            iconName: "restart_alt"
            tooltipText: root.resetTooltip
            onClicked: root.resetRequested()
        }
    }

    StyledText {
        width: parent.width
        visible: root.description !== ""
        text: root.description
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    DDropdown {
        width: parent.width
        enabled: root.enabled
        currentValue: root.labelFor(root.currentMode)
        options: root.options.map(function(o) {
            return o.label;
        })
        optionColorMap: root.optionColorMap
        onValueChanged: function(label) {
            const nextMode = root.valueFor(label);
            if (nextMode !== root.currentMode)
                root.modeSelected(nextMode);
        }
    }

    StyledRect {
        width: parent.width
        visible: root.currentMode === "custom"
        height: visible ? Math.max(Theme.minimumTouchTargetSize, swatchRow.implicitHeight + Theme.spacingS * 2) : 0
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh
        border.width: Theme.outlineWidth
        border.color: Theme.outlineMedium

        Row {
            id: swatchRow

            anchors.fill: parent
            anchors.leftMargin: Theme.spacingM
            anchors.rightMargin: Theme.spacingM
            spacing: Theme.spacingM

            DColorSwatch {
                width: root.swatchSize
                height: root.swatchSize
                anchors.verticalCenter: parent.verticalCenter
                swatchColor: root.customColor
            }

            Column {
                width: parent.width - root.swatchSize - pickIcon.width - Theme.spacingM * 2
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingXXS

                StyledText {
                    width: parent.width
                    text: "Custom color"
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                }

                StyledText {
                    width: parent.width
                    text: String(root.customColor)
                    font.pixelSize: Theme.fontSizeSmall
                    font.family: "monospace"
                    color: Theme.surfaceVariantText
                    elide: Text.ElideRight
                }
            }

            DIcon {
                id: pickIcon

                name: "colorize"
                size: Theme.iconSizeSmall
                color: Theme.primary
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: root.enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: root.openPicker()
        }
    }
}
