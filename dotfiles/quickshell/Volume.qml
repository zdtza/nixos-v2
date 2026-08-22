pragma ComponentBehavior: Bound

// PipeWire audio panel: default-device selection, volume controls, and mic peak.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Stylix

Item {
    id: root

    readonly property bool available: !!AudioService.output
    readonly property bool opened: PanelService.activePanel === root
    readonly property int outputPercent: Math.round(AudioService.outputVolume * 100)
    readonly property int inputPercent: Math.round(AudioService.inputVolume * 100)

    visible: available
    implicitWidth: available ? indicator.implicitWidth : 0
    implicitHeight: indicator.implicitHeight

    function outputIcon(): string {
        if (AudioService.outputMuted)
            return "󰝟";
        if (AudioService.outputVolume >= 0.6)
            return "󰕾";
        if (AudioService.outputVolume >= 0.2)
            return "󰖀";
        return "󰕿";
    }

    function nodeLabel(node: var): string {
        if (!node)
            return "Unknown device";
        return node.description || node.nickname || node.name || "Audio device";
    }

    function volumeStatus(): string {
        if (AudioService.outputMuted)
            return "MUTED";
        if (AudioService.outputVolume <= 0)
            return "SILENT";
        if (AudioService.outputVolume < 0.2)
            return "WHISPER QUIET";
        if (AudioService.outputVolume < 0.5)
            return "EASY LISTENING";
        if (AudioService.outputVolume < 0.8)
            return "LOUD AND CLEAR";
        if (AudioService.outputVolume <= 1)
            return "TURNED UP";
        return "OVERDRIVE";
    }

    PwNodePeakMonitor {
        id: inputPeak
        node: AudioService.input
        enabled: root.opened && !!node && !AudioService.inputMuted
    }

    BarButton {
        id: indicator
        anchors.centerIn: parent
        panel: root
        text: root.outputIcon()
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                AudioService.toggleOutputMute();
            else
                PanelService.toggle(root);
        }
        onWheeled: wheel => AudioService.adjustOutputVolume(
            wheel.angleDelta.y > 0 ? AudioService.outputStep : -AudioService.outputStep)
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
        implicitWidth: 420
        implicitHeight: panelContent.implicitHeight + contentMargins * 2

        PanelHero {
            width: parent.width
            icon: root.outputIcon()
            title: "Audio"
            status: root.volumeStatus()
            trailingWidth: 44
            trailingHeight: 24

            Rectangle {
                anchors.fill: parent
                color: AudioService.outputMuted
                    ? Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.18)
                    : Theme.foreground
                border.width: 1
                border.color: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.4)

                Rectangle {
                    width: 18
                    height: 18
                    y: 3
                    x: AudioService.outputMuted ? 3 : parent.width - width - 3
                    color: AudioService.outputMuted ? Theme.foreground : Theme.background
                    Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: AudioService.toggleOutputMute()
                }
            }
        }

        PanelSeparator {}

        PanelSectionHeader {
            title: "OUTPUT"
            detail: root.outputPercent + "%"
        }

        AudioSlider {
            width: parent.width
            value: AudioService.outputVolume / AudioService.maximumVolume
            fillColor: AudioService.outputMuted ? Theme.muted : Theme.foreground
            onValueEdited: value => AudioService.setOutputVolume(value * AudioService.maximumVolume)
        }

        Column {
            width: parent.width
            spacing: 4

            Text {
                width: parent.width
                height: AudioService.outputs.length === 0 ? implicitHeight : 0
                visible: AudioService.outputs.length === 0
                text: "No audio outputs"
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 12
            }

            Repeater {
                model: AudioService.outputs

                DeviceRow {
                    required property var modelData
                    node: modelData
                    icon: "󰓃"
                    selected: AudioService.output === modelData
                    onActivated: AudioService.selectOutput(modelData)
                }
            }
        }

        PanelSeparator {}

        PanelSectionHeader {
            title: "INPUT"
            detail: AudioService.inputMuted ? "MUTED" : root.inputPercent + "%"
        }

        AudioSlider {
            width: parent.width
            enabled: !!AudioService.input
            value: AudioService.inputVolume / AudioService.maximumVolume
            fillColor: AudioService.inputMuted ? Theme.muted : Theme.foreground
            onValueEdited: value => AudioService.setInputVolume(value * AudioService.maximumVolume)
        }

        AudioLevelMeter {
            width: parent.width
            muted: AudioService.inputMuted
            // Mild compression keeps speech responsive without amplifying the
            // microphone noise floor as aggressively as a square-root curve.
            level: Math.pow(Math.max(0, Number(inputPeak.peak || 0)), 0.75)
        }

        Column {
            width: parent.width
            spacing: 4

            Text {
                width: parent.width
                height: AudioService.inputs.length === 0 ? implicitHeight : 0
                visible: AudioService.inputs.length === 0
                text: "No audio inputs"
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 12
            }

            Repeater {
                model: AudioService.inputs

                DeviceRow {
                    required property var modelData
                    node: modelData
                    icon: "󰍬"
                    selected: AudioService.input === modelData
                    onActivated: AudioService.selectInput(modelData)
                }
            }
        }
    }

    component DeviceRow: Rectangle {
        id: deviceRow

        required property var node
        property string icon: ""
        property bool selected: false

        signal activated()

        width: parent.width
        height: 36
        color: selected
            ? Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.18)
            : deviceMouse.containsMouse
                ? Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.08)
                : "transparent"
        border.width: selected || deviceMouse.containsMouse ? 1 : 0
        border.color: selected ? Theme.muted
            : Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.25)
        Behavior on color { ColorAnimation { duration: 120 } }

        Text {
            id: deviceIcon
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: deviceRow.icon
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: 14
        }

        Text {
            anchors.left: deviceIcon.right
            anchors.leftMargin: 10
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: root.nodeLabel(deviceRow.node)
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: 12
            font.bold: deviceRow.selected
            elide: Text.ElideRight
        }

        MouseArea {
            id: deviceMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: deviceRow.activated()
        }
    }
}
