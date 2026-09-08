import Quickshell.Wayland

// Centered launcher-style drawer used by clock and quick-toggle panels.
// Chrome lives in ShellSurface; this only picks the free-floating shape.
ShellSurface {
    anchors.top: true

    WlrLayershell.namespace: "quickshell:center-panel"
}
