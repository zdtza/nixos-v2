pragma ComponentBehavior: Bound

// PipeWire audio panel: default-device selection, volume controls, and mic peak.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Stylix
import "../components"
import "../services"
import ".."

Item {
    id: root

    required property var screen
    readonly property bool available: !!AudioService.output
    readonly property bool opened: PanelService.activePanel === root
    readonly property bool requiresKeyboardFocus: true
    readonly property int outputPercent: Math.round(AudioService.outputVolume * 100)
    readonly property int inputPercent: Math.round(AudioService.inputVolume * 100)
    readonly property var keyboardDevices: AudioService.outputs.concat(AudioService.inputs)
    property int selectedDeviceIndex: 0

    visible: available
    implicitWidth: available ? indicator.implicitWidth : 0
    implicitHeight: indicator.implicitHeight

    function moveDeviceSelection(offset: int): void {
        if (keyboardDevices.length === 0)
            return;
        selectedDeviceIndex = Math.max(0,
            Math.min(keyboardDevices.length - 1, selectedDeviceIndex + offset));
    }

    function activateSelectedDevice(): void {
        const device = keyboardDevices[selectedDeviceIndex];
        if (!device)
            return;
        if (selectedDeviceIndex < AudioService.outputs.length)
            AudioService.selectOutput(device);
        else
            AudioService.selectInput(device);
    }

    function adjustSelectedVolume(offset: real): void {
        if (selectedDeviceIndex < AudioService.outputs.length)
            AudioService.adjustOutputVolume(offset * AudioService.outputStep);
        else
            AudioService.adjustInputVolume(offset * AudioService.inputStep);
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

    onOpenedChanged: if (opened)
        selectedDeviceIndex = Math.max(0,
            AudioService.outputs.indexOf(AudioService.output));

    Shortcut {
        enabled: root.opened
        sequence: "Up"
        context: Qt.ApplicationShortcut
        onActivated: root.moveDeviceSelection(-1)
    }
    Shortcut {
        enabled: root.opened
        sequence: "Down"
        context: Qt.ApplicationShortcut
        onActivated: root.moveDeviceSelection(1)
    }
    Shortcut {
        enabled: root.opened
        sequence: "Left"
        context: Qt.ApplicationShortcut
        onActivated: root.adjustSelectedVolume(-1)
    }
    Shortcut {
        enabled: root.opened
        sequence: "Right"
        context: Qt.ApplicationShortcut
        onActivated: root.adjustSelectedVolume(1)
    }
    Shortcut {
        enabled: root.opened
        sequence: "Return"
        context: Qt.ApplicationShortcut
        onActivated: root.activateSelectedDevice()
    }
    Shortcut {
        enabled: root.opened
        sequence: "Enter"
        context: Qt.ApplicationShortcut
        onActivated: root.activateSelectedDevice()
    }
    Shortcut {
        enabled: root.opened
        sequence: "Space"
        context: Qt.ApplicationShortcut
        onActivated: AudioService.toggleOutputMute()
    }
    PwNodePeakMonitor {
        id: inputPeak
        node: AudioService.input
        enabled: root.opened && !!node && !AudioService.inputMuted
    }

    Button {
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

    Drawer {
        id: panel
        anchorItem: root
        anchorWindow: root.QsWindow.window
        open: root.opened
        onCloseRequested: PanelService.close(root)
        contentSpacing: 14
        implicitWidth: 420 + PanelService.shellRounding
        implicitHeight: panelContent.implicitHeight
            + contentTopMargin + contentBottomMargin

        Hero {
            width: parent.width
            icon: root.outputIcon()
            title: "Audio"
            status: root.volumeStatus()
            trailingWidth: 44
            trailingHeight: 24

            ToggleSwitch {
                anchors.fill: parent
                checked: !AudioService.outputMuted
                onToggled: AudioService.toggleOutputMute()
            }
        }

        Separator {}

        SectionHeader {
            title: "OUTPUT"
            detail: root.outputPercent + "%"
        }

        Slider {
            width: parent.width
            value: AudioService.outputVolume / AudioService.maximumVolume
            fillColor: AudioService.outputMuted ? Theme.base04 : Theme.base05
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
                color: Theme.base04
                font.family: Theme.monospace
                font.pixelSize: Utils.scaledFont(12)
            }

            Repeater {
                model: AudioService.outputs

                DeviceRow {
                    id: outputDeviceRow
                    required property var modelData
                    required property int index
                    node: modelData
                    icon: "󰓃"
                    selected: AudioService.output === modelData
                    keyboardSelected: outputDeviceRow.index === root.selectedDeviceIndex
                    onActivated: {
                        root.selectedDeviceIndex = outputDeviceRow.index;
                        AudioService.selectOutput(modelData);
                    }
                }
            }
        }

        Separator {}

        SectionHeader {
            title: "INPUT"
            detail: AudioService.inputMuted ? "MUTED" : root.inputPercent + "%"
        }

        Slider {
            width: parent.width
            enabled: !!AudioService.input
            value: AudioService.inputVolume / AudioService.maximumVolume
            fillColor: AudioService.inputMuted ? Theme.base04 : Theme.base05
            onValueEdited: value => AudioService.setInputVolume(value * AudioService.maximumVolume)
        }

        Item {
            id: inputLevelMeter

            // Mild compression keeps speech responsive without amplifying the
            // microphone noise floor as aggressively as a square-root curve.
            readonly property real level: Math.pow(
                Math.max(0, Number(inputPeak.peak || 0)), 0.75)

            width: parent.width
            implicitHeight: 6

            Rectangle {
                anchors.fill: parent
                radius: PanelService.rounding
                color: Utils.alpha(Theme.base05, 0.12)

                Rectangle {
                    height: parent.height
                    width: parent.width * Math.max(0,
                        Math.min(1, inputLevelMeter.level))
                    radius: PanelService.rounding
                    color: AudioService.inputMuted
                        ? Theme.base04 : Theme.base05
                    Behavior on width { NumberAnimation { duration: 55 } }
                }
            }
        }

        Column {
            width: parent.width
            spacing: 4

            Text {
                width: parent.width
                height: AudioService.inputs.length === 0 ? implicitHeight : 0
                visible: AudioService.inputs.length === 0
                text: "No audio inputs"
                color: Theme.base04
                font.family: Theme.monospace
                font.pixelSize: Utils.scaledFont(12)
            }

            Repeater {
                model: AudioService.inputs

                DeviceRow {
                    id: inputDeviceRow
                    required property var modelData
                    required property int index
                    node: modelData
                    icon: "󰍬"
                    selected: AudioService.input === modelData
                    keyboardSelected: AudioService.outputs.length + inputDeviceRow.index
                        === root.selectedDeviceIndex
                    onActivated: {
                        root.selectedDeviceIndex = AudioService.outputs.length
                            + inputDeviceRow.index;
                        AudioService.selectInput(modelData);
                    }
                }
            }
        }
    }

    component DeviceRow: Rectangle {
        id: deviceRow

        required property var node
        property string icon: ""
        property bool selected: false
        property bool keyboardSelected: false

        signal activated()

        width: parent.width
        height: 36
        radius: PanelService.rounding
        color: keyboardSelected
            ? Utils.alpha(Theme.base05, 0.08)
            : "transparent"
        border.width: keyboardSelected ? 1 : 0
        border.color: Utils.alpha(Theme.base05, 0.25)

        Text {
            id: deviceIcon
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: deviceRow.icon
            color: Theme.base05
            font.family: Theme.monospace
            font.pixelSize: Utils.scaledFont(14)
        }

        Text {
            anchors.left: deviceIcon.right
            anchors.leftMargin: 10
            anchors.right: defaultIcon.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: root.nodeLabel(deviceRow.node)
            color: Theme.base05
            font.family: Theme.monospace
            font.pixelSize: Utils.scaledFont(12)
            elide: Text.ElideRight
        }

        Text {
            id: defaultIcon
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            visible: deviceRow.selected
            text: "󰄬"
            color: Theme.base05
            font.family: Theme.monospace
            font.pixelSize: Utils.scaledFont(12)
        }

        MouseArea {
            id: deviceMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onContainsMouseChanged: if (containsMouse) {
                const index = AudioService.outputs.indexOf(deviceRow.node);
                root.selectedDeviceIndex = index >= 0 ? index
                    : AudioService.outputs.length
                        + AudioService.inputs.indexOf(deviceRow.node);
            }
            onClicked: deviceRow.activated()
        }
    }
}
