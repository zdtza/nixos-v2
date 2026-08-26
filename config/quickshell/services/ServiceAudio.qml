pragma Singleton

// Shared PipeWire state plus IPC controls for UI and window-manager keybinds.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

Item {
    id: root

    readonly property real outputStep: 0.05
    readonly property real inputStep: 0.05
    readonly property real maximumVolume: 1.5
    readonly property var nodes: Pipewire.nodes ? Pipewire.nodes.values : []
    readonly property var outputs: audioNodes(true)
    readonly property var inputs: audioNodes(false)
    readonly property PwNode output: Pipewire.defaultAudioSink
    readonly property PwNode input: Pipewire.defaultAudioSource
    readonly property real outputVolume: output && output.audio ? Number(output.audio.volume) : 0
    readonly property real inputVolume: input && input.audio ? Number(input.audio.volume) : 0
    readonly property bool outputMuted: output && output.audio ? output.audio.muted : false
    readonly property bool inputMuted: input && input.audio ? input.audio.muted : false

    signal volumeIpcInvoked(bool input)

    function audioNodes(sinks: bool): var {
        return nodes.filter(node => node && node.ready && node.audio
            && !node.isStream && node.isSink === sinks);
    }

    function clampVolume(value: real): real {
        return Math.max(0, Math.min(maximumVolume, Number(value)));
    }

    function setOutputVolume(value: real): void {
        if (output && output.audio)
            output.audio.volume = clampVolume(value);
    }

    function adjustOutputVolume(delta: real): void {
        setOutputVolume(outputVolume + delta);
    }

    function setInputVolume(value: real): void {
        if (input && input.audio)
            input.audio.volume = clampVolume(value);
    }

    function adjustInputVolume(delta: real): void {
        setInputVolume(inputVolume + delta);
    }

    function toggleOutputMute(): void {
        if (output && output.audio)
            output.audio.muted = !output.audio.muted;
    }

    function toggleInputMute(): void {
        if (input && input.audio)
            input.audio.muted = !input.audio.muted;
    }

    function selectOutput(node: var): void {
        if (node && node.audio && node.isSink && !node.isStream)
            Pipewire.preferredDefaultAudioSink = node;
    }

    function selectInput(node: var): void {
        if (node && node.audio && !node.isSink && !node.isStream)
            Pipewire.preferredDefaultAudioSource = node;
    }

    PwObjectTracker {
        objects: root.nodes
    }

    IpcHandler {
        target: "audio"

        function outputUp(): void {
            root.adjustOutputVolume(root.outputStep);
            root.volumeIpcInvoked(false);
        }
        function outputDown(): void {
            root.adjustOutputVolume(-root.outputStep);
            root.volumeIpcInvoked(false);
        }
        function inputUp(): void {
            root.adjustInputVolume(root.inputStep);
            root.volumeIpcInvoked(true);
        }
        function inputDown(): void {
            root.adjustInputVolume(-root.inputStep);
            root.volumeIpcInvoked(true);
        }
        function toggleOutputMute(): void {
            root.toggleOutputMute();
            root.volumeIpcInvoked(false);
        }
        function toggleInputMute(): void {
            root.toggleInputMute();
            root.volumeIpcInvoked(true);
        }
        function setOutput(percent: int): void {
            root.setOutputVolume(percent / 100);
            root.volumeIpcInvoked(false);
        }
        function setInput(percent: int): void {
            root.setInputVolume(percent / 100);
            root.volumeIpcInvoked(true);
        }
        function outputPercent(): int { return Math.round(root.outputVolume * 100); }
        function inputPercent(): int { return Math.round(root.inputVolume * 100); }
    }
}
