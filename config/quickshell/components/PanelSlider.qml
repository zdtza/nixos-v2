import QtQuick
import Stylix
import ".."

// Square value slider shared by panel controls (volume, brightness, color
// temperature, ...).
Item {
    id: root

    property real value: 0
    property bool enabled: true
    property color fillColor: Theme.foreground

    signal valueEdited(real value)

    implicitHeight: 18

    function editAt(position: real): void {
        if (enabled)
            valueEdited(Math.max(0, Math.min(1, position / width)));
    }

    Rectangle {
        id: track
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: 5
        radius: height / 2
        color: Utils.alpha(Theme.foreground, 0.12)

        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, root.value))
            height: parent.height
            radius: height / 2
            color: root.fillColor
        }
    }

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        x: Math.max(0, Math.min(parent.width - width, parent.width * root.value - width / 2))
        width: 14
        height: 14
        radius: width / 2
        color: root.enabled ? Theme.foreground : Theme.muted
        border.width: 2
        border.color: Theme.background

        Behavior on color { ColorAnimation { duration: 120 } }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => root.editAt(mouse.x)
        onPositionChanged: mouse => {
            if (pressed)
                root.editAt(mouse.x);
        }
        onWheel: wheel => root.valueEdited(Math.max(0,
            Math.min(1, root.value + (wheel.angleDelta.y > 0 ? 0.04 : -0.04))))
    }
}
