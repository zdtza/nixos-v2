pragma ComponentBehavior: Bound

// Workspace switcher and taskbar combined into one row. Every workspace uses
// one representative application slot, regardless of focus.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../services"

Item {
    id: root

    property var screen: null

    readonly property var monitor: screen ? Hyprland.monitorFor(screen) : null
    readonly property string monitorName: String(monitor?.name ?? screen?.name ?? "")
    readonly property int activeWorkspaceId: Number(monitor?.activeWorkspace?.id ?? 0)

    // Persistent workspace rules keep empty assigned workspaces in Hyprland's
    // IPC model. Treat each monitor's sorted list independently so its first
    // three slots are always visible, then reveal every slot through the active
    // workspace when it lies beyond those defaults.
    readonly property var monitorWorkspaces: Hyprland.workspaces.values
        .filter(workspace => workspace.id > 0
            && String(workspace.monitor?.name ?? "") === root.monitorName)
        .sort((a, b) => a.id - b.id)
    readonly property int activeWorkspaceIndex: monitorWorkspaces
        .findIndex(workspace => workspace.id === root.activeWorkspaceId)
    readonly property var workspaces: monitorWorkspaces.slice(0,
        Math.max(3, activeWorkspaceIndex + 1))

    function isSteamPopup(toplevel: var): bool {
        const ipc = toplevel?.lastIpcObject ?? {};
        const steamClass = [ipc.class, ipc.initialClass, toplevel?.wayland?.appId]
            .some(value => String(value ?? "").toLowerCase() === "steam");
        return steamClass
            && String(toplevel?.title ?? "") === ""
            && String(ipc.title ?? "") === ""
            && String(ipc.initialTitle ?? "") === "";
    }

    function desktopEntry(toplevel: var): var {
        if (!toplevel)
            return null;
        const ipc = toplevel.lastIpcObject ?? {};
        const candidates = [toplevel.wayland?.appId, ipc.class, ipc.initialClass]
            .map(value => String(value ?? ""))
            .filter(value => value !== "");
        for (const candidate of candidates) {
            const entry = DesktopEntries.heuristicLookup(candidate);
            if (entry)
                return entry;
        }
        return null;
    }

    function usable(toplevel: var): bool {
        return !!toplevel && !root.isSteamPopup(toplevel)
            && root.desktopEntry(toplevel) !== null;
    }

    function tasksFor(workspace: var): var {
        // Keep terminals at the end while preserving compositor order within
        // the application and terminal groups.
        return workspace.toplevels.values
            .filter(toplevel => root.usable(toplevel))
            .sort((a, b) => Number(root.isKitty(a)) - Number(root.isKitty(b)));
    }

    function isKitty(toplevel: var): bool {
        const ipc = toplevel?.lastIpcObject ?? {};
        return [toplevel?.wayland?.appId, ipc.class, ipc.initialClass]
            .some(value => String(value ?? "").toLowerCase() === "kitty");
    }

    function representative(tasks: var): var {
        if (tasks.length === 0)
            return null;

        // A terminal may represent a workspace only when every logical task is
        // a terminal.
        const applications = tasks.filter(toplevel => !root.isKitty(toplevel));
        return applications.length > 0 ? applications[0] : tasks[0];
    }

    function focusWorkspace(workspaceId: int): void {
        PanelService.closeActive();
        Hyprland.dispatch(Hyprland.usingLua
            ? `hl.dsp.focus({ workspace = ${workspaceId} })`
            : `workspace ${workspaceId}`);
    }

    implicitWidth: workspaceRow.implicitWidth
    implicitHeight: workspaceRow.implicitHeight

    Row {
        id: workspaceRow

        anchors.centerIn: parent
        spacing: 2

        Repeater {
            model: root.workspaces

            Item {
                id: workspaceGroup

                required property var modelData
                readonly property var workspace: modelData
                readonly property int workspaceId: workspace.id
                readonly property bool active: workspaceId === root.activeWorkspaceId
                readonly property var tasks: root.tasksFor(workspace)
                readonly property var primary: root.representative(tasks)
                readonly property var displayedTasks: [primary]

                width: tasksRow.implicitWidth
                // Keep all workspace slots at icon-row height; smaller empty
                // indicators are centered in this space instead of top-aligned.
                height: 26
                implicitWidth: width
                implicitHeight: height
                clip: true

                Row {
                    id: tasksRow

                    anchors {
                        left: parent.left
                        verticalCenter: parent.verticalCenter
                        // Bias empty indicators down three pixels so their active
                        // underline aligns with occupied workspaces.
                        verticalCenterOffset: workspaceGroup.primary ? 0 : 3
                    }
                    spacing: 2

                    Repeater {
                    model: workspaceGroup.displayedTasks

                    Rectangle {
                        id: taskButton

                        required property var modelData
                        readonly property var toplevel: modelData
                        readonly property var entry: root.desktopEntry(toplevel)
                        readonly property bool urgent: !!toplevel && toplevel.urgent

                        // Keep workspace slots the same width whether empty or
                        // occupied so opening/closing a window cannot shift them.
                        width: 26
                        height: taskButton.toplevel ? 26
                            : Math.max(workspaceNumber.implicitWidth + 12,
                                workspaceNumber.implicitHeight + 2)
                        radius: 4
                        color: "transparent"
                        border.width: urgent ? 1 : 0
                        border.color: Theme.base08

                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: Math.min(16, parent.width)
                            height: 2
                            radius: PanelService.rounding
                            visible: opacity > 0
                            opacity: workspaceGroup.active || taskMouse.containsMouse ? 1 : 0
                            color: Theme.base05

                            Behavior on opacity { NumberAnimation { duration: 120 } }
                        }

                        Image {
                            id: appIcon

                            anchors.centerIn: parent
                            width: 17
                            height: 17
                            source: taskButton.entry
                                ? Quickshell.iconPath(taskButton.entry.icon, true) : ""
                            sourceSize.width: 34
                            sourceSize.height: 34
                            cache: true
                            asynchronous: true
                            smooth: true
                            visible: !!taskButton.toplevel && status === Image.Ready
                        }

                        ShellText {
                            id: workspaceNumber

                            anchors.centerIn: parent
                            // Compensate for the number glyph's visual right bias
                            // and lift it without moving the active underline.
                            anchors.horizontalCenterOffset: -1
                            anchors.verticalCenterOffset: -2
                            visible: !taskButton.toplevel
                            text: workspaceGroup.workspaceId
                            color: Theme.textSecondary
                            size: Theme.fontSize
                        }

                        MouseArea {
                            id: taskMouse

                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onClicked: mouse => {
                                PanelService.closeActive();

                                if (!taskButton.toplevel) {
                                    root.focusWorkspace(workspaceGroup.workspaceId);
                                    return;
                                }

                                if (mouse.button === Qt.MiddleButton)
                                    taskButton.toplevel.wayland?.close();
                                else
                                    root.focusWorkspace(workspaceGroup.workspaceId);
                            }
                        }
                    }
                }
            }
            }
        }
    }
}
