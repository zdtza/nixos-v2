pragma ComponentBehavior: Bound

// Application launcher drawer, opened from the 4-square bar button or Super+Space.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../components"
import "../services"
import ".."

Item {
    id: root

    property bool showButton: true
    readonly property bool opened: PanelService.activePanel === root
    readonly property bool requiresKeyboardFocus: true
    readonly property bool isLauncher: true

    property int currentIndex: 0
    property string query: ""
    property int searchCursorPosition: 0

    // Mounted in the bar window while this panel is active; the bar window owns
    // keyboard focus, so the search box in the drawer only mirrors this input.
    readonly property Component keyboardProxy: searchProxy

    implicitWidth: showButton ? 26 : 0
    implicitHeight: PanelService.barItemHeight

    // --- application results ---
    readonly property var results: {
        const tokens = root.query.toLowerCase().split(" ").filter(token => token !== "");
        if (tokens.length === 0) {
            return LauncherService.entries;
        }
        const matches = [];
        for (const item of LauncherService.entries) {
            let tier = 0;
            for (const token of tokens) {
                const tokenTier = LauncherService.matchTier(item, token);
                if (tokenTier === -1) {
                    tier = -1;
                    break;
                }
                tier = Math.max(tier, tokenTier);
            }
            if (tier !== -1)
                matches.push({ item, tier });
        }
        const found = matches.sort((a, b) => a.tier - b.tier
            || a.item.entry.name.localeCompare(b.item.entry.name)).map(match => match.item);
        return found.length > 0 || LauncherService.entries.length === 0
            ? found : LauncherService.fallbackResults(root.query);
    }

    readonly property var selectedItem: root.results[root.currentIndex] ?? null

    // --- interaction ---
    function itemLoading(item: var): bool {
        return !!item && !item.isFallback && LauncherService.isLaunching(item.entry.id);
    }

    function moveSelection(offset: int): void {
        if (root.results.length === 0) {
            root.currentIndex = -1;
            return;
        }
        const step = offset < 0 ? -1 : 1;
        let index = root.currentIndex + step;
        while (index >= 0 && index < root.results.length) {
            if (!root.itemLoading(root.results[index])) {
                root.currentIndex = index;
                appList.positionViewAtIndex(index, ListView.Contain);
                return;
            }
            index += step;
        }
    }

    function activate(item: var): void {
        if (!item || root.itemLoading(item))
            return;
        if (item.isFallback)
            LauncherService.launchDetached(item.command, "");
        else
            LauncherService.launch(item.entry);
        PanelService.close(root);
    }

    onOpenedChanged: {
        root.query = "";
        root.searchCursorPosition = 0;
        root.currentIndex = root.results.findIndex(item => !root.itemLoading(item));
        if (root.opened)
            Qt.callLater(() => appList.positionViewAtBeginning());
    }
    onResultsChanged: {
        PanelService.hoverSelectReady = false;
        PanelService.hoverArmPosition = null;
        root.currentIndex = root.results.findIndex(item => !root.itemLoading(item));
    }

    Component {
        id: searchProxy

        TextInput {
            id: proxyInput

            focus: true
            text: root.query

            onTextEdited: root.query = text
            onCursorPositionChanged: {
                if (activeFocus)
                    root.searchCursorPosition = cursorPosition;
            }
            onActiveFocusChanged: {
                if (activeFocus)
                    cursorPosition = root.searchCursorPosition;
            }

            Connections {
                target: root
                function onQueryChanged(): void {
                    if (proxyInput.text !== root.query)
                        proxyInput.text = root.query;
                }
                function onSearchCursorPositionChanged(): void {
                    if (proxyInput.cursorPosition !== root.searchCursorPosition)
                        proxyInput.cursorPosition = root.searchCursorPosition;
                }
            }

            Keys.onEscapePressed: PanelService.close(root)
            Keys.onDownPressed: root.moveSelection(1)
            Keys.onUpPressed: root.moveSelection(-1)
            Keys.onReturnPressed: root.activate(root.selectedItem)
            Keys.onEnterPressed: root.activate(root.selectedItem)
            Keys.onPressed: event => {
                if (event.key === Qt.Key_C && event.modifiers === Qt.ControlModifier) {
                    root.query = "";
                    event.accepted = true;
                }
            }
        }
    }

    // --- bar button ---
    LauncherIcon {
        anchors.centerIn: parent
        visible: root.showButton
        color: root.opened || buttonMouse.containsMouse ? Theme.textPrimary : Theme.textSecondary
        size: 16
    }

    MouseArea {
        id: buttonMouse
        anchors.fill: parent
        enabled: root.showButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: PanelService.toggle(root)
    }

    HyprlandFocusGrab {
        active: root.opened && !PanelService.refocusing
        windows: [panel, root.QsWindow.window]
        onCleared: if (!PanelService.refocusing) PanelService.close(root)
    }

    Drawer {
        id: panel

        anchorItem: root
        anchorWindow: root.QsWindow.window
        open: root.opened
        centeredHorizontally: true
        centeredVertically: true
        onCloseRequested: PanelService.close(root)
        contentMargins: 0
        contentSpacing: 0
        implicitWidth: 420
        // Search plus exactly nine application rows (64px rows, 4px spacing).
        implicitHeight: Math.min(16 + searchBox.height + 12 + 608 + 16,
            (root.QsWindow.window?.screen?.height ?? 800)
            - PanelService.panelBarInset - PanelService.panelGap * 2)

        Item {
            width: parent.width
            height: panel.implicitHeight

            // --- search ---
            Item {
                id: searchBox
                anchors {
                    top: parent.top; topMargin: 16
                    left: parent.left; right: parent.right
                    leftMargin: 40; rightMargin: 40
                }
                height: 52
                Item {
                    id: input
                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                    }
                    height: 32
                    clip: true

                    ShellText {
                        id: queryText
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.query
                        size: 16
                    }

                    TextMetrics {
                        id: cursorMetrics
                        font: queryText.font
                        text: root.query.slice(0, root.searchCursorPosition)
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        x: cursorMetrics.advanceWidth
                        width: 1
                        height: 20
                        color: Theme.base05
                    }

                    ShellText {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.query === ""
                        x: 2
                        text: "Search applications"
                        color: Theme.textSecondary
                        size: 16
                    }
                }
            }

            // --- lists ---
            Item {
                anchors {
                    top: searchBox.bottom; bottom: parent.bottom
                    left: parent.left; right: parent.right
                    topMargin: 12
                    bottomMargin: 16
                }

                ListView {
                    id: appList
                    anchors.fill: parent
                    model: root.results
                    currentIndex: -1
                    clip: true
                    spacing: 4
                    boundsBehavior: Flickable.StopAtBounds
                    maximumFlickVelocity: 12000

                    FastScroll { view: appList }

                    delegate: Rectangle {
                        id: row

                        required property var modelData
                        required property int index
                        readonly property bool current: index === root.currentIndex

                        width: ListView.view.width
                        height: 64
                        color: row.current ? Utils.alpha(Theme.base05, 0.11) : "transparent"

                        readonly property bool rowLaunching: root.itemLoading(row.modelData)

                        Image {
                            id: rowIcon
                            anchors { left: parent.left; leftMargin: 28; verticalCenter: parent.verticalCenter }
                            width: 32
                            height: 32
                            opacity: row.rowLaunching ? 0.35 : 1
                            source: row.modelData.entry.icon
                                ? Quickshell.iconPath(row.modelData.entry.icon, true) : ""
                            sourceSize.width: 64
                            sourceSize.height: 64
                            asynchronous: true
                            smooth: true
                        }

                        Spinner {
                            anchors.centerIn: rowIcon
                            size: 24
                            visible: row.rowLaunching
                        }

                        ShellText {
                            anchors {
                                left: rowIcon.right; leftMargin: 18
                                right: parent.right; rightMargin: 28
                                verticalCenter: parent.verticalCenter
                            }
                            textFormat: Text.PlainText
                            text: row.modelData.entry.name
                            opacity: row.rowLaunching ? 0.5 : 1
                            elide: Text.ElideRight
                            size: 16
                        }

                        HoverHandler {
                            enabled: !row.rowLaunching
                            cursorShape: Qt.PointingHandCursor
                            onPointChanged: if (PanelService.hoverSelectReady)
                                root.currentIndex = row.index
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: !row.rowLaunching
                            acceptedButtons: Qt.LeftButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.activate(row.modelData)
                        }
                    }
                }

                ShellText {
                    anchors.centerIn: parent
                    visible: root.results.length === 0
                    text: LauncherService.entries.length === 0 ? "LOADING APPLICATIONS…" : "NO MATCHES"
                    color: Theme.textSecondary
                    font.letterSpacing: 1
                    size: 12
                }

            }

        }
    }
}
