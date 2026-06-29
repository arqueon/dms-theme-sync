import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    function openConfiguration() {
        configDialog.openCentered();
    }

    function applyNow() {
        Quickshell.execDetached(["dms", "ipc", "call", "dmsThemeSync", "apply"]);
    }

    pluginId: "dmsThemeSync"
    pluginService: PluginService

    // The widget owns its own dialog instead of opening the daemon's over IPC,
    // so the bar button keeps working regardless of IPC handler state.
    ThemeSyncDialog {
        id: configDialog

        parentWidget: root
    }

    horizontalBarPill: Component {
        Item {
            implicitWidth: Theme.iconSize
            implicitHeight: Theme.iconSize
            anchors.verticalCenter: parent.verticalCenter

            DankIcon {
                anchors.centerIn: parent
                name: "palette"
                size: Theme.iconSizeSmall
                color: pillArea.containsMouse ? Theme.primary : Theme.surfaceText
            }

            MouseArea {
                id: pillArea

                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
                cursorShape: Qt.PointingHandCursor
            }

        }

    }

    verticalBarPill: Component {
        Item {
            implicitWidth: Theme.iconSize
            implicitHeight: Theme.iconSize
            anchors.horizontalCenter: parent.horizontalCenter

            DankIcon {
                anchors.centerIn: parent
                name: "palette"
                size: Theme.iconSizeSmall
                color: pillAreaV.containsMouse ? Theme.primary : Theme.surfaceText
            }

            MouseArea {
                id: pillAreaV

                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
                cursorShape: Qt.PointingHandCursor
            }

        }

    }

    // Left click opens the configuration dialog directly; right click triggers an
    // immediate synchronization through the daemon.
    pillClickAction: function() {
        root.openConfiguration();
    }
    pillRightClickAction: function() {
        root.applyNow();
    }

}
