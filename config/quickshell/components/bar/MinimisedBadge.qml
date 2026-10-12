// Count of windows minimised on this bar's monitor, beside the workspaces.
import QtQuick
import Quickshell.Hyprland
import "../primitives"
import "../../services"
import "../.."

Item {
    id: root

    property var screen: null

    // Matches the per-monitor workspace minimise_window parks windows on
    // (config/hypr/hyprland.lua).
    readonly property string workspaceName: "special:minimised-"
        + String(Hyprland.monitorFor(screen)?.name ?? screen?.name ?? "")
    // Match on each toplevel's own workspace, which stays current when a
    // workspace's toplevels list goes stale.
    readonly property int count: Hyprland.toplevels.values
        .filter(toplevel => toplevel.workspace?.name === root.workspaceName).length
    readonly property bool active: count > 0
    // Last non-zero count, so the badge never shows 0 while it collapses.
    property int shownCount: 0
    onCountChanged: if (count > 0) shownCount = count
    Component.onCompleted: shownCount = count

    implicitWidth: active ? content.implicitWidth + 16 : 0
    // Full bar height so the pill centres on the bar like every other control.
    implicitHeight: PanelService.barItemHeight
    clip: true
    opacity: active ? 1 : 0

    Behavior on implicitWidth {
        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
    }

    Behavior on opacity {
        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
    }

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 20
        radius: height / 2
        color: Utils.alpha(Theme.base05, 0.1)
        border.width: 1
        border.color: Utils.alpha(Theme.base05, 0.3)
    }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 4

        ShellText {
            anchors.verticalCenter: parent.verticalCenter
            text: "󰖰"
            size: 11
        }

        ShellText {
            anchors.verticalCenter: parent.verticalCenter
            text: root.shownCount
            size: 11
            font.weight: Font.Medium
        }
    }
}
