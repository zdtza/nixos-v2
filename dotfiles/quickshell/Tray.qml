pragma ComponentBehavior: Bound

// System tray, collapsed behind a chevron. Hovering the chevron (or the icons
// themselves) slides the icons out; moving the pointer away slides them back.
// Icons stay instantiated and are revealed by animating a clipped container,
// so nothing is rebuilt on every hover.
//
// Left click activates an item, right click opens its menu, rendered by
// TrayMenu so it follows the system palette instead of the Qt default.
import QtQuick
import Quickshell
import Stylix
import Quickshell.Hyprland
import Quickshell.Services.SystemTray

Item {
    id: root

    readonly property var items: SystemTray.items.values
    readonly property bool opened: PanelService.activePanel === root
    property bool pinned: false
    readonly property bool expanded: root.pinned || hover.hovered || root.opened

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

    visible: items.length > 0
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
                    PanelService.close(root);
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
                    duration: 160
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: 160
                    easing.type: Easing.OutCubic
                }
            }

            Row {
                id: icons

                anchors.right: parent.right
                spacing: 0

                Repeater {
                    model: root.items

                    Item {
                        id: entry

                        required property SystemTrayItem modelData

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
                            visible: itemMouse.containsMouse
                                || (root.opened && menuLoader.trayItem === entry.modelData)
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
                                if (entry.modelData.hasMenu) {
                                    // Same item toggles; another item transfers menu ownership.
                                    if (root.opened && menuLoader.trayItem === entry.modelData) {
                                        PanelService.close(root);
                                        return;
                                    }

                                    menuLoader.trayItem = entry.modelData;
                                    menuLoader.anchorItem = entry;
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
            }
        }
    }

    // Grabs input while a menu is open: a click anywhere outside the menu (and
    // its submenus) clears the grab and dismisses it.
    HyprlandFocusGrab {
        active: root.opened
        // Keep bar in grab scope so clicks can transfer directly to another
        // tray menu or panel without an intermediate dismissing click.
        windows: [root.QsWindow.window].concat(menuLoader.item?.openWindows ?? [])

        onCleared: PanelService.close(root)
    }

    Loader {
        id: menuLoader

        property SystemTrayItem trayItem: null
        property Item anchorItem: null

        active: root.opened && !!trayItem

        sourceComponent: TrayMenu {
            handle: menuLoader.trayItem?.menu ?? null
            anchorItem: menuLoader.anchorItem
            anchorWindow: root.QsWindow.window
            menuTitle: menuLoader.trayItem?.title ?? ""
            menuStatus: root.menuStatus(menuLoader.trayItem)

            onCloseRequested: PanelService.close(root)
        }
    }
}
