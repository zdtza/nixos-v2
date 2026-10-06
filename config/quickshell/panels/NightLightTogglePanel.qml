// Hyprsunset toggle and persistent color-temperature panel.
import QtQuick
import Quickshell
import "../components/panels"
import "../components/primitives"
import "../services"

Item {
    id: root

    readonly property bool opened: PanelService.activePanel === root
    readonly property bool requiresKeyboardFocus: true
    readonly property int temperatureStep: 100

    implicitHeight: PanelService.barItemHeight

    function temperatureStatus(): string {
        if (!NightLightService.available)
            return "UNAVAILABLE";
        if (!NightLightService.active)
            return "OFF";
        if (NightLightService.temperature <= 3000)
            return "EMBER GLOW";
        if (NightLightService.temperature <= 4500)
            return "WARM LIGHT";
        return "SOFT DAYLIGHT";
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


    Drawer {
        id: panel

        anchorItem: root
        implicitWidth: 420

        Hero {
            width: parent.width
            icon: ""
            title: "Night Light"
            status: root.temperatureStatus()
            ToggleSwitch {
                checked: NightLightService.active
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
