// Small countdown badge next to the clock. Shows the timer with the least
// remaining time when one or more timers are running; hidden otherwise.
import QtQuick
import "../services"
import ".."

Item {
    id: root

    property var panelTarget: null

    readonly property bool active: TimerService.running
    readonly property string display: TimerService.formatDuration(TimerService.remainingSeconds)

    implicitWidth: active ? content.implicitWidth + 16 : 0
    implicitHeight: 20
    clip: true
    opacity: active ? 1 : 0

    Behavior on implicitWidth {
        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
    }

    Behavior on opacity {
        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Utils.alpha(Theme.base05, 0.1)
        border.width: 1
        border.color: Utils.alpha(Theme.base05, 0.3)
    }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 4

        ShellText {
            anchors.verticalCenter: parent.verticalCenter
            text: "󱎫"
            size: 11
        }

        ShellText {
            anchors.verticalCenter: parent.verticalCenter
            text: root.display
            size: 11
            font.weight: Font.Medium
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.active && root.panelTarget !== null
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: PanelService.toggle(root.panelTarget)
    }
}
