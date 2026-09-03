pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Polkit
import Quickshell.Wayland
import "../services"

Scope {
    id: root

    property string openedMonitorName: ""

    function screenForMonitor(name: string): var {
        for (const screen of Quickshell.screens) {
            if (String(screen.name) === name)
                return screen;
        }
        return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null;
    }

    function submit(): void {
        const flow = agent.flow;
        if (!flow?.isResponseRequired)
            return;
        flow.submit(prompt.text);
        prompt.text = "";
    }

    PolkitAgent {
        id: agent

        onAuthenticationRequestStarted: {
            root.openedMonitorName = String(Hyprland.focusedMonitor?.name ?? "");
            PanelService.closeActive();
            Qt.callLater(() => prompt.input.forceActiveFocus());
        }
    }

    PanelWindow {
        id: window

        screen: root.screenForMonitor(root.openedMonitorName)
        visible: agent.isActive
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        WlrLayershell.namespace: "quickshell:polkit"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        onVisibleChanged: if (visible)
            Qt.callLater(() => prompt.input.forceActiveFocus())

        AuthPrompt {
            id: prompt
            anchors.fill: parent
            showWallpaper: false
            error: (agent.flow?.failed || agent.flow?.supplementaryIsError) ?? false
            inputEnabled: agent.flow?.isResponseRequired ?? false
            responseVisible: agent.flow?.responseVisible ?? false
            onAccepted: root.submit()
        }

        Shortcut {
            enabled: agent.isActive
            sequence: "Escape"
            context: Qt.ApplicationShortcut
            onActivated: agent.flow?.cancelAuthenticationRequest()
        }

        Connections {
            target: agent.flow

            function onIsResponseRequiredChanged(): void {
                prompt.text = "";
                if (agent.flow?.isResponseRequired)
                    prompt.input.forceActiveFocus();
            }

            function onAuthenticationFailed(): void {
                prompt.text = "";
                prompt.input.forceActiveFocus();
            }
        }
    }
}
