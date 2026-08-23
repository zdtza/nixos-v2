pragma Singleton

import QtQuick
import Quickshell.Hyprland
import Quickshell.Io

// Coordinates bar panels so only one instance is open across all screens.
Item {
    id: root

    property var activePanel: null
    property var pendingPanel: null
    property int handoffGeneration: 0
    property var registeredPanels: ({})

    // Shared top-bar geometry keeps standalone panels aligned with popups.
    property real barHeight: 30
    // Gap below the bar for popups/notifications. Mirrors Hyprland's
    // general:gaps_out (top value) so panels line up with window edges
    // regardless of gap configuration; refreshed on startup and whenever
    // Hyprland reloads its config. Falls back to this default until the
    // first query resolves, or if hyprctl is ever unavailable.
    property real barGap: 9
    // Corner rounding applied everywhere in the UI (panels, buttons, inputs,
    // highlights, ...) except the workspace indicator. Mirrors Hyprland's
    // decoration:rounding so the shell's corners match window corners;
    // refreshed the same way as barGap.
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
        toggle(candidate.panel);
        return true;
    }
}
