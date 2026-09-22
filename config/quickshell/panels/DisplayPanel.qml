pragma ComponentBehavior: Bound

// Brightness, focused-monitor scale, and monitor overview.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../components"
import "../services"
import ".."

Item {
    id: root

    required property var screen
    property bool showButton: true
    readonly property bool available: DisplayService.available || DisplayService.monitors.length > 0
    readonly property bool opened: PanelService.activePanel === root
    readonly property bool requiresKeyboardFocus: true
    readonly property var scales: [1, 1.33, 1.6, 2, 3.13, 4]
    property int selectedScaleIndex: 0

    visible: available
    implicitWidth: available && showButton ? indicator.implicitWidth : 0
    implicitHeight: indicator.implicitHeight

    function brightnessStatus(): string {
        if (!DisplayService.available) return "DISPLAY READY";
        const value = DisplayService.level;
        if (value > 100) return "BEYOND DAYLIGHT";
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

    onOpenedChanged: if (opened && DisplayService.focusedMonitor) {
        const currentScale = Number(DisplayService.focusedMonitor.scale);
        const index = scales.findIndex(scale => Math.abs(Number(scale) - currentScale) < 0.01);
        selectedScaleIndex = Math.max(0, index);
    }

    PanelShortcut {
        enabled: root.opened
        sequences: ["Up"]
        onActivated: DisplayService.adjustLevel(DisplayService.brightnessStep)
    }
    PanelShortcut {
        enabled: root.opened
        sequences: ["Down"]
        onActivated: DisplayService.adjustLevel(-DisplayService.brightnessStep)
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
        enabled: root.opened && !!DisplayService.focusedMonitor
        sequences: ["Return", "Enter"]
        onActivated: DisplayService.setScale(Number(root.scales[root.selectedScaleIndex]))
    }

    Button {
        id: indicator
        anchors.centerIn: parent
        visible: root.showButton
        panel: root
        text: "󰍹"
        onClicked: PanelService.toggle(root)
        onWheeled: wheel => DisplayService.adjustLevel(
            wheel.angleDelta.y > 0 ? DisplayService.brightnessStep : -DisplayService.brightnessStep)
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
        contentSpacing: 12
        implicitWidth: 460
        implicitHeight: panelContent.implicitHeight
            + contentTopMargin + contentBottomMargin

        Hero {
            width: parent.width
            icon: "󰍹"
            title: "Display"
            status: root.brightnessStatus()
        }

        Separator {}

        SectionHeader {
            title: "BRIGHTNESS"
            detail: DisplayService.available
                ? DisplayService.level + "%" : "UNAVAILABLE"
        }

        // Full travel is 0-150%: the last third is gamma overdrive on top of a maxed backlight, so the 100% hardware ceiling sits at two thirds.
        Slider {
            width: parent.width
            enabled: DisplayService.available
            value: DisplayService.level / DisplayService.maxLevel
            onValueEdited: value => DisplayService.setLevel(
                Math.round(value * DisplayService.maxLevel))
        }

        Separator {}

        SectionHeader {
            title: "SCALE"
            detail: DisplayService.focusedMonitor
                ? root.scaleLabel(DisplayService.focusedMonitor.scale) : "—"
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
                    active: !!DisplayService.focusedMonitor
                        && Math.abs(Number(scaleButton.modelData)
                            - Number(DisplayService.focusedMonitor.scale)) < 0.01
                    enabled: !!DisplayService.focusedMonitor
                    onHoveredChanged: if (hovered && PanelService.hoverSelectReady)
                        root.selectedScaleIndex = scaleButton.index
                    onActivated: {
                        root.selectedScaleIndex = scaleButton.index;
                        DisplayService.setScale(Number(scaleButton.modelData));
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
            title: "DISPLAYS"
            detail: DisplayService.monitors.length > 1
                ? DisplayService.monitors.length + " ACTIVE" : ""
        }

        Column {
            width: parent.width
            spacing: 4

            Repeater {
                model: DisplayService.monitors

                Rectangle {
                    id: monitorRow
                    required property var modelData
                    readonly property bool focused: DisplayService.focusedMonitor === modelData

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
