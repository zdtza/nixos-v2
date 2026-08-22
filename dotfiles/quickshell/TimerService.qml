pragma Singleton

// Shared countdown state plus persisted last-used duration.
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property bool running: false
    property double deadlineMs: 0
    property int remainingSeconds: 0
    property int lastDurationSeconds: 0

    signal elapsed()

    function formatDuration(seconds: int): string {
        const total = Math.max(0, Math.floor(Number(seconds)));
        const hours = Math.floor(total / 3600);
        const minutes = Math.floor(total % 3600 / 60);
        const secs = total % 60;
        return String(hours).padStart(2, "0") + ":"
            + String(minutes).padStart(2, "0") + ":"
            + String(secs).padStart(2, "0");
    }

    function rememberDuration(seconds: int): bool {
        const duration = Math.floor(Number(seconds));
        if (!Number.isFinite(duration) || duration < 0 || duration > 359999)
            return false;

        lastDurationSeconds = duration;
        durationState.setText(String(duration) + "\n");
        return true;
    }

    function start(seconds: int): bool {
        const duration = Math.floor(Number(seconds));
        if (!Number.isFinite(duration) || duration <= 0 || duration > 359999)
            return false;

        rememberDuration(duration);
        deadlineMs = Date.now() + duration * 1000;
        deadlineState.setText(String(deadlineMs) + "\n");
        remainingSeconds = duration;
        running = true;
        tick();
        return true;
    }

    function cancel(): void {
        running = false;
        deadlineMs = 0;
        deadlineState.setText("0\n");
        remainingSeconds = 0;
    }

    function tick(): void {
        if (!running)
            return;

        remainingSeconds = Math.max(0, Math.ceil((deadlineMs - Date.now()) / 1000));
        if (remainingSeconds > 0)
            return;

        running = false;
        deadlineMs = 0;
        deadlineState.setText("0\n");
        Quickshell.execDetached(["qs-timer-alert"]);
        elapsed();
    }

    FileView {
        id: durationState
        path: Quickshell.statePath("timer-duration-seconds")
        preload: true
        atomicWrites: true
        printErrors: false
        onLoaded: {
            const duration = Number(text().trim());
            if (Number.isFinite(duration) && duration >= 0 && duration <= 359999)
                root.lastDurationSeconds = Math.floor(duration);
        }
    }

    FileView {
        id: deadlineState
        path: Quickshell.statePath("timer-deadline-ms")
        preload: true
        atomicWrites: true
        printErrors: false
        onLoaded: {
            const deadline = Number(text().trim());
            if (!Number.isFinite(deadline) || deadline <= 0)
                return;

            root.deadlineMs = deadline;
            root.running = true;
            root.tick();
        }
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
