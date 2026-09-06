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
        PanelService.closeActive();
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

        // Debounced separately from search.text so the frame's height
        // (bound to results.length) doesn't re-animate on every keystroke
        // while typing fast.
        property string query: ""

        Timer {
            id: queryDebounce
            interval: 150
            onTriggered: window.query = search.text
        }

        readonly property var results: {
            const tokens = window.query.toLowerCase().split(" ").filter(token => token !== "");
            if (tokens.length === 0)
                return [];

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
            const found = matches.sort((a, b) => a.tier - b.tier).map(match => match.item);
            // No installed app matches -- offer to search the web / NixOS
            // packages for the typed term instead of a dead-end empty list.
            // Skipped while apps are still loading so this can't flash before
            // real matches have a chance to appear.
            if (found.length === 0 && window.entries.length > 0)
                return window.fallbackResults();
            return found;
        }

        function fallbackResults(): var {
            const term = window.query;
            return [
                {
                    isFallback: true,
                    entry: { name: "Search the web", icon: "firefox" },
                    command: ["firefox",
                        `https://www.google.com/search?q=${encodeURIComponent(term)}`]
                },
                {
                    isFallback: true,
                    entry: { name: "Search packages", icon: "nix-snowflake" },
                    command: ["firefox",
                        `https://search.nixos.org/packages?channel=unstable&query=${encodeURIComponent(term)}`]
                }
            ];
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

        function moveAppSelection(offset: int): void {
            if (results.length === 0) {
                appList.currentIndex = -1;
                return;
            }
            appList.currentIndex = Math.max(0, Math.min(results.length - 1,
                (appList.currentIndex < 0 ? 0 : appList.currentIndex) + offset));
            appList.positionViewAtIndex(appList.currentIndex, ListView.Contain);
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

        // Fallback rows (web/NixOS search) aren't desktop entries -- no
        // window to track, just fire and forget the browser command.
        function launchFallback(item: var): void {
            launchDetached(item.command, "");
            root.open = false;
        }

        // If Enter is pressed before the debounce timer fires, results still
        // reflect the stale query. Flush it immediately so the freshly typed
        // text has a chance to match, and jump to its top result rather than
        // launching whatever was selected under the old query.
        function launchSelection(): void {
            if (queryDebounce.running) {
                queryDebounce.stop();
                window.query = search.text;
                appList.currentIndex = window.results.length > 0 ? 0 : -1;
            }
            const current = appList.currentItem;
            if (current?.isFallback)
                window.launchFallback(current.modelData);
            else
                window.launch(current?.entry ?? null);
        }

        Connections {
            target: root

            function onOpenChanged(): void {
                window.hoverSelectReady = false;
                window.armPosition = null;
                // Reset immediately on close (while hidden) rather than on
                // open, so the frame is already collapsed to its empty-state
                // height before it's shown again — otherwise the height
                // Behavior animates the shrink visibly on the next open.
                search.text = "";
                queryDebounce.stop();
                window.query = "";
                appList.currentIndex = 0;
                if (!root.open)
                    return;
                search.forceActiveFocus();
                appList.positionViewAtBeginning();
            }
        }

        Rectangle {
            anchors.fill: parent
            color: Utils.alpha(Theme.base00, 0.7)
            opacity: root.open ? 1 : 0
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
            width: Math.min(400, parent.width - 32)
            // 72 = top+bottom margins (12 each) + search row (48); the list
            // only adds its own height (rows + inter-row spacing) plus the
            // spacing between the search row and the list, so the frame
            // never grows past what the visible rows need.
            readonly property int searchBarHeight: 72
            readonly property int rowHeight: 58
            readonly property int rowSpacing: 4
            readonly property int maxHeight: Math.min(400, parent.height - 64)
            readonly property int wantedListHeight: window.results.length === 0 ? 0
                : window.results.length * launcherFrame.rowHeight
                    + (window.results.length - 1) * launcherFrame.rowSpacing

            Behavior on height {
                NumberAnimation { duration: 100; easing.type: Easing.OutQuad }
            }

            height: window.results.length === 0
                ? launcherFrame.searchBarHeight
                : Math.min(launcherFrame.maxHeight,
                    launcherFrame.searchBarHeight + 10 + launcherFrame.wantedListHeight)
            enabled: root.open

            clip: true
            radius: PanelService.rounding
            color: Theme.base01
            opacity: root.open ? 1 : 0
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

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48

                    Text {
                        anchors {
                            left: parent.left
                            leftMargin: 16
                            verticalCenter: parent.verticalCenter
                        }
                        text: "󰍉"
                        color: Theme.base04
                        font.family: Theme.monospace
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
                        color: Theme.base05
                        selectionColor: Theme.base02
                        selectedTextColor: Theme.base05
                        font.family: Theme.monospace
                        font.pixelSize: Utils.scaledFont(14)

                        cursorDelegate: Rectangle {
                            width: 1
                            color: Theme.base05
                        }

                        onTextChanged: {
                            appList.currentIndex = 0;
                            queryDebounce.restart();
                        }

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            visible: search.text === ""
                            text: "Search apps…"
                            color: Theme.base04
                            font.family: Theme.monospace
                            font.pixelSize: Utils.scaledFont(14)
                        }

                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_C && event.modifiers === Qt.ControlModifier) {
                                search.text = "";
                                event.accepted = true;
                            }
                        }
                        Keys.onEscapePressed: root.open = false
                        Keys.onDownPressed: window.moveAppSelection(1)
                        Keys.onUpPressed: window.moveAppSelection(-1)
                        Keys.onReturnPressed: window.launchSelection()
                        Keys.onEnterPressed: window.launchSelection()
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
                        readonly property bool isFallback: !!modelData.isFallback
                        readonly property bool selected: ListView.isCurrentItem

                        width: appList.width
                        height: 58
                        radius: PanelService.rounding
                        color: selected ? Theme.base02 : "transparent"

                        Rectangle {
                            anchors {
                                left: parent.left
                                verticalCenter: parent.verticalCenter
                            }
                            width: 3
                            height: 30
                            radius: width / 2
                            color: Theme.base0D
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
                                color: Theme.base04
                                font.family: Theme.monospace
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
                                    colorizationColor: Theme.base04
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

                        Text {
                            anchors {
                                left: iconFrame.right
                                right: parent.right
                                leftMargin: 14
                                rightMargin: 14
                                verticalCenter: parent.verticalCenter
                            }
                            text: appRow.entry.name
                            color: Theme.base05
                            elide: Text.ElideRight
                            font.family: Theme.monospace
                            font.pixelSize: Utils.scaledFont(16)
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onContainsMouseChanged: if (containsMouse && window.hoverSelectReady)
                                appList.currentIndex = appRow.index
                            onClicked: {
                                appList.currentIndex = appRow.index;
                                if (appRow.isFallback)
                                    window.launchFallback(appRow.modelData);
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
                            color: Theme.base04
                            font.family: Theme.monospace
                            font.pixelSize: Utils.scaledFont(28)
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "LOADING APPLICATIONS"
                            color: Theme.base04
                            font.family: Theme.monospace
                            font.pixelSize: Utils.scaledFont(11)
                            font.bold: true
                            font.letterSpacing: 1
                        }
                    }
                }

            }
        }
    }
}
