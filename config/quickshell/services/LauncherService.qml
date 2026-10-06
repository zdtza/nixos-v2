pragma Singleton

// Application list and app launching shared by every launcher panel.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import ".."

Item {
    id: root

    property var terminal: ["kitty"]
    // Launches in flight, keyed by desktop entry id. Each lasts until its window
    // appears: { keys, tag, classes, icon, workspace, monitor, baselineAddresses, startedAt }.
    property var launches: ({})
    readonly property bool launching: Object.keys(launches).length > 0
    readonly property int launchTimeout: 60000
    // Hyprland tags each launch's window with `qslaunch-<serial>`, identifying it
    // even when its class looks nothing like the desktop entry.
    property int launchSerial: 0
    // Shared by every launch spinner (launcher rows, workspace slots) so they turn in step.
    property real spinnerAngle: 0

    NumberAnimation on spinnerAngle {
        running: root.launching
        from: 0
        to: 360
        duration: 900
        loops: Animation.Infinite
    }

    // In-flight launches opening on a workspace, oldest first.
    function launchesOn(workspaceId: int): var {
        return Object.values(root.launches)
            .filter(launch => launch.workspace === workspaceId)
            .sort((a, b) => a.startedAt - b.startedAt);
    }

    function isLaunching(id: string): bool {
        return launches[id] !== undefined;
    }

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

    function fallbackResults(term: string): var {
        return [
            {
                isFallback: true,
                entry: { name: "Search the web", icon: "firefox",
                    comment: `Find “${term}” with Google` },
                command: ["firefox", `https://www.google.com/search?q=${encodeURIComponent(term)}`]
            },
            {
                isFallback: true,
                entry: { name: "Search packages", icon: "nix-snowflake",
                    comment: `Find a package named “${term}”` },
                command: ["firefox", `https://search.nixos.org/packages?channel=unstable&query=${encodeURIComponent(term)}`]
            }
        ];
    }

    function normalizedAddress(address: var): string {
        return String(address ?? "").replace(/^0x/, "");
    }

    function normalizedIdentifier(value: var): string {
        return String(value ?? "").toLowerCase().replace(/[^a-z0-9]/g, "");
    }

    function windowKeys(address: string, extraClass: var): var {
        const toplevel = Hyprland.toplevels.values
            .find(candidate => root.normalizedAddress(candidate.address) === address);
        const ipc = toplevel?.lastIpcObject ?? {};
        return [extraClass, ipc.class, ipc.initialClass, toplevel?.wayland?.appId]
            .map(root.normalizedIdentifier).filter(key => key !== "");
    }

    function beginLaunchTracking(entry: DesktopEntry, tag: string, workspace: int): void {
        const addresses = {};
        for (const toplevel of Hyprland.toplevels.values)
            addresses[root.normalizedAddress(toplevel.address)] = true;
        const next = Object.assign({}, root.launches);
        // The executable's name also counts, as web apps (e.g. `firefox --new-tab`)
        // open in a window classed after their browser rather than the entry.
        const executable = String(entry.command[0] ?? "").split("/").pop();
        const classes = [entry.startupClass, entry.id, executable]
            .map(value => String(value ?? "")).filter(value => value !== "");
        if (workspace > 0 && classes.length > 0)
            root.setPlacementRule(entry.id, classes, workspace);
        next[entry.id] = {
            keys: [entry.id, entry.name, entry.startupClass, executable]
                .map(root.normalizedIdentifier).filter(key => key !== ""),
            tag,
            classes: workspace > 0 ? classes : [],
            icon: String(entry.icon ?? ""),
            workspace,
            monitor: String(Hyprland.focusedMonitor?.name ?? ""),
            baselineAddresses: addresses,
            startedAt: Date.now()
        };
        root.launches = next;
    }

    // Browsers and Electron apps (Firefox, Chromium, VS Code) hand a launch to an
    // already running or re-executed process, so their window escapes the exec
    // rule. A temporary rule matching the app's window class places it on the
    // launch's workspace as it maps. Rules can only be disabled, not removed, so
    // each entry reuses one rule name, which redeclaring replaces.
    function placementRuleName(id: string): string {
        return `qslaunch-${id.replace(/[^A-Za-z0-9_-]/g, "_")}`;
    }

    // Placement rules outlive their launch briefly, as apps request activation
    // just after mapping: { [id]: { classes, at } }.
    property var ruleDisables: ({})
    readonly property int ruleGrace: 3000

    function setPlacementRule(id: string, classes: var, workspace: int): void {
        if (root.ruleDisables[id]) {
            const next = Object.assign({}, root.ruleDisables);
            delete next[id];
            root.ruleDisables = next;
        }
        const pattern = `(?i)^(${classes.map(value =>
            value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")).join("|")})$`;
        // Refusing activation keeps an app that asks for focus as it opens
        // (Firefox) from pulling the view over to it.
        const spec = workspace > 0
            ? `workspace = "${workspace} silent", focus_on_activate = false` : "enabled = false";
        Quickshell.execDetached(["hyprctl", "eval",
            `hl.window_rule({ name = "${root.placementRuleName(id)}", ${spec}, match = { class = [==[${pattern}]==] } })`]);
    }

    function finishLaunchTracking(id: string): void {
        if (!root.isLaunching(id))
            return;
        if (root.launches[id].classes.length > 0) {
            const disables = Object.assign({}, root.ruleDisables);
            disables[id] = { classes: root.launches[id].classes, at: Date.now() + root.ruleGrace };
            root.ruleDisables = disables;
        }
        const next = Object.assign({}, root.launches);
        delete next[id];
        root.launches = next;
    }

    // Launch ids whose app owns the window with these identifiers.
    function launchesMatching(keys: var): var {
        return Object.keys(root.launches)
            .filter(id => root.launches[id].keys.some(key => keys.includes(key)));
    }

    function shellQuote(args: var): string {
        return args.map(arg => "'" + String(arg).replace(/'/g, "'\\''") + "'").join(" ");
    }

    // Workspace a launch made now opens on; 0 for special workspaces (negative
    // ids), which are left to Hyprland.
    function launchWorkspace(): int {
        const workspace = Number(Hyprland.focusedWorkspace?.id ?? 0);
        return workspace > 0 ? workspace : 0;
    }

    function launchDetached(command: var, workingDirectory: string, tag: string): void {
        const cwd = workingDirectory || Quickshell.env("HOME");
        const line = `cd ${root.shellQuote([cwd])} && exec ${root.shellQuote(["uwsm", "app", "--", ...command])}`;
        // Open the new window on the workspace it was requested from, even if
        // focus has moved on by the time it maps, without switching back to it.
        const rules = [];
        const workspace = root.launchWorkspace();
        if (workspace > 0)
            rules.push(`workspace = "${workspace} silent"`);
        if (tag)
            rules.push(`tag = "+${tag}"`);
        const ruleTable = rules.length > 0 ? `, { ${rules.join(", ")} }` : "";
        Quickshell.execDetached(["hyprctl", "dispatch",
            `hl.dsp.exec_cmd("${line.replace(/[\\"]/g, "\\$&")}"${ruleTable})`]);
    }

    function launch(entry: DesktopEntry): void {
        if (!entry)
            return;
        const tag = `qslaunch-${++root.launchSerial}`;
        root.beginLaunchTracking(entry, tag, root.launchWorkspace());
        root.launchDetached(entry.runInTerminal
            ? [...root.terminal, "--class", entry.id, "--", ...entry.command]
            : entry.command, entry.workingDirectory, tag);
    }

    Connections {
        target: Hyprland
        function onRawEvent(event: var): void {
            if (!root.launching)
                return;
            if (event.name === "openwindow") {
                const fields = event.data.split(",");
                const address = root.normalizedAddress(fields[0]);
                const matching = root.launchesMatching(root.windowKeys(address, fields[2]));
                if (matching.length > 0) {
                    matching.forEach(id => root.finishLaunchTracking(id));
                } else {
                    // Window class unlike its desktop entry: look for its launch tag.
                    root.unmatchedAddress = address;
                    clientsQuery.running = true;
                }
            } else if (event.name === "activewindowv2") {
                // A single-instance app answers by raising its window from before
                // the launch (focus_on_activate). Focus moving to a window the
                // launch opened is irrelevant; that window's opening ended it.
                const address = root.normalizedAddress(event.data);
                for (const id of root.launchesMatching(root.windowKeys(address, ""))) {
                    if (root.launches[id].baselineAddresses[address])
                        root.finishLaunchTracking(id);
                }
            } else if (event.name === "windowtitlev2") {
                // An already focused browser opening a web app in a new tab neither
                // opens nor focuses a window; only its title changes.
                const address = root.normalizedAddress(event.data.split(",")[0]);
                for (const id of root.launchesMatching(root.windowKeys(address, "")))
                    root.finishLaunchTracking(id);
            }
        }
    }

    // Most recent opened window no launch claimed by class, for the tag fallback.
    property string unmatchedAddress: ""

    Process {
        id: clientsQuery
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                let clients = [];
                try {
                    clients = JSON.parse(text);
                } catch (error) {
                    return;
                }
                // QML's JS engine has no Array.prototype.flatMap.
                const tags = new Set([].concat(...clients.map(client => client.tags ?? []))
                    .map(tag => String(tag).replace(/\*$/, "")));
                const claimed = Object.keys(root.launches)
                    .filter(id => tags.has(root.launches[id].tag));
                claimed.forEach(id => root.finishLaunchTracking(id));
                // Untagged (e.g. handed to an already running process) and no
                // ambiguity: credit it to the only launch in flight.
                const ids = Object.keys(root.launches);
                if (claimed.length === 0 && ids.length === 1
                    && !root.launches[ids[0]].baselineAddresses[root.unmatchedAddress])
                    root.finishLaunchTracking(ids[0]);
            }
        }
    }

    // Apps that never open a window (daemons, URL handlers) must not spin forever.
    Timer {
        interval: 1000
        repeat: true
        running: root.launching || Object.keys(root.ruleDisables).length > 0
        onTriggered: {
            const now = Date.now();
            for (const id of Object.keys(root.launches)) {
                if (now - root.launches[id].startedAt > root.launchTimeout)
                    root.finishLaunchTracking(id);
            }
            const expired = Object.keys(root.ruleDisables)
                .filter(id => now >= root.ruleDisables[id].at);
            if (expired.length === 0)
                return;
            const next = Object.assign({}, root.ruleDisables);
            for (const id of expired) {
                root.setPlacementRule(id, next[id].classes, 0);
                delete next[id];
            }
            root.ruleDisables = next;
        }
    }
}
