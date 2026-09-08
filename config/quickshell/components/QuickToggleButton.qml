import QtQuick
import "../services"

// Icon-only control inside a QuickToggleSlot. Set `interactive: false` for
// indicator-only cells that report state but can't be clicked (screen
// recording), which is why the click handler is a signal rather than assumed.
Item {
    id: root

    property string icon: ""
    property bool active: false
    property color activeColor: Theme.base05
    property color inactiveColor: Theme.base04
    property bool interactive: true

    signal clicked()

    anchors.fill: parent

    ShellText {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -1
        text: root.icon
        color: root.active ? root.activeColor : root.inactiveColor
        size: 14

        Behavior on color { ColorAnimation { duration: 120 } }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.interactive
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
