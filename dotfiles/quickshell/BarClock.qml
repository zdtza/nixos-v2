// Date and time with anchored calendar panel.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Stylix

Item {
    id: root

    readonly property bool opened: ServicePanel.activePanel === root
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
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        color: Theme.foreground
    }

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: label.left
        anchors.right: label.right
        height: 2
        radius: ServicePanel.rounding
        visible: root.opened || mouseArea.containsMouse
        color: Theme.accent
    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: ServicePanel.toggle(root)
    }

    HyprlandFocusGrab {
        active: root.opened
        windows: [calendar, root.QsWindow.window]
        onCleared: ServicePanel.close(root)
    }

    PanelCalendar {
        id: calendar

        anchorItem: root
        anchorWindow: root.QsWindow.window
        visible: root.opened
        onCloseRequested: ServicePanel.close(root)
    }
}
