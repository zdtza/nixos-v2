pragma ComponentBehavior: Bound

// Application launcher, replaces fuzzel.
//
// Toggled over IPC from the window manager:
//   qs ipc call launcher toggle
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
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
        color: Theme.overlay
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

        function description(entry: DesktopEntry): string {
            if (entry.comment)
                return entry.comment;
            if (entry.genericName)
                return entry.genericName;
            return "Application";
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
            width: 560
            height: 530
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
                        implicitHeight: 85

                        Column {
                            anchors.left: parent.left
                            anchors.leftMargin: 24
                            anchors.top: parent.top
                            anchors.topMargin: 22
                            spacing: 4

                            Text {
                                text: "Applications"
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: 21
                                font.weight: Font.Medium
                                font.letterSpacing: 0.1
                            }

                            Text {
                                text: "SELECT AND RUN"
                                color: Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                font.letterSpacing: 2
                            }
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: 24
                            anchors.top: parent.top
                            anchors.topMargin: 30
                            text: window.results.length + "/" + window.entries.length
                            color: Theme.accent
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            font.letterSpacing: 0.5
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        implicitHeight: 64

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: 24
                            anchors.rightMargin: 24
                            height: 44
                            color: Theme.dark_background
                            border.width: 1
                            border.color: Theme.surface

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 14
                                anchors.verticalCenter: parent.verticalCenter
                                text: "›"
                                color: Theme.accent
                                font.family: Theme.fontFamily
                                font.pixelSize: 14
                                font.bold: true
                            }

                            TextInput {
                                id: search

                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.leftMargin: 34
                                anchors.rightMargin: 14
                                anchors.verticalCenter: parent.verticalCenter
                                height: 24
                                verticalAlignment: TextInput.AlignVCenter
                                focus: true
                                selectByMouse: true
                                clip: true

                                color: Theme.foreground
                                selectionColor: Theme.surface
                                selectedTextColor: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: 14
                                font.letterSpacing: 0.15

                                cursorDelegate: Rectangle {
                                    width: 1
                                    color: Theme.accent
                                }

                                onTextChanged: list.currentIndex = 0

                                Text {
                                    anchors.fill: parent
                                    verticalAlignment: Text.AlignVCenter
                                    visible: search.text === ""
                                    text: "type to filter"
                                    color: Theme.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 14
                                    font.letterSpacing: 0.15
                                }

                                Keys.onEscapePressed: root.open = false
                                Keys.onDownPressed: list.incrementCurrentIndex()
                                Keys.onUpPressed: list.decrementCurrentIndex()
                                Keys.onReturnPressed: window.launch(list.currentItem?.entry ?? null)
                                Keys.onEnterPressed: window.launch(list.currentItem?.entry ?? null)
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 1
                        color: Theme.dark_background
                    }

                    ListView {
                        id: list

                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        clip: true
                        model: window.results
                        currentIndex: window.results.length > 0 ? 0 : -1
                        highlightMoveDuration: 0
                        keyNavigationEnabled: false
                        reuseItems: true
                        boundsBehavior: Flickable.StopAtBounds

                        header: Item {
                            width: list.width
                            height: 42

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 24
                                anchors.top: parent.top
                                anchors.topMargin: 14
                                text: search.text.trim() === "" ? "ALL APPLICATIONS" : "RESULTS"
                                color: Theme.border
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                font.letterSpacing: 2
                            }
                        }

                        footer: Item {
                            width: list.width
                            height: 18
                        }

                        Controls.ScrollBar.vertical: Controls.ScrollBar {
                            policy: Controls.ScrollBar.AlwaysOn
                            width: 6

                            contentItem: Rectangle {
                                implicitWidth: 6
                                color: Theme.surface
                            }

                            background: Item {}
                        }

                        delegate: Item {
                            id: row

                            required property var modelData
                            required property int index

                            readonly property var entry: modelData.entry
                            readonly property bool selected: ListView.isCurrentItem

                            width: list.width
                            implicitHeight: 54

                            Rectangle {
                                anchors {
                                    fill: parent
                                    leftMargin: 12
                                    rightMargin: 12
                                }
                                color: row.selected ? Theme.surface : "transparent"

                                Text {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 14
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 26
                                    horizontalAlignment: Text.AlignHCenter
                                    text: row.entry.name.length > 0 ? row.entry.name[0].toUpperCase() : "·"
                                    color: row.selected ? Theme.accent : Theme.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 15
                                    font.weight: Font.Bold
                                }

                                Column {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 54
                                    anchors.right: parent.right
                                    anchors.rightMargin: 14
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2

                                    Text {
                                        width: parent.width
                                        text: row.entry.name
                                        elide: Text.ElideRight
                                        color: Theme.foreground
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 14
                                        font.weight: Font.Medium
                                        font.letterSpacing: 0.1
                                    }

                                    Text {
                                        width: parent.width
                                        text: window.description(row.entry)
                                        elide: Text.ElideRight
                                        color: row.selected ? Theme.foreground : Theme.muted
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 11
                                        font.letterSpacing: 0.25
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        list.currentIndex = row.index;
                                        window.launch(row.entry);
                                    }
                                }
                            }
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 24
                            anchors.top: parent.top
                            anchors.topMargin: 62
                            visible: window.results.length === 0
                            text: "No applications match that filter."
                            color: Theme.border
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            font.letterSpacing: 0.5
                        }
                    }
                }
            }
        }
    }
}
