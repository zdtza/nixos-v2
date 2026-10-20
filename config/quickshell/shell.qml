//@ pragma UseQApplication

// Root of the shell.
import Quickshell
import Quickshell.Io
import "components/bar"
import "components/overlays"
import "components/session"
import "services"

ShellRoot {
    // Session lock and login screen, exposed through the `lock` IPC target.
    LockScreen {
        id: lockScreen
    }

    // Held back until the login lock (if any) is up, so nothing shows before it.
    Variants {
        model: lockScreen.desktopReady ? Quickshell.screens : []

        Background {}
    }

    Variants {
        model: lockScreen.desktopReady ? Quickshell.screens : []

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
