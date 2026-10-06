//@ pragma UseQApplication

// Root of the shell.
import Quickshell
import Quickshell.Io
import "components/bar"
import "components/overlays"
import "components/session"
import "services"

ShellRoot {
    id: root

    // Manual session lock exposed through the `lock` IPC target.
    LockScreen {}

    Variants {
        model: Quickshell.screens

        Background {}
    }

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

    Polkit {}

    // Launcher shortcuts and IPC (`qs ipc call launcher toggle`); the panel lives in the bar.
    LauncherControls {}
}
