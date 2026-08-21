pragma ComponentBehavior: Bound

// Application launcher, replaces fuzzel.
//
// Toggled over IPC from the window manager:
//   qs ipc call launcher toggle
//
// Deliberately minimal: names and icons only, fuzzy subsequence match over the
// entry name and description, no ranking, no animations. The window is built
// once at startup and only toggles visibility, so opening is instant.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Stylix

Scope {
    id: root

    property bool open: false

    // Desktop entries with `Terminal=true` carry a bare command (`btop`), so they
    // need a terminal emulator wrapped around them or they exit immediately.
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

        // Built once: every entry paired with its lowercased name and
        // description, so filtering is a couple of string scans per entry.
        // Descriptions live in either comment or genericName depending on the
        // desktop file, so both are folded together.
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

        // Subsequence match: every character must appear in order, not
        // necessarily adjacent ("chrm" -> Chromium).
        function fuzzyMatches(haystack: string, token: string): bool {
            let index = -1;

            for (const character of token) {
                index = haystack.indexOf(character, index + 1);
                if (index === -1)
                    return false;
            }

            return true;
        }

        // Match quality, lower is better. Fuzzy applies to the name only;
        // descriptions need a contiguous match, otherwise near enough every
        // entry matches every query.
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

                    // Every token has to match somewhere; the worst one decides
                    // where the entry lands.
                    if (tokenTier === -1) {
                        tier = -1;
                        break;
                    }

                    tier = Math.max(tier, tokenTier);
                }

                if (tier !== -1)
                    matched.push({
                        item,
                        tier
                    });
            }

            // Entries are already alphabetical, so a stable sort on tier alone
            // keeps names ordered inside each tier.
            return matched.sort((a, b) => a.tier - b.tier).map(match => match.item);
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

        // Click-outside to dismiss.
        MouseArea {
            anchors.fill: parent
            onClicked: root.open = false
        }

        Rectangle {
            anchors.centerIn: parent
            width: 560
            height: 420

            color: Theme.background
            radius: 0
            border.width: 1
            border.color: Theme.border

            // Swallow clicks so they don't reach the dismiss handler.
            MouseArea {
                anchors.fill: parent
                onPressed: mouse => mouse.accepted = true
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // --- search field ---
                Item {
                    Layout.fillWidth: true
                    implicitHeight: 44

                    TextInput {
                        id: search

                        anchors {
                            fill: parent
                            leftMargin: 14
                            rightMargin: 14
                        }

                        verticalAlignment: TextInput.AlignVCenter
                        focus: true
                        selectByMouse: true
                        clip: true

                        color: Theme.foreground
                        selectionColor: Theme.accent
                        selectedTextColor: Theme.background
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize

                        onTextChanged: list.currentIndex = 0

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            visible: search.text === ""
                            text: "Search"
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                        }

                        Keys.onEscapePressed: root.open = false
                        Keys.onDownPressed: list.incrementCurrentIndex()
                        Keys.onUpPressed: list.decrementCurrentIndex()
                        Keys.onReturnPressed: window.launch(list.currentItem?.entry ?? null)
                        Keys.onEnterPressed: window.launch(list.currentItem?.entry ?? null)
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Theme.border
                }

                // --- results ---
                ListView {
                    id: list

                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    clip: true
                    model: window.results
                    currentIndex: 0
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
                        implicitHeight: 36
                        color: row.selected ? Theme.surface : "transparent"

                        RowLayout {
                            anchors {
                                fill: parent
                                leftMargin: 14
                                rightMargin: 14
                            }
                            spacing: 12

                            Image {
                                Layout.preferredWidth: Theme.fontSize + 6
                                Layout.preferredHeight: Theme.fontSize + 6
                                source: Quickshell.iconPath(row.entry.icon, "application-x-executable")
                                sourceSize.width: 32
                                sourceSize.height: 32
                                cache: true
                                asynchronous: true
                                smooth: true
                            }

                            Text {
                                Layout.fillWidth: true
                                text: row.entry.name
                                elide: Text.ElideRight
                                color: row.selected ? Theme.foreground : Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
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
            }
        }
    }
}
