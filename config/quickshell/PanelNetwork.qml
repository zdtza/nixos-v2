pragma ComponentBehavior: Bound

// Omarchy-style NetworkManager panel: live status, radio toggle, scanning,
// connection management, passphrase entry, and saved-network removal.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Stylix

Item {
    id: root

    readonly property bool opened: ServicePanel.activePanel === root
    readonly property bool requiresKeyboardFocus: true

    property string passwordSsid: ""
    property string passwordText: ""
    property string failureText: ""
    property int phraseIndex: 0
    property string selectedSsid: ""
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

    readonly property bool available: ServiceNetwork.backendAvailable
    readonly property var connectedNetworks: ServiceNetwork.wifiNetworks.filter(network => network.connected)
    readonly property var availableNetworks: ServiceNetwork.wifiNetworks.filter(network => !network.connected)
    readonly property var networks: connectedNetworks.concat(availableNetworks)
    readonly property int networkRowHeight: 48
    readonly property int passwordRowHeight: 96
    readonly property int networkRowSpacing: 8
    readonly property int networkSectionSpacing: 14
    readonly property int emptyStateHeight: 52
    // One pixel lets the final row's antialiased border render inside the
    // clipped viewport without adding visible panel padding.
    readonly property int networkEdgeInset: 1
    readonly property var phrases: [
        "Wiring bits", "Handling packets", "Sorting frames", "Hauling bytes",
        "Routing crumbs", "Counting collisions", "Bending light"
    ]
    readonly property string statusText: ServiceNetwork.kind === "disconnected"
        ? "NOT CONNECTED" : phrases[phraseIndex % phrases.length].toUpperCase()

    signal restorePasswordFocus

    visible: available
    implicitWidth: available ? label.implicitWidth : 0
    implicitHeight: label.implicitHeight

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
        if (!next.iface)
            return;

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

        const pingRaw = next.internet_ping_ms;
        const sample = pingRaw !== undefined && pingRaw !== "" ? Number(pingRaw) : NaN;
        const samples = pingSamples.slice();
        samples.push(Number.isFinite(sample) && sample >= 0 ? sample : null);
        while (samples.length > 24)
            samples.shift();
        pingSamples = samples;

        let total = 0;
        let count = 0;
        for (let index = Math.max(0, samples.length - 5); index < samples.length; index++) {
            if (samples[index] === null)
                continue;
            total += samples[index];
            count++;
        }
        pingLatency = count > 0 ? total / count : -1;
        packetLoss = samples.length > 0 ? Math.round(samples.filter(value => value === null).length / samples.length * 100) : 0;
        info = next;
    }

    function formatBytes(bytes: real): string {
        let value = Number(bytes);
        if (!Number.isFinite(value) || value < 0)
            value = 0;
        if (value < 1024)
            return Math.round(value) + " B";
        if (value < 1048576)
            return (value / 1024).toFixed(1) + " KB";
        if (value < 1073741824)
            return (value / 1048576).toFixed(1) + " MB";
        return (value / 1073741824).toFixed(2) + " GB";
    }

    function formatRate(rate: real): string {
        return formatBytes(rate) + "/s";
    }

    function formatPing(): string {
        if (pingSamples.length === 0)
            return "--";
        if (pingLatency < 0)
            return "Timeout";
        return pingLatency.toFixed(pingLatency > 0 && pingLatency < 10 ? 1 : 0) + " ms";
    }

    function copyValue(value: string): void {
        if (value)
            Quickshell.execDetached(["wl-copy", value]);
    }

    function close(): void {
        ServicePanel.close(root);
        passwordSsid = "";
        passwordText = "";
        failureText = "";
    }

    function cancelPasswordEntry(): void {
        passwordSsid = "";
        passwordText = "";
        failureText = "";
        restoreNetworkListFocus();
    }

    function toggle(): void {
        ServicePanel.toggle(root);
    }

    function activateNetwork(network: var): void {
        selectedSsid = network.ssid;
        failureText = "";
        if (network.connected)
            return;
        if (ServiceNetwork.securityRequiresPassword(network.security) && !network.known) {
            passwordSsid = network.ssid;
            passwordText = "";
            return;
        }
        ServiceNetwork.connect(network.ssid, "");
    }

    function selectNetwork(delta: int): void {
        if (networks.length === 0) {
            selectedSsid = "";
            return;
        }
        let index = networks.findIndex(network => network.ssid === selectedSsid);
        if (index < 0)
            index = delta > 0 ? 0 : networks.length - 1;
        else
            index = Math.max(0, Math.min(networks.length - 1, index + delta));
        selectedSsid = networks[index].ssid;
        let headerCount = connectedNetworks.length > 0 ? 1 : 0;
        if (index >= connectedNetworks.length)
            headerCount++;
        const headerHeight = Number(availableHeader?.implicitHeight || 14);
        const rowTop = index * (networkRowHeight + networkRowSpacing)
            + headerCount * (headerHeight + networkRowSpacing);
        if (rowTop < networkList.contentY)
            networkList.contentY = rowTop;
        else if (rowTop + networkRowHeight > networkList.contentY + networkList.height)
            networkList.contentY = Math.min(networkList.contentHeight - networkList.height, rowTop + networkRowHeight - networkList.height);
    }

    function activateSelectedNetwork(): void {
        const network = networks.find(candidate => candidate.ssid === selectedSsid);
        if (!network)
            return;
        if (network.connected)
            ServiceNetwork.disconnect(String(network.ssid));
        else
            activateNetwork(network);
    }

    function forgetSelectedNetwork(): void {
        const network = networks.find(candidate => candidate.ssid === selectedSsid);
        if (network && (network.known || network.connected))
            ServiceNetwork.forget(String(network.ssid));
    }

    function restoreNetworkListFocus(): void {
        if (opened && passwordSsid === "")
            Qt.callLater(() => networkList.forceActiveFocus());
    }

    function submitPassword(): void {
        if (passwordSsid === "" || passwordText === "")
            return;
        if (ServiceNetwork.connect(passwordSsid, passwordText)) {
            passwordSsid = "";
            passwordText = "";
            restoreNetworkListFocus();
        } else {
            failureText = "Network is no longer available";
        }
    }

    onOpenedChanged: {
        if (opened) {
            phraseIndex = 0;
            previousSampleTime = 0;
            downloadRate = 0;
            uploadRate = 0;
            pingSamples = [];
            ServiceNetwork.acquireScanner();
            if (networks.length > 0)
                selectedSsid = networks[0].ssid;
            Qt.callLater(() => networkList.forceActiveFocus());
            if (!detailsProcess.running)
                detailsProcess.running = true;
        } else {
            ServiceNetwork.releaseScanner();
        }
    }

    onNetworksChanged: {
        if (networks.length === 0) {
            selectedSsid = "";
        } else if (!networks.some(network => network.ssid === selectedSsid)) {
            selectedSsid = networks[0].ssid;
        }
        if (passwordSsid !== "")
            passwordFocusTimer.restart();
        else
            restoreNetworkListFocus();
    }

    onPasswordSsidChanged: {
        if (passwordSsid === "")
            restoreNetworkListFocus();
        else
            passwordFocusTimer.restart();
    }

    Component.onDestruction: if (opened)
        ServiceNetwork.releaseScanner()

    Timer {
        id: passwordFocusTimer
        interval: 0
        repeat: false
        onTriggered: root.restorePasswordFocus()
    }

    Process {
        id: detailsProcess
        command: ["qs-network-status"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.updateDetails(text)
        }
    }

    Timer {
        interval: 1500
        running: root.opened
        repeat: true
        onTriggered: if (!detailsProcess.running)
            detailsProcess.running = true
    }

    PanelStatusRotator {
        target: networkHero.statusLabel
        running: root.opened && ServiceNetwork.kind !== "disconnected"
        onAdvance: root.phraseIndex = (root.phraseIndex + 1) % root.phrases.length
    }

    Shortcut {
        enabled: root.opened && root.passwordSsid === ""
        sequence: "Up"
        context: Qt.ApplicationShortcut
        onActivated: root.selectNetwork(-1)
    }
    Shortcut {
        enabled: root.opened && root.passwordSsid === ""
        sequence: "Down"
        context: Qt.ApplicationShortcut
        onActivated: root.selectNetwork(1)
    }
    Shortcut {
        enabled: root.opened && root.passwordSsid === ""
        sequence: "Return"
        context: Qt.ApplicationShortcut
        onActivated: root.activateSelectedNetwork()
    }
    Shortcut {
        enabled: root.opened && root.passwordSsid === ""
        sequence: "Enter"
        context: Qt.ApplicationShortcut
        onActivated: root.activateSelectedNetwork()
    }
    Shortcut {
        enabled: root.opened && root.passwordSsid === ""
        sequence: "Delete"
        context: Qt.ApplicationShortcut
        onActivated: root.forgetSelectedNetwork()
    }
    Shortcut {
        enabled: root.opened && root.passwordSsid === ""
        sequence: "Space"
        context: Qt.ApplicationShortcut
        onActivated: ServiceNetwork.toggleWifi()
    }

    BarButton {
        id: label
        anchors.centerIn: parent
        panel: root
        text: ServiceNetwork.icon
        onClicked: root.toggle()
    }

    HyprlandFocusGrab {
        active: root.opened
        windows: [panel, root.QsWindow.window]
        onCleared: root.close()
    }

    PanelPopup {
        id: panel
        anchorItem: root
        anchorWindow: root.QsWindow.window
        visible: root.opened
        closeOnEscape: root.passwordSsid === ""
        onCloseRequested: root.close()
        borderColor: Theme.border
        contentSpacing: 14
        readonly property real maximumHeight: Math.max(320,
            (root.QsWindow.window && root.QsWindow.window.screen
                ? root.QsWindow.window.screen.height : 800) - 45)
        readonly property real panelChromeHeight: contentTopMargin
            + contentBottomMargin + networkHero.implicitHeight
            + connectionInfo.implicitHeight + networkSeparator.height
            + contentSpacing * 3
        // Calculate from stable row counts rather than animated delegate size.
        // Password space exists only while editor is open, removing idle blank
        // space without reintroducing transient intermediate popup heights.
        readonly property real connectedSectionHeight: root.connectedNetworks.length > 0
            ? connectedHeader.implicitHeight
                + root.connectedNetworks.length * (root.networkRowHeight + root.networkRowSpacing)
            : 0
        readonly property real availableSectionHeight: availableHeader.implicitHeight
            + (root.availableNetworks.length > 0
                ? root.availableNetworks.length * (root.networkRowHeight + root.networkRowSpacing)
                : root.networkRowSpacing + root.emptyStateHeight)
        readonly property real passwordEditorHeight: root.passwordSsid !== ""
            ? root.passwordRowHeight - root.networkRowHeight : 0
        readonly property real desiredNetworkHeight: connectedSectionHeight
            + availableSectionHeight + passwordEditorHeight + root.networkEdgeInset
            + (root.connectedNetworks.length > 0 ? root.networkSectionSpacing : 0)
        readonly property real networkViewportHeight: Math.min(420,
            Math.max(80, maximumHeight - panelChromeHeight), desiredNetworkHeight)

        implicitWidth: 460
        implicitHeight: Math.min(maximumHeight, panelChromeHeight + networkViewportHeight)

        PanelHero {
            id: networkHero
            width: parent.width
            icon: ServiceNetwork.icon
            title: ServiceNetwork.connectionName
            status: root.statusText
            trailingWidth: 44
            trailingHeight: 24

            PanelToggleSwitch {
                anchors.fill: parent
                checked: ServiceNetwork.wifiEnabled
                onToggled: ServiceNetwork.toggleWifi()
            }
        }

        // Omarchy connection information block. Rows remain mounted
        // before the first sample so opening data never shifts layout.
        GridLayout {
            id: connectionInfo
            width: parent.width
            columns: 4
            columnSpacing: 20
            rowSpacing: 4

            InfoLabel {
                text: "Ping"
            }
            DetailValue {
                text: root.formatPing()
                valueColor: root.packetLoss > 0 ? Theme.urgent : Theme.foreground
            }
            InfoLabel {
                text: "Packet Loss"
            }
            DetailValue {
                text: root.pingSamples.length > 0 ? root.packetLoss + "%" : "--"
                valueColor: root.packetLoss > 0 ? Theme.urgent : Theme.foreground
            }

            InfoLabel {
                text: "Receiving"
            }
            DetailValue {
                text: root.info.rx_bytes !== undefined ? root.formatRate(root.downloadRate) : "--"
            }
            InfoLabel {
                text: "Sending"
            }
            DetailValue {
                text: root.info.tx_bytes !== undefined ? root.formatRate(root.uploadRate) : "--"
            }

            InfoLabel {
                text: "Downloaded"
            }
            DetailValue {
                text: root.info.rx_bytes !== undefined ? root.formatBytes(Number(root.info.rx_bytes)) : "--"
            }
            InfoLabel {
                text: "Uploaded"
            }
            DetailValue {
                text: root.info.tx_bytes !== undefined ? root.formatBytes(Number(root.info.tx_bytes)) : "--"
            }

            InfoLabel {
                text: "IP Address"
            }
            DetailValue {
                text: root.info.ip || "--"
                copyable: !!root.info.ip
            }
            InfoLabel {
                text: "Gateway"
            }
            DetailValue {
                text: root.info.gateway || "--"
                copyable: !!root.info.gateway
            }
        }

        PanelSeparator { id: networkSeparator }

        Item {
            width: parent.width
            height: panel.networkViewportHeight
            clip: true

            Flickable {
                id: networkList
                anchors.fill: parent
                contentHeight: networkColumn.implicitHeight + root.networkEdgeInset
                clip: true
                interactive: contentHeight > height
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.VerticalFlick
                activeFocusOnTab: true

                HoverHandler {
                    onHoveredChanged: if (hovered && root.passwordSsid === "")
                        networkList.forceActiveFocus()
                }

                Column {
                    id: networkColumn
                    width: networkList.width
                    spacing: root.networkSectionSpacing

                    Component {
                        id: networkRowComponent

                        Rectangle {
                            id: networkRow
                            required property var modelData
                            readonly property bool passwordOpen: root.passwordSsid === String(modelData.ssid)
                            readonly property bool keyboardSelected: root.selectedSsid === String(modelData.ssid)

                            width: parent.width
                            height: passwordOpen ? root.passwordRowHeight : root.networkRowHeight
                            color: rowMouse.pressed && !passwordOpen
                                ? Util.alpha(Theme.foreground, 0.22)
                                : networkRow.keyboardSelected && !passwordOpen
                                    ? Util.alpha(Theme.foreground, 0.08)
                                    : "transparent"
                            border.width: networkRow.keyboardSelected && !passwordOpen ? 1 : 0
                            border.color: Util.alpha(Theme.foreground, 0.25)
                            radius: ServicePanel.rounding
                            Behavior on color {
                                ColorAnimation {
                                    duration: 120
                                }
                            }

                            HoverHandler {
                                id: networkHover
                                onHoveredChanged: if (hovered && !networkRow.passwordOpen)
                                    root.selectedSsid = String(networkRow.modelData.ssid)
                            }

                            Connections {
                                target: ServiceNetwork.networkForSsid(String(networkRow.modelData.ssid))
                                function onConnectionFailed(reason): void {
                                    if (!ServiceNetwork.securityRequiresPassword(networkRow.modelData.security))
                                        return;
                                    root.passwordSsid = String(networkRow.modelData.ssid);
                                    root.passwordText = "";
                                    root.failureText = "Connection failed — check password";
                                    Qt.callLater(() => passwordInput.forceActiveFocus());
                                }
                            }

                            Connections {
                                target: root
                                function onRestorePasswordFocus(): void {
                                    if (root.passwordSsid === String(networkRow.modelData.ssid))
                                        passwordInput.forceActiveFocus();
                                }
                            }

                            Item {
                                id: summary
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                height: 48

                                Text {
                                    id: networkIcon
                                    anchors.left: parent.left
                                    anchors.leftMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: ServiceNetwork.wifiIcon(networkRow.modelData.signal)
                                    color: Theme.foreground
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Util.scaledFont(16)
                                }
                                Column {
                                    anchors.left: networkIcon.right
                                    anchors.leftMargin: 10
                                    anchors.right: actionRow.visible ? actionRow.left : lockIcon.left
                                    anchors.rightMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 1

                                    Text {
                                        width: parent.width
                                        text: networkRow.modelData.ssid
                                        color: Theme.foreground
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Util.scaledFont(12)
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        width: parent.width
                                        text: networkRow.modelData.stateChanging ? "Connecting…"
                                            : networkRow.modelData.connected ? "Connected"
                                            : networkRow.modelData.known ? "Known network"
                                            : ServiceNetwork.securityLabel(networkRow.modelData.security)
                                        color: Theme.muted
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Util.scaledFont(11)
                                        elide: Text.ElideRight
                                    }
                                }

                                Row {
                                    id: actionRow
                                    z: 2
                                    visible: networkRow.keyboardSelected
                                        && (networkRow.modelData.connected || networkRow.modelData.known)
                                    anchors.right: lockIcon.left
                                    anchors.rightMargin: 16
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 8

                                    PanelRowActionButton {
                                        visible: networkRow.modelData.connected
                                        icon: "󰅖"
                                        onClicked: ServiceNetwork.disconnect(String(networkRow.modelData.ssid))
                                    }

                                    PanelRowActionButton {
                                        visible: networkRow.modelData.known || networkRow.modelData.connected
                                        icon: "󰆴"
                                        onClicked: ServiceNetwork.forget(String(networkRow.modelData.ssid))
                                    }
                                }

                                Text {
                                    id: lockIcon
                                    anchors.right: parent.right
                                    anchors.rightMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: ServiceNetwork.securityRequiresPassword(networkRow.modelData.security) ? "󰌾" : ""
                                    color: Theme.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Util.scaledFont(12)
                                }

                                MouseArea {
                                    id: rowMouse
                                    anchors.fill: parent
                                    z: 1
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.selectedSsid = String(networkRow.modelData.ssid);
                                        root.activateNetwork(networkRow.modelData);
                                    }
                                }
                            }

                            Row {
                                visible: root.passwordSsid === String(networkRow.modelData.ssid)
                                onVisibleChanged: if (visible)
                                    Qt.callLater(() => passwordInput.forceActiveFocus())
                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    top: summary.bottom
                                    bottom: parent.bottom
                                    leftMargin: 10
                                    rightMargin: 10
                                    topMargin: 4
                                    bottomMargin: 20
                                }
                                spacing: 8

                                Rectangle {
                                    width: parent.width - connectButton.width - cancelButton.width - parent.spacing * 2
                                    height: 32
                                    radius: ServicePanel.rounding
                                    color: Util.alpha(Theme.foreground, 0.04)
                                    border.width: 1
                                    border.color: passwordInput.activeFocus ? Theme.muted : Util.alpha(Theme.foreground, 0.4)

                                    Text {
                                        anchors {
                                            left: parent.left
                                            leftMargin: 10
                                            verticalCenter: parent.verticalCenter
                                        }
                                        visible: passwordInput.text === ""
                                        text: root.failureText !== "" ? root.failureText : "Password"
                                        color: root.failureText !== "" ? Theme.urgent : Theme.muted
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Util.scaledFont(12)
                                    }

                                    TextInput {
                                        id: passwordInput
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 10
                                        verticalAlignment: TextInput.AlignVCenter
                                        text: root.passwordText
                                        onTextChanged: root.passwordText = text
                                        echoMode: TextInput.Password
                                        color: Theme.foreground
                                        selectionColor: Theme.muted
                                        selectedTextColor: Theme.background
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Util.scaledFont(12)
                                        font.letterSpacing: 2
                                        clip: true
                                        Component.onCompleted: {
                                            if (root.passwordSsid === String(networkRow.modelData.ssid))
                                                Qt.callLater(() => passwordInput.forceActiveFocus());
                                        }
                                        Keys.onReturnPressed: root.submitPassword()
                                        Keys.onEscapePressed: root.cancelPasswordEntry()
                                    }
                                }

                                Rectangle {
                                    id: connectButton
                                    width: 72
                                    height: 32
                                    radius: ServicePanel.rounding
                                    color: connectMouse.containsMouse ? Util.alpha(Theme.foreground, 0.18) : Util.alpha(Theme.foreground, 0.08)
                                    border.width: 1
                                    border.color: Util.alpha(Theme.foreground, 0.4)
                                    Text {
                                        anchors.centerIn: parent
                                        text: "Connect"
                                        color: Theme.foreground
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Util.scaledFont(11)
                                        font.bold: true
                                    }
                                    MouseArea {
                                        id: connectMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.submitPassword()
                                    }
                                }

                                Rectangle {
                                    id: cancelButton
                                    width: 32
                                    height: 32
                                    radius: ServicePanel.rounding
                                    color: cancelMouse.containsMouse ? Util.alpha(Theme.foreground, 0.12) : "transparent"
                                    border.width: 1
                                    border.color: Util.alpha(Theme.foreground, 0.3)
                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰅖"
                                        color: Theme.foreground
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Util.scaledFont(12)
                                    }
                                    MouseArea {
                                        id: cancelMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.cancelPasswordEntry()
                                    }
                                }
                            }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: root.networkRowSpacing
                        visible: root.connectedNetworks.length > 0

                        PanelSectionHeader {
                            id: connectedHeader
                            width: parent.width
                            title: "CONNECTED"
                            detail: root.connectedNetworks.length > 1
                                ? root.connectedNetworks.length + " NETWORKS" : ""
                        }

                        Repeater {
                            model: root.connectedNetworks
                            delegate: networkRowComponent
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: root.networkRowSpacing

                        PanelSectionHeader {
                            id: availableHeader
                            width: parent.width
                            title: "AVAILABLE"
                            detail: ServiceNetwork.wifiEnabled ? "SCANNING" : "WI-FI OFF"
                        }

                        Text {
                            width: parent.width
                            height: root.emptyStateHeight
                            visible: root.availableNetworks.length === 0
                            text: ServiceNetwork.wifiEnabled
                                ? "No available networks" : "Wi-Fi is turned off"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: Util.scaledFont(12)
                        }

                        Repeater {
                            model: root.availableNetworks
                            delegate: networkRowComponent
                        }
                    }
                }
            }
        }
    }

    component InfoLabel: Text {
        color: Theme.foreground
        opacity: 0.6
        font.family: Theme.fontFamily
        font.pixelSize: Util.scaledFont(12)
    }

    component DetailValue: Text {
        property bool copyable: false
        property color valueColor: Theme.foreground

        Layout.fillWidth: true
        horizontalAlignment: Text.AlignRight
        color: valueColor
        font.family: Theme.fontFamily
        font.pixelSize: Util.scaledFont(12)
        elide: Text.ElideRight

        MouseArea {
            anchors.fill: parent
            enabled: parent.copyable && parent.text !== "" && parent.text !== "--"
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: root.copyValue(parent.text)
        }
    }
}
