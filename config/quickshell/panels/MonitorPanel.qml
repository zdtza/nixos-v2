pragma ComponentBehavior: Bound

// Brightness, focused-monitor scale, and monitor overview.
import QtQuick
import Quickshell
import "../components"
import "../services"

Item {
    id: root

    property bool showButton: true
    readonly property bool available: MonitorService.available || MonitorService.monitors.length > 0
    readonly property bool opened: PanelService.activePanel === root
    readonly property bool requiresKeyboardFocus: true
    readonly property var scales: [1, 1.33, 1.6, 2, 3.13, 4]
    property int selectedScaleIndex: 0

    visible: available
    implicitWidth: available && showButton ? indicator.implicitWidth : 0
    implicitHeight: indicator.implicitHeight

    function brightnessStatus(): string {
        if (!MonitorService.available) return "MONITOR READY";
        const value = MonitorService.brightnessPercent;
        if (value <= 10) return "THE GLOAMING";
        if (value <= 30) return "MOONLIGHT HAZE";
        if (value <= 50) return "SOFT MORNING";
        if (value <= 70) return "GOLDEN HOURS";
        if (value <= 90) return "HIGH NOON";
        return "VISCERAL DAYLIGHT";
    }

    function scaleLabel(scale: real): string {
        return Number(scale).toFixed(Number.isInteger(scale) ? 0 : 2)
            .replace(/0$/, "") + "x";
    }

    onOpenedChanged: if (opened && MonitorService.focusedMonitor) {
        const currentScale = Number(MonitorService.focusedMonitor.scale);
        const index = scales.findIndex(scale => Math.abs(Number(scale) - currentScale) < 0.01);
        selectedScaleIndex = Math.max(0, index);
    }

    PanelShortcut {
        enabled: root.opened
        sequences: ["Up"]
        onActivated: MonitorService.adjustLevel(MonitorService.brightnessStep)
    }
    PanelShortcut {
        enabled: root.opened
        sequences: ["Down"]
        onActivated: MonitorService.adjustLevel(-MonitorService.brightnessStep)
    }
    PanelShortcut {
        enabled: root.opened
        sequences: ["Left"]
        onActivated: root.selectedScaleIndex = Math.max(0, root.selectedScaleIndex - 1)
    }
    PanelShortcut {
        enabled: root.opened
        sequences: ["Right"]
        onActivated: root.selectedScaleIndex = Math.min(root.scales.length - 1,
            root.selectedScaleIndex + 1)
    }
    PanelShortcut {
        enabled: root.opened && !!MonitorService.focusedMonitor
        sequences: ["Return", "Enter"]
        onActivated: MonitorService.setScale(Number(root.scales[root.selectedScaleIndex]))
    }

    Button {
        id: indicator
        anchors.centerIn: parent
        visible: root.showButton
        panel: root
        text: "󰍹"
        onClicked: PanelService.toggle(root)
        onWheeled: wheel => MonitorService.adjustLevel(
            wheel.angleDelta.y > 0 ? MonitorService.brightnessStep : -MonitorService.brightnessStep)
    }


    Drawer {
        id: panel
        anchorItem: root
        contentSpacing: 12
        implicitWidth: 460

        Hero {
            width: parent.width
            icon: "󰍹"
            title: "Monitor"
            status: root.brightnessStatus()
        }

        Separator {}

        SectionHeader {
            title: "BRIGHTNESS"
            detail: MonitorService.available
                ? MonitorService.brightnessPercent + "%" : "UNAVAILABLE"
        }

        Slider {
            width: parent.width
            enabled: MonitorService.available
            value: MonitorService.brightnessPercent / 100
            onValueEdited: value => MonitorService.setBrightness(Math.round(value * 100))
        }

        Separator {}

        SectionHeader {
            title: "SCALE"
            detail: MonitorService.focusedMonitor
                ? root.scaleLabel(MonitorService.focusedMonitor.scale) : "—"
        }

        Row {
            id: scaleRow
            width: parent.width
            spacing: 6
            readonly property real cellWidth: (width - spacing * (root.scales.length - 1))
                / root.scales.length

            Repeater {
                model: root.scales

                OptionButton {
                    id: scaleButton
                    required property var modelData
                    required property int index

                    width: scaleRow.cellWidth
                    keyboardFocused: scaleButton.index === root.selectedScaleIndex
                    active: !!MonitorService.focusedMonitor
                        && Math.abs(Number(scaleButton.modelData)
                            - Number(MonitorService.focusedMonitor.scale)) < 0.01
                    enabled: !!MonitorService.focusedMonitor
                    onHoveredChanged: if (hovered && PanelService.hoverSelectReady)
                        root.selectedScaleIndex = scaleButton.index
                    onActivated: {
                        root.selectedScaleIndex = scaleButton.index;
                        MonitorService.setScale(Number(scaleButton.modelData));
                    }

                    ShellText {
                        anchors.centerIn: parent
                        text: root.scaleLabel(Number(scaleButton.modelData))
                        size: 12
                    }
                }
            }
        }

        Separator {}

        SectionHeader {
            title: "MONITORS"
            detail: MonitorService.monitors.length > 1
                ? MonitorService.monitors.length + " ACTIVE" : ""
        }

        Column {
            width: parent.width
            spacing: 4

            Repeater {
                model: MonitorService.monitors

                Rectangle {
                    id: monitorRow
                    required property var modelData
                    readonly property bool focused: MonitorService.focusedMonitor === modelData

                    width: parent.width
                    height: 36
                    radius: PanelService.rounding
                    color: "transparent"

                    ShellText {
                        id: monitorIcon
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰍹"
                        size: 14
                    }

                    ShellText {
                        anchors.left: monitorIcon.right
                        anchors.leftMargin: 10
                        anchors.right: focusedCheck.left
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: String(monitorRow.modelData.name)
                        size: 12
                        elide: Text.ElideRight
                    }

                    ShellText {
                        id: focusedCheck
                        anchors.right: parent.right
                        anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        visible: monitorRow.focused
                        text: "󰄬"
                        size: 12
                    }
                }
            }
        }
    }
}
