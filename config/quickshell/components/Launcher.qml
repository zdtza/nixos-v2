pragma ComponentBehavior: Bound

// Spotlight-style application search matching the shell's compact panel language.
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "../services"
import ".."

Scope {
    id: root

    property var terminal: ["kitty"]
    property string pendingLaunchName: ""
    property string pendingLaunchIcon: "application-x-executable"
    property string launchBaselineActiveAddress: ""
    property var launchBaselineAddresses: ({})

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

    function matchTier(item: var, token: string): int {
        if (item.name.startsWith(token)) return 0;
        if (item.name.includes(token)) return 1;
        if (Utils.fuzzyMatches(item.name, token)) return 2;
        if (item.description.includes(token)) return 3;
        return -1;
    }

    readonly property var results: {
        const tokens = panel.query.toLowerCase().split(" ").filter(token => token !== "");
        // Open on the complete alphabetical application list; typing narrows
        // the same list in place instead of expanding an initially empty card.
        if (tokens.length === 0)
            return root.entries;

        const matches = [];
        for (const item of root.entries) {
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
        const found = matches.sort((a, b) => a.tier - b.tier).map(match => match.item);
        // No installed app matches -- offer to search the web / NixOS
        // packages for the typed term instead of a dead-end empty list.
        // Skipped while apps are still loading so this can't flash before
        // real matches have a chance to appear.
        if (found.length === 0 && root.entries.length > 0)
            return root.fallbackResults();
        return found;
    }

    function fallbackResults(): var {
        const term = panel.query;
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

    // Spawned through Hyprland's exec dispatcher rather than directly: only
    // that path hands the child an HL_INITIAL_WORKSPACE_TOKEN, which pins the
    // first window to the workspace that was active at launch time, however
    // long the app takes to map (misc:initial_workspace_tracking in
    // config/hypr/hyprland.lua). A direct execDetached has no token, so slow
    // apps land on whatever workspace is focused when they finally show up.
    //
    // `hyprctl dispatch` takes Lua now, not `exec <cmd>`; the shell line has
    // to be embedded as a Lua string literal.
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
            ? [...root.terminal, "--", ...entry.command]
            : entry.command, entry.workingDirectory);
        panel.open = false;
    }

    // Fallback rows (web/NixOS search) aren't desktop entries -- no
    // window to track, just fire and forget the browser command.
    function activate(item: var): void {
        if (!item)
            return;
        if (item.isFallback) {
            root.launchDetached(item.command, "");
            panel.open = false;
        } else {
            root.launch(item.entry);
        }
    }

    // Hyprland dispatches this in-process through its global-shortcut protocol.
    // Unlike `qs ipc call`, no Qt client process is started for each key press.
    GlobalShortcut {
        appid: "quickshell"
        name: "launcher"
        description: "Toggle application launcher"
        triggerDescription: "Super+Space"
        onPressed: panel.toggle()
    }

    // Keep IPC for scripts and manual control; the keyboard bind uses the
    // GlobalShortcut above.
    IpcHandler {
        target: "launcher"

        function toggle(): void { panel.toggle(); }
        function open(): void { panel.show(); }
        function close(): void { panel.open = false; }
        function isOpen(): bool { return panel.open; }
    }

    Connections {
        target: Hyprland

        function onRawEvent(event: var): void {
            if (event.name === "openwindow") {
                const address = root.normalizedAddress(event.data.split(",")[0]);
                if (root.launchBaselineAddresses[address])
                    return;
                root.finishLaunchTracking();
            } else if (event.name === "activewindowv2" && root.pendingLaunchName !== "") {
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

    SearchPanel {
        id: panel

        layerNamespace: "quickshell:launcher"
        placeholder: "Search for apps…"
        frameWidth: 440
        model: root.results
        expanded: root.results.length > 0 || root.entries.length === 0
        onAccepted: root.activate(root.results[panel.currentIndex])

        delegate: Rectangle {
            id: appRow

            required property var modelData
            required property int index
            readonly property var entry: modelData.entry

            width: ListView.view.width
            height: panel.rowHeight
            radius: PanelService.rounding
            // A quiet fill is enough to locate the keyboard cursor; an
            // outline made the compact rows read like individual buttons.
            color: appRow.ListView.isCurrentItem
                ? Utils.alpha(Theme.base05, 0.10) : "transparent"

            Item {
                id: iconFrame
                anchors {
                    left: parent.left
                    leftMargin: 10
                    verticalCenter: parent.verticalCenter
                }
                width: 28
                height: 28

                ShellText {
                    anchors.centerIn: parent
                    visible: applicationIcon.status === Image.Loading
                    text: "…"
                    color: Theme.base04
                    size: 14
                }

                Image {
                    anchors.centerIn: parent
                    width: 24
                    height: 24
                    visible: applicationIcon.status === Image.Error
                        || applicationIcon.status === Image.Null
                    source: "file://" + Quickshell.env("QS_FALLBACK_APP_ICON")
                    sourceSize.width: 48
                    sourceSize.height: 48
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
                    anchors.centerIn: parent
                    width: 24
                    height: 24
                    source: appRow.entry.icon ? Quickshell.iconPath(appRow.entry.icon, true) : ""
                    sourceSize.width: 48
                    sourceSize.height: 48
                    cache: true
                    asynchronous: true
                    smooth: true
                    visible: status === Image.Ready
                }
            }

            ShellText {
                anchors {
                    left: iconFrame.right
                    right: parent.right
                    leftMargin: 10
                    rightMargin: 12
                    verticalCenter: parent.verticalCenter
                }
                text: appRow.entry.name
                elide: Text.ElideRight
                size: 14
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onContainsMouseChanged: if (containsMouse && panel.hoverSelectReady)
                    panel.currentIndex = appRow.index
                onClicked: {
                    panel.currentIndex = appRow.index;
                    root.activate(appRow.modelData);
                }
            }
        }

        // Desktop entries load asynchronously; without this, opening the
        // launcher before they arrive briefly shows "no matching
        // applications" instead of a loading state.
        Column {
            anchors.centerIn: parent
            visible: root.entries.length === 0
            spacing: 10

            ShellText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "…"
                color: Theme.base04
                size: 28
            }

            ShellText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "LOADING APPLICATIONS"
                color: Theme.base04
                size: 11
                font.bold: true
                font.letterSpacing: 1
            }
        }
    }
}
