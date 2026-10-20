pragma Singleton

// Monitors currently being captured by any portal screencast: recordings, and
// screen sharing from Teams, browsers and the like.
import QtQuick
import Quickshell.Hyprland
import Quickshell.Services.Pipewire

Item {
    id: root

    // XDPH creates one of these PipeWire sources for as long as each portal
    // capture runs, so they say whether anything is being captured.
    readonly property var streams: Pipewire.nodes
        ? Pipewire.nodes.values.filter(node => node && node.ready
            && (node.name.startsWith("xdph-streaming-")
                || String(node.properties["media.name"] || "")
                    .startsWith("xdph-streaming-"))) : []
    readonly property bool active: streams.length > 0

    // Hyprland's screencastv2 events say what is captured, but switch on and
    // off with frame activity, so they only pick the monitors; the streams
    // above decide how long a monitor counts as captured.
    property var recordedMonitors: []
    // Recent capture starts: { monitor, at, preview }. Kept briefly so a start
    // reported just before its stream appears still counts.
    property var recentStarts: []

    // The share picker previews every window and monitor at once before any
    // stream exists; captures starting this close together are previews.
    readonly property int burstMs: 150
    readonly property int recentMs: 1500

    onActiveChanged: {
        if (!active) {
            recordedMonitors = [];
            return;
        }
        const now = Date.now();
        for (const start of recentStarts)
            if (!start.preview && now - start.at < recentMs)
                addMonitor(start.monitor);
    }

    function addMonitor(monitor: string): void {
        if (monitor !== "" && !recordedMonitors.includes(monitor))
            recordedMonitors = recordedMonitors.concat([monitor]);
    }

    function monitorForWindow(title: string): string {
        const window = Hyprland.toplevels.values.find(toplevel => toplevel.title === title);
        return String(window?.monitor?.name ?? "");
    }

    // "screencastv2>>STATE,OWNER,NAME": 1/0, "monitor" or "window", and the
    // monitor name or window title (which may itself contain commas).
    function handleEvent(data: string): void {
        const first = data.indexOf(",");
        const second = data.indexOf(",", first + 1);
        if (first < 0 || second < 0 || data.slice(0, first) !== "1")
            return;
        const owner = data.slice(first + 1, second);
        const name = data.slice(second + 1);
        const now = Date.now();

        const burst = recentStarts.filter(start => now - start.at < burstMs);
        for (const start of burst)
            start.preview = true;
        const start = {
            monitor: owner === "monitor" ? name : monitorForWindow(name),
            at: now,
            preview: burst.length > 0
        };
        recentStarts = recentStarts.filter(entry => now - entry.at < recentMs).concat([start]);

        if (active && !start.preview)
            addMonitor(start.monitor);
    }

    Connections {
        target: Hyprland
        function onRawEvent(event: var): void {
            if (event.name === "screencastv2")
                root.handleEvent(event.data);
        }
    }
}
