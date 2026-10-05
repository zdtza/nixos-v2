pragma Singleton

// Application list, recently-launched tracking and app launching shared by every launcher panel.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import ".."

Item {
    id: root

    property var terminal: ["kitty"]
    // Number of most recently launched apps pulled out of the full list into RECENT.
    readonly property int recentCount: 3

    // Last launch time (ms since epoch) keyed by desktop entry id.
    property var lastLaunched: ({})

    // Launches in flight, keyed by desktop entry id. Each lasts until its window
    // appears or takes focus: { keys, baselineAddresses, baselineActiveAddress, startedAt }.
    property var launches: ({})
    // The bar's launcher icon shows a spinner while anything is launching.
    readonly property bool launching: Object.keys(launches).length > 0
    readonly property int launchTimeout: 15000

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

    // Most recently launched first.
    readonly property var recentEntries: entries
        .filter(item => (lastLaunched[item.entry.id] ?? 0) > 0)
        .sort((a, b) => lastLaunched[b.entry.id] - lastLaunched[a.entry.id])
        .slice(0, recentCount)
    readonly property var remainingEntries: entries.filter(item => !recentEntries.includes(item))

    function matchTier(item: var, token: string): int {
        if (item.name.startsWith(token)) return 0;
        if (item.name.includes(token)) return 1;
        if (Utils.fuzzyMatches(item.name, token)) return 2;
        if (item.categories.includes(token)) return 3;
        if (item.description.includes(token)) return 3;
        return -1;
    }

    // Short uppercase label for the right-hand side of a launcher row.
    function categoryLabel(entry: var): string {
        const labels = {
            Development: "DEV", Office: "OFFICE", Game: "GAMES", Graphics: "GRAPHICS",
            Audio: "AUDIO", AudioVideo: "AUDIO", Video: "VIDEO", Science: "SCIENCE",
            Education: "EDU", Security: "SECURITY", Settings: "SETTINGS", System: "SYSTEM",
            Network: "NETWORK", Utility: "UTILITY"
        };
        // Most specific labels first, so an editor tagged Utility reads as DEV.
        const categories = Array.from(entry?.categories ?? []);
        for (const category of Object.keys(labels)) {
            if (categories.includes(category))
                return labels[category];
        }
        return "APP";
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

    function recordLaunch(entry: DesktopEntry): void {
        const next = Object.assign({}, root.lastLaunched);
        next[entry.id] = Date.now();
        root.lastLaunched = next;
        recentFile.setText(JSON.stringify(next));
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

    function beginLaunchTracking(entry: DesktopEntry): void {
        const addresses = {};
        for (const toplevel of Hyprland.toplevels.values)
            addresses[root.normalizedAddress(toplevel.address)] = true;
        const next = Object.assign({}, root.launches);
        next[entry.id] = {
            keys: [entry.id, entry.name, entry.startupClass]
                .map(root.normalizedIdentifier).filter(key => key !== ""),
            baselineAddresses: addresses,
            baselineActiveAddress: root.normalizedAddress(Hyprland.activeToplevel?.address),
            startedAt: Date.now()
        };
        root.launches = next;
    }

    function finishLaunchTracking(id: string): void {
        if (!root.isLaunching(id))
            return;
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

    function launchDetached(command: var, workingDirectory: string): void {
        const cwd = workingDirectory || Quickshell.env("HOME");
        const line = `cd ${root.shellQuote([cwd])} && exec ${root.shellQuote(["uwsm", "app", "--", ...command])}`;
        Quickshell.execDetached(["hyprctl", "dispatch",
            `hl.dsp.exec_cmd("${line.replace(/[\\"]/g, "\\$&")}")`]);
    }

    function launch(entry: DesktopEntry): void {
        if (!entry)
            return;
        root.recordLaunch(entry);
        root.beginLaunchTracking(entry);
        root.launchDetached(entry.runInTerminal
            ? [...root.terminal, "--class", entry.id, "--", ...entry.command]
            : entry.command, entry.workingDirectory);
    }

    FileView {
        id: recentFile
        path: Quickshell.statePath("launcher-last-launched.json")
        preload: true
        atomicWrites: true
        printErrors: false
        onLoaded: {
            try {
                root.lastLaunched = JSON.parse(text());
            } catch (error) {
                root.lastLaunched = ({});
            }
        }
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
                    // Window class unlike its desktop entry: credit it to the only
                    // launch in flight, as there is no ambiguity.
                    const pending = Object.keys(root.launches)
                        .filter(id => !root.launches[id].baselineAddresses[address]);
                    if (pending.length === 1 && Object.keys(root.launches).length === 1)
                        root.finishLaunchTracking(pending[0]);
                }
            } else if (event.name === "activewindowv2") {
                const address = root.normalizedAddress(event.data);
                if (address === "")
                    return;
                // A single-instance app may just focus its existing window. Other
                // focus changes (e.g. switching workspace) are not the launch.
                for (const id of root.launchesMatching(root.windowKeys(address, ""))) {
                    if (address !== root.launches[id].baselineActiveAddress)
                        root.finishLaunchTracking(id);
                }
            }
        }
    }

    // Apps that never open a window (daemons, URL handlers) must not spin forever.
    Timer {
        interval: 1000
        repeat: true
        running: root.launching
        onTriggered: {
            const now = Date.now();
            for (const id of Object.keys(root.launches)) {
                if (now - root.launches[id].startedAt > root.launchTimeout)
                    root.finishLaunchTracking(id);
            }
        }
    }
}
