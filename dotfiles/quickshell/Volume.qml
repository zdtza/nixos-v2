pragma ComponentBehavior: Bound

// PipeWire audio panel: default-device selection, volume controls, and mic peak.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Stylix

Item {
    id: root

    required property var screen
    readonly property bool available: !!AudioService.output
    readonly property bool opened: PanelService.activePanel === root
    readonly property bool requiresKeyboardFocus: false
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
        if (opened)
            selectedDeviceIndex = Math.max(0,
                AudioService.outputs.indexOf(AudioService.output));
        if (!opened && feedbackOpened) {
            feedbackClose.stop();
            feedbackOpened = false;
        }
    }

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
    Connections {
        target: AudioService
        function onVolumeIpcInvoked(): void { root.showIpcFeedback(); }
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
        color: keyboardSelected || deviceMouse.containsMouse
            ? Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.08)
            : "transparent"
        border.width: keyboardSelected || deviceMouse.containsMouse ? 1 : 0
        border.color: Qt.rgba(Theme.foreground.r, Theme.foreground.g,
            Theme.foreground.b, 0.25)
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
            anchors.right: defaultIcon.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: root.nodeLabel(deviceRow.node)
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: 12
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
            font.pixelSize: 12
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
