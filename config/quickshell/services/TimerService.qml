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

    // Completion alert, kept here as plain POSIX sh rather than a packaged
    // wrapper so this config runs unmodified off NixOS: nothing below is a
    // build-time path, it is all discovered from the running system. Same
    // idiom as NetworkService.detailsCommand.
    //
    // Both halves degrade quietly -- no notification daemon, no sound theme,
    // or no player just means that part is skipped, never a broken timer.
    readonly property string alertCommand: `
notify-send --app-name="Quickshell Timer" --urgency=critical \\
    --icon=alarm-symbolic --expire-time=10000 \\
    "Timer complete" "Countdown has elapsed." 2>/dev/null

# The freedesktop sound theme has no portable absolute path: NixOS keeps it in
# the system profile, most distros under /usr/share. Both are on XDG_DATA_DIRS.
dirs=$XDG_DATA_DIRS
[ -n "$dirs" ] || dirs=/usr/local/share:/usr/share

sound=$(IFS=:; for dir in $dirs; do
    for ext in oga ogg wav; do
        file=$dir/sounds/freedesktop/stereo/alarm-clock-elapsed.$ext
        [ -r "$file" ] && { printf '%s' "$file"; exit 0; }
    done
done)
[ -n "$sound" ] || exit 0

# First player present wins; between them these cover PipeWire, PulseAudio,
# ALSA and the usual media players.
for player in pw-play paplay mpv ffplay aplay; do
    command -v "$player" >/dev/null 2>&1 || continue
    case $player in
        mpv)    exec mpv --no-video --really-quiet "$sound" ;;
        ffplay) exec ffplay -nodisp -autoexit -loglevel quiet "$sound" ;;
        aplay)  case $sound in *.wav) exec aplay -q "$sound" ;; esac ;;
        *)      exec "$player" "$sound" ;;
    esac
done
`

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
            for (let index = 0; index < expired.length; ++index)
                Quickshell.execDetached(["sh", "-c", root.alertCommand]);
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
