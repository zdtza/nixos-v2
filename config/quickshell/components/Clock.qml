// Compact bar clock with a full date-and-time panel.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../panels"
import "../services"
import ".."

Item {
    id: root

    readonly property bool opened: PanelService.activePanel === root
    readonly property bool timerOpened: PanelService.activePanel === timerControl
    readonly property bool requiresKeyboardFocus: true
    readonly property alias timerPanel: timerControl

    implicitWidth: label.implicitWidth + 16
    implicitHeight: 26

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Rectangle {
        anchors.fill: parent
        radius: PanelService.rounding
        color: root.opened || root.timerOpened || mouseArea.containsMouse
            ? Utils.alpha(Theme.base05, 0.10) : "transparent"
    }

    ShellText {
        id: label

        anchors.centerIn: parent
        anchors.verticalCenterOffset: -1
        text: Qt.formatDateTime(clock.date, "HH:mm")
        font.pixelSize: 13
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                PanelService.toggle(timerControl);
            else
                PanelService.toggle(root);
        }
    }

    HyprlandFocusGrab {
        active: root.opened
        windows: [panel, root.QsWindow.window]
        onCleared: PanelService.close(root)
    }

    TimerTogglePanel {
        id: timerControl
        showButton: false
    }

    ClockPanel {
        id: panel
        anchorItem: root
        anchorWindow: root.QsWindow.window
        open: root.opened
        onCloseRequested: PanelService.close(root)
    }
}
