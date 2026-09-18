import Quickshell.Wayland

// Screen-edge drawer used by right-side system panels.
ShellSurface {
    edgeAligned: true

    anchors {
        top: true
        right: true
    }

    WlrLayershell.namespace: "quickshell:panel-drawer"
}
