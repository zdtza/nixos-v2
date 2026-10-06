import Quickshell.Wayland
import "../services"

// Floating drawer used by right-side system panels.
ShellSurface {
    property bool centeredHorizontally: false
    property bool centeredVertically: false
    property bool leftAligned: false

    anchors {
        top: !centeredVertically && PanelService.barAtTop
        bottom: !centeredVertically && !PanelService.barAtTop
        left: leftAligned
        right: !centeredHorizontally && !leftAligned
    }

    margins.top: !centeredVertically && PanelService.barAtTop
        ? PanelService.panelBarInset + PanelService.panelGap : 0
    margins.bottom: !centeredVertically && !PanelService.barAtTop
        ? PanelService.panelBarInset + PanelService.panelGap : 0

    margins.left: leftAligned
        ? PanelService.panelGap + PanelService.gapLeftOffset : 0

    margins.right: centeredHorizontally
        ? 0 : PanelService.panelGap + PanelService.gapRightOffset

    WlrLayershell.namespace: "quickshell:panel-drawer"
}
