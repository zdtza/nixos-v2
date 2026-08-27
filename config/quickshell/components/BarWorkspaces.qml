pragma ComponentBehavior: Bound

// Hyprland workspace indicators for one monitor. Click to switch.
//
// Shows the first `minVisible` workspaces of the monitor at all times, plus any
// higher one that is active, occupied or urgent - so the bar stays compact
// until the extra workspaces get used.
//
// Styling: only the active workspace gets a border; text is foreground when
// active or occupied, muted otherwise.
import QtQuick
import Quickshell
import Stylix
import Quickshell.Hyprland
import "../services"
import ".."

Item {
    id: root

    // Screen this widget belongs to; workspaces are filtered to it.
    property var screen: null

    // How many workspaces are always shown, even when empty.
    // five gives a nice balanace for both sides of the bar
    property int minVisible: 3

    readonly property var monitor: screen ? Hyprland.monitorFor(screen) : null
    readonly property string monitorName: monitor ? monitor.name : (screen ? screen.name : "")

    // Active workspace of *this* monitor, not the globally focused one.
    readonly property int activeWorkspaceId: root.monitor?.activeWorkspace?.id ?? 0

    // All workspaces assigned to this monitor, lowest id first.
    readonly property var monitorWorkspaces: Hyprland.workspaces.values
        .filter(ws => ws.id > 0 && (root.monitorName === "" || ws.monitor?.name === root.monitorName))
        .sort((a, b) => a.id - b.id)

    readonly property var workspaces: root.monitorWorkspaces.filter((ws, index) => index < root.minVisible || ws.id === root.activeWorkspaceId || ws.urgent || ws.toplevels.values.length > 0)

    implicitWidth: workspaceRow.implicitWidth
    implicitHeight: workspaceRow.implicitHeight

    Row {
        id: workspaceRow

        anchors.centerIn: parent
        spacing: 4

        Repeater {
            model: root.workspaces

            Rectangle {
                id: workspaceItem

                required property var modelData

                readonly property int workspaceId: modelData.id
                readonly property bool isActive: root.activeWorkspaceId === workspaceId
                readonly property bool isOccupied: modelData.toplevels.values.length > 0

                width: workspaceNumber.implicitWidth + 12
                height: workspaceNumber.implicitHeight + 2

                color: "transparent"
                radius: 4

                border.width: workspaceItem.isActive ? 1 : 0
                border.color: Theme.foreground

                Text {
                    id: workspaceNumber

                    anchors.centerIn: parent
                    text: workspaceItem.workspaceId
                    color: workspaceItem.isActive || workspaceItem.isOccupied ? Theme.foreground : Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: Utils.scaledFont(Theme.fontSize)
                }

                MouseArea {
                    id: mouseArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    // The lua config backend takes lua expressions, not the
                    // classic `workspace N` dispatcher string.
                    onClicked: {
                        ServicePanel.closeActive();
                        Hyprland.dispatch(Hyprland.usingLua ? `hl.dsp.focus({ workspace = ${workspaceItem.workspaceId} })` : `workspace ${workspaceItem.workspaceId}`);
                    }
                }
            }
        }
    }
}
