pragma Singleton

// Persistent hyprsunset state, temperature, and controls.
import QtQuick
import Quickshell
import Quickshell.Io

PersistentToggle {
    id: root

    stateFileName: "nightlight-enabled"

    property bool available: false
    property bool writingEnabled: false
    property int temperature: 3500
    property int writingTemperature: 3500
    property bool temperatureLoaded: false

    function dispatchDesired(): void {
        if (controlProcess.running || !stateLoaded || !temperatureLoaded)
            return;

        writingEnabled = active;
        writingTemperature = temperature;
        controlProcess.command = writingEnabled
            ? ["hyprctl", "hyprsunset", "temperature", String(writingTemperature)]
            : ["hyprctl", "hyprsunset", "identity", "true"];
        controlProcess.running = true;
    }

    onActiveChanged: if (stateLoaded) dispatchDesired()
    onRestored: dispatchDesired()
    onMissing: refresh()

    function setTemperature(value: int): void {
        const next = Math.max(1000, Math.min(6500, Math.round(Number(value))));
        if (!Number.isFinite(next))
            return;

        temperatureLoaded = true;
        temperature = next;
        temperatureFile.setText(String(next) + "\n");
        if (active)
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
        // With nothing saved yet, adopt whatever hyprsunset is doing.
        if (!stateLoaded)
            setEnabled(actualEnabled);
        else if (actualEnabled !== active)
            dispatchDesired();
    }

    function refresh(): void {
        if (!statusProcess.running && !controlProcess.running)
            statusProcess.running = true;
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
            if (root.writingEnabled !== root.active
                    || (root.active && root.writingTemperature !== root.temperature)) {
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
        function isEnabled(): bool { return root.active; }
        function setTemperature(value: int): void { root.setTemperature(value); }
        function getTemperature(): int { return root.temperature; }
    }
}
