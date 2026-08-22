// Optional controls beside the clock. Inactive controls collapse into the
// clock edge and slide out when the hidden area is hovered. Active controls
// remain visible on the right, with inactive controls ordered to their left.
import QtQuick
import Quickshell.Services.Pipewire
import Stylix

Item {
    id: root

    readonly property bool expanded: hover.hovered || timerToggle.opened
    // XDPH creates one of these PipeWire sources per active portal capture.
    readonly property var recordingNodes: Pipewire.nodes
        ? Pipewire.nodes.values.filter(node => node && node.ready
            && (node.name.startsWith("xdph-streaming-")
                || String(node.properties["media.name"] || "")
                    .startsWith("xdph-streaming-"))) : []
    readonly property bool recordingActive: recordingNodes.length > 0
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
        const states = [NightLightService.enabled, StayAwakeService.enabled,
            TimerService.running, recordingActive];
        const nextActive = [];
        const nextInactive = [];

        for (let index = 0; index < states.length; ++index) {
            if (states[index])
                nextActive.push(index);
            else
                nextInactive.push(index);
        }

        activeOrder = nextActive;
        inactiveOrder = nextInactive;
    }

    function toggleX(index: int): real {
        const order = inactiveOrder.concat(activeOrder);
        const slots = [nightLightSlot, stayAwakeSlot, timerSlot, recordingSlot];
        let x = 0;

        for (let position = 0; position < order.indexOf(index); ++position)
            x += slots[order[position]].width;

        return x;
    }

    Component.onCompleted: initializeToggleOrder()
    onRecordingActiveChanged: moveToggle(3, recordingActive)

    Connections {
        target: NightLightService
        function onEnabledChanged() {
            root.moveToggle(0, NightLightService.enabled);
        }
    }

    Connections {
        target: StayAwakeService
        function onEnabledChanged() {
            root.moveToggle(1, StayAwakeService.enabled);
        }
    }

    Connections {
        target: TimerService
        function onRunningChanged() {
            root.moveToggle(2, TimerService.running);
        }
    }

    // Preserve an invisible hover target when every toggle is inactive.
    implicitWidth: Math.max(28, viewport.implicitWidth)
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

        Behavior on opacity {
            NumberAnimation {
                duration: 160
                easing.type: Easing.OutCubic
            }
        }

        Item {
            id: buttons

            anchors.right: parent.right
            width: implicitWidth
            height: 26
            implicitWidth: nightLightSlot.width + stayAwakeSlot.width
                + timerSlot.width + recordingSlot.width

            Item {
                id: nightLightSlot

                x: root.toggleX(0)
                width: implicitWidth
                implicitWidth: root.expanded || NightLightService.enabled ? 28 : 0
                implicitHeight: 26
                clip: true

                Behavior on implicitWidth {
                    NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                }

                Item {
                    width: 28
                    height: 26
                    anchors.right: parent.right

                    Text {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: -1
                        text: "󰖔"
                        color: NightLightService.enabled ? Theme.foreground : Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: NightLightService.toggle()
                    }
                }
            }

            Item {
                id: stayAwakeSlot

                x: root.toggleX(1)
                width: implicitWidth
                implicitWidth: root.expanded || StayAwakeService.enabled ? 28 : 0
                implicitHeight: 26
                clip: true

                Behavior on implicitWidth {
                    NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                }

                Item {
                    width: 28
                    height: 26
                    anchors.right: parent.right

                    Text {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: -1
                        text: "󰅶"
                        color: StayAwakeService.enabled ? Theme.foreground : Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: StayAwakeService.toggle()
                    }
                }
            }

            Item {
                id: timerSlot

                x: root.toggleX(2)
                width: implicitWidth
                implicitWidth: root.expanded || TimerService.running ? 28 : 0
                implicitHeight: 26
                clip: true

                Behavior on implicitWidth {
                    NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                }

                TimerToggle {
                    id: timerToggle
                    anchors.right: parent.right
                }
            }

            Item {
                id: recordingSlot

                x: root.toggleX(3)
                width: implicitWidth
                implicitWidth: root.recordingActive ? 28 : 0
                implicitHeight: 26
                clip: true

                Behavior on implicitWidth {
                    NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                }

                Item {
                    width: 28
                    height: 26
                    anchors.right: parent.right

                    Text {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: -1
                        text: ""
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                    }
                }
            }
        }
    }
}
