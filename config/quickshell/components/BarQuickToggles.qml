// Optional controls beside the clock. Inactive controls collapse into the
// clock edge and slide out when the hidden area is hovered. Active controls
// remain visible on the right, with inactive controls ordered to their left.
import QtQuick
import Quickshell.Services.Pipewire
import Stylix
import "../panels"
import "../services"
import ".."

Item {
    id: root

    readonly property bool expanded: hover.hovered || nightLightToggle.opened
        || timerToggle.opened
    readonly property real fullTrayWidth: 28 * 4 + (recordingActive ? 28 : 0)
    readonly property var nightLightPanel: nightLightToggle
    readonly property var timerPanel: timerToggle
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
        const states = [ServiceNightLight.enabled, ServiceStayAwake.enabled,
            ServiceTimer.running, ServiceDoNotDisturb.enabled, recordingActive];
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
        const slots = [nightLightSlot, stayAwakeSlot, timerSlot, dndSlot,
            recordingSlot];
        let x = 0;

        for (let position = 0; position < order.indexOf(index); ++position)
            x += slots[order[position]].width;

        return x;
    }

    Component.onCompleted: initializeToggleOrder()
    onRecordingActiveChanged: moveToggle(4, recordingActive)

    Connections {
        target: ServiceNightLight
        function onEnabledChanged() {
            root.moveToggle(0, ServiceNightLight.enabled);
        }
    }

    Connections {
        target: ServiceStayAwake
        function onEnabledChanged() {
            root.moveToggle(1, ServiceStayAwake.enabled);
        }
    }

    Connections {
        target: ServiceTimer
        function onRunningChanged() {
            root.moveToggle(2, ServiceTimer.running);
        }
    }

    Connections {
        target: ServiceDoNotDisturb
        function onEnabledChanged() {
            root.moveToggle(3, ServiceDoNotDisturb.enabled);
        }
    }

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

        Behavior on opacity {
            NumberAnimation {
                duration: 120
                easing.type: Easing.OutCubic
            }
        }

        Item {
            id: buttons

            anchors.right: parent.right
            width: implicitWidth
            height: 26
            implicitWidth: nightLightSlot.width + stayAwakeSlot.width
                + timerSlot.width + dndSlot.width + recordingSlot.width

            Item {
                id: nightLightSlot

                x: root.toggleX(0)
                width: implicitWidth
                implicitWidth: root.expanded || ServiceNightLight.enabled ? 28 : 0
                implicitHeight: 26
                clip: true

                Behavior on implicitWidth {
                    NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                }

                PanelNightLightToggle {
                    id: nightLightToggle
                    anchors.right: parent.right
                }
            }

            Item {
                id: stayAwakeSlot

                x: root.toggleX(1)
                width: implicitWidth
                implicitWidth: root.expanded || ServiceStayAwake.enabled ? 28 : 0
                implicitHeight: 26
                clip: true

                Behavior on implicitWidth {
                    NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                }

                Item {
                    width: 28
                    height: 26
                    anchors.right: parent.right

                    Text {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: -1
                        text: "󰅶"
                        color: ServiceStayAwake.enabled ? Theme.foreground : Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: Utils.scaledFont(14)

                        Behavior on color { ColorAnimation { duration: 120 } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ServiceStayAwake.toggle()
                    }
                }
            }

            Item {
                id: timerSlot

                x: root.toggleX(2)
                width: implicitWidth
                // Running state is already surfaced by the badge next to the
                // clock, so this slot only reveals on hover rather than
                // staying pinned open while a timer counts down.
                implicitWidth: root.expanded ? 28 : 0
                implicitHeight: 26
                clip: true

                Behavior on implicitWidth {
                    NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                }

                PanelTimerToggle {
                    id: timerToggle
                    anchors.right: parent.right
                }
            }

            Item {
                id: dndSlot

                x: root.toggleX(3)
                width: implicitWidth
                implicitWidth: root.expanded || ServiceDoNotDisturb.enabled ? 28 : 0
                implicitHeight: 26
                clip: true

                Behavior on implicitWidth {
                    NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                }

                Item {
                    width: 28
                    height: 26
                    anchors.right: parent.right

                    Text {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: -1
                        text: "󰂛"
                        color: ServiceDoNotDisturb.enabled
                            ? Theme.foreground : Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: Utils.scaledFont(14)

                        Behavior on color { ColorAnimation { duration: 120 } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ServiceDoNotDisturb.toggle()
                    }
                }
            }

            Item {
                id: recordingSlot

                x: root.toggleX(4)
                width: implicitWidth
                implicitWidth: root.recordingActive ? 28 : 0
                implicitHeight: 26
                clip: true

                Behavior on implicitWidth {
                    NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
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
                        font.pixelSize: Utils.scaledFont(14)
                    }
                }
            }
        }
    }
}
