pragma ComponentBehavior: Bound

// Count of windows minimised on this bar's monitor, beside the workspaces.
// Hovering expands it into one icon per window; clicking an icon restores it.
import QtQuick
import Quickshell
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
    readonly property var windows: Hyprland.toplevels.values
        .filter(toplevel => toplevel.workspace?.name === root.workspaceName)
    readonly property int count: windows.length
    readonly property bool active: count > 0
    // Last non-zero count, so the badge never shows 0 while it collapses.
    property int shownCount: 0
    onCountChanged: if (count > 0) shownCount = count
    Component.onCompleted: shownCount = count
    readonly property bool expanded: active && hover.hovered

    // Moves a window onto this monitor's active workspace, which also focuses it.
    function restore(toplevel: var): void {
        const workspaceId = Number(Hyprland.monitorFor(screen)?.activeWorkspace?.id ?? 0);
        const raw = String(toplevel?.address ?? "");
        if (workspaceId === 0 || raw === "")
            return;
        const address = raw.startsWith("0x") ? raw : "0x" + raw;
        PanelService.closeActive();
        Hyprland.dispatch(Hyprland.usingLua
            ? `hl.dsp.window.move({ workspace = ${workspaceId}, window = "address:${address}" })`
            : `movetoworkspace ${workspaceId},address:${address}`);
    }

    implicitWidth: active ? content.implicitWidth + 16 : 0
    // Full bar height so the pill centres on the bar like every other control.
    implicitHeight: PanelService.barItemHeight
    clip: true
    opacity: active ? 1 : 0

    HoverHandler {
        id: hover
    }

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
            visible: !root.expanded
            text: root.shownCount
            size: 11
            font.weight: Font.Medium
        }

        Repeater {
            model: root.expanded ? root.windows : []

            Item {
                id: windowSlot

                required property var modelData
                readonly property var entry: Utils.desktopEntry(modelData)
                readonly property string iconName: entry?.icon
                    || String(modelData.wayland?.appId ?? modelData.lastIpcObject?.class ?? "")

                anchors.verticalCenter: parent.verticalCenter
                width: 18
                height: 18

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: Utils.alpha(Theme.base05, slotMouse.containsMouse ? 0.15 : 0)
                }

                Image {
                    anchors.centerIn: parent
                    width: 14
                    height: 14
                    source: Quickshell.iconPath(windowSlot.iconName, "application-x-executable")
                    sourceSize.width: 28
                    sourceSize.height: 28
                    asynchronous: true
                }

                MouseArea {
                    id: slotMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.restore(windowSlot.modelData)
                }
            }
        }
    }
}
