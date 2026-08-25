pragma ComponentBehavior: Bound

// System tray, collapsed behind a chevron. Hovering the chevron (or the icons
// themselves) slides the icons out; moving the pointer away slides them back.
// Icons stay instantiated and are revealed by animating a clipped container,
// so nothing is rebuilt on every hover.
//
// Left click activates an item, right click opens its menu, rendered by
// PanelTrayMenu so it follows the system palette instead of the Qt default.
//
// The Windows VM is appended as a synthetic entry: it exports no
// StatusNotifierItem, so ServiceWindowsVm polls systemd for it instead.
import QtQuick
import Quickshell
import Stylix
import Quickshell.Hyprland
import Quickshell.Services.SystemTray

Item {
    id: root

    readonly property var items: SystemTray.items.values
    readonly property bool opened: ServicePanel.activePanel === root
    readonly property bool requiresKeyboardFocus: true
    property bool pinned: false
    property bool openedFromIpc: false
    property int selectedItemIndex: 0
    readonly property int keyboardItemCount: items.length + (ServiceWindowsVm.running ? 1 : 0)
    readonly property bool expanded: root.pinned || hover.hovered || root.opened

    // Normalizes the Windows VM's plain action list to the same shape as a
    // real DBus menu's entries, so PanelTrayMenu can render either.
    readonly property var vmMenuEntries: ServiceWindowsVm.actions.map(action => ({
        text: action.label,
        isSeparator: false,
        enabled: true,
        hasChildren: false,
        checkState: Qt.Unchecked,
        triggered: () => ServiceWindowsVm.run(action.command)
    }))

    // Which of the two menu loaders the open panel belongs to.
    property bool vmMenuOpen: false

    onOpenedChanged: {
        if (!opened) {
            openedFromIpc = false;
            vmMenuOpen = false;
            menuLoader.trayItem = null;
            menuLoader.anchorItem = null;
            vmMenuLoader.anchorItem = null;
        } else {
            selectedItemIndex = Math.max(0,
                Math.min(keyboardItemCount - 1, selectedItemIndex));
        }
    }

    function dismissMenu(): void {
        vmMenuOpen = false;
        menuLoader.trayItem = null;
        menuLoader.anchorItem = null;
        vmMenuLoader.anchorItem = null;
    }

    function toggleFromIpc(): void {
        openedFromIpc = true;
        ServicePanel.toggle(root);
    }

    function dismissMenuFromEscape(): void {
        if (openedFromIpc && keyboardItemCount > 1)
            dismissMenu();
        else
            collapseTray();
    }

    function collapseTray(): void {
        pinned = false;
        dismissMenu();
        ServicePanel.close(root);
    }

    function moveSelection(offset: int): void {
        if (keyboardItemCount === 0)
            return;
        selectedItemIndex = Math.max(0,
            Math.min(keyboardItemCount - 1, selectedItemIndex + offset));
    }

    function activateSelection(): void {
        if (selectedItemIndex < items.length) {
            const item = items[selectedItemIndex];
            const entry = trayRepeater.itemAt(selectedItemIndex);
            if (item.hasMenu) {
                vmMenuOpen = false;
                menuLoader.trayItem = item;
                menuLoader.anchorItem = entry;
                ServicePanel.open(root);
            } else if (!item.onlyMenu) {
                item.activate();
                ServicePanel.close(root);
            }
            return;
        }
        if (ServiceWindowsVm.running) {
            vmMenuOpen = true;
            vmMenuLoader.anchorItem = vmEntry;
            ServicePanel.open(root);
        }
    }

    Shortcut {
        enabled: root.opened && !menuLoader.item && !vmMenuLoader.item
        sequence: "Escape"
        context: Qt.ApplicationShortcut
        onActivated: root.collapseTray()
    }
    Shortcut {
        enabled: root.opened && !menuLoader.item && !vmMenuLoader.item
        sequence: "Left"
        context: Qt.ApplicationShortcut
        onActivated: root.moveSelection(-1)
    }
    Shortcut {
        enabled: root.opened && !menuLoader.item && !vmMenuLoader.item
        sequence: "Up"
        context: Qt.ApplicationShortcut
        onActivated: root.moveSelection(-1)
    }
    Shortcut {
        enabled: root.opened && !menuLoader.item && !vmMenuLoader.item
        sequence: "Right"
        context: Qt.ApplicationShortcut
        onActivated: root.moveSelection(1)
    }
    Shortcut {
        enabled: root.opened && !menuLoader.item && !vmMenuLoader.item
        sequence: "Down"
        context: Qt.ApplicationShortcut
        onActivated: root.moveSelection(1)
    }
    Shortcut {
        enabled: root.opened && !menuLoader.item && !vmMenuLoader.item
        sequence: "Return"
        context: Qt.ApplicationShortcut
        onActivated: root.activateSelection()
    }
    Shortcut {
        enabled: root.opened && !menuLoader.item && !vmMenuLoader.item
        sequence: "Enter"
        context: Qt.ApplicationShortcut
        onActivated: root.activateSelection()
    }

    function menuStatus(item: SystemTrayItem): string {
        const description = item?.tooltipDescription?.trim() ?? "";
        if (description !== "")
            return description;
        if (item?.status === Status.NeedsAttention)
            return "Needs attention";
        if (item?.status === Status.Passive)
            return "Passive";
        return "Active";
    }

    visible: items.length > 0 || ServiceWindowsVm.running
    implicitWidth: row.implicitWidth
    implicitHeight: 25

    HoverHandler {
        id: hover
    }

    Row {
        id: row

        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        BarButton {
            id: chevron

            panel: root
            showPanelIndicator: false
            text: ""
            onClicked: {
                root.pinned = !root.pinned;
                if (!root.pinned)
                    ServicePanel.close(root);
            }
        }

        // Clipped viewport: its width animates, the icon row inside is pinned
        // to the right edge so the icons slide out from behind the chevron.
        Item {
            id: viewport

            anchors.verticalCenter: parent.verticalCenter
            clip: true

            implicitWidth: root.expanded ? icons.implicitWidth : 0
            implicitHeight: 25
            opacity: root.expanded ? 1 : 0

            Behavior on implicitWidth {
                NumberAnimation {
                    duration: 140
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: 140
                    easing.type: Easing.OutCubic
                }
            }

            Row {
                id: icons

                anchors.right: parent.right
                spacing: 0

                Repeater {
                    id: trayRepeater
                    model: root.items

                    Item {
                        id: entry

                        required property SystemTrayItem modelData
                        required property int index

                        implicitWidth: 30
                        implicitHeight: 25

                        Image {
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: -2
                            width: 16
                            height: 16
                            source: entry.modelData.icon
                            sourceSize.width: 16 * 2
                            sourceSize.height: 16 * 2
                            cache: true
                            smooth: true
                        }

                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 16
                            height: 2
                            radius: ServicePanel.rounding
                            // menuLoader.trayItem still points at the last item
                            // clicked, so the VM menu has to be excluded here or
                            // that item lights up alongside it.
                            visible: itemMouse.containsMouse
                                || (root.opened && root.selectedItemIndex === entry.index)
                                || (root.opened && !root.vmMenuOpen && menuLoader.trayItem === entry.modelData)
                            color: Theme.accent
                        }

                        MouseArea {
                            id: itemMouse

                            anchors.fill: parent
                            enabled: root.expanded
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton

                            onClicked: mouse => {
                                root.openedFromIpc = false;
                                root.selectedItemIndex = entry.index;
                                if (entry.modelData.hasMenu) {
                                    // Same item toggles; another item transfers menu ownership.
                                    if (root.opened && !root.vmMenuOpen && menuLoader.trayItem === entry.modelData) {
                                        ServicePanel.close(root);
                                        return;
                                    }

                                    root.vmMenuOpen = false;
                                    menuLoader.trayItem = entry.modelData;
                                    menuLoader.anchorItem = entry;
                                    ServicePanel.open(root);
                                    return;
                                }

                                // Fall back to activation only when no menu exists.
                                if (mouse.button === Qt.LeftButton && !entry.modelData.onlyMenu) {
                                    entry.modelData.activate();
                                    ServicePanel.close(root);
                                }
                            }
                        }
                    }
                }

                // Synthetic Windows VM entry, shown only while the container is
                // up so it behaves like a background app that comes and goes.
                Item {
                    id: vmEntry

                    visible: ServiceWindowsVm.running
                    implicitWidth: visible ? 30 : 0
                    implicitHeight: 25

                    Image {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: -2
                        width: 16
                        height: 16
                        source: Quickshell.iconPath("windows-vm", true)
                        sourceSize.width: 16 * 2
                        sourceSize.height: 16 * 2
                        cache: true
                        smooth: true
                    }

                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 16
                        height: 2
                        radius: ServicePanel.rounding
                        visible: vmMouse.containsMouse
                            || (root.opened && root.selectedItemIndex === root.items.length)
                            || (root.opened && root.vmMenuOpen)
                        color: Theme.accent
                    }

                    MouseArea {
                        id: vmMouse

                        anchors.fill: parent
                        enabled: root.expanded
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton

                        onClicked: {
                            root.openedFromIpc = false;
                            root.selectedItemIndex = root.items.length;
                            if (root.opened && root.vmMenuOpen) {
                                ServicePanel.close(root);
                                return;
                            }

                            root.vmMenuOpen = true;
                            vmMenuLoader.anchorItem = vmEntry;
                            ServicePanel.open(root);
                        }
                    }
                }
            }
        }
    }

    // Grabs input while a menu is open: a click anywhere outside the menu (and
    // its submenus) clears the grab and dismisses it.
    HyprlandFocusGrab {
        active: root.opened
        // Keep bar in grab scope so clicks can transfer directly to another
        // tray menu or panel without an intermediate dismissing click.
        windows: [root.QsWindow.window]
            .concat(menuLoader.item?.openWindows ?? [])
            .concat(vmMenuLoader.item?.openWindows ?? [])

        onCleared: ServicePanel.close(root)
    }

    Loader {
        id: menuLoader

        property SystemTrayItem trayItem: null
        property Item anchorItem: null

        active: root.opened && !root.vmMenuOpen && !!trayItem

        sourceComponent: PanelTrayMenu {
            handle: menuLoader.trayItem?.menu ?? null
            anchorItem: menuLoader.anchorItem
            anchorWindow: root.QsWindow.window
            menuTitle: menuLoader.trayItem?.title ?? ""
            menuStatus: root.menuStatus(menuLoader.trayItem)

            onDismissRequested: root.dismissMenuFromEscape()
            onCloseRequested: ServicePanel.close(root)
        }
    }

    Loader {
        id: vmMenuLoader

        property Item anchorItem: null

        active: root.opened && root.vmMenuOpen

        sourceComponent: PanelTrayMenu {
            entries: root.vmMenuEntries
            anchorItem: vmMenuLoader.anchorItem
            anchorWindow: root.QsWindow.window
            menuTitle: "Windows"
            menuStatus: ServiceWindowsVm.running ? "Running" : "Stopped"

            onDismissRequested: root.dismissMenuFromEscape()
            onCloseRequested: ServicePanel.close(root)
        }
    }
}
