// Compact bar clock with a full date-and-time panel.
import QtQuick
import Quickshell
import "../panels"
import "../services"

Item {
    id: root

    readonly property bool opened: PanelService.activePanel === root
    readonly property bool timerOpened: PanelService.activePanel === timerControl
    readonly property bool requiresKeyboardFocus: true
    readonly property alias timerPanel: timerControl

    implicitWidth: label.implicitWidth + 16
    implicitHeight: PanelService.barItemHeight

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Rectangle {
        visible: opacity > 0
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

        anchors.centerIn: parent
        anchors.verticalCenterOffset: -1
        text: Qt.formatDateTime(clock.date, "dddd HH:mm")
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


    TimerTogglePanel {
        id: timerControl
        showButton: false
    }

    ClockPanel {
        id: panel
        anchorItem: root
    }
}
