pragma Singleton

// Persisted list of time zones shown by the clock panel.
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    // An empty identifier represents the system's non-removable local clock.
    property var timeZones: [""]

    function addTimeZone(zone: string): bool {
        const normalized = String(zone).trim();
        if (normalized.length === 0 || timeZones.indexOf(normalized) !== -1)
            return false;

        timeZones = timeZones.concat([normalized]);
        save();
        return true;
    }

    function removeTimeZone(zone: string): void {
        if (zone.length === 0)
            return;

        const remaining = timeZones.filter(entry => entry !== zone);
        if (remaining.length === timeZones.length)
            return;

        timeZones = remaining;
        save();
    }

    function moveTimeZone(from: int, to: int): bool {
        // Local time remains fixed at index zero.
        if (from < 1 || from >= timeZones.length || to < 1
                || to >= timeZones.length || from === to)
            return false;

        const reordered = timeZones.slice();
        const moved = reordered.splice(from, 1)[0];
        reordered.splice(to, 0, moved);
        timeZones = reordered;
        save();
        return true;
    }

    function save(): void {
        zonesState.setText(JSON.stringify(timeZones) + "\n");
    }

    function restore(value: string): void {
        const raw = String(value).trim();
        if (raw.length === 0)
            return;

        try {
            const stored = JSON.parse(raw);
            if (!Array.isArray(stored))
                return;

            const restored = [];
            for (const value of stored) {
                const zone = String(value).trim();
                if ((zone.length > 0 || String(value) === "")
                        && restored.indexOf(zone) === -1)
                    restored.push(zone);
            }
            // Migrate state from versions that persisted only remote zones,
            // and keep local time fixed above every rearrangeable clock.
            const localIndex = restored.indexOf("");
            if (localIndex !== -1)
                restored.splice(localIndex, 1);
            restored.unshift("");
            timeZones = restored;
        } catch (error) {
            // Ignore malformed state and retain local time.
        }
    }

    FileView {
        id: zonesState
        path: Quickshell.statePath("clock-time-zones")
        preload: true
        atomicWrites: true
        printErrors: false
        onLoaded: root.restore(text())
    }
}
