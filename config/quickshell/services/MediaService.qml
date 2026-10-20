pragma Singleton

// MPRIS player selection plus IPC transport controls for media keybinds.
import QtQuick
import Quickshell.Io
import Quickshell.Services.Mpris

Item {
    id: root

    readonly property var players: Mpris.players ? Mpris.players.values : []
    // Prefer whatever is playing, otherwise the last player that was controlled.
    property MprisPlayer lastPlayer: null
    readonly property MprisPlayer player: players.find(player => player.isPlaying)
        ?? (players.includes(lastPlayer) ? lastPlayer : null)
        ?? players[0] ?? null
    readonly property bool playing: !!player && player.isPlaying
    readonly property string title: player ? (player.trackTitle || player.identity || "Unknown track") : ""
    readonly property string artist: player ? (player.trackArtist || "") : ""

    signal mediaIpcInvoked(string action)

    function control(action: string): void {
        const target = player;
        if (target) {
            lastPlayer = target;
            if (action === "playPause" && target.canTogglePlaying)
                target.togglePlaying();
            else if (action === "next" && target.canGoNext)
                target.next();
            else if (action === "previous" && target.canGoPrevious)
                target.previous();
            else if (action === "stop" && target.canControl)
                target.stop();
        }
    }

    function controlFromIpc(action: string): void {
        control(action);
        mediaIpcInvoked(action);
    }

    IpcHandler {
        target: "media"

        function playPause(): void { root.controlFromIpc("playPause"); }
        function next(): void { root.controlFromIpc("next"); }
        function previous(): void { root.controlFromIpc("previous"); }
        function stop(): void { root.controlFromIpc("stop"); }
    }
}
