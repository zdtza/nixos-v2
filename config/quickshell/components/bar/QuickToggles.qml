// Quick toggles: active ones stay visible as indicators, inactive ones slide
// out while the toggles' own area is hovered.
import QtQuick
import Quickshell.Services.Pipewire
import "../primitives"
import "../../services"

Item {
    id: root

    property var timerPanel: null
    property var nightLightPanel: null
    // Placed after the clock, so the row grows away from it towards the end.
    property bool mirrored: false
    readonly property bool hovered: hover.hovered
    property bool expanded: false

    // XDPH creates one of these PipeWire sources per active portal capture.
    readonly property var recordingNodes: Pipewire.nodes
        ? Pipewire.nodes.values.filter(node => node && node.ready
            && (node.name.startsWith("xdph-streaming-")
                || String(node.properties["media.name"] || "")
                    .startsWith("xdph-streaming-"))) : []
    readonly property bool recordingActive: recordingNodes.length > 0

    // Never narrower than one icon cell, so there is always a strip to hover even with every toggle off.
    implicitWidth: Math.max(PanelService.barIconWidth, toggles.implicitWidth)
    implicitHeight: PanelService.barItemHeight

    // A short grace period so crossing the gap between hotspot and toggles does not snap them shut.
    onHoveredChanged: {
        if (hovered) {
            collapseTimer.stop();
            expanded = true;
        } else {
            collapseTimer.restart();
        }
    }

    Timer {
        id: collapseTimer
        interval: 250
        onTriggered: root.expanded = false
    }

    HoverHandler {
        id: hover
    }

    // Anchored to the clock side, with the clock-most slots kept nearest it.
    Row {
        id: toggles

        anchors.right: root.mirrored ? undefined : parent.right
        anchors.left: root.mirrored ? parent.left : undefined
        layoutDirection: root.mirrored ? Qt.RightToLeft : Qt.LeftToRight
        anchors.verticalCenter: parent.verticalCenter

        QuickToggleSlot {
            gapBefore: !root.mirrored
            shown: StayAwakeService.active || root.expanded

            QuickToggleButton {
                icon: "󰅶"
                active: StayAwakeService.active
                inactiveColor: Theme.textMuted
                onClicked: StayAwakeService.toggle()
            }
        }

        QuickToggleSlot {
            gapBefore: !root.mirrored
            shown: DoNotDisturbService.active || root.expanded

            QuickToggleButton {
                icon: "󰂛"
                active: DoNotDisturbService.active
                inactiveColor: Theme.textMuted
                onClicked: DoNotDisturbService.toggle()
            }
        }

        QuickToggleSlot {
            gapBefore: !root.mirrored
            shown: NightLightService.active || root.expanded

            QuickToggleButton {
                icon: "󰖔"
                active: NightLightService.active
                inactiveColor: Theme.textMuted
                onClicked: PanelService.toggle(root.nightLightPanel)
            }
        }

        // The countdown itself shows on the clock's right.
        QuickToggleSlot {
            gapBefore: !root.mirrored
            shown: TimerService.running || root.expanded

            QuickToggleButton {
                icon: "󱎫"
                active: TimerService.running
                inactiveColor: Theme.textMuted
                onClicked: PanelService.toggle(root.timerPanel)
            }
        }

        QuickToggleSlot {
            gapBefore: !root.mirrored
            shown: root.recordingActive

            ShellText {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -1
                text: ""
                color: Theme.textPrimary
                size: 14
            }
        }
    }
}
