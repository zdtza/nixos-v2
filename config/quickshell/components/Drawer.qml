import Quickshell.Wayland
import "../services"

// Floating drawer used by right-side system panels.
ShellSurface {
    anchors {
        top: PanelService.barAtTop
        bottom: !PanelService.barAtTop
        right: true
    }

    margins.right: PanelService.panelGap + PanelService.gapRightOffset

    WlrLayershell.namespace: "quickshell:panel-drawer"
}
