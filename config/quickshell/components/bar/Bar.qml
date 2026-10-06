// Configurable top/bottom layer-shell bar.
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../panels"
import "../../services"

PanelWindow {
    id: bar

    required property var modelData

    readonly property var panelEntries: [
        ["launcher", launcher],
        ["clock", clock],
        ["nightlight", quickToggles.nightLightPanel],
        ["timer", clock.timerPanel],
        ["tray", tray],
        ["audio", audio],
        ["bluetooth", bluetooth],
        ["monitor", monitor],
        ["network", network],
        ["battery", battery]
    ]

    Component.onCompleted: {
        for (const entry of panelEntries)
            PanelService.registerPanel(entry[0], entry[1], bar.screen);
    }
    Component.onDestruction: {
        for (const entry of panelEntries)
            PanelService.unregisterPanel(entry[0], entry[1]);
    }

    screen: modelData
    // Layer-shell surfaces cannot stay mapped at zero height.
    color: PanelService.barVisible ? Theme.base01 : "transparent"
    implicitHeight: PanelService.barVisible ? PanelService.barHeight : 1
    exclusionMode: PanelService.barVisible ? ExclusionMode.Auto : ExclusionMode.Ignore

    mask: Region {
        width: PanelService.barVisible ? bar.width : 0
        height: PanelService.barVisible ? bar.height : 0
    }

    WlrLayershell.namespace: "quickshell:bar"
    WlrLayershell.keyboardFocus: PanelService.activePanel?.requiresKeyboardFocus
        && !PanelService.refocusing
        ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None


    anchors {
        top: PanelService.barAtTop
        bottom: !PanelService.barAtTop
        left: true
        right: true
    }
    margins.top: PanelService.barAtTop && !PanelService.barVisible ? -1 : 0
    margins.bottom: !PanelService.barAtTop && !PanelService.barVisible ? -1 : 0

    Rectangle {
        anchors {
            left: parent.left
            right: parent.right
        }
        y: PanelService.barAtTop ? parent.height - height : 0
        height: PanelService.chromeBorderWidth
        color: PanelService.chromeBorderColor
        visible: PanelService.barVisible
        z: 1
    }

    // Popup focus grabs include bar so controls remain directly clickable.
    MouseArea {
        anchors.fill: parent
        onClicked: PanelService.closeActive()
    }

    // Panel keyboard hosting.
    readonly property Component activeKeyboardProxy:
        PanelService.activePanel?.keyboardProxy ?? null

    Item {
        width: 1
        height: 1
        opacity: 0
        focus: !bar.activeKeyboardProxy
            && !!PanelService.activePanel?.requiresKeyboardFocus
    }

    Loader {
        x: -10
        width: 1
        height: 1
        opacity: 0
        // Loader is a focus scope, so this plus `focus: true` on the proxy itself is what actually lands active focus inside it.
        active: !!bar.activeKeyboardProxy
        focus: active
        sourceComponent: bar.activeKeyboardProxy
    }

    // --- left ---.
    // Opened with Super+Space only; it sits here for the drawer and keyboard proxy.
    LauncherPanel {
        id: launcher
        anchors {
            left: parent.left
            leftMargin: 8
            verticalCenter: parent.verticalCenter
        }
    }

    Workspaces {
        screen: bar.screen
        anchors {
            left: launcher.right
            verticalCenter: parent.verticalCenter
        }
    }

    // --- center ---.
    Clock {
        id: clock
        anchors.centerIn: parent
    }

    // --- right ---.
    Row {
        spacing: PanelService.barSpacing
        anchors {
            right: parent.right
            rightMargin: 12
            verticalCenter: parent.verticalCenter
        }

        Tray {
            id: tray
            nightLightPanel: quickToggles.nightLightPanel
            timerPanel: clock.timerPanel
        }

        QuickToggles { id: quickToggles }

        BluetoothPanel {
            id: bluetooth
        }

        AudioPanel {
            id: audio
        }

        BatteryPanel { id: battery }

        NetworkPanel { id: network }

        TimerBadge { panelTarget: clock.timerPanel }
    }

    // The monitor panel remains registered for Super+Ctrl+M, but has no bar button.
    MonitorPanel {
        id: monitor
        anchors {
            right: parent.right
            rightMargin: 12
            verticalCenter: parent.verticalCenter
        }
    }
}
