// Date and time with anchored calendar panel.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Stylix
import "../panels"
import "../services"

Item {
    id: root

    readonly property bool opened: PanelService.activePanel === root
    readonly property bool requiresKeyboardFocus: true

    implicitWidth: label.implicitWidth + 16
    implicitHeight: 26

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Text {
        id: label

        anchors.centerIn: parent
        anchors.verticalCenterOffset: -1
        text: Qt.formatDateTime(clock.date, "dddd HH:mm")
        font.family: Theme.monospace
        // Keep clock compact even when rest of shell uses readability boost.
        font.pixelSize: Theme.fontSize
        color: Theme.base05
    }

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: label.left
        anchors.right: label.right
        height: 2
        radius: PanelService.rounding
        visible: opacity > 0
        opacity: root.opened || mouseArea.containsMouse ? 1 : 0
        color: Theme.base0D

        Behavior on opacity { NumberAnimation { duration: 120 } }
    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: PanelService.toggle(root)
    }

    HyprlandFocusGrab {
        active: root.opened
        windows: [calendar, root.QsWindow.window]
        onCleared: PanelService.close(root)
    }

    CalendarPanel {
        id: calendar

        anchorItem: root
        anchorWindow: root.QsWindow.window
        open: root.opened
        onCloseRequested: PanelService.close(root)
    }
}
