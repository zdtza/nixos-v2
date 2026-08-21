// Battery level from UPower's display device. Hidden on desktops.
import QtQuick
import Stylix

Item {
    id: root

    visible: available
    implicitWidth: available ? label.implicitWidth : 0
    implicitHeight: label.implicitHeight

    Text {
        id: label
        anchors.centerIn: parent
        text: "󰤨"
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        color: Theme.foreground
    }
}
