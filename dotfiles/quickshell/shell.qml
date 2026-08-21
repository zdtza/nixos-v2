//@ pragma UseQApplication

// Root of the shell. One bar instance per connected screen.
import Quickshell

ShellRoot {
    Variants {
        model: Quickshell.screens

        Bar {}
    }
}
