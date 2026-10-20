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
    readonly property real maximumVolume: 1
    readonly property var nodes: Pipewire.nodes ? Pipewire.nodes.values : []
    readonly property var outputs: audioNodes(true)
    readonly property var inputs: audioNodes(false)
    // Channel swapping routes the default sink through a pw-loopback sink that
    // feeds the selected device with left and right exchanged. The loopback runs
    // as its own user unit so shell reloads do not interrupt playback, and its
    // current target is read back from PipeWire rather than kept here.
    readonly property string swapSinkName: "quickshell-swapped-output"
    readonly property bool swapChannels: swapToggle.active
    readonly property PwNode swapSink: nodes.find(node => node && node.name === swapSinkName) ?? null
    readonly property PwNode swapPlayback: nodes.find(node => node
        && node.name === swapSinkName + "-playback") ?? null
    readonly property string swapTargetName: swapPlayback
        ? String(swapPlayback.properties["target.object"] ?? "") : ""
    readonly property PwNode swapTarget: outputs.find(node => node.name === swapTargetName) ?? null
    // Target of a loopback (re)start that has not shown up in PipeWire yet.
    property string pendingSwapTarget: ""
    // Set shortly after startup, once PipeWire has reported the existing nodes,
    // so a reload never mistakes a not-yet-seen loopback for a missing one.
    property bool swapReady: false
    property PwNode previousDefaultSink: null
    // The real device being listened to, even while the swap sink is the default.
    readonly property PwNode output: swapSink && Pipewire.defaultAudioSink === swapSink
        ? swapTarget : Pipewire.defaultAudioSink
    readonly property PwNode input: Pipewire.defaultAudioSource
    readonly property real outputVolume: output && output.audio ? Number(output.audio.volume) : 0
    readonly property real inputVolume: input && input.audio ? Number(input.audio.volume) : 0
    readonly property bool outputMuted: output && output.audio ? output.audio.muted : false
    readonly property bool inputMuted: input && input.audio ? input.audio.muted : false

    // Speaker glyph for the current output level.
    readonly property string outputIcon: {
        if (outputMuted)
            return "󰝟";
        if (outputVolume >= 0.6)
            return "󰕾";
        if (outputVolume >= 0.2)
            return "󰖀";
        return "󰕿";
    }

    signal volumeIpcInvoked(bool input)

    function audioNodes(sinks: bool): var {
        return nodes.filter(node => node && node.ready && node.audio
            && !node.isStream && node.isSink === sinks && node.name !== swapSinkName);
    }

    function clampVolume(value: real): real {
        return Math.max(0, Math.min(maximumVolume, Number(value)));
    }

    // Snap PipeWire's imprecise float values to the volume grid.
    function snapToStep(value: real, step: real): real {
        return Math.round(value / step) * step;
    }

    // Every write goes through the grid, not just the keybind steps.
    function setOutputVolume(value: real): void {
        if (output && output.audio)
            output.audio.volume = clampVolume(snapToStep(value, outputStep));
    }

    function adjustOutputVolume(delta: real): void {
        setOutputVolume(snapToStep(outputVolume, outputStep) + delta);
    }

    function setInputVolume(value: real): void {
        if (input && input.audio)
            input.audio.volume = clampVolume(snapToStep(value, inputStep));
    }

    function adjustInputVolume(delta: real): void {
        setInputVolume(snapToStep(inputVolume, inputStep) + delta);
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
        if (!node || !node.audio || !node.isSink || node.isStream)
            return;
        if (swapChannels)
            retargetSwap(node.name);
        else
            Pipewire.preferredDefaultAudioSink = node;
    }

    function setSwapChannels(value: bool): void {
        swapToggle.setEnabled(value);
    }

    function retargetSwap(name: string): void {
        if (name === "" || name === pendingSwapTarget
            || (name === swapTargetName && !!swapSink))
            return;
        pendingSwapTarget = name;
        pendingSwapTimeout.restart();
        // Replaces any running unit; systemctl stop waits, so the names never clash.
        Quickshell.execDetached(["sh", "-c",
            "systemctl --user stop \"$0\" 2>/dev/null; exec systemd-run --user --quiet --collect --unit=\"$0\" -- \"$@\"",
            swapSinkName,
            "pw-loopback", "--name", swapSinkName,
            "--capture-props", "{ media.class=Audio/Sink node.name=" + swapSinkName
                + " node.description=\"Swapped channels\" audio.position=[ FL FR ] }",
            "--playback-props", "{ node.name=" + swapSinkName + "-playback"
                + " audio.position=[ FR FL ] stream.dont-remix=true node.passive=true"
                + " node.dont-reconnect=true target.object=\"" + name + "\" }"]);
    }

    function stopSwap(): void {
        pendingSwapTarget = "";
        Quickshell.execDetached(["systemctl", "--user", "stop", swapSinkName]);
    }

    // Keeps the loopback and the default sink in line with the swap setting.
    function syncSwap(): void {
        if (!swapToggle.stateLoaded || !swapReady)
            return;
        const current = Pipewire.defaultAudioSink;
        if (pendingSwapTarget !== "" && swapSink && swapTargetName === pendingSwapTarget)
            pendingSwapTarget = "";

        if (!swapChannels) {
            if (swapSink && current === swapSink && swapTarget)
                Pipewire.preferredDefaultAudioSink = swapTarget;
            if (swapSink || pendingSwapTarget !== "")
                stopSwap();
            return;
        }

        if (pendingSwapTarget === "") {
            if (!swapSink) {
                const first = current && outputs.includes(current) ? current : outputs[0];
                if (first)
                    retargetSwap(first.name);
            } else if (!swapTarget && outputs.length > 0) {
                // The target device went away.
                retargetSwap(outputs[0].name);
            }
        }

        if (swapSink && current !== swapSink && swapTarget && pendingSwapTarget === "")
            Pipewire.preferredDefaultAudioSink = swapSink;
    }

    onSwapChannelsChanged: syncSwap()
    onSwapSinkChanged: syncSwap()
    onSwapTargetChanged: syncSwap()
    onOutputsChanged: syncSwap()
    Connections {
        target: Pipewire
        function onDefaultAudioSinkChanged(): void {
            const current = Pipewire.defaultAudioSink;
            // Only a move away from a live swap sink is a device picked elsewhere;
            // the fallback while the loopback restarts happens with it gone.
            if (root.swapChannels && root.swapReady && root.swapSink
                    && root.previousDefaultSink === root.swapSink
                    && current && root.outputs.includes(current))
                root.retargetSwap(current.name);
            root.previousDefaultSink = current;
            root.syncSwap();
        }
    }

    Timer {
        running: true
        interval: 1500
        onTriggered: {
            root.previousDefaultSink = Pipewire.defaultAudioSink;
            root.swapReady = true;
            root.syncSwap();
        }
    }

    PersistentToggle {
        id: swapToggle
        stateFileName: "audio-swap-channels"
        ipcTarget: "audioSwap"
        onRestored: root.syncSwap()
    }

    // Gives up on a start that never appeared so the next sync can try again.
    Timer {
        id: pendingSwapTimeout
        interval: 3000
        onTriggered: {
            root.pendingSwapTarget = "";
            root.syncSwap();
        }
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
