pragma Singleton

// Shared NetworkManager state and actions for every per-screen network widget.
import QtQuick
import Quickshell.Networking

Item {
    id: root

    readonly property bool backendAvailable: Networking.backend === NetworkBackendType.NetworkManager
    readonly property var devices: Networking.devices ? Networking.devices.values : []
    readonly property var wifiDevice: findDevice(DeviceType.Wifi)
    readonly property var wiredDevice: findDevice(DeviceType.Wired)
    readonly property var networkObjects: wifiDevice && wifiDevice.networks ? wifiDevice.networks.values : []
    readonly property var connectedWifi: findConnectedWifi()
    readonly property bool wifiAvailable: !!wifiDevice
    readonly property bool wifiEnabled: Networking.wifiEnabled
    readonly property string kind: wiredDevice && wiredDevice.connected
        ? "ethernet" : (connectedWifi ? "wifi" : "disconnected")
    readonly property int signalStrength: connectedWifi
        ? Math.round(Number(connectedWifi.signalStrength || 0) * 100) : -1
    readonly property string connectionName: kind === "ethernet"
        ? "Ethernet" : (connectedWifi ? connectedWifi.name : "Disconnected")
    readonly property string interfaceName: kind === "ethernet" && wiredDevice
        ? wiredDevice.name : (wifiDevice ? wifiDevice.name : "—")
    readonly property string connectivity: NetworkConnectivity.toString(Networking.connectivity)
    readonly property string icon: connectionIcon(kind, signalStrength)
    readonly property var wifiNetworks: snapshotNetworks()

    property int scannerUsers: 0

    function findDevice(type: int): var {
        let fallback = null;
        for (const device of devices) {
            if (!device || device.type !== type) continue;
            if (device.connected) return device;
            if (!fallback) fallback = device;
        }
        return fallback;
    }

    function findConnectedWifi(): var {
        for (const network of networkObjects) {
            if (network && network.connected) return network;
        }
        return null;
    }

    function networkForSsid(ssid: string): var {
        for (const network of networkObjects) {
            if (network && network.name === ssid) return network;
        }
        return null;
    }

    function snapshotNetworks(): var {
        const rows = [];
        for (const network of networkObjects) {
            if (!network || !network.name) continue;
            rows.push({
                ssid: network.name,
                connected: !!network.connected,
                known: !!network.known,
                signal: Math.round(Number(network.signalStrength || 0) * 100),
                security: network.security,
                stateChanging: !!network.stateChanging
            });
        }
        rows.sort((a, b) => {
            if (a.connected !== b.connected) return a.connected ? -1 : 1;
            if (a.known !== b.known) return a.known ? -1 : 1;
            return b.signal - a.signal;
        });
        return rows;
    }

    function wifiIcon(strength: int): string {
        const icons = ["󰤯", "󰤟", "󰤢", "󰤥", "󰤨"];
        return icons[Math.max(0, Math.min(4, Math.ceil(strength / 20) - 1))];
    }

    function connectionIcon(connectionKind: string, strength: int): string {
        if (connectionKind === "wifi") return wifiIcon(strength);
        if (connectionKind === "ethernet") return "󰈀";
        return "󰤮";
    }

    function securityRequiresPassword(security: int): bool {
        return security !== WifiSecurityType.Open && security !== WifiSecurityType.Owe;
    }

    function securityLabel(security: int): string {
        if (security === WifiSecurityType.Open) return "Open";
        if (security === WifiSecurityType.Owe) return "Enhanced open";
        return WifiSecurityType.toString(security).replace(/([a-z])([A-Z])/g, "$1 $2");
    }

    function toggleWifi(): void {
        if (backendAvailable && wifiAvailable)
            Networking.wifiEnabled = !Networking.wifiEnabled;
    }

    function connect(ssid: string, password: string): bool {
        const network = networkForSsid(ssid);
        if (!network) return false;
        if (network.connected) {
            network.disconnect();
        } else if (password !== "") {
            network.connectWithPsk(password);
        } else {
            network.connect();
        }
        return true;
    }

    function disconnect(ssid: string): void {
        const network = networkForSsid(ssid);
        if (network) network.disconnect();
    }

    function forget(ssid: string): void {
        const network = networkForSsid(ssid);
        if (network) network.forget();
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
        if (wifiDevice) wifiDevice.scannerEnabled = scannerUsers > 0;
    }

    onWifiDeviceChanged: updateScanner()
}
