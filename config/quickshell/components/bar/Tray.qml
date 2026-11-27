pragma ComponentBehavior: Bound

// System tray, collapsed behind a left-facing chevron.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import "../panels"
import "../../services"
import "../.."

Item {
    id: root

    property var screen: null
    readonly property var items: SystemTray.items.values
    // Matches the per-monitor workspace minimise_window parks windows on
    // (config/hypr/hyprland.lua).
    readonly property string minimisedWorkspace: "special:minimised-"
        + String(Hyprland.monitorFor(screen)?.name ?? screen?.name ?? "")
    // Match on each toplevel's own workspace, which stays current when a
    // workspace's toplevels list goes stale.
    readonly property var minimised: Hyprland.toplevels.values
        .filter(toplevel => toplevel.workspace?.name === root.minimisedWorkspace)
    // Keyboard order: tray items, then minimised windows, then Windows.
    readonly property int windowsIndex: items.length + minimised.length
    readonly property bool opened: PanelService.activePanel === root
    readonly property bool requiresKeyboardFocus: true
    property bool pinned: false
    property int selectedItemIndex: 0
    readonly property int keyboardItemCount: windowsIndex + (WindowsService.running ? 1 : 0)
    readonly property bool expanded: root.pinned || hover.hovered || root.opened

    // Normalizes Windows' plain action list to the same shape as a real DBus menu's entries, so TrayMenu can render either.
    readonly property var windowsMenuEntries: WindowsService.actions.map(action => ({
        text: action.label,
        isSeparator: false,
        enabled: true,
        hasChildren: false,
        checkState: Qt.Unchecked,
        triggered: () => action.triggered()
    }))

    // Which of the two menu loaders the open panel belongs to.
    property bool windowsMenuOpen: false

    onOpenedChanged: {
        if (!opened)
            dismissMenu();
        else
            selectedItemIndex = Math.max(0,
                Math.min(keyboardItemCount - 1, selectedItemIndex));
    }

    function dismissMenu(): void {
        windowsMenuOpen = false;
        menuLoader.trayItem = null;
        menuLoader.anchorItem = null;
    }

    function showItemMenu(item: var, entry: Item): void {
        windowsMenuOpen = false;
        menuLoader.trayItem = item;
        menuLoader.anchorItem = entry;
    }

    function showWindowsMenu(): void {
        dismissMenu();
        windowsMenuOpen = true;
    }

    // Moves a minimised window onto this monitor's active workspace, which also focuses it.
    function restore(toplevel: var): void {
        const workspaceId = Number(Hyprland.monitorFor(screen)?.activeWorkspace?.id ?? 0);
        const raw = String(toplevel?.address ?? "");
        if (workspaceId === 0 || raw === "")
            return;
        const address = raw.startsWith("0x") ? raw : "0x" + raw;
        PanelService.close(root);
        Hyprland.dispatch(Hyprland.usingLua
            ? `hl.dsp.window.move({ workspace = ${workspaceId}, window = "address:${address}" })`
            : `movetoworkspace ${workspaceId},address:${address}`);
    }

    function toggleFromIpc(): void {
        const closing = PanelService.activePanel === root
            || PanelService.pendingPanel === root;
        PanelService.toggle(root);
        if (!closing && keyboardItemCount > 0) {
            selectedItemIndex = 0;
            cycleSelection(0);
        }
    }

    // Escape always leaves the tray entirely: the open menu (and any submenu chain under it) plus the tray itself, in one press.
    function collapseTray(): void {
        pinned = false;
        dismissMenu();
        PanelService.close(root);
    }

    function moveSelection(offset: int): void {
        if (keyboardItemCount === 0)
            return;
        selectedItemIndex = Math.max(0,
            Math.min(keyboardItemCount - 1, selectedItemIndex + offset));
    }

    function cycleSelection(offset: int): void {
        if (keyboardItemCount === 0)
            return;
        selectedItemIndex = (selectedItemIndex + offset + keyboardItemCount)
            % keyboardItemCount;

        if (selectedItemIndex < items.length) {
            const item = items[selectedItemIndex];
            if (item.hasMenu)
                showItemMenu(item, trayRepeater.itemAt(selectedItemIndex));
            else
                dismissMenu();
            return;
        }
        if (selectedItemIndex < windowsIndex) {
            dismissMenu();
            return;
        }
        showWindowsMenu();
    }

    function activateSelection(): void {
        if (selectedItemIndex < items.length) {
            const item = items[selectedItemIndex];
            if (item.hasMenu) {
                showItemMenu(item, trayRepeater.itemAt(selectedItemIndex));
                PanelService.open(root);
            } else if (!item.onlyMenu) {
                item.activate();
                PanelService.close(root);
            }
            return;
        }
        if (selectedItemIndex < windowsIndex) {
            restore(minimised[selectedItemIndex - items.length]);
            return;
        }
        if (WindowsService.running) {
            showWindowsMenu();
            PanelService.open(root);
        }
    }

    PanelShortcut {
        enabled: root.opened && !menuLoader.item && !windowsMenuLoader.item
        sequences: ["Escape"]
        onActivated: root.collapseTray()
    }
    PanelShortcut {
        enabled: root.opened && !menuLoader.item?.activeSubmenu
        sequences: ["Left"]
        onActivated: root.cycleSelection(-1)
    }
    PanelShortcut {
        enabled: root.opened && !menuLoader.item && !windowsMenuLoader.item
        sequences: ["Up"]
        onActivated: root.moveSelection(-1)
    }
    PanelShortcut {
        enabled: root.opened && !menuLoader.item?.activeSubmenu
        sequences: ["Right"]
        onActivated: root.cycleSelection(1)
    }
    PanelShortcut {
        enabled: root.opened && !menuLoader.item && !windowsMenuLoader.item
        sequences: ["Down"]
        onActivated: root.moveSelection(1)
    }
    PanelShortcut {
        enabled: root.opened && !menuLoader.item && !windowsMenuLoader.item
        sequences: ["Return", "Enter"]
        onActivated: root.activateSelection()
    }

    function menuStatus(item: SystemTrayItem): string {
        const description = item?.tooltipDescription.trim() ?? "";
        if (description !== "")
            return description;
        if (item?.status === Status.NeedsAttention)
            return "Needs attention";
        if (item?.status === Status.Passive)
            return "Passive";
        return "Active";
    }

    visible: items.length > 0 || minimised.length > 0 || WindowsService.running
    implicitWidth: row.implicitWidth
    implicitHeight: PanelService.barItemHeight

    HoverHandler {
        id: hover
    }

    Row {
        id: row

        anchors.verticalCenter: parent.verticalCenter
        layoutDirection: Qt.LeftToRight
        spacing: root.expanded ? PanelService.barSpacing : 0

        Behavior on spacing {
            NumberAnimation {
                duration: PanelService.slideDuration
                easing.type: Easing.OutCubic
            }
        }

        Button {
            panel: root
            showPanelIndicator: false
            text: ""
            textSize: 12
            onClicked: {
                root.pinned = !root.pinned;
                if (!root.pinned)
                    PanelService.close(root);
            }
        }

        // Clipped viewport keeps the icon row pinned behind the hotspot.
        Item {
            anchors.verticalCenter: parent.verticalCenter
            clip: true

            implicitWidth: root.expanded ? icons.implicitWidth : 0
            implicitHeight: PanelService.barItemHeight
            opacity: root.expanded ? 1 : 0

            Behavior on implicitWidth {
                NumberAnimation {
                    duration: PanelService.slideDuration
                    easing.type: Easing.OutCubic
                }
            }

            Row {
                id: icons

                anchors.right: parent.right
                spacing: PanelService.barSpacing

                Repeater {
                    id: trayRepeater
                    model: root.items

                    Item {
                        id: entry

                        required property SystemTrayItem modelData
                        required property int index

                        implicitWidth: 16 + PanelService.barItemPadding * 2
                        implicitHeight: PanelService.barItemHeight

                        HoverUnderline {
                            // menuLoader.trayItem still points at the last item clicked, so the Windows menu has to be excluded here or that item lights up alongside it.
                            shown: itemMouse.containsMouse
                                || (root.opened && root.selectedItemIndex === entry.index)
                                || (root.opened && !root.windowsMenuOpen && menuLoader.trayItem === entry.modelData)
                        }

                        Image {
                            anchors.centerIn: parent
                            width: 16
                            height: 16
                            source: entry.modelData.icon
                            sourceSize.width: 32
                            sourceSize.height: 32
                            cache: true
                            smooth: true
                        }

                        MouseArea {
                            id: itemMouse

                            anchors.fill: parent
                            enabled: root.expanded
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton

                            onClicked: mouse => {
                                root.selectedItemIndex = entry.index;
                                if (entry.modelData.hasMenu) {
                                    // Same item toggles; another item transfers menu ownership.
                                    if (root.opened && !root.windowsMenuOpen && menuLoader.trayItem === entry.modelData) {
                                        PanelService.close(root);
                                        return;
                                    }

                                    root.showItemMenu(entry.modelData, entry);
                                    PanelService.open(root);
                                    return;
                                }

                                // Fall back to activation only when no menu exists.
                                if (mouse.button === Qt.LeftButton && !entry.modelData.onlyMenu) {
                                    entry.modelData.activate();
                                    PanelService.close(root);
                                }
                            }
                        }
                    }
                }

                // Minimised windows on this monitor; clicking one restores it.
                Repeater {
                    model: root.minimised

                    Item {
                        id: minimisedEntry

                        required property var modelData
                        required property int index
                        readonly property var desktopEntry: Utils.desktopEntry(modelData)
                        readonly property string iconName: desktopEntry?.icon
                            || String(modelData.wayland?.appId ?? modelData.lastIpcObject?.class ?? "")

                        implicitWidth: 16 + PanelService.barItemPadding * 2
                        implicitHeight: PanelService.barItemHeight

                        HoverUnderline {
                            shown: minimisedMouse.containsMouse
                                || (root.opened && root.selectedItemIndex === root.items.length + minimisedEntry.index)
                        }

                        Image {
                            anchors.centerIn: parent
                            width: 16
                            height: 16
                            source: Quickshell.iconPath(minimisedEntry.iconName, "application-x-executable")
                            sourceSize.width: 32
                            sourceSize.height: 32
                            asynchronous: true
                            smooth: true
                        }

                        MouseArea {
                            id: minimisedMouse

                            anchors.fill: parent
                            enabled: root.expanded
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: root.restore(minimisedEntry.modelData)
                        }
                    }
                }

                // Synthetic Windows entry, shown only while the container is up so it behaves like a background app that comes and goes.
                Item {
                    id: windowsEntry

                    visible: WindowsService.running
                    implicitWidth: visible ? 16 + PanelService.barItemPadding * 2 : 0
                    implicitHeight: PanelService.barItemHeight

                    HoverUnderline {
                        shown: windowsMouse.containsMouse
                            || (root.opened && root.selectedItemIndex === root.windowsIndex)
                            || (root.opened && root.windowsMenuOpen)
                    }

                    Image {
                        anchors.centerIn: parent
                        width: 16
                        height: 16
                        source: Quickshell.iconPath("windows", true)
                        sourceSize.width: 32
                        sourceSize.height: 32
                        cache: true
                        smooth: true
                    }

                    MouseArea {
                        id: windowsMouse

                        anchors.fill: parent
                        enabled: root.expanded
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton

                        onClicked: {
                            root.selectedItemIndex = root.windowsIndex;
                            if (root.opened && root.windowsMenuOpen) {
                                PanelService.close(root);
                                return;
                            }

                            root.showWindowsMenu();
                            PanelService.open(root);
                        }
                    }
                }
            }
        }
    }

    // Grabs input while a menu is open: a click anywhere outside the menu (and its submenus) clears the grab and dismisses it.
    HyprlandFocusGrab {
        active: root.opened && !PanelService.refocusing
        // Keep bar in grab scope so clicks can transfer directly to another tray menu or panel without an intermediate dismissing click.
        windows: [root.QsWindow.window]
            .concat(menuLoader.item?.openWindows ?? [])
            .concat(windowsMenuLoader.item?.openWindows ?? [])

        onCleared: if (!PanelService.refocusing) PanelService.close(root)
    }

    Loader {
        id: menuLoader

        property SystemTrayItem trayItem: null
        property Item anchorItem: null

        active: root.opened && !root.windowsMenuOpen && !!trayItem

        sourceComponent: TrayMenu {
            handle: menuLoader.trayItem?.menu ?? null
            anchorItem: menuLoader.anchorItem
            anchorWindow: root.QsWindow.window
            menuTitle: menuLoader.trayItem?.title ?? ""
            menuStatus: root.menuStatus(menuLoader.trayItem)

            onDismissRequested: root.collapseTray()
            onCloseRequested: PanelService.close(root)
        }
    }

    Loader {
        id: windowsMenuLoader

        active: root.opened && root.windowsMenuOpen

        sourceComponent: TrayMenu {
            entries: root.windowsMenuEntries
            anchorItem: windowsEntry
            anchorWindow: root.QsWindow.window
            menuTitle: "Windows"
            menuStatus: WindowsService.running ? "Running" : "Stopped"

            onDismissRequested: root.collapseTray()
            onCloseRequested: PanelService.close(root)
        }
    }
}
