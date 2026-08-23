// Hyprsunset toggle and persistent color-temperature panel.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Stylix

Item {
    id: root

    readonly property bool opened: ServicePanel.activePanel === root
    readonly property bool requiresKeyboardFocus: true
    readonly property int temperatureStep: 100

    implicitWidth: 28
    implicitHeight: 26

    function temperatureStatus(): string {
        if (!ServiceNightLight.available)
            return "UNAVAILABLE";
        if (!ServiceNightLight.enabled)
            return "OFF";
        if (ServiceNightLight.temperature <= 3000)
            return "EMBER GLOW";
        if (ServiceNightLight.temperature <= 4500)
            return "WARM LIGHT";
        return "SOFT DAYLIGHT";
    }

    Text {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -1
        text: "󰖔"
        color: ServiceNightLight.enabled ? Theme.foreground : Theme.muted
        font.family: Theme.fontFamily
        font.pixelSize: 14
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                ServiceNightLight.toggle();
            else
                ServicePanel.toggle(root);
        }
    }

    Shortcut {
        enabled: root.opened
        sequence: "Left"
        context: Qt.ApplicationShortcut
        onActivated: ServiceNightLight.setTemperature(ServiceNightLight.temperature - root.temperatureStep)
    }
    Shortcut {
        enabled: root.opened
        sequence: "Down"
        context: Qt.ApplicationShortcut
        onActivated: ServiceNightLight.setTemperature(ServiceNightLight.temperature - root.temperatureStep)
    }
    Shortcut {
        enabled: root.opened
        sequence: "Right"
        context: Qt.ApplicationShortcut
        onActivated: ServiceNightLight.setTemperature(ServiceNightLight.temperature + root.temperatureStep)
    }
    Shortcut {
        enabled: root.opened
        sequence: "Up"
        context: Qt.ApplicationShortcut
        onActivated: ServiceNightLight.setTemperature(ServiceNightLight.temperature + root.temperatureStep)
    }
    Shortcut {
        enabled: root.opened
        sequence: "Space"
        context: Qt.ApplicationShortcut
        onActivated: ServiceNightLight.toggle()
    }
    Shortcut {
        enabled: root.opened
        sequence: "Delete"
        context: Qt.ApplicationShortcut
        onActivated: ServiceNightLight.disable()
    }

    HyprlandFocusGrab {
        active: root.opened
        windows: [panel, root.QsWindow.window]
        onCleared: ServicePanel.close(root)
    }

    PanelPopup {
        id: panel

        anchorItem: root
        anchorWindow: root.QsWindow.window
        visible: root.opened
        onCloseRequested: ServicePanel.close(root)
        borderColor: Theme.border
        contentSpacing: 14
        implicitWidth: 420
        implicitHeight: panelContent.implicitHeight + contentMargins * 2

        PanelHero {
            width: parent.width
            icon: "󰖔"
            title: "Night Light"
            status: root.temperatureStatus()
            trailingWidth: 44
            trailingHeight: 24

            PanelToggleSwitch {
                anchors.fill: parent
                checked: ServiceNightLight.enabled
                available: ServiceNightLight.available
                onToggled: ServiceNightLight.toggle()
            }
        }

        PanelSeparator {}

        PanelSectionHeader {
            title: "COLOR TEMPERATURE"
            detail: ServiceNightLight.temperature + " K"
        }

        PanelSlider {
            width: parent.width
            enabled: ServiceNightLight.available
            value: (ServiceNightLight.temperature - 1000) / 5500
            onValueEdited: value => ServiceNightLight.setTemperature(
                Math.round((1000 + value * 5500) / 100) * 100)
        }
    }
}
