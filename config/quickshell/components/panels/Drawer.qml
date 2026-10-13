import QtQuick
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

    // The card sits panelGap clear of the bar and the right screen edge. The
    // shadow fills that gap but stops at the bar and at the screen edge, and
    // only grows away from the bar as far as the screen allows.
    readonly property real cardBarInset: PanelService.panelBarInset + PanelService.panelGap
    readonly property real cardRightInset: PanelService.panelGap + PanelService.gapRightOffset
    readonly property real farEdgeRoom: Math.max(0,
        (screen?.height ?? 800) - cardBarInset - panelHeight)

    shadowTop: centeredVertically ? Theme.shadowExtent
        : PanelService.barAtTop ? PanelService.panelGap : Math.min(Theme.shadowExtent, farEdgeRoom)
    shadowBottom: centeredVertically ? Theme.shadowExtent
        : PanelService.barAtTop ? Math.min(Theme.shadowExtent, farEdgeRoom) : PanelService.panelGap
    shadowRight: centeredHorizontally ? Theme.shadowExtent : cardRightInset

    margins.top: !centeredVertically && PanelService.barAtTop
        ? cardBarInset - shadowTop : 0
    margins.bottom: !centeredVertically && !PanelService.barAtTop
        ? cardBarInset - shadowBottom : 0

    margins.right: centeredHorizontally ? 0 : cardRightInset - shadowRight

    WlrLayershell.namespace: "quickshell:panel-drawer"

    readonly property bool sharesNotificationCorner: open
        && !centeredHorizontally && !centeredVertically

    Binding {
        target: PanelService
        property: "drawerInset"
        value: root.panelHeight + PanelService.panelGap
        when: root.sharesNotificationCorner
        restoreMode: Binding.RestoreValue
    }

    Binding {
        target: PanelService
        property: "drawerWidth"
        value: root.panelWidth
        when: root.sharesNotificationCorner
        restoreMode: Binding.RestoreValue
    }

    Binding {
        target: PanelService
        property: "drawerScreenName"
        value: root.screen?.name ?? ""
        when: root.sharesNotificationCorner
        restoreMode: Binding.RestoreValue
    }

    // The bar stays in scope so a click can move straight to another bar control.
    HyprlandFocusGrab {
        active: root.open && !PanelService.refocusing
        windows: [root, root.anchorWindow]
        onCleared: if (!PanelService.refocusing) root.closeRequested()
    }
}
