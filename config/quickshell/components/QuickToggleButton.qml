import QtQuick
import "../services"

// Icon-only control inside a QuickToggleSlot.
Item {
    id: root

    property string icon: ""
    property bool active: false
    property color activeColor: Theme.textPrimary
    property color inactiveColor: Theme.textSecondary
    property real iconSize: 14

    signal clicked()

    anchors.fill: parent

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: 16
        height: 2
        radius: PanelService.rounding
        visible: opacity > 0
        opacity: mouseArea.containsMouse ? 1 : 0
        color: Theme.base05

        Behavior on opacity { NumberAnimation { duration: 120 } }
    }

    ShellText {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -1
        text: root.icon
        color: root.active ? root.activeColor : root.inactiveColor
        size: root.iconSize

        Behavior on color { ColorAnimation { duration: 120 } }
    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
