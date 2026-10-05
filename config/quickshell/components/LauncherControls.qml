// Global shortcuts and IPC entry points for the launcher panel hosted in the bar.
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "../services"

Scope {
    id: root

    readonly property bool launcherOpen: PanelService.activePanel?.isLauncher ?? false
    readonly property bool keybindsOpen: launcherOpen && PanelService.activePanel.keybindMode

    function toggleLauncher(): void {
        PanelService.toggleNamed("launcher");
    }

    function toggleKeybinds(): void {
        PanelService.callNamed("launcher", "toggleKeybinds");
    }

    GlobalShortcut {
        appid: "quickshell"
        name: "launcher"
        description: "Toggle application launcher"
        triggerDescription: "Super+Space"
        onPressed: root.toggleLauncher()
    }

    GlobalShortcut {
        appid: "quickshell"
        name: "keybinds"
        description: "Open keybindings in application launcher"
        triggerDescription: "Super+Ctrl+K"
        onPressed: root.toggleKeybinds()
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

    IpcHandler {
        target: "keybinds"
        function toggle(): void { root.toggleKeybinds(); }
        function open(): void {
            if (!root.keybindsOpen)
                root.toggleKeybinds();
        }
        function close(): void {
            if (root.launcherOpen)
                PanelService.closeActive();
        }
        function isOpen(): bool { return root.keybindsOpen; }
    }
}
