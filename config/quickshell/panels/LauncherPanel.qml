pragma ComponentBehavior: Bound

// Application launcher drawer, opened from the 4-square bar button or Super+Space.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "../components"
import "../services"
import ".."

Item {
    id: root

    property bool showButton: true
    readonly property bool opened: PanelService.activePanel === root
    readonly property bool requiresKeyboardFocus: true
    readonly property bool isLauncher: true

    property bool keybindMode: false
    property int currentIndex: 0
    property var binds: []
    property string bindsLoadError: ""
    property string query: ""

    // Mounted in the bar window while this panel is active; the bar window owns
    // keyboard focus, so the search box in the drawer only mirrors this input.
    readonly property Component keyboardProxy: searchProxy

    // Keybind rows borrow the shared hover gating through this name.
    readonly property bool hoverSelectReady: PanelService.hoverSelectReady

    implicitWidth: showButton ? 26 : 0
    implicitHeight: PanelService.barItemHeight

    // --- application results ---
    function withGroup(items: var, group: string): var {
        return items.map(item => Object.assign({}, item, { group }));
    }

    readonly property var results: {
        const tokens = root.query.toLowerCase().split(" ").filter(token => token !== "");
        if (tokens.length === 0) {
            return [
                ...root.withGroup(LauncherService.recentEntries, "RECENT"),
                ...root.withGroup(LauncherService.remainingEntries, "ALL APPLICATIONS")
            ];
        }
        const keybindingsItem = {
            isKeybinds: true,
            name: "keybindings",
            categories: "settings system keyboard",
            description: "browse shell window management shortcuts hotkeys",
            entry: {
                id: "quickshell-keybindings",
                name: "Keybindings",
                icon: "preferences-desktop-keyboard",
                comment: "Browse shell and window-management shortcuts",
                categories: ["Settings"]
            }
        };
        const matches = [];
        for (const item of [...LauncherService.entries, keybindingsItem]) {
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
        return root.withGroup(found.length > 0 || LauncherService.entries.length === 0
            ? found : LauncherService.fallbackResults(root.query), "RESULTS");
    }

    // Flat list rows: a header whenever the group changes, then the app itself.
    // `appIndex` is the position in `results`, which selection works in.
    readonly property var rows: {
        const counts = {};
        for (const item of root.results)
            counts[item.group] = (counts[item.group] ?? 0) + 1;
        const flat = [];
        let group = "";
        root.results.forEach((item, appIndex) => {
            if (item.group !== group) {
                group = item.group;
                flat.push({ isHeader: true, title: group, count: counts[group] });
            }
            flat.push({ isHeader: false, item, appIndex });
        });
        return flat;
    }

    // --- keybinds ---
    function keyName(key: string): string {
        if (key.startsWith("switch:"))
            return key.replace(/^switch:o(n|ff):/, "").replace(/\s*Switch$/, "")
                + (key.startsWith("switch:on:") ? " Close" : " Open");
        if (key.startsWith("XF86"))
            return key.slice(4).replace(/([a-z])([A-Z])/g, "$1 $2");
        if (key === "mouse:272") return "Left Mouse";
        if (key === "mouse:273") return "Right Mouse";
        if (key === "mouse:274") return "Middle Mouse";
        if (key === "mouse_up") return "Scroll Up";
        if (key === "mouse_down") return "Scroll Down";
        if (key.startsWith("mouse:") || key.startsWith("code:")) return key;
        if (key.length === 1) return key.toUpperCase();
        return key.charAt(0).toUpperCase() + key.slice(1);
    }

    function modifierText(bind: var): string {
        const parts = [];
        for (const modifier of [{ bit: 64, name: "SUPER" }, { bit: 4, name: "CTRL" },
                { bit: 8, name: "ALT" }, { bit: 1, name: "SHIFT" }]) {
            if (bind.modmask & modifier.bit)
                parts.push(modifier.name);
        }
        return parts.join(" + ");
    }

    function chordText(bind: var): string {
        const modifiers = root.modifierText(bind);
        const key = root.keyName(String(bind.key ?? ""));
        return modifiers === "" ? key : `${modifiers} + ${key}`;
    }

    readonly property var keybindRows: {
        const tokens = root.query.toLowerCase().split(" ").filter(token => token !== "");
        const rows = [];
        for (const bind of root.binds) {
            const chord = root.chordText(bind);
            const description = String(bind.description ?? "");
            const haystack = `${chord} ${description}`.toLowerCase();
            if (tokens.every(token => haystack.includes(token)
                    || Utils.fuzzyMatches(haystack, token)))
                rows.push(Object.assign({}, bind, { chord, description }));
        }
        return rows.sort((a, b) => a.modmask - b.modmask
            || a.description.localeCompare(b.description));
    }

    readonly property var activeModel: root.keybindMode ? root.keybindRows : root.results
    readonly property var selectedItem: root.activeModel[root.currentIndex] ?? null

    function showKeybinds(): void {
        root.keybindMode = true;
        root.query = "";
        root.currentIndex = 0;
        if (root.binds.length === 0 && !bindsProcess.running)
            bindsProcess.running = true;
    }

    function toggleKeybinds(): void {
        if (root.opened && root.keybindMode) {
            PanelService.close(root);
            return;
        }
        if (!root.opened)
            PanelService.open(root);
        root.showKeybinds();
    }

    // --- interaction ---
    // Wraps the characters of `name` that match the query in a highlight colour.
    function highlighted(name: string): string {
        const lower = name.toLowerCase();
        const marked = new Array(name.length).fill(false);
        for (const token of root.query.toLowerCase().split(" ").filter(token => token !== "")) {
            const at = lower.indexOf(token);
            if (at !== -1) {
                for (let i = at; i < at + token.length; ++i)
                    marked[i] = true;
                continue;
            }
            // Subsequence match, as used for ranking.
            const picked = [];
            let index = -1;
            for (const character of token) {
                index = lower.indexOf(character, index + 1);
                if (index === -1)
                    break;
                picked.push(index);
            }
            if (picked.length === token.length)
                picked.forEach(i => marked[i] = true);
        }
        const escape = character => character === "&" ? "&amp;"
            : character === "<" ? "&lt;" : character === ">" ? "&gt;" : character;
        let html = "";
        let open = false;
        for (let i = 0; i < name.length; ++i) {
            if (marked[i] !== open) {
                html += open ? "</b>" : "<b>";
                open = marked[i];
            }
            html += escape(name[i]);
        }
        return open ? html + "</b>" : html;
    }

    function moveSelection(offset: int): void {
        if (root.activeModel.length === 0) {
            root.currentIndex = -1;
            return;
        }
        root.currentIndex = Math.max(0, Math.min(root.activeModel.length - 1,
            Math.max(0, root.currentIndex) + offset));
        if (root.keybindMode)
            keybindList.positionViewAtIndex(root.currentIndex, ListView.Contain);
        else
            appList.positionViewAtIndex(root.rows.findIndex(
                row => !row.isHeader && row.appIndex === root.currentIndex), ListView.Contain);
    }

    function activate(item: var): void {
        if (!item)
            return;
        if (item.isKeybinds) {
            root.showKeybinds();
            return;
        }
        if (item.isFallback)
            LauncherService.launchDetached(item.command, "");
        else
            LauncherService.launch(item.entry);
        PanelService.close(root);
    }

    onOpenedChanged: {
        root.keybindMode = false;
        root.query = "";
        root.currentIndex = 0;
        if (root.opened)
            Qt.callLater(() => appList.positionViewAtBeginning());
    }
    onActiveModelChanged: {
        PanelService.hoverSelectReady = false;
        PanelService.hoverArmPosition = null;
        root.currentIndex = root.activeModel.length > 0 ? 0 : -1;
    }

    Component {
        id: searchProxy

        TextInput {
            id: proxyInput

            focus: true
            text: root.query

            onTextEdited: root.query = text

            Connections {
                target: root
                function onQueryChanged(): void {
                    if (proxyInput.text !== root.query)
                        proxyInput.text = root.query;
                }
            }

            Keys.onEscapePressed: PanelService.close(root)
            Keys.onDownPressed: root.moveSelection(1)
            Keys.onUpPressed: root.moveSelection(-1)
            Keys.onReturnPressed: if (!root.keybindMode) root.activate(root.selectedItem)
            Keys.onEnterPressed: if (!root.keybindMode) root.activate(root.selectedItem)
            Keys.onPressed: event => {
                if (event.key === Qt.Key_C && event.modifiers === Qt.ControlModifier) {
                    root.query = "";
                    event.accepted = true;
                }
            }
        }
    }

    Process {
        id: bindsProcess
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    root.binds = JSON.parse(text);
                    root.bindsLoadError = "";
                } catch (error) {
                    root.binds = [];
                    root.bindsLoadError = "Could not read keybindings";
                }
            }
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event: var): void {
            if (event.name === "configreloaded")
                root.binds = [];
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
        leftAligned: true
        onCloseRequested: PanelService.close(root)
        contentMargins: 0
        contentSpacing: 0
        implicitWidth: 420
        // Header, search and footer plus exactly nine application rows (48px rows, 2px spacing),
        // so the list never ends part-way through a row.
        implicitHeight: Math.min(header.height + searchBox.height + 8 + 448 + footer.height,
            (root.QsWindow.window?.screen?.height ?? 800)
            - PanelService.panelBarInset - PanelService.panelGap * 2)

        Item {
            width: parent.width
            height: panel.implicitHeight

            // --- header ---
            Item {
                id: header
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: 80

                Hero {
                    anchors {
                        left: parent.left; right: parent.right
                        leftMargin: 20; rightMargin: 20
                        verticalCenter: parent.verticalCenter
                    }
                    icon: "\uf313"
                    title: root.keybindMode ? "Keybindings" : "Launcher"
                    status: root.keybindMode
                        ? `${root.keybindRows.length} SHORTCUTS`
                        : `${LauncherService.entries.length} APPLICATIONS`
                    trailingWidth: chipLabel.implicitWidth + 16
                    trailingHeight: 22

                    Rectangle {
                        anchors.fill: parent
                        radius: PanelService.rounding
                        color: Utils.alpha(Theme.base05, 0.08)

                        ShellText {
                            id: chipLabel
                            anchors.centerIn: parent
                            text: "SUPER + SPACE"
                            color: Theme.textSecondary
                            size: 10
                            font.letterSpacing: 1.2
                        }
                    }
                }
            }

            // --- search ---
            Rectangle {
                id: searchBox
                anchors {
                    top: header.bottom
                    left: parent.left; right: parent.right
                    leftMargin: 20; rightMargin: 20
                }
                height: 42
                radius: PanelService.rounding
                color: Theme.base00
                border.width: PanelService.chromeBorderWidth
                border.color: PanelService.chromeBorderColor

                ShellText {
                    id: searchIcon
                    anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                    text: "󰍉"
                    color: Theme.textSecondary
                    size: 14
                }

                Item {
                    id: input
                    anchors {
                        left: searchIcon.right; leftMargin: 12
                        right: parent.right; rightMargin: 14
                        verticalCenter: parent.verticalCenter
                    }
                    height: 26
                    clip: true

                    ShellText {
                        id: queryText
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.query
                        size: 13
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        x: queryText.contentWidth
                        width: 1
                        height: 16
                        color: Theme.base05
                    }

                    ShellText {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.query === ""
                        x: 2
                        text: root.keybindMode ? "Search keybindings" : "Search applications"
                        color: Theme.textSecondary
                        size: 13
                    }
                }
            }

            // --- lists ---
            Item {
                anchors {
                    top: searchBox.bottom; bottom: footer.top
                    left: parent.left; right: parent.right
                    topMargin: 8
                }

                // Section headers are ordinary rows of the same height as app rows, so
                // every item sits on one 50px grid and the list never has to estimate
                // (and then correct) the height of rows it has not created yet.
                ListView {
                    id: appList
                    anchors.fill: parent
                    visible: !root.keybindMode
                    model: root.rows
                    currentIndex: -1
                    clip: true
                    spacing: 2
                    boundsBehavior: Flickable.StopAtBounds
                    maximumFlickVelocity: 12000

                    FastScroll { view: appList }

                    delegate: Rectangle {
                        id: row

                        required property var modelData
                        readonly property bool isHeader: modelData.isHeader
                        readonly property bool current: !isHeader
                            && modelData.appIndex === root.currentIndex

                        width: ListView.view.width
                        height: 48
                        color: row.current ? Utils.alpha(Theme.base05, 0.11) : "transparent"

                        SectionHeader {
                            anchors {
                                left: parent.left; right: parent.right
                                leftMargin: 20; rightMargin: 20
                                verticalCenter: parent.verticalCenter
                            }
                            visible: row.isHeader
                            title: row.modelData.title ?? ""
                            detail: row.isHeader ? String(row.modelData.count) : ""
                        }

                        readonly property bool rowLaunching: !row.isHeader
                            && LauncherService.launches[row.modelData.item.entry.id] !== undefined

                        Image {
                            id: rowIcon
                            anchors { left: parent.left; leftMargin: 20; verticalCenter: parent.verticalCenter }
                            width: 24
                            height: 24
                            opacity: row.rowLaunching ? 0.35 : 1
                            visible: !row.isHeader
                            source: !row.isHeader && row.modelData.item.entry.icon
                                ? Quickshell.iconPath(row.modelData.item.entry.icon, true) : ""
                            sourceSize.width: 48
                            sourceSize.height: 48
                            asynchronous: true
                            smooth: true
                        }

                        Spinner {
                            anchors.centerIn: rowIcon
                            size: 18
                            visible: row.rowLaunching
                        }

                        ShellText {
                            anchors {
                                left: rowIcon.right; leftMargin: 14
                                right: rowTag.left; rightMargin: 12
                                verticalCenter: parent.verticalCenter
                            }
                            visible: !row.isHeader
                            textFormat: Text.StyledText
                            text: row.isHeader ? "" : root.highlighted(row.modelData.item.entry.name)
                            elide: Text.ElideRight
                            size: 13
                        }

                        ShellText {
                            id: rowTag
                            anchors { right: parent.right; rightMargin: 20; verticalCenter: parent.verticalCenter }
                            visible: !row.isHeader
                            text: row.isHeader ? ""
                                : row.current ? "OPEN ↵"
                                : LauncherService.categoryLabel(row.modelData.item.entry)
                            color: Theme.textSecondary
                            size: 10
                            font.letterSpacing: 1.2
                        }

                        HoverHandler {
                            enabled: !row.isHeader
                            cursorShape: Qt.PointingHandCursor
                            onPointChanged: if (PanelService.hoverSelectReady)
                                root.currentIndex = row.modelData.appIndex
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: !row.isHeader
                            acceptedButtons: Qt.LeftButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.activate(row.modelData.item)
                        }
                    }
                }

                ShellText {
                    anchors.centerIn: parent
                    visible: !root.keybindMode && root.results.length === 0
                    text: LauncherService.entries.length === 0 ? "LOADING APPLICATIONS…" : "NO MATCHES"
                    color: Theme.textSecondary
                    font.letterSpacing: 1
                    size: 12
                }

                LauncherKeybindList {
                    id: keybindList
                    anchors.fill: parent
                    visible: root.keybindMode
                    launcher: root
                }

                ShellText {
                    anchors.centerIn: parent
                    visible: root.keybindMode && root.bindsLoadError !== ""
                    text: root.bindsLoadError
                    color: Theme.textSecondary
                    size: 12
                }
            }

            // --- footer ---
            Rectangle {
                id: footer
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 60
                color: "transparent"

                Rectangle {
                    anchors { top: parent.top; left: parent.left; right: parent.right }
                    height: PanelService.chromeBorderWidth
                    color: PanelService.chromeBorderColor
                }

                ShellText {
                    id: userIcon
                    anchors { left: parent.left; leftMargin: 20; verticalCenter: parent.verticalCenter }
                    text: "󰀄"
                    color: Theme.textSecondary
                    size: 14
                }

                ShellText {
                    anchors { left: userIcon.right; leftMargin: 10; verticalCenter: parent.verticalCenter }
                    text: Quickshell.env("USER") || "user"
                    size: 12
                }

                Row {
                    anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                    spacing: 2

                    Repeater {
                        model: [
                            { icon: "󰌾", command: ["qs", "ipc", "call", "lock", "activate"] },
                            { icon: "󰒲", command: ["systemctl", "suspend"] },
                            { icon: "󰤄", command: ["systemctl", "hibernate"] },
                            { icon: "󰜉", command: ["systemctl", "reboot"] },
                            { icon: "󰐥", command: ["systemctl", "poweroff"] }
                        ]

                        delegate: Rectangle {
                            id: action

                            required property var modelData

                            width: 32
                            height: 32
                            radius: PanelService.rounding
                            color: actionMouse.containsMouse
                                ? Utils.alpha(Theme.base05, 0.12) : "transparent"

                            ShellText {
                                anchors.centerIn: parent
                                text: action.modelData.icon
                                color: actionMouse.containsMouse ? Theme.textPrimary : Theme.textSecondary
                                size: 15
                            }

                            MouseArea {
                                id: actionMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    PanelService.close(root);
                                    Quickshell.execDetached(action.modelData.command);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
