import QtQuick
import qs.Common
import qs.Modals.Common
import qs.DCommon.Widgets

DModal {
    id: window

    property var parentWidget: null

    function openCentered() {
        shouldBeVisible = true;
        open();
    }

    layerNamespace: "dms:plugins:theme-sync"
    shouldBeVisible: false
    modalWidth: Theme.dialogMaxWidth + Theme.spacingXL * 5
    modalHeight: Math.min(Theme.mediumBreakpoint + Theme.spacingXL * 2, screenHeight - Theme.spacingXL * 3)
    keepContentLoaded: false
    keepPopoutsOpen: true
    closeOnEscapeKey: true
    closeOnBackgroundClick: true
    onBackgroundClicked: close()

    content: Component {
        Item {
            anchors.fill: parent

            Item {
                id: header

                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: Theme.spacingL
                height: Math.max(Theme.buttonHeightS, headerIcon.size + Theme.spacingM)

                DIcon {
                    id: headerIcon

                    name: "palette"
                    size: Theme.iconSizeLarge
                    color: Theme.primary
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    anchors.left: headerIcon.right
                    anchors.leftMargin: Theme.spacingM
                    anchors.right: closeButton.left
                    anchors.rightMargin: Theme.spacingM
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Dux Theme Sync"
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.Bold
                    color: Theme.surfaceText
                    elide: Text.ElideRight
                }

                DButton {
                    id: closeButton

                    text: "Close"
                    iconName: "close"
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    onClicked: window.close()
                }

            }

            Rectangle {
                id: divider

                anchors.top: header.bottom
                anchors.topMargin: Theme.spacingM
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: Theme.spacingL
                anchors.rightMargin: Theme.spacingL
                height: 1
                color: Theme.outline
                opacity: 0.25
            }

            DFlickable {
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
