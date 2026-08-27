import QtQuick
import Stylix
import "../services"
import ".."

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

    Behavior on opacity { NumberAnimation { duration: 120 } }

    Rectangle {
        anchors.fill: parent
        radius: ServicePanel.rounding
        color: switchMouse.pressed
            ? Utils.alpha(Theme.foreground, 0.16)
            : root.checked
                ? Utils.alpha(Theme.foreground,
                    switchMouse.containsMouse ? 0.12 : 0.08)
                : switchMouse.containsMouse
                    ? Utils.alpha(Theme.foreground, 0.04)
                    : "transparent"
        border.width: 1
        border.color: root.checked
            ? Utils.alpha(Theme.foreground,
                switchMouse.containsMouse ? 0.35 : 0.25)
            : Utils.alpha(Theme.foreground,
                switchMouse.containsMouse ? 0.25 : 0.15)
        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on border.color { ColorAnimation { duration: 120 } }

        Rectangle {
            width: 16
            height: 16
            y: 4
            x: root.checked ? parent.width - width - 4 : 4
            radius: ServicePanel.rounding
            color: root.checked ? Theme.foreground : Theme.muted
            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        }

        MouseArea {
            id: switchMouse
            anchors.fill: parent
            enabled: root.available
            hoverEnabled: true
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: root.toggled()
        }
    }
}
