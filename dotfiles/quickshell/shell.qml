//@ pragma UseQApplication

// Root of the shell. One bar instance per connected screen.
import Quickshell

ShellRoot {
    Variants {
        model: Quickshell.screens

        Bar {}
    }

    // Single instance, toggled over IPC: `qs ipc call launcher toggle`
    Launcher {}
}
