// Battery level from UPower's display device. Hidden on desktops.
import QtQuick
import Quickshell.Services.UPower
import Stylix

Item {
    id: root

    readonly property var device: UPower.displayDevice
    readonly property bool available: device && device.isLaptopBattery && device.isPresent
    readonly property int percent: device ? Math.round(device.percentage * 100) : 0
    readonly property bool charging: device && (device.state === UPowerDeviceState.Charging || device.state === UPowerDeviceState.FullyCharged)
    readonly property bool low: !charging && percent <= 20

    visible: available
    implicitHeight: label.implicitHeight

    Text {
        id: label
        anchors.centerIn: parent
        text: {
            if (root.charging)
                return `󰂄`;
            if (root.percent >= 80)
                return `󰁹`;
            if (root.percent >= 50)
                return `󰁿`;
            if (root.percent >= 20)
                return `󰁻`;
            return `󰁺`;
        }
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        color: root.low ? Theme.urgent : Theme.foreground
    }
}
