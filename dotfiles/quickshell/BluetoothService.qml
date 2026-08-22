pragma Singleton

// Shared BlueZ state and actions for every per-screen Bluetooth panel.
import QtQuick
import Quickshell.Bluetooth
import Quickshell.Io

Item {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool available: !!adapter
    readonly property bool enabled: available && adapter.enabled
    readonly property var deviceObjects: Bluetooth.devices ? Bluetooth.devices.values : []
    readonly property var devices: sortedDevices()
    readonly property var connectedDevices: devices.filter(device => device.connected)
    readonly property var connectedDevice: connectedDevices.length > 0 ? connectedDevices[0] : null
    readonly property bool busy: devices.some(device => device.pairing
        || device.state === BluetoothDeviceState.Connecting
        || device.state === BluetoothDeviceState.Disconnecting)
    readonly property string icon: !enabled ? "󰂲" : connectedDevices.length > 0 ? "󰂱" : "󰂯"

    property int scannerUsers: 0
    property bool scannerActive: false

    // BluetoothDevice.pair() delegates authentication to BlueZ. Keep a
    // no-input/no-output agent registered so mice, keyboards, and other
    // Just-Works devices can complete authentication instead of briefly
    // connecting and failing with "No agent available".
    Process {
        running: true
        stdinEnabled: true
        command: ["sh", "-c",
            "exec bluetoothctl --agent NoInputNoOutput >/dev/null 2>&1"]
    }

    function sortedDevices(): var {
        const rows = deviceObjects.filter(device => device && device.adapter === adapter);
        rows.sort((a, b) => {
            if (a.connected !== b.connected) return a.connected ? -1 : 1;
            if (a.paired !== b.paired) return a.paired ? -1 : 1;
            return deviceLabel(a).localeCompare(deviceLabel(b));
        });
        return rows;
    }

    function deviceLabel(device: var): string {
        if (!device) return "Unknown device";
        return device.name || device.deviceName || device.address || "Unknown device";
    }

    function deviceIcon(device: var): string {
        const icon = String(device && device.icon ? device.icon : "").toLowerCase();
        if (icon.includes("head") || icon.includes("audio")) return "󰋋";
        if (icon.includes("keyboard")) return "󰌌";
        if (icon.includes("mouse")) return "󰍽";
        if (icon.includes("phone")) return "󰏲";
        if (icon.includes("game")) return "󰊴";
        return "󰂯";
    }

    function toggle(): void {
        if (available) adapter.enabled = !adapter.enabled;
    }

    function activate(device: var): void {
        if (!enabled || !device || device.connected || device.pairing) return;
        // Explicit selection is consent to trust device for future reconnects.
        device.trusted = true;
        if (device.paired) device.connect();
        else device.pair();
    }

    function disconnect(device: var): void {
        if (device && device.connected) device.disconnect();
    }

    function forget(device: var): void {
        if (device && device.paired) device.forget();
    }

    function acquireScanner(): void {
        scannerUsers++;
        updateScanner();
    }

    function releaseScanner(): void {
        scannerUsers = Math.max(0, scannerUsers - 1);
        updateScanner();
    }

    function updateScanner(): void {
        if (!adapter) return;
        const shouldScan = scannerUsers > 0 && adapter.enabled;
        if (!shouldScan && scannerActive) {
            scannerActive = false;
            if (adapter.discovering) adapter.discovering = false;
        }
    }

    // BlueZ may report Enabled briefly before discovery is ready. Retry at a
    // low rate while panel is open instead of leaving scanner stuck off.
    Timer {
        interval: 750
        repeat: true
        running: root.scannerUsers > 0 && root.adapter && root.adapter.enabled
            && root.adapter.state === BluetoothAdapterState.Enabled
            && !root.adapter.discovering
        onTriggered: {
            root.scannerActive = true;
            root.adapter.discovering = true;
        }
    }

    onAdapterChanged: {
        scannerActive = false;
        updateScanner();
    }
    onEnabledChanged: updateScanner()
}
