//@ pragma UseQApplication

// Root of the shell. One bar instance per connected screen.
import Quickshell
import Quickshell.Io
import "components"
import "services"

ShellRoot {
    id: root

    Variants {
        model: Quickshell.screens

        Bar {}
    }

    IpcHandler {
        target: "panels"

        function toggle(name: string): bool {
            return PanelService.toggleNamed(name);
        }
    }

    IpcHandler {
        target: "bar"

        function toggle(): void {
            PanelService.barVisible = !PanelService.barVisible;
        }

        function hide(): void {
            PanelService.barVisible = false;
        }

        function show(): void {
            PanelService.barVisible = true;
        }
    }

    Notifications {}

    Osd {}

    // Secure compositor session lock: `qs ipc call lock activate`
    LockScreen {}

    Polkit {}

    // Single instance, toggled over IPC: `qs ipc call launcher toggle`
    Launcher {}
}
