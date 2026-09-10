pragma ComponentBehavior: Bound

// Read-only cheat sheet of every Hyprland bind, in the launcher's surface
// language. Data comes straight from `hyprctl binds -j`: config/hypr's local
// bind() wrapper asserts a description on every bind, so the description is
// always the label and the __lua dispatcher/arg pair is never shown.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "../services"
import ".."

Scope {
    id: root

    // Binds only change on a config reload, so they are fetched on first open
    // and kept until Hyprland says they are stale.
    property var binds: []
    property string loadError: ""

    function show(): void {
        if (root.binds.length === 0)
            bindsProcess.running = true;
        panel.show();
    }

    function toggle(): void {
        if (panel.open)
            panel.open = false;
        else
            root.show();
    }

    // Only the shapes the current config produces get special handling;
    // anything else passes through unchanged rather than being mangled.
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
        if (key.startsWith("mouse:") || key.startsWith("code:"))
            return key;
        if (key.length === 1)
            return key.toUpperCase();
        return key.charAt(0).toUpperCase() + key.slice(1);
    }

    // Fixed emit order, not bitmask order, so the same chord always reads
    // the same way regardless of how Hyprland packed it.
    function chordText(bind: var): string {
        const parts = [];
        for (const modifier of [{ bit: 64, name: "SUPER" }, { bit: 4, name: "CTRL" },
                { bit: 8, name: "ALT" }, { bit: 1, name: "SHIFT" }]) {
            if (bind.modmask & modifier.bit)
                parts.push(modifier.name);
        }
        parts.push(root.keyName(String(bind.key ?? "")));
        return parts.join(" + ");
    }

    // One flat CHORD → description list, like omarchy's menu: chords sort
    // by modmask (bare keys, SUPER, SUPER + SHIFT, …) then alphabetically
    // by description, so the order is emergent instead of hand-maintained.
    readonly property var rows: {
        const tokens = panel.query.toLowerCase().split(" ").filter(token => token !== "");
        const matches = [];
        for (const bind of root.binds) {
            const chord = root.chordText(bind);
            const description = String(bind.description ?? "");
            const haystack = `${chord} ${description}`.toLowerCase();
            if (tokens.every(token => haystack.includes(token)))
                matches.push({ modmask: bind.modmask, chord, description });
        }

        return matches.sort((a, b) => a.modmask - b.modmask
            || a.description.localeCompare(b.description));
    }

    GlobalShortcut {
        appid: "quickshell"
        name: "keybinds"
        description: "Toggle keybind list"
        triggerDescription: "Super+Ctrl+K"
        onPressed: root.toggle()
    }

    IpcHandler {
        target: "keybinds"

        function toggle(): void { root.toggle(); }
        function open(): void { root.show(); }
        function close(): void { panel.open = false; }
        function isOpen(): bool { return panel.open; }
    }

    Process {
        id: bindsProcess
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    root.binds = JSON.parse(text);
                    root.loadError = "";
                } catch (e) {
                    root.binds = [];
                    root.loadError = "Could not read binds: " + e;
                }
            }
        }
    }

    Connections {
        target: Hyprland

        function onRawEvent(event: var): void {
            if (event.name !== "configreloaded")
                return;
            // Re-read now if visible, otherwise drop the list so the next
            // open pays for the refresh.
            root.binds = [];
            if (panel.open)
                bindsProcess.running = true;
        }
    }

    SearchPanel {
        id: panel

        layerNamespace: "quickshell:keybinds"
        placeholder: "Keybinds…"
        // Wider than the launcher: a chord plus its description needs room
        // that an app name does not.
        frameWidth: 700
        rowHeight: 50
        rowSpacing: 2
        maxRows: 7
        model: root.rows
        // No matches collapses to the bare search bar: no empty-state row.
        expanded: root.rows.length > 0 || root.loadError !== ""
        // Read-only list: there is nothing to activate.
        onAccepted: panel.open = false

        delegate: Rectangle {
            id: bindRow

            required property var modelData
            required property int index

            width: ListView.view.width
            height: panel.rowHeight
            radius: PanelService.rounding
            color: bindRow.ListView.isCurrentItem ? Theme.base02 : "transparent"

            // Exact halves: each column is width / 2, padding lives inside
            // its own half so the split never moves.
            ShellText {
                id: chordLabel
                anchors {
                    left: parent.left
                    verticalCenter: parent.verticalCenter
                }
                width: bindRow.width / 2
                leftPadding: 14
                rightPadding: 10
                text: bindRow.modelData.chord
                elide: Text.ElideRight
                size: 15
            }

            ShellText {
                anchors {
                    left: chordLabel.right
                    verticalCenter: parent.verticalCenter
                }
                width: bindRow.width / 2
                rightPadding: 10
                text: "→ " + bindRow.modelData.description
                color: Theme.base04
                elide: Text.ElideRight
                size: 14
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onContainsMouseChanged: if (containsMouse && panel.hoverSelectReady)
                    panel.currentIndex = bindRow.index
            }
        }

        // Only a hard read failure gets a message; an empty result is blank.
        ShellText {
            anchors.centerIn: parent
            width: parent.width - 20
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            visible: root.loadError !== ""
            text: root.loadError
            color: Theme.base04
            size: 16
        }
    }
}
