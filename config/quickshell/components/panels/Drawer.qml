import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../../services"

// Floating drawer used by right-side system panels. Opens while its anchorItem
// is PanelService's active panel; Escape or a click outside closes it.
ShellSurface {
    id: root

    property bool centeredHorizontally: false
    property bool centeredVertically: false

    anchorWindow: anchorItem.QsWindow.window
    open: PanelService.activePanel === anchorItem
    onCloseRequested: PanelService.close(anchorItem)

    anchors {
        top: !centeredVertically && PanelService.barAtTop
        bottom: !centeredVertically && !PanelService.barAtTop
        right: !centeredHorizontally
    }

    margins.top: !centeredVertically && PanelService.barAtTop
        ? PanelService.panelBarInset + PanelService.panelGap : 0
    margins.bottom: !centeredVertically && !PanelService.barAtTop
        ? PanelService.panelBarInset + PanelService.panelGap : 0

    margins.right: centeredHorizontally
        ? 0 : PanelService.panelGap + PanelService.gapRightOffset

    WlrLayershell.namespace: "quickshell:panel-drawer"

    // The bar stays in scope so a click can move straight to another bar control.
    HyprlandFocusGrab {
        active: root.open && !PanelService.refocusing
        windows: [root, root.anchorWindow]
        onCleared: if (!PanelService.refocusing) root.closeRequested()
    }
}
