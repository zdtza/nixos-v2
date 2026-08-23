// Top bar layer-shell panel. Three anchored groups: left, right, and a clock
// pinned to the true center of the bar (independent of the side widths).
import QtQuick
import QtQuick.Layouts
import Quickshell
import Stylix
import Quickshell.Wayland

PanelWindow {
    id: bar

    required property var modelData

    function registerPanels(): void {
        const panels = [
            ["power", power],
            ["calendar", clock],
            ["nightlight", quickToggles.nightLightPanel],
            ["timer", quickToggles.timerPanel],
            ["tray", tray],
            ["volume", volume],
            ["bluetooth", bluetooth],
            ["display", display],
            ["network", network],
            ["battery", battery]
        ];
        for (const entry of panels)
            PanelService.registerPanel(entry[0], entry[1], bar.screen);
    }

    function unregisterPanels(): void {
        const panels = [
            ["power", power],
            ["calendar", clock],
            ["nightlight", quickToggles.nightLightPanel],
            ["timer", quickToggles.timerPanel],
            ["tray", tray],
            ["volume", volume],
            ["bluetooth", bluetooth],
            ["display", display],
            ["network", network],
            ["battery", battery]
        ];
        for (const entry of panels)
            PanelService.unregisterPanel(entry[0], entry[1]);
    }

    Component.onCompleted: registerPanels()
    Component.onDestruction: unregisterPanels()

    screen: modelData
    color: Theme.dark_background
    implicitHeight: PanelService.barHeight

    WlrLayershell.namespace: "quickshell:bar"
    WlrLayershell.keyboardFocus: PanelService.activePanel?.requiresKeyboardFocus
        ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    anchors {
        top: true
        left: true
        right: true
    }

    // Popup focus grabs include bar so controls remain directly clickable.
    // This background target dismisses active popup when unused bar area is hit.
    MouseArea {
        anchors.fill: parent
        onClicked: PanelService.closeActive()
    }

    // --- left ---
    RowLayout {
        anchors {
            leftMargin: 6
            left: parent.left
            verticalCenter: parent.verticalCenter
        }

        Power { id: power }

        Workspaces {
            screen: bar.screen
        }
    }

    // --- center ---
    Clock {
        id: clock
        anchors.centerIn: parent
    }

    QuickToggles {
        id: quickToggles

        anchors {
            right: clock.left
            verticalCenter: clock.verticalCenter
        }
    }


    // --- right ---
    RowLayout {
        anchors {
            right: parent.right
            rightMargin: 12
            verticalCenter: parent.verticalCenter
        }

        Tray { id: tray }

        Volume {
            id: volume
            screen: bar.screen
        }

        Bluetooth { id: bluetooth }

        Display {
            id: display
            screen: bar.screen
        }

        Network { id: network }

        Battery { id: battery }
    }
}
