import Quickshell.Wayland

// Centered floating panel used by the clock.
ShellSurface {
    anchors.bottom: true

    WlrLayershell.namespace: "quickshell:center-panel"
}
