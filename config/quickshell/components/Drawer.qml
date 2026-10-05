import Quickshell.Wayland
import "../services"

// Floating drawer used by right-side system panels.
ShellSurface {
    property bool centeredHorizontally: false
    property bool leftAligned: false

    anchors {
        top: PanelService.barAtTop
        bottom: !PanelService.barAtTop
        left: leftAligned
        right: !centeredHorizontally && !leftAligned
    }

    margins.left: leftAligned
        ? PanelService.panelGap + PanelService.gapLeftOffset : 0

    margins.right: centeredHorizontally
        ? 0 : PanelService.panelGap + PanelService.gapRightOffset

    WlrLayershell.namespace: "quickshell:panel-drawer"
}
