pragma ComponentBehavior: Bound

// Minimal application launcher: search field followed by application names and
// their desktop-entry icons. Right clicking a row opens its desktop-entry
// actions (Firefox's private window, this VM's shutdown/erase, ...), which are
// otherwise unreachable.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Stylix

Scope {
    id: root

    property bool open: false
    property var terminal: ["kitty"]

    function toggle(): void {
        root.open = !root.open;
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            root.toggle();
        }

        function open(): void {
            root.open = true;
        }

        function close(): void {
            root.open = false;
        }

        function isOpen(): bool {
            return root.open;
        }
    }

    PanelWindow {
        id: window

        visible: root.open

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        exclusionMode: ExclusionMode.Ignore
        color: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 0.45)
        WlrLayershell.namespace: "quickshell:launcher"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        readonly property var entries: {
            const list = [];

            for (const entry of DesktopEntries.applications.values) {
                if (entry.noDisplay)
                    continue;

                list.push({
                    entry,
                    name: entry.name.toLowerCase(),
                    description: `${entry.comment ?? ""} ${entry.genericName ?? ""}`.toLowerCase()
                });
            }

            return list.sort((a, b) => a.entry.name.localeCompare(b.entry.name));
        }

        function fuzzyMatches(haystack: string, token: string): bool {
            let index = -1;

            for (const character of token) {
                index = haystack.indexOf(character, index + 1);
                if (index === -1)
                    return false;
            }

            return true;
        }

        function matchTier(item: var, token: string): int {
            if (item.name.startsWith(token))
                return 0;
            if (item.name.includes(token))
                return 1;
            if (window.fuzzyMatches(item.name, token))
                return 2;
            if (item.description.includes(token))
                return 3;

            return -1;
        }

        readonly property var results: {
            const tokens = search.text.toLowerCase().split(" ").filter(token => token !== "");
            if (tokens.length === 0)
                return window.entries;

            const matched = [];

            for (const item of window.entries) {
                let tier = 0;

                for (const token of tokens) {
                    const tokenTier = window.matchTier(item, token);
                    if (tokenTier === -1) {
                        tier = -1;
                        break;
                    }

                    tier = Math.max(tier, tokenTier);
                }

                if (tier !== -1)
                    matched.push({ item, tier });
            }

            return matched.sort((a, b) => a.tier - b.tier).map(match => match.item);
        }

        // Right-click menu state. Rendered inline rather than as a PopupWindow:
        // the launcher already covers the screen and holds keyboard focus, so a
        // second layer-shell surface would only fight it for input.
        property var menuEntry: null
        property real menuX: 0
        property real menuY: 0

        readonly property bool menuOpen: menuEntry !== null
        readonly property var menuActions: menuEntry?.actions ?? []

        function openContextMenu(entry: DesktopEntry, item: Item, localX: real, localY: real): void {
            if (!entry)
                return;

            // Row-local to scene coordinates, which is what the menu is
            // positioned in since it shares the window's content item.
            const point = item.mapToItem(null, localX, localY);
            window.menuX = point.x;
            window.menuY = point.y;
            window.menuEntry = entry;
        }

        function closeContextMenu(): void {
            window.menuEntry = null;
        }

        function launch(entry: DesktopEntry): void {
            if (!entry)
                return;

            if (entry.runInTerminal)
                Quickshell.execDetached({
                    command: [...root.terminal, "--", ...entry.command],
                    workingDirectory: entry.workingDirectory || Quickshell.env("HOME")
                });
            else
                entry.execute();

            root.open = false;
        }

        onVisibleChanged: {
            window.closeContextMenu();
            if (!visible)
                return;
            search.text = "";
            search.forceActiveFocus();
            list.currentIndex = 0;
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.open = false
        }

        Rectangle {
            id: launcherFrame

            anchors.centerIn: parent
            width: 500
            height: 484
            color: Theme.border

            // Swallow clicks so they do not reach dismiss area.
            MouseArea {
                anchors.fill: parent
                onPressed: mouse => mouse.accepted = true
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 2
                color: Theme.background

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    Item {
                        Layout.fillWidth: true
                        implicitHeight: 78

                        Rectangle {
                            anchors {
                                left: parent.left
                                right: parent.right
                                top: parent.top
                                margins: 14
                            }
                            height: 50
                            color: Theme.dark_background
                            border.width: 1
                            border.color: Theme.surface

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                text: "󰍉"
                                color: Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: 18
                            }

                            TextInput {
                                id: search

                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    leftMargin: 34
                                    rightMargin: 12
                                    verticalCenter: parent.verticalCenter
                                }
                                height: 30
                                verticalAlignment: TextInput.AlignVCenter
                                focus: true
                                selectByMouse: true
                                clip: true

                                color: Theme.foreground
                                selectionColor: Theme.surface
                                selectedTextColor: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: 18

                                cursorDelegate: Rectangle {
                                    width: 1
                                    color: Theme.accent
                                }

                                onTextChanged: list.currentIndex = 0

                                Text {
                                    anchors.fill: parent
                                    verticalAlignment: Text.AlignVCenter
                                    visible: search.text === ""
                                    text: "Search applications"
                                    color: Theme.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 18
                                }

                                // Escape backs out of the menu first, so it does
                                // not close the whole launcher in one press.
                                Keys.onEscapePressed: {
                                    if (window.menuOpen)
                                        window.closeContextMenu();
                                    else
                                        root.open = false;
                                }
                                Keys.onDownPressed: list.incrementCurrentIndex()
                                Keys.onUpPressed: list.decrementCurrentIndex()
                                Keys.onReturnPressed: window.launch(list.currentItem?.entry ?? null)
                                Keys.onEnterPressed: window.launch(list.currentItem?.entry ?? null)
                            }
                        }
                    }

                    ListView {
                        id: list

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.leftMargin: 12
                        Layout.rightMargin: 12
                        Layout.bottomMargin: 12

                        clip: true
                        model: window.results
                        currentIndex: window.results.length > 0 ? 0 : -1
                        highlightMoveDuration: 0
                        keyNavigationEnabled: false
                        reuseItems: true
                        boundsBehavior: Flickable.StopAtBounds

                        delegate: Rectangle {
                            id: row

                            required property var modelData
                            required property int index

                            readonly property var entry: modelData.entry
                            readonly property bool selected: ListView.isCurrentItem

                            width: list.width
                            implicitHeight: 54
                            color: row.selected ? Theme.surface : "transparent"

                            RowLayout {
                                anchors {
                                    fill: parent
                                    leftMargin: 12
                                    rightMargin: 12
                                }
                                spacing: 12

                                Item {
                                    Layout.preferredWidth: 28
                                    Layout.preferredHeight: 28

                                    Grid {
                                        anchors.centerIn: parent
                                        columns: 2
                                        spacing: 3
                                        visible: applicationIcon.status !== Image.Ready

                                        Repeater {
                                            model: 4

                                            Rectangle {
                                                required property int index

                                                width: 9
                                                height: 9
                                                radius: 2
                                                color: row.selected ? Theme.foreground : Theme.muted
                                                opacity: index === 0 || index === 3 ? 1 : 0.65
                                            }
                                        }
                                    }

                                    Image {
                                        id: applicationIcon

                                        anchors.fill: parent
                                        // `check: true` returns an empty URL when desktop entry's
                                        // icon is absent instead of icon provider's checkerboard.
                                        source: row.entry.icon ? Quickshell.iconPath(row.entry.icon, true) : ""
                                        sourceSize.width: 56
                                        sourceSize.height: 56
                                        cache: true
                                        asynchronous: true
                                        smooth: true
                                        visible: applicationIcon.status === Image.Ready
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: row.entry.name
                                    elide: Text.ElideRight
                                    color: row.selected ? Theme.foreground : Theme.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 18
                                    font.weight: Font.Medium
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: mouse => {
                                    list.currentIndex = row.index;

                                    if (mouse.button === Qt.RightButton)
                                        window.openContextMenu(row.entry, row, mouse.x, mouse.y);
                                    else
                                        window.launch(row.entry);
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: window.results.length === 0
                            text: "No matching applications"
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: 16
                        }
                    }
                }
            }
        }

        // Dismiss layer. Swallows the click so closing the menu does not also
        // reach the launcher's own click-outside-to-close handler.
        MouseArea {
            anchors.fill: parent
            visible: window.menuOpen
            z: 10
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onPressed: mouse => {
                window.closeContextMenu();
                mouse.accepted = true;
            }
        }

        Rectangle {
            id: contextMenu

            visible: window.menuOpen
            z: 11
            width: 240
            height: menuColumn.implicitHeight + 12

            // Clamped so a row near the bottom or right edge does not push the
            // menu off screen.
            x: Math.max(8, Math.min(window.menuX, window.width - contextMenu.width - 8))
            y: Math.max(8, Math.min(window.menuY, window.height - contextMenu.height - 8))

            color: Theme.background
            border.width: 2
            border.color: Theme.border

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onPressed: mouse => mouse.accepted = true
            }

            Column {
                id: menuColumn

                anchors {
                    fill: parent
                    leftMargin: 2
                    rightMargin: 2
                    topMargin: 6
                    bottomMargin: 6
                }

                Rectangle {
                    width: menuColumn.width
                    height: 30
                    color: launchHover.containsMouse ? Theme.surface : "transparent"

                    Text {
                        anchors {
                            left: parent.left
                            leftMargin: 14
                            right: parent.right
                            rightMargin: 14
                            verticalCenter: parent.verticalCenter
                        }
                        text: "Launch"
                        color: Theme.foreground
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                    }

                    MouseArea {
                        id: launchHover

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const entry = window.menuEntry;
                            window.closeContextMenu();
                            window.launch(entry);
                        }
                    }
                }

                Repeater {
                    model: window.menuActions

                    Rectangle {
                        id: actionRow

                        required property var modelData

                        width: menuColumn.width
                        height: 30
                        color: actionHover.containsMouse ? Theme.surface : "transparent"

                        Text {
                            anchors {
                                left: parent.left
                                leftMargin: 14
                                right: parent.right
                                rightMargin: 14
                                verticalCenter: parent.verticalCenter
                            }
                            text: actionRow.modelData.name
                            color: Theme.muted
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                        }

                        MouseArea {
                            id: actionHover

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                actionRow.modelData.execute();
                                window.closeContextMenu();
                                root.open = false;
                            }
                        }
                    }
                }
            }
        }
    }
}
