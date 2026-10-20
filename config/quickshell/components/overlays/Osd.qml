// Bottom-center volume, brightness and media feedback, plus the persistent voice dictation readout.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import "../primitives"
import "../../services"
import "../.."

Scope {
    id: root

    // Only the monitor *name* is cached, never a screen object.
    property string targetScreenName: ""
    property bool shown: false
    property string icon: ""
    property real value: 0
    property int percent: 0
    property color fillColor: Theme.base05
    // Media keys swap the level bar for clickable transport controls.
    property bool mediaShown: false

    // Dictation has no timer: it shows for as long as voxtype is recording.
    readonly property bool dictationView: VoiceDictationService.recording && !shown
    readonly property bool mediaView: shown && mediaShown
    readonly property string displayIcon: dictationView
        ? (AudioService.inputMuted ? "󰍭" : "󰍬")
        : icon
    // Live microphone peak.
    readonly property real displayValue: dictationView
        ? Utils.peakLevel(inputPeak.peak) : value
    readonly property color displayFill: dictationView
        ? (AudioService.inputMuted ? Theme.base04 : Theme.base05) : fillColor

    // The built-in mic's wake-up DC offset is avoided by keeping it from
    // suspending (hosts/legion/default.nix), so the raw peak is shown as-is.
    PwNodePeakMonitor {
        id: inputPeak
        node: AudioService.input
        enabled: VoiceDictationService.recording && !!node && !AudioService.inputMuted
    }

    // percentValue is `real`, not `int`
    function show(iconName: string, progress: real, fill: color, percentValue: real): void {
        if (Quickshell.screens.length === 0)
            return;
        targetScreenName = String(Hyprland.focusedMonitor?.name ?? "");
        icon = iconName;
        value = Math.max(0, Math.min(1, Number(progress)));
        percent = Math.round(percentValue);
        fillColor = fill;
        mediaShown = false;
        shown = true;
        hideTimer.restart();
    }

    function showMedia(): void {
        if (Quickshell.screens.length === 0)
            return;
        targetScreenName = String(Hyprland.focusedMonitor?.name ?? "");
        mediaShown = true;
        shown = true;
        if (!cardHover.hovered)
            hideTimer.restart();
    }

    Timer {
        id: hideTimer
        // Longer than the ~1s pre-repeat delay of the brightness keys, so the OSD doesn't blink out between the first tap and the repeat stream.
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

        // Same rule as show(): pin the readout to whichever monitor was focused when recording started, and never cache the screen object.
        function onRecordingChanged(): void {
            if (VoiceDictationService.recording && Quickshell.screens.length > 0)
                root.targetScreenName = String(Hyprland.focusedMonitor?.name ?? "");
        }
    }

    Connections {
        target: MediaService

        function onMediaIpcInvoked(): void {
            root.showMedia();
        }
    }

    Connections {
        target: MonitorService

        function onBrightnessIpcInvoked(): void {
            root.show("󰍹", MonitorService.brightnessPercent / 100,
                Theme.base05, MonitorService.brightnessPercent);
        }
    }

    PanelWindow {
        id: window

        screen: Utils.screenForMonitor(root.targetScreenName)
        visible: (root.shown || VoiceDictationService.recording)
            && Quickshell.screens.length > 0
        color: "transparent"
        // Shadow room around the card, cut to the gap at the screen's bottom edge.
        readonly property real shadowBottom: PanelService.panelGap
        // Wider for media so track titles have room.
        implicitWidth: (root.mediaView ? 320 : 240) + Theme.shadowExtent * 2
        implicitHeight: 52 + Theme.shadowExtent + shadowBottom
        exclusionMode: ExclusionMode.Ignore

        WlrLayershell.namespace: "quickshell:osd"
        WlrLayershell.layer: WlrLayer.Overlay

        // The OSD always lives at the bottom. Only make room for the bar when
        // it is also at the bottom and currently affects panel geometry.
        anchors.bottom: true
        margins.bottom: PanelService.panelGap
            + (PanelService.barAtTop ? 0 : PanelService.panelBarInset) - shadowBottom

        mask: Region { item: card }

        ShellShadow {
            anchors.fill: card
        }

        Rectangle {
            id: card
            anchors {
                fill: parent
                leftMargin: Theme.shadowExtent
                rightMargin: Theme.shadowExtent
                topMargin: Theme.shadowExtent
                bottomMargin: window.shadowBottom
            }
            color: Theme.base01
            radius: 0

            // Stays up while the pointer is over it so the media controls can be used.
            HoverHandler {
                id: cardHover
                onHoveredChanged: {
                    if (hovered)
                        hideTimer.stop();
                    else if (root.shown)
                        hideTimer.restart();
                }
            }

            Row {
                visible: !root.mediaView
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
                    // The percent label collapses entirely for dictation, so its spacing has to go with it or the bar stops short of the padding on the right.
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
                    // Dictation is a state readout, not a value being nudged, so it shows the icon and bar only.
                    visible: !root.dictationView
                    // Natural width, not the widest possible label.
                    width: visible ? implicitWidth : 0
                    height: parent.height
                    text: root.percent + "%"
                    horizontalAlignment: Text.AlignRight
                    verticalAlignment: Text.AlignVCenter
                    size: 11
                    color: Utils.alpha(Theme.base05, 0.6)
                }
            }

            Row {
                visible: root.mediaView
                anchors {
                    fill: parent
                    margins: 8
                    leftMargin: 8
                    rightMargin: 14
                }
                spacing: 4

                MediaButton {
                    icon: "󰒮"
                    available: !!MediaService.player && MediaService.player.canGoPrevious
                    onClicked: MediaService.control("previous")
                }

                MediaButton {
                    icon: MediaService.playing ? "󰏤" : "󰐊"
                    iconSize: 20
                    available: !!MediaService.player && MediaService.player.canTogglePlaying
                    onClicked: MediaService.control("playPause")
                }

                MediaButton {
                    icon: "󰒭"
                    available: !!MediaService.player && MediaService.player.canGoNext
                    onClicked: MediaService.control("next")
                }

                Column {
                    width: parent.width - x
                    anchors.verticalCenter: parent.verticalCenter
                    leftPadding: 8
                    spacing: 1

                    ShellText {
                        width: parent.width - parent.leftPadding
                        text: MediaService.player ? MediaService.title : "No media playing"
                        elide: Text.ElideRight
                        size: 12
                        color: MediaService.player ? Theme.base05 : Utils.alpha(Theme.base05, 0.6)
                    }

                    ShellText {
                        width: parent.width - parent.leftPadding
                        visible: text !== ""
                        text: MediaService.artist
                        elide: Text.ElideRight
                        size: 11
                        color: Utils.alpha(Theme.base05, 0.6)
                    }
                }
            }
        }
    }

    component MediaButton: Rectangle {
        id: button

        property string icon: ""
        property real iconSize: 16
        property bool available: true

        signal clicked()

        width: 36
        height: 36
        radius: PanelService.rounding
        opacity: available ? 1 : 0.4
        color: buttonMouse.pressed ? Utils.alpha(Theme.base05, 0.16)
            : buttonMouse.containsMouse ? Utils.alpha(Theme.base05, 0.08)
            : "transparent"

        ShellText {
            anchors.centerIn: parent
            text: button.icon
            size: button.iconSize
        }

        MouseArea {
            id: buttonMouse
            anchors.fill: parent
            enabled: button.available
            hoverEnabled: true
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: button.clicked()
        }
    }
}
