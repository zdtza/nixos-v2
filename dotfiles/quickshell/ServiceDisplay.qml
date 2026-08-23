pragma Singleton

// Shared backlight state, monitor scaling, and external brightness controls.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Item {
    id: root

    readonly property int brightnessStep: 5
    readonly property var monitors: Hyprland.monitors ? Hyprland.monitors.values : []
    readonly property var focusedMonitor: Hyprland.focusedMonitor

    property bool available: false
    property int brightnessPercent: 0
    property int pendingBrightness: 0
    property int writingBrightness: 0

    signal brightnessIpcInvoked()

    function clampBrightness(percent: int): int {
        return Math.max(1, Math.min(100, Math.round(Number(percent))));
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
        brightnessPercent = clampBrightness(parsed);
        pendingBrightness = brightnessPercent;
    }

    function refresh(): void {
        if (!readProcess.running) readProcess.running = true;
    }

    function setBrightness(percent: int): void {
        pendingBrightness = clampBrightness(percent);
        brightnessPercent = pendingBrightness;
        writeDebounce.restart();
    }

    function adjustBrightness(delta: int): void {
        setBrightness(brightnessPercent + delta);
    }

    function luaString(value: string): string {
        return `"${String(value).replace(/\\/g, "\\\\").replace(/"/g, "\\\"")}"`;
    }

    function setScale(scale: real): void {
        if (!focusedMonitor) return;
        const value = Math.max(1, Math.min(4, Number(scale)));
        if (Math.abs(Number(focusedMonitor.scale) - value) < 0.01) return;
        const position = `${focusedMonitor.x}x${focusedMonitor.y}`;
        // This setup uses Hyprland's Lua config parser, where legacy `keyword
        // monitor` requests are rejected. Apply runtime monitor config through
        // eval and preserve focused monitor's current layout position.
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
        interval: 35
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

        function brightnessUp(): void {
            root.adjustBrightness(root.brightnessStep);
            root.brightnessIpcInvoked();
        }
        function brightnessDown(): void {
            root.adjustBrightness(-root.brightnessStep);
            root.brightnessIpcInvoked();
        }
        function setBrightness(percent: int): void {
            root.setBrightness(percent);
            root.brightnessIpcInvoked();
        }
        function brightness(): int { return root.brightnessPercent; }
        function setScale(scale: real): void { root.setScale(scale); }
    }
}
