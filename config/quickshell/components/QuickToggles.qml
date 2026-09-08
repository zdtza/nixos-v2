// Optional controls beside the clock. Inactive controls collapse into the
// clock edge and appear when the hidden area is hovered. Active controls
// remain visible on the right, with inactive controls ordered to their left.
import QtQuick
import Quickshell.Services.Pipewire
import "../panels"
import "../services"

Item {
    id: root

    readonly property bool expanded: hover.hovered || nightLightToggle.opened
        || timerToggle.opened
    readonly property real fullTrayWidth: 28 * 5 + (recordingActive ? 28 : 0)
    readonly property var nightLightPanel: nightLightToggle
    readonly property var timerPanel: timerToggle
    // XDPH creates one of these PipeWire sources per active portal capture.
    readonly property var recordingNodes: Pipewire.nodes
        ? Pipewire.nodes.values.filter(node => node && node.ready
            && (node.name.startsWith("xdph-streaming-")
                || String(node.properties["media.name"] || "")
                    .startsWith("xdph-streaming-"))) : []
    readonly property bool recordingActive: recordingNodes.length > 0

    // Active-state of every slot, in slot declaration order. A slot's index
    // here is its identity for the ordering below and for toggleX().
    readonly property var toggleStates: [
        NightLightService.enabled,
        StayAwakeService.enabled,
        TimerService.running,
        DoNotDisturbService.enabled,
        recordingActive,
        VoiceDictationService.active
    ]
    // Last states the ordering was built from, so a change can be narrowed to
    // the slots that actually flipped.
    property var appliedStates: []
    property var activeOrder: []
    property var inactiveOrder: []

    function moveToggle(index: int, active: bool): void {
        const nextActive = activeOrder.filter(candidate => candidate !== index);
        const nextInactive = inactiveOrder.filter(candidate => candidate !== index);

        if (active)
            nextActive.unshift(index);
        else
            nextInactive.push(index);

        activeOrder = nextActive;
        inactiveOrder = nextInactive;
    }

    function initializeToggleOrder(): void {
        const nextActive = [];
        const nextInactive = [];

        for (let index = 0; index < toggleStates.length; ++index) {
            if (toggleStates[index])
                nextActive.push(index);
            else
                nextInactive.push(index);
        }

        activeOrder = nextActive;
        inactiveOrder = nextInactive;
        appliedStates = toggleStates.slice();
    }

    // One handler on the states array replaces a Connections block per
    // service: whichever slots flipped since the last pass get re-ordered.
    function syncToggleOrder(): void {
        for (let index = 0; index < toggleStates.length; ++index) {
            if (appliedStates[index] !== toggleStates[index])
                moveToggle(index, toggleStates[index]);
        }
        appliedStates = toggleStates.slice();
    }

    function toggleX(index: int): real {
        const order = inactiveOrder.concat(activeOrder);
        const slots = [nightLightSlot, stayAwakeSlot, timerSlot, dndSlot,
            recordingSlot, dictationSlot];
        let x = 0;

        for (let position = 0; position < order.indexOf(index); ++position)
            x += slots[order[position]].width;

        return x;
    }

    Component.onCompleted: initializeToggleOrder()
    // Guarded so the first evaluation (which fires before onCompleted) can't
    // re-order against an empty baseline.
    onToggleStatesChanged: if (appliedStates.length > 0) syncToggleOrder()

    // Reserve hover space for every toggle, including collapsed controls, so
    // entering anywhere the expanded tray occupies reveals the full tray.
    implicitWidth: root.fullTrayWidth
    implicitHeight: 26

    HoverHandler {
        id: hover
    }

    Item {
        id: viewport

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        clip: true

        implicitWidth: buttons.implicitWidth
        implicitHeight: 26
        opacity: implicitWidth > 0 ? 1 : 0

        Item {
            id: buttons

            anchors.right: parent.right
            width: implicitWidth
            height: 26
            implicitWidth: nightLightSlot.width + stayAwakeSlot.width
                + timerSlot.width + dndSlot.width + recordingSlot.width
                + dictationSlot.width

            QuickToggleSlot {
                id: nightLightSlot
                x: root.toggleX(0)
                shown: root.expanded || NightLightService.enabled

                NightLightTogglePanel { id: nightLightToggle }
            }

            QuickToggleSlot {
                id: stayAwakeSlot
                x: root.toggleX(1)
                shown: root.expanded || StayAwakeService.enabled

                QuickToggleButton {
                    icon: "󰅶"
                    active: StayAwakeService.enabled
                    onClicked: StayAwakeService.toggle()
                }
            }

            QuickToggleSlot {
                id: timerSlot
                x: root.toggleX(2)
                // Running state is already surfaced by the badge next to the
                // clock, so this slot only reveals on hover rather than
                // staying pinned open while a timer counts down.
                shown: root.expanded

                TimerTogglePanel { id: timerToggle }
            }

            QuickToggleSlot {
                id: dndSlot
                x: root.toggleX(3)
                shown: root.expanded || DoNotDisturbService.enabled

                QuickToggleButton {
                    icon: "󰂛"
                    active: DoNotDisturbService.enabled
                    onClicked: DoNotDisturbService.toggle()
                }
            }

            QuickToggleSlot {
                id: recordingSlot
                x: root.toggleX(4)
                shown: root.recordingActive

                QuickToggleButton {
                    icon: ""
                    active: true
                    activeColor: Theme.base08
                    interactive: false
                }
            }

            QuickToggleSlot {
                id: dictationSlot
                x: root.toggleX(5)
                shown: root.expanded || VoiceDictationService.active

                QuickToggleButton {
                    icon: ""
                    active: VoiceDictationService.active
                    onClicked: VoiceDictationService.toggle()
                }
            }
        }
    }
}
