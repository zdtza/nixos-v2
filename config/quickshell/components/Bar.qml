// Top bar layer-shell panel. Three anchored groups: left, right, and a clock
// pinned to the true center of the bar (independent of the side widths).
import QtQuick
import QtQuick.Layouts
import Quickshell
import Stylix
import Quickshell.Wayland
import "../panels"
import "../services"

PanelWindow {
    id: bar

    required property var modelData

    function panelEntries(): var {
        return [
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
    }

    function registerPanels(): void {
        for (const entry of panelEntries())
            ServicePanel.registerPanel(entry[0], entry[1], bar.screen);
    }

    function unregisterPanels(): void {
        for (const entry of panelEntries())
            ServicePanel.unregisterPanel(entry[0], entry[1]);
    }

    Component.onCompleted: registerPanels()
    Component.onDestruction: unregisterPanels()

    screen: modelData
    // Layer-shell surfaces cannot stay mapped at zero height. Keep a
    // non-exclusive transparent pixel while hidden so popup anchors survive.
    color: ServicePanel.barVisible ? Theme.dark_background : "transparent"
    implicitHeight: ServicePanel.barVisible ? ServicePanel.barHeight : 1
    exclusionMode: ServicePanel.barVisible ? ExclusionMode.Auto : ExclusionMode.Ignore

    mask: Region {
        width: ServicePanel.barVisible ? bar.width : 0
        height: ServicePanel.barVisible ? bar.height : 0
    }

    WlrLayershell.namespace: "quickshell:bar"
    WlrLayershell.keyboardFocus: ServicePanel.activePanel?.requiresKeyboardFocus
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
        onClicked: ServicePanel.closeActive()
    }

    // Keep keyboard focus on bar without intercepting pointer input. Popup
    // shortcuts remain application-wide; timer text is mirrored through the
    // hidden bar input because popup windows do not own compositor focus.
    Item {
        width: 1
        height: 1
        opacity: 0
        focus: !!ServicePanel.activePanel
            && ServicePanel.activePanel !== quickToggles.timerPanel
            && !(ServicePanel.activePanel === network && network.passwordSsid !== "")
            && !!ServicePanel.activePanel.requiresKeyboardFocus
    }

    TextInput {
        id: timerKeyboardInput

        x: -10
        width: 1
        height: 1
        opacity: 0
        enabled: ServicePanel.activePanel === quickToggles.timerPanel
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
        Keys.onEscapePressed: ServicePanel.close(quickToggles.timerPanel)
    }

    TextInput {
        id: networkPasswordKeyboardInput

        x: -10
        width: 1
        height: 1
        opacity: 0
        enabled: ServicePanel.activePanel === network && network.passwordSsid !== ""
        focus: enabled
        echoMode: TextInput.Password
        text: network.passwordText

        onTextEdited: network.passwordText = text
        onActiveFocusChanged: if (activeFocus)
            cursorPosition = length

        Keys.onReturnPressed: network.submitPassword()
        Keys.onEnterPressed: network.submitPassword()
        Keys.onEscapePressed: network.cancelPasswordEntry()
    }

    // --- left ---
    RowLayout {
        spacing: ServicePanel.barSpacing
        anchors {
            leftMargin: 6
            left: parent.left
            verticalCenter: parent.verticalCenter
        }

        BarWorkspaces {
            screen: bar.screen
        }
    }

    // --- center ---
    BarClock {
        id: clock
        anchors.centerIn: parent
    }

    BarTimerBadge {
        id: timerBadge
        anchors {
            left: clock.right
            leftMargin: ServicePanel.barSpacing
            verticalCenter: clock.verticalCenter
        }
        panelTarget: quickToggles.timerPanel
    }

    BarQuickToggles {
        id: quickToggles

        anchors {
            right: clock.left
            // Clock and toggle slots both include transparent horizontal
            // padding. Pull their bounds together so visible content keeps
            // the same compact gap as neighboring bar icons.
            rightMargin: ServicePanel.barSpacing - 8
            verticalCenter: clock.verticalCenter
        }
    }

    // --- right ---
    RowLayout {
        spacing: ServicePanel.barSpacing
        anchors {
            right: parent.right
            rightMargin: 12
            verticalCenter: parent.verticalCenter
        }

        PanelTray { id: tray }

        PanelVolume {
            id: volume
            screen: bar.screen
        }

        PanelBluetooth { id: bluetooth }

        PanelDisplay {
            id: display
            screen: bar.screen
        }

        PanelNetwork { id: network }

        PanelBattery { id: battery }

        // PanelPower {
        //     id: power
        // }
    }
}
