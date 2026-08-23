import QtQuick
import Stylix

// Live microphone peak meter.
Item {
    id: root

    property real level: 0
    property bool muted: false

    implicitHeight: 6

    Rectangle {
        anchors.fill: parent
        color: Util.alpha(Theme.foreground, 0.12)

        Rectangle {
            height: parent.height
            width: parent.width * Math.max(0, Math.min(1, root.level))
            color: root.muted ? Theme.muted : Theme.foreground
            Behavior on width { NumberAnimation { duration: 55 } }
        }
    }
}
