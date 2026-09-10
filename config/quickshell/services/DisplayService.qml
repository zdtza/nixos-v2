pragma Singleton

// Shared backlight state, monitor scaling, and external brightness controls.
//
// Brightness is one 1-150 `level`, stacked in two stages:
//   1-100   backlight only, hyprsunset gamma parked at 100 (neutral)
//   101-150 backlight pinned at 100, the rest is hyprsunset CTM gamma
// Gamma only boosts from a full backlight, and the backlight only moves once
// gamma is back to neutral. Neither stage is persisted: the backlight is read
// from brightnessctl and the gamma from hyprsunset, so a shell reload or a
// hyprsunset restart re-adopts whatever is really applied. Gamma above 100
// multiplies the CTM, so highlights clip -- that is the price of brightness
// past hardware max, not a bug.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Item {
    id: root

    readonly property int brightnessStep: 5
    // Matches --gamma_max in home/hyprsunset.nix; hyprsunset rejects more.
    readonly property int maxLevel: 150
    // Held brightness keys repeat every ~40ms and a slider drag emits faster
    // still. Properties update immediately so the OSD and panel track the
    // input, but the backlight and gamma writes only fire once the stream of
    // events goes quiet -- one hardware write per gesture instead of dozens.
    readonly property int writeDelay: 150
    readonly property var monitors: Hyprland.monitors ? Hyprland.monitors.values : []
    readonly property var focusedMonitor: Hyprland.focusedMonitor

    property bool available: false
    property int brightnessPercent: 0
    property int pendingBrightness: 0
    property int writingBrightness: 0

    // hyprsunset gamma in percent; 100 is neutral, above it is overdrive.
    property int gammaPercent: 100
    property int pendingGamma: 100
    property int writingGamma: 100

    readonly property int level: gammaPercent > 100 ? gammaPercent : brightnessPercent

    property real lastStepMs: 0
    property int fastSteps: 0

    signal brightnessIpcInvoked()

    function clampBrightness(percent: int): int {
        return Math.max(1, Math.min(100, Math.round(Number(percent))));
    }

    function clampLevel(percent: int): int {
        return Math.max(1, Math.min(maxLevel, Math.round(Number(percent))));
    }

    // Single entry point for anything user-facing. Backlight first on the way
    // up, gamma first on the way down, so the two stages never overlap.
    function setLevel(percent: int): void {
        const next = clampLevel(percent);
        if (next > 100) {
            setBrightness(100);
            setGamma(next);
        } else {
            setGamma(100);
            setBrightness(next);
        }
    }

    function adjustLevel(delta: int): void {
        setLevel(level + delta);
    }

    // The brightness keys on this machine are firmware taps, not held keys:
    // the Video Bus / Ideapad device emits a press plus a release ~30ms later
    // even while the key is down, then auto-repeats those taps at ~16Hz after
    // a ~1s hardware pre-delay. So there is no held-key state to ramp from --
    // neither a compositor repeat flag nor a press/release ramp can work, both
    // see the key as already released. What we can do is make the tap stream
    // itself cover ground: consecutive taps grow the step, up to 3x.
    function stepLevel(direction: int): void {
        const now = Date.now();
        fastSteps = now - lastStepMs < 150 ? fastSteps + 1 : 0;
        lastStepMs = now;
        adjustLevel(direction * brightnessStep
            * Math.min(3, 1 + Math.floor(fastSteps / 4)));
        brightnessIpcInvoked();
    }

    function setGamma(percent: int): void {
        const next = Math.max(100, Math.min(maxLevel, Math.round(Number(percent))));
        // Every sub-100 level call parks gamma at neutral, so skip the hyprctl
        // round trip when it is already there.
        if (next === pendingGamma)
            return;
        pendingGamma = next;
        gammaPercent = next;
        gammaDebounce.restart();
    }

    function parseGamma(raw: string): void {
        const parsed = Number(String(raw || "").trim());
        if (!Number.isFinite(parsed) || gammaWriteProcess.running
                || gammaDebounce.running)
            return;
        gammaPercent = Math.max(100, Math.min(maxLevel, Math.round(parsed)));
        pendingGamma = gammaPercent;
        enforceGammaCeiling();
    }

    // The invariant, checked against what the backlight actually reports and
    // not what we asked for: a vendor hotkey or a power profile can dim the
    // panel under us, and a boost on a dimmed panel is just a washed-out
    // picture. Skipped while our own backlight write is in flight, since the
    // reported value is stale until it lands.
    function enforceGammaCeiling(): void {
        if (gammaPercent > 100 && available && brightnessPercent < 100
                && !writeProcess.running && !writeDebounce.running)
            setGamma(100);
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
        // A queued or in-flight write means the panel still reports the old
        // value; adopting it here would yank the slider back mid-gesture.
        if (writeDebounce.running || writeProcess.running)
            return;
        brightnessPercent = clampBrightness(parsed);
        pendingBrightness = brightnessPercent;
        enforceGammaCeiling();
    }

    function refresh(): void {
        if (!readProcess.running) readProcess.running = true;
        if (!gammaReadProcess.running && !gammaWriteProcess.running)
            gammaReadProcess.running = true;
    }

    function setBrightness(percent: int): void {
        const next = clampBrightness(percent);
        // Boost steps all target a pinned 100% backlight; don't respawn
        // brightnessctl for a value the panel already reports.
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
        interval: root.writeDelay
        onTriggered: {
            if (writeProcess.running) return;
            root.writingBrightness = root.pendingBrightness;
            writeProcess.running = true;
        }
    }

    Process {
        id: gammaReadProcess
        command: ["hyprctl", "hyprsunset", "gamma"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.parseGamma(text)
        }
    }

    Process {
        id: gammaWriteProcess
        command: ["hyprctl", "hyprsunset", "gamma", String(root.writingGamma)]
        onExited: if (root.pendingGamma !== root.writingGamma) gammaDebounce.restart()
    }

    Timer {
        id: gammaDebounce
        interval: root.writeDelay
        onTriggered: {
            if (gammaWriteProcess.running) return;
            root.writingGamma = root.pendingGamma;
            gammaWriteProcess.running = true;
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
        function gamma(): int { return root.gammaPercent; }
        function setScale(scale: real): void { root.setScale(scale); }
    }
}
