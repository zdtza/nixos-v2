// Passive status indicators for optional system states.
import QtQuick
import Quickshell.Services.Pipewire
import "../panels"
import "../services"

Item {
    id: root

    readonly property var nightLightPanel: nightLightControl
    // XDPH creates one of these PipeWire sources per active portal capture.
    readonly property var recordingNodes: Pipewire.nodes
        ? Pipewire.nodes.values.filter(node => node && node.ready
            && (node.name.startsWith("xdph-streaming-")
                || String(node.properties["media.name"] || "")
                    .startsWith("xdph-streaming-"))) : []
    readonly property bool recordingActive: recordingNodes.length > 0

    implicitWidth: indicators.implicitWidth
    implicitHeight: 26
    // RowLayout otherwise retains a spacing slot on both sides when every
    // collapsible toggle has zero width.
    visible: implicitWidth > 0

    Row {
        id: indicators
        anchors.verticalCenter: parent.verticalCenter

        QuickToggleSlot {
            shown: StayAwakeService.enabled

            QuickToggleButton {
                icon: "󰅶"
                active: true
                onClicked: StayAwakeService.toggle()
            }
        }

        QuickToggleSlot {
            shown: DoNotDisturbService.enabled

            QuickToggleButton {
                icon: "󰂛"
                active: true
                onClicked: DoNotDisturbService.toggle()
            }
        }

        QuickToggleSlot {
            shown: root.recordingActive

            ShellText {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -1
                text: ""
                color: Theme.base08
                size: 14
            }
        }

        QuickToggleSlot {
            shown: NightLightService.enabled

            QuickToggleButton {
                icon: ""
                iconSize: 12
                active: true
                onClicked: PanelService.toggle(nightLightControl)
            }
        }
    }

    // Retain the IPC-only panel without exposing a clickable bar control.
    NightLightTogglePanel {
        id: nightLightControl
        showButton: false
    }
}
