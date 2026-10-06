import QtQuick
import "../primitives"
import "../../services"
import "../.."

// Small square icon button embedded in a list row (disconnect, forget, cancel, ...).
Rectangle {
    id: root

    property string icon: ""
    property real iconSize: 12

    signal clicked()

    implicitWidth: visible ? 28 : 0
    implicitHeight: 28
    radius: PanelService.rounding
    opacity: enabled ? 1 : 0.5
    color: mouseArea.containsMouse ? Utils.alpha(Theme.base05, 0.12) : "transparent"
    border.width: 1
    border.color: Utils.alpha(Theme.base05, 0.3)

    ShellText {
        anchors.centerIn: parent
        text: root.icon
        size: root.iconSize
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
