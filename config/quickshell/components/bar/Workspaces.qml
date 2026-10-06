pragma ComponentBehavior: Bound

// Workspace switcher and taskbar combined into one row. Every workspace uses
// one representative application slot, regardless of focus.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../primitives"
import "../../services"

Item {
    id: root

    property var screen: null

    readonly property var monitor: screen ? Hyprland.monitorFor(screen) : null
    readonly property string monitorName: String(monitor?.name ?? screen?.name ?? "")
    readonly property int activeWorkspaceId: Number(monitor?.activeWorkspace?.id ?? 0)

    // Show four slots by default, extending through the furthest active or
    // occupied workspace so there are no gaps before its icon.
    readonly property var monitorWorkspaces: Hyprland.workspaces.values
        .filter(workspace => workspace.id > 0
            && String(workspace.monitor?.name ?? "") === root.monitorName)
        .sort((a, b) => a.id - b.id)
    readonly property int firstWorkspaceId: monitorWorkspaces.length > 0
        ? monitorWorkspaces[0].id : 1
    readonly property int lastVisibleWorkspaceId: {
        let workspaceId = firstWorkspaceId + 3;
        if (activeWorkspaceId >= firstWorkspaceId)
            workspaceId = Math.max(workspaceId, activeWorkspaceId);
        for (const workspace of monitorWorkspaces) {
            if (root.tasksFor(workspace).length > 0)
                workspaceId = Math.max(workspaceId, workspace.id);
        }
        // A workspace an app is launching onto counts as occupied, even though
        // Hyprland drops it while empty and unfocused.
        for (const launch of Object.values(LauncherService.launches)) {
            if (launch.monitor === root.monitorName && launch.workspace >= firstWorkspaceId)
                workspaceId = Math.max(workspaceId, launch.workspace);
        }
        return workspaceId;
    }
    readonly property var workspaces: {
        const result = [];
        for (let id = firstWorkspaceId; id <= lastVisibleWorkspaceId; ++id) {
            const workspace = monitorWorkspaces.find(item => item.id === id);
            result.push(workspace ?? { id: id, toplevels: { values: [] } });
        }
        return result;
    }

    function isSteamPopup(toplevel: var): bool {
        const ipc = toplevel?.lastIpcObject ?? {};
        const steamClass = [ipc.class, ipc.initialClass, toplevel?.wayland?.appId]
            .some(value => String(value ?? "").toLowerCase() === "steam");
        return steamClass
            && String(toplevel?.title ?? "") === ""
            && String(ipc.title ?? "") === ""
            && String(ipc.initialTitle ?? "") === "";
    }

    function normalizedIdentifier(value: var): string {
        // Some applications use slightly different window and desktop-entry
        // identifiers (for example, "Audacity4" versus "Audacity 4").
        return String(value ?? "").toLowerCase().replace(/[^a-z0-9]/g, "");
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

        // Quickshell's heuristic requires punctuation and spacing to match.
        // Fall back to normalized equality against the metadata intended for
        // associating windows with desktop entries.
        const candidateKeys = candidates.map(
            value => root.normalizedIdentifier(value));
        for (const entry of DesktopEntries.applications.values) {
            const entryKeys = [entry.id, entry.name, entry.startupClass]
                .map(value => root.normalizedIdentifier(value))
                .filter(value => value !== "");
            if (candidateKeys.some(key => entryKeys.includes(key)))
                return entry;
        }
        return null;
    }

    function usable(toplevel: var): bool {
        return !!toplevel && !root.isSteamPopup(toplevel)
            && root.desktopEntry(toplevel) !== null;
    }

    // Match on each toplevel's own workspace: a refresh after a workspace swap
    // reassigns it but leaves it in the old workspace's toplevels list too.
    function tasksFor(workspace: var): var {
        return Hyprland.toplevels.values
            .filter(toplevel => toplevel.workspace?.id === workspace.id
                && root.usable(toplevel));
    }

    // Apps whose icon only represents a workspace when nothing else is on it,
    // most important first. Each lists its window classes; Chromium web apps
    // have their own classes, so they are not hidden with the browser.
    readonly property var unfavouredApps: [
        ["firefox"],
        ["chromium", "chromium-browser"],
        ["kitty"]
    ]

    // Position in unfavouredApps, or -1 for every other app.
    function unfavouredRank(toplevel: var): int {
        const ipc = toplevel?.lastIpcObject ?? {};
        const classes = [toplevel?.wayland?.appId, ipc.class, ipc.initialClass]
            .map(value => String(value ?? "").toLowerCase());
        return root.unfavouredApps.findIndex(
            appClasses => appClasses.some(appClass => classes.includes(appClass)));
    }

    function focusHistoryRank(toplevel: var): int {
        const rank = Number(toplevel?.lastIpcObject?.focusHistoryID);
        return Number.isFinite(rank) && rank >= 0 ? rank : 2147483647;
    }

    function representative(tasks: var): var {
        if (tasks.length === 0)
            return null;

        // Use the most recently used favoured application as the workspace
        // icon, falling back through the unfavoured apps in order.
        const bestRank = Math.min(...tasks.map(root.unfavouredRank));
        const candidates = tasks.filter(toplevel => root.unfavouredRank(toplevel) === bestRank);
        return candidates.reduce((best, toplevel) =>
            root.focusHistoryRank(toplevel) < root.focusHistoryRank(best)
                ? toplevel : best, candidates[0]);
    }

    function workspaceLabel(workspaceId: int): string {
        if (workspaceId === 10)
            return "0";
        return String(workspaceId);
    }

    function focusWorkspace(workspaceId: int): void {
        PanelService.closeActive();
        Hyprland.dispatch(Hyprland.usingLua
            ? `hl.dsp.focus({ workspace = ${workspaceId} })`
            : `workspace ${workspaceId}`);
    }

    // Workspace swaps renumber workspaces in place (changeworkspaceid), which
    // Quickshell doesn't track. Refetch once the burst of renumbers settles,
    // since refresh calls made while one is in flight are dropped.
    Connections {
        target: Hyprland
        function onRawEvent(event: var): void {
            if (event.name === "changeworkspaceid")
                renumberRefresh.restart();
        }
    }

    Timer {
        id: renumberRefresh
        interval: 50
        onTriggered: {
            Hyprland.refreshWorkspaces();
            Hyprland.refreshMonitors();
            Hyprland.refreshToplevels();
        }
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
                // An app launching onto this workspace takes over its slot until
                // its window opens.
                readonly property var launch: LauncherService.launchesOn(workspaceId)[0] ?? null
                readonly property var toplevel: launch ? null : root.representative(root.tasksFor(workspace))
                readonly property var entry: root.desktopEntry(toplevel)
                readonly property string iconName: launch ? launch.icon : (entry?.icon ?? "")

                // Keep workspace slots the same width whether empty or
                // occupied so opening/closing a window cannot shift them.
                // Full bar height, so the active underline sits on the bar's bottom edge.
                width: 26
                height: PanelService.barItemHeight
                clip: true

                HoverUnderline {
                    shown: workspaceGroup.active || taskMouse.containsMouse
                }

                Image {
                    id: appIcon

                    anchors.centerIn: parent
                    width: 17
                    height: 17
                    source: workspaceGroup.iconName !== ""
                        ? Quickshell.iconPath(workspaceGroup.iconName, true) : ""
                    sourceSize.width: 34
                    sourceSize.height: 34
                    asynchronous: true
                    visible: status === Image.Ready
                    opacity: workspaceGroup.launch ? 0.35 : 1
                }

                // Same look and shared rotation as the launcher row's spinner.
                Spinner {
                    anchors.centerIn: appIcon
                    size: 13
                    visible: !!workspaceGroup.launch
                    selfDriven: false
                    angle: LauncherService.spinnerAngle
                }

                ShellText {
                    anchors.centerIn: parent
                    // Compensate for the number glyph's visual right bias
                    // and lift it without moving the active underline.
                    anchors.horizontalCenterOffset: -1
                    anchors.verticalCenterOffset: 1
                    visible: !workspaceGroup.toplevel && !workspaceGroup.launch
                    text: root.workspaceLabel(workspaceGroup.workspaceId)
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
                        if (mouse.button === Qt.MiddleButton && workspaceGroup.toplevel) {
                            PanelService.closeActive();
                            workspaceGroup.toplevel.wayland?.close();
                        } else {
                            root.focusWorkspace(workspaceGroup.workspaceId);
                        }
                    }
                }
            }
        }
    }
}
