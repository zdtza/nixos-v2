// Compact bar clock with a full date-and-time panel.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../panels"
import "../services"

Item {
    id: root

    property bool showButton: true
    readonly property bool opened: PanelService.activePanel === root
    readonly property bool timerOpened: PanelService.activePanel === timerControl
    readonly property bool requiresKeyboardFocus: true
    readonly property alias timerPanel: timerControl

    implicitWidth: showButton ? label.implicitWidth + 16 : 0
    implicitHeight: 26

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Rectangle {
        visible: root.showButton && opacity > 0
        anchors.bottom: parent.bottom
        anchors.left: label.left
        anchors.right: label.right
        height: 2
        radius: PanelService.rounding
        opacity: root.opened || root.timerOpened || mouseArea.containsMouse ? 1 : 0
        color: Theme.base05

        Behavior on opacity { NumberAnimation { duration: 120 } }
    }

    ShellText {
        id: label

        visible: root.showButton
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -1
        text: Qt.formatDateTime(clock.date, "HH:mm")
        font.pixelSize: 13
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        enabled: root.showButton
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
