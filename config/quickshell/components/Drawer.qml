import Quickshell.Wayland
import "../services"

// Floating drawer used by right-side system panels.
ShellSurface {
    property bool centeredHorizontally: false

    anchors {
        top: PanelService.barAtTop
        bottom: !PanelService.barAtTop
        right: !centeredHorizontally
    }

    margins.right: centeredHorizontally
        ? 0 : PanelService.panelGap + PanelService.gapRightOffset

    WlrLayershell.namespace: "quickshell:panel-drawer"
}
