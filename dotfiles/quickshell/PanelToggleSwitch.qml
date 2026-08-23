import QtQuick
import Stylix

// On/off pill switch used in panel hero trailing slots (mute, radio power,
// wifi, night light).
Item {
    id: root

    property bool checked: false
    property bool available: true

    signal toggled()

    implicitWidth: 44
    implicitHeight: 24
    opacity: available ? 1 : 0.5

    Rectangle {
        anchors.fill: parent
        radius: ServicePanel.rounding
        color: root.checked ? Theme.foreground : Util.alpha(Theme.foreground, 0.18)
        border.width: 1
        border.color: Util.alpha(Theme.foreground, 0.4)
        Behavior on color { ColorAnimation { duration: 120 } }

        Rectangle {
            width: 18
            height: 18
            y: 3
            x: root.checked ? parent.width - width - 3 : 3
            radius: ServicePanel.rounding
            color: root.checked ? Theme.background : Theme.foreground
            Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        }

        MouseArea {
            anchors.fill: parent
            enabled: root.available
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: root.toggled()
        }
    }
}
