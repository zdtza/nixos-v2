// Bottom-center volume and brightness feedback, plus the persistent voice
// dictation readout.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Wayland
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
    property int percent: 0
    property color fillColor: Theme.base05

    // Dictation has no timer: it shows for as long as voxtype is recording.
    // A volume or brightness OSD still wins the surface while its own timer
    // runs, then the dictation readout comes back underneath it.
    readonly property bool dictationView: VoiceDictationService.recording && !shown
    readonly property string displayIcon: dictationView
        ? (AudioService.inputMuted ? "󰍭" : "󰍬") : icon
    // Live microphone peak -- the same meter the audio panel's INPUT section
    // draws, through the same Utils.peakLevel curve, so the bar follows the
    // voice being dictated rather than a slider position.
    readonly property real displayValue: dictationView
        ? Utils.peakLevel(inputPeak.peak) : value
    readonly property color displayFill: dictationView
        ? (AudioService.inputMuted ? Theme.base04 : Theme.base05) : fillColor

    // A peak monitor is a real PipeWire capture stream, so only run one while
    // the readout is actually on screen.
    PwNodePeakMonitor {
        id: inputPeak
        node: AudioService.input
        enabled: root.dictationView && !!node && !AudioService.inputMuted
    }

    // percentValue is `real`, not `int`: an int parameter truncates on the way
    // in, so 70% volume that PipeWire reads back as 0.6999999 arrived as 69 and
    // the OSD disagreed with the panel by a percent.
    function show(iconName: string, progress: real, fill: color, percentValue: real): void {
        if (Quickshell.screens.length === 0)
            return;
        targetScreenName = String(Hyprland.focusedMonitor?.name ?? "");
        icon = iconName;
        value = Math.max(0, Math.min(1, Number(progress)));
        percent = Math.round(percentValue);
        fillColor = fill;
        shown = true;
        hideTimer.restart();
    }

    Timer {
        id: hideTimer
        // Longer than the ~1s pre-repeat delay of the brightness keys, so the
        // OSD doesn't blink out between the first tap and the repeat stream.
        interval: 1400
        onTriggered: root.shown = false
    }

    Connections {
        target: AudioService

        function onVolumeIpcInvoked(input: bool): void {
            if (input) {
                root.show(AudioService.inputMuted ? "󰍭" : "󰍬",
                    AudioService.inputVolume / AudioService.maximumVolume,
                    AudioService.inputMuted ? Theme.base04 : Theme.base05,
                    AudioService.inputVolume * 100);
            } else {
                root.show(AudioService.outputIcon,
                    AudioService.outputVolume / AudioService.maximumVolume,
                    AudioService.outputMuted ? Theme.base04 : Theme.base05,
                    AudioService.outputVolume * 100);
            }
        }
    }

    Connections {
        target: VoiceDictationService

        // Same rule as show(): pin the readout to whichever monitor was
        // focused when recording started, and never cache the screen object.
        function onRecordingChanged(): void {
            if (VoiceDictationService.recording && Quickshell.screens.length > 0)
                root.targetScreenName = String(Hyprland.focusedMonitor?.name ?? "");
        }
    }

    Connections {
        target: DisplayService

        function onBrightnessIpcInvoked(): void {
            root.show("󰍹", DisplayService.level / DisplayService.maxLevel,
                Theme.base05, DisplayService.level);
        }
    }

    PanelWindow {
        id: window

        screen: Utils.screenForMonitor(root.targetScreenName)
        visible: (root.shown || VoiceDictationService.recording)
            && Quickshell.screens.length > 0
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
                    margins: 14
                    leftMargin: 11
                    rightMargin: 11
                }
                spacing: 12

                ShellText {
                    width: 18
                    height: parent.height
                    text: root.displayIcon
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    size: 15
                }

                Item {
                    // The percent label collapses entirely for dictation, so
                    // its spacing has to go with it or the bar stops short of
                    // the padding on the right.
                    width: parent.width - 18 - percentText.width
                        - (percentText.visible ? 2 : 1) * parent.spacing
                    height: parent.height

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: 4
                        radius: height / 2
                        color: Utils.alpha(Theme.base05, 0.12)

                        Rectangle {
                            width: parent.width * root.displayValue
                            height: parent.height
                            radius: parent.radius
                            color: root.displayFill

                            Behavior on width {
                                NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                            }
                        }
                    }
                }

                ShellText {
                    id: percentText
                    // Dictation is a state readout, not a value being nudged,
                    // so it shows the icon and bar only.
                    visible: !root.dictationView
                    // Natural width, not the widest possible label: the track
                    // absorbs the slack so "5%" keeps the same right padding
                    // as "150%" instead of leaving a gap after the bar.
                    width: visible ? implicitWidth : 0
                    height: parent.height
                    text: root.percent + "%"
                    horizontalAlignment: Text.AlignRight
                    verticalAlignment: Text.AlignVCenter
                    size: 11
                    color: Utils.alpha(Theme.base05, 0.6)
                }
            }
        }
    }
}
