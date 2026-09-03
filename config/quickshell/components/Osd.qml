// Bottom-center volume and brightness feedback.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Stylix
import "../services"
import ".."

Scope {
    id: root

    // Only the monitor *name* is cached, never a screen object -- see
    // Notifications.qml for why caching a QuickshellScreenInfo/QScreen
    // reference across a reload segfaults.
    property string targetScreenName: ""
    property bool shown: false
    property string icon: ""
    property real value: 0
    property color fillColor: Theme.base05

    function screenForMonitor(name: string): var {
        for (const screen of Quickshell.screens) {
            if (String(screen.name) === name)
                return screen;
        }
        return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null;
    }

    function show(iconName: string, progress: real, fill: color): void {
        if (Quickshell.screens.length === 0)
            return;
        targetScreenName = String(Hyprland.focusedMonitor?.name ?? "");
        icon = iconName;
        value = Math.max(0, Math.min(1, Number(progress)));
        fillColor = fill;
        shown = true;
        hideTimer.restart();
    }

    function outputIcon(): string {
        if (AudioService.outputMuted)
            return "󰝟";
        if (AudioService.outputVolume >= 0.6)
            return "󰕾";
        if (AudioService.outputVolume >= 0.2)
            return "󰖀";
        return "󰕿";
    }

    Timer {
        id: hideTimer
        interval: 800
        onTriggered: root.shown = false
    }

    Connections {
        target: AudioService

        function onVolumeIpcInvoked(input: bool): void {
            if (input) {
                root.show(AudioService.inputMuted ? "󰍭" : "󰍬",
                    AudioService.inputVolume / AudioService.maximumVolume,
                    AudioService.inputMuted ? Theme.base04 : Theme.base05);
            } else {
                root.show(root.outputIcon(),
                    AudioService.outputVolume / AudioService.maximumVolume,
                    AudioService.outputMuted ? Theme.base04 : Theme.base05);
            }
        }
    }

    Connections {
        target: DisplayService

        function onBrightnessIpcInvoked(): void {
            root.show("󰍹", DisplayService.brightnessPercent / 100, Theme.base05);
        }
    }

    PanelWindow {
        id: window

        screen: root.screenForMonitor(root.targetScreenName)
        visible: root.shown && Quickshell.screens.length > 0
        color: "transparent"
        implicitWidth: 240
        implicitHeight: 52
        exclusionMode: ExclusionMode.Ignore

        WlrLayershell.namespace: "quickshell:osd"
        WlrLayershell.layer: WlrLayer.Overlay

        anchors.bottom: true
        margins.bottom: PanelService.barGap + PanelService.gapBottomOffset

        Rectangle {
            anchors.fill: parent
            color: Theme.base01
            radius: PanelService.rounding
            layer.enabled: true
            layer.effect: ShellShadow {}

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
                    color: Theme.base05
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.family: Theme.monospace
                    font.pixelSize: Utils.scaledFont(16)
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
                        color: Utils.alpha(Theme.base05, 0.12)

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
