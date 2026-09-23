// Bottom bar layer-shell panel.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../panels"
import "../services"

PanelWindow {
    id: bar

    required property var modelData

    function panelEntries(): var {
        return [
            ["clock", clock],
            ["nightlight", quickToggles.nightLightPanel],
            ["timer", clock.timerPanel],
            ["tray", tray],
            ["volume", volume],
            ["bluetooth", bluetooth],
            ["display", display],
            ["network", network],
            ["battery", battery]
        ];
    }

    function registerPanels(): void {
        for (const entry of panelEntries())
            PanelService.registerPanel(entry[0], entry[1], bar.screen);
    }

    function unregisterPanels(): void {
        for (const entry of panelEntries())
            PanelService.unregisterPanel(entry[0], entry[1]);
    }

    Component.onCompleted: registerPanels()
    Component.onDestruction: unregisterPanels()

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
        ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    anchors {
        bottom: true
        left: true
        right: true
    }
    margins.bottom: PanelService.barVisible ? 0 : -1

    Rectangle {
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
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
    RowLayout {
        spacing: PanelService.barSpacing
        anchors {
            leftMargin: 6
            left: parent.left
            verticalCenter: parent.verticalCenter
        }

        Workspaces {
            screen: bar.screen
        }
    }

    // --- right ---.
    RowLayout {
        spacing: PanelService.barSpacing
        anchors {
            right: parent.right
            rightMargin: 12
            verticalCenter: parent.verticalCenter
        }

        Tray { id: tray }

        QuickToggles { id: quickToggles }
        

        AudioPanel {
            id: volume
            screen: bar.screen
        }

        BluetoothPanel { id: bluetooth }

        BatteryPanel { id: battery }

        NetworkPanel { id: network }


        TimerBadge {
            id: timerBadge
            panelTarget: clock.timerPanel
        }

        Clock {
            id: clock
            Layout.rightMargin: -8
            Layout.leftMargin: -10
        }
    }

    // The display panel remains registered for Super+Ctrl+D, but has no bar button.
    DisplayPanel {
        id: display
        screen: bar.screen
        showButton: false
        anchors {
            right: parent.right
            rightMargin: 12
            verticalCenter: parent.verticalCenter
        }
    }
}
