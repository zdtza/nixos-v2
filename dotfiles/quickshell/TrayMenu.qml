pragma ComponentBehavior: Bound

// Themed replacement for the platform tray menu (QsMenuAnchor renders a native
// Qt menu that ignores the system palette). Recurses into submenus by loading
// itself, anchored to the row that owns them.
import QtQuick
import Quickshell
import Stylix

PopupWindow {
    id: menu

    // QsMenuHandle to display, usually SystemTrayItem.menu
    required property var handle
    // Item this menu is positioned against.
    required property Item anchorItem

    property int menuWidth: 220

    // Submenus grow sideways out of their parent row instead of downwards.
    property bool submenu: false

    // Index of the row whose submenu is currently open, -1 for none.
    property int submenuIndex: -1

    // Currently open child menu, if any.
    property var activeSubmenu: null

    // This window plus every open descendant, for the focus grab in Tray.qml:
    // clicking inside any of them must not dismiss the menu.
    readonly property var openWindows: [menu].concat(activeSubmenu ? activeSubmenu.openWindows : [])

    signal closeRequested

    anchor {
        item: menu.anchorItem
        edges: menu.submenu ? Edges.Right | Edges.Top : Edges.Bottom
        gravity: menu.submenu ? Edges.Right | Edges.Bottom : Edges.Bottom | Edges.Left
        adjustment: PopupAdjustment.Slide
    }

    implicitWidth: menu.menuWidth
    implicitHeight: Math.max(1, column.implicitHeight + 2)
    color: "transparent"

    onVisibleChanged: {
        if (!visible)
            menu.submenuIndex = -1;
    }

    QsMenuOpener {
        id: opener
        menu: menu.handle
    }

    Rectangle {
        anchors.fill: parent

        color: Theme.background
        radius: 0
        border.width: 1
        border.color: Theme.border

        Column {
            id: column

            anchors {
                fill: parent
                margins: 1
            }

            Repeater {
                model: opener.children

                Item {
                    id: row

                    required property var modelData
                    required property int index

                    readonly property var entry: modelData
                    readonly property bool interactive: !entry.isSeparator && entry.enabled

                    width: column.width
                    implicitHeight: entry.isSeparator ? 5 : 26

                    // --- separator ---
                    Rectangle {
                        visible: row.entry.isSeparator
                        anchors.centerIn: parent
                        width: parent.width
                        height: 1
                        color: Theme.border
                    }

                    // --- entry ---
                    Rectangle {
                        visible: !row.entry.isSeparator
                        anchors.fill: parent
                        color: mouseArea.containsMouse && row.interactive ? Theme.surface : "transparent"

                        Text {
                            anchors {
                                left: parent.left
                                leftMargin: 10
                                right: indicator.left
                                rightMargin: 6
                                verticalCenter: parent.verticalCenter
                            }

                            text: row.entry.text
                            elide: Text.ElideRight
                            color: row.interactive ? Theme.foreground : Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 1
                        }

                        // Checkmark for toggles, chevron for submenus.
                        Text {
                            id: indicator

                            anchors {
                                right: parent.right
                                rightMargin: 10
                                verticalCenter: parent.verticalCenter
                            }

                            text: {
                                if (row.entry.hasChildren)
                                    return "󰅂";
                                if (row.entry.checkState === Qt.Checked)
                                    return "󰄬";
                                return "";
                            }
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 1
                        }

                        MouseArea {
                            id: mouseArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: row.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor

                            onClicked: {
                                if (!row.interactive || row.entry.hasChildren)
                                    return;

                                row.entry.triggered();
                                menu.closeRequested();
                            }

                            // Hovering a submenu row opens it; hovering any
                            // other row closes whatever was open. Leaving the
                            // popup entirely (into the submenu) changes nothing.
                            onContainsMouseChanged: {
                                if (containsMouse)
                                    menu.submenuIndex = row.entry.hasChildren ? row.index : -1;
                            }
                        }
                    }

                    // --- submenu ---
                    // Loaded by URL rather than as an inline component: QML
                    // refuses to instantiate a type inside its own definition.
                    Loader {
                        id: submenuLoader

                        active: menu.submenuIndex === row.index

                        onActiveChanged: {
                            if (!active) {
                                if (menu.activeSubmenu === item)
                                    menu.activeSubmenu = null;

                                source = "";
                                return;
                            }

                            setSource("TrayMenu.qml", {
                                handle: row.entry,
                                anchorItem: row,
                                menuWidth: menu.menuWidth,
                                submenu: true,
                                visible: true
                            });
                        }

                        onLoaded: {
                            menu.activeSubmenu = item;
                            item.closeRequested.connect(menu.closeRequested);
                        }
                    }
                }
            }
        }
    }
}
