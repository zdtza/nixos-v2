pragma ComponentBehavior: Bound

// BlueZ device panel matching Network panel interaction and styling.
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Hyprland
import Stylix

Item {
    id: root

    readonly property bool available: BluetoothService.available
    readonly property bool opened: PanelService.activePanel === root
    readonly property var devices: BluetoothService.devices
    readonly property var connectedDevices: BluetoothService.enabled
        ? devices.filter(device => BluetoothService.isConnected(device)) : []
    readonly property var availableDevices: BluetoothService.enabled
        ? devices.filter(device => !BluetoothService.isConnected(device)) : []
    readonly property int deviceRowHeight: 48
    readonly property int deviceRowSpacing: 8
    readonly property int deviceSectionSpacing: 14
    readonly property int emptyStateHeight: 52
    readonly property var phrases: [
        "TRADING SIGNALS", "LINKING AIRWAVES", "KEEPING IN TOUCH",
        "MOVING THROUGH THE AIR", "TALKING WIRELESSLY"
    ]
    readonly property string statusText: {
        if (!BluetoothService.enabled) return "BLUETOOTH OFF";
        for (const device of devices) {
            if (device.pairing) return "PAIRING";
            if (device.state === BluetoothDeviceState.Connecting) return "CONNECTING";
            if (device.state === BluetoothDeviceState.Disconnecting) return "DISCONNECTING";
        }
        if (connectedDevices.length > 0)
            return phrases[phraseIndex % phrases.length];
        return BluetoothService.adapter && BluetoothService.adapter.discovering
            ? "DISCOVERING" : "READY TO CONNECT";
    }

    property int phraseIndex: 0

    visible: available
    implicitWidth: available ? indicator.implicitWidth : 0
    implicitHeight: indicator.implicitHeight

    onOpenedChanged: {
        if (opened) {
            phraseIndex = 0;
            BluetoothService.acquireScanner();
        } else {
            BluetoothService.releaseScanner();
        }
    }
    onAvailableChanged: if (!available)
        PanelService.close(root)
    Component.onDestruction: if (opened)
        BluetoothService.releaseScanner()

    PanelStatusRotator {
        target: bluetoothHero.statusLabel
        running: root.opened && BluetoothService.enabled
            && root.connectedDevices.length > 0
        onAdvance: root.phraseIndex = (root.phraseIndex + 1) % root.phrases.length
    }

    BarButton {
        id: indicator
        anchors.centerIn: parent
        panel: root
        text: BluetoothService.icon
        onClicked: PanelService.toggle(root)
    }

    HyprlandFocusGrab {
        active: root.opened
        windows: [panel, root.QsWindow.window]
        onCleared: PanelService.close(root)
    }

    PanelPopup {
        id: panel
        anchorItem: root
        anchorWindow: root.QsWindow.window
        visible: root.opened
        onCloseRequested: PanelService.close(root)
        borderColor: Theme.border
        contentSpacing: 14
        readonly property real maximumHeight: Math.max(260,
            (root.QsWindow.window && root.QsWindow.window.screen
                ? root.QsWindow.window.screen.height : 800) - 55)
        readonly property real panelChromeHeight: 98
        // Use stable section counts instead of Column.implicitHeight. Popup
        // follows actual content while ignoring transient delegate layouts.
        readonly property real connectedSectionHeight: root.connectedDevices.length > 0
            ? connectedHeader.implicitHeight
                + root.connectedDevices.length * (root.deviceRowHeight + root.deviceRowSpacing)
            : 0
        readonly property real availableSectionHeight: availableHeader.implicitHeight
            + (root.availableDevices.length > 0
                ? root.availableDevices.length * (root.deviceRowHeight + root.deviceRowSpacing)
                : root.deviceRowSpacing + root.emptyStateHeight)
        readonly property real desiredDeviceHeight: connectedSectionHeight
            + availableSectionHeight
            + (root.connectedDevices.length > 0 ? root.deviceSectionSpacing : 0)
        readonly property real deviceViewportHeight: Math.min(420,
            Math.max(80, maximumHeight - panelChromeHeight), desiredDeviceHeight)

        implicitWidth: 460
        implicitHeight: Math.min(maximumHeight, panelChromeHeight + deviceViewportHeight)

        PanelHero {
            id: bluetoothHero
            width: parent.width
            icon: BluetoothService.icon
            title: "Bluetooth"
            status: root.statusText
            trailingWidth: 44
            trailingHeight: 24

            Rectangle {
                anchors.fill: parent
                color: BluetoothService.enabled
                    ? Theme.foreground
                    : Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.18)
                border.width: 1
                border.color: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.4)
                Behavior on color { ColorAnimation { duration: 120 } }

                Rectangle {
                    width: 18
                    height: 18
                    y: 3
                    x: BluetoothService.enabled ? parent.width - width - 3 : 3
                    color: BluetoothService.enabled ? Theme.background : Theme.foreground
                    Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: BluetoothService.toggle()
                }
            }
        }

        PanelSeparator {}

        Item {
            width: parent.width
            height: panel.deviceViewportHeight
            clip: true

            Flickable {
                id: deviceList
                anchors.fill: parent
                contentHeight: deviceColumn.implicitHeight
                clip: true
                interactive: contentHeight > height
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.VerticalFlick

                Column {
                    id: deviceColumn
                    width: deviceList.width
                    spacing: root.deviceSectionSpacing

                    Column {
                        width: parent.width
                        spacing: root.deviceRowSpacing
                        visible: root.connectedDevices.length > 0

                        PanelSectionHeader {
                            id: connectedHeader
                            title: "CONNECTED"
                            detail: root.connectedDevices.length > 1
                                ? root.connectedDevices.length + " DEVICES" : ""
                        }

                        Repeater {
                            model: root.connectedDevices

                            DeviceRow {
                                required property var modelData
                                device: modelData
                                actionIcon: "󰅖"
                                actionVisible: true
                                actionLabel: "Disconnect"
                                secondaryActionIcon: "󰆴"
                                secondaryActionVisible: true
                                secondaryActionLabel: "Forget"
                                onActionTriggered: BluetoothService.disconnect(modelData)
                                onSecondaryActionTriggered: BluetoothService.forget(modelData)
                            }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: root.deviceRowSpacing

                        PanelSectionHeader {
                            id: availableHeader
                            title: "AVAILABLE"
                            detail: BluetoothService.adapter && BluetoothService.adapter.discovering
                                ? "DISCOVERING" : "READY"
                        }

                        Text {
                            width: parent.width
                            height: root.emptyStateHeight
                            visible: root.availableDevices.length === 0
                            text: BluetoothService.enabled
                                ? "No available devices" : "Bluetooth is turned off"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                        }

                        Repeater {
                            model: root.availableDevices

                            DeviceRow {
                                required property var modelData
                                device: modelData
                                clickable: !modelData.pairing
                                actionIcon: "󰆴"
                                actionVisible: modelData.paired
                                actionLabel: "Forget"
                                onActivated: BluetoothService.activate(modelData)
                                onActionTriggered: BluetoothService.forget(modelData)
                            }
                        }
                    }
                }
            }
        }
    }

    component DeviceRow: Rectangle {
        id: deviceRow

        required property var device
        property bool clickable: false
        property bool actionVisible: false
        property string actionIcon: ""
        property string actionLabel: ""
        property bool secondaryActionVisible: false
        property string secondaryActionIcon: ""
        property string secondaryActionLabel: ""

        signal activated()
        signal actionTriggered()
        signal secondaryActionTriggered()

        width: parent.width
        height: root.deviceRowHeight
        color: rowHover.hovered
            ? Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.08)
            : "transparent"
        border.width: rowHover.hovered ? 1 : 0
        border.color: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.25)
        Behavior on color { ColorAnimation { duration: 120 } }

        HoverHandler { id: rowHover }

        Text {
            id: deviceIcon
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: BluetoothService.deviceIcon(deviceRow.device)
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: 16
        }

        Column {
            anchors.left: deviceIcon.right
            anchors.leftMargin: 10
            anchors.right: actionRow.visible ? actionRow.left : stateIcon.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
                width: parent.width
                text: BluetoothService.deviceLabel(deviceRow.device)
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: 12
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: {
                    if (deviceRow.device.pairing) return "Pairing…";
                    if (deviceRow.device.state === BluetoothDeviceState.Connecting)
                        return "Connecting…";
                    if (deviceRow.device.state === BluetoothDeviceState.Disconnecting)
                        return "Disconnecting…";
                    if (BluetoothService.isConnected(deviceRow.device)) {
                        if (deviceRow.device.batteryAvailable)
                            return "Connected · " + Math.round(Number(deviceRow.device.battery) * 100) + "%";
                        return "Connected";
                    }
                    return deviceRow.device.paired ? "Paired" : "Available";
                }
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 11
                elide: Text.ElideRight
            }
        }

        Row {
            id: actionRow
            z: 2
            visible: rowHover.hovered
                && (deviceRow.actionVisible || deviceRow.secondaryActionVisible)
            anchors.right: stateIcon.left
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Rectangle {
                visible: deviceRow.actionVisible
                width: visible ? 28 : 0
                height: 28
                color: actionMouse.containsMouse
                    ? Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.12)
                    : "transparent"
                border.width: 1
                border.color: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.3)

                Text {
                    anchors.centerIn: parent
                    text: deviceRow.actionIcon
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                }
                MouseArea {
                    id: actionMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => {
                        mouse.accepted = true;
                        deviceRow.actionTriggered();
                    }
                }
            }

            Rectangle {
                visible: deviceRow.secondaryActionVisible
                width: visible ? 28 : 0
                height: 28
                color: secondaryActionMouse.containsMouse
                    ? Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.12)
                    : "transparent"
                border.width: 1
                border.color: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.3)

                Text {
                    anchors.centerIn: parent
                    text: deviceRow.secondaryActionIcon
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                }
                MouseArea {
                    id: secondaryActionMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => {
                        mouse.accepted = true;
                        deviceRow.secondaryActionTriggered();
                    }
                }
            }
        }

        Text {
            id: stateIcon
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: BluetoothService.isConnected(deviceRow.device) ? "󰂱"
                : (deviceRow.device.paired ? "󰌾" : "")
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 12
        }

        MouseArea {
            anchors.fill: parent
            z: 1
            enabled: deviceRow.clickable
            hoverEnabled: true
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: deviceRow.activated()
        }
    }
}
