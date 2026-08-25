pragma Singleton

// Persistent caffeine mode. Enabled means hypridle is stopped, leaving idle
// display power and suspend actions disabled until caffeine mode is cleared.
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property bool enabled: false
    property bool desiredEnabled: false
    property bool writingEnabled: false
    property bool stateLoaded: false

    function dispatchDesired(): void {
        if (controlProcess.running)
            return;

        writingEnabled = desiredEnabled;
        controlProcess.command = ["systemctl", "--user",
            writingEnabled ? "stop" : "start", "hypridle.service"];
        controlProcess.running = true;
    }

    function setEnabled(value: bool): void {
        stateLoaded = true;
        desiredEnabled = value;
        enabled = value;
        stateFile.setText(value ? "true\n" : "false\n");
        dispatchDesired();
    }

    function toggle(): void {
        setEnabled(!enabled);
    }

    function restore(raw: string): void {
        const value = String(raw || "").trim();
        desiredEnabled = value === "true";
        enabled = desiredEnabled;
        stateLoaded = true;
        dispatchDesired();
    }

    FileView {
        id: stateFile
        path: Quickshell.statePath("stay-awake-enabled")
        preload: true
        atomicWrites: true
        printErrors: false
        onLoaded: root.restore(text())
        onLoadFailed: if (!statusProcess.running) statusProcess.running = true
    }

    Process {
        id: controlProcess
        onExited: {
            if (root.writingEnabled !== root.desiredEnabled) {
                root.dispatchDesired();
                return;
            }
            statusDelay.restart();
        }
    }

    Process {
        id: statusProcess
        command: ["systemctl", "--user", "is-active", "--quiet", "hypridle.service"]
        onExited: (exitCode, exitStatus) => {
            if (controlProcess.running || exitCode === 4)
                return;

            const actualEnabled = exitCode !== 0;
            if (!root.stateLoaded) {
                root.stateLoaded = true;
                root.desiredEnabled = actualEnabled;
                root.enabled = actualEnabled;
                stateFile.setText(actualEnabled ? "true\n" : "false\n");
                return;
            }

            if (actualEnabled !== root.desiredEnabled) {
                root.enabled = root.desiredEnabled;
                root.dispatchDesired();
            } else {
                root.enabled = actualEnabled;
            }
        }
    }

    Timer {
        id: statusDelay
        interval: 100
        onTriggered: if (!statusProcess.running) statusProcess.running = true
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: if (!statusProcess.running && !controlProcess.running)
            statusProcess.running = true
    }

    IpcHandler {
        target: "stayawake"

        function toggle(): void { root.toggle(); }
        function enable(): void { root.setEnabled(true); }
        function disable(): void { root.setEnabled(false); }
        function isEnabled(): bool { return root.enabled; }
    }
}
