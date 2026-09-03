pragma ComponentBehavior: Bound

// BlueZ device panel matching Network panel interaction and styling.
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Hyprland
import Stylix
import "../components"
import "../services"
import ".."

Item {
    id: root

    readonly property bool available: BluetoothService.available
    readonly property bool opened: PanelService.activePanel === root
    readonly property bool requiresKeyboardFocus: true
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
            ? "SCANNING" : "READY TO CONNECT";
    }

    property int phraseIndex: 0
    property var selectedDevice: null
    readonly property var keyboardDevices: connectedDevices.concat(availableDevices)

    visible: available
    implicitWidth: available ? indicator.implicitWidth : 0
    implicitHeight: indicator.implicitHeight

    function selectDevice(offset: int): void {
        if (keyboardDevices.length === 0) {
            selectedDevice = null;
            return;
        }
        let index = keyboardDevices.indexOf(selectedDevice);
        if (index < 0)
            index = offset > 0 ? 0 : keyboardDevices.length - 1;
        else
            index = Math.max(0, Math.min(keyboardDevices.length - 1, index + offset));
        selectedDevice = keyboardDevices[index];
        let headerCount = connectedDevices.length > 0 ? 1 : 0;
        if (index >= connectedDevices.length)
            headerCount++;
        const rowTop = index * (deviceRowHeight + deviceRowSpacing)
            + headerCount * (connectedHeader.implicitHeight + deviceRowSpacing);
        if (rowTop < deviceList.contentY)
            deviceList.contentY = rowTop;
        else if (rowTop + deviceRowHeight > deviceList.contentY + deviceList.height)
            deviceList.contentY = Math.max(0, rowTop + deviceRowHeight - deviceList.height);
    }

    function activateSelectedDevice(): void {
        if (!selectedDevice)
            return;
        if (BluetoothService.isConnected(selectedDevice))
            BluetoothService.disconnect(selectedDevice);
        else
            BluetoothService.activate(selectedDevice);
    }

    function forgetSelectedDevice(): void {
        if (selectedDevice && selectedDevice.paired)
            BluetoothService.forget(selectedDevice);
    }

    onOpenedChanged: {
        if (opened) {
            phraseIndex = 0;
            selectedDevice = keyboardDevices.length > 0 ? keyboardDevices[0] : null;
            BluetoothService.acquireScanner();
        } else {
            BluetoothService.releaseScanner();
        }
    }
    onKeyboardDevicesChanged: {
        if (keyboardDevices.length === 0)
            selectedDevice = null;
        else if (!keyboardDevices.includes(selectedDevice))
            selectedDevice = keyboardDevices[0];
    }
    onAvailableChanged: if (!available)
        PanelService.close(root)
    Component.onDestruction: if (opened)
        BluetoothService.releaseScanner()

    Shortcut {
        enabled: root.opened
        sequence: "Up"
        context: Qt.ApplicationShortcut
        onActivated: root.selectDevice(-1)
    }
    Shortcut {
        enabled: root.opened
        sequence: "Down"
        context: Qt.ApplicationShortcut
        onActivated: root.selectDevice(1)
    }
    Shortcut {
        enabled: root.opened
        sequence: "Return"
        context: Qt.ApplicationShortcut
        onActivated: root.activateSelectedDevice()
    }
    Shortcut {
        enabled: root.opened
        sequence: "Enter"
        context: Qt.ApplicationShortcut
        onActivated: root.activateSelectedDevice()
    }
    Shortcut {
        enabled: root.opened
        sequence: "Space"
        context: Qt.ApplicationShortcut
        onActivated: BluetoothService.toggle()
    }
    Shortcut {
        enabled: root.opened
        sequence: "Delete"
        context: Qt.ApplicationShortcut
        onActivated: root.forgetSelectedDevice()
    }

    StatusRotator {
        target: bluetoothHero.statusLabel
        running: root.opened && BluetoothService.enabled
            && root.connectedDevices.length > 0
        onAdvance: root.phraseIndex = (root.phraseIndex + 1) % root.phrases.length
    }

    Button {
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

    Drawer {
        id: panel
        anchorItem: root
        anchorWindow: root.QsWindow.window
        open: root.opened
        onCloseRequested: PanelService.close(root)
        contentSpacing: 14
        readonly property real maximumHeight: Math.max(260,
            (root.QsWindow.window && root.QsWindow.window.screen
                ? root.QsWindow.window.screen.height : 800) - 55)
        readonly property real panelChromeHeight: contentTopMargin
            + contentBottomMargin + bluetoothHero.implicitHeight
            + bluetoothSeparator.height + contentSpacing * 2
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

        implicitWidth: 460 + PanelService.shellRounding
        implicitHeight: Math.min(maximumHeight, panelChromeHeight + deviceViewportHeight)

        Hero {
            id: bluetoothHero
            width: parent.width
            icon: BluetoothService.icon
            title: "Bluetooth"
            status: root.statusText
            trailingWidth: 44
            trailingHeight: 24

            ToggleSwitch {
                anchors.fill: parent
                checked: BluetoothService.enabled
                onToggled: BluetoothService.toggle()
            }
        }

        Separator { id: bluetoothSeparator }

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

                        SectionHeader {
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
                                keyboardSelected: root.selectedDevice === modelData
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

                        SectionHeader {
                            id: availableHeader
                            title: "AVAILABLE"
                            detail: BluetoothService.adapter && BluetoothService.adapter.discovering
                                ? "SCANNING" : "READY"
                        }

                        Text {
                            width: parent.width
                            height: root.emptyStateHeight
                            visible: root.availableDevices.length === 0
                            text: BluetoothService.enabled
                                ? "No available devices" : "Bluetooth is turned off"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            color: Theme.base04
                            font.family: Theme.monospace
                            font.pixelSize: Utils.scaledFont(12)
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
                                keyboardSelected: root.selectedDevice === modelData
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
        property bool keyboardSelected: false
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
        radius: PanelService.rounding
        color: keyboardSelected
            ? Utils.alpha(Theme.base05, 0.08)
            : "transparent"
        border.width: keyboardSelected ? 1 : 0
        border.color: Utils.alpha(Theme.base05, 0.25)

        HoverHandler {
            id: rowHover
            onHoveredChanged: if (hovered)
                root.selectedDevice = deviceRow.device
        }

        Text {
            id: deviceIcon
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: BluetoothService.deviceIcon(deviceRow.device)
            color: Theme.base05
            font.family: Theme.monospace
            font.pixelSize: Utils.scaledFont(16)
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
                color: Theme.base05
                font.family: Theme.monospace
                font.pixelSize: Utils.scaledFont(12)
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
                color: Theme.base04
                font.family: Theme.monospace
                font.pixelSize: Utils.scaledFont(11)
                elide: Text.ElideRight
            }
        }

        Row {
            id: actionRow
            z: 2
            visible: deviceRow.keyboardSelected
                && (deviceRow.actionVisible || deviceRow.secondaryActionVisible)
            anchors.right: stateIcon.left
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            RowActionButton {
                visible: deviceRow.actionVisible
                icon: deviceRow.actionIcon
                onClicked: deviceRow.actionTriggered()
            }

            RowActionButton {
                visible: deviceRow.secondaryActionVisible
                icon: deviceRow.secondaryActionIcon
                onClicked: deviceRow.secondaryActionTriggered()
            }
        }

        Text {
            id: stateIcon
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: BluetoothService.isConnected(deviceRow.device) ? "󰂱"
                : (deviceRow.device.paired ? "󰌾" : "")
            color: Theme.base04
            font.family: Theme.monospace
            font.pixelSize: Utils.scaledFont(12)
        }

        MouseArea {
            anchors.fill: parent
            z: 1
            enabled: deviceRow.clickable
            hoverEnabled: true
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: {
                root.selectedDevice = deviceRow.device;
                deviceRow.activated();
            }
        }
    }
}
