import QtQuick
import "../services"
import ".."

// Icon-only control inside a QuickToggleSlot.
Item {
    id: root

    property string icon: ""
    property bool active: false
    property color activeColor: Theme.base05
    property color inactiveColor: Theme.base04
    property bool interactive: true

    signal clicked()

    anchors.fill: parent

    Rectangle {
        anchors.fill: parent
        radius: 4
        color: mouseArea.containsMouse ? Utils.alpha(Theme.base05, 0.16) : "transparent"
    }

    ShellText {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -1
        text: root.icon
        color: root.active ? root.activeColor : root.inactiveColor
        size: 14

        Behavior on color { ColorAnimation { duration: 120 } }
    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        enabled: root.interactive
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
