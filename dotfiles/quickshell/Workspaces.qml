// Hyprland workspace pills for one monitor. Click to switch.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Stylix
import Quickshell.Hyprland

RowLayout {
    id: root

    // Screen this widget belongs to; used to filter workspaces per monitor.
    property var screen: null

    readonly property var monitor: screen ? Hyprland.monitorFor(screen) : null
    readonly property var workspaces: Hyprland.workspaces.values
        .filter(ws => ws.id > 0 && (!root.monitor || ws.monitor === root.monitor))
        .sort((a, b) => a.id - b.id)

    spacing: 4

    Repeater {
        model: root.workspaces

        Rectangle {
            id: pill

            required property var modelData

            readonly property bool focused: modelData.focused
            readonly property bool occupied: modelData.toplevels.values.length > 0

            implicitWidth: pill.focused ? 26 : 18
            implicitHeight: 18
            radius: height / 2
            color: pill.focused ? Theme.accent : (pill.occupied ? Theme.surface : "transparent")
            border.width: pill.occupied || pill.focused ? 0 : 1
            border.color: Theme.border

            Behavior on implicitWidth {
                NumberAnimation {
                    duration: 120
                    easing.type: Easing.OutCubic
                }
            }

            Text {
                anchors.centerIn: parent
                text: pill.modelData.id
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                color: pill.focused ? Theme.background : (pill.occupied ? Theme.foreground : Theme.muted)
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Hyprland.dispatch(`workspace ${pill.modelData.id}`)
            }
        }
    }
}
