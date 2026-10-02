import QtQuick
import "../services"
import ".."

Rectangle {
    id: menu

    required property var launcher

    x: launcher.pinMenuX
    y: launcher.pinMenuY
    width: 180
    height: 44
    visible: launcher.pinMenuOpen && launcher.pinMenuItem !== null
    color: Theme.base01
    border.width: 1
    border.color: PanelService.chromeBorderColor
    radius: PanelService.rounding

    Rectangle {
        anchors.fill: parent
        anchors.margins: 4
        radius: PanelService.rounding
        color: pinMouse.containsMouse ? Utils.alpha(Theme.base05, 0.11) : "transparent"

        ShellText {
            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
            text: menu.launcher.isPinned(menu.launcher.pinMenuItem) ? "󰤱" : "󰐃"
            size: 13
        }

        ShellText {
            anchors {
                left: parent.left
                right: parent.right
                leftMargin: 40
                rightMargin: 12
                verticalCenter: parent.verticalCenter
            }
            text: menu.launcher.isPinned(menu.launcher.pinMenuItem)
                ? "Unpin from Start" : "Pin to Start"
            elide: Text.ElideRight
            size: 11
        }

        MouseArea {
            id: pinMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                menu.launcher.togglePinned(menu.launcher.pinMenuItem);
                menu.launcher.pinMenuOpen = false;
            }
        }
    }
}
