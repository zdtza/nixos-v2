import QtQuick
import Quickshell.Hyprland

// Briefly opens a bar panel in response to an IPC call (volume/brightness
// keybinds), auto-closing shortly after unless the user keeps interacting.
// Suppressed on unfocused screens and while the focused workspace is
// fullscreen, and dismissed immediately if fullscreen starts while shown.
Item {
    id: root

    required property Item panel
    required property var screen
    property int autoCloseMs: 800

    property bool active: false

    implicitWidth: 0
    implicitHeight: 0

    function show(): void {
        const focused = Hyprland.focusedMonitor;
        if (focused && String(root.screen.name) !== String(focused.name))
            return;
        if (focused?.activeWorkspace?.hasFullscreen)
            return;
        if (ServicePanel.activePanel !== root.panel) {
            root.active = true;
            ServicePanel.open(root.panel);
        }
        if (root.active)
            closeTimer.restart();
    }

    function hide(): void {
        if (!root.active)
            return;
        closeTimer.stop();
        ServicePanel.close(root.panel);
        root.active = false;
    }

    Timer {
        id: closeTimer
        interval: root.autoCloseMs
        onTriggered: {
            ServicePanel.close(root.panel);
            root.active = false;
        }
    }

    Connections {
        target: Hyprland.focusedWorkspace
        function onHasFullscreenChanged(): void {
            if (Hyprland.focusedWorkspace?.hasFullscreen)
                root.hide();
        }
    }

    // Panel can also close through the normal path (click-away, toggle);
    // drop the pending auto-close without reopening/reclosing it.
    Connections {
        target: root.panel
        function onOpenedChanged(): void {
            if (!root.panel.opened && root.active) {
                closeTimer.stop();
                root.active = false;
            }
        }
    }
}
