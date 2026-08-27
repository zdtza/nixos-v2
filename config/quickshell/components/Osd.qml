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
    property color fillColor: Theme.foreground

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

        screen: root.screenForMonitor(root.targetScreenName)
        visible: root.shown && Quickshell.screens.length > 0
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
            color: Theme.dark_background
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
                        color: Utils.alpha(Theme.foreground, 0.12)

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
