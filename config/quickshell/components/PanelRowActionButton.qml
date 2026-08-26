import QtQuick
import Stylix
import "../services"
import ".."

// Small square icon button embedded in a list row (disconnect, forget,
// cancel, ...). Accepts its click so it doesn't also activate the row
// underneath it.
Rectangle {
    id: root

    property string icon: ""

    signal clicked()

    width: visible ? 28 : 0
    height: 28
    radius: ServicePanel.rounding
    color: mouseArea.containsMouse ? Utils.alpha(Theme.foreground, 0.12) : "transparent"
    border.width: 1
    border.color: Utils.alpha(Theme.foreground, 0.3)

    Text {
        anchors.centerIn: parent
        text: root.icon
        color: Theme.foreground
        font.family: Theme.fontFamily
        font.pixelSize: Utils.scaledFont(12)
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            mouse.accepted = true;
            root.clicked();
        }
    }
}
