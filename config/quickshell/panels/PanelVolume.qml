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
    readonly property bool available: !!ServiceAudio.output
    readonly property bool opened: ServicePanel.activePanel === root
    readonly property bool requiresKeyboardFocus: true
    readonly property int outputPercent: Math.round(ServiceAudio.outputVolume * 100)
    readonly property int inputPercent: Math.round(ServiceAudio.inputVolume * 100)
    readonly property var keyboardDevices: ServiceAudio.outputs.concat(ServiceAudio.inputs)
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
        if (selectedDeviceIndex < ServiceAudio.outputs.length)
            ServiceAudio.selectOutput(device);
        else
            ServiceAudio.selectInput(device);
    }

    function adjustSelectedVolume(offset: real): void {
        if (selectedDeviceIndex < ServiceAudio.outputs.length)
            ServiceAudio.adjustOutputVolume(offset * ServiceAudio.outputStep);
        else
            ServiceAudio.adjustInputVolume(offset * ServiceAudio.inputStep);
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

    function nodeLabel(node: var): string {
        if (!node)
            return "Unknown device";
        return node.description || node.nickname || node.name || "Audio device";
    }

    function volumeStatus(): string {
        if (ServiceAudio.outputMuted)
            return "MUTED";
        if (ServiceAudio.outputVolume <= 0)
            return "SILENT";
        if (ServiceAudio.outputVolume < 0.2)
            return "WHISPER QUIET";
        if (ServiceAudio.outputVolume < 0.5)
            return "EASY LISTENING";
        if (ServiceAudio.outputVolume < 0.8)
            return "LOUD AND CLEAR";
        if (ServiceAudio.outputVolume <= 1)
            return "TURNED UP";
        return "OVERDRIVE";
    }

    onOpenedChanged: if (opened)
        selectedDeviceIndex = Math.max(0,
            ServiceAudio.outputs.indexOf(ServiceAudio.output));

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
        onActivated: ServiceAudio.toggleOutputMute()
    }
    PwNodePeakMonitor {
        id: inputPeak
        node: ServiceAudio.input
        enabled: root.opened && !!node && !ServiceAudio.inputMuted
    }

    BarButton {
        id: indicator
        anchors.centerIn: parent
        panel: root
        text: root.outputIcon()
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                ServiceAudio.toggleOutputMute();
            else
                ServicePanel.toggle(root);
        }
        onWheeled: wheel => ServiceAudio.adjustOutputVolume(
            wheel.angleDelta.y > 0 ? ServiceAudio.outputStep : -ServiceAudio.outputStep)
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
        implicitWidth: 420
        implicitHeight: panelContent.implicitHeight
            + contentTopMargin + contentBottomMargin

        PanelHero {
            width: parent.width
            icon: root.outputIcon()
            title: "Audio"
            status: root.volumeStatus()
            trailingWidth: 44
            trailingHeight: 24

            PanelToggleSwitch {
                anchors.fill: parent
                checked: !ServiceAudio.outputMuted
                onToggled: ServiceAudio.toggleOutputMute()
            }
        }

        PanelSeparator {}

        PanelSectionHeader {
            title: "OUTPUT"
            detail: root.outputPercent + "%"
        }

        PanelSlider {
            width: parent.width
            value: ServiceAudio.outputVolume / ServiceAudio.maximumVolume
            fillColor: ServiceAudio.outputMuted ? Theme.muted : Theme.foreground
            onValueEdited: value => ServiceAudio.setOutputVolume(value * ServiceAudio.maximumVolume)
        }

        Column {
            width: parent.width
            spacing: 4

            Text {
                width: parent.width
                height: ServiceAudio.outputs.length === 0 ? implicitHeight : 0
                visible: ServiceAudio.outputs.length === 0
                text: "No audio outputs"
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: Utils.scaledFont(12)
            }

            Repeater {
                model: ServiceAudio.outputs

                DeviceRow {
                    id: outputDeviceRow
                    required property var modelData
                    required property int index
                    node: modelData
                    icon: "󰓃"
                    selected: ServiceAudio.output === modelData
                    keyboardSelected: outputDeviceRow.index === root.selectedDeviceIndex
                    onActivated: {
                        root.selectedDeviceIndex = outputDeviceRow.index;
                        ServiceAudio.selectOutput(modelData);
                    }
                }
            }
        }

        PanelSeparator {}

        PanelSectionHeader {
            title: "INPUT"
            detail: ServiceAudio.inputMuted ? "MUTED" : root.inputPercent + "%"
        }

        PanelSlider {
            width: parent.width
            enabled: !!ServiceAudio.input
            value: ServiceAudio.inputVolume / ServiceAudio.maximumVolume
            fillColor: ServiceAudio.inputMuted ? Theme.muted : Theme.foreground
            onValueEdited: value => ServiceAudio.setInputVolume(value * ServiceAudio.maximumVolume)
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
                radius: ServicePanel.rounding
                color: Utils.alpha(Theme.foreground, 0.12)

                Rectangle {
                    height: parent.height
                    width: parent.width * Math.max(0,
                        Math.min(1, inputLevelMeter.level))
                    radius: ServicePanel.rounding
                    color: ServiceAudio.inputMuted
                        ? Theme.muted : Theme.foreground
                    Behavior on width { NumberAnimation { duration: 55 } }
                }
            }
        }

        Column {
            width: parent.width
            spacing: 4

            Text {
                width: parent.width
                height: ServiceAudio.inputs.length === 0 ? implicitHeight : 0
                visible: ServiceAudio.inputs.length === 0
                text: "No audio inputs"
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: Utils.scaledFont(12)
            }

            Repeater {
                model: ServiceAudio.inputs

                DeviceRow {
                    id: inputDeviceRow
                    required property var modelData
                    required property int index
                    node: modelData
                    icon: "󰍬"
                    selected: ServiceAudio.input === modelData
                    keyboardSelected: ServiceAudio.outputs.length + inputDeviceRow.index
                        === root.selectedDeviceIndex
                    onActivated: {
                        root.selectedDeviceIndex = ServiceAudio.outputs.length
                            + inputDeviceRow.index;
                        ServiceAudio.selectInput(modelData);
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
        radius: ServicePanel.rounding
        color: keyboardSelected
            ? Utils.alpha(Theme.foreground, 0.08)
            : "transparent"
        border.width: keyboardSelected ? 1 : 0
        border.color: Utils.alpha(Theme.foreground, 0.25)
        Behavior on color { ColorAnimation { duration: 120 } }

        Text {
            id: deviceIcon
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: deviceRow.icon
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: Utils.scaledFont(14)
        }

        Text {
            anchors.left: deviceIcon.right
            anchors.leftMargin: 10
            anchors.right: defaultIcon.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: root.nodeLabel(deviceRow.node)
            color: Theme.foreground
            font.family: Theme.fontFamily
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
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: Utils.scaledFont(12)
        }

        MouseArea {
            id: deviceMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onContainsMouseChanged: if (containsMouse) {
                const index = ServiceAudio.outputs.indexOf(deviceRow.node);
                root.selectedDeviceIndex = index >= 0 ? index
                    : ServiceAudio.outputs.length
                        + ServiceAudio.inputs.indexOf(deviceRow.node);
            }
            onClicked: deviceRow.activated()
        }
    }
}
