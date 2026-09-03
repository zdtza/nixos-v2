pragma Singleton

// Voxtype voice dictation state. Follows the daemon's Waybar-style JSON
// status stream (voxtype pushes a line the instant recording starts/stops),
// so the indicator updates immediately instead of waiting on a poll tick.
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property bool active: false

    function toggle(): void {
        if (!toggleProcess.running)
            toggleProcess.running = true;
    }

    function parseStatus(raw: string): void {
        try {
            const data = JSON.parse(raw);
            root.active = String(data.class || "idle") !== "idle";
        } catch (e) {
            // Daemon not running or malformed output; leave state as-is.
        }
    }

    Process {
        id: followProcess
        command: ["voxtype", "status", "--follow", "--format", "json"]
        running: true
        stdout: SplitParser {
            onRead: line => root.parseStatus(line)
        }
        onExited: restartDelay.restart()
    }

    Timer {
        id: restartDelay
        interval: 1000
        onTriggered: if (!followProcess.running) followProcess.running = true
    }

    Process {
        id: toggleProcess
        command: ["voxtype", "record", "toggle"]
    }
}
