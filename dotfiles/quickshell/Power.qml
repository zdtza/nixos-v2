// System power actions shown beside clock.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Stylix

Item {
    id: root

    readonly property bool opened: PanelService.activePanel === root
    readonly property bool requiresKeyboardFocus: false
    property int phraseIndex: 0
    property int selectedActionIndex: 0
    readonly property var phrases: [
        "Don't forget to save your work.",
        "Make sure to close all applications.",
        "Remember to backup important files.",
        "Check for any unsaved documents.",
    ]
    readonly property var actions: [
        { title: "LOCK", icon: "󰌾", iconSize: 24,
            action: "lock", available: true },
        { title: "SHUTDOWN", icon: "", iconSize: 22,
            action: "poweroff", available: true },
        { title: "REBOOT", icon: "󰜉", iconSize: 28,
            action: "reboot", available: true },
        { title: "SLEEP", icon: "󰒲", iconSize: 28,
            action: "suspend", available: true }
    ]

    implicitWidth: 28
    implicitHeight: 26

    onOpenedChanged: if (opened) {
        phraseIndex = 0;
        selectedActionIndex = 0;
    }

    function moveSelection(offset: int): void {
        selectedActionIndex = Math.max(0,
            Math.min(actions.length - 1, selectedActionIndex + offset));
    }

    function activateSelection(): void {
        const action = actions[selectedActionIndex];
        if (action?.available)
            runAction(action.action);
    }

    Shortcut {
        enabled: root.opened
        sequence: "Left"
        context: Qt.ApplicationShortcut
        onActivated: root.moveSelection(-1)
    }
    Shortcut {
        enabled: root.opened
        sequence: "Up"
        context: Qt.ApplicationShortcut
        onActivated: root.moveSelection(-1)
    }
    Shortcut {
        enabled: root.opened
        sequence: "Right"
        context: Qt.ApplicationShortcut
        onActivated: root.moveSelection(1)
    }
    Shortcut {
        enabled: root.opened
        sequence: "Down"
        context: Qt.ApplicationShortcut
        onActivated: root.moveSelection(1)
    }
    Shortcut {
        enabled: root.opened
        sequence: "Return"
        context: Qt.ApplicationShortcut
        onActivated: root.activateSelection()
    }
    Shortcut {
        enabled: root.opened
        sequence: "Enter"
        context: Qt.ApplicationShortcut
        onActivated: root.activateSelection()
    }

    function runAction(action: string): void {
        if (!action)
            return;
        PanelService.close(root);
        if (action === "lock")
            Quickshell.execDetached(["qs", "ipc", "call", "lock", "activate"]);
        else
            Quickshell.execDetached(["systemctl", action]);
    }

    PanelStatusRotator {
        target: powerHero.statusLabel
        running: root.opened
        onAdvance: root.phraseIndex = (root.phraseIndex + 1) % root.phrases.length
    }

    BarButton {
        anchors.centerIn: parent
        panel: root
        text: ""
        onClicked: PanelService.toggle(root)
    }

    PanelPopup {
        id: panel

        anchorItem: root
        anchorWindow: root.QsWindow.window
        visible: root.opened
        onCloseRequested: PanelService.close(root)
        borderColor: Theme.border
        contentSpacing: 14
        implicitWidth: 360
        implicitHeight: panelContent.implicitHeight + contentMargins * 2

        PanelHero {
            id: powerHero
            width: parent.width
            icon: ""
            title: "Power"
            status: root.phrases[root.phraseIndex % root.phrases.length].toUpperCase()
        }

        PanelSeparator {}

        Grid {
            id: actionGrid

            width: parent.width
            columns: 4
            spacing: 10
            readonly property real cellWidth: (width - spacing * (columns - 1)) / columns

            Repeater {
                model: root.actions

                Rectangle {
                    id: actionButton
                    required property var modelData
                    required property int index

                    width: actionGrid.cellWidth
                    height: 50
                    color: modelData.available
                        && (actionButton.index === root.selectedActionIndex || actionMouse.containsMouse)
                        ? Qt.rgba(Theme.foreground.r, Theme.foreground.g,
                            Theme.foreground.b, 0.12)
                        : "transparent"
                    Behavior on color { ColorAnimation { duration: 140 } }

                    Text {
                        anchors.centerIn: parent
                        text: actionButton.modelData.icon
                        color: actionButton.modelData.available
                            ? Theme.foreground : Theme.muted
                        opacity: actionButton.modelData.available ? 1 : 0.45
                        scale: actionButton.index === root.selectedActionIndex
                            || actionMouse.containsMouse ? 1.1 : 1
                        font.family: Theme.fontFamily
                        font.pixelSize: actionButton.modelData.iconSize
                        Behavior on scale {
                            NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                        }
                    }

                    MouseArea {
                        id: actionMouse
                        anchors.fill: parent
                        enabled: actionButton.modelData.available
                        hoverEnabled: true
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            root.selectedActionIndex = actionButton.index;
                            root.runAction(actionButton.modelData.action);
                        }
                    }
                }
            }
        }
    }
}
