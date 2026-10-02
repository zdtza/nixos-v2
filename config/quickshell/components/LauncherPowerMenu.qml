pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "../services"
import ".."

Rectangle {
    id: menu

    required property var launcher

    width: 170
    height: 198
    visible: launcher.powerMenuOpen
    color: Theme.base01
    border.width: 1
    border.color: PanelService.chromeBorderColor
    radius: PanelService.rounding

    Column {
        anchors.fill: parent
        anchors.margins: 5
        spacing: 2

        Repeater {
            model: [
                { icon: "󰌾", label: "Lock", command: ["qs", "ipc", "call", "lock", "activate"] },
                { icon: "󰒲", label: "Sleep", command: ["systemctl", "suspend"] },
                { icon: "󰤄", label: "Hibernate", command: ["systemctl", "hibernate"] },
                { icon: "󰜉", label: "Restart", command: ["systemctl", "reboot"] },
                { icon: "󰐥", label: "Shut down", command: ["systemctl", "poweroff"] }
            ]

            delegate: Rectangle {
                id: action

                required property var modelData

                width: parent.width
                height: 36
                radius: PanelService.rounding
                color: actionMouse.containsMouse
                    ? Utils.alpha(Theme.base05, 0.11) : "transparent"

                ShellText {
                    anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                    text: action.modelData.icon
                    size: 13
                }

                ShellText {
                    anchors { left: parent.left; leftMargin: 38; verticalCenter: parent.verticalCenter }
                    text: action.modelData.label
                    size: 12
                }

                MouseArea {
                    id: actionMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        menu.launcher.open = false;
                        Quickshell.execDetached(action.modelData.command);
                    }
                }
            }
        }
    }
}
