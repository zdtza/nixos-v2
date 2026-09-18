import Quickshell.Wayland

// Centered launcher-style drawer used by clock and quick-toggle panels.
ShellSurface {
    anchors.top: true

    WlrLayershell.namespace: "quickshell:center-panel"
}
