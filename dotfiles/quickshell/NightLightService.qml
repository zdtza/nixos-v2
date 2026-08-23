pragma Singleton

// Persistent hyprsunset state, temperature, and controls. Hyprsunset stays
// running; controls use its Hyprland IPC endpoint to apply or remove warmth.
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
    property int temperature: 3500
    property int writingTemperature: 3500
    property bool temperatureLoaded: false

    function dispatchDesired(): void {
        if (controlProcess.running || !stateLoaded || !temperatureLoaded)
            return;

        writingEnabled = desiredEnabled;
        writingTemperature = temperature;
        controlProcess.command = writingEnabled
            ? ["hyprctl", "hyprsunset", "temperature", String(writingTemperature)]
            : ["hyprctl", "hyprsunset", "identity", "true"];
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

    function setTemperature(value: int): void {
        const next = Math.max(1000, Math.min(6500, Math.round(Number(value))));
        if (!Number.isFinite(next))
            return;

        temperatureLoaded = true;
        temperature = next;
        temperatureFile.setText(String(next) + "\n");
        if (desiredEnabled)
            dispatchDesired();
    }

    function restoreEnabled(raw: string): void {
        desiredEnabled = String(raw || "").trim() === "true";
        enabled = desiredEnabled;
        stateLoaded = true;
        dispatchDesired();
    }

    function restoreTemperature(raw: string): void {
        const value = Math.round(Number(String(raw || "").trim()));
        if (Number.isFinite(value) && value >= 1000 && value <= 6500)
            temperature = value;
        else
            temperatureFile.setText(String(temperature) + "\n");
        temperatureLoaded = true;
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
            if (actualEnabled)
                dispatchDesired();
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
        onLoaded: root.restoreEnabled(text())
        onLoadFailed: root.refresh()
    }

    FileView {
        id: temperatureFile
        path: Quickshell.statePath("nightlight-temperature")
        preload: true
        atomicWrites: true
        printErrors: false
        onLoaded: root.restoreTemperature(text())
        onLoadFailed: root.restoreTemperature("")
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
            if (root.writingEnabled !== root.desiredEnabled
                    || (root.desiredEnabled
                        && root.writingTemperature !== root.temperature)) {
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
        function setTemperature(value: int): void { root.setTemperature(value); }
        function getTemperature(): int { return root.temperature; }
    }
}
