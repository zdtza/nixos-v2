// Optional controls in the bar's right-hand group.
import QtQuick
import Quickshell.Services.Pipewire
import "../panels"
import "../services"

Item {
    id: root

    readonly property bool expanded: hover.hovered || nightLightToggle.opened
        || timerToggle.opened
    readonly property var nightLightPanel: nightLightToggle
    readonly property var timerPanel: timerToggle
    // XDPH creates one of these PipeWire sources per active portal capture.
    readonly property var recordingNodes: Pipewire.nodes
        ? Pipewire.nodes.values.filter(node => node && node.ready
            && (node.name.startsWith("xdph-streaming-")
                || String(node.properties["media.name"] || "")
                    .startsWith("xdph-streaming-"))) : []
    readonly property bool recordingActive: recordingNodes.length > 0

    // Reserve hover space for every toggle, including collapsed controls, so entering anywhere the expanded tray occupies reveals the full tray.
    implicitWidth: 28 * 4 + (recordingActive ? 28 : 0)
    implicitHeight: 26

    HoverHandler {
        id: hover
    }

    // Right-anchored: collapsed slots take no width, so the visible controls always sit against the right edge of the reserved strip.
    Row {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter

        QuickToggleSlot {
            shown: root.expanded || StayAwakeService.enabled

            QuickToggleButton {
                icon: "󰅶"
                active: StayAwakeService.enabled
                onClicked: StayAwakeService.toggle()
            }
        }

        QuickToggleSlot {
            shown: root.expanded || DoNotDisturbService.enabled

            QuickToggleButton {
                icon: "󰂛"
                active: DoNotDisturbService.enabled
                onClicked: DoNotDisturbService.toggle()
            }
        }

        QuickToggleSlot {
            // The clock badge already shows timer activity.
            shown: root.expanded

            TimerTogglePanel { id: timerToggle }
        }

        // Passive indicator, not a control: it only exists while something is capturing the screen through the portal.
        QuickToggleSlot {
            shown: root.recordingActive

            QuickToggleButton {
                icon: ""
                active: true
                activeColor: Theme.base08
                interactive: false
            }
        }

        QuickToggleSlot {
            shown: root.expanded || NightLightService.enabled

            NightLightTogglePanel { id: nightLightToggle }
        }
    }
}
