pragma ComponentBehavior: Bound

// Themed replacement for the platform tray menu (QsMenuAnchor renders a native
// Qt menu that ignores the system palette). Recurses into submenus by loading
// itself, anchored to the row that owns them.
//
// Backed by either a live DBus menu (`handle`, e.g. SystemTrayItem.menu) or a
// static `entries` list built elsewhere (e.g. the synthetic Windows tray
// entry), normalized to the same shape:
// { text, isSeparator, enabled, hasChildren, checkState, triggered() }.
import QtQuick
import Quickshell
import Stylix
import "../services"
import ".."

PopupWindow {
    id: menu

    // Exactly one of these is provided by the caller.
    property var handle: null
    property var entries: null

    // Item and bar window this menu is positioned against.
    required property Item anchorItem
    required property var anchorWindow

    property int menuWidth: 220
    property int panelPadding: 6
    property int itemAreaPadding: 6
    property string menuTitle: ""
    property string menuStatus: ""

    readonly property bool staticEntries: !handle
    property bool contentReady: staticEntries
    property var selectedEntry: null
    property int selectedEntryIndex: -1
    readonly property var menuEntries: staticEntries ? (entries ?? []) : opener.children.values
    readonly property var keyboardEntryIndices: menuEntries
        .map((entry, index) => entry && !entry.isSeparator && entry.enabled ? index : -1)
        .filter(index => index >= 0)

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

    function selectEntry(index: int): void {
        selectedEntryIndex = index;
        selectedEntry = index >= 0 ? menuEntries[index] : null;
    }

    function moveSelection(offset: int): void {
        if (keyboardEntryIndices.length === 0) {
            selectEntry(-1);
            return;
        }
        let position = keyboardEntryIndices.indexOf(selectedEntryIndex);
        if (position < 0)
            position = offset > 0 ? 0 : keyboardEntryIndices.length - 1;
        else
            position = (position + offset + keyboardEntryIndices.length)
                % keyboardEntryIndices.length;
        selectEntry(keyboardEntryIndices[position]);
        submenuEntry = null;
    }

    function activateSelection(): void {
        const entry = selectedEntryIndex >= 0 ? menuEntries[selectedEntryIndex] : null;
        if (!entry)
            return;
        if (entry.hasChildren) {
            submenuEntry = entry;
            return;
        }
        entry.triggered();
        closeRequested();
    }

    Component.onCompleted: {
        if (staticEntries) {
            if (keyboardEntryIndices.length > 0)
                selectEntry(keyboardEntryIndices[0]);
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
        enabled: menu.visible && menu.submenu && !menu.activeSubmenu
        sequence: "Right"
        context: Qt.ApplicationShortcut
        onActivated: {
            const entry = menu.selectedEntryIndex >= 0
                ? menu.menuEntries[menu.selectedEntryIndex] : null;
            if (entry?.hasChildren)
                menu.submenuEntry = entry;
        }
    }

    // Closes the deepest currently-open submenu in this chain, if any.
    // Returns whether it closed something, so escape can be pressed
    // repeatedly to walk back out one level at a time before finally
    // dismissing the whole menu.
    function closeSubmenu(): bool {
        if (!menu.activeSubmenu)
            return false;
        if (!menu.activeSubmenu.closeSubmenu())
            menu.submenuEntry = null;
        return true;
    }

    Shortcut {
        enabled: menu.visible && !menu.submenu
        sequence: "Escape"
        context: Qt.ApplicationShortcut
        onActivated: {
            if (!menu.closeSubmenu())
                menu.dismissRequested();
        }
    }

    // PopupAnchor.item and .window are mutually exclusive in quickshell's
    // native implementation (setting one unsets the other), and its internal
    // onItemWindowChanged() dereferences the anchor item unconditionally
    // whenever it's cleared. Binding both item and window permanently on the
    // same anchor (e.g. `item: cond ? x : null; window: cond ? null : y`)
    // means whichever evaluates second clobbers the other and can null-deref
    // a still-live item, crashing quickshell. Only ever touch the property
    // actually in use for this instance's lifetime, guarded so the other is
    // never written at all.
    Binding {
        target: popupAnchor
        property: "item"
        value: menu.anchorItem
        when: menu.submenu
    }

    Binding {
        target: popupAnchor
        property: "window"
        value: menu.anchorWindow
        when: !menu.submenu
    }

    anchor {
        id: popupAnchor

        edges: menu.submenu ? Edges.Right | Edges.Top : Edges.Top | Edges.Left
        gravity: menu.submenu ? Edges.Right | Edges.Bottom : Edges.Bottom | Edges.Right
        adjustment: PopupAdjustment.Slide
        // Submenus anchor to the parent row's right edge, which sits right at
        // the panel padding; pull the anchor point in slightly so the
        // submenu overlaps back over that padding instead of appearing to
        // float a few pixels further right than the main dropdown's edge.
        margins.right: menu.submenu ? 4 : 0
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
    implicitHeight: Math.max(1, column.implicitHeight
        + menu.panelPadding * 2)
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
            menu.selectEntry(-1);
            menu.submenuEntry = null;
            menu.contentReady = false;
            revealTimer.restart();
        }
        onChildrenChanged: {
            menu.selectEntry(-1);
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
                if (menu.selectedEntryIndex < 0 && menu.keyboardEntryIndices.length > 0)
                    menu.selectEntry(menu.keyboardEntryIndices[0]);
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
                topMargin: menu.panelPadding
                bottomMargin: menu.panelPadding
            }

            Item {
                width: column.width
                implicitHeight: menu.menuTitle === "" ? 0 : (menu.menuStatus === "" ? 38 : 52)
                visible: implicitHeight > 0

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.top: parent.top
                    anchors.topMargin: 6
                    text: menu.menuTitle
                    color: Theme.foreground
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pixelSize: Utils.scaledFont(14)
                    font.weight: Font.Medium
                    font.letterSpacing: 0.1
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.top: parent.top
                    anchors.topMargin: 26
                    visible: menu.menuStatus !== ""
                    text: menu.menuStatus.toUpperCase()
                    color: Theme.muted
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pixelSize: Utils.scaledFont(9)
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

            Item {
                width: column.width
                implicitHeight: menu.itemAreaPadding
            }

            Repeater {
                model: menu.menuEntries

                Item {
                    id: row

                    required property var modelData
                    required property int index

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
                        color: menu.selectedEntryIndex === row.index
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
                            font.pixelSize: Utils.scaledFont(row.sectionLabel ? 9 : 12)
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
                            font.pixelSize: Utils.scaledFont(Theme.fontSize)
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
                                    menu.selectEntry(row.interactive ? row.index : -1);
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

            Item {
                width: column.width
                implicitHeight: menu.itemAreaPadding / 2
            }
        }
    }
}
