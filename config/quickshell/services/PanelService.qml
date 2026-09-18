pragma Singleton

import QtQuick
import Quickshell.Hyprland
import Quickshell.Io

// Coordinates bar panels so only one instance is open across all screens.
Item {
    id: root

    property var activePanel: null
    property var pendingPanel: null

    // Hover-select is ignored until the pointer actually moves after a panel opens.
    property bool hoverSelectReady: false
    // Cursor position observed the first time it is seen after opening, to tell a real move from the one position report a still cursor makes.
    property var hoverArmPosition: null

    onActivePanelChanged: {
        hoverSelectReady = false;
        hoverArmPosition = null;
    }

    function armHoverSelect(x: real, y: real): void {
        if (hoverArmPosition === null)
            hoverArmPosition = Qt.point(x, y);
        else if (x !== hoverArmPosition.x || y !== hoverArmPosition.y)
            hoverSelectReady = true;
    }
    property int handoffGeneration: 0
    property var registeredPanels: ({})

    // Whether the status bar is currently shown (toggled via `qs ipc call bar toggle/hide/show`).
    property bool barVisible: true

    // Shared top-bar geometry keeps standalone panels aligned with popups.
    property real barHeight: 30
    // Single source for the gap between every bar button/toggle and the clock, so the bar's groups all read as evenly spaced.
    property real barSpacing: 6
    // Gap below the bar for popups/notifications.
    property real barGap: 9
    // Manual per-edge nudges layered on top of barGap, for whatever few pixels compositor rounding/borders leave popups and notifications off by.
    property real gapBottomOffset: 0
    property real gapLeftOffset: 0
    property real gapRightOffset: 0
    // Outer drawer/menu corners and their concave joins.
    property real shellRounding: 16
    // Shared speed for every shell slide-out reveal.
    property int slideDuration: 150
    // Control rounding mirrors Hyprland's decoration:rounding.
    property real rounding: 0

    function refreshBarGap(): void {
        if (!gapsProcess.running)
            gapsProcess.running = true;
    }

    function refreshRounding(): void {
        if (!roundingProcess.running)
            roundingProcess.running = true;
    }

    Process {
        id: gapsProcess
        command: ["hyprctl", "-j", "getoption", "general:gaps_out"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                let topGap;
                try {
                    topGap = Number(String(JSON.parse(text).css ?? "").trim().split(/\s+/)[0]);
                } catch (e) {
                    topGap = NaN;
                }
                if (Number.isFinite(topGap))
                    root.barGap = topGap;
            }
        }
    }

    Process {
        id: roundingProcess
        command: ["hyprctl", "-j", "getoption", "decoration:rounding"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                let value;
                try {
                    value = Number(JSON.parse(text).int);
                } catch (e) {
                    value = NaN;
                }
                if (Number.isFinite(value))
                    root.rounding = value;
            }
        }
    }

    Component.onCompleted: {
        refreshBarGap();
        refreshRounding();
    }

    Connections {
        target: Hyprland
        function onRawEvent(event: var): void {
            if (event.name === "configreloaded") {
                root.refreshBarGap();
                root.refreshRounding();
            }
        }
    }

    function open(panel: var): void {
        if (!panel)
            return;

        handoffGeneration++;
        pendingPanel = null;
        if (activePanel && activePanel !== panel) {
            const generation = handoffGeneration;
            pendingPanel = panel;
            activePanel = null;
            Qt.callLater(() => {
                if (root.handoffGeneration !== generation || !root.pendingPanel)
                    return;
                const nextPanel = root.pendingPanel;
                root.pendingPanel = null;
                root.activePanel = nextPanel;
            });
            return;
        }
        activePanel = panel;
    }

    function toggle(panel: var): void {
        if (activePanel === panel || pendingPanel === panel) {
            close(panel);
            return;
        }
        open(panel);
    }

    function close(panel: var): void {
        let changed = false;
        if (pendingPanel === panel) {
            pendingPanel = null;
            changed = true;
        }
        if (activePanel === panel) {
            activePanel = null;
            changed = true;
        }
        if (changed)
            handoffGeneration++;
    }

    function closeActive(): void {
        handoffGeneration++;
        pendingPanel = null;
        activePanel = null;
    }

    function registerPanel(name: string, panel: var, screen: var): void {
        const panels = registeredPanels[name] ?? [];
        if (!panels.some(candidate => candidate.panel === panel))
            panels.push({ panel, screen });
        registeredPanels[name] = panels;
    }

    function unregisterPanel(name: string, panel: var): void {
        const panels = registeredPanels[name] ?? [];
        registeredPanels[name] = panels.filter(candidate => candidate.panel !== panel);
        if (activePanel === panel)
            activePanel = null;
    }

    function toggleNamed(name: string): bool {
        const panels = registeredPanels[name] ?? [];
        if (panels.length === 0)
            return false;

        const focusedName = String(Hyprland.focusedMonitor?.name ?? "");
        const candidate = panels.find(entry => String(entry.screen?.name ?? "") === focusedName)
            ?? panels[0];
        if (typeof candidate.panel.toggleFromIpc === "function")
            candidate.panel.toggleFromIpc();
        else
            toggle(candidate.panel);
        return true;
    }
}
