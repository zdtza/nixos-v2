pragma Singleton

// Persistent caffeine mode.
import QtQuick
import Quickshell.Io

PersistentToggle {
    id: root

    stateFileName: "stay-awake-enabled"
    ipcTarget: "stayawake"

    property bool writingEnabled: false

    function dispatchDesired(): void {
        if (controlProcess.running)
            return;

        writingEnabled = active;
        controlProcess.command = ["systemctl", "--user",
            writingEnabled ? "start" : "stop", "stay-awake.service"];
        controlProcess.running = true;
    }

    onActiveChanged: if (stateLoaded) dispatchDesired()
    onRestored: dispatchDesired()
    onMissing: if (!statusProcess.running) statusProcess.running = true

    Process {
        id: controlProcess
        onExited: {
            if (root.writingEnabled !== root.active) {
                root.dispatchDesired();
                return;
            }
            statusDelay.restart();
        }
    }

    Process {
        id: statusProcess
        command: ["systemctl", "--user", "is-active", "--quiet", "stay-awake.service"]
        onExited: (exitCode, exitStatus) => {
            if (controlProcess.running || exitCode === 4)
                return;

            const actualEnabled = exitCode === 0;
            // With nothing saved yet, adopt whatever the service is doing.
            if (!root.stateLoaded)
                root.setEnabled(actualEnabled);
            else if (actualEnabled !== root.active)
                root.dispatchDesired();
        }
    }

    Timer {
        id: statusDelay
        interval: 100
        onTriggered: if (!statusProcess.running) statusProcess.running = true
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: if (!statusProcess.running && !controlProcess.running)
            statusProcess.running = true
    }
}
