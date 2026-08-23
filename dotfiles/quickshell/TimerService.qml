pragma Singleton

// Shared countdown state supporting multiple persisted timers.
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property var timers: []
    property bool running: false
    property double nowMs: Date.now()
    property int remainingSeconds: 0
    property int lastDurationSeconds: 0
    property int nextTimerSequence: 0

    signal elapsed(var timerId)

    function formatDuration(seconds: int): string {
        const total = Math.max(0, Math.min(5999, Math.floor(Number(seconds))));
        const minutes = Math.floor(total / 60);
        const secs = total % 60;
        return String(minutes).padStart(2, "0") + ":"
            + String(secs).padStart(2, "0");
    }

    function rememberDuration(seconds: int): bool {
        const duration = Math.floor(Number(seconds));
        if (!Number.isFinite(duration) || duration < 0 || duration > 5999)
            return false;

        lastDurationSeconds = duration;
        durationState.setText(String(duration) + "\n");
        return true;
    }

    function saveTimers(): void {
        const persisted = timers.map(timer => ({
            id: timer.id,
            deadlineMs: timer.deadlineMs,
            durationSeconds: timer.durationSeconds
        }));
        timersState.setText(JSON.stringify(persisted) + "\n");
    }

    function start(seconds: int): bool {
        const duration = Math.floor(Number(seconds));
        if (!Number.isFinite(duration) || duration <= 0 || duration > 5999)
            return false;

        rememberDuration(duration);
        const startedAt = Date.now();
        nowMs = startedAt;
        const timer = {
            id: String(startedAt) + "-" + String(nextTimerSequence++),
            deadlineMs: startedAt + duration * 1000,
            durationSeconds: duration,
            remainingSeconds: duration
        };
        timers = timers.concat([timer]);
        running = true;
        updateNearestRemaining();
        saveTimers();
        return true;
    }

    function removeTimer(timerId): void {
        const remaining = timers.filter(timer => timer.id !== timerId);
        if (remaining.length === timers.length)
            return;

        timers = remaining;
        running = timers.length > 0;
        updateNearestRemaining();
        saveTimers();
    }

    function cancel(): void {
        if (timers.length === 0)
            return;

        timers = [];
        running = false;
        remainingSeconds = 0;
        saveTimers();
    }

    function updateNearestRemaining(): void {
        if (timers.length === 0) {
            remainingSeconds = 0;
            return;
        }

        let nearest = timers[0].remainingSeconds;
        for (let index = 1; index < timers.length; ++index)
            nearest = Math.min(nearest, timers[index].remainingSeconds);
        remainingSeconds = nearest;
    }

    function tick(): void {
        if (timers.length === 0)
            return;

        const now = Date.now();
        const expired = [];
        let nearest = 5999;
        nowMs = now;

        for (const timer of timers) {
            const remaining = Math.max(0, Math.ceil((timer.deadlineMs - now) / 1000));
            if (remaining === 0)
                expired.push(timer.id);
            else
                nearest = Math.min(nearest, remaining);
        }

        // Keep model identity stable between expirations. Replacing array on
        // every tick destroys delegates, causing hover and popup-size flicker.
        if (expired.length > 0)
            timers = timers.filter(timer => expired.indexOf(timer.id) === -1);

        running = timers.length > 0;
        remainingSeconds = running ? nearest : 0;

        if (expired.length > 0) {
            saveTimers();
            for (const timerId of expired) {
                Quickshell.execDetached(["qs-timer-alert"]);
                elapsed(timerId);
            }
        }
    }

    function restoreTimers(value: string): void {
        const raw = String(value).trim();
        if (raw.length === 0)
            return;

        let stored = [];
        try {
            const parsed = JSON.parse(raw);
            if (Array.isArray(parsed)) {
                stored = parsed;
            } else if (Number.isFinite(Number(parsed)) && Number(parsed) > 0) {
                // Migrate state written by single-timer versions.
                stored = [{
                    id: "legacy-" + String(parsed),
                    deadlineMs: Number(parsed),
                    durationSeconds: Math.max(1, lastDurationSeconds)
                }];
            }
        } catch (error) {
            return;
        }

        const restored = [];
        for (const timer of stored) {
            const deadline = Number(timer.deadlineMs);
            const duration = Math.floor(Number(timer.durationSeconds));
            if (!Number.isFinite(deadline) || deadline <= 0)
                continue;
            restored.push({
                id: String(timer.id || ("restored-" + String(deadline))),
                deadlineMs: deadline,
                durationSeconds: Number.isFinite(duration) && duration > 0
                    ? duration : Math.max(1, lastDurationSeconds),
                remainingSeconds: Math.max(0, Math.ceil((deadline - Date.now()) / 1000))
            });
        }

        timers = restored;
        running = timers.length > 0;
        tick();
    }

    FileView {
        id: durationState
        path: Quickshell.statePath("timer-duration-seconds")
        preload: true
        atomicWrites: true
        printErrors: false
        onLoaded: {
            const duration = Number(text().trim());
            if (Number.isFinite(duration) && duration >= 0 && duration <= 5999)
                root.lastDurationSeconds = Math.floor(duration);
        }
    }

    FileView {
        id: timersState
        // Reuse old path so existing single timer can be migrated.
        path: Quickshell.statePath("timer-deadline-ms")
        preload: true
        atomicWrites: true
        printErrors: false
        onLoaded: root.restoreTimers(text())
    }

    Timer {
        interval: 250
        running: root.running
        repeat: true
        onTriggered: root.tick()
    }

    IpcHandler {
        target: "timer"

        function start(seconds: int): bool { return root.start(seconds); }
        function cancel(): void { root.cancel(); }
        function remaining(): int { return root.remainingSeconds; }
        function isRunning(): bool { return root.running; }
    }
}
