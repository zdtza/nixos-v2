// Top bar layer-shell panel: workspaces + title on the left, clock centered,
// status widgets on the right.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Stylix
import Quickshell.Wayland

PanelWindow {
    id: bar

    required property var modelData

    screen: modelData
    color: "transparent"
    implicitHeight: Theme.barHeight
    WlrLayershell.namespace: "quickshell:bar"

    anchors {
        top: true
        left: true
        right: true
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.background

        // Bottom hairline separates the bar from windows below it.
        Rectangle {
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
            }
            height: 1
            color: Theme.border
        }

        RowLayout {
            anchors {
                fill: parent
                leftMargin: Theme.paddingH
                rightMargin: Theme.paddingH
            }
            spacing: Theme.spacing

            // --- left ---
            RowLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: Theme.spacing

                Workspaces {
                    screen: bar.screen
                }
            }

            Item {
                Layout.fillWidth: true
            }

            // --- center ---
            Clock {
                Layout.alignment: Qt.AlignVCenter
            }

            Item {
                Layout.fillWidth: true
            }

            // --- right ---
            RowLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: Theme.spacing

                Tray {}

                Volume {}

                Battery {}
            }
        }
    }
}
