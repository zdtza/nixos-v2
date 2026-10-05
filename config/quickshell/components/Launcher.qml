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
    property bool keybindMode: false
    property var binds: []
    property string bindsLoadError: ""
    property bool powerMenuOpen: false
    property string openedMonitorName: ""
    property int currentIndex: 0
    // Ignore hover selection until the pointer genuinely moves. This prevents
    // freshly filtered rows under a stationary cursor from replacing index 0.
    property bool hoverSelectReady: false
    property var hoverArmPosition: null
    property string pendingLaunchName: ""
    property string pendingLaunchIcon: "application-x-executable"
    property string launchBaselineActiveAddress: ""
    property var launchBaselineAddresses: ({})

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
        root.keybindMode = true;
        root.currentIndex = 0;
        search.text = "";
        if (root.binds.length === 0 && !bindsProcess.running)
            bindsProcess.running = true;
        search.focusInput();
    }

    readonly property var results: {
        const tokens = search.text.toLowerCase().split(" ").filter(token => token !== "");
        if (tokens.length === 0)
            return root.entries;
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
            || a.item.entry.name.localeCompare(b.item.entry.name)).map(match => match.item);
        return found.length > 0 || root.entries.length === 0 ? found : root.fallbackResults();
    }

    readonly property var activeModel: root.keybindMode ? root.keybindRows : root.results
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

    function resetHoverSelect(): void {
        root.hoverSelectReady = false;
        root.hoverArmPosition = null;
    }

    function armHoverSelect(x: real, y: real): void {
        if (root.hoverArmPosition === null)
            root.hoverArmPosition = Qt.point(x, y);
        else if (x !== root.hoverArmPosition.x || y !== root.hoverArmPosition.y)
            root.hoverSelectReady = true;
    }

    function show(): void {
        root.openedMonitorName = String(Hyprland.focusedMonitor?.name ?? "");
        PanelService.closeActive();
        root.keybindMode = false;
        root.powerMenuOpen = false;
        root.currentIndex = 0;
        root.open = true;
    }

    function toggle(): void {
        if (root.open)
            root.open = false;
        else
            root.show();
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
        else
            searchResults.positionViewAtIndex(root.currentIndex, ListView.Contain);
    }

    onOpenChanged: {
        root.resetHoverSelect();
        search.text = "";
        root.currentIndex = 0;
        if (root.open) {
            Qt.callLater(() => {
                if (root.open)
                    searchResults.positionViewAtBeginning();
            });
            search.focusInput();
        }
    }
    onActiveModelChanged: {
        root.resetHoverSelect();
        root.currentIndex = root.activeModel.length > 0 ? 0 : -1;
    }

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
                horizontalCenter: parent.horizontalCenter
                top: PanelService.barAtTop ? parent.top : undefined
                bottom: PanelService.barAtTop ? undefined : parent.bottom
                topMargin: PanelService.barAtTop
                    ? PanelService.panelBarInset + PanelService.panelGap : 0
                bottomMargin: PanelService.barAtTop
                    ? 0 : PanelService.panelBarInset + PanelService.panelGap
            }
            width: Math.min(640, parent.width - PanelService.panelGap * 2)
            height: Math.min(695, parent.height - PanelService.panelBarInset
                - PanelService.panelGap * 2)
            color: Theme.base01
            // The overlay border at the end of this component is the single
            // source of outer chrome, avoiding doubled edges beside transparent content.
            border.width: 0
            border.color: PanelService.chromeBorderColor
            radius: 0
            clip: true
            enabled: root.open
            opacity: root.open ? 1 : 0

            HoverHandler {
                enabled: root.open && !root.hoverSelectReady
                acceptedDevices: PointerDevice.AllDevices
                onPointChanged: root.armHoverSelect(point.position.x, point.position.y)
            }

            MouseArea {
                anchors.fill: parent
                onPressed: mouse => mouse.accepted = true
            }

            Rectangle {
                id: header
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: footer.height
                color: Theme.base00

                LauncherSearchBox {
                    id: search
                    anchors {
                        left: parent.left; right: parent.right
                        leftMargin: 28; rightMargin: 29
                        verticalCenter: parent.verticalCenter
                    }
                    launcher: root
                }
            }

            Item {
                anchors {
                    top: header.bottom; bottom: footer.top
                    left: parent.left; right: parent.right
                    topMargin: 0; leftMargin: 28; rightMargin: 29; bottomMargin: 0
                }

                Item {
                    anchors.fill: parent
                    visible: !root.keybindMode

                    Item {
                        id: resultColumn
                        anchors { top: parent.top; bottom: parent.bottom; left: parent.left }
                        width: parent.width * 0.49
                        LauncherAppList {
                            id: searchResults
                            anchors { top: parent.top; bottom: parent.bottom; left: parent.left; right: parent.right }
                            launcher: root
                            model: root.results
                            spacing: 3
                            rowHeight: 58
                            iconSize: 30
                            iconLeftMargin: 10
                            textLeftMargin: 11
                            textRightMargin: 10
                            selectedColor: Utils.alpha(Theme.base05, 0.12)
                        }
                    }

                    LauncherAppDetails {
                        anchors {
                            top: parent.top; bottom: parent.bottom
                            left: resultColumn.right; right: parent.right
                            topMargin: 16; bottomMargin: 16; leftMargin: 16
                        }
                        launcher: root
                    }

                    ShellText {
                        anchors.centerIn: parent
                        visible: root.results.length === 0
                        text: root.entries.length === 0 ? "LOADING APPLICATIONS…" : "NO MATCHES"
                        color: Theme.textSecondary; font.letterSpacing: 1; size: 12
                    }
                }

                Item {
                    anchors.fill: parent
                    visible: root.keybindMode

                    Item {
                        id: keybindResultColumn
                        anchors { top: parent.top; bottom: parent.bottom; left: parent.left }
                        width: parent.width * 0.49

                        LauncherKeybindList {
                            id: keybindList
                            anchors {
                                top: parent.top; bottom: parent.bottom
                                left: parent.left; right: parent.right
                            }
                            launcher: root
                        }
                    }

                    LauncherKeybindDetails {
                        anchors {
                            top: parent.top; bottom: parent.bottom
                            left: keybindResultColumn.right; right: parent.right
                            topMargin: 16; bottomMargin: 16; leftMargin: 16
                        }
                        launcher: root
                    }

                    ShellText {
                        anchors.centerIn: parent
                        visible: root.bindsLoadError !== ""
                        text: root.bindsLoadError
                        color: Theme.textSecondary
                        size: 12
                    }
                }
            }

            LauncherFooter {
                id: footer
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                launcher: root
            }

            MouseArea {
                anchors.fill: parent
                visible: root.powerMenuOpen
                z: 19
                onClicked: root.powerMenuOpen = false
            }

            LauncherPowerMenu {
                anchors { right: parent.right; bottom: footer.top; rightMargin: 24; bottomMargin: 6 }
                launcher: root
                z: 20
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
