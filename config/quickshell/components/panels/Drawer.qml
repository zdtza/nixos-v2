import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../../services"

// Floating drawer used by bar panels. Opens while its anchorItem is
// PanelService's active panel; Escape or a click outside closes it.
ShellSurface {
    id: root

    // Bar items (see BarConfig) this panel belongs to; the first one shown
    // decides whether it opens at the start, centre or end of the screen.
    property var barItems: []
    property string fallbackAlignment: "end"
    // Set to pin the drawer regardless of the bar layout.
    property string fixedAlignment: ""
    readonly property string alignment: fixedAlignment !== "" ? fixedAlignment
        : BarConfig.alignmentFor(barItems, fallbackAlignment)
    readonly property bool alignedStart: alignment === "start"
    readonly property bool alignedEnd: alignment === "end"
    property bool centeredVertically: false

    anchorWindow: anchorItem.QsWindow.window
    open: PanelService.activePanel === anchorItem
    onCloseRequested: PanelService.close(anchorItem)

    anchors {
        top: !centeredVertically && PanelService.barAtTop
        bottom: !centeredVertically && !PanelService.barAtTop
        left: alignedStart
        right: alignedEnd
    }

    // The card sits panelGap clear of the bar and of the screen edge it is
    // aligned to. The shadow fills that gap but stops at the bar and at the
    // screen edge, and only grows away from the bar as far as the screen allows.
    readonly property real cardBarInset: PanelService.panelBarInset + PanelService.panelGap
    readonly property real cardEdgeInset: PanelService.panelGap
    readonly property real farEdgeRoom: Math.max(0,
        (screen?.height ?? 800) - cardBarInset - panelHeight)

    shadowTop: centeredVertically ? Theme.shadowExtent
        : PanelService.barAtTop ? PanelService.panelGap : Math.min(Theme.shadowExtent, farEdgeRoom)
    shadowBottom: centeredVertically ? Theme.shadowExtent
        : PanelService.barAtTop ? Math.min(Theme.shadowExtent, farEdgeRoom) : PanelService.panelGap
    shadowLeft: alignedStart ? cardEdgeInset : Theme.shadowExtent
    shadowRight: alignedEnd ? cardEdgeInset : Theme.shadowExtent

    margins.top: !centeredVertically && PanelService.barAtTop
        ? cardBarInset - shadowTop : 0
    margins.bottom: !centeredVertically && !PanelService.barAtTop
        ? cardBarInset - shadowBottom : 0

    margins.left: alignedStart ? cardEdgeInset - shadowLeft : 0
    margins.right: alignedEnd ? cardEdgeInset - shadowRight : 0

    WlrLayershell.namespace: "quickshell:panel-drawer"

    // Notifications stack in the end corner, beneath an end-aligned drawer.
    readonly property bool sharesNotificationCorner: open
        && alignedEnd && !centeredVertically

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
