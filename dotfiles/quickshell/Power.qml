// System power actions shown beside clock.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Stylix

Item {
    id: root

    readonly property bool opened: PanelService.activePanel === root
    readonly property var actions: [
        { title: "SHUTDOWN", icon: "", iconSize: 22,
            action: "poweroff", available: true },
        { title: "REBOOT", icon: "󰜉", iconSize: 28,
            action: "reboot", available: true },
        { title: "SLEEP", icon: "󰒲", iconSize: 28,
            action: "suspend", available: true },
        { title: "LOCK", icon: "", iconSize: 21,
            action: "", available: false }
    ]

    implicitWidth: 28
    implicitHeight: 26

    function runAction(action: string): void {
        if (!action)
            return;
        PanelService.close(root);
        Quickshell.execDetached(["systemctl", action]);
    }

    BarButton {
        anchors.centerIn: parent
        panel: root
        text: ""
        onClicked: PanelService.toggle(root)
    }

    HyprlandFocusGrab {
        active: root.opened
        windows: [panel, root.QsWindow.window]
        onCleared: PanelService.close(root)
    }

    PanelPopup {
        id: panel

        anchorItem: root
        anchorWindow: root.QsWindow.window
        visible: root.opened
        onCloseRequested: PanelService.close(root)
        borderColor: Theme.border
        contentSpacing: 14
        implicitWidth: 240
        implicitHeight: panelContent.implicitHeight + contentMargins * 2

        PanelHero {
            width: parent.width
            icon: ""
            title: "Power"
            status: "SYSTEM OPTIONS"
        }

        PanelSeparator {}

        Grid {
            id: actionGrid

            width: parent.width
            columns: 2
            spacing: 10
            readonly property real cellWidth: (width - spacing) / 2

            Repeater {
                model: root.actions

                Rectangle {
                    id: actionButton
                    required property var modelData

                    width: actionGrid.cellWidth
                    height: 72
                    color: modelData.available && actionMouse.containsMouse
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
                        scale: actionMouse.containsMouse ? 1.1 : 1
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
                        onClicked: root.runAction(actionButton.modelData.action)
                    }
                }
            }
        }
    }
}
