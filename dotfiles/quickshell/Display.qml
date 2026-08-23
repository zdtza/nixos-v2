pragma ComponentBehavior: Bound

// Brightness, focused-monitor scale, and monitor overview.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Stylix

Item {
    id: root

    required property var screen
    readonly property bool available: DisplayService.available || DisplayService.monitors.length > 0
    readonly property bool opened: PanelService.activePanel === root
    readonly property var scales: [1, 1.33, 1.6, 2, 3.13, 4]

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

    function showIpcFeedback(): void {
        const focused = Hyprland.focusedMonitor;
        if (focused && String(screen.name) !== String(focused.name))
            return;
        if (!opened) {
            feedbackOpened = true;
            PanelService.open(root);
        }
        if (feedbackOpened)
            feedbackClose.restart();
    }

    property bool feedbackOpened: false

    onOpenedChanged: {
        if (!opened && feedbackOpened) {
            feedbackClose.stop();
            feedbackOpened = false;
        }
    }

    Connections {
        target: DisplayService
        function onBrightnessIpcInvoked(): void { root.showIpcFeedback(); }
    }

    Timer {
        id: feedbackClose
        interval: 800
        onTriggered: {
            PanelService.close(root);
            root.feedbackOpened = false;
        }
    }

    BarButton {
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

    PanelPopup {
        id: panel
        anchorItem: root
        anchorWindow: root.QsWindow.window
        visible: root.opened
        onCloseRequested: PanelService.close(root)
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
            detail: DisplayService.available
                ? DisplayService.brightnessPercent + "%" : "UNAVAILABLE"
        }

        AudioSlider {
            width: parent.width
            enabled: DisplayService.available
            value: DisplayService.brightnessPercent / 100
            onValueEdited: value => DisplayService.setBrightness(Math.round(value * 100))
        }

        PanelSeparator {}

        PanelSectionHeader {
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

                Rectangle {
                    id: scaleButton
                    required property var modelData
                    readonly property bool selected: DisplayService.focusedMonitor
                        && Math.abs(Number(DisplayService.focusedMonitor.scale)
                            - Number(modelData)) < 0.01

                    width: scaleRow.cellWidth
                    height: 32
                    color: selected
                        ? Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.18)
                        : scaleMouse.containsMouse
                            ? Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.08)
                            : Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.04)
                    border.width: 1
                    border.color: selected ? Theme.muted
                        : Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.3)
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        anchors.centerIn: parent
                        text: root.scaleLabel(Number(scaleButton.modelData))
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.bold: scaleButton.selected
                    }

                    MouseArea {
                        id: scaleMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: !!DisplayService.focusedMonitor
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: DisplayService.setScale(Number(scaleButton.modelData))
                    }
                }
            }
        }

        PanelSeparator {}

        PanelSectionHeader {
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
                    height: 38
                    color: focused
                        ? Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.18)
                        : "transparent"
                    border.width: focused ? 1 : 0
                    border.color: Theme.muted

                    Text {
                        id: monitorIcon
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰍹"
                        color: monitorRow.focused ? Theme.foreground : Theme.muted
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
                            + (monitorRow.focused ? " · focused" : "")
                        color: monitorRow.focused ? Theme.foreground : Theme.muted
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
