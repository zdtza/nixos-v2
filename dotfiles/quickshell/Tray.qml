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
    readonly property bool expanded: hover.hovered || menuLoader.active

    visible: items.length > 0
    implicitWidth: row.implicitWidth
    implicitHeight: Math.max(chevron.implicitHeight, 16)

    HoverHandler {
        id: hover
    }

    Row {
        id: row

        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        Text {
            id: chevron

            anchors.verticalCenter: parent.verticalCenter
            text: ""
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize

        }

        // Clipped viewport: its width animates, the icon row inside is pinned
        // to the right edge so the icons slide out from behind the chevron.
        Item {
            id: viewport

            anchors.verticalCenter: parent.verticalCenter
            clip: true

            implicitWidth: root.expanded ? icons.implicitWidth : 0
            implicitHeight: 16
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
                spacing: 8

                Repeater {
                    model: root.items

                    Item {
                        id: entry

                        required property SystemTrayItem modelData

                        implicitWidth: 16
                        implicitHeight: 16

                        Image {
                            anchors.fill: parent
                            source: entry.modelData.icon
                            sourceSize.width: 16 * 2
                            sourceSize.height: 16 * 2
                            cache: true
                            smooth: true
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: root.expanded
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton

                            onClicked: mouse => {
                                if (mouse.button === Qt.LeftButton && !entry.modelData.onlyMenu) {
                                    entry.modelData.activate();
                                    return;
                                }

                                if (!entry.modelData.hasMenu)
                                    return;

                                // Toggle: clicking the same item again closes the menu.
                                if (menuLoader.active && menuLoader.trayItem === entry.modelData) {
                                    menuLoader.active = false;
                                    return;
                                }

                                menuLoader.trayItem = entry.modelData;
                                menuLoader.anchorItem = entry;
                                menuLoader.active = true;
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
        active: menuLoader.active
        windows: menuLoader.item?.openWindows ?? []

        onCleared: menuLoader.active = false
    }

    Loader {
        id: menuLoader

        property SystemTrayItem trayItem: null
        property Item anchorItem: null

        active: false

        sourceComponent: TrayMenu {
            handle: menuLoader.trayItem?.menu ?? null
            anchorItem: menuLoader.anchorItem
            visible: true

            onCloseRequested: menuLoader.active = false
        }
    }
}
