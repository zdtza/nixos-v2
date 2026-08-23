// Hyprsunset toggle and persistent color-temperature panel.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Stylix

Item {
    id: root

    readonly property bool opened: PanelService.activePanel === root
    readonly property var presets: [2500, 3500, 4500, 5500]

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

    Text {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -1
        text: "󰖔"
        color: NightLightService.enabled ? Theme.foreground : Theme.muted
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
                NightLightService.toggle();
            else
                PanelService.toggle(root);
        }
    }

    HyprlandFocusGrab {
        active: root.opened
        windows: [panel, root.QsWindow.window]
        onCleared: PanelService.close(root)
    }

    PanelPopup {
        id: panel

        anchorItem: root
        anchorWindow: root.QsWindow.window
        visible: root.opened
        onCloseRequested: PanelService.close(root)
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

            Rectangle {
                anchors.fill: parent
                color: NightLightService.enabled
                    ? Theme.foreground
                    : Qt.rgba(Theme.foreground.r, Theme.foreground.g,
                        Theme.foreground.b, 0.18)
                border.width: 1
                border.color: Qt.rgba(Theme.foreground.r, Theme.foreground.g,
                    Theme.foreground.b, 0.4)
                opacity: NightLightService.available ? 1 : 0.5
                Behavior on color { ColorAnimation { duration: 120 } }

                Rectangle {
                    width: 18
                    height: 18
                    y: 3
                    x: NightLightService.enabled ? parent.width - width - 3 : 3
                    color: NightLightService.enabled ? Theme.background : Theme.foreground
                    Behavior on x {
                        NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: NightLightService.available
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: NightLightService.toggle()
                }
            }
        }

        PanelSeparator {}

        PanelSectionHeader {
            title: "COLOR TEMPERATURE"
            detail: NightLightService.temperature + " K"
        }

        AudioSlider {
            width: parent.width
            enabled: NightLightService.available
            value: (NightLightService.temperature - 1000) / 5500
            onValueEdited: value => NightLightService.setTemperature(
                Math.round((1000 + value * 5500) / 100) * 100)
        }

        Row {
            id: presetRow

            width: parent.width
            spacing: 6
            readonly property real cellWidth: (width - spacing * (root.presets.length - 1))
                / root.presets.length

            Repeater {
                model: root.presets

                Rectangle {
                    id: presetButton
                    required property var modelData
                    readonly property bool selected: NightLightService.temperature === modelData

                    width: presetRow.cellWidth
                    height: 32
                    color: selected
                        ? Qt.rgba(Theme.foreground.r, Theme.foreground.g,
                            Theme.foreground.b, 0.18)
                        : presetMouse.containsMouse
                            ? Qt.rgba(Theme.foreground.r, Theme.foreground.g,
                                Theme.foreground.b, 0.08)
                            : Qt.rgba(Theme.foreground.r, Theme.foreground.g,
                                Theme.foreground.b, 0.04)
                    border.width: 1
                    border.color: selected ? Theme.muted
                        : Qt.rgba(Theme.foreground.r, Theme.foreground.g,
                            Theme.foreground.b, 0.3)
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        anchors.centerIn: parent
                        text: presetButton.modelData + " K"
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.bold: presetButton.selected
                    }

                    MouseArea {
                        id: presetMouse
                        anchors.fill: parent
                        enabled: NightLightService.available
                        hoverEnabled: true
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: NightLightService.setTemperature(presetButton.modelData)
                    }
                }
            }
        }

    }
}
