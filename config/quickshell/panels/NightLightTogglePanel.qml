// Hyprsunset toggle and persistent color-temperature panel.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../components"
import "../services"

Item {
    id: root

    property bool showButton: true
    readonly property bool opened: PanelService.activePanel === root
    readonly property bool requiresKeyboardFocus: true
    readonly property int temperatureStep: 100

    implicitWidth: showButton ? 28 : 0
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
        visible: root.showButton
        panel: root
        text: ""
        textSize: 12
        textColor: NightLightService.enabled ? Theme.base05 : Theme.base04
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                NightLightService.toggle();
            else
                PanelService.toggle(root);
        }
    }

    PanelShortcut {
        enabled: root.opened
        sequences: ["Left", "Down"]
        onActivated: NightLightService.setTemperature(NightLightService.temperature - root.temperatureStep)
    }
    PanelShortcut {
        enabled: root.opened
        sequences: ["Right", "Up"]
        onActivated: NightLightService.setTemperature(NightLightService.temperature + root.temperatureStep)
    }
    PanelShortcut {
        enabled: root.opened
        sequences: ["Space"]
        onActivated: NightLightService.toggle()
    }
    PanelShortcut {
        enabled: root.opened
        sequences: ["Delete"]
        onActivated: NightLightService.disable()
    }

    HyprlandFocusGrab {
        active: root.opened
        windows: [panel, root.QsWindow.window]
        onCleared: PanelService.close(root)
    }

    Drawer {
        id: panel

        anchorItem: root
        anchorWindow: root.QsWindow.window
        open: root.opened
        onCloseRequested: PanelService.close(root)
        contentSpacing: 14
        implicitWidth: 420
        implicitHeight: panelContent.implicitHeight
            + contentTopMargin + contentBottomMargin

        Hero {
            width: parent.width
            icon: ""
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
