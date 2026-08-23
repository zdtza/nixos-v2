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

    // Keep keyboard focus on bar without intercepting pointer input. Popup
    // shortcuts remain application-wide; timer text is mirrored through the
    // hidden bar input because popup windows do not own compositor focus.
    Item {
        width: 1
        height: 1
        opacity: 0
        focus: !!PanelService.activePanel
            && PanelService.activePanel !== quickToggles.timerPanel
            && !(PanelService.activePanel === network && network.passwordSsid !== "")
            && !!PanelService.activePanel.requiresKeyboardFocus
    }

    TextInput {
        id: timerKeyboardInput

        x: -10
        width: 1
        height: 1
        opacity: 0
        enabled: PanelService.activePanel === quickToggles.timerPanel
        focus: enabled
        inputMask: "00:00"
        text: quickToggles.timerPanel?.keyboardInputText ?? "00:00"

        onTextEdited: quickToggles.timerPanel.setInputText(text)
        onActiveFocusChanged: if (activeFocus)
            selectAll()

        Keys.onReturnPressed: quickToggles.timerPanel.startTimer()
        Keys.onEnterPressed: quickToggles.timerPanel.startTimer()
        Keys.onDownPressed: quickToggles.timerPanel.selectTimer(1)
        Keys.onUpPressed: quickToggles.timerPanel.selectTimer(-1)
        Keys.onDeletePressed: if (quickToggles.timerPanel.selectedTimerIndex >= 0)
            quickToggles.timerPanel.removeSelectedTimer()
        Keys.onEscapePressed: PanelService.close(quickToggles.timerPanel)
    }

    TextInput {
        id: networkPasswordKeyboardInput

        x: -10
        width: 1
        height: 1
        opacity: 0
        enabled: PanelService.activePanel === network && network.passwordSsid !== ""
        focus: enabled
        echoMode: TextInput.Password
        text: network.passwordText

        onTextEdited: network.passwordText = text
        onActiveFocusChanged: if (activeFocus)
            cursorPosition = length

        Keys.onReturnPressed: network.submitPassword()
        Keys.onEnterPressed: network.submitPassword()
        Keys.onEscapePressed: network.close()
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
