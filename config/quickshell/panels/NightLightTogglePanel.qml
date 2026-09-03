// Hyprsunset toggle and persistent color-temperature panel.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Stylix
import "../components"
import "../services"

Item {
    id: root

    readonly property bool opened: PanelService.activePanel === root
    readonly property bool requiresKeyboardFocus: true
    readonly property int temperatureStep: 100

    implicitWidth: 28
    implicitHeight: 26

    function temperatureStatus(): string {
        if (!NightLightService.available)
            return "UNAVAILABLE";
        if (!NightLightService.enabled)
            return "OFF";
        if (NightLightService.temperature <= 3000)
            return "EMBER GLOW";
        if (NightLightService.temperature <= 4500)
            return "WARM LIGHT";
        return "SOFT DAYLIGHT";
    }

    Button {
        anchors.centerIn: parent
        panel: root
        text: "󰖔"
        textColor: NightLightService.enabled ? Theme.base05 : Theme.base04
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                NightLightService.toggle();
            else
                PanelService.toggle(root);
        }
    }

    Shortcut {
        enabled: root.opened
        sequence: "Left"
        context: Qt.ApplicationShortcut
        onActivated: NightLightService.setTemperature(NightLightService.temperature - root.temperatureStep)
    }
    Shortcut {
        enabled: root.opened
        sequence: "Down"
        context: Qt.ApplicationShortcut
        onActivated: NightLightService.setTemperature(NightLightService.temperature - root.temperatureStep)
    }
    Shortcut {
        enabled: root.opened
        sequence: "Right"
        context: Qt.ApplicationShortcut
        onActivated: NightLightService.setTemperature(NightLightService.temperature + root.temperatureStep)
    }
    Shortcut {
        enabled: root.opened
        sequence: "Up"
        context: Qt.ApplicationShortcut
        onActivated: NightLightService.setTemperature(NightLightService.temperature + root.temperatureStep)
    }
    Shortcut {
        enabled: root.opened
        sequence: "Space"
        context: Qt.ApplicationShortcut
        onActivated: NightLightService.toggle()
    }
    Shortcut {
        enabled: root.opened
        sequence: "Delete"
        context: Qt.ApplicationShortcut
        onActivated: NightLightService.disable()
    }

    HyprlandFocusGrab {
        active: root.opened
        windows: [panel, root.QsWindow.window]
        onCleared: PanelService.close(root)
    }

    Popup {
        id: panel

        anchorItem: root
        anchorWindow: root.QsWindow.window
        open: root.opened
        onCloseRequested: PanelService.close(root)
        contentSpacing: 14
        implicitWidth: 420 + PanelService.shellRounding * 2
        implicitHeight: panelContent.implicitHeight
            + contentTopMargin + contentBottomMargin

        Hero {
            width: parent.width
            icon: "󰖔"
            title: "Night Light"
            status: root.temperatureStatus()
            trailingWidth: 44
            trailingHeight: 24

            ToggleSwitch {
                anchors.fill: parent
                checked: NightLightService.enabled
                available: NightLightService.available
                onToggled: NightLightService.toggle()
            }
        }

        Separator {}

        SectionHeader {
            title: "COLOR TEMPERATURE"
            detail: NightLightService.temperature + " K"
        }

        Slider {
            width: parent.width
            enabled: NightLightService.available
            value: (NightLightService.temperature - 1000) / 5500
            onValueEdited: value => NightLightService.setTemperature(
                Math.round((1000 + value * 5500) / 100) * 100)
        }
    }
}
