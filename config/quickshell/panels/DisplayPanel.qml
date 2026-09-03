pragma ComponentBehavior: Bound

// Brightness, focused-monitor scale, and monitor overview.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Stylix
import "../components"
import "../services"
import ".."

Item {
    id: root

    required property var screen
    readonly property bool available: DisplayService.available || DisplayService.monitors.length > 0
    readonly property bool opened: PanelService.activePanel === root
    readonly property bool requiresKeyboardFocus: true
    readonly property var scales: [1, 1.33, 1.6, 2, 3.13, 4]
    property int selectedScaleIndex: 0

    visible: available
    implicitWidth: available ? indicator.implicitWidth : 0
    implicitHeight: indicator.implicitHeight

    function brightnessStatus(): string {
        if (!DisplayService.available) return "DISPLAY READY";
        const value = DisplayService.brightnessPercent;
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

    Shortcut {
        enabled: root.opened
        sequence: "Up"
        context: Qt.ApplicationShortcut
        onActivated: DisplayService.adjustBrightness(DisplayService.brightnessStep)
    }
    Shortcut {
        enabled: root.opened
        sequence: "Down"
        context: Qt.ApplicationShortcut
        onActivated: DisplayService.adjustBrightness(-DisplayService.brightnessStep)
    }
    Shortcut {
        enabled: root.opened
        sequence: "Left"
        context: Qt.ApplicationShortcut
        onActivated: root.selectedScaleIndex = Math.max(0, root.selectedScaleIndex - 1)
    }
    Shortcut {
        enabled: root.opened
        sequence: "Right"
        context: Qt.ApplicationShortcut
        onActivated: root.selectedScaleIndex = Math.min(root.scales.length - 1,
            root.selectedScaleIndex + 1)
    }
    Shortcut {
        enabled: root.opened && !!DisplayService.focusedMonitor
        sequence: "Return"
        context: Qt.ApplicationShortcut
        onActivated: DisplayService.setScale(Number(root.scales[root.selectedScaleIndex]))
    }
    Shortcut {
        enabled: root.opened && !!DisplayService.focusedMonitor
        sequence: "Enter"
        context: Qt.ApplicationShortcut
        onActivated: DisplayService.setScale(Number(root.scales[root.selectedScaleIndex]))
    }

    Button {
        id: indicator
        anchors.centerIn: parent
        panel: root
        text: "󰍹"
        onClicked: PanelService.toggle(root)
        onWheeled: wheel => DisplayService.adjustBrightness(
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
        contentSpacing: 14
        implicitWidth: 460 + PanelService.shellRounding
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
                ? DisplayService.brightnessPercent + "%" : "UNAVAILABLE"
        }

        Slider {
            width: parent.width
            enabled: DisplayService.available
            value: DisplayService.brightnessPercent / 100
            onValueEdited: value => DisplayService.setBrightness(Math.round(value * 100))
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
                    readonly property bool selected: DisplayService.focusedMonitor
                        && Math.abs(Number(DisplayService.focusedMonitor.scale)
                            - Number(modelData)) < 0.01

                    width: scaleRow.cellWidth
                    active: selected
                    keyboardFocused: scaleButton.index === root.selectedScaleIndex
                    enabled: !!DisplayService.focusedMonitor
                    onHoveredChanged: if (hovered)
                        root.selectedScaleIndex = scaleButton.index
                    onActivated: {
                        root.selectedScaleIndex = scaleButton.index;
                        DisplayService.setScale(Number(scaleButton.modelData));
                    }

                    Text {
                        anchors.centerIn: parent
                        text: root.scaleLabel(Number(scaleButton.modelData))
                        color: Theme.base05
                        font.family: Theme.monospace
                        font.pixelSize: Utils.scaledFont(12)
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
                    color: focused
                        ? Utils.alpha(Theme.base05, 0.08)
                        : "transparent"
                    border.width: focused ? 1 : 0
                    border.color: Utils.alpha(Theme.base05, 0.25)

                    Text {
                        id: monitorIcon
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰍹"
                        color: Theme.base05
                        font.family: Theme.monospace
                        font.pixelSize: Utils.scaledFont(14)
                    }

                    Text {
                        anchors.left: monitorIcon.right
                        anchors.leftMargin: 10
                        anchors.right: focusedCheck.left
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: String(monitorRow.modelData.name)
                        color: Theme.base05
                        font.family: Theme.monospace
                        font.pixelSize: Utils.scaledFont(12)
                        elide: Text.ElideRight
                    }

                    Text {
                        id: focusedCheck
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        visible: monitorRow.focused
                        text: "󰄬"
                        color: Theme.base05
                        font.family: Theme.monospace
                        font.pixelSize: Utils.scaledFont(12)
                    }
                }
            }
        }
    }
}
