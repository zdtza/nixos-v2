pragma ComponentBehavior: Bound

// Brightness, focused-monitor scale, and monitor overview.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Stylix

Item {
    id: root

    required property var screen
    readonly property bool available: ServiceDisplay.available || ServiceDisplay.monitors.length > 0
    readonly property bool opened: ServicePanel.activePanel === root
    readonly property bool requiresKeyboardFocus: true
    readonly property var scales: [1, 1.33, 1.6, 2, 3.13, 4]
    property int selectedScaleIndex: 0

    visible: available
    implicitWidth: available ? indicator.implicitWidth : 0
    implicitHeight: indicator.implicitHeight

    function brightnessStatus(): string {
        if (!ServiceDisplay.available) return "DISPLAY READY";
        const value = ServiceDisplay.brightnessPercent;
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

    onOpenedChanged: if (opened && ServiceDisplay.focusedMonitor) {
        const currentScale = Number(ServiceDisplay.focusedMonitor.scale);
        const index = scales.findIndex(scale => Math.abs(Number(scale) - currentScale) < 0.01);
        selectedScaleIndex = Math.max(0, index);
    }

    Shortcut {
        enabled: root.opened
        sequence: "Up"
        context: Qt.ApplicationShortcut
        onActivated: ServiceDisplay.adjustBrightness(ServiceDisplay.brightnessStep)
    }
    Shortcut {
        enabled: root.opened
        sequence: "Down"
        context: Qt.ApplicationShortcut
        onActivated: ServiceDisplay.adjustBrightness(-ServiceDisplay.brightnessStep)
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
        enabled: root.opened && !!ServiceDisplay.focusedMonitor
        sequence: "Return"
        context: Qt.ApplicationShortcut
        onActivated: ServiceDisplay.setScale(Number(root.scales[root.selectedScaleIndex]))
    }
    Shortcut {
        enabled: root.opened && !!ServiceDisplay.focusedMonitor
        sequence: "Enter"
        context: Qt.ApplicationShortcut
        onActivated: ServiceDisplay.setScale(Number(root.scales[root.selectedScaleIndex]))
    }

    PanelIpcFeedback {
        id: ipcFeedback
        panel: root
        screen: root.screen
    }

    Connections {
        target: ServiceDisplay
        function onBrightnessIpcInvoked(): void { ipcFeedback.show(); }
    }

    BarButton {
        id: indicator
        anchors.centerIn: parent
        panel: root
        text: "󰍹"
        onClicked: ServicePanel.toggle(root)
        onWheeled: wheel => ServiceDisplay.adjustBrightness(
            wheel.angleDelta.y > 0 ? ServiceDisplay.brightnessStep : -ServiceDisplay.brightnessStep)
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
        implicitWidth: 460
        implicitHeight: panelContent.implicitHeight + contentMargins * 2

        PanelHero {
            width: parent.width
            icon: "󰍹"
            title: "Display"
            status: root.brightnessStatus()
        }

        PanelSeparator {}

        PanelSectionHeader {
            title: "BRIGHTNESS"
            detail: ServiceDisplay.available
                ? ServiceDisplay.brightnessPercent + "%" : "UNAVAILABLE"
        }

        PanelSlider {
            width: parent.width
            enabled: ServiceDisplay.available
            value: ServiceDisplay.brightnessPercent / 100
            onValueEdited: value => ServiceDisplay.setBrightness(Math.round(value * 100))
        }

        PanelSeparator {}

        PanelSectionHeader {
            title: "SCALE"
            detail: ServiceDisplay.focusedMonitor
                ? root.scaleLabel(ServiceDisplay.focusedMonitor.scale) : "—"
        }

        Row {
            id: scaleRow
            width: parent.width
            spacing: 6
            readonly property real cellWidth: (width - spacing * (root.scales.length - 1))
                / root.scales.length

            Repeater {
                model: root.scales

                PanelOptionButton {
                    id: scaleButton
                    required property var modelData
                    required property int index
                    readonly property bool selected: ServiceDisplay.focusedMonitor
                        && Math.abs(Number(ServiceDisplay.focusedMonitor.scale)
                            - Number(modelData)) < 0.01

                    width: scaleRow.cellWidth
                    active: selected
                    keyboardFocused: scaleButton.index === root.selectedScaleIndex
                    enabled: !!ServiceDisplay.focusedMonitor
                    onActivated: {
                        root.selectedScaleIndex = scaleButton.index;
                        ServiceDisplay.setScale(Number(scaleButton.modelData));
                    }

                    Text {
                        anchors.centerIn: parent
                        text: root.scaleLabel(Number(scaleButton.modelData))
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                    }
                }
            }
        }

        PanelSeparator {}

        PanelSectionHeader {
            title: "DISPLAYS"
            detail: ServiceDisplay.monitors.length > 1
                ? ServiceDisplay.monitors.length + " ACTIVE" : ""
        }

        Column {
            width: parent.width
            spacing: 4

            Repeater {
                model: ServiceDisplay.monitors

                Rectangle {
                    id: monitorRow
                    required property var modelData
                    readonly property bool focused: ServiceDisplay.focusedMonitor === modelData

                    width: parent.width
                    height: 36
                    radius: ServicePanel.rounding
                    color: focused
                        ? Util.alpha(Theme.foreground, 0.08)
                        : "transparent"
                    border.width: focused ? 1 : 0
                    border.color: Util.alpha(Theme.foreground, 0.25)
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        id: monitorIcon
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰍹"
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                    }

                    Text {
                        anchors.left: monitorIcon.right
                        anchors.leftMargin: 10
                        anchors.right: focusedCheck.left
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: String(monitorRow.modelData.name)
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }

                    Text {
                        id: focusedCheck
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        visible: monitorRow.focused
                        text: "󰄬"
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                    }
                }
            }
        }
    }
}
