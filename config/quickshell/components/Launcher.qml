pragma ComponentBehavior: Bound

// Windows-inspired Start panel, using the same square, low-contrast chrome as the rest of the shell.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import "../services"
import ".."

Scope {
    id: root

    property var terminal: ["kitty"]
    property bool open: false
    property bool allApps: false
    property bool keybindMode: false
    property var binds: []
    property string bindsLoadError: ""
    property bool powerMenuOpen: false
    property bool pinMenuOpen: false
    property var pinMenuItem: null
    property real pinMenuX: 0
    property real pinMenuY: 0
    property string openedMonitorName: ""
    property int currentIndex: 0
    property string pendingLaunchName: ""
    property string pendingLaunchIcon: "application-x-executable"
    property string launchBaselineActiveAddress: ""
    property var launchBaselineAddresses: ({})
    property var appUsage: ({})
    property var pinnedAppIds: []
    property bool pinStateLoaded: false
    property bool pinsInitialized: false

    readonly property var entries: {
        const applications = [];
        for (const entry of DesktopEntries.applications.values) {
            if (entry.noDisplay)
                continue;
            applications.push({
                entry,
                name: entry.name.toLowerCase(),
                categories: Array.from(entry.categories ?? []).join(" ").toLowerCase(),
                description: `${entry.comment ?? ""} ${entry.genericName ?? ""}`.toLowerCase()
            });
        }
        return applications.sort((a, b) => a.entry.name.localeCompare(b.entry.name));
    }

    readonly property var pinnedEntries: {
        const pinned = [];
        for (const id of root.pinnedAppIds) {
            const item = root.entries.find(candidate => candidate.entry.id === id);
            if (item)
                pinned.push(item);
        }
        return pinned;
    }

    function initializeDefaultPins(): void {
        if (root.pinsInitialized || root.entries.length === 0)
            return;
        const preferred = [
            "firefox", "kitty", "files", "nautilus", "yazi", "code", "vscode",
            "1password", "spotify", "discord", "calculator", "settings"
        ];
        const defaults = [];
        for (const needle of preferred) {
            const found = root.entries.find(item => !defaults.includes(item.entry.id)
                && (`${item.entry.id} ${item.entry.name}`).toLowerCase().includes(needle));
            if (found)
                defaults.push(found.entry.id);
            if (defaults.length === 8)
                break;
        }
        for (const item of root.entries) {
            if (defaults.length === 8)
                break;
            if (!defaults.includes(item.entry.id))
                defaults.push(item.entry.id);
        }
        root.pinnedAppIds = defaults;
        root.pinsInitialized = true;
        pinnedAppsState.setText(JSON.stringify(defaults) + "\n");
    }

    function restorePinnedApps(value: string): void {
        try {
            const stored = JSON.parse(String(value).trim());
            if (Array.isArray(stored)) {
                root.pinnedAppIds = stored.map(id => String(id)).slice(0, 8);
                root.pinsInitialized = true;
                return;
            }
        } catch (error) {
        }
        root.initializeDefaultPins();
    }

    function isPinned(item: var): bool {
        return !!item && !item.isFallback && !item.isSystemAction && !!item.entry
            && root.pinnedAppIds.includes(String(item.entry.id));
    }

    function togglePinned(item: var): void {
        if (!item || item.isFallback || !item.entry)
            return;
        const id = String(item.entry.id);
        const pins = root.pinnedAppIds.slice();
        const index = pins.indexOf(id);
        if (index !== -1)
            pins.splice(index, 1);
        else if (pins.length < 8)
            pins.push(id);
        else
            return;
        root.pinnedAppIds = pins;
        root.pinsInitialized = true;
        pinnedAppsState.setText(JSON.stringify(pins) + "\n");
    }

    function showPinMenu(item: var, source: Item, x: real, y: real): void {
        if (!item || item.isFallback || item.isSystemAction || !item.entry)
            return;
        const point = source.mapToItem(panel, x, y);
        root.pinMenuItem = item;
        root.pinMenuX = Math.max(8, Math.min(panel.width - 188, point.x));
        root.pinMenuY = Math.max(8, Math.min(panel.height - 52, point.y));
        root.powerMenuOpen = false;
        root.pinMenuOpen = true;
    }

    function movePinned(from: int, to: int): void {
        if (from < 0 || from >= root.pinnedAppIds.length
                || to < 0 || to >= root.pinnedAppIds.length || from === to)
            return;
        const pins = root.pinnedAppIds.slice();
        pins.splice(to, 0, pins.splice(from, 1)[0]);
        root.pinnedAppIds = pins;
        pinnedAppsState.setText(JSON.stringify(pins) + "\n");
    }

    onEntriesChanged: if (root.pinStateLoaded && !root.pinsInitialized)
        root.initializeDefaultPins()

    readonly property var mostUsedEntries: root.entries
        .filter(item => Number(root.appUsage[item.entry.id] ?? 0) > 0)
        .sort((a, b) => Number(root.appUsage[b.entry.id]) - Number(root.appUsage[a.entry.id])
            || a.entry.name.localeCompare(b.entry.name))
        .slice(0, 10)

    function rememberApp(entry: DesktopEntry): void {
        if (!entry)
            return;
        const id = String(entry.id);
        const usage = Object.assign({}, root.appUsage);
        usage[id] = Number(usage[id] ?? 0) + 1;
        root.appUsage = usage;
        appUsageState.setText(JSON.stringify(root.appUsage) + "\n");
    }

    function forgetAppUsage(item: var): void {
        if (!item || !item.entry)
            return;
        const usage = Object.assign({}, root.appUsage);
        delete usage[String(item.entry.id)];
        root.appUsage = usage;
        appUsageState.setText(JSON.stringify(usage) + "\n");
    }

    function restoreAppUsage(value: string): void {
        try {
            const stored = JSON.parse(String(value).trim());
            if (Array.isArray(stored)) {
                // Migrate the previous recently-opened list into initial usage data.
                const migrated = {};
                for (const id of stored)
                    migrated[String(id)] = 1;
                root.appUsage = migrated;
            } else if (stored && typeof stored === "object") {
                root.appUsage = stored;
            }
        } catch (error) {
            root.appUsage = {};
        }
    }

    function matchTier(item: var, token: string): int {
        if (item.name.startsWith(token)) return 0;
        if (item.name.includes(token)) return 1;
        if (Utils.fuzzyMatches(item.name, token)) return 2;
        if (item.categories.includes(token)) return 3;
        if (item.description.includes(token)) return 3;
        return -1;
    }

    function keyName(key: string): string {
        if (key.startsWith("switch:"))
            return key.replace(/^switch:o(n|ff):/, "").replace(/\s*Switch$/, "")
                + (key.startsWith("switch:on:") ? " Close" : " Open");
        if (key.startsWith("XF86"))
            return key.slice(4).replace(/([a-z])([A-Z])/g, "$1 $2");
        if (key === "mouse:272") return "Left Mouse";
        if (key === "mouse:273") return "Right Mouse";
        if (key === "mouse:274") return "Middle Mouse";
        if (key === "mouse_up") return "Scroll Up";
        if (key === "mouse_down") return "Scroll Down";
        if (key.startsWith("mouse:") || key.startsWith("code:")) return key;
        if (key.length === 1) return key.toUpperCase();
        return key.charAt(0).toUpperCase() + key.slice(1);
    }

    function modifierText(bind: var): string {
        if (!bind)
            return "None";
        const parts = [];
        for (const modifier of [{ bit: 64, name: "SUPER" }, { bit: 4, name: "CTRL" },
                { bit: 8, name: "ALT" }, { bit: 1, name: "SHIFT" }]) {
            if (bind.modmask & modifier.bit)
                parts.push(modifier.name);
        }
        return parts.length > 0 ? parts.join(" + ") : "None";
    }

    function chordText(bind: var): string {
        const modifiers = root.modifierText(bind);
        const key = root.keyName(String(bind.key ?? ""));
        return modifiers === "None" ? key : `${modifiers} + ${key}`;
    }

    readonly property var keybindRows: {
        const tokens = search.text.toLowerCase().split(" ").filter(token => token !== "");
        const rows = [];
        for (const bind of root.binds) {
            const chord = root.chordText(bind);
            const description = String(bind.description ?? "");
            const haystack = `${chord} ${description}`.toLowerCase();
            if (tokens.every(token => haystack.includes(token)
                    || Utils.fuzzyMatches(haystack, token)))
                rows.push(Object.assign({}, bind, { chord, description }));
        }
        return rows.sort((a, b) => a.modmask - b.modmask
            || a.description.localeCompare(b.description));
    }

    function showKeybinds(): void {
        if (!root.open)
            root.show();
        root.allApps = false;
        root.keybindMode = true;
        root.currentIndex = 0;
        search.text = "";
        if (root.binds.length === 0 && !bindsProcess.running)
            bindsProcess.running = true;
        search.forceActiveFocus();
    }

    readonly property var results: {
        const tokens = search.text.toLowerCase().split(" ").filter(token => token !== "");
        if (tokens.length === 0)
            return [];
        const matches = [];
        const keybindingsItem = {
            isSystemAction: true,
            isKeybinds: true,
            name: "keybindings",
            categories: "settings system keyboard",
            description: "browse shell window management shortcuts hotkeys",
            entry: {
                id: "quickshell-keybindings",
                name: "Keybindings",
                icon: "preferences-desktop-keyboard",
                comment: "Browse shell and window-management shortcuts",
                categories: ["Settings"]
            }
        };
        for (const item of [...root.entries, keybindingsItem]) {
            let tier = 0;
            for (const token of tokens) {
                const tokenTier = root.matchTier(item, token);
                if (tokenTier === -1) {
                    tier = -1;
                    break;
                }
                tier = Math.max(tier, tokenTier);
            }
            if (tier !== -1)
                matches.push({ item, tier });
        }
        const found = matches.sort((a, b) => a.tier - b.tier
            || Number(root.appUsage[b.item.entry.id] ?? 0)
                - Number(root.appUsage[a.item.entry.id] ?? 0)
            || a.item.entry.name.localeCompare(b.item.entry.name)).map(match => match.item);
        return found.length > 0 || root.entries.length === 0 ? found : root.fallbackResults();
    }

    readonly property var activeModel: root.keybindMode ? root.keybindRows
        : (search.text !== "" ? root.results
            : (root.allApps ? root.entries : root.pinnedEntries))
    readonly property var selectedItem: root.activeModel[root.currentIndex] ?? null
    readonly property var selectedKeybind: root.keybindMode
        ? root.keybindRows[root.currentIndex] ?? null : null

    function keybindType(bind: var): string {
        if (!bind)
            return "";
        const key = String(bind.key ?? "");
        if (bind.mouse || key.startsWith("mouse")) return "Mouse";
        if (key.startsWith("switch:")) return "Switch";
        return "Keyboard";
    }

    function keybindTrigger(bind: var): string {
        if (!bind)
            return "";
        if (bind.longPress) return "Long press";
        if (bind.release) return "Release";
        return "Press";
    }

    function keybindOptions(bind: var): string {
        if (!bind)
            return "";
        const options = [];
        if (bind.repeat) options.push("Repeats");
        if (bind.locked) options.push("Available while locked");
        if (bind.non_consuming) options.push("Non-consuming");
        if (bind.auto_consuming) options.push("Auto-consuming");
        if (bind.catch_all) options.push("Catch-all");
        if (bind.allow_input_capture) options.push("Input capture");
        if (String(bind.submap ?? "") !== "")
            options.push(`Submap: ${bind.submap}`);
        return options.length > 0 ? options.join(", ") : "Standard";
    }

    function categoryText(item: var): string {
        if (!item || item.isFallback || !item.entry)
            return "";
        const categories = Array.from(item.entry.categories ?? [])
            .filter(category => category !== "" && !category.startsWith("X-")
                && category !== "GTK" && category !== "Qt")
            .slice(0, 2)
            .map(category => String(category).replace(/([a-z])([A-Z])/g, "$1 $2"));
        return categories.join(", ");
    }

    function fallbackResults(): var {
        const term = search.text;
        return [
            {
                isFallback: true,
                entry: { name: "Search the web", icon: "firefox",
                    comment: `Find “${term}” with Google` },
                command: ["firefox", `https://www.google.com/search?q=${encodeURIComponent(term)}`]
            },
            {
                isFallback: true,
                entry: { name: "Search NixOS packages", icon: "nix-snowflake",
                    comment: `Find a package named “${term}”` },
                command: ["firefox", `https://search.nixos.org/packages?channel=unstable&query=${encodeURIComponent(term)}`]
            }
        ];
    }

    function show(): void {
        root.openedMonitorName = String(Hyprland.focusedMonitor?.name ?? "");
        PanelService.closeActive();
        root.allApps = false;
        root.keybindMode = false;
        root.powerMenuOpen = false;
        root.pinMenuOpen = false;
        root.currentIndex = 0;
        root.open = true;
    }

    function toggle(): void {
        if (root.open)
            root.open = false;
        else
            root.show();
    }

    function scrollListByWheel(view: var, event: var): void {
        let delta = Number(event.pixelDelta.y);
        if (delta === 0)
            delta = Number(event.angleDelta.y) / 120 * 100;
        if (event.inverted)
            delta = -delta;
        const minimum = Number(view.originY);
        const maximum = Math.max(minimum,
            minimum + Number(view.contentHeight) - Number(view.height));
        view.contentY = Math.max(minimum,
            Math.min(maximum, Number(view.contentY) - delta));
        event.accepted = true;
    }

    function moveSelection(offset: int): void {
        if (root.activeModel.length === 0) {
            root.currentIndex = -1;
            return;
        }
        root.currentIndex = Math.max(0, Math.min(root.activeModel.length - 1,
            Math.max(0, root.currentIndex) + offset));
        if (root.keybindMode)
            keybindList.positionViewAtIndex(root.currentIndex, ListView.Contain);
        else if (search.text !== "")
            searchResults.positionViewAtIndex(root.currentIndex, ListView.Contain);
        else if (root.allApps)
            allAppsList.positionViewAtIndex(root.currentIndex, ListView.Contain);
        else
            pinnedGrid.positionViewAtIndex(root.currentIndex, GridView.Contain);
    }

    onOpenChanged: {
        search.text = "";
        root.currentIndex = 0;
        if (root.open)
            search.forceActiveFocus();
    }
    onActiveModelChanged: root.currentIndex = root.activeModel.length > 0 ? 0 : -1

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

    function shellQuote(args: var): string {
        return args.map(arg => "'" + String(arg).replace(/'/g, "'\\''") + "'").join(" ");
    }

    function launchDetached(command: var, workingDirectory: string): void {
        const cwd = workingDirectory || Quickshell.env("HOME");
        const line = `cd ${root.shellQuote([cwd])} && exec ${root.shellQuote(["uwsm", "app", "--", ...command])}`;
        Quickshell.execDetached(["hyprctl", "dispatch",
            `hl.dsp.exec_cmd("${line.replace(/[\\"]/g, "\\$&")}")`]);
    }

    function launch(entry: DesktopEntry): void {
        if (!entry)
            return;
        root.rememberApp(entry);
        root.beginLaunchTracking(entry);
        root.launchDetached(entry.runInTerminal
            ? [...root.terminal, "--class", entry.id, "--", ...entry.command]
            : entry.command, entry.workingDirectory);
        root.open = false;
    }

    function activate(item: var): void {
        if (!item)
            return;
        if (item.isKeybinds) {
            root.showKeybinds();
        } else if (item.isFallback) {
            root.launchDetached(item.command, "");
            root.open = false;
        } else {
            root.launch(item.entry);
        }
    }

    GlobalShortcut {
        appid: "quickshell"
        name: "launcher"
        description: "Toggle application launcher"
        triggerDescription: "Super+Space"
        onPressed: root.toggle()
    }

    GlobalShortcut {
        appid: "quickshell"
        name: "keybinds"
        description: "Open keybindings in application launcher"
        triggerDescription: "Super+Ctrl+K"
        onPressed: {
            if (root.open && root.keybindMode)
                root.open = false;
            else
                root.showKeybinds();
        }
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void { root.toggle(); }
        function open(): void { root.show(); }
        function close(): void { root.open = false; }
        function isOpen(): bool { return root.open; }
    }

    IpcHandler {
        target: "keybinds"
        function toggle(): void {
            if (root.open && root.keybindMode)
                root.open = false;
            else
                root.showKeybinds();
        }
        function open(): void { root.showKeybinds(); }
        function close(): void { root.open = false; }
        function isOpen(): bool { return root.open && root.keybindMode; }
    }

    Connections {
        target: Hyprland
        function onFocusedMonitorChanged(): void {
            if (root.open && String(Hyprland.focusedMonitor?.name ?? "") !== root.openedMonitorName)
                root.open = false;
        }
        function onRawEvent(event: var): void {
            if (event.name === "configreloaded") {
                root.binds = [];
                if (root.keybindMode)
                    bindsProcess.running = true;
            } else if (event.name === "openwindow") {
                const address = root.normalizedAddress(event.data.split(",")[0]);
                if (!root.launchBaselineAddresses[address])
                    root.finishLaunchTracking();
            } else if (event.name === "activewindowv2" && root.pendingLaunchName !== "") {
                const address = root.normalizedAddress(event.data);
                if (address !== "" && address !== root.launchBaselineActiveAddress)
                    root.finishLaunchTracking();
            }
        }
    }

    Process {
        id: bindsProcess
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    root.binds = JSON.parse(text);
                    root.bindsLoadError = "";
                } catch (error) {
                    root.binds = [];
                    root.bindsLoadError = "Could not read keybindings";
                }
            }
        }
    }

    FileView {
        id: pinnedAppsState
        path: Quickshell.statePath("launcher-pinned-apps")
        preload: true
        atomicWrites: true
        printErrors: false
        onLoaded: {
            root.pinStateLoaded = true;
            root.restorePinnedApps(text());
        }
        onLoadFailed: {
            root.pinStateLoaded = true;
            root.initializeDefaultPins();
        }
    }

    FileView {
        id: appUsageState
        // Retain the old path so existing recent-app state can migrate in place.
        path: Quickshell.statePath("launcher-recent-apps")
        preload: true
        atomicWrites: true
        printErrors: false
        onLoaded: root.restoreAppUsage(text())
    }

    Timer {
        id: slowLaunchTimer
        interval: 3000
        onTriggered: {
            if (root.pendingLaunchName === "")
                return;
            Quickshell.execDetached(["notify-send", "--app-name=Application Launcher",
                `--icon=${root.pendingLaunchIcon}`, "--expire-time=2000",
                root.pendingLaunchName, "Application is launching..."]);
            root.pendingLaunchName = "";
        }
    }

    PanelWindow {
        id: window

        screen: Utils.screenForMonitor(root.openedMonitorName)
        visible: true
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }
        mask: Region {
            width: root.open ? window.width : 0
            height: root.open ? window.height : 0
        }
        WlrLayershell.namespace: "quickshell:launcher"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.open
            ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        Rectangle {
            anchors.fill: parent
            color: "transparent"
        }

        MouseArea {
            anchors.fill: parent
            enabled: root.open
            onClicked: root.open = false
        }

        Rectangle {
            id: panel

            anchors {
                left: parent.left
                bottom: parent.bottom
                leftMargin: PanelService.panelGap + PanelService.gapLeftOffset
                bottomMargin: PanelService.panelBarInset + PanelService.panelGap
            }
            width: Math.min(680, parent.width - anchors.leftMargin - PanelService.panelGap)
            height: Math.min(780, parent.height - anchors.bottomMargin - PanelService.panelGap)
            color: Theme.base01
            // The overlay border at the end of this component is the single
            // source of outer chrome, avoiding doubled edges beside transparent content.
            border.width: 0
            border.color: PanelService.chromeBorderColor
            radius: 0
            clip: true
            enabled: root.open
            opacity: root.open ? 1 : 0

            MouseArea {
                anchors.fill: parent
                onPressed: mouse => mouse.accepted = true
            }

            Rectangle {
                id: header
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: footer.height
                color: Theme.base00

                Rectangle {
                    id: searchBox
                    anchors {
                        left: parent.left; right: parent.right
                        leftMargin: 28; rightMargin: 29
                        verticalCenter: parent.verticalCenter
                    }
                    height: 34
                    color: Theme.base01
                    radius: height / 2
                    border.width: 1
                    border.color: PanelService.chromeBorderColor

                    ShellText {
                        id: searchIcon
                        anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                        text: "󰍉"
                        color: Theme.base04
                        size: 15
                    }

                    TextInput {
                    id: search
                    anchors {
                        left: searchIcon.right; right: parent.right
                        leftMargin: 11; rightMargin: 14; verticalCenter: parent.verticalCenter
                    }
                    height: 26
                    verticalAlignment: TextInput.AlignVCenter
                    focus: true
                    selectByMouse: true
                    clip: true
                    color: Theme.base05
                    selectionColor: Theme.base02
                    selectedTextColor: Theme.base05
                    font.family: Theme.monospace
                    font.pixelSize: Utils.scaledFont(13)
                    cursorDelegate: Rectangle { width: 1; color: Theme.base05 }

                    ShellText {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        visible: search.text === ""
                        text: root.keybindMode ? "Search keybindings" : "Search for apps"
                        color: Theme.base04
                        size: 13
                    }

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape) {
                            if (root.pinMenuOpen) {
                                root.pinMenuOpen = false;
                            } else if (root.powerMenuOpen) {
                                root.powerMenuOpen = false;
                            } else if (root.keybindMode) {
                                root.open = false;
                            } else if (search.text !== "") {
                                search.text = "";
                                root.currentIndex = 0;
                            } else if (root.allApps) {
                                root.allApps = false;
                                root.currentIndex = 0;
                            } else {
                                root.open = false;
                            }
                        } else if (event.key === Qt.Key_Down) {
                            root.moveSelection(root.keybindMode || root.allApps
                                || search.text !== "" ? 1 : 4);
                        } else if (event.key === Qt.Key_Up) {
                            root.moveSelection(root.keybindMode || root.allApps
                                || search.text !== "" ? -1 : -4);
                        } else if (!root.keybindMode && search.text === ""
                                && !root.allApps && event.key === Qt.Key_Right) {
                            root.moveSelection(1);
                        } else if (!root.keybindMode && search.text === ""
                                && !root.allApps && event.key === Qt.Key_Left) {
                            root.moveSelection(-1);
                        } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                                && !root.keybindMode) {
                            root.activate(root.selectedItem);
                        } else if (event.key === Qt.Key_C && event.modifiers === Qt.ControlModifier) {
                            search.text = "";
                        } else {
                            return;
                        }
                        event.accepted = true;
                    }
                }
            }
            }

            Item {
                id: page
                anchors {
                    top: header.bottom; bottom: footer.top
                    left: parent.left; right: parent.right
                    topMargin: 0; leftMargin: 28; rightMargin: 29; bottomMargin: 0
                }

                Item {
                    id: startPage
                    anchors.fill: parent
                    visible: !root.keybindMode && search.text === "" && !root.allApps

                    ShellText {
                        id: pinnedTitle
                        y: 22
                        text: "PINNED"
                        font.bold: true
                        font.letterSpacing: 1
                        size: 11
                    }

                    Rectangle {
                        anchors { right: parent.right; verticalCenter: pinnedTitle.verticalCenter }
                        width: allAppsLabel.width + 20
                        height: 28
                        radius: PanelService.rounding
                        color: allAppsMouse.containsMouse
                            ? Utils.alpha(Theme.base05, 0.07) : "transparent"
                        border.width: 0
                        ShellText { id: allAppsLabel; anchors.centerIn: parent; text: "ALL APPS  →"; size: 11 }
                        MouseArea {
                            id: allAppsMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { root.allApps = true; root.currentIndex = 0; search.forceActiveFocus(); }
                        }
                    }

                    GridView {
                        id: pinnedGrid
                        anchors { top: pinnedTitle.bottom; left: parent.left; right: parent.right; topMargin: 12 }
                        height: cellWidth * 1.7
                        model: root.pinnedEntries
                        cellWidth: width / 4
                        cellHeight: cellWidth * 0.85
                        interactive: false
                        currentIndex: root.currentIndex

                        delegate: Rectangle {
                            id: pinnedApp
                            required property var modelData
                            required property int index
                            property bool wasDragged: false
                            property real dragOriginX: 0
                            property real dragOriginY: 0
                            width: GridView.view.cellWidth - 6
                            height: GridView.view.cellHeight - 6
                            radius: PanelService.rounding
                            z: pinnedMouse.drag.active ? 10 : 0
                            color: pinnedApp.GridView.isCurrentItem
                                ? Utils.alpha(Theme.base05, 0.11)
                                : (pinnedMouse.containsMouse ? Utils.alpha(Theme.base05, 0.07) : "transparent")

                            Column {
                                anchors.centerIn: parent
                                width: parent.width - 24
                                spacing: 10

                                Image {
                                    id: pinnedIcon
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: 40; height: 40
                                    source: modelData.entry.icon ? Quickshell.iconPath(modelData.entry.icon, true) : ""
                                    sourceSize.width: 64; sourceSize.height: 64
                                    asynchronous: true; smooth: true
                                }
                                ShellText {
                                    width: parent.width
                                    horizontalAlignment: Text.AlignHCenter
                                    text: modelData.entry.name
                                    elide: Text.ElideRight
                                    size: 12
                                }
                            }
                            MouseArea {
                                id: pinnedMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                                cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                                drag.target: pinnedApp
                                drag.axis: Drag.XAndYAxis
                                drag.minimumX: 0
                                drag.maximumX: pinnedGrid.width - pinnedApp.width
                                drag.minimumY: 0
                                drag.maximumY: pinnedGrid.height - pinnedApp.height
                                onPressed: {
                                    pinnedApp.wasDragged = false;
                                    pinnedApp.dragOriginX = pinnedApp.x;
                                    pinnedApp.dragOriginY = pinnedApp.y;
                                }
                                onPositionChanged: if (drag.active) pinnedApp.wasDragged = true
                                onEntered: root.currentIndex = pinnedApp.index
                                onReleased: {
                                    if (!pinnedApp.wasDragged)
                                        return;
                                    const column = Math.max(0, Math.min(3,
                                        Math.floor((pinnedApp.x + pinnedApp.width / 2)
                                            / pinnedGrid.cellWidth)));
                                    const row = Math.max(0, Math.min(1,
                                        Math.floor((pinnedApp.y + pinnedApp.height / 2)
                                            / pinnedGrid.cellHeight)));
                                    const target = Math.min(root.pinnedAppIds.length - 1,
                                        row * 4 + column);
                                    if (target === pinnedApp.index) {
                                        pinnedApp.x = pinnedApp.dragOriginX;
                                        pinnedApp.y = pinnedApp.dragOriginY;
                                    } else {
                                        root.movePinned(pinnedApp.index, target);
                                        root.currentIndex = target;
                                    }
                                    pinnedGrid.forceLayout();
                                }
                                onClicked: mouse => {
                                    if (pinnedApp.wasDragged)
                                        return;
                                    if (mouse.button === Qt.MiddleButton)
                                        root.togglePinned(modelData);
                                    else if (mouse.button === Qt.RightButton)
                                        root.showPinMenu(pinnedApp.modelData,
                                            pinnedApp, mouse.x, mouse.y);
                                    else
                                        root.activate(modelData);
                                }
                            }
                        }
                    }

                    ShellText {
                        id: mostUsedTitle
                        anchors { top: pinnedGrid.bottom; left: parent.left; topMargin: 18 }
                        text: "RECENT"
                        font.bold: true
                        font.letterSpacing: 1
                        size: 11
                    }

                    ShellText {
                        anchors { top: mostUsedTitle.bottom; left: parent.left; topMargin: 22; leftMargin: 10 }
                        visible: root.mostUsedEntries.length === 0
                        text: "Apps you open will appear here"
                        color: Theme.base04
                        size: 12
                    }

                    Rectangle {
                        anchors { right: parent.right; verticalCenter: mostUsedTitle.verticalCenter }
                        width: clearSearchLabel.width + 18
                        height: 26
                        visible: root.mostUsedEntries.length > 0
                        radius: PanelService.rounding
                        color: clearSearchMouse.containsMouse ? Utils.alpha(Theme.base05, 0.10) : "transparent"
                        ShellText {
                            id: clearSearchLabel
                            anchors.centerIn: parent
                            text: "CLEAR"
                            color: Theme.base04
                            size: 10
                        }
                        MouseArea {
                            id: clearSearchMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.appUsage = {};
                                appUsageState.setText("{}\n");
                            }
                        }
                    }

                    GridView {
                        anchors { top: mostUsedTitle.bottom; bottom: parent.bottom; left: parent.left; right: parent.right; topMargin: 10 }
                        model: root.mostUsedEntries
                        cellWidth: width / 2
                        cellHeight: 58
                        interactive: false
                        delegate: Rectangle {
                            id: recentApp
                            required property var modelData
                            width: GridView.view.cellWidth - 5
                            height: 54
                            radius: PanelService.rounding
                            color: recentAppMouse.containsMouse ? Utils.alpha(Theme.base05, 0.08) : "transparent"
                            Image {
                                id: recentAppIcon
                                anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                                width: 28; height: 28
                                source: modelData.entry.icon ? Quickshell.iconPath(modelData.entry.icon, true) : ""
                                sourceSize.width: 48; sourceSize.height: 48
                                asynchronous: true; smooth: true
                            }
                            ShellText {
                                anchors { left: recentAppIcon.right; right: parent.right; leftMargin: 10; rightMargin: 8; verticalCenter: parent.verticalCenter }
                                text: modelData.entry.name
                                elide: Text.ElideRight
                                size: 12
                            }
                            MouseArea {
                                id: recentAppMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                                cursorShape: Qt.PointingHandCursor
                                onClicked: mouse => {
                                    if (mouse.button === Qt.MiddleButton)
                                        root.forgetAppUsage(modelData);
                                    else if (mouse.button === Qt.RightButton)
                                        root.showPinMenu(recentApp.modelData,
                                            recentApp, mouse.x, mouse.y);
                                    else
                                        root.activate(modelData);
                                }
                            }
                        }
                    }
                }

                Item {
                    anchors.fill: parent
                    visible: !root.keybindMode && search.text === "" && root.allApps

                    Rectangle {
                        id: backButton
                        // Align the centred label itself, rather than the larger hover target,
                        // with the other section headers at y=22.
                        y: 22 - Math.round((height - backLabel.implicitHeight) / 2)
                        width: backLabel.width + 20; height: 28
                        radius: PanelService.rounding
                        color: backMouse.containsMouse
                            ? Utils.alpha(Theme.base05, 0.07) : "transparent"
                        border.width: 0
                        ShellText {
                            id: backLabel
                            anchors.centerIn: parent
                            text: "←  PINNED"
                            font.bold: true
                            font.letterSpacing: 1
                            size: 11
                        }
                        MouseArea {
                            id: backMouse
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { root.allApps = false; root.currentIndex = 0; search.forceActiveFocus(); }
                        }
                    }
                    ShellText {
                        anchors { right: parent.right; verticalCenter: backButton.verticalCenter }
                        text: `${root.entries.length} APPLICATIONS`
                        color: Theme.base04; size: 11; font.letterSpacing: 1
                    }
                    ListView {
                        id: allAppsList
                        anchors { top: backButton.bottom; bottom: parent.bottom; left: parent.left; right: parent.right; topMargin: 12 }
                        model: root.entries
                        spacing: 2
                        clip: true
                        currentIndex: root.currentIndex
                        boundsBehavior: Flickable.StopAtBounds
                        maximumFlickVelocity: 12000

                        WheelHandler {
                            blocking: true
                            onWheel: event => root.scrollListByWheel(allAppsList, event)
                        }

                        delegate: Rectangle {
                            id: allApp
                            required property var modelData
                            required property int index
                            width: ListView.view.width; height: 50
                            radius: PanelService.rounding
                            color: allApp.ListView.isCurrentItem ? Utils.alpha(Theme.base05, 0.11) : "transparent"
                            Image {
                                id: allIcon
                                anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                                width: 28; height: 28
                                source: modelData.entry.icon ? Quickshell.iconPath(modelData.entry.icon, true) : ""
                                sourceSize.width: 48; sourceSize.height: 48
                                asynchronous: true; smooth: true
                            }
                            ShellText {
                                anchors {
                                    left: allIcon.right; right: parent.right
                                    leftMargin: 12; rightMargin: 12
                                    verticalCenter: parent.verticalCenter
                                }
                                text: modelData.entry.name; elide: Text.ElideRight; size: 13
                            }
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                cursorShape: Qt.PointingHandCursor
                                onEntered: root.currentIndex = allApp.index
                                onClicked: mouse => {
                                    if (mouse.button === Qt.RightButton)
                                        root.showPinMenu(allApp.modelData, allApp, mouse.x, mouse.y);
                                    else
                                        root.activate(allApp.modelData);
                                }
                            }
                        }
                    }
                }

                Item {
                    id: searchPage
                    anchors.fill: parent
                    visible: !root.keybindMode && search.text !== ""

                    Item {
                        id: resultColumn
                        anchors { top: parent.top; bottom: parent.bottom; left: parent.left }
                        width: parent.width * 0.49
                        ShellText {
                            id: resultTitle
                            y: 22
                            text: "BEST MATCH"
                            font.bold: true
                            font.letterSpacing: 1
                            size: 11
                        }
                        ListView {
                            id: searchResults
                            anchors { top: resultTitle.bottom; bottom: parent.bottom; left: parent.left; right: parent.right; topMargin: 10 }
                            model: root.results
                            spacing: 3
                            clip: true
                            currentIndex: root.currentIndex
                            boundsBehavior: Flickable.StopAtBounds
                            maximumFlickVelocity: 12000

                            WheelHandler {
                                blocking: true
                                onWheel: event => root.scrollListByWheel(searchResults, event)
                            }

                            delegate: Rectangle {
                                id: resultApp
                                required property var modelData
                                required property int index
                                width: ListView.view.width; height: 58
                                radius: PanelService.rounding
                                color: resultApp.ListView.isCurrentItem ? Utils.alpha(Theme.base05, 0.12) : "transparent"
                                Image {
                                    id: resultIcon
                                    anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                                    width: 30; height: 30
                                    source: modelData.entry.icon ? Quickshell.iconPath(modelData.entry.icon, true) : ""
                                    sourceSize.width: 48; sourceSize.height: 48
                                    asynchronous: true; smooth: true
                                }
                                ShellText {
                                    anchors {
                                        left: resultIcon.right; right: parent.right
                                        leftMargin: 11; rightMargin: 10
                                        verticalCenter: parent.verticalCenter
                                    }
                                    text: modelData.entry.name; elide: Text.ElideRight; size: 13
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: root.currentIndex = resultApp.index
                                    onClicked: mouse => {
                                        if (mouse.button === Qt.RightButton)
                                            root.showPinMenu(resultApp.modelData, resultApp, mouse.x, mouse.y);
                                        else
                                            root.activate(resultApp.modelData);
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        anchors {
                            top: parent.top; bottom: parent.bottom
                            left: resultColumn.right; right: parent.right
                            topMargin: 16; bottomMargin: 16; leftMargin: 16
                        }
                        color: Theme.base00
                        radius: PanelService.rounding
                        border.width: 1
                        border.color: PanelService.chromeBorderColor
                        visible: root.selectedItem !== null

                        Image {
                            id: detailIcon
                            anchors { top: parent.top; horizontalCenter: parent.horizontalCenter; topMargin: 54 }
                            width: 64; height: 64
                            source: root.selectedItem?.entry?.icon
                                ? Quickshell.iconPath(root.selectedItem.entry.icon, true) : ""
                            sourceSize.width: 96; sourceSize.height: 96
                            asynchronous: true; smooth: true
                        }
                        ShellText {
                            id: detailName
                            anchors { top: detailIcon.bottom; left: parent.left; right: parent.right; topMargin: 18; leftMargin: 18; rightMargin: 18 }
                            horizontalAlignment: Text.AlignHCenter
                            text: root.selectedItem?.entry?.name ?? ""
                            elide: Text.ElideRight
                            font.bold: true; size: 16
                        }
                        ShellText {
                            id: detailDescription
                            anchors { top: detailName.bottom; left: parent.left; right: parent.right; topMargin: 8; leftMargin: 24; rightMargin: 24 }
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.Wrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                            text: root.selectedItem?.entry?.comment
                                || root.selectedItem?.entry?.genericName || "Application"
                            color: Theme.base04; size: 11
                        }
                        ShellText {
                            id: detailMetadata
                            anchors {
                                top: detailDescription.bottom
                                left: parent.left; right: parent.right
                                topMargin: 12; leftMargin: 20; rightMargin: 20
                            }
                            horizontalAlignment: Text.AlignHCenter
                            text: root.categoryText(root.selectedItem)
                            visible: text !== ""
                            color: Theme.base04
                            elide: Text.ElideRight
                            size: 10
                        }

                        Column {
                            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 22 }
                            spacing: 8

                            Rectangle {
                                width: parent.width
                                height: 40
                                color: openMouse.containsMouse ? Utils.alpha(Theme.base05, 0.16) : Theme.base02
                                radius: PanelService.rounding
                                border.width: 1; border.color: PanelService.chromeBorderColor
                                ShellText { anchors.centerIn: parent; text: "OPEN  ↗"; font.bold: true; size: 12 }
                                MouseArea {
                                    id: openMouse
                                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: root.activate(root.selectedItem)
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: visible ? 36 : 0
                                visible: root.selectedItem !== null && !root.selectedItem.isFallback
                                    && !root.selectedItem.isSystemAction
                                color: detailPinMouse.containsMouse
                                    ? Utils.alpha(Theme.base05, 0.12) : "transparent"
                                radius: PanelService.rounding
                                border.width: 1
                                border.color: PanelService.chromeBorderColor
                                ShellText {
                                    anchors.centerIn: parent
                                    text: root.isPinned(root.selectedItem)
                                        ? "UNPIN FROM START" : "PIN TO START"
                                    size: 11
                                }
                                MouseArea {
                                    id: detailPinMouse
                                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: root.togglePinned(root.selectedItem)
                                }
                            }
                        }
                    }

                    ShellText {
                        anchors.centerIn: parent
                        visible: root.results.length === 0
                        text: root.entries.length === 0 ? "LOADING APPLICATIONS…" : "NO MATCHES"
                        color: Theme.base04; font.letterSpacing: 1; size: 12
                    }
                }

                Item {
                    anchors.fill: parent
                    visible: root.keybindMode

                    Item {
                        id: keybindResultColumn
                        anchors { top: parent.top; bottom: parent.bottom; left: parent.left }
                        width: parent.width * 0.49

                        ShellText {
                            id: keybindTitle
                            y: 22
                            text: "BEST MATCHES"
                            font.bold: true
                            font.letterSpacing: 1
                            size: 11
                        }

                        ListView {
                            id: keybindList
                            anchors {
                                top: keybindTitle.bottom; bottom: parent.bottom
                                left: parent.left; right: parent.right
                                topMargin: 10
                            }
                            model: root.keybindRows
                            spacing: 2
                            clip: true
                            currentIndex: root.currentIndex
                            boundsBehavior: Flickable.StopAtBounds
                            maximumFlickVelocity: 12000

                            WheelHandler {
                                blocking: true
                                onWheel: event => root.scrollListByWheel(keybindList, event)
                            }

                            delegate: Rectangle {
                                id: keybindRow
                                required property var modelData
                                required property int index
                                width: ListView.view.width
                                height: 58
                                radius: PanelService.rounding
                                color: keybindRow.ListView.isCurrentItem
                                    ? Utils.alpha(Theme.base05, 0.11) : "transparent"

                                ShellText {
                                    anchors {
                                        top: parent.top; left: parent.left; right: parent.right
                                        topMargin: 9; leftMargin: 12; rightMargin: 12
                                    }
                                    text: keybindRow.modelData.chord
                                    elide: Text.ElideRight
                                    size: 12
                                }
                                ShellText {
                                    anchors {
                                        bottom: parent.bottom; left: parent.left; right: parent.right
                                        bottomMargin: 9; leftMargin: 12; rightMargin: 12
                                    }
                                    text: keybindRow.modelData.description
                                    color: Theme.base04
                                    elide: Text.ElideRight
                                    size: 10
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onEntered: root.currentIndex = keybindRow.index
                                }
                            }
                        }
                    }

                    Rectangle {
                        anchors {
                            top: parent.top; bottom: parent.bottom
                            left: keybindResultColumn.right; right: parent.right
                            topMargin: 16; bottomMargin: 16; leftMargin: 16
                        }
                        visible: root.selectedKeybind !== null
                        color: Theme.base00
                        radius: PanelService.rounding
                        border.width: 1
                        border.color: PanelService.chromeBorderColor

                        ShellText {
                            id: keybindSummaryIcon
                            anchors { top: parent.top; horizontalCenter: parent.horizontalCenter; topMargin: 54 }
                            text: root.keybindType(root.selectedKeybind) === "Mouse" ? "󰍽"
                                : (root.keybindType(root.selectedKeybind) === "Switch" ? "󰜎" : "󰌌")
                            size: 42
                        }
                        ShellText {
                            id: keybindSummaryChord
                            anchors {
                                top: keybindSummaryIcon.bottom
                                left: parent.left; right: parent.right
                                topMargin: 18; leftMargin: 20; rightMargin: 20
                            }
                            horizontalAlignment: Text.AlignHCenter
                            text: root.selectedKeybind?.chord ?? ""
                            elide: Text.ElideRight
                            font.bold: true
                            size: 15
                        }
                        ShellText {
                            id: keybindSummaryDescription
                            anchors {
                                top: keybindSummaryChord.bottom
                                left: parent.left; right: parent.right
                                topMargin: 10; leftMargin: 24; rightMargin: 24
                            }
                            horizontalAlignment: Text.AlignHCenter
                            text: root.selectedKeybind?.description ?? ""
                            color: Theme.base04
                            wrapMode: Text.Wrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                            size: 11
                        }

                        ShellText {
                            id: keybindSummaryOptions
                            anchors {
                                top: keybindSummaryDescription.bottom
                                left: parent.left; right: parent.right
                                topMargin: 10; leftMargin: 24; rightMargin: 24
                            }
                            horizontalAlignment: Text.AlignHCenter
                            text: root.keybindOptions(root.selectedKeybind)
                            color: Theme.base04
                            wrapMode: Text.Wrap
                            size: 10
                        }

                        Column {
                            anchors {
                                top: keybindSummaryOptions.bottom
                                left: parent.left; right: parent.right
                                topMargin: 34; leftMargin: 24; rightMargin: 24
                            }
                            spacing: 16

                            Repeater {
                                model: [
                                    { label: "TYPE", value: root.keybindType(root.selectedKeybind) },
                                    { label: "TRIGGER", value: root.keybindTrigger(root.selectedKeybind) },
                                    { label: "MODIFIERS", value: root.modifierText(root.selectedKeybind) },
                                    { label: "KEY", value: root.keyName(String(root.selectedKeybind?.key ?? "")) }
                                ]
                                delegate: Item {
                                    required property var modelData
                                    width: parent.width
                                    height: 28
                                    ShellText {
                                        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                                        text: modelData.label
                                        color: Theme.base04
                                        font.bold: true
                                        font.letterSpacing: 1
                                        size: 9
                                    }
                                    ShellText {
                                        anchors {
                                            left: parent.left; right: parent.right
                                            leftMargin: 86; verticalCenter: parent.verticalCenter
                                        }
                                        text: modelData.value
                                        horizontalAlignment: Text.AlignRight
                                        elide: Text.ElideRight
                                        size: 11
                                    }
                                }
                            }
                        }
                    }

                    ShellText {
                        anchors.centerIn: parent
                        visible: root.bindsLoadError !== ""
                        text: root.bindsLoadError
                        color: Theme.base04
                        size: 12
                    }
                }
            }

            Rectangle {
                id: footer
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 58
                color: Theme.base00
                border.width: 0

                Rectangle {
                    anchors { left: parent.left; leftMargin: 28; verticalCenter: parent.verticalCenter }
                    width: 30; height: 30; radius: 15
                    color: Theme.base02
                    ShellText { anchors.centerIn: parent; text: "󰀄"; size: 14 }
                }
                ShellText {
                    anchors { left: parent.left; leftMargin: 70; verticalCenter: parent.verticalCenter }
                    text: Quickshell.env("USER") || "user"; size: 12
                }
                Rectangle {
                    anchors { right: parent.right; rightMargin: 24; verticalCenter: parent.verticalCenter }
                    width: 34; height: 34; radius: PanelService.rounding
                    color: powerMouse.containsMouse || root.powerMenuOpen ? Utils.alpha(Theme.base05, 0.12) : "transparent"
                    ShellText { anchors.centerIn: parent; text: "󰐥"; size: 16 }
                    MouseArea {
                        id: powerMouse
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: root.powerMenuOpen = !root.powerMenuOpen
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                visible: root.powerMenuOpen
                z: 19
                onClicked: root.powerMenuOpen = false
            }

            Rectangle {
                anchors { right: parent.right; bottom: footer.top; rightMargin: 24; bottomMargin: 6 }
                width: 170; height: 198
                visible: root.powerMenuOpen
                color: Theme.base01
                border.width: 1; border.color: PanelService.chromeBorderColor
                radius: PanelService.rounding
                z: 20
                Column {
                    anchors.fill: parent; anchors.margins: 5; spacing: 2
                    Repeater {
                        model: [
                            { icon: "󰌾", label: "Lock", command: ["qs", "ipc", "call", "lock", "activate"] },
                            { icon: "󰒲", label: "Sleep", command: ["systemctl", "suspend"] },
                            { icon: "󰤄", label: "Hibernate", command: ["systemctl", "hibernate"] },
                            { icon: "󰜉", label: "Restart", command: ["systemctl", "reboot"] },
                            { icon: "󰐥", label: "Shut down", command: ["systemctl", "poweroff"] }
                        ]
                        delegate: Rectangle {
                            id: powerAction
                            required property var modelData
                            width: parent.width; height: 36; radius: PanelService.rounding
                            color: actionMouse.containsMouse ? Utils.alpha(Theme.base05, 0.11) : "transparent"
                            ShellText {
                                anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                                text: modelData.icon; size: 13
                            }
                            ShellText {
                                anchors { left: parent.left; leftMargin: 38; verticalCenter: parent.verticalCenter }
                                text: modelData.label; size: 12
                            }
                            MouseArea {
                                id: actionMouse
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { root.open = false; Quickshell.execDetached(modelData.command); }
                            }
                        }
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                visible: root.pinMenuOpen
                z: 29
                onClicked: root.pinMenuOpen = false
            }

            Rectangle {
                x: root.pinMenuX
                y: root.pinMenuY
                width: 180
                height: 44
                visible: root.pinMenuOpen && root.pinMenuItem !== null
                color: Theme.base01
                border.width: 1
                border.color: PanelService.chromeBorderColor
                radius: PanelService.rounding
                z: 30

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 4
                    radius: PanelService.rounding
                    color: contextPinMouse.containsMouse
                        ? Utils.alpha(Theme.base05, 0.11) : "transparent"
                    ShellText {
                        anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                        text: root.isPinned(root.pinMenuItem) ? "󰤱" : "󰐃"
                        size: 13
                    }
                    ShellText {
                        anchors {
                            left: parent.left; right: parent.right
                            leftMargin: 40; rightMargin: 12
                            verticalCenter: parent.verticalCenter
                        }
                        text: root.isPinned(root.pinMenuItem)
                            ? "Unpin from Start" : "Pin to Start"
                        elide: Text.ElideRight
                        size: 11
                    }
                    MouseArea {
                        id: contextPinMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.togglePinned(root.pinMenuItem);
                            root.pinMenuOpen = false;
                        }
                    }
                }
            }

            // Keep the outer chrome above edge-to-edge children such as the footer,
            // so every side of the launcher remains visible.
            Rectangle {
                anchors.fill: parent
                color: "transparent"
                border.width: PanelService.chromeBorderWidth
                border.color: PanelService.chromeBorderColor
                radius: parent.radius
                enabled: false
                z: 100
            }
        }
    }
}
