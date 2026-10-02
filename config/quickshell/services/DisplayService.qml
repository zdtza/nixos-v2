pragma Singleton

// Shared backlight state, monitor scaling, and external brightness controls.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Item {
    id: root

    readonly property int brightnessStep: 5
    readonly property int maxLevel: 100
    // Held brightness keys repeat every ~40ms and a slider drag emits faster still.
    readonly property int writeDelay: 150
    readonly property var monitors: Hyprland.monitors ? Hyprland.monitors.values : []
    readonly property var focusedMonitor: Hyprland.focusedMonitor

    property bool available: false
    property int brightnessPercent: 0
    property int pendingBrightness: 0
    property int writingBrightness: 0

    readonly property int level: brightnessPercent

    property real lastStepMs: 0
    property int fastSteps: 0

    signal brightnessIpcInvoked()

    function clampBrightness(percent: int): int {
        return Math.max(1, Math.min(100, Math.round(Number(percent))));
    }

    function setLevel(percent: int): void {
        setBrightness(percent);
    }

    function adjustLevel(delta: int): void {
        setLevel(level + delta);
    }

    // The brightness keys on this machine are firmware taps, not held keys.
    function stepLevel(direction: int): void {
        const now = Date.now();
        fastSteps = now - lastStepMs < 150 ? fastSteps + 1 : 0;
        lastStepMs = now;
        adjustLevel(direction * brightnessStep
            * Math.min(3, 1 + Math.floor(fastSteps / 4)));
        brightnessIpcInvoked();
    }

    function parseBrightness(raw: string): void {
        const line = String(raw || "").trim().split("\n")[0] || "";
        const fields = line.split(",");
        if (fields.length < 4) {
            available = false;
            return;
        }
        const parsed = Number(String(fields[3]).replace("%", ""));
        if (!Number.isFinite(parsed)) return;
        available = true;
        // A queued or in-flight write means the panel still reports the old value; adopting it here would yank the slider back mid-gesture.
        if (writeDebounce.running || writeProcess.running)
            return;
        brightnessPercent = clampBrightness(parsed);
        pendingBrightness = brightnessPercent;
    }

    function refresh(): void {
        if (!readProcess.running) readProcess.running = true;
    }

    function setBrightness(percent: int): void {
        const next = clampBrightness(percent);
        // Don't respawn brightnessctl for a value the panel already reports.
        if (next === pendingBrightness && next === brightnessPercent)
            return;
        pendingBrightness = next;
        brightnessPercent = pendingBrightness;
        writeDebounce.restart();
    }

    function luaString(value: string): string {
        return `"${String(value).replace(/\\/g, "\\\\").replace(/"/g, "\\\"")}"`;
    }

    function setScale(scale: real): void {
        if (!focusedMonitor) return;
        const value = Math.max(1, Math.min(4, Number(scale)));
        if (Math.abs(Number(focusedMonitor.scale) - value) < 0.01) return;
        const position = `${focusedMonitor.x}x${focusedMonitor.y}`;
        // This setup uses Hyprland's Lua config parser, where legacy `keyword monitor` requests are rejected.
        const code = `hl.monitor({ output = ${luaString(focusedMonitor.name)}, `
            + `mode = "preferred", position = ${luaString(position)}, scale = ${value} })`;
        Quickshell.execDetached(["hyprctl", "eval", code]);
        monitorRefresh.restart();
    }

    Process {
        id: readProcess
        command: ["brightnessctl", "--machine-readable", "--class=backlight", "info"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.parseBrightness(text)
        }
    }

    Process {
        id: writeProcess
        command: ["brightnessctl", "--quiet", "--class=backlight", "set",
            `${root.writingBrightness}%`]
        onExited: {
            if (root.pendingBrightness !== root.writingBrightness)
                writeDebounce.restart();
            else
                refreshAfterWrite.restart();
        }
    }

    Timer {
        id: writeDebounce
        interval: root.writeDelay
        onTriggered: {
            if (writeProcess.running) return;
            root.writingBrightness = root.pendingBrightness;
            writeProcess.running = true;
        }
    }

    Timer {
        id: refreshAfterWrite
        interval: 80
        onTriggered: root.refresh()
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Timer {
        id: monitorRefresh
        interval: 250
        onTriggered: Hyprland.refreshMonitors()
    }

    Component.onCompleted: refresh()

    IpcHandler {
        target: "display"

        function brightnessUp(): void { root.stepLevel(1); }
        function brightnessDown(): void { root.stepLevel(-1); }
        function setBrightness(percent: int): void {
            root.setLevel(percent);
            root.brightnessIpcInvoked();
        }
        function brightness(): int { return root.level; }
        function setScale(scale: real): void { root.setScale(scale); }
    }
}
