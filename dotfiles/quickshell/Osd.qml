// Bottom-center volume and brightness feedback.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Stylix

Scope {
    id: root

    property var targetScreen: null
    property bool shown: false
    property string icon: ""
    property real value: 0
    property color fillColor: Theme.foreground

    function focusedScreen(): var {
        const monitorName = String(Hyprland.focusedMonitor?.name ?? "");
        for (const screen of Quickshell.screens) {
            if (String(screen.name) === monitorName)
                return screen;
        }
        return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null;
    }

    function show(iconName: string, progress: real, fill: color): void {
        targetScreen = focusedScreen();
        if (!targetScreen)
            return;
        icon = iconName;
        value = Math.max(0, Math.min(1, Number(progress)));
        fillColor = fill;
        shown = true;
        hideTimer.restart();
    }

    function outputIcon(): string {
        if (ServiceAudio.outputMuted)
            return "󰝟";
        if (ServiceAudio.outputVolume >= 0.6)
            return "󰕾";
        if (ServiceAudio.outputVolume >= 0.2)
            return "󰖀";
        return "󰕿";
    }

    Timer {
        id: hideTimer
        interval: 800
        onTriggered: root.shown = false
    }

    Connections {
        target: ServiceAudio

        function onVolumeIpcInvoked(input: bool): void {
            if (input) {
                root.show(ServiceAudio.inputMuted ? "󰍭" : "󰍬",
                    ServiceAudio.inputVolume / ServiceAudio.maximumVolume,
                    ServiceAudio.inputMuted ? Theme.muted : Theme.foreground);
            } else {
                root.show(root.outputIcon(),
                    ServiceAudio.outputVolume / ServiceAudio.maximumVolume,
                    ServiceAudio.outputMuted ? Theme.muted : Theme.foreground);
            }
        }
    }

    Connections {
        target: ServiceDisplay

        function onBrightnessIpcInvoked(): void {
            root.show("󰍹", ServiceDisplay.brightnessPercent / 100, Theme.foreground);
        }
    }

    PanelWindow {
        id: window

        screen: root.targetScreen
        visible: root.shown && !!root.targetScreen
        color: "transparent"
        implicitWidth: 240
        implicitHeight: 52
        exclusionMode: ExclusionMode.Ignore

        WlrLayershell.namespace: "quickshell:osd"
        WlrLayershell.layer: WlrLayer.Overlay

        anchors.bottom: true
        margins.bottom: ServicePanel.barGap + ServicePanel.gapBottomOffset

        Rectangle {
            anchors.fill: parent
            color: Theme.background
            border.width: 1
            border.color: Theme.border
            radius: ServicePanel.rounding

            Row {
                anchors {
                    fill: parent
                    margins: 16
                    leftMargin: 11
                }
                spacing: 14

                Text {
                    width: 18
                    height: parent.height
                    text: root.icon
                    color: Theme.foreground
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.family: Theme.fontFamily
                    font.pixelSize: Util.scaledFont(16)
                }

                Item {
                    width: parent.width - 18 - parent.spacing
                    height: parent.height

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: 5
                        radius: height / 2
                        color: Util.alpha(Theme.foreground, 0.12)

                        Rectangle {
                            width: parent.width * root.value
                            height: parent.height
                            radius: parent.radius
                            color: root.fillColor
                        }
                    }
                }
            }
        }
    }
}
