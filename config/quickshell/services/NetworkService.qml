pragma Singleton

// Shared NetworkManager state and actions for every per-screen network widget.
import QtQuick
import Quickshell.Io
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
    property int detailsUsers: 0
    property var info: ({})
    property real previousRxBytes: 0
    property real previousTxBytes: 0
    property real previousSampleTime: 0
    property string previousInterface: ""
    property real downloadRate: 0
    property real uploadRate: 0
    property var pingSamples: []
    property real pingLatency: -1
    property int packetLoss: 0

    readonly property string detailsCommand: `
probe=1.1.1.1
route_json="$(ip -j route get "$probe" 2>/dev/null || true)"
[[ -n "$route_json" ]] || exit 0

iface="$(jq -r '.[0].dev // ""' <<<"$route_json")"
gateway="$(jq -r '.[0].gateway // ""' <<<"$route_json")"
address="$(jq -r '.[0].prefsrc // ""' <<<"$route_json")"
[[ -n "$iface" ]] || exit 0

prefix="$(ip -j addr show "$iface" | jq -r '.[0].addr_info[]? | select(.family == "inet") | .prefixlen // ""' | head -n1)"
printf 'iface\\t%s\\n' "$iface"
printf 'ip\\t%s\\n' "$address"
printf 'prefix\\t%s\\n' "$prefix"
printf 'gateway\\t%s\\n' "$gateway"

[[ -r "/sys/class/net/$iface/statistics/rx_bytes" ]] && printf 'rx_bytes\\t%s\\n' "$(<"/sys/class/net/$iface/statistics/rx_bytes")"
[[ -r "/sys/class/net/$iface/statistics/tx_bytes" ]] && printf 'tx_bytes\\t%s\\n' "$(<"/sys/class/net/$iface/statistics/tx_bytes")"

if [[ -d "/sys/class/net/$iface/wireless" ]]; then
    printf 'type\\twifi\\n'
    link="$(iw dev "$iface" link 2>/dev/null || true)"
    [[ -n "$link" ]] && {
        printf 'ssid\\t%s\\n' "$(awk '/SSID:/ { sub(/.*SSID: /, ""); print; exit }' <<<"$link")"
        printf 'freq\\t%s\\n' "$(awk '/freq:/ { print $2; exit }' <<<"$link")"
        printf 'bitrate\\t%s %s\\n' "$(awk '/tx bitrate:/ { print $3; exit }' <<<"$link")" "$(awk '/tx bitrate:/ { print $4; exit }' <<<"$link")"
    }
else
    printf 'type\\tethernet\\n'
    [[ -r "/sys/class/net/$iface/speed" ]] && printf 'speed\\t%s\\n' "$(<"/sys/class/net/$iface/speed")"
fi

ping_ms() {
    LC_ALL=C ping -n -c 1 -W 1 "$1" 2>/dev/null | awk -F'time[=<]' '/time[=<]/ { split($2, p, " "); print p[1]; exit }'
}
[[ -n "$gateway" ]] && printf 'router_ping_ms\\t%s\\n' "$(ping_ms "$gateway")"
printf 'internet_ping_ms\\t%s\\n' "$(ping_ms "$probe")"
`

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

    function parseDetails(raw: string): var {
        const values = {};
        for (const line of String(raw || "").split("\n")) {
            const separator = line.indexOf("\t");
            if (separator > 0)
                values[line.substring(0, separator)] = line.substring(separator + 1).trim();
        }
        return values;
    }

    function updateDetails(raw: string): void {
        const next = parseDetails(raw);
        if (!next.iface) return;

        const now = Date.now() / 1000;
        const rx = Number(next.rx_bytes || 0);
        const tx = Number(next.tx_bytes || 0);
        if (previousInterface === next.iface && previousSampleTime > 0) {
            const elapsed = now - previousSampleTime;
            if (elapsed > 0) {
                downloadRate = Math.max(0, (rx - previousRxBytes) / elapsed);
                uploadRate = Math.max(0, (tx - previousTxBytes) / elapsed);
            }
        } else {
            downloadRate = 0;
            uploadRate = 0;
            pingSamples = [];
        }
        previousInterface = next.iface;
        previousRxBytes = rx;
        previousTxBytes = tx;
        previousSampleTime = now;

        const sample = next.internet_ping_ms !== undefined && next.internet_ping_ms !== ""
            ? Number(next.internet_ping_ms) : NaN;
        const samples = pingSamples.slice();
        samples.push(Number.isFinite(sample) && sample >= 0 ? sample : null);
        while (samples.length > 24) samples.shift();
        pingSamples = samples;

        let total = 0;
        let count = 0;
        for (let index = Math.max(0, samples.length - 5); index < samples.length; index++) {
            if (samples[index] === null) continue;
            total += samples[index];
            count++;
        }
        pingLatency = count > 0 ? total / count : -1;
        packetLoss = samples.length > 0
            ? Math.round(samples.filter(value => value === null).length / samples.length * 100) : 0;
        info = next;
    }

    function acquireDetails(): void {
        if (detailsUsers++ === 0) {
            previousSampleTime = 0;
            downloadRate = 0;
            uploadRate = 0;
            pingSamples = [];
            if (!detailsProcess.running) detailsProcess.running = true;
        }
    }

    function releaseDetails(): void {
        detailsUsers = Math.max(0, detailsUsers - 1);
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

    Process {
        id: detailsProcess
        command: ["bash", "-c", root.detailsCommand]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.updateDetails(text)
        }
    }

    Timer {
        interval: 1500
        running: root.detailsUsers > 0
        repeat: true
        onTriggered: if (!detailsProcess.running) detailsProcess.running = true
    }
}
