pragma ComponentBehavior: Bound

// Themed replacement for the platform tray menu (QsMenuAnchor renders a native
// Qt menu that ignores the system palette). Recurses into submenus by loading
// itself, anchored to the row that owns them.
//
// Backed by either a live DBus menu (`handle`, e.g. SystemTrayItem.menu) or a
// static `entries` list built elsewhere (e.g. the synthetic Windows VM tray
// entry), normalized to the same shape:
// { text, isSeparator, enabled, hasChildren, checkState, triggered() }.
import QtQuick
import Quickshell
import Stylix

PopupWindow {
    id: menu

    // Exactly one of these is provided by the caller.
    property var handle: null
    property var entries: null

    // Item and bar window this menu is positioned against.
    required property Item anchorItem
    required property var anchorWindow

    property int menuWidth: 220
    property string menuTitle: ""
    property string menuStatus: ""

    readonly property bool staticEntries: !handle
    property bool contentReady: staticEntries
    property var selectedEntry: null
    readonly property var menuEntries: staticEntries ? (entries ?? []) : opener.children.values
    readonly property var keyboardEntries: menuEntries.filter(entry =>
        entry && !entry.isSeparator && entry.enabled)

    // Submenus grow sideways out of their parent row instead of downwards.
    // Only ever set true recursively below, for DBus submenus.
    property bool submenu: false

    // Stable menu entry whose submenu is currently open, null for none.
    property var submenuEntry: null

    // Currently open child menu, if any.
    property var activeSubmenu: null

    // This window plus every open descendant, for the focus grab in PanelTray.qml:
    // clicking inside any of them must not dismiss the menu.
    readonly property var openWindows: [menu].concat(activeSubmenu ? activeSubmenu.openWindows : [])

    signal closeRequested
    signal dismissRequested

    function moveSelection(offset: int): void {
        if (keyboardEntries.length === 0) {
            selectedEntry = null;
            return;
        }
        let index = keyboardEntries.indexOf(selectedEntry);
        if (index < 0)
            index = offset > 0 ? 0 : keyboardEntries.length - 1;
        else
            index = Math.max(0, Math.min(keyboardEntries.length - 1, index + offset));
        selectedEntry = keyboardEntries[index];
        submenuEntry = null;
    }

    function activateSelection(): void {
        if (!selectedEntry)
            return;
        if (selectedEntry.hasChildren) {
            submenuEntry = selectedEntry;
            return;
        }
        selectedEntry.triggered();
        closeRequested();
    }

    Component.onCompleted: {
        if (staticEntries) {
            if (keyboardEntries.length > 0)
                selectedEntry = keyboardEntries[0];
        } else {
            revealTimer.restart();
        }
    }

    Shortcut {
        enabled: menu.visible && !menu.activeSubmenu
        sequence: "Up"
        context: Qt.ApplicationShortcut
        onActivated: menu.moveSelection(-1)
    }
    Shortcut {
        enabled: menu.visible && !menu.activeSubmenu
        sequence: "Down"
        context: Qt.ApplicationShortcut
        onActivated: menu.moveSelection(1)
    }
    Shortcut {
        enabled: menu.visible && !menu.activeSubmenu
        sequence: "Return"
        context: Qt.ApplicationShortcut
        onActivated: menu.activateSelection()
    }
    Shortcut {
        enabled: menu.visible && !menu.activeSubmenu
        sequence: "Enter"
        context: Qt.ApplicationShortcut
        onActivated: menu.activateSelection()
    }
    Shortcut {
        enabled: menu.visible && !menu.activeSubmenu
        sequence: "Right"
        context: Qt.ApplicationShortcut
        onActivated: menu.activateSelection()
    }

    Shortcut {
        enabled: menu.visible && !menu.submenu
        sequence: "Escape"
        context: Qt.ApplicationShortcut
        onActivated: menu.dismissRequested()
    }

    anchor {
        id: popupAnchor

        item: menu.submenu ? menu.anchorItem : null
        window: menu.submenu ? null : menu.anchorWindow
        edges: menu.submenu ? Edges.Right | Edges.Top : Edges.Top | Edges.Left
        gravity: menu.submenu ? Edges.Right | Edges.Bottom : Edges.Bottom | Edges.Right
        adjustment: PopupAdjustment.Slide
        rect.width: 1
        rect.height: 1

        // Match PanelPopup positioning: center under bar item, then leave same
        // compositor-gap-sized offset below bar.
        onAnchoring: {
            if (menu.submenu || !menu.anchorWindow)
                return;

            let point = menu.anchorWindow.contentItem.mapFromItem(
                menu.anchorItem,
                menu.anchorItem.width / 2 - menu.implicitWidth / 2,
                menu.anchorItem.height + ServicePanel.barGap + ServicePanel.gapTopOffset
            );
            point.x = Math.max(ServicePanel.barGap + ServicePanel.gapLeftOffset,
                Math.min(point.x, menu.anchorWindow.width - menu.implicitWidth
                    - ServicePanel.barGap - ServicePanel.gapRightOffset));
            popupAnchor.rect.x = Math.round(point.x);
            popupAnchor.rect.y = Math.round(point.y);
        }
    }

    implicitWidth: menu.menuWidth
    implicitHeight: Math.max(1, column.implicitHeight + 12)
    visible: contentReady
    color: "transparent"

    onVisibleChanged: {
        if (!visible)
            menu.submenuEntry = null;
    }

    // Only meaningful in handle mode; harmless no-op (null menu, no children)
    // when driven by a static entries list instead.
    QsMenuOpener {
        id: opener
        menu: menu.handle

        onMenuChanged: {
            menu.selectedEntry = null;
            menu.submenuEntry = null;
            menu.contentReady = false;
            revealTimer.restart();
        }
        onChildrenChanged: {
            menu.selectedEntry = null;
            menu.submenuEntry = null;
            if (!menu.contentReady)
                revealTimer.restart();
        }
    }

    // QsMenuOpener populates its model asynchronously. Keep popup unmapped
    // until initial nonempty model geometry has settled, then leave it mapped
    // while later menu updates hydrate to avoid empty-frame and hide/show flicker.
    Timer {
        id: revealTimer
        interval: 20
        onTriggered: {
            if (opener.children.values.length > 0) {
                menu.contentReady = true;
                if (!menu.selectedEntry && menu.keyboardEntries.length > 0)
                    menu.selectedEntry = menu.keyboardEntries[0];
            }
        }
    }

    Rectangle {
        anchors.fill: parent

        color: Theme.dark_background
        radius: ServicePanel.rounding
        border.width: 1
        border.color: Theme.border

        Column {
            id: column

            anchors {
                fill: parent
                leftMargin: 2
                rightMargin: 2
                topMargin: 6
                bottomMargin: 6
            }

            Item {
                width: column.width
                implicitHeight: menu.menuTitle === "" ? 0 : (menu.menuStatus === "" ? 44 : 58)
                visible: implicitHeight > 0

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.top: parent.top
                    anchors.topMargin: 12
                    text: menu.menuTitle
                    color: Theme.foreground
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pixelSize: Util.scaledFont(14)
                    font.weight: Font.Medium
                    font.letterSpacing: 0.1
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.top: parent.top
                    anchors.topMargin: 32
                    visible: menu.menuStatus !== ""
                    text: menu.menuStatus.toUpperCase()
                    color: Theme.muted
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pixelSize: Util.scaledFont(9)
                    font.weight: Font.Medium
                    font.letterSpacing: 1.8
                }
            }

            Rectangle {
                width: column.width
                implicitHeight: menu.menuTitle === "" ? 0 : 1
                visible: implicitHeight > 0
                color: Theme.border
            }

            Repeater {
                model: menu.menuEntries

                Item {
                    id: row

                    required property var modelData

                    readonly property var entry: modelData
                    readonly property bool interactive: !entry.isSeparator && entry.enabled
                    readonly property bool sectionLabel: !entry.isSeparator && !entry.enabled

                    width: column.width
                    implicitHeight: entry.isSeparator ? 13 : (row.sectionLabel ? 26 : 30)

                    // --- separator ---
                    Rectangle {
                        visible: row.entry.isSeparator
                        anchors.centerIn: parent
                        width: parent.width
                        height: 1
                        color: Theme.border
                    }

                    // --- entry or section heading ---
                    Rectangle {
                        visible: !row.entry.isSeparator
                        anchors {
                            fill: parent
                            leftMargin: 6
                            rightMargin: 6
                        }
                        radius: ServicePanel.rounding
                        color: menu.selectedEntry === row.entry
                            && row.interactive ? Theme.surface : "transparent"

                        Text {
                            anchors {
                                left: parent.left
                                leftMargin: 14
                                right: indicator.left
                                rightMargin: 8
                                verticalCenter: parent.verticalCenter
                            }

                            text: row.sectionLabel ? row.entry.text.toUpperCase() : row.entry.text
                            elide: Text.ElideRight
                            color: row.sectionLabel ? Theme.border : (row.interactive ? Theme.foreground : Theme.muted)
                            font.family: Theme.fontFamily
                            font.pixelSize: Util.scaledFont(row.sectionLabel ? 9 : 12)
                            font.weight: row.sectionLabel ? Font.Medium : Font.Normal
                            font.letterSpacing: row.sectionLabel ? 1.8 : 0.1
                        }

                        // Checkmark for toggles, chevron for submenus.
                        Text {
                            id: indicator

                            anchors {
                                right: parent.right
                                rightMargin: 14
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
                            font.pixelSize: Util.scaledFont(Theme.fontSize)
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
                                if (containsMouse) {
                                    menu.selectedEntry = row.interactive ? row.entry : null;
                                    menu.submenuEntry = row.entry.hasChildren ? row.entry : null;
                                }
                            }
                        }
                    }

                    // --- submenu (DBus entries only; static entries never
                    // report hasChildren, so this loader never activates) ---
                    // Loaded by URL rather than as an inline component: QML
                    // refuses to instantiate a type inside its own definition.
                    Loader {
                        id: submenuLoader

                        property var loadedSubmenu: null

                        active: menu.submenuEntry === row.entry

                        onActiveChanged: {
                            if (!active) {
                                if (menu.activeSubmenu === loadedSubmenu)
                                    menu.activeSubmenu = null;

                                loadedSubmenu = null;
                                source = "";
                                return;
                            }

                            setSource("PanelTrayMenu.qml", {
                                handle: row.entry,
                                anchorItem: row,
                                anchorWindow: menu.anchorWindow,
                                menuWidth: menu.menuWidth,
                                menuTitle: row.entry.text,
                                submenu: true
                            });
                        }

                        onItemChanged: {
                            if (!item && menu.activeSubmenu === loadedSubmenu)
                                menu.activeSubmenu = null;
                            if (!item)
                                loadedSubmenu = null;
                        }

                        onLoaded: {
                            loadedSubmenu = item;
                            menu.activeSubmenu = item;
                            item.closeRequested.connect(menu.closeRequested);
                            item.dismissRequested.connect(menu.dismissRequested);
                        }
                    }
                }
            }
        }
    }
}
