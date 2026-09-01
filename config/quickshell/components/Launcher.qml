pragma ComponentBehavior: Bound

// Spotlight-style application search matching the shell's compact panel language.
// Right clicking an entry exposes desktop-entry actions that have no other shell UI.
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Stylix
import "../panels"
import "../services"
import ".."

Scope {
    id: root

    property bool open: false
    property var terminal: ["kitty"]
    property string openedMonitorName: ""
    property string pendingLaunchName: ""
    property string pendingLaunchIcon: "application-x-executable"
    property string launchBaselineActiveAddress: ""
    property var launchBaselineAddresses: ({})

    function normalizedAddress(address: var): string {
        return String(address ?? "").replace(/^0x/, "");
    }

    function beginLaunchTracking(entry: DesktopEntry): void {
        const addresses = {};
        for (const toplevel of Hyprland.toplevels.values)
            addresses[root.normalizedAddress(toplevel.address)] = true;

        root.pendingLaunchName = entry.name;
        root.pendingLaunchIcon = String(entry.icon || "application-x-executable");
        root.launchBaselineAddresses = addresses;
        root.launchBaselineActiveAddress = root.normalizedAddress(Hyprland.activeToplevel?.address);
        slowLaunchTimer.restart();
    }

    function finishLaunchTracking(): void {
        slowLaunchTimer.stop();
        root.pendingLaunchName = "";
    }

    function screenForMonitor(name: string): var {
        for (const screen of Quickshell.screens) {
            if (String(screen.name) === name)
                return screen;
        }
        return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null;
    }

    function show(): void {
        const monitorName = String(Hyprland.focusedMonitor?.name ?? "");
        root.openedMonitorName = monitorName;
        ServicePanel.closeActive();
        root.open = true;
    }

    function toggle(): void {
        if (root.open)
            root.open = false;
        else
            root.show();
    }

    // Hyprland dispatches this in-process through its global-shortcut protocol.
    // Unlike `qs ipc call`, no Qt client process is started for each key press.
    GlobalShortcut {
        appid: "quickshell"
        name: "launcher"
        description: "Toggle application launcher"
        triggerDescription: "Super+Space"
        onPressed: root.toggle()
    }

    // Keep IPC for scripts and manual control; the keyboard bind uses the
    // GlobalShortcut above.
    IpcHandler {
        target: "launcher"

        function toggle(): void { root.toggle(); }
        function open(): void { root.show(); }
        function close(): void { root.open = false; }
        function isOpen(): bool { return root.open; }
    }

    Connections {
        target: Hyprland

        function onFocusedMonitorChanged(): void {
            if (!root.open)
                return;
            const monitorName = String(Hyprland.focusedMonitor?.name ?? "");
            if (monitorName !== root.openedMonitorName)
                root.open = false;
        }

        function onRawEvent(event: var): void {
            if (root.pendingLaunchName === "")
                return;

            if (event.name === "openwindow") {
                const address = root.normalizedAddress(event.data.split(",")[0]);
                if (!root.launchBaselineAddresses[address])
                    root.finishLaunchTracking();
            } else if (event.name === "activewindowv2") {
                const address = root.normalizedAddress(event.data);
                if (address !== "" && address !== root.launchBaselineActiveAddress)
                    root.finishLaunchTracking();
            }
        }
    }

    Timer {
        id: slowLaunchTimer
        interval: 3000

        onTriggered: {
            if (root.pendingLaunchName === "")
                return;
            Quickshell.execDetached([
                "notify-send",
                "--app-name=Application Launcher",
                `--icon=${root.pendingLaunchIcon}`,
                "--expire-time=2000",
                `${root.pendingLaunchName}`,
                "Application is launching..."
            ]);
            root.pendingLaunchName = "";
        }
    }

    PanelWindow {
        id: window

        screen: root.screenForMonitor(root.openedMonitorName)

        // Keep the layer surface mapped. Closing only makes it transparent and
        // removes its input region, avoiding a Wayland map round trip on open.
        visible: true
        color: "transparent"
        mask: Region {
            width: root.open ? window.width : 0
            height: root.open ? window.height : 0
        }
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "quickshell:launcher"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.open
            ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        readonly property var entries: {
            const entries = [];
            for (const entry of DesktopEntries.applications.values) {
                if (entry.noDisplay)
                    continue;

                entries.push({
                    entry,
                    name: entry.name.toLowerCase(),
                    description: `${entry.comment ?? ""} ${entry.genericName ?? ""}`.toLowerCase()
                });
            }
            return entries.sort((a, b) => a.entry.name.localeCompare(b.entry.name));
        }

        function fuzzyMatches(haystack: string, token: string): bool {
            let index = -1;
            for (const character of token) {
                index = haystack.indexOf(character, index + 1);
                if (index === -1)
                    return false;
            }
            return true;
        }

        function matchTier(item: var, token: string): int {
            if (item.name.startsWith(token)) return 0;
            if (item.name.includes(token)) return 1;
            if (window.fuzzyMatches(item.name, token)) return 2;
            if (item.description.includes(token)) return 3;
            return -1;
        }

        readonly property var results: {
            const tokens = search.text.toLowerCase().split(" ").filter(token => token !== "");
            if (tokens.length === 0)
                return window.entries;

            const matches = [];
            for (const item of window.entries) {
                let tier = 0;
                for (const token of tokens) {
                    const tokenTier = window.matchTier(item, token);
                    if (tokenTier === -1) {
                        tier = -1;
                        break;
                    }
                    tier = Math.max(tier, tokenTier);
                }
                if (tier !== -1)
                    matches.push({ item, tier });
            }
            return matches.sort((a, b) => a.tier - b.tier).map(match => match.item);
        }

        // Hover-select is ignored until the pointer actually moves after the
        // launcher opens. Without this, opening the launcher under a
        // stationary cursor synthesizes a hover-enter on whatever row/action
        // ends up beneath it, silently overriding the default selection.
        property bool hoverSelectReady: false
        // Cursor position observed the first time it's seen after opening.
        // Compared against later positions to detect real movement, since a
        // stationary cursor still reports a position once input starts.
        property var armPosition: null

        property var menuEntry: null
        property real menuX: 0
        property real menuY: 0
        property int menuActionIndex: 0
        readonly property bool menuOpen: menuEntry !== null
        readonly property var menuActions: menuEntry?.actions ?? []

        function openContextMenu(entry: DesktopEntry, item: Item, localX: real, localY: real): void {
            if (!entry)
                return;
            const point = item.mapToItem(null, localX, localY);
            window.menuX = point.x;
            window.menuY = point.y;
            window.menuActionIndex = 0;
            window.menuEntry = entry;
        }

        function closeContextMenu(): void {
            window.menuEntry = null;
            window.menuActionIndex = 0;
        }

        function moveContextSelection(offset: int): void {
            menuActionIndex = Math.max(0,
                Math.min(menuActions.length, menuActionIndex + offset));
        }

        function moveAppSelection(offset: int): void {
            if (results.length === 0) {
                appList.currentIndex = -1;
                return;
            }
            appList.currentIndex = Math.max(0, Math.min(results.length - 1,
                (appList.currentIndex < 0 ? 0 : appList.currentIndex) + offset));
            appList.positionViewAtIndex(appList.currentIndex, ListView.Contain);
        }

        function activateContextSelection(): void {
            const entry = menuEntry;
            if (!entry)
                return;
            if (menuActionIndex === 0) {
                closeContextMenu();
                launch(entry);
                return;
            }
            const action = menuActions[menuActionIndex - 1];
            if (!action)
                return;
            launchDetached(action.command, entry.workingDirectory);
            closeContextMenu();
            root.open = false;
        }

        function openSelectedContextMenu(): void {
            const item = appList.currentItem;
            if (!item?.entry)
                return;
            openContextMenu(item.entry, item, item.width - 10, item.height / 2);
        }

        function launchDetached(command: var, workingDirectory: string): void {
            Quickshell.execDetached({
                command: ["uwsm", "app", "--", ...command],
                workingDirectory: workingDirectory || Quickshell.env("HOME")
            });
        }

        function launch(entry: DesktopEntry): void {
            if (!entry)
                return;

            root.beginLaunchTracking(entry);
            launchDetached(entry.runInTerminal
                ? [...root.terminal, "--", ...entry.command]
                : entry.command, entry.workingDirectory);
            root.open = false;
        }

        Connections {
            target: root

            function onOpenChanged(): void {
                window.closeContextMenu();
                window.hoverSelectReady = false;
                window.armPosition = null;
                if (!root.open)
                    return;
                search.text = "";
                search.forceActiveFocus();
                appList.currentIndex = 0;
                appList.positionViewAtBeginning();
            }
        }

        Rectangle {
            anchors.fill: parent
            color: Theme.overlay
            opacity: root.open ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: ServicePanel.slideDuration } }
        }

        MouseArea {
            anchors.fill: parent
            enabled: root.open
            onClicked: root.open = false
        }

        // Arms hover-select once the pointer genuinely moves (as opposed to
        // the launcher merely appearing underneath it). A HoverHandler on
        // this top-level Item sees every pointer move within the window
        // regardless of which child is topmost, unlike a plain MouseArea
        // which only gets events when nothing else covers it.
        HoverHandler {
            enabled: root.open && !window.hoverSelectReady
            acceptedDevices: PointerDevice.AllDevices
            onPointChanged: {
                if (window.armPosition === null) {
                    window.armPosition = Qt.point(point.position.x, point.position.y);
                } else if (point.position.x !== window.armPosition.x
                        || point.position.y !== window.armPosition.y) {
                    window.hoverSelectReady = true;
                }
            }
        }

        Rectangle {
            id: launcherFrame

            anchors.centerIn: parent
            width: Math.min(640, parent.width - 32)
            height: Math.min(522, parent.height - 64)
            enabled: root.open
            clip: true
            radius: ServicePanel.rounding
            color: Theme.dark_background
            opacity: root.open ? 1 : 0
            scale: root.open ? 1 : 0.96
            Behavior on opacity { NumberAnimation { duration: ServicePanel.slideDuration } }
            Behavior on scale {
                NumberAnimation {
                    duration: ServicePanel.slideDuration
                    easing.type: Easing.OutCubic
                }
            }
            layer.enabled: true
            layer.effect: ShellShadow {}

            MouseArea {
                anchors.fill: parent
                onPressed: mouse => mouse.accepted = true
            }

            ColumnLayout {
                anchors {
                    fill: parent
                    leftMargin: 12
                    rightMargin: 12
                    topMargin: 12
                    bottomMargin: 12
                }
                opacity: root.open ? 1 : 0
                spacing: 10

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48
                    radius: ServicePanel.rounding
                    color: Theme.surface

                    Text {
                        anchors {
                            left: parent.left
                            leftMargin: 16
                            verticalCenter: parent.verticalCenter
                        }
                        text: "󰍉"
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: Utils.scaledFont(14)
                    }

                    TextInput {
                        id: search

                        anchors {
                            left: parent.left
                            right: parent.right
                            leftMargin: 46
                            rightMargin: 16
                            verticalCenter: parent.verticalCenter
                        }
                        height: 30
                        verticalAlignment: TextInput.AlignVCenter
                        focus: true
                        selectByMouse: true
                        clip: true
                        color: Theme.foreground
                        selectionColor: Theme.surface
                        selectedTextColor: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: Utils.scaledFont(14)

                        cursorDelegate: Rectangle {
                            width: 1
                            color: Theme.foreground
                        }

                        onTextChanged: appList.currentIndex = 0

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            visible: search.text === ""
                            text: "Search apps…"
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: Utils.scaledFont(14)
                        }

                        Keys.onEscapePressed: {
                            if (window.menuOpen)
                                window.closeContextMenu();
                            else
                                root.open = false;
                        }
                        Keys.onDownPressed: {
                            if (window.menuOpen)
                                window.moveContextSelection(1);
                            else
                                window.moveAppSelection(1);
                        }
                        Keys.onUpPressed: {
                            if (window.menuOpen)
                                window.moveContextSelection(-1);
                            else
                                window.moveAppSelection(-1);
                        }
                        Keys.onLeftPressed: if (window.menuOpen)
                            window.closeContextMenu()
                        Keys.onPressed: event => {
                            if (!window.menuOpen && (event.key === Qt.Key_Menu
                                    || (event.key === Qt.Key_F10
                                        && event.modifiers & Qt.ShiftModifier))) {
                                window.openSelectedContextMenu();
                                event.accepted = true;
                            }
                        }
                        Keys.onReturnPressed: {
                            if (window.menuOpen)
                                window.activateContextSelection();
                            else
                                window.launch(appList.currentItem?.entry ?? null);
                        }
                        Keys.onEnterPressed: {
                            if (window.menuOpen)
                                window.activateContextSelection();
                            else
                                window.launch(appList.currentItem?.entry ?? null);
                        }
                    }
                }

                ListView {
                    id: appList

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 4
                    model: window.results
                    currentIndex: window.results.length > 0 ? 0 : -1
                    keyNavigationEnabled: false
                    reuseItems: true
                    cacheBuffer: height
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Rectangle {
                        id: appRow

                        required property var modelData
                        required property int index
                        readonly property var entry: modelData.entry
                        readonly property bool selected: ListView.isCurrentItem

                        width: appList.width
                        height: 58
                        radius: ServicePanel.rounding
                        color: selected ? Theme.surface : "transparent"

                        Rectangle {
                            anchors {
                                left: parent.left
                                verticalCenter: parent.verticalCenter
                            }
                            width: 3
                            height: 30
                            radius: width / 2
                            color: Theme.accent
                            visible: appRow.selected
                        }

                        Item {
                            id: iconFrame
                            anchors {
                                left: parent.left
                                leftMargin: 14
                                verticalCenter: parent.verticalCenter
                            }
                            width: 38
                            height: 38

                            Text {
                                anchors.centerIn: parent
                                visible: applicationIcon.status === Image.Loading
                                text: "…"
                                color: Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: Utils.scaledFont(16)
                            }

                            Image {
                                anchors.centerIn: parent
                                width: 32
                                height: 32
                                visible: applicationIcon.status === Image.Error
                                    || applicationIcon.status === Image.Null
                                source: "file://" + Quickshell.env("QS_FALLBACK_APP_ICON")
                                sourceSize.width: 64
                                sourceSize.height: 64
                                smooth: true
                                layer.enabled: true
                                layer.effect: MultiEffect {
                                    brightness: 1
                                    colorization: 1
                                    colorizationColor: Theme.muted
                                }
                            }

                            Image {
                                id: applicationIcon
                                anchors.fill: parent
                                source: appRow.entry.icon
                                    ? Quickshell.iconPath(appRow.entry.icon, true) : ""
                                sourceSize.width: 76
                                sourceSize.height: 76
                                cache: true
                                asynchronous: true
                                smooth: true
                                visible: status === Image.Ready
                            }
                        }

                        Column {
                            anchors {
                                left: iconFrame.right
                                right: parent.right
                                leftMargin: 14
                                rightMargin: 14
                                verticalCenter: parent.verticalCenter
                            }
                            spacing: 2

                            Text {
                                width: parent.width
                                text: appRow.entry.name
                                color: Theme.foreground
                                elide: Text.ElideRight
                                font.family: Theme.fontFamily
                                font.pixelSize: Utils.scaledFont(14)
                                font.bold: appRow.selected
                            }

                            Text {
                                width: parent.width
                                text: appRow.entry.comment || appRow.entry.genericName || "Application"
                                color: Theme.muted
                                elide: Text.ElideRight
                                font.family: Theme.fontFamily
                                font.pixelSize: Utils.scaledFont(11)
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onContainsMouseChanged: if (containsMouse && window.hoverSelectReady)
                                appList.currentIndex = appRow.index
                            onClicked: mouse => {
                                appList.currentIndex = appRow.index;
                                if (mouse.button === Qt.RightButton)
                                    window.openContextMenu(appRow.entry, appRow, mouse.x, mouse.y);
                                else
                                    window.launch(appRow.entry);
                            }
                        }
                    }

                    // Desktop entries load asynchronously; without this, opening
                    // the launcher before they arrive briefly shows "no matching
                    // applications" instead of a loading state.
                    Column {
                        anchors.centerIn: parent
                        visible: window.entries.length === 0
                        spacing: 10

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "…"
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: Utils.scaledFont(28)
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "LOADING APPLICATIONS"
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: Utils.scaledFont(11)
                            font.bold: true
                            font.letterSpacing: 1
                        }
                    }

                    Column {
                        anchors.centerIn: parent
                        visible: window.entries.length > 0 && window.results.length === 0
                        spacing: 10

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "󰈉"
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: Utils.scaledFont(28)
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "NO MATCHING APPLICATIONS"
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: Utils.scaledFont(11)
                            font.bold: true
                            font.letterSpacing: 1
                        }
                    }
                }

            }
        }


        // Close context menu without also dismissing launcher.
        MouseArea {
            anchors.fill: parent
            visible: window.menuOpen
            z: 10
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onPressed: mouse => {
                window.closeContextMenu();
                mouse.accepted = true;
            }
        }

        Rectangle {
            id: contextMenu

            visible: window.menuOpen
            z: 11
            width: 250
            height: contextColumn.implicitHeight + 24
            radius: ServicePanel.rounding
            x: Math.max(8, Math.min(window.menuX, window.width - width - 8))
            y: Math.max(8, Math.min(window.menuY, window.height - height - 8))
            color: Theme.background
            border.width: 1
            border.color: Theme.border
            layer.enabled: true
            layer.effect: ShellShadow {}

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onPressed: mouse => mouse.accepted = true
            }

            Column {
                id: contextColumn
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: 12
                }
                spacing: 2

                PanelSectionHeader {
                    width: contextColumn.width
                    title: "APPLICATION ACTIONS"
                }

                Item { width: 1; height: 6 }

                Rectangle {
                    width: contextColumn.width
                    height: 34
                    radius: ServicePanel.rounding
                    color: window.menuActionIndex === 0 ? Theme.surface : "transparent"

                    Text {
                        anchors {
                            left: parent.left
                            leftMargin: 10
                            verticalCenter: parent.verticalCenter
                        }
                        text: "Launch"
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: Utils.scaledFont(13)
                        font.bold: true
                    }

                    Text {
                        anchors {
                            right: parent.right
                            rightMargin: 10
                            verticalCenter: parent.verticalCenter
                        }
                        text: "↵"
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: Utils.scaledFont(12)
                    }

                    MouseArea {
                        id: launchMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onContainsMouseChanged: if (containsMouse && window.hoverSelectReady)
                            window.menuActionIndex = 0
                        onClicked: {
                            const entry = window.menuEntry;
                            window.closeContextMenu();
                            window.launch(entry);
                        }
                    }
                }

                Repeater {
                    model: window.menuActions

                    Rectangle {
                        id: actionRow
                        required property var modelData
                        required property int index
                        width: contextColumn.width
                        height: 34
                        radius: ServicePanel.rounding
                        color: window.menuActionIndex === actionRow.index + 1
                            ? Theme.surface : "transparent"

                        Text {
                            anchors {
                                left: parent.left
                                right: parent.right
                                leftMargin: 10
                                rightMargin: 10
                                verticalCenter: parent.verticalCenter
                            }
                            text: actionRow.modelData.name
                            color: Theme.muted
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pixelSize: Utils.scaledFont(13)
                        }

                        MouseArea {
                            id: actionMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onContainsMouseChanged: if (containsMouse && window.hoverSelectReady)
                                window.menuActionIndex = actionRow.index + 1
                            onClicked: {
                                window.menuActionIndex = actionRow.index + 1;
                                window.launchDetached(actionRow.modelData.command,
                                    window.menuEntry?.workingDirectory ?? "");
                                window.closeContextMenu();
                                root.open = false;
                            }
                        }
                    }
                }
            }
        }
    }
}
