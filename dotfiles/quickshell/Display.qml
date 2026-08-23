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
    readonly property bool requiresKeyboardFocus: false
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

    function showIpcFeedback(): void {
        const focused = Hyprland.focusedMonitor;
        if (focused && String(screen.name) !== String(focused.name))
            return;
        if (focused?.activeWorkspace?.hasFullscreen)
            return;
        if (!opened) {
            feedbackOpened = true;
            PanelService.open(root);
        }
        if (feedbackOpened)
            feedbackClose.restart();
    }

    function closeIpcFeedback(): void {
        if (!feedbackOpened)
            return;
        feedbackClose.stop();
        PanelService.close(root);
        feedbackOpened = false;
    }

    property bool feedbackOpened: false

    onOpenedChanged: {
        if (opened && DisplayService.focusedMonitor) {
            const currentScale = Number(DisplayService.focusedMonitor.scale);
            const index = scales.findIndex(scale => Math.abs(Number(scale) - currentScale) < 0.01);
            selectedScaleIndex = Math.max(0, index);
        }
        if (!opened && feedbackOpened) {
            feedbackClose.stop();
            feedbackOpened = false;
        }
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

    Connections {
        target: DisplayService
        function onBrightnessIpcInvoked(): void { root.showIpcFeedback(); }
    }

    Connections {
        target: Hyprland.focusedWorkspace
        function onHasFullscreenChanged(): void {
            if (Hyprland.focusedWorkspace?.hasFullscreen)
                root.closeIpcFeedback();
        }
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
                    required property int index
                    readonly property bool selected: DisplayService.focusedMonitor
                        && Math.abs(Number(DisplayService.focusedMonitor.scale)
                            - Number(modelData)) < 0.01

                    width: scaleRow.cellWidth
                    height: 32
                    color: selected
                        ? Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.18)
                        : scaleButton.index === root.selectedScaleIndex || scaleMouse.containsMouse
                            ? Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.08)
                            : Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.04)
                    border.width: 1
                    border.color: selected || scaleButton.index === root.selectedScaleIndex
                        ? Theme.muted
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
                        onClicked: {
                            root.selectedScaleIndex = scaleButton.index;
                            DisplayService.setScale(Number(scaleButton.modelData));
                        }
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
