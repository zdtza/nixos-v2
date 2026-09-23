import Quickshell.Wayland
import "../services"

// Centered floating panel used by the clock.
ShellSurface {
    anchors.top: PanelService.barAtTop
    anchors.bottom: !PanelService.barAtTop

    WlrLayershell.namespace: "quickshell:center-panel"
}
