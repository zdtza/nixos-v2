pragma Singleton

// Persistent hyprsunset state and controls. Hyprsunset stays running; toggles
// use its Hyprland IPC endpoint to apply or remove warmth.
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property bool available: false
    property bool enabled: false
    property bool desiredEnabled: false
    property bool writingEnabled: false
    property bool stateLoaded: false

    function dispatchDesired(): void {
        if (controlProcess.running)
            return;

        writingEnabled = desiredEnabled;
        controlProcess.command = ["hyprctl", "hyprsunset", "identity",
            writingEnabled ? "false" : "true"];
        controlProcess.running = true;
    }

    function setEnabled(value: bool): void {
        stateLoaded = true;
        desiredEnabled = value;
        enabled = value;
        available = true;
        stateFile.setText(value ? "true\n" : "false\n");
        dispatchDesired();
    }

    function toggle(): void {
        setEnabled(!enabled);
    }

    function restore(raw: string): void {
        desiredEnabled = String(raw || "").trim() === "true";
        enabled = desiredEnabled;
        stateLoaded = true;
        dispatchDesired();
    }

    function parseIdentity(raw: string): void {
        const value = String(raw || "").trim();
        if (value !== "true" && value !== "false") {
            available = false;
            return;
        }

        available = true;
        if (controlProcess.running)
            return;

        const actualEnabled = value === "false";
        if (!stateLoaded) {
            stateLoaded = true;
            desiredEnabled = actualEnabled;
            enabled = actualEnabled;
            stateFile.setText(actualEnabled ? "true\n" : "false\n");
            return;
        }

        if (actualEnabled !== desiredEnabled) {
            enabled = desiredEnabled;
            dispatchDesired();
        } else {
            enabled = actualEnabled;
            desiredEnabled = actualEnabled;
        }
    }

    function refresh(): void {
        if (!statusProcess.running && !controlProcess.running)
            statusProcess.running = true;
    }

    FileView {
        id: stateFile
        path: Quickshell.statePath("nightlight-enabled")
        preload: true
        atomicWrites: true
        printErrors: false
        onLoaded: root.restore(text())
        onLoadFailed: root.refresh()
    }

    Process {
        id: statusProcess
        command: ["hyprctl", "hyprsunset", "identity", "get"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.parseIdentity(text)
        }
    }

    Process {
        id: controlProcess
        onExited: {
            if (root.writingEnabled !== root.desiredEnabled) {
                root.dispatchDesired();
                return;
            }
            refreshDelay.restart();
        }
    }

    Timer {
        id: refreshDelay
        interval: 100
        onTriggered: root.refresh()
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    IpcHandler {
        target: "nightlight"

        function toggle(): void { root.toggle(); }
        function enable(): void { root.setEnabled(true); }
        function disable(): void { root.setEnabled(false); }
        function isEnabled(): bool { return root.enabled; }
    }
}
