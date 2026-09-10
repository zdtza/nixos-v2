pragma Singleton

// Voxtype voice dictation state. Follows the daemon's Waybar-style JSON
// status stream (voxtype pushes a line the instant recording starts/stops),
// so the indicator updates immediately instead of waiting on a poll tick.
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    // Strictly the capture window. The daemon reports three classes -- idle,
    // recording, transcribing -- and transcribing can run for seconds after
    // the toggle is pressed, so anything treating "not idle" as active keeps
    // showing a microphone that is no longer listening.
    property bool recording: false

    function toggle(): void {
        if (!toggleProcess.running)
            toggleProcess.running = true;
    }

    function parseStatus(raw: string): void {
        try {
            const data = JSON.parse(raw);
            root.recording = String(data.class || "idle") === "recording";
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
