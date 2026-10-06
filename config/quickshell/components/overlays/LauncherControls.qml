// Global shortcuts and IPC entry points for the launcher panel hosted in the bar.
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "../../services"

Scope {
    id: root

    readonly property bool launcherOpen: PanelService.activePanel?.isLauncher ?? false

    function toggleLauncher(): void {
        PanelService.toggleNamed("launcher");
    }

    GlobalShortcut {
        appid: "quickshell"
        name: "launcher"
        description: "Toggle application launcher"
        triggerDescription: "Super+Space"
        onPressed: root.toggleLauncher()
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void { root.toggleLauncher(); }
        function open(): void {
            if (!root.launcherOpen)
                root.toggleLauncher();
        }
        function close(): void {
            if (root.launcherOpen)
                PanelService.closeActive();
        }
        function isOpen(): bool { return root.launcherOpen; }
    }

}
