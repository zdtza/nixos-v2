// Small countdown badge next to the clock.
import QtQuick
import "../primitives"
import "../../services"
import "../.."

Item {
    id: root

    property var panelTarget: null

    readonly property bool active: TimerService.running
    readonly property string display: TimerService.formatDuration(TimerService.remainingSeconds)

    implicitWidth: active ? content.implicitWidth + 16 : 0
    // Full bar height so the pill centres on the bar like every other control.
    implicitHeight: PanelService.barItemHeight
    clip: true
    opacity: active ? 1 : 0

    Behavior on implicitWidth {
        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
    }

    Behavior on opacity {
        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
    }

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 20
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
