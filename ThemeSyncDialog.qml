import QtQuick
import qs.Common
import qs.Modals.Common
import qs.Widgets

DankModal {
    id: window

    property var parentWidget: null

    function openCentered() {
        shouldBeVisible = true;
        open();
    }

    layerNamespace: "dms:plugins:theme-sync"
    shouldBeVisible: false
    modalWidth: 680
    modalHeight: Math.min(820, screenHeight - 80)
    keepContentLoaded: true
    keepPopoutsOpen: true
    closeOnEscapeKey: true
    closeOnBackgroundClick: true
    onBackgroundClicked: close()

    content: Component {
        Item {
            anchors.fill: parent

            Row {
                id: header

                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: Theme.spacingL
                height: 44
                spacing: Theme.spacingM

                DankIcon {
                    name: "palette"
                    size: Theme.iconSizeLarge
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: "DMS Theme Sync"
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.Bold
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }

                Item {
                    width: Math.max(0, parent.width - 250)
                    height: 1
                }

                DankButton {
                    text: "Close"
                    iconName: "close"
                    anchors.verticalCenter: parent.verticalCenter
                    onClicked: window.close()
                }

            }

            Rectangle {
                id: divider

                anchors.top: header.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: Theme.spacingL
                anchors.rightMargin: Theme.spacingL
                height: 1
                color: Theme.outline
                opacity: 0.25
            }

            Flickable {
                id: scroll

                anchors.top: divider.bottom
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: Theme.spacingL
                anchors.topMargin: Theme.spacingM
                clip: true
                contentWidth: width
                contentHeight: controls.implicitHeight + Theme.spacingL
                boundsBehavior: Flickable.StopAtBounds

                ThemeSyncSettings {
                    id: controls

                    width: scroll.width
                    pluginService: window.parentWidget ? window.parentWidget.pluginService : null
                }

            }

        }

    }

}
