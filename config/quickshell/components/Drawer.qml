import Quickshell.Wayland

// Screen-edge drawer used by right-side system panels. Chrome lives in
// ShellSurface; this only pins it to the right edge.
ShellSurface {
    edgeAligned: true

    anchors {
        top: true
        right: true
    }

    WlrLayershell.namespace: "quickshell:panel-drawer"
}
