pragma Singleton

// Persistent notification suppression state.
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property bool enabled: false

    function setEnabled(value: bool): void {
        enabled = value;
        stateFile.setText(value ? "true\n" : "false\n");
    }

    function toggle(): void {
        setEnabled(!enabled);
    }

    FileView {
        id: stateFile
        path: Quickshell.statePath("do-not-disturb-enabled")
        preload: true
        atomicWrites: true
        printErrors: false
        onLoaded: root.enabled = String(text() || "").trim() === "true"
        onLoadFailed: stateFile.setText("false\n")
    }

    IpcHandler {
        target: "dnd"

        function toggle(): void { root.toggle(); }
        function enable(): void { root.setEnabled(true); }
        function disable(): void { root.setEnabled(false); }
        function isEnabled(): bool { return root.enabled; }
    }
}
