// On/off setting saved in Quickshell's state directory and exposed over IPC
// as toggle/enable/disable/isEnabled.
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    required property string stateFileName
    // Empty when the service declares its own, larger IPC handler.
    property string ipcTarget: ""
    property bool active: false
    // False until the saved value (or the live system state) has been read.
    property bool stateLoaded: false

    // The saved value was read into `active`.
    signal restored()
    // Nothing has been saved yet.
    signal missing()

    function setEnabled(value: bool): void {
        stateLoaded = true;
        active = value;
        stateFile.setText(value ? "true\n" : "false\n");
    }

    function toggle(): void {
        setEnabled(!active);
    }

    FileView {
        id: stateFile
        path: Quickshell.statePath(root.stateFileName)
        preload: true
        atomicWrites: true
        printErrors: false
        onLoaded: {
            root.active = String(text() || "").trim() === "true";
            root.stateLoaded = true;
            root.restored();
        }
        onLoadFailed: root.missing()
    }

    IpcHandler {
        target: root.ipcTarget
        enabled: root.ipcTarget !== ""

        function toggle(): void { root.toggle(); }
        function enable(): void { root.setEnabled(true); }
        function disable(): void { root.setEnabled(false); }
        function isEnabled(): bool { return root.active; }
    }
}
