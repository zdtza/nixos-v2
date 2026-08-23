pragma Singleton

import QtQuick

// Coordinates bar panels so only one instance is open across all screens.
QtObject {
    property var activePanel: null

    // Shared top-bar geometry keeps standalone panels aligned with popups.
    property real barHeight: 30
    property real barGap: 9

    function open(panel: var): void {
        activePanel = panel;
    }

    function toggle(panel: var): void {
        activePanel = activePanel === panel ? null : panel;
    }

    function close(panel: var): void {
        if (activePanel === panel)
            activePanel = null;
    }

    function closeActive(): void {
        activePanel = null;
    }
}
