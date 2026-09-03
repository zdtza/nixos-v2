pragma ComponentBehavior: Bound

// Omarchy-style NetworkManager panel: live status, radio toggle, scanning,
// connection management, passphrase entry, and saved-network removal.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Stylix
import "../components"
import "../services"
import ".."

Item {
    id: root

    readonly property bool opened: PanelService.activePanel === root
    readonly property bool requiresKeyboardFocus: true

    property string passwordSsid: ""
    property string passwordText: ""
    property string failureText: ""
    property int phraseIndex: 0
    property string selectedSsid: ""

    readonly property bool available: NetworkService.backendAvailable
    readonly property var connectedNetworks: NetworkService.wifiNetworks.filter(network => network.connected)
    readonly property var availableNetworks: NetworkService.wifiNetworks.filter(network => !network.connected)
    readonly property var networks: connectedNetworks.concat(availableNetworks)
    readonly property int networkRowHeight: 48
    readonly property int passwordRowHeight: 96
    readonly property int networkRowSpacing: 8
    readonly property int emptyStateHeight: 52
    // One pixel lets the final row's antialiased border render inside the
    // clipped viewport without adding visible panel padding.
    readonly property int networkEdgeInset: 1
    readonly property var phrases: [
        "Wiring bits", "Handling packets", "Sorting frames", "Hauling bytes",
        "Routing crumbs", "Counting collisions", "Bending light"
    ]
    readonly property string statusText: NetworkService.kind === "disconnected"
        ? "NOT CONNECTED" : phrases[phraseIndex % phrases.length].toUpperCase()

    signal restorePasswordFocus

    visible: available
    implicitWidth: available ? label.implicitWidth : 0
    implicitHeight: label.implicitHeight

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
        if (NetworkService.pingSamples.length === 0)
            return "--";
        if (NetworkService.pingLatency < 0)
            return "Timeout";
        return NetworkService.pingLatency.toFixed(NetworkService.pingLatency < 10 ? 1 : 0) + " ms";
    }

    function copyValue(value: string): void {
        if (value)
            Quickshell.execDetached(["wl-copy", value]);
    }

    function close(): void {
        PanelService.close(root);
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
        PanelService.toggle(root);
    }

    function activateNetwork(network: var): void {
        selectedSsid = network.ssid;
        failureText = "";
        if (network.connected)
            return;
        if (NetworkService.securityRequiresPassword(network.security) && !network.known) {
            passwordSsid = network.ssid;
            passwordText = "";
            return;
        }
        NetworkService.connect(network.ssid, "");
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

        // Connected networks are pinned above the scrollable area and are
        // always visible, so only available-network selections need scrolling.
        if (index < connectedNetworks.length)
            return;

        const availableIndex = index - connectedNetworks.length;
        const rowTop = availableIndex * (networkRowHeight + networkRowSpacing);
        const rowHeight = passwordSsid === selectedSsid
            ? passwordRowHeight : networkRowHeight;
        if (rowTop < networkList.contentY)
            networkList.contentY = rowTop;
        else if (rowTop + rowHeight > networkList.contentY + networkList.height)
            networkList.contentY = Math.min(networkList.contentHeight - networkList.height,
                rowTop + rowHeight - networkList.height);
    }

    function activateSelectedNetwork(): void {
        const network = networks.find(candidate => candidate.ssid === selectedSsid);
        if (!network)
            return;
        if (network.connected)
            NetworkService.disconnect(String(network.ssid));
        else
            activateNetwork(network);
    }

    function forgetSelectedNetwork(): void {
        const network = networks.find(candidate => candidate.ssid === selectedSsid);
        if (network && (network.known || network.connected))
            NetworkService.forget(String(network.ssid));
    }

    function restoreNetworkListFocus(): void {
        if (opened && passwordSsid === "")
            Qt.callLater(() => networkList.forceActiveFocus());
    }

    function submitPassword(): void {
        if (passwordSsid === "" || passwordText === "")
            return;
        if (NetworkService.connect(passwordSsid, passwordText)) {
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
            NetworkService.acquireScanner();
            NetworkService.acquireDetails();
            if (networks.length > 0)
                selectedSsid = networks[0].ssid;
            Qt.callLater(() => networkList.forceActiveFocus());
        } else {
            NetworkService.releaseScanner();
            NetworkService.releaseDetails();
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
        if (passwordSsid === "") {
            restoreNetworkListFocus();
        } else {
            passwordFocusTimer.restart();
        }
    }

    Component.onDestruction: if (opened) {
        NetworkService.releaseScanner();
        NetworkService.releaseDetails();
    }

    Timer {
        id: passwordFocusTimer
        interval: 0
        repeat: false
        onTriggered: root.restorePasswordFocus()
    }

    StatusRotator {
        target: networkHero.statusLabel
        running: root.opened && NetworkService.kind !== "disconnected"
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
        onActivated: NetworkService.toggleWifi()
    }

    Button {
        id: label
        anchors.centerIn: parent
        panel: root
        text: NetworkService.icon
        onClicked: root.toggle()
    }

    HyprlandFocusGrab {
        active: root.opened
        windows: [panel, root.QsWindow.window]
        onCleared: root.close()
    }

    Drawer {
        id: panel
        anchorItem: root
        anchorWindow: root.QsWindow.window
        open: root.opened
        closeOnEscape: root.passwordSsid === ""
        onCloseRequested: root.close()
        contentSpacing: 14
        contentBottomMargin: 12
        readonly property real maximumHeight: Math.max(320,
            (root.QsWindow.window && root.QsWindow.window.screen
                ? root.QsWindow.window.screen.height : 800) - 45)
        // Connected networks and the "AVAILABLE" header are pinned
        // (non-scrolling), so they count toward chrome height rather than
        // the scrollable viewport.
        readonly property real panelChromeHeight: contentTopMargin
            + contentBottomMargin + networkHero.implicitHeight
            + connectionInfo.implicitHeight + networkSeparator.height
            + connectedSectionHeight + availableHeader.implicitHeight
            + contentSpacing * (root.connectedNetworks.length > 0 ? 5 : 4)
        // Use stable section counts instead of Column.implicitHeight. Panel
        // follows actual content while ignoring transient delegate layouts.
        readonly property real connectedSectionHeight: root.connectedNetworks.length > 0
            ? connectedHeader.implicitHeight
                + root.connectedNetworks.length * (root.networkRowHeight + root.networkRowSpacing)
            : 0
        readonly property real availableSectionHeight: root.availableNetworks.length > 0
            ? root.availableNetworks.length * (root.networkRowHeight + root.networkRowSpacing)
            : root.networkRowSpacing + root.emptyStateHeight
        readonly property real networkViewportHeight: Math.min(420,
            Math.max(80, maximumHeight - panelChromeHeight), availableSectionHeight + root.networkEdgeInset)

        implicitWidth: 460 + PanelService.shellRounding
        implicitHeight: Math.min(maximumHeight, panelChromeHeight + networkViewportHeight)

        Hero {
            id: networkHero
            width: parent.width
            icon: NetworkService.icon
            title: NetworkService.connectionName
            status: root.statusText
            trailingWidth: 44
            trailingHeight: 24

            ToggleSwitch {
                anchors.fill: parent
                checked: NetworkService.wifiEnabled
                onToggled: NetworkService.toggleWifi()
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
                valueColor: NetworkService.packetLoss > 0 ? Theme.base08 : Theme.base05
            }
            InfoLabel {
                text: "Packet Loss"
            }
            DetailValue {
                text: NetworkService.pingSamples.length > 0 ? NetworkService.packetLoss + "%" : "--"
                valueColor: NetworkService.packetLoss > 0 ? Theme.base08 : Theme.base05
            }

            InfoLabel {
                text: "Receiving"
            }
            DetailValue {
                text: NetworkService.info.rx_bytes !== undefined ? root.formatRate(NetworkService.downloadRate) : "--"
            }
            InfoLabel {
                text: "Sending"
            }
            DetailValue {
                text: NetworkService.info.tx_bytes !== undefined ? root.formatRate(NetworkService.uploadRate) : "--"
            }

            InfoLabel {
                text: "Downloaded"
            }
            DetailValue {
                text: NetworkService.info.rx_bytes !== undefined ? root.formatBytes(Number(NetworkService.info.rx_bytes)) : "--"
            }
            InfoLabel {
                text: "Uploaded"
            }
            DetailValue {
                text: NetworkService.info.tx_bytes !== undefined ? root.formatBytes(Number(NetworkService.info.tx_bytes)) : "--"
            }

            InfoLabel {
                text: "IP Address"
            }
            DetailValue {
                text: NetworkService.info.ip || "--"
                copyable: !!NetworkService.info.ip
            }
            InfoLabel {
                text: "Gateway"
            }
            DetailValue {
                text: NetworkService.info.gateway || "--"
                copyable: !!NetworkService.info.gateway
            }
        }

        Separator { id: networkSeparator }

        Component {
            id: networkRowComponent

            Rectangle {
                            id: networkRow
                            required property var modelData
                            readonly property bool passwordOpen: root.passwordSsid === String(modelData.ssid)
                            readonly property bool keyboardSelected: root.selectedSsid === String(modelData.ssid)

                            onPasswordOpenChanged: if (passwordOpen) Qt.callLater(() => {
                                const point = networkRow.mapToItem(networkList.contentItem, 0, 0);
                                const bottom = point.y + networkRow.height;
                                if (bottom > networkList.contentY + networkList.height)
                                    networkList.contentY = Math.max(0, Math.min(
                                        networkList.contentHeight - networkList.height,
                                        bottom - networkList.height));
                            })

                            width: parent.width
                            height: passwordOpen ? root.passwordRowHeight : root.networkRowHeight
                            color: rowMouse.pressed && !passwordOpen
                                ? Utils.alpha(Theme.base05, 0.22)
                                : networkRow.keyboardSelected && !passwordOpen
                                    ? Utils.alpha(Theme.base05, 0.08)
                                    : "transparent"
                            border.width: networkRow.keyboardSelected && !passwordOpen ? 1 : 0
                            border.color: Utils.alpha(Theme.base05, 0.25)
                            radius: PanelService.rounding

                            HoverHandler {
                                id: networkHover
                                onHoveredChanged: if (hovered && !networkRow.passwordOpen)
                                    root.selectedSsid = String(networkRow.modelData.ssid)
                            }

                            Connections {
                                target: NetworkService.networkForSsid(String(networkRow.modelData.ssid))
                                function onConnectionFailed(reason): void {
                                    if (!NetworkService.securityRequiresPassword(networkRow.modelData.security))
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
                                    text: NetworkService.wifiIcon(networkRow.modelData.signal)
                                    color: Theme.base05
                                    font.family: Theme.monospace
                                    font.pixelSize: Utils.scaledFont(16)
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
                                        color: Theme.base05
                                        font.family: Theme.monospace
                                        font.pixelSize: Utils.scaledFont(12)
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        width: parent.width
                                        text: networkRow.modelData.stateChanging ? "Connecting…"
                                            : networkRow.modelData.connected ? "Connected"
                                            : networkRow.modelData.known ? "Known network"
                                            : NetworkService.securityLabel(networkRow.modelData.security)
                                        color: Theme.base04
                                        font.family: Theme.monospace
                                        font.pixelSize: Utils.scaledFont(11)
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

                                    RowActionButton {
                                        visible: networkRow.modelData.connected
                                        icon: "󰅖"
                                        onClicked: NetworkService.disconnect(String(networkRow.modelData.ssid))
                                    }

                                    RowActionButton {
                                        visible: networkRow.modelData.known || networkRow.modelData.connected
                                        icon: "󰆴"
                                        onClicked: NetworkService.forget(String(networkRow.modelData.ssid))
                                    }
                                }

                                Text {
                                    id: lockIcon
                                    anchors.right: parent.right
                                    anchors.rightMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: NetworkService.securityRequiresPassword(networkRow.modelData.security) ? "󰌾" : ""
                                    color: Theme.base04
                                    font.family: Theme.monospace
                                    font.pixelSize: Utils.scaledFont(12)
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
                                    radius: PanelService.rounding
                                    color: Utils.alpha(Theme.base05, 0.04)
                                    border.width: 1
                                    border.color: passwordInput.activeFocus ? Theme.base04 : Utils.alpha(Theme.base05, 0.4)


                                    Text {
                                        anchors {
                                            left: parent.left
                                            leftMargin: 10
                                            verticalCenter: parent.verticalCenter
                                        }
                                        visible: passwordInput.text === ""
                                        text: root.failureText !== "" ? root.failureText : "Password"
                                        color: root.failureText !== "" ? Theme.base08 : Theme.base04
                                        font.family: Theme.monospace
                                        font.pixelSize: Utils.scaledFont(12)
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
                                        color: Theme.base05
                                        selectionColor: Theme.base04
                                        selectedTextColor: Theme.base00
                                        font.family: Theme.monospace
                                        font.pixelSize: Utils.scaledFont(12)
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
                                    radius: PanelService.rounding
                                    color: connectMouse.containsMouse ? Utils.alpha(Theme.base05, 0.18) : Utils.alpha(Theme.base05, 0.08)

                                    border.width: 1
                                    border.color: Utils.alpha(Theme.base05, 0.4)
                                    Text {
                                        anchors.centerIn: parent
                                        text: "Connect"
                                        color: Theme.base05
                                        font.family: Theme.monospace
                                        font.pixelSize: Utils.scaledFont(11)
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
                                    radius: PanelService.rounding
                                    color: cancelMouse.containsMouse ? Utils.alpha(Theme.base05, 0.12) : "transparent"

                                    border.width: 1
                                    border.color: Utils.alpha(Theme.base05, 0.3)
                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰅖"
                                        color: Theme.base05
                                        font.family: Theme.monospace
                                        font.pixelSize: Utils.scaledFont(12)
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
            id: connectedSection
            width: parent.width
            spacing: root.networkRowSpacing
            visible: root.connectedNetworks.length > 0

            SectionHeader {
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

        SectionHeader {
            id: availableHeader
            width: parent.width
            title: "AVAILABLE"
            detail: NetworkService.wifiEnabled ? "SCANNING" : "WI-FI OFF"
        }

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
                    spacing: root.networkRowSpacing

                    Text {
                        width: parent.width
                        height: root.emptyStateHeight
                        visible: root.availableNetworks.length === 0
                        text: NetworkService.wifiEnabled
                            ? "No available networks" : "Wi-Fi is turned off"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        color: Theme.base04
                        font.family: Theme.monospace
                        font.pixelSize: Utils.scaledFont(12)
                    }

                    Repeater {
                        model: root.availableNetworks
                        delegate: networkRowComponent
                    }
                }
            }
        }
    }

    component InfoLabel: Text {
        color: Theme.base05
        opacity: 0.6
        font.family: Theme.monospace
        font.pixelSize: Utils.scaledFont(12)
    }

    component DetailValue: Text {
        property bool copyable: false
        property color valueColor: Theme.base05

        Layout.fillWidth: true
        horizontalAlignment: Text.AlignRight
        color: valueColor
        font.family: Theme.monospace
        font.pixelSize: Utils.scaledFont(12)
        elide: Text.ElideRight

        MouseArea {
            anchors.fill: parent
            enabled: parent.copyable && parent.text !== "" && parent.text !== "--"
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: root.copyValue(parent.text)
        }
    }
}
