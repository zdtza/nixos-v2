pragma Singleton

// The Windows container registers no StatusNotifierItem of its own, so there is
// nothing for Quickshell.Services.SystemTray to pick up. Its state is polled
// from systemd instead and rendered by PanelTray.qml as a synthetic entry that sits
// alongside real tray icons.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Item {
    id: root

    readonly property string unit: "docker-windows.service"
    readonly property string viewerUrl: "http://127.0.0.1:8006"

    property bool running: false

    // One command per action, none of which can delete anything. Erasing is
    // windows-remove, deliberately terminal-only.
    readonly property var actions: [
        {
            label: "Connect",
            triggered: () => root.connect()
        },
        {
            label: "Web viewer",
            triggered: () => root.run(["xdg-open", root.viewerUrl])
        },
        {
            label: "Shut down",
            triggered: () => root.run(["windows-stop"])
        }
    ]

    function connect(): void {
        for (const toplevel of Hyprland.toplevels.values) {
            const ipc = toplevel.lastIpcObject ?? {};
            const identities = [ipc.class ?? "", ipc.initialClass ?? "",
                toplevel.wayland?.appId ?? ""]
                .map(value => String(value).toLowerCase());
            if (!identities.some(value => value === "windows"))
                continue;

            Quickshell.execDetached(["hyprctl", "dispatch",
                "hl.dsp.focus({ window = 'class:^(windows)$' })"]);
            return;
        }
        run(["windows-launch"]);
    }

    function probe(): void {
        if (!statusProcess.running)
            statusProcess.running = true;
    }

    function run(command: var): void {
        Quickshell.execDetached({
            command: ["uwsm", "app", "--", ...command]
        });
        // Starting or stopping takes a moment to land; re-probe ahead of the
        // regular poll so the icon does not lag behind the click.
        settleTimer.restart();
    }

    Process {
        id: statusProcess

        command: ["systemctl", "is-active", "--quiet", root.unit]
        onExited: exitCode => root.running = exitCode === 0
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.probe()
    }

    Timer {
        id: settleTimer

        interval: 1500
        onTriggered: root.probe()
    }
}
