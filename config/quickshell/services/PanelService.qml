pragma Singleton

import QtQuick
import Quickshell.Hyprland
import Quickshell.Io
import ".."

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

    // Change this one line to "top" or "bottom" to place the bar and its panels.
    property string barPosition: "top"
    readonly property bool barAtTop: barPosition === "top"

    // Whether the status bar is currently shown (toggled via `qs ipc call bar toggle/hide/show`).
    property bool barVisible: true
    readonly property bool focusedAppFullscreen: !!Hyprland.activeToplevel
        && !!Hyprland.focusedWorkspace?.hasFullscreen

    // Fullscreen clients cover the bar, so overlays use hidden-bar geometry.
    readonly property bool barAffectsPanels: barVisible && !focusedAppFullscreen
    readonly property real panelBarInset: barAffectsPanels ? barHeight : 0
    // A visible-but-covered bar remains the popup's parent at the screen edge.
    readonly property real popupParentOffset: barVisible && focusedAppFullscreen
        ? barHeight : 0

    // Shared bar geometry keeps standalone panels aligned with popups.
    property real barHeight: 32
    // Every bar control spans the full bar height, so hover/active underlines
    // anchored to a control's bottom sit exactly on the bar's bottom edge.
    readonly property real barItemHeight: barHeight
    // Single source for the gap between every bar button/toggle and the clock, so the bar's groups all read as evenly spaced.
    property real barSpacing: 4
    // Hyprland's outer gap, also used to inset floating shell panels.
    property real barGap: 9
    readonly property real panelGap: barGap
    // Manual per-edge nudges layered on top of barGap, for whatever few pixels compositor rounding/borders leave popups and notifications off by.
    property real gapBottomOffset: 0
    property real gapLeftOffset: 0
    property real gapRightOffset: 0
    // Shared speed for animated bar controls.
    property int slideDuration: 150
    // Shared subtle border used by the bar and every shell panel.
    readonly property real chromeBorderWidth: 1
    readonly property color chromeBorderColor: Utils.alpha(Theme.base05, 0.15)
    // Internal controls use a small, stable radius independent of Hyprland.
    readonly property real rounding: 2

    function refreshBarGap(): void {
        if (!gapsProcess.running)
            gapsProcess.running = true;
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

    Component.onCompleted: refreshBarGap()

    Connections {
        target: Hyprland
        function onRawEvent(event: var): void {
            if (event.name === "configreloaded")
                root.refreshBarGap();
        }
        // Switching workspace (e.g. Super+5) refocuses the target workspace and
        // strips keyboard focus from the bar, so a keyboard panel goes deaf.
        // Briefly releasing the bar's keyboard interactivity and focus grab, then
        // restoring both, makes Hyprland hand focus back without closing the panel.
        function onFocusedWorkspaceChanged(): void {
            if (!root.activePanel?.requiresKeyboardFocus)
                return;
            root.refocusing = true;
            refocusTimer.restart();
        }
    }

    // While true, bars drop keyboard interactivity and panel focus grabs stand down
    // (ignoring the resulting clear) so the panel stays open.
    property bool refocusing: false

    Timer {
        id: refocusTimer
        interval: 50
        onTriggered: root.refocusing = false
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

    // Panel registered under `name` on the focused monitor, else the first one.
    function panelFor(name: string): var {
        const panels = registeredPanels[name] ?? [];
        if (panels.length === 0)
            return null;

        const focusedName = String(Hyprland.focusedMonitor?.name ?? "");
        return (panels.find(entry => String(entry.screen?.name ?? "") === focusedName)
            ?? panels[0]).panel;
    }

    function toggleNamed(name: string): bool {
        const panel = panelFor(name);
        if (!panel)
            return false;

        if (typeof panel.toggleFromIpc === "function")
            panel.toggleFromIpc();
        else
            toggle(panel);
        return true;
    }

    // Calls a named method on the panel registered under `name`.
    function callNamed(name: string, method: string): bool {
        const panel = panelFor(name);
        if (!panel || typeof panel[method] !== "function")
            return false;

        panel[method]();
        return true;
    }
}
