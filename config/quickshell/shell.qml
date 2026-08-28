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

        Bar {
            visible: ServicePanel.barVisible
        }
    }

    IpcHandler {
        target: "panels"

        function toggle(name: string): bool {
            return ServicePanel.toggleNamed(name);
        }
    }

    IpcHandler {
        target: "bar"

        function toggle(): void {
            ServicePanel.barVisible = !ServicePanel.barVisible;
        }

        function hide(): void {
            ServicePanel.barVisible = false;
        }

        function show(): void {
            ServicePanel.barVisible = true;
        }
    }

    Notifications {}

    Osd {}

    // Secure compositor session lock: `qs ipc call lock activate`
    LockScreen {}

    // Single instance, toggled over IPC: `qs ipc call launcher toggle`
    Launcher {}
}
