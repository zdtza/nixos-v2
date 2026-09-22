import Quickshell.Wayland
import "../services"

// Floating drawer used by right-side system panels.
ShellSurface {
    anchors {
        bottom: true
        right: true
    }

    margins.right: PanelService.panelGap + PanelService.gapRightOffset

    WlrLayershell.namespace: "quickshell:panel-drawer"
}
