import QtQuick
import Quickshell
import "../services"
import ".."

Rectangle {
    id: footer

    required property var launcher

    height: 58
    color: Theme.base00
    border.width: 0

    Rectangle {
        anchors { left: parent.left; leftMargin: 28; verticalCenter: parent.verticalCenter }
        width: 30
        height: 30
        radius: 15
        color: Theme.base02

        ShellText { anchors.centerIn: parent; text: "󰀄"; size: 14 }
    }

    ShellText {
        anchors { left: parent.left; leftMargin: 70; verticalCenter: parent.verticalCenter }
        text: Quickshell.env("USER") || "user"
        size: 12
    }

    Rectangle {
        anchors { right: parent.right; rightMargin: 24; verticalCenter: parent.verticalCenter }
        width: 34
        height: 34
        radius: PanelService.rounding
        color: powerMouse.containsMouse || footer.launcher.powerMenuOpen
            ? Utils.alpha(Theme.base05, 0.12) : "transparent"

        ShellText { anchors.centerIn: parent; text: "󰐥"; size: 16 }

        MouseArea {
            id: powerMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: footer.launcher.powerMenuOpen = !footer.launcher.powerMenuOpen
        }
    }
}
