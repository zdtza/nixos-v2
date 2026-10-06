pragma ComponentBehavior: Bound

// BlueZ device panel matching Network panel interaction and styling.
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import "../components/bar"
import "../components/panels"
import "../components/primitives"
import "../services"
import ".."

Item {
    id: root

    readonly property bool available: BluetoothService.available
    readonly property bool opened: PanelService.activePanel === root
    readonly property bool requiresKeyboardFocus: true
    readonly property var devices: BluetoothService.devices
    readonly property var connectedDevices: BluetoothService.powered
        ? devices.filter(device => BluetoothService.isConnected(device)) : []
    readonly property var availableDevices: BluetoothService.powered
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
        if (!BluetoothService.powered) return "BLUETOOTH OFF";
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

    function deviceStatus(device: var): string {
        if (device.pairing) return "Pairing…";
        if (device.state === BluetoothDeviceState.Connecting) return "Connecting…";
        if (device.state === BluetoothDeviceState.Disconnecting) return "Disconnecting…";
        if (BluetoothService.isConnected(device))
            return device.batteryAvailable
                ? "Connected · " + Math.round(Number(device.battery) * 100) + "%" : "Connected";
        return device.paired ? "Paired" : "Available";
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

    PanelShortcut {
        enabled: root.opened
        sequences: ["Up"]
        onActivated: root.selectDevice(-1)
    }
    PanelShortcut {
        enabled: root.opened
        sequences: ["Down"]
        onActivated: root.selectDevice(1)
    }
    PanelShortcut {
        enabled: root.opened
        sequences: ["Return", "Enter"]
        onActivated: root.activateSelectedDevice()
    }
    PanelShortcut {
        enabled: root.opened
        sequences: ["Space"]
        onActivated: BluetoothService.toggle()
    }
    PanelShortcut {
        enabled: root.opened
        sequences: ["Delete"]
        onActivated: root.forgetSelectedDevice()
    }

    StatusRotator {
        target: bluetoothHero.statusLabel
        running: root.opened && BluetoothService.powered
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


    Drawer {
        id: panel
        anchorItem: root
        readonly property real panelChromeHeight: contentTopMargin
            + contentBottomMargin + bluetoothHero.implicitHeight
            + bluetoothSeparator.height + contentSpacing * 2
        // Use stable section counts instead of Column.implicitHeight.
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

        Hero {
            id: bluetoothHero
            width: parent.width
            icon: BluetoothService.icon
            title: "Bluetooth"
            status: root.statusText
            ToggleSwitch {
                checked: BluetoothService.powered
                onToggled: BluetoothService.toggle()
            }
        }

        Separator { id: bluetoothSeparator }

        ScrollArea {
            id: deviceList
            width: parent.width
            height: panel.deviceViewportHeight
            contentHeight: deviceColumn.implicitHeight

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
                            id: connectedRow
                            clickable: false

                            RowActionButton {
                                icon: "󰅖"
                                onClicked: BluetoothService.disconnect(connectedRow.modelData)
                            }
                            RowActionButton {
                                icon: "󰆴"
                                onClicked: BluetoothService.forget(connectedRow.modelData)
                            }
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

                    ShellText {
                        width: parent.width
                        height: root.emptyStateHeight
                        visible: root.availableDevices.length === 0
                        text: BluetoothService.powered
                            ? "No available devices" : "Bluetooth is turned off"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        color: Theme.textSecondary
                        size: 12
                    }

                    Repeater {
                        model: root.availableDevices

                        DeviceRow {
                            id: availableRow
                            clickable: !modelData.pairing
                            onActivated: BluetoothService.activate(modelData)

                            RowActionButton {
                                visible: availableRow.modelData.paired
                                icon: "󰆴"
                                onClicked: BluetoothService.forget(availableRow.modelData)
                            }
                        }
                    }
                }
            }
        }
    }

    component DeviceRow: ListRow {
        required property var modelData

        height: root.deviceRowHeight
        icon: BluetoothService.deviceIcon(modelData)
        title: BluetoothService.deviceLabel(modelData)
        subtitle: root.deviceStatus(modelData)
        trailingIcon: BluetoothService.isConnected(modelData) ? "󰂱" : (modelData.paired ? "󰌾" : "")
        selected: root.selectedDevice === modelData
        onHoverSelected: root.selectedDevice = modelData
        onActivated: root.selectedDevice = modelData
    }
}
