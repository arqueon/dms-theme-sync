import QtQuick
import qs.Common
import qs.DCommon.Widgets

Column {
    id: root

    property var options: []
    property string currentValue: ""
    property bool ready: true

    signal selected(string value)

    readonly property bool hasSwatches: options.length > 0 && options[0] && options[0].primary !== undefined

    width: parent ? parent.width : 0
    spacing: Theme.spacingS

    Item {
        width: parent.width
        visible: root.hasSwatches
        height: visible ? gridFlow.implicitHeight : 0

        Flow {
            id: gridFlow

            readonly property int cols: width >= 460 ? 3 : 2
            readonly property real tileWidth: Math.max(120, Math.floor((width - spacing * (cols - 1)) / cols))

            width: parent.width
            spacing: Theme.spacingS
            opacity: root.ready ? 1 : 0.6

            Repeater {
                model: root.options

                StyledRect {
                    id: tile

                    required property var modelData
                    readonly property bool active: root.currentValue === modelData.value

                    width: gridFlow.tileWidth
                    height: tileRow.implicitHeight + Theme.spacingS * 2
                    radius: Theme.cornerRadius
                    color: active ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
                    border.width: active ? 2 : Theme.outlineWidth
                    border.color: active ? Theme.primary : Theme.outlineMedium

                    Row {
                        id: tileRow

                        anchors.fill: parent
                        anchors.margins: Theme.spacingS
                        spacing: Theme.spacingS

                        DPaletteSwatch {
                            width: 28
                            height: 28
                            anchors.verticalCenter: parent.verticalCenter
                            primaryColor: tile.modelData.primary || Theme.primary
                            secondaryColor: tile.modelData.secondary || tile.modelData.primary || Theme.primary
                            tertiaryColor: tile.modelData.tertiary || tile.modelData.secondary || tile.modelData.primary || Theme.primary
                        }

                        StyledText {
                            width: parent.width - 28 - Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            text: tile.modelData.label || tile.modelData.value
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: tile.active ? Font.Bold : Font.Medium
                            color: tile.active ? Theme.primary : Theme.surfaceText
                            maximumLineCount: 2
                            wrapMode: Text.WordWrap
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: root.enabled
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (tile.modelData.value !== root.currentValue)
                                root.selected(tile.modelData.value);
                        }
                    }
                }
            }
        }
    }

    DDropdown {
        width: parent.width
        visible: !root.hasSwatches
        enabled: root.enabled
        currentValue: {
            for (let i = 0; i < root.options.length; i++) {
                if (root.options[i].value === root.currentValue)
                    return root.options[i].label;
            }
            return root.currentValue;
        }
        options: root.options.map(function(o) {
            return o.label;
        })
        onValueChanged: function(label) {
            for (let i = 0; i < root.options.length; i++) {
                if (root.options[i].label === label && root.options[i].value !== root.currentValue) {
                    root.selected(root.options[i].value);
                    return;
                }
            }
        }
    }
}
