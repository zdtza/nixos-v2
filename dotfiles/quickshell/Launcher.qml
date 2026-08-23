pragma ComponentBehavior: Bound

// Centered application browser matching the shell's compact panel language.
// Right clicking an entry exposes desktop-entry actions that have no other shell UI.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Stylix

Scope {
    id: root

    property bool open: false
    property var terminal: ["kitty"]
    property var targetScreen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    property string openedMonitorName: ""

    function screenForMonitor(name: string): var {
        for (const screen of Quickshell.screens) {
            if (String(screen.name) === name)
                return screen;
        }
        return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null;
    }

    function show(): void {
        const monitorName = String(Hyprland.focusedMonitor?.name ?? "");
        root.openedMonitorName = monitorName;
        root.targetScreen = root.screenForMonitor(monitorName);
        PanelService.closeActive();
        root.open = true;
    }

    function toggle(): void {
        if (root.open)
            root.open = false;
        else
            root.show();
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void { root.toggle(); }
        function open(): void { root.show(); }
        function close(): void { root.open = false; }
        function isOpen(): bool { return root.open; }
    }

    Connections {
        target: Hyprland

        function onFocusedMonitorChanged(): void {
            if (!root.open)
                return;
            const monitorName = String(Hyprland.focusedMonitor?.name ?? "");
            if (monitorName !== root.openedMonitorName)
                root.open = false;
        }
    }

    PanelWindow {
        id: window

        screen: root.targetScreen
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
        WlrLayershell.keyboardFocus: root.open
            ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        readonly property var entries: {
            const entries = [];
            for (const entry of DesktopEntries.applications.values) {
                if (entry.noDisplay)
                    continue;

                const subtitle = entry.comment || entry.genericName || "Application";
                entries.push({
                    entry,
                    name: entry.name.toLowerCase(),
                    description: `${entry.comment ?? ""} ${entry.genericName ?? ""}`.toLowerCase(),
                    subtitle
                });
            }
            return entries.sort((a, b) => a.entry.name.localeCompare(b.entry.name));
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
            if (item.name.startsWith(token)) return 0;
            if (item.name.includes(token)) return 1;
            if (window.fuzzyMatches(item.name, token)) return 2;
            if (item.description.includes(token)) return 3;
            return -1;
        }

        readonly property var results: {
            const tokens = search.text.toLowerCase().split(" ").filter(token => token !== "");
            if (tokens.length === 0)
                return window.entries;

            const matches = [];
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
                    matches.push({ item, tier });
            }
            return matches.sort((a, b) => a.tier - b.tier).map(match => match.item);
        }

        property var menuEntry: null
        property real menuX: 0
        property real menuY: 0
        readonly property bool menuOpen: menuEntry !== null
        readonly property var menuActions: menuEntry?.actions ?? []

        function openContextMenu(entry: DesktopEntry, item: Item, localX: real, localY: real): void {
            if (!entry)
                return;
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

            if (entry.runInTerminal) {
                Quickshell.execDetached({
                    command: [...root.terminal, "--", ...entry.command],
                    workingDirectory: entry.workingDirectory || Quickshell.env("HOME")
                });
            } else {
                entry.execute();
            }
            root.open = false;
        }

        onVisibleChanged: {
            window.closeContextMenu();
            if (!visible)
                return;
            search.text = "";
            search.forceActiveFocus();
            appList.currentIndex = 0;
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.open = false
        }

        Rectangle {
            id: launcherFrame

            anchors.centerIn: parent
            width: 520
            height: 680
            color: Theme.background
            border.width: 2
            border.color: Theme.border

            MouseArea {
                anchors.fill: parent
                onPressed: mouse => mouse.accepted = true
            }

            ColumnLayout {
                anchors {
                    fill: parent
                    leftMargin: 20
                    rightMargin: 20
                    topMargin: 18
                    bottomMargin: 14
                }
                spacing: 14

                PanelHero {
                    Layout.fillWidth: true
                    icon: "󰀻"
                    title: "Applications"
                    status: search.text.length > 0
                        ? `${window.results.length} MATCHES`
                        : `${window.entries.length} INSTALLED`
                    trailingWidth: 46
                    trailingHeight: 22

                    Rectangle {
                        anchors.fill: parent
                        color: Theme.dark_background
                        border.width: 1
                        border.color: Theme.surface

                        Text {
                            anchors.centerIn: parent
                            text: "ESC"
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.bold: true
                            font.letterSpacing: 1
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 42
                    color: Theme.dark_background
                    border.width: 1
                    border.color: search.activeFocus ? Theme.muted : Theme.surface

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 13
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰍉"
                        color: search.activeFocus ? Theme.foreground : Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 16
                    }

                    TextInput {
                        id: search

                        anchors {
                            left: parent.left
                            right: parent.right
                            leftMargin: 40
                            rightMargin: 14
                            verticalCenter: parent.verticalCenter
                        }
                        height: 28
                        verticalAlignment: TextInput.AlignVCenter
                        focus: true
                        selectByMouse: true
                        clip: true
                        color: Theme.foreground
                        selectionColor: Theme.surface
                        selectedTextColor: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: 14

                        cursorDelegate: Rectangle {
                            width: 1
                            color: Theme.accent
                        }

                        onTextChanged: appList.currentIndex = 0

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            visible: search.text === ""
                            text: "Type to search applications…"
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                        }

                        Keys.onEscapePressed: {
                            if (window.menuOpen)
                                window.closeContextMenu();
                            else
                                root.open = false;
                        }
                        Keys.onDownPressed: appList.incrementCurrentIndex()
                        Keys.onUpPressed: appList.decrementCurrentIndex()
                        Keys.onReturnPressed: window.launch(appList.currentItem?.entry ?? null)
                        Keys.onEnterPressed: window.launch(appList.currentItem?.entry ?? null)
                    }
                }

                ListView {
                    id: appList

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: window.results
                    currentIndex: window.results.length > 0 ? 0 : -1
                    highlightMoveDuration: 0
                    keyNavigationEnabled: false
                    reuseItems: true
                    boundsBehavior: Flickable.StopAtBounds
                    spacing: 2

                    delegate: Rectangle {
                        id: appRow

                        required property var modelData
                        required property int index
                        readonly property var entry: modelData.entry
                        readonly property bool selected: ListView.isCurrentItem

                        width: appList.width
                        height: 52
                        color: selected ? Theme.surface
                            : (rowMouse.containsMouse ? Theme.dark_background : "transparent")

                        Rectangle {
                            anchors {
                                left: parent.left
                                top: parent.top
                                bottom: parent.bottom
                            }
                            width: 2
                            visible: appRow.selected
                            color: Theme.accent
                        }

                        Item {
                            id: iconFrame
                            anchors.left: parent.left
                            anchors.leftMargin: 13
                            anchors.verticalCenter: parent.verticalCenter
                            width: 28
                            height: 28

                            Grid {
                                anchors.centerIn: parent
                                columns: 2
                                spacing: 3
                                visible: applicationIcon.status !== Image.Ready

                                Repeater {
                                    model: 4
                                    Rectangle {
                                        required property int index
                                        width: 8
                                        height: 8
                                        color: appRow.selected ? Theme.foreground : Theme.muted
                                        opacity: index === 0 || index === 3 ? 1 : 0.55
                                    }
                                }
                            }

                            Image {
                                id: applicationIcon
                                anchors.fill: parent
                                source: appRow.entry.icon
                                    ? Quickshell.iconPath(appRow.entry.icon, true) : ""
                                sourceSize.width: 56
                                sourceSize.height: 56
                                cache: true
                                asynchronous: true
                                smooth: true
                                visible: status === Image.Ready
                            }
                        }

                        Column {
                            anchors {
                                left: iconFrame.right
                                right: actionHint.left
                                leftMargin: 13
                                rightMargin: 12
                                verticalCenter: parent.verticalCenter
                            }
                            spacing: 2

                            Text {
                                width: parent.width
                                text: appRow.entry.name
                                color: Theme.foreground
                                elide: Text.ElideRight
                                font.family: Theme.fontFamily
                                font.pixelSize: 14
                                font.bold: appRow.selected
                            }

                            Text {
                                width: parent.width
                                text: appRow.modelData.subtitle
                                color: Qt.darker(Theme.foreground, 1.4)
                                elide: Text.ElideRight
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                            }
                        }

                        Text {
                            id: actionHint
                            anchors.right: parent.right
                            anchors.rightMargin: 14
                            anchors.verticalCenter: parent.verticalCenter
                            text: appRow.selected ? "↵" : ""
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                        }

                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: mouse => {
                                appList.currentIndex = appRow.index;
                                if (mouse.button === Qt.RightButton)
                                    window.openContextMenu(appRow.entry, appRow, mouse.x, mouse.y);
                                else
                                    window.launch(appRow.entry);
                            }
                        }
                    }

                    Column {
                        anchors.centerIn: parent
                        visible: window.results.length === 0
                        spacing: 10

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "󰈉"
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: 28
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "NO MATCHING APPLICATIONS"
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.bold: true
                            font.letterSpacing: 1
                        }
                    }
                }

            }
        }

        // Close context menu without also dismissing launcher.
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
            width: 250
            height: contextColumn.implicitHeight + 24
            x: Math.max(8, Math.min(window.menuX, window.width - width - 8))
            y: Math.max(8, Math.min(window.menuY, window.height - height - 8))
            color: Theme.background
            border.width: 2
            border.color: Theme.border

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onPressed: mouse => mouse.accepted = true
            }

            Column {
                id: contextColumn
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: 12
                }
                spacing: 2

                PanelSectionHeader {
                    width: contextColumn.width
                    title: "APPLICATION ACTIONS"
                }

                Item { width: 1; height: 6 }

                Rectangle {
                    width: contextColumn.width
                    height: 34
                    color: launchMouse.containsMouse ? Theme.surface : "transparent"

                    Text {
                        anchors {
                            left: parent.left
                            leftMargin: 10
                            verticalCenter: parent.verticalCenter
                        }
                        text: "Launch"
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.bold: true
                    }

                    Text {
                        anchors {
                            right: parent.right
                            rightMargin: 10
                            verticalCenter: parent.verticalCenter
                        }
                        text: "↵"
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                    }

                    MouseArea {
                        id: launchMouse
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
                        width: contextColumn.width
                        height: 34
                        color: actionMouse.containsMouse ? Theme.surface : "transparent"

                        Text {
                            anchors {
                                left: parent.left
                                right: parent.right
                                leftMargin: 10
                                rightMargin: 10
                                verticalCenter: parent.verticalCenter
                            }
                            text: actionRow.modelData.name
                            color: Theme.muted
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                        }

                        MouseArea {
                            id: actionMouse
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
