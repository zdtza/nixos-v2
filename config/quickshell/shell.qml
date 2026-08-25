//@ pragma UseQApplication

// Root of the shell. One bar instance per connected screen.
import Quickshell
import Quickshell.Io

ShellRoot {
    id: root

    property bool statusBarVisible: true

    Variants {
        model: Quickshell.screens

        Bar {
            visible: root.statusBarVisible
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
            root.statusBarVisible = !root.statusBarVisible;
        }

        function hide(): void {
            root.statusBarVisible = false;
        }

        function show(): void {
            root.statusBarVisible = true;
        }
    }

    Notifications {}

    Osd {}

    // Secure compositor session lock: `qs ipc call lock activate`
    LockScreen {}

    // Single instance, toggled over IPC: `qs ipc call launcher toggle`
    Launcher {}
}
